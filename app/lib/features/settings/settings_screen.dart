import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/brand.dart';
import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/router.dart';
import '../../core/supabase.dart';
import '../../core/theme/tokens.dart';
import '../run/health_import.dart';
import '../run/run_queue.dart';
import 'widgets/pace_trend.dart';
import 'widgets/permission_receipt.dart';
import 'widgets/profile_card.dart';
import 'widgets/run_heatmap.dart';
import 'widgets/totals_row.dart';

/// The "You" tab: trust centre first, furniture below the fold (DESIGN.md §7).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    ref.read(runQueueProvider); // flush any runs saved offline
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _importHealth(Profile? p) async {
    if (_working) return;
    setState(() => _working = true);
    final s = await HealthImport.importRecent(ref.read(apiProvider), ref.read(runQueueProvider), timezone: p?.timezone ?? Brand.defaultTimezone);
    if (s.submitted > 0) refreshAfterCard(ref);
    if (mounted) setState(() => _working = false);
    if (s.message != null) _snack(s.message!);
  }

  Future<void> _export(Profile? p) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final api = ref.read(apiProvider);
      final runs = await api.myRuns(limit: 2000);
      final cards = await api.myCards(limit: 2000);
      final data = {
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'profile': p == null
            ? null
            : {
                'id': p.id,
                'display_name': p.displayName,
                'birth_year': p.birthYear,
                'sex': p.sex,
                'home_region': p.homeRegion,
                'timezone': p.timezone,
                'connected': p.connected,
              },
        'runs': [
          for (final r in runs)
            {
              'id': r.id,
              'started_at': r.startedAt.toUtc().toIso8601String(),
              'distance_m': r.distanceM,
              'moving_s': r.movingS,
              'avg_speed_kmh': r.avgSpeedKmh,
              'verdict': r.verdict.name,
              'eligible': r.eligible,
              'speed_band': r.speedBand,
              'time_window': r.timeWindow,
              'flags': r.flags,
              'state_code': r.stateCode,
              'elev_gain_m': r.elevGainM,
            }
        ],
        'cards': [
          for (final k in cards)
            {
              'id': k.id,
              'serial': k.serial,
              'animal': k.name,
              'slug': k.slug,
              'rarity': k.rarity.name,
              'scope': k.scope.name,
              'stage': k.stage.name,
              'finish': k.finish.name,
              'season': k.season,
              'stats': k.stats,
              'verdict': k.verdict.name,
              'issued_at': k.issuedAt.toUtc().toIso8601String(),
              'verify_url': k.verifyUrl,
            }
        ],
        'note': 'Routes (run_tracks) are kept privately and are not included in this export. Email support to request them.',
      };
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/json', name: 'pugmark-export.json')],
        subject: 'My Pugmark data',
        text: 'Your Pugmark profile, runs and cards.',
      );
    } catch (_) {
      _snack('We couldn\'t build the export right now. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteAccount() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('This removes your profile, runs, routes and cards for good. Serial numbers you earned are retired, not reissued. There is no undo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep my account')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _working = true);
    try {
      await supabase.rpc('delete_my_account');
      await supabase.auth.signOut();
      ref.read(onboardingDoneProvider.notifier).state = false;
    } catch (_) {
      _snack('Deletion isn\'t automated yet. Email support@pugmark.run from your account address and we\'ll remove everything within 7 days.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Sign-out didn\'t complete. Try again in a moment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final text = Theme.of(context).textTheme;
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final runs = ref.watch(myRunsProvider).valueOrNull ?? const <RunSummary>[];
    final cards = ref.watch(myCardsProvider).valueOrNull ?? const <PugCard>[];

    return Scaffold(
      appBar: AppBar(title: const Text('You')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileProvider);
          ref.invalidate(myRunsProvider);
          ref.invalidate(myCardsProvider);
          await ref.read(profileProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxxl),
          children: [
            if (profile != null) ProfileCard(profile: profile) else if (profileAsync.isLoading) const _Loading() else const _Unavailable(),
            const SizedBox(height: Space.xl),
            if (profile != null) PermissionReceipt(profile: profile),
            const SizedBox(height: Space.xxl),
            // ---- furniture (below the fold) ----
            TotalsRow(runs: runs, cards: cards),
            const SizedBox(height: Space.xl),
            _Card(child: RunHeatmap(runs: runs)),
            const SizedBox(height: Space.lg),
            _Card(child: PaceTrend(runs: runs)),
            const SizedBox(height: Space.xxl),
            // ---- actions ----
            _Action(icon: Icons.qr_code_scanner, title: 'Verify a card', subtitle: 'Look up any serial, like "Tiger #0427"', onTap: () => context.pushNamed(Routes.search)),
            _Action(
              icon: Icons.favorite_outline,
              title: 'Import from Health',
              subtitle: 'Bring in recent running workouts from your watch',
              onTap: _working ? null : () => _importHealth(profile),
            ),
            _Action(icon: Icons.download_outlined, title: 'Export my data', subtitle: 'Profile, runs and cards as JSON', onTap: _working ? null : () => _export(profile)),
            _Action(
              icon: Icons.delete_outline,
              title: 'Delete my account',
              subtitle: 'Removes everything. Takes effect immediately.',
              danger: true,
              onTap: _working ? null : _deleteAccount,
            ),
            _Action(icon: Icons.logout, title: 'Sign out', onTap: _signOut),
            if (profile?.isAdmin == true) ...[
              const SizedBox(height: Space.lg),
              _Action(icon: Icons.admin_panel_settings_outlined, title: 'Admin panel', subtitle: 'Animals, rules, config, seasons', onTap: () => context.pushNamed(Routes.admin)),
            ],
            const SizedBox(height: Space.xl),
            Center(child: Text('${Brand.name} · ${Brand.tagline}', style: text.labelSmall?.copyWith(color: c.inkMuted))),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
      child: child,
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, this.subtitle, this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final color = danger ? c.danger : c.ink;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.sm),
      leading: Icon(icon, color: onTap == null ? c.inkMuted : color),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: onTap == null ? c.inkMuted : color)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkMuted)),
      trailing: Icon(Icons.chevron_right, color: c.inkMuted),
      onTap: onTap,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(Space.xl), child: Center(child: CircularProgressIndicator()));
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Text('Your profile will appear once we can reach the server. Pull to refresh.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.inkMuted)),
    );
  }
}
