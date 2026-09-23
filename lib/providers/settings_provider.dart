import 'package:flutter/material.dart';
import 'package:ataraxy/models/settings.dart';

class SettingsProvider extends InheritedWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;

  const SettingsProvider({
    super.key,
    required this.settings,
    required this.onChanged,
    required super.child,
  });

  static SettingsProvider of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
    assert(result != null, 'No SettingsProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(SettingsProvider oldWidget) =>
      oldWidget.settings != settings;
}
