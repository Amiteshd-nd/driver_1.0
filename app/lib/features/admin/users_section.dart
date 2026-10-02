/// Users (support view): profiles sorted by created_at, admin toggle, connected purposes. No deletion here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';

class UsersSection extends ConsumerStatefulWidget {
  const UsersSection({super.key});
  @override
  ConsumerState<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends ConsumerState<UsersSection> {
  final _search = TextEditingController();
  final Set<String> _busy = {};
  bool _adminsOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(adminUsersProvider);

  Future<void> _toggleAdmin(AdminUser u, bool v) async {
    final me = ref.read(profileProvider).valueOrNull;
    if (me != null && me.id == u.profile.id && !v) {
      showErr(context, 'You cannot remove your own admin access from here.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: v ? 'Make ${u.profile.displayName} an admin?' : 'Remove admin from ${u.profile.displayName}?',
      body: v ? 'They will be able to edit every animal, rule and config value.' : 'They keep playing as a normal runner.',
      confirm: v ? 'Make admin' : 'Remove',
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(u.profile.id));
    try {
      await ref.read(adminRepoProvider).setUserAdmin(u.profile.id, v);
      if (mounted) showOk(context, '${u.profile.displayName} ${v ? 'is now an admin' : 'is no longer an admin'}');
      _refresh();
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(u.profile.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final users = ref.watch(adminUsersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Users',
          subtitle: 'Support view. Age and sex are never shown. Accounts are deleted by the runner themselves, not here.',
          actions: [IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh))],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Wrap(
            spacing: Space.md,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(controller: _search, decoration: denseInput('Filter by name or id').copyWith(prefixIcon: const Icon(Icons.search, size: 18)), onChanged: (_) => setState(() {})),
              ),
              FilterChip(label: const Text('Admins only'), selected: _adminsOnly, onSelected: (v) => setState(() => _adminsOnly = v)),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: AsyncBody<List<AdminUser>>(
            value: users,
            onRetry: _refresh,
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No runners yet.',
            builder: (all) {
              final q = _search.text.trim().toLowerCase();
              final rows = all.where((u) {
                if (_adminsOnly && !u.profile.isAdmin) return false;
                return q.isEmpty || u.profile.displayName.toLowerCase().contains(q) || u.profile.id.startsWith(q);
              }).toList();
              if (rows.isEmpty) return Center(child: Text('No runners match.', style: t.bodyMedium?.copyWith(color: c.inkMuted)));
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
                          DataColumn(label: Text('Display name')),
                          DataColumn(label: Text('Id')),
                          DataColumn(label: Text('Joined')),
                          DataColumn(label: Text('Last run')),
                          DataColumn(label: Text('Home')),
                          DataColumn(label: Text('Connected')),
                          DataColumn(label: Text('Admin')),
                        ],
                        rows: [
                          for (final u in rows)
                            DataRow(cells: [
                              DataCell(Text(u.profile.displayName)),
                              DataCell(Tooltip(message: u.profile.id, child: Text(shortUuid(u.profile.id), style: monoStyle(context, size: 12, color: c.inkMuted)))),
                              DataCell(Text(fmtDate(u.createdAt), style: t.bodySmall)),
                              DataCell(Text(u.profile.lastRunAt == null ? '—' : fmtDate(u.profile.lastRunAt!), style: t.bodySmall?.copyWith(color: u.profile.lastRunAt == null ? c.inkMuted : null))),
                              DataCell(Text(u.profile.homeRegion ?? '—', style: monoStyle(context, size: 12))),
                              DataCell(
                                Wrap(
                                  spacing: Space.xs,
                                  children: [
                                    if (u.profile.connected.isEmpty) Text('none', style: t.labelSmall?.copyWith(color: c.inkMuted)),
                                    for (final p in kConnected)
                                      if (u.profile.connected.contains(p)) TagPill(p, color: c.success),
                                  ],
                                ),
                              ),
                              DataCell(
                                _busy.contains(u.profile.id)
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Switch(value: u.profile.isAdmin, onChanged: (v) => _toggleAdmin(u, v)),
                              ),
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
