import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/brand.dart';
import '../../core/supabase.dart';
import '../../core/theme/tokens.dart';

/// Flip these once the providers are configured in the Supabase dashboard
/// (MANUAL_TASKS.md step 4). Until then the buttons are visible but disabled.
const bool kAppleSignInConfigured = false;
const bool kGoogleSignInConfigured = false;

/// Deep link registered for the magic-link redirect (iOS URL scheme / Android intent filter).
const String kAuthRedirect = 'pugmark://login';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _testEmail = TextEditingController();
  final _testPassword = TextEditingController();
  bool _busy = false;
  bool _linkSent = false;
  bool _showTest = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _testEmail.dispose();
    _testPassword.dispose();
    super.dispose();
  }

  bool get _emailValid {
    final v = _email.text.trim();
    return v.contains('@') && v.contains('.') && v.length >= 5;
  }

  Future<void> _sendLink() async {
    if (!_emailValid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithOtp(email: _email.text.trim(), emailRedirectTo: kAuthRedirect);
      if (mounted) setState(() => _linkSent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'We couldn\'t reach the sign-in service. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _oauth(OAuthProvider provider) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithOAuth(provider, redirectTo: kAuthRedirect);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign-in didn\'t complete. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testSignIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithPassword(email: _testEmail.text.trim(), password: _testPassword.text);
      // The router redirects on auth state change.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'We couldn\'t reach the sign-in service. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.pets, size: 56, color: c.accent),
                  const SizedBox(height: Space.lg),
                  Text(Brand.name, style: text.headlineSmall?.copyWith(color: c.inkMuted)),
                  const SizedBox(height: Space.sm),
                  Text(Brand.promise, style: text.displayMedium),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Every run earns a collectible animal card. Sign in to start your collection.',
                    style: text.bodyMedium?.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(height: Space.xxl),
                  if (_linkSent) _InboxCard(email: _email.text.trim(), onChange: () => setState(() => _linkSent = false)) else _emailForm(context),
                  const SizedBox(height: Space.xl),
                  Row(children: [
                    Expanded(child: Divider(color: c.line)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      child: Text('or', style: text.labelMedium?.copyWith(color: c.inkMuted)),
                    ),
                    Expanded(child: Divider(color: c.line)),
                  ]),
                  const SizedBox(height: Space.xl),
                  _providerButton(
                    label: 'Continue with Apple',
                    icon: Icons.apple,
                    configured: kAppleSignInConfigured,
                    onPressed: () => _oauth(OAuthProvider.apple),
                  ),
                  const SizedBox(height: Space.md),
                  _providerButton(
                    label: 'Continue with Google',
                    icon: Icons.g_mobiledata,
                    configured: kGoogleSignInConfigured,
                    onPressed: () => _oauth(OAuthProvider.google),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.lg),
                    Text(_error!, style: text.bodySmall?.copyWith(color: c.danger)),
                  ],
                  const SizedBox(height: Space.xxl),
                  _testAccountExpander(context),
                  const SizedBox(height: Space.lg),
                  Text(
                    'By continuing you agree to keep running for the joy of it. Your routes and health data stay private to you.',
                    textAlign: TextAlign.center,
                    style: text.labelSmall?.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _sendLink(),
          decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
        ),
        const SizedBox(height: Space.md),
        FilledButton(
          onPressed: _emailValid && !_busy ? _sendLink : null,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send me a sign-in link'),
        ),
      ],
    );
  }

  Widget _providerButton({required String label, required IconData icon, required bool configured, required VoidCallback onPressed}) {
    final button = OutlinedButton.icon(
      onPressed: configured && !_busy ? onPressed : null,
      icon: Icon(icon),
      label: Text(configured ? label : '$label · coming soon'),
    );
    if (configured) return button;
    return Tooltip(message: 'Coming soon', child: button);
  }

  Widget _testAccountExpander(BuildContext context) {
    final c = context.pug;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: () => setState(() => _showTest = !_showTest),
            icon: Icon(_showTest ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text('Test account', style: text.labelMedium?.copyWith(color: c.inkMuted)),
            style: TextButton.styleFrom(foregroundColor: c.inkMuted),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: _showTest
              ? Container(
                  padding: const EdgeInsets.all(Space.lg),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Pre-launch play accounts (arjun@pugmark.test …). Removed before public launch.',
                          style: text.bodySmall?.copyWith(color: c.inkMuted)),
                      const SizedBox(height: Space.md),
                      TextField(
                        controller: _testEmail,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Test email'),
                      ),
                      const SizedBox(height: Space.md),
                      TextField(
                        controller: _testPassword,
                        obscureText: true,
                        onSubmitted: (_) => _testSignIn(),
                        decoration: const InputDecoration(labelText: 'Password'),
                      ),
                      const SizedBox(height: Space.md),
                      OutlinedButton(onPressed: _busy ? null : _testSignIn, child: const Text('Sign in to test account')),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.email, required this.onChange});
  final String email;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_unread_outlined, color: c.accent, size: 32),
          const SizedBox(height: Space.md),
          Text('Check your inbox', style: text.headlineSmall),
          const SizedBox(height: Space.sm),
          Text('We sent a sign-in link to $email. Open it on this device and you\'re in.',
              style: text.bodyMedium?.copyWith(color: c.inkMuted)),
          const SizedBox(height: Space.md),
          TextButton(onPressed: onChange, child: const Text('Use a different email')),
        ],
      ),
    );
  }
}
