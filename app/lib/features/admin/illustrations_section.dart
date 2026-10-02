/// Illustrations: the pipeline ledger (DESIGN.md §11) — one tile per animal × stage × variant × style version,
/// with review actions. Only approved art reaches players; the server enforces that in `card_json`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';
import 'art_preview.dart';
import 'style_template_panel.dart';

String statusLabel(String s) => s.replaceAll('_', ' ');

Color statusColor(AppColors c, String s) => switch (s) {
      'approved' => c.success,
      'pending_review' => c.warn,
      'failed' => c.danger,
      _ => c.inkMuted,
    };

/// One-line summary of the `illustrate` Edge Function's `run` response for a snackbar.
String summariseWorker(Map<String, dynamic> w) {
  if (w['ok'] == false) return 'worker: ${w['error'] ?? 'unavailable'}';
  final parts = <String>[];
  for (final k in const ['passes', 'claimed', 'processed', 'completed', 'pending_review', 'failed', 'skipped', 'cost_cents']) {
    if (w[k] != null) parts.add('$k ${w[k]}');
  }
  if (parts.isNotEmpty) return 'worker: ${parts.join(' · ')}';
  final s = prettyJson(w).replaceAll('\n', ' ');
  return 'worker: ${s.length > 160 ? '${s.substring(0, 160)}…' : s}';
}

class IllustrationsSection extends ConsumerStatefulWidget {
  const IllustrationsSection({super.key});
  @override
  ConsumerState<IllustrationsSection> createState() => _IllustrationsSectionState();
}

class _IllustrationsSectionState extends ConsumerState<IllustrationsSection> {
  Set<String> _statuses = {};
  String? _family;
  bool _working = false;
  final Set<String> _busy = {};

  void _refresh() {
    ref.invalidate(adminIllustrationsProvider);
    ref.invalidate(adminAnimalsProvider);
    ref.invalidate(animalsProvider);
    ref.invalidate(myCardsProvider);
  }

  Future<void> _generateMissing() async {
    setState(() => _working = true);
    try {
      final repo = ref.read(adminRepoProvider);
      final n = await repo.enqueueMissing();
      final w = await repo.runWorker();
      if (mounted) showOk(context, 'Queued $n new · ${summariseWorker(w)}');
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
      _refresh();
    }
  }

  Future<void> _runWorker() async {
    setState(() => _working = true);
    try {
      final w = await ref.read(adminRepoProvider).runWorker();
      if (!mounted) return;
      if (w['ok'] == false) {
        showErr(context, w['error'] ?? 'Worker unavailable');
      } else {
        showOk(context, summariseWorker(w));
      }
    } finally {
      if (mounted) setState(() => _working = false);
      _refresh();
    }
  }

  Future<void> _review(IllustrationRow r, String decision) async {
    setState(() => _busy.add(r.id));
    try {
      await ref.read(adminRepoProvider).review(r.id, decision);
      if (mounted) showOk(context, '${r.name} · ${r.stageEnum.label.toLowerCase()} → $decision');
      _refresh();
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  List<IllustrationRow> _filter(List<IllustrationRow> all) => all.where((r) {
        if (_statuses.isNotEmpty && !_statuses.contains(r.status)) return false;
        if (_family != null && r.family != _family) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(adminIllustrationsProvider);
    final rows = lib.valueOrNull ?? const <IllustrationRow>[];
    final counts = {for (final s in IllustrationRow.statuses) s: rows.where((r) => r.status == s).length};
    final families = <String>{...kFamilies, ...rows.map((r) => r.family)}.toList();
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Illustrations',
          subtitle: 'One illustration per animal × stage × style version. Only approved art is shown on cards — the server enforces it; '
              'everything else falls back to the family placeholder.',
          actions: [
            IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
            OutlinedButton.icon(
              onPressed: _working ? null : _runWorker,
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('Run worker'),
            ),
            FilledButton.icon(
              onPressed: _working ? null : _generateMissing,
              icon: _working
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined),
              label: const Text('Generate missing'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final s in IllustrationRow.statuses)
                FilterChip(
                  label: Text('${statusLabel(s)} · ${counts[s]}'),
                  selected: _statuses.contains(s),
                  visualDensity: VisualDensity.compact,
                  selectedColor: statusColor(c, s).withValues(alpha: 0.18),
                  onSelected: (on) => setState(() {
                    final next = Set<String>.from(_statuses);
                    on ? next.add(s) : next.remove(s);
                    _statuses = next;
                  }),
                ),
              const SizedBox(width: Space.sm),
              DropdownButton<String?>(
                value: _family,
                hint: const Text('All families'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All families')),
                  for (final f in families) DropdownMenuItem<String?>(value: f, child: Text(f)),
                ],
                onChanged: (v) => setState(() => _family = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: AsyncBody<List<IllustrationRow>>(
            value: lib,
            onRetry: _refresh,
            builder: (all) {
              final filtered = _filter(all);
              return Scrollbar(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.md),
                      sliver: SliverToBoxAdapter(child: StyleTemplatePanel(onSaved: _refresh)),
                    ),
                    if (all.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(Space.xl),
                          child: Text('No illustration rows yet — press Generate missing to enqueue every active animal.',
                              textAlign: TextAlign.center, style: TextStyle(color: c.inkMuted)),
                        ),
                      )
                    else if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(Space.xl),
                          child: Text('No illustrations match that filter.', textAlign: TextAlign.center, style: TextStyle(color: c.inkMuted)),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisExtent: 392,
                            crossAxisSpacing: Space.md,
                            mainAxisSpacing: Space.md,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final r = filtered[i];
                              return _IllustrationTile(
                                key: ValueKey(r.id),
                                row: r,
                                busy: _busy.contains(r.id),
                                onReview: (d) => _review(r, d),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _IllustrationTile extends StatelessWidget {
  const _IllustrationTile({super.key, required this.row, required this.busy, required this.onReview});
  final IllustrationRow row;
  final bool busy;
  final ValueChanged<String> onReview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final col = statusColor(c, row.status);
    final inFlight = row.status == 'queued' || row.status == 'generating';
    final canApprove = !busy && !inFlight && row.hasArt && row.status != 'approved';
    final canReject = !busy && (row.status == 'pending_review' || row.status == 'approved');
    final canRegen = !busy && !inFlight;
    final notes = row.qaNotes?.trim() ?? '';
    final caption = notes.isNotEmpty ? notes : (row.lastError?.trim() ?? '');
    final providerLine = [row.provider, row.model].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final cents = row.costCents % 1 == 0 ? row.costCents.toStringAsFixed(0) : row.costCents.toStringAsFixed(1);
    final muted = t.labelSmall?.copyWith(color: c.inkMuted);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.control),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: ArtPreview(slug: row.slug, name: row.name, family: row.family, stage: row.stageEnum, path: row.bestPath),
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
            Text('${row.stageEnum.label} · ${row.variant} · v${row.styleVersion}', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            const SizedBox(height: Space.xs),
            Row(
              children: [
                TagPill(statusLabel(row.status), color: col),
                const Spacer(),
                Text('×${row.attempts} · ¢$cents', style: muted),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(providerLine.isEmpty ? '—' : providerLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            const SizedBox(height: Space.xs),
            SizedBox(
              height: 30,
              child: Text(
                caption.isEmpty ? ' ' : caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(fontSize: 11, height: 1.3, color: notes.isEmpty && caption.isNotEmpty ? c.danger : c.inkMuted),
              ),
            ),
            const Spacer(),
            if (busy)
              const Padding(padding: EdgeInsets.symmetric(vertical: Space.md), child: LinearProgressIndicator(minHeight: 2))
            else
              Wrap(
                spacing: Space.xs,
                runSpacing: 0,
                children: [
                  _MiniButton('Approve', canApprove, () => onReview('approve'), color: c.success),
                  _MiniButton('Reject', canReject, () => onReview('reject'), color: c.danger),
                  _MiniButton('Regenerate', canRegen, () => onReview('regenerate')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton(this.label, this.enabled, this.onTap, {this.color});
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
