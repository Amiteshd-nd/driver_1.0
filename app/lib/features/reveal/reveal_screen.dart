import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/router.dart';
import '../../core/theme/tokens.dart';
import '../card/widgets/pug_card_view.dart';
import 'widgets/card_back.dart';
import 'widgets/reveal_particles.dart';

enum _Phase { reading, slide, flip, revealed }

/// The one long moment (DESIGN.md §6): scrim → card back slides up → flips → face,
/// particles for rare+, then celebrations as captions. Tap anywhere → card detail.
class RevealScreen extends StatefulWidget {
  const RevealScreen({super.key, required this.result});
  final RevealPayload result;

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> with TickerProviderStateMixin {
  _Phase _phase = _Phase.reading;
  late final AnimationController _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final AnimationController _particles = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final List<Timer> _timers = [];
  late final List<Celebration> _celebs;
  int _captionIndex = -1;
  late Stage _displayStage;
  bool _reduce = false;
  bool _started = false;

  PugCard? get _card => widget.result.card;

  @override
  void initState() {
    super.initState();
    _celebs = widget.result.celebrations.where((c) => c.caption.isNotEmpty).toList();
    final card = _card;
    if (card != null) {
      final growth = _celebs.any((c) => c.kind == 'growth');
      _displayStage = growth ? Stage.values[math.max(0, card.stage.index - 1)] : card.stage;
    } else {
      _displayStage = Stage.baby;
    }
    _flip.addStatusListener((st) {
      if (st == AnimationStatus.completed) _onRevealed();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (!_started && _card != null) {
      _started = true;
      _after(500, _startSlide);
    }
  }

  void _after(int ms, VoidCallback f) {
    _timers.add(Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }));
  }

  void _startSlide() {
    HapticFeedback.lightImpact();
    if (_reduce) {
      setState(() => _phase = _Phase.revealed);
      _onRevealed();
      return;
    }
    setState(() => _phase = _Phase.slide);
    _after(420 + 300, _startFlip);
  }

  void _startFlip() {
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.flip);
    _flip.forward(from: 0);
  }

  void _onRevealed() {
    final card = _card;
    if (card == null) return;
    setState(() => _phase = _Phase.revealed);
    if (card.rarity.isRarePlus) {
      HapticFeedback.heavyImpact();
      _after(120, HapticFeedback.lightImpact);
      if (!_reduce && RarityStyle.of(card.rarity).particles) _particles.forward(from: 0);
    }
    if (_celebs.isNotEmpty) _after(500, _nextCaption);
  }

  void _nextCaption() {
    if (_captionIndex + 1 >= _celebs.length) return;
    setState(() => _captionIndex++);
    final c = _celebs[_captionIndex];
    if (c.kind == 'growth' && _card != null) {
      HapticFeedback.heavyImpact();
      _after(250, () => setState(() => _displayStage = _card!.stage));
    }
    if (_captionIndex + 1 < _celebs.length) _after(2600, _nextCaption);
  }

  void _dismiss() {
    final card = _card;
    if (card == null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed(Routes.today);
      }
      return;
    }
    if (_phase != _Phase.revealed) {
      // Skip ahead rather than ignore the tap.
      for (final t in _timers) {
        t.cancel();
      }
      _timers.clear();
      _flip.stop();
      _onRevealed();
      return;
    }
    context.goNamed(Routes.card, pathParameters: {'id': card.id}, extra: card);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _flip.dispose();
    _particles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final c = context.pug;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scrim = isDark ? c.bg : c.ink;
    final onScrim = isDark ? c.ink : c.bg;

    if (card == null) return _NoCardView(message: _fallbackMessage(), onDone: _dismiss);

    final size = MediaQuery.sizeOf(context);
    final cardW = math.min(size.width - 48, 320.0);
    final cardH = cardW * PugCardView.aspect;
    final cardRect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: cardW, height: cardH);

    return Scaffold(
      backgroundColor: scrim,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Semantics(
          label: _phase == _Phase.revealed ? 'Card revealed. Tap anywhere to continue.' : 'Revealing your card',
          button: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (RarityStyle.of(card.rarity).particles)
                AnimatedBuilder(
                  animation: _particles,
                  builder: (_, __) => CustomPaint(
                    painter: RevealParticlesPainter(progress: _particles.value, cardRect: cardRect, colors: [card.palette.accent, card.palette.bg]),
                  ),
                ),
              Center(child: _cardArea(card, cardW, onScrim)),
              Positioned(
                left: Space.xl,
                right: Space.xl,
                top: cardRect.bottom + Space.xl,
                child: _captions(onScrim),
              ),
              if (_phase == _Phase.revealed)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: Space.xxl + MediaQuery.paddingOf(context).bottom,
                  child: Text('Tap anywhere', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: onScrim.withValues(alpha: 0.6)))
                      .animate()
                      .fadeIn(delay: const Duration(milliseconds: 900), duration: const Duration(milliseconds: 400)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardArea(PugCard card, double cardW, Color onScrim) {
    final face = AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: PugCardView(
        key: ValueKey(_displayStage),
        card: card,
        width: cardW,
        interactive: _phase == _Phase.revealed,
        stageOverride: _displayStage,
      ),
    );
    final back = CardBack(palette: card.palette, width: cardW);
    final reading = widget.result.pending != null ? 'Opening your envelope…' : 'Reading your run…';

    switch (_phase) {
      case _Phase.reading:
        return Text(reading, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: onScrim))
            .animate(onPlay: (ctl) => ctl.repeat())
            .shimmer(duration: const Duration(milliseconds: 1200));
      case _Phase.slide:
        return back
            .animate()
            .fadeIn(duration: const Duration(milliseconds: 200))
            .slideY(begin: 1.2, end: 0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
      case _Phase.flip:
        return AnimatedBuilder(
          animation: _flip,
          builder: (_, __) {
            final angle = Curves.easeInOutCubic.transform(_flip.value) * math.pi;
            final showFace = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle),
              child: showFace
                  ? Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateY(math.pi), child: face)
                  : back,
            );
          },
        );
      case _Phase.revealed:
        return _reduce ? face.animate().fadeIn(duration: const Duration(milliseconds: 350)) : face;
    }
  }

  Widget _captions(Color onScrim) {
    if (_phase != _Phase.revealed || _captionIndex < 0 || _captionIndex >= _celebs.length) return const SizedBox(height: 48);
    final text = _celebs[_captionIndex].caption;
    return Text(
      text,
      key: ValueKey(_captionIndex),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: onScrim),
    ).animate().fadeIn(duration: const Duration(milliseconds: 350)).slideY(begin: 0.2, end: 0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  /// DESIGN.md §9 copy when the server sent no message.
  String _fallbackMessage() {
    final r = widget.result.result;
    final m = r?.message;
    if (m != null && m.isNotEmpty) return m;
    if (r == null) return 'Nothing to open right now.';
    if (r.duplicate) return 'This run is already in your ledger.';
    if (r.verdict == Verdict.rejected) return "We couldn't confirm this one was a run — no card this time.";
    if (!r.floorMet) return 'Recorded. A run of 1 km or 10 minutes earns a card.';
    if (r.capped) return 'Recorded and counted. Your card bag refills tomorrow.';
    return 'Recorded. No card this time.';
  }
}

/// Calm screen for rejected / floor / capped results.
class _NoCardView extends StatelessWidget {
  const _NoCardView({required this.message, required this.onDone});
  final String message;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.pets, size: 40, color: c.inkMuted),
              const SizedBox(height: Space.lg),
              Text('Recorded', style: tt.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: Space.sm),
              Text(message, style: tt.bodyMedium?.copyWith(color: c.inkMuted), textAlign: TextAlign.center),
              const Spacer(),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: onDone, child: const Text('Done'))),
            ],
          ),
        ),
      ),
    );
  }
}
