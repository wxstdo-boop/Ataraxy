import 'package:flutter/material.dart';

/// The app's signature header backdrop: the rounded-bottom gradient panel
/// shared by every screen's AppBar. Besides the theme gradient it adds the
/// two "premium" layers that make the header read as lit and volumetric
/// instead of a flat colour wash:
///   • a soft light sheen falling from the top edge (a glassy crown),
///   • a hairline specular highlight along the bottom curve.
/// Both layers are static (no animation) — a perpetual shimmer would repaint
/// the whole AppBar on every frame, which hurts low-end devices (Redmi).
class PremiumHeader extends StatelessWidget {
  final List<Color> colors;
  final double radius;

  const PremiumHeader({super.key, required this.colors, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(radius),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft light falling from the top edge.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5],
                  ),
                ),
              ),
            ),
            // Hairline specular highlight along the bottom curve.
            Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.40),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
