/// Config: one card per key with a validated JSON editor, plus quick-edit fields for the common numbers.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repos/repos.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';

class ConfigSection extends ConsumerWidget {
  const ConfigSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(adminConfigProvider);
    void refresh() {
      ref.invalidate(adminConfigProvider);
      ref.invalidate(weeklyConfigProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Config',
          subtitle: 'Every tunable number. Quick fields cover the common ones; every key has a full JSON editor.',
          actions: [IconButton(tooltip: 'Refresh', onPressed: refresh, icon: const Icon(Icons.refresh))],
        ),
        Expanded(
          child: AsyncBody<List<ConfigEntry>>(
            value: cfg,
            onRetry: refresh,
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No config rows — run the seed migration.',
            builder: (entries) {
              final byKey = {for (final e in entries) e.key: e};
              return ListView(
                padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                children: [
                  _QuickEdits(byKey: byKey, onSaved: refresh),
                  const SizedBox(height: Space.xl),
                  Text('All keys', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Space.md),
                  for (final e in entries) ...[
                    _ConfigCard(key: ValueKey('cfg-${e.key}-${e.updatedAt?.millisecondsSinceEpoch}'), entry: e, onSaved: refresh),
                    const SizedBox(height: Space.md),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConfigCard extends ConsumerStatefulWidget {
  const _ConfigCard({super.key, required this.entry, required this.onSaved});
  final ConfigEntry entry;
  final VoidCallback onSaved;
  @override
  ConsumerState<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends ConsumerState<_ConfigCard> {
  late final _ctrl = TextEditingController(text: prettyJson(widget.entry.value));
  String? _error;
  bool _dirty = false, _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _validate() {
    String? err;
    try {
      jsonDecode(_ctrl.text);
    } on FormatException catch (e) {
      err = e.message;
    }
    setState(() {
      _error = err;
      _dirty = _ctrl.text != prettyJson(widget.entry.value);
    });
  }

  Future<void> _save() async {
    dynamic parsed;
    try {
      parsed = jsonDecode(_ctrl.text);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminRepoProvider).updateConfig(widget.entry.key, parsed);
      if (mounted) showOk(context, '${widget.entry.key} saved');
      widget.onSaved();
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final e = widget.entry;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(e.key, style: monoStyle(context, size: 15)),
              const SizedBox(width: Space.md),
              Expanded(child: Text(e.description ?? '', style: t.bodySmall?.copyWith(color: c.inkMuted))),
              if (e.updatedAt != null) Text('updated ${fmtWhen(e.updatedAt!)}', style: t.labelSmall?.copyWith(color: c.inkMuted)),
            ],
          ),
          const SizedBox(height: Space.sm),
          TextField(
            controller: _ctrl,
            maxLines: null,
            minLines: 2,
            style: monoStyle(context, size: 12.5),
            decoration: denseInput().copyWith(errorText: _error),
            onChanged: (_) => _validate(),
          ),
          const SizedBox(height: Space.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_dirty)
                TextButton(
                  onPressed: () {
                    _ctrl.text = prettyJson(e.value);
                    _validate();
                  },
                  child: const Text('Reset'),
                ),
              FilledButton(onPressed: (_dirty && _error == null && !_saving) ? _save : null, child: Text(_saving ? 'Saving…' : 'Save')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Friendly fields for the numbers designers touch most (ALGORITHMS.md §3, §6.3, §1, §7).
class _QuickEdits extends ConsumerStatefulWidget {
  const _QuickEdits({required this.byKey, required this.onSaved});
  final Map<String, ConfigEntry> byKey;
  final VoidCallback onSaved;
  @override
  ConsumerState<_QuickEdits> createState() => _QuickEditsState();
}

class _QuickEditsState extends ConsumerState<_QuickEdits> {
  /// (config key, json path) → controller.
  final Map<String, TextEditingController> _ctrls = {};
  final Set<String> _saving = {};

  static const _groups = <String, List<(String, String)>>{
    'speed_bands': [('swift', 'swift ≥ P'), ('steady', 'steady ≥ P'), ('calm', 'calm ≥ P')],
    'pity': [('n0', 'n0 (grace cards)'), ('k', 'k (slope)'), ('cap', 'cap'), ('hard_pity', 'hard pity')],
    'floor': [('min_km', 'min km'), ('min_moving_s', 'min moving s'), ('min_speed_kmh', 'min speed km/h')],
    'limits': [('max_run_cards_per_day', 'run cards / day'), ('max_track_points', 'max track points')],
    'weekly': [('min_run_days', 'min run-days')],
  };

  TextEditingController _ctrl(String key, String path, dynamic current) =>
      _ctrls.putIfAbsent('$key.$path', () => TextEditingController(text: current?.toString() ?? ''));

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveGroup(String key) async {
    final entry = widget.byKey[key];
    if (entry == null) return;
    final value = Map<String, dynamic>.from((entry.value as Map?)?.cast<String, dynamic>() ?? const {});
    for (final (path, _) in _groups[key]!) {
      final text = _ctrls['$key.$path']?.text.trim() ?? '';
      final n = num.tryParse(text);
      if (n == null) {
        showErr(context, '$key.$path must be a number');
        return;
      }
      value[path] = text.contains('.') ? n.toDouble() : n.toInt();
    }
    setState(() => _saving.add(key));
    try {
      await ref.read(adminRepoProvider).updateConfig(key, value);
      if (mounted) showOk(context, '$key saved');
      widget.onSaved();
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick edits', style: t.titleMedium),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [
            for (final g in _groups.entries)
              if (widget.byKey.containsKey(g.key))
                SizedBox(
                  width: 300,
                  child: AdminCard(
                    padding: const EdgeInsets.all(Space.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.key, style: monoStyle(context, size: 14)),
                        Text(widget.byKey[g.key]!.description ?? '', style: t.labelSmall?.copyWith(color: c.inkMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: Space.sm),
                        for (final (path, label) in g.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.sm),
                            child: Row(
                              children: [
                                Expanded(child: Text(label, style: t.bodySmall)),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: _ctrl(g.key, path, (widget.byKey[g.key]!.value as Map?)?[path]),
                                    decoration: denseInput(),
                                    style: monoStyle(context),
                                    textAlign: TextAlign.end,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onSubmitted: (_) => _saveGroup(g.key),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: _saving.contains(g.key) ? null : () => _saveGroup(g.key),
                            child: Text(_saving.contains(g.key) ? 'Saving…' : 'Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
