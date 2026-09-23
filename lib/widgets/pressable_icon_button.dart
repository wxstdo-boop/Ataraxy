import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Icon button with a soft, tactile press: while the finger is held the icon
/// gently scales down into a faint halo (a "dimple"), releasing springs it
/// back in 220ms. Replaces the raw InkWell splash — which flashed a hard grey
/// block on low-end GPUs — with a smooth, expensive-feeling press. Long-press
/// and tooltip supported.
class PressableIconButton extends StatefulWidget {
  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double size;

  const PressableIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.onLongPress,
    this.size = 40,
  });

  @override
  State<PressableIconButton> createState() => _PressableIconButtonState();
}

class _PressableIconButtonState extends State<PressableIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget inner = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onPressed?.call();
          },
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onLongPress!();
                },
          onHighlightChanged: (v) {
            if (mounted && v != _pressed) setState(() => _pressed = v);
          },
          borderRadius: BorderRadius.circular(widget.size / 2),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: AnimatedScale(
            scale: _pressed ? 0.93 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.onSurface.withValues(
                  alpha: _pressed ? 0.10 : 0.0,
                ),
              ),
              child: Center(child: widget.icon),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      inner = Tooltip(message: widget.tooltip!, child: inner);
    }
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      child: inner,
    );
  }
}