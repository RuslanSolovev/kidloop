import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'leaderboard_screen.dart';

enum ScatterGameState { waiting, showing, tapping, result }

class ScatterModeScreen extends StatefulWidget {
  const ScatterModeScreen({super.key});

  @override
  State<ScatterModeScreen> createState() => _ScatterModeScreenState();
}

class _ScatterModeScreenState extends State<ScatterModeScreen>
    with TickerProviderStateMixin {
  ScatterGameState _gameState = ScatterGameState.waiting;
  int _level = 1;
  int _score = 0;
  int _digitCount = 3;
  int _nextExpected = 1;
  List<int> _numbers = [];
  Map<int, Offset> _positions = {}; // 🔥 Map: номер -> позиция
  Set<int> _tappedNumbers = {};
  bool _isCorrect = false;
  int _bestScore = 0;
  String? _currentUserId;
  String? _currentUserName;

  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _celebrationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _celebrationAnimation;

  static const String _apiUrl =
      'https://functions.yandexcloud.net/d4ei7lnhipg7enofqsd3';

  @override
  void initState() {
    super.initState();
    _loadBestScore();
    _initAnimations();
    _loadUserData();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _celebrationAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _currentUserName = prefs.getString('user_name') ?? 'Игрок';
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _bestScore = prefs.getInt('scatter_game_best') ?? 0);
    }
  }

  Future<void> _saveScore() async {
    if (_score > _bestScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('scatter_game_best', _score);
      if (mounted) setState(() => _bestScore = _score);
    }
    _uploadScore();
  }

  Future<void> _uploadScore() async {
    try {
      await http
          .post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "save-game-score",
          "game": "memory_scatter",
          "user_id": _currentUserId,
          "user_name": _currentUserName,
          "score": _score,
          "level": _level,
        }),
      )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  void _startNewGame() {
    setState(() {
      _level = 1;
      _score = 0;
      _digitCount = 3;
      _gameState = ScatterGameState.waiting;
      _tappedNumbers = {};
    });
  }

  void _generateNumbers() {
    _numbers = List.generate(_digitCount, (i) => i + 1);
    _numbers.shuffle();
    _nextExpected = 1;
    _tappedNumbers = {};

    final random = Random();
    _positions = {};

    for (int i = 0; i < _digitCount; i++) {
      Offset? newPos;
      int attempts = 0;

      while (newPos == null && attempts < 100) {
        final candidate = Offset(
          random.nextDouble() * 0.7 + 0.15,
          random.nextDouble() * 0.5 + 0.15,
        );

        bool tooClose = false;
        for (final existingPos in _positions.values) {
          if ((candidate - existingPos).distance < 0.08) {
            tooClose = true;
            break;
          }
        }

        if (!tooClose) newPos = candidate;
        attempts++;
      }

      _positions[_numbers[i]] = newPos ??
          Offset(
            random.nextDouble() * 0.6 + 0.2,
            random.nextDouble() * 0.4 + 0.2,
          );
    }
  }

  void _startShowing() {
    _generateNumbers();
    setState(() => _gameState = ScatterGameState.showing);
    final showTime = max(1.5, 3.0 - (_level * 0.2));
    Future.delayed(Duration(milliseconds: (showTime * 1000).round()), () {
      if (mounted && _gameState == ScatterGameState.showing) {
        setState(() => _gameState = ScatterGameState.tapping);
      }
    });
  }

  void _onNumberTap(int number) {
    if (_gameState != ScatterGameState.tapping) return;

    if (number == _nextExpected) {
      setState(() {
        _tappedNumbers.add(number);
        _nextExpected++;
      });

      if (_nextExpected > _digitCount) {
        final bonusPoints = _digitCount * 15;
        setState(() {
          _isCorrect = true;
          _score += bonusPoints;
          _level++;
          _digitCount = min(10, _digitCount + 1);
          _gameState = ScatterGameState.result;
        });
        _celebrationController.forward(from: 0);
      }
    } else {
      setState(() {
        _isCorrect = false;
        _gameState = ScatterGameState.result;
      });
      _shakeController.forward(from: 0);
      _saveScore(); // 🔥 Сохраняем только при ошибке
    }
  }

  void _nextRound() => _startShowing();

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final backgroundColor =
    isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade200,
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          '💥 Вразброс',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded, color: Colors.amber),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
            tooltip: 'Таблица лидеров',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCompactStatsBar(isDark),
            const SizedBox(height: 8),
            Expanded(
              child: _buildGameArea(isDark, textColor, subTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatsBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _compactStat('Ур.', '$_level', Colors.green),
          _compactStat('Очки', '$_score', Colors.amber),
          _compactStat('Рек.', '$_bestScore', Colors.orange),
          _compactStat('Цифр', '$_digitCount', Colors.blue),
        ],
      ),
    );
  }

  Widget _compactStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildGameArea(bool isDark, Color textColor, Color subTextColor) {
    switch (_gameState) {
      case ScatterGameState.waiting:
        return _buildStartScreen();
      case ScatterGameState.showing:
        return _buildShowingScatter();
      case ScatterGameState.tapping:
        return _buildTappingScreen();
      case ScatterGameState.result:
        return _buildResultScreen(textColor, subTextColor);
    }
  }

  Widget _buildStartScreen() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: GestureDetector(
          onTap: _startShowing,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.lightBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(height: 6),
                Text(
                  'СТАРТ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 Показ чисел с использованием Map для позиций
  Widget _buildShowingScatter() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height - 200;
    final circleSize = _digitCount > 8 ? 44.0 : 56.0;

    return Stack(
      children: _positions.entries.map((entry) {
        final number = entry.key;
        final pos = entry.value;
        final left = (pos.dx * screenWidth - circleSize / 2)
            .clamp(0.0, screenWidth - circleSize);
        final top =
        (pos.dy * screenHeight).clamp(0.0, screenHeight - circleSize);

        return Positioned(
          left: left,
          top: top + 60,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            ),
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 🔥 Экран tapping с Map для позиций — скрываем только нажатые
  Widget _buildTappingScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height - 200;
    final circleSize = _digitCount > 8 ? 44.0 : 56.0;

    return Stack(
      children: _positions.entries
          .where((entry) => !_tappedNumbers.contains(entry.key))
          .map((entry) {
        final number = entry.key;
        final pos = entry.value;
        final left = (pos.dx * screenWidth - circleSize / 2)
            .clamp(0.0, screenWidth - circleSize);
        final top =
        (pos.dy * screenHeight).clamp(0.0, screenHeight - circleSize);

        return Positioned(
          left: left,
          top: top + 60,
          child: GestureDetector(
            onTap: () => _onNumberTap(number),
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.15),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.5),
                  width: 2.5,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultScreen(Color textColor, Color subTextColor) {
    return Center(
      child: AnimatedBuilder(
        animation: _isCorrect ? _celebrationAnimation : _shakeAnimation,
        builder: (context, child) {
          double scale = _isCorrect ? _celebrationAnimation.value : 1.0;
          Offset offset = _isCorrect
              ? Offset.zero
              : Offset(sin(_shakeAnimation.value * 6 * pi) * 10, 0);
          return Transform.scale(
            scale: scale,
            child: Transform.translate(offset: offset, child: child),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 64,
              color: _isCorrect ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              _isCorrect ? 'Правильно! 🎉' : 'Неправильно 😢',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isCorrect ? Colors.green : Colors.red,
              ),
            ),
            if (!_isCorrect) ...[
              const SizedBox(height: 6),
              Text(
                'Нужно было: $_nextExpected',
                style: TextStyle(fontSize: 16, color: subTextColor),
              ),
            ],
            if (_isCorrect)
              Text(
                '+${_digitCount * 15} очков',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              height: 44,
              child: ElevatedButton(
                onPressed: _isCorrect ? _nextRound : _startNewGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCorrect ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  _isCorrect ? 'Дальше ►' : 'Заново',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (!_isCorrect) ...[
              const SizedBox(height: 8),
              Text(
                'Счёт: $_score',
                style: TextStyle(color: subTextColor, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}