/// Seasons: named sets with date ranges and a palette that tints glow/radiant finishes (ALGORITHMS.md §5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';

class SeasonsSection extends ConsumerWidget {
  const SeasonsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pug;
    final t = Theme.of(context).textTheme;
    final seasons = ref.watch(adminSeasonsProvider);
    void refresh() => ref.invalidate(adminSeasonsProvider);
    final today = DateTime.now();

    Future<void> edit(Season? s) async {
      final saved = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _SeasonDialog(existing: s));
      if (saved == true) refresh();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Seasons',
          subtitle: 'Cards issued inside a season carry its name and tint their finish with its palette.',
          actions: [
            IconButton(tooltip: 'Refresh', onPressed: refresh, icon: const Icon(Icons.refresh)),
            FilledButton.icon(onPressed: () => edit(null), icon: const Icon(Icons.add), label: const Text('New season')),
          ],
        ),
        Expanded(
          child: AsyncBody<List<Season>>(
            value: seasons,
            onRetry: refresh,
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No seasons yet.',
            builder: (list) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
              itemBuilder: (_, i) {
                final s = list[i];
                final live = s.isActive && !today.isBefore(s.startsOn) && !today.isAfter(s.endsOn.add(const Duration(days: 1)));
                final primary = HexField.parse(s.palette['primary']?.toString() ?? '') ?? c.surfaceAlt;
                final accent = HexField.parse(s.palette['accent']?.toString() ?? '') ?? c.line;
                return Card(
                  child: ListTile(
                    onTap: () => edit(s),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Space.sm),
                        gradient: LinearGradient(colors: [primary, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        border: Border.all(color: c.line),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(s.name, style: t.titleSmall),
                        const SizedBox(width: Space.sm),
                        if (live) TagPill('live now', color: c.success),
                        if (!s.isActive) TagPill('inactive', color: c.warn),
                      ],
                    ),
                    subtitle: Text('${fmtDay(s.startsOn)} → ${fmtDay(s.endsOn)} · ${s.slug}${s.palette['foil'] != null ? ' · foil ${s.palette['foil']}' : ''}', style: t.bodySmall?.copyWith(color: c.inkMuted)),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SeasonDialog extends ConsumerStatefulWidget {
  const _SeasonDialog({this.existing});
  final Season? existing;
  @override
  ConsumerState<_SeasonDialog> createState() => _SeasonDialogState();
}

class _SeasonDialogState extends ConsumerState<_SeasonDialog> {
  late final Season? _s = widget.existing;
  late final _name = TextEditingController(text: _s?.name ?? '');
  late final _slug = TextEditingController(text: _s?.slug ?? '');
  late final _primary = TextEditingController(text: _s?.palette['primary']?.toString() ?? '');
  late final _accent = TextEditingController(text: _s?.palette['accent']?.toString() ?? '');
  late final _foil = TextEditingController(text: _s?.palette['foil']?.toString() ?? '');
  late DateTime _start = _s?.startsOn ?? DateTime.now();
  late DateTime _end = _s?.endsOn ?? DateTime.now().add(const Duration(days: 90));
  late bool _active = _s?.isActive ?? true;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _slug, _primary, _accent, _foil]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(context: context, initialDate: start ? _start : _end, firstDate: DateTime(2024), lastDate: DateTime(2040));
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = d.isBefore(_start) ? _start : d;
      }
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _slug.text.trim().isEmpty) {
      showErr(context, 'Name and slug are required');
      return;
    }
    final row = {
      'name': _name.text.trim(),
      'slug': _slug.text.trim(),
      'starts_on': fmtDay(_start),
      'ends_on': fmtDay(_end),
      'palette': {
        if (HexField.parse(_primary.text) != null) 'primary': _primary.text.trim(),
        if (HexField.parse(_accent.text) != null) 'accent': _accent.text.trim(),
        if (_foil.text.trim().isNotEmpty) 'foil': _foil.text.trim(),
      },
      'is_active': _active,
    };
    setState(() => _busy = true);
    final repo = ref.read(adminRepoProvider);
    final s = _s;
    try {
      if (s == null) {
        await repo.insertSeason(row);
      } else {
        await repo.updateSeason(s.id, row);
      }
      if (mounted) {
        showOk(context, '${row['name']} saved');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final s = _s;
    if (s == null) return;
    final ok = await confirmDialog(context, title: 'Delete ${s.name}?', body: 'Cards already issued keep their season reference only if the row remains; prefer marking it inactive.');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepoProvider).deleteSeason(s.id);
      if (mounted) {
        showOk(context, 'Season deleted');
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
    return AlertDialog(
      title: Text(_s == null ? 'New season' : 'Edit season'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Field(label: 'Name', child: TextField(controller: _name, decoration: denseInput('Monsoon 2026'))),
              const SizedBox(height: Space.md),
              Field(label: 'Slug', child: TextField(controller: _slug, decoration: denseInput('monsoon-2026'), style: monoStyle(context))),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(child: Field(label: 'Starts on', child: OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(Icons.event, size: 18), label: Text(fmtDay(_start))))),
                  const SizedBox(width: Space.md),
                  Expanded(child: Field(label: 'Ends on', child: OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Icons.event, size: 18), label: Text(fmtDay(_end))))),
                ],
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(child: HexField(label: 'Primary', controller: _primary, onChanged: () => setState(() {}))),
                  const SizedBox(width: Space.md),
                  Expanded(child: HexField(label: 'Accent', controller: _accent, onChanged: () => setState(() {}))),
                ],
              ),
              const SizedBox(height: Space.md),
              Field(label: 'Foil', hint: 'teal · amber · rose …', child: TextField(controller: _foil, decoration: denseInput('amber'))),
              SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Active'), value: _active, onChanged: (v) => setState(() => _active = v)),
            ],
          ),
        ),
      ),
      actions: [
        if (_s != null) TextButton(style: TextButton.styleFrom(foregroundColor: c.danger), onPressed: _busy ? null : _delete, child: const Text('Delete')),
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
      ],
    );
  }
}
