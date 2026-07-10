// features/games/chess/chess_matchmaking_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chess_api_service.dart';

class ChessMatchmakingScreen extends StatefulWidget {
  const ChessMatchmakingScreen({super.key});

  @override
  State<ChessMatchmakingScreen> createState() => _ChessMatchmakingScreenState();
}

class _ChessMatchmakingScreenState extends State<ChessMatchmakingScreen> {
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;
  String? _currentUserId;

  static const String _apiUrl = 'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "friends", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          setState(() {
            _friends = (data['friends'] as List).cast<Map<String, dynamic>>();
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendChallenge(Map<String, dynamic> friend) async {
    final userId = friend['user_id'] ?? '';
    final userName = friend['user_name'] ?? friend['name'] ?? 'Пользователь';

    // 🔥 Отправляем timeControl: 0 для игры без таймера
    final success = await ChessApiService.sendChallenge(
      toUserId: userId,
      toUserName: userName,
      timeControl: 0,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Приглашение отправлено $userName! 🎉'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось отправить приглашение'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
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
        title: const Text('Пригласить друга', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _friends.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Нет друзей для игры', style: TextStyle(color: subTextColor)),
            const SizedBox(height: 8),
            Text('Добавьте друзей в разделе "Пользователи"',
                style: TextStyle(color: subTextColor.withOpacity(0.6), fontSize: 13)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return _buildFriendCard(friend, isDark, textColor, subTextColor, surfaceColor);
        },
      ),
    );
  }

  Widget _buildFriendCard(
      Map<String, dynamic> friend, bool isDark, Color textColor, Color subTextColor, Color surfaceColor) {
    final name = friend['user_name'] ?? friend['name'] ?? 'Пользователь';
    final avatarUrl = friend['avatar_url'] ?? '';

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
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(name[0].toUpperCase(),
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 16)),
                Text('Без ограничения времени',
                    style: TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _sendChallenge(friend),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Пригласить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
