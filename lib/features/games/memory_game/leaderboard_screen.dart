import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _leadersSequence = [];
  List<Map<String, dynamic>> _leadersScatter = [];
  bool _loading = true;
  String? _errorMessage;

  static const String _apiUrl =
      'https://functions.yandexcloud.net/d4ei7lnhipg7enofqsd3';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllLeaderboards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllLeaderboards() async {
    try {
      await Future.wait([
        _loadLeaderboard('memory_sequence'),
        _loadLeaderboard('memory_scatter'),
      ]);
    } catch (_) {
      _errorMessage = 'Не удалось загрузить данные';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLeaderboard(String gameType) async {
    try {
      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "get-leaderboard",
          "game": gameType,
          "limit": 50,
        }),
      )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (data['ok'] == true && data['leaders'] != null) {
        final leaders =
        (data['leaders'] as List).cast<Map<String, dynamic>>();
        setState(() {
          if (gameType == 'memory_sequence') {
            _leadersSequence = leaders;
          } else {
            _leadersScatter = leaders;
          }
        });
      }
    } catch (_) {
      // Оставляем пустой список — покажется "Нет данных"
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
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
          '🏆 Таблица лидеров',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: '📝 Последовательно'),
            Tab(text: '💥 Вразброс'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: textColor),
            ),
          ],
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderList(
              _leadersSequence, isDark, textColor, 'последовательно'),
          _buildLeaderList(
              _leadersScatter, isDark, textColor, 'вразброс'),
        ],
      ),
    );
  }

  Widget _buildLeaderList(
      List<Map<String, dynamic>> leaders,
      bool isDark,
      Color textColor,
      String modeName,
      ) {
    if (leaders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              size: 64,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет данных',
              style: TextStyle(
                color: textColor.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Сыграйте в режиме «$modeName», чтобы попасть в таблицу!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withOpacity(0.3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: leaders.length,
      itemBuilder: (context, index) {
        final leader = leaders[index];
        final rank = leader['rank'] ?? index + 1;
        final isTop3 = rank <= 3;
        final medals = ['🥇', '🥈', '🥉'];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isTop3
                ? LinearGradient(
              colors: rank == 1
                  ? [Colors.amber.withOpacity(0.2), Colors.amber.withOpacity(0.05)]
                  : rank == 2
                  ? [Colors.grey.withOpacity(0.2), Colors.grey.withOpacity(0.05)]
                  : [Colors.orange.withOpacity(0.2), Colors.orange.withOpacity(0.05)],
            )
                : null,
            color: isTop3
                ? null
                : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isTop3
                  ? Colors.amber.withOpacity(0.3)
                  : (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade200),
            ),
            boxShadow: isTop3
                ? [
              BoxShadow(
                color: rank == 1
                    ? Colors.amber.withOpacity(0.2)
                    : rank == 2
                    ? Colors.grey.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                blurRadius: 8,
              )
            ]
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: isTop3
                    ? Text(medals[rank - 1], style: const TextStyle(fontSize: 28))
                    : Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leader['user_name'] ?? 'Игрок',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Уровень ${leader['level'] ?? 1}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isTop3
                        ? [Colors.amber, Colors.orange]
                        : [Colors.orange, Colors.deepOrange],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${leader['score'] ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}