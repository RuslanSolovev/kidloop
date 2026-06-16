import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_profile.dart';

class ProfileProvider extends ChangeNotifier {
  UserProfile _profile = UserProfile(
    name: 'Новый пользователь',
    city: 'Рига',
    bio: '',
    age: 18,
    favoriteCategory: 'LEGO',
    telegram: '',
  );

  UserProfile get profile => _profile;

  ProfileProvider() {
    loadProfile();
  }

  Future<void> updateProfile(UserProfile newProfile) async {
    _profile = newProfile;
    notifyListeners();
    await saveProfile();
  }

  Future<void> saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_profile.toMap());
    await prefs.setString('user_profile', jsonString);
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_profile');
    final savedName = prefs.getString('user_name');

    if (jsonString != null && jsonString.isNotEmpty) {
      final map = jsonDecode(jsonString);
      _profile = UserProfile.fromMap(map);
    }

    if (savedName != null && savedName.isNotEmpty && _profile.name == 'Новый пользователь') {
      _profile = UserProfile(
        name: savedName,
        city: _profile.city,
        bio: _profile.bio,
        age: _profile.age,
        favoriteCategory: _profile.favoriteCategory,
        telegram: _profile.telegram,
        avatarUrl: _profile.avatarUrl,
      );
      await saveProfile();
    }

    notifyListeners();
  }

  // 🔥 Очистка профиля при выходе
  void clearProfile() {
    _profile = UserProfile(
      name: 'Новый пользователь',
      city: 'Рига',
      bio: '',
      age: 18,
      favoriteCategory: 'LEGO',
      telegram: '',
      avatarUrl: '',
    );
    notifyListeners();
  }
}