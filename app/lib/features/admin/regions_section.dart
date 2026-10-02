/// Regions: ISO 3166-2:IN codes with coarse bounding boxes (ALGORITHMS.md §9.4).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repos/repos.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';

class RegionsSection extends ConsumerStatefulWidget {
  const RegionsSection({super.key});
  @override
  ConsumerState<RegionsSection> createState() => _RegionsSectionState();
}

class _RegionsSectionState extends ConsumerState<RegionsSection> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(adminRegionsProvider);
    ref.invalidate(regionsProvider);
  }

  Future<void> _edit(RegionRow? r) async {
    final saved = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _RegionDialog(existing: r));
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final regions = ref.watch(adminRegionsProvider);
    String f(double? v) => v == null ? '—' : v.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Regions',
          subtitle: 'States and union territories. Bounding boxes sanity-check the on-device geocoder; souvenirs and monthly pools key off the code.',
          actions: [
            IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
            FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('New region')),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: SizedBox(
            width: 280,
            child: TextField(controller: _search, decoration: denseInput('Search code or name').copyWith(prefixIcon: const Icon(Icons.search, size: 18)), onChanged: (_) => setState(() {})),
          ),
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: AsyncBody<List<RegionRow>>(
            value: regions,
            onRetry: _refresh,
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No regions — run the seed migration.',
            builder: (all) {
              final q = _search.text.trim().toLowerCase();
              final rows = all.where((r) => q.isEmpty || r.code.toLowerCase().contains(q) || r.name.toLowerCase().contains(q)).toList();
              return Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Card(
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 44,
                        columnSpacing: Space.xl,
                        columns: const [
                          DataColumn(label: Text('Code')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Kind')),
                          DataColumn(label: Text('Lat range')),
                          DataColumn(label: Text('Lon range')),
                          DataColumn(label: Text('Centroid')),
                          DataColumn(label: Text('')),
                        ],
                        rows: [
                          for (final r in rows)
                            DataRow(cells: [
                              DataCell(Text(r.code, style: monoStyle(context))),
                              DataCell(Text(r.name), onTap: () => _edit(r)),
                              DataCell(TagPill(r.kind, color: r.kind == 'country' ? c.accent : null)),
                              DataCell(Text('${f(r.minLat)} – ${f(r.maxLat)}', style: monoStyle(context, size: 12, color: c.inkMuted))),
                              DataCell(Text('${f(r.minLon)} – ${f(r.maxLon)}', style: monoStyle(context, size: 12, color: c.inkMuted))),
                              DataCell(Text('${f(r.centroidLat)}, ${f(r.centroidLon)}', style: monoStyle(context, size: 12, color: c.inkMuted))),
                              DataCell(IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _edit(r))),
                            ]),
                        ],
                      ),
                    ),
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

class _RegionDialog extends ConsumerStatefulWidget {
  const _RegionDialog({this.existing});
  final RegionRow? existing;
  @override
  ConsumerState<_RegionDialog> createState() => _RegionDialogState();
}

class _RegionDialogState extends ConsumerState<_RegionDialog> {
  late final RegionRow? _r = widget.existing;
  late final _code = TextEditingController(text: _r?.code ?? 'IN-');
  late final _name = TextEditingController(text: _r?.name ?? '');
  late String _kind = _r?.kind ?? 'state';
  late final Map<String, TextEditingController> _nums = {
    'min_lat': TextEditingController(text: _r?.minLat?.toString() ?? ''),
    'max_lat': TextEditingController(text: _r?.maxLat?.toString() ?? ''),
    'min_lon': TextEditingController(text: _r?.minLon?.toString() ?? ''),
    'max_lon': TextEditingController(text: _r?.maxLon?.toString() ?? ''),
    'centroid_lat': TextEditingController(text: _r?.centroidLat?.toString() ?? ''),
    'centroid_lon': TextEditingController(text: _r?.centroidLon?.toString() ?? ''),
  };
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    for (final c in _nums.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty || _name.text.trim().isEmpty) {
      showErr(context, 'Code and name are required');
      return;
    }
    final row = <String, dynamic>{'code': code, 'name': _name.text.trim(), 'kind': _kind};
    for (final e in _nums.entries) {
      final t = e.value.text.trim();
      if (t.isEmpty) {
        row[e.key] = null;
        continue;
      }
      final v = double.tryParse(t);
      if (v == null) {
        showErr(context, '${e.key} must be a number');
        return;
      }
      row[e.key] = v;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminRepoProvider).upsertRegion(row);
      if (mounted) {
        showOk(context, '$code saved');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final r = _r;
    if (r == null) return;
    final ok = await confirmDialog(context, title: 'Delete ${r.code}?', body: 'Runs and rules referencing this code will block the delete; this is for typos only.');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepoProvider).deleteRegion(r.code);
      if (mounted) {
        showOk(context, '${r.code} deleted');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showErr(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    Widget numField(String key, String label) => Expanded(
          child: Field(label: label, child: TextField(controller: _nums[key], decoration: denseInput(), style: monoStyle(context), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
        );
    return AlertDialog(
      title: Text(_r == null ? 'New region' : 'Edit ${widget.existing?.code}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Field(label: 'Code', hint: 'ISO 3166-2:IN', child: TextField(controller: _code, decoration: denseInput('IN-KA'), style: monoStyle(context), enabled: _r == null))),
                  const SizedBox(width: Space.md),
                  Expanded(flex: 2, child: Field(label: 'Name', child: TextField(controller: _name, decoration: denseInput('Karnataka')))),
                ],
              ),
              const SizedBox(height: Space.md),
              Field(
                label: 'Kind',
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [ButtonSegment(value: 'state', label: Text('state')), ButtonSegment(value: 'ut', label: Text('ut')), ButtonSegment(value: 'country', label: Text('country'))],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
              ),
              const SizedBox(height: Space.md),
              Row(children: [numField('min_lat', 'Min lat'), const SizedBox(width: Space.md), numField('max_lat', 'Max lat')]),
              const SizedBox(height: Space.md),
              Row(children: [numField('min_lon', 'Min lon'), const SizedBox(width: Space.md), numField('max_lon', 'Max lon')]),
              const SizedBox(height: Space.md),
              Row(children: [numField('centroid_lat', 'Centroid lat'), const SizedBox(width: Space.md), numField('centroid_lon', 'Centroid lon')]),
            ],
          ),
        ),
      ),
      actions: [
        if (_r != null) TextButton(style: TextButton.styleFrom(foregroundColor: c.danger), onPressed: _busy ? null : _delete, child: const Text('Delete')),
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
      ],
    );
  }
}
