// See lib/compat/material.dart for why the legacy Material library is still
// in use. `GlobalMaterialLocalizations` and `GlobalCupertinoLocalizations` are
// deprecated in favour of the `material_ui` / `cupertino_ui` copies, which are
// distinct types and cannot be swapped in yet. Referencing the deprecated
// classes through these aliases keeps the deprecation in one place instead of
// at every `MaterialApp` in the app and the tests.
//
// ignore_for_file: deprecated_member_use
import 'package:flutter/widgets.dart' show LocalizationsDelegate;
import 'package:flutter_localizations/flutter_localizations.dart' as legacy;

export 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;

const LocalizationsDelegate<dynamic> materialLocalizationsDelegate =
    legacy.GlobalMaterialLocalizations.delegate;

const LocalizationsDelegate<dynamic> cupertinoLocalizationsDelegate =
    legacy.GlobalCupertinoLocalizations.delegate;
