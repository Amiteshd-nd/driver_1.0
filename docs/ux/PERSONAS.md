# Flying Cobra — Personas

Six personas, one per seeded dummy user (`supabase/migrations/0007_seed_dummy_users.sql`). Expected card outcomes follow `docs/ALGORITHMS.md` §13 and the tier rules in §6.1; screen IDs follow `docs/ux/SCREEN_IDS.md`. These are the people we design for and the accounts we play-test with. They are deliberately different *kinds* of runner, never better and worse ones: the card reflects the run, not the runner.

A note on IST dawn: India runs on one clock across 29 degrees of longitude. The dawn window is computed from real sunrise at the run's location (§9.6), so a 6:40 start in Pune is dawn while a 6:40 start in Guwahati is broad daylight. Four of our six personas run in the morning; where that lands them matters for their first card.

---

## 1. Arjun — the 24-year-old sprinter who wants proof he is fast

**Portrait.** Engineering graduate in Bengaluru, two years into a product job, runs hard three evenings a week because it is the only hour of the day nobody can message him.

**Context.** Bengaluru (Cubbon Park loop, IN-KA). Runs 5 km at 3:55/km around 17:30, after the office, before the traffic peaks. iPhone plus an Apple Watch he bought for exactly this. Granted everything: location, motion, steps, heart rate, activity recognition, elevation. His reasoning: "If a watch can prove I did it, I want it proving it." Day window (Bengaluru sunset in October is about 18:00; he starts before the dusk window).

**Job to be done.** "Turn my hard run into something I can show without sounding like I am bragging." He has outgrown pace screenshots; a card with a serial does the bragging for him in a way that reads as play.

**Expected first card.** Age-graded P ≈ 0.64 → swift band → 5 km → *young* stage, plain finish (three run-days in the trailing seven). Most likely a Chinkara or Horse (commons), with the Peregrine Falcon (rare) and Cheetah (epic) as the chase. Three evening runs this week keep the pity counter ticking toward his first rare. Cheetah is his goal animal; he will not see it in the first week and that is by design.

**Delight.** Foil shimmer under the Cubbon Park streetlights the moment the card flips; the heart-rate line on the card that says "verified"; a low serial on anything swift. Later, the Cheetah growth celebration after six distinct weeks.

**What makes him quit.** A rejected run he knows was real (GPS slack pushing a split past the hard ceiling); a reveal that feels slower than the run; discovering the recipe on a forum and finding the game solved. He also quits if anything in the app ranks him, because then it is just Strava with cartoons.

**Accessibility and trust.** Wants to see what the watch contributed and why the run was verified; the `permission-receipt` is his proof-of-fairness page. High-contrast evening light; large pace numbers while moving.

**In his voice.** "I don't need a leaderboard. I need the serial to be a smaller number than my friend's."

---

## 2. Meera — the 62-year-old who has run the Marina for thirty years

**Portrait.** Retired schoolteacher in Chennai, up before the fishing boats, 12 km along Marina Beach at a steady 7:10/km with the same two friends since 1996.

**Context.** Chennai (Marina, IN-TN). Starts 05:50, out-and-back along the promenade past the chai carts setting up. Android phone in an arm pouch and a Garmin her daughter configured. Granted all permissions, including birth year and sex on the `fairness` screen, because her daughter read the "Why?" expander aloud and she agreed it was reasonable. Chennai sunrise in October is about 06:00, so 05:50 lands in the **dawn** window.

**Job to be done.** "Let me enjoy a running app that does not tell me I am slow." Every other app has greeted her with a red pace.

**Expected first card.** Her first run is in the dawn window and she has never earned a time-of-day animal, so tier 1 fires guaranteed: a Rooster or Bulbul (dawn commons), *adult* stage from 12 km, with the caption "You found this one because you ran at dawn." On her second Marina run (dawn fires again only at 0.35), she most often draws from the speed pool: age factor 0.77 lifts her to P ≈ 0.44 → calm band, and because D ≥ 8 the Elephant ("the tireless traveller", epic) sits in her bag. Elephant is her chase, and her encyclopedia entry to show the grandchildren.

**Delight.** An adult-sized animal on the very first card because she went far; the encyclopedia line that elephants walk 30–50 km a day; the same gold foil as the sprinters when her rare comes.

**What makes her quit.** Small text she cannot read in the half-dark; a permission prompt that feels like a trap; any copy that implies the calm or gentle families are consolation prizes; a card that shows her age.

**Accessibility and trust.** 1.3× Dynamic Type on every screen, especially `run-recording` and `card-detail`; haptics plus text for every celebration; "Only used to grade effort fairly. Never shown." must be visible wherever birth year appears. She will show the `permission-receipt` to her daughter.

**In her voice.** "It gave me a bird for being up before the sun. Nobody has ever given me anything for that."

---

## 3. Ravi — the 7-day streak runner who measures himself by not missing

**Portrait.** 35, runs a small logistics business in Pune, 5 km every single morning at 06:40 before the shutters go up. Consistency is his personality.

**Context.** Pune (IN-MH), a slightly different loop each day around the same neighbourhood. Mid-range Android, no watch. Granted **only location and steps**: "The phone knows where I went and how many steps. That is enough." Declined motion, activity recognition and heart rate on the first launch and has not revisited them. Pune sunrise in October is about 06:25, so 06:40 is inside the dawn window.

**Job to be done.** "Reward the streak itself, not the speed." At 5:27/km (P ≈ 0.46, calm band, borderline steady) his daily cards are gentle-family commons and that is fine by him; the weekly card is the thing he actually runs for.

**Expected first card.** First morning: dawn tier fires guaranteed → Rooster or Bulbul, young stage. Daily cards after that: calm commons with occasional dawn birds. At week close, seven verified run-days → the **7-day weekly bag**: Bengal Tiger or Great Indian Bustard (legendary), *adult* stage from 35 km of volume, **radiant** finish. Delivered as a glowing envelope on `today` Monday morning.

**Delight.** Seven filled streak dots; "7 of the week"; the envelope waiting when he opens the app on Monday with his first chai; a legendary with a radiant finish that only consistency can mint.

**What makes him quit.** A run that counted as a run but not toward the streak; a GPS dropout under the Mula-Mutha bridge silently losing a day; the app pretending his phone-only runs are less trustworthy. With just GPS and steps his trust score is still about 0.85 → verified, and the app must never hint otherwise.

**Accessibility and trust.** Needs the offline and GPS-searching states on `run-recording` to be unmistakable; needs `today` to show the week count without showing a leaderboard. The `permission-receipt` should tell him plainly what he loses without motion data (nothing he cares about yet) and never nag.

**In his voice.** "I don't care which animal. I care that Monday has something waiting for me."

---

## 4. Priya — the traveller who runs to learn a city

**Portrait.** 30, a consultant based in Bengaluru who spends half the month in client cities, runs 5 km at 5:43/km wherever she wakes up because it is the fastest way to feel at home somewhere.

**Context.** Home region IN-KA (Koramangala). This month: Bengaluru (14 days ago, 07:10), Kochi (7 days ago, 06:50, past the backwater ferries), Goa (2 days ago, 07:00, Miramar). iPhone and Apple Watch. Granted everything; travels enough that she wants the watch to vouch for runs on unfamiliar roads. Day window on all three (each start is more than 30 min after local sunrise).

**Job to be done.** "Give me a souvenir from each place I run, one I did not buy." She already keeps boarding passes.

**Expected first card.** Bengaluru run: home state is never a souvenir; P ≈ 0.49 steady → Chital or Desi Dog, young stage. Kochi: first run in a new state → tier 3 guaranteed → **Great Hornbill**, "A souvenir from Kerala." Goa: now three states in 21 days → tier 4 outranks tier 3 → a migratory bird (Bar-headed Goose or Greater Flamingo, rare; Amur Falcon or Demoiselle Crane, epic). The Goa Olive Ridley stays guaranteed for her next Goa run, so the design must make the Collection silhouette for Goa feel like a promise, not a miss.

**Delight.** The hornbill with the Kerala line; the migratory bird caption "You found this one because you ran in three states"; a Collection grouped by family that quietly becomes a map of her year.

**What makes her quit.** A souvenir that leaks where she stayed (the poster must never show route or start point; she shares from hotel rooms); state detection that misfires at an airport; being asked to re-grant location every time she changes city.

**Accessibility and trust.** Reverse geocoding happens on-device; the `permission-receipt` must say so. Verify page shows state name only when she toggles it on in `card-detail`.

**In her voice.** "I have a hornbill from Kochi and a goose for the three cities. My suitcase has nothing this good."

---

## 5. Kabir — the night owl who runs when Delhi finally cools down

**Portrait.** 38, restaurant manager near Connaught Place, finishes service at 22:00 and runs 4 km at 6:00/km through the emptied inner circle because the air is 8 degrees cooler and nobody honks.

**Context.** Delhi (IN-DL). Starts 22:15, well past sunset + 60 min → **night** window. Android flagship with a Wear OS watch. Granted all permissions; he is used to apps asking and is more interested in whether the app works when the streets are dark and his phone is in a jacket.

**Job to be done.** "Make running at 10 pm feel like a feature, not a workaround." Every other app's social feed is full of 6 am people.

**Expected first card.** P ≈ 0.41 → calm band, but the night tier fires guaranteed on his first run → **Indian Eagle-Owl** (common) most likely, Nightjar or Fruit Bat (uncommon) or Palm Civet (rare) otherwise; *young* stage from 4 km; caption "You found this one because you ran at night." Repeat night runs fire the owl bag at 0.35, so most later nights draw calm commons, and the night bag becomes a thing he looks forward to rather than expects.

**Delight.** Dark mode that is actually dark at 22:15; a card whose palette matches the hour; the encyclopedia telling him the eagle-owl is "the keeper of the dark".

**What makes him quit.** A bright white reveal screen in a dark street; a run auto-paused at every traffic signal and never resumed; a notification at 06:00 congratulating him on yesterday when he went to bed at 02:00.

**Accessibility and trust.** `run-recording` must respect auto-pause and resume on its own; the app should schedule reminders relative to his usual run hour, never a fixed morning; glare-free dark theme on `reveal`.

**In his voice.** "The owl came out because I did. Finally an app on my schedule."

---

## 6. Sana — the collector who runs slow on purpose

**Portrait.** 26, UX writer in Hyderabad, started running three weeks ago, 3 km at 7:30/km along Necklace Road at 17:00. She wants a rabbit and she has worked out that running gently is how you get one.

**Context.** Hyderabad (IN-TG, Hussain Sagar). Evening runs twice a week, day window (sunset about 18:00 in October). Budget Android, no watch. Granted **only location and steps**; skipped heart rate and activity recognition because "I am not training for anything. I am collecting." Declined the fairness screen too, so no age factor is applied.

**Job to be done.** "Let me play the game my way." She is the proof of the PRD's promise that a gentle run opens a different bag, not a worse one.

**Expected first card.** 3.0 km at 8 km/h → calm or gentle band depending on the day's P → *young* stage (exactly 3 km). From the calm pool: Rabbit or Cat (commons, roughly even odds), Grey Langur or Peacock (uncommon), Smooth-coated Otter (rare), Mouse-deer (epic). She may get the Cat first, and the rabbit chase across the next few runs is the point. The pity timer protects her from a long drought of commons.

**Delight.** The Rabbit flavour line "soft paws, big heart"; the Collection silhouettes showing how big the calm family is; a serial under #0100 on anything.

**What makes her quit.** Any copy that says slow; a pace screen in red; discovering that someone else's rabbit has a nicer border because they were faster (it does not, and the design must make that obvious); being told the recipe, because the finding is the fun.

**Accessibility and trust.** With only GPS and steps, her trust score still verifies cleanly; `run-finish` must never say "unverified" for a phone-only run that passes. She reads microcopy closely and will screenshot anything that shames.

**In her voice.** "I ran slow for a rabbit and got a cat. Fine. Thursday I'm running slower."

---

## Design implications

| Persona | Screen 1 | Screen 2 | Screen 3 | Why these three |
|---|---|---|---|---|
| Arjun | `reveal` | `permission-receipt` | `poster` | The reveal is the payoff; the receipt proves the watch verified him; the poster is how he brags without bragging |
| Meera | `run-recording` | `card-detail` | `encyclopedia` | Large legible numbers in the half-dark; the adult-stage card she shows the family; the facts that make calm and gentle animals majestic |
| Ravi | `today` | `run-recording` | `reveal` (weekly) | Streak dots and "7 of the week"; unmistakable GPS and offline states on a phone-only run; the Monday envelope |
| Priya | `celebration-discovery` | `collection` | `poster` | Souvenir and migratory captions; the collection as a map of her year; a share that leaks no location |
| Kabir | `run-recording` | `reveal` | `settings` | Dark, auto-pause-tolerant live screen; a glare-free reveal at 22:15; reminder timing on his schedule |
| Sana | `reveal` | `collection` | `animal-entry` | Equal foil and weight for calm animals; silhouettes that hint at a big family; flavour copy that never shames |
