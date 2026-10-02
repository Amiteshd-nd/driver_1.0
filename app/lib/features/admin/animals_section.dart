/// Animals: roster table with thumbnail, family, rarity, issued count and active toggle (DESIGN.md §11).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';
import 'animal_editor.dart';

class AnimalsSection extends ConsumerStatefulWidget {
  const AnimalsSection({super.key});
  @override
  ConsumerState<AnimalsSection> createState() => _AnimalsSectionState();
}

class _AnimalsSectionState extends ConsumerState<AnimalsSection> {
  final _search = TextEditingController();
  String? _family;
  bool _showInactive = true;
  final Set<String> _busy = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(adminAnimalsProvider);
    ref.invalidate(adminIssuedCountsProvider);
    ref.invalidate(animalsProvider);
    ref.invalidate(issuedCountsProvider);
  }

  Future<void> _toggleActive(AdminAnimal a, bool v) async {
    setState(() => _busy.add(a.animal.id));
    try {
      await ref.read(adminRepoProvider).setAnimalActive(a.animal.id, v);
      if (mounted) showOk(context, '${a.animal.name} is now ${v ? 'active' : 'inactive'}');
      _refresh();
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(a.animal.id));
    }
  }

  Future<void> _edit(AdminAnimal? a) async {
    final saved = await showAnimalEditor(context, a);
    if (saved == true) _refresh();
  }

  List<AdminAnimal> _filter(List<AdminAnimal> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((a) {
      if (!_showInactive && !a.isActive) return false;
      if (_family != null && a.animal.family != _family) return false;
      if (q.isEmpty) return true;
      final an = a.animal;
      return an.name.toLowerCase().contains(q) || an.slug.contains(q) || an.code.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final animals = ref.watch(adminAnimalsProvider);
    final counts = ref.watch(adminIssuedCountsProvider).valueOrNull ?? const <String, int>{};
    final c = context.pug;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Animals',
          subtitle: 'Every species in the game. Inactive animals stay in collections but leave every pool.',
          actions: [
            IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
            FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('New animal')),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Wrap(
            spacing: Space.md,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  decoration: denseInput('Search name, slug or code').copyWith(prefixIcon: const Icon(Icons.search, size: 18)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              DropdownButton<String?>(
                value: _family,
                hint: const Text('All families'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All families')),
                  for (final f in kFamilies) DropdownMenuItem<String?>(value: f, child: Text(f)),
                ],
                onChanged: (v) => setState(() => _family = v),
              ),
              FilterChip(label: const Text('Show inactive'), selected: _showInactive, onSelected: (v) => setState(() => _showInactive = v)),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: AsyncBody<List<AdminAnimal>>(
            value: animals,
            onRetry: _refresh,
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No animals yet — add the first one.',
            builder: (all) {
              final rows = _filter(all);
              if (rows.isEmpty) {
                return Center(child: Text('No animals match that filter.', style: TextStyle(color: c.inkMuted)));
              }
              return Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Card(
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 52,
                        columnSpacing: Space.xl,
                        columns: const [
                          DataColumn(label: Text('')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Code')),
                          DataColumn(label: Text('Family')),
                          DataColumn(label: Text('Rarity')),
                          DataColumn(label: Text('Issued'), numeric: true),
                          DataColumn(label: Text('Sort'), numeric: true),
                          DataColumn(label: Text('Active')),
                          DataColumn(label: Text('')),
                        ],
                        rows: [for (final a in rows) _row(context, a, counts[a.animal.id] ?? 0)],
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

  DataRow _row(BuildContext context, AdminAnimal a, int issued) {
    final an = a.animal;
    final c = context.pug;
    final repo = ref.read(adminRepoProvider);
    final adultArt = an.artPath(Stage.adult);
    final muted = TextStyle(color: c.inkMuted);
    return DataRow(
      cells: [
        DataCell(ArtThumb(animal: an, url: adultArt == null ? null : repo.artUrl(adultArt))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(an.name, style: a.isActive ? null : muted),
              if (an.isSecret) ...[const SizedBox(width: Space.sm), const TagPill('secret')],
            ],
          ),
          onTap: () => _edit(a),
        ),
        DataCell(Text(an.code, style: monoStyle(context))),
        DataCell(Text(an.family)),
        DataCell(RarityPill(an.rarity)),
        DataCell(Text('$issued')),
        DataCell(Text('${an.sortOrder}', style: muted)),
        DataCell(
          _busy.contains(an.id)
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(value: a.isActive, onChanged: (v) => _toggleActive(a, v)),
        ),
        DataCell(IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _edit(a))),
      ],
    );
  }
}
