import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'item_model.dart';

class ItemsProvider extends ChangeNotifier {
  final List<Item> _items = [];
  bool _isLoading = false;
  String? _currentUserId;

  List<Item> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  static const String apiUrl = 'https://functions.yandexcloud.net/d4ei9an1aushareidmjc';
  static const String usersApiUrl = 'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';

  final Map<String, Map<String, dynamic>> _profileCache = {};

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id') ?? '';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      );
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        _items.clear();
        for (final item in data['items']) {
          _items.add(Item(
            itemId: item['item_id'] ?? '',
            ownerId: item['user_id'] ?? '',
            title: item['title'] ?? '',
            description: item['description'] ?? '',
            sv: item['sv'] ?? 50,
            imagePath: item['image_path'] ?? 'assets/images/bear.jpg',
            location: item['location'] ?? '',
            category: item['category'] ?? 'Игрушки',
            condition: item['condition'] ?? 'Хороший',
            isMine: item['user_id'] == _currentUserId,
            status: item['status'] ?? 'available',
          ));
        }
      }
    } catch (e) {
      print('Error loading items: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // 🔥 Исправленный getUserProfile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (userId.isEmpty || userId == 'me') return null;

    // Проверяем кэш
    if (_profileCache.containsKey(userId)) {
      print('Profile cache hit for: $userId');
      return _profileCache[userId];
    }

    try {
      // 🔥 Используем search с query
      final response = await http.post(
        Uri.parse(usersApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "search",
          "query": "",  // Пустой - вернёт всех
          "user_id": "", // Не исключаем никого
          "offset": 0,
          "limit": 100,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      print('Search response: ${data['ok']}, users count: ${data['users']?.length ?? 0}');

      if (data['ok'] == true) {
        final users = data['users'] as List?;
        if (users != null) {
          // Ищем конкретного пользователя
          for (final user in users) {
            if (user['user_id'] == userId) {
              final profile = {
                'name': user['name'] ?? 'Пользователь',
                'avatar_url': user['avatar_url'] ?? '',
              };
              _profileCache[userId] = profile;
              print('Found profile: ${profile['name']}');
              return profile;
            }
          }
        }
      }

      // Если не нашли - пробуем list
      return await _getProfileViaList(userId);
    } catch (e) {
      print('Error in search: $e');
      return await _getProfileViaList(userId);
    }
  }

  Future<Map<String, dynamic>?> _getProfileViaList(String userId) async {
    try {
      final response = await http.post(
        Uri.parse(usersApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "list",
          "query": "",
          "user_id": "",
          "offset": 0,
          "limit": 100,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final users = data['users'] as List?;
        if (users != null) {
          for (final user in users) {
            if (user['user_id'] == userId) {
              final profile = {
                'name': user['name'] ?? 'Пользователь',
                'avatar_url': user['avatar_url'] ?? '',
              };
              _profileCache[userId] = profile;
              return profile;
            }
          }
        }
      }
    } catch (e) {
      print('Error in list: $e');
    }

    // Заглушка если совсем не нашли
    return {'name': 'Пользователь', 'avatar_url': ''};
  }

  Future<void> addItem(Item item) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'unknown';
    final userName = prefs.getString('user_name') ?? 'Пользователь';

    // 🔥 СОЗДАЁМ С ПРАВИЛЬНЫМ ownerId
    final correctItem = Item(
      itemId: item.itemId,
      ownerId: userId,  // 🔥 Реальный ID
      title: item.title,
      description: item.description,
      sv: item.sv,
      imagePath: item.imagePath,
      location: item.location,
      category: item.category,
      condition: item.condition,
      isMine: true,
      status: 'available',
    );

    _items.insert(0, correctItem);
    notifyListeners();

    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "add",
          "user_id": userId,
          "title": item.title,
          "description": item.description,
          "sv": item.sv,
          "image_path": item.imagePath,
          "location": item.location,
          "category": item.category,
          "condition": item.condition,
        }),
      );
    } catch (e) {
      print('Error adding item: $e');
    }
  }
}