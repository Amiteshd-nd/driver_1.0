# Flying Cobra marketing site — the script

A creative director's script for `web/marketing/index.html`: what the visitor sees, in what order, what moves, and why. Written 3 Oct 2026 against the skills imported into `.claude/skills/` (`taste-skill` for the design read and anti-slop pre-flight, `ui-ux-pro-max` for tokens, accessibility and the Three.js rules, `design-motion-principles` for the motion). The video treatment in `docs/source/Running-App-Video-Treatment.md` is the emotional source: one moment of wonder per film, the card reveal, everything else grounded and quiet.

## Logline

A person runs through an ordinary Indian morning. An animal runs beside them. When they stop, the animal becomes a card with a number only they hold. The site makes that one feeling scroll.

## Design read (taste-skill step 1)

> Reading this as: a consumer app landing (App Store style blended with scroll-triggered storytelling) for Indian runners of every age and pace, with a warm, playful-but-calm language, leaning toward the existing Flying Cobra design system (Satoshi, bone and burnt-saffron tokens, 16 px cards and pill controls) plus one Three.js layer for the animals and runners.

Redesign mode: **preserve**. Brand tokens, nav labels, anchor IDs (`#how`, `#animals`, `#verify`, `#privacy`), the verify form (`q`) and the copy voice are kept. What changed: the hero is recomposed around a 3D stage, the "three equal cards" and "four equal cards" blocks are replaced by a sticky card reveal and an interactive pace stage, a card river and a night-and-day scene were added, and em-dashes left the page copy.

**Dials.** `DESIGN_VARIANCE 7` (asymmetric split hero, sticky split, a sideways river; never three equal cards). `MOTION_INTENSITY 7` (a 3D layer, scroll-triggered beats, one enter recipe; all of it collapses under reduced motion). `VISUAL_DENSITY 3` (one message per section, section padding 64 to 128 px).

**Palette note.** ui-ux-pro-max proposed a generic orange-and-green dark palette with Barlow Condensed. Rejected: the brand already has tokens, and a redesign that preserves the brand extracts colours before applying new ones. The only local colour is the darker accent fill for white button text (token accent sits at 4.1:1, the fill at 5.2:1).

**Motion weighting (design-motion-principles).** Marketing page: Jakub primary (production polish: opacity + 14 px + 4 px blur enters, exits softer than enters, no bounce), Jhey secondary (the 3D stages and the card turn), Emil for the nav and the serial form (nothing animates there). Frequency gate: everything that moves is seen once per visit or on a tap. No loops except the foil sheen on epic cards, which is the product's own rarity cue and stops under reduced motion.

## Cast

| Role | Built as | Where |
|---|---|---|
| The runner | Procedural low-poly figure, 1.9 units tall, run cycle at 1.45 strides per second scaled by pace | Scenes 1 and 3 |
| Cheetah (swift, epic) | Quadruped kit: long body, spots, long tail | Scenes 1 and 3 |
| Chital (steady, common) | Quadruped kit: neck, antlers, white spots | Scene 3 |
| Cat (calm, common) | Quadruped kit: compact, pointed ears, tail up | Scene 3 |
| Star Tortoise (gentle, common, "unstoppable") | Quadruped kit with a domed shell and nine shell stars | Scene 3 |
| Rooster (dawn) | Bird kit: comb, wattle, three tail plumes | Scene 4 |
| Indian Eagle-Owl (night) | Bird kit: ear tufts, large amber eyes, pale belly | Scene 4 |

All names, families, rarities and flavour lines match the seeded animals in `supabase/migrations/0005_seed_animals.sql`. The models are stand-ins with the silhouette and colour of each animal; the kit lives in `web/marketing/scene.js` so a real GLB per animal can replace a builder without touching the page.

## Storyboard

Each scene is one viewport-ish of page. "Camera" is the 3D camera; "Cut" is what the visitor does to move on (scroll).

### Scene 1 · The dawn road (hero)

**Frame.** Left: eyebrow "A jogging app for India", headline "Run. Get an animal. Collect India.", one 16-word line, two store buttons. Right: a stage, no frame colour, the page itself is the sky. A runner jogs in place on a pale road; a cheetah lopes beside them, slightly ahead and nearer the camera. Dashes on the road and bushes at the verge stream backwards, so the pair reads as moving without ever leaving the frame.
**Camera.** 36° lens from front-right at head height, drifting a few centimetres with the pointer (lerped, never snapped). Touch devices get the still camera.
**Motion.** Continuous run cycle. Reduced motion: both figures freeze mid-stride, the road stops, the frame renders once.
**Why.** Film 1 in the treatment: a sprint, a buzz, a cheetah. The visitor should understand "run, animal" before reading a word.
**Cut.** Scroll.

### Scene 2 · One moment per run (`#how`)

**Frame.** Sticky left column: a card lying face down (paw mark on an amber back). Right column: three beats that pass at reading speed. Beat 1, the headline and the promise ("Three seconds after you stop, a card turns over"). Beat 2, "You run." The card slides up into place. Beat 3, "It turns over." The card flips to the Cheetah #0312 face with its foil sheen, and the hint lands: "Some animals only come out at night."
**Motion.** The beat nearest the middle of the viewport drives the card: slide 420 ms, hold with a 4° tilt, flip 600 ms, using the product's own reveal tokens. Transitions are duration-based, never scrubbed, so a fast scroll still gets a complete flip. Reduced motion: a 200 ms crossfade from back to face.
**Why.** The reveal is the product. It is the one place the page is allowed a long sequence, and it borrows the app's exact choreography.
**Cut.** Scroll.

### Scene 3 · Your pace picks the animal (`#animals`)

**Frame.** Headline "Your pace picks the animal, not the prize." A pill control: Gentle · Calm · Steady · Swift. A wide stage: the same kind of runner, now with the animal of the chosen family beside them. A panel in the family's colour names the animal and its flavour line ("Star Tortoise, unstoppable"), and lists the rest of the family.
**Interaction.** Tap or arrow-key a pace. The runner's cadence eases to the new speed over a few frames; the old animal disappears, the new one pops in from 90% to 100% over 300 ms; the panel recolours. Default is Gentle, so the first thing anyone meets here is a tortoise jogging with a runner.
**Why.** Film 3: many runners, many animals, none better. The segmented control shows families without ever showing a threshold, which keeps the recipe hidden (DESIGN principle 2).
**Cut.** Scroll.

### Scene 4 · The hour you run (`#hours`)

**Frame.** A wide cinematic stage: a branch across a dawn sky, a rooster on it. As the section scrolls through the viewport the sky deepens from peach to indigo, the sun sinks, the moon rises, stars fade in, and the rooster becomes an owl. Under the stage, two cards: Rooster (dawn) and Indian Eagle-Owl (night), each captioned "You found this one because…".
**Motion.** Scroll position is sampled inside the render loop (no scroll listener); the sky lerps toward the target so it never jitters. The bird looks toward the pointer, breathes, blinks every few seconds. Reduced motion: the sky switches once at the midpoint, the bird holds still.
**Why.** Film 4: a split-world film about time of day. Lighting is the whole story, so the 3D layer earns its place here more than anywhere.
**Cut.** Scroll.

### Scene 5 · Everywhere you run (`#everywhere`)

**Frame.** Headline "Every place you run leaves you something to keep." A river of five cards scrolls sideways (native scroll-snap, arrow buttons for keyboard and pointer): Great Hornbill (Kerala souvenir), Bengal Tiger (the 7-day weekly card, legendary, radiant), Camel (Rajasthan, age-graded effort), Bar-headed Goose (three states in 21 days), Indian Fox (a new route). Each card has a one-line caption that says what earned it, never how much.
**Motion.** None beyond the enter and the user's own scroll. The only horizontal pattern on the page.
**Why.** Film 2 and the montage: travel, consistency, exploration, each a different kind of runner. Breadth without a wall of text.
**Cut.** Scroll.

### Scene 6 · Real cards have serial numbers (`#verify`)

**Frame.** Headline and the trust line. The one form on the page (label, field, Verify). Beneath: an example card beside its ledger entry (Cheetah #0042, earned by Priya, 28 Sep 2026, issued 42 of 118, Real).
**Motion.** The form does not animate (Emil: forms are high-intent, instant). The card and ledger enter once.
**Why.** The growth loop in Film 5: a friend scans the QR, the verify page says it is real, the friend downloads the app.

### Scene 7 · Private by design (`#privacy`)

**Frame.** Five promises in two columns, each a bold line and a plain sentence, separated by hairlines, no cards.
**Why.** The settings screen in the app reads like a receipt; the site makes the same promises in the same voice.

### Scene 8 · Your first run opens the bag (`#download`)

**Frame.** Centred closing: headline, "Free. Works with location alone.", the two store buttons, a small honest line that the buttons light up the day the apps ship. Footer with the tagline "Run. Collect. Keep."
**Interaction.** Store buttons are placeholders: a toast says so. Filling `STORE_LINKS` in `app.js` turns every store button on the page into a real link (MANUAL_TASKS.md section 11).

## Rules the page obeys

- One theme (follows the system, light or dark), one accent, one radius system (16 px surfaces, pill controls). The night sky in Scene 4 is content inside a stage, not a section flip.
- One eyebrow on the page (hero). Zero em-dashes in anything a visitor can read. No three-equal-card rows, no scroll cues, no version labels, no decorative dots (the rarity dot on a card is the product's own cue).
- Hero: four text elements, headline fits two lines at desktop, CTAs above the fold at 1280 × 720.
- Animate only `transform`, `opacity`, `filter`. Every motion has a reduced-motion path in the same stylesheet or module.
- Three.js: one renderer, scissor-rect views, pixel ratio capped at 2, shared geometries and materials, shadows only from the key light, loop paused when the tab is hidden, `role="img"` with a label on the canvas.
- Images: the page has none yet. Card art areas show the product's own placeholder (family field and initial) until the illustration pipeline's approved art is wired in; the 3D stages are the page's visuals.

## What is still a placeholder

| Placeholder | Replace with | Where |
|---|---|---|
| Store buttons | Real App Store and Google Play URLs | `web/marketing/app.js` → `STORE_LINKS` |
| Procedural animals and runner | GLB models, one per animal, same names | `web/marketing/scene.js` → the `ANIMALS` / `BIRDS` specs and builders; see `web/marketing/README.md` |
| Card art (initial on a family field) | Approved illustrations from `animal_art` | the `.card__art` blocks |
| Footer Privacy and Terms | Real documents | footer links |
