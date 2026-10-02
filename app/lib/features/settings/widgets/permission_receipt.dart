import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/models.dart';
import '../../../core/repos/repos.dart';
import '../../../core/theme/tokens.dart';
import '../../onboarding/onboarding_flow.dart' show kNotificationsPrefKey;
import '../../run/permissions.dart';

/// "Permissions as a receipt": one row per purpose, status from `profiles.connected` AND the live OS state,
/// plain-language why, what you lose, a toggle. Off removes the purpose immediately; on asks the OS.
class PermissionReceipt extends ConsumerStatefulWidget {
  const PermissionReceipt({super.key, required this.profile});
  final Profile profile;

  @override
  ConsumerState<PermissionReceipt> createState() => _PermissionReceiptState();
}

class _PermissionReceiptState extends ConsumerState<PermissionReceipt> with WidgetsBindingObserver {
  final Map<Purpose, PurposeStatus> _os = {};
  bool _notifPref = false;
  Purpose? _busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final p in Purpose.values) {
      final s = await PermissionCenter.status(p);
      if (mounted) setState(() => _os[p] = s);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _notifPref = prefs.getBool(kNotificationsPrefKey) ?? false);
    } catch (_) {}
  }

  bool _isOn(Purpose p) {
    if (p == Purpose.notifications) return _notifPref && (_os[p] == null || PermissionCenter.usable(_os[p]!) || _os[p] == PurposeStatus.unavailable);
    final recorded = p.connectedKeys.every(widget.profile.connected.contains);
    final os = _os[p];
    if (os == null || os == PurposeStatus.unknown) return recorded;
    return recorded && PermissionCenter.usable(os);
  }

  Future<void> _toggle(Purpose p, bool on) async {
    if (_busy != null) return;
    setState(() => _busy = p);
    try {
      if (p == Purpose.notifications) {
        var granted = true;
        if (on) granted = await PermissionCenter.request(p);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(kNotificationsPrefKey, on && granted);
        if (on && !granted && mounted) _explainDenied(p);
        if (mounted) setState(() => _notifPref = on && granted);
      } else {
        final current = widget.profile.connected.toSet();
        if (on) {
          final granted = await PermissionCenter.request(p);
          if (granted) {
            current.addAll(p.connectedKeys);
          } else if (mounted) {
            _explainDenied(p);
          }
        } else {
          current.removeAll(p.connectedKeys);
        }
        await ref.read(apiProvider).updateProfile({'connected': current.toList()});
        ref.invalidate(profileProvider);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('We couldn\'t update that right now. Try again in a moment.')));
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _explainDenied(Purpose p) async {
    final s = await PermissionCenter.status(p);
    if (!mounted) return;
    final msg = s == PurposeStatus.permanentlyDenied
        ? 'Your phone remembers an earlier "no". Turn it on in phone settings when you\'re ready.'
        : s == PurposeStatus.unavailable
            ? 'Not available on this device.'
            : 'No change made. You can allow it any time.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      action: s == PurposeStatus.permanentlyDenied ? SnackBarAction(label: 'Settings', onPressed: PermissionCenter.openSettings) : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final dataPurposes = Purpose.values.where((p) => p != Purpose.notifications);
    final fully = dataPurposes.every(_isOn);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Permissions', style: text.headlineSmall),
      const SizedBox(height: Space.xs),
      Text('A receipt of what this app may read, and what each one is for. Switching something off takes effect immediately.',
          style: text.bodySmall?.copyWith(color: c.inkMuted)),
      const SizedBox(height: Space.md),
      Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
        child: Column(children: [
          for (final p in Purpose.values) ...[
            _Row(
              purpose: p,
              on: _isOn(p),
              osStatus: _os[p],
              busy: _busy == p,
              onChanged: (v) => _toggle(p, v),
              onBackground: p == Purpose.location && _os[p] == PurposeStatus.limited
                  ? () async {
                      await PermissionCenter.requestBackgroundLocation();
                      await _refresh();
                    }
                  : null,
            ),
            if (p != Purpose.values.last) Divider(color: c.line, height: 1),
          ],
        ]),
      ),
      const SizedBox(height: Space.md),
      _FullyConnected(fully: fully),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.purpose, required this.on, required this.osStatus, required this.busy, required this.onChanged, this.onBackground});
  final Purpose purpose;
  final bool on, busy;
  final PurposeStatus? osStatus;
  final ValueChanged<bool> onChanged;
  final Future<void> Function()? onBackground;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final String status;
    if (on) {
      status = PermissionCenter.describe(osStatus ?? PurposeStatus.granted);
    } else if (osStatus == PurposeStatus.unavailable) {
      status = PermissionCenter.describe(PurposeStatus.unavailable);
    } else {
      status = 'Off';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(purpose.title, style: text.titleSmall)),
              Text(status, style: text.labelSmall?.copyWith(color: on ? c.success : c.inkMuted)),
            ]),
            const SizedBox(height: 2),
            Text('Why: ${purpose.why}.', style: text.bodySmall?.copyWith(color: c.inkMuted)),
            const SizedBox(height: 2),
            Text(on ? 'We keep ${purpose.store}.' : purpose.lose, style: text.bodySmall?.copyWith(color: c.inkMuted)),
            if (onBackground != null)
              TextButton(
                onPressed: onBackground,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerLeft),
                child: const Text('Allow in the background, so a run keeps recording with the screen off'),
              ),
          ]),
        ),
        const SizedBox(width: Space.sm),
        busy
            ? const Padding(padding: EdgeInsets.all(Space.md), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : Switch(value: on, onChanged: osStatus == PurposeStatus.unavailable && purpose != Purpose.notifications ? null : onChanged),
      ]),
    );
  }
}

/// Mentions the reward once, gently, without naming it (DESIGN.md §8 rules).
class _FullyConnected extends StatelessWidget {
  const _FullyConnected({required this.fully});
  final bool fully;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: fully ? c.success.withValues(alpha: 0.08) : c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: fully ? c.success.withValues(alpha: 0.4) : c.line),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: fully ? c.success.withValues(alpha: 0.15) : c.ink.withValues(alpha: 0.85), shape: BoxShape.circle),
          child: fully
              ? Icon(Icons.verified_outlined, color: c.success)
              : Stack(alignment: Alignment.center, children: [
                  Icon(Icons.pets, color: c.bg.withValues(alpha: 0.25), size: 26),
                  Icon(Icons.lock_outline, color: c.bg, size: 16),
                ]),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fully ? 'Fully connected' : 'Something waits for a fully connected runner', style: text.titleSmall),
            Text(
              fully
                  ? 'Thank you for trusting us with the full picture. Every kind of evidence counts on your runs.'
                  : 'When every data purpose above is on, one more animal becomes possible. No hurry; it will wait.',
              style: text.bodySmall?.copyWith(color: c.inkMuted),
            ),
          ]),
        ),
      ]),
    );
  }
}
