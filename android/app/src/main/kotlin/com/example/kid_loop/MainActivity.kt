package com.example.kid_loop

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.kid_loop/step_counter"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startStepCounterService()
                    result.success(true)
                }
                "stopService" -> {
                    val intent = Intent(this, StepCounterService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "requestIgnoreBattery" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "isServiceRunning" -> {
                    result.success(isStepCounterServiceRunning())
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            methodChannel?.setMethodCallHandler(null)
        } catch (e: Exception) {
            // Игнорируем ошибки при очистке
        }
        methodChannel = null
        super.onDestroy()
    }

    private fun startStepCounterService() {
        try {
            val intent = Intent(this, StepCounterService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            println("✅ StepCounterService запущен")
        } catch (e: Exception) {
            println("❌ Ошибка запуска StepCounterService: ${e.message}")
        }
    }

    private fun isStepCounterServiceRunning(): Boolean {
        return try {
            val manager = getSystemService(android.content.Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            manager.getRunningServices(Integer.MAX_VALUE).any {
                it.service.className == StepCounterService::class.java.name
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val pm = getSystemService(POWER_SERVICE) as PowerManager
                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                }
            } catch (e: Exception) {
                println("❌ Ошибка запроса оптимизации батареи: ${e.message}")
            }
        }
    }
}