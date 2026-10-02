import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_shell.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/card/card_detail_screen.dart';
import '../features/collection/collection_screen.dart';
import '../features/encyclopedia/encyclopedia_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/reveal/reveal_screen.dart';
import '../features/run/run_screen.dart';
import '../features/search/serial_search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/share/poster_screen.dart';
import '../features/today/today_screen.dart';
import 'models/models.dart';
import 'supabase.dart';
import 'theme/tokens.dart';

/// Route names. Features navigate with `context.goNamed(Routes.x)` / `pushNamed`.
class Routes {
  Routes._();
  static const today = 'today';
  static const collection = 'collection';
  static const encyclopedia = 'encyclopedia';
  static const you = 'you';
  static const signIn = 'sign-in';
  static const onboarding = 'onboarding';
  static const run = 'run';
  static const reveal = 'reveal';
  static const card = 'card';
  static const poster = 'poster';
  static const search = 'search';
  static const admin = 'admin';
  static const setup = 'setup';
}

final routerProvider = Provider<GoRouter>((ref) {
  final ready = ref.watch(supabaseReadyProvider);
  final auth = ready ? ref.watch(authStateProvider) : null;
  final onboarded = ref.watch(onboardingDoneProvider);

  return GoRouter(
    initialLocation: '/today',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      if (!ready) return state.matchedLocation == '/setup' ? null : '/setup';
      final signedIn = supabase.auth.currentSession != null;
      final loc = state.matchedLocation;
      final isPublic = loc == '/sign-in' || loc.startsWith('/verify');
      if (!signedIn && !isPublic) return '/sign-in';
      if (signedIn && loc == '/sign-in') return '/today';
      if (signedIn && !onboarded && !loc.startsWith('/onboarding') && !loc.startsWith('/verify')) return '/onboarding';
      auth; // keep the dependency
      return null;
    },
    routes: [
      GoRoute(path: '/setup', name: Routes.setup, builder: (_, __) => const SetupNeededScreen()),
      GoRoute(path: '/sign-in', name: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/onboarding', name: Routes.onboarding, builder: (_, __) => const OnboardingFlow()),
      GoRoute(path: '/run', name: Routes.run, builder: (_, __) => const RunScreen()),
      GoRoute(
        path: '/reveal',
        name: Routes.reveal,
        pageBuilder: (_, state) => CustomTransitionPage(
          fullscreenDialog: true,
          child: RevealScreen(result: state.extra as RevealPayload),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ),
      ),
      GoRoute(path: '/card/:id', name: Routes.card, builder: (_, state) => CardDetailScreen(cardId: state.pathParameters['id']!, initial: state.extra as PugCard?)),
      GoRoute(path: '/poster/:id', name: Routes.poster, builder: (_, state) => PosterScreen(cardId: state.pathParameters['id']!, initial: state.extra as PugCard?)),
      GoRoute(path: '/verify', name: Routes.search, builder: (_, state) => SerialSearchScreen(initialQuery: state.uri.queryParameters['q'])),
      GoRoute(path: '/admin', name: Routes.admin, builder: (_, state) => AdminShell(section: state.uri.queryParameters['s'])),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/today', name: Routes.today, builder: (_, __) => const TodayScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/collection', name: Routes.collection, builder: (_, __) => const CollectionScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/encyclopedia', name: Routes.encyclopedia, builder: (_, __) => const EncyclopediaScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/you', name: Routes.you, builder: (_, __) => const SettingsScreen())]),
        ],
      ),
    ],
  );
});

/// What the reveal screen needs: a run result or a pending weekly/monthly card.
class RevealPayload {
  const RevealPayload({this.result, this.pending});
  final RunResult? result;
  final PendingCard? pending;
  PugCard? get card => result?.card ?? pending?.card;
  List<Celebration> get celebrations => result?.celebrations ?? pending?.celebrations ?? const [];
}

/// Persisted in SharedPreferences by the onboarding feature.
final onboardingDoneProvider = StateProvider<bool>((_) => true);

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(supabaseReadyProvider, (_, __) => notifyListeners());
    ref.listen(onboardingDoneProvider, (_, __) => notifyListeners());
    if (ref.read(supabaseReadyProvider)) {
      ref.listen(authStateProvider, (_, __) => notifyListeners());
    }
  }
}

class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: 'Collection'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Encyclopedia'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'You'),
        ],
      ),
    );
  }
}

/// Shown when `.env` still has placeholders (MANUAL_TASKS.md step 1).
class SetupNeededScreen extends StatelessWidget {
  const SetupNeededScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets, size: 48, color: c.accent),
              const SizedBox(height: Space.lg),
              Text('Almost there', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: Space.sm),
              Text(
                'Pugmark needs its Supabase keys. Copy app/.env.example to app/.env and paste the Project URL and anon key (MANUAL_TASKS.md, step 1), then restart the app.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
