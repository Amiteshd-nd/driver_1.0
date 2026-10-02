import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/brand.dart';
import '../../core/repos/repos.dart';
import '../../core/router.dart';
import '../../core/theme/tokens.dart';
import '../run/permissions.dart';

/// SharedPreferences key for the local notifications preference (no server field).
const String kNotificationsPrefKey = 'notifications_enabled';

/// DESIGN.md §8: promise → permissions one at a time → optional fairness → done.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _page = PageController();
  int _index = 0;
  bool _busy = false;
  final Set<String> _granted = <String>{};
  int? _birthYear;
  String? _sex;

  static const _permissionOrder = [Purpose.location, Purpose.motion, Purpose.activity, Purpose.heartRate, Purpose.notifications];
  int get _pageCount => 1 + _permissionOrder.length + 2; // promise + permissions + fairness + done

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index >= _pageCount - 1) return;
    setState(() => _index++);
    await _page.animateToPage(_index, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  Future<void> _allow(Purpose p) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await PermissionCenter.request(p);
    if (ok) {
      _granted.addAll(p.connectedKeys);
      if (p == Purpose.notifications) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(kNotificationsPrefKey, true);
        } catch (_) {}
      }
      if (p.connectedKeys.isNotEmpty) {
        try {
          await ref.read(apiProvider).updateProfile({'connected': _granted.toList()});
        } catch (_) {}
      }
    } else if (mounted) {
      final status = await PermissionCenter.status(p);
      if (mounted && status == PurposeStatus.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(kIsWeb ? 'Not available on web. You can turn this on in the phone app.' : 'Not available on this device.')),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
    await _next();
  }

  Future<void> _saveFairness() async {
    if (_birthYear == null && _sex == null) return;
    try {
      await ref.read(apiProvider).updateProfile({'birth_year': _birthYear, 'sex': _sex});
    } catch (_) {}
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
    } catch (_) {}
    ref.invalidate(profileProvider);
    ref.read(onboardingDoneProvider.notifier).state = true;
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, 0),
              child: Row(
                children: List.generate(
                  _pageCount,
                  (i) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= _index ? c.accent : c.line,
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PromisePage(onContinue: _next),
                  for (final p in _permissionOrder)
                    _PermissionPage(purpose: p, busy: _busy, onAllow: () => _allow(p), onNotNow: _next),
                  _FairnessPage(
                    birthYear: _birthYear,
                    sex: _sex,
                    onBirthYear: (v) => setState(() => _birthYear = v),
                    onSex: (v) => setState(() => _sex = v),
                    onContinue: () async {
                      await _saveFairness();
                      await _next();
                    },
                    onSkip: _next,
                  ),
                  _DonePage(busy: _busy, onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

class _PromisePage extends StatelessWidget {
  const _PromisePage({required this.onContinue});
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return _Frame(children: [
      Icon(Icons.pets, size: 72, color: c.accent),
      const SizedBox(height: Space.xl),
      Text(Brand.promise, style: text.displayLarge),
      const SizedBox(height: Space.lg),
      Text(
        'Every run earns an animal card with its own serial number. Consistency grows your animals. Exploring finds new ones.',
        style: text.bodyLarge?.copyWith(color: c.inkMuted),
      ),
      const SizedBox(height: Space.sm),
      Text(
        'Next, a few questions about what the app may read. Each one is yours to decide; the app works with Location alone.',
        style: text.bodyMedium?.copyWith(color: c.inkMuted),
      ),
      const SizedBox(height: Space.xxl),
      FilledButton(onPressed: onContinue, child: const Text('Continue')),
    ]);
  }
}

class _PermissionPage extends StatelessWidget {
  const _PermissionPage({required this.purpose, required this.busy, required this.onAllow, required this.onNotNow});
  final Purpose purpose;
  final bool busy;
  final VoidCallback onAllow, onNotNow;

  IconData get _icon => switch (purpose) {
        Purpose.location => Icons.place_outlined,
        Purpose.motion => Icons.directions_walk,
        Purpose.activity => Icons.directions_run,
        Purpose.heartRate => Icons.favorite_outline,
        Purpose.notifications => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return _Frame(children: [
      Container(
        padding: const EdgeInsets.all(Space.xl),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.sheet),
          border: Border.all(color: c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_icon, size: 44, color: c.accent),
          const SizedBox(height: Space.lg),
          Text(purpose.title, style: text.headlineMedium),
          const SizedBox(height: Space.lg),
          _Row(label: 'Why', value: 'We ask ${purpose.why}.'),
          const SizedBox(height: Space.md),
          _Row(label: 'What we store', value: '${purpose.store[0].toUpperCase()}${purpose.store.substring(1)}.'),
          const SizedBox(height: Space.md),
          _Row(label: 'If you skip', value: purpose.lose),
          if (kIsWeb && purpose != Purpose.location) ...[
            const SizedBox(height: Space.md),
            Text('Not available on web.', style: text.labelMedium?.copyWith(color: c.warn)),
          ],
        ]),
      ),
      const SizedBox(height: Space.xl),
      // Equal weight by rule: same size, same style family.
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: busy ? null : onNotNow, child: const Text('Not now'))),
        const SizedBox(width: Space.md),
        Expanded(
          child: OutlinedButton(
            onPressed: busy ? null : onAllow,
            style: OutlinedButton.styleFrom(side: BorderSide(color: c.accent, width: 1.5), foregroundColor: c.accent),
            child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Allow'),
          ),
        ),
      ]),
      const SizedBox(height: Space.md),
      Text('You can change this any time under You → Permissions.', textAlign: TextAlign.center, style: text.labelSmall?.copyWith(color: c.inkMuted)),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: text.labelSmall?.copyWith(color: c.inkMuted)),
      const SizedBox(height: 2),
      Text(value, style: text.bodyMedium),
    ]);
  }
}

class _FairnessPage extends StatefulWidget {
  const _FairnessPage({
    required this.birthYear,
    required this.sex,
    required this.onBirthYear,
    required this.onSex,
    required this.onContinue,
    required this.onSkip,
  });
  final int? birthYear;
  final String? sex;
  final ValueChanged<int?> onBirthYear;
  final ValueChanged<String?> onSex;
  final VoidCallback onContinue, onSkip;

  @override
  State<_FairnessPage> createState() => _FairnessPageState();
}

class _FairnessPageState extends State<_FairnessPage> {
  bool _why = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final thisYear = DateTime.now().year;
    final years = [for (var y = thisYear - 10; y >= thisYear - 95; y--) y];
    final filled = widget.birthYear != null || widget.sex != null;
    return _Frame(children: [
      Icon(Icons.balance, size: 44, color: c.accent),
      const SizedBox(height: Space.lg),
      Text('Grade effort fairly?', style: text.headlineMedium),
      const SizedBox(height: Space.sm),
      Text('Optional. Used to grade effort fairly. Never shown to anyone.', style: text.bodyMedium?.copyWith(color: c.inkMuted)),
      const SizedBox(height: Space.sm),
      TextButton.icon(
        onPressed: () => setState(() => _why = !_why),
        icon: Icon(_why ? Icons.expand_less : Icons.expand_more, size: 18),
        label: const Text('Why?'),
        style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
      ),
      if (_why)
        Text(
          'A 7-minute kilometre at 62 is a different achievement from the same pace at 24. Age-grading uses standard tables so a strong effort earns a strong animal at every age. We keep birth year, never a full date.',
          style: text.bodySmall?.copyWith(color: c.inkMuted),
        ),
      const SizedBox(height: Space.xl),
      DropdownButtonFormField<int?>(
        value: widget.birthYear,
        decoration: const InputDecoration(labelText: 'Birth year'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Prefer not to say')),
          for (final y in years) DropdownMenuItem<int?>(value: y, child: Text('$y')),
        ],
        onChanged: widget.onBirthYear,
      ),
      const SizedBox(height: Space.lg),
      Text('Sex', style: text.labelMedium?.copyWith(color: c.inkMuted)),
      const SizedBox(height: Space.sm),
      SegmentedButton<String>(
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'female', label: Text('Female')),
          ButtonSegment(value: 'male', label: Text('Male')),
        ],
        selected: widget.sex == null ? const <String>{} : {widget.sex!},
        onSelectionChanged: (s) => widget.onSex(s.isEmpty ? null : s.first),
      ),
      const SizedBox(height: Space.xxl),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: widget.onSkip, child: const Text('Skip'))),
        const SizedBox(width: Space.md),
        Expanded(child: OutlinedButton(
          onPressed: filled ? widget.onContinue : widget.onSkip,
          style: OutlinedButton.styleFrom(side: BorderSide(color: c.accent, width: 1.5), foregroundColor: c.accent),
          child: Text(filled ? 'Save and continue' : 'Continue'),
        )),
      ]),
    ]);
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage({required this.busy, required this.onFinish});
  final bool busy;
  final VoidCallback onFinish;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return _Frame(children: [
      Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: c.line)),
          child: Icon(Icons.shopping_bag_outlined, size: 64, color: c.accent),
        ),
      ),
      const SizedBox(height: Space.xl),
      Text('Your first run opens the bag.', textAlign: TextAlign.center, style: text.displayMedium),
      const SizedBox(height: Space.md),
      Text('A run of 1 km or 10 minutes earns a card. See you outside.', textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: c.inkMuted)),
      const SizedBox(height: Space.xxl),
      FilledButton(onPressed: busy ? null : onFinish, child: const Text('Let\'s go')),
    ]);
  }
}
