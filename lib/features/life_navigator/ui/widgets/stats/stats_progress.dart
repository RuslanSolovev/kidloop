// features/life_navigator/ui/widgets/stats/stats_progress.dart
import 'package:flutter/material.dart';

class StatsProgress extends StatelessWidget {
  final bool isDark;
  final Map<String, dynamic> stats;

  const StatsProgress({super.key, required this.isDark, required this.stats});

  @override
  Widget build(BuildContext context) {
    final completionRate = (stats['completionRate'] ?? 0).toDouble();
    final isCompact = MediaQuery.of(context).size.width < 400;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.green.withOpacity(0.06), Colors.blue.withOpacity(0.03)]
              : [Colors.green.withOpacity(0.04), Colors.blue.withOpacity(0.02)],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_rounded, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Общий прогресс',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: completionRate >= 80
                        ? [Colors.green, Colors.green.shade700]
                        : completionRate >= 50
                        ? [Colors.orange, Colors.orange.shade700]
                        : [Colors.red, Colors.red.shade700],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${completionRate.round()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completionRate / 100,
              minHeight: 10,
              backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                completionRate >= 80 ? Colors.green :
                completionRate >= 50 ? Colors.orange :
                Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniProgress(
                'Задачи',
                (stats['completedTasks'] ?? 0).toDouble(),
                (stats['totalTasks'] ?? 1).toDouble(),
                Colors.blue,
                isCompact,
              ),
              const SizedBox(width: 8),
              _buildMiniProgress(
                'Привычки',
                (stats['completedHabitsToday'] ?? 0).toDouble(),
                (stats['totalHabits'] ?? 1).toDouble(),
                Colors.green,
                isCompact,
              ),
              const SizedBox(width: 8),
              _buildMiniProgress(
                'Идеи',
                (stats['implementedIdeas'] ?? 0).toDouble(),
                (stats['totalIdeas'] ?? 1).toDouble(),
                Colors.purple,
                isCompact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgress(String label, double done, double total, Color color, bool isCompact) {
    final progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isCompact ? 9 : 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              Text(
                '${done.round()}/${total.round()}',
                style: TextStyle(
                  fontSize: isCompact ? 8 : 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}