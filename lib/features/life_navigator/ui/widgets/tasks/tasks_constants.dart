// features/life_navigator/ui/widgets/tasks/tasks_constants.dart
import 'package:flutter/material.dart';

class TasksConstants {
  static const List<Map<String, dynamic>> statuses = [
    {'id': 'formulated', 'label': 'Сформулирована', 'emoji': '📝', 'color': Color(0xFF4A9EFF)},
    {'id': 'in_progress', 'label': 'В процессе', 'emoji': '⚡', 'color': Color(0xFFFF6B35)},
    {'id': 'done', 'label': 'Готова', 'emoji': '✅', 'color': Color(0xFF00C853)},
    {'id': 'postponed', 'label': 'Отложена', 'emoji': '⏰', 'color': Color(0xFF7C4DFF)},
  ];

  static const List<Map<String, dynamic>> priorities = [
    {'id': 'urgent', 'label': 'Срочный', 'emoji': '🔴', 'color': Color(0xFFFF1744)},
    {'id': 'high', 'label': 'Высокий', 'emoji': '🟠', 'color': Color(0xFFFF6B35)},
    {'id': 'medium', 'label': 'Средний', 'emoji': '🟡', 'color': Color(0xFFFFC107)},
    {'id': 'low', 'label': 'Низкий', 'emoji': '🟢', 'color': Color(0xFF00C853)},
  ];

  static Color getStatusColor(String statusId) {
    final status = statuses.firstWhere(
          (s) => s['id'] == statusId,
      orElse: () => statuses.first,
    );
    return status['color'] as Color;
  }

  static String getStatusEmoji(String statusId) {
    final status = statuses.firstWhere(
          (s) => s['id'] == statusId,
      orElse: () => statuses.first,
    );
    return status['emoji'] as String;
  }

  static String getStatusLabel(String statusId) {
    final status = statuses.firstWhere(
          (s) => s['id'] == statusId,
      orElse: () => statuses.first,
    );
    return status['label'] as String;
  }

  static Color getPriorityColor(String priorityId) {
    final priority = priorities.firstWhere(
          (p) => p['id'] == priorityId,
      orElse: () => priorities.last,
    );
    return priority['color'] as Color;
  }

  static String getPriorityEmoji(String priorityId) {
    final priority = priorities.firstWhere(
          (p) => p['id'] == priorityId,
      orElse: () => priorities.last,
    );
    return priority['emoji'] as String;
  }

  static Color getTagColor(String tag) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    return colors[tag.hashCode.abs() % colors.length];
  }
}