import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/brand.dart';
import 'core/router.dart';
import 'core/supabase.dart';
import 'core/theme/theme.dart';
import 'features/run/run_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ready = await initSupabase();
  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarding_done') ?? false;
  runApp(
    ProviderScope(
      overrides: [
        supabaseReadyProvider.overrideWith((_) => ready),
        onboardingDoneProvider.overrideWith((_) => onboarded),
      ],
      child: const FlyingCobraApp(),
    ),
  );
}

class FlyingCobraApp extends ConsumerWidget {
  const FlyingCobraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    if (ref.read(supabaseReadyProvider)) {
      ref.read(runQueueProvider); // start the offline run queue (flushes queued runs on launch/resume)
    }
    return MaterialApp.router(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
