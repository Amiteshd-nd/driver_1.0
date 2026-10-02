# Source documents (as written, unedited)

The five original project documents by @amitesh, dated 2 Oct 2026. They are the authority for *what* Pugmark is. The derived docs one level up (`docs/ALGORITHMS.md`, `DESIGN.md`, `API.md`, `ARCHITECTURE.md`, `PHASES.md`) are the authority for *how* it was built. Where the two disagree, these files win and the derived docs should be corrected.

| File | What it is | Used to build |
|---|---|---|
| [Running-App-PRD.md](Running-App-PRD.md) | The phased product requirements. Section 12 defines the 8 build phases. | Everything. The primary spec. |
| [Running-App-Full-Context-Master-Record.md](Running-App-Full-Context-Master-Record.md) | Every decision made in conversation, in one place. Includes the two open questions. | Cross-checked against the PRD; settled the duplicate-card and migratory-geography questions. |
| [Running-App-Claude-Code-Prompts.md](Running-App-Claude-Code-Prompts.md) | The phase-by-phase build prompts and the fixed technical decisions. | Build order, and the rule that Flutter + Supabase + database-issued serials + data-driven rules are not to be changed. |
| [Running-App-Design-Presentation.md](Running-App-Design-Presentation.md) | Presentation-ready walkthrough of the concept and its logic, with a full parameter reference appendix. | `docs/DESIGN.md` voice and the "slow is never shame" principle; the parameter table was used to audit the rules engine. |
| [Running-App-Video-Treatment.md](Running-App-Video-Treatment.md) | Five scene-by-scene marketing films, tone, casting and locations. | The reveal moment in `docs/DESIGN.md` §6, the celebration copy, and the marketing site's hero and story sections. |

## Audit against the build

Checked each document's claims against the shipped engine on 2 Oct 2026.

**Matches.** The video treatment's five films are all reachable in the build: the sprint-to-cheetah reveal (Film 1), the Kerala souvenir with the "Monsoon 2026" set name (Film 2), the camel for Rajasthan, the quick hare, the streak glow and the tortoise flavoured "unstoppable" (Film 3), the dawn songbird and the night owl (Film 4), and the growth celebration, poster without a map, QR scan and public verify page (Film 5). The design presentation's parameter appendix matches the engine row for row.

**One gap.** The design presentation's exploration table has a row the PRD does not: **"Home region · set once · an always-available regional pride animal."** The build sets `profiles.home_region` and uses it to decide what is *not* a travel souvenir, and the monthly card draws on the region you actually ran in — but there is no home animal available in the everyday run pool. Adding it is a small, data-only change (one tier-0 rule per region, gated on `region_codes`, at a low weight), but how often a home animal should appear is a balance decision, so it is left open. Tracked in `docs/PHASES.md`.
