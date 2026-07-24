import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'bundle_model.dart';

class BundleProvider extends ChangeNotifier {
  final List<Bundle> _myBundles = [];
  final List<Bundle> _allBundles = [];
  bool _isLoading = false;
  String? _userId;

  List<Bundle> get myBundles => List.unmodifiable(_myBundles);
  List<Bundle> get allBundles => List.unmodifiable(_allBundles);
  bool get isLoading => _isLoading;

  static const String apiUrl =
      'https://functions.yandexcloud.net/d4eu30euelvc8hh759t4';

  Future<void> _ensureUserId() async {
    if (_userId == null || _userId!.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id') ?? '';
    }
  }

  Future<void> loadMyBundles() async {
    await _ensureUserId();
    if (_userId == null || _userId!.isEmpty) return;

    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "list-my-bundles",
          "user_id": _userId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && data['bundles'] != null) {
        _myBundles.clear();
        for (final b in data['bundles']) {
          final bundle = Bundle.fromJson(b);
          bundle.isMine = true;
          _myBundles.add(bundle);
        }
      }
    } catch (e) {
      debugPrint('Error loading my bundles: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAllBundles() async {
    await _ensureUserId();
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "list-all-bundles",
          "limit": 50,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && data['bundles'] != null) {
        _allBundles.clear();
        for (final b in data['bundles']) {
          final bundle = Bundle.fromJson(b);
          bundle.isMine = bundle.userId == _userId;
          _allBundles.add(bundle);
        }
      }
    } catch (e) {
      debugPrint('Error loading all bundles: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createBundle({
    required String title,
    required String description,
    required List<String> itemIds,
    required List<String> imagePaths,
    required String location,
    required List<String> categories,  // 🔥 Было String category
    required String condition,
  }) async {
    await _ensureUserId();
    if (_userId == null || _userId!.isEmpty) {
      return {"ok": false, "error": "User not logged in"};
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "create-bundle",
          "user_id": _userId,
          "title": title,
          "description": description,
          "item_ids": itemIds,
          "image_paths": imagePaths,
          "location": location,
          "categories": categories,  // 🔥 Массив категорий
          "condition": condition,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        await loadMyBundles();
        return {"ok": true};
      }
      return {"ok": false, "error": data['error'] ?? 'Unknown error'};
    } catch (e) {
      return {"ok": false, "error": e.toString()};
    }
  }

  Future<void> deleteBundle(String bundleId) async {
    await _ensureUserId();
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "delete-bundle",
          "bundle_id": bundleId,
          "user_id": _userId,
        }),
      );
      _myBundles.removeWhere((b) => b.bundleId == bundleId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting bundle: $e');
    }
  }

  Bundle? getBundleById(String bundleId) {
    try {
      return [..._myBundles, ..._allBundles].firstWhere(
            (b) => b.bundleId == bundleId,
      );
    } catch (_) {
      return null;
    }
  }
}