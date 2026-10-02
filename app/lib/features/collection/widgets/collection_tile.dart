import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/tokens.dart';
import '../../card/widgets/pug_card_view.dart';

/// Tile width used by the collection grid.
const double kCollectionTileWidth = 150;

/// An earned animal: its best (lowest-serial) card plus a count badge.
class OwnedAnimalTile extends StatelessWidget {
  const OwnedAnimalTile({super.key, required this.best, required this.count, required this.onTap});

  final PugCard best;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${best.name}, earned $count ${count == 1 ? 'time' : 'times'}, best serial ${best.serialNo}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PugCardView(card: best, width: kCollectionTileWidth, interactive: false, showStats: false),
              if (count > 1)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(Radii.chip), border: Border.all(color: c.bg, width: 2)),
                    child: Text('×$count', style: tt.labelMedium?.copyWith(color: c.accentInk, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A non-secret animal not yet earned: silhouette with "?", no name.
class UnknownAnimalTile extends StatelessWidget {
  const UnknownAnimalTile({super.key, required this.palette});
  final FamilyPalette palette;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    const w = kCollectionTileWidth;
    const h = w * 7 / 5;
    return Semantics(
      label: 'An animal you have not met yet',
      child: ExcludeSemantics(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.card * 0.6),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 56,
                child: Center(
                  child: Container(
                    width: w * 0.46,
                    height: w * 0.46,
                    decoration: BoxDecoration(color: c.line, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('?', style: tt.displaySmall?.copyWith(color: c.inkMuted)),
                  ),
                ),
              ),
              Expanded(
                flex: 44,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 10, width: w * 0.5, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(5))),
                      const SizedBox(height: Space.sm),
                      Container(height: 8, width: w * 0.35, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(4))),
                      const Spacer(),
                      Container(height: 4, width: w * 0.3, decoration: BoxDecoration(color: palette.accent.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
