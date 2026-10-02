import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 24 dots that burst from the card edge over 900 ms (DESIGN.md §6, rare+).
/// [progress] is 0..1; [cardRect] is where the card sits in this painter's space.
class RevealParticlesPainter extends CustomPainter {
  const RevealParticlesPainter({required this.progress, required this.cardRect, required this.colors});

  final double progress;
  final Rect cardRect;
  final List<Color> colors;

  static const count = 24;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || colors.isEmpty) return;
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    final center = cardRect.center;
    final halfW = cardRect.width / 2;
    final halfH = cardRect.height / 2;

    for (var i = 0; i < count; i++) {
      final jitter = ((i * 7919) % 97) / 97.0; // deterministic 0..1
      final angle = (i / count) * math.pi * 2 + jitter * 0.18;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      // Project to the card edge.
      final tEdge = math.min(dx == 0 ? double.infinity : halfW / dx.abs(), dy == 0 ? double.infinity : halfH / dy.abs());
      final start = center + Offset(dx * tEdge, dy * tEdge);
      final travel = (70 + jitter * 90) * eased;
      final pos = start + Offset(dx * travel, dy * travel - 24 * eased);
      final radius = (3.2 - 2.0 * progress) * (0.8 + jitter * 0.5);
      final color = colors[i % colors.length].withValues(alpha: fade);
      canvas.drawCircle(pos, math.max(0.5, radius), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(RevealParticlesPainter old) => old.progress != progress || old.cardRect != cardRect || old.colors != colors;
}
