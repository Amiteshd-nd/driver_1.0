# Running App — Full Context & Master Record

Oct 2, 2026 · @amitesh

Everything discussed, in one place. Paste this into a fresh chat to give it full context and memory of the project.

## Purpose of This Document

This is the complete master record of the Running App project. Paste it into a fresh chat to give that chat full context and memory of every decision made so far.

**Concept in one paragraph:** A playful jogging app for India where every run earns a collectible animal card. The animal matches how you ran, each card carries a unique serial number for scarcity and proof, and there are no leaderboards or rankings. It is fun-first: a growing, shareable collection that makes people want to run again.

## Core Concept & Principles

- Every run earns a collectible animal card: original art, unique serial number, run stats, a short flavour line ("Elephant, the tireless traveller"), and a set name ("Monsoon 2026").
- **Fun-first; no leaderboards or rankings.** Nobody is ranked above or below anyone.
- **The card is the hero.** Standard furniture (heat maps, calendar, pace over time) exists but stays in the background.
- **The card reflects the run, not the runner.** Different efforts earn different animals, never better and worse ones.
- **Dropped from v1:** brand sponsorships and vouchers.
- **Visual style:** the feel of a rare collectible card (foil, rarity borders, set names) but all art, layout, fonts and naming fully original to avoid trademark issues.

## The Animal System

**Three time scales:**
- **Daily** — how you ran today (speed, pace, distance, effort). Everyday animals: cheetah, horse, rabbit, hamster, cat.
- **Weekly** — the pattern of the week (consistency 3/5/7 days, volume, variety). Rare animals live here.
- **Monthly** — where you are. Regional animals: Kerala species, West Bengal species, camel for Rajasthan.

**Selection logic:** speed (age-graded) picks the animal *family*; distance picks the *scale* (baby to adult); consistency picks the *special finish* (glow, seasonal colour).

**Families, not tiers:** fast and slow are different kinds, not high and low. Elephant = endurance; tortoise = "Unstoppable"; wolf = "Pack Hunter". A fast runner having a light week gets a hamster or baby animal, because the card reflects the week.

**Growth & reset:** baby to adult with consistency, celebrated as an event. No re-babying on a break (a different animal shows instead); after ~2 months inactivity, animals reset to baby. Skipped weeks give no card at all, never an insulting one.

**Unlock the Wild:** once a user masters an animal, they graduate to rolling different rare species per run, keeping the late game fresh.

## Card Design Rules

- **Anatomy:** original animal art, unique serial number, run stats, short flavour line, set name.
- **Serial number** is the scarcity and proof mechanic. Tiger #0009 beats Tiger #4120, visible to all.
- **Same animal plus same tier = identical card template for everyone** — only the serial number differs.
- **Rarity cues:** foil/holographic shimmer and rarity borders on the rarest cards; cards grouped into collectible seasons by set name.
- **Fully original** art, layout, fonts and naming.

## Surprise Layer & Fairness

- **The run decides the pool; luck decides which animal from that pool.** Fast effort opens the fast bag (cheetah, falcon, horse); a gentle run opens the calm bag (rabbit, cat, owl, deer) — so a collector can run slowly on purpose to chase a rabbit.
- **Pity timer** raises rare odds the longer a user goes without one.
- **Age-grading** lets a 60-year-old and a 25-year-old both earn top animals for equivalent effort.
- **Age and gender** are optional, private, used only for age-grading, and never shown on the card.

## Exploration & Geography

- **New route / zigzag / untraced path** in a familiar area gives an explorer animal (e.g. fox).
- **A single run in a new location** gives that location's animal (a travel souvenir).
- **Migratory birds** are the prestige prize: running across different geographies (likely state level) over about 3 weeks.
- **Time of day:** night runs give an owl; dawn gives a rooster or songbird.
- **Minimum floor** (about 1 km or 10 minutes at running pace) so location animals cannot be farmed from a train or car.
- The app may gently nudge when a user is somewhere new, warmly and without spam.

## Verification, Search, Sharing & Trust

- **One search field only: serial-number lookup.** No searching people by name. Type a serial (Tiger #0427) and see that one card — animal, number, who earned it, when.
- **Trust / anti-forgery:** anyone can Photoshop or AI-generate a card image, but cannot fake a serial number living in the database. In there = real; not = bluffing.
- **Shareable posters** for Instagram and WhatsApp stories with a QR code or short link to a simple public verify page — no app download needed. This is the growth loop.
- **Safety:** posters and verify pages never show the route map or start point, to avoid leaking a home address.

## Anti-Cheating & Data Parameters

**Anti-cheating (layered):** GPS pace sanity ceiling (~20-24 km/h); accelerometer and gyroscope footfall rhythm (vehicles are too smooth, cycling gives itself away); platform activity classification (iOS Core Motion, Android Activity Recognition); consistency across the whole run; optional heart rate from a watch (hardest to spoof).

**Data via Apple HealthKit (iOS) and Google Health Connect (Android).**
- **Keep (v1):** GPS location/route, speed/pace, distance, steps/cadence, accelerometer/gyroscope, system activity class, elevation, time of day, heart rate, optional age/gender.
- **Drop (v1):** HRV, VO2 max, running power, stride length, ground contact time, sleep, skin temperature, SpO2, resting heart rate.
- The app must **degrade gracefully** if only GPS and steps are granted.

## Privacy & Consent

- **Granular, purpose-specific consent** — each permission explains exactly why it is needed.
- **Data minimisation** — only what the animal logic actually needs.
- **India DPDP compliance.**
- Permission-granting may itself be gamified (rare "fully connected" animals), but never at the cost of genuine, informed consent.

## App Architecture

- **Passive / read-only app:** permissions granted once, recording automatic, essentially zero user input.
- **Standard running furniture** (heat maps, calendar, pace over time) present but the animal is the hero.
- **Settings page = the trust centre:** granular permissions, purpose explanations, notifications, home region.
- **Edge cases to handle:** GPS dropouts, always-on location strictness.

## Tech Stack & Surfaces

- **Flutter** — one codebase for iOS, Android and web; chosen for heavy animation needs (card growth, foil shimmer, celebrations).
- **Backend: Supabase** — Postgres (users, animals, cards, serial numbers all linked), built-in Auth (including admin login), Storage (card art). Postgres chosen for reliable exact serial-number counting so no two cards share a number. Firebase was rejected. User accounts live in Supabase Auth.
- **Five surfaces:** iOS app, Android app, internal testing web build, public marketing website (info + store links), and an admin panel (web, login-locked) listing every animal with illustration, name, encyclopedia qualities, rarity and exact trigger parameters.
- **Rules are data-driven from the admin panel** so balance can be retuned without touching code.
- **Seeded dummy users** for pre-launch play, one per use case: fast young sprinter (cheetah), older endurance runner (elephant), 7-day-streak consistency runner, traveller unlocking a regional animal, night-owl runner, and a collector deliberately running slow for a rabbit.

## Open Questions & Deliverables

**Open questions:**
- Duplicate cards versus a single levelling card when the same animal is earned twice (deferred; v1 suggestion is nothing happens on re-earn).
- The exact definition of "different geography" for migratory birds (state level assumed).

**The five deliverable files:**
1. The phased PRD — "Running App — PRD (Animal Card Collectible)".
2. The design presentation — "Running App — Design Presentation (Animal Card Collectible)".
3. The director's marketing video treatment — "Running App — Director's Marketing Video Treatment".
4. This full context and master record.
5. The Claude Code prompts file — "Running App — Claude Code Prompts" (phase-by-phase prompts to build the PRD).
