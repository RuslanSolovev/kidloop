import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'race_monster_mode.dart';
import 'race_multiplayer_mode.dart';

/// Правая панель – выбор режима игры и статистика
class RightPanelLife extends StatefulWidget {
  const RightPanelLife({super.key});

  @override
  State<RightPanelLife> createState() => _RightPanelLifeState();
}

class _RightPanelLifeState extends State<RightPanelLife> {
  static const String _apiUrl = 'https://functions.yandexcloud.net/d4e54708k3gi6cmgnhh4';

  int _totalGames = 0;
  int _wins = 0;
  int _losses = 0;
  int _bestLevel = 0;

  // ⭐ Доски лидеров
  List<_LeaderEntry> _winners = [];
  List<_LeaderEntry> _losers = [];
  bool _leadersLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadLeaders();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalGames = prefs.getInt('race_total_games') ?? 0;
      _wins = prefs.getInt('race_wins') ?? 0;
      _losses = prefs.getInt('race_losses') ?? 0;
      _bestLevel = prefs.getInt('race_best_level') ?? 0;
    });
  }

  // ⭐ Загрузка досок лидеров с сервера
  Future<void> _loadLeaders() async {
    if (_leadersLoading) return;
    _leadersLoading = true;
    try {
      final resp = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'get-leaders'}),
      ).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      final data = jsonDecode(resp.body);
      if (data['ok'] == true) {
        setState(() {
          _winners = (data['winners'] as List? ?? [])
              .map((e) => _LeaderEntry.fromJson(e))
              .toList();
          _losers = (data['losers'] as List? ?? [])
              .map((e) => _LeaderEntry.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Load leaders error: $e');
    } finally {
      if (mounted) {
        setState(() => _leadersLoading = false);
      }
    }
  }

  Future<void> _saveStats({int? addTotal, int? addWin, int? addLoss, int? bestLevel}) async {
    final prefs = await SharedPreferences.getInstance();
    if (addTotal != null) {
      _totalGames += addTotal;
      await prefs.setInt('race_total_games', _totalGames);
    }
    if (addWin != null) {
      _wins += addWin;
      await prefs.setInt('race_wins', _wins);
    }
    if (addLoss != null) {
      _losses += addLoss;
      await prefs.setInt('race_losses', _losses);
    }
    if (bestLevel != null && bestLevel > _bestLevel) {
      _bestLevel = bestLevel;
      await prefs.setInt('race_best_level', _bestLevel);
    }
    setState(() {});
  }

  void _openMonsterMode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RaceMonsterMode()),
    );

    if (result != null && result is Map<String, dynamic>) {
      await _saveStats(
        addTotal: 1,
        addWin: result['win'] == true ? 1 : 0,
        addLoss: result['win'] == false ? 1 : 0,
        bestLevel: result['level'] ?? 0,
      );
    }
  }

  void _openMultiplayerMode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RaceMultiplayerMode()),
    );

    if (result != null && result is Map<String, dynamic>) {
      await _saveStats(
        addTotal: 1,
        addWin: result['win'] == true ? 1 : 0,
        addLoss: result['win'] == false ? 1 : 0,
      );
      // ⭐ Обновляем доски лидеров после мультиплеерной игры
      _loadLeaders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);
    final bgColors = isDark
        ? [const Color(0xFF0F1115), const Color(0xFF1A1D24), const Color(0xFF2A1A1A)]
        : [const Color(0xFFF5F7FA), Colors.white, const Color(0xFFFFF0F0)];

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgColors,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.sports_motorsports_rounded, color: Colors.purple, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🏁 Гонки',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Выбери режим игры',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Карточка статистики
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('🎯', '$_totalGames', 'Игр', isDark),
                        _buildStatItem('🏆', '$_wins', 'Побед', isDark),
                        _buildStatItem('😢', '$_losses', 'Поражений', isDark),
                      ],
                    ),
                    if (_bestLevel > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Лучший уровень: $_bestLevel',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Кнопка "Монстр"
              _buildModeCard(
                emoji: '👾',
                title: 'Режим Монстр',
                subtitle: 'Убегай от монстра, 10 уровней',
                color: Colors.red,
                gradient: const [Colors.red, Colors.deepOrange],
                onTap: _openMonsterMode,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // Кнопка "Мультиплеер"
              _buildModeCard(
                emoji: '👊',
                title: 'Мультиплеер',
                subtitle: 'Соревнуйся с другими игроками',
                color: Colors.purple,
                gradient: const [Colors.purple, Colors.deepPurple],
                onTap: _openMultiplayerMode,
                isDark: isDark,
              ),

              const SizedBox(height: 24),

              // ⭐ Доски лидеров
              _buildLeadersBoard(isDark, textColor),

              const SizedBox(height: 24),

              // Кнопка сброса статистики
              if (_totalGames > 0)
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Сбросить статистику?'),
                          content: const Text('Все данные будут удалены'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Сбросить', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('race_total_games');
                        await prefs.remove('race_wins');
                        await prefs.remove('race_losses');
                        await prefs.remove('race_best_level');
                        await _loadStats();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 14, color: Colors.red.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Сбросить статистику',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ Доска лидеров
  Widget _buildLeadersBoard(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.leaderboard_rounded, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Таблица лидеров',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const Spacer(),
            if (_leadersLoading)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              GestureDetector(
                onTap: _loadLeaders,
                child: Icon(Icons.refresh_rounded, size: 20, color: isDark ? Colors.white38 : Colors.grey),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // Две колонки
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLeaderColumn(
                title: '🏆 Побеждатели',
                subtitle: 'по победам',
                entries: _winners,
                scoreColor: Colors.amber.shade700,
                bgColor: isDark ? Colors.amber.withOpacity(0.08) : Colors.amber.withOpacity(0.12),
                emptyText: 'Пока никого',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLeaderColumn(
                title: '💀 Проигратели',
                subtitle: 'по поражениям',
                entries: _losers,
                scoreColor: Colors.red.shade700,
                bgColor: isDark ? Colors.red.withOpacity(0.08) : Colors.red.withOpacity(0.12),
                emptyText: 'Чисто!',
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaderColumn({
    required String title,
    required String subtitle,
    required List<_LeaderEntry> entries,
    required Color scoreColor,
    required Color bgColor,
    required String emptyText,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: scoreColor)),
          Text(subtitle, style: TextStyle(fontSize: 9, color: scoreColor.withOpacity(0.7))),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  emptyText,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                ),
              ),
            )
          else
            ...List.generate(entries.length, (i) {
              final e = entries[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    // Место (медаль для топ-3)
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: i < 3
                            ? (i == 0 ? Colors.amber : i == 1 ? Colors.grey.shade400 : Colors.brown.shade300)
                            : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: i < 3 ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Аватар
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                      backgroundImage: e.avatar.isNotEmpty ? NetworkImage(e.avatar) : null,
                      child: e.avatar.isEmpty
                          ? Icon(Icons.person, size: 14, color: isDark ? Colors.white38 : Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    // Имя
                    Expanded(
                      child: Text(
                        e.name.length > 10 ? '${e.name.substring(0, 10)}…' : e.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1A1D24),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Счёт
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${e.score}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label, bool isDark) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1A1D24),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required List<Color> gradient,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient.map((c) => c.withOpacity(isDark ? 0.3 : 0.15)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.3 : 0.2),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1D24),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: color,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

// ⭐ Модель для записи таблицы лидеров
class _LeaderEntry {
  final String userId;
  final String name;
  final String avatar;
  final int score;

  _LeaderEntry({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.score,
  });

  factory _LeaderEntry.fromJson(Map<String, dynamic> json) {
    return _LeaderEntry(
      userId: json['user_id'] ?? '',
      name: json['name'] ?? 'Без имени',
      avatar: json['avatar'] ?? '',
      score: json['score'] is int
          ? json['score']
          : int.tryParse(json['score']?.toString() ?? '0') ?? 0,
    );
  }
}