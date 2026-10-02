# `workbench` — the Flying Cobra UX workbench

Every screen of the app, clickable inside a phone frame, with live control over animation and toast timing and the triggers that fire them. Runs on mock data. No backend, no GPS, no build step.

## Open it

From the project folder:

```bash
python3 -m http.server 8790
```

Then open **http://localhost:8790/workbench/** in a browser. Any static server works; it just has to serve the repository root, because the workbench reads `../design_system/` for tokens and components. Opening `index.html` directly from disk will not work (browsers block the JSON fetch).

**What you should see.** Three columns. Left: who is using it (the six seeded personas plus a brand-new account), the pages grouped by journey, and three conditions to toggle. Centre: a phone showing Arjun's Today tab with his Cheetah card, three filled streak dots and a "Start a run" button. Right: Today's properties, the simulate-run control, and the global settings.

## How to use it

| To… | Do this |
|---|---|
| Walk a journey | Click pages on the left, or tap inside the phone. Taps navigate exactly as the real app does. |
| See a screen's other states | Pick a state chip at the top of the right panel (empty / loading / error / screen-specific). |
| Tune a timing | Change a number on the right. The phone updates instantly. Values are kept in this browser. |
| Preview a trigger | Press **Fire** next to any animation or toast to see what that trigger does on this page, without walking the whole flow. |
| Earn a card on the web | Right panel → **Simulate a run**: pace, distance, start hour, location, flags → **Run it**. The real selection logic runs (age-graded pace → family, distance → scale, run-days → finish), then the reveal plays. **Show the bag** lists the pool with real probabilities. |
| Review a persona | Click a persona on the left. Their collection, streak, permissions and run history load. Meera's first card is a dawn bird, Priya has a migratory bird, Ravi has a weekly tiger waiting. |
| Test the hard states | Left panel → Conditions: reduced motion, location denied, offline. These are the states that go wrong in real apps. |
| Check the design system | Pages → Design system → **Living catalogue**: every token and every component, every variant and state. |
| Keep your changes | Right panel → **Download interaction-config.json**, then replace `workbench/interaction-config.json` in the repository. That file is the source of truth the production app reads. **Reset all** returns to the shipped defaults. |
| Change device | Top bar: iPhone, Android, Small. **App: light/dark** flips the app's theme independently of the workbench. **Reset to start** reloads the current persona at their first screen. |

## Files

| File | What |
|---|---|
| `index.html` | the three-column shell |
| `workbench.css` | the review chrome (neutral palette, so it never competes with the app) |
| `app.css` | screen layouts; components come from `../design_system/components.css` |
| `screens.js` | one renderer per screen ID from `docs/ux/SCREEN_IDS.md`; returns HTML; interactions are `data-act="verb:arg"` |
| `workbench.js` | state, navigation, the properties panel, triggers, simulate-run, persistence, export |
| `engine.js` | the selection formulas from `docs/ALGORITHMS.md` (age-grading, bands, stage, finish, weighted draw with pity) |
| `data.js` | mock data in the Phase 1 shapes: animals, the six personas, permissions, states |
| `catalogue.js` | renders the living catalogue from `../design_system/tokens.json` + `catalogue.json` |
| `interaction-config.json` | every tunable timing, toast and trigger, per screen. The export. |

## Add a page

1. Add the ID and title to `docs/ux/SCREEN_IDS.md` and describe it in `docs/ux/SCREEN_INVENTORY.md`.
2. In `screens.js`, add `S['my-screen'] = (st, W) => \`…html…\`` using components from the design system and `data-act` for interactions. Handle any new verbs in the `switch` in `workbench.js`.
3. In `workbench.js`, add the ID to the right journey in `JOURNEYS` and a title in `TITLES`; list its states in `STATES` if it has any.
4. In `interaction-config.json`, add a `screens["my-screen"]` block with its animations and toasts. The right panel builds itself from this block.

## Add a component

Add token-only CSS to `design_system/components.css` (no hex, no raw ms), behaviour if needed to `design_system/components.js`, and an entry to `design_system/catalogue.json` so it appears in the catalogue with its variants. See `design_system/README.md`.

## Why this is HTML and not Flutter web

The spec asks for Flutter web so screens carry straight into production. This machine has no Flutter SDK (see `MANUAL_TASKS.md` step 5), so the workbench is hand-written HTML, CSS and JavaScript that runs today. What carries into production is the part that matters for design decisions: `design_system/tokens.json` generates the Flutter theme, `interaction-config.json` is read by the Flutter reveal and celebration widgets, and every screen here is specified by ID in the same inventory the Flutter features implement. When the SDK is installed, the Flutter workbench shell is a wrapper around the existing widgets, reading the same two files.
