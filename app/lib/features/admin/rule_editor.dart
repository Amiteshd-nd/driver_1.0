/// Structured rule editor: fields build the `predicates` JSON (ALGORITHMS.md §6.1 keys).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';

Future<bool?> showRuleEditor(BuildContext context, {required AdminAnimal animal, AnimalRule? existing}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(Space.lg),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820, maxHeight: 860), child: RuleEditor(animal: animal, existing: existing)),
    ),
  );
}

class RuleEditor extends ConsumerStatefulWidget {
  const RuleEditor({super.key, required this.animal, this.existing});
  final AdminAnimal animal;
  final AnimalRule? existing;
  @override
  ConsumerState<RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<RuleEditor> {
  late final AnimalRule? _r = widget.existing;
  late final Map<String, dynamic> _p0 = _r?.predicates ?? const {};

  late CardScope _scope = _r?.scope ?? CardScope.run;
  late int _tier = _r?.tier ?? 0;
  late Set<String> _bands = _list('speed_bands');
  late Set<String> _windows = _list('time_windows');
  late Set<String> _flags = _list('requires_flags');
  late Set<String> _regions = _list('region_codes');
  late Set<String> _connected = _list('requires_connected');
  late final _minKm = TextEditingController(text: _p0['min_km']?.toString() ?? '');
  late final _maxKm = TextEditingController(text: _p0['max_km']?.toString() ?? '');
  late final _minRunDays = TextEditingController(text: _p0['min_run_days']?.toString() ?? '');
  late final _minMoving = TextEditingController(text: _p0['min_moving_s']?.toString() ?? '');
  late final _note = TextEditingController(text: _r?.note ?? '');
  late double _weight = (_r?.weight ?? 1.0).clamp(0.1, 5.0).toDouble();
  late bool _guaranteed = _r?.firstTimeGuaranteed ?? true;
  late double _repeat = (_r?.repeatProbability ?? 1.0).clamp(0.0, 1.0).toDouble();
  late bool _active = _r?.isActive ?? true;
  bool _saving = false;

  Set<String> _list(String k) => ((_p0[k] as List?) ?? const []).map((e) => e.toString()).toSet();

  @override
  void dispose() {
    for (final c in [_minKm, _maxKm, _minRunDays, _minMoving, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _predicates {
    num? n(TextEditingController c) => num.tryParse(c.text.trim());
    final p = <String, dynamic>{};
    if (_bands.isNotEmpty) p['speed_bands'] = kSpeedBands.where(_bands.contains).toList();
    if (n(_minKm) != null) p['min_km'] = n(_minKm);
    if (n(_maxKm) != null) p['max_km'] = n(_maxKm);
    if (_windows.isNotEmpty) p['time_windows'] = kTimeWindows.where(_windows.contains).toList();
    if (_flags.isNotEmpty) p['requires_flags'] = kRunFlags.where(_flags.contains).toList();
    if (_regions.isNotEmpty) p['region_codes'] = (_regions.toList()..sort());
    if (_connected.isNotEmpty) p['requires_connected'] = kConnected.where(_connected.contains).toList();
    if (n(_minRunDays) != null) p['min_run_days'] = n(_minRunDays)!.toInt();
    if (n(_minMoving) != null) p['min_moving_s'] = n(_minMoving)!.toInt();
    // Keep any advanced keys we do not edit here (min_volume_km, requires_variety …).
    for (final e in _p0.entries) {
      if (!p.containsKey(e.key) && !_knownKeys.contains(e.key)) p[e.key] = e.value;
    }
    return p;
  }

  static const _knownKeys = {'speed_bands', 'min_km', 'max_km', 'time_windows', 'requires_flags', 'region_codes', 'requires_connected', 'min_run_days', 'min_moving_s'};

  Map<String, dynamic> _row() => {
        'animal_id': widget.animal.animal.id,
        'scope': _scope.name,
        'tier': _tier,
        'predicates': _predicates,
        'weight': double.parse(_weight.toStringAsFixed(3)),
        'first_time_guaranteed': _guaranteed,
        'repeat_probability': double.parse(_repeat.toStringAsFixed(3)),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'is_active': _active,
      };

  void _setScope(CardScope s) {
    setState(() {
      _scope = s;
      if (s == CardScope.weekly) {
        if (!kWeeklyTiers.contains(_tier)) _tier = kWeeklyTiers.first;
        if (_minRunDays.text.trim().isEmpty) _minRunDays.text = '$_tier';
      } else if (s == CardScope.monthly) {
        _tier = 0;
      } else if (_tier > 4) {
        _tier = 0;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(adminRepoProvider);
    final r = _r;
    try {
      if (r == null) {
        await repo.insertRule(_row());
      } else {
        await repo.updateRule(r.id, _row());
      }
      if (mounted) {
        showOk(context, 'Rule saved');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final r = _r;
    if (r == null) return;
    final ok = await confirmDialog(context, title: 'Delete this rule?', body: '${widget.animal.animal.name} leaves this bag. The change is kept in History.');
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminRepoProvider).deleteRule(r.id);
      if (mounted) {
        showOk(context, 'Rule deleted');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showErr(context, e);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final t = Theme.of(context).textTheme;
    final regions = ref.watch(adminRegionsProvider).valueOrNull ?? const <RegionRow>[];
    final regionCodes = regions.where((r) => r.kind != 'country').map((r) => r.code).toList();
    final regionLabels = {for (final r in regions) r.code: '${r.code.replaceFirst('IN-', '')} ${r.name}'};
    final isRun = _scope == CardScope.run, isWeekly = _scope == CardScope.weekly;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.md, 0),
          child: Row(
            children: [
              ArtThumb(animal: widget.animal.animal, size: 36),
              const SizedBox(width: Space.md),
              Expanded(child: Text('${_r == null ? 'New rule' : 'Edit rule'} · ${widget.animal.animal.name}', style: t.headlineSmall)),
              IconButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Space.xl),
            children: [
              Wrap(
                spacing: Space.xl,
                runSpacing: Space.md,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Field(
                    label: 'Scope',
                    child: SegmentedButton<CardScope>(
                      showSelectedIcon: false,
                      segments: [for (final s in CardScope.values) ButtonSegment(value: s, label: Text(s.name))],
                      selected: {_scope},
                      onSelectionChanged: (s) => _setScope(s.first),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: Field(
                      label: isWeekly ? 'Bag (run-days)' : 'Tier',
                      hint: isRun ? 'Higher tiers open first when their trigger fires' : isWeekly ? 'Tier = run-days the bag needs' : 'Monthly pools are regional (tier 0)',
                      child: DropdownButtonFormField<int>(
                        value: _tier,
                        decoration: denseInput(),
                        items: isRun
                            ? [for (final e in kRunTierLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))]
                            : isWeekly
                                ? [for (final d in kWeeklyTiers) DropdownMenuItem(value: d, child: Text('$d-day bag'))]
                                : const [DropdownMenuItem(value: 0, child: Text('0 · regional'))],
                        onChanged: (v) => setState(() {
                          _tier = v ?? _tier;
                          if (isWeekly) _minRunDays.text = '$_tier';
                        }),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: Space.xxl),
              Text('Predicates', style: t.titleMedium),
              Text('All set predicates must hold for the rule to match. Leave a field empty to ignore it.', style: t.labelSmall?.copyWith(color: c.inkMuted)),
              const SizedBox(height: Space.md),
              Field(label: 'Speed bands', child: ChipGroup(values: kSpeedBands, selected: _bands, onChanged: (s) => setState(() => _bands = s))),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(child: Field(label: 'Min km', child: TextField(controller: _minKm, decoration: denseInput('e.g. 3'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})))),
                  const SizedBox(width: Space.lg),
                  Expanded(child: Field(label: 'Max km', child: TextField(controller: _maxKm, decoration: denseInput('e.g. 10'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})))),
                  const SizedBox(width: Space.lg),
                  Expanded(child: Field(label: 'Min moving s', child: TextField(controller: _minMoving, decoration: denseInput('e.g. 1800'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                  const SizedBox(width: Space.lg),
                  Expanded(child: Field(label: 'Min run-days', hint: 'weekly scope', child: TextField(controller: _minRunDays, decoration: denseInput('3 / 5 / 7'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                ],
              ),
              const SizedBox(height: Space.md),
              Field(label: 'Time windows', child: ChipGroup(values: kTimeWindows, selected: _windows, onChanged: (s) => setState(() => _windows = s))),
              const SizedBox(height: Space.md),
              Field(label: 'Requires flags', child: ChipGroup(values: kRunFlags, selected: _flags, onChanged: (s) => setState(() => _flags = s))),
              const SizedBox(height: Space.md),
              Field(label: 'Requires connected', hint: 'granted data purposes', child: ChipGroup(values: kConnected, selected: _connected, onChanged: (s) => setState(() => _connected = s))),
              const SizedBox(height: Space.md),
              Field(
                label: 'Region codes${_regions.isEmpty ? '' : ' (${_regions.length})'}',
                child: regions.isEmpty
                    ? Text('Regions are loading…', style: t.bodySmall?.copyWith(color: c.inkMuted))
                    : ChipGroup(values: regionCodes, selected: _regions, labels: regionLabels, onChanged: (s) => setState(() => _regions = s)),
              ),
              const Divider(height: Space.xxl),
              Text('Draw', style: t.titleMedium),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: Field(
                      label: 'Weight × ${_weight.toStringAsFixed(2)}',
                      hint: 'multiplies the rarity base weight',
                      child: Slider(value: _weight, min: 0.1, max: 5, divisions: 49, label: _weight.toStringAsFixed(1), onChanged: (v) => setState(() => _weight = v)),
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Field(
                      label: 'Repeat probability ${(_repeat * 100).round()}%',
                      hint: 'chance the tier fires again after the first time',
                      child: Slider(value: _repeat, min: 0, max: 1, divisions: 20, label: '${(_repeat * 100).round()}%', onChanged: (v) => setState(() => _repeat = v)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('First-time guaranteed'), subtitle: const Text('Tiers 1–4: fires the first time the trigger ever happens'), value: _guaranteed, onChanged: (v) => setState(() => _guaranteed = v))),
                  const SizedBox(width: Space.lg),
                  Expanded(child: SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Active'), value: _active, onChanged: (v) => setState(() => _active = v))),
                ],
              ),
              const SizedBox(height: Space.md),
              Field(label: 'Note', child: TextField(controller: _note, decoration: denseInput('why this rule exists'))),
              const SizedBox(height: Space.lg),
              Field(label: 'Resulting predicates JSON', child: JsonBlock(_predicates)),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              if (_r != null)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: c.danger),
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              const Spacer(),
              TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              const SizedBox(width: Space.sm),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
