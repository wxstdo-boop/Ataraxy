import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'l10n/strings.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_letters.dart';

class SplashContent extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<double> contentOpacity;
  final bool opaque;

  /// When false the loading "snake" stops animating. The splash exit passes
  /// false once the fade begins so the spinner is not repainting the whole
  /// screen every frame underneath the (cheap) opacity fade.
  final bool spinning;

  const SplashContent({
    super.key,
    required this.opacity,
    required this.contentOpacity,
    this.opaque = false,
    this.spinning = true,
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
                    // Brand wordmark: italic display cut with a trailing
                    // period, and each glyph writes itself in on a stagger.
                    AnimatedLetters(
                      '${L.tr(context, 'launchTitle')}.',
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontStyle: FontStyle.italic,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.4,
                        shadows: [
                          Shadow(
                            color: scheme.shadow.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // The "POWERED BY LARAF" line, underlined by a soft
                    // translucent red wavy stroke with rounded ends.
                    _WavyUnderlined(
                      child: Text(
                        L.tr(context, 'byWetidom'),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Black "snake": a dark comet arc so it reads as ink on
                    // the themed wash, matching the black-field artwork.
                    CometSpinner(size: 46, spinning: spinning),
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

  /// When false the arc stops rotating and holds its current frame.
  final bool spinning;

  const CometSpinner({
    super.key,
    this.size = 46,
    this.color = const Color(0xE6000000),
    this.strokeWidth = 5,
    this.spinning = true,
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
    );
    if (widget.spinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant CometSpinner old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller.stop();
    }
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

/// Wraps [child] and paints a soft translucent red wavy rule beneath it, with
/// rounded caps — the "hand-drawn" underline under the POWERED BY LARAF line.
class _WavyUnderlined extends StatelessWidget {
  final Widget child;

  const _WavyUnderlined({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 4),
        CustomPaint(
          size: const Size(150, 7),
          painter: _WavyUnderlinePainter(
            // Translucent red: reads as ink, not a warning stripe.
            color: const Color(0xFFE05A5A).withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

/// A rounded-cap sine wave, drawn as a single stroked path so both ends get
/// the rounded terminal the request asked for.
class _WavyUnderlinePainter extends CustomPainter {
  final Color color;

  const _WavyUnderlinePainter({required this.color});

  static const double _strokeWidth = 2.4;
  static const double _amplitude = 2.6;
  static const double _wavelength = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final midY = size.height / 2;
    final path = Path()..moveTo(0, midY);
    // Step finely so the polyline reads as a smooth curve.
    const step = 1.0;
    for (double x = step; x <= size.width; x += step) {
      final y = midY + _amplitude * math.sin(2 * math.pi * x / _wavelength);
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavyUnderlinePainter old) =>
      old.color != color;
}
