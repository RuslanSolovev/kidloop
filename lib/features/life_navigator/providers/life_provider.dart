// features/life_navigator/providers/life_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/life_database.dart';
import '../models/life_models.dart';
import '../../../services/notification_service.dart'; // 🔥 ДОБАВЛЕН ИМПОРТ

class LifeProvider extends ChangeNotifier {
  final LifeDatabase _db = LifeDatabase();
  final Uuid _uuid = const Uuid();

  List<LifeWidget> _widgets = [];
  List<LifeNote> _notes = [];
  List<CalendarEvent> _events = [];
  List<LifeProject> _projects = [];
  List<LifeTask> _tasks = [];
  List<LifeHabit> _habits = [];
  List<HabitReminder> _reminders = []; // 🔥 НОВЫЙ СПИСОК
  List<LifeIdea> _ideas = [];
  List<InboxItem> _inbox = [];
  List<TimeLog> _timeLogs = [];

  bool _isLoading = false;

  List<LifeWidget> get widgets => _widgets;
  List<LifeNote> get notes => _notes;
  List<CalendarEvent> get events => _events;
  List<LifeProject> get projects => _projects;
  List<LifeTask> get tasks => _tasks;
  List<LifeHabit> get habits => _habits;
  List<HabitReminder> get reminders => _reminders; // 🔥 ГЕТТЕР
  List<LifeIdea> get ideas => _ideas;
  List<InboxItem> get inbox => _inbox;
  List<TimeLog> get timeLogs => _timeLogs;
  bool get isLoading => _isLoading;

  // ==================== ИНИЦИАЛИЗАЦИЯ ====================

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadWidgets(),
        _loadNotes(),
        _loadEvents(),
        _loadProjects(),
        _loadTasks(),
        _loadHabits(),
        _loadReminders(), // 🔥 ЗАГРУЗКА НАПОМИНАНИЙ
        _loadIdeas(),
        _loadInbox(),
        _loadTimeLogs(),
      ]);

      // 🔥 СБРАСЫВАЕМ СЧЁТЧИКИ ДЛЯ НОВОГО ДНЯ
      _resetHabitsForNewDay();

      // 🔥 ВОССТАНАВЛИВАЕМ НАПОМИНАНИЯ
      _rescheduleAllReminders();

    } catch (e) {
      debugPrint('Ошибка загрузки данных: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // 🔥 СБРОС completionsToday ДЛЯ ВСЕХ ПРИВЫЧЕК ПРИ НОВОМ ДНЕ
  void _resetHabitsForNewDay() {
    final today = _todayString();
    bool changed = false;

    for (int i = 0; i < _habits.length; i++) {
      final habit = _habits[i];

      if (habit.lastCompleted != null && _dateString(habit.lastCompleted!) != today) {
        if (habit.completionsToday > 0) {
          _habits[i] = habit.copyWith(completionsToday: 0);
          changed = true;
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  // 🔥 ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С ДАТАМИ
  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _dateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadWidgets() async {
    final data = await _db.query('widgets', orderBy: 'position ASC');
    _widgets = data.map((e) => LifeWidget.fromMap(e)).toList();
    if (_widgets.isEmpty) {
      _createDefaultWidgets();
    }
  }

  void _createDefaultWidgets() {
    final defaultWidgets = [
      LifeWidget(id: _uuid.v4(), type: 'calendar', position: 0),
      LifeWidget(id: _uuid.v4(), type: 'tasks', position: 1),
      LifeWidget(id: _uuid.v4(), type: 'habits', position: 2),
      LifeWidget(id: _uuid.v4(), type: 'notes', position: 3),
      LifeWidget(id: _uuid.v4(), type: 'ideas', position: 4),
      LifeWidget(id: _uuid.v4(), type: 'stats', position: 5),
      LifeWidget(id: _uuid.v4(), type: 'inbox', position: 6),
    ];
    for (final w in defaultWidgets) {
      _db.insert('widgets', w.toMap());
      _widgets.add(w);
    }
    notifyListeners();
  }

  Future<void> _loadNotes() async {
    final data = await _db.query('notes', orderBy: 'createdAt DESC');
    _notes = data.map((e) => LifeNote.fromMap(e)).toList();
  }

  Future<void> _loadEvents() async {
    final data = await _db.query('calendar_events', orderBy: 'date ASC');
    _events = data.map((e) => CalendarEvent.fromMap(e)).toList();
  }

  Future<void> _loadProjects() async {
    final data = await _db.query('projects', orderBy: 'createdAt DESC');
    _projects = data.map((e) => LifeProject.fromMap(e)).toList();
  }

  Future<void> _loadTasks() async {
    final data = await _db.query('tasks', orderBy: 'deadline ASC, createdAt DESC');
    _tasks = data.map((e) => LifeTask.fromMap(e)).toList();
  }

  Future<void> _loadHabits() async {
    final data = await _db.query('habits', orderBy: 'title ASC');
    _habits = data.map((e) => LifeHabit.fromMap(e)).toList();
  }

  // 🔥 ЗАГРУЗКА НАПОМИНАНИЙ
  Future<void> _loadReminders() async {
    final data = await _db.query('habit_reminders', orderBy: 'time ASC');
    _reminders = data.map((e) => HabitReminder.fromMap(e)).toList();
    debugPrint('📅 Загружено напоминаний: ${_reminders.length}');
  }

  // 🔥 ВОССТАНОВЛЕНИЕ ВСЕХ НАПОМИНАНИЙ ПОСЛЕ ПЕРЕЗАПУСКА
  void _rescheduleAllReminders() {
    final notificationService = NotificationService();

    for (final reminder in _reminders) {
      if (!reminder.isActive) continue;

      // Находим привычку
      final habit = _habits.firstWhere(
            (h) => h.id == reminder.habitId,
        orElse: () => _habits.first,
      );

      // Если привычка уже выполнена сегодня — не планируем
      if (habit.id == reminder.habitId && habit.isCompletedToday()) continue;

      // Если сегодня не тот день недели — не планируем
      if (!reminder.isActiveToday()) continue;

      // Планируем напоминание
      notificationService.scheduleHabitReminder(
        habitId: habit.id,
        habitTitle: habit.title,
        reminderTime: reminder.time,
      );
    }

    debugPrint('🔄 Восстановлено напоминаний: ${_reminders.where((r) => r.isActive).length}');
  }

  Future<void> _loadIdeas() async {
    final data = await _db.query('ideas', orderBy: 'isFavorite DESC, createdAt DESC');
    _ideas = data.map((e) => LifeIdea.fromMap(e)).toList();
  }

  Future<void> _loadInbox() async {
    final data = await _db.query('inbox', orderBy: 'createdAt DESC');
    _inbox = data.map((e) => InboxItem.fromMap(e)).toList();
  }

  Future<void> _loadTimeLogs() async {
    final data = await _db.query('time_logs', orderBy: 'startTime DESC');
    _timeLogs = data.map((e) => TimeLog.fromMap(e)).toList();
  }

  // ==================== ВИДЖЕТЫ ====================

  Future<void> addWidget(String type) async {
    final position = _widgets.length;
    final widget = LifeWidget(id: _uuid.v4(), type: type, position: position);
    await _db.insert('widgets', widget.toMap());
    _widgets.add(widget);
    notifyListeners();
  }

  Future<void> removeWidget(String id) async {
    await _db.delete('widgets', where: 'id = ?', whereArgs: [id]);
    _widgets.removeWhere((w) => w.id == id);
    _reorderWidgets();
    notifyListeners();
  }

  Future<void> reorderWidgets(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final widget = _widgets.removeAt(oldIndex);
    _widgets.insert(newIndex, widget);
    _reorderWidgets();
    notifyListeners();
  }

  void _reorderWidgets() {
    for (var i = 0; i < _widgets.length; i++) {
      _widgets[i] = LifeWidget(
        id: _widgets[i].id,
        type: _widgets[i].type,
        position: i,
        config: _widgets[i].config,
        isActive: _widgets[i].isActive,
        createdAt: _widgets[i].createdAt,
        updatedAt: DateTime.now(),
      );
      _db.update('widgets', _widgets[i].toMap(), where: 'id = ?', whereArgs: [_widgets[i].id]);
    }
  }

  // ==================== ЗАМЕТКИ ====================

  Future<void> deleteNote(String id) async {
    await _db.delete('notes', where: 'id = ?', whereArgs: [id]);
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  Future<LifeNote> addNote(
      String title,
      String content, {
        List<String> tags = const [],
        String color = '#FF6B00',
        List<String> images = const [], // <-- ДОБАВЛЯЕМ
      }) async {
    final note = LifeNote(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags,
      color: color,
      images: images, // <-- ДОБАВЛЯЕМ
    );
    await _db.insert('notes', note.toMap());
    _notes.insert(0, note);
    notifyListeners();
    return note;
  }

  Future<void> updateNote(LifeNote note) async {
    final updated = LifeNote(
      id: note.id,
      title: note.title,
      content: note.content,
      tags: note.tags,
      color: note.color,
      isFavorite: note.isFavorite,
      images: note.images, // <-- ДОБАВЛЯЕМ
      createdAt: note.createdAt,
      updatedAt: DateTime.now(),
    );
    await _db.update('notes', updated.toMap(), where: 'id = ?', whereArgs: [note.id]);
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) _notes[index] = updated;
    notifyListeners();
  }

  // ==================== СОБЫТИЯ КАЛЕНДАРЯ ====================

  Future<CalendarEvent> addEvent({
    required String title,
    String description = '',
    required DateTime date,
    DateTime? time,
    String? endDate,
    String? endTime,
    String? location,
    String color = '#FF6B00',
    bool isAllDay = false,
    bool hasReminder = false,
    int reminderMinutes = 15,
  }) async {
    final event = CalendarEvent(
      id: _uuid.v4(),
      title: title,
      description: description,
      date: date,
      time: time,
      endDate: endDate,
      endTime: endTime,
      location: location,
      color: color,
      isAllDay: isAllDay,
      hasReminder: hasReminder,
      reminderMinutes: reminderMinutes,
    );
    await _db.insert('calendar_events', event.toMap());
    _events.add(event);
    _events.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    return event;
  }

  Future<void> updateEvent(CalendarEvent event) async {
    await _db.update('calendar_events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) _events[index] = event;
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    await _db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  List<CalendarEvent> getEventsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _events.where((e) => e.date.isAfter(start) && e.date.isBefore(end)).toList();
  }

  // ==================== ПРОЕКТЫ ====================

  Future<LifeProject> addProject({
    required String title,
    String description = '',
    String? parentId,
    String category = 'personal',
    DateTime? deadline,
  }) async {
    final project = LifeProject(
      id: _uuid.v4(),
      title: title,
      description: description,
      parentId: parentId,
      category: category,
      deadline: deadline,
    );
    await _db.insert('projects', project.toMap());
    _projects.insert(0, project);
    notifyListeners();
    return project;
  }

  Future<void> updateProject(LifeProject project) async {
    await _db.update('projects', project.toMap(), where: 'id = ?', whereArgs: [project.id]);
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) _projects[index] = project;
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    await _db.delete('projects', where: 'id = ?', whereArgs: [id]);
    _projects.removeWhere((p) => p.id == id);
    final tasksToDelete = _tasks.where((t) => t.projectId == id).toList();
    for (final task in tasksToDelete) {
      await deleteTask(task.id);
    }
    notifyListeners();
  }

  // ==================== ЗАДАЧИ (ОБНОВЛЁННЫЕ) ====================

  Future<LifeTask> addTask({
    required String title,
    String description = '',
    String? projectId,
    String? goalId,
    List<String> tags = const [],
    String priority = 'medium',
    String status = 'formulated', // изменено с 'todo'
    DateTime? deadline,
    int estimatedMinutes = 0,
    String? parentId,
    List<String>? subtaskIds, // изменено с List<TaskSubtask>?
    List<String>? images,
    bool? hasReminder,
    int? reminderMinutes,
    TimeOfDay? reminderTime,
  }) async {
    final task = LifeTask(
      id: _uuid.v4(),
      title: title,
      description: description,
      projectId: projectId,
      goalId: goalId,
      tags: tags,
      priority: priority,
      status: status,
      deadline: deadline,
      estimatedMinutes: estimatedMinutes,
      parentId: parentId,
      subtaskIds: subtaskIds,
      images: images,
      hasReminder: hasReminder,
      reminderMinutes: reminderMinutes,
      reminderTime: reminderTime,
    );
    await _db.insert('tasks', task.toMap());
    _tasks.add(task);
    _sortTasks();

    // 🔥 Если у задачи есть родитель - обновляем его subtaskIds
    if (parentId != null) {
      await _addSubtaskToParent(parentId, task.id);
    }

    notifyListeners();
    return task;
  }

  /// Добавляет ID подзадачи в родительскую задачу
  Future<void> _addSubtaskToParent(String parentId, String subtaskId) async {
    final parentIndex = _tasks.indexWhere((t) => t.id == parentId);
    if (parentIndex == -1) return;

    final parent = _tasks[parentIndex];
    final updatedSubtaskIds = List<String>.from(parent.subtaskIds ?? [])..add(subtaskId);

    final updatedParent = parent.copyWith(subtaskIds: updatedSubtaskIds);
    _tasks[parentIndex] = updatedParent;

    await _db.update('tasks', updatedParent.toMap(), where: 'id = ?', whereArgs: [parentId]);
  }

  /// Удаляет ID подзадачи из родительской задачи
  Future<void> _removeSubtaskFromParent(String parentId, String subtaskId) async {
    final parentIndex = _tasks.indexWhere((t) => t.id == parentId);
    if (parentIndex == -1) return;

    final parent = _tasks[parentIndex];
    final updatedSubtaskIds = List<String>.from(parent.subtaskIds ?? [])..remove(subtaskId);

    final updatedParent = parent.copyWith(subtaskIds: updatedSubtaskIds.isEmpty ? null : updatedSubtaskIds);
    _tasks[parentIndex] = updatedParent;

    await _db.update('tasks', updatedParent.toMap(), where: 'id = ?', whereArgs: [parentId]);
  }

  Future<void> updateTask(LifeTask task) async {
    await _db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) _tasks[index] = task;
    _sortTasks();
    notifyListeners();
  }

  // ==================== ЗАДАЧИ (ПРОСТОЕ УДАЛЕНИЕ) ====================

  Future<void> deleteTask(String id) async {
    // 🔥 ПОЛУЧАЕМ ВСЕ ID ДЛЯ УДАЛЕНИЯ
    final idsToDelete = <String>[];
    idsToDelete.add(id);
    await _collectAllSubtaskIds(id, idsToDelete);

    // 🔥 УДАЛЯЕМ ВСЕ ЗАДАЧИ ИЗ БД
    for (final taskId in idsToDelete) {
      await _db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
    }

    // 🔥 УДАЛЯЕМ ИЗ СПИСКА
    _tasks.removeWhere((t) => idsToDelete.contains(t.id));

    // 🔥 ОБНОВЛЯЕМ РОДИТЕЛЕЙ
    for (final task in _tasks) {
      if (task.subtaskIds != null) {
        final updatedIds = task.subtaskIds!.where((sid) => !idsToDelete.contains(sid)).toList();
        if (updatedIds.length != task.subtaskIds!.length) {
          final updatedTask = task.copyWith(
            subtaskIds: updatedIds.isEmpty ? null : updatedIds,
          );
          final index = _tasks.indexWhere((t) => t.id == task.id);
          _tasks[index] = updatedTask;
          await _db.update('tasks', updatedTask.toMap(), where: 'id = ?', whereArgs: [task.id]);
        }
      }
    }

    notifyListeners();
  }

  Future<void> _collectAllSubtaskIds(String parentId, List<String> result) async {
    // 🔥 НАХОДИМ ВСЕ ПРЯМЫЕ ПОДЗАДАЧИ
    final subtasks = _tasks.where((t) => t.parentId == parentId).toList();

    for (final subtask in subtasks) {
      result.add(subtask.id);
      await _collectAllSubtaskIds(subtask.id, result);
    }
  }

  void _sortTasks() {
    _tasks.sort((a, b) {
      // Сначала корневые задачи
      if (a.parentId == null && b.parentId != null) return -1;
      if (a.parentId != null && b.parentId == null) return 1;

      // Потом по статусу
      final statusOrder = {'formulated': 0, 'in_progress': 1, 'postponed': 2, 'done': 3};
      final statusCompare = (statusOrder[a.status] ?? 0).compareTo(statusOrder[b.status] ?? 0);
      if (statusCompare != 0) return statusCompare;

      // Потом по приоритету
      final priorityOrder = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
      final priorityCompare = (priorityOrder[a.priority] ?? 2).compareTo(priorityOrder[b.priority] ?? 2);
      if (priorityCompare != 0) return priorityCompare;

      // Потом по дедлайну
      if (a.deadline != null && b.deadline != null) {
        return a.deadline!.compareTo(b.deadline!);
      }
      if (a.deadline != null) return -1;
      if (b.deadline != null) return 1;

      return a.createdAt.compareTo(b.createdAt);
    });
  }

  List<LifeTask> getTasksForProject(String projectId) {
    return _tasks.where((t) => t.projectId == projectId).toList();
  }

  List<LifeTask> getTodayTasks() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    return _tasks.where((t) {
      if (t.deadline == null) return false;
      return t.deadline!.isAfter(start) && t.deadline!.isBefore(end);
    }).toList();
  }

  /// Получить все подзадачи для задачи (рекурсивно)
  List<LifeTask> getSubtasks(String taskId) {
    return _tasks.where((t) => t.parentId == taskId).toList();
  }

  /// Получить все подзадачи рекурсивно (включая под-подзадачи)
  List<LifeTask> getSubtasksRecursive(String taskId) {
    final result = <LifeTask>[];
    final directSubtasks = _tasks.where((t) => t.parentId == taskId).toList();

    for (final subtask in directSubtasks) {
      result.add(subtask);
      result.addAll(getSubtasksRecursive(subtask.id));
    }

    return result;
  }

  /// Получить дерево задач (иерархия)
  List<LifeTask> getTaskTree() {
    return _tasks.where((t) => t.parentId == null).toList();
  }

  /// Получить глубину вложенности задачи
  int getTaskDepth(String taskId) {
    int depth = 0;
    String? currentId = taskId;

    while (true) {
      final task = _tasks.firstWhere((t) => t.id == currentId, orElse: () => throw Exception('Task not found'));
      if (task.parentId == null) break;
      depth++;
      currentId = task.parentId;
    }

    return depth;
  }

  /// Проверить, является ли задача родительской (имеет подзадачи)
  bool hasSubtasks(String taskId) {
    return _tasks.any((t) => t.parentId == taskId);
  }

  /// Получить прогресс выполнения подзадач
  Map<String, dynamic> getSubtasksProgress(String taskId) {
    final subtasks = getSubtasks(taskId);
    final total = subtasks.length;
    if (total == 0) return {'total': 0, 'completed': 0, 'progress': 0.0};

    final completed = subtasks.where((t) => t.status == 'done').length;
    return {
      'total': total,
      'completed': completed,
      'progress': completed / total,
    };
  }

  // ==================== ПРИВЫЧКИ (ОБНОВЛЁННАЯ ЛОГИКА) ====================

  Future<LifeHabit> addHabit({
    required String title,
    String description = '',
    String icon = '⭐',
    String color = '#FF6B00',
    String frequency = 'daily',
    List<String> daysOfWeek = const [],
    int targetCount = 1,
  }) async {
    final habit = LifeHabit(
      id: _uuid.v4(),
      title: title,
      description: description,
      icon: icon,
      color: color,
      frequency: frequency,
      daysOfWeek: daysOfWeek,
      targetCount: targetCount,
      completionsToday: 0,
      completedDates: [],
    );
    await _db.insert('habits', habit.toMap());
    _habits.add(habit);
    _sortHabits();
    notifyListeners();
    return habit;
  }

  Future<void> updateHabit(LifeHabit habit) async {
    await _db.update('habits', habit.toMap(), where: 'id = ?', whereArgs: [habit.id]);
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index != -1) _habits[index] = habit;
    _sortHabits();
    notifyListeners();
  }

  // 🔥 ОБНОВЛЁН: КАСКАДНОЕ УДАЛЕНИЕ НАПОМИНАНИЙ
  Future<void> deleteHabit(String id) async {
    // Удаляем все напоминания для этой привычки
    await _db.deleteRemindersForHabit(id);
    _reminders.removeWhere((r) => r.habitId == id);

    // Удаляем саму привычку
    await _db.delete('habits', where: 'id = ?', whereArgs: [id]);
    _habits.removeWhere((h) => h.id == id);

    notifyListeners();
    debugPrint('🗑️ Привычка и её напоминания удалены');
  }

  // 🔥 ПОЛНОСТЬЮ ПЕРЕПИСАННЫЙ МЕТОД ВЫПОЛНЕНИЯ ПРИВЫЧКИ
  Future<bool> completeHabit(String id) async {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index == -1) return false;

    final habit = _habits[index];
    final now = DateTime.now();
    final today = _todayString();
    final yesterday = _dateString(now.subtract(const Duration(days: 1)));

    if (!habit.canCompleteToday()) {
      debugPrint('⚠️ Привычка "${habit.title}" уже выполнена сегодня (${habit.completionsToday}/${habit.targetCount})');
      return false;
    }

    int newStreak = habit.currentStreak;
    int newCompletionsToday = habit.completionsToday + 1;

    if (habit.completionsToday == 0) {
      final wasCompletedYesterday = habit.lastCompleted != null &&
          _dateString(habit.lastCompleted!) == yesterday;

      if (wasCompletedYesterday) {
        newStreak = habit.currentStreak + 1;
      } else if (habit.lastCompleted != null && _dateString(habit.lastCompleted!) == today) {
        newStreak = habit.currentStreak;
      } else {
        newStreak = 1;
      }
    }

    final updatedDates = List<String>.from(habit.completedDates);
    final todayStr = now.toIso8601String();
    if (!updatedDates.contains(todayStr)) {
      updatedDates.add(todayStr);
    }

    final updated = habit.copyWith(
      currentStreak: newStreak,
      longestStreak: newStreak > habit.longestStreak ? newStreak : habit.longestStreak,
      lastCompleted: now,
      completionsToday: newCompletionsToday,
      completedDates: updatedDates,
    );

    await _db.update('habits', updated.toMap(), where: 'id = ?', whereArgs: [id]);
    _habits[index] = updated;
    _sortHabits();
    notifyListeners();

    debugPrint('✅ Привычка "${habit.title}": стрик $newStreak, сегодня $newCompletionsToday/${habit.targetCount}');
    return true;
  }

  Future<void> uncompleteHabit(String id) async {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index == -1) return;

    final habit = _habits[index];

    if (habit.completionsToday <= 0) return;

    int newStreak = habit.currentStreak;
    int newCompletionsToday = habit.completionsToday - 1;

    if (habit.completionsToday == 1) {
      if (habit.currentStreak > 0) {
        newStreak = habit.currentStreak - 1;
      }
    }

    final updatedDates = List<String>.from(habit.completedDates);
    if (updatedDates.isNotEmpty) {
      updatedDates.removeLast();
    }

    final updated = habit.copyWith(
      currentStreak: newStreak,
      lastCompleted: newCompletionsToday == 0 ? null : habit.lastCompleted,
      completionsToday: newCompletionsToday,
      completedDates: updatedDates,
    );

    await _db.update('habits', updated.toMap(), where: 'id = ?', whereArgs: [id]);
    _habits[index] = updated;
    _sortHabits();
    notifyListeners();

    debugPrint('↩️ Отмена: "${habit.title}" — стрик $newStreak');
  }

  Future<void> skipHabit(String id) async {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index == -1) return;

    final habit = _habits[index];

    final updated = habit.copyWith(
      currentStreak: 0,
      completionsToday: 0,
      lastCompleted: null,
    );

    await _db.update('habits', updated.toMap(), where: 'id = ?', whereArgs: [id]);
    _habits[index] = updated;
    _sortHabits();
    notifyListeners();

    debugPrint('⏭️ Пропуск: "${habit.title}" — стрик сброшен');
  }

  void _sortHabits() {
    _habits.sort((a, b) {
      final aCompleted = a.isCompletedToday();
      final bCompleted = b.isCompletedToday();

      if (aCompleted && !bCompleted) return 1;
      if (!aCompleted && bCompleted) return -1;

      if (aCompleted && bCompleted) {
        return b.currentStreak.compareTo(a.currentStreak);
      }

      return b.currentStreak.compareTo(a.currentStreak);
    });
  }

  Future<LifeHabit> convertInboxToHabit(String inboxItemId, {String icon = '⭐', String frequency = 'daily'}) async {
    final item = _inbox.firstWhere((i) => i.id == inboxItemId);

    final habit = await addHabit(
      title: item.text,
      icon: icon,
      frequency: frequency,
    );

    await processInboxItem(inboxItemId, 'habit');

    return habit;
  }

  // ==================== 🔥 НАПОМИНАНИЯ ДЛЯ ПРИВЫЧЕК ====================

  /// Получить напоминания для конкретной привычки
  List<HabitReminder> getRemindersForHabit(String habitId) {
    return _reminders.where((r) => r.habitId == habitId).toList();
  }

  /// Есть ли активное напоминание у привычки
  bool hasActiveReminder(String habitId) {
    return _reminders.any((r) => r.habitId == habitId && r.isActive);
  }

  /// Добавить напоминание для привычки
  Future<HabitReminder> addHabitReminder({
    required String habitId,
    required TimeOfDay time,
    List<String>? daysOfWeek,
  }) async {
    final reminder = HabitReminder(
      id: _uuid.v4(),
      habitId: habitId,
      time: time,
      daysOfWeek: daysOfWeek,
      isActive: true,
    );

    await _db.addReminder(reminder.toMap());
    _reminders.add(reminder);

    // 🔥 ПЛАНИРУЕМ УВЕДОМЛЕНИЕ
    final habit = _habits.firstWhere((h) => h.id == habitId);
    final notificationService = NotificationService();
    await notificationService.scheduleHabitReminder(
      habitId: habitId,
      habitTitle: habit.title,
      reminderTime: time,
    );

    notifyListeners();
    debugPrint('🔔 Напоминание для "${habit.title}" установлено на ${reminder.formattedTime}');
    return reminder;
  }

  /// Обновить напоминание
  Future<void> updateHabitReminder(HabitReminder reminder) async {
    await _db.updateReminder(reminder.id, reminder.toMap());
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) _reminders[index] = reminder;

    // 🔥 ПЕРЕПЛАНИРУЕМ УВЕДОМЛЕНИЕ
    final habit = _habits.firstWhere((h) => h.id == reminder.habitId);
    final notificationService = NotificationService();

    // Отменяем старое
    final oldId = (reminder.habitId + habit.title).hashCode.abs();
    await notificationService.cancelNotification(oldId);

    // Планируем новое
    if (reminder.isActive && reminder.isActiveToday()) {
      await notificationService.scheduleHabitReminder(
        habitId: reminder.habitId,
        habitTitle: habit.title,
        reminderTime: reminder.time,
      );
    }

    notifyListeners();
    debugPrint('🔄 Напоминание обновлено');
  }

  /// Удалить напоминание
  Future<void> deleteHabitReminder(String reminderId) async {
    final reminder = _reminders.firstWhere((r) => r.id == reminderId);

    // Отменяем уведомление
    final habit = _habits.firstWhere((h) => h.id == reminder.habitId);
    final notificationService = NotificationService();
    final notifId = (reminder.habitId + habit.title).hashCode.abs();
    await notificationService.cancelNotification(notifId);

    await _db.deleteReminder(reminderId);
    _reminders.removeWhere((r) => r.id == reminderId);

    notifyListeners();
    debugPrint('🗑️ Напоминание удалено');
  }

  /// Включить/выключить напоминание
  Future<void> toggleReminder(String reminderId) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index == -1) return;

    final reminder = _reminders[index];
    final updated = reminder.copyWith(isActive: !reminder.isActive);

    await _db.updateReminder(reminderId, updated.toMap());
    _reminders[index] = updated;

    // 🔥 УПРАВЛЯЕМ УВЕДОМЛЕНИЕМ
    final habit = _habits.firstWhere((h) => h.id == reminder.habitId);
    final notificationService = NotificationService();
    final notifId = (reminder.habitId + habit.title).hashCode.abs();

    if (updated.isActive && updated.isActiveToday()) {
      await notificationService.scheduleHabitReminder(
        habitId: reminder.habitId,
        habitTitle: habit.title,
        reminderTime: reminder.time,
      );
      debugPrint('🔔 Напоминание включено');
    } else {
      await notificationService.cancelNotification(notifId);
      debugPrint('🔕 Напоминание выключено');
    }

    notifyListeners();
  }

  // ==================== ИДЕИ ====================

  // features/life_navigator/providers/life_provider.dart
// 🔥 Замените метод addIdea и updateIdea на эти:

  Future<LifeIdea> addIdea({
    required String title,
    String description = '',
    List<String> tags = const [],
    String category = 'general',
    int rating = 0,
    String color = '#FF6B00',
    String status = 'idea',
    int priority = 0,
    int impact = 5,
    int confidence = 5,
    int ease = 5,
    DateTime? deadline,
    List<String> images = const [],
  }) async {
    final idea = LifeIdea(
      id: _uuid.v4(),
      title: title,
      description: description,
      tags: tags,
      category: category,
      rating: rating,
      color: color,
      status: status,
      priority: priority,
      impact: impact,
      confidence: confidence,
      ease: ease,
      deadline: deadline,
      images: images,
    );
    await _db.insert('ideas', idea.toMap());
    _ideas.insert(0, idea);
    notifyListeners();
    return idea;
  }

  Future<void> updateIdea(LifeIdea idea) async {
    await _db.update('ideas', idea.toMap(), where: 'id = ?', whereArgs: [idea.id]);
    final index = _ideas.indexWhere((i) => i.id == idea.id);
    if (index != -1) _ideas[index] = idea;
    notifyListeners();
  }

  Future<void> deleteIdea(String id) async {
    await _db.delete('ideas', where: 'id = ?', whereArgs: [id]);
    _ideas.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  Future<void> implementIdea(String id) async {
    final idea = _ideas.firstWhere((i) => i.id == id);
    final updated = LifeIdea(
      id: idea.id,
      title: idea.title,
      description: idea.description,
      tags: idea.tags,
      category: idea.category,
      rating: idea.rating,
      isFavorite: idea.isFavorite,
      isImplemented: true,
      implementedAt: DateTime.now(),
      createdAt: idea.createdAt,
      updatedAt: DateTime.now(),
    );
    await updateIdea(updated);
  }

  // ==================== ВХОДЯЩИЕ ====================

  Future<InboxItem> addInboxItem(String text, {String type = 'idea'}) async {
    final item = InboxItem(id: _uuid.v4(), text: text, type: type);
    await _db.insert('inbox', item.toMap());
    _inbox.insert(0, item);
    notifyListeners();
    return item;
  }

  Future<void> processInboxItem(String id, String targetType) async {
    final item = _inbox.firstWhere((i) => i.id == id);
    switch (targetType) {
      case 'task':
        await addTask(title: item.text);
        break;
      case 'note':
        await addNote(item.text, '');
        break;
      case 'idea':
        await addIdea(title: item.text);
        break;
      case 'habit':
        break;
    }
    final updated = InboxItem(
      id: item.id,
      text: item.text,
      type: item.type,
      isProcessed: true,
      processedAt: DateTime.now(),
      createdAt: item.createdAt,
    );
    await _db.update('inbox', updated.toMap(), where: 'id = ?', whereArgs: [id]);
    final index = _inbox.indexWhere((i) => i.id == id);
    if (index != -1) _inbox[index] = updated;
    notifyListeners();
  }

  Future<void> deleteInboxItem(String id) async {
    await _db.delete('inbox', where: 'id = ?', whereArgs: [id]);
    _inbox.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  // ==================== ТРЕКЕР ВРЕМЕНИ ====================

  Future<TimeLog> startTimeLog(String taskId) async {
    final log = TimeLog(
      id: _uuid.v4(),
      taskId: taskId,
      startTime: DateTime.now(),
    );
    await _db.insert('time_logs', log.toMap());
    _timeLogs.insert(0, log);
    notifyListeners();
    return log;
  }

  Future<void> stopTimeLog(String id) async {
    final log = _timeLogs.firstWhere((l) => l.id == id);
    final endTime = DateTime.now();
    final duration = endTime.difference(log.startTime).inMinutes;
    final updated = TimeLog(
      id: log.id,
      taskId: log.taskId,
      startTime: log.startTime,
      endTime: endTime,
      durationMinutes: duration,
    );
    await _db.update('time_logs', updated.toMap(), where: 'id = ?', whereArgs: [id]);
    final index = _timeLogs.indexWhere((l) => l.id == id);
    if (index != -1) _timeLogs[index] = updated;
    final task = _tasks.firstWhere((t) => t.id == log.taskId);
    final updatedTask = LifeTask(
      id: task.id,
      title: task.title,
      description: task.description,
      projectId: task.projectId,
      goalId: task.goalId,
      tags: task.tags,
      priority: task.priority,
      status: task.status,
      deadline: task.deadline,
      estimatedMinutes: task.estimatedMinutes,
      actualMinutes: task.actualMinutes + duration,
      isRecurring: task.isRecurring,
      recurrenceRule: task.recurrenceRule,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
    );
    await updateTask(updatedTask);
    notifyListeners();
  }

  // ==================== СТАТИСТИКА (ОБНОВЛЁНА) ====================

  Map<String, dynamic> getStats() {
    final totalTasks = _tasks.length;
    final completedTasks = _tasks.where((t) => t.status == 'done').length;
    final totalProjects = _projects.length;
    final completedProjects = _projects.where((p) => p.status == 'completed').length;
    final totalHabits = _habits.length;
    final completedHabitsToday = _habits.where((h) => h.isCompletedToday()).length;
    final activeReminders = _reminders.where((r) => r.isActive).length; // 🔥
    final totalIdeas = _ideas.length;
    final implementedIdeas = _ideas.where((i) => i.isImplemented).length;
    final totalEvents = _events.length;
    final todayTasks = getTodayTasks();

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'completionRate': totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0,
      'totalProjects': totalProjects,
      'completedProjects': completedProjects,
      'totalHabits': totalHabits,
      'completedHabitsToday': completedHabitsToday, // 🔥
      'activeReminders': activeReminders, // 🔥
      'totalIdeas': totalIdeas,
      'implementedIdeas': implementedIdeas,
      'totalEvents': totalEvents,
      'todayTasks': todayTasks.length,
      'inboxCount': _inbox.where((i) => !i.isProcessed).length,
    };
  }

  // ==================== БЭКАП ====================

  Future<String> exportBackup() async {
    return await _db.exportBackup();
  }

  Future<void> importBackup(String path) async {
    await _db.importBackup(path);
    await init();
  }

  // ==================== ОЧИСТКА (ОБНОВЛЕНА) ====================

  Future<void> clearAllData() async {
    await _db.deleteAll('widgets');
    await _db.deleteAll('notes');
    await _db.deleteAll('calendar_events');
    await _db.deleteAll('projects');
    await _db.deleteAll('tasks');
    await _db.deleteAll('habits');
    await _db.deleteAll('habit_reminders');
    await _db.deleteAll('ideas');
    await _db.deleteAll('inbox');
    await _db.deleteAll('time_logs');
    _widgets.clear();
    _notes.clear();
    _events.clear();
    _projects.clear();
    _tasks.clear();
    _habits.clear();
    _reminders.clear();
    _ideas.clear();
    _inbox.clear();
    _timeLogs.clear();
    _createDefaultWidgets();
    notifyListeners();
  }
}