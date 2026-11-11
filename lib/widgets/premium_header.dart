import 'package:flutter/material.dart';

/// Wraps an [AppBar] so the header gradient is painted behind the WHOLE
/// app-bar rectangle, not just inside its rounded shape.
///
/// The screens give the AppBar a `shape` with rounded bottom corners, and the
/// AppBar's own Material is clipped to that shape. The notch left by the
/// rounding then shows whatever sits behind the AppBar — the scaffold — as a
/// pale wedge poking out from under the header on every screen ("белый фон
/// снизу плашки выпирает из округлённых углов"). Painting the SAME gradient
/// on a square rectangle behind the bar fills those corners with the exact
/// colour the gradient has there, so the seam disappears and the header reads
/// as one clean panel in every theme.
class HeaderBackedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Color> colors;
  final AppBar appBar;

  const HeaderBackedAppBar({
    super.key,
    required this.colors,
    required this.appBar,
  });

  @override
  Size get preferredSize => appBar.preferredSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: appBar,
    );
  }
}

/// The app's signature header backdrop: the rounded-bottom gradient panel
/// shared by every screen's AppBar.
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
