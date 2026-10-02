import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/router.dart';
import '../../core/theme/tokens.dart';
import 'widgets/collection_tile.dart';

enum _Filter { all, run, weekly, monthly, rarePlus }

enum _Sort { newest, rarest, bestSerial }

/// Family display order (DESIGN.md §3.2), unknown families after.
const _familyOrder = ['swift', 'steady', 'calm', 'gentle', 'time', 'explorer', 'regional', 'weekly', 'migratory', 'national', 'secret'];

class _Entry {
  _Entry({required this.animalId, required this.family, required this.best, required this.count, required this.newest, required this.sortOrder});
  final String animalId, family;
  final PugCard best;
  final int count;
  final DateTime newest;
  final int sortOrder;
}

/// Earned animals grouped by family, plus "?" silhouettes for the rest of the world.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.newest;

  bool _passes(PugCard c) => switch (_filter) {
        _Filter.all => true,
        _Filter.run => c.scope == CardScope.run,
        _Filter.weekly => c.scope == CardScope.weekly,
        _Filter.monthly => c.scope == CardScope.monthly,
        _Filter.rarePlus => c.rarity.isRarePlus,
      };

  int _compare(_Entry a, _Entry b) => switch (_sort) {
        _Sort.newest => b.newest.compareTo(a.newest),
        _Sort.rarest => b.best.rarity.index != a.best.rarity.index ? b.best.rarity.index.compareTo(a.best.rarity.index) : a.best.serialNo.compareTo(b.best.serialNo),
        _Sort.bestSerial => a.best.serialNo != b.best.serialNo ? a.best.serialNo.compareTo(b.best.serialNo) : b.newest.compareTo(a.newest),
      };

  Future<void> _refresh() async {
    ref.invalidate(myCardsProvider);
    ref.invalidate(animalsProvider);
    try {
      await ref.read(myCardsProvider.future);
    } catch (_) {}
  }

  void _open(PugCard card) => context.pushNamed(Routes.card, pathParameters: {'id': card.id}, extra: card);

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    final cardsAsync = ref.watch(myCardsProvider);
    final animals = ref.watch(animalsProvider).asData?.value ?? const <Animal>[];
    final animalById = {for (final a in animals) a.id: a};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
        actions: [
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.newest, child: Text('Newest')),
              PopupMenuItem(value: _Sort.rarest, child: Text('Rarest')),
              PopupMenuItem(value: _Sort.bestSerial, child: Text('Best serial')),
            ],
          ),
        ],
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(Space.xl),
            children: [Text("Couldn't load your collection. Pull down to try again.", textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: c.inkMuted))],
          ),
        ),
        data: (cards) {
          final filtered = cards.where(_passes).toList();
          final byAnimal = <String, List<PugCard>>{};
          for (final card in filtered) {
            byAnimal.putIfAbsent(card.animalId, () => []).add(card);
          }
          final entries = byAnimal.entries.map((e) {
            final list = e.value..sort((a, b) => a.serialNo.compareTo(b.serialNo));
            final newest = list.map((x) => x.issuedAt).reduce((a, b) => a.isAfter(b) ? a : b);
            return _Entry(
              animalId: e.key,
              family: list.first.family,
              best: list.first,
              count: list.length,
              newest: newest,
              sortOrder: animalById[e.key]?.sortOrder ?? 100,
            );
          }).toList()
            ..sort(_compare);

          final ownedIds = cards.map((x) => x.animalId).toSet();
          final unseen = _filter == _Filter.all ? animals.where((a) => !a.isSecret && !ownedIds.contains(a.id)).toList() : const <Animal>[];

          final families = <String>{...entries.map((e) => e.family), ...unseen.map((a) => a.family)}.toList()
            ..sort((a, b) {
              final ia = _familyOrder.indexOf(a), ib = _familyOrder.indexOf(b);
              return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
            });

          var tileIndex = 0;
          final slivers = <Widget>[
            SliverToBoxAdapter(child: _filterChips()),
            if (cards.isEmpty) SliverToBoxAdapter(child: _emptyHero(context)),
            if (cards.isNotEmpty && entries.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
                  child: Text('Nothing in this set yet. Keep running — the bag is deep.', style: tt.bodyMedium?.copyWith(color: c.inkMuted)),
                ),
              ),
          ];

          for (final fam in families) {
            final owned = entries.where((e) => e.family == fam).toList();
            final hidden = unseen.where((a) => a.family == fam).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            if (owned.isEmpty && hidden.isEmpty) continue;
            slivers.add(SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.md),
                child: Row(
                  children: [
                    Text(_familyLabel(fam), style: tt.headlineSmall),
                    const SizedBox(width: Space.sm),
                    Text('${owned.length} of ${owned.length + hidden.length}', style: tt.labelMedium?.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
            ));
            final tiles = <Widget>[
              for (final e in owned) OwnedAnimalTile(best: e.best, count: e.count, onTap: () => _open(e.best)),
              for (final a in hidden) UnknownAnimalTile(palette: a.palette),
            ];
            slivers.add(SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: kCollectionTileWidth + Space.lg,
                  mainAxisExtent: kCollectionTileWidth * 7 / 5 + Space.sm,
                  crossAxisSpacing: Space.md,
                  mainAxisSpacing: Space.md,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final delay = math.min(40 * (tileIndex++), 320);
                    return Center(
                      child: tiles[i].animate(delay: Duration(milliseconds: delay)).fadeIn(duration: const Duration(milliseconds: 220)),
                    );
                  },
                  childCount: tiles.length,
                ),
              ),
            ));
          }
          slivers.add(const SliverToBoxAdapter(child: SizedBox(height: Space.xxxl)));

          return RefreshIndicator(onRefresh: _refresh, child: CustomScrollView(slivers: slivers));
        },
      ),
    );
  }

  Widget _filterChips() {
    const labels = {_Filter.all: 'All', _Filter.run: 'Run', _Filter.weekly: 'Weekly', _Filter.monthly: 'Monthly', _Filter.rarePlus: 'Rare+'};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, 0),
      child: Row(
        children: [
          for (final f in _Filter.values) ...[
            ChoiceChip(
              label: Text(labels[f]!),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
            const SizedBox(width: Space.sm),
          ],
        ],
      ),
    );
  }

  Widget _emptyHero(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xxl, Space.xl, Space.sm),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: c.line)),
            child: Icon(Icons.shopping_bag_outlined, size: 40, color: c.inkMuted),
          ),
          const SizedBox(height: Space.lg),
          Text('Your first run opens the bag.', style: tt.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: Space.xs),
          Text('Every animal below is out there, waiting.', style: tt.bodyMedium?.copyWith(color: c.inkMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static String _familyLabel(String f) => f.isEmpty ? 'Other' : '${f[0].toUpperCase()}${f.substring(1)}';
}
