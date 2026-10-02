import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialises Supabase from `.env` (SUPABASE_URL, SUPABASE_ANON_KEY).
/// Returns false when the placeholders have not been replaced yet, so the app can show a setup screen.
Future<bool> initSupabase() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    return false;
  }
  final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
  final key = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
  if (url.isEmpty || key.isEmpty || url.contains('YOUR-PROJECT') || key.contains('YOUR-ANON')) return false;
  await Supabase.initialize(url: url, anonKey: key, authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce));
  return true;
}

SupabaseClient get supabase => Supabase.instance.client;

/// Whether Supabase was configured at startup (set by main).
final supabaseReadyProvider = StateProvider<bool>((_) => false);

/// Current auth session, kept live.
final authStateProvider = StreamProvider<AuthState>((ref) => supabase.auth.onAuthStateChange);

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return supabase.auth.currentUser;
});
