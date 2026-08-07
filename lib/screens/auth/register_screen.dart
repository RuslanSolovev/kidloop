import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:animate_do/animate_do.dart';

import '../../features/dashboard/dashboard_screen.dart'; // ✅ Исправлен импорт

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  bool _nameValid = false;
  bool _emailValid = false;
  bool _passwordValid = false;
  bool _passwordsMatch = true;
  bool _passwordLengthValid = false;

  late AnimationController _bubbleController;

  @override
  void initState() {
    super.initState();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    name.addListener(_validateName);
    email.addListener(_validateEmail);
    password.addListener(_validatePassword);
    confirmPassword.addListener(_checkPasswordsMatch);
  }

  void _validateName() {
    final valid = name.text.trim().isNotEmpty;
    if (valid != _nameValid) setState(() => _nameValid = valid);
  }

  void _validateEmail() {
    final emailText = email.text.trim();
    final valid =
        emailText.isNotEmpty && emailText.contains('@') && emailText.contains('.');
    if (valid != _emailValid) setState(() => _emailValid = valid);
  }

  void _validatePassword() {
    final passwordText = password.text;
    final lengthValid = passwordText.length >= 4;
    if (lengthValid != _passwordLengthValid) {
      setState(() => _passwordLengthValid = lengthValid);
    }
    if (lengthValid != _passwordValid) {
      setState(() => _passwordValid = lengthValid);
    }
    _checkPasswordsMatch();
  }

  void _checkPasswordsMatch() {
    final match = password.text.isEmpty ||
        confirmPassword.text.isEmpty ||
        password.text == confirmPassword.text;
    if (match != _passwordsMatch) setState(() => _passwordsMatch = match);
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    name.removeListener(_validateName);
    email.removeListener(_validateEmail);
    password.removeListener(_validatePassword);
    confirmPassword.removeListener(_checkPasswordsMatch);
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

    if (!_nameValid || !_emailValid || !_passwordValid || !_passwordsMatch) {
      _showError("Пожалуйста, проверьте введенные данные");
      return;
    }

    setState(() => loading = true);

    try {
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

      final data = jsonDecode(response.body);
      setState(() => loading = false);

      if (data['ok'] == true) {
        final userId = data['user_id']?.toString();
        final userName = data['name']?.toString() ?? nameTrimmed;
        if (userId == null || userId.isEmpty) throw Exception("User ID missing");

        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', userName);
        await prefs.setString('user_email', emailTrimmed);

        final profileData = {
          'name': userName,
          'city': '',
          'bio': '',
          'age': 0,
          'favoriteCategory': 'LEGO',
          'telegram': '',
          'avatarUrl': '',
        };
        await prefs.setString('user_profile', jsonEncode(profileData));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.celebration, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Добро пожаловать, $userName! 🎉",
                      style: GoogleFonts.nunito(),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.greenAccent.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              duration: const Duration(seconds: 2),
            ),
          );

          // ✅ ИСПРАВЛЕНО: Переход на DashboardScreen после регистрации
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
                    scale: Tween<double>(begin: 0.8, end: 1.0)
                        .animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.elasticOut,
                    )),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
                (route) => false,
          );
        }
      } else {
        _showError(data['error']?.toString() ?? "Ошибка регистрации");
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Регистрация",
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFFF6B6B),
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bubbleController,
            builder: (_, __) => CustomPaint(
              painter: _BackgroundPainter(
                animationValue: _bubbleController.value,
              ),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: AnimationLimiter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                  AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 600),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: widget,
                      ),
                    ),
                    children: [
                      const SizedBox(height: 10),
                      FadeInLeft(
                        duration: const Duration(milliseconds: 800),
                        child: Text(
                          "Создайте аккаунт",
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeInLeft(
                        duration: const Duration(milliseconds: 900),
                        child: Text(
                          "Присоединяйтесь к нашему сообществу",
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildValidatedField(
                        controller: name,
                        hint: "Ваше имя",
                        icon: Icons.person_outline_rounded,
                        isValid: name.text.isEmpty ? null : _nameValid,
                        validIcon: Icons.check_circle_rounded,
                        invalidIcon: Icons.cancel_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildValidatedField(
                        controller: email,
                        hint: "Email адрес",
                        icon: Icons.email_outlined,
                        isValid: email.text.isEmpty ? null : _emailValid,
                        validIcon: Icons.check_circle_rounded,
                        invalidIcon: Icons.cancel_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 16),
                      _buildConfirmPasswordField(),
                      const SizedBox(height: 24),
                      _buildPasswordRequirements(),
                      const SizedBox(height: 32),
                      _buildRegisterButton(),
                      const SizedBox(height: 24),
                      _buildLoginLink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidatedField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool? isValid,
    IconData? validIcon,
    IconData? invalidIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isValid == null
              ? Colors.white.withOpacity(0.2)
              : isValid
              ? Colors.greenAccent.withOpacity(0.5)
              : Colors.redAccent.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isValid == null
                ? Colors.transparent
                : isValid
                ? Colors.greenAccent.withOpacity(0.1)
                : Colors.redAccent.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
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
          suffixIcon: isValid != null
              ? Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              isValid ? validIcon : invalidIcon,
              color: isValid ? Colors.greenAccent : Colors.redAccent,
              size: 22,
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
        ),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: password.text.isEmpty
              ? Colors.white.withOpacity(0.2)
              : _passwordLengthValid
              ? Colors.greenAccent.withOpacity(0.5)
              : Colors.redAccent.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: password,
        obscureText: obscurePassword,
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: "Пароль (мин. 4 символа)",
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
            child: const Icon(Icons.lock_outline_rounded,
                color: Color(0xFFFF6B6B), size: 22),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (password.text.isNotEmpty)
                Icon(
                  _passwordLengthValid
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: _passwordLengthValid
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  size: 22,
                ),
              IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white70,
                ),
                onPressed: () =>
                    setState(() => obscurePassword = !obscurePassword),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: confirmPassword.text.isEmpty
              ? Colors.white.withOpacity(0.2)
              : _passwordsMatch
              ? Colors.greenAccent.withOpacity(0.5)
              : Colors.redAccent.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: confirmPassword,
        obscureText: obscureConfirmPassword,
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: "Повторите пароль",
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
            child: const Icon(Icons.lock_outline_rounded,
                color: Color(0xFFFF6B6B), size: 22),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (confirmPassword.text.isNotEmpty)
                Icon(
                  _passwordsMatch
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color:
                  _passwordsMatch ? Colors.greenAccent : Colors.redAccent,
                  size: 22,
                ),
              IconButton(
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white70,
                ),
                onPressed: () => setState(
                        () => obscureConfirmPassword = !obscureConfirmPassword),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    return AnimatedOpacity(
      opacity: password.text.isEmpty ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Требования к паролю:",
              style: GoogleFonts.nunito(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildRequirementRow(
              "Минимум 6 символов",
              _passwordLengthValid,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: isValid ? Colors.greenAccent : Colors.white30,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.nunito(
              color: isValid ? Colors.white : Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    final allValid = _nameValid &&
        _emailValid &&
        _passwordValid &&
        _passwordsMatch;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 62,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allValid
              ? [const Color(0xFFFF6B6B), const Color(0xFFE94560)]
              : [Colors.grey.shade700, Colors.grey.shade800],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: allValid
            ? [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.5),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ]
            : [],
      ),
      child: loading
          ? const Center(
        child: SpinKitFadingCircle(
          color: Colors.white,
          size: 30,
        ),
      )
          : Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: allValid ? register : null,
          borderRadius: BorderRadius.circular(22),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Создать аккаунт",
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.rocket_launch_rounded,
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

  Widget _buildLoginLink() {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.nunito(fontSize: 16),
            children: [
              TextSpan(
                text: "Уже есть аккаунт? ",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              TextSpan(
                text: "Войти",
                style: GoogleFonts.nunito(
                  color: const Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double animationValue;

  _BackgroundPainter({required this.animationValue});

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

    final bubblePaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    for (int i = 0; i < 6; i++) {
      final x = size.width * (0.2 + (i % 3) * 0.3);
      final y = size.height * (0.15 + (i ~/ 3) * 0.3);
      final offset = 25 * math.sin(animationValue * math.pi * 2 + i);

      bubblePaint.color = (i.isEven
          ? const Color(0xFFFF6B6B)
          : const Color(0xFF302B63))
          .withOpacity(0.06 + 0.02 * math.sin(animationValue + i));

      canvas.drawCircle(Offset(x, y + offset), 60 + i * 10, bubblePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) => true;
}