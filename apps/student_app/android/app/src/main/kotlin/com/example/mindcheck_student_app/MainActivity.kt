package com.example.mindcheck_student_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val prefsChannelName = "plugins.flutter.io/shared_preferences"
    private val deviceChannelName = "mindcheck.campus/device"
    private val prefsFileName = "FlutterSharedPreferences"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Lưu trữ bền vững xuống đĩa thật trên Android cho SharedPreferences
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, prefsChannelName)
            .setMethodCallHandler { call, result ->
                val prefs = applicationContext.getSharedPreferences(prefsFileName, Context.MODE_PRIVATE)
                when (call.method) {
                    "getAll" -> {
                        result.success(prefs.all)
                    }
                    "setString" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<String>("value")
                        if (key != null) {
                            prefs.edit().putString(key, value).apply()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "setBool" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<Boolean>("value")
                        if (key != null && value != null) {
                            prefs.edit().putBoolean(key, value).apply()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "remove" -> {
                        val key = call.argument<String>("key")
                        if (key != null) {
                            prefs.edit().remove(key).apply()
                        }
                        result.success(true)
                    }
                    "clear" -> {
                        prefs.edit().clear().apply()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Mở trình gọi điện khẩn cấp 1 chạm (tel:115, tel:111) trên thiết bị di động (S21 - R3)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dialPhone" -> {
                        val rawPhone = call.argument<String>("phone")?.trim() ?: ""
                        if (rawPhone.isEmpty()) {
                            result.success(false)
                        } else {
                            try {
                                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                                    data = Uri.parse("tel:$rawPhone")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(dialIntent)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

