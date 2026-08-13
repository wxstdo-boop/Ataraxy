/// Web-only implementation of the notification helpers, selected by the
/// conditional import in notification_service.dart when
/// `dart.library.js_interop` is available. Uses the browser's
/// Notification API — see web_notifications_stub.dart for the off-web stub.
library;

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Requests the browser's notification permission. Resolves true when the
/// user grants it.
Future<bool> webRequestPermission() async {
  try {
    final status = await web.Notification.requestPermission().toDart;
    return status.toDart == 'granted';
  } catch (e) {
    debugPrint('[Notif] Web permission error: $e');
    return false;
  }
}

/// Shows a browser notification immediately.
void webShowNotification(String title, String body) {
  try {
    web.Notification(title, web.NotificationOptions(body: body));
    debugPrint('[Notif] Web: notification shown');
  } catch (e) {
    debugPrint('[Notif] Web show error: $e');
  }
}
