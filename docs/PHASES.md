# Phase tracker (PRD §12)

Legend: ✅ built and tested · 🟡 built, awaiting Flutter SDK / Supabase keys to run · ⬜ not started

| Phase | PRD scope | Status | Where |
|---|---|---|---|
| 0 Kickoff | Flutter + Supabase skeleton, connect Supabase | 🟡 | `app/` scaffold, `MANUAL_TASKS.md` §1–5 |
| 1 | Record a run (GPS, pace, distance); issue one daily card with DB serial; basic card display; long-term tables | ✅ DB · 🟡 app | `0001_schema.sql`, `0003_engine.sql` (`submit_run`, `issue_card`), `features/run`, `features/card` |
| 2 | Speed → family, distance → scale, card templates, baby→adult growth, celebrations; rules from DB | ✅ DB · 🟡 app | `0002_math.sql` (`perf_index`, `speed_band`, `stage_for`), `update_bond`, `0005_seed_animals.sql`, `features/reveal` |
| 3 | Weekly cards (3/5/7), lottery pool + pity, age-grading | ✅ DB · 🟡 app | `issue_weekly_card_for`, `build_run_pool`, `pick_weighted`, `age_factor`, `claim_pending_cards` |
| 4 | Regional/monthly animals, exploration (new route/zigzag), new location, time of day, migratory birds, 1 km/10 min floor | ✅ DB · 🟡 app | `analyze_track`, `solar_events`, `time_window_of`, flags in `submit_run_for`, `issue_monthly_card_for`, regions seed |
| 5 | Serial search (only search), public verify page (QR/link), shareable posters, encyclopedia | ✅ DB · 🟡 app/web | `lookup_serial`, `supabase/functions/verify`, `web/marketing/verify.html`, `features/search`, `features/share`, `features/encyclopedia` |
| 6 | Anti-cheat layers; granular consent; graceful degradation; settings trust centre | ✅ DB · 🟡 app | `trust_score`, `features/onboarding`, `features/settings`, `0009_account.sql` (export/delete) |
| 7 | Admin panel (data-driven rules), seeded dummy users, internal web build, marketing site | ✅ DB · 🟡 app/web | `features/admin`, `0007_seed_dummy_users.sql`, `web/marketing` |
| 8 | Polish (reveals, foil, celebrations), GPS dropouts, strict location permission, end-to-end test, manual checklist | 🟡 | `assets/shaders/foil.frag`, recorder dropout handling; checklist below |

## UX prototype phase (added 2 Oct 2026, spec: docs/source/Running-App-UX-Prototype-PRD.md)

| Step | Deliverable | Status | Where |
|---|---|---|---|
| 1 Design phase | Personas, journeys, screen inventory, interaction spec, by product / UX / UI designer agents | ✅ | `docs/ux/` |
| 2 Workbench | Three columns: pages by journey · phone frame with every screen clickable · per-page properties (animations, toasts, triggers, Fire, state switcher) · simulate-run · persists and exports `interaction-config.json` · living catalogue | ✅ runs now (HTML/CSS/JS) | `workbench/` |
| 3 Design system | `tokens.json` → generated `tokens.css` + `tokens.dart`; token-only components; patterns; catalogue | ✅ | `design_system/` |

The spec asks for Flutter web. Without the SDK on this machine the workbench is hand-written web that runs today; the two files production consumes (`design_system/tokens.json`, `workbench/interaction-config.json`) are platform-neutral, so nothing decided in the workbench has to be re-decided when the Flutter shell is added.

## Illustration pipeline (added 2 Oct 2026, spec: docs/source/Running-App-Illustration-Pipeline-PRD.md)

| Prompt | Deliverable | Status | Where |
|---|---|---|---|
| 1 Architecture & backend | design note · `animal_illustrations` with UNIQUE (animal, stage, variant, style_version) · claim/retry RPCs · review · `animal_art` view · `card_json.illustration` · worker with provider adapter, QA, vectorisation | ✅ 11 PGlite tests | `docs/illustration-pipeline.md`, `0010_illustrations.sql`, `supabase/functions/illustrate/` |
| 2 Style template & Illustrator Agent | versioned template v1 · agent composes prompts, runs Claude vision QA, decides retry, writes reasons · first three animals generated (mock) | ✅ | `design_system/illustration-style.json`, `core/agent.mjs` |
| 3 Admin review | Illustration Library section with generate / regenerate / approve / reject and the style editor | 🟡 Flutter (uncompiled) | `app/lib/features/admin/illustrations_section.dart` |
| 4 Flutter widget & workbench | `AnimalArt` prefers SVG → PNG → placeholder; workbench Illustration Library + real approved art inside the phone | ✅ workbench · 🟡 Flutter | `workbench/library.js`, `tools/illustrate/serve.mjs` |
| 5 Dedup proof & README | create animal → rows appear once; second request creates none; generate-all summary | ✅ (mock provider) | `supabase/functions/illustrate/README.md` |

Real illustrations need the provider key (MANUAL_TASKS §7). Everything else is proven with the mock provider, whose rows are tagged `provider = mock` so they can never be mistaken for final art.

## What "🟡" means
The code exists but has not been compiled or run because this Mac has no Flutter SDK and no Supabase project yet. The first session after `MANUAL_TASKS.md` §1–5 are done should: run all migrations, `flutter pub get`, `flutter analyze`, fix compile errors, run on the iOS simulator, and walk the checklist below with the six dummy users.

## Decisions made while building (not in the PRD)
- **Home state is not a souvenir.** The first state a user runs in (or their chosen home region) becomes "home"; souvenirs are for other states. Otherwise every first run would be a regional card instead of a speed animal.
- **Variety stamps the weekly card, it does not change the bag.** Injecting explorer animals into the weekly pool made a 7-day week yield a jackal instead of a tiger.
- **Two run cards per day max** (config `limits.max_run_cards_per_day`); later runs still count for streaks and weekly volume.
- **Dawn/night are solar, not clock-based** (India spans ~2 h of sunrise under one timezone).
- **Trust verdicts are three-way**: verified / unverified (card from the speed bag only) / rejected (no card).
- **Re-earn = new card** (PRD open question, v1 answer); the collection shows count + best serial.
- **Age factors are an approximation of the WMA shape**, admin-editable, flagged as such.

## Open from the source documents

**Home region pride animal.** The design presentation lists "Home region · set once · an always-available regional pride animal"; the PRD does not, so it was not built. Today `profiles.home_region` only decides what is *not* a travel souvenir, and regional animals reach the player through the monthly card or a new-state souvenir. Adding it needs no code: one tier-0 `animal_rules` row per region, predicate `{"region_codes":["IN-XX"]}`, at a low weight so it seasons the everyday pool rather than crowding out the speed families. The open question is the weight, which is a balance call — try it in the admin Simulator first.

## Phase 8 manual test checklist (for Amitesh, after setup)
1. Sign in with a magic link; complete onboarding; decline Motion and Health; confirm the app still records a run with Location only.
2. Record a 1.2 km walk-jog outdoors. Expect: a card (calm or gentle family), stage baby, serial #0001 for that animal if nobody else earned it.
3. Record a 400 m stroll. Expect: "Recorded. A run of 1 km or 10 minutes earns a card." and no card.
4. Sign in as `kabir@flyingcobra.test`; open Collection. Expect: a night-family card (owl bag) from the seed.
5. Sign in as `ravi@flyingcobra.test`; open Today. Expect: a weekly card with radiant finish from last week; Collection shows it under "Weekly".
6. Sign in as `priya@flyingcobra.test`. Expect: a Kerala souvenir, a Goa souvenir and a migratory bird.
7. On any card, tap Share poster; confirm the PNG has the serial and QR, and no map. Scan the QR; the verify page shows the same card and "Earned by …".
8. Type `Horse #0003`, `horse 3` and a bogus `Tiger #9999` into Verify a card. Expect: found / found / "No such card … bluffing".
9. Settings → turn Location off → start a run → expect the graceful "timer-only" explanation. Turn it back on.
10. Settings → Export my data → confirm a JSON file is produced. (Do NOT run Delete on your real account; use a dummy.)
11. Admin → Simulator: band swift, 5 km, day → expect the swift pool with probabilities summing to 100%. Change `pity.n0` in Config and re-run with "as user" = a dummy uuid.
12. Airplane mode → finish a run → expect "Saved. We'll fetch your card when you're back online." → disable airplane mode → reopen → card reveal appears.
13. Walk under a bridge / indoors mid-run: GPS pill shows "Looking for GPS…", distance pauses, timer continues, run still submits.
14. Dark mode: every screen uses the dark tokens; card palettes still pass contrast.

## Marketing site rebuild (added 3 Oct 2026)

| Step | Deliverable | Status | Where |
|---|---|---|---|
| Skills | `ui-ux-pro-max`, `design-motion-principles`, `taste-skill` imported from `a7/two/cloud-march` with a local note | ✅ | `.claude/skills/` |
| Script | Creative director's script and storyboard: logline, design read, dials, cast, eight scenes, placeholders | ✅ | `docs/marketing/SITE_SCRIPT.md` |
| Site | Eight-scene page on the design-system tokens; sticky card reveal; pace control; card river; verify; privacy; download | ✅ runs now | `web/marketing/` |
| 3D | Three.js 0.186.1 vendored and pinned; one renderer, three scissor-rect stages; procedural runner, cheetah, chital, cat, star tortoise, rooster, eagle-owl; reduced-motion path | ✅ | `web/marketing/scene.js`, `web/vendor/three/` |
| Placeholders | Store links (`app.js` → `STORE_LINKS`), GLB models, card art, footer legal links | 🟡 user | `MANUAL_TASKS.md` §11 |
