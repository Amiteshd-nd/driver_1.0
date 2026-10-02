# Running App — PRD (Animal Card Collectible)

Oct 2, 2026 · Owner @amitesh

> Companion file: **Running-App-Claude-Code-Prompts.md** contains the ready-to-paste prompts for building this PRD with Claude Code, phase by phase.

## 1. Overview & Vision

A playful jogging app for India where every run earns a collectible animal card. Fun-first, no leaderboards, no rankings. The animal card is the hero product; standard running stats (distance, pace, calendar, heat map) are supporting furniture. The emotional promise: running gives you something delightful to collect, grow, and share — never a number that makes you feel slow.

The card a user earns reflects *how they ran*, not *who they are*. A fast sprint and a gentle amble earn different animal families, not better and worse scores. Slow is never shame.

## 2. Product Principles

- **Passive / read-only.** The user grants permissions once; the app records runs automatically. Essentially zero manual input.
- **Discovery-first.** Mechanics are never explained upfront. Users discover how parameters map to animals by playing. Hint at rewards existing, never the recipe.
- **Fun over competition.** No leaderboards, no ranking people against each other.
- **Trust through serial numbers.** Every card has a unique, database-issued serial number that cannot be forged.
- **Privacy by design.** Granular, purpose-specific consent; collect only what is used; India DPDP-aware.

## 3. The Animal System (core logic)

Three time scales, each telling a different story:

- **Daily card** — how you ran today. Speed, pace, distance, effort of a single run. Everyday animals (cheetah, horse, rabbit, hamster, cat).
- **Weekly card** — the pattern of the week. Consistency (3/5/7 days), total volume, variety (new route or location). Rare animals live here.
- **Monthly card** — where you are. Regional/geographic animals (Kerala species, West Bengal species, camel for Rajasthan).

**Selection logic:**

- **Speed (age-graded)** picks the animal *family*.
- **Distance** picks the *scale* (baby to adult).
- **Consistency** picks the *special finish* (glow, seasonal colour).

**Growth & reset:**

- Animals grow baby to adult with consistency; growth moments are celebrated ("Your cheetah is all grown up!").
- No re-babying on a break — a different animal is shown instead. After about 2 months of inactivity, animals reset to baby.
- Skipped weeks produce no card at all, never an insulting one.
- **Unlock the Wild:** once a user masters an animal, they graduate to rolling different rare species per run, preventing late-game boredom.

## 4. Card Design Rules

- **Same animal + same tier = identical card template for everyone.** Only the serial number differs, so two runners instantly see they are on equal footing.
- Card contents: original animal art, unique serial number, run stats, a short flavour line (e.g. "Elephant, the tireless traveller"), and a set name (e.g. "Monsoon 2026").
- Visual style: the *feel* of a rare collectible card — foil/holographic shimmer on the rarest, rarity borders — but art, layout, fonts, and naming are fully original to avoid any trademark issue.
- Serial number is the scarcity and proof mechanic (Tiger #0009 beats Tiger #4120).

## 5. Surprise / Lottery Layer

Not pure luck. **The run decides the pool; luck decides which animal from that pool.** A fast effort opens the fast-animals bag (cheetah, falcon, horse); a gentle run opens the calm bag (rabbit, cat, owl, deer). This lets a collector deliberately run slowly to chase a rabbit.

A **pity timer** raises the odds of a rare the longer a user goes without one, to avoid frustration.

**Exploration triggers:**

- New route, zigzag, or untraced path in a familiar area gives an explorer animal (e.g. fox).
- A single run in a new location gives that location's animal (a travel souvenir).
- **Migratory birds** are the prestige prize: running across different geographies (likely state-level) over about 3 weeks.
- **Time of day:** night runs earn an owl, dawn runs a rooster or songbird.
- A **minimum distance/duration floor** (about 1 km or 10 minutes at running pace) stops farming location animals from a train or car.

## 6. Fairness & Age-Grading

**Age and gender** are used purely for age-grading, so a 60-year-old and a 25-year-old can both earn top animals for an equivalent effort. These inputs are optional, private, and never shown on the card.

Speed families are different *kinds* of animal, not high/low tiers: elephant = endurance/majestic, tortoise = "Unstoppable", wolf = "Pack Hunter". A fast runner having a light week gets a hamster or baby animal, and that is fine — the card reflects the week, not the person.

## 7. Animal Encyclopedia

A searchable in-app database: every animal with its majestic real-world qualities (e.g. elephants walk up to 50 miles a day). This is the mechanism that removes any sense of shame from "slow" animals and adds educational charm. Possible undocumented secret animals act as easter eggs.

## 8. Verification, Search & Sharing

- **One search field only: serial-number lookup.** No searching people by name. A user types a serial number (e.g. Tiger #0427) and sees that single card as confirmation — animal, number, who earned it, when.
- This is the **trust mechanism**: anyone can fake a card image or AI-generate one, but they cannot fake a serial number that lives in the database. If it is in there, it is real; if not, someone is bluffing.
- Shareable poster for Instagram/WhatsApp stories showing animal and serial number, with a QR code / short link opening a simple public verify page — no app download needed, which becomes the growth loop.
- Posters and share pages never show the route map or start point (home-address leak risk).

## 9. Anti-Cheating

Layered defence:

- **GPS pace sanity ceiling** — nobody sustains more than about 20–24 km/h.
- **Accelerometer/gyroscope footfall rhythm** — running has a distinctive bounce; vehicles are too smooth; cycling gives itself away with effortless high speed.
- **Platform activity classification** — iOS Core Motion, Android Activity Recognition.
- **Consistency across the whole run**, not just segments.
- **Heart rate from a watch** (optional) — hardest to spoof; real runs raise heart rate, car rides do not.

## 10. Data Parameters (Keep / Drop)

Sources: Apple HealthKit (iOS) and Google Health Connect (Android) — one integration each covers most watches and bands.

| Parameter | Source | Keep/Drop | Purpose |
| --- | --- | --- | --- |
| GPS location/route | Phone | Keep | Pace, distance, new-route & location detection |
| Speed / pace | Phone | Keep | Picks animal family |
| Distance | Phone | Keep | Picks animal scale |
| Steps / cadence | Phone | Keep | Running-rhythm verification |
| Accelerometer / gyroscope | Phone | Keep | Anti-cheat footfall rhythm |
| System activity class | Phone | Keep | Confirms running |
| Elevation | Phone | Keep | Effort context |
| Time of day | Phone | Keep | Night/dawn animals |
| Heart rate | Watch | Keep | Effort + anti-cheat |
| Age / gender | User (optional) | Keep | Age-grading only; never shown |
| HRV, VO2 max, running power, stride, ground contact | Watch | Drop (v1) | Not yet used; revisit later |
| Sleep, skin temp, SpO2, resting HR | Watch | Drop (v1) | Not needed for card logic |

The app must degrade gracefully if only GPS and steps are granted.

## 11. Privacy & Consent

- **Granular, purpose-specific consent** — each data type requested separately, with a plain-language reason, not one blanket agreement.
- **Data minimisation** — collect only what card logic uses.
- Permission-granting may itself be **gamified**: users who connect more data unlock rare "fully connected" animals — without crossing into data hoarding.
- **Settings = the trust centre:** granular permission control, what each data type is used for, notifications, home region.
- India DPDP law is a design constraint throughout.

## 12. Tech Stack, Surfaces & Build Phases

**Stack:** Flutter (one codebase for iOS, Android, web) — chosen for heavy animation and visual needs (card growth, foil shimmer, celebrations). **Backend: Supabase** — Postgres (users, animals, cards, serial numbers all linked), built-in Auth (including admin login), and Storage (card art). Postgres gives reliable exact serial-number counting so no two cards share a number.

**Surfaces:**

1. iOS app
2. Android app
3. Internal testing web build (user tests here first)
4. Public marketing website (info plus App Store / Play Store links)
5. Admin panel (web, login-locked) — master list of every animal: illustration, name, encyclopedia qualities, rarity, and exact trigger parameters (speed band, distance, consistency, region, time of day). Rules are data-driven from this panel so balance can be retuned without touching code.

**Seeded dummy users** for pre-launch play, one per use case: fast young sprinter (cheetah), older endurance runner (elephant), 7-day-streak consistency runner, traveller unlocking a regional animal, night-owl runner, collector deliberately running slow for a rabbit.

**Build phases (start simple):**

1. **Phase 1:** Flutter + Supabase skeleton; record a run (GPS, pace, distance); issue one daily card with serial number; basic card display.
2. **Phase 2:** Animal selection logic (speed family, distance scale), card templates, growth baby-to-adult, celebration moments.
3. **Phase 3:** Weekly cards, consistency, surprise/lottery pool plus pity timer, age-grading.
4. **Phase 4:** Regional/monthly animals, exploration (new route, new location), time-of-day, migratory birds.
5. **Phase 5:** Serial-number search, QR/link verify page, shareable posters, encyclopedia.
6. **Phase 6:** Anti-cheat layers, granular consent plus settings trust centre.
7. **Phase 7:** Admin panel (data-driven rules), seeded dummy users, internal web build, marketing site.
8. **Phase 8:** Polish, graceful degradation, edge cases (GPS dropouts, always-on location).
