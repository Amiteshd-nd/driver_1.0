// Pugmark — public verify page (Supabase Edge Function, Deno, no dependencies).
//
//   GET /verify/<animal-slug>/<serial>            → HTML page with Open Graph tags
//   GET /verify/<animal-slug>/<serial>/card.svg   → 1200×630 SVG preview image
//   GET /verify?q=Tiger%20%230427                 → HTML page (free-form serial)
//   GET /verify                                   → HTML search page
//
// Calls the `lookup_serial(q)` RPC with the anon key. Only whitelisted fields are rendered;
// every dynamic string is escaped. Never renders location, route or health data.

const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const PUBLIC_BASE_URL = (Deno.env.get("PUBLIC_BASE_URL") ?? "").replace(/\/+$/, ""); // optional override for absolute og:image URLs

const CACHE = "public, max-age=300";
const FONTS =
  "https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,500;0,9..144,600;1,9..144,500&family=Manrope:wght@400;500;600;700&display=swap";

type Palette = { bg: string; fg: string; accent: string };
const FAMILIES: Record<string, Palette> = {
  swift: { bg: "#F5E2C8", fg: "#5A2E0C", accent: "#E0902F" },
  steady: { bg: "#D9E7D6", fg: "#1F3D2B", accent: "#4F8A5B" },
  calm: { bg: "#E6DFF0", fg: "#3A2E57", accent: "#8B74C9" },
  gentle: { bg: "#F1DCD1", fg: "#5B2F22", accent: "#C76A4E" },
  time: { bg: "#1F2340", fg: "#E7E4FF", accent: "#8FA3FF" },
  explorer: { bg: "#F3E3B8", fg: "#4E3B10", accent: "#D1A233" },
  regional: { bg: "#D3ECEA", fg: "#134845", accent: "#2E9C96" },
  weekly: { bg: "#F0D4D8", fg: "#5A1322", accent: "#B82A47" },
  migratory: { bg: "#D7E8F7", fg: "#143A5C", accent: "#3E86C8" },
  secret: { bg: "#E7DAF5", fg: "#3C1F5E", accent: "#9D6AE3" },
  national: { bg: "#FBE4C6", fg: "#6B3A0E", accent: "#F2A33A" },
};
const RARITIES = new Set(["common", "uncommon", "rare", "epic", "legendary"]);
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const HEX = /^#[0-9a-fA-F]{6}$/;

// ---------- helpers ----------
function esc(s: unknown): string {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}
function str(v: unknown, fallback = ""): string {
  return typeof v === "string" ? v : fallback;
}
function num(v: unknown): number | null {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}
function obj(v: unknown): Record<string, unknown> {
  return v !== null && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}
function pad4(n: number): string {
  return String(n).padStart(4, "0");
}
function mmss(sec: number): string {
  const s = Math.round(sec);
  const m = Math.floor(s / 60), r = s % 60;
  if (m >= 60) {
    const hh = Math.floor(m / 60), mm = m % 60;
    return `${hh}:${String(mm).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
  }
  return `${m}:${String(r).padStart(2, "0")}`;
}
function fmtDate(iso: string): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const parts = new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Kolkata", day: "numeric", month: "numeric", year: "numeric" }).formatToParts(d);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  const mi = Number(get("month")) - 1;
  return `${get("day")} ${MONTHS[mi] ?? ""} ${get("year")}`.trim();
}
function cap(s: string): string {
  return s ? s.charAt(0).toUpperCase() + s.slice(1) : "";
}

// ---------- view model: only these keys ever reach the page ----------
interface CardView {
  slug: string; name: string; family: string; rarity: string; flavour: string; season: string;
  serialNo: number; scope: string; verdict: string; issuedAt: string;
  palette: Palette; earnedBy: string; issuedSoFar: number; statsLine: string;
}
interface NotFound { found: false; reason: string; hint: string; animal: string; issuedSoFar: number }
type Lookup = { found: true; view: CardView } | NotFound;

function statsLine(stats: Record<string, unknown>, scope: string): string {
  const km = num(stats.distance_km);
  const kmS = km !== null ? `${km.toFixed(1)} km` : null;
  if (scope === "weekly" && num(stats.run_days) !== null) return `${num(stats.run_days)} days${kmS ? ` · ${kmS}` : ""}`;
  if (scope === "monthly") return [str(stats.month), str(stats.region)].filter(Boolean).join(" · ") || kmS || "";
  const bits: string[] = [];
  if (kmS) bits.push(kmS);
  const dur = num(stats.duration_s);
  if (dur !== null) bits.push(mmss(dur));
  const pace = num(stats.pace_s_per_km);
  if (pace !== null) bits.push(`${mmss(pace)}/km`);
  return bits.join(" · ");
}

function toLookup(raw: unknown): Lookup {
  const r = obj(raw);
  if (r.found !== true) {
    return {
      found: false,
      reason: str(r.reason, "serial"),
      hint: str(r.hint),
      animal: str(r.animal),
      issuedSoFar: num(r.issued_so_far) ?? 0,
    };
  }
  const c = obj(r.card);
  const pal = obj(c.palette);
  const family = str(c.family);
  const fam = FAMILIES[family] ?? FAMILIES.swift;
  const rarityRaw = str(c.rarity, "common");
  const stats = obj(r.stats);
  const scope = str(c.scope, "run");
  return {
    found: true,
    view: {
      slug: str(c.slug).replace(/[^a-z0-9-]/gi, ""),
      name: str(c.name, "Unknown"),
      family,
      rarity: RARITIES.has(rarityRaw) ? rarityRaw : "common",
      flavour: str(c.flavour_line),
      season: str(c.season),
      serialNo: num(c.serial_no) ?? 0,
      scope,
      verdict: str(c.verdict, "verified"),
      issuedAt: str(c.issued_at) || str(stats.date),
      palette: {
        bg: HEX.test(str(pal.bg)) ? str(pal.bg) : fam.bg,
        fg: HEX.test(str(pal.fg)) ? str(pal.fg) : fam.fg,
        accent: HEX.test(str(pal.accent)) ? str(pal.accent) : fam.accent,
      },
      earnedBy: str(r.earned_by, "a runner"),
      issuedSoFar: num(r.issued_so_far) ?? 0,
      statsLine: statsLine(stats, scope),
    },
  };
}

// ---------- RPC ----------
async function lookupSerial(q: string): Promise<Lookup> {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) throw new Error("SUPABASE_URL / SUPABASE_ANON_KEY not set");
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 8000);
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/lookup_serial`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({ q }),
      signal: ctl.signal,
    });
    if (!res.ok) throw new Error(`lookup_serial HTTP ${res.status}`);
    return toLookup(await res.json());
  } finally {
    clearTimeout(timer);
  }
}

// ---------- shared HTML bits ----------
const CSS = `
:root{--bg:#F7F3EC;--surface:#fff;--surface-alt:#EFE9DE;--ink:#1B1B18;--ink-muted:#6B6A63;--line:#E2DCD0;--accent:#C8551B;--accent-fill:#B84A14;--accent-ink:#fff;--success:#2E7D5B;--warn:#B3791C;--danger:#A33A2B;--shadow:0 18px 50px -24px rgba(27,27,24,.35);--display:"Fraunces","Iowan Old Style",Georgia,serif;--text:"Manrope",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;color-scheme:light dark}
@media(prefers-color-scheme:dark){:root{--bg:#121311;--surface:#1C1E1B;--surface-alt:#262925;--ink:#F2EFE8;--ink-muted:#A5A49C;--line:#33362F;--accent:#F08A4B;--accent-fill:#F08A4B;--accent-ink:#1B1B18;--success:#59B98F;--warn:#E0A94C;--danger:#E0695A;--shadow:0 18px 50px -20px rgba(0,0,0,.7)}}
*,*::before,*::after{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:400 16px/1.5 var(--text);-webkit-font-smoothing:antialiased}
h1,h2{font-family:var(--display);font-weight:600;margin:0 0 .4em;letter-spacing:-.01em}h1{font-size:clamp(1.8rem,4vw,2.6rem);line-height:1.1}h2{font-size:1.5rem;line-height:1.2}p{margin:0 0 1em}
a{color:inherit;text-decoration-color:var(--accent);text-decoration-thickness:2px;text-underline-offset:3px}:focus-visible{outline:3px solid var(--accent);outline-offset:3px;border-radius:4px}
.wrap{width:min(100% - 32px,1100px);margin-inline:auto}.muted{color:var(--ink-muted)}.eyebrow{font:500 13px/1.4 var(--text);letter-spacing:.08em;text-transform:uppercase;color:var(--accent-fill);margin-bottom:12px}
.nav{border-bottom:1px solid var(--line)}.nav .wrap{display:flex;align-items:center;gap:12px;min-height:64px}.brand{display:inline-flex;align-items:center;gap:10px;text-decoration:none;font:600 22px/1 var(--display);color:var(--ink);margin-right:auto}.brand svg{width:30px;height:30px;fill:var(--accent)}
main{padding-block:clamp(32px,6vw,72px);min-height:60vh}.layout{display:grid;gap:32px;align-items:start}@media(min-width:860px){.layout{grid-template-columns:340px 1fr}}
.btn{display:inline-flex;align-items:center;justify-content:center;min-height:48px;padding:0 20px;border-radius:999px;font:600 15px/1 var(--text);text-decoration:none;border:1.5px solid var(--line);background:var(--surface);color:var(--ink)}.btn--primary{background:var(--accent-fill);border-color:var(--accent-fill);color:var(--accent-ink)}.actions{display:flex;gap:12px;flex-wrap:wrap;margin-top:8px}
.lookup{display:flex;gap:10px;flex-wrap:wrap;max-width:560px;margin-bottom:40px}.lookup label{flex:1 1 100%;font-weight:600;font-size:14px}.lookup input{flex:1 1 220px;min-height:48px;padding:0 16px;border-radius:999px;border:1.5px solid var(--line);background:var(--surface);color:var(--ink);font:500 16px/1 var(--display);letter-spacing:.04em}
.seal{display:inline-flex;align-items:center;gap:10px;padding:8px 14px 8px 10px;border-radius:999px;border:1.5px solid var(--success);color:var(--success);font-weight:600;font-size:14px;background:var(--surface)}.seal--warn{border-color:var(--warn);color:var(--warn)}.seal--off{border-color:var(--danger);color:var(--danger)}.seal svg{width:20px;height:20px}
.facts{margin:20px 0 0;padding:0;list-style:none;border-top:1px solid var(--line)}.facts li{display:flex;justify-content:space-between;gap:16px;padding:12px 0;border-bottom:1px solid var(--line);font-size:15px}.facts li span:first-child{color:var(--ink-muted)}.facts b{font:500 16px/1.3 var(--display);letter-spacing:.06em;font-variant-numeric:tabular-nums;text-align:right}
.state{background:var(--surface);border:1px solid var(--line);border-radius:16px;padding:28px;max-width:640px}.state code{font:500 14px/1.4 ui-monospace,Menlo,monospace;background:var(--surface-alt);padding:2px 6px;border-radius:6px}
footer{border-top:1px solid var(--line);padding:40px 0 56px;color:var(--ink-muted);font-size:14px}footer .wrap{display:flex;flex-wrap:wrap;gap:12px 24px;align-items:center}footer .tag{font:600 20px/1 var(--display);color:var(--ink);margin-right:auto}
.card{position:relative;width:300px;aspect-ratio:5/7;border-radius:16px;background:var(--surface);color:var(--ink);overflow:hidden;display:flex;flex-direction:column;box-shadow:var(--shadow);border:1px solid var(--line);margin-inline:auto}
.card--uncommon{border:1.5px solid var(--fam-accent)}.card--rare,.card--epic,.card--legendary{border:2px solid transparent;background:linear-gradient(var(--surface),var(--surface)) padding-box,linear-gradient(135deg,var(--fam-accent),#fff 60%,var(--fam-accent)) border-box}.card--epic{border-width:2.5px;box-shadow:var(--shadow),inset 0 0 0 1px var(--line)}.card--legendary{border-width:3px}
.card__cap{display:flex;justify-content:space-between;align-items:center;gap:8px;padding:12px 16px 8px;font:500 12px/1.3 var(--text);letter-spacing:.04em;text-transform:uppercase;color:var(--ink-muted)}.card__rarity{display:inline-flex;align-items:center;gap:6px}.card__rarity::before{content:"";width:8px;height:8px;border-radius:50%;background:var(--fam-accent)}
.card__art{height:50%;margin:0 12px;border-radius:12px;background:var(--fam-bg);color:var(--fam-fg);display:grid;place-items:center;overflow:hidden}.card__glyph{width:56%;aspect-ratio:1;border-radius:50%;background:var(--fam-accent);color:var(--fam-bg);display:grid;place-items:center;font:600 92px/1 var(--display);box-shadow:inset -14px -18px 0 rgba(0,0,0,.12)}
.card__body{padding:14px 16px 16px;display:flex;flex-direction:column;flex:1}.card__name{font:600 28px/32px var(--display);margin:0}.card__flavour{font:italic 400 14px/20px var(--text);color:var(--ink-muted);margin:2px 0 0;min-height:40px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.card__rule{border:0;border-top:1px solid var(--line);margin:auto 0 10px}.card__stats{font:500 13px/18px var(--text);letter-spacing:.02em;margin:0 0 6px;font-variant-numeric:tabular-nums}
.card__serial{display:flex;align-items:baseline;gap:10px;margin:0;font:500 18px/22px var(--display);letter-spacing:.08em;font-variant-numeric:tabular-nums;font-feature-settings:"tnum";text-transform:uppercase}.card__serial .tick{margin-left:auto;font:700 15px/1 var(--text);letter-spacing:0;color:var(--success)}.card__serial .tick--unverified{color:var(--warn);font-size:11px;border:1.5px solid currentColor;border-radius:999px;padding:1px 7px;text-transform:none;align-self:center}
.card--epic::after,.card--legendary::after{content:"";position:absolute;inset:-40%;pointer-events:none;z-index:2;background:conic-gradient(from 0deg,transparent 0 18%,rgba(255,120,200,.55) 24%,rgba(140,220,255,.6) 29%,rgba(255,240,150,.55) 34%,transparent 40%,transparent 58%,rgba(255,255,255,.5) 66%,transparent 74%);-webkit-mask:radial-gradient(closest-side,#000 20%,rgba(0,0,0,.35) 60%,transparent);mask:radial-gradient(closest-side,#000 20%,rgba(0,0,0,.35) 60%,transparent);mix-blend-mode:soft-light;opacity:.9;animation:foil 9s linear infinite}
@media(prefers-color-scheme:dark){.card--epic::after,.card--legendary::after{mix-blend-mode:screen;opacity:.35}}@keyframes foil{to{transform:rotate(1turn)}}@media(prefers-reduced-motion:reduce){.card--epic::after,.card--legendary::after{animation:none;transform:rotate(35deg);opacity:.45}}
`;

const PAW =
  `<svg viewBox="0 0 100 100" aria-hidden="true" focusable="false"><ellipse cx="19" cy="36" rx="10" ry="12"/><ellipse cx="39" cy="20" rx="10" ry="12"/><ellipse cx="61" cy="20" rx="10" ry="12"/><ellipse cx="81" cy="36" rx="10" ry="12"/><path d="M38 52h24q16 0 19 16l3 10q2 16-14 16H30q-16 0-14-16l3-10q3-16 19-16z"/></svg>`;
const TICK_SVG =
  `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 12.5l5 5L20 6.5" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`;

interface Meta { title: string; description: string; image?: string; url: string; status: number }

function page(meta: Meta, body: string, mount: string): Response {
  const og = `
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Pugmark">
  <meta property="og:title" content="${esc(meta.title)}">
  <meta property="og:description" content="${esc(meta.description)}">
  <meta property="og:url" content="${esc(meta.url)}">
  ${meta.image ? `<meta property="og:image" content="${esc(meta.image)}">
  <meta property="og:image:type" content="image/svg+xml">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="${esc(meta.title)}">` : ""}
  <meta name="twitter:card" content="${meta.image ? "summary_large_image" : "summary"}">
  <meta name="twitter:title" content="${esc(meta.title)}">
  <meta name="twitter:description" content="${esc(meta.description)}">
  ${meta.image ? `<meta name="twitter:image" content="${esc(meta.image)}">` : ""}`;
  const html = `<!doctype html>
<html lang="en-IN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${esc(meta.title)}</title>
  <meta name="description" content="${esc(meta.description)}">
  <meta name="color-scheme" content="light dark">${og}
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="${FONTS}">
  <style>${CSS}</style>
</head>
<body>
  <header class="nav"><div class="wrap">
    <a class="brand" href="https://pugmark.run" aria-label="Pugmark home">${PAW}Pugmark</a>
    <a class="btn" href="${esc(mount)}">Verify another</a>
  </div></header>
  <main><div class="wrap">${body}</div></main>
  <footer><div class="wrap"><span class="tag">Leave your pugmark.</span><span>© 2026 Pugmark</span></div></footer>
</body>
</html>`;
  return new Response(html, {
    status: meta.status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": meta.status >= 500 ? "no-store" : CACHE,
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "strict-origin-when-cross-origin",
      "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; base-uri 'none'; form-action 'self'",
    },
  });
}

function cardHtml(v: CardView): string {
  const tick = v.verdict === "verified"
    ? `<span class="tick" aria-label="Verified">✓</span>`
    : `<span class="tick tick--unverified">unverified</span>`;
  const label = `${v.name}, ${v.rarity}, serial ${v.serialNo}${v.issuedAt ? `, earned ${fmtDate(v.issuedAt)}` : ""}`;
  return `<article class="card card--${esc(v.rarity)}" style="--fam-bg:${esc(v.palette.bg)};--fam-fg:${esc(v.palette.fg)};--fam-accent:${esc(v.palette.accent)}" aria-label="${esc(label)}">
  <div class="card__cap"><span>${esc(v.season || "Pugmark")}</span><span class="card__rarity">${esc(cap(v.rarity))}</span></div>
  <div class="card__art" aria-hidden="true"><span class="card__glyph">${esc(v.name.charAt(0).toUpperCase())}</span></div>
  <div class="card__body">
    <h2 class="card__name">${esc(v.name)}</h2>
    <p class="card__flavour">${esc(v.flavour)}</p>
    <hr class="card__rule">
    <p class="card__stats">${esc(v.statsLine)}</p>
    <p class="card__serial"><span>${esc(v.name)}</span><span>#${pad4(v.serialNo)}</span>${tick}</p>
  </div>
</article>`;
}

function searchForm(q: string, mount: string): string {
  return `<form class="lookup" action="${esc(mount)}" method="get">
    <label for="q">Serial number</label>
    <input id="q" name="q" type="text" autocomplete="off" spellcheck="false" placeholder="Tiger #0427" value="${esc(q)}" required>
    <button class="btn btn--primary" type="submit">Verify</button>
  </form>`;
}

function storeButtons(): string {
  return `<div class="actions"><a class="btn btn--primary" href="https://pugmark.run/#store" data-store="ios">App Store</a><a class="btn" href="https://pugmark.run/#store" data-store="android">Google Play</a></div>`;
}

function foundPage(v: CardView, mount: string, origin: string): Response {
  const date = fmtDate(v.issuedAt);
  const title = `${v.name} #${pad4(v.serialNo)} · Pugmark`;
  const descBits = [`Earned by ${v.earnedBy}${date ? ` on ${date}` : ""}`];
  if (v.statsLine) descBits.push(v.statsLine.replace(" · ", " in ").replace(/ · .*$/, ""));
  const description = `${descBits.join(" · ")}. Real — it lives in the Pugmark ledger.`;
  const cardPath = `${mount}/${v.slug}/${v.serialNo}`;
  const seal = v.verdict === "verified"
    ? `<span class="seal">${TICK_SVG}Real ✓ · lives in the Pugmark ledger</span>`
    : `<span class="seal seal--warn">Real · lives in the ledger, drawn from the everyday bag</span>`;
  const body = `
    <p class="eyebrow">Verified card</p>
    <div class="layout">
      <div>${cardHtml(v)}</div>
      <div>
        ${seal}
        <h1 style="margin-top:18px">Earned by ${esc(v.earnedBy)}${date ? ` on ${esc(date)}` : ""}</h1>
        <p class="muted">This card is in the ledger. Serial numbers are issued once, by the database, and never reused. No route, location or health data is shown here — ever.</p>
        <ul class="facts">
          <li><span>Card</span><b>${esc(v.name)} #${pad4(v.serialNo)}</b></li>
          <li><span>Earned by</span><b>${esc(v.earnedBy)}</b></li>
          ${date ? `<li><span>On</span><b>${esc(date)}</b></li>` : ""}
          ${v.statsLine ? `<li><span>${esc(cap(v.scope))}</span><b>${esc(v.statsLine)}</b></li>` : ""}
          <li><span>Issued</span><b>#${pad4(v.serialNo)} of ${v.issuedSoFar} issued</b></li>
        </ul>
        <p class="muted" style="margin-top:24px;font-size:14px">Want your own? Every run earns a card.</p>
        ${storeButtons()}
      </div>
    </div>`;
  return page({ title, description, image: `${origin}${cardPath}/card.svg`, url: `${origin}${cardPath}`, status: 200 }, body, mount);
}

function notFoundPage(nf: NotFound, q: string, mount: string, origin: string): Response {
  const isFormat = nf.reason === "format" || nf.reason === "empty";
  const title = isFormat ? "That doesn’t look like a serial · Pugmark" : "No such card · Pugmark";
  const lead = isFormat ? "Serials look like an animal name and a number." : "If someone showed you this, they’re bluffing.";
  let extra = "";
  if (nf.reason === "serial" && nf.animal) {
    extra = nf.issuedSoFar > 0
      ? `<p class="muted">${esc(cap(nf.animal))} exists, but only ${nf.issuedSoFar} of them have been issued so far.</p>`
      : `<p class="muted">No ${esc(nf.animal)} card has been issued yet.</p>`;
  }
  const body = `
    <p class="eyebrow">Verify a card</p>
    <h1>Is this card real?</h1>
    ${searchForm(q, mount)}
    <div class="state">
      <span class="seal seal--off">Not in the ledger</span>
      <h2 style="margin-top:16px">${isFormat ? "That doesn’t look like a serial." : "No such card."}</h2>
      <p>${lead}</p>
      ${extra}
      ${nf.hint ? `<p class="muted">${esc(nf.hint)}</p>` : ""}
      ${q ? `<p class="muted" style="font-size:14px">You searched for <code>${esc(q)}</code></p>` : ""}
    </div>`;
  const description = `${isFormat ? "That doesn’t look like a serial." : "No such card."} ${lead}`;
  return page({ title, description, url: `${origin}${mount}`, status: 404 }, body, mount);
}

function idlePage(mount: string, origin: string): Response {
  const body = `
    <p class="eyebrow">Verify a card</p>
    <h1>Is this card real?</h1>
    ${searchForm("", mount)}
    <div class="state">
      <h2>Type a serial to begin.</h2>
      <p class="muted">You’ll see that single card — the animal, the number, who earned it and when. If it isn’t in the ledger, someone is bluffing.</p>
    </div>`;
  return page({ title: "Verify a card · Pugmark", description: "Type a Pugmark serial to see whether the card is real.", url: `${origin}${mount}`, status: 200 }, body, mount);
}

function errorPage(mount: string, origin: string): Response {
  const body = `
    <p class="eyebrow">Verify a card</p>
    <h1>The ledger is taking a moment.</h1>
    <div class="state"><p>We couldn’t reach it just now. Try again in a little while.</p></div>`;
  return page({ title: "Verify a card · Pugmark", description: "The ledger is taking a moment.", url: `${origin}${mount}`, status: 502 }, body, mount);
}

// ---------- 1200×630 SVG preview ----------
function cardSvg(v: CardView): Response {
  const p = v.palette;
  const date = fmtDate(v.issuedAt);
  const tickColor = v.verdict === "verified" ? "#2E7D5B" : "#B3791C";
  // Card: 300×420 scaled 1.25 → 375×525, left side; copy on the right.
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630" role="img" aria-label="${esc(`${v.name} #${pad4(v.serialNo)} · Pugmark`)}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${esc(p.bg)}"/><stop offset="1" stop-color="${esc(p.accent)}" stop-opacity=".55"/></linearGradient>
    <linearGradient id="bd" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${esc(p.accent)}"/><stop offset=".6" stop-color="#ffffff"/><stop offset="1" stop-color="${esc(p.accent)}"/></linearGradient>
    <clipPath id="cp"><rect x="0" y="0" width="300" height="420" rx="16"/></clipPath>
    <filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="18" stdDeviation="18" flood-color="#1B1B18" flood-opacity=".28"/></filter>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <rect width="1200" height="630" fill="${esc(p.bg)}" opacity=".35"/>
  <g transform="translate(96 52) scale(1.25)" filter="url(#sh)">
    <g clip-path="url(#cp)">
      <rect width="300" height="420" rx="16" fill="#FFFFFF"/>
      <rect x="12" y="38" width="276" height="210" rx="12" fill="${esc(p.bg)}"/>
      <circle cx="150" cy="143" r="78" fill="${esc(p.accent)}"/>
      <text x="150" y="176" text-anchor="middle" font-family="Fraunces, Georgia, serif" font-weight="600" font-size="92" fill="${esc(p.bg)}">${esc(v.name.charAt(0).toUpperCase())}</text>
      <text x="16" y="26" font-family="Manrope, system-ui, sans-serif" font-size="12" font-weight="500" letter-spacing=".5" fill="#6B6A63">${esc((v.season || "Pugmark").toUpperCase())}</text>
      <circle cx="${v.rarity.length > 6 ? 212 : 224}" cy="22" r="4" fill="${esc(p.accent)}"/>
      <text x="284" y="26" text-anchor="end" font-family="Manrope, system-ui, sans-serif" font-size="12" font-weight="500" letter-spacing=".5" fill="#6B6A63">${esc(v.rarity.toUpperCase())}</text>
      <text x="16" y="290" font-family="Fraunces, Georgia, serif" font-weight="600" font-size="28" fill="#1B1B18">${esc(v.name)}</text>
      <text x="16" y="314" font-family="Manrope, system-ui, sans-serif" font-style="italic" font-size="14" fill="#6B6A63">${esc(v.flavour.length > 40 ? v.flavour.slice(0, 38) + "…" : v.flavour)}</text>
      <line x1="16" y1="356" x2="284" y2="356" stroke="#E2DCD0"/>
      <text x="16" y="378" font-family="Manrope, system-ui, sans-serif" font-size="13" font-weight="500" fill="#1B1B18">${esc(v.statsLine)}</text>
      <text x="16" y="404" font-family="Fraunces, Georgia, serif" font-size="18" font-weight="500" letter-spacing="1.4" fill="#1B1B18">${esc(v.name.toUpperCase())}  #${pad4(v.serialNo)}</text>
      <text x="284" y="404" text-anchor="end" font-family="Manrope, system-ui, sans-serif" font-size="16" font-weight="700" fill="${tickColor}">${v.verdict === "verified" ? "✓" : "○"}</text>
    </g>
    <rect x="1.25" y="1.25" width="297.5" height="417.5" rx="15" fill="none" stroke="url(#bd)" stroke-width="2.5"/>
  </g>
  <g transform="translate(560 150)" font-family="Manrope, system-ui, sans-serif" fill="${esc(p.fg)}">
    <text y="0" font-size="20" font-weight="600" letter-spacing="2" opacity=".75">PUGMARK · VERIFIED CARD</text>
    <text y="84" font-family="Fraunces, Georgia, serif" font-size="68" font-weight="600" letter-spacing="1">${esc(v.name)} #${pad4(v.serialNo)}</text>
    <text y="140" font-size="28">Earned by ${esc(v.earnedBy)}${date ? ` on ${esc(date)}` : ""}</text>
    ${v.statsLine ? `<text y="184" font-size="26" opacity=".85">${esc(v.statsLine)}</text>` : ""}
    <text y="236" font-size="22" opacity=".8">#${pad4(v.serialNo)} of ${v.issuedSoFar} issued</text>
    <g transform="translate(0 284)">
      <rect x="0" y="-30" width="${v.verdict === "verified" ? 420 : 470}" height="52" rx="26" fill="none" stroke="${tickColor}" stroke-width="2.5"/>
      <text x="24" y="6" font-size="22" font-weight="700" fill="${tickColor}">${v.verdict === "verified" ? "Real ✓ · lives in the Pugmark ledger" : "Real · drawn from the everyday bag"}</text>
    </g>
  </g>
  <text x="1150" y="590" text-anchor="end" font-family="Fraunces, Georgia, serif" font-size="24" font-weight="600" fill="${esc(p.fg)}" opacity=".7">pugmark.run</text>
</svg>`;
  return new Response(svg, {
    status: 200,
    headers: { "Content-Type": "image/svg+xml; charset=utf-8", "Cache-Control": CACHE, "X-Content-Type-Options": "nosniff" },
  });
}

// ---------- routing ----------
Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method Not Allowed", { status: 405, headers: { Allow: "GET, HEAD" } });
  }
  const url = new URL(req.url);
  const i = url.pathname.indexOf("/verify");
  const mountPath = i >= 0 ? url.pathname.slice(0, i + "/verify".length) : "/verify";
  const rest = (i >= 0 ? url.pathname.slice(i + "/verify".length) : url.pathname).split("/").filter(Boolean).map(decodeURIComponent);
  const origin = PUBLIC_BASE_URL || url.origin;
  const mount = mountPath;

  let q = (url.searchParams.get("q") ?? "").trim().slice(0, 80);
  let wantSvg = false;
  if (rest.length >= 2) {
    const slug = rest[0].toLowerCase();
    const serial = rest[1];
    if (!/^[a-z0-9-]{1,60}$/.test(slug) || !/^\d{1,7}$/.test(serial)) {
      return notFoundPage({ found: false, reason: "format", hint: 'Try "Tiger #0427"', animal: "", issuedSoFar: 0 }, `${slug} ${serial}`, mount, origin);
    }
    q = `${slug.replace(/-/g, " ")} ${serial}`;
    wantSvg = rest[2] === "card.svg";
  }

  if (!q) return idlePage(mount, origin);

  let result: Lookup;
  try {
    result = await lookupSerial(q);
  } catch (err) {
    console.error("lookup_serial failed:", err instanceof Error ? err.message : String(err));
    if (wantSvg) return new Response("ledger unavailable", { status: 502, headers: { "Cache-Control": "no-store" } });
    return errorPage(mount, origin);
  }

  if (wantSvg) {
    if (!result.found) return new Response("no such card", { status: 404, headers: { "Content-Type": "text/plain", "Cache-Control": CACHE } });
    return cardSvg(result.view);
  }
  if (!result.found) return notFoundPage(result, q, mount, origin);
  return foundPage(result.view, mount, origin);
});
