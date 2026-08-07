// features/life_navigator/ui/race_monster_mode.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

/// Режим "Убеги от монстра" – 10 уровней
class RaceMonsterMode extends StatefulWidget {
  const RaceMonsterMode({super.key});

  @override
  State<RaceMonsterMode> createState() => _RaceMonsterModeState();
}

class _RaceMonsterModeState extends State<RaceMonsterMode>
    with SingleTickerProviderStateMixin {
  int _level = 1;
  static const int _maxLevel = 10;

  double _playerProgress = 0.10;
  double _monsterProgress = 0.0;
  double _timeLeft = 15.0;

  bool _isPlaying = false;
  bool _isWin = false;
  bool _isLose = false;
  bool _gameFinished = false;
  String _statusMessage = 'Нажми, чтобы начать!';

  double get _monsterSpeed => 1.0 / (15.0 - (_level - 1) * 0.55);
  double get _pressBoost => 0.025 - (_level - 1) * 0.0017;

  final List<String> _bosses = [
    '👾', '🐕', '🐺', '🐉', '👹',
    '🧛', '🧟', '🦇', '👽', '💀',
  ];
  String get _currentBoss => _bosses[_level - 1];

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  Timer? _gameTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCamera();
  }

  void _initAnimations() {
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        CameraDescription? frontCamera;
        for (var camera in _cameras!) {
          if (camera.lensDirection == CameraLensDirection.front) {
            frontCamera = camera;
            break;
          }
        }
        final selectedCamera = frontCamera ?? _cameras![0];
        _cameraController =
            CameraController(selectedCamera, ResolutionPreset.medium);
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Ошибка инициализации камеры: $e');
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    _cameraController?.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _level = 1;
      _playerProgress = 0.10;
      _monsterProgress = 0.0;
      _timeLeft = 15.0;
      _isPlaying = false;
      _isWin = false;
      _isLose = false;
      _gameFinished = false;
      _statusMessage = 'Нажми, чтобы начать!';
    });
    _gameTimer?.cancel();
  }

  void _startLevel() {
    setState(() {
      _isPlaying = true;
      _isWin = false;
      _isLose = false;
      _playerProgress = 0.10;
      _monsterProgress = 0.0;
      _timeLeft = 15.0;
      _statusMessage = 'Уровень $_level – Беги от ${_currentBoss}!';
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _monsterProgress += _monsterSpeed * 0.05;
        _timeLeft -= 0.05;

        if (_playerProgress >= 1.0) {
          _playerProgress = 1.0;
          _winLevel();
          timer.cancel();
          return;
        }

        if (_monsterProgress >= _playerProgress) {
          _monsterProgress = _playerProgress;
          _loseLevel();
          timer.cancel();
          return;
        }

        if (_timeLeft <= 0) {
          _timeLeft = 0;
          if (_playerProgress < 1.0 && _monsterProgress < _playerProgress) {
            _winLevel();
            timer.cancel();
            return;
          }
        }
      });
    });
  }

  void _onButtonPressed() {
    if (_gameFinished) {
      _resetGame();
      return;
    }
    if (!_isPlaying) {
      _startLevel();
      return;
    }
    if (_isWin || _isLose) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _playerProgress += _pressBoost;
      if (_playerProgress > 1.0) _playerProgress = 1.0;
    });

    _shakeController.forward(from: 0.0);
    _scaleController.forward(from: 0.0);
    Future.delayed(const Duration(milliseconds: 50), () {
      HapticFeedback.lightImpact();
    });
  }

  void _winLevel() {
    setState(() {
      _isWin = true;
      _isPlaying = false;
      _statusMessage = '🏆 Красавчик! Уровень $_level пройден!';
    });
    _gameTimer?.cancel();

    if (_level >= _maxLevel) {
      _gameFinished = true;
      _statusMessage = '🎉 Ты победил всех боссов! Ты ЛЕГЕНДА!';
      Future.delayed(const Duration(milliseconds: 400), () {
        _openCameraWithMessage('Ты ЛЕГЕНДА! 👑', isWin: true, isFinal: true);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 400), () {
        _openCameraWithMessage('Красавчик!', isWin: true, isFinal: false);
      });
    }
  }

  void _loseLevel() {
    setState(() {
      _isLose = true;
      _isPlaying = false;
      _statusMessage = '😱 ${_currentBoss} догнал тебя! Ты ЛОХ!';
    });
    _gameTimer?.cancel();

    Future.delayed(const Duration(milliseconds: 300), () {
      _openCameraWithMessage('ЛОХ', isWin: false, isFinal: false);
    });
  }

  void _openCameraWithMessage(String message, {required bool isWin, required bool isFinal}) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📸 $message'),
          backgroundColor: isWin ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          if (isWin && !isFinal) {
            setState(() {
              _level++;
              _isWin = false;
              _isPlaying = false;
              _playerProgress = 0.10;
              _monsterProgress = 0.0;
              _timeLeft = 15.0;
              _statusMessage = 'Уровень $_level – Нажми, чтобы начать!';
            });
          } else if (isWin && isFinal) {
            _gameFinished = true;
          } else {
            _resetGame();
          }
        }
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _CameraWithOverlayScreen(
          cameraController: _cameraController!,
          overlayText: message,
          isWin: isWin,
          isFinal: isFinal,
          onClose: () {
            if (mounted) {
              if (isWin && !isFinal) {
                setState(() {
                  _level++;
                  _isWin = false;
                  _isPlaying = false;
                  _playerProgress = 0.10;
                  _monsterProgress = 0.0;
                  _timeLeft = 15.0;
                  _statusMessage = 'Уровень $_level – Нажми, чтобы начать!';
                });
              } else if (isWin && isFinal) {
                setState(() {
                  _gameFinished = true;
                  _statusMessage = '👑 Ты ЛЕГЕНДА! Нажми, чтобы сыграть снова!';
                });
              } else {
                _resetGame();
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('👾 Режим Монстр'),
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor),
          onPressed: () {
            Navigator.pop(context, {'win': _isWin, 'level': _level});
          },
        ),
      ),
      body: _buildGameUI(isDark, textColor),
    );
  }

  Widget _buildGameUI(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(isDark, textColor),
          const SizedBox(height: 12),
          SizedBox(height: 90, child: _buildProgressTrack(isDark)),
          const SizedBox(height: 12),
          Center(child: _buildGameButton()),
          const SizedBox(height: 16),
          _buildStatusMessage(isDark),
          const SizedBox(height: 8),
          if (_gameFinished)
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context, {'win': true, 'level': _maxLevel});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '🏠 В меню',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    final distance = ((_playerProgress - _monsterProgress) * 100).clamp(0.0, 100.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Уровень $_level / $_maxLevel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _currentBoss,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _level > 7
                        ? Colors.red.withOpacity(0.3)
                        : (_level > 4
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _level > 7
                        ? '🔥🔥'
                        : (_level > 4
                        ? '🔥'
                        : ''),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
            Text(
              '⚡ ${(_pressBoost * 100).toStringAsFixed(1)}% | '
                  'Монстр ${(15.0 - (_level - 1) * 0.55).toStringAsFixed(1)}с',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: distance < 10
                ? Colors.red.withOpacity(0.2)
                : Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: distance < 10 ? Colors.red : Colors.orange,
              width: 1.5,
            ),
          ),
          child: Text(
            '${distance.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: distance < 10 ? Colors.red : Colors.orange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTrack(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width - 32;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: _playerProgress.clamp(0.0, 1.0),
              minHeight: 44,
              backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _playerProgress >= 1.0
                    ? Colors.green
                    : (_monsterProgress >= _playerProgress * 0.9
                    ? Colors.red
                    : Colors.blue),
              ),
            ),
          ),

          // ИГРОК – ЗЕРКАЛЬНО ОТРАЖЁН (БЕЖИТ ВПРАВО)
          Positioned(
            left: (_playerProgress.clamp(0.0, 1.0) * screenWidth * 0.9) + 8,
            top: 8,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isWin
                  ? const Text('🏆', style: TextStyle(fontSize: 28))
                  : _isLose
                  ? const Text('💀', style: TextStyle(fontSize: 28))
                  : Transform.scale(
                scaleX: -1,
                child: const Text('🏃', style: TextStyle(fontSize: 28)),
              ),
            ),
          ),

          // МОНСТР
          Positioned(
            left: (_monsterProgress.clamp(0.0, 1.0) * screenWidth * 0.9) + 8,
            top: 8,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _currentBoss,
                style: TextStyle(fontSize: 28),
                key: ValueKey(_currentBoss),
              ),
            ),
          ),

          // Индикатор форы
          if (_isPlaying && _playerProgress > _monsterProgress && !_isWin && !_isLose)
            Positioned(
              left: 0,
              right: 0,
              top: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚡ Фора ${((_playerProgress - _monsterProgress) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Опасно!
          if (_monsterProgress >= _playerProgress * 0.9 && !_isWin && !_isLose)
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '⚠️ ОПАСНО!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Финиш
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: _playerProgress >= 1.0
                  ? Colors.green
                  : Colors.grey.withOpacity(0.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '🏁',
                    style: TextStyle(
                      fontSize: _playerProgress >= 1.0 ? 16 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameButton() {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_shakeAnimation, _pulseAnimation, _scaleAnimation]),
        builder: (context, child) {
          final shakeX = _shakeAnimation.value * (_random.nextBool() ? 1 : -1);
          final shakeY = _shakeAnimation.value * 0.5 * (_random.nextBool() ? 1 : -1);

          return Transform.scale(
            scale: _isWin || _isLose || _gameFinished
                ? 1.0
                : (_isPlaying ? _pulseAnimation.value : 1.0),
            child: Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: GestureDetector(
                onTap: _onButtonPressed,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: _gameFinished
                          ? [Colors.green.shade700, Colors.green.shade900]
                          : (_isWin
                          ? [Colors.green.shade700, Colors.green.shade900]
                          : (_isLose
                          ? [Colors.grey.shade700, Colors.grey.shade900]
                          : [Colors.red.shade600, Colors.red.shade900])),
                      stops: const [0.3, 1.0],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _gameFinished
                            ? Colors.green.withOpacity(0.5)
                            : (_isWin
                            ? Colors.green.withOpacity(0.5)
                            : (_isLose
                            ? Colors.grey.withOpacity(0.4)
                            : Colors.red.withOpacity(0.5))),
                        blurRadius: _isWin || _gameFinished ? 25 : (_isLose ? 15 : 30),
                        spreadRadius: _isWin || _gameFinished ? 8 : (_isLose ? 3 : 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _gameFinished
                            ? '👑'
                            : (_isWin
                            ? '🏆'
                            : (_isLose
                            ? '😵'
                            : (_isPlaying
                            ? '👆'
                            : '▶️'))),
                        style: const TextStyle(fontSize: 34),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _gameFinished
                            ? 'Легенда!'
                            : (_isWin
                            ? 'Красавчик!'
                            : (_isLose
                            ? 'ЛОХ'
                            : (_isPlaying
                            ? 'ЖМИ!'
                            : 'СТАРТ'))),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusMessage(bool isDark) {
    final defaultColor = isDark ? Colors.white : const Color(0xFF1A1D24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Text(
        _statusMessage,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _isWin
              ? Colors.green
              : (_isLose ? Colors.red : defaultColor),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ==================== ЭКРАН КАМЕРЫ ====================

class _CameraWithOverlayScreen extends StatefulWidget {
  final CameraController cameraController;
  final String overlayText;
  final bool isWin;
  final bool isFinal;
  final VoidCallback onClose;

  const _CameraWithOverlayScreen({
    required this.cameraController,
    required this.overlayText,
    required this.isWin,
    required this.isFinal,
    required this.onClose,
  });

  @override
  State<_CameraWithOverlayScreen> createState() =>
      _CameraWithOverlayScreenState();
}

class _CameraWithOverlayScreenState extends State<_CameraWithOverlayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color glowColor = widget.isWin ? Colors.green : Colors.red;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(widget.cameraController),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withOpacity(0.6),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: glowColor.withOpacity(0.3),
                          blurRadius: 80,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.overlayText,
                      style: TextStyle(
                        fontSize: widget.isFinal ? 60 : 80,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(color: glowColor, blurRadius: 20),
                          Shadow(color: glowColor, blurRadius: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () {
                widget.onClose();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}