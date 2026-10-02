import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/tokens.dart';
import '../../reveal/widgets/card_back.dart';

/// A glowing envelope for a claimed weekly/monthly card waiting to be revealed.
class EnvelopeCard extends StatelessWidget {
  const EnvelopeCard({super.key, required this.pending, required this.onOpen});

  final PendingCard pending;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final pal = pending.card.palette;
    final what = pending.scope == CardScope.monthly ? 'monthly' : 'weekly';
    final reduce = MediaQuery.disableAnimationsOf(context);

    Widget tile = Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: pal.bg,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: pal.accent, width: 1.5),
        boxShadow: [BoxShadow(color: pal.accent.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 1)],
      ),
      child: Row(
        children: [
          SizedBox(width: 48, height: 48, child: CustomPaint(painter: PawMarkPainter(color: pal.accent))),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A $what card is waiting', style: tt.titleMedium?.copyWith(color: pal.fg)),
                const SizedBox(height: 2),
                Text(
                  pending.runDays != null ? '${pending.runDays} run-days this ${pending.scope == CardScope.monthly ? 'month' : 'week'}. Tap to open.' : 'Tap to open.',
                  style: tt.bodySmall?.copyWith(color: pal.fg.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Icon(Icons.chevron_right, color: pal.fg),
        ],
      ),
    );

    if (!reduce) {
      tile = tile.animate(onPlay: (ctl) => ctl.repeat()).shimmer(delay: const Duration(milliseconds: 800), duration: const Duration(milliseconds: 1600));
    }

    return Semantics(
      button: true,
      label: 'A $what card is waiting. Open it.',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onOpen,
        child: ExcludeSemantics(child: Padding(padding: const EdgeInsets.all(2), child: tile)),
      ),
    );
  }
}
