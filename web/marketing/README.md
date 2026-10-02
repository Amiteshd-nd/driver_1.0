# web/marketing

The public site (`index.html`) and the public verify page (`verify.html`). Static files, no build step.

## Run it

```bash
python3 -m http.server 8790
```

Open <http://localhost:8790/web/marketing/>. Fonts, tokens and Three.js all load from this repository, so it works offline. The page must be served over http (not opened as a file) because `scene.js` is an ES module.

## What is in here

| File | Role |
|---|---|
| `index.html` | Eight scenes; the script is in `docs/marketing/SITE_SCRIPT.md` |
| `styles.css` | Layout and motion on top of `design_system/tokens.css` |
| `app.js` | Store buttons, enter-once reveals, the sticky card beats, the pace control, the card river |
| `scene.js` | The Three.js layer: one renderer, three stages, procedural runner, animals and birds |
| `verify.html`, `verify.js`, `verify-config.js` | Serial lookup against Supabase (`lookup_serial`) |
| `../vendor/three/` | Three.js 0.186.1, pinned, via the page's import map |

## Change things

- **Store links.** `app.js` → `STORE_LINKS = { ios: '', android: '' }`. Fill both and every store button on the page links out; empty means a polite toast.
- **Copy.** Edit `index.html`. Rule for anything a visitor reads: no em-dashes. Check with `grep -n "—\|–" web/marketing/index.html` (should print nothing).
- **Which animal appears for a pace.** `scene.js` → `paceView` → `PICK`, and the matching text in `app.js` → `FAMILIES`.
- **Animal look.** `scene.js` → `ANIMALS` and `BIRDS` are plain spec objects (body size, leg length, colours, gait). Tweak numbers, reload.
- **Real 3D models later.** Keep the names. Copy `GLTFLoader.js` from the three tarball's `examples/jsm/loaders/` into `web/vendor/three/`, add `"three/addons/": "../vendor/three/"` to the import map, load the `.glb`, and return `{ group, legs: [], headPivot, tailPivot, spec }` from a builder so the animate functions still work (or play the model's own AnimationClip).
- **Reduced motion.** Everything freezes or crossfades under `prefers-reduced-motion`. Test it: macOS System Settings → Accessibility → Display → Reduce motion.

## Checks before publishing

1. Open in light and dark mode, at 375, 768 and 1280 px wide.
2. `grep -n "—\|–" web/marketing/*.html web/marketing/*.js` prints nothing.
3. Keyboard: Tab reaches every button, arrow keys move the pace control, the card river scrolls with the arrow buttons.
4. Minify `../vendor/three/*.js` (2.1 MB unminified) or bundle before a public launch.
