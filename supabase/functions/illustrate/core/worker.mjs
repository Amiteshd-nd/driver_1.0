// The worker loop. Platform-agnostic: it talks to the database and storage through two small interfaces so the
// same code runs in the Supabase Edge Function (Deno) and in the local runner (Node + PGlite + filesystem).
//
//   db.claim(batch, worker)            → rows from illustrations_claim(...)
//   db.animal(id)                      → animal row (name, slug, family, encyclopedia)
//   db.template(version)               → style_templates row
//   db.complete(id, {png, svg, hash, prompt, provider, model, seed, costCents, qaNotes})
//   db.fail(id, error, qaNotes, costCents)
//   storage.put(path, bytes|string, contentType) → public path
//
// One pass = claim a small batch, process each row once, return a summary. Call repeatedly (cron) until it returns 0 claimed.
import { vectorise, sha256Hex } from './vectorise.mjs';

export async function runOnce({ db, storage, provider, agent, tracer = null, batch = 3, worker = 'worker', log = () => {} }) {
  const rows = await db.claim(batch, worker);
  const summary = { claimed: rows.length, completed: 0, retried: 0, failed: 0, costCents: 0, items: [] };
  for (const row of rows) {
    const item = { id: row.id, stage: row.growth_stage, attempt: row.attempts };
    try {
      const animal = await db.animal(row.animal_id);
      const template = await db.template(row.style_version);
      item.animal = animal.slug;
      const { prompt, negative } = agent.prompt(template, animal, row.growth_stage, row.attempts);
      const size = (template.output && template.output.size) || '1024x1024';
      log(`[${worker}] ${animal.slug}/${row.growth_stage} attempt ${row.attempts} via ${provider.name}`);

      let gen;
      try { gen = await provider.generate({ prompt, negative, size, animal, stage: row.growth_stage }); }
      catch (e) { // provider error: count the attempt, re-queue (or fail) with the reason
        await db.fail(row.id, `provider: ${e.message}`, null, 0); summary[row.attempts >= row.max_attempts ? 'failed' : 'retried']++; item.error = e.message; summary.items.push(item); continue;
      }
      summary.costCents += gen.costCents || 0;

      const qa = await agent.qa({ template, animal, stage: row.growth_stage, png: gen.png, svg: gen.svg, provider: provider.name });
      const decision = agent.decide({ qa, attempt: row.attempts, maxAttempts: row.max_attempts });
      item.qa = qa.reason;
      if (decision !== 'accept') {
        await db.fail(row.id, `QA ${decision === 'retry' ? 'retry' : 'failed'}: ${qa.reason}`, qa.reason, gen.costCents || 0);
        summary[decision === 'retry' ? 'retried' : 'failed']++; summary.items.push(item); continue;
      }

      // post-process: vectorise (if we have a raster), hash, store at the immutable paths
      const svg = gen.svg || await vectorise(gen.png, { trace: tracer });
      const base = `${animal.slug}/${row.growth_stage}/${row.variant}/v${row.style_version}`;
      let pngPath = null, svgPath = null;
      if (gen.png) pngPath = await storage.put(`${base}.png`, gen.png, 'image/png');
      if (svg) svgPath = await storage.put(`${base}.svg`, svg, 'image/svg+xml');
      const hash = await sha256Hex(gen.png || svg);
      await db.complete(row.id, { png: pngPath, svg: svgPath, hash, prompt, provider: provider.name, model: provider.model, seed: gen.seed, costCents: gen.costCents || 0, qaNotes: qa.reason });
      summary.completed++; item.png = pngPath; item.svg = svgPath; summary.items.push(item);
    } catch (e) {
      log(`[${worker}] error on ${row.id}: ${e.message}`);
      try { await db.fail(row.id, `worker: ${e.message}`, null, 0); } catch { /* ignore */ }
      summary.failed++; item.error = e.message; summary.items.push(item);
    }
  }
  return summary;
}

/** Drain the queue: keep running passes until nothing is claimed or maxPasses is hit. */
export async function drain(opts, maxPasses = 200) {
  const total = { passes: 0, claimed: 0, completed: 0, retried: 0, failed: 0, costCents: 0, items: [] };
  for (let i = 0; i < maxPasses; i++) {
    const s = await runOnce(opts);
    total.passes++; total.claimed += s.claimed; total.completed += s.completed; total.retried += s.retried; total.failed += s.failed; total.costCents += s.costCents; total.items.push(...s.items);
    if (s.claimed === 0) break;
  }
  return total;
}
