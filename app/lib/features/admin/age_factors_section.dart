/// Age factors: editable sex × age → factor table (ALGORITHMS.md §2.2).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';

const _sexes = ['male', 'female'];

class AgeFactorsSection extends ConsumerStatefulWidget {
  const AgeFactorsSection({super.key});
  @override
  ConsumerState<AgeFactorsSection> createState() => _AgeFactorsSectionState();
}

class _AgeFactorsSectionState extends ConsumerState<AgeFactorsSection> {
  final Set<String> _busy = {};
  final _newAge = TextEditingController();

  @override
  void dispose() {
    _newAge.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(adminAgeFactorsProvider);

  Future<void> _write(String sex, int age, double factor) async {
    final k = '$sex:$age';
    setState(() => _busy.add(k));
    try {
      await ref.read(adminRepoProvider).upsertAgeFactor(sex, age, factor);
      if (mounted) showOk(context, '$sex $age → ${factor.toStringAsFixed(3)} saved');
      _refresh();
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(k));
    }
  }

  Future<void> _deleteAge(int age) async {
    final ok = await confirmDialog(context, title: 'Remove age $age?', body: 'Both sexes lose this knot; the curve interpolates across the gap.');
    if (!ok || !mounted) return;
    setState(() => _busy.add('age:$age'));
    try {
      for (final s in _sexes) {
        await ref.read(adminRepoProvider).deleteAgeFactor(s, age);
      }
      if (mounted) showOk(context, 'Age $age removed');
      _refresh();
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove('age:$age'));
    }
  }

  Future<void> _addAge(List<AgeFactor> all) async {
    final age = int.tryParse(_newAge.text.trim());
    if (age == null || age < 5 || age > 110) {
      showErr(context, 'Enter an age between 5 and 110');
      return;
    }
    if (all.any((a) => a.age == age)) {
      showErr(context, 'Age $age already has a row');
      return;
    }
    for (final s in _sexes) {
      await _write(s, age, 1.0);
    }
    _newAge.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final factors = ref.watch(adminAgeFactorsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Age factors',
          subtitle: 'Knots of the age-grading curve; ages between knots are interpolated. Factor 1.000 = open-class speed.',
          actions: [IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh))],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(color: c.warn.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Radii.control), border: Border.all(color: c.warn.withValues(alpha: 0.4))),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: c.warn),
                const SizedBox(width: Space.sm),
                Expanded(child: Text('Approximate WMA shape — replace if licensed tables are adopted.', style: t.bodySmall)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: AsyncBody<List<AgeFactor>>(
            value: factors,
            onRetry: _refresh,
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No age factors — run the seed migration.',
            builder: (all) {
              final ages = all.map((a) => a.age).toSet().toList()..sort();
              final byKey = {for (final a in all) '${a.sex}:${a.age}': a.factor};
              return Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 48,
                            columnSpacing: Space.xxl,
                            columns: [
                              const DataColumn(label: Text('Age'), numeric: true),
                              for (final s in _sexes) DataColumn(label: Text(s)),
                              const DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final age in ages)
                                DataRow(cells: [
                                  DataCell(Text('$age', style: monoStyle(context))),
                                  for (final s in _sexes)
                                    DataCell(_FactorCell(
                                      key: ValueKey('$s:$age:${byKey['$s:$age']}'),
                                      value: byKey['$s:$age'],
                                      busy: _busy.contains('$s:$age'),
                                      onSubmit: (v) => _write(s, age, v),
                                    )),
                                  DataCell(IconButton(
                                    tooltip: 'Remove age',
                                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                                    onPressed: _busy.contains('age:$age') ? null : () => _deleteAge(age),
                                  )),
                                ]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      Row(
                        children: [
                          SizedBox(width: 120, child: TextField(controller: _newAge, decoration: denseInput('age'), keyboardType: TextInputType.number, onSubmitted: (_) => _addAge(all))),
                          const SizedBox(width: Space.sm),
                          OutlinedButton.icon(onPressed: () => _addAge(all), icon: const Icon(Icons.add, size: 18), label: const Text('Add age knot')),
                          const SizedBox(width: Space.lg),
                          Text('Factors must be in (0, 1.2]. Press Enter in a cell to save.', style: t.labelSmall?.copyWith(color: c.inkMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FactorCell extends StatefulWidget {
  const _FactorCell({super.key, required this.value, required this.busy, required this.onSubmit});
  final double? value;
  final bool busy;
  final ValueChanged<double> onSubmit;
  @override
  State<_FactorCell> createState() => _FactorCellState();
}

class _FactorCellState extends State<_FactorCell> {
  late final _ctrl = TextEditingController(text: widget.value?.toStringAsFixed(3) ?? '');
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v <= 0 || v > 1.2) {
      setState(() => _err = '0–1.2');
      return;
    }
    setState(() => _err = null);
    widget.onSubmit(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final changed = _ctrl.text.trim() != (widget.value?.toStringAsFixed(3) ?? '');
    return SizedBox(
      width: 140,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: !widget.busy,
              style: monoStyle(context, color: _err == null ? null : c.danger),
              decoration: denseInput('—').copyWith(errorText: _err, errorStyle: const TextStyle(fontSize: 0, height: 0)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ),
          SizedBox(
            width: 28,
            child: widget.busy
                ? const Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2))
                : changed
                    ? IconButton(padding: EdgeInsets.zero, iconSize: 18, tooltip: 'Save', icon: Icon(Icons.check, color: c.success), onPressed: _submit)
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
