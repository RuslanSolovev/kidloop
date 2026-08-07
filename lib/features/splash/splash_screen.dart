import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:animate_do/animate_do.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../screens/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late AnimationController _particleController;
  late AnimationController _progressController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ringAnimation;
  late Animation<double> _progressAnimation;

  final List<_Particle> _particles = [];
  final int _particleCount = 50;

  String _loadingStatus = 'Инициализация...';
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();

    // Контроллер появления
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    // Пульсация логотипа
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Кольца
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ringAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.elasticOut),
    );

    // Прогресс-бар
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeInOut),
      ),
    );

    // Частицы
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _generateParticles();
    _startAnimations();
    _checkAuth();
  }

  void _generateParticles() {
    final random = math.Random(42);
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 5 + 2,
        speed: random.nextDouble() * 0.8 + 0.2,
        angle: random.nextDouble() * 2 * math.pi,
        opacity: random.nextDouble() * 0.6 + 0.2,
        color: [
          const Color(0xFFFF6B35),
          const Color(0xFFFFD93D),
          const Color(0xFFFF8E53),
        ][random.nextInt(3)],
      ));
    }
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _loadingStatus = 'Загрузка ресурсов...');
      _fadeController.forward();
      _ringController.forward();
      _progressController.forward();
    }
  }

  Future<void> _checkAuth() async {
    // Симуляция проверки сессии
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _loadingStatus = 'Проверка авторизации...');

    // ✅ ПРАВИЛЬНАЯ ПРОВЕРКА АВТОРИЗАЦИИ
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userEmail = prefs.getString('user_email');
    final userName = prefs.getString('user_name');

    // Ждем завершения анимаций
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    setState(() {
      _authChecked = true;
      _loadingStatus = userId != null ? 'Вход выполнен! 👋' : 'Добро пожаловать!';
    });

    // Небольшая пауза перед переходом
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // ✅ ОПРЕДЕЛЯЕМ КУДА ИДТИ
    Widget targetScreen;

    if (userId != null && userId.isNotEmpty && userEmail != null && userEmail.isNotEmpty) {
      // Пользователь авторизован - на главную
      targetScreen = const DashboardScreen();
    } else {
      // НЕ АВТОРИЗОВАН - на экран входа
      targetScreen = const LoginScreen();
      // На всякий случай чистим данные
      await prefs.clear();
    }

    // Плавный переход
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _particleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _particleController,
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A1A),
                  Color(0xFF15103A),
                  Color(0xFF0A0A1A),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Частицы
                CustomPaint(
                  painter: _ParticlePainter(
                    particles: _particles,
                    animationValue: _particleController.value,
                  ),
                  size: Size.infinite,
                ),

                // Сетка
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.02,
                    child: CustomPaint(
                      painter: _GridPainter(),
                      size: Size.infinite,
                    ),
                  ),
                ),

                // Контент
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _fadeAnimation,
                            _pulseAnimation,
                            _ringAnimation,
                          ]),
                          builder: (context, child) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Логотип с кольцами
                                _buildAnimatedLogo(),
                                const SizedBox(height: 50),
                                // Название
                                _buildTitle(),
                                const SizedBox(height: 20),
                                // Подзаголовок
                                _buildSubtitle(),
                                const SizedBox(height: 70),
                                // Прогресс-бар
                                _buildProgressBar(),
                                const SizedBox(height: 24),
                                // Статус загрузки
                                _buildLoadingStatus(),
                                const SizedBox(height: 40),
                                // Нижний брендинг
                                _buildFooter(),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _ringAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Внешнее кольцо 1
            Transform.scale(
              scale: _ringAnimation.value * 1.3,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withOpacity(0.15 * _ringAnimation.value),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.05),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            // Внешнее кольцо 2
            Transform.scale(
              scale: _ringAnimation.value * 1.15,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD93D).withOpacity(0.2 * _ringAnimation.value),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
              ),
            ),
            // Пульсирующая иконка
            Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6B35), Color(0xFFE94560)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD93D).withOpacity(0.2),
                      blurRadius: 60,
                      spreadRadius: 15,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.recycling_rounded,
                    color: Colors.white,
                    size: 52,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTitle() {
    return FadeInDown(
      duration: const Duration(milliseconds: 1200),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFFD93D)],
        ).createShader(bounds),
        child: Text(
          'KidLoop',
          style: GoogleFonts.nunito(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 8,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return FadeInUp(
      duration: const Duration(milliseconds: 1400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
        child: Text(
          'Меняйся. Дари. Играй.',
          style: GoogleFonts.nunito(
            fontSize: 15,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 3,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          width: 220,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withOpacity(0.06),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progressAnimation.value,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              minHeight: 4,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingStatus() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_authChecked)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SpinKitThreeBounce(
                color: const Color(0xFFFF6B35).withOpacity(0.6),
                size: 16,
              ),
            ),
          if (_authChecked)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent.shade400,
                size: 18,
              ),
            ),
          Text(
            _loadingStatus,
            key: ValueKey(_loadingStatus),
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: _authChecked
                  ? Colors.greenAccent.shade200
                  : Colors.white.withOpacity(0.5),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return FadeInUp(
      duration: const Duration(milliseconds: 2000),
      child: Opacity(
        opacity: 0.3,
        child: Column(
          children: [
            Text(
              'Powered by',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: Colors.white38,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'KidLoop Community',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: Colors.white30,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== Модель частицы ==========
class _Particle {
  final double x, y, size, speed, angle, opacity;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.angle,
    required this.opacity,
    required this.color,
  });
}

// ========== Отрисовщик частиц ==========
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationValue;

  _ParticlePainter({required this.particles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final x = particle.x * size.width +
          20 * math.sin(animationValue * 2 * math.pi + particle.angle);
      final y = (particle.y + animationValue * particle.speed) % 1.0 * size.height;

      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

// ========== Отрисовщик сетки ==========
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const spacing = 30.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}