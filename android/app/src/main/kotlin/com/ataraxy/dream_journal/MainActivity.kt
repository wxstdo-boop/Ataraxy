package com.ataraxy.dream_journal

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Returns the device's real IANA timezone id (e.g. "Europe/Moscow").
        // Dart's DateTime.timeZoneName can report "UTC" on some MIUI builds,
        // which made scheduled reminders fire hours late.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ataraxy/timezone")
            .setMethodCallHandler { call, result ->
                if (call.method == "getTimeZone") {
                    result.success(TimeZone.getDefault().id)
                } else {
                    result.notImplemented()
                }
            }
    }
}
