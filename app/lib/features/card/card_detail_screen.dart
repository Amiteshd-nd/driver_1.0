import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import 'widgets/pug_card_view.dart';

/// Full card with stage, earn history, stats, season, verification and sharing.
class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({super.key, required this.cardId, this.initial});
  final String cardId;
  final PugCard? initial;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  PugCard? _card;
  bool _loading = false;
  bool _missing = false;
  bool? _publicOverride;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _card = widget.initial;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final fresh = await ref.read(apiProvider).card(widget.cardId);
      if (!mounted) return;
      setState(() {
        if (fresh != null) {
          _card = fresh;
          _publicOverride = null;
        } else if (_card == null) {
          _missing = true;
        }
      });
    } catch (_) {
      // Keep showing `initial`; nothing to say if we have nothing at all.
      if (mounted && _card == null) setState(() => _missing = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePublic(bool v) async {
    final card = _card;
    if (card == null || _toggling) return;
    setState(() {
      _toggling = true;
      _publicOverride = v;
    });
    try {
      await ref.read(apiProvider).setCardPublic(card.id, v);
      ref.invalidate(myCardsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _publicOverride = !v);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save that right now. Try again in a moment.")));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _copyLink(PugCard card) async {
    if (card.verifyUrl.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: card.verifyUrl));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verify link copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final c = context.pug;
    final tt = Theme.of(context).textTheme;

    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Card')),
        body: Center(
          child: _missing
              ? Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Text("We can't find that card in your ledger.", textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: c.inkMuted)),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final myCards = ref.watch(myCardsProvider).asData?.value ?? const <PugCard>[];
    final same = myCards.where((x) => x.animalId == card.animalId).toList();
    final earnCount = math.max(1, same.length);
    final bestSerial = same.isEmpty ? card.serialNo : same.map((x) => x.serialNo).reduce(math.min);
    final bestText = '#${bestSerial.toString().padLeft(4, '0')}';
    final earnedLine = earnCount == 1 ? 'Earned once · $bestText' : 'Earned $earnCount times · best $bestText';
    final isPublic = _publicOverride ?? card.isPublic;
    final width = math.min(MediaQuery.sizeOf(context).width - 48, 340.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(card.name),
        actions: [if (_loading) const Padding(padding: EdgeInsets.only(right: Space.lg), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xxxl),
          children: [
            Center(child: PugCardView(card: card, width: width)),
            const SizedBox(height: Space.xl),
            Text(card.stage.label, style: tt.headlineSmall),
            const SizedBox(height: Space.xs),
            Text(earnedLine, style: tt.bodyMedium?.copyWith(color: c.inkMuted)),
            const SizedBox(height: Space.xl),
            _StatsPanel(card: card),
            const SizedBox(height: Space.lg),
            _VerdictBadge(verdict: card.verdict),
            const SizedBox(height: Space.xl),
            FilledButton.icon(
              onPressed: () => context.pushNamed(Routes.poster, pathParameters: {'id': card.id}, extra: card),
              icon: const Icon(Icons.ios_share),
              label: const Text('Share poster'),
            ),
            const SizedBox(height: Space.sm),
            OutlinedButton.icon(
              onPressed: card.verifyUrl.isEmpty ? null : () => _copyLink(card),
              icon: const Icon(Icons.link),
              label: const Text('Copy verify link'),
            ),
            const SizedBox(height: Space.sm),
            SwitchListTile.adaptive(
              value: isPublic,
              onChanged: _toggling ? null : _togglePublic,
              contentPadding: EdgeInsets.zero,
              title: Text('Show on verify page', style: tt.titleMedium),
              subtitle: Text(
                isPublic ? 'Anyone with the serial can see this card and your first name.' : 'The serial still checks out, but the card stays with you.',
                style: tt.bodySmall?.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.card});
  final PugCard card;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    final rows = <(String, String)>[];
    switch (card.scope) {
      case CardScope.run:
        if (card.distanceKm != null) rows.add(('Distance', '${card.distanceKm!.toStringAsFixed(2)} km'));
        if (card.durationS != null) rows.add(('Time', fmtDuration(card.durationS!)));
        if (card.paceSPerKm != null) rows.add(('Pace', '${fmtPace(card.paceSPerKm!)} /km'));
      case CardScope.weekly:
        rows.add(('Run-days', '${card.runDays ?? 0}'));
        rows.add(('Distance', '${(card.volumeKm ?? 0).toStringAsFixed(1)} km'));
        if (card.variety) rows.add(('Wanderer', 'Yes'));
      case CardScope.monthly:
        if (card.statsLine.isNotEmpty) rows.add(('Month', card.statsLine));
    }
    rows.add(('Earned', fmtDate(card.issuedAt)));
    if (card.season != null && card.season!.isNotEmpty) rows.add(('Season', card.season!));
    rows.add(('Set', switch (card.scope) { CardScope.run => 'Everyday run', CardScope.weekly => 'Weekly', CardScope.monthly => 'Monthly' }));

    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(color: c.line, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Row(
                children: [
                  Expanded(child: Text(rows[i].$1, style: tt.bodyMedium?.copyWith(color: c.inkMuted))),
                  Text(rows[i].$2, style: PugText.stat(context).copyWith(fontSize: 18)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VerdictBadge extends StatelessWidget {
  const _VerdictBadge({required this.verdict});
  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    final color = verdictColor(context, verdict);
    final verified = verdict == Verdict.verified;
    final title = verified ? 'Verified ✓' : 'Unverified';
    final why = verified ? 'This run checked out end to end, so it drew from the full bag.' : "We couldn't fully verify this run, so it drew from the everyday bag.";
    return Semantics(
      label: '$title. $why',
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(verified ? Icons.verified_rounded : Icons.verified_outlined, color: color),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tt.titleMedium?.copyWith(color: color)),
                  const SizedBox(height: Space.xs),
                  Text(why, style: tt.bodySmall?.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
