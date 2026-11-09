package com.ataraxy.dream_journal

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ataraxy/updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestInstallPermission" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                        ) {
                            result.success(true)
                        } else {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            )
                            startActivity(intent)
                            result.success(false)
                        }
                    }

                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("invalid_path", "APK path is required", null)
                            return@setMethodCallHandler
                        }

                        val updatesDirectory = File(cacheDir, "updates").canonicalFile
                        val apk = File(path).canonicalFile
                        if (!apk.path.startsWith("${updatesDirectory.path}${File.separator}") ||
                            !apk.isFile
                        ) {
                            result.error("invalid_apk", "Downloaded APK was not found", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                apk,
                            )
                            val intent = Intent(Intent.ACTION_INSTALL_PACKAGE)
                                .setData(uri)
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            startActivity(intent)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("install_failed", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
