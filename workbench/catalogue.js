/* Flying Cobra workbench — the living catalogue. Renders every token group and every component
   variant/state from design_system/tokens.json + catalogue.json so the system can be checked by eye. */
(function () {
  'use strict';
  const esc = FC.esc;
  let T = null, C = null;

  async function load() {
    if (T) return;
    const ds = window.DS_BASE || '../design_system';
    [T, C] = await Promise.all([fetch(ds + '/tokens.json').then(r => r.json()), fetch(ds + '/catalogue.json').then(r => r.json())]);
  }
  const sw = (hex, label) => `<div class="cat-sw"><i style="background:${esc(hex)}"></i><span>${esc(label)}</span><code>${esc(hex)}</code></div>`;
  const table = (obj) => { const keys = Object.keys(Object.values(obj)[0]).filter(k => typeof Object.values(obj)[0][k] !== 'object'); return `<table class="cat-table"><thead><tr><th></th>${keys.map(k => `<th>${esc(k)}</th>`).join('')}</tr></thead><tbody>${Object.entries(obj).map(([n, v]) => `<tr><td><b>${esc(n)}</b></td>${keys.map(k => `<td>${esc(String(v[k]))}</td>`).join('')}</tr>`).join('')}</tbody></table>`; };
  const sample = (name, family, rarity, extra = {}) => Object.assign({ animal: { name, slug: name.toLowerCase(), family, rarity, flavour: 'the one for the catalogue' }, serial: 42, tier: 'young', finish: 'plain', season: 'Monsoon 2026', statsLine: '5.0 km · 25:00 · 5:00/km', verdict: 'verified', issuedAt: '2026-10-02' }, extra);

  function tokens() {
    const out = [];
    out.push(`<section class="cat-sec"><h2>Colour · chrome</h2><div class="cat-row">${['light','dark'].map(m => `<div class="cat-mode" data-mode="${m}"><h4>${m}</h4><div class="cat-grid">${Object.entries(T.color[m]).map(([k, v]) => sw(v, k)).join('')}</div></div>`).join('')}</div></section>`);
    out.push(`<section class="cat-sec"><h2>Colour · families</h2><div class="cat-grid">${Object.entries(T.family).map(([k, f]) => `<div class="cat-fam" data-family="${k}"><div class="cat-fam__chip" style="background:${f.bg};color:${f.fg};border-color:${f.accent}"><b>${esc(f.label)}</b><span>${esc(f.mood)}</span></div>${sw(f.bg, 'bg')}${sw(f.fg, 'fg')}${sw(f.accent, 'accent')}</div>`).join('')}</div></section>`);
    out.push(`<section class="cat-sec"><h2>Rarity</h2><p class="cat-hint">A new rarity is a new row here, never a new component.</p>${table(T.rarity)}</section>`);
    out.push(`<section class="cat-sec"><h2>Tier (scale)</h2>${table(T.tier)}</section>`);
    out.push(`<section class="cat-sec"><h2>Finish (consistency)</h2>${table(T.finish)}</section>`);
    out.push(`<section class="cat-sec"><h2>Typography</h2>${Object.entries(T.typography.scale).map(([k, s]) => `<div class="cat-type"><code>${esc(k)}</code><span style="font-family:var(--font-${s.font});font-size:${s.size}px;line-height:${s.line}px;font-weight:${s.weight};${s.italic ? 'font-style:italic;' : ''}${s.tabular ? 'font-variant-numeric:tabular-nums;' : ''}${s.tracking ? `letter-spacing:${s.tracking}em;` : ''}">${s.tabular ? 'CHEETAH #0042' : 'Run. Collect. Keep.'}</span><small>${s.size}/${s.line} · ${s.weight}${s.use ? ' · ' + esc(s.use) : ''}</small></div>`).join('')}</section>`);
    out.push(`<section class="cat-sec"><h2>Spacing</h2><div class="cat-bars">${Object.entries(T.space).map(([k, v]) => `<div><i style="width:${v * 3}px"></i><code>${k}</code> ${v}px</div>`).join('')}</div></section>`);
    out.push(`<section class="cat-sec"><h2>Radius</h2><div class="cat-row">${Object.entries(T.radius).map(([k, v]) => `<div class="cat-radius" style="border-radius:${Math.min(v, 40)}px"><code>${k}</code><span>${v}px</span></div>`).join('')}</div></section>`);
    out.push(`<section class="cat-sec"><h2>Elevation</h2><div class="cat-row">${Object.entries(T.elevation).map(([k, v]) => `<div class="cat-elev" style="box-shadow:${esc(v)}"><code>${k}</code></div>`).join('')}</div></section>`);
    out.push(`<section class="cat-sec"><h2>Motion</h2><div class="cat-row">${Object.entries(T.motion.duration).map(([k, v]) => `<div class="cat-motion"><i style="animation-duration:${v}ms"></i><code>${k}</code><span>${v} ms</span></div>`).join('')}</div><p class="cat-hint">${esc(T.motion.reducedMotion)}</p>${table(Object.fromEntries(Object.entries(T.motion.easing).map(([k, v]) => [k, { curve: v }])))}</section>`);
    out.push(`<section class="cat-sec"><h2>Haptics</h2>${table(T.haptic)}</section>`);
    return out.join('');
  }

  function components() {
    const out = [];
    const rar = Object.keys(T.rarity), tiers = Object.keys(T.tier), fins = Object.keys(T.finish);
    out.push(`<section class="cat-sec"><h2>Animal card · rarity</h2><p class="cat-hint">Slots: art · serial · stats · flavour · set name. Same animal + tier + finish + season = identical template.</p><div class="cat-cards">${rar.map((r, i) => FC.card(sample(['Horse','Blackbuck','Peregrine Falcon','Cheetah','Bengal Tiger'][i], i === 4 ? 'weekly' : 'swift', r))).join('')}</div></section>`);
    out.push(`<section class="cat-sec"><h2>Animal card · tier</h2><div class="cat-cards">${tiers.map(t => FC.card(sample('Elephant', 'gentle', 'epic', { tier: t }))).join('')}</div></section>`);
    out.push(`<section class="cat-sec"><h2>Animal card · finish</h2><div class="cat-cards">${fins.map(f => FC.card(sample('Chital', 'steady', 'common', { finish: f }))).join('')}</div></section>`);
    out.push(`<section class="cat-sec"><h2>Animal card · verdict &amp; size</h2><div class="cat-cards">${FC.card(sample('Rabbit', 'calm', 'common', { verdict: 'unverified' }))}<div style="width:150px">${FC.card(sample('Rabbit', 'calm', 'common'), { tile: true })}</div></div></section>`);
    out.push(`<section class="cat-sec"><h2>Buttons</h2><div class="cat-row cat-row--app">${['', '--ghost', '--quiet', '--danger'].map(k => `<button class="btn btn${k}" style="width:auto">${k ? k.slice(2) : 'primary'}</button>`).join('')}<button class="btn" style="width:auto" disabled>disabled</button></div></section>`);
    out.push(`<section class="cat-sec"><h2>Chips</h2><div class="cat-row cat-row--app"><span class="chip">off</span><span class="chip is-on">on</span></div></section>`);
    out.push(`<section class="cat-sec"><h2>Toast &amp; banner</h2><div class="cat-row cat-row--app"><div class="toast" style="animation:none;position:static;max-width:300px"><b>Saved.</b><span>We'll fetch your card when you're back online.</span></div><div class="banner" style="max-width:300px"><em>🌱</em><div><b>Your chital is growing!</b><div class="tiny muted">Three weeks of showing up.</div></div></div></div><p class="cat-hint">One at a time. Never during the reveal.</p></section>`);
    out.push(`<section class="cat-sec"><h2>List row · search · stat · ring</h2><div class="cat-row cat-row--app" style="align-items:stretch"><div style="width:280px" data-family="calm"><div class="row"><div class="row__avatar">R</div><div class="row__main"><b>Rabbit</b><span>soft paws, big heart</span></div><div class="row__end">×3</div></div></div><div style="width:280px"><div class="search"><input class="input" placeholder="Tiger #0427"><button class="btn">Verify</button></div></div><div class="stats" style="width:280px"><div class="stat"><b>12</b><span>runs</span></div><div class="stat"><b>58</b><span>km</span></div><div class="stat"><b>9</b><span>cards</span></div></div><div class="ring" style="--p:43"><b>43%</b></div></div></section>`);
    out.push(`<section class="cat-sec"><h2>Navigation bar</h2><div style="width:390px"><nav class="tabbar" style="position:static">${[['☀','Today',true],['▦','Collection'],['📖','Encyclopedia'],['◯','You']].map(([i, l, on]) => `<button class="tab${on ? ' is-on' : ''}"><em>${i}</em>${l}</button>`).join('')}</nav></div></section>`);
    out.push(`<section class="cat-sec"><h2>Poster</h2><p class="cat-hint">No map. No start point. Serial + QR only.</p><div style="width:200px">${FC.poster(sample('Cheetah', 'swift', 'epic'))}</div></section>`);
    out.push(`<section class="cat-sec"><h2>Patterns</h2><p class="cat-hint">Card reveal, growth celebration, permission flow and the poster are sequences in <code>design_system/components.js</code>, tuned from the right panel on their pages. Use the Pages list on the left to see them live.</p></section>`);
    return out.join('');
  }

  async function render(host, mode) {
    await load();
    host.hidden = false;
    host.setAttribute('data-mode', mode);
    host.innerHTML = `<style>
      .catalogue h2{font-size:18px;margin:0 0 8px}.cat-sec{padding:18px 0;border-top:1px solid var(--color-line)}.cat-sec:first-child{border-top:0;padding-top:0}
      .cat-hint{color:var(--color-ink-muted);font-size:12.5px;margin:0 0 10px}.cat-row{display:flex;flex-wrap:wrap;gap:14px;align-items:flex-start}.cat-row--app{align-items:center}
      .cat-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px}.cat-sw{display:grid;grid-template-columns:28px 1fr;gap:2px 8px;align-items:center;font-size:12px}
      .cat-sw i{width:28px;height:28px;border-radius:7px;border:1px solid var(--color-line);grid-row:span 2}.cat-sw code{font-size:10.5px;color:var(--color-ink-muted)}
      .cat-mode{flex:1;min-width:280px;background:var(--color-bg);color:var(--color-ink);padding:12px;border-radius:12px;border:1px solid var(--color-line)}.cat-mode h4{margin:0 0 8px;font-family:var(--font-display)}
      .cat-fam{display:grid;gap:4px}.cat-fam__chip{border-radius:10px;padding:10px;border-left:4px solid}.cat-fam__chip b{display:block;font-family:var(--font-display)}.cat-fam__chip span{font-size:11px;opacity:.8}
      .cat-table{border-collapse:collapse;font-size:12.5px;width:100%}.cat-table th,.cat-table td{text-align:left;padding:6px 8px;border-bottom:1px solid var(--color-line)}.cat-table th{font-size:10.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--color-ink-muted)}
      .cat-type{display:grid;grid-template-columns:150px 1fr auto;gap:12px;align-items:baseline;padding:8px 0;border-bottom:1px dashed var(--color-line)}.cat-type code,.cat-type small{font-size:11px;color:var(--color-ink-muted)}
      .cat-bars div{display:flex;align-items:center;gap:10px;font-size:12px;margin:4px 0}.cat-bars i{display:block;height:14px;background:var(--color-accent);border-radius:3px}
      .cat-radius,.cat-elev{width:110px;height:72px;background:var(--color-surface);border:1px solid var(--color-line);display:grid;place-content:center;gap:2px;font-size:12px;text-align:center}.cat-elev{border-radius:12px;border:0}
      .cat-motion{display:grid;justify-items:center;gap:4px;font-size:12px;width:96px}.cat-motion i{display:block;width:22px;height:22px;border-radius:50%;background:var(--color-accent);animation:cat-bounce 1s ease-in-out infinite alternate}@keyframes cat-bounce{to{transform:translateX(50px)}}
      .cat-cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:16px}.cat-cards .card-slot{width:100%}
    </style><h1 style="font-size:26px;margin:0 0 4px">Living catalogue</h1><p class="cat-hint">Flying Cobra Design System v${esc(T.version)} · every token and component, every variant and state. Source: <code>design_system/tokens.json</code>.</p>
    <div class="cat-tabs" style="display:flex;gap:6px;margin-bottom:14px"><button class="chip is-on" data-cat="tokens">Tokens</button><button class="chip" data-cat="components">Components</button></div>
    <div id="cat-body">${tokens()}</div>`;
    host.querySelectorAll('[data-cat]').forEach(b => b.addEventListener('click', () => { host.querySelectorAll('[data-cat]').forEach(x => x.classList.toggle('is-on', x === b)); host.querySelector('#cat-body').innerHTML = b.dataset.cat === 'tokens' ? tokens() : components(); }));
  }

  window.Catalogue = { render };
})();
