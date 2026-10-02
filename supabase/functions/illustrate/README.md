# `illustrate` — the illustration worker

Generates one original illustration per animal per growth stage, once, and stores it where every user reads it. Design note: `docs/illustration-pipeline.md`. Spec: `docs/source/Running-App-Illustration-Pipeline-PRD.md`.

```
supabase/functions/illustrate/
├── index.ts                 Edge Function (Deno): auth, Supabase adapters, run / enqueue / status
├── core/worker.mjs          the loop: claim → prompt → generate → QA → vectorise → store → complete / fail
├── core/agent.mjs           the Illustrator Agent: prompt composition, vision QA with Claude, retry decision, rejection reason
├── core/style.mjs           template filling ({animal_name} {stage_cues} {features}); retries append adjustments
├── core/vectorise.mjs       PNG → SVG (potrace posterise), sha-256 content hash
└── core/providers/          openai.mjs (gpt-image-1, default) · mock.mjs (procedural SVG, no key needed)
```

The same `core/` runs locally in Node: `node tools/illustrate/serve.mjs` uses PGlite and a filesystem bucket at `workbench/art/`, and serves the workbench with its Illustration Library wired to `/api/*`.

## Set the provider key (you do this once)

1. OpenAI Platform → **API keys** → **Create new secret key**. Copy it.
2. Optional, for the automated vision QA: Anthropic Console → **API keys** → create one.
3. In Terminal, from the project folder (needs the Supabase CLI, see MANUAL_TASKS §6):

```bash
supabase secrets set OPENAI_API_KEY=sk-...
```
```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

Keys never go in the repo or the apps. Without `ANTHROPIC_API_KEY` generation still works and QA is skipped (the row says so). Without `OPENAI_API_KEY` the function falls back to the mock provider, which proves the plumbing but is not art.

## Deploy and run

```bash
supabase functions deploy illustrate
```

Run **Generate missing** from the admin panel or the workbench, or call it directly with the service role key:

```bash
curl -X POST "https://YOUR-PROJECT.supabase.co/functions/v1/illustrate" -H "Authorization: Bearer YOUR-SERVICE-ROLE-KEY" -H "content-type: application/json" -d '{"action":"enqueue-missing"}'
```
```bash
curl -X POST "https://YOUR-PROJECT.supabase.co/functions/v1/illustrate" -H "Authorization: Bearer YOUR-SERVICE-ROLE-KEY" -H "content-type: application/json" -d '{"action":"run","passes":20,"batch":3}'
```

Each pass claims three rows; `passes: 20` processes up to sixty images in one call. Repeat until the summary reports `claimed: 0`. A daily pass via `pg_cron` + `pg_net` is in `0011_platform_illustrations.sql` (optional).

In plain language: once the key is in place, click **Generate missing**. The queue fills with one row per animal per stage. The worker takes a few at a time, asks the image model for a picture, has Claude check it is the right animal on a light background with no text, traces it to a vector, saves both files under a path that can never be overwritten, and marks it **pending review**. You approve the ones you like; approved art appears on cards. Rejected ones you can regenerate; the old file stays where it was.

## Change the style

Edit the template in the admin panel or the workbench (Illustration Library → Style template), preview on one animal, **Save as new version**. That inserts a new `style_templates` row and bumps the version; nothing existing is touched. New generations use the new version and land at new paths (`.../v2.png`). To re-illustrate everything in the new style, run **Generate missing** again: the unique constraint is per version, so every animal gets a fresh v2 slot while v1 stays live until you approve v2.

## Guarantees

- `UNIQUE (animal_id, growth_stage, variant, style_version)` — a second request for the same state is a database no-op.
- `illustrations_claim` uses `FOR UPDATE SKIP LOCKED` — concurrent workers never generate the same row; stale claims re-queue after ten minutes.
- Storage upload is `upsert: false` with a one-year immutable cache — a path is written once.
- Generation is never triggered by a user earning a card; `card_json.illustration` is a read of what already exists.
