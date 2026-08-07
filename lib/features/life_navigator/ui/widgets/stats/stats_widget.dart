// features/life_navigator/ui/widgets/stats/stats_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../base_life_widget.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';

// ============================================================
// ОСНОВНОЙ ВИДЖЕТ СТАТИСТИКИ
// ============================================================

class StatsWidget extends BaseLifeWidget {
  const StatsWidget({
    super.key,
    required super.isDark,
    super.isCompact = true,
  });

  @override
  State<StatsWidget> createState() => _StatsWidgetState();
}

class _StatsWidgetState extends State<StatsWidget> with LifeWidgetMixin<StatsWidget> {
  bool _isExpanded = false;
  String _selectedPeriod = 'today'; // today, week, month

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final stats = provider.getStats();
    final habits = provider.habits;
    final notes = provider.notes;
    final ideas = provider.ideas;
    final tasks = provider.tasks;

    return GestureDetector(
      onTap: widget.isCompact ? openFullScreen : null,
      child: Container(
        padding: EdgeInsets.all(widget.isCompact ? 16 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isDark
                ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(stats),
            const SizedBox(height: 14),
            _buildStatsCards(stats),
            const SizedBox(height: 14),
            _buildMainProgress(stats),
            const SizedBox(height: 14),
            if (_isExpanded || !widget.isCompact) ...[
              _buildDetailedStats(stats, habits, notes, ideas, tasks),
              const SizedBox(height: 12),
            ],
            _buildExpandButton(),
            if (widget.isCompact) ...[
              const SizedBox(height: 8),
              _buildCompactHint(),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ЗАГОЛОВОК
  // ============================================================

  Widget _buildHeader(Map<String, dynamic> stats) {
    final productivityLevel = _getProductivityLevel(stats);
    final productivityEmoji = _getProductivityEmoji(productivityLevel);
    final productivityColor = _getProductivityColor(productivityLevel);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BCD4).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.analytics_rounded,
            color: Colors.white,
            size: widget.isCompact ? 20 : 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Статистика',
                style: TextStyle(
                  fontSize: widget.isCompact ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                _getTodaySummary(stats),
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [productivityColor.withOpacity(0.15), productivityColor.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: productivityColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(productivityEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text(
                productivityLevel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: productivityColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // КАРТОЧКИ СТАТИСТИКИ
  // ============================================================

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    final cards = [
      {
        'icon': '📋',
        'value': '${stats['totalTasks'] ?? 0}',
        'label': 'Задач',
        'sub': '${stats['completedTasks'] ?? 0} выполнено',
        'color': const Color(0xFF4A9EFF),
        'progress': stats['totalTasks'] > 0
            ? (stats['completedTasks'] ?? 0) / (stats['totalTasks'] ?? 1)
            : 0.0,
      },
      {
        'icon': '💪',
        'value': '${stats['totalHabits'] ?? 0}',
        'label': 'Привычек',
        'sub': '${stats['completedHabitsToday'] ?? 0} сегодня',
        'color': const Color(0xFF00C853),
        'progress': stats['totalHabits'] > 0
            ? (stats['completedHabitsToday'] ?? 0) / (stats['totalHabits'] ?? 1)
            : 0.0,
      },
      {
        'icon': '💡',
        'value': '${stats['totalIdeas'] ?? 0}',
        'label': 'Идей',
        'sub': '${stats['implementedIdeas'] ?? 0} реализовано',
        'color': const Color(0xFF7C4DFF),
        'progress': stats['totalIdeas'] > 0
            ? (stats['implementedIdeas'] ?? 0) / (stats['totalIdeas'] ?? 1)
            : 0.0,
      },
      {
        'icon': '📝',
        'value': '${stats['totalNotes'] ?? 0}',
        'label': 'Заметок',
        'sub': 'Активных',
        'color': const Color(0xFFFF6B35),
        'progress': 0.0,
      },
    ];

    return Row(
      children: cards.map((card) {
        final color = card['color'] as Color;
        final progress = card['progress'] as double;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(widget.isDark ? 0.08 : 0.04),
                  color.withOpacity(widget.isDark ? 0.03 : 0.01),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withOpacity(widget.isDark ? 0.12 : 0.06),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  card['icon'] as String,
                  style: TextStyle(fontSize: widget.isCompact ? 20 : 24),
                ),
                const SizedBox(height: 4),
                Text(
                  card['value'] as String,
                  style: TextStyle(
                    fontSize: widget.isCompact ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  card['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  card['sub'] as String,
                  style: TextStyle(
                    fontSize: 8,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // ОСНОВНОЙ ПРОГРЕСС
  // ============================================================

  Widget _buildMainProgress(Map<String, dynamic> stats) {
    final completionRate = (stats['completionRate'] ?? 0).toDouble();
    final totalTasks = stats['totalTasks'] ?? 0;
    final completedTasks = stats['completedTasks'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00BCD4).withOpacity(widget.isDark ? 0.06 : 0.03),
            const Color(0xFF26C6DA).withOpacity(widget.isDark ? 0.03 : 0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00BCD4).withOpacity(widget.isDark ? 0.1 : 0.04),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📈 Общий прогресс',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00BCD4).withOpacity(0.15),
                      const Color(0xFF00BCD4).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${completionRate.round()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF00BCD4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: completionRate / 100),
              duration: const Duration(milliseconds: 800),
              builder: (_, double value, __) => LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completionRate >= 80 ? Colors.green :
                  completionRate >= 60 ? Colors.teal :
                  completionRate >= 40 ? Colors.orange : Colors.red,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedTasks / $totalTasks задач выполнено',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: completionRate >= 80
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  completionRate >= 80 ? 'Отлично! 🎉' : 'Продолжай! 💪',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: completionRate >= 80 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ДЕТАЛЬНАЯ СТАТИСТИКА
  // ============================================================

  Widget _buildDetailedStats(
      Map<String, dynamic> stats,
      List<LifeHabit> habits,
      List<LifeNote> notes,
      List<LifeIdea> ideas,
      List<LifeTask> tasks,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Достижения
        _buildAchievements(stats, habits),
        const SizedBox(height: 12),

        // Рекорды
        if (habits.isNotEmpty) ...[
          _buildRecords(habits),
          const SizedBox(height: 12),
        ],

        // Статистика по категориям
        _buildCategoryStats(notes, ideas, tasks),
        const SizedBox(height: 12),

        // Активность по дням
        _buildActivityChart(),
        const SizedBox(height: 12),

        // Привычки топ
        if (habits.isNotEmpty) ...[
          _buildTopHabits(habits),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ============================================================
  // ДОСТИЖЕНИЯ
  // ============================================================

  Widget _buildAchievements(Map<String, dynamic> stats, List<LifeHabit> habits) {
    final achievements = <Map<String, dynamic>>[];

    if ((stats['completedTasks'] ?? 0) >= 10) {
      achievements.add({'icon': '✅', 'title': '10+ задач', 'desc': 'Выполнено задач', 'color': Colors.green});
    }
    if ((stats['completedTasks'] ?? 0) >= 50) {
      achievements.add({'icon': '🏆', 'title': '50+ задач', 'desc': 'Выполнено задач', 'color': Colors.amber});
    }
    if ((stats['totalHabits'] ?? 0) >= 3) {
      achievements.add({'icon': '💪', 'title': '3+ привычки', 'desc': 'Активных привычек', 'color': Colors.orange});
    }
    if ((stats['totalHabits'] ?? 0) >= 7) {
      achievements.add({'icon': '🔥', 'title': '7+ привычек', 'desc': 'Активных привычек', 'color': Colors.red});
    }
    if ((stats['implementedIdeas'] ?? 0) >= 1) {
      achievements.add({'icon': '💡', 'title': 'Идея реализована', 'desc': 'Воплощено в жизнь', 'color': Colors.purple});
    }

    final maxStreak = habits.fold<int>(0, (max, h) => h.currentStreak > max ? h.currentStreak : max);
    if (maxStreak >= 7) {
      achievements.add({'icon': '🔥', 'title': '$maxStreak дней', 'desc': 'Максимальный стрик', 'color': Colors.red});
    }
    if (maxStreak >= 30) {
      achievements.add({'icon': '👑', 'title': '30+ дней', 'desc': 'Месячный стрик', 'color': Colors.amber});
    }

    if (achievements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text('🎯', style: TextStyle(fontSize: widget.isCompact ? 20 : 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Достижения появятся здесь\nПродолжайте развиваться!',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🏅 Достижения',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: achievements.map((a) {
            return FadeInUp(
              duration: Duration(milliseconds: 300 + achievements.indexOf(a) * 100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (a['color'] as Color).withOpacity(0.12),
                      (a['color'] as Color).withOpacity(0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (a['color'] as Color).withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(a['icon'] as String, style: TextStyle(fontSize: widget.isCompact ? 14 : 18)),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['title'] as String,
                          style: TextStyle(
                            fontSize: widget.isCompact ? 11 : 13,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          a['desc'] as String,
                          style: TextStyle(
                            fontSize: widget.isCompact ? 9 : 10,
                            color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // РЕКОРДЫ
  // ============================================================

  Widget _buildRecords(List<LifeHabit> habits) {
    final topHabits = List<LifeHabit>.from(habits)
      ..sort((a, b) => b.longestStreak.compareTo(a.longestStreak));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 Рекорды привычек',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.withOpacity(widget.isDark ? 0.06 : 0.02),
                Colors.orange.withOpacity(widget.isDark ? 0.03 : 0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withOpacity(widget.isDark ? 0.1 : 0.04),
              width: 1,
            ),
          ),
          child: Column(
            children: topHabits.take(widget.isCompact ? 3 : 5).map((h) {
              final progress = (h.currentStreak / 30).clamp(0.0, 1.0);
              final habitColor = Color(int.parse('0xFF${h.color.replaceFirst('#', '')}'));

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [habitColor.withOpacity(0.3), habitColor],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(h.icon, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2,
                              backgroundColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(habitColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.withOpacity(0.15), Colors.orange.withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.orange),
                          const SizedBox(width: 2),
                          Text(
                            '${h.longestStreak} дн.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // СТАТИСТИКА ПО КАТЕГОРИЯМ
  // ============================================================

  Widget _buildCategoryStats(List<LifeNote> notes, List<LifeIdea> ideas, List<LifeTask> tasks) {
    final categories = {
      'Работа': {'notes': 0, 'ideas': 0, 'tasks': 0, 'color': const Color(0xFF4A9EFF)},
      'Личное': {'notes': 0, 'ideas': 0, 'tasks': 0, 'color': const Color(0xFFFF6B35)},
      'Идеи': {'notes': 0, 'ideas': 0, 'tasks': 0, 'color': const Color(0xFF7C4DFF)},
      'Финансы': {'notes': 0, 'ideas': 0, 'tasks': 0, 'color': const Color(0xFF00C853)},
      'Здоровье': {'notes': 0, 'ideas': 0, 'tasks': 0, 'color': const Color(0xFFFF1744)},
    };

    // Подсчёт по тегам
    for (final note in notes) {
      for (final tag in note.tags) {
        final key = categories.keys.firstWhere(
              (k) => tag.toLowerCase().contains(k.toLowerCase()) || k.toLowerCase().contains(tag.toLowerCase()),
          orElse: () => 'Личное',
        );
        categories[key]!['notes'] = (categories[key]!['notes'] as int) + 1;
      }
    }

    for (final idea in ideas) {
      for (final tag in idea.tags) {
        final key = categories.keys.firstWhere(
              (k) => tag.toLowerCase().contains(k.toLowerCase()) || k.toLowerCase().contains(tag.toLowerCase()),
          orElse: () => 'Идеи',
        );
        categories[key]!['ideas'] = (categories[key]!['ideas'] as int) + 1;
      }
    }

    for (final task in tasks) {
      for (final tag in task.tags) {
        final key = categories.keys.firstWhere(
              (k) => tag.toLowerCase().contains(k.toLowerCase()) || k.toLowerCase().contains(tag.toLowerCase()),
          orElse: () => 'Личное',
        );
        categories[key]!['tasks'] = (categories[key]!['tasks'] as int) + 1;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📂 По категориям',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            children: categories.entries.map((entry) {
              final key = entry.key;
              final data = entry.value;
              final color = data['color'] as Color;
              final total = (data['notes'] as int) + (data['ideas'] as int) + (data['tasks'] as int);
              final maxTotal = categories.values.fold<int>(
                0,
                    (sum, d) => sum + (d['notes'] as int) + (d['ideas'] as int) + (d['tasks'] as int),
              );
              final progress = maxTotal > 0 ? total / maxTotal : 0.0;

              if (total == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // АКТИВНОСТЬ ПО ДНЯМ
  // ============================================================

  Widget _buildActivityChart() {
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final values = [5, 7, 4, 8, 6, 3, 2];
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📅 Активность за неделю',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00BCD4).withOpacity(widget.isDark ? 0.04 : 0.02),
                const Color(0xFF26C6DA).withOpacity(widget.isDark ? 0.02 : 0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00BCD4).withOpacity(widget.isDark ? 0.08 : 0.04),
              width: 1,
            ),
          ),
          child: Row(
            children: days.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              final value = values[i];
              final height = (value / maxValue * (widget.isCompact ? 36 : 50)).clamp(4.0, widget.isCompact ? 36.0 : 50.0);

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: widget.isCompact ? 9 : 11,
                        fontWeight: FontWeight.w700,
                        color: value >= 7 ? Colors.green : (value >= 4 ? Colors.teal : (value >= 2 ? Colors.orange : Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: height,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (value >= 7 ? Colors.green : value >= 4 ? Colors.teal : value >= 2 ? Colors.orange : Colors.grey).withOpacity(0.5),
                            (value >= 7 ? Colors.green : value >= 4 ? Colors.teal : value >= 2 ? Colors.orange : Colors.grey),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: widget.isCompact ? 9 : 11,
                        color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ТОП ПРИВЫЧЕК
  // ============================================================

  Widget _buildTopHabits(List<LifeHabit> habits) {
    final topHabits = List<LifeHabit>.from(habits)
      ..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🔥 Топ привычек',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.withOpacity(widget.isDark ? 0.04 : 0.02),
                Colors.green.withOpacity(widget.isDark ? 0.02 : 0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withOpacity(widget.isDark ? 0.08 : 0.04),
              width: 1,
            ),
          ),
          child: Column(
            children: topHabits.take(3).map((h) {
              final habitColor = Color(int.parse('0xFF${h.color.replaceFirst('#', '')}'));
              final isCompleted = h.isCompletedToday();

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [habitColor.withOpacity(0.3), habitColor],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(h.icon, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${h.currentStreak} дней • ${h.frequency}',
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted ? '✅' : '⏳',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // КНОПКА РАЗВОРАЧИВАНИЯ
  // ============================================================

  Widget _buildExpandButton() {
    if (!widget.isCompact) return const SizedBox.shrink();

    if (!_isExpanded) {
      return FadeInUp(
        child: GestureDetector(
          onTap: () {
            setState(() => _isExpanded = true);
            HapticFeedback.selectionClick();
          },
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00BCD4).withOpacity(widget.isDark ? 0.08 : 0.04),
                  const Color(0xFF26C6DA).withOpacity(widget.isDark ? 0.08 : 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00BCD4).withOpacity(widget.isDark ? 0.1 : 0.04),
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.expand_more_rounded, size: 18, color: const Color(0xFF00BCD4)),
                  const SizedBox(width: 6),
                  Text(
                    'Подробная статистика',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00BCD4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() => _isExpanded = false);
        HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_less_rounded, size: 18, color: widget.isDark ? Colors.white54 : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Свернуть',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ПОДСКАЗКА
  // ============================================================

  Widget _buildCompactHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF00BCD4).withOpacity(0.1), const Color(0xFF26C6DA).withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_full_rounded, size: 14, color: const Color(0xFF00BCD4).withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(
              'Нажмите для полного просмотра',
              style: TextStyle(
                fontSize: 10,
                color: const Color(0xFF00BCD4).withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ============================================================

  String _getProductivityLevel(Map<String, dynamic> stats) {
    final rate = stats['completionRate'] ?? 0;
    if (rate >= 90) return 'S';
    if (rate >= 75) return 'A';
    if (rate >= 60) return 'B';
    if (rate >= 40) return 'C';
    if (rate >= 20) return 'D';
    return 'F';
  }

  Color _getProductivityColor(String level) {
    switch (level) {
      case 'S': return Colors.amber;
      case 'A': return Colors.green;
      case 'B': return Colors.teal;
      case 'C': return Colors.orange;
      case 'D': return Colors.deepOrange;
      default: return Colors.red;
    }
  }

  String _getProductivityEmoji(String level) {
    switch (level) {
      case 'S': return '👑';
      case 'A': return '🌟';
      case 'B': return '👍';
      case 'C': return '📈';
      case 'D': return '💪';
      default: return '🎯';
    }
  }

  String _getTodaySummary(Map<String, dynamic> stats) {
    final completedHabits = stats['completedHabitsToday'] ?? 0;
    final totalHabits = stats['totalHabits'] ?? 0;
    final completedTasks = stats['completedTasks'] ?? 0;
    final totalTasks = stats['totalTasks'] ?? 0;
    final completedIdeas = stats['implementedIdeas'] ?? 0;

    return 'Сегодня: $completedTasks/$totalTasks задач, $completedHabits/$totalHabits привычек';
  }
}