/// Simulator: the designer's balance tool. Builds a run context → `admin_simulate_pool`; speed/distance/sex/age → `admin_perf_preview`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';

class SimulatorSection extends ConsumerStatefulWidget {
  const SimulatorSection({super.key});
  @override
  ConsumerState<SimulatorSection> createState() => _SimulatorSectionState();
}

class _SimulatorSectionState extends ConsumerState<SimulatorSection> {
  // band: either picked directly or derived from the perf preview
  String _band = 'steady';
  bool _derive = false;
  final _speed = TextEditingController(text: '11.5');
  final _distance = TextEditingController(text: '5');
  final _age = TextEditingController(text: '30');
  final _moving = TextEditingController(text: '1500');
  final _asUser = TextEditingController();
  String? _sex;
  String _window = 'day';
  Set<String> _flags = {};
  Set<String> _connected = {'location', 'motion'};
  String? _state;

  Map<String, dynamic>? _perf;
  Map<String, dynamic>? _pool;
  bool _perfBusy = false, _poolBusy = false;
  String? _perfErr, _poolErr;

  @override
  void dispose() {
    for (final c in [_speed, _distance, _age, _moving, _asUser]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _preview() async {
    final v = double.tryParse(_speed.text.trim()), d = double.tryParse(_distance.text.trim());
    if (v == null || d == null) {
      setState(() => _perfErr = 'Speed and distance must be numbers');
      return;
    }
    setState(() {
      _perfBusy = true;
      _perfErr = null;
    });
    try {
      final r = await ref.read(apiProvider).adminPerfPreview(vKmh: v, dKm: d, sex: _sex, age: int.tryParse(_age.text.trim()));
      if (!mounted) return;
      setState(() {
        _perf = r;
        final b = r['band']?.toString();
        if (b != null && kSpeedBands.contains(b)) _band = b;
      });
    } catch (e) {
      if (mounted) setState(() => _perfErr = friendlyError(e));
    } finally {
      if (mounted) setState(() => _perfBusy = false);
    }
  }

  Map<String, dynamic> get _ctx => {
        'speed_band': _band,
        'distance_km': double.tryParse(_distance.text.trim()) ?? 0,
        'time_window': _window,
        'flags': (kRunFlags.where(_flags.contains).toList()),
        if (_state != null) 'state_code': _state,
        'connected': kConnected.where(_connected.contains).toList(),
        'moving_s': int.tryParse(_moving.text.trim()) ?? 0,
      };

  Future<void> _resolve() async {
    if (_derive && _perf == null) await _preview();
    setState(() {
      _poolBusy = true;
      _poolErr = null;
    });
    try {
      final asUser = _asUser.text.trim();
      final r = await ref.read(apiProvider).adminSimulatePool(_ctx, asUser: asUser.isEmpty ? null : asUser);
      if (mounted) setState(() => _pool = r);
    } catch (e) {
      if (mounted) setState(() => _poolErr = friendlyError(e));
    } finally {
      if (mounted) setState(() => _poolBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final regions = ref.watch(adminRegionsProvider).valueOrNull ?? const <RegionRow>[];
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    final inputs = _Inputs(
      band: _band,
      derive: _derive,
      onBand: (b) => setState(() => _band = b),
      onDerive: (v) => setState(() => _derive = v),
      speed: _speed,
      distance: _distance,
      age: _age,
      moving: _moving,
      asUser: _asUser,
      sex: _sex,
      onSex: (s) => setState(() => _sex = s),
      window: _window,
      onWindow: (w) => setState(() => _window = w),
      flags: _flags,
      onFlags: (f) => setState(() => _flags = f),
      connected: _connected,
      onConnected: (v) => setState(() => _connected = v),
      state: _state,
      onState: (s) => setState(() => _state = s),
      regions: regions,
      perf: _perf,
      perfBusy: _perfBusy,
      perfErr: _perfErr,
      onPreview: _preview,
      onResolve: _resolve,
      poolBusy: _poolBusy,
      ctx: _ctx,
    );
    final result = _PoolResult(pool: _pool, error: _poolErr, busy: _poolBusy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Simulator', subtitle: 'Describe a run, see which bag opens and every animal\'s chance. Nothing is issued.'),
        Expanded(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: ListView(padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.md, Space.xl), children: [inputs])),
                    Expanded(flex: 4, child: ListView(padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.xl, Space.xl), children: [result])),
                  ],
                )
              : ListView(padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl), children: [inputs, const SizedBox(height: Space.lg), result]),
        ),
        if (!wide) const SizedBox.shrink() else Padding(padding: const EdgeInsets.all(Space.sm), child: Text('Tip: an "as user" id applies pity, mastery and tier history for that runner.', style: t.labelSmall?.copyWith(color: c.inkMuted))),
      ],
    );
  }
}

class _Inputs extends StatelessWidget {
  const _Inputs({
    required this.band, required this.derive, required this.onBand, required this.onDerive,
    required this.speed, required this.distance, required this.age, required this.moving, required this.asUser,
    required this.sex, required this.onSex, required this.window, required this.onWindow,
    required this.flags, required this.onFlags, required this.connected, required this.onConnected,
    required this.state, required this.onState, required this.regions,
    required this.perf, required this.perfBusy, required this.perfErr, required this.onPreview,
    required this.onResolve, required this.poolBusy, required this.ctx,
  });
  final String band, window;
  final bool derive, perfBusy, poolBusy;
  final ValueChanged<String> onBand, onWindow;
  final ValueChanged<bool> onDerive;
  final TextEditingController speed, distance, age, moving, asUser;
  final String? sex, state, perfErr;
  final ValueChanged<String?> onSex, onState;
  final Set<String> flags, connected;
  final ValueChanged<Set<String>> onFlags, onConnected;
  final List<RegionRow> regions;
  final Map<String, dynamic>? perf;
  final VoidCallback onPreview, onResolve;
  final Map<String, dynamic> ctx;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final p = perf;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Run context', style: t.titleMedium),
          const SizedBox(height: Space.md),
          Field(
            label: 'Speed band',
            child: Row(
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [for (final b in kSpeedBands) ButtonSegment(value: b, label: Text(b))],
                  selected: {band},
                  onSelectionChanged: derive ? null : (s) => onBand(s.first),
                ),
                const SizedBox(width: Space.lg),
                Switch(value: derive, onChanged: onDerive),
                const SizedBox(width: Space.xs),
                Text('derive from speed', style: t.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(child: Field(label: 'Speed km/h', child: TextField(controller: speed, decoration: denseInput(), keyboardType: const TextInputType.numberWithOptions(decimal: true), enabled: derive))),
              const SizedBox(width: Space.md),
              Expanded(child: Field(label: 'Distance km', child: TextField(controller: distance, decoration: denseInput(), keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
              const SizedBox(width: Space.md),
              Expanded(child: Field(label: 'Moving s', child: TextField(controller: moving, decoration: denseInput(), keyboardType: TextInputType.number))),
              const SizedBox(width: Space.md),
              Expanded(
                child: Field(
                  label: 'Sex',
                  child: DropdownButtonFormField<String?>(
                    value: sex,
                    decoration: denseInput(),
                    items: const [DropdownMenuItem(value: null, child: Text('unknown')), DropdownMenuItem(value: 'male', child: Text('male')), DropdownMenuItem(value: 'female', child: Text('female'))],
                    onChanged: derive ? onSex : null,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(child: Field(label: 'Age', child: TextField(controller: age, decoration: denseInput(), keyboardType: TextInputType.number, enabled: derive))),
            ],
          ),
          if (derive) ...[
            const SizedBox(height: Space.sm),
            Row(
              children: [
                OutlinedButton.icon(onPressed: perfBusy ? null : onPreview, icon: const Icon(Icons.calculate_outlined, size: 18), label: Text(perfBusy ? 'Computing…' : 'Preview P')),
                const SizedBox(width: Space.lg),
                if (perfErr != null) Expanded(child: Text(perfErr!, style: t.bodySmall?.copyWith(color: c.danger))),
                if (p != null && perfErr == null)
                  Expanded(
                    child: Wrap(
                      spacing: Space.lg,
                      children: [
                        _Stat('v_std', '${_f(p['v_std'])} km/h'),
                        _Stat('age factor', _f(p['age_factor'], 3)),
                        _Stat('P', _f(p['perf_index'], 3)),
                        TagPill('band ${p['band']}', color: c.accent),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const Divider(height: Space.xxl),
          Field(
            label: 'Time window',
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final w in kTimeWindows) ButtonSegment(value: w, label: Text(w))],
              selected: {window},
              onSelectionChanged: (s) => onWindow(s.first),
            ),
          ),
          const SizedBox(height: Space.md),
          Field(label: 'Flags', child: ChipGroup(values: kRunFlags, selected: flags, onChanged: onFlags)),
          const SizedBox(height: Space.md),
          Field(label: 'Connected', child: ChipGroup(values: kConnected, selected: connected, onChanged: onConnected)),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Field(
                  label: 'State',
                  child: DropdownButtonFormField<String?>(
                    value: state,
                    decoration: denseInput(),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
                      for (final r in regions.where((r) => r.kind != 'country')) DropdownMenuItem<String?>(value: r.code, child: Text('${r.code} · ${r.name}')),
                    ],
                    onChanged: onState,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(child: Field(label: 'As user (uuid, optional)', child: TextField(controller: asUser, decoration: denseInput('applies pity & history'), style: monoStyle(context)))),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              FilledButton.icon(
                onPressed: poolBusy ? null : onResolve,
                icon: poolBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.casino_outlined),
                label: const Text('Resolve pool'),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Context JSON', style: t.labelMedium?.copyWith(color: c.inkMuted)),
            children: [JsonBlock(ctx)],
          ),
        ],
      ),
    );
  }
}

String _f(dynamic v, [int digits = 2]) {
  final n = v is num ? v : num.tryParse(v?.toString() ?? '');
  return n == null ? '—' : n.toStringAsFixed(digits);
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label, style: t.labelSmall?.copyWith(color: context.colors.inkMuted)), Text(value, style: monoStyle(context))],
    );
  }
}

class _PoolResult extends StatelessWidget {
  const _PoolResult({required this.pool, required this.error, required this.busy});
  final Map<String, dynamic>? pool;
  final String? error;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final p = pool;
    if (error != null) {
      return AdminCard(child: Row(children: [Icon(Icons.error_outline, color: c.danger), const SizedBox(width: Space.sm), Expanded(child: Text(error!, style: t.bodySmall?.copyWith(color: c.danger)))]));
    }
    if (p == null) {
      return AdminCard(child: Text(busy ? 'Resolving…' : 'Resolve a pool to see tier, trigger and probabilities here.', style: t.bodyMedium?.copyWith(color: c.inkMuted)));
    }
    final entries = ((p['pool'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList()
      ..sort((a, b) => (_num(b['p'])).compareTo(_num(a['p'])));
    final tier = p['tier']?.toString() ?? '0';
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Space.lg,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Tier $tier', style: t.headlineSmall),
              TagPill('trigger ${p['trigger'] ?? '—'}', color: c.accent),
              _Stat('pity n', '${p['pity_n'] ?? 0}'),
              _Stat('animals', '${entries.length}'),
            ],
          ),
          const SizedBox(height: Space.lg),
          if (entries.isEmpty)
            Text('Empty pool — no active rule matches this context at tier $tier.', style: t.bodyMedium?.copyWith(color: c.warn))
          else
            for (final e in entries) ...[
              _PoolRow(entry: e),
              const SizedBox(height: Space.sm),
            ],
        ],
      ),
    );
  }
}

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

class _PoolRow extends StatelessWidget {
  const _PoolRow({required this.entry});
  final Map<String, dynamic> entry;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final prob = _num(entry['p']).clamp(0.0, 1.0).toDouble();
    final rarity = Rarity.values.firstWhere((r) => r.name == entry['rarity'], orElse: () => Rarity.common);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(entry['name']?.toString() ?? entry['slug']?.toString() ?? '?', style: t.titleSmall)),
            RarityPill(rarity),
            const SizedBox(width: Space.md),
            SizedBox(width: 64, child: Text('w ${_f(entry['w'])}', style: monoStyle(context, size: 12, color: c.inkMuted), textAlign: TextAlign.end)),
            SizedBox(width: 64, child: Text('${(prob * 100).toStringAsFixed(1)}%', style: monoStyle(context), textAlign: TextAlign.end)),
          ],
        ),
        const SizedBox(height: Space.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.chip),
          child: LinearProgressIndicator(value: prob, minHeight: 6, backgroundColor: c.surfaceAlt, color: rarity.isRarePlus ? c.accent : c.success),
        ),
      ],
    );
  }
}
