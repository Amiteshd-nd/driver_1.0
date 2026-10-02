# UX design phase

Produced before any screen was built, by three specialised agents acting as product designer, UX designer and UI/motion designer, each applying the practices of that role. Spec: `docs/source/Running-App-UX-Prototype-PRD.md` §4.

| File | Author role | What it is |
|---|---|---|
| [SCREEN_IDS.md](SCREEN_IDS.md) | shared vocabulary | Canonical screen IDs grouped by journey, per-screen states, and the trigger vocabulary. Every other document and the workbench use these names. Add here first. |
| [PERSONAS.md](PERSONAS.md) | product designer | Six personas from the seeded dummy users: context, job-to-be-done, delight, quit triggers, realistic first card, trust needs, a quote, and the three screens that matter most to each. |
| [JOURNEYS.md](JOURNEYS.md) | product designer | Twelve end-to-end journeys with screen sequence, emotional arc, friction and the design response, triggers fired, and one success metric each. Ends with a journey map. |
| [SCREEN_INVENTORY.md](SCREEN_INVENTORY.md) | UX designer | All screens: purpose, entry and exit points, actions, every state with exact copy, data needed, accessibility, and what each screen must never show. Ends with the navigation map. |
| [INTERACTION_SPEC.md](INTERACTION_SPEC.md) | UI / motion designer | The motion system (durations, easings, reduced-motion rule, haptics), every named animation and toast per screen with its trigger, the notification hierarchy, how rarity and tier are expressed through tokens, and fifteen open timing decisions. |

## Findings from the design phase worth knowing

- **Dawn catches most Indian morning runners.** Meera at 05:50 in Chennai and Ravi at 06:40 in Pune are both inside the solar dawn window, so their guaranteed first card is a Rooster or Bulbul, not the animal the product spec implies. The dawn discovery caption is the first thing many users will see; it is worth polishing.
- **The migratory bird outranks a souvenir.** On Priya's Goa run the tier-4 bird fires before the tier-3 Olive Ridley. The Collection must show the unmet turtle as a promise, not a miss.
- **Phone-only users verify fully.** Location plus steps gives a trust score around 0.85. Nothing in the run-finish or permission copy may imply their runs are second-class.
- **Two inconsistencies between the design doc and the shipped code**, exposed as tunables rather than decided silently: particle counts per rarity (the doc says rare and above, the code says legendary only; the spec proposes 8 / 16 / 24), and a pre-slide hold in the reveal that the doc did not specify.
- **One screen proposed beyond the original list**: `verify-web`, the public verify page, so the "friend verifies it with no app" journey can be walked inside the frame. Adopted.

## Where this feeds

`SCREEN_IDS.md` → the page list in `/workbench`. `INTERACTION_SPEC.md` → the defaults in `workbench/interaction-config.json`. `SCREEN_INVENTORY.md` states → the state switcher in the workbench's right panel. `PERSONAS.md` → the persona data in `workbench/data.js`.
