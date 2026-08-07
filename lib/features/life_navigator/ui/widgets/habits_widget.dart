// features/life_navigator/ui/widgets/habits_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:math';
import '../../../../services/notification_service.dart';
import 'base_life_widget.dart';
import '../../providers/life_provider.dart';
import '../../models/life_models.dart';

class HabitsWidget extends BaseLifeWidget {
  const HabitsWidget({
    super.key,
    required super.isDark,
    super.isCompact = true,
  });

  @override
  State<HabitsWidget> createState() => _HabitsWidgetState();
}

class _HabitsWidgetState extends State<HabitsWidget> with LifeWidgetMixin<HabitsWidget> {
  String? _animatingHabitId;
  bool _showConfetti = false;
  bool _isExpanded = false;
  String _filterType = 'all';
  String _searchQuery = '';

  // ========== ДОСТИЖЕНИЯ ==========
  List<Map<String, dynamic>> getAchievements(LifeHabit habit) {
    final achievements = <Map<String, dynamic>>[];
    final streak = habit.currentStreak;

    if (streak >= 3) {
      achievements.add({
        'icon': '🌟',
        'title': 'Первые шаги',
        'description': 'Стрик 3 дня',
        'unlocked': true,
        'color': Colors.blue,
      });
    }
    if (streak >= 7) {
      achievements.add({
        'icon': '🔥',
        'title': 'Недельный герой',
        'description': 'Стрик 7 дней',
        'unlocked': true,
        'color': Colors.orange,
      });
    }
    if (streak >= 14) {
      achievements.add({
        'icon': '⚡',
        'title': 'Дисциплина',
        'description': 'Стрик 14 дней',
        'unlocked': true,
        'color': Colors.purple,
      });
    }
    if (streak >= 30) {
      achievements.add({
        'icon': '🏆',
        'title': 'Месячный марафон',
        'description': 'Стрик 30 дней',
        'unlocked': true,
        'color': Colors.amber,
      });
    }
    if (streak >= 60) {
      achievements.add({
        'icon': '💎',
        'title': 'Железная воля',
        'description': 'Стрик 60 дней',
        'unlocked': true,
        'color': Colors.teal,
      });
    }
    if (streak >= 100) {
      achievements.add({
        'icon': '👑',
        'title': 'Легенда',
        'description': 'Стрик 100 дней',
        'unlocked': true,
        'color': Colors.red,
      });
    }

    return achievements;
  }

  // ========== ПРОГНОЗ СТРИКА ==========
  String getStreakPrediction(LifeHabit habit) {
    final streak = habit.currentStreak;
    if (streak == 0) return 'Начните сегодня! 🚀';
    if (streak < 3) return 'До первого достижения осталось ${3 - streak} дн.';
    if (streak < 7) return 'До недельного стрика осталось ${7 - streak} дн.';
    if (streak < 14) return 'До 2 недель осталось ${14 - streak} дн.';
    if (streak < 30) return 'До месяца осталось ${30 - streak} дн.';
    if (streak < 60) return 'До 2 месяцев осталось ${60 - streak} дн.';
    if (streak < 100) return 'До 100 дней осталось ${100 - streak} дн.';
    return 'Вы легенда! Продолжайте в том же духе! 👑';
  }

  // ========== ДАННЫЕ ДЛЯ ГРАФИКА ==========
  List<Map<String, dynamic>> getMonthlyData(LifeHabit habit) {
    final data = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    for (int i = 0; i < 30; i++) {
      final date = monthStart.add(Duration(days: i));
      if (date.month != now.month) break;
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final isDone = habit.wasCompletedOn(date);
      data.add({
        'day': date.day,
        'date': dateStr,
        'done': isDone,
        'isToday': date.day == now.day,
      });
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final habits = provider.habits;
    final reminders = provider.reminders;

    // Фильтрация
    List<LifeHabit> filteredHabits = habits;
    if (_filterType == 'active') {
      filteredHabits = habits.where((h) => !h.isCompletedToday()).toList();
    } else if (_filterType == 'completed') {
      filteredHabits = habits.where((h) => h.isCompletedToday()).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredHabits = filteredHabits.where((h) =>
      h.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          h.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          h.icon.contains(_searchQuery)).toList();
    }

    final totalHabits = habits.length;
    final completedToday = habits.where((h) => h.isCompletedToday()).length;
    final totalStreak = habits.fold<int>(0, (sum, h) => sum + h.currentStreak);
    final completionRate = totalHabits > 0 ? (completedToday / totalHabits * 100).round() : 0;

    final maxDisplayHabits = widget.isCompact ? 5 : habits.length;
    final displayedHabits = _isExpanded ? filteredHabits : filteredHabits.take(maxDisplayHabits).toList();

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
            _buildHeader(
              totalHabits: totalHabits,
              completedToday: completedToday,
              completionRate: completionRate,
              provider: provider,
            ),
            const SizedBox(height: 12),
            _buildStats(
              totalHabits: totalHabits,
              completedToday: completedToday,
              totalStreak: totalStreak,
              completionRate: completionRate,
              reminders: reminders,
              habits: habits,
            ),
            const SizedBox(height: 16),
            _buildSearchAndFilters(),
            const SizedBox(height: 12),
            if (filteredHabits.isEmpty)
              _buildEmptyState()
            else
              ...displayedHabits.map((habit) {
                final habitColor = Color(int.parse('0xFF${habit.color.replaceFirst('#', '')}'));
                final isAnimating = _animatingHabitId == habit.id;
                final isCompleted = habit.isCompletedToday();
                final canComplete = habit.canCompleteToday();
                final hasReminder = provider.hasActiveReminder(habit.id);

                return _buildHabitCard(
                  habit: habit,
                  habitColor: habitColor,
                  isAnimating: isAnimating,
                  isCompleted: isCompleted,
                  canComplete: canComplete,
                  hasReminder: hasReminder,
                  provider: provider,
                );
              }),
            if (filteredHabits.length > maxDisplayHabits && !_isExpanded)
              _buildExpandButton(filteredHabits.length - maxDisplayHabits),
            if (_isExpanded && filteredHabits.length > maxDisplayHabits)
              _buildCollapseButton(),
            const SizedBox(height: 12),
            _buildActionButtons(provider),
            if (widget.isCompact) ...[
              const SizedBox(height: 8),
              _buildCompactHint(),
            ],
          ],
        ),
      ),
    );
  }

  // ========== ЗАГОЛОВОК ==========
  Widget _buildHeader({
    required int totalHabits,
    required int completedToday,
    required int completionRate,
    required LifeProvider provider,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C853), Color(0xFF00E676)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.fitness_center_rounded,
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
                'Привычки',
                style: TextStyle(
                  fontSize: widget.isCompact ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  Text(
                    '$totalHabits привычек',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.2),
                          Colors.green.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$completionRate%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: totalHabits > 0 ? completedToday / totalHabits : 0,
                strokeWidth: 3,
                backgroundColor: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C853)),
              ),
              Text(
                '$completionRate%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== СТАТИСТИКА ==========
  Widget _buildStats({
    required int totalHabits,
    required int completedToday,
    required int totalStreak,
    required int completionRate,
    required List<HabitReminder> reminders,
    required List<LifeHabit> habits,
  }) {
    final bestHabit = habits.isNotEmpty
        ? habits.reduce((a, b) => a.currentStreak > b.currentStreak ? a : b)
        : null;

    final stats = [
      {'label': 'Выполнено', 'value': '$completedToday/$totalHabits', 'icon': '✅', 'color': Colors.green},
      {'label': 'Стрик', 'value': '$totalStreak', 'icon': '🔥', 'color': Colors.orange},
      {'label': 'Напоминаний', 'value': '${reminders.where((r) => r.isActive).length}', 'icon': '🔔', 'color': Colors.purple},
      if (bestHabit != null) {'label': 'Рекорд', 'value': '${bestHabit.icon} ${bestHabit.currentStreak}д', 'icon': '🏆', 'color': Colors.amber},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: stats.map((stat) => Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (stat['color'] as Color).withOpacity(widget.isDark ? 0.12 : 0.06),
                (stat['color'] as Color).withOpacity(widget.isDark ? 0.04 : 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (stat['color'] as Color).withOpacity(widget.isDark ? 0.15 : 0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Text(stat['icon'] as String, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                stat['value'] as String,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: stat['color'] as Color,
                ),
              ),
              Text(
                ' ${stat['label']}',
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // ========== ПОИСК И ФИЛЬТРЫ ==========
  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: TextStyle(
              fontSize: 14,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Поиск привычек...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: widget.isDark ? Colors.white38 : Colors.grey.shade400),
                onPressed: () => setState(() => _searchQuery = ''),
              )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildFilterChip('Все', 'all', Colors.grey),
            const SizedBox(width: 6),
            _buildFilterChip('Активные', 'active', Colors.blue),
            const SizedBox(width: 6),
            _buildFilterChip('Готово', 'completed', Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterType = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.05),
            ],
          )
              : null,
          color: isSelected ? null : (widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : (widget.isDark ? Colors.white70 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  // ========== КАРТОЧКА ПРИВЫЧКИ ==========
  Widget _buildHabitCard({
    required LifeHabit habit,
    required Color habitColor,
    required bool isAnimating,
    required bool isCompleted,
    required bool canComplete,
    required bool hasReminder,
    required LifeProvider provider,
  }) {
    final achievements = getAchievements(habit);
    final unlockedAchievements = achievements.where((a) => a['unlocked'] == true).toList();

    return GestureDetector(
      onTap: () => _showHabitDetails(context, habit, provider),
      onLongPress: () => _showHabitContextMenu(context, habit, provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCompleted
                ? [Colors.green.withOpacity(0.08), Colors.green.withOpacity(0.02)]
                : [habitColor.withOpacity(0.08), habitColor.withOpacity(0.02)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCompleted
                ? Colors.green.withOpacity(0.15)
                : habitColor.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isCompleted ? Colors.green : habitColor).withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [Colors.green, Colors.green.shade700]
                      : [habitColor, habitColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (isCompleted ? Colors.green : habitColor).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: isAnimating
                    ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
                    : Center(
                  child: Text(
                    habit.icon,
                    style: const TextStyle(fontSize: 24),
                    key: ValueKey(habit.icon),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          habit.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: widget.isCompact ? 14 : 16,
                            color: widget.isDark ? Colors.white : Colors.black87,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            decorationColor: Colors.green.withOpacity(0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasReminder)
                        Tooltip(
                          message: _getReminderTooltip(habit, provider),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              size: 16,
                              color: Colors.purple.withOpacity(0.7),
                            ),
                          ),
                        ),
                      if (unlockedAchievements.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '🏆 ${unlockedAchievements.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: TweenAnimationBuilder(
                              tween: Tween<double>(
                                begin: 0,
                                end: (habit.currentStreak / 30).clamp(0.0, 1.0),
                              ),
                              duration: const Duration(milliseconds: 600),
                              builder: (_, double value, __) => Container(
                                width: value * double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isCompleted
                                        ? [Colors.green.shade300, Colors.green]
                                        : [habitColor.withOpacity(0.5), habitColor],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${habit.currentStreak}д',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                      if (habit.targetCount > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCompleted ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${habit.completionsToday}/${habit.targetCount}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isCompleted ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildWeekProgressDots(habit, isCompleted),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildActionButton(habit, isCompleted, canComplete, isAnimating, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(LifeHabit habit, bool isCompleted, bool canComplete, bool isAnimating, LifeProvider provider) {
    final habitColor = Color(int.parse('0xFF${habit.color.replaceFirst('#', '')}')); // Добавляем цвет здесь

    return GestureDetector(
      onTap: () async {
        if (isCompleted) {
          HapticFeedback.mediumImpact();
          await provider.uncompleteHabit(habit.id);
        } else if (canComplete) {
          setState(() => _animatingHabitId = habit.id);
          HapticFeedback.lightImpact();

          final success = await provider.completeHabit(habit.id);

          if (success) {
            final updatedHabit = provider.habits.firstWhere((h) => h.id == habit.id);
            if (updatedHabit.isCompletedToday()) {
              setState(() => _showConfetti = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _showConfetti = false);
              });
            }
          }

          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) setState(() => _animatingHabitId = null);
        } else {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                habit.frequency == 'weekly'
                    ? '⏳ Привычка доступна только в определённые дни'
                    : '✅ Цель на сегодня достигнута!',
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isCompleted
              ? LinearGradient(
            colors: [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)],
          )
              : canComplete
              ? LinearGradient(
            colors: isAnimating
                ? [Colors.green, Colors.green.shade700]
                : [habitColor, habitColor.withOpacity(0.8)],
          )
              : null,
          color: isCompleted
              ? null
              : canComplete
              ? null
              : widget.isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCompleted
                ? Colors.green.withOpacity(0.2)
                : canComplete
                ? Colors.transparent
                : widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: isAnimating
              ? [
            BoxShadow(
              color: Colors.green.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ]
              : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isCompleted
              ? Row(
            mainAxisSize: MainAxisSize.min,
            key: const ValueKey('completed'),
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: widget.isCompact ? 16 : 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Готово',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: widget.isCompact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          )
              : canComplete
              ? Row(
            mainAxisSize: MainAxisSize.min,
            key: ValueKey('do_${isAnimating}'),
            children: [
              Icon(
                isAnimating ? Icons.check_circle_rounded : Icons.check_rounded,
                color: Colors.white,
                size: widget.isCompact ? 16 : 20,
              ),
              const SizedBox(width: 6),
              Text(
                isAnimating ? 'Готово!' : 'Сделать',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.isCompact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          )
              : Icon(
            Icons.lock_rounded,
            key: const ValueKey('locked'),
            color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
            size: widget.isCompact ? 16 : 20,
          ),
        ),
      ),
    );
  }

  // ========== НЕДЕЛЬНЫЙ ПРОГРЕСС ==========
  Widget _buildWeekProgressDots(LifeHabit habit, bool isCompletedToday) {
    final weekProgress = habit.getWeekProgress();
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Row(
      children: [
        Text(
          'Неделя: ',
          style: TextStyle(
            fontSize: widget.isCompact ? 9 : 11,
            color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
        ...weekProgress.asMap().entries.map((entry) {
          final i = entry.key;
          final isDone = entry.value;
          final isToday = i == 6;

          return Container(
            margin: const EdgeInsets.only(right: 4),
            child: Column(
              children: [
                Container(
                  width: widget.isCompact ? 14 : 18,
                  height: widget.isCompact ? 14 : 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? (isToday ? Colors.green : Colors.green.withOpacity(0.6))
                        : (isToday && !isCompletedToday
                        ? Colors.orange.withOpacity(0.3)
                        : widget.isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.shade200),
                    border: isToday && !isDone
                        ? Border.all(color: Colors.orange.withOpacity(0.5), width: 2)
                        : null,
                  ),
                  child: isDone
                      ? Icon(
                    Icons.check_rounded,
                    size: widget.isCompact ? 8 : 10,
                    color: Colors.white,
                  )
                      : null,
                ),
                const SizedBox(height: 2),
                Text(
                  dayNames[i],
                  style: TextStyle(
                    fontSize: widget.isCompact ? 6 : 8,
                    color: widget.isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // ========== ПУСТОЕ СОСТОЯНИЕ ==========
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 24 : 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Text('🌟', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'Ничего не найдено' : 'Нет привычек',
              style: TextStyle(
                fontSize: widget.isCompact ? 16 : 20,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            if (!_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Нажмите "Добавить" чтобы начать',
                style: TextStyle(
                  fontSize: widget.isCompact ? 12 : 14,
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========== КНОПКИ РАЗВОРАЧИВАНИЯ ==========
  Widget _buildExpandButton(int remaining) {
    return GestureDetector(
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
              Colors.green.withOpacity(widget.isDark ? 0.08 : 0.04),
              Colors.blue.withOpacity(widget.isDark ? 0.08 : 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withOpacity(widget.isDark ? 0.1 : 0.04),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_more_rounded, size: 18, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                'Показать ещё $remaining привычек',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton() {
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

  // ========== КНОПКИ ДЕЙСТВИЙ ==========
  Widget _buildActionButtons(LifeProvider provider) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showAddHabitDialog(context, widget.isDark, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green, Colors.green.shade700],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: widget.isCompact ? 18 : 20),
                  const SizedBox(width: 6),
                  Text(
                    'Добавить',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: widget.isCompact ? 14 : 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _showAllHabitsDialog(context, widget.isDark, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  'Все привычки',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white70 : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: widget.isCompact ? 14 : 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== ПОДСКАЗКА ДЛЯ КОМПАКТНОГО РЕЖИМА ==========
  Widget _buildCompactHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, size: 14, color: Colors.green.withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(
              'Нажмите для полного просмотра',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== ВСПОМОГАТЕЛЬНЫЙ МЕТОД ==========
  String _getReminderTooltip(LifeHabit habit, LifeProvider provider) {
    final reminders = provider.getRemindersForHabit(habit.id);
    if (reminders.isEmpty) return 'Нет напоминаний';

    final activeReminder = reminders.firstWhere((r) => r.isActive, orElse: () => reminders.first);
    final timeStr = activeReminder.formattedTime;
    final daysStr = activeReminder.daysDescription;

    return '🔔 Напоминание: $timeStr ($daysStr)';
  }

  // ================================================================
  // ДЕТАЛЬНЫЙ ПРОСМОТР
  // ================================================================

  void _showHabitDetails(BuildContext context, LifeHabit habit, LifeProvider provider) {
    final achievements = getAchievements(habit);
    final monthlyData = getMonthlyData(habit);
    final prediction = getStreakPrediction(habit);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isDark
                ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Заголовок
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(int.parse('0xFF${habit.color.replaceFirst('#', '')}')),
                          Color(int.parse('0xFF${habit.color.replaceFirst('#', '')}')).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(habit.icon, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                          ),
                        ),
                        Text(
                          'Стрик: ${habit.currentStreak} дн. • ${habit.frequency}',
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (habit.isCompletedToday())
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Готово',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Прогноз
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withOpacity(0.1),
                      Colors.amber.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🔮', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        prediction,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? Colors.white70 : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Статистика
              Row(
                children: [
                  _buildStatItem('🔥 Стрик', '${habit.currentStreak} дн.', Colors.orange),
                  _buildStatItem('🎯 Сегодня', '${habit.completionsToday}/${habit.targetCount}', Colors.green),
                  _buildStatItem('📅 Выполнено', '${habit.completedDates.length}', Colors.blue),
                ],
              ),

              const SizedBox(height: 16),

              // Достижения
              if (achievements.isNotEmpty) ...[
                Text(
                  '🏆 Достижения',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: achievements.map((ach) {
                    final isUnlocked = ach['unlocked'] == true;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? (ach['color'] as Color).withOpacity(0.15)
                            : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isUnlocked
                              ? (ach['color'] as Color).withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ach['icon'] as String, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            ach['title'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isUnlocked
                                  ? ach['color'] as Color
                                  : (widget.isDark ? Colors.white38 : Colors.grey.shade400),
                            ),
                          ),
                          if (!isUnlocked) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.lock_rounded,
                              size: 12,
                              color: widget.isDark ? Colors.white24 : Colors.grey.shade400,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // График
              Text(
                '📊 Прогресс за месяц',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: monthlyData.map((day) {
                    final isDone = day['done'] == true;
                    final isToday = day['isToday'] == true;
                    return Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? Colors.green
                            : (isToday
                            ? Colors.orange.withOpacity(0.3)
                            : widget.isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200),
                        border: isToday && !isDone
                            ? Border.all(color: Colors.orange, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day['day']}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isDone ? FontWeight.w700 : FontWeight.w400,
                            color: isDone
                                ? Colors.white
                                : (widget.isDark ? Colors.white38 : Colors.grey.shade500),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Кнопки действий
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showReminderDialog(context, habit, provider);
                      },
                      icon: Icon(
                        provider.hasActiveReminder(habit.id)
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        color: Colors.purple,
                        size: 18,
                      ),
                      label: Text(
                        provider.hasActiveReminder(habit.id) ? 'Напоминание' : 'Добавить напом.',
                        style: TextStyle(
                          color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditHabitDialog(context, habit, provider);
                      },
                      icon: Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                      label: Text(
                        'Редактировать',
                        style: TextStyle(
                          color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeleteHabit(context, habit, provider);
                  },
                  icon: Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                  label: Text(
                    'Удалить привычку',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    'Закрыть',
                    style: TextStyle(
                      color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                      fontSize: 15,
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // КОНТЕКСТНОЕ МЕНЮ
  // ================================================================

  void _showHabitContextMenu(BuildContext context, LifeHabit habit, LifeProvider provider) {
    HapticFeedback.mediumImpact();
    final hasReminder = provider.hasActiveReminder(habit.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Text(habit.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Стрик: ${habit.currentStreak} дн. • ${habit.frequency}',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildContextMenuItem(
              icon: Icons.info_rounded,
              label: 'Подробности',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(ctx);
                _showHabitDetails(context, habit, provider);
              },
            ),

            _buildContextMenuItem(
              icon: Icons.edit_rounded,
              label: 'Редактировать',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(ctx);
                _showEditHabitDialog(context, habit, provider);
              },
            ),

            _buildContextMenuItem(
              icon: Icons.skip_next_rounded,
              label: 'Пропустить сегодня (сбросить стрик)',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(ctx);
                provider.skipHabit(habit.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('⏭️ Стрик "${habit.title}" сброшен'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),

            _buildContextMenuItem(
              icon: hasReminder ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              label: hasReminder ? 'Изменить напоминание' : 'Добавить напоминание',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(ctx);
                _showReminderDialog(context, habit, provider);
              },
            ),

            _buildContextMenuItem(
              icon: Icons.delete_rounded,
              label: 'Удалить привычку',
              color: Colors.red,
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteHabit(context, habit, provider);
              },
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withOpacity(0.2)
                : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red : (widget.isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // УДАЛЕНИЕ
  // ================================================================

  void _confirmDeleteHabit(BuildContext context, LifeHabit habit, LifeProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text('Удалить привычку?'),
          ],
        ),
        content: Text(
          'Вы уверены, что хотите удалить "${habit.title}"?\n\n'
              '📊 Текущий стрик: ${habit.currentStreak} дн.\n'
              '📅 Выполнено: ${habit.completedDates.length} раз\n'
              '🔔 Все напоминания также будут удалены.',
          style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteHabit(habit.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🗑️ Привычка "${habit.title}" удалена'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // РЕДАКТИРОВАНИЕ
  // ================================================================

  void _showEditHabitDialog(BuildContext context, LifeHabit habit, LifeProvider provider) {
    final titleController = TextEditingController(text: habit.title);
    final descriptionController = TextEditingController(text: habit.description);
    String selectedIcon = habit.icon;
    String selectedFrequency = habit.frequency;
    int selectedTarget = habit.targetCount;

    final icons = ['⭐', '💪', '📚', '🏃', '🧘', '🎯', '💧', '🥗', '😴', '🧠', '🎨', '🌱', '🎵', '✍️', '🧹', '💊', '🚶', '🏋️'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isDark
                ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blue.shade700],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Редактировать привычку',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                          ),
                        ),
                        Text(
                          'Измените данные привычки',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              TextField(
                controller: titleController,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Название привычки',
                  labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: descriptionController,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Описание (необязательно)',
                  labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedIcon,
                      dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white,
                      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Иконка',
                        labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
                        filled: true,
                        fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: icons.map((icon) => DropdownMenuItem(
                        value: icon,
                        child: Text('$icon  ', style: const TextStyle(fontSize: 24)),
                      )).toList(),
                      onChanged: (value) { if (value != null) selectedIcon = value; },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white,
                      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Частота',
                        labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
                        filled: true,
                        fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('📅 Ежедневно')),
                        DropdownMenuItem(value: 'weekly', child: Text('📆 Еженедельно')),
                      ],
                      onChanged: (value) { if (value != null) selectedFrequency = value; },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                value: selectedTarget,
                dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Цель в день',
                  labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('🎯 1 раз')),
                  DropdownMenuItem(value: 2, child: Text('🎯 2 раза')),
                  DropdownMenuItem(value: 3, child: Text('🎯 3 раза')),
                  DropdownMenuItem(value: 4, child: Text('🎯 4 раза')),
                  DropdownMenuItem(value: 5, child: Text('🎯 5 раз')),
                ],
                onChanged: (value) { if (value != null) selectedTarget = value; },
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.isNotEmpty) {
                          final updatedHabit = habit.copyWith(
                            title: titleController.text,
                            description: descriptionController.text,
                            icon: selectedIcon,
                            frequency: selectedFrequency,
                            targetCount: selectedTarget,
                          );
                          await provider.updateHabit(updatedHabit);

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Text('✅ '),
                                  Expanded(child: Text('Привычка обновлена!')),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Сохранить',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.isDark ? Colors.white70 : Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // ДИАЛОГ НАПОМИНАНИЯ
  // ================================================================

  void _showReminderDialog(BuildContext context, LifeHabit habit, LifeProvider provider) {
    final reminders = provider.getRemindersForHabit(habit.id);
    final activeReminder = reminders.isNotEmpty ? reminders.first : null;

    TimeOfDay selectedTime = activeReminder?.time ?? const TimeOfDay(hour: 8, minute: 0);
    bool isActive = activeReminder?.isActive ?? true;
    List<String> selectedDays = activeReminder?.daysOfWeek ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: Colors.purple, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activeReminder != null ? 'Напоминание' : 'Добавить напоминание',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Привычка: ${habit.icon} ${habit.title}',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),

                // Время
                Text(
                  'Время напоминания',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: Colors.purple, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Дни недели
                if (habit.frequency == 'weekly') ...[
                  Text(
                    'Дни недели',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((day) {
                      final dayMap = {'Пн': 'Monday', 'Вт': 'Tuesday', 'Ср': 'Wednesday', 'Чт': 'Thursday', 'Пт': 'Friday', 'Сб': 'Saturday', 'Вс': 'Sunday'};
                      final dayEn = dayMap[day]!;
                      final isSelected = selectedDays.contains(dayEn);

                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            if (isSelected) {
                              selectedDays.remove(dayEn);
                            } else {
                              selectedDays.add(dayEn);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.purple.withOpacity(0.15)
                                : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purple.withOpacity(0.3)
                                  : (widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.purple
                                  : (widget.isDark ? Colors.white54 : Colors.grey.shade600),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Активно
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Напоминание активно',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  value: isActive,
                  activeColor: Colors.purple,
                  onChanged: (value) {
                    setDialogState(() => isActive = value);
                  },
                ),

                if (activeReminder != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      provider.deleteHabitReminder(activeReminder.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🗑️ Напоминание удалено'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                    label: Text(
                      'Удалить напоминание',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Отмена',
                style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (activeReminder != null) {
                  final updated = activeReminder.copyWith(
                    time: selectedTime,
                    daysOfWeek: habit.frequency == 'weekly' ? selectedDays : null,
                    isActive: isActive,
                  );
                  await provider.updateHabitReminder(updated);
                } else {
                  await provider.addHabitReminder(
                    habitId: habit.id,
                    time: selectedTime,
                    daysOfWeek: habit.frequency == 'weekly' ? selectedDays : null,
                  );

                  if (!isActive) {
                    final newReminder = provider.getRemindersForHabit(habit.id).last;
                    await provider.toggleReminder(newReminder.id);
                  }
                }

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isActive ? '🔔 Напоминание сохранено' : '🔕 Напоминание выключено'),
                    backgroundColor: Colors.purple,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // ДИАЛОГ ДОБАВЛЕНИЯ
  // ================================================================

  void _showAddHabitDialog(BuildContext context, bool isDark, LifeProvider provider) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedIcon = '⭐';
    String selectedFrequency = 'daily';
    TimeOfDay? selectedReminderTime;
    int selectedTarget = 1;

    final icons = ['⭐', '💪', '📚', '🏃', '🧘', '🎯', '💧', '🥗', '😴', '🧠', '🎨', '🌱', '🎵', '✍️', '🧹', '💊', '🚶', '🏋️'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C853), Color(0xFF00E676)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Новая привычка',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1A1D24),
                          ),
                        ),
                        Text(
                          'Создайте полезную привычку',
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
              const SizedBox(height: 18),

              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Название привычки',
                  labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: descriptionController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Описание (необязательно)',
                  labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedIcon,
                      dropdownColor: isDark ? const Color(0xFF2A2D35) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Иконка',
                        labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: icons.map((icon) => DropdownMenuItem(
                        value: icon,
                        child: Text('$icon  ', style: const TextStyle(fontSize: 24)),
                      )).toList(),
                      onChanged: (value) { if (value != null) selectedIcon = value; },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      dropdownColor: isDark ? const Color(0xFF2A2D35) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Частота',
                        labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('📅 Ежедневно')),
                        DropdownMenuItem(value: 'weekly', child: Text('📆 Еженедельно')),
                      ],
                      onChanged: (value) { if (value != null) selectedFrequency = value; },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selectedTarget,
                      dropdownColor: isDark ? const Color(0xFF2A2D35) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Цель',
                        labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('🎯 1 раз')),
                        DropdownMenuItem(value: 2, child: Text('🎯 2 раза')),
                        DropdownMenuItem(value: 3, child: Text('🎯 3 раза')),
                        DropdownMenuItem(value: 4, child: Text('🎯 4 раза')),
                        DropdownMenuItem(value: 5, child: Text('🎯 5 раз')),
                      ],
                      onChanged: (value) { if (value != null) selectedTarget = value; },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedReminderTime ?? const TimeOfDay(hour: 8, minute: 0),
                        );
                        if (time != null) {
                          setState(() => selectedReminderTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedReminderTime != null
                                ? Colors.green.withOpacity(0.3)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedReminderTime != null ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                              color: selectedReminderTime != null ? Colors.green : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedReminderTime != null
                                  ? '${selectedReminderTime!.hour.toString().padLeft(2, '0')}:${selectedReminderTime!.minute.toString().padLeft(2, '0')}'
                                  : 'Напомнить',
                              style: TextStyle(
                                color: selectedReminderTime != null
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.white54 : Colors.grey.shade600),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.isNotEmpty) {
                          final newHabit = await provider.addHabit(
                            title: titleController.text,
                            description: descriptionController.text,
                            icon: selectedIcon,
                            frequency: selectedFrequency,
                            targetCount: selectedTarget,
                          );

                          if (selectedReminderTime != null) {
                            await provider.addHabitReminder(
                              habitId: newHabit.id,
                              time: selectedReminderTime!,
                            );
                          }

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Text('✅ '),
                                  Expanded(child: Text('Привычка "${titleController.text}" создана!')),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Создать',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // ДИАЛОГ ВСЕХ ПРИВЫЧЕК
  // ================================================================

  void _showAllHabitsDialog(BuildContext context, bool isDark, LifeProvider provider) {
    final habits = provider.habits;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C853), Color(0xFF00E676)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Все привычки',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1D24),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${habits.length} шт.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (habits.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Text('🌟', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(
                        'Нет привычек',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: habits.length,
                  itemBuilder: (ctx, index) {
                    final habit = habits[index];
                    final habitColor = Color(int.parse('0xFF${habit.color.replaceFirst('#', '')}'));
                    final isCompleted = habit.isCompletedToday();
                    final reminders = provider.getRemindersForHabit(habit.id);
                    final hasReminder = reminders.any((r) => r.isActive);
                    final achievements = getAchievements(habit);
                    final unlockedAchievements = achievements.where((a) => a['unlocked'] == true).toList();

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showHabitDetails(context, habit, provider);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isCompleted
                                ? [Colors.green.withOpacity(0.06), Colors.green.withOpacity(0.02)]
                                : [habitColor.withOpacity(0.06), habitColor.withOpacity(0.02)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCompleted
                                ? Colors.green.withOpacity(0.1)
                                : habitColor.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isCompleted
                                      ? [Colors.green, Colors.green.shade700]
                                      : [habitColor, habitColor.withOpacity(0.7)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(habit.icon, style: const TextStyle(fontSize: 18)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          habit.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : Colors.black87,
                                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                      if (hasReminder)
                                        Icon(
                                          Icons.notifications_active_rounded,
                                          size: 14,
                                          color: Colors.purple.withOpacity(0.7),
                                        ),
                                      if (unlockedAchievements.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          margin: const EdgeInsets.only(left: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '🏆 ${unlockedAchievements.length}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.amber.shade700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '🔥 ${habit.currentStreak}д',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                                        ),
                                      ),
                                      if (habit.targetCount > 1) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${habit.completionsToday}/${habit.targetCount}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isCompleted ? Colors.green : Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                      if (hasReminder) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '• 🔔 ${reminders.firstWhere((r) => r.isActive).formattedTime}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.purple.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isCompleted ? '✅' : '⏳',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  'Закрыть',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}