import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionsProvider extends ChangeNotifier {
  final List<String> _subscriptions = [];
  bool _isLoading = false;
  String? _userId;

  List<String> get subscriptions => List.unmodifiable(_subscriptions);
  bool get isLoading => _isLoading;

  static const String apiUrl =
      'https://functions.yandexcloud.net/d4e1edlmtc18q31jfdlh';

  Future<void> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    if (_userId == null || _userId!.isEmpty) return;

    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "list-my-subscriptions",
          "user_id": _userId,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && data['categories'] != null) {
        _subscriptions.clear();
        _subscriptions.addAll(List<String>.from(data['categories']));
      }
    } catch (e) {
      debugPrint('Error loading subscriptions: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> subscribeToCategory(String category) async {
    if (_userId == null) return;
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "subscribe",
          "user_id": _userId,
          "category": category,
        }),
      );
      if (!_subscriptions.contains(category)) {
        _subscriptions.add(category);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Subscribe error: $e');
    }
  }

  Future<void> unsubscribeFromCategory(String category) async {
    if (_userId == null) return;
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "unsubscribe",
          "user_id": _userId,
          "category": category,
        }),
      );
      _subscriptions.remove(category);
      notifyListeners();
    } catch (e) {
      debugPrint('Unsubscribe error: $e');
    }
  }

  Future<void> unsubscribeAll() async {
    if (_userId == null) return;
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "unsubscribe-all",
          "user_id": _userId,
        }),
      );
      _subscriptions.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Unsubscribe all error: $e');
    }
  }

  bool isSubscribed(String category) => _subscriptions.contains(category);
}