// features/life_navigator/ui/widgets/tasks/tasks_progress.dart
import 'package:flutter/material.dart';

class TasksProgress extends StatelessWidget {
  final bool isDark;
  final int todoCount, doneCount, inProgressCount;

  const TasksProgress({super.key, required this.isDark, required this.todoCount, required this.doneCount, required this.inProgressCount});

  @override
  Widget build(BuildContext context) {
    final total = todoCount + doneCount + inProgressCount;
    if (total == 0) return const SizedBox.shrink();

    final doneProgress = doneCount / total;
    final inProgressProgress = inProgressCount / total;
    final todoProgress = todoCount / total;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Прогресс', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
        Text('${(doneProgress * 100).round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.green)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(height: 8, child: Row(children: [
        if (doneCount > 0) Expanded(flex: doneCount, child: Container(color: Colors.green)),
        if (inProgressCount > 0) Expanded(flex: inProgressCount, child: Container(color: Colors.orange)),
        if (todoCount > 0) Expanded(flex: todoCount, child: Container(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200)),
      ]))),
      const SizedBox(height: 4),
      Row(children: [
        _buildLegend('Выполнено', doneCount, Colors.green),
        const SizedBox(width: 10),
        _buildLegend('В процессе', inProgressCount, Colors.orange),
        const SizedBox(width: 10),
        _buildLegend('Ожидают', todoCount, isDark ? Colors.white38 : Colors.grey.shade400),
      ]),
    ]);
  }

  Widget _buildLegend(String label, int count, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text('$label: $count', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
    ]);
  }
}