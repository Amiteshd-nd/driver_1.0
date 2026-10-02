import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// The back of a card: a palette-coloured rectangle carrying the paw mark
/// (DESIGN.md §2: four toes, rounded-trapezoid pad, same corner radius as the card).
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.palette, required this.width});

  final FamilyPalette palette;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 7 / 5;
    final s = width / 300;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(Radii.card * s),
        border: Border.all(color: palette.accent, width: 2 * s),
      ),
      child: Center(
        child: SizedBox(
          width: width * 0.42,
          height: width * 0.42,
          child: CustomPaint(painter: PawMarkPainter(color: palette.accent)),
        ),
      ),
    );
  }
}

/// Single-colour paw print. Draws into whatever square it is given.
class PawMarkPainter extends CustomPainter {
  const PawMarkPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Pad: rounded trapezoid, wider at the top.
    final pad = Path()
      ..moveTo(cx - u * 0.28, cy + u * 0.02)
      ..lineTo(cx + u * 0.28, cy + u * 0.02)
      ..lineTo(cx + u * 0.20, cy + u * 0.40)
      ..lineTo(cx - u * 0.20, cy + u * 0.40)
      ..close();
    // Fill, then stroke with round joins so the corners read as rounded.
    canvas.drawPath(pad, paint);
    canvas.drawPath(
      pad,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = u * 0.10,
    );

    // Four toes in an arc above the pad.
    final toes = [
      Offset(cx - u * 0.30, cy - u * 0.16),
      Offset(cx - u * 0.11, cy - u * 0.30),
      Offset(cx + u * 0.11, cy - u * 0.30),
      Offset(cx + u * 0.30, cy - u * 0.16),
    ];
    for (final t in toes) {
      canvas.drawOval(Rect.fromCenter(center: t, width: u * 0.17, height: u * 0.21), paint);
    }
  }

  @override
  bool shouldRepaint(PawMarkPainter old) => old.color != color;
}
