import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/theme/tokens.dart';
import '../card/widgets/animal_art.dart';
import 'animal_entry_sheet.dart';

const _familyOrder = ['swift', 'steady', 'calm', 'gentle', 'time', 'explorer', 'regional', 'weekly', 'migratory', 'national', 'secret'];

/// Searchable list of animals (names only — never people), grouped by family.
class EncyclopediaScreen extends ConsumerStatefulWidget {
  const EncyclopediaScreen({super.key});

  @override
  ConsumerState<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends ConsumerState<EncyclopediaScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(animalsProvider);
    ref.invalidate(issuedCountsProvider);
    try {
      await ref.read(animalsProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    final animalsAsync = ref.watch(animalsProvider);
    final cards = ref.watch(myCardsProvider).asData?.value ?? const <PugCard>[];
    final issued = ref.watch(issuedCountsProvider).asData?.value ?? const <String, int>{};
    final earnedCounts = <String, int>{};
    for (final card in cards) {
      earnedCounts[card.animalId] = (earnedCounts[card.animalId] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Encyclopedia')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.sm),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search animals',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty ? null : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close), onPressed: _query.clear),
              ),
            ),
          ),
          Expanded(
            child: animalsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(Space.xl),
                  children: [Text("Couldn't load the encyclopedia. Pull down to try again.", textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: c.inkMuted))],
                ),
              ),
              data: (animals) {
                final q = _query.text.trim().toLowerCase();
                final visible = animals.where((a) {
                  final owned = (earnedCounts[a.id] ?? 0) > 0;
                  if (a.isSecret && !owned) return false;
                  return q.isEmpty || a.name.toLowerCase().contains(q);
                }).toList();

                if (visible.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(Space.xl),
                    children: [
                      Text(q.isEmpty ? 'The encyclopedia is filling up. Check back soon.' : 'No animal by that name — yet.', textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: c.inkMuted)),
                    ],
                  );
                }

                final families = visible.map((a) => a.family).toSet().toList()
                  ..sort((a, b) {
                    final ia = _familyOrder.indexOf(a), ib = _familyOrder.indexOf(b);
                    return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
                  });

                final rows = <Widget>[];
                for (final fam in families) {
                  rows.add(Padding(
                    padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xs),
                    child: Text(_familyLabel(fam), style: tt.headlineSmall),
                  ));
                  for (final a in visible.where((a) => a.family == fam)) {
                    final n = earnedCounts[a.id] ?? 0;
                    rows.add(_AnimalRow(
                      animal: a,
                      earnedCount: n,
                      onTap: () => AnimalEntrySheet.show(context, animal: a, earnedCount: n, issuedSoFar: _issuedSoFar(issued[a.id])),
                    ));
                  }
                }
                rows.add(const SizedBox(height: Space.xxxl));
                return RefreshIndicator(onRefresh: _refresh, child: ListView(children: rows));
              },
            ),
          ),
        ],
      ),
    );
  }

  /// `animal_counters.next_serial` is the next number to hand out, so issued = next − 1.
  // animal_counters.next_serial is the number of cards issued so far (0 before the first card).
  static int? _issuedSoFar(int? nextSerial) => nextSerial;

  static String _familyLabel(String f) => f.isEmpty ? 'Other' : '${f[0].toUpperCase()}${f.substring(1)}';
}

class _AnimalRow extends StatelessWidget {
  const _AnimalRow({required this.animal, required this.earnedCount, required this.onTap});
  final Animal animal;
  final int earnedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    final a = animal;
    return ListTile(
      onTap: onTap,
      minVerticalPadding: Space.md,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          width: 56,
          height: 56,
          color: a.palette.bg,
          padding: const EdgeInsets.all(6),
          child: AnimalArt(slug: a.slug, name: a.name, family: a.family, stage: Stage.adult, path: a.artPath(Stage.adult), palette: a.palette),
        ),
      ),
      title: Text(a.name, style: tt.titleMedium),
      subtitle: a.flavourLine.isEmpty ? null : Text(a.flavourLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: c.inkMuted)),
      trailing: earnedCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
              decoration: BoxDecoration(color: c.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.chip)),
              child: Text('×$earnedCount', style: tt.labelMedium?.copyWith(color: c.success)),
            )
          : Icon(Icons.chevron_right, color: c.inkMuted),
    );
  }
}
