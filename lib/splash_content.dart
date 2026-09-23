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
          // Three-stop diagonal wash: primary glow up top melting into the
          // tertiary depth below — richer than a flat two-color ramp.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.55, 1.0],
            colors: [
              scheme.primary.withValues(alpha: a),
              Color.lerp(scheme.primary, scheme.tertiary, 0.45)!
                  .withValues(alpha: a),
              scheme.tertiary.withValues(alpha: a),
            ],
          ),
        ),
        child: Stack(
          children: [
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
                    // Squircle logo tile: softer glow ring + layered shadow
                    // instead of the old hard black26 drop.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.white.withValues(alpha: 0.86),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.25),
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
                    Text(
                      'BY WETIDOM',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                        strokeWidth: 3.5,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
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
