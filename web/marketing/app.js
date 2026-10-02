/* Flying Cobra marketing: progressive enhancements. The page reads and works without this file.
   Motion weighting (design-motion-principles): Jakub for every enter and state change, Emil for the
   form (no animation), Jhey only inside scene.js. Everything here is a one-time enter or a response to
   a tap, never a loop. Reduced motion is handled in styles.css; this file only toggles classes. */
(function () {
  'use strict';

  /* Store links. Leave empty until the apps are live; the buttons then explain instead of jumping.
     When filled, every [data-store] button links out (MANUAL_TASKS.md section 11). */
  var STORE_LINKS = { ios: '', android: '' };

  var toast = document.getElementById('toast');
  var toastTimer = 0;
  function say(msg) {
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add('is-on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toast.classList.remove('is-on'); }, 3000);
  }

  document.querySelectorAll('[data-store]').forEach(function (a) {
    var key = a.getAttribute('data-store');
    if (STORE_LINKS[key]) { a.href = STORE_LINKS[key]; a.rel = 'noopener'; return; }
    a.addEventListener('click', function (e) {
      e.preventDefault();
      var store = key === 'ios' ? 'the App Store' : 'Google Play';
      say('Not in ' + store + ' yet. Your first run opens the bag soon.');
    });
  });

  /* Enter once when a block scrolls into view. */
  var revealed = document.querySelectorAll('[data-reveal]');
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add('is-in'); io.unobserve(en.target); } });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.15 });
    revealed.forEach(function (el) { io.observe(el); });
  } else {
    revealed.forEach(function (el) { el.classList.add('is-in'); });
  }

  /* How it works: the beat nearest the middle of the viewport drives the card (slide, hold, turn over).
     Duration-based transitions, so the flip never scrubs with scroll speed. */
  var how = document.getElementById('how');
  var beats = how ? Array.prototype.slice.call(how.querySelectorAll('.beat')) : [];
  if (how && beats.length && 'IntersectionObserver' in window) {
    var bo = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        var idx = en.target.getAttribute('data-beat-index');
        how.setAttribute('data-beat', idx);
        beats.forEach(function (b) { b.classList.toggle('is-on', b === en.target); });
      });
    }, { rootMargin: '-42% 0px -42% 0px', threshold: 0 });
    beats.forEach(function (b) { bo.observe(b); });
  } else if (how) {
    how.setAttribute('data-beat', '3');
  }

  /* Pace control: a radiogroup that swaps the animal in the 3D stage and the pick panel. */
  var FAMILIES = {
    gentle: { label: 'Gentle family', name: 'Star Tortoise', flavour: 'unstoppable', also: 'Hamster, Porcupine, Pangolin, Sloth Bear, Elephant' },
    calm:   { label: 'Calm family',   name: 'Cat',           flavour: 'curious and unbothered', also: 'Rabbit, Peacock' },
    steady: { label: 'Steady family', name: 'Chital',        flavour: 'the dappled wanderer', also: 'Nilgai, Dhole, Leopard' },
    swift:  { label: 'Swift family',  name: 'Cheetah',       flavour: 'the comeback sprinter', also: 'Chinkara, Horse, Blackbuck' }
  };
  var group = document.getElementById('pace');
  if (group) {
    var radios = Array.prototype.slice.call(group.querySelectorAll('[role="radio"]'));
    var pick = document.getElementById('pick');
    var stage = document.querySelector('[data-scene="pace"]');
    function choose(fam, focus) {
      var f = FAMILIES[fam]; if (!f) return;
      radios.forEach(function (r) {
        var on = r.getAttribute('data-family') === fam;
        r.setAttribute('aria-checked', on ? 'true' : 'false');
        r.tabIndex = on ? 0 : -1;
        if (on && focus) r.focus();
      });
      if (pick) pick.setAttribute('data-family', fam);
      if (stage) stage.setAttribute('data-family', fam);
      document.getElementById('pick-family').textContent = f.label;
      document.getElementById('pick-name').textContent = f.name;
      document.getElementById('pick-flavour').textContent = f.flavour;
      document.getElementById('pick-also').textContent = f.also;
      window.dispatchEvent(new CustomEvent('fc:pace', { detail: { family: fam } }));
    }
    radios.forEach(function (r, i) {
      r.tabIndex = r.getAttribute('aria-checked') === 'true' ? 0 : -1;
      r.addEventListener('click', function () { choose(r.getAttribute('data-family'), false); });
      r.addEventListener('keydown', function (e) {
        var d = (e.key === 'ArrowRight' || e.key === 'ArrowDown') ? 1 : (e.key === 'ArrowLeft' || e.key === 'ArrowUp') ? -1 : 0;
        if (!d) return;
        e.preventDefault();
        var next = radios[(i + d + radios.length) % radios.length];
        choose(next.getAttribute('data-family'), true);
      });
    });
  }

  /* Card river: native scroll-snap; these buttons page it for pointer and keyboard users. */
  var river = document.getElementById('river');
  document.querySelectorAll('[data-river]').forEach(function (b) {
    b.addEventListener('click', function () {
      if (!river) return;
      var dir = parseInt(b.getAttribute('data-river'), 10) || 1;
      var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
      river.scrollBy({ left: dir * Math.max(280, river.clientWidth * 0.8), behavior: reduce ? 'auto' : 'smooth' });
    });
  });

  /* Illustrations: approved art from the illustration pipeline replaces the family placeholder.
     The local runner writes workbench/art/manifest.json (production reads animals.art instead); only
     rows with status approved are used, so what the admin approves is exactly what the page shows. */
  var ART_BASE = '../../workbench/art/';
  fetch(ART_BASE + 'manifest.json', { cache: 'no-store' }).then(function (r) { return r.ok ? r.json() : null; }).then(function (m) {
    if (!m || !m.rows) return;
    document.querySelectorAll('.card[data-animal]').forEach(function (card) {
      var slug = card.getAttribute('data-animal'), stage = card.getAttribute('data-stage') || 'adult';
      var row = m.rows.find(function (x) { return x.slug === slug && x.stage === stage && x.status === 'approved' && (x.svg || x.png); })
             || m.rows.find(function (x) { return x.slug === slug && x.status === 'approved' && (x.svg || x.png); });
      if (!row) return;
      var art = card.querySelector('.card__art'); if (!art) return;
      var img = new Image();
      img.alt = ''; img.decoding = 'async'; img.className = 'card__img';   // no loading=lazy: a detached lazy image never loads
      img.onload = function () { art.innerHTML = ''; art.appendChild(img); art.classList.add('card__art--real'); };
      img.src = ART_BASE + (row.svg || row.png);
    });
  }).catch(function () { /* no pipeline output yet: the placeholder stays */ });

  /* Serial lookup: trim and go (the form also works natively). */
  var form = document.getElementById('lookup-form');
  var q = document.getElementById('q');
  if (form && q) {
    form.addEventListener('submit', function (e) {
      var v = q.value.trim();
      e.preventDefault();
      if (!v) { q.focus(); return; }
      window.location.href = 'verify.html?q=' + encodeURIComponent(v);
    });
  }
})();
