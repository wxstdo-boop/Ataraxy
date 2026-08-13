/// Stub used on non-web platforms (Android / iOS / desktop / tests), where
/// `dart:js_interop` / `package:web` are not available. All helpers are
/// no-ops — the real implementation lives in web_notifications.dart and is
/// selected via conditional import on `dart.library.js_interop`.
library;

/// Browser notification permission — always false off-web.
Future<bool> webRequestPermission() async => false;

/// Shows a browser notification — no-op off-web.
void webShowNotification(String title, String body) {}
