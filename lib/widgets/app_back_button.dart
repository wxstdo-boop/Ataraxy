import 'package:flutter/material.dart';

import 'package:ataraxy/widgets/pressable_icon_button.dart';

/// AppBar leading back button shared by every screen.
///
/// Replaces the implicit Material [BackButton]: that one ships a localized
/// "Назад" tooltip that popped over the arrow on long-press, and it has no
/// press recoil. This uses [PressableIconButton] — no visual tooltip, the same
/// soft dimple as the rest of the app's icon buttons — while keeping an
/// accessible name for screen readers via [MaterialLocalizations].
class AppBackButton extends StatelessWidget {
  /// Custom handler; defaults to popping the current route.
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return PressableIconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
