# Flying Cobra — Tech Stack

Written 2 Oct 2026. Every choice here, and the reason it was made. Versions are the ones pinned in `app/pubspec.yaml`, `tools/dbtest/package.json` and `supabase/functions/verify/deno.json`.

---

## The shape in one line

A thin Flutter client records a run and uploads **summarised features, never raw sensor data**. One Postgres function decides everything that matters. Clients only read what it wrote.

```
Flutter (iOS · Android · web)
        │ submit_run(payload)
        ▼
Supabase · Postgres        ← the game engine: eligibility, trust, pool, draw, serial, growth
        │                     Auth (accounts + admin) · Storage (card art)
        ├─ Edge Function ──▶ public verify page (Open Graph previews)
        └─ RLS ────────────▶ every table, owner-scoped
```

---

## Fixed decisions (from the build prompts, not to be changed)

| Decision | Consequence for everything else |
|---|---|
| Flutter, one codebase | iOS, Android, internal web build and the admin panel all ship from `app/`. |
| Supabase (Postgres, Auth, Storage) | Postgres row locking gives exact, gap-free serial numbers. Firebase was rejected for this reason. |
| Serial numbers issued by the database | No client path can mint one. A forged card fails the public lookup. |
| Animal rules are data, not code | Rebalancing the game is an admin-panel edit, never a release. |

---

## Backend

| Component | Technology | Version | Why this |
|---|---|---|---|
| Database | PostgreSQL via Supabase | 15+ (tested on 18) | Transactional counters make serials exact. Relational joins keep users, animals, cards and serials consistent. |
| Game logic | plpgsql stored functions | — | Runs server-side, so a modified app cannot forge a card. Also lets the whole engine run inside a test sandbox. |
| Auth | Supabase Auth | — | Email magic link, Apple, Google. Admin is a flag on the profile row, enforced in policy, not in app code. |
| File storage | Supabase Storage | — | Bucket `card-art`, public read and admin write, so posters and the verify page can load art without a session. |
| Verify page | Deno Edge Function | Deno runtime, strict TS | Server-rendered HTML with Open Graph tags, so a shared link previews the card inside WhatsApp and Instagram before anyone taps. |
| Scheduling | pg_cron | optional | Closes weekly and monthly periods. Optional because the app also claims them lazily on open, idempotently. |

**Deliberately not used.** PostGIS: geohashing, haversine, bearing and sunrise are implemented in plain plpgsql, which removes an extension dependency and lets the engine run in the WebAssembly test harness. An ORM: the schema is the contract and the functions are the API. A separate application server: there is nothing it would do that the database does not already do closer to the data.

---

## Client — Flutter

| Purpose | Package | Version |
|---|---|---|
| Framework | Flutter / Dart | 3.24+ / 3.5+ |
| Backend client | `supabase_flutter` | ^2.8.0 |
| State management | `flutter_riverpod` | ^2.6.1 |
| Navigation | `go_router` | ^14.6.0 |
| Config | `flutter_dotenv` | ^5.2.1 |
| Local prefs | `shared_preferences` | ^2.3.3 |
| Offline queue files | `path_provider` | ^2.1.5 |
| IDs | `uuid` | ^4.5.1 |
| Dates and numbers | `intl`, `collection` | ^0.19.0, ^1.18.0 |

**No code generation anywhere.** Models are hand-written and tolerant of missing keys. This keeps the source readable and hand-editable, and removes a build step that would otherwise have to run before the project compiles.

### Sensing — one package per consent purpose

| Signal | Package | Version | What it feeds |
|---|---|---|---|
| GPS track | `geolocator` | ^13.0.2 | distance, pace, route novelty, state |
| Accelerometer | `sensors_plus` | ^6.1.1 | footfall rhythm (anti-cheat), card tilt |
| Steps | `pedometer` | ^4.0.2 | stride and cadence checks |
| Heart rate, workouts | `health` | ^11.1.0 | effort, strongest anti-cheat signal |
| Activity class | `flutter_activity_recognition` | ^4.0.0 | confirms running, catches vehicles |
| Place name | `geocoding` | ^3.0.0 | on-device state lookup, no third-party API |
| Permissions | `permission_handler` | ^11.3.1 | the granular consent flow |

The mapping is deliberate: each package backs exactly one purpose in the consent screen, so declining one degrades one feature instead of breaking the app. With location alone, a run still earns a card.

### Visual

| Purpose | Package | Version |
|---|---|---|
| Type | Satoshi, bundled (`assets/fonts/`); `google_fonts` kept only for the admin JSON monospace | ^6.2.1 |
| Motion | `flutter_animate` | ^4.5.0 |
| Charts | `fl_chart` | ^0.69.2 |
| QR codes | `qr_flutter` | ^4.1.0 |
| Sharing | `share_plus` | ^10.1.2 |
| Remote images | `cached_network_image` | ^3.4.1 |
| Links | `url_launcher` | ^6.3.1 |
| Foil shimmer | GLSL fragment shader | `assets/shaders/foil.frag` |

The foil is a real shader, not an image overlay: a hue-rotating band whose angle follows device tilt, falling back to a slow time drift where there is no gyroscope. It fails silently to no foil if the shader cannot load.

---

## Web

| Surface | Stack | Why |
|---|---|---|
| Marketing site | Hand-written HTML, CSS, JavaScript | No framework and no build step. Deploys to any static host and stays editable by hand. |
| Verify fallback | Same, plus one `fetch` to the lookup function | Works even if the Edge Function is not deployed yet. |
| Design document | Hand-written HTML, CSS, JavaScript | Same reasoning. See `web/design-doc/`. |

No bundler, no `node_modules`, no transpile step anywhere in `web/`. Satoshi is self-hosted from `design_system/fonts/` with a system fallback, so a blocked CDN degrades to readable rather than broken.

---

## Testing

| Tool | Version | What it does |
|---|---|---|
| PGlite | ^0.5.8 | PostgreSQL compiled to WebAssembly, run inside Node |
| Node | 24 | the test runner |

PGlite is the reason the engine could be built and proven on a machine with no Supabase project, no Docker and no Postgres install. It loads every migration into an in-memory Postgres and runs forty end-to-end scenarios: the six personas, vehicle rejection, GPS-only degradation, exploration detection, bond growth and reset, pity-timer distribution, serial uniqueness under failure, lookup parsing, row-level security and account deletion.

```bash
cd tools/dbtest && npm install && node test.mjs
```

---

## What the machine needs

| Already present | Still required (see MANUAL_TASKS.md) |
|---|---|
| Node, npm, git | Flutter SDK |
| Xcode Command Line Tools | Xcode (iOS builds) |
| | Android Studio (Android builds) |
| | A Supabase project |
| | Supabase CLI, for the verify function |

The database layer and both web surfaces are complete and verified without any of the missing items. Only the Flutter app is waiting on them.
