// features/life_navigator/ui/widgets/stats/stats_habits.dart
import 'package:flutter/material.dart';
import '../../../models/life_models.dart';

class StatsHabits extends StatelessWidget {
  final bool isDark;
  final List<LifeHabit> habits;

  const StatsHabits({super.key, required this.isDark, required this.habits});

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) return const SizedBox.shrink();

    final topHabits = List<LifeHabit>.from(habits)
      ..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.orange.withOpacity(0.06), Colors.red.withOpacity(0.03)]
              : [Colors.orange.withOpacity(0.04), Colors.red.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Text(
                'Топ привычек',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${habits.where((h) => h.isCompletedToday()).length}/${habits.length} сегодня',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...topHabits.take(5).map((habit) {
            final progress = (habit.currentStreak / 30).clamp(0.0, 1.0);
            final habitColor = Color(int.parse('0xFF${habit.color.replaceFirst('#', '')}'));
            final isCompleted = habit.isCompletedToday();

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCompleted
                      ? Colors.green.withOpacity(0.15)
                      : habitColor.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Text(habit.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted ? Colors.green : habitColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🔥',
                          style: TextStyle(fontSize: isCompleted ? 10 : 12),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${habit.currentStreak}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isCompleted ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
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
}