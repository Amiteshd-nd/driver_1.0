// Image provider: OpenAI Images API (gpt-image-1). Raw HTTP on purpose — this is the image model,
// not Claude; the provider interface is {name, model, generate({prompt, negative, size}) → {png: Uint8Array, seed, costCents}}.
// Commercial use: OpenAI's terms assign output ownership to the customer; record provider+model per row for the audit trail.
export function openaiProvider({ apiKey, model = 'gpt-image-1', quality = 'medium' } = {}) {
  if (!apiKey) throw new Error('OPENAI_API_KEY is not set');
  // Approximate list prices per image for cost tracking (cents). Adjust in one place if pricing changes.
  const COST = { low: 1.1, medium: 4.2, high: 16.7 };
  return {
    name: 'openai', model,
    async generate({ prompt, negative, size = '1024x1024' }) {
      const body = { model, prompt: negative ? `${prompt}\n\nAvoid: ${negative}.` : prompt, n: 1, size, quality, output_format: 'png', background: 'opaque' };
      const res = await fetch('https://api.openai.com/v1/images/generations', {
        method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` }, body: JSON.stringify(body)
      });
      if (!res.ok) { const txt = await res.text().catch(() => ''); const err = new Error(`openai ${res.status}: ${txt.slice(0, 300)}`); err.retryable = res.status === 429 || res.status >= 500; throw err; }
      const json = await res.json();
      const b64 = json?.data?.[0]?.b64_json; if (!b64) throw new Error('openai: no image in response');
      const bin = typeof Buffer !== 'undefined' ? new Uint8Array(Buffer.from(b64, 'base64')) : Uint8Array.from(atob(b64), c => c.charCodeAt(0));
      return { png: bin, seed: json?.created ? String(json.created) : null, costCents: COST[quality] ?? COST.medium };
    }
  };
}
