import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:ataraxy/models/settings.dart';

class SettingsService {
  static const String _boxName = 'app_settings';

  Future<Box<String>> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  Future<AppSettings> load() async {
    final box = await _openBox();
    final raw = box.get('settings');
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(AppSettings settings) async {
    final box = await _openBox();
    await box.put('settings', jsonEncode(settings.toJson()));
  }

  Future<void> reset() async {
    final box = await _openBox();
    await box.delete('settings');
  }
}
