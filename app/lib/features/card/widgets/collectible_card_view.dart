import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/tokens.dart';
import 'animal_art.dart';
import 'foil_overlay.dart';
import 'tilt_source.dart';

/// The hero: a 5:7 collectible card per DESIGN.md §5. Scales as a unit from
/// [width] (300 = design size). Rarity is carried by border and finish only.
class CollectibleCardView extends StatefulWidget {
  const CollectibleCardView({
    super.key,
    required this.card,
    this.width = 300,
    this.interactive = true,
    this.showStats = true,
    this.stageOverride,
  });

  final CollectibleCard card;
  final double width;

  /// Enables the subtle 3-D tilt that follows the device.
  final bool interactive;

  /// Hide flavour + stats (collection tiles).
  final bool showStats;

  /// Show a different stage's art (used by the growth cross-fade).
  final Stage? stageOverride;

  static const aspect = 7 / 5;

  /// Accessibility label per DESIGN.md §10.
  static String semanticsLabel(CollectibleCard c) {
    final v = c.verdict == Verdict.verified ? '' : ', unverified';
    return '${c.name}, ${c.stage.label.toLowerCase()}, ${c.rarity.label.toLowerCase()}, serial ${c.serialNo}, earned ${fullDate(c.issuedAt)}$v';
  }

  static String fullDate(DateTime d) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${d.day} ${months[(d.month - 1).clamp(0, 11)]} ${d.year}';
  }

  @override
  State<CollectibleCardView> createState() => _CollectibleCardViewState();
}

class _CollectibleCardViewState extends State<CollectibleCardView> with TickerProviderStateMixin {
  AnimationController? _legendary;
  AnimationController? _breath;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _ensureControllers();
  }

  @override
  void didUpdateWidget(covariant CollectibleCardView old) {
    super.didUpdateWidget(old);
    if (old.card.rarity != widget.card.rarity || old.card.finish != widget.card.finish) _ensureControllers();
  }

  void _ensureControllers() {
    final style = RarityStyle.of(widget.card.rarity);
    if (style.animated) {
      _legendary ??= AnimationController(vsync: this, duration: const Duration(seconds: 6));
    } else {
      _legendary?.dispose();
      _legendary = null;
    }
    if (widget.card.finish == Finish.radiant) {
      _breath ??= AnimationController(vsync: this, duration: const Duration(seconds: 4));
    } else {
      _breath?.dispose();
      _breath = null;
    }
    _syncMotion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _syncMotion();
  }

  void _syncMotion() {
    if (_reduce) {
      _legendary?.stop();
      _breath?.stop();
      _breath?.value = 1;
      return;
    }
    if (_legendary != null && !_legendary!.isAnimating) _legendary!.repeat();
    if (_breath != null && !_breath!.isAnimating) _breath!.repeat(reverse: true);
  }

  @override
  void dispose() {
    _legendary?.dispose();
    _breath?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final w = widget.width;
    final h = w * CollectibleCardView.aspect;
    final s = w / 300;
    final c = context.colors;
    final style = RarityStyle.of(card.rarity);
    final bw = style.width * s.clamp(0.6, 1.5);
    final radius = math.max(10.0, Radii.card * s);

    Widget body = AnimatedBuilder(
      animation: Listenable.merge(<Listenable?>[_legendary, _breath]),
      builder: (context, _) {
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: _borderColor(c),
            gradient: _borderGradient(style),
            boxShadow: _glow(s),
          ),
          padding: EdgeInsets.all(bw),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - bw),
            child: ColoredBox(
              color: c.surface,
              child: _face(context, innerW: w - 2 * bw, innerH: h - 2 * bw, s: s, style: style),
            ),
          ),
        );
      },
    );

    if (widget.interactive && !_reduce) {
      final tilt = TiltSource.instance;
      body = ListenableBuilder(
        listenable: tilt,
        builder: (context, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-tilt.y * 0.10)
            ..rotateY(tilt.x * 0.10),
          child: child,
        ),
        child: body,
      );
    }

    return Semantics(
      label: CollectibleCardView.semanticsLabel(card),
      container: true,
      child: ExcludeSemantics(child: MediaQuery.withNoTextScaling(child: body)),
    );
  }

  Color? _borderColor(AppColors c) {
    if (widget.card.rarity == Rarity.common) return c.line;
    if (widget.card.rarity == Rarity.uncommon) return widget.card.palette.accent;
    return null;
  }

  Gradient? _borderGradient(RarityStyle style) {
    final accent = widget.card.palette.accent;
    if (!widget.card.rarity.isRarePlus) return null;
    const white = Color(0xFFFFFFFF); // DESIGN §3.3: family accent → white
    if (style.animated) {
      final t = _legendary?.value ?? 0;
      return SweepGradient(
        colors: [accent, white, accent, white, accent],
        transform: GradientRotation(t * math.pi * 2),
      );
    }
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent, white, accent]);
  }

  List<BoxShadow>? _glow(double s) {
    final accent = widget.card.palette.accent;
    switch (widget.card.finish) {
      case Finish.plain:
        return null;
      case Finish.glow:
        return [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 12 * s, spreadRadius: 1 * s)];
      case Finish.radiant:
        final t = _breath?.value ?? 1;
        return [BoxShadow(color: accent.withValues(alpha: 0.30 + 0.20 * t), blurRadius: (18 + 6 * t) * s, spreadRadius: (1 + 2 * t) * s)];
    }
  }

  Widget _face(BuildContext context, {required double innerW, required double innerH, required double s, required RarityStyle style}) {
    final card = widget.card;
    final c = context.colors;
    final tt = Theme.of(context).textTheme;
    final pal = card.palette;
    final stage = widget.stageOverride ?? card.stage;
    final artH = innerH * 0.56;
    final pad = 14 * s;

    final art = SizedBox(
      height: artH,
      width: innerW,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: pal.bg),
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 28 * s, pad, 8 * s),
            child: AnimalArt(slug: card.slug, name: card.name, family: card.family, stage: stage, path: card.artPath(stage), illustration: card.illustration, palette: pal),
          ),
          if (style.foil) Positioned.fill(child: FoilOverlay(tilt: widget.interactive)),
          if (card.rarity == Rarity.epic || card.rarity == Rarity.legendary)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: pal.fg.withValues(alpha: 0.22), width: 1)),
                ),
              ),
            ),
          Positioned(
            left: pad - 2 * s,
            right: pad - 2 * s,
            top: 10 * s,
            child: _captionRow(context, s),
          ),
        ],
      ),
    );

    final name = Text(
      card.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tt.displaySmall?.copyWith(fontSize: 28 * s, height: 32 / 28, color: c.ink),
    );

    final serialRow = Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(card.serial.toUpperCase().replaceFirst(' #', '  #'), maxLines: 1, style: AppText.serial(context, size: 18 * s)),
            ),
          ),
        ),
        SizedBox(width: 6 * s),
        Icon(
          card.verdict == Verdict.verified ? Icons.verified_rounded : Icons.verified_outlined,
          size: 18 * s,
          color: verdictColor(context, card.verdict),
        ),
      ],
    );

    final lower = Padding(
      padding: EdgeInsets.fromLTRB(pad, 10 * s, pad, 12 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          name,
          if (widget.showStats) ...[
            SizedBox(height: 4 * s),
            Text(
              card.flavourLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.flavour(context).copyWith(fontSize: 14 * s, height: 20 / 14),
            ),
          ],
          const Spacer(),
          if (widget.showStats && card.statsLine.isNotEmpty) ...[
            Container(height: 1, color: c.line),
            SizedBox(height: 8 * s),
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(card.statsLine, maxLines: 1, style: AppText.stat(context).copyWith(fontSize: 22 * s, height: 26 / 22)),
              ),
            ),
            SizedBox(height: 6 * s),
          ],
          serialRow,
        ],
      ),
    );

    return Stack(
      children: [
        Column(children: [art, Expanded(child: lower)]),
        if (style.animated) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CornerMarksPainter(color: pal.accent, inset: 6 * s, length: 14 * s)))),
      ],
    );
  }

  Widget _captionRow(BuildContext context, double s) {
    final card = widget.card;
    final pal = card.palette;
    final tt = Theme.of(context).textTheme;
    final caption = (tt.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(fontSize: 11 * s, height: 14 / 11, color: pal.fg, letterSpacing: 0.9 * s, fontWeight: FontWeight.w600);
    final setName = card.season ?? switch (card.scope) { CardScope.run => 'Everyday', CardScope.weekly => 'Weekly', CardScope.monthly => 'Monthly' };
    return Row(
      children: [
        Expanded(child: Text(setName.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: caption)),
        SizedBox(width: 8 * s),
        Container(width: 6 * s, height: 6 * s, decoration: BoxDecoration(color: pal.accent, shape: BoxShape.circle)),
        SizedBox(width: 4 * s),
        Text(card.rarity.label.toUpperCase(), style: caption),
      ],
    );
  }
}

/// Legendary corner marks (DESIGN §3.3).
class _CornerMarksPainter extends CustomPainter {
  const _CornerMarksPainter({required this.color, required this.inset, required this.length});
  final Color color;
  final double inset, length;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    void corner(Offset o, double sx, double sy) {
      canvas.drawLine(o, o + Offset(length * sx, 0), p);
      canvas.drawLine(o, o + Offset(0, length * sy), p);
    }

    corner(Offset(inset, inset), 1, 1);
    corner(Offset(size.width - inset, inset), -1, 1);
    corner(Offset(inset, size.height - inset), 1, -1);
    corner(Offset(size.width - inset, size.height - inset), -1, -1);
  }

  @override
  bool shouldRepaint(_CornerMarksPainter old) => old.color != color || old.inset != inset || old.length != length;
}
