/* Flying Cobra workbench — screen renderers. Each returns HTML for the phone viewport.
   Interactions are declared with data-act="verb:arg" and handled in workbench.js.
   Screen IDs: docs/ux/SCREEN_IDS.md. Copy: docs/DESIGN.md §9 and docs/ux/SCREEN_INVENTORY.md. */
(function () {
  'use strict';
  const { esc, card, fmtPace, fmtDur, fmtDate, pad4, poster } = FC;

  const TABS = [['today','☀','Today'],['collection','▦','Collection'],['encyclopedia','📖','Encyclopedia'],['settings','◯','You']];
  const tabbar = (on) => `<nav class="tabbar" aria-label="Tabs">${TABS.map(([id, ic, l]) => `<button class="tab${on === id ? ' is-on' : ''}" data-act="go:${id}" aria-current="${on === id}"><em aria-hidden="true">${ic}</em>${l}</button>`).join('')}</nav>`;
  const appbar = (title, right = '') => `<header class="appbar"><h1>${esc(title)}</h1><span class="appbar__spacer"></span>${right}</header>`;
  const back = (to) => `<button class="iconbtn" data-act="go:${to}" aria-label="Back">‹</button>`;
  const empty = (icon, title, sub, cta = '') => `<div class="empty"><div class="empty__bag">${icon}</div><h2 style="font-size:20px">${esc(title)}</h2><p class="muted tiny">${esc(sub)}</p>${cta}</div>`;
  const loading = (n = 3) => `<div class="pad stack">${Array.from({ length: n }, () => '<div class="skeleton" style="height:64px"></div>').join('')}</div>`;
  const errorBox = (msg, retry) => `<div class="pad"><div class="sheet center"><p><b>Something went quiet.</b></p><p class="muted tiny">${esc(msg)}</p><button class="btn btn--ghost" data-act="${retry}">Try again</button></div></div>`;

  const S = {};

  // ---------- Onboarding ----------
  S.welcome = () => `<div class="onb"><div style="height:16%"></div>
    <div class="onb__icon">${FC.PAW.replace('<svg', '<svg style="width:34px;fill:var(--color-accent)"')}</div>
    <h2>Run. Get an animal.<br>Collect India.</h2>
    <p class="muted">Every run earns a collectible animal card with a serial number only you hold. No leaderboards. No rankings.</p>
    <div class="onb__actions"><button class="btn" data-act="go:sign-in">Continue</button><p class="tiny muted center">Works with location alone. Everything else is optional and asked for separately.</p></div></div>`;

  S['sign-in'] = (st) => `<div class="onb"><h2>Sign in</h2><p class="muted">A link in your inbox. No password to remember.</p>
    ${st.state === 'sent' ? `<div class="sheet fade-in"><b style="font-family:var(--font-display)">Check your inbox</b><p class="muted tiny" style="margin:4px 0 0">We sent a sign-in link to you@example.in. Tap it on this phone.</p></div>
      <button class="btn btn--quiet" data-act="go:perm-location">(prototype) I tapped the link</button>`
    : st.state === 'error' ? `<div class="sheet"><b>That address didn't work.</b><p class="muted tiny" style="margin:4px 0 0">Check for a typo and try again.</p></div><button class="btn" data-act="state:sent">Send the link</button>`
    : `<input class="input" placeholder="you@example.in" aria-label="Email"><button class="btn" data-act="state:sent">Send me a link</button>
      <div class="btn-row"><button class="btn btn--ghost" disabled title="Coming soon"> Apple</button><button class="btn btn--ghost" disabled title="Coming soon">G Google</button></div>
      <details class="tiny muted"><summary>Test account</summary><p style="margin:8px 0 0">arjun@flyingcobra.test · password in the seed file</p></details>`}
    </div>`;

  const permScreen = (key, idx) => (st) => {
    const p = DATA.permissions.find(x => x.key === key);
    const next = ['perm-location','perm-motion','perm-activity','perm-health','perm-notifications','fairness'][idx + 1];
    return `<div class="onb"><div class="onb__dots" aria-hidden="true">${[0,1,2,3,4].map(i => `<i class="${i === idx ? 'is-on' : ''}"></i>`).join('')}</div>
      <div class="onb__icon">${p.icon}</div><h2>${esc(p.title)}</h2>
      <div class="onb__why"><b>Why</b>${esc('Flying Cobra uses this ' + p.why)}</div>
      <div class="onb__why"><b>What we store</b>${esc(p.store.charAt(0).toUpperCase() + p.store.slice(1))}</div>
      <div class="onb__why"><b>If you skip it</b>${esc(p.lose)}</div>
      ${st.state === 'denied' ? `<p class="tiny muted fade-in">No problem. You can turn this on later in You → Permissions.</p>` : ''}
      <div class="onb__actions"><div class="btn-row"><button class="btn btn--ghost" data-act="perm:deny:${key}:${next}">Not now</button><button class="btn" data-act="perm:allow:${key}:${next}">Allow</button></div></div></div>`;
  };
  S['perm-location'] = permScreen('location', 0); S['perm-motion'] = permScreen('motion', 1); S['perm-activity'] = permScreen('activity', 2);
  S['perm-health'] = permScreen('heart_rate', 3); S['perm-notifications'] = permScreen('notifications', 4);

  S.fairness = (st) => `<div class="onb"><h2>One optional thing</h2>
    <p class="muted">Your birth year and sex are used for one purpose: to grade effort fairly, so a sixty-year-old and a twenty-five-year-old can both earn top animals. Never shown on a card. Never shared.</p>
    <div class="sheet stack"><label class="tiny muted">Birth year<input class="input" placeholder="1996" inputmode="numeric"></label>
      <div class="btn-row"><button class="btn btn--ghost">Female</button><button class="btn btn--ghost">Male</button><button class="btn btn--ghost">Skip</button></div></div>
    <details class="tiny muted"><summary>Why does age matter?</summary><p style="margin:8px 0 0">Performance declines about 0.7% a year after 35. We divide your speed by that factor so the animal reflects effort, not birthday.</p></details>
    <div class="onb__actions"><button class="btn" data-act="go:onboarding-done">Continue</button><button class="btn btn--quiet" data-act="go:onboarding-done">Skip for now</button></div></div>`;

  S['onboarding-done'] = () => `<div class="onb center" style="align-content:center">${empty('🎒', 'Your first run opens the bag.', 'Run a kilometre, or ten minutes at running pace. We take it from there.')}
    <button class="btn" data-act="finish-onboarding">Let\'s go</button></div>`;

  // ---------- Home ----------
  S.today = (st, W) => {
    const u = W.user, last = u.cards[u.cards.length - 1];
    const days = ['M','T','W','T','F','S','S'];
    const dow = (new Date(DATA.today).getDay() + 6) % 7;
    const runDays = new Set(u.runs.filter(r => r.eligible).map(r => (new Date(r.date).getDay() + 6) % 7));
    const minDays = 3, got = Math.min(runDays.size, 7), more = Math.max(0, minDays - got);
    const envelope = W.pending ? `<button class="envelope slide-up" data-act="open-pending"><em>✉</em><span><b>A ${W.pending.scope} card is waiting</b><span class="tiny muted">Tap to open</span></span></button>` : '';
    const banners = W.banners.map((b, i) => `<div class="banner"><em>${b.kind === 'growth' ? '🌱' : b.kind === 'mastered' ? '✦' : '👋'}</em><div><b>${esc(b.title)}</b><div class="tiny muted">${esc(b.text)}</div></div><button data-act="dismiss-banner:${i}" aria-label="Dismiss">×</button></div>`).join('');
    if (st.state === 'loading') return appbar('Today') + loading() + tabbar('today');
    if (st.state === 'error') return appbar('Today') + errorBox('We could not reach the ledger. Your runs are safe on this phone.', 'state:success') + tabbar('today');
    return `${appbar('Today', `<button class="iconbtn" data-act="go:serial-search" aria-label="Verify a card">⌕</button>`)}
      <div class="pad stack">${envelope}${banners}
        ${last ? `<div data-act="open-card:${u.cards.length - 1}" style="cursor:pointer">${card(last)}</div>` : empty('🎒', 'Your first run opens the bag.', 'A run of 1 km or 10 minutes earns a card.')}
        <div class="sheet"><div class="streak" role="img" aria-label="${got} run-days this week">${days.map((d, i) => `<div class="streak__day${runDays.has(i) ? ' is-on' : ''}${i === dow ? ' is-today' : ''}"><div class="streak__dot"></div>${d}</div>`).join('')}</div>
          <p class="tiny muted center" style="margin:10px 0 0">${got} of the week${more > 0 ? ` · ${more} more opens the weekly bag` : ' · the weekly bag is open'}</p></div>
        ${u.cards.length ? `<div class="stats"><div class="stat"><b>${u.runs.length}</b><span>runs</span></div><div class="stat"><b>${u.runs.reduce((s, r) => s + r.km, 0).toFixed(0)}</b><span>km</span></div><div class="stat"><b>${u.cards.length}</b><span>cards</span></div></div>` : ''}
      </div>
      <button class="btn fab" data-act="go:run-ready">Start a run</button>${tabbar('today')}`;
  };

  // ---------- Run ----------
  S['run-ready'] = (st, W) => `${appbar('Run', back('today'))}<div class="runwrap">
    <div class="gpspill" data-state="${W.opts.nogps ? 'denied' : 'good'}"><i></i>${W.opts.nogps ? 'Location is off' : 'GPS ready'}</div>
    ${W.opts.nogps ? `<div class="sheet"><b>Timer-only run</b><p class="muted tiny" style="margin:4px 0 0">Without location we can time your run but not measure it, so it will not earn a card. Turn location on in You → Permissions.</p></div>` : `<p class="muted center tiny">Runs are also recorded automatically when you start moving. This button is for people who like intent.</p>`}
    <div class="bignum">0:00<small>moving</small></div>
    <button class="btn" data-act="start-run">Start</button></div>`;

  S['run-recording'] = (st, W) => {
    const r = W.live, gps = W.opts.nogps ? 'denied' : (st.state === 'gps-searching' ? 'searching' : 'good');
    return `${appbar('Running')}<div class="runwrap">
      <div class="gpspill" data-state="${gps}"><i></i>${gps === 'good' ? 'GPS good' : gps === 'searching' ? 'Looking for GPS…' : 'Location is off'}</div>
      <div class="bignum">${fmtDur(r.movingS)}<small>${st.state === 'auto-paused' ? 'paused for you' : 'moving'}</small></div>
      <div class="metrics"><div class="metric"><b>${r.km.toFixed(2)}</b><span>km</span></div><div class="metric"><b>${r.km > 0.05 ? fmtPace(r.movingS / r.km) : '–:––'}</b><span>/km</span></div><div class="metric"><b>${r.gain}</b><span>m climb</span></div></div>
      ${st.state === 'offline' ? `<div class="sheet tiny"><b>Offline.</b> <span class="muted">Your run is being saved on this phone and will submit when you are back online.</span></div>` : ''}
      <div class="btn-row"><button class="btn btn--ghost" data-act="${st.state === 'paused' ? 'resume-run' : 'pause-run'}">${st.state === 'paused' ? 'Resume' : 'Pause'}</button><button class="btn" data-act="finish-run">Finish</button></div>
      <p class="tiny muted center">Simulated: ${fmtPace(W.sim.paceSec)}/km · ${W.sim.km} km target · ${Engine.timeWindow(W.sim.hour)}</p></div>`;
  };

  S['run-finish'] = (st, W) => {
    if (st.state === 'confirm') return `${appbar('Finish?')}<div class="runwrap"><div class="sheet"><b>Under a kilometre</b><p class="muted tiny" style="margin:4px 0 0">Recorded. A run of 1 km or 10 minutes earns a card. Keep going?</p></div>
      <div class="btn-row"><button class="btn btn--ghost" data-act="submit-run">Finish anyway</button><button class="btn" data-act="go:run-recording">Keep running</button></div></div>`;
    return `<div class="overlay"><div class="overlay__shimmer">Reading your run</div></div>`;
  };

  // ---------- Cards ----------
  S.reveal = () => ''; // driven by the sequence in workbench.js
  S['card-detail'] = (st, W) => {
    const c = W.focusCard; if (!c) return appbar('Card', back('collection')) + empty('🃏', 'No card selected', 'Pick one from your collection.');
    const same = W.user.cards.filter(x => x.animal.name === c.animal.name), best = Math.min(...same.map(x => x.serial));
    return `${appbar(c.animal.name, back('collection'))}<div class="pad stack">
      <div class="card-slot card-slot--lg">${card(c)}</div>
      <div class="sheet"><div class="tiny muted">${esc(FC.cap(c.tier))} · earned ${same.length} time${same.length === 1 ? '' : 's'} · best #${pad4(best)}</div>
        <div style="margin-top:8px"><span class="seal">${c.verdict === 'unverified' ? '◐ Unverified · drew from the everyday bag' : '✓ Verified · lives in the ledger'}</span></div>
        <p class="tiny muted" style="margin:10px 0 0">${esc(c.animal.flavour)}. Earned ${fmtDate(c.issuedAt)}. ${c.season ? 'Set: ' + esc(c.season) + '.' : ''}</p></div>
      <div class="btn-row"><button class="btn" data-act="go:poster">Share poster</button><button class="btn btn--ghost" data-act="fire:link-copied">Copy link</button></div>
      <div class="sheet" style="display:flex;align-items:center;gap:12px"><div style="flex:1"><b style="font-family:var(--font-display)">Show on verify page</b><div class="tiny muted">Anyone with the serial can see this card, your display name and the date. Never your route.</div></div><button class="toggle" role="switch" aria-checked="${c.isPublic !== false}" data-act="toggle-public" aria-label="Show on verify page"></button></div>
      <p class="tiny muted center">Never shown here: your route, start point, heart rate, age or sex.</p></div>`;
  };
  S.poster = (st, W) => `${appbar('Share', back('card-detail'))}<div class="pad stack"><div style="width:min(100%,220px);margin-inline:auto">${poster(W.focusCard)}</div>
    <p class="tiny muted center">1080 × 1920. Animal, serial and a QR code to the verify page. No map, no start point.</p>
    <button class="btn" data-act="toast:poster:exported">Share to Instagram / WhatsApp</button></div>`;

  // ---------- Collection ----------
  S.collection = (st, W) => {
    const u = W.user, f = W.filter || 'all';
    if (st.state === 'loading') return appbar('Collection') + loading(4) + tabbar('collection');
    if (!u.cards.length) return appbar('Collection') + empty('🎒', 'Your first run opens the bag.', 'Every animal you earn appears here, grouped by family.') + tabbar('collection');
    const cards = u.cards.filter(c => f === 'all' || (f === 'rare' ? ['rare','epic','legendary'].includes(c.animal.rarity) : c.scope === f));
    const byAnimal = {}; cards.forEach(c => { (byAnimal[c.animal.name] ||= []).push(c); });
    const fams = {}; Object.values(byAnimal).forEach(list => { const best = list.reduce((a, b) => a.serial < b.serial ? a : b); (fams[best.animal.family] ||= []).push({ best, n: list.length }); });
    const unseen = f === 'all' ? DATA.animals.filter(a => !a.secret && !byAnimal[a.name] && ['swift','steady','calm','gentle'].includes(a.family)).slice(0, 6) : [];
    return `${appbar('Collection', `<button class="iconbtn" aria-label="Sort">⇅</button>`)}
      <div class="chiprow">${[['all','All'],['run','Run'],['weekly','Weekly'],['monthly','Monthly'],['rare','Rare+']].map(([k, l]) => `<button class="chip${f === k ? ' is-on' : ''}" data-act="filter:${k}">${l}</button>`).join('')}</div>
      ${Object.entries(fams).map(([fam, list]) => `<div class="section-head"><h2>${esc(FC.cap(fam))}</h2><span>${list.length} of ${DATA.animals.filter(a => a.family === fam && !a.secret).length}</span></div>
        <div class="grid2">${list.map(({ best, n }) => `<button class="celltile" data-act="open-card-name:${esc(best.animal.name)}">${n > 1 ? `<span class="celltile__count">×${n}</span>` : ''}${card(best, { tile: true })}</button>`).join('')}</div>`).join('')}
      ${unseen.length ? `<div class="section-head"><h2>Still out there</h2></div><div class="grid2">${unseen.map(() => '<div class="unknown" aria-label="An animal you have not met yet">?</div>').join('')}</div>` : ''}
      ${tabbar('collection')}`;
  };

  // ---------- Search & Verify ----------
  S['serial-search'] = (st, W) => `${appbar('Verify a card', back('today'))}<div class="pad stack">
    <p class="muted tiny">Type a serial number, like <b>Tiger #0427</b>. Serials are the only thing you can search. Never people.</p>
    <form class="search" data-act="search"><input class="input" id="q" value="${esc(W.query || '')}" placeholder="Cheetah #0042" aria-label="Serial number"><button class="btn" type="submit">Verify</button></form>
    ${st.state === 'loading' ? loading(1) : st.state === 'found' && W.found ? `<div class="fade-in stack"><div class="card-slot">${card(W.found)}</div><div class="sheet center"><span class="seal">✓ Real · lives in the Flying Cobra ledger</span><p class="tiny muted" style="margin:10px 0 0">Earned by <b>${esc(W.foundBy)}</b> on ${fmtDate(W.found.issuedAt)} · #${pad4(W.found.serial)} of ${W.found.animal.issued} issued</p></div></div>`
    : st.state === 'not-found' ? `<div class="sheet center fade-in"><b style="font-family:var(--font-display)">No such card.</b><p class="muted tiny" style="margin:4px 0 0">If someone showed you this, they're bluffing.</p></div>` : ''}</div>`;

  S['verify-web'] = (st, W) => `<div style="background:var(--color-surface-alt);height:100%"><div style="background:var(--color-ink);color:var(--color-bg);font-size:11px;padding:8px 14px;display:flex;gap:8px;align-items:center"><span>🔒</span><span style="opacity:.8">flyingcobra.run/v/${W.found ? esc(W.found.animal.slug) + '/' + W.found.serial : 'cheetah/42'}</span></div>
    <div class="pad stack center">${W.found ? `<div class="card-slot">${card(W.found)}</div><span class="seal">✓ Real · lives in the Flying Cobra ledger</span><p class="tiny muted">Earned by <b>${esc(W.foundBy)}</b> on ${fmtDate(W.found.issuedAt)}<br>#${pad4(W.found.serial)} of ${W.found.animal.issued} issued</p><div class="btn-row"><button class="btn btn--ghost">App Store</button><button class="btn btn--ghost">Google Play</button></div>` : empty('🔍', 'No such card.', "If someone showed you this, they're bluffing.")}
    <p class="tiny muted">No app needed. No route, no location, no health data — ever.</p></div></div>`;

  // ---------- Encyclopedia ----------
  S.encyclopedia = (st, W) => {
    const q = (W.encQuery || '').toLowerCase(), owned = new Set(W.user.cards.map(c => c.animal.name));
    const list = DATA.animals.filter(a => !(a.secret && !owned.has(a.name)) && a.name.toLowerCase().includes(q));
    const fams = {}; list.forEach(a => (fams[a.family] ||= []).push(a));
    return `${appbar('Encyclopedia')}<div class="pad" style="padding-bottom:0"><input class="input" placeholder="Search animals" value="${esc(W.encQuery || '')}" data-act="enc-search" aria-label="Search animals by name"></div>
      <div class="pad">${Object.entries(fams).map(([fam, as]) => `<div class="section-head" style="padding-left:0"><h2>${esc(FC.cap(fam))}</h2><span>${as.length}</span></div>${as.map(a => `<button class="row" data-family="${a.family}" data-act="entry:${esc(a.name)}"><div class="row__avatar">${esc(a.name[0])}</div><div class="row__main"><b>${esc(a.name)}</b><span>${esc(a.flavour)}</span></div><div class="row__end">${owned.has(a.name) ? '×' + W.user.cards.filter(c => c.animal.name === a.name).length : esc(a.rarity)}</div></button>`).join('')}`).join('')}</div>${tabbar('encyclopedia')}`;
  };
  S['animal-entry'] = (st, W) => {
    const a = W.focusAnimal, n = W.user.cards.filter(c => c.animal.name === a.name).length;
    return S.encyclopedia(st, W) + `<div class="bottom-sheet" data-family="${a.family}"><div style="display:flex;gap:14px;align-items:center"><div class="row__avatar" style="width:64px;height:64px;font-size:28px">${esc(a.name[0])}</div><div><h2 style="font-size:22px">${esc(a.name)}</h2><div class="tiny muted">${esc(a.flavour)} · ${esc(a.rarity)}</div></div></div>
      <div class="chiprow" style="padding:12px 0 6px"><span class="chip">${esc(FC.cap(a.family))}</span>${n ? `<span class="chip is-on">Earned ×${n}</span>` : ''}<span class="chip">${a.issued} issued so far</span></div>
      <p class="tiny" style="margin-top:8px"><b>Superpower.</b> <span class="muted">Placeholder: the real encyclopedia entry (facts, habitat, size, India note) comes from the animals table.</span></p>
      <button class="btn btn--ghost" data-act="go:encyclopedia">Close</button></div>`;
  };

  // ---------- Settings ----------
  S.settings = (st, W) => {
    const u = W.user, granted = new Set(u.permissions), allOn = DATA.permissions.filter(p => p.key !== 'notifications').every(p => granted.has(p.key));
    const weeks = Array.from({ length: 84 }, (_, i) => u.runs.some(r => r.date === DATA.dAgo(83 - i)) ? 2 : 0);
    return `${appbar('You')}<div class="pad stack">
      <div class="sheet"><div style="display:flex;gap:12px;align-items:center"><div class="row__avatar" style="background:var(--color-surface-alt);color:var(--color-ink)">${esc(u.name[0])}</div><div style="flex:1"><b style="font-family:var(--font-display);font-size:17px">${esc(u.name)}</b><div class="tiny muted">${esc(u.city)}${u.age ? ` · fairness: ${u.age}, ${u.sex}` : ' · fairness: not set'}</div></div><button class="iconbtn" aria-label="Edit">✎</button></div>
        <p class="tiny muted" style="margin:10px 0 0">Age and sex are used to grade effort fairly. Never shown. <a data-act="go:fairness" style="color:var(--color-accent);cursor:pointer">Change</a></p></div>
      <div class="sheet"><h2 style="font-size:16px;margin-bottom:4px">Permissions</h2><p class="tiny muted">A receipt of what you have let us read, and why.</p>
        ${DATA.permissions.map(p => `<div class="perm"><div class="perm__main"><b>${esc(p.title)}</b><span>${esc('Used ' + p.why)}</span>${granted.has(p.key) ? '' : `<span class="perm__lose">${esc(p.lose)}</span>`}</div><button class="toggle" role="switch" aria-checked="${granted.has(p.key)}" data-act="toggle-perm:${p.key}" aria-label="${esc(p.title)}"></button></div>`).join('')}
        <div class="perm" style="border-top:1px solid var(--color-line)"><div class="perm__main"><b>${allOn ? '✦ Fully connected' : '🔒 Fully connected'}</b><span>${allOn ? 'Everything is on. Something rare is possible.' : 'Something rare becomes possible when every purpose is on. We will not say what.'}</span></div></div></div>
      <div class="sheet"><h2 style="font-size:16px;margin-bottom:8px">The last twelve weeks</h2><div class="heat" role="img" aria-label="Run-day heat map">${weeks.map(v => `<i data-v="${v}"></i>`).join('')}</div></div>
      <div class="stack"><button class="row" data-act="go:serial-search"><div class="row__main"><b>Verify a card</b><span>The only search in the app</span></div><div class="row__end">›</div></button>
        <button class="row" data-act="toast:settings:exported"><div class="row__main"><b>Export my data</b><span>Everything we hold, as one file</span></div><div class="row__end">›</div></button>
        <button class="row" data-act="go:data-and-account"><div class="row__main"><b>Delete my account</b><span>Erases everything. Serials stay reserved.</span></div><div class="row__end">›</div></button></div></div>${tabbar('settings')}`;
  };
  S['permission-receipt'] = S.settings;
  S['data-and-account'] = (st) => `${appbar('Your data', back('settings'))}<div class="pad stack">
    <div class="sheet"><b style="font-family:var(--font-display)">Export my data</b><p class="tiny muted" style="margin:4px 0 10px">Profile, runs, routes, cards and bonds, as one JSON file. Yours to keep.</p><button class="btn btn--ghost" data-act="toast:settings:exported">Export</button></div>
    <div class="sheet"><b style="font-family:var(--font-display);color:var(--color-danger)">Delete my account</b><p class="tiny muted" style="margin:4px 0 10px">Everything is erased. Your serial numbers stay reserved so nobody else can claim them, and the public lookup shows "not found".</p>
      ${st.state === 'confirm' ? `<div class="btn-row fade-in"><button class="btn btn--ghost" data-act="state:success">Keep my account</button><button class="btn btn--danger" data-act="delete-account">Delete everything</button></div>` : `<button class="btn btn--ghost" data-act="state:confirm">Delete…</button>`}</div></div>`;

  // ---------- Celebrations (rendered as overlays by workbench.js; these are the fallbacks) ----------
  ['celebration-growth','celebration-mastered','celebration-welcome-back','celebration-discovery'].forEach(id => { S[id] = (st, W) => S.today(st, W); });
  S['setup-needed'] = () => `<div class="onb center" style="align-content:center">${empty('🔑', 'Almost there', 'Flying Cobra needs its Supabase keys. Copy app/.env.example to app/.env, paste the Project URL and anon key, and restart.')}</div>`;

  window.SCREENS = S;
})();
