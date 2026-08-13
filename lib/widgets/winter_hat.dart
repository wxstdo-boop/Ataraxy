import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small decorative knitted winter beanie (шапочка) with a fluffy pompom,
/// drawn entirely with [CustomPainter] so it scales cleanly and needs no
/// image assets. Sits on the first letter of the Ataraxy wordmark in the
/// home header.
///
/// Colors are pulled from the active theme's [ColorScheme] (Material You):
/// the cone shades from primary → secondary → tertiary, the brim and pompom
/// use the surface colour, so the hat always matches the current theme.
/// Wrap it in a [Transform.rotate] for a playful tilt.
class WinterHat extends StatelessWidget {
  /// Width of the hat in logical pixels (the brim).
  final double width;

  /// Height of the hat from brim to pompom top.
  final double height;

  const WinterHat({
    super.key,
    this.width = 30,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size(width, height),
      painter: _WinterHatPainter(
        bodyColors: [
          scheme.primary,
          scheme.secondary,
          scheme.tertiary,
        ],
        brim: scheme.surface,
        pompom: scheme.surface,
        accent: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}

class _WinterHatPainter extends CustomPainter {
  final List<Color> bodyColors;
  final Color brim;
  final Color pompom;
  final Color accent;

  _WinterHatPainter({
    required this.bodyColors,
    required this.brim,
    required this.pompom,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ---- Brim (rolled strip at the bottom) ----
    final brimTop = h * 0.66;
    final brimRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, brimTop, w, h - brimTop),
      const Radius.circular(4),
    );
    canvas.drawRRect(brimRRect, Paint()..color = brim);
    // Soft shading to separate the brim from the body.
    canvas.drawRRect(
      brimRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x22000000)],
        ).createShader(Rect.fromLTWH(0, brimTop, w, h - brimTop)),
    );
    // Knitted ribbing on the brim.
    final ribPaint = Paint()
      ..color = accent.withValues(alpha: 0.30)
      ..strokeWidth = 1.0;
    for (var x = 4.0; x < w - 2; x += 4.2) {
      canvas.drawLine(
        Offset(x, brimTop + 3.0),
        Offset(x, h - 3.0),
        ribPaint,
      );
    }

    // ---- Body (cone narrowing toward the top) ----
    final body = Path()
      ..moveTo(w * 0.06, brimTop)
      ..quadraticBezierTo(w * 0.20, h * 0.16, w * 0.42, h * 0.08)
      ..lineTo(w * 0.58, h * 0.12)
      ..quadraticBezierTo(w * 0.86, h * 0.24, w * 0.94, brimTop)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bodyColors,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Light specular highlight along the left edge of the body.
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x4DFFFFFF), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Knitted ribbing stripes curving with the cone.
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 2; i++) {
      final t = i / 3.0;
      final y = brimTop - t * (brimTop - h * 0.10);
      final inset = w * (0.12 + t * 0.30);
      final p = Path()
        ..moveTo(w * 0.06 + inset * 0.35, y)
        ..quadraticBezierTo(
          w * 0.50,
          y - h * 0.09,
          w * 0.94 - inset * 0.35,
          y,
        );
      canvas.drawPath(p, stripe);
    }

    // Tiny snowflake motif on the body.
    canvas.save();
    canvas.translate(w * 0.52, h * 0.34);
    canvas.scale(w / 30);
    final flake = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a = i * (math.pi / 3);
      canvas.drawLine(
        Offset.zero,
        Offset(2.8 * math.cos(a), 2.8 * math.sin(a)),
        flake,
      );
    }
    canvas.drawCircle(Offset.zero, 0.8, flake);
    canvas.restore();

    // ---- Pompom (fluffy ball hanging over the top edge) ----
    final pomCenter = Offset(w * 0.50, h * 0.04);
    final pomRadius = w * 0.19;
    canvas.drawCircle(pomCenter, pomRadius, Paint()..color = pompom);
    canvas.drawCircle(
      pomCenter,
      pomRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0x00000000), Color(0x33000000)],
        ).createShader(
          Rect.fromCircle(center: pomCenter, radius: pomRadius),
        ),
    );
    // Fuzz bumps on the pompom.
    final fuzz = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (final off in const [
      Offset(2.2, 0.6),
      Offset(-2.0, -1.0),
      Offset(0.2, -2.2),
      Offset(-2.8, 1.0),
    ]) {
      canvas.drawLine(pomCenter + off, pomCenter + off * 1.6, fuzz);
    }
  }

  @override
  bool shouldRepaint(covariant _WinterHatPainter oldDelegate) {
    return oldDelegate.bodyColors != bodyColors ||
        oldDelegate.brim != brim ||
        oldDelegate.pompom != pompom ||
        oldDelegate.accent != accent;
  }
}
