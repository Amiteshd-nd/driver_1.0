import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/tokens.dart';

/// Calendar heat map of run-days for the last [weeks] weeks (columns = weeks, rows = Mon–Sun).
class RunHeatmap extends StatelessWidget {
  const RunHeatmap({super.key, required this.runs, this.weeks = 12});
  final List<RunSummary> runs;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final text = Theme.of(context).textTheme;
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    // Monday of the current week, then back (weeks - 1) weeks.
    final thisMonday = todayD.subtract(Duration(days: todayD.weekday - 1));
    final firstMonday = thisMonday.subtract(Duration(days: 7 * (weeks - 1)));

    final km = <DateTime, double>{};
    for (final r in runs) {
      final d = DateTime(r.localDate.year, r.localDate.month, r.localDate.day);
      if (d.isBefore(firstMonday) || d.isAfter(todayD)) continue;
      km[d] = (km[d] ?? 0) + r.distanceKm;
    }
    final runDays = km.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Run days', style: text.titleMedium),
        Text('$runDays in $weeks weeks', style: text.labelMedium?.copyWith(color: c.inkMuted)),
      ]),
      const SizedBox(height: Space.md),
      LayoutBuilder(builder: (context, box) {
        const gap = 3.0;
        final cell = ((box.maxWidth - 20 - gap * (weeks - 1)) / weeks).clamp(6.0, 22.0);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                for (var r = 0; r < 7; r++)
                  SizedBox(
                    height: cell + gap,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(r == 0 ? 'M' : r == 3 ? 'T' : r == 6 ? 'S' : '', style: text.labelSmall?.copyWith(color: c.inkMuted)),
                    ),
                  ),
              ],
            ),
          ),
          CustomPaint(
            size: Size(cell * weeks + gap * (weeks - 1), (cell + gap) * 7 - gap),
            painter: _HeatPainter(
              firstMonday: firstMonday,
              weeks: weeks,
              cell: cell,
              gap: gap,
              km: km,
              today: todayD,
              empty: c.surfaceAlt,
              line: c.line,
              accent: c.accent,
            ),
          ),
        ]);
      }),
    ]);
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter({
    required this.firstMonday,
    required this.weeks,
    required this.cell,
    required this.gap,
    required this.km,
    required this.today,
    required this.empty,
    required this.line,
    required this.accent,
  });
  final DateTime firstMonday, today;
  final int weeks;
  final double cell, gap;
  final Map<DateTime, double> km;
  final Color empty, line, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line.withValues(alpha: 0.6);
    for (var w = 0; w < weeks; w++) {
      for (var d = 0; d < 7; d++) {
        final day = firstMonday.add(Duration(days: w * 7 + d));
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH(w * (cell + gap), d * (cell + gap), cell, cell), const Radius.circular(3));
        if (day.isAfter(today)) continue;
        final v = km[day];
        if (v == null) {
          paint.color = empty;
          canvas.drawRRect(rect, paint);
        } else {
          final t = (v / 8).clamp(0.25, 1.0);
          paint.color = accent.withValues(alpha: t);
          canvas.drawRRect(rect, paint);
        }
        if (day == today) canvas.drawRRect(rect, border..color = accent);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatPainter old) => old.km != km || old.cell != cell || old.accent != accent || old.empty != empty;
}
