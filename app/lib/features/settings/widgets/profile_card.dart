import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/repos/repos.dart';
import '../../../core/theme/tokens.dart';

/// Display name, home region, optional birth year / sex (DESIGN.md §7 "You").
class ProfileCard extends ConsumerStatefulWidget {
  const ProfileCard({super.key, required this.profile});
  final Profile profile;

  @override
  ConsumerState<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<ProfileCard> {
  bool _saving = false;

  Future<void> _patch(Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).updateProfile(patch);
      ref.invalidate(profileProvider);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('We couldn\'t save that right now. Try again in a moment.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: widget.profile.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'How the verify page names you'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty && trimmed != widget.profile.displayName) await _patch({'display_name': trimmed});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final text = Theme.of(context).textTheme;
    final p = widget.profile;
    final regions = ref.watch(regionsProvider).valueOrNull ?? const <Map<String, dynamic>>[];
    final regionCodes = regions.map((r) => r['code'] as String).toSet();
    final thisYear = DateTime.now().year;
    final years = [for (var y = thisYear - 10; y >= thisYear - 95; y--) y];

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: c.accent.withValues(alpha: 0.15),
            child: Text(p.displayName.isEmpty ? '?' : p.displayName[0].toUpperCase(), style: text.titleLarge?.copyWith(color: c.accent)),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.displayName, style: text.titleMedium),
              Text('Shown on your cards\' verify pages', style: text.labelSmall?.copyWith(color: c.inkMuted)),
            ]),
          ),
          IconButton(onPressed: _saving ? null : _editName, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit name'),
        ]),
        const SizedBox(height: Space.lg),
        DropdownButtonFormField<String?>(
          value: regionCodes.contains(p.homeRegion) ? p.homeRegion : null,
          decoration: const InputDecoration(labelText: 'Home region', helperText: 'Where you live is home, not a souvenir.'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Let my first run decide')),
            for (final r in regions) DropdownMenuItem<String?>(value: r['code'] as String, child: Text(r['name'] as String)),
          ],
          onChanged: _saving ? null : (v) => _patch({'home_region': v}),
        ),
        const SizedBox(height: Space.lg),
        Text('Fairness (optional)', style: text.titleSmall),
        Text('Used to grade effort fairly. Never shown.', style: text.bodySmall?.copyWith(color: c.inkMuted)),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<int?>(
          value: p.birthYear,
          decoration: const InputDecoration(labelText: 'Birth year'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Prefer not to say')),
            for (final y in years) DropdownMenuItem<int?>(value: y, child: Text('$y')),
          ],
          onChanged: _saving ? null : (v) => _patch({'birth_year': v}),
        ),
        const SizedBox(height: Space.md),
        SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'female', label: Text('Female')),
            ButtonSegment(value: 'male', label: Text('Male')),
          ],
          selected: p.sex == null ? const <String>{} : {p.sex!},
          onSelectionChanged: _saving ? null : (s) => _patch({'sex': s.isEmpty ? null : s.first}),
        ),
      ]),
    );
  }
}
