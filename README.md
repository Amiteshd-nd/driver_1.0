# Flying Cobra

**Run. Get an animal. Collect India.** A jogging app for India where every run earns a collectible animal card with a database-issued serial number. No leaderboards, no rankings. Fun first.

- **Source documents** (the five originals by @amitesh, unedited): [docs/source/](docs/source/) — PRD, full context master record, build prompts, design presentation, marketing video treatment. The [index there](docs/source/README.md) says what each one drove, and audits the build against them.
- The math: [docs/ALGORITHMS.md](docs/ALGORITHMS.md) · Design system: [docs/DESIGN.md](docs/DESIGN.md) · Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · API: [docs/API.md](docs/API.md) · Progress: [docs/PHASES.md](docs/PHASES.md)
- **Things only Amitesh can do:** [MANUAL_TASKS.md](MANUAL_TASKS.md)

## Design and review it before the backend
```bash
python3 -m http.server 8790
```
Open **http://localhost:8790/workbench/**: every screen clickable in a phone frame, timings and triggers tunable live, the design-system catalogue, and a simulate-run control that plays real card reveals. See [workbench/README.md](workbench/README.md). The design phase documents are in [docs/ux/](docs/ux/README.md). The marketing site is at **http://localhost:8790/web/marketing/** (script and storyboard: [docs/marketing/SITE_SCRIPT.md](docs/marketing/SITE_SCRIPT.md)).

## Layout
```
docs/ux/               personas, journeys, screen inventory, interaction spec
design_system/         tokens.json → tokens.css + tokens.dart; token-only components; catalogue
workbench/             the UX workbench (pages · phone · properties · Illustration Library), interaction-config.json
tools/illustrate/      local illustration pipeline: `node tools/illustrate/serve.mjs` (PGlite + mock provider + workbench)
supabase/migrations/   the whole game engine lives in Postgres (apply 0001 → 0009 in order)
supabase/functions/    verify page · illustrate worker (Edge Functions)
app/                   Flutter: player app + admin panel
web/marketing/         marketing site (Three.js stages, see docs/marketing/SITE_SCRIPT.md) + verify page
web/vendor/three/      Three.js 0.186.1, pinned and self-hosted
tools/dbtest/          PGlite test harness — `cd tools/dbtest && npm install && node test.mjs`
```

## Test the engine without any accounts
```bash
cd tools/dbtest && npm install && node test.mjs
```
Loads every migration into an embedded Postgres 18 and runs 39 end-to-end scenarios (personas, anti-cheat, exploration, pity, serials, RLS, account deletion).
