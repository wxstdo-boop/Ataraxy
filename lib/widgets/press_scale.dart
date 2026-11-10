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

  /// When true the press-in and the recoil share [duration] (used by tests that
  /// assert a single scale transition); otherwise the dimple snaps in at
  /// [duration] and the recoil settles more slowly for a softer release.
  final bool symmetric;

  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.94,
    this.duration = const Duration(milliseconds: 130),
    this.haptic = false,
    this.symmetric = false,
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
        // Asymmetric timing: the dimple snaps in quickly under the finger, but
        // the recoil back to full size is slower and eased out, so the release
        // reads as smooth instead of a hard pop ("отдача уменьшения плавная").
        // `symmetric` opts out (tests assert one shared duration).
        duration: widget.symmetric
            ? widget.duration
            : (_pressed
                ? widget.duration
                : Duration(
                    milliseconds: widget.duration.inMilliseconds + 120,
                  )),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
