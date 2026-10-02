/// Admin panel shell: login gate (profiles.is_admin), left nav rail / drawer, section switching (DESIGN.md §11).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repos/repos.dart';
import '../../core/theme/tokens.dart';
import 'age_factors_section.dart';
import 'animals_section.dart';
import 'config_section.dart';
import 'history_section.dart';
import 'illustrations_section.dart';
import 'regions_section.dart';
import 'rules_section.dart';
import 'seasons_section.dart';
import 'simulator_section.dart';
import 'users_section.dart';

enum AdminSection {
  animals('animals', 'Animals', Icons.pets_outlined, Icons.pets),
  illustrations('illustrations', 'Illustrations', Icons.brush_outlined, Icons.brush),
  rules('rules', 'Rules', Icons.rule_outlined, Icons.rule),
  config('config', 'Config', Icons.tune_outlined, Icons.tune),
  seasons('seasons', 'Seasons', Icons.calendar_month_outlined, Icons.calendar_month),
  regions('regions', 'Regions', Icons.map_outlined, Icons.map),
  ageFactors('age-factors', 'Age factors', Icons.timeline_outlined, Icons.timeline),
  simulator('simulator', 'Simulator', Icons.science_outlined, Icons.science),
  users('users', 'Users', Icons.people_outline, Icons.people),
  history('history', 'History', Icons.history_outlined, Icons.history);

  const AdminSection(this.slug, this.label, this.icon, this.selectedIcon);
  final String slug, label;
  final IconData icon, selectedIcon;

  static AdminSection fromSlug(String? s) =>
      AdminSection.values.firstWhere((v) => v.slug == s || v.name == s, orElse: () => AdminSection.animals);
}

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, this.section});
  final String? section;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  late AdminSection _section = AdminSection.fromSlug(widget.section);

  @override
  void didUpdateWidget(covariant AdminShell old) {
    super.didUpdateWidget(old);
    if (old.section != widget.section) _section = AdminSection.fromSlug(widget.section);
  }

  void _select(AdminSection s) {
    setState(() => _section = s);
    // Keep the URL in sync so the section survives reload / deep-linking.
    context.go('/admin?s=${s.slug}');
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return profile.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => _Gate(
        title: 'Could not load your profile',
        body: e.toString(),
        onBack: _back,
        onRetry: () => ref.invalidate(profileProvider),
      ),
      data: (p) {
        if (p == null || !p.isAdmin) {
          return _Gate(
            title: 'Admin only',
            body: 'This area is for the Flying Cobra design team. Your runs and cards are untouched — head back whenever you like.',
            onBack: _back,
          );
        }
        return _AdminScaffold(section: _section, onSelect: _select, onBack: _back);
      },
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.title, required this.body, required this.onBack, this.onRetry});
  final String title, body;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 40, color: c.inkMuted),
                const SizedBox(height: Space.lg),
                Text(title, style: t.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: Space.sm),
                Text(body, style: t.bodyMedium?.copyWith(color: c.inkMuted), textAlign: TextAlign.center),
                const SizedBox(height: Space.xl),
                Wrap(
                  spacing: Space.sm,
                  children: [
                    FilledButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('Back')),
                    if (onRetry != null) OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminScaffold extends StatelessWidget {
  const _AdminScaffold({required this.section, required this.onSelect, required this.onBack});
  final AdminSection section;
  final ValueChanged<AdminSection> onSelect;
  final VoidCallback onBack;

  Widget _body() => switch (section) {
        AdminSection.animals => const AnimalsSection(),
        AdminSection.illustrations => const IllustrationsSection(),
        AdminSection.rules => const RulesSection(),
        AdminSection.config => const ConfigSection(),
        AdminSection.seasons => const SeasonsSection(),
        AdminSection.regions => const RegionsSection(),
        AdminSection.ageFactors => const AgeFactorsSection(),
        AdminSection.simulator => const SimulatorSection(),
        AdminSection.users => const UsersSection(),
        AdminSection.history => const HistorySection(),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = KeyedSubtree(key: ValueKey(section), child: _body());

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: c.surface,
              selectedIndex: section.index,
              onDestinationSelected: (i) => onSelect(AdminSection.values[i]),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: Space.sm, bottom: Space.md),
                child: IconButton(tooltip: 'Back to app', onPressed: onBack, icon: const Icon(Icons.arrow_back)),
              ),
              destinations: [
                for (final s in AdminSection.values)
                  NavigationRailDestination(icon: Icon(s.icon), selectedIcon: Icon(s.selectedIcon), label: Text(s.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin · ${section.label}'),
        leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
        actions: [IconButton(tooltip: 'Back to app', onPressed: onBack, icon: const Icon(Icons.close))],
      ),
      drawer: Drawer(
        backgroundColor: c.surface,
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
                child: Text('Flying Cobra admin', style: Theme.of(context).textTheme.headlineSmall),
              ),
              for (final s in AdminSection.values)
                ListTile(
                  dense: true,
                  leading: Icon(s == section ? s.selectedIcon : s.icon),
                  title: Text(s.label),
                  selected: s == section,
                  selectedTileColor: c.accent.withValues(alpha: 0.12),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(s);
                  },
                ),
            ],
          ),
        ),
      ),
      body: body,
    );
  }
}
