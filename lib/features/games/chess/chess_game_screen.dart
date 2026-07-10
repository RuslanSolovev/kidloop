// features/games/chess/chess_game_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chess_models.dart';
import 'chess_api_service.dart';
import 'chess_board_screen.dart';
import 'chess_matchmaking_screen.dart';
import 'chess_history_screen.dart';
import 'chess_leaderboard_screen.dart';
import 'chess_queue_screen.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  List<ChessGameModel> _activeGames = [];
  List<ChessChallenge> _challenges = [];
  ChessRating? _myRating;
  bool _loading = true;
  Timer? _refreshTimer; // 🔥 Таймер автообновления

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _loadData();
    _startAutoRefresh(); // 🔥 Запускаем автообновление
  }

  @override
  void dispose() {
    _controller.dispose();
    _refreshTimer?.cancel(); // 🔥 Останавливаем таймер
    super.dispose();
  }

  // 🔥 Автообновление каждые 5 секунд
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    // 🔥 При автообновлении не показываем индикатор загрузки
    if (_loading) {
      setState(() => _loading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      List<ChessGameModel> games = [];
      List<ChessChallenge> challenges = [];
      ChessRating? rating;

      try {
        games = await ChessApiService.getActiveGames();
      } catch (_) {}

      try {
        challenges = await ChessApiService.getChallenges();
      } catch (_) {}

      if (userId != null) {
        try {
          rating = await ChessApiService.getRating(userId);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _activeGames = games;
          _challenges = challenges;
          _myRating = rating;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
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
        title: const Text('♟ Шахматы',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded, color: Colors.amber),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ChessLeaderboardScreen()),
            ),
            tooltip: 'Рейтинг',
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.orange),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChessHistoryScreen()),
            ),
            tooltip: 'История',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
        onRefresh: _loadData,
        color: Colors.orange,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeTransition(
              opacity: _animation,
              child: _buildRatingCard(
                  isDark, textColor, subTextColor, surfaceColor),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _animation,
              child: _buildPlayButtons(isDark, textColor, surfaceColor),
            ),
            const SizedBox(height: 20),
            if (_challenges.isNotEmpty) ...[
              FadeTransition(
                opacity: _animation,
                child: _buildChallengesSection(
                    isDark, textColor, subTextColor, surfaceColor),
              ),
              const SizedBox(height: 20),
            ],
            if (_activeGames.isNotEmpty) ...[
              FadeTransition(
                opacity: _animation,
                child: _buildActiveGamesSection(
                    isDark, textColor, subTextColor, surfaceColor),
              ),
            ],
            if (_activeGames.isEmpty && _challenges.isEmpty) ...[
              const SizedBox(height: 40),
              FadeTransition(
                opacity: _animation,
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.sports_esports_rounded,
                          size: 64, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('Нет активных игр',
                          style: TextStyle(
                              color: subTextColor, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Начните новую игру!',
                          style: TextStyle(
                              color: subTextColor.withOpacity(0.6),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard(bool isDark, Color textColor, Color subTextColor,
      Color surfaceColor) {
    if (_myRating == null) return const SizedBox.shrink();
    final rating = _myRating!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.deepPurple]),
              boxShadow: [
                BoxShadow(
                    color: Colors.purple.withOpacity(0.3), blurRadius: 16)
              ],
            ),
            child: Text(
              '${rating.rating}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ваш рейтинг',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColor)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniStat('${rating.gamesPlayed}', 'игр', Colors.grey),
                    const SizedBox(width: 16),
                    _miniStat('${rating.wins}', 'побед', Colors.green),
                    const SizedBox(width: 16),
                    _miniStat('${rating.losses}', 'пораж.', Colors.red),
                    const SizedBox(width: 16),
                    _miniStat('${rating.draws}', 'ничьих', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildPlayButtons(
      bool isDark, Color textColor, Color surfaceColor) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ChessMatchmakingScreen()),
            ).then((_) => _loadData()),
            icon: const Icon(Icons.person_add_rounded, size: 24),
            label: const Text('Пригласить друга',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _showRandomMatchmaking(),
            icon: const Icon(Icons.shuffle_rounded, size: 20),
            label: const Text('Случайный соперник (с таймером)',
                style: TextStyle(fontSize: 14)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  void _showRandomMatchmaking() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const ChessQueueScreen()))
        .then((_) => _loadData());
  }

  Widget _buildChallengesSection(bool isDark, Color textColor,
      Color subTextColor, Color surfaceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_active_rounded,
                color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text('Входящие приглашения',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor)),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('${_challenges.length}',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._challenges.map((challenge) => _buildChallengeCard(
            challenge, isDark, textColor, subTextColor, surfaceColor)),
      ],
    );
  }

  Widget _buildChallengeCard(ChessChallenge challenge, bool isDark,
      Color textColor, Color subTextColor, Color surfaceColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.orange.shade100,
            child: Text(
                challenge.fromUserName.isNotEmpty
                    ? challenge.fromUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(challenge.fromUserName,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: textColor)),
                Text('Без таймера',
                    style:
                    TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final gameId = await ChessApiService.respondChallenge(
                  challenge.challengeId, true);
              if (gameId != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ChessBoardScreen(gameId: gameId, hasTimer: false)),
                );
                _loadData();
              }
            },
            style: TextButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.1),
                foregroundColor: Colors.green),
            child: const Text('Принять'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              ChessApiService.respondChallenge(
                  challenge.challengeId, false);
              _loadData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGamesSection(bool isDark, Color textColor,
      Color subTextColor, Color surfaceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Активные игры',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor)),
        const SizedBox(height: 12),
        ..._activeGames.map((game) => _buildActiveGameCard(
            game, isDark, textColor, subTextColor, surfaceColor)),
      ],
    );
  }

  Widget _buildActiveGameCard(ChessGameModel game, bool isDark,
      Color textColor, Color subTextColor, Color surfaceColor) {
    final hasTimer = game.timeControl > 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChessBoardScreen(
                gameId: game.gameId, hasTimer: hasTimer)),
      ).then((_) => _loadData()), // 🔥 Обновляем после возврата из игры
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Column(children: [
              CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: const Text('♔', style: TextStyle(fontSize: 16))),
              const SizedBox(height: 4),
              Text(game.whitePlayerName,
                  style: TextStyle(fontSize: 12, color: subTextColor)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(children: [
                Text('vs',
                    style: TextStyle(color: subTextColor, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasTimer
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasTimer ? '⏱ С таймером' : '📩 Без таймера',
                    style: TextStyle(
                      color: hasTimer ? Colors.orange : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Column(children: [
              CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.black,
                  child: const Text('♚',
                      style:
                      TextStyle(fontSize: 16, color: Colors.white))),
              const SizedBox(height: 4),
              Text(game.blackPlayerName,
                  style: TextStyle(fontSize: 12, color: subTextColor)),
            ]),
          ],
        ),
      ),
    );
  }
}