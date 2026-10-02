# Flying Cobra — Architecture

## One-paragraph shape

A thin Flutter client records a run and uploads **features, not raw sensor data**. A single Postgres function (`submit_run`) running inside Supabase decides everything that matters: eligibility, trust, which bag opens, which animal is drawn, the serial number, growth and celebrations. Clients, posters and the public verify page only ever read what that function wrote. Balance is data (`config`, `animal_rules`, `animals`), edited from the admin panel. Nothing game-critical is computed on the device, so a modified app cannot forge a card.

```
┌──────────────┐  submit_run(payload)   ┌───────────────────────────────────┐
│ Flutter app  │ ─────────────────────▶ │ Postgres (Supabase)               │
│ iOS/Android/ │ ◀───────────────────── │  submit_run_for → analyze_track   │
│ web + admin  │  card + celebrations   │   → trust_score → build_run_pool  │
└──────┬───────┘                        │   → pick_weighted → issue_card    │
       │ tables via RLS                 │  claim_pending_cards (weekly/mo)  │
       ▼                                │  lookup_serial (anon)             │
┌──────────────┐                        │  admin_* (is_admin)               │
│ Verify page  │  lookup_serial(q)      └───────────────┬───────────────────┘
│ Edge Function│ ◀──────────────────────────────────────┘
│ + static     │        Storage: card-art bucket (public read, admin write)
└──────────────┘
```

## Repository layout

| Path | What |
|---|---|
| `docs/ALGORITHMS.md` | Every formula and threshold, with reasoning. The spec the SQL implements. |
| `docs/DESIGN.md` | Design system, card anatomy, motion, IA, consent flow, copy voice, admin UX. |
| `docs/API.md` | Client ↔ database contract (RPCs, payloads, tables). |
| `docs/PHASES.md` | PRD phase tracker. |
| `supabase/migrations/0001…0009` | Schema → math → engine → config seed → animals seed → RLS → dummy users → platform (storage/cron) → account lifecycle. Apply in order. |
| `supabase/functions/verify` | Deno Edge Function rendering the public verify page with Open Graph tags. |
| `tools/dbtest` | PGlite harness + 39 end-to-end tests (`node test.mjs`). Runs without Supabase. |
| `app/` | Flutter app (player app + admin panel in one codebase). `CONTRIBUTING.md` is the module contract. |
| `web/marketing` | Static marketing site + static verify fallback. |
| `MANUAL_TASKS.md` | Everything only the owner can do (accounts, keys, SDK install). |

## Database design decisions

- **Serials:** one `animal_counters` row per animal; `UPDATE … RETURNING` inside the card-insert transaction. Row locks serialise concurrent issuance; `UNIQUE (animal_id, serial_no)` is the backstop; a failed insert rolls the counter back (tested). Counters never decrement, so a deleted account's serial stays reserved and the public lookup returns "not found".
- **Idempotency everywhere:** `runs (user_id, client_run_id)` unique; `cards (user_id, scope, period_key)` unique (period_key = run id | ISO week | month). Weekly/monthly issuance is safe to call repeatedly, so the app claims lazily on open and `pg_cron` is optional.
- **Privacy boundary in the schema:** the route lives in `run_tracks` (owner-only RLS), never joined into `cards.stats`. `card_json` is the only shape the public lookup returns, and it has no location, age, sex or health field.
- **Discovery-first in RLS:** players can read `animals` (encyclopedia) but not `animal_rules`; secret animals are invisible until earned.
- **Data-driven rules:** `animal_rules.predicates` is a small JSON predicate language evaluated by `rule_matches()`. Tiers (0 speed → 4 migratory) decide which bag opens; `first_time_guaranteed` + `repeat_probability` make discovery reliable the first time and surprising afterwards.
- **No PostGIS dependency:** geohash, haversine, bearing and NOAA sunrise are plain plpgsql, so the whole engine also runs in PGlite for tests.
- **Audit:** every change to animals, rules, config, seasons, regions and age factors lands in `rule_history` with the admin's uid.

## Client design decisions

- **Feature-first folders** (`app/lib/features/*`) over a shared `core/` (theme tokens, models, repos, router). Riverpod for state, go_router for navigation with a `StatefulShellRoute` for the four tabs.
- **Sensing stays on-device until summarised:** the recorder computes footfall rhythm ratio / RMS, activity fractions and HR mean/max, then discards raw samples. The server re-derives distance, cells, turns and time window from the downsampled track.
- **Offline-first submission:** payloads queue on disk and flush on resume; `client_run_id` makes retries safe.
- **Art pipeline:** `animals.art` holds Storage paths; until illustrations exist, a deterministic procedural placeholder renders from the slug so every surface (app, poster, verify page) agrees.
- **Foil** is a Flutter fragment shader driven by gyroscope tilt, time-only on web.

## Environments

| Surface | Where | Notes |
|---|---|---|
| iOS / Android | Flutter | needs Xcode / Android Studio (MANUAL_TASKS §5) |
| Internal web build | `flutter build web` | sensors degrade gracefully; admin panel lives here |
| Verify page | Supabase Edge Function `verify` | `supabase functions deploy verify --no-verify-jwt` |
| Marketing | any static host | `web/marketing` |

## Testing strategy

- Database: `tools/dbtest/test.mjs` — personas, anti-cheat scenarios, exploration flags, bonds/reset/mastery, pity math (Monte Carlo), serial uniqueness and rollback, lookup parsing, RLS, account deletion.
- Flutter: once the SDK is installed, `flutter analyze` then widget tests for `CollectibleCardView` and the recorder's feature extraction (pure Dart). Manual checklist in PHASES.md Phase 8.
