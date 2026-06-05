import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../navigation/main_navigation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _formAnimationController;
  late Animation<double> _formSlideAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _formAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _formSlideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _formAnimationController, curve: Curves.easeOutCubic),
    );

    _formAnimationController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _formAnimationController.dispose();
    name.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final nameTrimmed = name.text.trim();
    final emailTrimmed = email.text.trim();
    final passwordTrimmed = password.text.trim();
    final confirmPasswordTrimmed = confirmPassword.text.trim();

    if (nameTrimmed.isEmpty) { _showError("Введите имя"); return; }
    if (emailTrimmed.isEmpty || !emailTrimmed.contains('@') || !emailTrimmed.contains('.')) {
      _showError("Введите корректный email"); return;
    }
    if (passwordTrimmed.length < 4) {
      _showError("Пароль должен быть не менее 4 символов"); return;
    }
    if (passwordTrimmed != confirmPasswordTrimmed) {
      _showError("Пароли не совпадают"); return;
    }

    setState(() => loading = true);

    try {
      print("📝 Регистрация: $emailTrimmed");
      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4eltcbga5mf8h8g5eam'),
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-cache",
        },
        body: jsonEncode({
          "name": nameTrimmed,
          "email": emailTrimmed,
          "password": passwordTrimmed,
        }),
      ).timeout(const Duration(seconds: 15));

      print("📥 Ответ регистрации: ${response.statusCode}");
      final data = jsonDecode(response.body);
      setState(() => loading = false);

      if (data['ok'] == true) {
        final userId = data['user_id']?.toString();
        final userName = data['name']?.toString() ?? nameTrimmed;
        if (userId == null || userId.isEmpty) throw Exception("User ID не получен");

        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', userName);
        await prefs.setString('user_email', emailTrimmed);

        final profileData = {
          'name': userName, 'city': '', 'bio': '', 'age': 0,
          'favoriteCategory': 'LEGO', 'telegram': '', 'avatarUrl': '',
        };
        await prefs.setString('user_profile', jsonEncode(profileData));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Регистрация успешна! Добро пожаловать!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                (route) => false,
          );
        }
      } else {
        _showError(data['error']?.toString() ?? "Ошибка регистрации");
      }
    } catch (e) {
      setState(() => loading = false);
      _showError("Ошибка соединения: $e");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text("Регистрация", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFFF6B6B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Анимированный фоновый градиент
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.6 * _pulseAnimation.value,
                      colors: [
                        const Color(0xFFFF6B6B).withOpacity(0.1),
                        const Color(0xFF302B63).withOpacity(0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Контент
          AnimatedBuilder(
            animation: _formSlideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _formSlideAnimation.value),
                child: Opacity(
                  opacity: 1 - (_formSlideAnimation.value / 40),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Поля в стеклянном стиле
                    _buildGlassField(
                      controller: name,
                      hint: "Имя",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildGlassField(
                      controller: email,
                      hint: "Email",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildGlassField(
                      controller: password,
                      hint: "Пароль",
                      icon: Icons.lock_outline,
                      obscure: obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGlassField(
                      controller: confirmPassword,
                      hint: "Подтвердите пароль",
                      icon: Icons.lock_outline,
                      obscure: obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Кнопка создания аккаунта
                    SizedBox(
                      width: double.infinity,
                      child: loading
                          ? Container(
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
                        child: const Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                          : GestureDetector(
                        onTap: register,
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
                          child: const Center(
                            child: Text(
                              "Создать аккаунт",
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon: Icon(icon, color: const Color(0xFFFF6B6B)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        keyboardType: keyboardType,
      ),
    );
  }
}