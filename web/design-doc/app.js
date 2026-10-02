/* Flying Cobra — design document
   The selection demo runs the real formulas from docs/ALGORITHMS.md (§2 age grading,
   §3 bands, §4 stage, §5 finish, §6 weighted draw) against the real animal roster from
   supabase/migrations/0005_seed_animals.sql, so the page cannot drift from the build. */
(function () {
  'use strict';

  // ---------- §2.2 age factors (knots; linear interpolation between them) ----------
  var AGE_M = { 10:.700, 12:.780, 14:.860, 16:.930, 18:.980, 20:1, 30:1, 35:.985, 40:.955, 45:.925,
                50:.893, 55:.860, 60:.826, 65:.788, 70:.746, 75:.698, 80:.640, 85:.570, 90:.490 };
  var AGE_F = { 10:.740, 12:.820, 14:.900, 16:.960, 18:.990, 20:1, 30:1, 35:.983, 40:.955, 45:.920,
                50:.880, 55:.840, 60:.798, 65:.752, 70:.700, 75:.643, 80:.578, 85:.505, 90:.425 };

  function interp(table, age) {
    var keys = Object.keys(table).map(Number).sort(function (a, b) { return a - b; });
    var a = Math.max(keys[0], Math.min(keys[keys.length - 1], age));
    var lo = keys[0], hi = keys[keys.length - 1];
    for (var i = 0; i < keys.length; i++) {
      if (keys[i] <= a) lo = keys[i];
      if (keys[i] >= a) { hi = keys[i]; break; }
    }
    if (hi === lo) return table[lo];
    return table[lo] + (table[hi] - table[lo]) * (a - lo) / (hi - lo);
  }
  // The demo does not ask for sex, so it uses the "unknown" path: the mean of both columns.
  function ageFactor(age) { return (interp(AGE_M, age) + interp(AGE_F, age)) / 2; }

  // ---------- §2.1 Riegel open standard ----------
  var T_REF_UNKNOWN = 796, D_REF = 5, RIEGEL = 1.06, MIN_D_EFF = 1.5;
  function vStd(km) {
    var dEff = Math.max(km, MIN_D_EFF);
    var tStd = T_REF_UNKNOWN * Math.pow(dEff / D_REF, RIEGEL);
    return dEff / (tStd / 3600);
  }
  // ---------- §2.4, §3, §4.1, §5 ----------
  function perfIndex(vKmh, km, age) { return vKmh / (vStd(km) * ageFactor(age)); }
  function speedBand(p) { return p >= 0.60 ? 'swift' : p >= 0.47 ? 'steady' : p >= 0.35 ? 'calm' : 'gentle'; }
  function stageFor(km) { return km >= 7 ? 'adult' : km >= 3 ? 'young' : 'baby'; }
  function finishFor(days) { return days >= 7 ? 'radiant' : days >= 4 ? 'glow' : 'plain'; }

  // ---------- the roster (0005_seed_animals.sql) ----------
  var RARITY_WEIGHT = { common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1 };
  var ELEPHANT = { name: 'Elephant', rarity: 'epic', flavour: 'the tireless traveller', minKm: 8 };
  var ROSTER = {
    swift: [
      { name: 'Chinkara', rarity: 'common', flavour: 'the desert dancer' },
      { name: 'Horse', rarity: 'common', flavour: 'born to gallop' },
      { name: 'Indian Hare', rarity: 'uncommon', flavour: 'quick as a thought' },
      { name: 'Blackbuck', rarity: 'uncommon', flavour: 'the spiral-horned sprinter' },
      { name: 'Peregrine Falcon', rarity: 'rare', flavour: 'the fastest thing alive' },
      { name: 'Cheetah', rarity: 'epic', flavour: 'the comeback sprinter' }
    ],
    steady: [
      { name: 'Chital', rarity: 'common', flavour: 'the dappled wanderer' },
      { name: 'Desi Dog', rarity: 'common', flavour: "everyone's running partner" },
      { name: 'Nilgai', rarity: 'uncommon', flavour: 'the blue bull of the plains' },
      { name: 'Dhole', rarity: 'uncommon', flavour: 'the pack hunter' },
      { name: 'Indian Wolf', rarity: 'rare', flavour: 'the grassland ghost' },
      { name: 'Leopard', rarity: 'epic', flavour: 'the shadow that walks anywhere' }
    ],
    calm: [
      { name: 'Rabbit', rarity: 'common', flavour: 'soft paws, big heart' },
      { name: 'Cat', rarity: 'common', flavour: 'curious and unbothered' },
      { name: 'Grey Langur', rarity: 'uncommon', flavour: 'the temple acrobat' },
      { name: 'Peacock', rarity: 'uncommon', flavour: 'the monsoon dancer' },
      { name: 'Smooth-coated Otter', rarity: 'rare', flavour: "the river's playmate" },
      { name: 'Mouse Deer', rarity: 'epic', flavour: 'small, secret, sure-footed' },
      ELEPHANT // the elephant rule covers gentle AND calm, at 8 km or more
    ],
    gentle: [
      { name: 'Star Tortoise', rarity: 'common', flavour: 'unstoppable' },
      { name: 'Hamster', rarity: 'common', flavour: 'the midnight marathoner' },
      { name: 'Porcupine', rarity: 'uncommon', flavour: 'the quilled knight' },
      { name: 'Sloth Bear', rarity: 'uncommon', flavour: 'the shaggy wanderer' },
      { name: 'Pangolin', rarity: 'rare', flavour: 'the armoured pilgrim' },
      ELEPHANT
    ]
  };

  // §6.1 a rule matches only when its predicates hold
  function buildPool(band, km) {
    return ROSTER[band].filter(function (a) { return !a.minKm || km >= a.minKm; })
      .map(function (a) { return { animal: a, w: RARITY_WEIGHT[a.rarity] }; });
  }
  function drawFrom(pool) {
    var total = pool.reduce(function (s, x) { return s + x.w; }, 0);
    var r = Math.random() * total, acc = 0;
    for (var i = 0; i < pool.length; i++) { acc += pool[i].w; if (r < acc) return pool[i].animal; }
    return pool[pool.length - 1].animal;
  }

  // ---------- small helpers ----------
  function $(id) { return document.getElementById(id); }
  function pad(n) { return String(n).padStart(4, '0'); }
  function fmtPace(sec) { return Math.floor(sec / 60) + ':' + String(Math.round(sec % 60)).padStart(2, '0'); }
  function fmtDur(sec) {
    var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = Math.round(sec % 60);
    return h > 0 ? h + ':' + String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0')
                 : m + ':' + String(s).padStart(2, '0');
  }
  function hash(str) { var h = 2166136261; for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }

  // ---------- the demo ----------
  var els = {
    pace: $('pace'), dist: $('dist'), days: $('days'), age: $('age'),
    paceOut: $('pace-out'), distOut: $('dist-out'), daysOut: $('days-out'), ageOut: $('age-out'),
    wrap: $('demo-wrap'), card: $('demo-card'), art: $('d-art'), blob: $('d-blob'), initial: $('d-initial'),
    name: $('d-name'), flavour: $('d-flavour'), stats: $('d-stats'), serial: $('d-serial'), rarity: $('d-rarity'),
    rP: $('r-p'), rBand: $('r-band'), rStage: $('r-stage'), rFinish: $('r-finish'),
    pool: $('pool'), draw: $('draw')
  };

  var current = null;      // the animal currently shown
  var serials = {};        // a stable serial per animal for the life of the page

  function serialFor(name) {
    if (!serials[name]) serials[name] = 1 + (hash(name) % 900);
    return serials[name];
  }

  function paintArt(animal, stage) {
    var sizes = { baby: 70, young: 80, adult: 92 };
    els.blob.style.width = sizes[stage] + '%';
    els.initial.textContent = animal.name.charAt(0);
    els.initial.style.fontSize = (stage === 'baby' ? 18 : stage === 'young' ? 23 : 27) + 'cqw';

    // deterministic decorative dots, so the same animal always looks the same
    Array.prototype.slice.call(els.art.querySelectorAll('.card__dot')).forEach(function (d) { d.remove(); });
    var h = hash(animal.name), count = 2 + (h % 3);
    for (var i = 0; i < count; i++) {
      var d = document.createElement('span');
      d.className = 'card__dot';
      var s = 8 + ((h >> (i * 3)) % 14);
      d.style.width = d.style.height = s + 'px';
      d.style.left = (6 + ((h >> (i * 5)) % 80)) + '%';
      d.style.top = (8 + ((h >> (i * 7)) % 76)) + '%';
      els.art.appendChild(d);
    }
    // foil only on epic and above (DESIGN.md §3.3)
    var foil = els.art.querySelector('.card__foil');
    var wantsFoil = animal.rarity === 'epic' || animal.rarity === 'legendary';
    if (wantsFoil && !foil) {
      var f = document.createElement('div'); f.className = 'card__foil'; els.art.appendChild(f);
    } else if (!wantsFoil && foil) { foil.remove(); }
  }

  function paintPool(pool, drawn) {
    var total = pool.reduce(function (s, x) { return s + x.w; }, 0);
    els.pool.innerHTML = '';
    pool.slice().sort(function (a, b) { return b.w - a.w; }).forEach(function (entry) {
      var p = entry.w / total;
      var row = document.createElement('div');
      row.className = 'pool__row';
      row.setAttribute('data-drawn', String(entry.animal.name === drawn.name));
      var bar = document.createElement('div');
      bar.className = 'pool__bar';
      var fill = document.createElement('div');
      fill.className = 'pool__fill';
      fill.style.width = Math.max(4, p * 100) + '%';
      var label = document.createElement('div');
      label.className = 'pool__label';
      label.textContent = entry.animal.name + ' · ' + entry.animal.rarity;
      bar.appendChild(fill); bar.appendChild(label);
      var pct = document.createElement('div');
      pct.className = 'pool__p';
      pct.textContent = (p * 100).toFixed(1) + '%';
      row.appendChild(bar); row.appendChild(pct);
      els.pool.appendChild(row);
    });
  }

  function update(redraw) {
    var paceSec = Number(els.pace.value);
    var km = Number(els.dist.value);
    var days = Number(els.days.value);
    var age = Number(els.age.value);

    var vKmh = 3600 / paceSec;
    var p = perfIndex(vKmh, km, age);
    var band = speedBand(p);
    var stage = stageFor(km);
    var finish = finishFor(days);

    els.paceOut.textContent = fmtPace(paceSec) + ' /km';
    els.distOut.textContent = km.toFixed(1) + ' km';
    els.daysOut.textContent = String(days);
    els.ageOut.textContent = String(age);

    var pool = buildPool(band, km);
    if (redraw || !current || !pool.some(function (x) { return x.animal.name === current.name; })) {
      current = drawFrom(pool);
    }

    els.wrap.setAttribute('data-family', band);
    els.card.setAttribute('data-rarity', current.rarity);
    els.card.setAttribute('data-finish', finish);
    els.name.textContent = current.name;
    els.flavour.textContent = current.flavour;
    els.rarity.textContent = current.rarity.charAt(0).toUpperCase() + current.rarity.slice(1);
    els.stats.textContent = km.toFixed(1) + ' km · ' + fmtDur(km * paceSec) + ' · ' + fmtPace(paceSec) + '/km';
    els.serial.textContent = current.name.toUpperCase() + ' #' + pad(serialFor(current.name));
    paintArt(current, stage);

    els.rP.textContent = p.toFixed(2);
    els.rBand.textContent = band;
    els.rStage.textContent = stage;
    els.rFinish.textContent = finish;

    paintPool(pool, current);
  }

  if (els.pace) {
    ['pace', 'dist', 'days', 'age'].forEach(function (k) {
      els[k].addEventListener('input', function () { update(false); });
    });
    els.draw.addEventListener('click', function () { update(true); });
    update(true);
  }

  // ---------- reading progress ----------
  var progress = $('progress');
  function onScroll() {
    if (!progress) return;
    var h = document.documentElement;
    var max = h.scrollHeight - h.clientHeight;
    progress.style.width = (max > 0 ? (h.scrollTop / max) * 100 : 0) + '%';
  }
  document.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  // ---------- scrollspy ----------
  var links = Array.prototype.slice.call(document.querySelectorAll('.toc a'));
  if (links.length && 'IntersectionObserver' in window) {
    var byId = {};
    links.forEach(function (a) { byId[a.getAttribute('href').slice(1)] = a; });
    var visible = {};
    var obs = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { visible[e.target.id] = e.isIntersecting ? e.intersectionRatio : 0; });
      var best = null, bestRatio = 0;
      Object.keys(visible).forEach(function (id) { if (visible[id] > bestRatio) { bestRatio = visible[id]; best = id; } });
      links.forEach(function (a) { a.removeAttribute('aria-current'); });
      if (best && byId[best]) byId[best].setAttribute('aria-current', 'true');
    }, { rootMargin: '-72px 0px -55% 0px', threshold: [0, 0.25, 0.5, 1] });
    Object.keys(byId).forEach(function (id) { var el = document.getElementById(id); if (el) obs.observe(el); });
  }

  // ---------- typeface controller ----------
  const tfBtn = $('typeface'); if (tfBtn && window.Typeface) Typeface.bind(tfBtn);

  // ---------- theme ----------
  var btn = $('theme');
  function label() {
    var t = document.documentElement.getAttribute('data-theme');
    btn.textContent = t === 'dark' ? 'Light' : t === 'light' ? 'Dark' : 'Theme';
    btn.setAttribute('aria-label', 'Switch theme, currently ' + (t || 'matching your system'));
  }
  if (btn) {
    try {
      var saved = localStorage.getItem('fc-theme');
      if (saved) document.documentElement.setAttribute('data-theme', saved);
    } catch (e) { /* private mode or blocked storage: fall back to the system setting */ }
    label();
    btn.addEventListener('click', function () {
      var cur = document.documentElement.getAttribute('data-theme');
      var prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
      var next = cur ? (cur === 'dark' ? 'light' : 'dark') : (prefersDark ? 'light' : 'dark');
      document.documentElement.setAttribute('data-theme', next);
      try { localStorage.setItem('fc-theme', next); } catch (e) { /* not fatal */ }
      label();
    });
  }
})();
