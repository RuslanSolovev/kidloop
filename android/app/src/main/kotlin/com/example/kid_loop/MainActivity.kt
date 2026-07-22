// MainActivity.kt
package com.example.kid_loop

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.onesignal.OneSignal
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val STEP_CHANNEL = "com.example.kid_loop/step_counter"
    private val NOTIF_CHANNEL = "kidloop/notifications"

    private var stepMethodChannel: MethodChannel? = null
    private var notifMethodChannel: MethodChannel? = null
    private var pendingNotificationPayload: String? = null

    companion object {
        private const val TAG = "MainActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Создаём каналы уведомлений ДО OneSignal
        createNotificationChannels()

        // Инициализация OneSignal
        OneSignal.initWithContext(this, "0083de8f-7ca0-4824-ac88-9c037278237e")
        Log.d(TAG, "✅ OneSignal инициализирован")

        // Логиним пользователя в OneSignal
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val userId = prefs.getString("flutter.user_id", null)
        if (userId != null) {
            OneSignal.login(userId)
            Log.d(TAG, "✅ OneSignal login: $userId")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        stepMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_CHANNEL)
        stepMethodChannel?.setMethodCallHandler { call, result ->
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

        notifMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
        notifMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "createChannels" -> {
                    createNotificationChannels()
                    result.success(true)
                }
                "requestPermissions" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val channelId = call.argument<String>("channelId") ?: "chat"
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val payload = call.argument<String>("payload") ?: ""
                    showNotification(id, channelId, title, body, payload)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        if (pendingNotificationPayload != null) {
            notifMethodChannel?.invokeMethod("notificationTap", pendingNotificationPayload)
            pendingNotificationPayload = null
        }

        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val payload = intent?.getStringExtra("notification_payload")
        if (payload != null) {
            if (notifMethodChannel != null) {
                notifMethodChannel?.invokeMethod("notificationTap", payload)
            } else {
                pendingNotificationPayload = payload
            }
        }
    }

    override fun onDestroy() {
        try {
            stepMethodChannel?.setMethodCallHandler(null)
            notifMethodChannel?.setMethodCallHandler(null)
        } catch (e: Exception) {}
        stepMethodChannel = null
        notifMethodChannel = null
        super.onDestroy()
    }

    private fun startStepCounterService() {
        try {
            val intent = Intent(this, StepCounterService::class.java)
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val userId = prefs.getString("flutter.user_id", null)
            intent.putExtra("user_id", userId)
            Log.d(TAG, "🚀 Запуск сервиса с userId=$userId")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка запуска StepCounterService: ${e.message}", e)
        }
    }

    private fun isStepCounterServiceRunning(): Boolean {
        return try {
            val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            manager.getRunningServices(Integer.MAX_VALUE).any {
                it.service.className == StepCounterService::class.java.name
            }
        } catch (e: Exception) { false }
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
                Log.e(TAG, "❌ Ошибка запроса оптимизации батареи: ${e.message}")
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channels = listOf(
                NotificationChannel("chat", "💬 Сообщения", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Уведомления о новых сообщениях"
                    enableVibration(true)
                },
                NotificationChannel("game", "🎮 Игры", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Уведомления о ходе в играх"
                    enableVibration(true)
                },
                NotificationChannel("trade", "🔄 Обмены", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Уведомления об обменах"
                }
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            channels.forEach { manager.createNotificationChannel(it) }
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
            }
        }
    }

    private fun showNotification(id: Int, channelId: String, title: String, body: String, payload: String) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("notification_payload", payload)
            }
            val pendingIntent = PendingIntent.getActivity(
                this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val notification = NotificationCompat.Builder(this, channelId)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
                ) {
                    NotificationManagerCompat.from(this).notify(id, notification)
                }
            } else {
                NotificationManagerCompat.from(this).notify(id, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка показа уведомления: ${e.message}")
        }
    }
}