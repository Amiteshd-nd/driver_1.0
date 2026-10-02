/* Flying Cobra verify, static fallback. Calls the public lookup_serial RPC and renders the card client-side.
   All dynamic text goes through textContent; nothing from the network touches innerHTML. */
(function () {
  'use strict';

  var FAMILIES = {
    swift: ['#F5E2C8', '#5A2E0C', '#E0902F'], steady: ['#D9E7D6', '#1F3D2B', '#4F8A5B'],
    calm: ['#E6DFF0', '#3A2E57', '#8B74C9'], gentle: ['#F1DCD1', '#5B2F22', '#C76A4E'],
    time: ['#1F2340', '#E7E4FF', '#8FA3FF'], explorer: ['#F3E3B8', '#4E3B10', '#D1A233'],
    regional: ['#D3ECEA', '#134845', '#2E9C96'], weekly: ['#F0D4D8', '#5A1322', '#B82A47'],
    migratory: ['#D7E8F7', '#143A5C', '#3E86C8'], secret: ['#E7DAF5', '#3C1F5E', '#9D6AE3'],
    national: ['#FBE4C6', '#6B3A0E', '#F2A33A']
  };
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  var HEX = /^#[0-9a-fA-F]{6}$/;

  // --- tiny DOM helper: h(tag, attrs, ...children) ---
  function h(tag, attrs) {
    var el = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === 'style') el.style.cssText = attrs[k];
      else if (k === 'class') el.className = attrs[k];
      else el.setAttribute(k, attrs[k]);
    });
    for (var i = 2; i < arguments.length; i++) {
      var c = arguments[i];
      if (c == null) continue;
      el.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    }
    return el;
  }
  function svgTick() {
    var ns = 'http://www.w3.org/2000/svg';
    var s = document.createElementNS(ns, 'svg');
    s.setAttribute('viewBox', '0 0 24 24'); s.setAttribute('aria-hidden', 'true');
    var p = document.createElementNS(ns, 'path');
    p.setAttribute('d', 'M4 12.5l5 5L20 6.5'); p.setAttribute('fill', 'none');
    p.setAttribute('stroke', 'currentColor'); p.setAttribute('stroke-width', '2.5');
    p.setAttribute('stroke-linecap', 'round'); p.setAttribute('stroke-linejoin', 'round');
    s.appendChild(p); return s;
  }

  // --- formatting ---
  function pad4(n) { var s = String(n); while (s.length < 4) s = '0' + s; return s; }
  function mmss(sec) {
    sec = Math.round(Number(sec) || 0);
    var m = Math.floor(sec / 60), s = sec % 60;
    if (m >= 60) { var hh = Math.floor(m / 60); m = m % 60; return hh + ':' + (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s; }
    return m + ':' + (s < 10 ? '0' : '') + s;
  }
  function fmtDate(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    // Render in IST regardless of viewer timezone (India-first).
    var parts = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', day: 'numeric', month: 'numeric', year: 'numeric' }).formatToParts(d);
    var o = {}; parts.forEach(function (p) { o[p.type] = p.value; });
    return o.day + ' ' + MONTHS[Number(o.month) - 1] + ' ' + o.year;
  }
  function statsLine(stats, scope) {
    stats = stats || {};
    var km = typeof stats.distance_km === 'number' ? stats.distance_km.toFixed(1) + ' km' : null;
    if (scope === 'weekly' && typeof stats.run_days === 'number') return stats.run_days + ' days' + (km ? ' · ' + km : '');
    if (scope === 'monthly') return [stats.month, stats.region].filter(Boolean).join(' · ') || km || '';
    var bits = [];
    if (km) bits.push(km);
    if (typeof stats.duration_s === 'number') bits.push(mmss(stats.duration_s));
    if (typeof stats.pace_s_per_km === 'number') bits.push(mmss(stats.pace_s_per_km) + '/km');
    return bits.join(' · ');
  }
  function cap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ''; }

  // --- whitelist the RPC payload: never pass unknown keys through ---
  function pick(res) {
    var c = (res && res.card) || {};
    var pal = c.palette || {};
    var fam = FAMILIES[c.family] || FAMILIES.swift;
    return {
      slug: String(c.slug || ''), name: String(c.name || 'Unknown'), family: String(c.family || ''),
      rarity: String(c.rarity || 'common'), flavour: String(c.flavour_line || ''), season: String(c.season || ''),
      serialNo: Number(c.serial_no) || 0, serial: String(c.serial || ''), scope: String(c.scope || 'run'),
      verdict: String(c.verdict || 'verified'), issuedAt: String(c.issued_at || (res.stats && res.stats.date) || ''),
      bg: HEX.test(pal.bg) ? pal.bg : fam[0], fg: HEX.test(pal.fg) ? pal.fg : fam[1], accent: HEX.test(pal.accent) ? pal.accent : fam[2],
      earnedBy: String(res.earned_by || 'a runner'), issuedSoFar: Number(res.issued_so_far) || 0,
      stats: res.stats && typeof res.stats === 'object' ? res.stats : {}
    };
  }

  // --- the card (same markup as index.html) ---
  function renderCard(v) {
    var tick = v.verdict === 'verified'
      ? h('span', { class: 'tick', 'aria-label': 'Verified' }, '✓')
      : h('span', { class: 'tick tick--unverified' }, 'unverified');
    var label = v.name + ', ' + v.rarity + ', serial ' + v.serialNo + (v.issuedAt ? ', earned ' + fmtDate(v.issuedAt) : '');
    var card = h('article', { class: 'card card--' + v.rarity, style: '--fam-bg:' + v.bg + ';--fam-fg:' + v.fg + ';--fam-accent:' + v.accent, 'aria-label': label },
      h('div', { class: 'card__cap' }, h('span', null, v.season || 'Flying Cobra'), h('span', { class: 'card__rarity' }, cap(v.rarity))),
      h('div', { class: 'card__art', 'aria-hidden': 'true' }, h('span', { class: 'card__glyph' }, v.name.charAt(0).toUpperCase())),
      h('div', { class: 'card__body' },
        h('h2', { class: 'card__name' }, v.name),
        h('p', { class: 'card__flavour' }, v.flavour),
        h('hr', { class: 'card__rule' }),
        h('p', { class: 'card__stats' }, statsLine(v.stats, v.scope)),
        h('p', { class: 'card__serial' }, h('span', null, v.name), h('span', null, '#' + pad4(v.serialNo)), tick)
      )
    );
    return card;
  }

  function storeButtons() {
    return h('div', { class: 'hero-actions' },
      h('a', { class: 'btn btn--primary', href: '#', 'data-store': 'ios' }, 'App Store'),
      h('a', { class: 'btn', href: '#', 'data-store': 'android' }, 'Google Play'));
  }

  // --- states ---
  function viewFound(res) {
    var v = pick(res);
    var seal = v.verdict === 'verified'
      ? h('span', { class: 'seal' }, svgTick(), 'Real ✓ · lives in the Flying Cobra ledger')
      : h('span', { class: 'seal seal--warn' }, 'Real · lives in the ledger, drawn from the everyday bag');
    var facts = h('ul', { class: 'verify-facts' },
      h('li', null, h('span', null, 'Card'), h('b', null, v.name + ' #' + pad4(v.serialNo))),
      h('li', null, h('span', null, 'Earned by'), h('b', null, v.earnedBy)),
      v.issuedAt ? h('li', null, h('span', null, 'On'), h('b', null, fmtDate(v.issuedAt))) : null,
      statsLine(v.stats, v.scope) ? h('li', null, h('span', null, cap(v.scope)), h('b', null, statsLine(v.stats, v.scope))) : null,
      h('li', null, h('span', null, 'Issued'), h('b', null, '#' + pad4(v.serialNo) + ' of ' + v.issuedSoFar + ' issued'))
    );
    return [
      h('div', { class: 'verify-card' }, renderCard(v)),
      h('div', null,
        seal,
        h('h2', { style: 'margin-top:18px' }, 'Earned by ' + v.earnedBy + (v.issuedAt ? ' on ' + fmtDate(v.issuedAt) : '')),
        h('p', { class: 'muted' }, 'This card is in the ledger. Serial numbers are issued once, by the database, and never reused. No route, location or health data is shown here, ever.'),
        facts,
        h('p', { class: 'muted', style: 'margin-top:24px;font-size:14px' }, 'Want your own? Every run earns a card.'),
        storeButtons())
    ];
  }
  function viewNotFound(res, q) {
    var hint = res && typeof res.hint === 'string' ? res.hint : '';
    var reason = res && res.reason;
    var title = reason === 'format' ? 'That doesn’t look like a serial.' : 'No such card.';
    var body = reason === 'format'
      ? 'Serials look like an animal name and a number.'
      : 'If someone showed you this, they’re bluffing.';
    var extra = null;
    if (reason === 'serial' && typeof res.animal === 'string') {
      var n = Number(res.issued_so_far) || 0;
      extra = h('p', { class: 'muted' }, n > 0 ? cap(res.animal) + ' exists, but only ' + n + ' of them have been issued so far.' : 'No ' + res.animal + ' card has been issued yet.');
    }
    return [h('div', { class: 'state', style: 'grid-column:1/-1;max-width:640px' },
      h('span', { class: 'seal seal--off' }, 'Not in the ledger'),
      h('h2', { style: 'margin-top:16px' }, title),
      h('p', null, body),
      extra,
      hint ? h('p', { class: 'muted' }, hint) : null,
      q ? h('p', { class: 'muted', style: 'font-size:14px' }, 'You searched for ', h('code', null, q)) : null)];
  }
  function viewNotConfigured() {
    return [h('div', { class: 'state', style: 'grid-column:1/-1;max-width:640px' },
      h('h2', null, 'Not connected to the ledger yet.'),
      h('p', null, 'This page needs to know which Flying Cobra database to ask. Open ', h('code', null, 'verify-config.js'),
        ' and set ', h('code', null, 'SUPABASE_URL'), ' and ', h('code', null, 'SUPABASE_ANON_KEY'), ' to your project’s values.'),
      h('p', { class: 'muted' }, 'The anon key is public by design: the only thing it can read is a serial lookup.'))];
  }
  function viewError(msg) {
    return [h('div', { class: 'state', style: 'grid-column:1/-1;max-width:640px' },
      h('h2', null, 'The ledger is taking a moment.'),
      h('p', null, 'We couldn’t reach it just now. Try again in a little while.'),
      msg ? h('p', { class: 'muted', style: 'font-size:14px' }, msg) : null)];
  }
  function viewIdle() {
    return [h('div', { class: 'state', style: 'grid-column:1/-1;max-width:640px' },
      h('h2', null, 'Type a serial to begin.'),
      h('p', { class: 'muted' }, 'You’ll see that single card, the animal, the number, who earned it and when. If it isn’t in the ledger, someone is bluffing.'))];
  }
  function viewLoading() {
    return [h('div', { class: 'verify-card' }, h('div', { class: 'shimmer', 'aria-hidden': 'true' })),
      h('div', null, h('p', { class: 'muted' }, 'Reading the ledger…'))];
  }

  // --- wiring ---
  var root = document.getElementById('result');
  function show(nodes) {
    while (root.firstChild) root.removeChild(root.firstChild);
    nodes.forEach(function (n) { if (n) root.appendChild(n); });
  }
  function isConfigured() {
    return typeof SUPABASE_URL === 'string' && typeof SUPABASE_ANON_KEY === 'string' &&
      SUPABASE_URL.indexOf('YOUR-PROJECT') === -1 && SUPABASE_ANON_KEY.indexOf('YOUR-ANON-KEY') === -1 &&
      SUPABASE_URL.length > 0 && SUPABASE_ANON_KEY.length > 0;
  }
  function baseUrl() {
    var u = SUPABASE_URL.replace(/\/+$/, '');
    return /^https?:\/\//i.test(u) ? u : 'https://' + u;
  }
  function queryFromLocation() {
    var sp = new URLSearchParams(window.location.search);
    var q = sp.get('q');
    if (q && q.trim()) return q.trim();
    var m = /^#\/?([a-z0-9-]+)\/(\d{1,7})\/?$/i.exec(window.location.hash || '');
    if (m) return m[1].replace(/-/g, ' ') + ' ' + m[2];
    return '';
  }

  function lookup(q) {
    if (!q) { show(viewIdle()); return; }
    if (!isConfigured()) { show(viewNotConfigured()); return; }
    root.setAttribute('aria-busy', 'true');
    show(viewLoading());
    var ctl = typeof AbortController === 'function' ? new AbortController() : null;
    var timer = ctl ? setTimeout(function () { ctl.abort(); }, 10000) : 0;
    fetch(baseUrl() + '/rest/v1/rpc/lookup_serial', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': SUPABASE_ANON_KEY, 'Authorization': 'Bearer ' + SUPABASE_ANON_KEY },
      body: JSON.stringify({ q: q }),
      signal: ctl ? ctl.signal : undefined
    }).then(function (r) {
      if (!r.ok) throw new Error('Ledger answered ' + r.status);
      return r.json();
    }).then(function (res) {
      if (res && res.found === true && res.card) {
        var v = pick(res);
        document.title = v.name + ' #' + pad4(v.serialNo) + ' · Flying Cobra';
        show(viewFound(res));
      } else {
        document.title = 'No such card · Flying Cobra';
        show(viewNotFound(res || {}, q));
      }
    }).catch(function (err) {
      show(viewError(err && err.name === 'AbortError' ? 'Timed out after 10 seconds.' : (err && err.message) || ''));
    }).finally(function () {
      clearTimeout(timer);
      root.setAttribute('aria-busy', 'false');
    });
  }

  var input = document.getElementById('q');
  var form = document.getElementById('lookup-form');
  var q0 = queryFromLocation();
  if (input && q0) input.value = q0;
  lookup(q0);

  if (form && input) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var v = input.value.trim();
      if (!v) { input.focus(); return; }
      var url = new URL(window.location.href);
      url.hash = ''; url.search = '?q=' + encodeURIComponent(v);
      history.pushState(null, '', url.toString());
      lookup(v);
    });
  }
  window.addEventListener('popstate', function () {
    var q = queryFromLocation();
    if (input) input.value = q;
    lookup(q);
  });
  window.addEventListener('hashchange', function () {
    var q = queryFromLocation();
    if (input) input.value = q;
    lookup(q);
  });

  // Store placeholders (shared with index).
  var toast = document.getElementById('toast'); var toastTimer = 0;
  document.addEventListener('click', function (e) {
    var a = e.target.closest ? e.target.closest('[data-store]') : null;
    if (!a) return;
    e.preventDefault();
    if (!toast) return;
    toast.textContent = 'Not in ' + (a.getAttribute('data-store') === 'ios' ? 'the App Store' : 'Google Play') + ' yet. Soon.';
    toast.classList.add('is-on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toast.classList.remove('is-on'); }, 2800);
  });
})();
