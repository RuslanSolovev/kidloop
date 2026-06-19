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

  void clearItems() {
    _items.clear();
    _profileCache.clear();
    _currentUserId = null;
    notifyListeners();
  }

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id') ?? '';

      if (_currentUserId!.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        _items.clear();
        for (final item in data['items']) {
          // 🔥 Парсим image_paths
          final imagePathsRaw = item['image_paths'];
          List<String> imagePaths = [];
          if (imagePathsRaw is List) {
            imagePaths = imagePathsRaw.cast<String>();
          } else if (item['image_path'] != null && item['image_path'].toString().isNotEmpty) {
            imagePaths = [item['image_path'].toString()];
          }
          if (imagePaths.isEmpty) {
            imagePaths = ['assets/images/bear.jpg'];
          }

          _items.add(Item(
            itemId: item['item_id']?.toString() ?? '',
            ownerId: item['user_id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            description: item['description']?.toString() ?? '',
            sv: (item['sv'] ?? 0) is int ? item['sv'] : int.tryParse(item['sv'].toString()) ?? 0,
            imagePath: imagePaths.isNotEmpty ? imagePaths.first : 'assets/images/bear.jpg',
            imagePaths: imagePaths,
            location: item['location']?.toString() ?? '',
            category: item['category']?.toString() ?? 'Игрушки',
            condition: item['condition']?.toString() ?? 'Хороший',
            isMine: item['user_id']?.toString() == _currentUserId,
            status: item['status']?.toString() ?? 'available',
            latitude: item['latitude'] != null ? (item['latitude'] as num).toDouble() : null,
            longitude: item['longitude'] != null ? (item['longitude'] as num).toDouble() : null,
          ));
        }
      }
    } catch (e) {
      print('Error loading items: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (userId.isEmpty || userId == 'me') return null;

    if (_profileCache.containsKey(userId)) {
      return _profileCache[userId];
    }

    try {
      final response = await http.post(
        Uri.parse(usersApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "search",
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

    return {'name': 'Пользователь', 'avatar_url': ''};
  }

  Future<void> addItem(Item item) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'unknown';

    final correctItem = Item(
      itemId: item.itemId,
      ownerId: userId,
      title: item.title,
      description: item.description,
      sv: item.sv,
      imagePath: item.imagePaths.isNotEmpty ? item.imagePaths.first : item.imagePath,
      imagePaths: item.imagePaths,
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
          "image_path": item.imagePaths.isNotEmpty ? item.imagePaths.first : item.imagePath,
          "image_paths": item.imagePaths,
          "location": item.location,
          "category": item.category,
          "condition": item.condition,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Error adding item: $e');
    }
  }
}