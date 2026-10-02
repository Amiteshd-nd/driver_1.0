import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/tokens.dart';

/// Distinct run-days and this week's count, derived from eligible runs.
class StreakStats {
  const StreakStats({required this.runDayKeys, required this.weekCount});

  /// `yyyy-mm-dd` keys for every eligible run-day.
  final Set<String> runDayKeys;

  /// Distinct run-days in the current Monday-first week.
  final int weekCount;

  static String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory StreakStats.from(List<RunSummary> runs, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final keys = <String>{for (final r in runs.where((r) => r.eligible)) key(r.localDate)};
    final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
    var week = 0;
    for (var i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      if (d.isAfter(today)) break;
      if (keys.contains(key(d))) week++;
    }
    return StreakStats(runDayKeys: keys, weekCount: week);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool ran(DateTime d) => runDayKeys.contains(key(_dateOnly(d)));
}

/// Seven dots for the last seven days plus the weekly-bag hint
/// (the only threshold the product ever hints at — DESIGN.md §7).
class StreakRow extends StatelessWidget {
  const StreakRow({super.key, required this.stats, required this.minRunDays});

  final StreakStats stats;
  final int minRunDays;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    final today = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final remaining = (minRunDays - stats.weekCount).clamp(0, 99);
    final n = stats.weekCount;
    final hint = remaining == 0
        ? '$n of the week · the weekly bag is open'
        : '$n of the week · $remaining more ${remaining == 1 ? 'opens' : 'open'} the weekly bag';

    return Semantics(
      label: 'Run-days in the last seven days: ${days.where(stats.ran).length}. $hint',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final d in days)
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stats.ran(d) ? c.accent : c.surfaceAlt,
                            border: Border.all(color: _isToday(d, today) ? c.accent : c.line, width: _isToday(d, today) ? 2 : 1),
                          ),
                          child: stats.ran(d) ? Icon(Icons.check, size: 16, color: c.accentInk) : null,
                        ),
                        const SizedBox(height: Space.xs),
                        Text(letters[d.weekday - 1], style: tt.labelSmall?.copyWith(color: c.inkMuted)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              Text(hint, style: tt.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isToday(DateTime d, DateTime now) => d.year == now.year && d.month == now.month && d.day == now.day;
}
