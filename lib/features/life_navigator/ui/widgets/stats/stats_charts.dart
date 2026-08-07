// features/life_navigator/ui/widgets/stats/stats_charts.dart
import 'package:flutter/material.dart';
import '../../../models/life_models.dart';

class StatsCharts extends StatelessWidget {
  final bool isDark;
  final Map<String, dynamic> stats;
  final List<LifeHabit> habits;

  const StatsCharts({super.key, required this.isDark, required this.stats, required this.habits});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 400;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.blue.withOpacity(0.06), Colors.purple.withOpacity(0.03)]
              : [Colors.blue.withOpacity(0.04), Colors.purple.withOpacity(0.02)],
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
              const Icon(Icons.calendar_month_rounded, color: Colors.blue, size: 18),
              const SizedBox(width: 6),
              Text(
                'Активность за неделю',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildWeekHeatmap(isCompact),
          const SizedBox(height: 14),
          _buildWeekChart(isCompact),
        ],
      ),
    );
  }

  Widget _buildWeekHeatmap(bool isCompact) {
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final today = DateTime.now().weekday - 1;
    final values = habits.isEmpty ? [0, 0, 0, 0, 0, 0, 0] : _calculateWeeklyProgress();
    final maxValue = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.asMap().entries.map((entry) {
        final i = entry.key;
        final day = entry.value;
        final value = values[i];
        final isToday = i == today;
        final intensity = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

        Color color;
        if (value == 0) {
          color = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;
        } else if (intensity >= 0.8) {
          color = Colors.green;
        } else if (intensity >= 0.5) {
          color = Colors.lightGreen;
        } else if (intensity >= 0.3) {
          color = Colors.orange;
        } else {
          color = Colors.deepOrange;
        }

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCompact ? 32 : 38,
              height: isCompact ? 32 : 38,
              decoration: BoxDecoration(
                color: isToday
                    ? color.withOpacity(0.9)
                    : color.withOpacity(value > 0 ? 0.7 : 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? Colors.white.withOpacity(0.3)
                      : color.withOpacity(value > 0 ? 0.3 : 0.1),
                  width: isToday ? 2 : 1,
                ),
                boxShadow: isToday && value > 0
                    ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)]
                    : null,
              ),
              child: Center(
                child: Text(
                  value > 0 ? '$value' : '•',
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 12,
                    fontWeight: FontWeight.w700,
                    color: value > 0
                        ? (isToday ? Colors.white : Colors.white)
                        : (isDark ? Colors.white24 : Colors.grey.shade400),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day,
              style: TextStyle(
                fontSize: isCompact ? 9 : 11,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ),
            if (isToday)
              Container(
                width: 4,
                height: 2,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildWeekChart(bool isCompact) {
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final values = habits.isEmpty ? [0, 0, 0, 0, 0, 0, 0] : _calculateWeeklyProgress();
    final maxValue = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: isCompact ? 80 : 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.asMap().entries.map((entry) {
          final i = entry.key;
          final day = entry.value;
          final value = values[i];
          final height = maxValue > 0 ? (value / maxValue * (isCompact ? 60 : 80)).clamp(4.0, isCompact ? 60.0 : 80.0) : 4.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: value > 0
                            ? [Colors.blue.withOpacity(0.5), Colors.blue]
                            : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(value > 0 ? 4 : 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: isCompact ? 8 : 10,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<int> _calculateWeeklyProgress() {
    final result = List<int>.filled(7, 0);
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - 6);

    for (final habit in habits) {
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        if (habit.wasCompletedOn(date)) {
          result[i]++;
        }
      }
    }
    return result;
  }
}