// StepCounterService.kt
package com.example.kid_loop

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.onesignal.OneSignal
import java.text.SimpleDateFormat
import java.util.*

class StepCounterService : Service(), SensorEventListener {

    companion object {
        const val TAG = "KidLoop"
    }

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private var lastStepCount = -1
    private var lastStepTime: Long = 0
    private var walkStartTime: Long = 0
    private var currentSessionSeconds = 0
    private var currentSessionSteps = 0
    private var isInWalkSession = false
    private lateinit var wakeLock: PowerManager.WakeLock
    private lateinit var prefs: SharedPreferences

    private val PAUSE_THRESHOLD = 120_000L
    private val INACTIVITY_CHECK_INTERVAL = 30_000L

    private var inactivityHandler: Handler? = null
    private var inactivityRunnable: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "StepCounterService onCreate")

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "KidLoop:StepCounter")
        wakeLock.acquire(24 * 60 * 60 * 1000L)

        createNotificationChannel()
        startForeground(1, createNotification())

        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        loadState()
        startInactivityChecker()

        // Логиним пользователя в OneSignal если userId уже есть
        val userId = prefs.getString("flutter.user_id", null)
        if (userId != null) {
            OneSignal.login(userId)
            Log.d(TAG, "✅ OneSignal login: $userId")
        }

        Log.i(TAG, "✅ StepCounterService запущен (шагомер + OneSignal)")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra("user_id")?.let { userId ->
            prefs.edit().putString("flutter.user_id", userId).apply()
            Log.d(TAG, "🆔 userId обновлён: $userId")

            // Логиним пользователя в OneSignal
            OneSignal.login(userId)
            Log.d(TAG, "✅ OneSignal login: $userId")
        }
        stepSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "StepCounterService onDestroy")
        sensorManager.unregisterListener(this)
        inactivityRunnable?.let { inactivityHandler?.removeCallbacks(it) }
        if (::wakeLock.isInitialized) wakeLock.release()
        saveDailyStats()
        saveState()
        super.onDestroy()
    }

    private fun loadState() {
        lastStepCount = prefs.getInt("flutter.last_step_count", -1)
        lastStepTime = prefs.getLong("flutter.last_step_time", 0)
        walkStartTime = prefs.getLong("flutter.walk_start_time", 0)
        currentSessionSeconds = prefs.getInt("flutter.current_session_seconds", 0)
        currentSessionSteps = prefs.getInt("flutter.current_session_steps", 0)
        isInWalkSession = prefs.getBoolean("flutter.is_in_walk_session", false)
    }

    private fun saveState() {
        prefs.edit().apply {
            putInt("flutter.last_step_count", lastStepCount)
            putLong("flutter.last_step_time", lastStepTime)
            putLong("flutter.walk_start_time", walkStartTime)
            putInt("flutter.current_session_seconds", currentSessionSeconds)
            putInt("flutter.current_session_steps", currentSessionSteps)
            putBoolean("flutter.is_in_walk_session", isInWalkSession)
            apply()
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_STEP_COUNTER) return

        val currentSteps = event.values[0].toInt()
        val now = System.currentTimeMillis()

        if (lastStepCount == -1) {
            lastStepCount = currentSteps
            saveState()
            return
        }

        if (currentSteps < lastStepCount) {
            lastStepCount = currentSteps
            saveState()
            return
        }

        if (currentSteps == lastStepCount) return

        val newSteps = currentSteps - lastStepCount
        if (newSteps > 500) {
            lastStepCount = currentSteps
            saveState()
            return
        }

        lastStepCount = currentSteps

        if (!isInWalkSession) {
            startWalkSession(now)
        } else {
            val diff = if (lastStepTime > 0) now - lastStepTime else PAUSE_THRESHOLD + 1
            if (diff < PAUSE_THRESHOLD && diff > 0) {
                currentSessionSeconds += (diff / 1000).toInt()
            } else if (diff >= PAUSE_THRESHOLD) {
                endWalkSession(now)
                startWalkSession(now)
            }
        }

        currentSessionSteps += newSteps
        lastStepTime = now
        updateCounters(newSteps)
        saveState()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun startWalkSession(timestamp: Long) {
        isInWalkSession = true
        walkStartTime = timestamp
        lastStepTime = timestamp
        currentSessionSeconds = 0
        currentSessionSteps = 0
        saveState()
    }

    private fun endWalkSession(timestamp: Long) {
        if (walkStartTime == 0L) return
        val durationSeconds = ((timestamp - walkStartTime) / 1000).toInt()
        val totalSeconds = maxOf(currentSessionSeconds, durationSeconds)
        val activeMinutes = if (totalSeconds >= 60) (totalSeconds / 60) else 1
        addActiveMinutes(activeMinutes)
        saveDailyStats()
        isInWalkSession = false
        walkStartTime = 0L
        currentSessionSeconds = 0
        currentSessionSteps = 0
        saveState()
    }

    private fun saveDailyStats() {
        val calendar = Calendar.getInstance()
        val todayKey = "flutter.stats_${calendar.get(Calendar.YEAR)}_${calendar.get(Calendar.MONTH) + 1}_${calendar.get(Calendar.DAY_OF_MONTH)}"
        prefs.edit()
            .putInt(todayKey, prefs.getInt("flutter.today_steps", 0))
            .putInt("${todayKey}_minutes", prefs.getInt("flutter.active_minutes", 0))
            .apply()
    }

    private fun updateCounters(newSteps: Int) {
        val todayDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val lastDate = prefs.getString("flutter.last_date", "") ?: ""
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, -1)
        val yesterdayStr = "${calendar.get(Calendar.YEAR)}_${calendar.get(Calendar.MONTH) + 1}_${calendar.get(Calendar.DAY_OF_MONTH)}"

        if (lastDate != todayDate && lastDate.isNotEmpty()) {
            prefs.edit()
                .putInt("flutter.stats_$yesterdayStr", prefs.getInt("flutter.today_steps", 0))
                .putInt("flutter.stats_${yesterdayStr}_minutes", prefs.getInt("flutter.active_minutes", 0))
                .apply()
        }

        val newTodaySteps = if (lastDate != todayDate) newSteps else prefs.getInt("flutter.today_steps", 0) + newSteps

        if (lastDate != todayDate) {
            prefs.edit().putInt("flutter.active_minutes", 0).apply()
        }

        prefs.edit().apply {
            putString("flutter.last_date", todayDate)
            putInt("flutter.today_steps", newTodaySteps)
            putInt("flutter.weekly_steps", prefs.getInt("flutter.weekly_steps", 0) + newSteps)
            putInt("flutter.monthly_${calendar.get(Calendar.YEAR)}_${calendar.get(Calendar.MONTH) + 1}",
                prefs.getInt("flutter.monthly_${calendar.get(Calendar.YEAR)}_${calendar.get(Calendar.MONTH) + 1}", 0) + newSteps)
            putInt("flutter.total_steps", prefs.getInt("flutter.total_steps", 0) + newSteps)
            apply()
        }

        saveDailyStats()
        updateNotification("$newTodaySteps шагов сегодня")
    }

    private fun addActiveMinutes(minutes: Int) {
        prefs.edit()
            .putInt("flutter.active_minutes", prefs.getInt("flutter.active_minutes", 0) + minutes)
            .apply()
    }

    private fun startInactivityChecker() {
        inactivityHandler = Handler(Looper.getMainLooper())
        inactivityRunnable = Runnable {
            if (isInWalkSession && lastStepTime > 0) {
                if (System.currentTimeMillis() - lastStepTime >= PAUSE_THRESHOLD) {
                    endWalkSession(System.currentTimeMillis())
                }
            }
            inactivityHandler?.postDelayed(inactivityRunnable!!, INACTIVITY_CHECK_INTERVAL)
        }
        inactivityHandler?.postDelayed(inactivityRunnable!!, INACTIVITY_CHECK_INTERVAL)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "step_counter",
                "Шагомер",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Подсчёт шагов"
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pi = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, "step_counter")
            .setContentTitle("KidLoop")
            .setContentText("Шаги считаются...")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(text: String) {
        try {
            val n = NotificationCompat.Builder(this, "step_counter")
                .setContentTitle("KidLoop")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_menu_compass)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
            startForeground(1, n)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка обновления уведомления: ${e.message}")
        }
    }
}