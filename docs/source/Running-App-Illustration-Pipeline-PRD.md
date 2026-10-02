# Running App — Animal Illustration Pipeline PRD

Oct 2, 2026 · Owner @amitesh

> Companion files: **Running-App-Illustration-Pipeline-Prompts.md** (prompts for Claude Code), **Running-App-PRD.md** (product), **Running-App-UX-Prototype-PRD.md** (workbench).

## 1. Purpose

Automatically generate one original vector-style illustration for every animal in every state the game needs, store it once, and serve that same illustration to every user who earns it. No hand-made images, no duplicates, no generation on the user's critical path.

## 2. Requirements

- **Style:** vector illustration (flat/clean shapes, no photorealism), light background, subtle "majestic" effects (soft glow, light rays, gentle sparkle). Fully original; never reference brands, franchises or named artists.
- **One illustration per state.** A state is the combination of animal + growth stage (+ variant where relevant). "Baby cheetah" is generated once; every user who earns a baby cheetah sees that same image.
- **Automatic.** Adding an animal in the admin panel is enough; illustrations are generated without anyone drawing or uploading.
- **Backend-owned.** Generation, storage and deduplication live in the backend. The Flutter app and the web prototype only read.
- **Visible in the workbench** so the designer can review every illustration and its status.

## 3. Key architecture decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Identity of an illustration | `(animal_id, growth_stage, variant, style_version)` with a **unique constraint** in Postgres | Makes duplicates impossible at the database level, not just by convention |
| When to generate | **Ahead of time** (on animal creation and via a batch "pre-warm" job), never when a user earns a card | A card reveal must never wait on an image model (slow, can fail) |
| Where to generate | A **server-side worker** (Supabase Edge Function or scheduled job) behind a provider adapter | Keys stay off devices; provider can be swapped |
| Image model | **Provider-agnostic adapter**; one default provider configured by API key | Image models change fast; the pipeline must not depend on one |
| Output format | Model produces **PNG**; pipeline also produces an **SVG via automatic vectorisation**; both stored | Image models output raster; vectorising gives true scalable assets. If vectorisation quality is poor for an animal, the PNG is used |
| Rarity / foil effects | **Not baked into the image.** Applied in-app as overlays from the design system | One illustration serves common and legendary alike; keeps the count low |
| Style consistency | A **locked, versioned style prompt template** (`style_version`) shared by every generation | Changing the style later creates a new version without overwriting old art |
| Human check | **Approval status** in the admin panel (`pending_review → approved / regenerate`) | AI output varies; the designer approves before art reaches users |

## 4. Data model (Postgres / Supabase)

**`animal_illustrations`**
- `id`
- `animal_id` → animals
- `growth_stage` (`baby`, `juvenile`, `adult` — from the game's growth tiers)
- `variant` (default `base`; later e.g. `seasonal_monsoon`)
- `style_version` (int)
- `status` (`queued`, `generating`, `ready`, `failed`, `pending_review`, `approved`, `rejected`)
- `png_path`, `svg_path` (Supabase Storage paths), `content_hash`
- `prompt_used`, `provider`, `model`, `seed`, `cost_cents`
- `attempts`, `last_error`, `claimed_at`, `created_at`, `updated_at`
- **UNIQUE** `(animal_id, growth_stage, variant, style_version)`

**Storage** bucket `animal-art`, deterministic paths:
`{animal_slug}/{growth_stage}/{variant}/v{style_version}.png` and `.svg`
Public-read, long cache headers (content is immutable per path).

**`animals`** gains `current_style_version` and an `illustration_status` summary for the admin list.

## 5. Generation flow

1. **Trigger:** an animal is created or edited in the admin panel, or the batch job runs ("generate all missing").
2. **Enqueue:** for each required `(stage, variant)` the system does an idempotent **upsert** into `animal_illustrations` with `status = queued`. The unique constraint means a second request for the same state is a no-op.
3. **Claim:** the worker atomically claims a `queued` row (`status = generating`, `claimed_at = now()`), so two workers cannot generate the same state. Stale claims (older than a timeout) are re-queued.
4. **Prompt build:** the Illustrator Agent composes the prompt from the **style template** + the animal's name + distinctive physical features + growth-stage cues (baby: rounder, larger head and eyes; adult: full proportions, confident stance) + "light background, soft majestic glow, vector illustration, no text, no border, centred, single animal".
5. **Generate:** call the provider adapter; receive PNG.
6. **QA pass (automated):** a vision check confirms it is the right species, a single animal, light background, no text or watermark, no realistic photo look. Failures retry with an adjusted prompt up to `max_attempts`, then mark `failed`.
7. **Post-process:** trim, normalise canvas size, vectorise to SVG, compute `content_hash`.
8. **Store:** upload PNG and SVG to the deterministic paths; set `status = pending_review`.
9. **Review:** designer approves or requests regeneration in the admin panel. Approved art becomes live.

A **placeholder silhouette** per animal family is shown anywhere an approved illustration does not yet exist, so the app never shows a broken image.

## 6. API surface (read side)

- `GET /illustrations/{animal_id}?stage=&variant=` → URLs for PNG and SVG plus status (served via a Postgres view / RPC, cached).
- Cards store a reference to the illustration row, not a copy of the file.

## 7. Frontend (Flutter app)

- Reads the illustration URL from the card payload; displays SVG when available, PNG otherwise, placeholder while loading or missing.
- Caches aggressively (immutable URLs).
- Rarity borders, foil and shimmer come from the design system and are layered on top at render time.

## 8. Web prototype (workbench)

- Add an **Illustration Library** page: a grid of every animal × stage × variant showing the image, status, provider, attempts, and buttons for *Generate missing*, *Regenerate*, *Approve*, *Reject*.
- Card screens in the phone frame use **real** illustrations from Supabase Storage (the mock data layer points at the real art), so the designer sees exactly what users will see.
- The style template is editable from the workbench with a *Preview on one animal* action; saving it bumps `style_version`.

## 9. The Illustrator Agent

A Claude Code sub-agent, run server-side as part of the pipeline, responsible for:
- Writing the per-animal prompt from the style template and the animal's encyclopedia facts.
- Running the automated QA check and deciding retry vs. fail.
- Writing a short, plain-language reason when it rejects an image, shown in the admin panel.

## 10. Operational concerns

- **Cost:** one-time per state. Roughly animals × stages × variants images (e.g. 60 animals × 3 stages = 180 generations). Tracked per row in `cost_cents`.
- **Secrets:** provider API key lives only in Supabase secrets, set by the designer manually; never in the repo or the apps.
- **Licensing:** choose a provider whose terms allow commercial use of outputs; record provider and model per image for the audit trail.
- **Rate limits:** worker processes a small batch at a time with backoff.
- **Immutability:** a path is never overwritten; regeneration bumps `attempts` and replaces the row's paths only after approval.

## 11. Deliverables

1. Migration for `animal_illustrations`, storage bucket, policies, and the read view.
2. Worker with provider adapter (one default provider), claim/retry logic, QA step, vectorisation, upload.
3. Versioned style prompt template and the Illustrator Agent.
4. Admin panel: Illustration Library with generate / regenerate / approve / reject.
5. Flutter illustration widget with SVG/PNG/placeholder handling and caching.
6. Workbench Illustration Library page and real art inside the phone frame.
7. README: how to set the provider key, run "generate all missing", and change the style.

## 12. Done when

The designer adds a new animal in the admin panel, waits, and sees its baby and adult illustrations appear in the Illustration Library for review; approves them; and then sees that exact art on a card inside the workbench phone frame. Requesting the same animal and stage again creates nothing new.
