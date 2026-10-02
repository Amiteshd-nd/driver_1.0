# Flying Cobra — Interaction Spec

Per-screen animations, toasts and notifications, with the conditions that fire them. Screen IDs and trigger names come from `SCREEN_IDS.md` only. Timings start from DESIGN.md §6 and the shipped `reveal_screen.dart` / `collectible_card_view.dart`; every value here is a tunable default and maps 1:1 onto `interaction-config.json` (right panel of the workbench).

Principle (DESIGN §1): one moment per run. The reveal is the only long sequence; every other animation is short, purposeful and quieter than the reveal. Nothing competes with the card.

---

## 1. Motion system

### 1.1 Duration tokens (`motion.*`)

| Token | ms | Used for |
|---|---|---|
| `motion.instant` | 100 | Pressed states, toggle thumbs, selection ticks, focus rings |
| `motion.quick` | 200 | Tab fade-through (§6), chip select, toast enter, badge state swaps |
| `motion.standard` | 300 | Sheets, list rows, captions, cross-fades of content |
| `motion.emphasised` | 420 | Card back slide (§6), container transforms, celebration scrims |
| `motion.reveal` | 600 | Card flip (§6). Only the card uses it |
| `motion.celebrate` | 900 | Particle burst (§6), mastered burst |
| `motion.shimmer` | 1200 | "Reading your run…" shimmer loop (max one cycle, §6) |
| `motion.breathe` | 4000 | Radiant glow breathing (§3.3), bag/envelope idle glow |
| `motion.drift` | 6000 | Legendary animated-gradient border, one full hue cycle |

Stagger constants: `motion.staggerCard` 40 ms (grid, cap 320 ms, §6) · `motion.staggerRow` 40 ms (lists, cap 320) · `motion.staggerDot` 60 ms (streak dots) · `motion.staggerCell` 20 ms (heat map, cap 400).
Exit durations are 75 % of enter (M3 norm): a 200 ms toast enters in 200, leaves in 150.

### 1.2 Easing tokens (`easing.*`)

| Token | Curve (Flutter) | CSS | Used for |
|---|---|---|---|
| `easing.standard` | `Easing.standard` | `cubic-bezier(.2,0,0,1)` | Things that move on screen and stay (sheets, rows, toggles, cross-fades) |
| `easing.decelerate` | `Curves.easeOutCubic` | `cubic-bezier(.33,1,.68,1)` | Things entering (card back slide, toasts, result cards) |
| `easing.accelerate` | `Curves.easeInCubic` | `cubic-bezier(.32,0,.67,0)` | Things leaving (toast exit, dismissed sheets) |
| `easing.flip` | `Curves.easeInOutCubic` | `cubic-bezier(.65,0,.35,1)` | The Y-flip only; symmetric so the edge-on frame lands mid-way |
| `easing.spring` | `Curves.easeOutBack` | `cubic-bezier(.34,1.56,.64,1)` | Small celebratory settles ≤ 24 pt: dot fill, tick, seal stamp, envelope landing |
| `easing.linear` | `Curves.linear` | `linear` | Loops and progress (shimmer, hold rings, border drift) |

Rules: never spring anything larger than a badge; never accelerate an entrance; a loop never changes speed.

### 1.3 Reduced motion (`MediaQuery.disableAnimations` / `prefers-reduced-motion`)

Substitution rule, applied mechanically to every animation below unless its row says otherwise:
1. Any translate > 8 pt, any rotate, any scale > 1.04 or any 3D transform → opacity cross-fade of `min(duration, 350 ms)`, `easing.standard`.
2. Loops (shimmer, breathe, drift, pulses) stop at their rest frame (glow at mid value, border at hue 0, shimmer off).
3. Particles off; foil tilt term and time term off (static band at 30 % across the art).
4. Staggers collapse to 0; everything in the group appears together.
5. Haptics, copy, durations of auto-dismiss and sequence order are **unchanged**: a reduced-motion reveal is the same length and the same story, told with fades (DESIGN §6, §10).

### 1.4 Haptic vocabulary (`haptic.*`)

| Token | iOS / Android | Means |
|---|---|---|
| `haptic.light` | `lightImpact` | Something arrived or was selected (slide start, chip, dot) |
| `haptic.medium` | `mediumImpact` | A state committed (flip start, toggle, sheet snap, hold complete) |
| `haptic.heavy` | `heavyImpact` | A big thing landed (irreversible hold complete, mastered) |
| `haptic.success` | heavy, then light at +120 ms (shipped pattern) | A card or stage was earned — rare+ reveal, growth, mastered |
| `haptic.warn` | medium, medium at +90 ms | Attention without alarm: auto-pause, GPS lost |
| `haptic.none` | — | Default for everything not listed |

Pairing rules: one haptic per visual event, fired on the frame the thing *lands or commits*, not when it starts moving (exception: the reveal slide fires `light` at start because the card is still off-screen). Minimum 500 ms between patterns; `success` always wins a collision. Toasts never carry haptics (they are passive); banners never do; inline captions never do. Rejection, floor-not-met and not-found get `haptic.none`: no buzz for bad news (DESIGN §1.3, "slow is never shame"). Every family gets the same haptic volume for the same rarity.

### 1.5 Message durations (`toast.*`)

`toast.short` 3000 (confirmations) · `toast.standard` 4000 (information, M3 "short") · `toast.long` 6000 (anything the runner must read twice, e.g. a rejection) · `banner.persistent` until condition clears or tapped. Toast enter 200 `decelerate` from bottom (+16 pt → 0), exit 150 `accelerate`. Default position: bottom, 16 pt above the tab bar / safe area. Top is reserved for connectivity banners.

---

## 2. Per-screen interaction tables

Column notes: **Delay** is from the trigger (or from the previous step where the row says "after …"). **Trigger** uses the vocabulary; *enter*, *tap*, *drag*, *value change* in italics are lifecycle/gesture cues that always run and are not in the right-panel dropdown. **Reduced** is the reduced-motion variant where it differs from the §1.3 rule. Message **Tier** is from §3.

### Global (all tabbed screens: `today`, `collection`, `encyclopedia`, `settings`)

| Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|
| `tab-fade-through` | 200 | 0 | standard | *tap* tab | same (already a fade) | none |
| `press-scale` (buttons, cards: 1 → 0.97) | 100 | 0 | standard | *tap down* | none | none |
| `sheet-rise` (all bottom sheets) | 300 | 0 | decelerate | *tap* | fade 200 | light at snap |

### Onboarding

**`welcome` · `sign-in` · `fairness` · `onboarding-done`**

| Screen | Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|---|
| `welcome` | `paw-mark-draw` (stroke draws the four toes then pad; the only time the mark animates, DESIGN §2) | 800 | 0 | standard | `first-launch` | fade 300 | none |
| `welcome` | `promise-text-rise` (+12 pt → 0, fade) | 300 | 400 | decelerate | `first-launch` | fade | none |
| `sign-in` | `provider-sheet-rise` | 300 | 0 | decelerate | *tap* provider | fade 200 | light |
| `sign-in` | `sign-in-complete-tick` (24 pt tick) | 300 | 0 | spring | `sign-in-complete` | fade | medium |
| `fairness` | `why-expander` (height + fade) | 300 | 0 | standard | *tap* "Why?" | fade | none |
| `onboarding-done` | `bag-settle` (bag drops 16 pt, settles) | 420 | 0 | spring | *enter* | fade | light at land |
| `onboarding-done` | `bag-idle-glow` (outer glow 20 → 35 % alpha loop) | 4000 | 420 | linear (sine) | *enter* | static 28 % | none |

Messages (all inline, no toasts): `welcome` after `account-deleted`: "Your account and cards are gone. Thank you for running with us." · `sign-in` success: "Check your inbox. The link works for 10 minutes." · `sign-in` error: "That link has expired. We've sent a fresh one." · `onboarding-done` headline: "Your first run opens the bag."

**`perm-location` · `perm-motion` · `perm-activity` · `perm-health` · `perm-notifications`** (one shared block; each screen is an instance)

| Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|
| `perm-card-enter` (card +24 pt → 0, fade) | 300 | 0 | decelerate | *enter* | fade | none |
| `perm-icon-settle` (icon 0.9 → 1.0) | 420 | 100 | spring | *enter* | none | none |
| `perm-granted-tick` (status pill → tick) | 300 | 0 | spring | `permission-granted` | fade | medium |
| `perm-denied-settle` (status pill → "Not now", same weight as Allow) | 200 | 0 | standard | `permission-denied` | same | none |
| `perm-advance` (card slides out left, next slides in) | 300 | 250 | standard | `permission-granted` / `permission-denied` | fade | none |

Messages: none. Permission screens never toast and never nag (DESIGN §8). Denied → inline caption "No problem. You can turn this on any time in You."

### Home

**`today`**

| Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|
| `hero-card-enter` (last card, +16 pt → 0, fade) | 300 | 0 | decelerate | *enter* | fade | none |
| `streak-dot-fill` (dot fills 0 → 1 scale, stagger `staggerDot`) | 240 | 0 | spring | `run-ended` (first view after) · *enter* | instant fill | light, once, on the newest dot |
| `weekly-count-tick` (old numeral rolls up, new rolls in) | 200 | 240 | standard | `run-ended` | swap | none |
| `envelope-arrive` (envelope drops from −24 pt, lands) | 420 | 0 | spring | `weekly-card-ready` / `monthly-card-ready` | fade | medium at land |
| `envelope-glow` (glow 25 → 45 % alpha, family accent) | 4000 | 420 | linear (sine) | `weekly-card-ready` / `monthly-card-ready` | static 35 % | none |
| `envelope-open` (envelope scales 1.06 and fades; hands off to `reveal`) | 300 | 0 | standard | *tap* envelope | fade | light |

| Message | Tier | Text | Dur | Pos | Dismiss | Trigger |
|---|---|---|---|---|---|---|
| `banner-no-weekly` | banner | "No weekly card this week — three run-days opens the weekly bag." | persistent (clears on next run-day) | inline under streak row | tap ✕ | `no-weekly-card` |
| `banner-offline` | banner | "You're offline. Runs are saved on your phone and upload later." | persistent | top | auto on `back-online` | `offline-saved` |
| `toast-back-online` | toast | "Back online. Everything's uploaded." | 3000 | bottom | auto · swipe | `back-online` |
| `toast-run-capped` | toast | "Recorded and counted. Your card bag refills tomorrow." | 4000 | bottom | auto · swipe | `run-capped` (auto-detected run, app opened later) |

State: `empty` shows the bag illustration with `bag-idle-glow`; `loading` shows a hero skeleton (shimmer 1200, no text).

### Run

**`run-ready` · `run-recording`** (`run-recording` states: `gps-good`, `gps-searching`, `gps-denied`, `auto-paused`, `offline`)

| Screen | Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|---|
| `run-ready` | `gps-pill-pulse` (pill dot 60 → 100 % alpha loop while searching) | 1200 | 0 | linear (sine) | *enter* while `gps-searching` | static 80 % | none |
| `run-ready` | `gps-pill-ready` (dot turns `success`, label swaps) | 200 | 0 | standard | `gps-regained` | same | none |
| `run-ready` | `start-expand` (Start button container-transforms into the recording layout) | 420 | 0 | standard | `run-started` | fade 300 | medium |
| `run-recording` | `distance-roll` (tabular digits roll on value change; timer digits never animate) | 300 | 0 | standard | *value change* | swap | none |
| `run-recording` | `gps-pill-state` (pill colour + label cross-fade) | 200 | 0 | standard | `gps-lost` / `gps-regained` | same | warn on lost, none on regained |
| `run-recording` | `auto-pause-dim` (stats to 60 % alpha, "Paused" label rises) | 300 | 0 | standard | `run-auto-paused` | fade | warn |
| `run-recording` | `auto-resume-lift` (reverse of dim) | 300 | 0 | standard | *movement resumes* | fade | light |
| `run-recording` | `stop-hold-ring` (ring fills around Stop while held; release cancels) | 800 | 0 | linear | *hold* Stop | same (progress, not motion) | light at start, medium at complete |

Messages (all inline; a run is glanceable and never toasts): `run-ready` pill caption "Finding GPS…" / "Ready" / "Location is off. Turn it on in You to measure distance." (`gps-denied`) · `run-recording`: "GPS is wandering. Distance pauses until it's back." (`gps-lost`) · "Paused — you stopped moving. It resumes when you do." (`run-auto-paused`) · "Offline. This run is safe on your phone." (`offline`).

**`run-finish`**

| Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|
| `finish-summary-rise` (stats card +24 pt → 0) | 300 | 0 | decelerate | *hold complete* | fade | none |
| `reading-scrim` (scrim to 85 %, "Reading your run…" with `reading-shimmer`) | 200 | 0 | standard | `run-ended` | same | none |
| `reading-shimmer` (text shimmer; max one cycle while the RPC runs, DESIGN §6) | 1200 | 0 | linear | `run-ended` | static text | none |

| Message | Tier | Text | Dur | Pos | Dismiss | Trigger |
|---|---|---|---|---|---|---|
| `toast-run-floor` | toast | "Recorded. A run of 1 km or 10 minutes earns a card." | 4000 | bottom | auto · swipe | `run-floor-not-met` |
| `toast-run-rejected` | toast | "We couldn't confirm this one was a run — no card this time." | 6000 | bottom | auto · tap · swipe | `run-rejected` |
| `toast-run-capped-now` | toast | "Recorded and counted. Your card bag refills tomorrow." | 4000 | bottom | auto · swipe | `run-capped` |
| `toast-offline-saved` | toast | "Saved on your phone. We'll open the bag when you're back online." | 4000 | bottom | auto · swipe | `offline-saved` |

`card-issued` / `rare-card-issued` / `run-unverified` do **not** toast here: they route to `reveal`. After a verdict toast the screen returns to `today` on dismiss.

### Cards

**`reveal`** (also weekly / monthly / claimed celebrations). T0 = RPC resolved (≤ 1200 ms after `run-ended`); the shipped 500 ms hold before the slide is `reveal.preSlideHold`.

| Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|
| `reveal-scrim` (dark scrim fade in; carries over from `reading-scrim`) | 200 | 0 | standard | `card-issued` / `rare-card-issued` / `weekly-card-ready` / `monthly-card-ready` | same | none |
| `card-back-slide` (card back from +120 % height to centre) | 420 | T0 + 500 | decelerate | ↑ | card face fades in 350 at T0 + 500 | light at start |
| `card-flip` (Y rotation 0 → π; back shows to 50 %, face after) | 600 | after slide + 300 | flip | ↑ | skipped (face already shown) | medium at start |
| `foil-reveal` (foil/sheen alpha 0 → 1, starts at 50 % of flip) | 300 | flip + 300 | standard | `card-issued` if `rarity.finish ≠ matte` | static band | none |
| `reveal-particles` (`rarity.particleCount` dots burst from the card edge, 24 pt lift, fade) | `rarity.particleMs` (900) | flip end | decelerate | `rare-card-issued` | off | success at flip end |
| `caption-rise` (celebration/discovery caption +20 % → 0, fade; next caption every `reveal.captionCadence` 2600) | 350 | flip end + `rarity.revealHold` (500) | decelerate | `animal-grew` · `discovery-*` · `run-unverified` | fade 350 | none (growth has its own) |
| `growth-crossfade` (art cross-fades to the new stage with a radial wipe from art centre) | 500 | caption + 250 | out `accelerate` / in `decelerate` | `animal-grew` | plain fade 350 | success |
| `tap-anywhere-hint` ("Tap anywhere", 60 % alpha) | 400 | flip end + 900 | standard | ↑ | same | none |
| `reveal-dismiss` (card shared-element to `card-detail`) | 420 | 0 | standard | *tap* | fade 200 | none |

Default timeline (common card): T0+500 slide → T0+1220 flip → T0+1520 foil → T0+1820 revealed → T0+2320 first caption → T0+2720 hint. A tap before "revealed" **skips ahead** to the revealed frame (shipped behaviour); it never ignores the tap.
Messages: **no toast, banner or push may appear on `reveal`**, ever. Captions (inline tier) only: "Your cheetah is all grown up!" (`animal-grew`) · "You found this one because you ran at night." (`discovery-time`) · "A souvenir from Kerala." (`discovery-souvenir`) · "We couldn't fully verify this run, so it drew from the everyday bag." (`run-unverified`, shown with the `warn` outline tick).

**`card-detail`**

| Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|
| `detail-hero-transform` (shared element from grid/reveal to full card) | 420 | 0 | standard | *enter* | fade 200 | none |
| `foil-tilt` (shader band follows gyroscope + slow time term; web: time only) | continuous | 0 | — | *tilt* if `rarity.finish ∈ {sheen, foil}` | static band | none |
| `legendary-border-drift` (gradient hue cycle + corner marks) | 6000 loop | 0 | linear | *enter* if `rarity.borderAnimated` | hue 0 | none |
| `radiant-breathe` (outer glow alpha 25 ↔ 45 %, reverse loop) | 4000 loop | 0 | standard (sine) | *enter* if `finish = radiant` | static 45 % | none |
| `stat-row-stagger` (stage · earned N times · best serial, 3 rows) | 200 each | 40 stagger | decelerate | *enter* | together | none |
| `verify-toggle` ("Show on verify page" thumb) | 200 | 0 | standard | *tap* | same | medium |

Messages: inline caption under the toggle: "Shown on your verify page." / "Hidden from your verify page." No toasts.

**`poster`**

| Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|
| `poster-compose` (gradient, card at 70 %, serial, QR fade in as a unit) | 300 | 0 | decelerate | *enter* | fade | none |
| `export-progress` (indeterminate ring on the Share button) | 1200 loop | 0 | linear | *tap* Share | same | none |
| `export-done-tick` (ring → tick) | 300 | 0 | spring | `poster-exported` | fade | medium |

| Message | Tier | Text | Dur | Pos | Dismiss | Trigger |
|---|---|---|---|---|---|---|
| `toast-poster-exported` | toast | "Poster saved. No route, no location — the card and its serial." | 3000 | bottom | auto · swipe | `poster-exported` |

### Collection

**`collection`**

| Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|
| `grid-stagger-fade` (40 ms per card, cap 320, DESIGN §6) | 200 each | 40 stagger | decelerate | *enter* · filter change | together | none |
| `filter-chip-select` (chip fill + label colour) | 200 | 0 | standard | *tap* chip | same | light |
| `sort-reorder` (cards move to new positions) | 300 | 0 | standard | *tap* sort | swap | none |
| `new-card-badge-pop` ("New" pip on the newest card) | 240 | 320 | spring | `card-issued` (next visit) | fade | none |
| `silhouette-reveal` ("?" silhouette cross-fades to art when first earned) | 300 | 0 | standard | `card-issued` (next visit) | same | none |

Messages: `empty` state inline "Your first run opens the bag." No toasts.

### Search & Verify

**`serial-search`**

| Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|
| `serial-field-focus` (accent focus ring, tabular placeholder) | 200 | 0 | standard | *focus* | same | none |
| `result-card-rise` (card +24 pt → 0) | 300 | 0 | decelerate | `serial-found` | fade | light |
| `ledger-seal-stamp` ("Real ✓ · lives in the Flying Cobra ledger" seal 1.2 → 1.0) | 300 | 150 | spring | `serial-found` | fade | medium |
| `not-found-settle` (field hairline → `inkMuted`, caption fades in; no shake) | 200 | 0 | standard | `serial-not-found` | same | none |

Messages: inline "Earned by Priya on 28 Sep 2026 · #0042 of 118 issued" (`serial-found`) · inline "No such card. If someone showed you this, they're bluffing." (`serial-not-found`). No toasts: the verify surface is calm and official (DESIGN §1.5).

### Encyclopedia

**`encyclopedia` · `animal-entry`**

| Screen | Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|---|
| `encyclopedia` | `list-stagger-fade` (40 ms per row, cap 320) | 200 each | 40 stagger | decelerate | *enter* | together | none |
| `encyclopedia` | `search-filter-crossfade` (list cross-fades as the query narrows) | 200 | 0 | standard | *type* | same | none |
| `animal-entry` | `entry-sheet-rise` (bottom sheet to 90 %) | 300 | 0 | decelerate | *tap* row | fade 200 | light at snap |
| `animal-entry` | `fact-sections-stagger` (facts · habitat · superpower · India note) | 200 each | 40 stagger | decelerate | *enter* | together | none |
| `animal-entry` | `entry-sheet-dismiss` (drag follows finger; release below 50 % flings out) | 300 | 0 | accelerate | *drag* | fade 150 | none |

Messages: inline "Earned 3 times" badge on `animal-entry` if owned. No toasts.

### Settings

**`settings` · `permission-receipt` · `data-and-account`**

| Screen | Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|---|
| `settings`, `permission-receipt` | `receipt-row-toggle` (thumb + row status + "what you lose" caption swap) | 200 | 0 | standard | `permission-toggled` | same | medium |
| `settings` | `fully-connected-crossfade` (reward row: locked silhouette ↔ animal) | 300 | 200 | standard | `permission-toggled` | same | none |
| `settings` | `heatmap-fill` (calendar cells fill, 20 ms stagger, cap 400) | 200 each | 20 stagger | standard | *scroll into view* | together | none |
| `permission-receipt` | `row-why-expand` (plain-language why + what we store) | 300 | 0 | standard | *tap* row | fade | none |
| `data-and-account` | `export-progress` (reused, on the Export row) | 1200 loop | 0 | linear | *tap* Export | same | none |
| `data-and-account` | `delete-hold-ring` (hold-to-confirm ring; release cancels) | 1500 | 0 | linear | *hold* Delete | same | light at start, heavy at complete |

| Message | Tier | Text | Dur | Pos | Dismiss | Trigger |
|---|---|---|---|---|---|---|
| `toast-data-exported` | toast | "Your export is ready — everything we hold about you, in one file." | 6000 | bottom | auto · tap (opens share sheet) · swipe | `data-exported` |

`settings` and `permission-receipt` never toast: toggling off is immediate and the row itself is the confirmation (DESIGN §7). `account-deleted` is not a toast: the `data-and-account` `success` state is a full-bleed calm page, then `welcome` with its inline caption.

### Celebrations (full-screen tier; each is also reachable standalone when claimed at app open)

**`celebration-growth` · `celebration-mastered` ("Unlock the Wild") · `celebration-welcome-back` (after a 60-day break; warm, not loud) · `celebration-discovery`**

| Screen | Animation | Dur | Delay | Easing | Trigger | Reduced | Haptic |
|---|---|---|---|---|---|---|---|
| all four | `celebration-scrim` (scrim to `celebration.scrimAlpha` 85 % in family `bg` tint; 92 % on mastered) | 420 | 0 | standard | the screen's trigger | fade 300 | none |
| `celebration-growth` | `growth-crossfade` (reused; art scales from `stage.<from>.artScale` to `stage.<to>.artScale` under the wipe) | 500 | 250 | out accelerate / in decelerate | `animal-grew` | plain fade | success |
| `celebration-growth` | `growth-headline-rise` ("Your tortoise is all grown up!") | 350 | 600 | decelerate | `animal-grew` | fade | none |
| `celebration-mastered` | `mastered-card-rise` (adult card +32 pt → 0) | 420 | 200 | decelerate | `animal-mastered` | fade | light |
| `celebration-mastered` | `wild-particles` (24 dots, family accent + `secret` violet) | 900 | 620 | decelerate | `animal-mastered` | off | success at start |
| `celebration-mastered` | `wild-headline-rise` ("You've mastered the cheetah. The Wild is open.") | 350 | 900 | decelerate | `animal-mastered` | fade | none |
| `celebration-welcome-back` | `animals-shrink` (three hero animals cross-fade adult → baby, scale 1.0 → 0.72) | 600 | 300 | standard | `welcome-back` | fade | light |
| `celebration-welcome-back` | `welcome-back-headline-rise` ("Welcome back. Your animals start small again — and so does the adventure.") | 350 | 700 | decelerate | `welcome-back` | fade | none |
| `celebration-discovery` | `discovery-tint-wash` (scrim washes to the discovery family palette: indigo, peach, ochre, teal, sky) | 600 | 0 | standard | `discovery-time` / `discovery-explorer` / `discovery-souvenir` / `discovery-migratory` | instant tint | medium |
| `celebration-discovery` | `caption-rise` (reused; copy from DESIGN §9, never a threshold) | 350 | 400 | decelerate | ↑ | fade | none |

Discovery copy: "You found this one because you ran at night." / "…because you ran at dawn." (`discovery-time`) · "You found this one somewhere new." (`discovery-explorer`) · "A souvenir from Kerala." (`discovery-souvenir`) · "This one followed you across the map." (`discovery-migratory`).

### System

**`setup-needed`** — no animation. Inline error: "Internal build: Supabase keys are missing. Add them to `.env` and restart." No haptic, no toast.

### Push notifications (outside any screen; see §3)

| Message | Text | Trigger | Rules |
|---|---|---|---|
| `push-weekly-ready` | "Your weekly card is waiting." | `weekly-card-ready` | Mon 08:00 IST; opens `today` with the envelope |
| `push-monthly-ready` | "Your October card is ready to open." | `monthly-card-ready` | 1st of month 08:00 IST |
| `push-welcome-back` | "Welcome back. The bag is still here." | `welcome-back` | Once, on first open after 60 days (local, not remote) |

Never pushed: reveals, growth, discoveries, verdicts, streak nudges, GPS states.

---

## 3. Toast and notification hierarchy

| Tier | What it is | Allowed when | Haptic |
|---|---|---|---|
| 1 · Inline caption | Text in the layout, under the thing it describes; no chrome | Always; the default for state changes, verdicts the user is looking at, discovery lines | none |
| 2 · Banner | Persistent strip (top for connectivity, inline for a standing condition); has a reason to stay | A condition that persists: offline, no weekly card this week | none |
| 3 · Toast | Transient bottom message, 3–6 s | Something finished off-screen or will not be re-shown: export done, poster saved, run verdict, back online | none |
| 4 · Full-screen celebration | Scrim + card/art + one headline | Growth, mastered, welcome back, discovery (and the reveal itself) | success / medium |
| 5 · Push notification | OS notification | Only weekly/monthly card ready and welcome back; quiet hours 22:00–07:00 IST | OS |

Rules:
1. **Max one visible message per screen, across tiers 2–3.** A new toast replaces the current one (exit 150, enter 200); it never stacks. Duplicates within 10 s are dropped.
2. **Never during the reveal.** From `run-ended` until `reveal-dismiss` completes, tiers 2–3 and 5 are queued; the queue is flushed on `today`, one at a time, lowest tier first. Celebrations (tier 4) chain *after* the reveal as captions, never over it.
3. **Never during `run-recording`.** GPS and pause states are inline; connectivity is inline. The runner is moving.
4. A toast is a courtesy, not a gate: everything it says is also visible somewhere persistent (the run's row, the receipt, the collection). Nothing important lives only in a toast.
5. Toasts are swipe-dismissable and pause their timer while the finger is down; `toast.long` toasts are also tap-dismissable.
6. Voice (DESIGN §2, §9): second person, one sentence, max one "!" per screen (spent by the celebration headline, so toasts never use one). Never "slow", "lazy", "only", "just", "failed", "better than".
7. Bad news (rejected, floor not met, not found, denied) uses the lowest tier that still gets read, `haptic.none`, `ink` not `danger` text, and offers the path forward in the same sentence.

---

## 4. Rarity and tier expression (token-driven)

Rarity is border and finish, never size or animal colour (DESIGN §3.3). Stage is art scale and pose, never border. Finish is glow. Family changes palette only, never celebration volume (DESIGN §1.3). Adding a rarity, stage or finish means adding a token row, not a component.

### 4.1 Rarity tokens (`rarity.<r>.*`)

| Token | common | uncommon | rare | epic | legendary |
|---|---|---|---|---|---|
| `borderWidth` (pt) | 1 | 1.5 | 2 | 2.5 | 3 |
| `borderStyle` | `hairline(line)` | `solid(accent)` | `gradient(accent→white)` | `gradient + innerHairline` | `animatedGradient + cornerMarks` |
| `borderAnimated` (`drift` 6000) | no | no | no | no | yes |
| `finish` | matte | matte | sheen (tilt only) | foil (shader) | foil (shader) |
| `foilIntensity` | 0 | 0 | 0.35 | 0.8 | 1.0 |
| `particleCount` | 0 | 0 | 8 | 16 | 24 |
| `particleMs` | — | — | 900 | 900 | 1200 |
| `flipMs` | 600 | 600 | 600 | 660 | 720 |
| `revealHold` (flip end → first caption) | 500 | 500 | 500 | 650 | 800 |
| `revealHaptic` | light (slide) + medium (flip) | same | + success | + success | + success |
| `revealSound` (respects silent switch; off by default) | none | none | `chime-soft` | `chime-bright` | `chime-full` |
| `pipLabel` (caption row, always text, DESIGN §10) | Common | Uncommon | Rare | Epic | Legendary |

`rare-card-issued` fires for rare and above. The flip grows at most 20 % so the whole reveal stays under 3 s before the first caption; anticipation comes from `revealHold`, not from slowing the card.

### 4.2 Stage tokens (`stage.<s>.*`)

| Token | baby | young | adult |
|---|---|---|---|
| `artScale` (of art area) | 0.72 | 0.86 | 1.0 |
| `artOffsetY` (pt, lower = grounded) | +12 | +6 | 0 |
| `pose` | `baby` | `young` | `adult` |
| `label` (detail view only) | Baby | Young | Adult |

Growth: `growth-crossfade` 500 interpolates `artScale`/`artOffsetY` under a radial wipe from the art centre; `haptic.success`; copy "Your {animal} is all grown up!" at adult, "Your {animal} is growing." at young (no "!" — the one per screen is saved for adult). Welcome back reverses the scale over 600 with `haptic.light`.

### 4.3 Finish tokens (`finish.<f>.*`)

| Token | plain | glow | radiant |
|---|---|---|---|
| `glowBlur` (pt) | 0 | 12 | 24 |
| `glowAlpha` | 0 | 0.35 | 0.25 ↔ 0.45 |
| `glowBreatheMs` | — | — | 4000 (reverse loop; reduced: static 0.45) |
| `glowColor` | — | family `accent` | family `accent`, tinted by season palette in-season |
| `revealExtra` | — | glow fades in with `foil-reveal` (300) | glow fades in with `foil-reveal`, breathe starts at flip end |

Finish never changes haptics or sound: it rewards consistency, and a radiant common must feel exactly as warm as a radiant legendary minus the rarity layer.

---

## 5. Open decisions for the designer (right-panel knobs)

Each is a key in `interaction-config.json`, with the default above and the range the workbench should allow.

1. `reveal.preSlideHold` — 500 ms shipped vs 0 ms in DESIGN §6. Does the breath before the slide help, or does it read as lag? (0–1000)
2. `reveal.slideFlipPause` — 300 ms. Shorter feels eager; longer builds anticipation. (0–800)
3. `rarity.*.flipMs` — flat 600 vs scaling to 720 for legendary. Should rarity ever slow the card? (400–900)
4. `rarity.*.particleCount` — DESIGN §6 says rare+ gets particles, §3.3 and the code give them only to legendary. Default here is 8/16/24; confirm or zero out rare and epic. (0–48)
5. `reveal.captionCadence` — 2600 ms auto-advance vs tap-to-advance when more than one caption chains (growth + discovery). (1500–4000, or `tap`)
6. `reveal.tapBeforeRevealed` — skip-ahead (shipped) vs ignore. Skip respects impatience; ignore protects the moment.
7. `rarity.*.revealHold` — 500/650/800. Is the longer legendary hold felt, or wasted? (300–1200)
8. `toast.standard` — 4000 vs 3000; and whether verdict toasts (`toast-run-rejected`) deserve `toast.long` 6000 or a banner on `today` instead.
9. `today.envelopeGlow` — 4 s breathe vs a 2 s shimmer pass every 8 s; and whether the envelope should breathe at all when the user has not opened the app in a week (attention vs nag).
10. `run.stopHoldMs` 800 and `account.deleteHoldMs` 1500 — hold-to-confirm lengths; too short invites accidents, too long feels broken. (500–2500)
11. `today.streakDotStagger` — 60 ms; and whether the newest dot alone should spring while older dots fill instantly.
12. `rarity.*.revealSound` — sounds off by default. If on, should common/uncommon stay silent?
13. `push.quietHours` — 22:00–07:00 IST default; and weekly push at Monday 08:00 vs Sunday evening.
14. `growth.wipe` — radial wipe vs plain cross-fade; 500 ms vs 700 ms when the stage jump is baby → adult (welcome back → first run).
15. `celebration.scrimAlpha` — 85 % (growth, welcome back, discovery) vs 92 % (mastered); and `motion.reducedCrossfadeCap` 350 ms for all reduced-motion substitutions.
