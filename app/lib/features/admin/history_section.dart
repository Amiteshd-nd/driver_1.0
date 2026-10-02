/// History: `rule_history` latest 200 with an expandable old → new diff (changed keys highlighted).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';

class HistorySection extends ConsumerStatefulWidget {
  const HistorySection({super.key});
  @override
  ConsumerState<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<HistorySection> {
  String? _table;

  void _refresh() => ref.invalidate(adminHistoryProvider);

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final t = Theme.of(context).textTheme;
    final history = ref.watch(adminHistoryProvider);
    const tables = ['animals', 'animal_rules', 'config', 'seasons', 'age_factors', 'regions'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'History',
          subtitle: 'Every change to the rule tables, newest first (latest 200).',
          actions: [IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh))],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Wrap(
            spacing: Space.sm,
            children: [
              ChoiceChip(label: const Text('all'), selected: _table == null, onSelected: (_) => setState(() => _table = null)),
              for (final tb in tables) ChoiceChip(label: Text(tb), selected: _table == tb, onSelected: (_) => setState(() => _table = tb)),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: AsyncBody<List<RuleHistoryRow>>(
            value: history,
            onRetry: _refresh,
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No changes recorded yet.',
            builder: (all) {
              final rows = _table == null ? all : all.where((r) => r.tableName == _table).toList();
              if (rows.isEmpty) return Center(child: Text('No changes for $_table.', style: t.bodyMedium?.copyWith(color: c.inkMuted)));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: Space.xs),
                itemBuilder: (_, i) => _HistoryTile(row: rows[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row});
  final RuleHistoryRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final t = Theme.of(context).textTheme;
    final r = row;
    final actionColor = switch (r.action) { 'INSERT' => c.success, 'DELETE' => c.danger, _ => c.accent };
    final label = _rowLabel(r);
    return Card(
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        tilePadding: const EdgeInsets.symmetric(horizontal: Space.lg),
        childrenPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        leading: SizedBox(width: 64, child: TagPill(r.action.toLowerCase(), color: actionColor)),
        title: Row(
          children: [
            Text(r.tableName, style: monoStyle(context, size: 13)),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(label, style: t.bodySmall?.copyWith(color: c.inkMuted), overflow: TextOverflow.ellipsis)),
          ],
        ),
        subtitle: Text('${fmtWhen(r.changedAt)} · by ${shortUuid(r.changedBy)}', style: t.labelSmall?.copyWith(color: c.inkMuted)),
        children: [_Diff(oldRow: r.oldRow, newRow: r.newRow)],
      ),
    );
  }

  String _rowLabel(RuleHistoryRow r) {
    final m = r.newRow ?? r.oldRow ?? const {};
    final name = m['name'] ?? m['key'] ?? m['slug'] ?? m['code'];
    if (name != null) return name.toString();
    if (r.tableName == 'animal_rules') return 'rule ${shortUuid(r.rowId)} · ${m['scope']} tier ${m['tier']}';
    return r.rowId;
  }
}

class _Diff extends StatelessWidget {
  const _Diff({required this.oldRow, required this.newRow});
  final Map<String, dynamic>? oldRow, newRow;

  static const _skip = {'updated_at'};

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final t = Theme.of(context).textTheme;
    final o = oldRow ?? const <String, dynamic>{};
    final n = newRow ?? const <String, dynamic>{};
    final keys = {...o.keys, ...n.keys}.where((k) => !_skip.contains(k)).toList()..sort();
    final changed = keys.where((k) => prettyJson(o[k]) != prettyJson(n[k])).toList();
    final unchanged = keys.where((k) => !changed.contains(k)).toList();

    if (changed.isEmpty) {
      return Text('No field changes (touch only).', style: t.bodySmall?.copyWith(color: c.inkMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${changed.length} changed · ${unchanged.length} unchanged', style: t.labelSmall?.copyWith(color: c.inkMuted)),
        const SizedBox(height: Space.sm),
        for (final k in changed) _DiffRow(k: k, oldV: o[k], newV: n[k], hasOld: oldRow != null, hasNew: newRow != null),
      ],
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.k, required this.oldV, required this.newV, required this.hasOld, required this.hasNew});
  final String k;
  final dynamic oldV, newV;
  final bool hasOld, hasNew;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    Widget side(dynamic v, bool present, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(Space.sm),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Space.sm), border: Border.all(color: color.withValues(alpha: 0.35))),
            child: SelectableText(present ? prettyJson(v) : '∅', style: monoStyle(context, size: 12, color: present ? null : c.inkMuted)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: monoStyle(context, size: 12, color: c.accent)),
          const SizedBox(height: Space.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              side(oldV, hasOld, c.danger),
              Padding(padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm), child: Icon(Icons.arrow_forward, size: 16, color: c.inkMuted)),
              side(newV, hasNew, c.success),
            ],
          ),
        ],
      ),
    );
  }
}
