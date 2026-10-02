import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/tokens.dart';

/// Pace trend (min/km) over the most recent eligible runs. Lower is faster, so the y-axis is inverted
/// by plotting negative pace and labelling the extremes.
class PaceTrend extends StatelessWidget {
  const PaceTrend({super.key, required this.runs, this.maxRuns = 20});
  final List<RunSummary> runs;
  final int maxRuns;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final usable = runs.where((r) => r.distanceM >= 1000 && r.movingS > 0).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final recent = usable.length > maxRuns ? usable.sublist(usable.length - maxRuns) : usable;

    if (recent.length < 2) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pace', style: text.titleMedium),
        const SizedBox(height: Space.sm),
        Text('Two measured runs and a trend line appears here.', style: text.bodySmall?.copyWith(color: c.inkMuted)),
      ]);
    }

    final spots = <FlSpot>[];
    var minPace = double.infinity, maxPace = 0.0;
    for (var i = 0; i < recent.length; i++) {
      final paceMin = recent[i].paceSPerKm / 60;
      if (paceMin < minPace) minPace = paceMin;
      if (paceMin > maxPace) maxPace = paceMin;
      spots.add(FlSpot(i.toDouble(), -paceMin));
    }
    final pad = ((maxPace - minPace) * 0.2).clamp(0.3, 2.0);
    final latest = recent.last.paceSPerKm;
    final best = recent.map((r) => r.paceSPerKm).reduce((a, b) => a < b ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Pace', style: text.titleMedium),
        Text('latest ${fmtPace(latest)} · best ${fmtPace(best)} /km', style: text.labelMedium?.copyWith(color: c.inkMuted)),
      ]),
      const SizedBox(height: Space.md),
      SizedBox(
        height: 120,
        child: LineChart(
          LineChartData(
            minY: -(maxPace + pad),
            maxY: -(minPace - pad),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touched) => touched
                    .map((s) => LineTooltipItem('${fmtPace((-s.y * 60).round())} /km', text.labelMedium ?? const TextStyle()))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.25,
                preventCurveOverShooting: true,
                color: c.accent,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(radius: 3, color: c.accent, strokeWidth: 0, strokeColor: c.accent),
                ),
                belowBarData: BarAreaData(show: true, color: c.accent.withValues(alpha: 0.10)),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
      const SizedBox(height: Space.xs),
      Text('Last ${recent.length} measured runs · higher on the chart is a quicker pace', style: text.labelSmall?.copyWith(color: c.inkMuted)),
    ]);
  }
}
