// services/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:workmanager/workmanager.dart';

// ==================== CALLBACKS ВЕРХНЕГО УРОВНЯ ====================

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('📱 Background notification tapped: ${response.payload}');
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('🔔 WorkManager task: $task');

    if (task == 'show_notification') {
      final title = inputData?['title'] as String? ?? 'Напоминание';
      final body = inputData?['body'] as String? ?? '';
      final channel = inputData?['channel'] as String? ?? 'calendar_channel';
      final payload = inputData?['payload'] as String?;

      // Инициализируем плагин внутри WorkManager
      final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await notifications.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            'Напоминания',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    }

    return true;
  });
}

// ==================== NOTIFICATION SERVICE ====================

class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const MethodChannel _channel = MethodChannel('kidloop/notifications');
  static const MethodChannel _stepChannel = MethodChannel('com.example.kid_loop/step_counter');

  String? _currentUserId;

  static const String _apiUrl = 'https://functions.yandexcloud.net/d4e1t4stgil2lvkjq5o0';

  void Function(String chatId, String otherUserId, String otherName)? onChatTap;
  void Function(String gameId, String opponentName)? onGameTap;
  void Function(String tradeId)? onTradeTap;
  void Function(String eventId, String eventTitle)? onCalendarEventTap;

  static final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Database? _lifeDatabase;
  final Map<int, Timer> _timers = {};

  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    WidgetsBinding.instance.addObserver(this);

    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');

    // Инициализация WorkManager
    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      debugPrint('✅ WorkManager инициализирован');
    } catch (e) {
      debugPrint('⚠️ WorkManager error: $e');
    }

    try {
      try {
        await _channel.invokeMethod('createChannels');
        debugPrint('✅ Каналы созданы');
      } catch (e) {
        debugPrint('⚠️ createChannels error: $e');
      }

      try {
        await _channel.invokeMethod('requestPermissions');
        debugPrint('✅ Разрешения запрошены');
      } catch (e) {
        debugPrint('⚠️ requestPermissions error: $e');
      }

      await _startForegroundService();

      try {
        await _initializeLocalNotifications();
      } catch (e) {
        debugPrint('❌ Ошибка инициализации Local Notifications: $e');
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('Platform channel error: $e');
    }

    debugPrint('✅ NotificationService инициализирован');
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      tz.initializeTimeZones();
      debugPrint('✅ Timezones инициализированы');

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      debugPrint('✅ FlutterLocalNotifications инициализирован');

      try {
        final androidPlugin = notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          final bool? granted = await androidPlugin.requestNotificationsPermission();
          debugPrint('✅ Разрешения для уведомлений: ${granted == true ? "получены" : "отклонены"}');

          final bool? areEnabled = await androidPlugin.areNotificationsEnabled();
          debugPrint('🔔 Уведомления включены в системе: $areEnabled');
        }
      } catch (e) {
        debugPrint('⚠️ Ошибка запроса разрешений: $e');
      }

      await _createNotificationChannels();

      _isInitialized = true;
      debugPrint('✅ Local Notifications полностью инициализированы');

      await _schedulePendingReminders();
    } catch (e, stackTrace) {
      debugPrint('❌ Критическая ошибка: $e');
      _isInitialized = true;
    }
  }

  Future<void> _createNotificationChannels() async {
    try {
      const androidChannel = AndroidNotificationChannel(
        'calendar_channel',
        '📅 Напоминания о событиях',
        importance: Importance.max,
        description: 'Уведомления о предстоящих событиях',
        enableVibration: true,
        playSound: true,
      );

      const habitChannel = AndroidNotificationChannel(
        'habit_channel',
        '💪 Напоминания о привычках',
        importance: Importance.high,
        description: 'Напоминания о ежедневных привычках',
        enableVibration: true,
        playSound: true,
      );

      const reminderChannel = AndroidNotificationChannel(
        'reminder_channel',
        '⏰ Отложенные напоминания',
        importance: Importance.high,
        description: 'Отложенные напоминания',
        enableVibration: true,
        playSound: true,
      );

      final androidPlugin = notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        await androidPlugin.createNotificationChannel(habitChannel);
        await androidPlugin.createNotificationChannel(reminderChannel);
        debugPrint('✅ Все каналы созданы');
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка создания каналов: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');
    if (response.payload != null) {
      _handleLocalNotificationTap(response.payload!);
    }
  }

  // ==================== ПЛАНИРОВАНИЕ НАПОМИНАНИЙ ====================

  Future<void> scheduleEventReminder({
    required String eventId,
    required String eventTitle,
    required DateTime eventTime,
    required int reminderMinutes,
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Local Notifications не инициализированы');
      return;
    }

    try {
      final reminderTime = eventTime.subtract(Duration(minutes: reminderMinutes));
      final now = DateTime.now();

      debugPrint('📅 ПЛАНИРОВАНИЕ НАПОМИНАНИЯ:');
      debugPrint('  📌 Событие: $eventTitle');
      debugPrint('  🕐 Время события: ${eventTime.toLocal()}');
      debugPrint('  🔔 Время напоминания: ${reminderTime.toLocal()}');
      debugPrint('  🕑 Текущее время: ${now.toLocal()}');

      if (reminderTime.isBefore(now)) {
        debugPrint('⏰ Время напоминания уже прошло!');
        return;
      }

      final notificationId = (eventId + eventTitle).hashCode.abs();
      final delaySeconds = reminderTime.difference(now).inSeconds;

      debugPrint('  ⏱ Задержка: $delaySeconds секунд');
      debugPrint('  🆔 ID: $notificationId');

      if (delaySeconds < 60) {
        // Короткая задержка — используем Timer
        _timers[notificationId]?.cancel();
        _timers[notificationId] = Timer(Duration(seconds: delaySeconds), () {
          debugPrint('🔔 СРАБОТАЛ ТАЙМЕР: $eventTitle');
          showInstantNotification(
            title: '🔔 Напоминание: $eventTitle',
            body: 'Событие начнётся через $reminderMinutes минут',
            payload: jsonEncode({
              'type': 'calendar_event',
              'event_id': eventId,
              'event_title': eventTitle,
            }),
          );
        });
        debugPrint('✅ Таймер установлен!');
      } else {
        // Длинная задержка — используем WorkManager для фона
        await Workmanager().registerOneOffTask(
          'reminder_$notificationId',
          'show_notification',
          inputData: {
            'title': '🔔 Напоминание: $eventTitle',
            'body': 'Событие начнётся через $reminderMinutes минут',
            'channel': 'calendar_channel',
            'payload': jsonEncode({
              'type': 'calendar_event',
              'event_id': eventId,
              'event_title': eventTitle,
            }),
          },
          initialDelay: Duration(seconds: delaySeconds),
        );
        debugPrint('✅ WorkManager запланирован!');
      }
    } catch (e) {
      debugPrint('❌ Ошибка планирования: $e');
    }
  }

  Future<void> scheduleHabitReminder({
    required String habitId,
    required String habitTitle,
    required TimeOfDay reminderTime,
  }) async {
    if (!_isInitialized) return;

    try {
      final now = DateTime.now();
      var scheduledDateTime = DateTime(
        now.year, now.month, now.day,
        reminderTime.hour, reminderTime.minute,
      );

      if (scheduledDateTime.isBefore(now)) {
        scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
      }

      final notificationId = (habitId + habitTitle).hashCode.abs();
      final delaySeconds = scheduledDateTime.difference(now).inSeconds;

      _timers[notificationId]?.cancel();

      if (delaySeconds < 60) {
        _timers[notificationId] = Timer(Duration(seconds: delaySeconds), () {
          showInstantNotification(
            title: '💪 Напоминание: $habitTitle',
            body: 'Не забудьте выполнить привычку сегодня!',
            channel: 'habit_channel',
            payload: jsonEncode({
              'type': 'habit_reminder',
              'habit_id': habitId,
              'habit_title': habitTitle,
            }),
          );
        });
      } else {
        await Workmanager().registerOneOffTask(
          'habit_$notificationId',
          'show_notification',
          inputData: {
            'title': '💪 Напоминание: $habitTitle',
            'body': 'Не забудьте выполнить привычку сегодня!',
            'channel': 'habit_channel',
            'payload': jsonEncode({
              'type': 'habit_reminder',
              'habit_id': habitId,
              'habit_title': habitTitle,
            }),
          },
          initialDelay: Duration(seconds: delaySeconds),
        );
      }

      debugPrint('📅 Привычка "$habitTitle" запланирована на ${scheduledDateTime.toLocal()}');
    } catch (e) {
      debugPrint('❌ Ошибка: $e');
    }
  }

  Future<void> scheduleSnoozeReminder({
    required String eventId,
    required String eventTitle,
    required int snoozeMinutes,
  }) async {
    if (!_isInitialized) return;

    try {
      final delaySeconds = snoozeMinutes * 60;
      final notificationId = ('snooze_$eventId$snoozeMinutes').hashCode.abs();

      _timers[notificationId]?.cancel();

      if (delaySeconds < 60) {
        _timers[notificationId] = Timer(Duration(seconds: delaySeconds), () {
          showInstantNotification(
            title: '⏰ Напоминание: $eventTitle',
            body: 'Вы отложили напоминание на $snoozeMinutes минут',
            channel: 'reminder_channel',
          );
        });
      } else {
        await Workmanager().registerOneOffTask(
          'snooze_$notificationId',
          'show_notification',
          inputData: {
            'title': '⏰ Напоминание: $eventTitle',
            'body': 'Вы отложили напоминание на $snoozeMinutes минут',
            'channel': 'reminder_channel',
          },
          initialDelay: Duration(seconds: delaySeconds),
        );
      }

      debugPrint('⏰ Отложенное напоминание на $snoozeMinutes минут');
    } catch (e) {
      debugPrint('❌ Ошибка: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    _timers[id]?.cancel();
    _timers.remove(id);
    try {
      await Workmanager().cancelByUniqueName('reminder_$id');
      await Workmanager().cancelByUniqueName('habit_$id');
      await Workmanager().cancelByUniqueName('snooze_$id');
    } catch (_) {}
    debugPrint('✅ Уведомление #$id отменено');
  }

  Future<void> cancelAllNotifications() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    try {
      await Workmanager().cancelAll();
    } catch (_) {}
    debugPrint('✅ Все уведомления отменены');
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String channel = 'calendar_channel',
    String? payload,
  }) async {
    if (!_isInitialized) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        channel,
        '📅 Напоминания о событиях',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('🔔 Уведомление показано: $title');
    } catch (e) {
      debugPrint('❌ Ошибка показа уведомления: $e');
    }
  }

  Future<void> _schedulePendingReminders() async {
    if (!_isInitialized) {
      debugPrint('⚠️ Local Notifications не инициализированы');
      return;
    }

    try {
      final db = await _getLifeDatabase();

      final tables = await db.query('sqlite_master',
          where: 'type = ? AND name = ?', whereArgs: ['table', 'calendar_events']);

      if (tables.isEmpty) {
        debugPrint('⚠️ Таблица calendar_events не найдена');
        return;
      }

      final events = await db.query(
        'calendar_events',
        where: 'hasReminder = 1',
      );

      debugPrint('📊 Найдено событий с напоминаниями: ${events.length}');

      int scheduled = 0;
      for (final event in events) {
        final eventId = event['id'] as String;
        final eventTitle = event['title'] as String;
        final eventDate = DateTime.parse(event['date'] as String);
        final reminderMinutes = event['reminderMinutes'] as int? ?? 15;

        DateTime eventTime;
        if (event['time'] != null) {
          final timeStr = event['time'] as String;
          eventTime = DateTime.parse(timeStr);
        } else {
          eventTime = DateTime(eventDate.year, eventDate.month, eventDate.day, 12, 0);
        }

        debugPrint('🔍 Проверка события: $eventTitle');
        debugPrint('   Время события: ${eventTime.toLocal()}');
        debugPrint('   Сейчас: ${DateTime.now().toLocal()}');
        debugPrint('   В будущем: ${eventTime.isAfter(DateTime.now())}');

        if (eventTime.isAfter(DateTime.now())) {
          await scheduleEventReminder(
            eventId: eventId,
            eventTitle: eventTitle,
            eventTime: eventTime,
            reminderMinutes: reminderMinutes,
          );
          scheduled++;
        }
      }

      debugPrint('✅ Восстановлено $scheduled напоминаний');
    } catch (e) {
      debugPrint('⚠️ Ошибка восстановления напоминаний: $e');
    }
  }

  Future<Database> _getLifeDatabase() async {
    if (_lifeDatabase != null && _lifeDatabase!.isOpen) {
      return _lifeDatabase!;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'life_navigator.db');
    _lifeDatabase = await openDatabase(path);
    return _lifeDatabase!;
  }

  void _handleLocalNotificationTap(String payload) {
    try {
      final data = jsonDecode(payload);
      final type = data['type'];

      switch (type) {
        case 'calendar_event':
          onCalendarEventTap?.call(
            data['event_id'] ?? '',
            data['event_title'] ?? '',
          );
          break;
        case 'habit_reminder':
          debugPrint('💪 Напоминание о привычке: ${data['habit_title']}');
          break;
      }
    } catch (e) {
      debugPrint('Local notification tap error: $e');
    }
  }

  Future<void> _startForegroundService() async {
    try {
      final isRunning = await _stepChannel.invokeMethod('isServiceRunning');
      if (isRunning != true) {
        await _stepChannel.invokeMethod('startService');
      }
      debugPrint('✅ Foreground service ensured');
    } catch (e) {
      debugPrint('Foreground service error: $e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'notificationTap':
        final payload = call.arguments as String?;
        if (payload != null) {
          _handleNotificationTap(payload);
        }
        break;
      case 'localNotificationTap':
        final payload = call.arguments as String?;
        if (payload != null) {
          _handleLocalNotificationTap(payload);
        }
        break;
    }
  }

  void _handleNotificationTap(String payload) {
    try {
      final data = jsonDecode(payload);
      final type = data['type'];

      switch (type) {
        case 'chat':
          onChatTap?.call(
            data['chat_id'] ?? '',
            data['other_user_id'] ?? '',
            data['other_name'] ?? '',
          );
          break;
        case 'game':
          onGameTap?.call(
            data['game_id'] ?? '',
            data['opponent_name'] ?? '',
          );
          break;
        case 'trade':
          onTradeTap?.call(data['trade_id'] ?? '');
          break;
      }
    } catch (e) {
      debugPrint('Notification tap error: $e');
    }
  }

  static Future<void> sendNotification({
    required String targetUserId,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    debugPrint('📤 SENDING NOTIFICATION to: $targetUserId, type: $type');

    try {
      final body = jsonEncode({
        'action': 'send-notification',
        'target_user_id': targetUserId,
        'type': type,
        'data': data,
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      debugPrint('📤 Response: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('❌ Send notification error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint('⏸️ App paused');
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('▶️ App resumed');
      if (_isInitialized) {
        _schedulePendingReminders();
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _lifeDatabase?.close();
    _lifeDatabase = null;
  }
}