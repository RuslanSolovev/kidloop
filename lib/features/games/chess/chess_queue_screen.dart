// features/games/chess/chess_queue_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'chess_api_service.dart';
import 'chess_board_screen.dart';

class ChessQueueScreen extends StatefulWidget {
  const ChessQueueScreen({super.key});

  @override
  State<ChessQueueScreen> createState() => _ChessQueueScreenState();
}

class _ChessQueueScreenState extends State<ChessQueueScreen> with TickerProviderStateMixin {
  Timer? _checkTimer;
  bool _searching = true;
  String? _gameId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    _joinQueue();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _pulseController.dispose();
    _leaveQueue();
    super.dispose();
  }

  Future<void> _joinQueue() async {
    final result = await ChessApiService.joinQueue();
    if (result != null && mounted) {
      if (result['game_id'] != null) {
        // Сразу нашли соперника!
        _startGame(result['game_id']);
      } else {
        // Ждём соперника
        _startPolling();
      }
    }
  }

  void _startPolling() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_searching) return;

      // Проверяем активные игры
      final games = await ChessApiService.getActiveGames();
      if (games.isNotEmpty && mounted) {
        // Берём последнюю созданную игру
        final game = games.first;
        _startGame(game.gameId);
      }
    });
  }

  void _startGame(String gameId) {

    setState(() => _searching = false);
    _checkTimer?.cancel();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChessBoardScreen(gameId: gameId, hasTimer: true),
          ),
        );
      }
    });
  }

  Future<void> _leaveQueue() async {
    await ChessApiService.leaveQueue();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final backgroundColor = isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Поиск соперника'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Container(
                width: 120,
                height: 120,
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
                child: const Icon(Icons.search_rounded, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _searching ? 'Поиск соперника...' : 'Соперник найден! 🎉',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 12),
            if (_searching) ...[
              const CircularProgressIndicator(color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'Ожидайте, другой игрок тоже ищет игру',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  _leaveQueue();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('Отмена'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}