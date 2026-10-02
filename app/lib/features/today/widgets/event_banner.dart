import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/tokens.dart';

/// Dismissible banner for an unseen `events` row (growth / mastered / welcome_back).
class EventBanner extends StatelessWidget {
  const EventBanner({super.key, required this.event, required this.onDismiss});

  final AppEvent event;
  final VoidCallback onDismiss;

  static const kinds = {'growth', 'mastered', 'welcome_back'};

  /// DESIGN.md §9 copy, preferring a server-provided message.
  static String copyFor(AppEvent e) {
    final m = e.payload['message'];
    if (m is String && m.isNotEmpty) return m;
    final animal = (e.payload['animal'] as String?)?.toLowerCase();
    switch (e.kind) {
      case 'growth':
        return animal == null ? 'One of your animals is all grown up!' : 'Your $animal is all grown up!';
      case 'mastered':
        return animal == null ? 'You and one of your animals know each other well now.' : 'You and your $animal know each other well now.';
      case 'welcome_back':
        return 'Welcome back. Your animals start small again — and so does the adventure.';
      default:
        return '';
    }
  }

  IconData get _icon => switch (event.kind) {
        'growth' => Icons.eco_outlined,
        'mastered' => Icons.auto_awesome_outlined,
        _ => Icons.waving_hand_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tt = Theme.of(context).textTheme;
    final text = copyFor(event);
    if (text.isEmpty) return const SizedBox.shrink();
    return Dismissible(
      key: ValueKey('event-${event.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss(),
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.md),
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.xs, Space.sm),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: c.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(_icon, color: c.accent),
            const SizedBox(width: Space.md),
            Expanded(child: Text(text, style: tt.bodyMedium)),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: c.inkMuted),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ],
        ),
      ),
    );
  }
}
