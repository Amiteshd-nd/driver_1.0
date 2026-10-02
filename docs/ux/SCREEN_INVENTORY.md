# Screen inventory

Deliverable 3 of the UX prototype PRD (§4). Every screen the journeys need, in the order and with the IDs of `SCREEN_IDS.md`. The workbench left panel lists exactly these screens; the right panel's state switcher exposes exactly the states named here; trigger names are from the SCREEN_IDS vocabulary. Where a screen is already built in `app/lib/features/`, the copy below is the built copy.

## How to read a screen entry
- **Entry / Exit** name screens by ID and the trigger that moves the user. **Primary** is the one action the screen exists for; everything else is **Secondary**.
- **States** always cover `empty · loading · success · error`; `n/a` means the state cannot occur and the switcher hides it. Screen-specific states follow.
- **Data** lists API.md fields (`submit_run`, `claim_pending_cards`, `lookup_serial`, tables) the screen reads or writes. **Never** lists what the screen must not show.

## Baseline that applies to every screen
- Voice (DESIGN §9): warm, brief, second person, max one `!` per screen. Never "slow", "lazy", "only", "just", "failed", "better than". Errors say what happened and what to do next; recovery is always available (retry, pull-to-refresh or a safe exit).
- Targets ≥ 48 × 48 pt; body ≥ 16 pt; Dynamic Type to 1.3× with the card scaling as a unit. Rarity and status never carried by colour alone (border weight + text, dot + label).
- Reduced motion: flips become 350 ms cross-fades, particles and foil tilt off, staggers off; haptics stay. Every celebration has text; haptics are supplementary.
- Loading states keep layout (skeleton at final size) so nothing jumps. Snackbars are 4 s, swipe-dismissable, never the sole carrier of information a user must act on.
- Equal-weight choices: "Not now" and "Allow", "Keep going" and "Finish anyway", "Keep my account" first in destructive dialogs.

---

## Onboarding

### `welcome` — Promise screen
- **Purpose:** State the promise and set expectations before asking for anything.
- **Entry:** `first-launch` (first open; or after `sign-in-complete` when sign-in precedes it). **Exit:** `sign-in` if signed out, else `perm-location`.
- **Primary:** Continue. **Secondary:** none (no skip; nothing is being asked yet).
- **States:** `empty` n/a · `loading` n/a (static) · `success` "Run. Get an animal. Collect India." / "Every run earns an animal card with its own serial number. Consistency grows your animals. Exploring finds new ones." / "Next, a few questions about what the app may read. Each one is yours to decide; the app works with Location alone." · `error` n/a.
- **Data:** none. **A11y:** paw mark animates on first launch; decorative, `excludeSemantics`; heading announced first.
- **Never:** thresholds, animal recipes, mention of the fully-connected reward.

### `sign-in` — Sign in
- **Purpose:** Get the runner an account with the least friction (magic link, Apple, Google).
- **Entry:** `welcome`; `settings` after sign out; `data-and-account` after `account-deleted`. **Exit:** `welcome`/`perm-location` on `sign-in-complete`; `today` if onboarding already done.
- **Primary:** "Send me a sign-in link". **Secondary:** "Continue with Apple", "Continue with Google", "Test account" (internal builds), "Use a different email".
- **States:** `empty` form idle, promise + "Every run earns a collectible animal card. Sign in to start your collection." · `loading` button busy, inputs disabled · `success` → `link-sent`: "Check your inbox" / "We sent a sign-in link to {email}. Open it on this device and you're in." · `error` "We couldn't reach the sign-in service. Check your connection and try again." or "Sign-in didn't complete. Try again in a moment." (inline, under the buttons) · `provider-unavailable` button reads "Continue with Apple · coming soon", disabled with tooltip · `test-account` expander: "Pre-launch play accounts (arjun@flyingcobra.test …). Removed before public launch."
- **Data:** Supabase Auth; `profiles` row created by trigger. **A11y:** email field labelled; error text in a live region; footer "By continuing you agree to keep running for the joy of it. Your routes and health data stay private to you."
- **Never:** password field, name/age/sex questions, social sign-up upsell.

### Permission cards (shared template for `perm-location` … `perm-notifications`)
Full-screen card: icon · **what** (title) · rows "Why: We ask {why}." · "What we store: {store}." · "If you skip: {lose}" · two equal buttons **Not now** / **Allow** · footer "You can change this any time under You → Permissions."
- **Entry:** previous card or `welcome`. **Exit:** next card on `permission-granted` or `permission-denied` (both advance; nothing blocks).
- **States:** `empty` n/a · `loading` OS dialog open; Allow shows a spinner, Not now stays enabled · `success` card shown · `error` treated as `denied` (never surfaced as a fault) · `granted` / `denied` (advance) · `unavailable` label "Not available on web." (`warn`), snackbar "Not available on web. You can turn this on in the phone app." or "Not available on this device."
- **Data:** writes `profiles.connected`. **A11y:** buttons 56 pt tall, same weight and width; rows read as label/value pairs. **Never:** mention the fully-connected reward; pre-select; use urgency.

### `perm-location` — Location while running
- Why "to measure distance and notice when you explore somewhere new" · Store "your route, visible to you alone" · Skip "Without it, runs are timed but not measured, and explorer animals stay hidden." · Extra state `while-in-use`: OS granted while-in-use; a follow-up row offers background ("Allow in the background, so a run keeps recording with the screen off"). **Exit:** `perm-motion`.

### `perm-motion` — Motion & fitness
- Why "to count steps and feel the rhythm of your footfall" · Store "step counts and two rhythm numbers per run — never raw sensor data" · Skip "Without it, we have less evidence that a run was a run, so more cards draw from the everyday bag." **Exit:** `perm-activity`.

### `perm-activity` — Activity recognition
- Why "to tell running from walking, cycling or a bus ride" · Store "time fractions per activity type for each run" · Skip "Without it, we rely on GPS and steps alone to confirm a run." **Exit:** `perm-health`.

### `perm-health` — Health · heart rate
- Why "to read effort from your watch and confirm a run with confidence" · Store "average and peak heart rate per run" · Skip "Without it, heart-rate evidence is skipped. Everything else still works." · Extra state `no-watch`: card still shown; copy adds "Needs a watch or Health app with heart-rate data." **Exit:** `perm-notifications`.

### `perm-notifications` — Notifications
- Why "to tell you when a weekly or monthly card is waiting" · Store "nothing extra — a device token on your phone" · Skip "Without it, new cards wait quietly on Today until you open the app." **Exit:** `fairness`.

### `fairness` — Optional birth year & sex
- **Purpose:** Offer age-grading inputs, pre-skipped, with the reason visible.
- **Entry:** `perm-notifications`. **Exit:** `onboarding-done` (Skip or Continue).
- **Primary:** "Skip" and "Continue" / "Save and continue" (equal weight). **Secondary:** "Why?" expander.
- **States:** `empty` default: nothing selected, "Grade effort fairly?" / "Optional. Used to grade effort fairly. Never shown to anyone." Birth year "Prefer not to say"; Sex Female / Male · `loading` saving, buttons busy · `success` → next · `error` "We couldn't save that right now. Try again in a moment." Skip remains enabled so the user is never stuck · `why-open` "A 7-minute kilometre at 62 is a different achievement from the same pace at 24. Age-grading uses standard tables so a strong effort earns a strong animal at every age. We keep birth year, never a full date."
- **Data:** writes `profiles.birth_year`, `profiles.sex`. **A11y:** dropdown and segmented control labelled; expander state announced. **Never:** required fields; full birth date; show these values anywhere else.

### `onboarding-done` — "Your first run opens the bag."
- **Purpose:** Close onboarding with the bag and one clear next step.
- **Entry:** `fairness`. **Exit:** `today` (sets `onboarding_done`).
- **Primary:** "Let's go". **Secondary:** none.
- **States:** `empty` n/a · `loading` button busy while prefs save · `success` bag illustration, "Your first run opens the bag." / "A run of 1 km or 10 minutes earns a card. See you outside." · `error` n/a (prefs are local; on failure still navigate).
- **Data:** none. **A11y:** illustration decorative; heading first. **Never:** the fully-connected reward (that lives in `permission-receipt`).

---

## Home

### `today` — Today tab
- **Purpose:** Show the latest card as hero, the week's run-days, and anything waiting (envelopes, celebrations); start a run.
- **Entry:** `onboarding-done`; tab bar; `run-finish` on `offline-saved`; `reveal` "Done" (no card); app foreground (calls `claim_pending_cards`). **Exit:** `run-ready` (FAB), `card-detail` (hero), `reveal` (envelope), `serial-search` (app-bar icon / "Verify a card"), other tabs.
- **Primary:** "Start a run" FAB. **Secondary:** open envelope, tap hero, verify a card, dismiss banner, pull-to-refresh.
- **States:** `empty` bag card: "Your first run opens the bag." / "Run. Get an animal. Collect India." · `loading` hero skeleton at card aspect; streak row renders from local runs · `success` hero card + "Latest card · {date}"; streak dots (7 days) + "{n} of the week · {r} more open(s) the weekly bag" or "{n} of the week · the weekly bag is open" · `error` bag card with "Couldn't load your cards. Pull down to try again." · `pending-envelope` section "Waiting for you": "A weekly card is waiting" / "{run_days} run-days this week. Tap to open." (monthly: "this month") · `banner-growth` "Your {animal} is all grown up!" · `banner-mastered` "You and your {animal} know each other well now." · `banner-welcome-back` "Welcome back. Your animals start small again — and so does the adventure." · `no-weekly-card` quiet line under the streak row at week rollover: "No weekly card this week — three run-days opens the weekly bag." · `offline-saved` snackbar "Saved. We'll fetch your card when you're back online." · `back-online` envelopes/hero refresh silently.
- **Triggers:** `weekly-card-ready`, `monthly-card-ready`, `no-weekly-card`, `animal-grew`, `animal-mastered`, `welcome-back`, `offline-saved`, `back-online`.
- **Data:** `cards` (latest), `runs` (last 7 days), `config.min_run_days`, `claim_pending_cards` → `scope`, `card`, `run_days`, `celebrations`; `events` (`kind`, `id`) + `mark_events_seen`.
- **A11y:** hero is a button, hint "Opens card details"; streak row label "Run-days in the last seven days: {n}. {hint}"; envelope label "A {scope} card is waiting. Open it."; banners persist until dismissed (never timed). FAB label is text, not icon alone.
- **Never:** leaderboard, ranking, friends' activity; any threshold other than the weekly minimum; pace judgement.

---

## Run

### `run-ready` — Run screen before start
- **Purpose:** Give people who like intent a big Start; auto-detected runs skip this screen.
- **Entry:** `today` FAB. **Exit:** `run-recording` on `run-started`; back → `today`.
- **Primary:** "Start" (220 × 64). **Secondary:** back.
- **States:** `empty` n/a · `loading` n/a · `success` "Ready when you are." / "Keep your phone with you. A run of 1 km or 10 minutes earns a card." · `error` n/a (sensor problems surface on `run-recording`).
- **Data:** `profiles.timezone`. **A11y:** Start is the first focusable element; medium haptic on start. **Never:** pace targets, goals, comparisons.

### `run-recording` — Live run
- **Purpose:** Keep time, distance and pace visible at arm's length; make GPS truth legible; make finishing deliberate.
- **Entry:** `run-ready` (`run-started`), or auto-detect. **Exit:** `run-finish` (Finish). No system back (`PopScope`); Pause is the "step away" action.
- **Primary:** "Finish". **Secondary:** "Pause" / "Resume".
- **States:** `empty` n/a · `loading` n/a · `success` = `gps-good`: pill "GPS" (`success`), title "Running", moving time 72 pt, "moving · {elapsed} total", stats km / pace /km / climb m · `error` n/a (every fault is a named state below) · `gps-searching` pill "Looking for GPS…" (`warn`), hint "Looking for GPS… time keeps counting; distance resumes with the next fix." · `gps-denied` pill "Timer", km "—", hint "This run is timed, not measured." · `while-in-use` pill "GPS · open app", hint "Location is allowed while the app is open. Keep the screen on, or allow background location under You → Permissions." · `paused` title "Paused", button "Resume" · `auto-paused` title "Auto-paused" (`run-auto-paused`) · `offline` no visual change while recording; submission handled by `run-finish` · `below-floor` dialog on Finish: "Finish this run?" / "Recorded. A run of 1 km or 10 minutes earns a card." → "Keep going" / "Finish anyway".
- **Triggers:** `gps-lost`, `gps-regained`, `run-auto-paused`, `run-ended`.
- **Data:** local recorder → `submit_run` payload (`elapsed_s`, `moving_s`, `track`, `distance_m`, `steps`, `splits_kmh`, `accel`, `activity`, `hr`, `state_code`, `timezone`).
- **A11y:** buttons 60 pt; pill = dot + text; timer not read continuously (announce on focus); screen stays awake; high-contrast numerals tabular.
- **Never:** map of the live route (prototype shows none), other runners, pace judgement of any kind, a destructive Finish without the floor check.

### `run-finish` — "Reading your run…"
- **Purpose:** Bridge the end of the run to the reveal while `submit_run` runs; absorb network trouble without losing the run.
- **Entry:** `run-recording` Finish (`run-ended`). **Exit:** `reveal` (replace) on response; `today` on `offline-saved`; back to `run-recording` with notice on other errors.
- **Primary:** none (automatic). **Secondary:** none; no cancel (the run is already saved locally).
- **States:** `empty` n/a · `loading` default: shimmering card back, "Reading your run…" / "Measuring, checking, choosing." (visual max 1.2 s; RPC timeout 30 s) · `success` → `reveal` with the full response · `error` run enqueued, return to recording with notice "We couldn't read this run right now. It's saved on your phone; we'll try again when you reopen the app." · `offline-saved` run enqueued, snackbar "Saved. We'll fetch your card when you're back online.", go `today`.
- **Data:** `submit_run` request → response (`run_id`, `verdict`, `card`, `celebrations`, `floor`, `capped`, `duplicate`, `message`). **A11y:** live region "Reading your run"; reduced motion: static card back, no shimmer. **Never:** a spinner with no words; data loss on failure.

---

## Cards

### `reveal` — Card reveal sequence
- **Purpose:** The one moment per run. Also opens weekly/monthly envelopes.
- **Entry:** `run-finish` (`run-ended` → `card-issued` / `rare-card-issued` / `run-floor-not-met` / `run-rejected` / `run-unverified` / `run-capped`); `today` envelope (`weekly-card-ready`, `monthly-card-ready`). **Exit:** tap anywhere → `card-detail`; no-card → "Done" → `today`.
- **Primary:** tap anywhere (whole screen). **Secondary:** none until revealed.
- **States:** `empty` "Nothing to open right now." + Done · `loading` scrim + "Reading your run…" or "Opening your envelope…" · `success` card back slides up (420 ms), pause, flips (600 ms), foil at 50 %, "Tap anywhere" after reveal · `error` n/a (upstream) · `rare` 24 edge particles (900 ms), success haptic · `captions` after flip, one at a time (2.6 s each): growth, mastered, discovery (see Celebrations) · `unverified` card revealed with `warn` outline tick; verdict copy lives on `card-detail` · `no-card` "Recorded" + one line + "Done": duplicate "This run is already in your ledger." · rejected "We couldn't confirm this one was a run — no card this time." · floor "Recorded. A run of 1 km or 10 minutes earns a card." · capped "Recorded and counted. Your card bag refills tomorrow." · fallback "Recorded. No card this time." · `reduced-motion` cross-fade 350 ms, no particles, no tilt, haptics kept.
- **Data:** `card.*` (name, slug, rarity, palette, art, stage, finish, season, serial, stats, verdict), `celebrations[]` (`kind`, `stage`, `animal`, `message`, `tier`, `trigger`), `verdict`, `floor`, `capped`, `duplicate`, `message`; from envelope: `scope`, `run_days`.
- **A11y:** semantics "Revealing your card" → "Card revealed. Tap anywhere to continue."; the whole screen is one target; captions are text; never auto-dismisses.
- **Never:** route, start point, time of day, heart rate; thresholds in any caption; a visibly smaller or duller treatment for the gentle family.

### `card-detail` — Card detail
- **Purpose:** Hold the card: stage, provenance ("earned N times, best serial"), run stats, verdict, share and verify controls.
- **Entry:** `reveal` tap; `today` hero; `collection` cell. **Exit:** `poster`; back.
- **Primary:** "Share poster". **Secondary:** "Copy verify link", toggle "Show on verify page", tilt the card.
- **States:** `empty` n/a · `loading` instant when the card is passed as `extra`; otherwise skeleton card at full size · `success` title = animal name; card with tilt foil; stage word; "Earned once · best #0009" / "Earned {n} times · best #0009"; rows Set (Everyday run / Weekly / Monthly), distance, time, pace, date; verdict panel "Verified ✓" + "This run checked out end to end, so it drew from the full bag." · `unverified` panel "Unverified" (`warn`) + "We couldn't fully verify this run, so it drew from the everyday bag." · `error` "We can't find that card in your ledger." + back · `toggle-error` snackbar "Couldn't save that right now. Try again in a moment." · `link-copied` snackbar "Verify link copied." · toggle subtitles: on "Anyone with the serial can see this card and your first name."; off "The serial still checks out, but the card stays with you."
- **Data:** `cards` row (`name`, `stage`, `rarity`, `serial`, `serial_no`, `scope`, `finish`, `season`, `stats`, `verdict`, `verify_url`, public flag); `bonds` / card count for earned/best. **A11y:** card label "Cheetah, young, epic, serial 42, earned 2 October 2026"; tilt is decorative; switch labelled with its consequence.
- **Never:** route map, start point, time of day, heart rate, age, sex; per-stage run counts.

### `poster` — Share poster
- **Purpose:** Export a 1080 × 1920 story with the card, serial, QR and wordmark — zero location.
- **Entry:** `card-detail`. **Exit:** OS share sheet; back to `card-detail` (`poster-exported`).
- **Primary:** "Share". **Secondary:** back.
- **States:** `empty` n/a · `loading` button "Making your poster…", disabled · `success` preview + "Your card and its serial. No route, no location." → share sheet · `error` snackbar "Couldn't make the poster this time. Try again in a moment."
- **Data:** `card.palette`, `art`, `serial`, `verify_url` (QR), `season`. **A11y:** preview labelled "Poster preview of {animal} #{serial}"; progress announced. **Never:** map, start point, health data, runner's name, stats beyond the card's own row.

---

## Collection

### `collection` — Collection grid
- **Purpose:** Show how big the world is and where you are in it, grouped by family, without revealing recipes.
- **Entry:** tab bar. **Exit:** `card-detail`.
- **Primary:** tap a card. **Secondary:** chips All · Run · Weekly · Monthly · Rare+; sort Newest / Rarest / Best serial; pull-to-refresh.
- **States:** `empty` "Your first run opens the bag." / "Every animal below is out there, waiting." with silhouettes still shown · `loading` skeleton grid; staggered fade-in 40 ms per card, max 320 ms · `success` family headers with "{owned} of {total}"; owned cards show count badge and best serial; unseen non-secret animals as "?" silhouettes · `error` "Couldn't load your collection. Pull down to try again." · `filter-empty` "Nothing in this set yet. Keep running — the bag is deep."
- **Data:** `cards`, `animals` (secret hidden until earned), `animal_counters`, `bonds`. **A11y:** cells labelled per DESIGN §10; silhouette label "An animal you haven't found yet"; chips are toggles with selected state; reduced motion removes the stagger.
- **Never:** secret animals as silhouettes; names of unseen animals; rank or percentile against others.

---

## Search & Verify

### `serial-search` — Serial lookup (the one search in the app)
- **Purpose:** Let anyone check a serial and see an official, calm answer.
- **Entry:** `today` (app-bar icon, "Verify a card"), `settings` row, deep link `/verify?q=`. **Exit:** back.
- **Primary:** search (submit). **Secondary:** clear field.
- **States:** `empty` "Verify a card" / "Type the serial printed on the card." field hint "Tiger #0427" · `loading` field busy, result area skeleton · `success` = `serial-found`: card, "Earned by {earned_by} on {date}" (or "Earned on {date}"), "{Animal} #{serial} of {issued_so_far} issued", seal "Real ✓ · lives in the Flying Cobra ledger" · `unverified` adds "We couldn't fully verify this run, so it drew from the everyday bag." · `not-found` = `serial-not-found`: "No such card. If someone showed you this, they're bluffing." + API `hint` or "Try the animal name and the number, like \"Tiger #0427\"." · `error` "Couldn't reach the ledger right now. Try again in a moment."
- **Data:** `lookup_serial` → `found`, `card`, `earned_by`, `stats`, `issued_so_far`, `reason`, `hint`. **A11y:** field labelled; result announced; seal label "Real. Lives in the Flying Cobra ledger."; serial in tabular Fraunces.
- **Never:** people search, location, route, health; an owner's full name.

---

## Encyclopedia

### `encyclopedia` — Encyclopedia list
- **Purpose:** Browse every known animal (names, families); learn, never be instructed.
- **Entry:** tab bar. **Exit:** `animal-entry` (sheet).
- **Primary:** tap an animal. **Secondary:** "Search animals" (name filter), pull-to-refresh.
- **States:** `empty` "The encyclopedia is filling up. Check back soon." · `loading` list skeleton · `success` family sections; rows art · name · flavour line; "×{n}" pill when earned · `error` "Couldn't load the encyclopedia. Pull down to try again." · `no-match` "No animal by that name — yet."
- **Data:** `animals` (secret absent until earned), `cards` count per slug. **A11y:** search field labelled "Search animals"; rows 56 pt; pill text not colour alone. **Never:** people, recipes, secret animals before they are earned.

### `animal-entry` — Animal entry sheet
- **Purpose:** One animal's facts, habitat, superpower and India note; your tally with it.
- **Entry:** `encyclopedia` row. **Exit:** drag down / close → `encyclopedia`.
- **Primary:** read. **Secondary:** close.
- **States:** `empty` sections with no content are omitted · `loading` n/a (data arrives with the list) · `success` art, name, flavour, pills (family · rarity · "Earned once" / "Earned {n} times"), sections Superpower · Facts · Habitat · Size · In India · `error` n/a · `not-owned` "Not in your collection yet. Keep running — it is out there."
- **Data:** `animals` (`name`, `flavour_line`, `facts`, `habitat`, `size`, `superpower`, `india_note`, `rarity`, `family`), card count. **A11y:** drag handle + close button (48 pt); focus moves into the sheet; heading announced. **Never:** how to earn it; thresholds; time windows.

---

## Settings

### `settings` — You tab
- **Purpose:** Trust centre first (profile, permission receipt), furniture below the fold, account actions last.
- **Entry:** tab bar. **Exit:** `permission-receipt`, `data-and-account`, `serial-search`, admin shell (admins), `sign-in` (after sign out).
- **Primary:** none (a receipt). **Secondary:** edit display name, home region, fairness fields; permission toggles; "Verify a card"; "Import from Health"; "Export my data"; "Delete my account"; "Sign out"; "Admin panel" (admins).
- **States:** `empty` furniture renders zeros (no hidden sections) · `loading` profile spinner at card size · `success` profile card ("Display name" / "Shown on your cards' verify pages"; "Home region" helper "Where you live is home, not a souvenir." default "Let my first run decide"; "Fairness (optional)" / "Used to grade effort fairly. Never shown."), receipt, totals, heat map, pace trend, actions · `error` "Your profile will appear once we can reach the server. Pull to refresh." · `working` actions disabled while one runs · `save-error` snackbar "We couldn't save that right now. Try again in a moment." · `import-result` snackbar from Health import · `sign-out-error` "Sign-out didn't complete. Try again in a moment."
- **Data:** `profiles` (`display_name`, `home_region`, `birth_year`, `sex`, `timezone`, `connected`, `is_admin`), `runs`, `cards`, `regions`. **A11y:** receipt rows before charts in reading order; charts have text summaries. **Never:** leaderboards, comparisons, showing age/sex beyond this screen.

### `permission-receipt` — Granular permissions
- **Purpose:** A receipt of what the app may read, why, and what each one costs to switch off; toggling is immediate.
- **Entry:** `settings`; `run-recording` hint "You → Permissions"; onboarding footer. **Exit:** back; OS settings deep link.
- **Primary:** per-row switch (`permission-toggled`). **Secondary:** background-location row; "Open phone settings".
- **States:** `empty` n/a · `loading` row-level spinner while a toggle saves · `success` title "Permissions", intro "A receipt of what this app may read, and what each one is for. Switching something off takes effect immediately."; rows: title · status On/Off · "Why: {why}." · "We keep {store}." or the skip line; "Fully connected" + "Thank you for trusting us with the full picture. Every kind of evidence counts on your runs." · `partial` locked silhouette: "Something waits for a fully connected runner" / "When every data purpose above is on, one more animal becomes possible. No hurry; it will wait." · `error` snackbar "We couldn't update that right now. Try again in a moment." · `os-denied` "Your phone remembers an earlier \"no\". Turn it on in phone settings when you're ready." · `unavailable` "Not available on this device." · `no-change` "No change made. You can allow it any time."
- **Data:** `profiles.connected` + live OS permission status. **A11y:** switches labelled "{purpose}, {On|Off}"; result announced; rows ≥ 56 pt. **Never:** dark patterns, pre-ticked upsells, the recipe of the fully-connected animal.

### `data-and-account` — Export my data, delete account
- **Purpose:** DPDP rights in two taps: take your data, or leave for good with a clear, calm confirmation.
- **Entry:** `settings`. **Exit:** OS share sheet (export); `sign-in` after `account-deleted`; back.
- **Primary:** "Export my data" ("Profile, runs and cards as JSON"). **Secondary:** "Delete my account" ("Removes everything. Takes effect immediately."), "Sign out".
- **States:** `empty` n/a · `loading` building export; actions disabled · `success` share sheet with `flyingcobra-export.json`, subject "My Flying Cobra data", text "Your Flying Cobra profile, runs and cards." (`data-exported`) · `error` "We couldn't build the export right now. Try again in a moment." · `confirm-delete` dialog "Delete your account?" / "This removes your profile, runs, routes and cards for good. Serial numbers you earned are retired, not reissued. There is no undo." → "Keep my account" / "Delete everything" (`danger`) · `delete-fallback` "Deletion isn't automated yet. Email support@flyingcobra.run from your account address and we'll remove everything within 7 days."
- **Data:** `runs` (stats fields), `cards`, `profiles`; export note "Routes (run_tracks) are kept privately and are not included in this export. Email support to request them." **A11y:** destructive action carried by label + colour + position; dialog focus lands on "Keep my account". **Never:** delete without confirmation; silent omission of what the export excludes.

---

## Celebrations (overlays and banners, not destinations)

### `celebration-growth` — "Your cheetah is all grown up!"
- **Purpose:** Mark a stage change as a gift, not a score.
- **Entry:** `reveal` caption (`animal-grew` in `celebrations[]`); `today` banner from `events` kind `growth`. **Exit:** reveal tap → `card-detail`; banner dismiss → `mark_events_seen`.
- **States:** `empty` n/a · `loading` n/a · `success` art cross-fades to the new stage (500 ms, radial wipe) + "Your {animal} is all grown up!" (banner without animal: "One of your animals is all grown up!") · `error` n/a · `reduced-motion` cross-fade without wipe.
- **Data:** `celebrations[kind=growth].stage/animal/message`; `events`. **A11y:** text first; success haptic. **Never:** runs-until-next-stage, stage numbers.

### `celebration-mastered` — Unlock the Wild
- **Entry:** `reveal` caption (`animal-mastered`); `today` banner from `events` kind `mastered`. **Exit:** as growth.
- **States:** `success` "You and your {animal} know each other well now." (fallback "You and one of your animals know each other well now."); `reduced-motion` text alone; others n/a.
- **Data:** `celebrations[]`, `events`. **Never:** what mastery unlocked, counts, comparisons with anyone else.

### `celebration-welcome-back` — After a 60-day break
- **Entry:** `today` banner on app open (`welcome-back`, `events` kind `welcome_back`). **Exit:** dismiss → `mark_events_seen`.
- **States:** `success` "Welcome back. Your animals start small again — and so does the adventure."; others n/a.
- **Data:** `events`. **A11y:** persists until dismissed. **Never:** days-missed counts, guilt, streak-lost language.

### `celebration-discovery` — First night / dawn / explorer / souvenir / migratory
- **Entry:** `reveal` caption when `celebrations[]` has `kind: discovery` (`discovery-time`, `discovery-explorer`, `discovery-souvenir`, `discovery-migratory`). **Exit:** reveal tap → `card-detail`.
- **States:** `success` one line under the card by trigger: night "You found this one because you ran at night." · dawn "You found this one because you ran at dawn." · explorer "You found this one because you ran somewhere new." · souvenir "A souvenir from {state}." · migratory "This one came with you, a long way from home." · `reduced-motion` caption fades 200 ms; others n/a.
- **Data:** `celebrations[].tier`, `trigger`, `state_code` → state name. **Never:** thresholds, distances, time windows, the recipe.

---

## System

### `setup-needed` — Supabase keys missing (internal builds)
- **Entry:** launch when the client has no keys. **Exit:** none (restart after configuration). **Primary:** none.
- **States:** `success` "Flying Cobra needs its Supabase keys. Copy app/.env.example to app/.env and paste the Project URL and anon key (MANUAL_TASKS.md, step 1), then restart the app."; others n/a.
- **Data:** none. **Never:** shipped in a public build.

---

## Navigation map
- Launch
  - `setup-needed` (internal; dead end until restart)
  - `sign-in` → `link-sent` → (link opened) `sign-in-complete`
  - Onboarding stack (forward, no back stack; every step skippable): `welcome` → `perm-location` → `perm-motion` → `perm-activity` → `perm-health` → `perm-notifications` → `fairness` → `onboarding-done`
- Tab shell (4 tabs, fade-through 200 ms, no slide stacks between tabs)
  - **Today** `today`
    - FAB → `run-ready` → `run-recording` → `run-finish` ⇒ replaces with `reveal` → `card-detail` → `poster`
    - envelope → `reveal` → `card-detail` → `poster`
    - hero → `card-detail` → `poster`
    - verify icon / link → `serial-search`
    - inline banners: `celebration-growth` · `celebration-mastered` · `celebration-welcome-back`
  - **Collection** `collection` → `card-detail` → `poster`
  - **Encyclopedia** `encyclopedia` → `animal-entry` (bottom sheet)
  - **You** `settings` → `permission-receipt` · `data-and-account` · `serial-search` · admin shell (admins) · `sign-in` (after sign out / `account-deleted`)
- Modal and overlay stack (top to bottom)
  - Full-screen scrim: `reveal` (captions `celebration-growth` → `celebration-mastered` → `celebration-discovery`)
  - Dialogs: "Finish this run?" (`run-recording`), "Delete your account?" (`data-and-account`)
  - Bottom sheet: `animal-entry`
  - Snackbars (4 s): offline-saved, link copied, save errors, permission results
- Deep links: `/verify?q=` → `serial-search`; `/card/:id` → `card-detail`; `/poster/:id` → `poster`

## Proposed additions
- `verify-web` — the public web page at `/v/<animal>/<serial>` (DESIGN §7). It shares `serial-search`'s found/not-found copy and seal but has its own layout (Open Graph card, store badges) and no tab shell. Worth a workbench page so the "friend verifies it" journey can be walked end to end.
- No new ID for the "Recorded / no card" outcome: it is modelled as `reveal` state `no-card` (with duplicate / rejected / floor / capped variants), matching the built `RevealScreen`.
- "Import from Health" is modelled as `settings` state `import-result`, not a screen; promote it to an ID if it grows a progress view.
