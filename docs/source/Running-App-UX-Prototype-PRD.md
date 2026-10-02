# Running App — UX Prototype Workbench PRD

Oct 2, 2026 · Owner @amitesh

> Companion files: **Running-App-UX-Prototype-Prompt.md** (the prompt to give Claude Code) and **Running-App-PRD.md** (the product itself). This PRD covers only the design prototype, not the production app.

## 1. Purpose

A web-based prototype workbench for designing the Running App's user interface and experience before building real features. It lets the designer click through every screen in a phone frame, tune interaction details (animation and toast durations, what triggers what) live from a properties panel, and see the result instantly. It also establishes a scalable design system that the production app will reuse.

This is a **prototype**: clickable, visually complete, running on mock data. No real GPS, HealthKit, or Supabase calls.

## 2. Goals

- Map the complete user experience and every user journey before any screen is drawn.
- Produce every screen of the app as real, reusable UI, not throwaway mockups.
- Give the designer direct control over timing and trigger rules without touching code.
- Create a design system that scales to the full app and admin panel.

## 3. Non-goals

- Real data, real tracking, real backend, authentication, or app store builds.
- Final illustration art — use clear placeholder animal art with correct dimensions.
- Performance tuning or production hardening.

## 4. Approach: design first, then screens

Before building, Claude Code runs a short **design phase using specialised sub-agents** (product designer, UX designer, UI designer), each adopting the best practices of that role. Their output, saved as markdown files in the repo, is:

1. **User personas** — drawn from the six seeded dummy users in the product PRD (fast sprinter, older endurance runner, streak runner, traveller, night owl, slow collector).
2. **User journeys** — end-to-end flows, e.g. first launch and permissions; a run that ends in a card reveal; an animal growing up; searching a serial number; sharing a poster; a friend verifying it; adjusting permissions in settings.
3. **Screen inventory** — every screen the journeys need, with purpose, entry points, exit points, and states (empty, loading, success, error).
4. **Interaction spec** — for each screen, the animations, toasts, notifications, and the conditions that trigger them.

Only after these four documents exist does screen building start.

## 5. The workbench layout (three columns)

| Column | Contents | Behaviour |
| --- | --- | --- |
| **Left panel — Pages** | Every screen from the inventory, grouped by journey (Onboarding, Home, Run, Cards, Collection, Search & Verify, Encyclopedia, Settings, Celebrations). | Clicking a page loads it into the phone frame and swaps the right panel to that page's properties. |
| **Centre — Phone frame** | A realistic phone frame (iPhone-size by default, toggle to a common Android size) showing the live app screen. | Fully interactive: taps navigate exactly as the real app would. A "reset to start" button. |
| **Right panel — Properties** | The selected page's child actions and parameters: animation durations and easing, toast/notification durations, which event triggers each one, and page-specific toggles. | Changing a value updates the centre frame immediately. Values persist (saved to a JSON config file) so nothing is lost on reload. |

The left and right panels sit **outside** the phone frame; they are workbench chrome, not part of the app.

### Right panel — what it exposes per page

- **Animations:** duration (ms), delay, easing curve, enabled on/off — for each named animation on the page (e.g. card flip, foil shimmer, growth celebration).
- **Toasts and notifications:** display duration, position, dismiss behaviour, message text.
- **Triggers:** the use case that fires each action (e.g. "run ended", "new animal earned", "animal grew up", "GPS lost", "first launch"), chosen from a dropdown. Each page also gets a **"Fire this trigger"** button so the designer can preview the outcome without simulating the whole flow.
- **State switcher:** empty / loading / success / error views of the page where applicable.

### Export

All property values live in one versioned JSON file (`interaction-config.json`). This file becomes the source of truth for animation and notification behaviour in the production app and feeds the data-driven admin panel later.

## 6. Design system package

A separate, independently importable package (not mixed into the prototype's screen code), built so the production app and admin panel can depend on it.

Contents, each as a documented, reusable unit:

- **Foundations:** colour tokens (light and dark), typography scale, spacing scale, radii, elevation, motion tokens (standard durations and easings), iconography.
- **Rarity and tier tokens:** common / rare / epic / legendary borders, foil and shimmer effects, baby → adult sizing rules.
- **Components:** buttons, cards (the animal card itself with all its slots: art, serial number, run stats, flavour line, set name), chips, toasts, bottom sheets, list items, search field, stat tiles, progress rings, the celebration overlay, the phone-safe navigation bar.
- **Patterns:** card reveal sequence, growth celebration sequence, permission request flow, share poster layout (no map, no start point).
- **A living catalogue page** in the workbench showing every token and component with its variants and states, so the system is browsable and can be checked for consistency.

Rules: every component reads from tokens, never from hard-coded values; adding a new animal tier or rarity should require only new tokens, not new components.

## 7. Technical direction

- **Flutter web**, consistent with Phase 1, so every screen built here is real Flutter UI that carries straight into the production app. The workbench shell (panels, phone frame, properties) is a web-only wrapper around the same screen widgets.
- **Monorepo structure:** `/app` (screens), `/design_system` (the package), `/workbench` (the three-column shell), `/docs` (personas, journeys, inventory, interaction spec).
- **Mock data layer** that mimics the real data shapes from Phase 1 (users, runs, cards, animals) and includes the six dummy users, so switching to Supabase later is a swap, not a rewrite.
- Runs are **simulated** with a "simulate run" control (pace, distance, time of day, location) so card reveals can be previewed on the web.

## 8. Deliverables

1. `/docs` — personas, journeys, screen inventory, interaction spec.
2. The workbench running in a browser with all screens clickable.
3. `interaction-config.json` with every tunable value.
4. The design system package with its living catalogue.
5. A short README explaining how to run it and how to add a page or a component.

## 9. Done when

The designer can open the workbench in a browser, click any page on the left, walk every journey inside the phone frame, change a duration or trigger on the right and see it update live, reload without losing changes, and browse the full design system catalogue.
