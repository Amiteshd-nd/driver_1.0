// Image provider: MOCK. Produces a deterministic procedural SVG per (animal, stage) so the whole pipeline —
// claim, QA, upload, review, display — runs end to end with no API key. It is a stylised emblem, not a real
// depiction; every row it produces is tagged provider='mock' so it can never be mistaken for final art.
// Vector by construction, so vectorisation is skipped and png may be null.
function hash(s) { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
const FAM = { swift: ['#F5E2C8', '#5A2E0C', '#E0902F'], steady: ['#D9E7D6', '#1F3D2B', '#4F8A5B'], calm: ['#E6DFF0', '#3A2E57', '#8B74C9'], gentle: ['#F1DCD1', '#5B2F22', '#C76A4E'],
  time: ['#EEF0FF', '#1F2340', '#8FA3FF'], explorer: ['#F3E3B8', '#4E3B10', '#D1A233'], regional: ['#D3ECEA', '#134845', '#2E9C96'], weekly: ['#F0D4D8', '#5A1322', '#B82A47'],
  migratory: ['#D7E8F7', '#143A5C', '#3E86C8'], secret: ['#E7DAF5', '#3C1F5E', '#9D6AE3'], national: ['#FBE4C6', '#6B3A0E', '#F2A33A'] };

export function mockSvg(animal, stage) {
  const h = hash(animal.slug || animal.name), [bg, fg, ac] = FAM[animal.family] || FAM.calm;
  const S = 1024, cx = 512, cy = 560;
  // stage cues: baby = bigger head, shorter body; adult = true proportions
  const headR = stage === 'baby' ? 150 : stage === 'young' ? 120 : 105;
  const bodyRx = stage === 'baby' ? 170 : stage === 'young' ? 200 : 230, bodyRy = stage === 'baby' ? 130 : 150;
  const legH = stage === 'baby' ? 70 : 120, earK = (h % 3), tail = 60 + (h % 50);
  const eyeR = stage === 'baby' ? 16 : 10;
  const rays = Array.from({ length: 12 }, (_, i) => { const a = (i / 12) * Math.PI * 2; return `<line x1="${cx}" y1="${cy - 60}" x2="${(cx + Math.cos(a) * 470).toFixed(0)}" y2="${(cy - 60 + Math.sin(a) * 470).toFixed(0)}" stroke="${ac}" stroke-opacity="0.08" stroke-width="18" stroke-linecap="round"/>`; }).join('');
  const sparkles = Array.from({ length: 7 }, (_, i) => { const x = 120 + ((h >> (i * 3)) % 780), y = 90 + ((h >> (i * 5)) % 520), r = 5 + ((h >> i) % 9); return `<path d="M${x} ${y - r} L${x + r * .35} ${y - r * .35} L${x + r} ${y} L${x + r * .35} ${y + r * .35} L${x} ${y + r} L${x - r * .35} ${y + r * .35} L${x - r} ${y} L${x - r * .35} ${y - r * .35}Z" fill="#fff" opacity="0.9"/>`; }).join('');
  const ears = earK === 0 ? `<circle cx="${cx - headR * .7}" cy="${cy - 160 - headR * .7}" r="${headR * .35}" fill="${fg}"/><circle cx="${cx + headR * .7}" cy="${cy - 160 - headR * .7}" r="${headR * .35}" fill="${fg}"/>`
    : earK === 1 ? `<path d="M${cx - headR * .8} ${cy - 160 - headR * .3} l-${headR * .25} -${headR * .9} l${headR * .6} ${headR * .45}Z" fill="${fg}"/><path d="M${cx + headR * .8} ${cy - 160 - headR * .3} l${headR * .25} -${headR * .9} l-${headR * .6} ${headR * .45}Z" fill="${fg}"/>`
    : `<ellipse cx="${cx - headR * .85}" cy="${cy - 160 - headR * .5}" rx="${headR * .22}" ry="${headR * .55}" fill="${fg}"/><ellipse cx="${cx + headR * .85}" cy="${cy - 160 - headR * .5}" rx="${headR * .22}" ry="${headR * .55}" fill="${fg}"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${S} ${S}" width="${S}" height="${S}" role="img" aria-label="${animal.name}, ${stage} (mock illustration)">
<defs><radialGradient id="glow" cx="50%" cy="48%" r="55%"><stop offset="0" stop-color="#fff" stop-opacity="0.95"/><stop offset="0.55" stop-color="${ac}" stop-opacity="0.35"/><stop offset="1" stop-color="${bg}" stop-opacity="0"/></radialGradient></defs>
<rect width="${S}" height="${S}" fill="${bg}"/>${rays}<circle cx="${cx}" cy="${cy - 60}" r="400" fill="url(#glow)"/>
<ellipse cx="${cx}" cy="${cy + bodyRy + legH + 30}" rx="${bodyRx * 1.1}" ry="26" fill="${fg}" opacity="0.12"/>
<rect x="${cx - bodyRx * .6}" y="${cy + bodyRy * .6}" width="46" height="${legH}" rx="22" fill="${fg}"/><rect x="${cx + bodyRx * .6 - 46}" y="${cy + bodyRy * .6}" width="46" height="${legH}" rx="22" fill="${fg}"/>
<path d="M${cx + bodyRx * .9} ${cy} q${tail} -${tail} ${tail * .4} -${tail * 1.6}" stroke="${fg}" stroke-width="30" fill="none" stroke-linecap="round"/>
<ellipse cx="${cx}" cy="${cy}" rx="${bodyRx}" ry="${bodyRy}" fill="${fg}"/>
${ears}<circle cx="${cx}" cy="${cy - 160}" r="${headR}" fill="${fg}"/>
<circle cx="${cx - headR * .35}" cy="${cy - 170}" r="${eyeR}" fill="${bg}"/><circle cx="${cx + headR * .35}" cy="${cy - 170}" r="${eyeR}" fill="${bg}"/>
<ellipse cx="${cx}" cy="${cy - 130}" rx="${headR * .28}" ry="${headR * .18}" fill="${ac}"/>
${sparkles}
<text x="${S - 24}" y="${S - 20}" font-family="monospace" font-size="22" fill="${fg}" opacity="0.35" text-anchor="end">mock · ${stage}</text>
</svg>`;
}

export function mockProvider() {
  return {
    name: 'mock', model: 'procedural-svg-v1',
    async generate({ animal, stage }) {
      const svg = mockSvg(animal, stage);
      return { png: null, svg, seed: String(hash(animal.slug + stage)), costCents: 0 };
    }
  };
}
