# Flying Cobra — User Journeys

Twelve end-to-end journeys. Screen IDs and trigger names come only from `docs/ux/SCREEN_IDS.md`; personas from `docs/ux/PERSONAS.md`; rules from `docs/ALGORITHMS.md`; copy from `docs/DESIGN.md` §9. Each journey names one success signal: the single metric that says the design did its job. The arc notation is **feel → feel**, one per step.

Shared rules across every journey:
- The reveal is the only long sequence (DESIGN §6). Every other screen is quieter than it.
- "Not now" is never smaller than "Allow". No recipe is ever shown; captions say *that* a rule exists, never the threshold.
- Nothing shames a slow run. Copy never uses "slow", "only", "just", "failed".
- Posters, verify pages and share flows carry zero location.

---

## (a) First launch and permissions

**Goal.** Get from app store to "ready to run" with the permissions the runner actually wants, in under two minutes, with no dark patterns.
**Persona.** Ravi (grants location and steps, declines the rest). Secondary: Meera (grants all, with her daughter reading the "Why?" aloud).
**Entry.** Cold open after install → **Exit.** `onboarding-done`, then `today` in its empty state ("Your first run opens the bag").

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | `welcome` | Paw mark animates once (the only time it ever does). "Run. Get an animal. Collect India." | Curious, unhurried |
| 2 | `sign-in` | Magic link, Apple, Google. Test account visible only in internal builds | Low-stakes |
| 3 | `perm-location` | What / why / what we store / Allow · Not now, equal weight | Informed |
| 4 | `perm-motion` | Ravi taps Not now. The card thanks him, no second ask | Respected |
| 5 | `perm-activity` | Not now again. Copy: auto-detect is off, the big Start button is on | Still in control |
| 6 | `perm-health` | Not now. "Heart rate helps us vouch for your run; without it we use steps and pace" | Reassured |
| 7 | `perm-notifications` | Ravi allows: he wants the Monday envelope | Anticipating |
| 8 | `fairness` | Pre-skipped. Meera expands "Why?" and fills birth year | Trusting |
| 9 | `onboarding-done` | The bag illustration. "Your first run opens the bag." | Ready |

**Friction removed.** Five prompts in a row feel like a gauntlet → each prompt is a single card with a reason in one sentence and the loss stated plainly, not a wall of OS dialogs; progress dots show how many remain. Fear of being locked out for declining → every "Not now" screen confirms the app works with just location. The "fully connected" reward could pressure consent → it is mentioned once, in `settings`, never here.
**Triggers.** `first-launch` · `sign-in-complete` · `permission-granted` · `permission-denied`.
**Success signal.** Onboarding completion rate ≥ 85 % with median time under 120 s, *and* no measurable drop in completion among people who decline two or more permissions.

---

## (b) A run that ends in a card reveal (verified)

**Goal.** Finish a run and, within three seconds, hold a card that reflects it.
**Persona.** Arjun, 5 km at 3:55/km, Cubbon Park, 17:30, all sensors.
**Entry.** `today` FAB (or auto-detect) → **Exit.** `card-detail`.

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | `today` | Hero shows last card; FAB "Start a run" | Intent |
| 2 | `run-ready` | GPS pill goes green within ~5 s; watch connected tick | Confident |
| 3 | `run-recording` | Big pace, distance, timer; GPS pill; auto-pause at the Hudson Circle signal, resumes alone | Focused, then forgets the phone |
| 4 | `run-finish` | Hold-to-finish. Dark scrim, "Reading your run…" shimmer ≤ 1.2 s | Held breath |
| 5 | `reveal` | Card back slides up (420 ms), pause, flip (600 ms), foil at 50 %; Chinkara, young, plain, `#0312` | Surprise, then grin |
| 6 | `card-detail` | Tap anywhere. Stats, flavour line, "earned 1 time, best #0312", Share poster | Possession |

**Friction removed.** Accidental finish → hold-to-finish with haptic ramp, not a tap. Reveal lag → RPC runs under the shimmer; if it exceeds 1.2 s the shimmer continues without a spinner. Watch not connected → the card still reveals; a one-line footnote on `card-detail` says the run verified by pace and steps. Rare animals look like the goal → common cards use the same slide/flip and haptic weight; only the particles differ.
**Triggers.** `run-started` · `run-auto-paused` · `run-ended` · `card-issued` (or `rare-card-issued`).
**Success signal.** Time from `run-ended` to card face visible ≤ 3 s at p90; ≥ 95 % of verified runs reach `card-detail` without the user leaving the reveal early.

---

## (c) A run that earns nothing, handled kindly

**Goal.** Record the effort, explain the outcome in one honest line, and leave the runner wanting the next run, not an argument.
**Persona.** Sana (floor not met on a 0.8 km test jog); Arjun (third run of the day, capped); a bus-ride edge case (rejected).
**Entry.** `run-finish` → **Exit.** `today`, with the run counted where it counts.

| Step | Screen | Case | Copy (DESIGN §9) | Feels |
|---|---|---|---|---|
| 1 | `run-finish` | Floor not met | "Recorded. A run of 1 km or 10 minutes earns a card." | Oh — fair enough |
| 1 | `run-finish` | Capped (2 cards/day) | "Recorded and counted. Your card bag refills tomorrow." | Fine, it still counted |
| 1 | `run-finish` | Unverified (0.40 ≤ τ < 0.60) | "We couldn't fully verify this run, so it drew from the everyday bag." → proceeds to `reveal` | Slight pause, then a card anyway |
| 1 | `run-finish` | Rejected (τ < 0.40) | "We couldn't confirm this one was a run — no card this time." | Not accused |
| 2 | `today` | Streak dot still fills for floor-met and capped runs; furniture totals update | Not wasted |

**Friction removed.** "No card" reads as failure → it is a calm sheet, no red, no sad animal, one sentence, one button. Capped runners feel punished for enthusiasm → the copy says "counted" first and the streak dot visibly fills. Rejected runners want to appeal → the sheet links to `permission-receipt` with "What helps us verify a run" (never the thresholds). The floor message is the single place a numeric rule is spoken, because it protects everyone from farming and it is a floor, not a judgement.
**Triggers.** `run-floor-not-met` · `run-capped` · `run-unverified` · `run-rejected`.
**Success signal.** Next-7-day return rate after a no-card run within 5 points of the return rate after a card run. Zero support tickets containing the word "cheating" from phone-only users.

---

## (d) An animal growing up

**Goal.** Celebrate consistency as growth, without re-babying anyone.
**Persona.** Arjun: Cheetah earned in a third distinct ISO week → bond_stage baby → young. Later, week six → adult.
**Entry.** `reveal` of a card for that animal → **Exit.** `card-detail` showing the new stage.

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | `reveal` | Normal flip reveals the cheetah at its run stage | Recognition ("you again") |
| 2 | `celebration-growth` | Art cross-fades to the new stage (500 ms, radial wipe). "Your cheetah is all grown up!" Haptic success | Pride, the earned kind |
| 3 | `card-detail` | Stage chip reads young; "earned 4 times, best #0087" | Ownership of a relationship |
| 4 | `collection` | Cheetah tile now the young silhouette size | The grid tells a story |

**Friction removed.** Growth after a break is confusing → the bond never decreases; a weak week draws a different animal, and the caption on that card never mentions the cheetah. The growth moment could be lost in the reveal → it fires *after* the flip, as its own beat. A six-week wait feels invisible → `card-detail` shows "earned in N weeks" quietly, hinting that weeks (not runs) matter, without stating 3 or 6.
**Triggers.** `card-issued` · `animal-grew` (and `animal-mastered` at adult + 10 earns, which opens `celebration-mastered`, Unlock the Wild).
**Success signal.** ≥ 60 % of runners who see one `animal-grew` celebration earn that same animal again within four weeks.

---

## (e) The weekly card arriving

**Goal.** Make Monday morning the best moment of the week for a consistent runner.
**Persona.** Ravi, seven run-days, 35 km, Pune.
**Entry.** Monday 06:30 IST notification, or app open after week close → **Exit.** `card-detail` of a legendary.

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | notification → `today` | "Your weekly card is ready." A glowing envelope sits above the hero card | Chai-in-hand anticipation |
| 2 | `reveal` | Envelope opens; the same slide and flip; radiant finish; 24 particles. Bengal Tiger, adult, radiant, `#0041` | Awe |
| 3 | `card-detail` | "7 run-days · 35 km"; set name "Monsoon 2026" if in season; Share poster | Earned, not lucky |
| 4 | `today` | Streak dots reset for the new week; "0 of the week · 3 opens the weekly bag" | A reason to lace up |

**Friction removed.** Week close at 03:00 Monday could issue the card while he sleeps and bury it → the card is *held* as a pending envelope and only reveals on tap. Three-day weeks feel like near-misses → the Today row is the one place a threshold is hinted ("2 more opens the weekly bag") because consistency is the thing we teach. Skipped weeks → `no-weekly-card` shows nothing on Today beyond the gentle line "No weekly card this week — three run-days opens the weekly bag", and never an insulting animal.
**Triggers.** `weekly-card-ready` · `rare-card-issued` · `no-weekly-card` · (`monthly-card-ready` follows the same envelope pattern).
**Success signal.** ≥ 70 % of pending weekly envelopes are opened within 24 hours; run-day count in the following week is equal or higher for runners who opened one.

---

## (f) A travel souvenir and the migratory bird

**Goal.** Reward running in a new place with that place's animal, and crossing India with a bird that crosses it too.
**Persona.** Priya: Bengaluru (home) → Kochi → Goa inside 21 days.
**Entry.** `run-finish` in Kochi → **Exit.** `collection` with two new families.

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | `reveal` (Kochi) | Great Hornbill, tier 3 guaranteed | "Wait, is that…" |
| 2 | `celebration-discovery` | Caption: "A souvenir from Kerala." | Delight, the postcard kind |
| 3 | `card-detail` | State shown on card; "Show on verify page" toggle (off by default) | In control of what travels |
| 4 | `reveal` (Goa) | Tier 4 outranks tier 3: Bar-headed Goose (or Flamingo / Amur Falcon / Demoiselle Crane) | Astonishment |
| 5 | `celebration-discovery` | "You found this one because you ran in three states." | Scale of the achievement lands |
| 6 | `collection` | Souvenir and migratory families appear; Goa's Olive Ridley shows as a silhouette | A map of the year, and a promise |

**Friction removed.** Priya "missed" the Goa turtle → the Goa souvenir remains guaranteed for her next Goa run; the Collection silhouette is captioned "Some animals belong to a place" (no recipe). State misdetected at an airport → the floor (1 km or 10 min) and the server bounding-box check keep a terminal stroll from minting a souvenir; a mismatch quietly earns no regional animal. Home state as a souvenir → never; the home row in `settings` explains "Where you live is not a souvenir."
**Triggers.** `discovery-souvenir` · `discovery-migratory` · `card-issued` · `rare-card-issued`.
**Success signal.** ≥ 80 % of first runs in a new state produce a souvenir reveal that is viewed to the caption; share rate on souvenir and migratory cards is at least 2× the share rate of speed-family cards.

---

## (g) A night run discovery

**Goal.** Make running at 22:15 feel like finding a secret.
**Persona.** Kabir, Connaught Place, Delhi, first night run.
**Entry.** `run-ready` in the dark → **Exit.** `animal-entry` for the owl.

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | `run-ready` | Dark theme, dim GPS pill, no white flash | Calm |
| 2 | `run-recording` | Auto-pause at each signal; resumes without a tap | Trust in the tool |
| 3 | `run-finish` → `reveal` | Indian Eagle-Owl, young, night palette | "It knows what time it is" |
| 4 | `celebration-discovery` | "You found this one because you ran at night." | A secret found |
| 5 | `animal-entry` | "The keeper of the dark"; facts; "Earned 1 time" | Quietly proud |

**Friction removed.** Fixed-clock night rules misfire across India → night is computed from local sunset (§9.6), so a 19:30 run in Kohima and a 20:30 run in Dwarka are judged by their own sky. A 06:00 "well done" notification wakes him → reminders anchor to his usual run hour. Repeat nights feel like a lottery → the caption appears every time the owl bag fires (0.35 after the first), so the connection stays legible without stating odds.
**Triggers.** `run-started` · `run-auto-paused` · `run-ended` · `discovery-time` · `card-issued`.
**Success signal.** Runners whose first run falls in a night or dawn window return for a second run within 7 days at a rate ≥ day-window runners.

---

## (h) Searching a serial number

**Goal.** Answer "is this card real?" in one field and one glance.
**Persona.** Arjun's colleague Dev, who was shown a Cheetah `#0009` on WhatsApp and does not believe it.
**Entry.** `settings` → Verify a card (or deep link `/v/cheetah/9`) → **Exit.** the single verified card.

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | `serial-search` | One field, hint "Tiger #0427". Accepts `Cheetah #0009`, `cheetah 9`, `CHE-0009` | Simple |
| 2 | `serial-search` (loading) | Banknote-style serial typesetting while it looks up | Official |
| 3 | `serial-search` (success) | The card, "Earned by Arjun on 28 Sep 2026", "#0009 of 118 issued", "Real ✓ · lives in the Flying Cobra ledger" | Settled |
| 3′ | `serial-search` (error) | "No such card. If someone showed you this, they're bluffing." | Amused, not scolded |

**Friction removed.** People search for people → there is no name search anywhere; the field accepts only serial forms and says so. Format anxiety → three formats parse. Privacy → the lookup returns animal, serial, stage, finish, set, earner's display name, date, distance, duration, pace, never location or health.
**Triggers.** `serial-found` · `serial-not-found`.
**Success signal.** ≥ 90 % of searches resolve on the first submission (found or confidently not found); zero successful lookups by any input that is not a serial.

---

## (i) Sharing a poster and a friend verifying on the web with no app

**Goal.** Turn one card into one story post and one verified click, with nothing to download.
**Persona.** Priya shares the hornbill; her friend Anu in Mumbai verifies from Instagram.
**Entry.** `card-detail` → Share poster → **Exit.** Anu on the public verify page (web, outside the app), store badges visible.

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | `card-detail` | Share poster | Pride |
| 2 | `poster` | 1080×1920 preview: family gradient, card at 70 % width, serial large, QR bottom-right, wordmark. Toggle "Show my name" | Safe to post |
| 3 | `poster` | Export → system share sheet → Instagram story / WhatsApp status | Done in two taps |
| 4 | (web) verify page | Anu scans the QR: calm page, the card, "Earned by Priya on 28 Sep 2026", "#0042 of 118 issued", "Real ✓". No route, no map, no city | Convinced, intrigued |
| 5 | (web) | Store badges below. Anu installs; her own journey (a) begins | The growth loop |

**Friction removed.** Home-address leak via a route thumbnail → posters and verify pages never render a map or start point, by rule, not by setting. Flattened screenshots lose the proof → the QR and short link are baked into the poster image. Verify looks like marketing → it is a receipt: white space, serial typography, one seal.
**Triggers.** `poster-exported` · `serial-found`.
**Success signal.** Verify-page visits per exported poster ≥ 1.5; install rate from verify pages ≥ 5 %.

---

## (j) Adjusting permissions in settings and seeing graceful degradation

**Goal.** Let a runner turn data off (or on) and understand, in one row, exactly what changes.
**Persona.** Ravi, six weeks in, curious whether motion data is worth it; Meera, checking what the app holds.
**Entry.** `settings` → **Exit.** back to `today`, nothing broken.

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | `settings` | Profile card, then "Permissions" as a receipt: each purpose, status, why, what you lose without it | Read like a bill, in a good way |
| 2 | `permission-receipt` | Ravi toggles Motion & fitness on; the row explains footfall rhythm helps vouch for runs. A locked "Fully connected" silhouette (Himalayan Monal) hints at what connecting everything unlocks | Curious, not pressured |
| 3 | `permission-receipt` | Meera toggles Heart rate off to test it. Immediate. Row now reads "We use pace and steps to verify instead" | Still in control |
| 4 | `today` | Nothing visibly changes. Her next run still verifies and still draws a card | Trust confirmed |
| 5 | `data-and-account` | "Export my data" produces a file; "Delete my account" is two steps with a plain warning | DPDP-grade respect |

**Friction removed.** Toggling off feels like breaking the app → each row states the fallback, and the trust score simply excludes missing evidence (§10). Dark-pattern fear → "off" is one tap with no confirm dialog; "on" routes through the OS prompt only. Age data worry → birth year row carries "Only used to grade effort fairly. Never shown." and a one-tap clear.
**Triggers.** `permission-toggled` · `permission-granted` · `permission-denied` · `data-exported` · `account-deleted`.
**Success signal.** ≥ 30 % of users who declined a permission in onboarding open `permission-receipt` within 30 days, and card-issue rate for runners with only location + steps equals the all-permissions rate.

---

## (k) Coming back after a 60-day break

**Goal.** Welcome a lapsed runner back without a lecture, and make small animals feel like a new game, not a demotion.
**Persona.** Kabir, after a two-month restaurant renovation.
**Entry.** `today` on first open after 60+ days → **Exit.** `card-detail` of the comeback card.

| Step | Screen | What happens | Feels |
|---|---|---|---|
| 1 | `today` | Hero still shows his last owl; furniture is quiet; no red "streak lost" | Not judged |
| 2 | `run-recording` → `run-finish` | A short 2 km night run | Tentative |
| 3 | `celebration-welcome-back` | "Welcome back. Your animals start small again — and so does the adventure." Bonds reset to baby on this run | Relief, then a spark |
| 4 | `reveal` | A baby calm-family card (or the owl bag at 0.35) | Fresh start |
| 5 | `collection` | Earlier adult cards keep their printed stage forever; the live bond is baby | Nothing taken away |

**Friction removed.** Reset reads as punishment → printed cards never change; only the *bond* restarts, and the copy frames it as a new adventure. A guilt notification during the break → there is none; the 60-day rule is silent until he runs. Pity timer state carries over so his first comeback weeks are not a common-card drought.
**Triggers.** `welcome-back` · `run-ended` · `card-issued`.
**Success signal.** ≥ 50 % of runners who see `celebration-welcome-back` record a second run within 14 days.

---

## (l) GPS lost mid-run and offline finish

**Goal.** Never lose a run to a tunnel, a monsoon cloudburst, or a dead data signal.
**Persona.** Ravi under the Mula-Mutha bridge in a Pune downpour, phone in a plastic bag, no data.
**Entry.** `run-recording` → **Exit.** `reveal` when back online, run intact.

| Step | Screen (state) | What happens | Feels |
|---|---|---|---|
| 1 | `run-recording` (`gps-good`) | Normal | Flow |
| 2 | `run-recording` (`gps-searching`) | Pill turns amber "Finding GPS"; distance pauses, timer continues; steps keep counting | Noticed, not alarmed |
| 3 | `run-recording` (`gps-good`) | Pill green again; the gap is bridged by steps, not a straight line | Trust |
| 4 | `run-finish` (`offline`) | "Saved on your phone. We'll read it when you're back online." No shimmer, no spinner | Patient |
| 5 | `today` | Hero card unchanged; a quiet "1 run waiting" chip | Reassured |
| 6 | `reveal` | On reconnection the run uploads and the reveal plays as if live | Delayed, not denied |

**Friction removed.** Runner stops to fiddle with the phone → the pill plus one haptic is the whole alert; no modal. GPS jumps inflate pace into the hard-rejection ceiling → client drops points with accuracy > 50 m or implied speed > 30 km/h before upload (§9.1), and the server re-validates. Offline finish feels like a loss → the saved state is explicit and the reveal is preserved for when it can be felt properly. GPS denied entirely → `gps-denied` state says steps still count and links to `permission-receipt`.
**Triggers.** `gps-lost` · `gps-regained` · `run-ended` · `offline-saved` · `back-online` · `card-issued`.
**Success signal.** ≥ 99 % of runs with a GPS gap or offline finish are uploaded and resolved within 24 hours; abandonment during `gps-searching` under 2 %.

---

## Journey map

| Journey | Screens in order | Key moment | The one metric |
|---|---|---|---|
| (a) First launch & permissions | `welcome` → `sign-in` → `perm-location` → `perm-motion` → `perm-activity` → `perm-health` → `perm-notifications` → `fairness` → `onboarding-done` → `today` | Declining a permission and being thanked for it | Completion ≥ 85 %, unchanged for people who decline ≥ 2 |
| (b) Run → verified reveal | `today` → `run-ready` → `run-recording` → `run-finish` → `reveal` → `card-detail` | The flip at 50 % when the foil appears | Run end to card face ≤ 3 s at p90 |
| (c) Run earns nothing | `run-finish` → `today` | "Recorded and counted." with the streak dot filling | 7-day return rate within 5 pts of a card run |
| (d) Animal grows up | `reveal` → `celebration-growth` → `card-detail` → `collection` | The cross-fade to the bigger animal | 60 % re-earn the animal within 4 weeks |
| (e) Weekly card | `today` → `reveal` → `card-detail` → `today` | The glowing envelope on Monday morning | 70 % of envelopes opened in 24 h |
| (f) Souvenir & migratory | `reveal` → `celebration-discovery` → `card-detail` → `reveal` → `celebration-discovery` → `collection` | "A souvenir from Kerala." | Souvenir share rate ≥ 2× speed cards |
| (g) Night discovery | `run-ready` → `run-recording` → `run-finish` → `reveal` → `celebration-discovery` → `animal-entry` | "You found this one because you ran at night." | Night/dawn first-runners return ≥ day-runners |
| (h) Serial search | `serial-search` (loading → success / error) | "Real ✓ · lives in the ledger" | 90 % first-submission resolution |
| (i) Poster & web verify | `card-detail` → `poster` → system share → web verify | Friend scans QR, sees the proof, no app | ≥ 1.5 verify visits per poster; ≥ 5 % install |
| (j) Permissions & degradation | `settings` → `permission-receipt` → `today` → `data-and-account` | Toggling off and nothing breaking | Card-issue rate equal for location+steps-only users |
| (k) Welcome back | `today` → `run-recording` → `run-finish` → `celebration-welcome-back` → `reveal` → `collection` | "…and so does the adventure." | 50 % run again within 14 days |
| (l) GPS lost & offline | `run-recording` (gps-good → gps-searching → gps-good) → `run-finish` (offline) → `today` → `reveal` | Amber pill, timer keeps going, nothing lost | 99 % of gapped/offline runs resolved in 24 h |
