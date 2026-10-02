# Running App — Illustration Pipeline Prompts

Paste into Claude Code with **Running-App-Illustration-Pipeline-PRD.md** attached. Do the prompts in order; test each before the next.

---

## Prompt 1 — Architecture and backend

> Read **Running-App-Illustration-Pipeline-PRD.md** fully. Act as a principal engineer, senior software architect and senior software engineer: before coding, write a short design note in `/docs/illustration-pipeline.md` confirming the data model, the unique constraint that makes duplicates impossible, the claim/retry flow, and which image-generation provider you recommend as the default (pick one with clear commercial-use terms and a simple API; tell me exactly how to get its key and where to paste it in Supabase secrets — I will do that part myself). Then build the backend: the `animal_illustrations` migration, the `animal-art` storage bucket and policies, the read view, the server-side worker with a provider adapter, atomic claiming, retries, the automated vision QA step, PNG-to-SVG vectorisation, and upload to the deterministic paths. Generation must be triggered on animal creation and by a "generate all missing" job, never when a user earns a card. Explain to me in plain language how to run it once the key is in place.

## Prompt 2 — Style template and Illustrator Agent

> Create the versioned style prompt template for a vector illustration: flat clean shapes, no photorealism, light background, subtle majestic effects (soft glow, gentle light rays, a little sparkle), single animal, centred, no text, no border, fully original — never mention brands, franchises or artists. Build the Illustrator Agent that composes each animal's prompt from this template plus the animal's name, distinctive features and growth-stage cues (baby: rounder, bigger head and eyes; adult: full proportions, confident stance), runs the QA check, retries with adjusted prompts, and writes a plain-language rejection reason when it fails. Generate the first three animals (cheetah, elephant, rabbit) in baby and adult states so I can judge the style, then stop and show me.

## Prompt 3 — Admin panel review

> Add an Illustration Library to the admin panel: a grid of every animal × growth stage × variant with the image, status, provider, attempts and cost, plus buttons for Generate missing, Regenerate, Approve and Reject. Only approved art goes live; everything else shows the per-family placeholder silhouette. Add a style-template editor with "Preview on one animal"; saving bumps the style version without touching existing art.

## Prompt 4 — Flutter app and workbench

> Build the Flutter illustration widget: shows the SVG when available, otherwise the PNG, otherwise the placeholder; caches by immutable URL; and layers rarity borders, foil and shimmer from the design system on top at render time rather than baking them into the image. Then wire the web prototype: add an Illustration Library page to the workbench mirroring the admin one, and make the card screens inside the phone frame load the real approved illustrations from Supabase Storage so I see exactly what users will see.

## Prompt 5 — Prove the dedup and finish

> Demonstrate deduplication: create a new animal in the admin panel, run generation, then request the same animal and stage again and show me that nothing new is created. Run "generate all missing" for every animal currently in the database and give me a summary — how many images, how many approved, how many failed and why, and total cost. Finish with a README covering the provider key, running the job, and changing the style.
