import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RaceMultiplayerMode extends StatefulWidget {
  const RaceMultiplayerMode({super.key});
  @override
  State<RaceMultiplayerMode> createState() => _RaceMultiplayerModeState();
}

class _RaceMultiplayerModeState extends State<RaceMultiplayerMode> with SingleTickerProviderStateMixin {
  static const String _apiUrl = 'https://functions.yandexcloud.net/d4e54708k3gi6cmgnhh4';
  static const int _countdownMs = 3000;

  String? _gameId;
  String? _opponentId;
  String _opponentName = 'Соперник';
  String _opponentAvatar = '';

  double _myProgress = 0.0;
  double _opponentProgress = 0.0;
  int _countdown = 0;
  bool _isCountingDown = false;
  bool _isPlaying = false;
  bool _isWin = false;
  bool _isLose = false;
  bool _gameFinished = false;
  bool _isWaiting = false;
  bool _isSearching = false;
  bool _gameStarted = false;
  String _statusMessage = 'Нажми, чтобы начать!';

  // ⭐ Медленнее: 0.008 вместо 0.012 (на 50% дольше игра)
  final double _pressBoost = 0.008;

  DateTime? _gameStartAt;
  DateTime? _gamePlayStart;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  Timer? _gameTimer;
  Timer? _queueTimer;
  Timer? _syncTimer;
  Timer? _countdownTimer;
  Timer? _uiCountdownTimer;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _finishing = false;

  Duration _serverTimeOffset = Duration.zero;
  final List<double> _offsetSamples = [];
  DateTime? _lastUpdateSent;
  double _pendingProgress = 0.0;
  Timer? _throttleTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCamera();
  }

  void _initAnimations() {
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _shakeAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut));
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final front = _cameras!.where((c) => c.lensDirection == CameraLensDirection.front).firstOrNull ?? _cameras![0];
        _cameraController = CameraController(front, ResolutionPreset.medium);
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) { debugPrint('Camera error: $e'); }
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _shakeController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _cancelAllTimers() {
    _gameTimer?.cancel(); _queueTimer?.cancel(); _syncTimer?.cancel();
    _countdownTimer?.cancel(); _uiCountdownTimer?.cancel(); _throttleTimer?.cancel();
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  void _resetGame() {
    _cancelAllTimers();
    setState(() {
      _gameId = null; _opponentId = null;
      _opponentName = 'Соперник'; _opponentAvatar = '';
      _myProgress = 0.0; _opponentProgress = 0.0;
      _countdown = 0; _isCountingDown = false;
      _isPlaying = false; _isWin = false; _isLose = false;
      _gameFinished = false; _isWaiting = false; _isSearching = false;
      _gameStarted = false; _finishing = false;
      _gameStartAt = null; _gamePlayStart = null;
      _serverTimeOffset = Duration.zero;
      _offsetSamples.clear();
      _lastUpdateSent = null;
      _statusMessage = 'Нажми, чтобы начать!';
    });
  }

  void _computeNtpOffset(Map<String, dynamic> data, int t1Ms, int t4Ms) {
    final r = data['server_receive_time'] ?? '';
    final s = data['server_send_time'] ?? '';
    if (r.isEmpty || s.isEmpty) return;
    try {
      final t2 = DateTime.parse(r).toUtc().millisecondsSinceEpoch;
      final t3 = DateTime.parse(s).toUtc().millisecondsSinceEpoch;
      final offsetMs = ((t2 - t1Ms) + (t3 - t4Ms)) / 2.0;
      final rttMs = (t4Ms - t1Ms) - (t3 - t2);
      if (rttMs < 0 || rttMs > 3000) return;
      _offsetSamples.add(offsetMs);
      if (_offsetSamples.length > 5) _offsetSamples.removeAt(0);
      final sorted = List<double>.from(_offsetSamples)..sort();
      _serverTimeOffset = Duration(milliseconds: sorted[sorted.length ~/ 2].round());
    } catch (_) {}
  }

  DateTime _serverNow() => DateTime.now().toUtc().add(_serverTimeOffset);

  Future<void> _findMatch() async {
    if (_isSearching || _gameStarted) return;
    final userId = await _getUserId();
    if (userId == null) return;
    setState(() { _isSearching = true; _statusMessage = '🔍 Ищем соперника...'; });
    final t1 = DateTime.now().millisecondsSinceEpoch;
    try {
      final resp = await http.post(Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'find-match', 'user_id': userId}),
      ).timeout(const Duration(seconds: 8));
      final t4 = DateTime.now().millisecondsSinceEpoch;
      final data = jsonDecode(resp.body);
      if (data['ok'] == true) {
        _computeNtpOffset(data, t1, t4);
        if (data['waiting'] == true) {
          setState(() { _isWaiting = true; _isSearching = false; _statusMessage = '⏳ Ожидаем соперника...'; });
          _startQueueCheck();
        } else {
          _onGameFound(data);
        }
      } else {
        setState(() { _isSearching = false; _statusMessage = '❌ Ошибка поиска'; });
      }
    } catch (e) {
      setState(() { _isSearching = false; _statusMessage = '❌ Ошибка: $e'; });
    }
  }

  void _onGameFound(Map<String, dynamic> data) {
    if (_gameStarted) return;
    _queueTimer?.cancel();
    setState(() {
      _gameId = data['game_id'];
      _opponentId = data['opponent_id'];
      _opponentName = data['opponent_name'] ?? 'Соперник';
      _opponentAvatar = data['opponent_avatar'] ?? '';
      _isSearching = false; _isWaiting = false; _gameStarted = true;
      _statusMessage = '👊 Найден: $_opponentName!';
    });

    final startedAtStr = data['started_at'] ?? '';
    if (startedAtStr.isEmpty) { _startLocalCountdown(); return; }

    final startedAt = DateTime.parse(startedAtStr).toUtc();
    _gameStartAt = startedAt;
    _gamePlayStart = startedAt.add(const Duration(milliseconds: _countdownMs));

    final now = _serverNow();
    if (now.isBefore(_gamePlayStart!)) {
      _startSyncedCountdown();
    } else {
      _startPlaying();
    }
  }

  void _startSyncedCountdown() {
    _countdownTimer?.cancel(); _uiCountdownTimer?.cancel();
    final waitMs = _gamePlayStart!.difference(_serverNow()).inMilliseconds;
    if (waitMs <= 0) { _startPlaying(); return; }
    setState(() { _isCountingDown = true; _countdown = (waitMs / 1000).ceil(); });

    _countdownTimer = Timer(Duration(milliseconds: waitMs), () {
      if (!mounted) return;
      _uiCountdownTimer?.cancel();
      _startPlaying();
    });

    _uiCountdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isCountingDown) { timer.cancel(); return; }
      final rem = _gamePlayStart!.difference(_serverNow()).inMilliseconds;
      if (rem <= 0) { timer.cancel(); return; }
      final newCd = (rem / 1000).ceil();
      if (newCd != _countdown && newCd >= 0) {
        setState(() { _countdown = newCd; _statusMessage = '🎯 Старт через $_countdown...'; });
      }
    });
  }

  void _startPlaying() {
    setState(() {
      _isCountingDown = false;
      _isPlaying = true;
      _countdown = 0;
      _statusMessage = '🔥 ЖМИ БЫСТРЕЕ!';
      _myProgress = 0.0;
      _opponentProgress = 0.0;
    });

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 500), (t) async {
      if (!mounted) { t.cancel(); return; }
      await _syncGame();
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_gameFinished || _finishing) { timer.cancel(); return; }

      // ✅ Только прогресс-триггеры — никакого таймера!
      if (_myProgress >= 1.0) {
        _myProgress = 1.0; timer.cancel(); _syncTimer?.cancel();
        if (!_gameFinished && !_finishing) { _finishing = true; _requestFinish('player_finished'); }
      } else if (_opponentProgress >= 1.0) {
        _opponentProgress = 1.0; timer.cancel(); _syncTimer?.cancel();
        if (!_gameFinished && !_finishing) { _finishing = true; _requestFinish('opponent_finished'); }
      }
    });
  }

  void _startLocalCountdown() {
    final now = DateTime.now().toUtc();
    _gameStartAt = now;
    _gamePlayStart = now.add(const Duration(milliseconds: _countdownMs));
    _startSyncedCountdown();
  }

  void _startQueueCheck() {
    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _isSearching || _gameStarted) { timer.cancel(); return; }
      final userId = await _getUserId();
      if (userId == null) { timer.cancel(); return; }
      final t1 = DateTime.now().millisecondsSinceEpoch;
      try {
        final r = await http.post(Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'check-queue', 'user_id': userId}));
        final t4 = DateTime.now().millisecondsSinceEpoch;
        final data = jsonDecode(r.body);
        _computeNtpOffset(data, t1, t4);
        if (data['ok'] == true && data['in_queue'] == false) {
          timer.cancel();
          if (mounted && !_gameStarted && !_isSearching) _findMatch();
        }
      } catch (_) {}
    });
  }

  Future<void> _syncGame() async {
    if (_gameId == null || _gameFinished || !mounted) return;
    final t1 = DateTime.now().millisecondsSinceEpoch;
    try {
      final userId = await _getUserId();
      if (userId == null || !mounted) return;
      final r = await http.post(Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'get-game', 'game_id': _gameId, 'user_id': userId}),
      ).timeout(const Duration(seconds: 5));
      final t4 = DateTime.now().millisecondsSinceEpoch;
      if (!mounted) return;
      final data = jsonDecode(r.body);
      _computeNtpOffset(data, t1, t4);

      if (data['ok'] == true && data['game'] != null) {
        final g = data['game'];
        final status = g['status'] ?? '';
        final winnerId = g['winner_id'] ?? '';
        final p1p = (g['player1_progress'] ?? 0).toDouble();
        final p2p = (g['player2_progress'] ?? 0).toDouble();
        final p1Id = g['player1_id'] ?? '';
        final isP1 = p1Id == userId;
        final myP = isP1 ? p1p : p2p;
        final oppP = isP1 ? p2p : p1p;

        if (mounted) {
          setState(() {
            if (myP > _myProgress) _myProgress = myP;
            if (oppP > _opponentProgress) _opponentProgress = oppP;
          });
        }

        if (!_gameFinished && status == 'finished') {
          _gameTimer?.cancel(); _syncTimer?.cancel();
          _applyFinishResult(winnerId == userId, 'server_finished');
        }
      }
    } catch (_) {}
  }

  Future<void> _requestFinish(String reason) async {
    if (_gameId == null || _gameFinished) return;
    _gameTimer?.cancel(); _syncTimer?.cancel();
    await _updateProgressAndWait(_myProgress);
    try {
      final userId = await _getUserId();
      if (userId == null) return;
      final r = await http.post(Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'finish-game', 'game_id': _gameId, 'user_id': userId, 'reason': reason}),
      ).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      final data = jsonDecode(r.body);
      if (data['ok'] == true && data['game'] != null) {
        _applyFinishResult((data['game']['winner_id'] ?? '') == userId, reason);
        return;
      }
    } catch (_) {}
    if (!_gameFinished) await _syncGame();
  }

  Future<void> _updateProgressAndWait(double progress) async {
    if (_gameId == null) return;
    try {
      final userId = await _getUserId();
      if (userId == null) return;
      await http.post(Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'update-progress', 'game_id': _gameId, 'user_id': userId, 'progress': progress}),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  void _updateProgress(double progress) {
    if (_gameId == null || !_isPlaying) return;
    _pendingProgress = progress;
    final now = DateTime.now();
    if (_lastUpdateSent == null || now.difference(_lastUpdateSent!).inMilliseconds >= 50) {
      _lastUpdateSent = now;
      _sendProgressUpdate(progress);
    } else {
      _throttleTimer?.cancel();
      final delay = 50 - now.difference(_lastUpdateSent!).inMilliseconds;
      _throttleTimer = Timer(Duration(milliseconds: delay), () {
        _lastUpdateSent = DateTime.now();
        _sendProgressUpdate(_pendingProgress);
      });
    }
  }

  void _sendProgressUpdate(double progress) {
    _getUserId().then((userId) {
      if (userId == null || _gameId == null) return;
      http.post(Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'update-progress', 'game_id': _gameId, 'user_id': userId, 'progress': progress}),
      ).catchError((_) {});
    });
  }

  void _applyFinishResult(bool isWin, String reason) {
    if (_gameFinished) return;
    _gameFinished = true; _finishing = false;
    _cancelAllTimers();
    setState(() {
      _isPlaying = false; _isCountingDown = false;
      if (isWin) { _isWin = true; _isLose = false; _statusMessage = '🏆 ПОБЕДА!'; }
      else { _isWin = false; _isLose = true; _statusMessage = '😱 ПРОИГРЫШ!'; }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _openCameraWithMessage(isWin ? 'Красавчик! 🏆' : 'ЛОХ', isWin: isWin);
    });
  }

  void _onButtonPressed() {
    if (_isCountingDown || _gameFinished) return;
    if (_isSearching || _isWaiting) { _cancelSearch(); return; }
    if (!_isPlaying) { _findMatch(); return; }

    HapticFeedback.mediumImpact();
    setState(() {
      _myProgress += _pressBoost;
      if (_myProgress > 1.0) _myProgress = 1.0;
    });
    _updateProgress(_myProgress);
    _shakeController.forward(from: 0.0);
    _scaleController.forward(from: 0.0);
  }

  void _cancelSearch() {
    _queueTimer?.cancel();
    setState(() { _isSearching = false; _isWaiting = false; _gameStarted = false; _statusMessage = 'Поиск отменён'; });
    _getUserId().then((uid) {
      if (uid != null) http.post(Uri.parse(_apiUrl), headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'action': 'cancel-queue', 'user_id': uid})).catchError((_) {});
    });
  }

  Future<bool> _handleBackButton() async {
    if (_isPlaying || _isCountingDown) {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Выйти из игры?'),
          content: const Text('Игра будет засчитана как проигрыш.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Остаться')),
            TextButton(onPressed: () {
              Navigator.pop(ctx, true);
              if (_gameId != null) {
                _getUserId().then((uid) {
                  if (uid != null) http.post(Uri.parse(_apiUrl),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'action': 'finish-game', 'game_id': _gameId, 'user_id': uid, 'reason': 'surrender'}),
                  ).catchError((_) {});
                });
              }
            }, child: const Text('Выйти', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      return result ?? false;
    }
    return true;
  }

  void _openCameraWithMessage(String message, {required bool isWin}) {
    if (!mounted) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📸 $message'), backgroundColor: isWin ? Colors.green : Colors.red, duration: const Duration(seconds: 2)),
      );
      Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pop(context, {'win': isWin}); });
      return;
    }
    Navigator.push(context, MaterialPageRoute(fullscreenDialog: true,
      builder: (ctx) => _CameraWithOverlayScreen(cameraController: _cameraController!, overlayText: message, isWin: isWin,
        onClose: () { if (mounted) Navigator.pop(context, {'win': isWin}); },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackButton();
        if (shouldPop && mounted) Navigator.pop(context, {'win': _isWin});
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1115) : Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('👊 Мультиплеер'),
          backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
          foregroundColor: textColor, elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: textColor),
            onPressed: () async {
              final shouldPop = await _handleBackButton();
              if (shouldPop && mounted) Navigator.pop(context, {'win': _isWin});
            },
          ),
        ),
        body: _buildGameUI(isDark, textColor),
      ),
    );
  }

  Widget _buildGameUI(bool isDark, Color textColor) {
    return Stack(children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _buildHeader(isDark, textColor), const SizedBox(height: 12),
        SizedBox(height: 90, child: _buildProgressTrack(isDark)), const SizedBox(height: 12),
        Center(child: _buildGameButton()), const SizedBox(height: 16),
        _buildStatusMessage(isDark),
      ])),
      if (_isCountingDown) Container(color: Colors.black54, child: Center(
        child: Text('$_countdown', style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: Colors.white,
            shadows: [Shadow(color: Colors.blue, blurRadius: 40), Shadow(color: Colors.blue, blurRadius: 80)]),
        ),
      )),
    ]);
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    final distance = ((_myProgress - _opponentProgress) * 100).clamp(0.0, 100.0);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('👊 Мультиплеер', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.purple.shade700)),
          const SizedBox(width: 6),
          if (_opponentName.isNotEmpty && _isPlaying)
            Text('vs $_opponentName', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
        ]),
        // ✅ Убрали время, показываем прогресс
        Text('${(_myProgress * 100).toStringAsFixed(0)}% пройдено',
            style: TextStyle(fontSize: 13, color: _myProgress > 0.8 ? Colors.green : textColor, fontWeight: FontWeight.w600)),
      ]),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: distance < 10 ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: distance < 10 ? Colors.red : Colors.green, width: 1.5)),
        child: Text(distance >= 0 ? '+${distance.toStringAsFixed(0)}%' : '${distance.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: distance < 10 ? Colors.red : Colors.green)),
      ),
    ]);
  }

  Widget _buildProgressTrack(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: LinearProgressIndicator(
            value: _myProgress.clamp(0.0, 1.0), minHeight: 44,
            backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_myProgress >= 1.0 ? Colors.green : (_opponentProgress >= _myProgress * 0.9 ? Colors.red : Colors.blue)),
          )),
          Positioned(left: (_opponentProgress.clamp(0.0, 1.0) * screenWidth * 0.9) + 8, top: 8,
              child: Text('👤', style: TextStyle(fontSize: 28, color: Colors.orange.shade400))),
          Positioned(left: (_myProgress.clamp(0.0, 1.0) * screenWidth * 0.9) + 8, top: 8,
              child: _isWin ? const Text('🏆', style: TextStyle(fontSize: 28)) : _isLose ? const Text('💀', style: TextStyle(fontSize: 28)) : Transform.scale(scaleX: -1, child: const Text('🏃', style: TextStyle(fontSize: 28)))),
          if (_opponentProgress >= _myProgress * 0.9 && !_isWin && !_isLose)
            Positioned(left: 0, right: 0, bottom: 2, child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(6)),
                child: const Text('⚠️ ОПАСНО!', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))))),
          Positioned(right: 6, top: 0, bottom: 0, child: Container(width: 2,
              color: _myProgress >= 1.0 ? Colors.green : Colors.grey.withOpacity(0.5),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🏁', style: TextStyle(fontSize: _myProgress >= 1.0 ? 16 : 12))]))),
        ]));
  }

  Widget _buildGameButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_shakeAnimation, _pulseAnimation, _scaleAnimation]),
      builder: (ctx, child) => Transform.scale(
        scale: _isPlaying && !_isCountingDown ? _pulseAnimation.value : 1.0,
        child: GestureDetector(onTap: _onButtonPressed, child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
              gradient: RadialGradient(colors:
              _isCountingDown ? [Colors.orange.shade600, Colors.orange.shade900] :
              _isSearching || _isWaiting ? [Colors.grey.shade600, Colors.grey.shade900] :
              _gameFinished || _isWin ? [Colors.green.shade700, Colors.green.shade900] :
              _isLose ? [Colors.grey.shade700, Colors.grey.shade900] :
              [Colors.red.shade600, Colors.red.shade900],
                  stops: const [0.3, 1.0]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: _isPlaying ? 30 : 10, spreadRadius: _isPlaying ? 10 : 3)]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_isCountingDown ? '⏳' : _isSearching || _isWaiting ? '⏳' : _gameFinished || _isWin ? '🏆' : _isLose ? '😵' : _isPlaying ? '👆' : '👊', style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 2),
            Text(_isCountingDown ? 'Жди...' : _isSearching || _isWaiting ? 'Поиск...' : _gameFinished || _isWin ? 'Победа!' : _isLose ? 'ЛОХ' : _isPlaying ? 'ЖМИ!' : 'ИГРАТЬ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
          ]),
        )),
      ),
    );
  }

  Widget _buildStatusMessage(bool isDark) {
    final defaultColor = isDark ? Colors.white : const Color(0xFF1A1D24);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))),
        child: Text(_statusMessage, style: TextStyle(fontSize: _isCountingDown ? 24 : 14, fontWeight: FontWeight.w700,
            color: _isWin ? Colors.green : (_isLose ? Colors.red : defaultColor)), textAlign: TextAlign.center));
  }
}

class _CameraWithOverlayScreen extends StatefulWidget {
  final CameraController cameraController;
  final String overlayText;
  final bool isWin;
  final VoidCallback onClose;
  const _CameraWithOverlayScreen({required this.cameraController, required this.overlayText, required this.isWin, required this.onClose});
  @override
  State<_CameraWithOverlayScreen> createState() => _CameraWithOverlayScreenState();
}

class _CameraWithOverlayScreenState extends State<_CameraWithOverlayScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pc;
  late Animation<double> _pa;
  @override
  void initState() {
    super.initState();
    _pc = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _pa = Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _pc, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _pc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final c = widget.isWin ? Colors.green : Colors.red;
    return Scaffold(backgroundColor: Colors.black, body: Stack(fit: StackFit.expand, children: [
      CameraPreview(widget.cameraController),
      Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.6)]))),
      Center(child: AnimatedBuilder(animation: _pa, builder: (ctx, child) => Transform.scale(scale: _pa.value,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 40, spreadRadius: 10)]),
            child: Text(widget.overlayText, style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: Colors.white,
                letterSpacing: 4, shadows: [Shadow(color: c, blurRadius: 20)])),
          )))),
      Positioned(top: 40, right: 20, child: GestureDetector(onTap: () { widget.onClose(); Navigator.pop(context); },
          child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 28)))),
    ]));
  }
}