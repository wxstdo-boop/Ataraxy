import 'package:flutter/material.dart';

/// The app's avatar: the actual app artwork (assets/ataraxy.png — the peach
/// crescent-moon icon) inside a volumetric gradient ring + soft glow.
///
/// The ring's colors are pulled from the ACTIVE THEME (primary → tertiary
/// sweep) and the glow uses scheme.primary, so the avatar visibly matches the
/// current theme in Settings and About — while the artwork itself stays the
/// original app image.
class AppAvatar extends StatelessWidget {
  final double radius;

  const AppAvatar({super.key, this.radius = 44});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Decode at PHYSICAL resolution (logical size x DPR): cacheWidth in
    // logical px decoded the 512px art down to ~70px and then upscaled it
    // on screen — that's what made the avatar look soft. Exact-size decode
    // is both hyper-sharp and memory-cheap.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final facePx = (radius * 1.6 * dpr).ceil();

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            scheme.primary,
            scheme.secondary,
            scheme.tertiary,
            scheme.primary,
          ],
          stops: const [0, 0.35, 0.7, 1],
        ),
        boxShadow: [
          // Outer colored glow — gives the "volumetric" lift.
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: radius * 0.55,
            offset: Offset(0, radius * 0.22),
            spreadRadius: 0,
          ),
          // A crisp inner ring highlight (top-left) for the glassy edge.
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.5),
            blurRadius: 2,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      padding: EdgeInsets.all(radius * 0.10),
      // Inner face: the original app artwork, framed with a thin theme-tinted
      // ring so it reads as one polished medallion on every theme.
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.35),
            width: radius * 0.05,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: radius * 0.16,
              offset: Offset(0, radius * 0.06),
            ),
          ],
        ),
        padding: EdgeInsets.all(radius * 0.06),
        child: ClipOval(
          child: Image.asset(
            'assets/ataraxy.png',
            width: radius * 1.6,
            height: radius * 1.6,
            fit: BoxFit.cover,
            cacheWidth: facePx,
            cacheHeight: facePx,
          ),
        ),
      ),
    );
  }
}
