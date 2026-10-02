# Canonical screen IDs and journeys

Shared vocabulary for the UX documents, the workbench (`/workbench`) and `interaction-config.json`. Every document and every piece of code refers to screens by these IDs. Add a screen here first; everything else follows.

| Journey | Screen ID | Working title |
|---|---|---|
| Onboarding | `welcome` | Promise screen |
| Onboarding | `sign-in` | Sign in (magic link, Apple, Google, test account) |
| Onboarding | `perm-location` | Permission: location while running |
| Onboarding | `perm-motion` | Permission: motion & fitness (steps, footfall) |
| Onboarding | `perm-activity` | Permission: activity recognition (auto-detect runs) |
| Onboarding | `perm-health` | Permission: health (heart rate) |
| Onboarding | `perm-notifications` | Permission: notifications |
| Onboarding | `fairness` | Optional birth year & sex (age-grading only) |
| Onboarding | `onboarding-done` | "Your first run opens the bag." |
| Home | `today` | Today tab (hero card, streak, pending envelopes, banners) |
| Run | `run-ready` | Run screen before start |
| Run | `run-recording` | Live run (timer, distance, pace, GPS pill) |
| Run | `run-finish` | Finish confirmation / "Reading your run…" |
| Cards | `reveal` | Card reveal sequence (also used for weekly/monthly) |
| Cards | `card-detail` | Card detail |
| Cards | `poster` | Share poster preview & export |
| Collection | `collection` | Collection grid |
| Search & Verify | `serial-search` | Serial lookup (the only search) |
| Encyclopedia | `encyclopedia` | Encyclopedia list |
| Encyclopedia | `animal-entry` | Animal entry sheet |
| Settings | `settings` | You tab: profile, permission receipt, furniture |
| Settings | `permission-receipt` | Granular permissions (focused view) |
| Settings | `data-and-account` | Export my data, delete account |
| Celebrations | `celebration-growth` | "Your cheetah is all grown up!" |
| Celebrations | `celebration-mastered` | Unlock the Wild |
| Celebrations | `celebration-welcome-back` | After a 60-day break |
| Celebrations | `celebration-discovery` | First night / dawn / explorer / souvenir / migratory |
| System | `setup-needed` | Supabase keys missing (internal builds only) |

## Per-screen states (right-panel state switcher)
`empty` · `loading` · `success` · `error`, plus screen-specific ones named in the inventory (e.g. `run-recording`: `gps-good`, `gps-searching`, `gps-denied`, `auto-paused`, `offline`).

## Trigger vocabulary (right-panel dropdown)
`first-launch` · `sign-in-complete` · `permission-granted` · `permission-denied` · `run-started` · `run-auto-paused` · `gps-lost` · `gps-regained` · `run-ended` · `run-floor-not-met` · `run-rejected` · `run-unverified` · `run-capped` · `card-issued` · `rare-card-issued` · `animal-grew` · `animal-mastered` · `welcome-back` · `discovery-time` · `discovery-explorer` · `discovery-souvenir` · `discovery-migratory` · `weekly-card-ready` · `monthly-card-ready` · `no-weekly-card` · `serial-found` · `serial-not-found` · `link-copied` · `card-visibility-toggled` · `poster-exported` · `offline-saved` · `back-online` · `permission-toggled` · `data-exported` · `account-deleted`
