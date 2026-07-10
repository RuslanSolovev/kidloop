// features/games/chess/chess_leaderboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChessLeaderboardScreen extends StatefulWidget {
  const ChessLeaderboardScreen({super.key});

  @override
  State<ChessLeaderboardScreen> createState() => _ChessLeaderboardScreenState();
}

class _ChessLeaderboardScreenState extends State<ChessLeaderboardScreen> {
  List<Map<String, dynamic>> _leaders = [];
  bool _loading = true;

  // 🔥 Исправлен URL на chess-api
  static const String _apiUrl = 'https://functions.yandexcloud.net/d4edmoonsukf22mq48uo';

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-leaderboard", "game": "chess", "limit": 50}),
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          setState(() {
            _leaders = (data['leaders'] as List).cast<Map<String, dynamic>>();
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
        title: const Text('🏆 Рейтинг шахматистов', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _leaders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Нет данных', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16)),
            const SizedBox(height: 8),
            Text('Сыграйте в шахматы, чтобы попасть в рейтинг!',
                style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 13)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaders.length,
        itemBuilder: (context, index) {
          final leader = _leaders[index];
          final rank = leader['rank'] ?? index + 1;
          final isTop3 = rank <= 3;
          final medals = ['🥇', '🥈', '🥉'];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isTop3 ? Colors.amber.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: isTop3
                      ? Text(medals[rank - 1], style: const TextStyle(fontSize: 28))
                      : Text('$rank', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16), textAlign: TextAlign.center),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(leader['user_name'] ?? 'Игрок', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                      Text('Игр: ${leader['games_played'] ?? 0} • Побед: ${leader['wins'] ?? 0}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurple]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${leader['rating'] ?? 1200}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}