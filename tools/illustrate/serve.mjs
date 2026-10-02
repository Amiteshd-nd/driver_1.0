#!/usr/bin/env node
// Local illustration pipeline + workbench server.
//   node tools/illustrate/serve.mjs            → http://localhost:8790/workbench/
// Runs the SAME worker, agent and SQL as production, against an embedded Postgres (PGlite) with the repo's
// migrations, and a filesystem "bucket" at workbench/art/. Provider: mock by default; set OPENAI_API_KEY to
// generate real images and ANTHROPIC_API_KEY to run the vision QA. The workbench's Illustration Library talks
// to the /api endpoints below; in production the same calls go to Supabase RPCs and the Edge Function.
import http from 'node:http';
import { readFileSync, writeFileSync, existsSync, mkdirSync, statSync } from 'node:fs';
import { join, dirname, extname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadDb, signIn, createUser } from '../dbtest/harness.mjs';
import { runOnce, drain } from '../../supabase/functions/illustrate/core/worker.mjs';
import { createAgent } from '../../supabase/functions/illustrate/core/agent.mjs';
import { composePrompt } from '../../supabase/functions/illustrate/core/style.mjs';
import { openaiProvider } from '../../supabase/functions/illustrate/core/providers/openai.mjs';
import { mockProvider, mockSvg } from '../../supabase/functions/illustrate/core/providers/mock.mjs';
import { nodeTracer } from '../../supabase/functions/illustrate/core/vectorise.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(here, '..', '..');
const ART = join(ROOT, 'workbench', 'art');
const PORT = Number(process.env.PORT || 8790);
mkdirSync(ART, { recursive: true });

const db = await loadDb({ dataDir: join(here, '.pgdata') });   // persisted: the ledger survives restarts, like production
const q = async (s, p = []) => (await db.query(s, p)).rows;
const one = async (s, p = []) => (await q(s, p))[0];
// a local admin identity so admin-only RPCs work
const existing = await one(`select id from auth.users where email = 'local-admin@flyingcobra.test'`);
const admin = existing ? existing.id : await createUser(db, 'local-admin@flyingcobra.test', 'Local admin');
await q(`update profiles set is_admin = true where id = $1`, [admin]); await signIn(db, admin);

// providers
const providerName = process.env.ILLUSTRATION_PROVIDER || (process.env.OPENAI_API_KEY ? 'openai' : 'mock');
const provider = providerName === 'openai' ? openaiProvider({ apiKey: process.env.OPENAI_API_KEY }) : mockProvider();
let anthropic = null, zod = null;
if (process.env.ANTHROPIC_API_KEY) { try { anthropic = new (await import('@anthropic-ai/sdk')).default(); zod = (await import('zod')).z; } catch (e) { console.log('Anthropic SDK not installed; QA skipped (npm i in tools/illustrate)'); } }
const agent = createAgent({ anthropic, zod, log: console.log });
const tracer = await nodeTracer();

const dbi = {
  claim: (b, w) => q(`select * from illustrations_claim($1,$2)`, [b, w]),
  animal: (id) => one(`select id, slug, name, family, encyclopedia from animals where id=$1`, [id]),
  template: (v) => one(`select * from style_templates where version=$1`, [v]),
  complete: (id, r) => q(`select illustrations_complete($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`, [id, r.png, r.svg, r.hash, r.prompt, r.provider, r.model, r.seed, r.costCents, r.qaNotes]),
  fail: (id, e, qa, c) => q(`select illustrations_fail($1,$2,$3,$4)`, [id, e, qa, c])
};
const storage = { async put(path, bytes, ct) { const f = join(ART, path); mkdirSync(dirname(f), { recursive: true }); if (!existsSync(f)) writeFileSync(f, typeof bytes === 'string' ? bytes : Buffer.from(bytes)); return path; } };
const workerOpts = { db: dbi, storage, provider, agent, tracer, batch: 3, worker: 'local', log: console.log };

// ---------- API ----------
const api = {
  async 'GET /api/illustrations'() { return (await one(`select admin_illustration_library() l`)).l; },
  async 'GET /api/status'() { const rows = await q(`select status, count(*)::int n from animal_illustrations group by status`); return { provider: provider.name, model: provider.model, qa: anthropic ? 'claude-opus-5' : 'skipped', counts: Object.fromEntries(rows.map(r => [r.status, r.n])) }; },
  async 'POST /api/enqueue-missing'() { return { created: (await one(`select illustrations_enqueue_missing() n`)).n }; },
  async 'POST /api/run'(body) { return body.all ? await drain(workerOpts) : await runOnce({ ...workerOpts, batch: body.batch || 3 }); },
  async 'POST /api/run-animals'(body) { // generate specific animals/stages now (used for the first-three demo)
    const slugs = body.slugs || [], stages = body.stages || ['baby', 'adult'];
    await q(`update animal_illustrations i set created_at = now() - interval '1 day' from animals a where a.id = i.animal_id and a.slug = any($1) and i.growth_stage::text = any($2) and i.status='queued'`, [slugs, stages]);
    const need = (await one(`select count(*)::int n from animal_illustrations i join animals a on a.id=i.animal_id where a.slug = any($1) and i.growth_stage::text = any($2) and i.status='queued'`, [slugs, stages])).n;
    return await drain({ ...workerOpts, batch: Math.max(1, need) }, 1); },
  async 'POST /api/review'(body) { await q(`select illustrations_review($1,$2)`, [body.id, body.decision]); return { ok: true }; },
  async 'POST /api/animals'(body) { // dedup demo: create an animal; the trigger enqueues it
    const slug = String(body.name).toLowerCase().replace(/[^a-z]+/g, '-'); const code = (body.code || slug.replace(/-/g, '').slice(0, 4)).toUpperCase();
    const before = (await one(`select count(*)::int n from animal_illustrations`)).n;
    await q(`insert into animals(slug, code, name, family, rarity, flavour_line, encyclopedia) values ($1,$2,$3,$4,$5,$6,$7) on conflict (slug) do nothing`, [slug, code, body.name, body.family || 'calm', body.rarity || 'common', body.flavour || 'the newest arrival', body.encyclopedia || {}]);
    const a = await one(`select id from animals where slug=$1`, [slug]);
    const viaEnqueue = (await one(`select illustrations_enqueue($1) n`, [a.id])).n;      // explicit second request: must be 0 when the trigger already did it
    const after = (await one(`select count(*)::int n from animal_illustrations`)).n;
    return { slug, newRows: after - before, viaTrigger: after - before - viaEnqueue, viaExplicitEnqueue: viaEnqueue, rows: await q(`select growth_stage, status from animal_illustrations where animal_id=$1 order by growth_stage`, [a.id]) }; },
  async 'GET /api/style'() { return await q(`select * from style_templates order by version desc`); },
  async 'POST /api/style'(body) { // save = new version; existing art untouched
    const v = (await one(`select coalesce(max(version),0)+1 v from style_templates`)).v;
    await q(`update style_templates set is_active = false`);
    await q(`insert into style_templates(version, name, template, stage_cues, negative, qa_criteria, retry_adjustments, output, created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [v, body.name || `Style v${v}`, body.template, body.stage_cues, body.negative || '', body.qa_criteria || [], body.retry_adjustments || [], body.output || { size: '1024x1024', format: 'png' }, admin]);
    return { version: v }; },
  async 'POST /api/preview'(body) { // preview the draft template on one animal without persisting anything
    const a = await one(`select id, slug, name, family, encyclopedia from animals where slug=$1`, [body.slug || 'cheetah']);
    const tpl = body.template ? body : await one(`select * from style_templates where is_active order by version desc limit 1`);
    const { prompt } = composePrompt(tpl, a, body.stage || 'adult', 1);
    const gen = await provider.generate({ prompt, negative: tpl.negative, size: '1024x1024', animal: a, stage: body.stage || 'adult' });
    const svg = gen.svg || null; const png = gen.png ? Buffer.from(gen.png).toString('base64') : null;
    return { prompt, svg, png, provider: provider.name }; }
};

async function writeManifest() {
  const rows = (await one(`select admin_illustration_library() l`)).l; const style = await q(`select version, name, is_active from style_templates order by version desc`);
  const counts = Object.fromEntries((await q(`select status, count(*)::int n from animal_illustrations group by status`)).map(r => [r.status, r.n]));
  writeFileSync(join(ART, 'manifest.json'), JSON.stringify({ written: new Date().toISOString(), status: { provider: provider.name, model: provider.model, qa: anthropic ? 'claude-opus-5' : 'skipped', counts }, style, rows }, null, 1));
}
const MIME = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.md': 'text/markdown' };
http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x'); const key = `${req.method} ${url.pathname}`;
  res.setHeader('access-control-allow-origin', '*');
  if (api[key]) {
    let body = {}; if (req.method === 'POST') { const chunks = []; for await (const c of req) chunks.push(c); try { body = JSON.parse(Buffer.concat(chunks).toString() || '{}'); } catch { body = {}; } }
    try { const out = await api[key](body); if (req.method === 'POST') await writeManifest(); res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify(out)); }
    catch (e) { res.writeHead(500, { 'content-type': 'application/json' }); res.end(JSON.stringify({ error: e.message })); }
    return;
  }
  // static files from the repo root (the workbench, the design system, generated art)
  let p = decodeURIComponent(url.pathname); if (p.endsWith('/')) p += 'index.html';
  const f = resolve(ROOT, '.' + p); if (!f.startsWith(ROOT) || !existsSync(f) || statSync(f).isDirectory()) { res.writeHead(404); res.end('not found'); return; }
  res.writeHead(200, { 'content-type': MIME[extname(f)] || 'application/octet-stream', 'cache-control': p.startsWith('/workbench/art/') ? 'public, max-age=31536000, immutable' : 'no-store' });
  res.end(readFileSync(f));
}).listen(PORT, () => console.log(`Flying Cobra local pipeline · provider=${provider.name} · QA=${anthropic ? 'claude-opus-5' : 'skipped'}\n→ http://localhost:${PORT}/workbench/   (Illustration Library is under Design system in the Pages list)`));
