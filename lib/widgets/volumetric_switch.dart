import 'package:flutter/material.dart';

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

  const VolumetricSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.thumbColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = activeTrackColor ?? scheme.primary;
    final inactive = inactiveTrackColor ?? scheme.surfaceContainerHighest;
    final thumb = thumbColor ?? Colors.white;

    return GestureDetector(
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
            // Inner highlight on top edge for 3D glass effect
            BoxShadow(
              color: Colors.white.withValues(alpha: value ? 0.25 : 0.15),
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
    return ListTile(
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
      ),
      onTap: () => onChanged(!value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
