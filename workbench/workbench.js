/* Flying Cobra workbench — the three-column shell.
   Left: pages grouped by journey. Centre: phone frame running SCREENS. Right: the selected page's
   properties from interaction-config.json (animations, toasts, triggers, state), a Fire button per
   trigger, the simulate-run control, and export. Changes apply instantly and persist in localStorage;
   Download writes interaction-config.json. */
(function () {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const esc = FC.esc;

  const JOURNEYS = [
    ['Onboarding', ['welcome','sign-in','perm-location','perm-motion','perm-activity','perm-health','perm-notifications','fairness','onboarding-done']],
    ['Home', ['today']],
    ['Run', ['run-ready','run-recording','run-finish']],
    ['Cards', ['reveal','card-detail','poster']],
    ['Collection', ['collection']],
    ['Search & Verify', ['serial-search','verify-web']],
    ['Encyclopedia', ['encyclopedia','animal-entry']],
    ['Settings', ['settings','permission-receipt','data-and-account']],
    ['Celebrations', ['celebration-growth','celebration-mastered','celebration-welcome-back','celebration-discovery']],
    ['System', ['setup-needed']],
    ['Design system', ['catalogue']]
  ];
  const TITLES = { welcome: 'Welcome', 'sign-in': 'Sign in', 'perm-location': 'Permission · Location', 'perm-motion': 'Permission · Motion', 'perm-activity': 'Permission · Activity', 'perm-health': 'Permission · Health', 'perm-notifications': 'Permission · Notifications', fairness: 'Fairness (age & sex)', 'onboarding-done': 'Onboarding done', today: 'Today', 'run-ready': 'Run · ready', 'run-recording': 'Run · recording', 'run-finish': 'Run · finish', reveal: 'Card reveal', 'card-detail': 'Card detail', poster: 'Share poster', collection: 'Collection', 'serial-search': 'Serial search', 'verify-web': 'Public verify page (web)', encyclopedia: 'Encyclopedia', 'animal-entry': 'Animal entry', settings: 'You (settings)', 'permission-receipt': 'Permission receipt', 'data-and-account': 'Data & account', 'celebration-growth': 'Celebration · growth', 'celebration-mastered': 'Celebration · mastered', 'celebration-welcome-back': 'Celebration · welcome back', 'celebration-discovery': 'Celebration · discovery', 'setup-needed': 'Setup needed', catalogue: 'Living catalogue' };
  const STATES = { 'sign-in': ['sent','error'], 'perm-location': ['denied'], today: ['loading','error'], 'run-recording': ['gps-searching','auto-paused','paused','offline'], 'run-finish': ['confirm'], collection: ['loading'], 'serial-search': ['loading','found','not-found'], 'data-and-account': ['confirm'] };
  const TRIGGERS = ['first-launch','sign-in-complete','permission-granted','permission-denied','run-started','run-auto-paused','gps-lost','gps-regained','run-ended','run-floor-not-met','run-rejected','run-unverified','run-capped','card-issued','rare-card-issued','animal-grew','animal-mastered','welcome-back','discovery-time','discovery-explorer','discovery-souvenir','discovery-migratory','weekly-card-ready','monthly-card-ready','no-weekly-card','serial-found','serial-not-found','link-copied','card-visibility-toggled','poster-exported','offline-saved','back-online','permission-toggled','data-exported','account-deleted'];
  const EASINGS = ['standard','decelerate','accelerate','emphasised','spring'];

  // ---------- state ----------
  const W = {
    cfg: null, defaults: null, page: 'today', state: 'success', user: null, personaId: 'arjun',
    sim: { paceSec: 300, km: 5, hour: 7, state: 'IN-KA', flags: [] }, live: { movingS: 0, km: 0, gain: 0 }, ticker: null,
    opts: { reduced: false, nogps: false, offline: false },
    pending: null, banners: [], focusCard: null, focusAnimal: null, filter: 'all', query: '', found: null, foundBy: '', encQuery: '',
    device: 'iphone', mode: 'light'
  };
  const toast = FC.toaster($('toasts'));

  // ---------- config persistence ----------
  async function loadConfig() {
    const res = await fetch((window.WB_BASE || '') + 'interaction-config.json'); W.defaults = await res.json();
    let saved = null; try { saved = JSON.parse(localStorage.getItem('fc-interaction-config') || 'null'); } catch (e) { /* ignore */ }
    // Saved values layer over the shipped defaults, so new screens or keys added to the JSON still appear.
    W.cfg = saved && saved.version === W.defaults.version ? deepMerge(structuredClone(W.defaults), saved) : structuredClone(W.defaults);
  }
  function deepMerge(base, over) {
    for (const k of Object.keys(over || {})) {
      if (over[k] && typeof over[k] === 'object' && !Array.isArray(over[k]) && base[k] && typeof base[k] === 'object') deepMerge(base[k], over[k]);
      else base[k] = over[k];
    }
    return base;
  }
  function saveConfig() { try { localStorage.setItem('fc-interaction-config', JSON.stringify(W.cfg)); } catch (e) { /* storage may be blocked; the Download button still works */ } $('dirty').textContent = JSON.stringify(W.cfg) === JSON.stringify(W.defaults) ? '' : '· unsaved changes live in this browser · Download to keep'; }
  function pageCfg(id) { return (W.cfg.screens[id] ||= { animations: {}, toasts: {} }); }
  const ms = (page, anim, fallback) => { const a = pageCfg(page).animations[anim]; return a && a.enabled !== false ? a.ms : (a ? 0 : fallback); };

  // ---------- persona ----------
  function setPersona(id) {
    W.personaId = id; W.user = structuredClone(DATA.personas.find(p => p.id === id)); W.user.cards.forEach(c => c.animal = DATA.byName[c.animal.name]);
    W.pending = id === 'ravi' ? { scope: 'weekly', card: W.user.cards.find(c => c.scope === 'weekly') } : null;
    if (W.pending) W.user.cards = W.user.cards.filter(c => c.scope !== 'weekly');
    W.banners = []; W.focusCard = W.user.cards[W.user.cards.length - 1] || null;
    const lastRun = W.user.runs[W.user.runs.length - 1];
    W.sim = lastRun ? { paceSec: lastRun.paceSec, km: lastRun.km, hour: lastRun.hour, state: lastRun.state || W.user.state || 'IN-KA', flags: [] } : { paceSec: 330, km: 3, hour: 7, state: 'IN-KA', flags: [] };
    W.page = W.user.fresh ? 'welcome' : 'today'; W.state = 'success';
    renderAll();
  }

  // ---------- rendering ----------
  function renderPages() {
    $('pages').innerHTML = JOURNEYS.map(([j, ids]) => `<div class="pages__group"><h3>${esc(j)}</h3>${ids.map(id => `<button class="page${W.page === id ? ' is-on' : ''}" data-page="${id}">${esc(TITLES[id] || id)}</button>`).join('')}</div>`).join('');
  }
  function renderPhone() {
    const vp = $('viewport'); vp.setAttribute('data-mode', W.mode); vp.setAttribute('data-reduced', String(W.opts.reduced));
    $('phone').setAttribute('data-device', W.device);
    if (W.page === 'catalogue') { $('stage').classList.add('is-catalogue'); Catalogue.render($('catalogue'), W.mode); return; }
    $('stage').classList.remove('is-catalogue');
    const fn = SCREENS[W.page] || SCREENS.today;
    $('screen').innerHTML = fn({ state: W.state }, W);
    $('screen').scrollTop = 0;
    $('screen-name').textContent = (TITLES[W.page] || W.page) + (W.state !== 'success' ? ` · ${W.state}` : '');
    $('clock').textContent = `${Math.floor(W.sim.hour)}:${String(Math.round((W.sim.hour % 1) * 60)).padStart(2, '0')}`;
  }
  function renderProps() {
    const id = W.page, pc = pageCfg(id), panel = $('props');
    if (id === 'catalogue') { panel.innerHTML = `<h2>Living catalogue</h2><p class="hint">Every token and component, every variant and state, light and dark. Edit <code>design_system/tokens.json</code> and run the build to change anything here.</p>`; return; }
    const anims = Object.entries(pc.animations), toasts = Object.entries(pc.toasts);
    const field = (label, inner) => `<label class="field"><span>${esc(label)}</span>${inner}</label>`;
    const num = (path, v, min = 0, max = 6000, step = 10) => `<input type="number" data-cfg="${path}" value="${v}" min="${min}" max="${max}" step="${step}">`;
    const sel = (path, v, opts) => `<select data-cfg="${path}">${opts.map(o => `<option${o === v ? ' selected' : ''}>${esc(o)}</option>`).join('')}</select>`;
    const chk = (path, v) => `<input type="checkbox" data-cfg="${path}"${v !== false ? ' checked' : ''}>`;
    panel.innerHTML = `
      <h2>${esc(TITLES[id] || id)}</h2><p class="hint">Changes apply to the phone instantly and are kept in this browser. <button class="link" id="dl">Download interaction-config.json</button> <span id="dirty" class="hint"></span></p>
      ${STATES[id] ? `<section class="prop"><h3>State</h3><div class="chips">${['success', ...STATES[id]].map(s => `<button class="chip${W.state === s ? ' is-on' : ''}" data-state="${s}">${s}</button>`).join('')}</div></section>` : ''}
      <section class="prop"><h3>Animations <span>${anims.length}</span></h3>${anims.length ? anims.map(([k, a]) => `<div class="item"><div class="item__head"><b>${esc(k)}</b>${chk(`screens.${id}.animations.${k}.enabled`, a.enabled)}</div>
        <div class="item__grid">${field('ms', num(`screens.${id}.animations.${k}.ms`, a.ms))}${field('delay', num(`screens.${id}.animations.${k}.delay`, a.delay || 0))}${field('easing', sel(`screens.${id}.animations.${k}.easing`, a.easing, EASINGS))}</div>
        <div class="item__trig">${field('trigger', sel(`screens.${id}.animations.${k}.trigger`, a.trigger, TRIGGERS))}<button class="fire" data-fire="${esc(a.trigger)}">Fire</button></div></div>`).join('') : '<p class="hint">No named animations on this page.</p>'}</section>
      <section class="prop"><h3>Toasts &amp; banners <span>${toasts.length}</span></h3>${toasts.length ? toasts.map(([k, t]) => `<div class="item"><div class="item__head"><b>${esc(k)}</b></div>
        ${field('text', `<textarea data-cfg="screens.${id}.toasts.${k}.text" rows="2">${esc(t.text)}</textarea>`)}
        <div class="item__grid">${field('ms (0 = sticky)', num(`screens.${id}.toasts.${k}.ms`, t.ms, 0, 10000, 100))}${field('position', sel(`screens.${id}.toasts.${k}.pos`, t.pos, ['top','bottom']))}${field('dismiss', sel(`screens.${id}.toasts.${k}.dismiss`, t.dismiss, ['auto','tap','both']))}</div>
        <div class="item__trig">${field('trigger', sel(`screens.${id}.toasts.${k}.trigger`, t.trigger, TRIGGERS))}<button class="fire" data-fire="${esc(t.trigger)}">Fire</button></div></div>`).join('') : '<p class="hint">No toasts on this page.</p>'}</section>
      ${id === 'reveal' ? `<section class="prop"><h3>Reveal sequence</h3><p class="hint">Timeline: shimmer → slide → pause → flip → particles (rare+) → captions every <b>${pc.captionGapMs}</b> ms.</p>${field('caption gap ms', num(`screens.reveal.captionGapMs`, pc.captionGapMs, 500, 6000, 100))}<button class="btn-sm" data-fire="card-issued">Preview a reveal</button></section>` : ''}
      ${id.startsWith('celebration') ? `<section class="prop"><h3>Overlay</h3>${field('auto-dismiss ms', num(`screens.${id}.autoDismissMs`, pc.autoDismissMs || 2600, 0, 8000, 100))}${field('haptic', sel(`screens.${id}.haptic`, pc.haptic || 'light', ['light','medium','heavy','success']))}</section>` : ''}
      <section class="prop"><h3>Simulate a run</h3><p class="hint">Runs the real selection logic (age-graded pace → family, distance → scale, run-days → finish) for <b>${esc(W.user.name)}</b>, then plays the reveal.</p>
        <div class="item__grid">${field('pace /km', `<input type="range" id="sim-pace" min="210" max="600" step="5" value="${W.sim.paceSec}"><output>${FC.fmtPace(W.sim.paceSec)}</output>`)}${field('distance km', `<input type="range" id="sim-km" min="0.5" max="15" step="0.5" value="${W.sim.km}"><output>${W.sim.km}</output>`)}${field('start hour (IST)', `<input type="range" id="sim-hour" min="0" max="23.5" step="0.5" value="${W.sim.hour}"><output>${Engine.timeWindow(W.sim.hour)}</output>`)}</div>
        <div class="item__grid">${field('location', `<select id="sim-state">${DATA.states.map(([c, n]) => `<option value="${c}"${c === W.sim.state ? ' selected' : ''}>${esc(n)}</option>`).join('')}</select>`)}${field('flags', `<select id="sim-flags" multiple size="3">${['new_state','explorer','migratory_2','migratory_3'].map(f => `<option${W.sim.flags.includes(f) ? ' selected' : ''}>${f}</option>`).join('')}</select>`)}</div>
        <div class="btn-row"><button class="btn-sm" id="sim-run">Run it → reveal</button><button class="btn-sm ghost" id="sim-pool">Show the bag</button></div><div id="sim-out" class="hint"></div></section>
      <section class="prop"><h3>Global</h3>${field('default toast ms', num('global.toastDefaultMs', W.cfg.global.toastDefaultMs, 800, 8000, 100))}${field('reduced-motion crossfade ms', num('global.reducedMotionCrossfadeMs', W.cfg.global.reducedMotionCrossfadeMs, 1, 1000, 10))}
        <p class="hint"><button class="link" id="reset-cfg">Reset all to shipped defaults</button></p></section>`;
    $('dirty') && saveConfig();
  }
  function renderAll() { renderPages(); renderPhone(); renderProps(); }

  // ---------- navigation & actions ----------
  function go(page, state = 'success') { W.page = page; W.state = state; renderAll(); }
  function openCard(c) { W.focusCard = c; go('card-detail'); }

  function fire(trigger) {
    const id = W.page, pc = pageCfg(id);
    for (const [k, t] of Object.entries(pc.toasts)) if (t.trigger === trigger) toast.show({ text: t.text, ms: t.ms || 0, pos: t.pos, dismiss: t.ms ? t.dismiss : 'tap' });
    switch (trigger) {
      case 'gps-lost': if (id === 'run-recording') { W.state = 'gps-searching'; renderPhone(); } break;
      case 'gps-regained': if (id === 'run-recording') { W.state = 'success'; renderPhone(); } break;
      case 'run-auto-paused': if (id === 'run-recording') { W.state = 'auto-paused'; renderPhone(); } break;
      case 'card-issued': case 'rare-card-issued': playReveal(simulate({ forceRare: trigger === 'rare-card-issued' })); break;
      case 'animal-grew': celebrate('celebration-growth', { kind: 'growth', title: `Your ${(W.focusCard?.animal.name || 'cheetah').toLowerCase()} is all grown up!`, message: 'Six weeks of showing up.', family: W.focusCard?.animal.family, card: W.focusCard && Object.assign({}, W.focusCard, { tier: 'adult' }) }); break;
      case 'animal-mastered': celebrate('celebration-mastered', { kind: 'mastered', title: 'The wild opens up.', message: `You and the ${(W.focusCard?.animal.name || 'cheetah').toLowerCase()} know each other now. Rarer animals start to appear.`, family: W.focusCard?.animal.family }); break;
      case 'welcome-back': celebrate('celebration-welcome-back', { kind: 'welcome-back', title: 'Welcome back.', message: 'Your animals start small again — and so does the adventure.', family: 'gentle' }); break;
      case 'discovery-time': case 'discovery-explorer': case 'discovery-souvenir': case 'discovery-migratory': {
        const cap = { 'discovery-time': 'You found this one because you ran at night.', 'discovery-explorer': 'You found this one because you went somewhere new.', 'discovery-souvenir': 'A souvenir from where you ran.', 'discovery-migratory': 'You found this one by running across India.' }[trigger];
        celebrate('celebration-discovery', { kind: 'discovery', title: 'A discovery', message: cap, family: 'time', card: W.focusCard }); break; }
      case 'weekly-card-ready': W.pending = { scope: 'weekly', card: DATA.mkCard('Bengal Tiger', 9, 'adult', 'radiant', 'weekly', DATA.today, '7 days · 35 km') }; go('today'); break;
      case 'monthly-card-ready': W.pending = { scope: 'monthly', card: DATA.mkCard('Great Hornbill', 45, 'young', 'glow', 'monthly', DATA.today, 'October · Kerala') }; go('today'); break;
      case 'serial-found': W.query = 'Cheetah #0042'; W.found = DATA.mkCard('Cheetah', 42, 'young', 'plain', 'run', DATA.dAgo(1), '5.0 km · 19:35 · 3:55/km'); W.foundBy = 'Arjun'; go(id === 'verify-web' ? 'verify-web' : 'serial-search', 'found'); break;
      case 'serial-not-found': W.found = null; go(id === 'verify-web' ? 'verify-web' : 'serial-search', 'not-found'); break;
      case 'first-launch': go('welcome'); break;
      case 'sign-in-complete': go('sign-in', 'sent'); break;
      case 'permission-denied': if (id.startsWith('perm-')) { W.state = 'denied'; renderPhone(); } break;
      case 'run-floor-not-met': case 'run-capped': case 'run-rejected': case 'run-unverified': if (id !== 'run-finish') go('today'); break;
      case 'account-deleted': setPersona('new'); break;
      default: break;
    }
  }

  function simulate(extra = {}) {
    const rng = Math.random;
    let r = Engine.simulate({ paceSec: W.sim.paceSec, km: W.sim.km, hour: W.sim.hour, stateCode: W.sim.state, flags: W.sim.flags, date: DATA.today, cadenceOk: !W.opts.nogps }, W.user, Object.assign(DATA.animals.filter(a => !a.secret), { counters: {} }), rng);
    if (extra.forceRare && r.card) { const rare = r.pool.filter(e => ['rare','epic','legendary'].includes(e.animal.rarity)); if (rare.length) r.card.animal = rare[Math.floor(rng() * rare.length)].animal; }
    return r;
  }

  function playReveal(result) {
    if (!result.card) { toast.show({ text: result.message, ms: 3600, pos: 'bottom', dismiss: 'tap' }); go('today'); return; }
    const pc = pageCfg('reveal'), red = W.opts.reduced;
    W.page = 'reveal'; renderPages(); $('screen-name').textContent = 'Card reveal';
    FC.reveal($('screen'), result.card, { shimmerMs: ms('reveal', 'shimmer', 900), slideMs: ms('reveal', 'card-slide', 420), pauseMs: ms('reveal', 'pause-before-flip', 300), flipMs: ms('reveal', 'card-flip', 600), particles: ms('reveal', 'particle-burst', 900) ? 24 : 0, reduced: red }, (ov) => {
      const caps = result.celebrations.map(c => c.kind === 'growth' ? c.message : c.kind === 'discovery' ? ({ 1: `You found this one because you ran at ${result.timeWindow}.`, 2: 'You found this one because you went somewhere new.', 3: 'A souvenir from where you ran.', 4: 'You found this one by running across India.' })[c.tier] : '').filter(Boolean);
      if (result.message) caps.unshift(result.message);
      const capEl = ov.querySelector('#reveal-caption'); let i = 0;
      const next = () => { if (i < caps.length) { capEl.innerHTML = `<span class="fade-in">${esc(caps[i++])}</span>`; setTimeout(next, pc.captionGapMs || 2600); } };
      next();
      ov.addEventListener('click', () => { W.user.cards.push(result.card); W.user.runDaysLast7++; W.user.runs.push({ date: DATA.today, km: W.sim.km, paceSec: W.sim.paceSec, hour: W.sim.hour, movingS: Math.round(W.sim.km * W.sim.paceSec), eligible: true, verdict: result.verdict }); openCard(result.card); }, { once: true });
    });
  }
  function celebrate(screen, opts) {
    const pc = pageCfg(screen); W.page = screen; renderPages(); $('screen-name').textContent = TITLES[screen];
    if (!$('screen').innerHTML || W.page.startsWith('celebration')) $('screen').innerHTML = SCREENS.today({ state: 'success' }, W);
    FC.celebration($('screen'), Object.assign({ ms: pc.autoDismissMs || 2600 }, opts), () => go('today'));
  }

  // run ticker (simulated sensors)
  function startRun() {
    W.live = { movingS: 0, km: 0, gain: 0 }; go('run-recording'); clearInterval(W.ticker);
    W.ticker = setInterval(() => {
      if (W.state === 'paused' || W.state === 'auto-paused') return;
      W.live.movingS += 1; if (!W.opts.nogps && W.state !== 'gps-searching') { W.live.km = Math.min(W.sim.km, W.live.movingS / W.sim.paceSec); W.live.gain = Math.round(W.live.km * 6); }
      if (W.page === 'run-recording') { const b = $('screen').querySelector('.bignum'); if (b) { b.firstChild.textContent = FC.fmtDur(W.live.movingS); const m = $('screen').querySelectorAll('.metric b'); if (m[0]) { m[0].textContent = W.live.km.toFixed(2); m[1].textContent = W.live.km > 0.05 ? FC.fmtPace(W.live.movingS / W.live.km) : '–:––'; m[2].textContent = W.live.gain; } } }
    }, 1000 / 8); // 8× speed so a 5 km run takes seconds
  }
  function finishRun() {
    clearInterval(W.ticker);
    const kmDone = W.opts.nogps ? 0 : Math.max(W.live.km, 0.01);
    if (!Engine.floorOk(kmDone, W.live.movingS, kmDone > 0 ? kmDone / (W.live.movingS / 3600) : 0) && kmDone < 1) { go('run-finish', 'confirm'); return; }
    submitRun();
  }
  function submitRun() {
    const kmDone = W.opts.nogps ? 0 : Math.max(W.live.km, 0.01);
    go('run-finish', 'reading');
    if (W.opts.offline) { setTimeout(() => { toast.show({ text: pageCfg('today').toasts['offline-saved']?.text || 'Saved. We\'ll fetch your card when you\'re back online.', ms: 3200, pos: 'bottom' }); go('today'); }, 600); return; }
    const saveKm = W.sim.km; W.sim.km = +kmDone.toFixed(2) || 0.5;
    const r = simulate(); W.sim.km = saveKm;
    setTimeout(() => playReveal(r), ms('run-finish', 'reading-shimmer', 900));
  }

  // ---------- event wiring ----------
  $('pages').addEventListener('click', e => { const b = e.target.closest('[data-page]'); if (b) go(b.dataset.page); });
  $('screen').addEventListener('click', e => {
    const el = e.target.closest('[data-act]'); if (!el || el.tagName === 'FORM' || el.tagName === 'INPUT') return;
    const [verb, ...rest] = el.dataset.act.split(':'); const arg = rest.join(':');
    switch (verb) {
      case 'go': go(arg); break;
      case 'state': W.state = arg; renderPhone(); break;
      case 'perm': { const [choice, key, next] = rest; if (choice === 'allow' && !W.user.permissions.includes(key)) W.user.permissions.push(key); if (choice === 'deny') { W.state = 'denied'; renderPhone(); setTimeout(() => go(next), 900); } else go(next); break; }
      case 'finish-onboarding': go('today'); break;
      case 'start-run': startRun(); break;
      case 'pause-run': W.state = 'paused'; renderPhone(); break;
      case 'resume-run': W.state = 'success'; renderPhone(); break;
      case 'finish-run': finishRun(); break;
      case 'submit-run': submitRun(); break;
      case 'open-card': openCard(W.user.cards[+arg]); break;
      case 'open-card-name': openCard(W.user.cards.filter(c => c.animal.name === arg).reduce((a, b) => a.serial < b.serial ? a : b)); break;
      case 'open-pending': { const p = W.pending; W.pending = null; W.user.cards.push(p.card); playReveal({ card: p.card, celebrations: [], verdict: 'verified', timeWindow: 'day' }); break; }
      case 'dismiss-banner': W.banners.splice(+arg, 1); renderPhone(); break;
      case 'filter': W.filter = arg; renderPhone(); break;
      case 'entry': W.focusAnimal = DATA.byName[arg]; go('animal-entry'); break;
      case 'toggle-perm': { const i = W.user.permissions.indexOf(arg); if (i >= 0) { W.user.permissions.splice(i, 1); fire('permission-toggled'); } else W.user.permissions.push(arg); renderPhone(); break; }
      case 'toggle-public': W.focusCard.isPublic = W.focusCard.isPublic === false; renderPhone(); if (W.focusCard.isPublic === false) fire('card-visibility-toggled'); break;
      case 'fire': fire(arg); break;
      case 'toast': { const [pg, k] = rest; const t = pageCfg(pg).toasts[k]; if (t) toast.show({ text: t.text, ms: t.ms, pos: t.pos, dismiss: t.dismiss }); break; }
      case 'delete-account': toast.show({ text: pageCfg('data-and-account').toasts.deleted.text, ms: 4000, pos: 'bottom', dismiss: 'tap' }); setTimeout(() => setPersona('new'), 1200); break;
      default: break;
    }
  });
  $('screen').addEventListener('submit', e => { const f = e.target.closest('[data-act="search"]'); if (!f) return; e.preventDefault(); W.query = f.querySelector('#q').value; W.state = 'loading'; renderPhone();
    setTimeout(() => { const m = W.query.toLowerCase().match(/^\s*([a-z][a-z \-']*?)\s*#?\s*0*(\d{1,7})\s*$/); const a = m && DATA.animals.find(x => x.name.toLowerCase() === m[1].trim()); const n = m && +m[2];
      if (a && n && n <= a.issued) { W.found = DATA.mkCard(a.name, n, 'young', 'plain', 'run', DATA.dAgo(2 + (n % 20)), '5.0 km · 27:40 · 5:32/km'); W.foundBy = ['Arjun','Meera','Ravi','Priya','Kabir','Sana'][n % 6]; W.state = 'found'; } else { W.found = null; W.state = 'not-found'; } renderPhone(); }, 500); });
  $('screen').addEventListener('input', e => { if (e.target.dataset.act === 'enc-search') { W.encQuery = e.target.value; const pos = e.target.selectionStart; renderPhone(); const i = $('screen').querySelector('[data-act="enc-search"]'); i.focus(); i.setSelectionRange(pos, pos); } });

  $('props').addEventListener('input', e => {
    const path = e.target.dataset.cfg; if (path) { const keys = path.split('.'); let o = W.cfg; for (const k of keys.slice(0, -1)) o = o[k] ||= {}; const last = keys[keys.length - 1];
      o[last] = e.target.type === 'checkbox' ? e.target.checked : e.target.type === 'number' ? +e.target.value : e.target.value; saveConfig(); return; }
    if (e.target.id === 'sim-pace') { W.sim.paceSec = +e.target.value; e.target.nextElementSibling.textContent = FC.fmtPace(W.sim.paceSec); }
    if (e.target.id === 'sim-km') { W.sim.km = +e.target.value; e.target.nextElementSibling.textContent = W.sim.km; }
    if (e.target.id === 'sim-hour') { W.sim.hour = +e.target.value; e.target.nextElementSibling.textContent = Engine.timeWindow(W.sim.hour); $('clock').textContent = `${Math.floor(W.sim.hour)}:${String(Math.round((W.sim.hour % 1) * 60)).padStart(2, '0')}`; }
    if (e.target.id === 'sim-state') W.sim.state = e.target.value;
    if (e.target.id === 'sim-flags') W.sim.flags = [...e.target.selectedOptions].map(o => o.value);
  });
  $('props').addEventListener('click', e => {
    if (e.target.dataset.fire) fire(e.target.dataset.fire);
    if (e.target.dataset.state) { W.state = e.target.dataset.state; renderPhone(); renderProps(); }
    if (e.target.id === 'sim-run') { W.live = { movingS: Math.round(W.sim.km * W.sim.paceSec), km: W.sim.km, gain: 0 }; const r = simulate(); $('sim-out').textContent = `P ${r.perfIndex ?? '—'} · ${r.band ?? r.verdict} · ${r.card ? r.card.animal.name + ' (' + r.card.animal.rarity + ')' : r.message}`; playReveal(r); }
    if (e.target.id === 'sim-pool') { const r = simulate(); $('sim-out').innerHTML = r.pool ? `<b>${esc(r.trigger)}</b> · ` + r.pool.sort((a, b) => b.p - a.p).map(x => `${esc(x.animal.name)} ${(x.p * 100).toFixed(1)}%`).join(' · ') : esc(r.message); }
    if (e.target.id === 'dl') { const blob = new Blob([JSON.stringify(W.cfg, null, 2)], { type: 'application/json' }); const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = 'interaction-config.json'; a.click(); }
    if (e.target.id === 'reset-cfg') { W.cfg = structuredClone(W.defaults); saveConfig(); renderProps(); }
  });

  $('personas').addEventListener('click', e => { const b = e.target.closest('[data-persona]'); if (b) { setPersona(b.dataset.persona); $('personas').querySelectorAll('.persona').forEach(x => x.classList.toggle('is-on', x.dataset.persona === b.dataset.persona)); } });
  document.querySelectorAll('[data-device]').forEach(b => b.addEventListener('click', () => { W.device = b.dataset.device; document.querySelectorAll('[data-device]').forEach(x => x.classList.toggle('is-on', x === b)); renderPhone(); }));
  $('mode').addEventListener('click', () => { W.mode = W.mode === 'light' ? 'dark' : 'light'; $('mode').textContent = W.mode === 'light' ? 'App: light' : 'App: dark'; renderPhone(); });
  ['reduced','nogps','offline'].forEach(k => $('opt-' + k).addEventListener('change', e => { W.opts[k] = e.target.checked; renderPhone(); }));
  $('reset').addEventListener('click', () => { clearInterval(W.ticker); setPersona(W.personaId); go(W.user.fresh ? 'welcome' : 'today'); });

  // ---------- boot ----------
  loadConfig().then(() => {
    $('personas').innerHTML = DATA.personas.map(p => `<button class="persona${p.id === 'arjun' ? ' is-on' : ''}" data-persona="${p.id}"><b>${esc(p.name)}</b><span>${esc(p.blurb)}</span></button>`).join('');
    setPersona('arjun');
  });
})();
