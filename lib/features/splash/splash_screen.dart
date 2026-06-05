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
  late AnimationController _bgController;

  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..addListener(() {
      setState(() {
        _progress = _progressController.value;
      });
    });

    _floatController1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatController2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _floatController3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);

    _floatController4 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..repeat(reverse: true);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _startAnimations();
    _checkAuth();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _progressController.forward();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 3200));

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (!mounted) return;

    final target = userId != null && userId.isNotEmpty
        ? const MainNavigationScreen()
        : const LoginScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _floatController1.dispose();
    _floatController2.dispose();
    _floatController3.dispose();
    _floatController4.dispose();
    _bgController.dispose();
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
                  Color.lerp(const Color(0xFF0F0C29), const Color(0xFF1E1A4A), _bgController.value)!,
                  Color.lerp(const Color(0xFF302B63), const Color(0xFF24243E), _bgController.value)!,
                  Color.lerp(const Color(0xFF24243E), const Color(0xFF0F0C29), _bgController.value)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Парящие игрушки
                _buildFloatingToys(),

                // Основной контент
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      _buildLogo(),
                      const SizedBox(height: 24),
                      _buildTitle(),
                      const SizedBox(height: 8),
                      _buildSubtitle(),
                      const Spacer(),
                      _buildCreativeProgress(),
                      const SizedBox(height: 50),
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

  Widget _buildFloatingToys() {
    return Stack(
      children: [
        // Игрушка 1 – мяч
        Positioned(
          top: 120, left: 40,
          child: _floatingToy(
            controller: _floatController1,
            size: 70, shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)]),
            icon: Icons.sports_basketball,
            rotateFactor: 0.3,
          ),
        ),
        // Игрушка 2 – кубик
        Positioned(
          top: 160, right: 50,
          child: _floatingToy(
            controller: _floatController2,
            size: 65, shape: BoxShape.rectangle,
            borderRadius: 16,
            gradient: const LinearGradient(colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)]),
            icon: Icons.grid_view,
            rotateFactor: -0.4,
          ),
        ),
        // Игрушка 3 – машинка
        Positioned(
          bottom: 220, left: 70,
          child: _floatingToy(
            controller: _floatController3,
            size: 75, shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFFFD93D), Color(0xFFFF9A3C)]),
            icon: Icons.directions_car,
            rotateFactor: 0.25,
          ),
        ),
        // Игрушка 4 – кукла
        Positioned(
          bottom: 180, right: 60,
          child: _floatingToy(
            controller: _floatController4,
            size: 68, shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFA8E6CF), Color(0xFF88D8B0)]),
            icon: Icons.face,
            rotateFactor: -0.35,
          ),
        ),
      ],
    );
  }

  Widget _floatingToy({
    required AnimationController controller,
    required double size,
    required BoxShape shape,
    required LinearGradient gradient,
    required IconData icon,
    double borderRadius = 0,
    double rotateFactor = 0,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            math.sin(controller.value * 2 * math.pi) * 20,
            math.cos(controller.value * 2 * math.pi) * 25,
          ),
          child: Transform.rotate(
            angle: controller.value * rotateFactor,
            child: child,
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.5),
              blurRadius: 25,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Transform.scale(
          scale: Curves.elasticOut.transform(_logoController.value),
          child: Opacity(
            opacity: _logoController.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFE94560), Color(0xFFFF8E8E)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.6),
              blurRadius: 35,
              spreadRadius: 8,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.cake, size: 65, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _logoController.value)),
            child: child,
          ),
        );
      },
      child: const Text(
        "KidLoop",
        style: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 3,
          shadows: [
            Shadow(color: Color(0xFFFF6B6B), blurRadius: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoController.value * 0.8,
          child: child,
        );
      },
      child: Text(
        "Делитесь игрушками с любовью 💝",
        style: TextStyle(
          fontSize: 16,
          color: Colors.white.withOpacity(0.7),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCreativeProgress() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoController.value,
          child: child,
        );
      },
      child: Container(
        width: 260,
        child: Column(
          children: [
            // Прогресс-бар
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withOpacity(0.8),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Иконки этапов
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProgressToy(Icons.sports_basketball, 0.0),
                _buildProgressToy(Icons.grid_view, 0.33),
                _buildProgressToy(Icons.directions_car, 0.66),
                _buildProgressToy(Icons.face, 1.0),
              ],
            ),
            const SizedBox(height: 14),

            // Текст статуса
            Text(
              _getLoadingText(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressToy(IconData icon, double threshold) {
    final bool isActive = _progress >= threshold;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: isActive ? const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFE94560)],
        ) : null,
        color: isActive ? null : Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
        boxShadow: isActive ? [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: Icon(
        icon,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        size: 22,
      ),
    );
  }

  String _getLoadingText() {
    if (_progress < 0.25) return "Подготовка игрушек...";
    if (_progress < 0.5) return "Сортировка мячиков...";
    if (_progress < 0.75) return "Полировка кубиков...";
    if (_progress < 1.0) return "Почти готово...";
    return "Добро пожаловать!";
  }
}