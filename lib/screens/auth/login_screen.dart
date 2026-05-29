import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'register_screen.dart';
import '../../navigation/main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;

  Future<void> _loadAndSaveProfile(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4euctluka7dnot8sosh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get", "user_id": userId}),
      );
      final data = jsonDecode(response.body);
      if (data['ok'] == true && data['profile'] != null) {
        final p = data['profile'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', p['name'] ?? '');
        await prefs.setString('user_profile', jsonEncode({
          'name': p['name'] ?? '',
          'city': p['city'] ?? '',
          'bio': p['bio'] ?? '',
          'age': p['age'] ?? 0,
          'favoriteCategory': 'LEGO',
          'telegram': p['telegram'] ?? '',
          'avatarUrl': p['avatar_url'] ?? '',
        }));
      }
    } catch (e) {
      print("LOAD PROFILE ERROR: $e");
    }
  }

  Future<void> login() async {
    setState(() => loading = true);

    final res = await http.post(
      Uri.parse('https://functions.yandexcloud.net/d4eu9sikbtqatturth3c'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email.text.trim(),
        "password": password.text.trim(),
      }),
    );

    final data = jsonDecode(res.body);

    setState(() => loading = false);

    if (data['ok'] == true) {
      final userId = data['user']['user_id'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);

      // Загружаем профиль с сервера
      await _loadAndSaveProfile(userId);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
              (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Неверный email или пароль")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Вход",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : login,
                child: Text(loading ? "Загрузка..." : "Войти"),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text("Нет аккаунта? Регистрация"),
            ),
          ],
        ),
      ),
    );
  }
}