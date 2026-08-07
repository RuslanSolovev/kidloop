// features/life_navigator/ui/widgets/stats/stats_cards.dart
import 'package:flutter/material.dart';

class StatsCards extends StatelessWidget {
  final bool isDark;
  final Map<String, dynamic> stats;

  const StatsCards({super.key, required this.isDark, required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCardData(
        icon: '📋',
        value: '${stats['totalTasks'] ?? 0}',
        label: 'Задач',
        sub: '${stats['completedTasks'] ?? 0} выполнено',
        color: Colors.blue,
        progress: stats['totalTasks'] != null && stats['totalTasks'] > 0
            ? (stats['completedTasks'] ?? 0) / stats['totalTasks']
            : 0.0,
      ),
      _StatCardData(
        icon: '💪',
        value: '${stats['totalHabits'] ?? 0}',
        label: 'Привычек',
        sub: '${stats['completedHabitsToday'] ?? 0} сегодня',
        color: Colors.green,
        progress: stats['totalHabits'] != null && stats['totalHabits'] > 0
            ? (stats['completedHabitsToday'] ?? 0) / stats['totalHabits']
            : 0.0,
      ),
      _StatCardData(
        icon: '💡',
        value: '${stats['totalIdeas'] ?? 0}',
        label: 'Идей',
        sub: '${stats['implementedIdeas'] ?? 0} реализовано',
        color: Colors.purple,
        progress: stats['totalIdeas'] != null && stats['totalIdeas'] > 0
            ? (stats['implementedIdeas'] ?? 0) / stats['totalIdeas']
            : 0.0,
      ),
      _StatCardData(
        icon: '🔔',
        value: '${stats['activeReminders'] ?? 0}',
        label: 'Напоминаний',
        sub: 'активных',
        color: Colors.orange,
        progress: 0.0,
      ),
    ];

    return Row(
      children: cards.map((card) => Expanded(
        child: _StatCard(
          isDark: isDark,
          data: card,
        ),
      )).toList(),
    );
  }
}

class _StatCardData {
  final String icon;
  final String value;
  final String label;
  final String sub;
  final Color color;
  final double progress;

  _StatCardData({
    required this.icon,
    required this.value,
    required this.label,
    required this.sub,
    required this.color,
    required this.progress,
  });
}

class _StatCard extends StatelessWidget {
  final bool isDark;
  final _StatCardData data;

  const _StatCard({required this.isDark, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.color.withOpacity(isDark ? 0.08 : 0.04),
            data.color.withOpacity(isDark ? 0.02 : 0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: data.color.withOpacity(isDark ? 0.15 : 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(data.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          Text(
            data.value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: data.color,
              height: 1.1,
            ),
          ),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          if (data.progress > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: data.progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(data.color),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            data.sub,
            style: TextStyle(
              fontSize: 8,
              color: data.color.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}