import 'package:flutter/material.dart';

/// The app's signature header backdrop: the rounded-bottom gradient panel
/// shared by every screen's AppBar.
///
/// Screens use it as an AppBar `flexibleSpace` with a matching rounded-bottom
/// `shape` — the gradient is clipped to those corners. A `HeaderBackedAppBar`
/// wrapper that painted the gradient behind the whole square app-bar rectangle
/// (to hide the corner notch) was tried and REVERTED: the user rejected the
/// result ("верни как было"). The bare AppBar + clipped header is the intended
/// look.
///
/// It used to add a "premium" hairline specular highlight along the bottom
/// curve. On the light themes that 1px white line read as a stray STRIPE
/// creeping out under the header / the pill bar ("снизу вылезает полоса") on
/// every screen, so it was removed — the gradient alone carries the header.
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
          ],
        ),
      ),
    );
  }
}
