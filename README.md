# Pugmark

**Run. Get an animal. Collect India.** A jogging app for India where every run earns a collectible animal card with a database-issued serial number. No leaderboards, no rankings. Fun first.

- **Source documents** (the five originals by @amitesh, unedited): [docs/source/](docs/source/) — PRD, full context master record, build prompts, design presentation, marketing video treatment. The [index there](docs/source/README.md) says what each one drove, and audits the build against them.
- The math: [docs/ALGORITHMS.md](docs/ALGORITHMS.md) · Design system: [docs/DESIGN.md](docs/DESIGN.md) · Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · API: [docs/API.md](docs/API.md) · Progress: [docs/PHASES.md](docs/PHASES.md)
- **Things only Amitesh can do:** [MANUAL_TASKS.md](MANUAL_TASKS.md)

## Layout
```
supabase/migrations/   the whole game engine lives in Postgres (apply 0001 → 0009 in order)
supabase/functions/    verify page (Edge Function)
app/                   Flutter: player app + admin panel
web/marketing/         static marketing site + verify fallback
tools/dbtest/          PGlite test harness — `cd tools/dbtest && npm install && node test.mjs`
```

## Test the engine without any accounts
```bash
cd tools/dbtest && npm install && node test.mjs
```
Loads every migration into an embedded Postgres 18 and runs 39 end-to-end scenarios (personas, anti-cheat, exploration, pity, serials, RLS, account deletion).
