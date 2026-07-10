// features/games/chess/chess_history_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chess_api_service.dart';
import 'chess_models.dart';

class ChessHistoryScreen extends StatefulWidget {
  const ChessHistoryScreen({super.key});

  @override
  State<ChessHistoryScreen> createState() => _ChessHistoryScreenState();
}

class _ChessHistoryScreenState extends State<ChessHistoryScreen> {
  List<ChessGameModel> _games = [];
  bool _loading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    if (_currentUserId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final games = await ChessApiService.getGameHistory(_currentUserId!);
      if (mounted) {
        setState(() {
          _games = games;
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
    final backgroundColor = isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text('📜 История игр', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _games.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Нет завершённых игр', style: TextStyle(color: subTextColor, fontSize: 16)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _games.length,
        itemBuilder: (context, index) {
          final game = _games[index];
          final isWhite = _currentUserId == game.whitePlayerId;
          final opponentName = isWhite ? game.blackPlayerName : game.whitePlayerName;
          final myColor = isWhite ? 'Белые' : 'Чёрные';
          final resultText = _getResultText(game, isWhite);
          final resultColor = _getResultColor(game, isWhite);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: resultColor.withOpacity(0.2),
                  ),
                  child: Center(
                    child: Text(
                      resultText,
                      style: TextStyle(color: resultColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('vs $opponentName', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                      const SizedBox(height: 4),
                      Text('$myColor • ${_formatDate(game.createdAt)}',
                          style: TextStyle(color: subTextColor, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getResultText(ChessGameModel game, bool isWhite) {
    final result = game.result;
    if (result == GameResult.draw) return '½';
    if (result == GameResult.whiteWin && isWhite) return '1';
    if (result == GameResult.blackWin && !isWhite) return '1';
    if (result == GameResult.whiteWinTimeout && isWhite) return '1';
    if (result == GameResult.blackWinTimeout && !isWhite) return '1';
    return '0';
  }

  Color _getResultColor(ChessGameModel game, bool isWhite) {
    final result = game.result;
    if (result == GameResult.draw) return Colors.grey;
    if ((result == GameResult.whiteWin || result == GameResult.whiteWinTimeout) && isWhite) return Colors.green;
    if ((result == GameResult.blackWin || result == GameResult.blackWinTimeout) && !isWhite) return Colors.green;
    return Colors.red;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}