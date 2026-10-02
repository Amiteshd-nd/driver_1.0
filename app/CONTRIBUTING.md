# Pugmark Flutter app — module contract

Flutter 3.24+ / Dart 3.5, Riverpod 2, go_router 14, supabase_flutter 2. **Flutter is not installed on this machine yet**, so code must be written carefully to compile first time: no codegen, explicit imports, null-safety, `const` where possible, `withValues(alpha:)` not `withOpacity`, `WidgetStatePropertyAll` not `MaterialStatePropertyAll`.

## Shared core (do not restructure; extend only)
- `lib/core/brand.dart` — name/tagline.
- `lib/core/theme/tokens.dart` — `PugColors` (via `context.pug`), `Space`, `Radii`, `FamilyPalette`.
- `lib/core/theme/theme.dart` — `buildTheme`, `PugText.serial/stat/flavour`.
- `lib/core/models/models.dart` — `Animal`, `PugCard`, `RunResult`, `PendingCard`, `Celebration`, `Profile`, `RunSummary`, `Bond`, `AppEvent`, `SerialLookup`, enums, `fmtDuration/fmtPace/fmtDate`, `RarityStyle`.
- `lib/core/repos/repos.dart` — `PugApi` + providers (`apiProvider`, `profileProvider`, `myCardsProvider`, `myRunsProvider`, `animalsProvider`, `issuedCountsProvider`, `myBondsProvider`, `unseenEventsProvider`, `weeklyConfigProvider`, `regionsProvider`, `refreshAfterCard(ref)`).
- `lib/core/supabase.dart` — `supabase` client, `authStateProvider`, `currentUserProvider`, `supabaseReadyProvider`.
- `lib/core/router.dart` — `Routes`, `RevealPayload`, `onboardingDoneProvider`. It imports these screens, which each feature MUST provide with exactly these constructors:

| File | Class & constructor |
|---|---|
| `features/auth/sign_in_screen.dart` | `SignInScreen()` |
| `features/onboarding/onboarding_flow.dart` | `OnboardingFlow()` — on finish: `prefs.setBool('onboarding_done', true)`, set `onboardingDoneProvider` true, `context.go('/today')` |
| `features/today/today_screen.dart` | `TodayScreen()` |
| `features/run/run_screen.dart` | `RunScreen()` |
| `features/reveal/reveal_screen.dart` | `RevealScreen({required RevealPayload result})` |
| `features/card/card_detail_screen.dart` | `CardDetailScreen({required String cardId, PugCard? initial})` |
| `features/share/poster_screen.dart` | `PosterScreen({required String cardId, PugCard? initial})` |
| `features/collection/collection_screen.dart` | `CollectionScreen()` |
| `features/encyclopedia/encyclopedia_screen.dart` | `EncyclopediaScreen()` |
| `features/search/serial_search_screen.dart` | `SerialSearchScreen({String? initialQuery})` |
| `features/settings/settings_screen.dart` | `SettingsScreen()` |
| `features/admin/admin_shell.dart` | `AdminShell({String? section})` |

Shared widget every feature may use: `features/card/widgets/pug_card_view.dart` → `PugCardView({required PugCard card, double width = 300, bool interactive = true, bool showStats = true})` (owner: UI agent). Until it exists, other agents may reference it; it will be there.

## Navigation
`context.goNamed(Routes.card, pathParameters: {'id': card.id}, extra: card)`; reveal: `context.pushNamed(Routes.reveal, extra: RevealPayload(result: r))`.

## Rules of the product (never break)
- No leaderboards, no ranking, no name search. The only search is the serial lookup.
- Never show route map / start point / health fields on a card or poster or verify view.
- Never reveal thresholds/recipes to the player (except the weekly minimum run-days hint on Today).
- Copy voice: docs/DESIGN.md §9. Never "slow", "lazy", "only", "just", "failed".
- Age/sex are optional, explained, never shown.
