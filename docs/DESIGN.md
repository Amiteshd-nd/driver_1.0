# Pugmark — Design System & Experience Spec

The card is the hero. Everything else is furniture. This document is the single source for visual language, motion, information architecture, copy voice and the consent experience. Flutter implementation lives in `app/lib/core/theme/`.

---

## 1. Experience principles (how we decide)

1. **One moment per run.** The whole app exists for the three seconds after a run ends: the reveal. Every other screen is quieter than the reveal.
2. **Discovery over instruction.** We never show the recipe. We show that recipes exist: a locked silhouette, a line of copy ("some animals only come out at night"), never a threshold.
3. **Slow is never shame.** No animal copy, badge, colour or sound may read as lesser. The gentle family gets the same foil, the same celebration volume, the same card weight.
4. **Zero-input by default.** No start button is required (auto-detect via platform activity recognition), but a big manual Start exists for people who like intent. No forms after onboarding.
5. **Trust is a feature.** Serial numbers are typeset like banknote serials. The verify page looks official and calm. The settings page reads like a receipt of what we hold and why.
6. **India-first.** Hindi/English bilingual microcopy hooks (i18n keys from day one), 12-hour clock, km only, IST default, monsoon/festival seasons, Indian species and places.

---

## 2. Brand

- **Name:** Pugmark (working). A pugmark is a tiger's footprint, the unit of India's wildlife census. "Leave your pugmark" is the tagline.
- **Mark:** a four-toed paw print whose pad is a rounded trapezoid, drawn with the same corner radius as the card (16 pt). Single colour. Never animated except on first launch.
- **Voice:** warm, brief, a little playful, never sarcastic. Second person. Celebrates without exclamation-mark spam (max one `!` per screen).

---

## 3. Colour

Design tokens are semantic. Family palettes come from the database (`animals.palette`) so the admin can retune without a release; the tokens below are the app chrome.

### 3.1 Chrome (light / dark)

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#F7F3EC` (bone) | `#121311` | app background |
| `surface` | `#FFFFFF` | `#1C1E1B` | cards, sheets |
| `surfaceAlt` | `#EFE9DE` | `#262925` | secondary panels, calendar cells |
| `ink` | `#1B1B18` | `#F2EFE8` | primary text |
| `inkMuted` | `#6B6A63` | `#A5A49C` | secondary text |
| `line` | `#E2DCD0` | `#33362F` | hairlines |
| `accent` | `#C8551B` (burnt saffron) | `#F08A4B` | primary action, focus ring |
| `accentInk` | `#FFFFFF` | `#1B1B18` | text on accent |
| `success` | `#2E7D5B` | `#59B98F` | verified badge |
| `warn` | `#B3791C` | `#E0A94C` | unverified badge |
| `danger` | `#A33A2B` | `#E0695A` | rejected, destructive |

### 3.2 Family palettes (seeded in DB; shown for reference)

| Family | bg | fg | accent | Mood |
|---|---|---|---|---|
| swift | `#F5E2C8` | `#5A2E0C` | `#E0902F` | warm amber, sand |
| steady | `#D9E7D6` | `#1F3D2B` | `#4F8A5B` | forest |
| calm | `#E6DFF0` | `#3A2E57` | `#8B74C9` | dusk lavender |
| gentle | `#F1DCD1` | `#5B2F22` | `#C76A4E` | terracotta |
| time (night) | `#1F2340` | `#E7E4FF` | `#8FA3FF` | indigo |
| time (dawn) | `#FFE3D1` | `#5B3123` | `#FF9D6E` | peach |
| explorer | `#F3E3B8` | `#4E3B10` | `#D1A233` | ochre |
| regional | `#D3ECEA` | `#134845` | `#2E9C96` | teal |
| weekly | `#F0D4D8` | `#5A1322` | `#B82A47` | crimson |
| migratory | `#D7E8F7` | `#143A5C` | `#3E86C8` | sky |
| secret | `#E7DAF5` | `#3C1F5E` | `#9D6AE3` | iridescent violet |
| national | `#FBE4C6` | `#6B3A0E` | `#F2A33A` | saffron |

Contrast: all `fg` on `bg` pairs ≥ 7:1. Never place `inkMuted` on family `bg`.

### 3.3 Rarity

Rarity is expressed by **border and finish**, never by size or by colour of the animal.

| Rarity | Border | Finish treatment |
|---|---|---|
| common | 1 pt `line` hairline | matte |
| uncommon | 1.5 pt family `accent` | matte |
| rare | 2 pt gradient (family accent → white) | subtle sheen on tilt |
| epic | 2.5 pt gradient + inner hairline | holographic foil (shader) |
| legendary | 3 pt animated gradient + corner marks | full foil + particle dust on reveal |

Consistency finishes (`plain / glow / radiant`) add a soft outer glow (`glow`: 12 pt blur at 35 % of family accent; `radiant`: 24 pt blur, animated breathing 4 s cycle) and, in-season, tint the glow with the season palette.

---

## 4. Typography

Two families, both open-licence (bundled as assets; Google Fonts fallback):

- **Display:** *Fraunces* (variable, optical size). Animal names, serial numbers, headlines. Serial numbers use `Fraunces` with tabular figures, `font-feature-settings: "tnum"`, letter-spacing 0.08 em, so `#0427` reads like a banknote.
- **Text:** *Manrope*. Everything else.

| Role | Font | Size / line | Weight |
|---|---|---|---|
| Card animal name | Fraunces | 28 / 32 | 600 |
| Card serial | Fraunces | 18 / 22, tabular | 500 |
| Card flavour | Manrope | 14 / 20, italic | 400 |
| Screen title | Fraunces | 24 / 30 | 600 |
| Body | Manrope | 16 / 24 | 400 |
| Caption / meta | Manrope | 13 / 18 | 500, +0.02 em |
| Stat numeral | Fraunces | 22 / 26, tabular | 500 |

Minimum touch target 48 × 48 pt. Dynamic Type supported to 1.3×; the card scales as a unit.

---

## 5. The card (anatomy)

Portrait 5:7 ratio (e.g. 300 × 420 pt), corner radius 16 pt, 1 pt border per rarity. Identical template for same animal + stage + finish + season; only the serial and stats vary.

```
┌────────────────────────────┐
│ SET NAME            RARITY │  caption row: season set name · rarity pip
│                            │
│      [ animal art ]        │  art area 100 % width, 56 % height, family bg
│                            │
│  Cheetah                   │  display 28
│  the one who makes the     │  flavour, italic 14, 2 lines max
│  horizon come closer       │
│  ──────────────────────    │  hairline
│  5.0 km · 19:35 · 3:55/km  │  stats row (run) | "7 days · 35 km" (weekly) | "October · Kerala" (monthly)
│  CHEETAH  #0042   ✓        │  serial in tabular display + verified tick
└────────────────────────────┘
   baby / young / adult: the art changes (scale + pose), the stage word appears only in the detail view
```

Rules:
- Art is **original**: flat-shaded illustration with a single light source, no outlines, 3 poses per animal (baby, young, adult). Until commissioned, the app renders a **procedural placeholder**: family-coloured silhouette card with the animal's initial in Fraunces, deterministic per slug (so placeholders are consistent everywhere).
- The route map, start point, time of day in detail, heart rate, age and sex **never** appear on the card or poster.
- Verified tick: `success` for verified; `warn` outline "unverified" for unverified cards (still a card, still real).

---

## 6. Motion

Durations are short; the reveal is the only long sequence.

| Moment | Spec |
|---|---|
| **Reveal** (after run upload) | 0 ms: dark scrim + "Reading your run…" shimmer (max 1.2 s while the RPC runs). Then card back slides up from bottom (420 ms, `Curves.easeOutCubic`), pauses 300 ms, flips on Y (600 ms) to reveal face; foil appears at 50 % of flip. Rare+: 24 particles from the card edge (900 ms). Haptic: light at slide, medium at flip, success pattern for rare+. One tap anywhere dismisses to the card detail. |
| **Growth celebration** | After the reveal, if `celebrations` has `growth`: the card art cross-fades to the new stage (500 ms) with a radial wipe and the line "Your cheetah is all grown up!" Haptic: success. |
| **Discovery** (tier ≥ 1) | A one-line caption appears under the card: "You found this one because you ran at night." Never show thresholds. |
| **Foil** | Fragment shader (`assets/shaders/foil.frag`): hue-rotating rainbow band driven by device tilt (gyroscope) and a slow time term; masked by the art alpha. On web/no-gyro: time term only. |
| **Collection grid** | Staggered fade-in 40 ms per card, max 320 ms total. |
| **Tab transitions** | Fade through, 200 ms. No slide stacks for tabs. |
| Reduced motion | Replace flip with cross-fade, disable particles/foil tilt; keep haptics. |

---

## 7. Information architecture

Bottom tabs (4): **Today · Collection · Encyclopedia · You**. The run recorder is a floating action on Today.

### Today (home)
- Hero: last card (or an empty-state "bag" illustration with "Your first run opens the bag").
- Row: streak dots for the last 7 days (filled = run-day) and this week's run-day count ("3 of the week · 2 more opens the weekly bag" — this is the *only* place a threshold is hinted, and only for the weekly minimum, because consistency is the thing we want to teach).
- "Start a run" FAB (optional; auto-detect runs are recorded regardless).
- Pending reveals (weekly/monthly cards claimed at app open) appear here as a glowing envelope.

### Collection
- Grid of earned animals grouped by family; count badge and best serial per animal. Unseen animals appear as silhouettes with "?" (no name) — only for *non-secret* animals, so the collection shows how big the world is without revealing recipes.
- Filter chips: All · Run · Weekly · Monthly · Rare+. Sort: newest / rarest / best serial.
- Card detail: full card, tilt foil, stage + "earned N times, best #0009", the run's stats, Share poster, Toggle "Show on verify page".

### Encyclopedia
- Searchable list (name only; this search is for animals, never people). Each entry: art, facts, habitat, superpower, India note; "Earned 3 times" if owned. Secret animals absent until earned.

### You (trust centre + furniture)
- Profile card: display name, home region, optional age/sex with a one-line reason ("Only used to grade effort fairly. Never shown.").
- **Permissions as a receipt:** each data purpose on its own row with status, plain-language *why*, and what you lose without it. Toggling off is immediate. A gentle "Fully connected" row shows a locked silhouette when something is off.
- Furniture: calendar heat map (run-days), pace trend, distance totals. Deliberately below the fold.
- Verify a card: the serial search field.
- Notifications, export my data, delete my account (DPDP).

### Verify (public web)
`/v/<animal>/<serial>`: calm page, the card, "Earned by Priya on 28 Sep 2026", "Pugmark #0042 of 118 issued", a "Real ✓ · lives in the Pugmark ledger" seal, store badges. No route, no location, no health data. If not found: "No such card. If someone showed you this, they're bluffing."

### Poster (share)
1080 × 1920 story: family gradient background, card centred at 70 % width, serial large beneath, QR to verify URL bottom-right, small "pugmark.run" wordmark. Zero location.

---

## 8. Onboarding & consent (DPDP-aware)

1. **Promise screen** (1): "Run. Get an animal. Collect India." Continue.
2. **Sign in** (2): email magic link or Apple/Google.
3. **Permissions, one at a time** (3–7), each a full card with: the icon, *what* ("Location while running"), *why* ("to measure distance and notice when you explore somewhere new"), *what we store* ("your route, visible only to you"), and two buttons: *Allow* / *Not now*. Order: Location → Motion & fitness (steps, footfall) → Activity recognition (auto-detect runs) → Health (heart rate) → Notifications. Each is skippable; the app works with just Location.
4. **Optional fairness screen** (8): birth year + sex, pre-skipped, with "Why?" expander. Stored as birth year only.
5. **Done**: the bag illustration; "Your first run opens the bag."

Rules: no dark patterns; "Not now" is the same size and weight as "Allow"; the "fully connected" reward is mentioned once, after onboarding, in the trust centre, never during a permission prompt.

---

## 9. Copy voice (examples)

| Situation | Copy |
|---|---|
| Rejected run | "We couldn't confirm this one was a run — no card this time." |
| Unverified | "We couldn't fully verify this run, so it drew from the everyday bag." |
| Floor not met | "Recorded. A run of 1 km or 10 minutes earns a card." |
| Cap reached | "Recorded and counted. Your card bag refills tomorrow." |
| No weekly card | "No weekly card this week — three run-days opens the weekly bag." |
| Growth | "Your tortoise is all grown up!" |
| Welcome back | "Welcome back. Your animals start small again — and so does the adventure." |
| Night discovery | "You found this one because you ran at night." |
| New state | "A souvenir from Kerala." |

Never: "slow", "lazy", "only", "just", "failed", "better than".

---

## 10. Accessibility

- All family palettes ≥ 7:1 text contrast; rarity never carried by colour alone (border weight + label).
- Every card has a semantic label: "Cheetah, young, epic, serial 42, earned 2 October 2026".
- Haptics are supplementary; every celebration also has text.
- Reduced-motion variant for every animation.
- Minimum body 16 pt; supports 1.3× Dynamic Type.

---

## 11. Admin panel (web) UX

Dense, keyboard-friendly, left nav: Animals · Rules · Config · Seasons · Regions · Age factors · Simulator · Users · History.
- **Animals:** table with art thumbnail, name, family, rarity, issued count, active toggle; edit drawer with JSON-free form fields (facts as a list editor).
- **Rules:** per animal; predicate editor as structured fields (band chips, distance range, time windows, flags, regions, connected) with the raw JSON shown read-only beneath; weight slider; tier; guaranteed/repeat probability.
- **Simulator:** enter a sample run context (band, km, time, flags, state) → see the resolved tier, pool and probabilities live (calls `admin_simulate_pool`). Also a performance-index preview (speed, distance, sex, age → P and band). This is how the designer tunes balance without touching code.
- **Config:** key/value cards with description; JSON editor with validation.
- **History:** every change with who/when and a diff.
