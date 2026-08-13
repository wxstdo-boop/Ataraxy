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
      // On Android, try to get the real Downloads directory.
      // Fall back to app documents if public Downloads is unreachable.
      Directory? targetDir;
      String finalPath = '';
      
      try {
        // Try to get the actual Downloads directory
        // Common paths: /storage/emulated/0/Download or /sdcard/Download
        final commonPaths = [
          '/storage/emulated/0/Download',
          '/sdcard/Download',
          '/storage/emulated/0/Downloads',
        ];
        
        for (final path in commonPaths) {
          final testDir = Directory(path);
          if (await testDir.exists()) {
            targetDir = Directory('${testDir.path}/Ataraxy');
            if (!targetDir.existsSync()) {
              targetDir.createSync(recursive: true);
            }
            finalPath = '${targetDir.path}/$filename';
            break;
          }
        }
        
        if (targetDir == null) {
          // Fallback: try to use getDownloadsDirectory from path_provider
          try {
            final downloadsDir = await getDownloadsDirectory();
            if (downloadsDir != null) {
              targetDir = Directory('${downloadsDir.path}/Ataraxy');
              if (!targetDir.existsSync()) {
                targetDir.createSync(recursive: true);
              }
              finalPath = '${targetDir.path}/$filename';
            }
          } catch (e) {
            debugPrint('AutoExportService: getDownloadsDirectory failed: $e');
          }
        }
        
        if (targetDir == null) {
          // Last fallback: try the old method
          final appDir = await getApplicationDocumentsDirectory();
          targetDir = Directory('${appDir.path}/Ataraxy');
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
          finalPath = '${targetDir.path}/$filename';
        }
        
        final file = File(finalPath);
        await file.writeAsString(json);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastExportKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('AutoExportService: exported to $finalPath');
        return;
      } catch (e) {
        debugPrint('AutoExportService: write failed: $e');
      }
      
      // If all else fails, try app documents
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fallbackDir = Directory('${appDir.path}/Ataraxy');
        if (!fallbackDir.existsSync()) {
          fallbackDir.createSync(recursive: true);
        }
        final file = File('${fallbackDir.path}/$filename');
        await file.writeAsString(json);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastExportKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('AutoExportService: exported to ${fallbackDir.path}/$filename');
      } catch (e) {
        debugPrint('AutoExportService: final fallback write failed: $e');
      }
    } catch (e) {
      debugPrint('AutoExportService: export error: $e');
    }
  }
}
