import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/router.dart';
import '../../core/theme/tokens.dart';
import '../card/widgets/pug_card_view.dart';
import 'widgets/envelope_card.dart';
import 'widgets/event_banner.dart';
import 'widgets/streak_row.dart';

/// Home (DESIGN.md §7): latest card as hero, streak dots, weekly-bag hint,
/// pending envelopes, celebration banners, and the Start-a-run action.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> with WidgetsBindingObserver {
  final List<PendingCard> _pending = [];
  final Set<int> _dismissedEvents = {};
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      refreshAfterCard(ref);
      _claim();
    }
  }

  Future<void> _claim() async {
    if (_claiming) return;
    _claiming = true;
    try {
      final claimed = await ref.read(apiProvider).claimPendingCards();
      if (!mounted || claimed.isEmpty) return;
      setState(() {
        final have = _pending.map((p) => p.card.id).toSet();
        _pending.addAll(claimed.where((p) => !have.contains(p.card.id)));
      });
      refreshAfterCard(ref);
    } catch (_) {
      // Quiet: the envelopes will be there next time.
    } finally {
      _claiming = false;
    }
  }

  Future<void> _refresh() async {
    refreshAfterCard(ref);
    ref.invalidate(weeklyConfigProvider);
    try {
      await ref.read(myCardsProvider.future);
    } catch (_) {}
    await _claim();
  }

  void _openEnvelope(PendingCard p) {
    setState(() => _pending.removeWhere((x) => x.card.id == p.card.id));
    context.pushNamed(Routes.reveal, extra: RevealPayload(pending: p));
  }

  Future<void> _dismissEvent(AppEvent e) async {
    setState(() => _dismissedEvents.add(e.id));
    try {
      await ref.read(apiProvider).markEventsSeen([e.id]);
    } catch (_) {
    } finally {
      ref.invalidate(unseenEventsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    final cardsAsync = ref.watch(myCardsProvider);
    final runs = ref.watch(myRunsProvider).asData?.value ?? const <RunSummary>[];
    final weekly = ref.watch(weeklyConfigProvider).asData?.value ?? const <String, dynamic>{};
    final events = (ref.watch(unseenEventsProvider).asData?.value ?? const <AppEvent>[])
        .where((e) => EventBanner.kinds.contains(e.kind) && !_dismissedEvents.contains(e.id))
        .toList();
    final minDays = _asInt(weekly['min_run_days']) ?? 3;
    final stats = StreakStats.from(runs);
    final heroWidth = math.min(MediaQuery.sizeOf(context).width - 48, 320.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'Verify a card',
            icon: const Icon(Icons.qr_code_scanner_outlined),
            onPressed: () => context.pushNamed(Routes.search),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(Routes.run),
        icon: const Icon(Icons.directions_run),
        label: const Text('Start a run'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, 96),
          children: [
            for (final e in events) EventBanner(event: e, onDismiss: () => _dismissEvent(e)),
            if (_pending.isNotEmpty) ...[
              Text('Waiting for you', style: tt.labelMedium?.copyWith(color: c.inkMuted)),
              const SizedBox(height: Space.sm),
              for (final p in _pending) Padding(padding: const EdgeInsets.only(bottom: Space.md), child: EnvelopeCard(pending: p, onOpen: () => _openEnvelope(p))),
              const SizedBox(height: Space.sm),
            ],
            cardsAsync.when(
              loading: () => SizedBox(height: heroWidth * PugCardView.aspect, child: const Center(child: CircularProgressIndicator())),
              error: (_, __) => _EmptyBag(width: heroWidth, message: "Couldn't load your cards. Pull down to try again."),
              data: (cards) {
                if (cards.isEmpty) return _EmptyBag(width: heroWidth, message: 'Your first run opens the bag.');
                final latest = cards.first;
                return Column(
                  children: [
                    Center(
                      child: Semantics(
                        button: true,
                        hint: 'Opens card details',
                        child: GestureDetector(
                          onTap: () => context.pushNamed(Routes.card, pathParameters: {'id': latest.id}, extra: latest),
                          child: PugCardView(card: latest, width: heroWidth),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Text('Latest card · ${fmtDate(latest.issuedAt)}', style: tt.labelMedium?.copyWith(color: c.inkMuted)),
                  ],
                );
              },
            ),
            const SizedBox(height: Space.xl),
            StreakRow(stats: stats, minRunDays: minDays),
            const SizedBox(height: Space.lg),
            Center(
              child: TextButton.icon(
                onPressed: () => context.pushNamed(Routes.search),
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Verify a card'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int? _asInt(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));
}

/// Empty-state "bag" illustration.
class _EmptyBag extends StatelessWidget {
  const _EmptyBag({required this.width, required this.message});
  final double width;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Container(
        width: width,
        height: width * 1.1,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: c.line),
        ),
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.line)),
              child: Icon(Icons.shopping_bag_outlined, size: 48, color: c.accent),
            ),
            const SizedBox(height: Space.xl),
            Text(message, textAlign: TextAlign.center, style: tt.headlineSmall),
            const SizedBox(height: Space.sm),
            Text('Run. Get an animal. Collect India.', textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: c.inkMuted)),
          ],
        ),
      ),
    );
  }
}
