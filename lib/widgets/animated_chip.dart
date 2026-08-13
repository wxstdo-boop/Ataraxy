import 'package:flutter/material.dart';

/// A [Chip] that animates in on mount (fade + scale) and, when the user taps
/// its delete button, animates out (fade + shrink) BEFORE [onDeleted] runs.
///
/// Used for tags and custom dream signs in the entry editor so adding and
/// removing them feels smooth instead of snapping.
class AnimatedChip extends StatefulWidget {
  final String label;
  final bool withHash;
  final VoidCallback onDeleted;

  const AnimatedChip({
    super.key,
    required this.label,
    required this.onDeleted,
    this.withHash = true,
  });

  @override
  State<AnimatedChip> createState() => _AnimatedChipState();
}

class _AnimatedChipState extends State<AnimatedChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      // Start hidden so the mount animation is visible (fade + pop-in).
      value: 0.0,
    );
    _scale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  Future<void> _delete() async {
    await _ctrl.reverse();
    if (mounted) widget.onDeleted();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Chip(
          label: Text(widget.withHash ? '#${widget.label}' : widget.label),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
          onDeleted: _delete,
        ),
      ),
    );
  }
}
