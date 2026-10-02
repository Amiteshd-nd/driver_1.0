# `design-doc` — the Flying Cobra design document

A self-contained web page presenting the concept and complete logic of Flying Cobra, for sharing with collaborators, investors and new team members. Open `index.html` in any browser; nothing needs to be installed or built.

## What it is

The content follows `docs/source/Running-App-Design-Presentation.md` section for section. The page is not a styled copy of that document, though: the three parts people find hardest to understand from prose are demonstrated instead of described.

| Section | How the page teaches it |
|---|---|
| 03 How an animal is chosen | Four dials — pace, distance, run-days and age — drive a live card. Moving a dial changes the family, the scale or the finish in front of you. |
| 04 Slow is never shame | The four families sit side by side at equal size, each showing the same common-to-epic ladder, so the claim is visible rather than asserted. Raising the age dial without touching the pace proves the fairness engine in one gesture. |
| 06 The surprise layer | The page lists the whole bag the run opened, with each animal's real draw probability, and highlights the one that came out. "Draw again" re-rolls the same bag. |

## It runs the real engine

The demo is not an illustration. `app.js` implements the shipped formulas from `docs/ALGORITHMS.md`, against the real roster from `supabase/migrations/0005_seed_animals.sql`:

- Riegel distance-adjusted open standard (§2.1) and the age-factor table (§2.2)
- the performance index and the four band thresholds (§2.4, §3)
- stage from distance (§4.1) and finish from run-days (§5)
- the rarity-weighted draw (§6.2), including the elephant's eight-kilometre predicate

Checked against the worked examples in the specification: four minutes per kilometre reads swift, five reads steady, six reads calm, eight and a half reads gentle, and a sixty-year-old at six minutes lands in the same family as a thirty-year-old at five.

Two deliberate simplifications, both noted here so nobody mistakes the page for the engine: the demo uses the sex-neutral reference time, because it does not ask for sex, which shifts the index slightly against the table in §2.4 while leaving every band boundary in place; and it omits the pity timer, since that depends on a player's history rather than a single run.

**If the engine's numbers change, change them here too.** The constants live at the top of `app.js` in one block.

## Stack

Hand-written HTML, CSS and JavaScript. No framework, no bundler, no dependencies, no build step.

That is a deliberate choice rather than a shortcut. This page has to outlive the toolchain that made it: a collaborator should be able to open it in five years, read the source, and change a sentence without installing anything. The only external request is to Fontshare for Satoshi, and the page falls back to the system sans if that is blocked.

| File | Role |
|---|---|
| `index.html` | content and structure |
| `styles.css` | design tokens, then layout, then components |
| `app.js` | the selection demo, reading progress, scrollspy, theme toggle |

## Design system

Flying Cobra's own, from `docs/DESIGN.md`: the chrome palette (§3.1), the family palettes (§3.2), the rarity borders and finishes (§3.3), Satoshi for both display and text (§4), and the card anatomy (§5). The cards on this page are built from the same rules as the cards in the app, so the two cannot drift apart visually.

## Accessibility

Semantic landmarks and a skip link. Every control is labelled and reachable by keyboard, with a visible focus ring. The demo's readout is an `aria-live` region, so screen-reader users hear the result when a dial moves. Colour never carries meaning alone: rarity is a border weight plus a word, and the drawn animal in the bag is marked by weight as well as outline. Light and dark both ship, following the system setting with a manual override. Everything animated is disabled under `prefers-reduced-motion`, and the page has a print stylesheet.

## Deploying

Copy the folder to any static host, or serve it locally:

```bash
python3 -m http.server 8788 --directory web/design-doc
```

It sits alongside `web/marketing/`, which is built the same way, and links back to it from the wordmark.
