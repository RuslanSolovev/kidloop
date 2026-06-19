import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import '../../navigation/main_navigation_screen.dart';
import '../../screens/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late AnimationController _floatController1;
  late AnimationController _floatController2;
  late AnimationController _floatController3;
  late AnimationController _floatController4;
  late AnimationController _floatController5;
  late AnimationController _floatController6;
  late AnimationController _bgController;
  late AnimationController _sparkleController;

  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..addListener(() {
        setState(() => _progress = _progressController.value);
      });

    _floatController1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _floatController2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _floatController3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2100))..repeat(reverse: true);
    _floatController4 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _floatController5 = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _floatController6 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))..repeat(reverse: true);

    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);

    _sparkleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    _startAnimations();
    _checkAuth();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _progressController.forward();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 3500));

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (!mounted) return;

    final target = userId != null && userId.isNotEmpty
        ? const MainNavigationScreen()
        : const LoginScreen();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => target,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
          },
          transitionDuration: const Duration(milliseconds: 700),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _floatController1.dispose();
    _floatController2.dispose();
    _floatController3.dispose();
    _floatController4.dispose();
    _floatController5.dispose();
    _floatController6.dispose();
    _bgController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF0A0A2E), const Color(0xFF1A1A4E), _bgController.value)!,
                  Color.lerp(const Color(0xFF1A1A4E), const Color(0xFF2D2B55), _bgController.value)!,
                  Color.lerp(const Color(0xFF2D2B55), const Color(0xFF0A0A2E), _bgController.value)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Звёзды на фоне
                ..._buildStars(),

                // Парящие игрушки
                _buildFloatingToys(),

                // Основной контент
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      _buildLogo(),
                      const SizedBox(height: 28),
                      _buildTitle(),
                      const SizedBox(height: 10),
                      _buildSubtitle(),
                      const Spacer(flex: 2),
                      _buildCreativeProgress(),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildStars() {
    final random = math.Random(42);
    final stars = <Widget>[];
    for (int i = 0; i < 35; i++) {
      final x = random.nextDouble();
      final y = random.nextDouble();
      final size = random.nextDouble() * 3 + 1;
      final opacity = random.nextDouble() * 0.6 + 0.2;
      final delay = random.nextDouble() * 2;

      stars.add(
        Positioned(
          left: x * MediaQuery.of(context).size.width,
          top: y * MediaQuery.of(context).size.height,
          child: AnimatedBuilder(
            animation: _sparkleController,
            builder: (context, child) {
              final sparkle = math.sin((_sparkleController.value + delay) * 2 * math.pi) * 0.5 + 0.5;
              return Opacity(
                opacity: opacity * (0.5 + sparkle * 0.5),
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              );
            },
          ),
        ),
      );
    }
    return stars;
  }

  Widget _buildFloatingToys() {
    return Stack(
      children: [
        // Мяч
        Positioned(top: 100, left: 30, child: _floatingToy(controller: _floatController1, size: 65, gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)]), icon: Icons.sports_basketball, rotateFactor: 0.3)),
        // Кубик LEGO
        Positioned(top: 140, right: 35, child: _floatingToy(controller: _floatController2, size: 60, gradient: const LinearGradient(colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)]), icon: Icons.grid_view_rounded, rotateFactor: -0.35, borderRadius: 14)),
        // Машинка
        Positioned(bottom: 240, left: 55, child: _floatingToy(controller: _floatController3, size: 70, gradient: const LinearGradient(colors: [Color(0xFFFFD93D), Color(0xFFFF9A3C)]), icon: Icons.directions_car, rotateFactor: 0.25)),
        // Самолётик
        Positioned(bottom: 200, right: 40, child: _floatingToy(controller: _floatController4, size: 62, gradient: const LinearGradient(colors: [Color(0xFFA8E6CF), Color(0xFF88D8B0)]), icon: Icons.flight, rotateFactor: -0.3)),
        // Звезда
        Positioned(top: 300, left: 140, child: _floatingToy(controller: _floatController5, size: 50, gradient: const LinearGradient(colors: [Color(0xFFFFB347), Color(0xFFFFD700)]), icon: Icons.star_rounded, rotateFactor: 0.5)),
        // Сердце
        Positioned(top: 350, right: 120, child: _floatingToy(controller: _floatController6, size: 55, gradient: const LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFFF3D7F)]), icon: Icons.favorite_rounded, rotateFactor: -0.4)),
      ],
    );
  }

  Widget _floatingToy({
    required AnimationController controller,
    required double size,
    required LinearGradient gradient,
    required IconData icon,
    double rotateFactor = 0,
    double borderRadius = 0,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            math.sin(controller.value * 2 * math.pi + 1) * 22,
            math.cos(controller.value * 2 * math.pi + 1) * 28,
          ),
          child: Transform.rotate(
            angle: controller.value * rotateFactor * 2 * math.pi,
            child: child,
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius > 0 ? BorderRadius.circular(borderRadius) : null,
          shape: borderRadius == 0 ? BoxShape.circle : BoxShape.rectangle,
          boxShadow: [
            BoxShadow(color: gradient.colors.first.withOpacity(0.55), blurRadius: 30, spreadRadius: 5),
            BoxShadow(color: Colors.white.withOpacity(0.08), blurRadius: 15, spreadRadius: -3),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.42, shadows: const [Shadow(color: Colors.black26, blurRadius: 8)]),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        final scale = Curves.elasticOut.transform(_logoController.value.clamp(0.0, 1.0));
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: _logoController.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFE94560), Color(0xFFFF477E)],
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.7), blurRadius: 40, spreadRadius: 10),
            BoxShadow(color: const Color(0xFFFF477E).withOpacity(0.4), blurRadius: 60, spreadRadius: 15),
            BoxShadow(color: Colors.white.withOpacity(0.12), blurRadius: 25, spreadRadius: -8),
          ],
        ),
        child: const Center(
          child: Icon(Icons.toys_rounded, size: 70, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 10)]),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoController.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - _logoController.value.clamp(0.0, 1.0))),
            child: child,
          ),
        );
      },
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E), Color(0xFFFFD93D)],
        ).createShader(bounds),
        child: const Text(
          "KidLoop",
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 4,
            shadows: [
              Shadow(color: Color(0xFFFF6B6B), blurRadius: 30),
              Shadow(color: Colors.white24, blurRadius: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: (_logoController.value * 0.85).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - _logoController.value.clamp(0.0, 1.0))),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Text(
          "🧸 Делитесь игрушками с любовью 💝",
          style: TextStyle(fontSize: 15, color: Colors.white70, letterSpacing: 0.6),
        ),
      ),
    );
  }

  Widget _buildCreativeProgress() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoController.value.clamp(0.0, 1.0),
          child: child,
        );
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            // Прогресс-бар
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF477E), Color(0xFFFFD93D)]),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.6), blurRadius: 14, spreadRadius: 2)],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Иконки этапов
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProgressToy(Icons.inventory_2_rounded, 0.0, 'Вещи'),
                _buildProgressToy(Icons.swap_horiz_rounded, 0.33, 'Обмен'),
                _buildProgressToy(Icons.check_circle_rounded, 0.66, 'Сделка'),
                _buildProgressToy(Icons.celebration_rounded, 1.0, 'Готово'),
              ],
            ),
            const SizedBox(height: 16),

            // Текст статуса
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _getLoadingText(),
                key: ValueKey(_getLoadingText()),
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14, letterSpacing: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressToy(IconData icon, double threshold, String label) {
    final bool isActive = _progress >= threshold;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isActive ? const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFE94560)]) : null,
              color: isActive ? null : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: isActive ? [BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.5), blurRadius: 14, spreadRadius: 2)] : null,
              border: !isActive ? Border.all(color: Colors.white.withOpacity(0.15)) : null,
            ),
            child: Icon(icon, color: isActive ? Colors.white : Colors.white.withOpacity(0.35), size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white70 : Colors.white.withOpacity(0.3),
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _getLoadingText() {
    if (_progress < 0.15) return "🎨 Собираем игрушки...";
    if (_progress < 0.35) return "🧩 Сортируем LEGO...";
    if (_progress < 0.55) return "🚗 Проверяем машинки...";
    if (_progress < 0.75) return "🧸 Упаковываем кукол...";
    if (_progress < 0.95) return "✨ Почти готово...";
    return "🎉 Добро пожаловать в KidLoop!";
  }
}