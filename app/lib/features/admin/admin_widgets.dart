/// Small shared building blocks for the admin sections (DESIGN.md §11: dense, keyboard-friendly).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';

/// The 11 animal families (`animals.family`; DESIGN.md §3.2 — `time` covers both dawn and night bags).
const kFamilies = ['swift', 'steady', 'calm', 'gentle', 'time', 'explorer', 'regional', 'migratory', 'weekly', 'secret', 'national'];
const kSpeedBands = ['swift', 'steady', 'calm', 'gentle'];
const kTimeWindows = ['dawn', 'day', 'dusk', 'night'];
const kRunFlags = ['new_route', 'untraced', 'zigzag', 'new_area', 'explorer', 'new_state', 'migratory_2', 'migratory_3'];
const kConnected = ['location', 'motion', 'steps', 'heart_rate', 'activity', 'elevation'];

const kRunTierLabels = {0: '0 · speed', 1: '1 · time of day', 2: '2 · explorer', 3: '3 · state souvenir', 4: '4 · migratory'};
const kWeeklyTiers = [3, 5, 7];

// ---------- feedback ----------
void showOk(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showErr(BuildContext context, Object error) {
  if (!context.mounted) return;
  final c = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(backgroundColor: c.danger, content: Text(friendlyError(error))));
}

String friendlyError(Object e) {
  final s = e.toString();
  return s.length > 240 ? '${s.substring(0, 240)}…' : s;
}

String shortUuid(String? id) => id == null || id.isEmpty ? '—' : (id.length > 8 ? id.substring(0, 8) : id);

String fmtWhen(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0'), mm = d.minute.toString().padLeft(2, '0');
  return '${fmtDate(d)} $hh:$mm';
}

String fmtDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String prettyJson(dynamic v) => const JsonEncoder.withIndent('  ').convert(v);

TextStyle monoStyle(BuildContext context, {double size = 13, Color? color}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, height: 1.45, color: color ?? context.colors.ink);

// ---------- async states ----------
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.isEmpty,
    this.emptyText = 'Nothing here yet.',
  });
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return value.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(Space.xxl), child: CircularProgressIndicator())),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, color: c.danger),
              const SizedBox(height: Space.sm),
              Text(friendlyError(e), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkMuted)),
              if (onRetry != null) ...[
                const SizedBox(height: Space.md),
                OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
      data: (d) {
        if (isEmpty != null && isEmpty!(d)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Text(emptyText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.inkMuted)),
            ),
          );
        }
        return builder(d);
      },
    );
  }
}

// ---------- layout ----------
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.headlineMedium),
                if (subtitle != null) Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text(subtitle!, style: t.bodySmall?.copyWith(color: c.inkMuted))),
              ],
            ),
          ),
          Wrap(spacing: Space.sm, children: actions),
        ],
      ),
    );
  }
}

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.lg)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

/// Label above a control, dense.
class Field extends StatelessWidget {
  const Field({super.key, required this.label, required this.child, this.hint});
  final String label;
  final String? hint;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.labelMedium?.copyWith(color: c.inkMuted)),
        const SizedBox(height: Space.xs),
        child,
        if (hint != null) Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text(hint!, style: t.labelSmall?.copyWith(color: c.inkMuted))),
      ],
    );
  }
}

InputDecoration denseInput([String? hint]) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
    );

// ---------- chips ----------
class ChipGroup extends StatelessWidget {
  const ChipGroup({super.key, required this.values, required this.selected, required this.onChanged, this.labels = const {}});
  final List<String> values;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.xs,
      children: [
        for (final v in values)
          FilterChip(
            label: Text(labels[v] ?? v),
            selected: selected.contains(v),
            visualDensity: VisualDensity.compact,
            onSelected: (on) {
              final next = Set<String>.from(selected);
              on ? next.add(v) : next.remove(v);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class RarityPill extends StatelessWidget {
  const RarityPill(this.rarity, {super.key});
  final Rarity rarity;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (rarity) {
      Rarity.common => c.inkMuted,
      Rarity.uncommon => c.success,
      Rarity.rare => c.accent,
      Rarity.epic => c.warn,
      Rarity.legendary => c.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(rarity.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}

class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = color ?? c.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.chip)),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: col)),
    );
  }
}

// ---------- hex colour field ----------
class HexField extends StatelessWidget {
  const HexField({super.key, required this.label, required this.controller, required this.onChanged});
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  static Color? parse(String hex) {
    final h = hex.trim().replaceFirst('#', '');
    if (h.length != 6 && h.length != 8) return null;
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v == null ? null : Color(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = parse(controller.text);
    return Field(
      label: label,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color ?? c.surfaceAlt, borderRadius: BorderRadius.circular(Space.sm), border: Border.all(color: c.line)),
            child: color == null ? Icon(Icons.question_mark, size: 16, color: c.inkMuted) : null,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: denseInput('#RRGGBB'),
              style: monoStyle(context),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only JSON block.
class JsonBlock extends StatelessWidget {
  const JsonBlock(this.value, {super.key});
  final dynamic value;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.control), border: Border.all(color: c.line)),
      child: SelectableText(prettyJson(value), style: monoStyle(context, size: 12)),
    );
  }
}

/// Procedural art placeholder (DESIGN.md §5): palette accent circle + initial, or the real art when present.
class ArtThumb extends StatelessWidget {
  const ArtThumb({super.key, required this.animal, this.url, this.size = 36});
  final Animal animal;
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = animal.palette;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle, border: Border.all(color: p.accent, width: 2)),
      alignment: Alignment.center,
      child: Text(animal.name.isEmpty ? '?' : animal.name.substring(0, 1).toUpperCase(),
          style: GoogleFonts.fraunces(fontSize: size * 0.45, fontWeight: FontWeight.w600, color: p.fg)),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

/// Confirm dialog; returns true on confirm.
Future<bool> confirmDialog(BuildContext context, {required String title, required String body, String confirm = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}
