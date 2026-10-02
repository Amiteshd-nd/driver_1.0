# `design_system` — Flying Cobra design system

An independently reusable package. The production Flutter app, the admin panel, the marketing site, the verify page and the UX workbench all read from here. **One rule:** components read only from tokens. Adding a rarity, tier or finish is a new entry in `tokens.json`, never a new component.

```
design_system/
├── tokens.json         THE source of truth (colour, family, rarity, tier, finish, type, space, radius, elevation, motion, haptic, layout, icon)
├── build-tokens.mjs    node design_system/build-tokens.mjs → regenerates the two files below
├── tokens.css          generated custom properties for the web
├── tokens.dart         generated constants for Flutter
├── fonts/              Satoshi, self-hosted (woff2 + satoshi.css). Pages link this; no external font request.
├── components.css      the web components, token-only (card, button, chip, toast, sheet, list row, search field, stat tile, progress ring, celebration overlay, nav bar)
├── components.js       behaviour for the components that need it (card renderer, toast queue, reveal and celebration sequences, poster)
└── catalogue.json      what the living catalogue in the workbench shows: every token group and every component with its variants and states
```

## How the two platforms share one system

| Layer | Web | Flutter |
|---|---|---|
| Tokens | `tokens.css` (generated) | `tokens.dart` (generated) → copy to `app/lib/core/theme/generated_tokens.dart`; `tokens.dart` in `app/lib/core/theme/` consumes it |
| Components | `components.css` + `components.js` | widgets in `app/lib/features/card/widgets/` etc., built from the same token names |
| Patterns | `components.js` sequences, driven by `workbench/interaction-config.json` | the same durations read from `interaction-config.json` at build time (next step once Flutter is installed) |

The workbench is where timings are tuned; `interaction-config.json` is the export. When the Flutter SDK is installed, the Dart theme switches from its hand-maintained constants to the generated file, and the reveal/celebration widgets read their durations from the same JSON. Nothing in the design has to be re-decided.

## Adding things

**A new rarity (e.g. `mythic`):** add one entry under `rarity` in `tokens.json` with its border width, style, foil, particle count, reveal duration, haptic and draw weight → run the build → the card component, the reveal sequence and the catalogue all pick it up. No component changes.

**A new family:** one entry under `family` with bg / fg / accent / label → run the build → `[data-family='x']` scoping works everywhere.

**A new component:** add its CSS to `components.css` using only `var(--…)` tokens, add any behaviour to `components.js`, and add an entry to `catalogue.json` so it appears in the living catalogue with its variants and states. If you find yourself typing a hex colour or a millisecond value, stop and add a token instead.

## Checking consistency

The workbench's Catalogue page renders every token and every component in every variant and state, light and dark, side by side. That page is the review surface for the system: if two things look like they disagree, one of them is reading a non-token value.

```bash
node design_system/build-tokens.mjs
grep -nE '#[0-9a-fA-F]{3,8}|[0-9]+ms' design_system/components.css   # should print nothing
```
