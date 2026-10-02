/* Flying Cobra design system — component behaviour (web).
   Pure functions that return HTML strings or drive sequences. No framework.
   Timings come from an interaction config object (see workbench/interaction-config.json);
   defaults fall back to the motion tokens. Exposed as window.FC. */
(function () {
  'use strict';

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
  function hash(str) { let h = 2166136261; for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function pad4(n) { return String(n).padStart(4, '0'); }
  function fmtPace(sec) { return Math.floor(sec / 60) + ':' + String(Math.round(sec % 60)).padStart(2, '0'); }
  function fmtDur(sec) { const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = Math.round(sec % 60); return h ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`; }
  function fmtDate(d) { d = new Date(d); return d.getDate() + ' ' + ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.getMonth()] + ' ' + d.getFullYear(); }

  const PAW = `<svg viewBox="0 0 100 100" aria-hidden="true"><ellipse cx="19" cy="36" rx="10" ry="12"/><ellipse cx="39" cy="20" rx="10" ry="12"/><ellipse cx="61" cy="20" rx="10" ry="12"/><ellipse cx="81" cy="36" rx="10" ry="12"/><path d="M38 52h24q16 0 19 16l3 10q2 16-14 16H30q-16 0-14-16l3-10q3-16 19-16z"/></svg>`;

  /** Procedural placeholder art: deterministic per animal name (DESIGN.md §5). */
  function art(animal, tier) {
    const url = animal.artUrls && animal.artUrls[tier];
    if (url) return `<div class="card__art card__art--real"><img class="card__img" src="${esc(url)}" alt="" loading="lazy">${(animal.rarity === 'epic' || animal.rarity === 'legendary') ? '<div class="card__foil"></div>' : ''}</div>`;
    const h = hash(animal.name);
    const dots = [];
    const count = 2 + (h % 3);
    for (let i = 0; i < count; i++) {
      const s = 8 + ((h >> (i * 3)) % 14), l = 6 + ((h >> (i * 5)) % 80), t = 8 + ((h >> (i * 7)) % 76);
      dots.push(`<span class="card__dot" style="width:${s}px;height:${s}px;left:${l}%;top:${t}%"></span>`);
    }
    const foil = (animal.rarity === 'epic' || animal.rarity === 'legendary') ? '<div class="card__foil"></div>' : '';
    return `<div class="card__art">${dots.join('')}<div class="card__blob"><span class="card__initial">${esc(animal.name.charAt(0))}</span></div>${foil}</div>`;
  }

  /** The animal card. card = {animal:{name,slug,family,rarity,flavour}, serial, tier, finish, season, statsLine, verdict} */
  function card(c, opts = {}) {
    const a = c.animal;
    const tick = c.verdict === 'unverified' ? '<span class="card__tick card__tick--unverified" title="Unverified">◐</span>' : '<span class="card__tick" title="Verified">✓</span>';
    const label = c.verdict === 'unverified' ? 'unverified' : 'verified';
    const sem = `${a.name}, ${c.tier}, ${a.rarity}, serial ${c.serial}, ${label}`;
    return `<div class="card-slot${opts.tile ? ' card-slot--tile' : ''}" data-family="${esc(a.family)}">
      <div class="card" data-rarity="${esc(a.rarity)}" data-tier="${esc(c.tier)}" data-finish="${esc(c.finish || 'plain')}" role="img" aria-label="${esc(sem)}">
        <div class="card__cap"><span>${esc(c.season || 'Everyday')}</span><span class="card__rarity"><i></i>${esc(cap(a.rarity))}</span></div>
        ${art(a, c.tier)}
        <div class="card__body">
          <div class="card__name">${esc(a.name)}</div>
          <div class="card__flavour">${esc(a.flavour)}</div>
          ${opts.tile ? '' : `<div class="card__rule"></div><div class="card__stats">${esc(c.statsLine || '')}</div>`}
          <div class="card__serial"><span>${esc(a.name.toUpperCase())} #${pad4(c.serial)}</span>${tick}</div>
        </div>
      </div></div>`;
  }

  function cap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ''; }

  /** Toast queue: one at a time per host (hierarchy rule: never stack). */
  function toaster(host) {
    let timer = null;
    return {
      show({ text, title, ms = 2600, pos = 'bottom', dismiss = 'auto' }) {
        host.setAttribute('data-pos', pos);
        host.innerHTML = '';
        const el = document.createElement('div');
        el.className = 'toast'; el.setAttribute('role', 'status');
        el.innerHTML = `${title ? `<b>${esc(title)}</b>` : ''}<span>${esc(text)}</span>${dismiss !== 'auto' ? '<button aria-label="Dismiss">×</button>' : ''}`;
        host.appendChild(el);
        clearTimeout(timer);
        const leave = () => { el.classList.add('is-leaving'); setTimeout(() => el.remove(), 220); };
        if (dismiss === 'auto' || dismiss === 'both') timer = setTimeout(leave, ms);
        el.querySelector('button')?.addEventListener('click', leave);
        if (dismiss === 'tap' || dismiss === 'both') el.addEventListener('click', leave);
        return el;
      },
      clear() { clearTimeout(timer); host.innerHTML = ''; }
    };
  }

  /** Card reveal sequence (DESIGN.md §6). Returns a promise resolving when the face is shown.
      cfg: {shimmerMs, slideMs, pauseMs, flipMs, particles, reduced} */
  function reveal(mount, cardObj, cfg, onDone) {
    const c = Object.assign({ shimmerMs: 900, slideMs: 420, pauseMs: 300, flipMs: 600, reduced: false }, cfg);
    const rar = cardObj.animal.rarity;
    const particles = (rar === 'legendary' && !c.reduced) ? (c.particles ?? 24) : 0;
    mount.innerHTML = `<div class="overlay" data-family="${esc(cardObj.animal.family)}">
      <div class="overlay__shimmer">Reading your run</div></div>`;
    const ov = mount.querySelector('.overlay');
    const t0 = setTimeout(() => {
      ov.style.setProperty('--reveal-slide', c.slideMs + 'ms');
      ov.style.setProperty('--reveal-flip', c.flipMs + 'ms');
      ov.innerHTML = `<div class="flip ${c.reduced ? 'fade-in' : 'slide-up'}"><div class="flip__inner">
          <div class="flip__back">${PAW}</div>
          <div class="flip__face">${card(cardObj)}</div></div>
          <div class="particles"></div></div>
        <div class="overlay__text" id="reveal-caption"></div>`;
      const inner = ov.querySelector('.flip__inner');
      setTimeout(() => {
        inner.classList.add('is-flipped');
        setTimeout(() => {
          if (particles) {
            const host = ov.querySelector('.particles');
            for (let i = 0; i < particles; i++) {
              const p = document.createElement('i'); const ang = (i / particles) * Math.PI * 2, r = 90 + (i % 5) * 18;
              p.style.setProperty('--dx', Math.cos(ang) * r + 'px'); p.style.setProperty('--dy', Math.sin(ang) * r + 'px'); p.style.animationDelay = (i % 6) * 30 + 'ms';
              host.appendChild(p);
            }
          }
          onDone && onDone(ov);
        }, c.flipMs);
      }, c.slideMs + c.pauseMs);
    }, c.shimmerMs);
    return { cancel() { clearTimeout(t0); mount.innerHTML = ''; } };
  }

  /** Celebration overlay (growth / mastered / welcome back / discovery). */
  function celebration(mount, { kind, title, message, family, card: cardObj, ms = 2600 }, onDone) {
    mount.innerHTML = `<div class="overlay" data-family="${esc(family || 'calm')}">
      ${cardObj ? `<div class="fade-in" style="width:min(100%,236px)">${card(cardObj)}</div>` : ''}
      <div class="overlay__text fade-in"><b>${esc(title)}</b>${esc(message || '')}</div></div>`;
    const ov = mount.querySelector('.overlay');
    const done = () => { mount.innerHTML = ''; onDone && onDone(); };
    ov.addEventListener('click', done, { once: true });
    if (ms > 0) setTimeout(() => { if (mount.contains(ov)) done(); }, ms);
  }

  /** Share poster: 9:16, card + serial + QR mark. Never a map. */
  function poster(cardObj) {
    return `<div class="poster" data-family="${esc(cardObj.animal.family)}">
      <div style="width:70%">${card(cardObj)}</div>
      <div class="poster__serial">${esc(cardObj.animal.name.toUpperCase())} #${pad4(cardObj.serial)}</div>
      <div style="display:flex;gap:10px;align-items:center;width:100%;justify-content:space-between">
        <span class="poster__mark">flyingcobra.run</span><span class="poster__qr" aria-label="QR code to the verify page"></span></div></div>`;
  }

  window.FC = { esc, hash, pad4, fmtPace, fmtDur, fmtDate, card, art, toaster, reveal, celebration, poster, PAW, cap };
})();
