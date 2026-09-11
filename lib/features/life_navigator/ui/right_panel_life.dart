// features/life_navigator/ui/right_panel_life.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'race_monster_mode.dart';
import 'race_multiplayer_mode.dart';

// ==================== iOS DESIGN SYSTEM ====================

class _IOS {
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color darkBg = Color(0xFF000000);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);

  static const Color blue = Color(0xFF007AFF);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color purple = Color(0xFFAF52DE);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color indigo = Color(0xFF5856D6);
  static const Color pink = Color(0xFFFF2D55);
  static const Color red = Color(0xFFFF3B30);
  static const Color gray = Color(0xFF8E8E93);

  static Color separator(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color textPrimary(bool isDark) => isDark ? Colors.white : Colors.black;
  static Color textSecondary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.6)
      : const Color(0xFF3C3C43).withOpacity(0.6);
  static Color textTertiary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.3)
      : const Color(0xFF3C3C43).withOpacity(0.3);
}

/// Правая панель – выбор режима игры и статистика
class RightPanelLife extends StatefulWidget {
  const RightPanelLife({super.key});

  @override
  State<RightPanelLife> createState() => _RightPanelLifeState();
}

class _RightPanelLifeState extends State<RightPanelLife> {
  static const String _apiUrl =
      'https://functions.yandexcloud.net/d4e54708k3gi6cmgnhh4';

  int _totalGames = 0;
  int _wins = 0;
  int _losses = 0;
  int _bestLevel = 0;

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
    if (!mounted) return;
    setState(() {
      _totalGames = prefs.getInt('race_total_games') ?? 0;
      _wins = prefs.getInt('race_wins') ?? 0;
      _losses = prefs.getInt('race_losses') ?? 0;
      _bestLevel = prefs.getInt('race_best_level') ?? 0;
    });
  }

  Future<void> _loadLeaders() async {
    if (_leadersLoading) return;
    setState(() => _leadersLoading = true);
    try {
      final resp = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'get-leaders'}),
      );
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
      if (mounted) setState(() => _leadersLoading = false);
    }
  }

  Future<void> _saveStats({
    int? addTotal,
    int? addWin,
    int? addLoss,
    int? bestLevel,
  }) async {
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
    if (mounted) setState(() {});
  }

  void _openMonsterMode() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RaceMonsterMode()),
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
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RaceMultiplayerMode()),
    );
    if (result != null && result is Map<String, dynamic>) {
      await _saveStats(
        addTotal: 1,
        addWin: result['win'] == true ? 1 : 0,
        addLoss: result['win'] == false ? 1 : 0,
      );
      _loadLeaders();
    }
  }

  Future<void> _resetStats() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildIosAlert(
        context: ctx,
        title: 'Сбросить статистику?',
        message: 'Все локальные данные будут удалены',
        confirmLabel: 'Сбросить',
        isDestructive: true,
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = _IOS.textPrimary(isDark);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _IOS.bg(isDark),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark, textColor),
              const SizedBox(height: 24),
              _buildStatsCard(isDark, textColor),
              const SizedBox(height: 24),

              // Section: Режимы игры
              _buildSectionTitle('Режимы игры', isDark),
              const SizedBox(height: 12),
              _buildModeCard(
                emoji: '👾',
                title: 'Режим Монстр',
                subtitle: 'Убегай от монстра, 10 уровней',
                color: _IOS.red,
                onTap: _openMonsterMode,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildModeCard(
                emoji: '👊',
                title: 'Мультиплеер',
                subtitle: 'Соревнуйся с другими игроками',
                color: _IOS.purple,
                onTap: _openMultiplayerMode,
                isDark: isDark,
              ),

              const SizedBox(height: 28),

              // Section: Лидеры
              _buildSectionTitle(
                'Таблица лидеров',
                isDark,
                trailing: _leadersLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _IOS.blue,
                  ),
                )
                    : GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _loadLeaders();
                  },
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: _IOS.textTertiary(isDark),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLeaderColumn(
                      emoji: '🏆',
                      title: 'Победители',
                      subtitle: 'по победам',
                      entries: _winners,
                      accent: _IOS.orange,
                      emptyText: 'Пока никого',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLeaderColumn(
                      emoji: '💀',
                      title: 'Проигравшие',
                      subtitle: 'по поражениям',
                      entries: _losers,
                      accent: _IOS.red,
                      emptyText: 'Чисто!',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Reset
              if (_totalGames > 0)
                Center(
                  child: GestureDetector(
                    onTap: _resetStats,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _IOS.red.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: _IOS.red,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Сбросить статистику',
                            style: TextStyle(
                              fontSize: 13,
                              color: _IOS.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER — iOS Large Title
  // ============================================================

  Widget _buildHeader(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ИГРЫ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: _IOS.textTertiary(isDark),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Гонки',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            height: 1.05,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Выбери режим и побей свой рекорд',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: _IOS.textSecondary(isDark),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title, bool isDark, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: _IOS.textSecondary(isDark),
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ============================================================
  // STATS CARD
  // ============================================================

  Widget _buildStatsCard(bool isDark, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: _IOS.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _IOS.separator(isDark)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    value: '$_totalGames',
                    label: 'Игр',
                    color: _IOS.blue,
                    isDark: isDark,
                  ),
                ),
                _dividerVertical(isDark),
                Expanded(
                  child: _buildStatItem(
                    value: '$_wins',
                    label: 'Побед',
                    color: _IOS.green,
                    isDark: isDark,
                  ),
                ),
                _dividerVertical(isDark),
                Expanded(
                  child: _buildStatItem(
                    value: '$_losses',
                    label: 'Поражений',
                    color: _IOS.red,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          if (_bestLevel > 0) ...[
            Divider(height: 0.5, color: _IOS.separator(isDark)),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _IOS.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: _IOS.orange,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Лучший уровень',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_bestLevel',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: _IOS.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dividerVertical(bool isDark) {
    return Container(
      width: 0.5,
      height: 40,
      color: _IOS.separator(isDark),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            color: _IOS.textSecondary(isDark),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MODE CARD
  // ============================================================

  Widget _buildModeCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _IOS.card(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _IOS.separator(isDark)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      height: 1.1,
                      color: _IOS.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _IOS.textSecondary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _IOS.textTertiary(isDark),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LEADER COLUMN
  // ============================================================

  Widget _buildLeaderColumn({
    required String emoji,
    required String title,
    required String subtitle,
    required List<_LeaderEntry> entries,
    required Color accent,
    required String emptyText,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _IOS.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _IOS.separator(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.1,
                        color: _IOS.textPrimary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _IOS.textTertiary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  emptyText,
                  style: TextStyle(
                    fontSize: 12,
                    color: _IOS.textTertiary(isDark),
                  ),
                ),
              ),
            )
          else
            ...List.generate(entries.length, (i) {
              final e = entries[i];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == entries.length - 1 ? 0 : 8,
                ),
                child: _buildLeaderRow(
                  rank: i + 1,
                  entry: e,
                  accent: accent,
                  isDark: isDark,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLeaderRow({
    required int rank,
    required _LeaderEntry entry,
    required Color accent,
    required bool isDark,
  }) {
    final isTop3 = rank <= 3;
    final medalColor = rank == 1
        ? const Color(0xFFFFCC00)
        : rank == 2
        ? const Color(0xFFB0B0B0)
        : const Color(0xFFCD7F32);

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isTop3
                ? medalColor.withOpacity(0.18)
                : (isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05)),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
              color: isTop3 ? medalColor : _IOS.textTertiary(isDark),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: entry.avatar.isNotEmpty
              ? Image.network(
            entry.avatar,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              Icons.person_rounded,
              size: 14,
              color: _IOS.textTertiary(isDark),
            ),
          )
              : Icon(
            Icons.person_rounded,
            size: 14,
            color: _IOS.textTertiary(isDark),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: _IOS.textPrimary(isDark),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${entry.score}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // iOS ALERT (Widget builder)
  // ============================================================

  Widget _buildIosAlert({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _IOS.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _IOS.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 0.5, color: _IOS.separator(isDark)),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: const Text(
                        'Отмена',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: _IOS.blue,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 50,
                  color: _IOS.separator(isDark),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: Text(
                        confirmLabel,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isDestructive ? _IOS.red : _IOS.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== LEADER ENTRY ====================

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