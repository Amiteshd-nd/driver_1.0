import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import 'run_queue.dart';
import 'run_recorder.dart';

class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key});

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> {
  RunRecorder? _rec;
  bool _submitting = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    ref.read(runQueueProvider); // start the offline flusher
  }

  @override
  void dispose() {
    _rec?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final tz = ref.read(profileProvider).valueOrNull?.timezone ?? Brand.defaultTimezone;
    final rec = RunRecorder(timezone: tz);
    setState(() => _rec = rec);
    await rec.start();
    if (rec.lastError != null && mounted) setState(() => _notice = rec.lastError);
    HapticFeedback.mediumImpact();
  }

  Future<void> _finish() async {
    final rec = _rec;
    if (rec == null || _submitting) return;
    final belowFloor = rec.distanceM < 1000 && rec.moving.inSeconds < 600;
    if (belowFloor) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Finish this run?'),
          content: const Text('Recorded. A run of 1 km or 10 minutes earns a card.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep going')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Finish anyway')),
          ],
        ),
      );
      if (go != true) return;
    }
    if (!mounted) return;
    setState(() => _submitting = true);
    HapticFeedback.heavyImpact();
    final payload = await rec.finish();
    final api = ref.read(apiProvider);
    try {
      final RunResult r = await api.submitRun(payload).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      refreshAfterCard(ref);
      context.pushReplacementNamed(Routes.reveal, extra: RevealPayload(result: r));
    } catch (e) {
      if (!mounted) return;
      if (isNetworkError(e)) {
        await ref.read(runQueueProvider).enqueue(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved. We\'ll fetch your card when you\'re back online.')));
        context.go('/today');
      } else {
        setState(() {
          _submitting = false;
          _notice = 'We couldn\'t read this run right now. It\'s saved on your phone; we\'ll try again when you reopen the app.';
        });
        await ref.read(runQueueProvider).enqueue(payload);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = _rec;
    if (_submitting) return const _ReadingRun();
    if (rec == null) return _Ready(onStart: _start);
    return ListenableBuilder(
      listenable: rec,
      builder: (context, _) => _Recording(rec: rec, notice: _notice, onFinish: _finish),
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Run')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.directions_run, size: 72, color: c.accent),
            const SizedBox(height: Space.xl),
            Text('Ready when you are.', style: text.headlineMedium),
            const SizedBox(height: Space.sm),
            Text('Keep your phone with you. A run of 1 km or 10 minutes earns a card.',
                textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: c.inkMuted)),
            const SizedBox(height: Space.xxl),
            SizedBox(width: 220, height: 64, child: FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow), label: const Text('Start'))),
          ]),
        ),
      ),
    );
  }
}

class _Recording extends StatelessWidget {
  const _Recording({required this.rec, required this.notice, required this.onFinish});
  final RunRecorder rec;
  final String? notice;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final text = Theme.of(context).textTheme;
    final km = rec.distanceM / 1000;
    final pace = rec.currentPaceSPerKm;
    final paused = rec.phase == RunPhase.paused;
    final autoPaused = rec.phase == RunPhase.autoPaused;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(paused ? 'Paused' : autoPaused ? 'Auto-paused' : 'Running'),
          automaticallyImplyLeading: false,
          actions: [Padding(padding: const EdgeInsets.only(right: Space.lg), child: _GpsPill(status: rec.gps))],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(children: [
              const Spacer(),
              Text(fmtDuration(rec.moving.inSeconds), style: text.displayLarge?.copyWith(fontSize: 72, height: 1.1, fontFeatures: PugText.tabular)),
              Text('moving · ${fmtDuration(rec.elapsed.inSeconds)} total', style: text.labelMedium?.copyWith(color: c.inkMuted)),
              const SizedBox(height: Space.xxl),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _Stat(label: 'km', value: rec.gps == GpsStatus.denied ? '—' : km.toStringAsFixed(2)),
                _Stat(label: 'pace /km', value: pace == null ? '—' : fmtPace(pace)),
                _Stat(label: 'climb m', value: rec.elevationGainM.round().toString()),
              ]),
              const Spacer(),
              if (rec.gps == GpsStatus.searching) _Hint(icon: Icons.satellite_alt_outlined, text: 'Looking for GPS… time keeps counting; distance resumes with the next fix.'),
              if (rec.gps == GpsStatus.foregroundOnly) _Hint(icon: Icons.phone_android, text: 'Location is allowed while the app is open. Keep the screen on, or allow background location under You → Permissions.'),
              if (rec.gps == GpsStatus.denied) _Hint(icon: Icons.timer_outlined, text: notice ?? 'This run is timed, not measured.'),
              if (notice != null && rec.gps != GpsStatus.denied) _Hint(icon: Icons.info_outline, text: notice!),
              const SizedBox(height: Space.xl),
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: paused ? rec.resume : rec.pause,
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                      label: Text(paused ? 'Resume' : 'Pause'),
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: FilledButton.icon(onPressed: onFinish, icon: const Icon(Icons.flag), label: const Text('Finish')),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    return Column(children: [
      Text(value, style: PugText.stat(context).copyWith(fontSize: 30)),
      Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.inkMuted)),
    ]);
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.sm),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.control)),
      child: Row(children: [
        Icon(icon, size: 20, color: c.inkMuted),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}

class _GpsPill extends StatelessWidget {
  const _GpsPill({required this.status});
  final GpsStatus status;
  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final (label, color) = switch (status) {
      GpsStatus.good => ('GPS', c.success),
      GpsStatus.foregroundOnly => ('GPS · open app', c.warn),
      GpsStatus.searching => ('Looking for GPS…', c.warn),
      GpsStatus.denied => ('Timer', c.inkMuted),
      GpsStatus.off => ('—', c.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: Space.xs),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ]),
    );
  }
}

class _ReadingRun extends StatelessWidget {
  const _ReadingRun();
  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 220,
            height: 320,
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
          ).animate(onPlay: (ctrl) => ctrl.repeat()).shimmer(duration: 1400.ms, color: c.surface.withValues(alpha: 0.7)),
          const SizedBox(height: Space.xl),
          Text('Reading your run…', style: text.headlineSmall),
          const SizedBox(height: Space.sm),
          Text('Measuring, checking, choosing.', style: text.bodyMedium?.copyWith(color: c.inkMuted)),
        ]),
      ),
    );
  }
}
