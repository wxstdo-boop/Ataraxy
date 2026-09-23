import 'package:flutter/material.dart';

import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/theme/app_theme.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
    Widget build(BuildContext context) {
    // Soft rose/lilac instead of the neon #FF9FB6 / #B9A7FF pair.
    final pink = AppAccents.roseLight;
    final lavender = AppAccents.lilac;
    // This screen paints on a near-black backdrop, so its type is a fixed
    // light warm grey — `scheme.onSurface` would be dark ink on a light theme
    // and the title would vanish.
    const onSurface = Color(0xFFEDE7E2);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Lifted off pure black: #000000 next to a bright icon reads as a
            // hole punched in the display.
            colors: [Color(0xFF100F13), Color(0xFF1A181D)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [pink.withValues(alpha: 0.45), lavender.withValues(alpha: 0.55)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/ataraxy.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        cacheWidth: 96,
                        cacheHeight: 96,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    L.tr(context, 'launchTitle'),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'BY WETIDOM',
                    style: TextStyle(
                      fontSize: 14,
                      color: onSurface,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
