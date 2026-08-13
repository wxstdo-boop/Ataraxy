import 'package:flutter/foundation.dart';

/// True while the splash overlay is on screen. The MUTILATED blood layer is
/// hidden during the splash so the theme's deep-red start screen stays clean
/// (blood appears only once the app content is visible).
final ValueNotifier<bool> splashActive = ValueNotifier(false);
