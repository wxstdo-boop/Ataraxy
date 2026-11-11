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
                          // Decode at PHYSICAL resolution (96dp x DPR) with a
                          // high-quality filter, so the crescent edge stays
                          // razor sharp instead of being resampled from the
                          // full-size bitmap every frame.
                          cacheWidth:
                              (96 * MediaQuery.devicePixelRatioOf(context))
                                  .ceil(),
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Brand wordmark: italic display cut with a trailing
                    // period, and each glyph writes itself in on a stagger —
                    // then erases again in reverse as the splash melts away, so
                    // the letters both appear AND disappear smoothly.
                    AnimatedLetters(
                      '${L.tr(context, 'launchTitle')}.',
                      erase: true,
                      // The write-on only begins once the splash's first frame
                      // is on screen (startDelay) and then proceeds slowly and
                      // with a clear per-letter stagger, so the wordmark reads
                      // as being written by hand — this is the recurring
                      // "буквы пишутся как обычно" complaint. It finishes inside
                      // the opaque hold, then the letters erase in step with the
                      // fade.
                      startDelay: const Duration(milliseconds: 140),
                      duration: const Duration(milliseconds: 380),
                      delay: const Duration(milliseconds: 42),
                      outDelay: const Duration(milliseconds: 120),
                      outDuration: const Duration(milliseconds: 700),
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontStyle: FontStyle.italic,
                        fontSize: 38,
                        // SemiBold italic (Cormorant ships up to Bold). The
                        // wordmark used to be Bold plus four zero-blur white
                        // shadows that faked an even heavier cut — the user
                        // read that stack as too fat ("имя тоньше надо"). A
                        // real lighter cut carries the same elegance with no
                        // faux-bold ringing around every glyph.
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.6,
                        shadows: const [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 14,
                            offset: Offset(0, 3),
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

    // One unbroken, endless loop. The arc geometry is FIXED in a local frame
    // and the whole canvas is rotated by `phase` — the shader sector never
    // moves, so there is no per-lap seam.
    //
    // Why not feed a growing `startAngle` to the SweepGradient: `ui.Gradient`
    // normalises any angle outside [0, 2π] back into range, so once
    // `startAngle + sweep` crossed 2π the gradient sector wrapped to the
    // complementary arc while `drawArc` kept painting the original one — the
    // lit head and the dark tail swapped sides for one frame. That visible
    // flip every revolution is exactly the "snake starts a second lap"
    // complaint. Rotating the canvas keeps the shader in [0, sweep], so
    // `startAngle` is always in range and the motion never seams.
    final phase = t.value * 2 * math.pi;
    const sweep = 4.6; // ~264°: a long, calm comet

    // Head bright, tail melting to nothing: a real "snake" (the old gradient
    // was symmetric — a bright MIDDLE fading at both ends — which read as a
    // rotating dash, not a comet). The tail (alpha 0) sits at 0, the head at
    // `sweep`; `TileMode.clamp` extends those edge colours outside the sector,
    // but only [0, sweep] is ever painted.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase);
    final localRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    paint.shader = SweepGradient(
      startAngle: 0,
      endAngle: sweep,
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.10),
        color.withValues(alpha: 0.45),
        color,
      ],
      stops: const [0.0, 0.45, 0.78, 1.0],
    ).createShader(localRect);
    canvas.drawArc(localRect, 0, sweep, false, paint);
    canvas.restore();
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
    // IntrinsicWidth + stretch makes the rule hug the LABEL's width instead of
    // spanning the whole row (the previous LayoutBuilder reported the incoming
    // max width — the full screen — so the wave stretched edge to edge).
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          const SizedBox(height: 3),
          SizedBox(
            height: 6,
            child: CustomPaint(
              painter: _WavyUnderlinePainter(
                // Translucent red: reads as ink, not a warning stripe. Kept
                // LOW-alpha so it sits UNDER the text as a faint flourish —
                // the user asked for it to be more transparent, not a bold
                // stripe ("подчеркивание красное прозрачнее должно быть").
                color: const Color(0xFFE05A5A).withValues(alpha: 0.34),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded-cap sine wave, drawn as a single stroked path so both ends get
/// the rounded terminal the request asked for. Denser (tighter wavelength,
/// thicker stroke, smaller amplitude) so it reads as a fine hand-drawn rule
/// rather than a loose scribble.
class _WavyUnderlinePainter extends CustomPainter {
  final Color color;

  const _WavyUnderlinePainter({required this.color});

  static const double _strokeWidth = 1.8;
  static const double _amplitude = 1.7;
  static const double _wavelength = 9;

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
    const step = 0.8;
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
