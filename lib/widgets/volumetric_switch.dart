import 'package:flutter/material.dart';

import 'package:ataraxy/widgets/press_scale.dart';

/// A volumetric toggle switch with a gradient track, rounded white thumb,
/// and a subtle spring animation.  Drop-in replacement for Material [Switch].
///
/// ```dart
/// VolumetricSwitch(value: _enabled, onChanged: (v) => setState(() => _enabled = v))
/// ```
class VolumetricSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;
  final Color? thumbColor;

  /// Gives the switch its own press dimple. On by default so the control
  /// answers a touch like every other button; [VolumetricSwitchListTile] turns
  /// it off because its row already dips the whole tile.
  final bool dimple;

  const VolumetricSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.thumbColor,
    this.dimple = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = activeTrackColor ?? scheme.primary;
    final inactive = inactiveTrackColor ?? scheme.surfaceContainerHighest;
    final thumb = thumbColor ?? Colors.white;

    final switchBody = GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 34,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: value
                ? [active, HSLColor.fromColor(active).withLightness(
                    (HSLColor.fromColor(active).lightness + 0.08).clamp(0, 1),
                  ).toColor()]
                : [
                    inactive,
                    HSLColor.fromColor(inactive).withLightness(
                      (HSLColor.fromColor(inactive).lightness - 0.04).clamp(0, 1),
                    ).toColor(),
                  ],
          ),
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: value
                  ? active.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            // Subtle inner shading for depth. Was a WHITE top-edge highlight,
            // which on the light themes read as a white rim inside the control
            // (the same "белые полосы" trap as elsewhere) — a faint dark shade
            // gives the depth without any white overlay.
            BoxShadow(
              color: Colors.black.withValues(alpha: value ? 0.10 : 0.08),
              blurRadius: 2,
              offset: const Offset(0, 1),
              spreadRadius: -1,
            ),
          ],
        ),
        child: Stack(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [thumb, thumb.withValues(alpha: 0.9)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                    // Top highlight for 3D dome effect
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.7),
                      blurRadius: 1,
                      offset: const Offset(-1, -1),
                      spreadRadius: -0.5,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: Tween(begin: 0.6, end: 1.0).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                    ),
                    child: child,
                  ),
                  child: Icon(
                    key: ValueKey(value),
                    value ? Icons.check_rounded : Icons.close_rounded,
                    size: 16,
                    color: value ? active.withValues(alpha: 0.8) : Colors.grey.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return dimple
        ? PressScale(scale: 0.9, haptic: true, child: switchBody)
        : switchBody;
  }
}

/// A [SwitchListTile] variant that uses [VolumetricSwitch] for the trailing
/// widget — drop-in upgrade for settings screens.
class VolumetricSwitchListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;
  final Color? activeTrackColor;

  const VolumetricSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.leading,
    this.activeTrackColor,
  });

  @override
  Widget build(BuildContext context) {
    // Wrapped in PressScale so a switch row dips on touch like every other
    // control — the rows were the last flat, ripple-only taps in Settings.
    return PressScale(
      scale: 0.98,
      haptic: true,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: leading,
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        subtitle: subtitle != null
            ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
            : null,
        trailing: VolumetricSwitch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: activeTrackColor,
          // The whole row already dips below; keep the switch from dimpling
          // twice.
          dimple: false,
        ),
        onTap: () => onChanged(!value),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
