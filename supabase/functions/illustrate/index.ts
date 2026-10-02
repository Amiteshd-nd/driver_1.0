// Flying Cobra · illustrate — the server-side illustration worker (Supabase Edge Function, Deno).
// POST /illustrate            {action:"run", passes?:number}   → claim+generate+QA+store, returns a summary
// POST /illustrate            {action:"enqueue-missing"}        → idempotent upsert for every active animal
// GET  /illustrate?status=1                                     → queue counts
// Auth: a signed-in admin's JWT, or the service role key (for pg_cron / scheduled calls).
// Secrets (set with `supabase secrets set`): OPENAI_API_KEY (image model), ANTHROPIC_API_KEY (vision QA; optional),
// SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto-provided to functions), ILLUSTRATION_PROVIDER=openai|mock (default openai when key present).
import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { z } from 'npm:zod@3';
import { runOnce, drain } from './core/worker.mjs';
import { createAgent } from './core/agent.mjs';
import { openaiProvider } from './core/providers/openai.mjs';
import { mockProvider } from './core/providers/mock.mjs';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const BUCKET = 'animal-art';

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*', 'access-control-allow-headers': 'authorization, content-type' } });
}

async function authorise(req: Request): Promise<{ ok: boolean; who: string }> {
  const auth = req.headers.get('authorization') ?? '';
  const token = auth.replace(/^Bearer\s+/i, '');
  if (!token) return { ok: false, who: 'anon' };
  if (token === SERVICE_KEY) return { ok: true, who: 'service' };
  // a user JWT: ask the database whether this user is an admin (RLS-safe, uses is_admin())
  const asUser = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { authorization: `Bearer ${token}` } } });
  const { data, error } = await asUser.rpc('is_admin');
  return { ok: !error && data === true, who: 'admin' };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json({ ok: true });
  const who = await authorise(req);
  if (!who.ok) return json({ error: 'admin or service role required' }, 401);

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);
  const url = new URL(req.url);

  if (req.method === 'GET' && url.searchParams.has('status')) {
    const { data, error } = await sb.from('animal_illustrations').select('status');
    if (error) return json({ error: error.message }, 500);
    const counts: Record<string, number> = {};
    for (const r of data ?? []) counts[r.status] = (counts[r.status] ?? 0) + 1;
    return json({ counts, total: data?.length ?? 0 });
  }

  const body = req.method === 'POST' ? await req.json().catch(() => ({})) : {};
  if (body.action === 'enqueue-missing') {
    const { data, error } = await sb.rpc('illustrations_enqueue_missing', { p_variant: body.variant ?? 'base' });
    return error ? json({ error: error.message }, 500) : json({ created: data });
  }

  // ---- style preview: compose the prompt for one animal with a draft template and generate once, nothing persisted ----
  if (body.action === 'preview') {
    const { data: animal, error: aErr } = await sb.from('animals').select('id,slug,name,family,encyclopedia').eq('slug', body.slug ?? 'cheetah').single();
    if (aErr) return json({ error: aErr.message }, 404);
    let tpl = body.template ? body : null;
    if (!tpl) { const { data } = await sb.from('style_templates').select('*').eq('is_active', true).order('version', { ascending: false }).limit(1).single(); tpl = data; }
    const { composePrompt } = await import('./core/style.mjs');
    const { prompt, negative } = composePrompt(tpl, animal, body.stage ?? 'adult', 1);
    const openaiKey0 = Deno.env.get('OPENAI_API_KEY');
    const prov = (Deno.env.get('ILLUSTRATION_PROVIDER') ?? (openaiKey0 ? 'openai' : 'mock')) === 'openai' ? openaiProvider({ apiKey: openaiKey0 }) : mockProvider();
    try {
      const gen = await prov.generate({ prompt, negative, size: '1024x1024', animal, stage: body.stage ?? 'adult' });
      const png = gen.png ? btoa(String.fromCharCode(...gen.png)) : null;
      return json({ prompt, negative, svg: gen.svg ?? null, png, provider: prov.name, model: prov.model, cost_cents: gen.costCents ?? 0 });
    } catch (e) { return json({ prompt, negative, svg: null, png: null, provider: prov.name, error: String((e as Error).message) }); }
  }

  // ---- the worker ----
  const openaiKey = Deno.env.get('OPENAI_API_KEY');
  const providerName = Deno.env.get('ILLUSTRATION_PROVIDER') ?? (openaiKey ? 'openai' : 'mock');
  const provider = providerName === 'openai' ? openaiProvider({ apiKey: openaiKey }) : mockProvider();
  const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY');
  const agent = createAgent({ anthropic: anthropicKey ? new Anthropic({ apiKey: anthropicKey }) : null, zod: anthropicKey ? z : null, log: console.log });

  const db = {
    async claim(batch: number, worker: string) { const { data, error } = await sb.rpc('illustrations_claim', { p_batch: batch, p_worker: worker }); if (error) throw new Error(error.message); return data ?? []; },
    async animal(id: string) { const { data, error } = await sb.from('animals').select('id,slug,name,family,encyclopedia').eq('id', id).single(); if (error) throw new Error(error.message); return data; },
    async template(version: number) { const { data, error } = await sb.from('style_templates').select('*').eq('version', version).single(); if (error) throw new Error(error.message); return data; },
    async complete(id: string, r: Record<string, unknown>) { const { error } = await sb.rpc('illustrations_complete', { p_id: id, p_png: r.png, p_svg: r.svg, p_hash: r.hash, p_prompt: r.prompt, p_provider: r.provider, p_model: r.model, p_seed: r.seed, p_cost_cents: r.costCents, p_qa_notes: r.qaNotes }); if (error) throw new Error(error.message); },
    async fail(id: string, err: string, qa: string | null, cost: number) { const { error } = await sb.rpc('illustrations_fail', { p_id: id, p_error: err, p_qa_notes: qa, p_cost_cents: cost }); if (error) throw new Error(error.message); }
  };
  const storage = {
    async put(path: string, bytes: Uint8Array | string, contentType: string) {
      const body = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes;
      // immutable per path: never overwrite; if it exists (re-run after a crash), keep it
      const { error } = await sb.storage.from(BUCKET).upload(path, body, { contentType, cacheControl: '31536000', upsert: false });
      if (error && !/exists|duplicate/i.test(error.message)) throw new Error(`storage: ${error.message}`);
      return path;
    }
  };

  const opts = { db, storage, provider, agent, batch: Number(body.batch ?? 3), worker: `edge-${who.who}`, log: console.log };
  const summary = body.passes && body.passes > 1 ? await drain(opts, Number(body.passes)) : await runOnce(opts);
  return json({ provider: provider.name, model: provider.model, qa: anthropicKey ? 'claude-opus-5' : 'skipped', ...summary });
});
