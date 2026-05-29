import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'item_model.dart';

class ItemsProvider extends ChangeNotifier {
  final List<Item> _items = [];
  bool _isLoading = false;

  List<Item> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  static const String apiUrl = 'https://functions.yandexcloud.net/d4ei9an1aushareidmjc';

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      );
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        _items.clear();
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? '';
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
            isMine: item['user_id'] == userId,
            status: item['status'] ?? 'available',
          ));
        }
      }
    } catch (e) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addItem(Item item) async {
    _items.insert(0, item);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'unknown';
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
    } catch (e) {}
  }
}