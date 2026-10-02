import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'tilt_source.dart';

/// Holographic foil (DESIGN.md §6) drawn over the art area with BlendMode.plus.
/// Driven by `assets/shaders/foil.frag`; tilt from [TiltSource], time from a
/// ticker. Renders nothing if the shader cannot be loaded. With reduced motion
/// the band is static (no tilt, no drift).
class FoilOverlay extends StatefulWidget {
  const FoilOverlay({super.key, this.strength = 0.6, this.tilt = true});

  /// 0..1 overall opacity of the foil.
  final double strength;

  /// Follow device tilt (ignored under reduced motion).
  final bool tilt;

  static Future<ui.FragmentProgram>? _programFuture;

  static Future<ui.FragmentProgram> program() => _programFuture ??= ui.FragmentProgram.fromAsset('assets/shaders/foil.frag');

  @override
  State<FoilOverlay> createState() => _FoilOverlayState();
}

class _FoilOverlayState extends State<FoilOverlay> with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  bool _failed = false;
  bool _reduce = false;
  Ticker? _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await FoilOverlay.program();
      if (!mounted) return;
      setState(() => _shader = p.fragmentShader());
      _syncTicker();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _syncTicker();
  }

  void _syncTicker() {
    if (_shader == null || _failed) return;
    if (_reduce) {
      _ticker?.stop();
      return;
    }
    _ticker ??= createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6);
    if (!_ticker!.isActive) _ticker!.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _shader?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (_failed || shader == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _FoilPainter(
          shader: shader,
          time: _time,
          tilt: widget.tilt && !_reduce ? TiltSource.instance : null,
          strength: widget.strength,
        ),
      ),
    );
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter({required this.shader, required this.time, required this.tilt, required this.strength})
      : super(repaint: Listenable.merge(<Listenable?>[time, tilt]));

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final TiltSource? tilt;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, tilt?.x ?? 0)
      ..setFloat(4, tilt?.y ?? 0)
      ..setFloat(5, strength.clamp(0.0, 1.0));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(_FoilPainter old) => old.shader != shader || old.strength != strength || old.tilt != tilt;
}
