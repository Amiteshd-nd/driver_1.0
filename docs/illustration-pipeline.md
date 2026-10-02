# Illustration pipeline — design note

Spec: `docs/source/Running-App-Illustration-Pipeline-PRD.md`. This note confirms the architecture before the code, and records the decisions the spec left to engineering. Written 2 Oct 2026.

## The one sentence

Every animal gets one illustration per growth stage, generated once by a server-side worker, stored at an immutable path, approved by a human, and then served to every user who ever earns that card. The database makes duplicates impossible; the worker just fills slots.

## Data model (confirmed)

```
style_templates        version PK · template text · stage_cues · negative · qa_criteria · retry_adjustments · is_active
animal_illustrations   id · animal_id → animals · growth_stage (stage_t: baby|young|adult) · variant ('base') · style_version → style_templates
                       status (queued → generating → pending_review → approved | rejected | failed) · png_path · svg_path · content_hash
                       prompt_used · provider · model · seed · cost_cents · attempts · max_attempts · last_error · qa_notes
                       claimed_at · claimed_by · reviewed_by · reviewed_at
                       UNIQUE (animal_id, growth_stage, variant, style_version)      ← the dedup guarantee
animals                + current_style_version · illustration_status (none|partial|ready) · art mirrors the APPROVED paths per stage
```

**Why the constraint and not a check in code.** Two workers, an admin clicking twice, a retried HTTP call and a cron overlap are all the same event to the database: a second row for the same identity. `ON CONFLICT DO NOTHING` on enqueue makes every one of them a no-op, with no coordination and no race window. The stage set is the game's own `stage_t`, not the spec's `juvenile`, so one vocabulary serves cards and art.

**Storage.** Bucket `animal-art`, path `{slug}/{stage}/{variant}/v{style_version}.png` and `.svg`. A path is never overwritten (`upsert: false`, one-year immutable cache). A new style is a new version and therefore a new path; old art stays addressable for cards already on screen.

## Claim / retry flow (confirmed)

1. **Enqueue** is idempotent: `illustrations_enqueue(animal)` upserts three queued rows; a trigger calls it on animal insert; `illustrations_enqueue_missing()` calls it for every active animal. Return value is the number of *new* rows, so "nothing new was created" is observable, not inferred.
2. **Claim** is atomic: `illustrations_claim(batch, worker)` first re-queues claims older than ten minutes (a crashed worker), then takes `batch` queued rows with `FOR UPDATE SKIP LOCKED` and marks them `generating` with `attempts + 1`. Concurrent workers cannot collide.
3. **Generate → QA → store** happens in the worker (below). Success calls `illustrations_complete` → `pending_review`. Any failure calls `illustrations_fail`, which re-queues while `attempts < max_attempts` (default 3) and otherwise marks `failed` with the plain-language reason.
4. **Review.** `illustrations_review(id, approve|reject|regenerate)`. Approve mirrors the paths into `animals.art` and recomputes `illustration_status`. Regenerate re-queues with attempts reset and keeps the old paths until a new completion replaces them.

Tested in `tools/dbtest/illus.mjs` (11 scenarios): idempotent enqueue, constraint rejection, auto-enqueue on insert, atomic claim across two workers, stale re-queue, retry-then-fail, complete → approve → mirror, regenerate, `card_json` exposure, RLS.

## Worker (confirmed)

One module, `supabase/functions/illustrate/core/worker.mjs`, talks to the database and storage through two tiny interfaces, so the same code runs as a Supabase Edge Function (Deno) and as a local Node process over PGlite. A pass claims a small batch and, per row: compose prompt → provider → QA → vectorise → hash → upload → complete. Cost is accumulated on the row even when QA rejects, so the audit trail is honest.

**Illustrator Agent** (`core/agent.mjs`). Composes the prompt from the versioned template plus the animal's name, encyclopedia features and stage cues; attempts after the first append one retry adjustment each. Runs the vision QA with Claude (`claude-opus-5`, structured JSON verdict against the template's criteria, low effort because the judgement is simple) and writes the designer-readable reason into `qa_notes`. With no Anthropic key, QA is skipped and says so in the note.

**Vectorisation** (`core/vectorise.mjs`). Potrace posterisation, eight colours, suited to flat art. A trace with fewer than three paths is treated as failed and the PNG is kept; the client prefers SVG when present.

## Provider recommendation

**Default: OpenAI `gpt-image-1`.** Clear commercial-use terms (outputs are the customer's), a plain REST endpoint, strong instruction-following for "flat vector, light background, no text", square 1024 output, and quality tiers that map to cost. Recorded per row as `provider = openai`, `model = gpt-image-1`. The adapter is twelve lines; swapping to another provider is a new file in `core/providers/` and one environment variable.

**Also shipped: `mock`.** A deterministic procedural SVG per animal and stage, so the whole pipeline runs with no key at all. It is an emblem, not a depiction, and every row it produces says `provider = mock`.

**Getting the key (you do this).** OpenAI Platform → API keys → Create new secret key. Then, in Supabase: Project → Edge Functions → Secrets, or from Terminal:

```bash
supabase secrets set OPENAI_API_KEY=sk-... ANTHROPIC_API_KEY=sk-ant-...
```

`ANTHROPIC_API_KEY` is optional; without it generation still works and QA is skipped.

## When generation runs

Never on a user's critical path. Triggers are: animal insert (database trigger enqueues; a worker pass picks it up), the admin's **Generate missing** (enqueue RPC + function call), and a daily `pg_cron` pass. A card reveal reads `animals.art` or `card_json.illustration`, which is either an approved path or nothing, in which case the family placeholder renders.

## Open decisions recorded

- Particle counts and reveal timing are unaffected: rarity, foil and glow are overlays applied at render time, never baked into the image (spec §3). One illustration serves common and legendary alike.
- `variant` is reserved for seasonal art; nothing generates variants yet.
- The spec's `ready` status is folded into `pending_review` (ready-and-stored *is* awaiting review); the enum keeps `ready` for forward compatibility.
