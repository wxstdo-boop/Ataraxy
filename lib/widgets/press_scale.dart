import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps any tappable child and gives it a smooth "press dimple": while the
/// finger is held the child eases down to [scale] and springs back on release.
///
/// Used on controls that are not [PressableIconButton] (the onboarding Start
/// button, close buttons, pills) so the whole app answers a touch the same
/// soft, expensive-feeling way.
///
/// The child keeps its own tap handling — this widget only tracks the pressed
/// state (so a button inside still receives its tap), optionally firing a
/// light haptic the moment the finger lands.
class PressScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;
  final bool haptic;

  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.94,
    this.duration = const Duration(milliseconds: 180),
    this.haptic = false,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (mounted && v != _pressed) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (widget.haptic) HapticFeedback.lightImpact();
        _set(true);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
