package com.example.kid_loop

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class StepCounterBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.ACTION_SHUTDOWN") {

            // Запускаем сервис при загрузке устройства
            val serviceIntent = Intent(context, StepCounterService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}