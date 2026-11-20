import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import 'github_update_service.dart';

/// Background check for a newer GitHub release.
///
/// The updater only ran when the user tapped "Обновление Ataraxy" in Settings,
/// so most installs never learned a release existed — the pipeline published
/// 1.3.32 while a device sat on 1.3.31 with no prompt. This runs once at
/// startup and at most once a day, silently: offline/rate-limit failures are
/// swallowed and only a genuinely newer release surfaces to the UI.
class UpdateChecker {
  UpdateChecker({GithubUpdateService? service})
      : _service = service ??
            GithubUpdateService(currentVersion: AppVersion.current);

  static const _lastCheckKey = 'update_last_check';
  static const _interval = Duration(hours: 24);

  /// Tests set this to false. `flutter_test` already blocks HTTP (the request
  /// comes back as a 400), but the check would then log a failure on every
  /// widget test that mounts HomeScreen.
  static bool enabled = true;

  final GithubUpdateService _service;

  /// Returns the newer release, or null when the build is current, the check
  /// is not due yet, or the network/API failed.
  Future<GithubRelease?> checkIfDue() async {
    if (!enabled) return null;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _interval.inMilliseconds) return null;

    try {
      return await _service.checkForUpdate();
    } catch (error) {
      debugPrint('[Update] check failed: $error');
      return null;
    } finally {
      // Record the attempt, not only a success: a device that is offline for
      // weeks must not hit the API on every launch.
      await prefs.setInt(_lastCheckKey, now);
      _service.close();
    }
  }

  /// Android can install the downloaded APK in place; every other platform
  /// only gets the release page.
  static bool get canSelfInstall =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
