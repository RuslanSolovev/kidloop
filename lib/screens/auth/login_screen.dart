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

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool _obscurePassword = true;

  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _buttonAnimationController.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _loadAndSaveProfile(String userId, String userName) async {
    try {
      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4euctluka7dnot8sosh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get", "user_id": userId}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();

      if (data['ok'] == true && data['profile'] != null) {
        final p = data['profile'];
        final profileName = p['name']?.toString() ?? userName;
        await prefs.setString('user_name', profileName);
        await prefs.setString('user_profile', jsonEncode({
          'name': profileName,
          'city': p['city']?.toString() ?? '',
          'bio': p['bio']?.toString() ?? '',
          'age': p['age'] ?? 0,
          'favoriteCategory': 'LEGO',
          'telegram': p['telegram']?.toString() ?? '',
          'avatarUrl': p['avatar_url']?.toString() ?? '',
        }));
      } else {
        await prefs.setString('user_name', userName);
        await prefs.setString('user_profile', jsonEncode({
          'name': userName,
          'city': '',
          'bio': '',
          'age': 0,
          'favoriteCategory': 'LEGO',
          'telegram': '',
          'avatarUrl': '',
        }));
      }
    } catch (e) {
      print("Ошибка загрузки профиля: $e");
    }
  }

  Future<void> login() async {
    setState(() => loading = true);

    try {
      final emailTrimmed = email.text.trim();
      final passwordTrimmed = password.text.trim();

      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4eu9sikbtqatturth3c'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailTrimmed,
          "password": passwordTrimmed,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      setState(() => loading = false);

      if (data['ok'] == true && data['user'] != null) {
        final userId = data['user']['user_id']?.toString();
        final userName = data['user']['name']?.toString() ?? 'Пользователь';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userId!);
        await prefs.setString('user_email', emailTrimmed);
        await _loadAndSaveProfile(userId, userName);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Неверный email или пароль"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Логотип в стеклянном стиле
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFE94560)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withOpacity(0.4),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.cake, size: 55, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "KidLoop",
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Делитесь игрушками с любовью 💝",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Стеклянная карточка с полями
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Email
                        TextField(
                          controller: email,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Email",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFFF6B6B)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Пароль
                        TextField(
                          controller: password,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Пароль",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFF6B6B)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white70,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Кнопка входа с анимацией
                  AnimatedBuilder(
                    animation: _buttonScaleAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _buttonScaleAnimation.value,
                      child: child,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTapDown: (_) => _buttonAnimationController.reverse(),
                        onTapUp: (_) => _buttonAnimationController.forward(),
                        onTapCancel: () => _buttonAnimationController.forward(),
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFE94560)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B6B).withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: loading
                              ? const Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          )
                              : TextButton(
                            onPressed: login,
                            child: const Text(
                              "Войти",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Ссылка на регистрацию
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 15),
                        children: [
                          TextSpan(
                            text: "Нет аккаунта? ",
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                          const TextSpan(
                            text: "Регистрация",
                            style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}