// services/notification_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const MethodChannel _channel = MethodChannel('kidloop/notifications');
  static const MethodChannel _stepChannel =
  MethodChannel('com.example.kid_loop/step_counter');

  String? _currentUserId;

  static const String _apiUrl =
      'https://functions.yandexcloud.net/d4e1t4stgil2lvkjq5o0';

  // Колбэки для обработки кликов по уведомлениям
  void Function(String chatId, String otherUserId, String otherName)? onChatTap;
  void Function(String gameId, String opponentName)? onGameTap;
  void Function(String tradeId)? onTradeTap;

  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    WidgetsBinding.instance.addObserver(this);

    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');

    try {
      await _channel.invokeMethod('createChannels');
      await _channel.invokeMethod('requestPermissions');
      await _startForegroundService();
    } catch (e) {
      debugPrint('Platform channel error: $e');
    }

    debugPrint('✅ NotificationService инициализирован (OneSignal + шагомер)');
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

  // ====================== ОТПРАВКА УВЕДОМЛЕНИЙ ======================

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

  // ====================== ЖИЗНЕННЫЙ ЦИКЛ ======================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint('⏸️ App paused');
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('▶️ App resumed');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}