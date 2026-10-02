# Running App — Claude Code Prompts

How to use this file: start a Claude Code session in an empty folder, paste the **Kickoff prompt** first (attach or paste the PRD when it asks), then work through the phase prompts **one at a time, in order**. Finish and test each phase before pasting the next. If something breaks, use the fix-it prompt at the bottom.

---

## Kickoff prompt (paste first)

> You are going to build a complete app for me over several sessions. I am a designer with no coding experience, so you make all technical decisions, explain things simply, and never assume I can edit code myself.
>
> I'm giving you a PRD file (Running-App-PRD.md) — read it fully before doing anything. It describes a jogging app for India where every run earns a collectible animal card with a unique serial number. No leaderboards. Fun-first.
>
> Fixed technical decisions, do not change them: Flutter (one codebase for iOS, Android, web), Supabase backend (Postgres for users/animals/cards/serial numbers, Supabase Auth for accounts and admin login, Supabase Storage for card art). Serial numbers must be issued by the database so no two cards can ever share a number. Animal rules must be data-driven (stored in the database, editable from the admin panel), not hard-coded.
>
> We'll build in the 8 phases listed in section 12 of the PRD. Right now: set up the project skeleton, connect Supabase (walk me through creating the Supabase project step by step, including exactly what to click and which keys to copy), and confirm everything runs. Don't start Phase 1 features until the skeleton runs.

## Phase 1 — Record a run, issue a card

> Build Phase 1 from the PRD: record a run (GPS, pace, distance), issue one daily card with a database-issued serial number, and display the card on screen. Keep the card design simple for now — animal name, serial number, run stats. Set up the database tables you'll need long-term (users, animals, cards, runs) so we don't redo them later. When done, tell me exactly how to run it and what I should see.

## Phase 2 — Animal selection and growth

> Build Phase 2: the animal selection logic (speed picks the animal family, distance picks baby-to-adult scale), proper card templates (same animal + same tier = identical template, only the serial differs), baby-to-adult growth with consistency, and celebration moments ("Your cheetah is all grown up!"). Load the animal rules from the database, not hard-coded. Add a few test animals across fast and calm families.

## Phase 3 — Weekly cards, lottery, age-grading

> Build Phase 3: weekly cards (consistency 3/5/7 days, volume), the surprise layer (the run decides the pool, luck decides the animal from that pool), a pity timer that raises rare odds over time, and age-grading so older runners can earn top animals (age/gender optional, private, never shown on cards).

## Phase 4 — Geography and time of day

> Build Phase 4: regional/monthly animals tied to Indian states, exploration rewards (new route or zigzag in a familiar area = explorer animal; a run in a new location = that location's animal), time-of-day animals (night = owl, dawn = rooster/songbird), and migratory birds for running in different states over ~3 weeks. Enforce a minimum floor of about 1 km or 10 minutes at running pace so location animals can't be farmed from a vehicle.

## Phase 5 — Search, verify, share, encyclopedia

> Build Phase 5: the serial-number search (the ONLY search in the app — no searching people by name), a public verify web page reachable by QR code/short link without installing the app, shareable poster images for Instagram/WhatsApp stories (animal + serial, never the route map or start point), and the animal encyclopedia with each animal's real-world qualities.

## Phase 6 — Anti-cheat and consent

> Build Phase 6: the layered anti-cheat from PRD section 9 (GPS pace ceiling ~20–24 km/h, accelerometer/gyroscope footfall rhythm, platform activity classification, whole-run consistency, optional heart rate), and the privacy side from sections 10–11: granular purpose-specific permission requests via HealthKit/Health Connect, graceful degradation if only GPS + steps are granted, and the settings page as a trust centre.

## Phase 7 — Admin panel, dummy users, web build, marketing site

> Build Phase 7: the login-locked admin panel (every animal with illustration, name, encyclopedia qualities, rarity, and exact trigger parameters — all editable, driving the live rules), the six seeded dummy users from PRD section 12 so I can play before launch, the internal testing web build, and a simple public marketing website with app store links.

## Phase 8 — Polish and edge cases

> Build Phase 8: polish animations (card reveals, foil shimmer on rares, growth celebrations), handle GPS dropouts mid-run, handle strict/denied location permissions, and test the app end to end using the dummy users. Then give me a simple checklist of what I should manually test myself.

## When something is broken (fix-it prompt)

> Something isn't working. Here's what I did, what I expected, and what happened instead: [describe in your own words, paste any error text or a screenshot]. Please find the cause, fix it, and tell me in plain language what was wrong.

## When you want a change

> I want to change how something works: [describe the change]. Before coding, tell me briefly what you'll modify and whether it affects anything else, then do it.
