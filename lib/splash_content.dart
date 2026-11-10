import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'l10n/strings.dart';

class SplashContent extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<double> contentOpacity;
  final bool opaque;

  const SplashContent({
    super.key,
    required this.opacity,
    required this.contentOpacity,
    this.opaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The splash follows the active theme palette instead of the old
    // hardcoded pink/lavender. MUTILATED gets a fully opaque background
    // (deep blood red); other themes keep the soft translucent gradient.
    final a = opaque ? 1.0 : 0.85;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Layered wash: a warm primary glow up top melting through a
          // mid tone into the tertiary depth, with a soft radial bloom at
          // the top so the logo tile reads as if lit from above.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.4, 0.72, 1.0],
            colors: [
              scheme.primary.withValues(alpha: a),
              Color.lerp(
                scheme.primary,
                scheme.secondary,
                0.4,
              )!.withValues(alpha: a),
              Color.lerp(
                scheme.primary,
                scheme.tertiary,
                0.6,
              )!.withValues(alpha: a),
              scheme.tertiary.withValues(alpha: a),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Soft top bloom so the logo tile reads as lit from above.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.55),
                    radius: 0.9,
                    colors: [
                      Colors.white.withValues(alpha: opaque ? 0.10 : 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Soft bokeh circles for depth (same language as the guide banner).
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              top: 120,
              left: 40,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: opacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Squircle logo tile: the black-field artwork sits on a
                    // black tile so the moon reads as a floating crescent
                    // against the themed wash, not a hard white square.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF000000), Color(0xFF121014)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.12),
                            blurRadius: 40,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/ataraxy.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          L.tr(context, 'launchTitle'),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.6,
                            shadows: [
                              Shadow(
                                color: scheme.shadow.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Hand-drawn underline: a rounded dashed rule under
                        // the wordmark. CustomPaint (not a decoration) so the
                        // dashes get round caps and a slight arc.
                        SizedBox(
                          width: 168,
                          height: 12,
                          child: CustomPaint(
                            painter: _DashedUnderlinePainter(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      L.tr(context, 'byWetidom'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Black "snake": a dark comet arc so it reads as ink on
                    // the themed wash, matching the black-field artwork.
                    const CometSpinner(size: 46),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A smooth rotating "comet" arc: a dark stroke whose head and tail both fade
/// to nothing (a snake), so the loading motion never shows a hard blunt end.
/// The arc length gently breathes as it spins.
class CometSpinner extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const CometSpinner({
    super.key,
    this.size = 46,
    this.color = const Color(0xE6000000),
    this.strokeWidth = 5,
  });

  @override
  State<CometSpinner> createState() => _CometSpinnerState();
}

class _CometSpinnerState extends State<CometSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      // Own layer: the arc repaints every frame, so isolating it keeps that
      // per-frame repaint from dirtying the whole splash (which would force
      // the big gradient + artwork to re-rasterise on every frame — the
      // stutter felt while the splash was fading out).
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CometPainter(
            t: _controller,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _CometPainter extends CustomPainter {
  final Animation<double> t;
  final Color color;
  final double strokeWidth;

  _CometPainter({
    required this.t,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final phase = t.value * 2 * math.pi;
    final start = phase;
    // Breathe the arc length between ~215° and ~285°.
    final sweep = 4.2 + 0.5 * math.sin(phase * 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.35),
          color,
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _CometPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// A gentle dashed underline with rounded caps, drawn along a shallow arc so
/// it reads as a hand-drawn stroke rather than a machine-straight rule.
class _DashedUnderlinePainter extends CustomPainter {
  final Color color;

  static const double _dash = 7;
  static const double _gap = 6;
  static const double _strokeWidth = 3;

  _DashedUnderlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    // Shallow downward bow: ends sit slightly higher than the middle.
    final path = Path()
      ..moveTo(_strokeWidth, size.height * 0.35)
      ..quadraticBezierTo(
        size.width / 2,
        size.height,
        size.width - _strokeWidth,
        size.height * 0.35,
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedUnderlinePainter old) =>
      old.color != color;
}
