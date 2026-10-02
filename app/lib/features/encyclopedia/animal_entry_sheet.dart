import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../card/widgets/animal_art.dart';

/// One encyclopedia entry: adult art, facts, habitat, superpower, India note,
/// and how often you (and everyone) have met it.
class AnimalEntrySheet extends StatelessWidget {
  const AnimalEntrySheet({super.key, required this.animal, required this.earnedCount, required this.issuedSoFar, this.scrollController});

  final Animal animal;
  final int earnedCount;
  final int? issuedSoFar;
  final ScrollController? scrollController;

  static Future<void> show(BuildContext context, {required Animal animal, required int earnedCount, int? issuedSoFar}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) => AnimalEntrySheet(animal: animal, earnedCount: earnedCount, issuedSoFar: issuedSoFar, scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tt = Theme.of(context).textTheme;
    final a = animal;
    final facts = a.facts;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.xxxl),
      children: [
        Center(
          child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: Space.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.card),
          child: Container(
            color: a.palette.bg,
            child: AspectRatio(
              aspectRatio: 1.25,
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: AnimalArt(slug: a.slug, name: a.name, family: a.family, stage: Stage.adult, path: a.artPath(Stage.adult), palette: a.palette),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(a.name, style: tt.headlineMedium)),
            const SizedBox(width: Space.sm),
            _Pill(text: a.rarity.label, color: a.palette.accent),
          ],
        ),
        if (a.flavourLine.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          Text(a.flavourLine, style: AppText.flavour(context)),
        ],
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            _Pill(text: _familyLabel(a.family), color: c.inkMuted),
            if (earnedCount > 0) _Pill(text: earnedCount == 1 ? 'Earned once' : 'Earned $earnedCount times', color: c.success),
            if (issuedSoFar != null) _Pill(text: '$issuedSoFar issued so far', color: c.inkMuted),
          ],
        ),
        if (a.superpower != null && a.superpower!.isNotEmpty) _Section(title: 'Superpower', child: Text(a.superpower!, style: tt.bodyMedium)),
        if (facts.isNotEmpty)
          _Section(
            title: 'Facts',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in facts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 9), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: a.palette.accent, shape: BoxShape.circle))),
                        const SizedBox(width: Space.md),
                        Expanded(child: Text(f, style: tt.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (a.habitat != null && a.habitat!.isNotEmpty) _Section(title: 'Habitat', child: Text(a.habitat!, style: tt.bodyMedium)),
        if (a.size != null && a.size!.isNotEmpty) _Section(title: 'Size', child: Text(a.size!, style: tt.bodyMedium)),
        if (a.indiaNote != null && a.indiaNote!.isNotEmpty) _Section(title: 'In India', child: Text(a.indiaNote!, style: tt.bodyMedium)),
        if (earnedCount == 0) ...[
          const SizedBox(height: Space.xl),
          Text('Not in your collection yet. Keep running — it is out there.', style: tt.bodySmall?.copyWith(color: c.inkMuted)),
        ],
      ],
    );
  }

  static String _familyLabel(String f) => f.isEmpty ? 'Other' : '${f[0].toUpperCase()}${f.substring(1)}';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: tt.labelMedium?.copyWith(color: c.inkMuted)),
          const SizedBox(height: Space.sm),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.chip), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
    );
  }
}
