// PNG → SVG vectorisation. Best effort: image models output raster; a posterised trace gives a true scalable
// asset for flat illustrations. If tracing fails or the result is poor, the pipeline keeps the PNG (PRD §3).
// Implementation is injected (`trace(png) → svg string`) so Deno and Node can supply potrace via npm.
export async function vectorise(png, { trace } = {}) {
  if (!png || !trace) return null;
  try {
    const svg = await trace(png);
    if (typeof svg !== 'string' || svg.length < 200 || !svg.includes('<svg')) return null;
    // crude quality gate: an SVG with almost no paths is a failed trace, not an illustration
    const paths = (svg.match(/<path/g) || []).length;
    return paths >= 3 ? svg : null;
  } catch { return null; }
}

/** potrace-based tracer for Node (npm i potrace jimp). 8-colour posterisation suits flat vector art. */
export async function nodeTracer() {
  try {
    const potrace = await import('potrace');
    const { posterize } = potrace.default || potrace;
    return (png) => new Promise((res, rej) => posterize(Buffer.from(png), { steps: 8, fillStrategy: 'dominant', background: '#FFFFFF' }, (err, svg) => err ? rej(err) : res(svg)));
  } catch { return null; } // potrace not installed → PNG only
}

export async function sha256Hex(bytes) {
  const buf = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes;
  const digest = await crypto.subtle.digest('SHA-256', buf);
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, '0')).join('');
}
