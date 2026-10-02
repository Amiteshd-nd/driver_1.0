/// Rules: pick an animal, list its `animal_rules`, open the structured predicate editor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';
import 'rule_editor.dart';

class RulesSection extends ConsumerStatefulWidget {
  const RulesSection({super.key});
  @override
  ConsumerState<RulesSection> createState() => _RulesSectionState();
}

class _RulesSectionState extends ConsumerState<RulesSection> {
  AdminAnimal? _animal;
  final _busy = <String>{};

  void _refresh() {
    final a = _animal;
    if (a != null) ref.invalidate(adminRulesProvider(a.animal.id));
  }

  Future<void> _toggle(AnimalRule r, bool v) async {
    setState(() => _busy.add(r.id));
    try {
      await ref.read(adminRepoProvider).updateRule(r.id, {'is_active': v});
      if (mounted) showOk(context, 'Rule ${v ? 'enabled' : 'disabled'}');
      _refresh();
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _edit(AnimalRule? r) async {
    final a = _animal;
    if (a == null) return;
    final changed = await showRuleEditor(context, animal: a, existing: r);
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final t = Theme.of(context).textTheme;
    final animals = ref.watch(adminAnimalsProvider);
    final a = _animal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Rules',
          subtitle: 'Which bag an animal sits in, and when. Predicates are built from the fields; the JSON is shown read-only.',
          actions: [
            IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
            FilledButton.icon(onPressed: a == null ? null : () => _edit(null), icon: const Icon(Icons.add), label: const Text('New rule')),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: AsyncBody<List<AdminAnimal>>(
            value: animals,
            onRetry: () => ref.invalidate(adminAnimalsProvider),
            builder: (list) => Row(
              children: [
                SizedBox(width: 360, child: _AnimalPicker(animals: list, selected: a, onSelected: (v) => setState(() => _animal = v))),
                if (a != null) ...[
                  const SizedBox(width: Space.lg),
                  ArtThumb(animal: a.animal, size: 32),
                  const SizedBox(width: Space.sm),
                  Text(a.animal.family, style: t.bodySmall?.copyWith(color: c.inkMuted)),
                  const SizedBox(width: Space.sm),
                  RarityPill(a.animal.rarity),
                  if (!a.isActive) ...[const SizedBox(width: Space.sm), TagPill('inactive animal', color: c.warn)],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: a == null
              ? Center(child: Text('Pick an animal to see its rules.', style: t.bodyMedium?.copyWith(color: c.inkMuted)))
              : AsyncBody<List<AnimalRule>>(
                  value: ref.watch(adminRulesProvider(a.animal.id)),
                  onRetry: _refresh,
                  isEmpty: (d) => d.isEmpty,
                  emptyText: 'No rules yet — this animal is in no bag. Add one.',
                  builder: (rules) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                    itemCount: rules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
                    itemBuilder: (_, i) => _RuleTile(rule: rules[i], busy: _busy.contains(rules[i].id), onEdit: () => _edit(rules[i]), onToggle: (v) => _toggle(rules[i], v)),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AnimalPicker extends StatelessWidget {
  const _AnimalPicker({required this.animals, required this.selected, required this.onSelected});
  final List<AdminAnimal> animals;
  final AdminAnimal? selected;
  final ValueChanged<AdminAnimal?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<AdminAnimal>(
      displayStringForOption: (a) => '${a.animal.name} · ${a.animal.code}',
      initialValue: TextEditingValue(text: selected == null ? '' : '${selected!.animal.name} · ${selected!.animal.code}'),
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return animals;
        return animals.where((a) => a.animal.name.toLowerCase().contains(q) || a.animal.slug.contains(q) || a.animal.code.toLowerCase().contains(q) || a.animal.family.contains(q));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
        controller: ctrl,
        focusNode: focus,
        decoration: denseInput('Search an animal…').copyWith(
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              ctrl.clear();
              onSelected(null);
            },
          ),
        ),
        onSubmitted: (_) => onSubmit(),
      ),
      optionsViewBuilder: (context, select, options) {
        final c = context.pug;
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final a = list[i];
                  return ListTile(
                    dense: true,
                    leading: ArtThumb(animal: a.animal, size: 28),
                    title: Text(a.animal.name),
                    subtitle: Text('${a.animal.family} · ${a.animal.rarity.label}'),
                    trailing: Text(a.animal.code, style: monoStyle(context, size: 12, color: c.inkMuted)),
                    onTap: () => select(a),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.busy, required this.onEdit, required this.onToggle});
  final AnimalRule rule;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final t = Theme.of(context).textTheme;
    final r = rule;
    final tierLabel = r.scope == CardScope.run ? (kRunTierLabels[r.tier] ?? 'tier ${r.tier}') : r.scope == CardScope.weekly ? '${r.tier}-day bag' : 'regional';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TagPill(r.scope.name, color: c.accent),
                        Text(tierLabel, style: t.titleSmall),
                        Text('weight ${r.weight.toStringAsFixed(2)}', style: t.labelMedium?.copyWith(color: c.inkMuted)),
                        if (r.firstTimeGuaranteed) const TagPill('first-time guaranteed'),
                        Text('repeat ${(r.repeatProbability * 100).round()}%', style: t.labelMedium?.copyWith(color: c.inkMuted)),
                        if (!r.isActive) TagPill('disabled', color: c.warn),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Text(summarisePredicates(r.predicates), style: monoStyle(context, size: 12, color: c.inkMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if ((r.note ?? '').isNotEmpty) Text(r.note!, style: t.labelSmall?.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Switch(value: r.isActive, onChanged: onToggle),
              IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-line human summary: `speed ∈ swift · 3–7 km · time ∈ night`.
String summarisePredicates(Map<String, dynamic> p) {
  if (p.isEmpty) return 'always matches';
  final parts = <String>[];
  List<String> l(String k) => ((p[k] as List?) ?? const []).map((e) => e.toString()).toList();
  if (p.containsKey('speed_bands')) parts.add('speed ∈ ${l('speed_bands').join('/')}');
  if (p.containsKey('min_km') || p.containsKey('max_km')) parts.add('${p['min_km'] ?? '0'}–${p['max_km'] ?? '∞'} km');
  if (p.containsKey('time_windows')) parts.add('time ∈ ${l('time_windows').join('/')}');
  if (p.containsKey('requires_flags')) parts.add('flags ⊇ ${l('requires_flags').join(',')}');
  if (p.containsKey('region_codes')) parts.add('state ∈ ${l('region_codes').join(',')}');
  if (p.containsKey('requires_connected')) parts.add('connected ⊇ ${l('requires_connected').join(',')}');
  if (p.containsKey('min_run_days')) parts.add('run-days ≥ ${p['min_run_days']}');
  if (p.containsKey('min_moving_s')) parts.add('moving ≥ ${p['min_moving_s']} s');
  if (p.containsKey('min_volume_km')) parts.add('volume ≥ ${p['min_volume_km']} km');
  if (p['requires_variety'] == true) parts.add('variety');
  return parts.join(' · ');
}
