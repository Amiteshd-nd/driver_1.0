/* Flying Cobra design system — typeface controller.
   One switch flips every surface: sets data-typeface on <html>, which tokens.css maps to --font-display/--font-text.
   Satoshi is self-hosted; the reserved "classic" pair (Fraunces + Manrope) is fetched from Google Fonts only when selected,
   so the default page makes no external font request. Persists the viewer's choice in localStorage. */
(function () {
  'use strict';
  const KEY = 'fc-typeface', DEFAULT = 'satoshi';
  const OPTIONS = { satoshi: 'Satoshi', classic: 'Classic (Fraunces + Manrope)' };
  const GOOGLE = 'https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,500;0,9..144,600;0,9..144,700;1,9..144,500&family=Manrope:wght@400;500;600;700&display=swap';
  function ensureClassicLoaded() {
    if (document.getElementById('fc-classic-fonts')) return;
    const l = document.createElement('link'); l.id = 'fc-classic-fonts'; l.rel = 'stylesheet'; l.href = GOOGLE; document.head.appendChild(l);
  }
  function get() { try { return localStorage.getItem(KEY) || DEFAULT; } catch (e) { return DEFAULT; } }
  function set(name) {
    if (!OPTIONS[name]) name = DEFAULT;
    if (name === 'classic') ensureClassicLoaded();
    document.documentElement.setAttribute('data-typeface', name);
    try { localStorage.setItem(KEY, name); } catch (e) { /* storage blocked: the attribute still applies for this page */ }
    window.dispatchEvent(new CustomEvent('fc:typeface', { detail: { typeface: name } }));
    return name;
  }
  function toggle() { return set(get() === 'satoshi' ? 'classic' : 'satoshi'); }
  /** Wire a button: shows the current typeface and flips on click. */
  function bind(button) {
    const paint = () => { const cur = get(); button.textContent = 'Type: ' + (cur === 'satoshi' ? 'Satoshi' : 'Classic'); button.title = 'Switch the whole product typeface. Now: ' + OPTIONS[cur]; };
    button.addEventListener('click', () => { toggle(); paint(); });
    window.addEventListener('fc:typeface', paint); paint();
  }
  set(get());   // apply the stored choice before first paint
  window.Typeface = { get, set, toggle, bind, OPTIONS };
})();
