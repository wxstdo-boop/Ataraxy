import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис для автоэкспорта данных в Downloads каждые N минут.
class AutoExportService {
  static const String _enabledKey = 'auto_export_enabled';
  static const String _lastExportKey = 'auto_export_last_time';
  static const Duration _interval = Duration(hours: 1);
  
  bool _isEnabled = false;
  DateTime? _lastExport;
  
  // Callback экспорта
  Future<String> Function()? _exportCallback;
  
  static final AutoExportService _instance = AutoExportService._internal();
  factory AutoExportService() => _instance;
  AutoExportService._internal();
  
  void setExportCallback(Future<String> Function() callback) {
    _exportCallback = callback;
  }
  
  Future<void> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_enabledKey) ?? false;
      final lastExportMs = prefs.getInt(_lastExportKey);
      if (lastExportMs != null) {
        _lastExport = DateTime.fromMillisecondsSinceEpoch(lastExportMs);
      }
    } catch (e) {
      debugPrint('AutoExportService: failed to load state: $e');
    }
  }
  
  bool get enabled => _isEnabled;
  DateTime? get lastExport => _lastExport;
  
  Future<void> enable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);
      _isEnabled = true;
      await _performExport();
    } catch (e) {
      debugPrint('AutoExportService: enable error: $e');
    }
  }
  
  Future<void> disable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, false);
      _isEnabled = false;
    } catch (e) {
      debugPrint('AutoExportService: disable error: $e');
    }
  }
  
  Future<bool> checkAndExport() async {
    if (!_isEnabled) return false;
    
    final now = DateTime.now();
    if (_lastExport == null || now.difference(_lastExport!) >= _interval) {
      await _performExport();
      return true;
    }
    return false;
  }
  
  Future<void> _performExport() async {
    try {
      if (_exportCallback == null) {
        debugPrint('AutoExportService: no export callback set');
        return;
      }
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'ataraxy_backup_$timestamp.json';
      final json = await _exportCallback!();

      // Save into Downloads/Ataraxy (creating the folder if needed).
      // getApplicationDocumentsDirectory() on Android points at
      // /storage/emulated/0/Android/data/.../files — the user's real
      // Downloads is its parent's parent + /Download (public storage).
      // We create a dedicated Ataraxy subfolder so backups never clutter
      // the root of Downloads.
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsRoot = Directory('${appDir.parent.path}/Download');
      final targetDir = Directory('${downloadsRoot.path}/Ataraxy');
      try {
        if (!targetDir.existsSync()) targetDir.createSync(recursive: true);
        final file = File('${targetDir.path}/$filename');
        await file.writeAsString(json);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            _lastExportKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('AutoExportService: exported to ${targetDir.path}/$filename');
        return;
      } catch (e) {
        debugPrint('AutoExportService: Downloads/Ataraxy write failed: $e');
      }

      // Fallback to app documents directory if public Downloads is
      // unreachable (permission denied on some devices).
      debugPrint('AutoExportService: falling back to app docs');
      final file = File('${appDir.path}/$filename');
      await file.writeAsString(json);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastExportKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('AutoExportService: exported to ${appDir.path}/$filename');
    } catch (e) {
      debugPrint('AutoExportService: export error: $e');
    }
  }
}
