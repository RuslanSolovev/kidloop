// features/life_navigator/models/life_models.dart
import 'dart:convert';
import 'package:flutter/material.dart';

// ==================== ВИДЖЕТЫ ====================

class LifeWidget {
  final String id;
  final String type;
  final int position;
  final Map<String, dynamic> config;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  LifeWidget({
    required this.id,
    required this.type,
    required this.position,
    this.config = const {},
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'position': position,
      'config': jsonEncode(config),
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LifeWidget.fromMap(Map<String, dynamic> map) {
    return LifeWidget(
      id: map['id'],
      type: map['type'],
      position: map['position'],
      config: map['config'] is String ? jsonDecode(map['config']) : (map['config'] as Map?) ?? {},
      isActive: (map['isActive'] ?? 1) == 1,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}

// ==================== ЗАМЕТКИ ====================

class LifeNote {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final String color;
  final bool isFavorite;
  final List<String> images; // <-- ДОБАВЛЯЕМ
  final DateTime createdAt;
  final DateTime updatedAt;

  LifeNote({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    this.color = '#FF6B00',
    this.isFavorite = false,
    this.images = const [], // <-- ДОБАВЛЯЕМ
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': jsonEncode(tags),
      'color': color,
      'isFavorite': isFavorite ? 1 : 0,
      'images': jsonEncode(images), // <-- ДОБАВЛЯЕМ
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LifeNote.fromMap(Map<String, dynamic> map) {
    return LifeNote(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      tags: map['tags'] is String ? List<String>.from(jsonDecode(map['tags'])) : (map['tags'] as List?)?.cast<String>() ?? [],
      color: map['color'] ?? '#FF6B00',
      isFavorite: (map['isFavorite'] ?? 0) == 1,
      images: map['images'] is String ? List<String>.from(jsonDecode(map['images'])) : (map['images'] as List?)?.cast<String>() ?? [], // <-- ДОБАВЛЯЕМ
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  LifeNote copyWith({
    String? title,
    String? content,
    List<String>? tags,
    String? color,
    bool? isFavorite,
    List<String>? images, // <-- ДОБАВЛЯЕМ
    DateTime? updatedAt,
  }) {
    return LifeNote(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      isFavorite: isFavorite ?? this.isFavorite,
      images: images ?? this.images, // <-- ДОБАВЛЯЕМ
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

// ==================== СОБЫТИЯ КАЛЕНДАРЯ ====================

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final DateTime? time;
  final String? endDate;
  final String? endTime;
  final String? location;
  final String color;
  final bool isAllDay;
  final bool hasReminder;
  final int reminderMinutes;
  final bool isCompleted;
  final String recurrence;
  final String recurrenceDays;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.time,
    this.endDate,
    this.endTime,
    this.location,
    this.color = '#FF6B00',
    this.isAllDay = false,
    this.hasReminder = false,
    this.reminderMinutes = 15,
    this.isCompleted = false,
    this.recurrence = 'none',
    this.recurrenceDays = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'time': time?.toIso8601String(),
      'endDate': endDate,
      'endTime': endTime,
      'location': location,
      'color': color,
      'isAllDay': isAllDay ? 1 : 0,
      'hasReminder': hasReminder ? 1 : 0,
      'reminderMinutes': reminderMinutes,
      'isCompleted': isCompleted ? 1 : 0,
      'recurrence': recurrence,
      'recurrenceDays': recurrenceDays,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      date: DateTime.parse(map['date']),
      time: map['time'] != null ? DateTime.parse(map['time']) : null,
      endDate: map['endDate'],
      endTime: map['endTime'],
      location: map['location'],
      color: map['color'] ?? '#FF6B00',
      isAllDay: (map['isAllDay'] ?? 0) == 1,
      hasReminder: (map['hasReminder'] ?? 0) == 1,
      reminderMinutes: map['reminderMinutes'] ?? 15,
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      recurrence: map['recurrence'] ?? 'none',
      recurrenceDays: map['recurrenceDays'] ?? '',
    );
  }

  bool get isRecurring => recurrence != 'none';

  List<String> get recurrenceDaysList {
    if (recurrenceDays.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(recurrenceDays));
    } catch (_) {
      return [];
    }
  }
}

// ==================== ПРОЕКТЫ ====================

class LifeProject {
  final String id;
  final String title;
  final String description;
  final String? parentId;
  final String category;
  final String status;
  final int progress;
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime updatedAt;

  LifeProject({
    required this.id,
    required this.title,
    this.description = '',
    this.parentId,
    this.category = 'personal',
    this.status = 'active',
    this.progress = 0,
    this.deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'parentId': parentId,
      'category': category,
      'status': status,
      'progress': progress,
      'deadline': deadline?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LifeProject.fromMap(Map<String, dynamic> map) {
    return LifeProject(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      parentId: map['parentId'],
      category: map['category'] ?? 'personal',
      status: map['status'] ?? 'active',
      progress: map['progress'] ?? 0,
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}

// ==================== ЗАДАЧИ (ПОЛНАЯ ИЕРАРХИЯ) ====================

class LifeTask {
  final String id;
  final String title;
  final String description;
  final String? projectId;
  final String? goalId;
  final List<String> tags;
  final String priority;
  final String status; // formulated, in_progress, done, postponed
  final DateTime? deadline;
  final int estimatedMinutes;
  final int actualMinutes;
  final bool isRecurring;
  final String recurrenceRule;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 🔥 ИЕРАРХИЯ - связь с родителем и дочерними задачами через ID
  final String? parentId;          // ID родительской задачи
  final List<String>? subtaskIds;  // ID дочерних задач (полноценные задачи)
  final List<String>? images;
  final bool? hasReminder;
  final int? reminderMinutes;
  final TimeOfDay? reminderTime;

  LifeTask({
    required this.id,
    required this.title,
    this.description = '',
    this.projectId,
    this.goalId,
    this.tags = const [],
    this.priority = 'medium',
    this.status = 'formulated', // изменено с 'todo' на 'formulated'
    this.deadline,
    this.estimatedMinutes = 0,
    this.actualMinutes = 0,
    this.isRecurring = false,
    this.recurrenceRule = '',
    this.parentId,
    this.subtaskIds,
    this.images,
    this.hasReminder,
    this.reminderMinutes,
    this.reminderTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'projectId': projectId,
      'goalId': goalId,
      'tags': jsonEncode(tags),
      'priority': priority,
      'status': status,
      'deadline': deadline?.toIso8601String(),
      'estimatedMinutes': estimatedMinutes,
      'actualMinutes': actualMinutes,
      'isRecurring': isRecurring ? 1 : 0,
      'recurrenceRule': recurrenceRule,
      'parentId': parentId,
      'subtaskIds': subtaskIds != null ? jsonEncode(subtaskIds) : null,
      'images': images != null ? jsonEncode(images) : null,
      'hasReminder': hasReminder == true ? 1 : 0,
      'reminderMinutes': reminderMinutes,
      'reminderTime': reminderTime != null ? '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}' : null,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LifeTask.fromMap(Map<String, dynamic> map) {
    List<String>? subtaskIds;
    if (map['subtaskIds'] != null) {
      try {
        subtaskIds = map['subtaskIds'] is String
            ? List<String>.from(jsonDecode(map['subtaskIds']))
            : (map['subtaskIds'] as List).cast<String>();
      } catch (_) {
        subtaskIds = null;
      }
    }

    List<String>? images;
    if (map['images'] != null) {
      try {
        images = map['images'] is String
            ? List<String>.from(jsonDecode(map['images']))
            : (map['images'] as List).cast<String>();
      } catch (_) {
        images = null;
      }
    }

    TimeOfDay? reminderTime;
    if (map['reminderTime'] != null) {
      try {
        final parts = (map['reminderTime'] as String).split(':');
        reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {
        reminderTime = null;
      }
    }

    return LifeTask(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      projectId: map['projectId'],
      goalId: map['goalId'],
      tags: map['tags'] is String ? List<String>.from(jsonDecode(map['tags'])) : (map['tags'] as List?)?.cast<String>() ?? [],
      priority: map['priority'] ?? 'medium',
      status: map['status'] ?? 'formulated',
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      estimatedMinutes: map['estimatedMinutes'] ?? 0,
      actualMinutes: map['actualMinutes'] ?? 0,
      isRecurring: (map['isRecurring'] ?? 0) == 1,
      recurrenceRule: map['recurrenceRule'] ?? '',
      parentId: map['parentId'],
      subtaskIds: subtaskIds,
      images: images,
      hasReminder: (map['hasReminder'] ?? 0) == 1,
      reminderMinutes: map['reminderMinutes'],
      reminderTime: reminderTime,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  LifeTask copyWith({
    String? title,
    String? description,
    String? projectId,
    String? goalId,
    List<String>? tags,
    String? priority,
    String? status,
    DateTime? deadline,
    int? estimatedMinutes,
    int? actualMinutes,
    bool? isRecurring,
    String? recurrenceRule,
    String? parentId,
    List<String>? subtaskIds,
    List<String>? images,
    bool? hasReminder,
    int? reminderMinutes,
    TimeOfDay? reminderTime,
    DateTime? updatedAt,
  }) {
    return LifeTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      goalId: goalId ?? this.goalId,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      deadline: deadline ?? this.deadline,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      parentId: parentId ?? this.parentId,
      subtaskIds: subtaskIds ?? this.subtaskIds,
      images: images ?? this.images,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  /// Проверяет, является ли задача корневой (без родителя)
  bool get isRoot => parentId == null;

  /// Проверяет, есть ли у задачи дочерние задачи
  bool get hasSubtasks => subtaskIds != null && subtaskIds!.isNotEmpty;

  /// Возвращает статус в удобном для отображения виде
  String get statusDisplay {
    switch (status) {
      case 'formulated': return 'Сформулирована';
      case 'in_progress': return 'В процессе';
      case 'done': return 'Готова';
      case 'postponed': return 'Отложена';
      default: return status;
    }
  }

  /// Возвращает эмодзи для статуса
  String get statusEmoji {
    switch (status) {
      case 'formulated': return '📝';
      case 'in_progress': return '⚡';
      case 'done': return '✅';
      case 'postponed': return '⏰';
      default: return '📋';
    }
  }

  /// Возвращает цвет для статуса
  Color get statusColor {
    switch (status) {
      case 'formulated': return const Color(0xFF4A9EFF);
      case 'in_progress': return const Color(0xFFFF6B35);
      case 'done': return const Color(0xFF00C853);
      case 'postponed': return const Color(0xFF7C4DFF);
      default: return Colors.grey;
    }
  }

  /// Возвращает приоритет в удобном для отображения виде
  String get priorityDisplay {
    switch (priority) {
      case 'urgent': return 'Срочный';
      case 'high': return 'Высокий';
      case 'medium': return 'Средний';
      case 'low': return 'Низкий';
      default: return priority;
    }
  }

  /// Возвращает эмодзи для приоритета
  String get priorityEmoji {
    switch (priority) {
      case 'urgent': return '🔴';
      case 'high': return '🟠';
      case 'medium': return '🟡';
      case 'low': return '🟢';
      default: return '⚪';
    }
  }

  /// Возвращает цвет для приоритета
  Color get priorityColor {
    switch (priority) {
      case 'urgent': return const Color(0xFFFF1744);
      case 'high': return const Color(0xFFFF6B35);
      case 'medium': return const Color(0xFFFFC107);
      case 'low': return const Color(0xFF00C853);
      default: return Colors.grey;
    }
  }

  /// Возвращает цвет для тега
  static Color getTagColor(String tag) {
    final colors = [
      const Color(0xFF4A9EFF),
      const Color(0xFF00C853),
      const Color(0xFFFF6B35),
      const Color(0xFF7C4DFF),
      const Color(0xFFFF1744),
      const Color(0xFF00BCD4),
      const Color(0xFFFFC107),
      const Color(0xFFFF6B9D),
    ];
    return colors[tag.hashCode.abs() % colors.length];
  }
}

// ==================== КЛАСС ДЛЯ ВВОДА ПОДЗАДАЧ В ДИАЛОГЕ ====================

class SubtaskInput {
  final TextEditingController controller = TextEditingController();
  bool isDone = false;

  SubtaskInput({String? initialText}) {
    if (initialText != null) {
      controller.text = initialText;
    }
  }

  void dispose() {
    controller.dispose();
  }
}

// ==================== ПРИВЫЧКИ ====================

class LifeHabit {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String color;
  final String frequency;
  final List<String> daysOfWeek;
  final int targetCount;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCompleted;
  final int completionsToday;
  final List<String> completedDates;
  final DateTime createdAt;
  final DateTime updatedAt;

  LifeHabit({
    required this.id,
    required this.title,
    this.description = '',
    this.icon = '⭐',
    this.color = '#FF6B00',
    this.frequency = 'daily',
    this.daysOfWeek = const [],
    this.targetCount = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompleted,
    this.completionsToday = 0,
    this.completedDates = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'color': color,
      'frequency': frequency,
      'daysOfWeek': jsonEncode(daysOfWeek),
      'targetCount': targetCount,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastCompleted': lastCompleted?.toIso8601String(),
      'completionsToday': completionsToday,
      'completedDates': jsonEncode(completedDates),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LifeHabit.fromMap(Map<String, dynamic> map) {
    return LifeHabit(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      icon: map['icon'] ?? '⭐',
      color: map['color'] ?? '#FF6B00',
      frequency: map['frequency'] ?? 'daily',
      daysOfWeek: map['daysOfWeek'] is String ? List<String>.from(jsonDecode(map['daysOfWeek'])) : (map['daysOfWeek'] as List?)?.cast<String>() ?? [],
      targetCount: map['targetCount'] ?? 1,
      currentStreak: map['currentStreak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      lastCompleted: map['lastCompleted'] != null ? DateTime.parse(map['lastCompleted']) : null,
      completionsToday: map['completionsToday'] ?? 0,
      completedDates: map['completedDates'] is String ? List<String>.from(jsonDecode(map['completedDates'])) : (map['completedDates'] as List?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  bool isCompletedToday() {
    final today = _todayString();
    if (lastCompleted == null) return false;
    if (_dateString(lastCompleted!) != today) return false;
    return completionsToday >= targetCount;
  }

  bool canCompleteToday() {
    final today = _todayString();
    if (lastCompleted != null && _dateString(lastCompleted!) == today) {
      if (completionsToday >= targetCount) return false;
    }
    if (frequency == 'weekly' && daysOfWeek.isNotEmpty) {
      final weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final todayWeekday = weekdayNames[DateTime.now().weekday - 1];
      if (!daysOfWeek.contains(todayWeekday)) return false;
    }
    return true;
  }

  List<bool> getWeekProgress() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));
    final progress = <bool>[];
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateStr = _dateString(date);
      final wasCompleted = completedDates.any((d) {
        try { return _dateString(DateTime.parse(d)) == dateStr; } catch (_) { return false; }
      });
      final isLastCompletedDate = lastCompleted != null && _dateString(lastCompleted!) == dateStr;
      progress.add(wasCompleted || isLastCompletedDate);
    }
    return progress;
  }

  bool wasCompletedOn(DateTime date) {
    final dateStr = _dateString(date);
    final inList = completedDates.any((d) {
      try { return _dateString(DateTime.parse(d)) == dateStr; } catch (_) { return false; }
    });
    final isLastCompleted = lastCompleted != null && _dateString(lastCompleted!) == dateStr;
    return inList || isLastCompleted;
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _dateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  LifeHabit copyWith({
    String? id, String? title, String? description, String? icon, String? color,
    String? frequency, List<String>? daysOfWeek, int? targetCount, int? currentStreak,
    int? longestStreak, DateTime? lastCompleted, int? completionsToday,
    List<String>? completedDates, DateTime? createdAt, DateTime? updatedAt,
  }) {
    return LifeHabit(
      id: id ?? this.id, title: title ?? this.title, description: description ?? this.description,
      icon: icon ?? this.icon, color: color ?? this.color, frequency: frequency ?? this.frequency,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek, targetCount: targetCount ?? this.targetCount,
      currentStreak: currentStreak ?? this.currentStreak, longestStreak: longestStreak ?? this.longestStreak,
      lastCompleted: lastCompleted ?? this.lastCompleted, completionsToday: completionsToday ?? this.completionsToday,
      completedDates: completedDates ?? this.completedDates, createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

// ==================== НАПОМИНАНИЕ ДЛЯ ПРИВЫЧКИ ====================

class HabitReminder {
  final String id;
  final String habitId;
  final TimeOfDay time;
  final List<String>? daysOfWeek;
  final bool isActive;
  final DateTime createdAt;

  HabitReminder({
    required this.id,
    required this.habitId,
    required this.time,
    this.daysOfWeek,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'daysOfWeek': daysOfWeek != null ? jsonEncode(daysOfWeek) : null,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HabitReminder.fromMap(Map<String, dynamic> map) {
    final timeStr = map['time'] as String;
    final parts = timeStr.split(':');
    final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    return HabitReminder(
      id: map['id'],
      habitId: map['habitId'],
      time: time,
      daysOfWeek: map['daysOfWeek'] is String ? List<String>.from(jsonDecode(map['daysOfWeek'])) : (map['daysOfWeek'] as List?)?.cast<String>(),
      isActive: (map['isActive'] ?? 1) == 1,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  String get formattedTime => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  bool isActiveToday() {
    if (!isActive) return false;
    if (daysOfWeek == null || daysOfWeek!.isEmpty) return true;
    final weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final todayWeekday = weekdayNames[DateTime.now().weekday - 1];
    return daysOfWeek!.contains(todayWeekday);
  }

  String get daysDescription {
    if (daysOfWeek == null || daysOfWeek!.isEmpty) return 'Ежедневно';
    const shortNames = {'Monday': 'Пн', 'Tuesday': 'Вт', 'Wednesday': 'Ср', 'Thursday': 'Чт', 'Friday': 'Пт', 'Saturday': 'Сб', 'Sunday': 'Вс'};
    return daysOfWeek!.map((d) => shortNames[d] ?? d).join(', ');
  }

  HabitReminder copyWith({String? id, String? habitId, TimeOfDay? time, List<String>? daysOfWeek, bool? isActive, DateTime? createdAt}) {
    return HabitReminder(
      id: id ?? this.id, habitId: habitId ?? this.habitId, time: time ?? this.time,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek, isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ==================== ИДЕИ ====================

class LifeIdea {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final String category;
  final int rating;
  final String color;
  final String status;
  final int priority;
  final int impact;
  final int confidence;
  final int ease;
  final DateTime? deadline;
  final List<String> images;
  final bool isFavorite;
  final bool isImplemented;
  final DateTime? implementedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isIdeaOfDay;

  LifeIdea({
    required this.id,
    required this.title,
    this.description = '',
    this.tags = const [],
    this.category = 'general',
    this.rating = 0,
    this.color = '#FF6B00',
    this.status = 'idea',
    this.priority = 0,
    this.impact = 5,
    this.confidence = 5,
    this.ease = 5,
    this.deadline,
    this.images = const [],
    this.isFavorite = false,
    this.isImplemented = false,
    this.implementedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isIdeaOfDay = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get iceScore => (impact + confidence + ease) / 3.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'tags': jsonEncode(tags),
      'category': category,
      'rating': rating,
      'color': color,
      'status': status,
      'priority': priority,
      'impact': impact,
      'confidence': confidence,
      'ease': ease,
      'deadline': deadline?.toIso8601String(),
      'images': jsonEncode(images),
      'isFavorite': isFavorite ? 1 : 0,
      'isImplemented': isImplemented ? 1 : 0,
      'implementedAt': implementedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isIdeaOfDay': isIdeaOfDay ? 1 : 0,
    };
  }

  factory LifeIdea.fromMap(Map<String, dynamic> map) {
    return LifeIdea(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      tags: _parseJsonList(map['tags']),
      category: map['category'] ?? 'general',
      rating: map['rating'] ?? 0,
      color: map['color'] ?? '#FF6B00',
      status: map['status'] ?? 'idea',
      priority: map['priority'] ?? 0,
      impact: map['impact'] ?? 5,
      confidence: map['confidence'] ?? 5,
      ease: map['ease'] ?? 5,
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      images: _parseJsonList(map['images']),
      isFavorite: (map['isFavorite'] ?? 0) == 1,
      isImplemented: (map['isImplemented'] ?? 0) == 1,
      implementedAt: map['implementedAt'] != null ? DateTime.parse(map['implementedAt']) : null,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isIdeaOfDay: (map['isIdeaOfDay'] ?? 0) == 1,
    );
  }

  static List<String> _parseJsonList(dynamic value) {
    if (value is String) {
      try { return List<String>.from(jsonDecode(value)); } catch (_) {}
    }
    if (value is List) return value.cast<String>();
    return [];
  }

  LifeIdea copyWith({
    String? title,
    String? description,
    List<String>? tags,
    String? category,
    int? rating,
    String? color,
    String? status,
    int? priority,
    int? impact,
    int? confidence,
    int? ease,
    DateTime? deadline,
    List<String>? images,
    bool? isFavorite,
    bool? isImplemented,
    DateTime? implementedAt,
    bool? isIdeaOfDay,
  }) {
    return LifeIdea(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      color: color ?? this.color,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      impact: impact ?? this.impact,
      confidence: confidence ?? this.confidence,
      ease: ease ?? this.ease,
      deadline: deadline ?? this.deadline,
      images: images ?? this.images,
      isFavorite: isFavorite ?? this.isFavorite,
      isImplemented: isImplemented ?? this.isImplemented,
      implementedAt: implementedAt ?? this.implementedAt,
      isIdeaOfDay: isIdeaOfDay ?? this.isIdeaOfDay,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// ==================== ВХОДЯЩИЕ ====================

class InboxItem {
  final String id;
  final String text;
  final String type;
  final bool isProcessed;
  final DateTime? processedAt;
  final DateTime createdAt;

  InboxItem({
    required this.id,
    required this.text,
    this.type = 'idea',
    this.isProcessed = false,
    this.processedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'isProcessed': isProcessed ? 1 : 0,
      'processedAt': processedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InboxItem.fromMap(Map<String, dynamic> map) {
    return InboxItem(
      id: map['id'],
      text: map['text'],
      type: map['type'] ?? 'idea',
      isProcessed: (map['isProcessed'] ?? 0) == 1,
      processedAt: map['processedAt'] != null ? DateTime.parse(map['processedAt']) : null,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

// ==================== ТРЕКЕР ВРЕМЕНИ ====================

class TimeLog {
  final String id;
  final String taskId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;

  TimeLog({
    required this.id,
    required this.taskId,
    required this.startTime,
    this.endTime,
    this.durationMinutes = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
    };
  }

  factory TimeLog.fromMap(Map<String, dynamic> map) {
    return TimeLog(
      id: map['id'],
      taskId: map['taskId'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      durationMinutes: map['durationMinutes'] ?? 0,
    );
  }
}