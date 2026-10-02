import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/tokens.dart';

/// Runs · km · cards, side by side.
class TotalsRow extends StatelessWidget {
  const TotalsRow({super.key, required this.runs, required this.cards});
  final List<RunSummary> runs;
  final List<CollectibleCard> cards;

  @override
  Widget build(BuildContext context) {
    final km = runs.fold<double>(0, (a, r) => a + r.distanceKm);
    return Row(children: [
      Expanded(child: _Tile(label: 'runs', value: runs.length.toString())),
      const SizedBox(width: Space.md),
      Expanded(child: _Tile(label: 'km', value: km >= 100 ? km.toStringAsFixed(0) : km.toStringAsFixed(1))),
      const SizedBox(width: Space.md),
      Expanded(child: _Tile(label: 'cards', value: cards.length.toString())),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
      child: Column(children: [
        Text(value, style: AppText.stat(context)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.inkMuted)),
      ]),
    );
  }
}
