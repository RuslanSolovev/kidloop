import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:animate_do/animate_do.dart';

import '../../features/dashboard/dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool _obscurePassword = true;

  late AnimationController _bubbleController;
  late AnimationController _pulseController;
  late AnimationController _buttonPressController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _buttonPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _buttonPressController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _pulseController.dispose();
    _buttonPressController.dispose();
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
          // ✅ ИСПРАВЛЕНО: Переход на DashboardScreen с анимацией
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
              const DashboardScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0)
                        .animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    )),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
                (route) => false,
          );
        }
      } else {
        _showError("Неверный email или пароль");
      }
    } catch (e) {
      setState(() => loading = false);
      _showError("Ошибка соединения");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message, style: GoogleFonts.nunito()),
          ],
        ),
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bubbleController,
            builder: (_, __) => CustomPaint(
              painter: _BackgroundPainter(
                animationValue: _bubbleController.value,
                colorScheme: const ColorScheme(
                  brightness: Brightness.dark,
                  primary: Color(0xFFFF6B6B),
                  secondary: Color(0xFF302B63),
                  surface: Color(0xFF24243E),
                  error: Colors.red,
                  onPrimary: Colors.white,
                  onSecondary: Colors.white,
                  onSurface: Colors.white,
                  onError: Colors.white,
                ),
              ),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 24),
                child: AnimationLimiter(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: AnimationConfiguration.toStaggeredList(
                      duration: const Duration(milliseconds: 800),
                      childAnimationBuilder: (widget) => SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: widget,
                        ),
                      ),
                      children: [
                        _buildAnimatedLogo(),
                        const SizedBox(height: 24),
                        FadeInDown(
                          duration: const Duration(milliseconds: 1000),
                          child: Text(
                            "KidLoop",
                            style: GoogleFonts.nunito(
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeInUp(
                          duration: const Duration(milliseconds: 1000),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              "Делитесь игрушками с любовью 💝",
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        _buildGlassCard(),
                        const SizedBox(height: 32),
                        _buildLoginButton(),
                        const SizedBox(height: 24),
                        _buildRegisterLink(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_pulseController.value * 0.1),
          child: child,
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E), Color(0xFFE94560)],
            transform: GradientRotation(math.pi / 4),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.6),
              blurRadius: 40,
              spreadRadius: 12,
            ),
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.3),
              blurRadius: 60,
              spreadRadius: 20,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFE94560)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.cake,
              size: 55,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 10,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInputField(
            controller: email,
            hint: "Email адрес",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            controller: password,
            hint: "Пароль",
            icon: Icons.lock_outlined,
            obscure: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.white70,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // TODO: Восстановление пароля
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                "Забыли пароль?",
                style: GoogleFonts.nunito(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
          color: Colors.white.withOpacity(0.4),
          fontSize: 16,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF6B6B).withOpacity(0.2),
                const Color(0xFFE94560).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFF6B6B), size: 22),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFFF6B6B),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 20,
        ),
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildLoginButton() {
    return AnimatedBuilder(
      animation: _buttonPressController,
      builder: (context, child) => Transform.scale(
        scale: _buttonScaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) => _buttonPressController.reverse(),
        onTapUp: (_) {
          _buttonPressController.forward();
          if (!loading) login();
        },
        onTapCancel: () => _buttonPressController.forward(),
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFE94560)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.5),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.3),
                blurRadius: 35,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: loading
              ? const Center(
            child: SpinKitFadingCircle(
              color: Colors.white,
              size: 30,
            ),
          )
              : Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Войти",
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return TextButton(
      onPressed: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
          const RegisterScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.nunito(fontSize: 16),
          children: [
            TextSpan(
              text: "Впервые здесь? ",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: "Создать аккаунт",
              style: GoogleFonts.nunito(
                color: const Color(0xFFFF6B6B),
                fontWeight: FontWeight.w800,
                fontSize: 16,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFFFF6B6B).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double animationValue;
  final ColorScheme colorScheme;

  _BackgroundPainter({
    required this.animationValue,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF0F0C29),
          const Color(0xFF302B63),
          const Color(0xFF24243E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final particlePaint = Paint()
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final x = size.width * (0.1 + (i % 5) * 0.2);
      final y = size.height * (0.1 + (i ~/ 5) * 0.25);
      final offset = 30 * math.sin(animationValue * 2 * math.pi + i * 0.5);

      particlePaint.color = Colors.white.withOpacity(0.05 + 0.02 * math.sin(animationValue + i));
      particlePaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(
        Offset(x, y + offset),
        4 + (i % 3) * 2,
        particlePaint,
      );
    }

    final bubblePaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

    final bubbles = [
      (offset: Offset(size.width * 0.3, size.height * 0.2),
      radius: 80.0,
      opacity: 0.08,
      color: colorScheme.primary),
      (offset: Offset(size.width * 0.8, size.height * 0.6),
      radius: 100.0,
      opacity: 0.06,
      color: colorScheme.secondary),
      (offset: Offset(size.width * 0.1, size.height * 0.8),
      radius: 70.0,
      opacity: 0.07,
      color: colorScheme.primary),
      (offset: Offset(size.width * 0.7, size.height * 0.3),
      radius: 90.0,
      opacity: 0.05,
      color: colorScheme.secondary),
    ];

    for (final bubble in bubbles) {
      final animatedOffset = Offset(
        bubble.offset.dx + 20 * math.cos(animationValue * math.pi * 2),
        bubble.offset.dy + 20 * math.sin(animationValue * math.pi * 2),
      );

      bubblePaint.color = bubble.color.withOpacity(
        bubble.opacity * (0.8 + 0.2 * math.sin(animationValue * math.pi)),
      );

      canvas.drawCircle(animatedOffset, bubble.radius, bubblePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) => true;
}