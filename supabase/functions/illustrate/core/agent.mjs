// The Illustrator Agent (PRD §9). Composes each animal's prompt from the style template, runs the vision QA
// on the generated image with Claude, decides retry vs fail, and writes a plain-language rejection reason.
// `makeAnthropic` is injected so Deno (npm: specifier) and Node (@anthropic-ai/sdk) can both supply the SDK;
// with no key, or provider 'mock', QA runs in mock mode and passes with a note.
import { composePrompt, qaCriteria } from './style.mjs';

const QA_MODEL = 'claude-opus-5';

export function createAgent({ anthropic = null, zod = null, log = () => {} } = {}) {
  return {
    /** Build the prompt for this row (attempt-aware: later attempts append retry adjustments). */
    prompt(template, animal, stage, attempt) { return composePrompt(template, animal, stage, attempt); },

    /** Vision QA. Returns {pass, reason, confidence}. Never throws on a model refusal: that counts as a soft fail. */
    async qa({ template, animal, stage, png, svg, provider }) {
      const criteria = qaCriteria(template, animal, stage);
      if (provider === 'mock' || !anthropic) {
        return { pass: true, reason: provider === 'mock' ? 'Mock provider: QA skipped (procedural emblem, not final art).' : 'QA skipped: ANTHROPIC_API_KEY not set.', confidence: 0 };
      }
      if (!png) return { pass: false, reason: 'No raster image to check.', confidence: 1 };
      const b64 = typeof Buffer !== 'undefined' ? Buffer.from(png).toString('base64') : btoa(String.fromCharCode(...png));
      const schema = zod ? zod.object({ pass: zod.boolean(), reason: zod.string(), failed_criteria: zod.array(zod.string()), confidence: zod.number() }) : null;
      const { zodOutputFormat } = zod ? await import('@anthropic-ai/sdk/helpers/zod') : { zodOutputFormat: null };
      const text = `You are the quality check for a children's-book style animal illustration pipeline. Judge this image against every criterion. ` +
        `Be strict about species identity, single animal, light background, vector look and absence of text. Write "reason" as one or two plain sentences a designer would understand.\n\nCriteria:\n` + criteria.map((c, i) => `${i + 1}. ${c}`).join('\n');
      const req = {
        model: QA_MODEL, max_tokens: 1024, output_config: { effort: 'low' },
        messages: [{ role: 'user', content: [{ type: 'image', source: { type: 'base64', media_type: 'image/png', data: b64 } }, { type: 'text', text }] }]
      };
      try {
        if (schema && zodOutputFormat) {
          const res = await anthropic.messages.parse({ ...req, output_config: { ...req.output_config, format: zodOutputFormat(schema) } });
          if (res.stop_reason === 'refusal') return { pass: false, reason: 'The QA model declined to assess this image.', confidence: 0 };
          const v = res.parsed_output; if (!v) return { pass: false, reason: 'QA returned no verdict.', confidence: 0 };
          return { pass: v.pass, reason: v.reason, failed: v.failed_criteria, confidence: v.confidence };
        }
        const res = await anthropic.messages.create({ ...req, messages: [{ role: 'user', content: [...req.messages[0].content, { type: 'text', text: 'Reply with JSON only: {"pass":boolean,"reason":string,"failed_criteria":string[],"confidence":number}' }] }] });
        if (res.stop_reason === 'refusal') return { pass: false, reason: 'The QA model declined to assess this image.', confidence: 0 };
        const out = res.content.find(b => b.type === 'text')?.text || '{}';
        const v = JSON.parse(out.slice(out.indexOf('{'), out.lastIndexOf('}') + 1));
        return { pass: !!v.pass, reason: v.reason || '', failed: v.failed_criteria || [], confidence: v.confidence ?? 0.5 };
      } catch (e) {
        log('qa error', e?.message);
        return { pass: false, reason: `QA could not run: ${e?.message || e}`, confidence: 0, transient: true };
      }
    },

    /** Retry policy: retry on QA failure while attempts remain; fail for good otherwise. */
    decide({ qa, attempt, maxAttempts }) {
      if (qa.pass) return 'accept';
      return attempt < maxAttempts ? 'retry' : 'fail';
    }
  };
}
