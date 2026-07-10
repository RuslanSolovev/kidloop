import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'leaderboard_screen.dart';

enum SeqGameState { waiting, showing, input, result }

class SequenceModeScreen extends StatefulWidget {
  const SequenceModeScreen({super.key});

  @override
  State<SequenceModeScreen> createState() => _SequenceModeScreenState();
}

class _SequenceModeScreenState extends State<SequenceModeScreen>
    with TickerProviderStateMixin {
  SeqGameState _gameState = SeqGameState.waiting;
  int _level = 1;
  int _score = 0;
  int _digitCount = 3;
  String _currentNumber = '';
  String _userInput = '';
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
      setState(() => _bestScore = prefs.getInt('sequence_game_best') ?? 0);
    }
  }

  Future<void> _saveScore() async {
    if (_score > _bestScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sequence_game_best', _score);
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
          "game": "memory_sequence",
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
      _userInput = '';
      _gameState = SeqGameState.waiting;
    });
  }

  void _generateNumber() {
    final random = Random();
    final sb = StringBuffer();
    for (int i = 0; i < _digitCount; i++) {
      sb.write(random.nextInt(10));
    }
    _currentNumber = sb.toString();
  }

  void _startShowing() {
    _generateNumber();
    setState(() {
      _gameState = SeqGameState.showing;
      _userInput = '';
    });
    final showTime = max(1.5, 3.0 - (_level * 0.2));
    Future.delayed(Duration(milliseconds: (showTime * 1000).round()), () {
      if (mounted && _gameState == SeqGameState.showing) {
        setState(() => _gameState = SeqGameState.input);
      }
    });
  }

  void _checkAnswer() {
    if (_userInput == _currentNumber) {
      final bonusPoints = _digitCount * 10;
      setState(() {
        _isCorrect = true;
        _score += bonusPoints;
        _level++;
        _digitCount = min(10, _digitCount + 1);
        _gameState = SeqGameState.result;
      });
      _celebrationController.forward(from: 0);
    } else {
      setState(() {
        _isCorrect = false;
        _gameState = SeqGameState.result;
      });
      _shakeController.forward(from: 0);
      _saveScore(); // 🔥 Сохраняем только при ошибке
    }
  }

  void _nextRound() => _startShowing();

  void _onDigitPressed(String digit) {
    if (_gameState != SeqGameState.input) return;
    if (_userInput.length < _digitCount) {
      setState(() => _userInput += digit);
    }
  }

  void _onDeletePressed() {
    if (_userInput.isNotEmpty) {
      setState(() => _userInput = _userInput.substring(0, _userInput.length - 1));
    }
  }

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
          '📝 Последовательно',
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            children: [
              _buildCompactStatsBar(isDark),
              const SizedBox(height: 12),
              Expanded(
                child: _buildGameArea(isDark, textColor, subTextColor),
              ),
              if (_gameState == SeqGameState.input) _buildNumpad(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatsBar(bool isDark) {
    return Container(
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
      case SeqGameState.waiting:
        return _buildStartScreen();
      case SeqGameState.showing:
        return _buildShowingScreen(isDark, textColor);
      case SeqGameState.input:
        return _buildInputScreen(isDark, textColor);
      case SeqGameState.result:
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
                colors: [Colors.orange, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
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

  Widget _buildShowingScreen(bool isDark, Color textColor) {
    final showTime = max(1.5, 3.0 - (_level * 0.2));
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Запомните число:',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.15),
                  blurRadius: 16,
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _currentNumber,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  letterSpacing: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 160,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 0.0),
              duration: Duration(milliseconds: (showTime * 1000).round()),
              builder: (context, value, child) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.amber],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputScreen(bool isDark, Color textColor) {
    final screenWidth = MediaQuery.of(context).size.width - 40;
    final slotWidth = min(40.0, (screenWidth / _digitCount) - 8);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Введите число:',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(_digitCount, (i) {
                final char = i < _userInput.length ? _userInput[i] : '_';
                return Container(
                  width: slotWidth,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: char == '_'
                            ? Colors.grey.shade400
                            : Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        char,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: char == '_'
                              ? Colors.grey.shade400
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
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
            const SizedBox(height: 6),
            if (!_isCorrect)
              Text(
                'Было: $_currentNumber',
                style: TextStyle(fontSize: 18, color: subTextColor),
              ),
            if (_isCorrect)
              Text(
                '+${_digitCount * 10} очков',
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
                  backgroundColor: _isCorrect ? Colors.green : Colors.orange,
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

  Widget _buildNumpad(bool isDark) {
    final buttons = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['⌫', '0', '✓'],
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: buttons.map((row) {
          return Row(
            children: row.map((btn) {
              if (btn.isEmpty) return const Spacer();
              final isDelete = btn == '⌫';
              final isCheck = btn == '✓';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Material(
                    color: isCheck
                        ? (_userInput.length == _digitCount
                        ? Colors.orange
                        : Colors.grey.shade400)
                        : isDelete
                        ? Colors.red.withOpacity(isDark ? 0.15 : 0.1)
                        : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        if (isCheck) {
                          if (_userInput.length == _digitCount) {
                            _checkAnswer();
                          }
                        } else {
                          isDelete
                              ? _onDeletePressed()
                              : _onDigitPressed(btn);
                        }
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        child: isCheck
                            ? Icon(
                          Icons.check_rounded,
                          color: _userInput.length == _digitCount
                              ? Colors.white
                              : Colors.white54,
                          size: 24,
                        )
                            : isDelete
                            ? const Icon(
                          Icons.backspace_outlined,
                          color: Colors.red,
                          size: 22,
                        )
                            : Text(
                          btn,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}