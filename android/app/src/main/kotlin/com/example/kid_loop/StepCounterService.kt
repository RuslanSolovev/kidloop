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
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.*

class StepCounterService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private var lastStepCount = -1  // Начинаем с -1 для первого определения
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

        println("✅ StepCounterService создан")
    }

    private fun loadState() {
        lastStepCount = prefs.getInt("flutter.last_step_count", -1)
        lastStepTime = prefs.getLong("flutter.last_step_time", 0)
        walkStartTime = prefs.getLong("flutter.walk_start_time", 0)
        currentSessionSeconds = prefs.getInt("flutter.current_session_seconds", 0)
        currentSessionSteps = prefs.getInt("flutter.current_session_steps", 0)
        isInWalkSession = prefs.getBoolean("flutter.is_in_walk_session", false)

        println("📂 Загружено: lastStepCount=$lastStepCount")
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

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stepSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            println("✅ Сенсор зарегистрирован")
        }
        return START_STICKY
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_STEP_COUNTER) return

        val currentSteps = event.values[0].toInt()
        val now = System.currentTimeMillis()

        // Первый запуск: запоминаем начальное значение сенсора
        if (lastStepCount == -1) {
            lastStepCount = currentSteps
            println("🔄 Инициализация сенсора: lastStepCount=$lastStepCount")
            saveState()
            return
        }

        // Сброс сенсора (перезагрузка телефона)
        if (currentSteps < lastStepCount) {
            println("🔄 Сброс сенсора: было $lastStepCount, стало $currentSteps")
            lastStepCount = currentSteps
            saveState()
            return
        }

        // Нет новых шагов
        if (currentSteps == lastStepCount) return

        val newSteps = currentSteps - lastStepCount

        // Слишком много шагов за раз - возможно глюк сенсора
        if (newSteps > 500) {
            println("⚠️ Слишком много шагов: $newSteps, игнорируем")
            lastStepCount = currentSteps
            saveState()
            return
        }

        println("🚶 +$newSteps шагов (всего сенсор: $currentSteps)")

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

    private fun startWalkSession(timestamp: Long) {
        isInWalkSession = true
        walkStartTime = timestamp
        lastStepTime = timestamp
        currentSessionSeconds = 0
        currentSessionSteps = 0

        saveActivityToHistory("🚶 Начало: ${formatTime(timestamp)}")
        saveState()
        updateNotification("🚶 Идём...")
    }

    private fun endWalkSession(timestamp: Long) {
        if (walkStartTime == 0L) return

        val durationSeconds = ((timestamp - walkStartTime) / 1000).toInt()
        val totalSeconds = maxOf(currentSessionSeconds, durationSeconds)
        val activeMinutes = if (totalSeconds >= 60) (totalSeconds / 60) else 1

        saveActivityToHistory(
            "⏹ Конец: ${formatTime(timestamp)} | " +
                    "Длительность: ${formatDuration(totalSeconds)} | " +
                    "Шагов: $currentSessionSteps"
        )

        addActiveMinutes(activeMinutes)
        saveDailyStats()

        isInWalkSession = false
        walkStartTime = 0L
        currentSessionSeconds = 0
        currentSessionSteps = 0

        saveState()
        updateNotification("✅ Прогулка завершена")
    }

    private fun saveDailyStats() {
        val calendar = Calendar.getInstance()
        val todayKey = "flutter.stats_${calendar.get(Calendar.YEAR)}_${calendar.get(Calendar.MONTH)+1}_${calendar.get(Calendar.DAY_OF_MONTH)}"
        val currentSteps = prefs.getInt("flutter.today_steps", 0)
        val currentMinutes = prefs.getInt("flutter.active_minutes", 0)

        prefs.edit()
            .putInt(todayKey, currentSteps)
            .putInt("${todayKey}_minutes", currentMinutes)
            .apply()

        println("📊 Сохранена статистика: $todayKey = $currentSteps шагов, $currentMinutes мин")
    }

    private fun updateCounters(newSteps: Int) {
        val todayDate = getTodayDateString()
        val lastDate = prefs.getString("flutter.last_date", "") ?: ""

        // Определяем вчерашнюю дату
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, -1)
        val yesterdayStr = "${calendar.get(Calendar.YEAR)}_${calendar.get(Calendar.MONTH)+1}_${calendar.get(Calendar.DAY_OF_MONTH)}"

        if (lastDate != todayDate && lastDate.isNotEmpty()) {
            // Сохраняем итоги вчерашнего дня
            val yesterdaySteps = prefs.getInt("flutter.today_steps", 0)
            val yesterdayActive = prefs.getInt("flutter.active_minutes", 0)
            prefs.edit()
                .putInt("flutter.stats_$yesterdayStr", yesterdaySteps)
                .putInt("flutter.stats_${yesterdayStr}_minutes", yesterdayActive)
                .apply()
            println("📅 Сохранены итоги вчера: $yesterdayStr — $yesterdaySteps шагов, $yesterdayActive мин")
        }

        // 🔥 ИСПРАВЛЕНИЕ: Явно читаем текущий total_steps
        val currentTotal = prefs.getInt("flutter.total_steps", 0)
        val currentToday = prefs.getInt("flutter.today_steps", 0)
        val currentWeekly = prefs.getInt("flutter.weekly_steps", 0)

        val monthKey = "flutter.monthly_${calendar.get(Calendar.YEAR)}_${calendar.get(Calendar.MONTH)+1}"
        val currentMonthly = prefs.getInt(monthKey, 0)

        // Сброс дневных счётчиков при новом дне
        var newTodaySteps = if (lastDate != todayDate) newSteps else currentToday + newSteps
        val newWeeklySteps = currentWeekly + newSteps
        val newMonthlySteps = currentMonthly + newSteps
        val newTotalSteps = currentTotal + newSteps  // 👈 Явно прибавляем к прочитанному значению

        // Сброс active_minutes при новом дне
        if (lastDate != todayDate) {
            prefs.edit().putInt("flutter.active_minutes", 0).apply()
        }

        // Сохраняем ВСЕ значения
        prefs.edit().apply {
            putString("flutter.last_date", todayDate)
            putInt("flutter.today_steps", newTodaySteps)
            putInt("flutter.weekly_steps", newWeeklySteps)
            putInt(monthKey, newMonthlySteps)
            putInt("flutter.total_steps", newTotalSteps)  // 👈 Сохраняем новое значение
            apply()
        }

        // 🔥 СОХРАНЯЕМ ТЕКУЩУЮ СТАТИСТИКУ ПРИ КАЖДОМ ОБНОВЛЕНИИ
        saveDailyStats()

        println("📊 today=$newTodaySteps weekly=$newWeeklySteps month=$newMonthlySteps total=$newTotalSteps")
        updateNotification("$newTodaySteps шагов сегодня")
    }

    private fun addActiveMinutes(minutes: Int) {
        val current = prefs.getInt("flutter.active_minutes", 0)
        prefs.edit().putInt("flutter.active_minutes", current + minutes).apply()
    }

    private fun saveActivityToHistory(text: String) {
        val dateStr = SimpleDateFormat("dd.MM HH:mm", Locale.getDefault()).format(Date())
        val fullText = "$dateStr - $text"

        val history = prefs.getString("flutter.activity_feed", "") ?: ""
        val list = history.split("\n").filter { it.isNotEmpty() }.toMutableList()
        list.add(0, fullText)
        if (list.size > 50) list.removeAt(list.size - 1)
        prefs.edit().putString("flutter.activity_feed", list.joinToString("\n")).apply()
    }

    private fun startInactivityChecker() {
        inactivityHandler = Handler(Looper.getMainLooper())
        inactivityRunnable = Runnable {
            if (isInWalkSession && lastStepTime > 0) {
                val now = System.currentTimeMillis()
                if (now - lastStepTime >= PAUSE_THRESHOLD) {
                    endWalkSession(now)
                }
            }
            inactivityHandler?.postDelayed(inactivityRunnable!!, INACTIVITY_CHECK_INTERVAL)
        }
        inactivityHandler?.postDelayed(inactivityRunnable!!, INACTIVITY_CHECK_INTERVAL)
    }

    private fun formatTime(ts: Long) = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(ts))

    private fun formatDuration(s: Int): String {
        val m = s / 60
        val sec = s % 60
        return if (m > 0) "${m}мин ${sec}сек" else "${sec}сек"
    }

    private fun getTodayDateString() = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        inactivityRunnable?.let { inactivityHandler?.removeCallbacks(it) }
        if (::wakeLock.isInitialized) wakeLock.release()
        saveDailyStats()
        saveState()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("step_counter", "Шагомер", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Подсчёт шагов"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pi = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, "step_counter")
            .setContentTitle("KidLoop Шагомер")
            .setContentText("Шаги считаются...")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(text: String) {
        val n = NotificationCompat.Builder(this, "step_counter")
            .setContentTitle("KidLoop Шагомер")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(1, n)
    }
}