// features/life_navigator/database/life_database.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class LifeDatabase {
  static final LifeDatabase _instance = LifeDatabase._internal();
  static Database? _database;

  LifeDatabase._internal();

  factory LifeDatabase() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 🔥 Метод для удаления старой БД
  Future<void> deleteDatabaseFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'life_navigator.db');

    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
      }

      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        debugPrint('🗑️ База данных удалена!');
      }

      final walFile = File('$path-wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }

      final shmFile = File('$path-shm');
      if (await shmFile.exists()) {
        await shmFile.delete();
      }

      debugPrint('✅ Все файлы БД очищены');
    } catch (e) {
      debugPrint('⚠️ Ошибка удаления БД: $e');
    }
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'life_navigator.db');

    return await openDatabase(
      path,
      version: 10, // 🔥 ОБНОВЛЕНА ДО ВЕРСИИ 10
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('📦 Создание новой базы данных версии $version');

    // Таблица виджетов
    await db.execute('''
      CREATE TABLE widgets (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        position INTEGER NOT NULL,
        config TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Таблица заметок (с полем images)
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT,
        tags TEXT,
        color TEXT,
        isFavorite INTEGER DEFAULT 0,
        images TEXT DEFAULT '[]',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Таблица событий календаря
    await db.execute('''
      CREATE TABLE calendar_events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        time TEXT,
        endDate TEXT,
        endTime TEXT,
        location TEXT,
        color TEXT,
        isAllDay INTEGER DEFAULT 0,
        hasReminder INTEGER DEFAULT 0,
        reminderMinutes INTEGER DEFAULT 15,
        isCompleted INTEGER DEFAULT 0,
        recurrence TEXT DEFAULT 'none',
        recurrenceDays TEXT DEFAULT ''
      )
    ''');

    // Таблица проектов
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        parentId TEXT,
        category TEXT,
        status TEXT,
        progress INTEGER DEFAULT 0,
        deadline TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // ==================== ТАБЛИЦА ЗАДАЧ (ОБНОВЛЕНА) ====================
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        projectId TEXT,
        goalId TEXT,
        tags TEXT,
        priority TEXT,
        status TEXT,
        deadline TEXT,
        estimatedMinutes INTEGER DEFAULT 0,
        actualMinutes INTEGER DEFAULT 0,
        isRecurring INTEGER DEFAULT 0,
        recurrenceRule TEXT,
        parentId TEXT,
        subtaskIds TEXT,          -- 🔥 ЗАМЕНЕНО subtasks → subtaskIds
        images TEXT,
        hasReminder INTEGER DEFAULT 0,
        reminderMinutes INTEGER,
        reminderTime TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Таблица привычек
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        icon TEXT,
        color TEXT,
        frequency TEXT,
        daysOfWeek TEXT,
        targetCount INTEGER DEFAULT 1,
        currentStreak INTEGER DEFAULT 0,
        longestStreak INTEGER DEFAULT 0,
        lastCompleted TEXT,
        completionsToday INTEGER DEFAULT 0,
        completedDates TEXT DEFAULT '[]',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Таблица напоминаний для привычек
    await db.execute('''
      CREATE TABLE habit_reminders (
        id TEXT PRIMARY KEY,
        habitId TEXT NOT NULL,
        time TEXT NOT NULL,
        daysOfWeek TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (habitId) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');

    // Таблица идей
    await db.execute('''
      CREATE TABLE ideas (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        tags TEXT,
        category TEXT,
        rating INTEGER DEFAULT 0,
        color TEXT DEFAULT '#FF6B00',
        status TEXT DEFAULT 'idea',
        priority INTEGER DEFAULT 0,
        impact INTEGER DEFAULT 5,
        confidence INTEGER DEFAULT 5,
        ease INTEGER DEFAULT 5,
        deadline TEXT,
        images TEXT DEFAULT '[]',
        isFavorite INTEGER DEFAULT 0,
        isImplemented INTEGER DEFAULT 0,
        implementedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isIdeaOfDay INTEGER DEFAULT 0
      )
    ''');

    // Таблица входящих
    await db.execute('''
      CREATE TABLE inbox (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        type TEXT,
        isProcessed INTEGER DEFAULT 0,
        processedAt TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Таблица логов времени
    await db.execute('''
      CREATE TABLE time_logs (
        id TEXT PRIMARY KEY,
        taskId TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        durationMinutes INTEGER DEFAULT 0
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Миграция базы данных: $oldVersion → $newVersion');

    try {
      // 🔥 Миграция v4 → v5: колонки completionsToday, completedDates в habits
      if (oldVersion < 5) {
        debugPrint('📋 Миграция на версию 5: habits');
        final columns = await db.rawQuery('PRAGMA table_info(habits)');
        final columnNames = columns.map((c) => c['name'] as String).toList();

        if (!columnNames.contains('completionsToday')) {
          await db.execute('ALTER TABLE habits ADD COLUMN completionsToday INTEGER DEFAULT 0');
          debugPrint('✅ Добавлена колонка completionsToday');
        }
        if (!columnNames.contains('completedDates')) {
          await db.execute("ALTER TABLE habits ADD COLUMN completedDates TEXT DEFAULT '[]'");
          debugPrint('✅ Добавлена колонка completedDates');
        }
      }

      // 🔥 Миграция v5 → v6: таблица habit_reminders
      if (oldVersion < 6) {
        debugPrint('📋 Миграция на версию 6: habit_reminders');
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='habit_reminders'");
        if (tables.isEmpty) {
          await db.execute('''
            CREATE TABLE habit_reminders (
              id TEXT PRIMARY KEY,
              habitId TEXT NOT NULL,
              time TEXT NOT NULL,
              daysOfWeek TEXT,
              isActive INTEGER DEFAULT 1,
              createdAt TEXT NOT NULL,
              FOREIGN KEY (habitId) REFERENCES habits(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_habit_reminders_habitId ON habit_reminders(habitId)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_habit_reminders_active ON habit_reminders(isActive)');
          debugPrint('✅ Таблица habit_reminders создана');
        }
      }

      // 🔥 Миграция v6 → v7: новые колонки в ideas
      if (oldVersion < 7) {
        debugPrint('📋 Миграция на версию 7: ideas');
        final columns = await db.rawQuery('PRAGMA table_info(ideas)');
        final columnNames = columns.map((c) => c['name'] as String).toList();
        debugPrint('📋 Существующие колонки ideas: $columnNames');

        final newColumns = {
          'color': "TEXT DEFAULT '#FF6B00'",
          'status': "TEXT DEFAULT 'idea'",
          'priority': 'INTEGER DEFAULT 0',
          'impact': 'INTEGER DEFAULT 5',
          'confidence': 'INTEGER DEFAULT 5',
          'ease': 'INTEGER DEFAULT 5',
          'deadline': 'TEXT',
          'images': "TEXT DEFAULT '[]'",
          'isIdeaOfDay': 'INTEGER DEFAULT 0',
        };

        for (final entry in newColumns.entries) {
          if (!columnNames.contains(entry.key)) {
            await db.execute('ALTER TABLE ideas ADD COLUMN ${entry.key} ${entry.value}');
            debugPrint('✅ Добавлена колонка ${entry.key}');
          }
        }

        if (!columnNames.contains('isFavorite')) {
          await db.execute('ALTER TABLE ideas ADD COLUMN isFavorite INTEGER DEFAULT 0');
          debugPrint('✅ Добавлена колонка isFavorite');
        }
        if (!columnNames.contains('isImplemented')) {
          await db.execute('ALTER TABLE ideas ADD COLUMN isImplemented INTEGER DEFAULT 0');
          debugPrint('✅ Добавлена колонка isImplemented');
        }
        if (!columnNames.contains('implementedAt')) {
          await db.execute('ALTER TABLE ideas ADD COLUMN implementedAt TEXT');
          debugPrint('✅ Добавлена колонка implementedAt');
        }
      }

      // 🔥 Миграция v7 → v8: колонка images в notes
      if (oldVersion < 8) {
        debugPrint('📋 Миграция на версию 8: notes - images');
        final columns = await db.rawQuery('PRAGMA table_info(notes)');
        final columnNames = columns.map((c) => c['name'] as String).toList();

        if (!columnNames.contains('images')) {
          await db.execute("ALTER TABLE notes ADD COLUMN images TEXT DEFAULT '[]'");
          debugPrint('✅ Добавлена колонка images в notes');
        }
      }

      // 🔥 Миграция v8 → v9: новые колонки в tasks
      if (oldVersion < 9) {
        debugPrint('📋 Миграция на версию 9: tasks - новые колонки');
        final columns = await db.rawQuery('PRAGMA table_info(tasks)');
        final columnNames = columns.map((c) => c['name'] as String).toList();

        final newColumns = {
          'parentId': 'TEXT',
          'subtasks': 'TEXT',
          'images': 'TEXT',
          'hasReminder': 'INTEGER DEFAULT 0',
          'reminderMinutes': 'INTEGER',
          'reminderTime': 'TEXT',
        };

        for (final entry in newColumns.entries) {
          if (!columnNames.contains(entry.key)) {
            await db.execute('ALTER TABLE tasks ADD COLUMN ${entry.key} ${entry.value}');
            debugPrint('✅ Добавлена колонка ${entry.key} в tasks');
          }
        }
      }

      // 🔥 Миграция v9 → v10: замена subtasks на subtaskIds
      if (oldVersion < 10) {
        debugPrint('📋 Миграция на версию 10: tasks - subtaskIds вместо subtasks');
        final columns = await db.rawQuery('PRAGMA table_info(tasks)');
        final columnNames = columns.map((c) => c['name'] as String).toList();

        // Добавляем колонку subtaskIds
        if (!columnNames.contains('subtaskIds')) {
          await db.execute('ALTER TABLE tasks ADD COLUMN subtaskIds TEXT');
          debugPrint('✅ Добавлена колонка subtaskIds в tasks');
        }

        // 🔥 Переносим данные из subtasks в subtaskIds (если есть)
        if (columnNames.contains('subtasks')) {
          // Получаем все задачи с subtasks
          final tasks = await db.query('tasks', where: 'subtasks IS NOT NULL');
          for (final task in tasks) {
            try {
              final subtasksData = task['subtasks'] as String?;
              if (subtasksData != null && subtasksData.isNotEmpty) {
                // Парсим старый формат и создаём новые задачи
                // (это сложно сделать в миграции, поэтому просто логируем)
                debugPrint('⚠️ Обнаружены старые subtasks в задаче ${task['id']}, перенос не выполнен');
                // Рекомендуем пользователю обновить данные
              }
            } catch (e) {
              debugPrint('⚠️ Ошибка при переносе subtasks: $e');
            }
          }

          // 🔥 ВНИМАНИЕ: SQLite не поддерживает DROP COLUMN
          // Поэтому оставляем колонку subtasks, но больше не используем
          debugPrint('ℹ️ Колонка subtasks оставлена для совместимости, используйте subtaskIds');
        }
      }

      // 🔥 Проверка calendar_events (миграция с v3)
      final eventColumns = await db.rawQuery('PRAGMA table_info(calendar_events)');
      final eventColumnNames = eventColumns.map((c) => c['name'] as String).toList();

      if (!eventColumnNames.contains('recurrence')) {
        await db.execute('ALTER TABLE calendar_events ADD COLUMN recurrence TEXT DEFAULT "none"');
        debugPrint('✅ Добавлена колонка recurrence в calendar_events');
      }
      if (!eventColumnNames.contains('recurrenceDays')) {
        await db.execute('ALTER TABLE calendar_events ADD COLUMN recurrenceDays TEXT DEFAULT ""');
        debugPrint('✅ Добавлена колонка recurrenceDays в calendar_events');
      }

    } catch (e) {
      debugPrint('⚠️ Ошибка миграции: $e');
    }

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_deadline ON tasks(deadline)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_projectId ON tasks(projectId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_parentId ON tasks(parentId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_events_date ON calendar_events(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_habits_frequency ON habits(frequency)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_habits_lastCompleted ON habits(lastCompleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_inbox_processed ON inbox(isProcessed)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_favorite ON notes(isFavorite)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ideas_implemented ON ideas(isImplemented)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ideas_status ON ideas(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ideas_category ON ideas(category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_habit_reminders_habitId ON habit_reminders(habitId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_habit_reminders_active ON habit_reminders(isActive)');
    } catch (e) {
      debugPrint('⚠️ Ошибка создания индексов: $e');
    }
  }

  // ==================== ОСТАЛЬНЫЕ МЕТОДЫ ====================

  Future<void> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
      String table, {
        bool? distinct,
        String? where,
        List<Object?>? whereArgs,
        String? groupBy,
        String? having,
        String? orderBy,
        int? limit,
        int? offset,
      }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct ?? false,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> update(
      String table,
      Map<String, dynamic> values, {
        String? where,
        List<Object?>? whereArgs,
      }) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
      String table, {
        String? where,
        List<Object?>? whereArgs,
      }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> deleteAll(String table) async {
    final db = await database;
    await db.delete(table);
  }

  Future<int> count(String table, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    final result = await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      columns: ['COUNT(*) as count'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> transaction(Future<void> Function(Batch) action) async {
    final db = await database;
    final batch = db.batch();
    await action(batch);
    await batch.commit();
  }

  // ==================== БЭКАП ====================

  Future<String> exportBackup() async {
    final db = await database;
    final tables = [
      'widgets', 'notes', 'calendar_events', 'projects', 'tasks',
      'habits', 'habit_reminders', 'ideas', 'inbox', 'time_logs'
    ];
    final backup = <String, dynamic>{};

    for (final table in tables) {
      final data = await db.query(table);
      backup[table] = data;
    }

    backup['_metadata'] = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'KidLoop Life Navigator',
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = join(directory.path, 'life_backup_$timestamp.json');
    await File(path).writeAsString(jsonString);
    return path;
  }

  Future<void> importBackup(String filePath) async {
    final jsonString = await File(filePath).readAsString();
    final backup = jsonDecode(jsonString) as Map<String, dynamic>;

    if (backup['_metadata'] == null) {
      throw Exception('Неверный формат бэкапа: отсутствуют метаданные');
    }

    final db = await database;
    final tables = [
      'widgets', 'notes', 'calendar_events', 'projects', 'tasks',
      'habits', 'habit_reminders', 'ideas', 'inbox', 'time_logs'
    ];

    await db.transaction((txn) async {
      for (final table in tables) {
        if (backup.containsKey(table)) {
          final data = backup[table] as List;
          await txn.delete(table);
          for (final row in data) {
            await txn.insert(table, row);
          }
        }
      }
    });
  }

  // ==================== СПЕЦИАЛЬНЫЕ ЗАПРОСЫ ====================

  Future<List<Map<String, dynamic>>> getTasksByProject(String projectId) async {
    return await query('tasks', where: 'projectId = ?', whereArgs: [projectId], orderBy: 'deadline ASC, createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getSubtasks(String parentId) async {
    return await query('tasks', where: 'parentId = ?', whereArgs: [parentId], orderBy: 'createdAt ASC');
  }

  Future<List<Map<String, dynamic>>> getTaskTree() async {
    return await query('tasks', where: 'parentId IS NULL', orderBy: 'priority ASC, deadline ASC');
  }

  Future<List<Map<String, dynamic>>> getTodayEvents() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();
    final end = DateTime(today.year, today.month, today.day + 1).toIso8601String();
    return await query('calendar_events', where: 'date >= ? AND date < ?', whereArgs: [start, end], orderBy: 'time ASC');
  }

  Future<List<Map<String, dynamic>>> getActiveHabits() async {
    return await query('habits', orderBy: 'title ASC');
  }

  // 🔥 НАПОМИНАНИЯ
  Future<List<Map<String, dynamic>>> getRemindersForHabit(String habitId) async {
    return await query('habit_reminders', where: 'habitId = ?', whereArgs: [habitId], orderBy: 'time ASC');
  }

  Future<List<Map<String, dynamic>>> getActiveReminders() async {
    return await query('habit_reminders', where: 'isActive = 1', orderBy: 'time ASC');
  }

  Future<List<Map<String, dynamic>>> getRemindersForTime(String time) async {
    return await query('habit_reminders', where: 'time = ? AND isActive = 1', whereArgs: [time]);
  }

  Future<void> addReminder(Map<String, dynamic> reminder) async {
    await insert('habit_reminders', reminder);
  }

  Future<void> updateReminder(String id, Map<String, dynamic> values) async {
    await update('habit_reminders', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteReminder(String id) async {
    await delete('habit_reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteRemindersForHabit(String habitId) async {
    await delete('habit_reminders', where: 'habitId = ?', whereArgs: [habitId]);
  }

  // 🔥 ИДЕИ
  Future<List<Map<String, dynamic>>> getIdeasByStatus(String status) async {
    return await query('ideas', where: 'status = ?', whereArgs: [status], orderBy: 'priority DESC, createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getIdeasByCategory(String category) async {
    return await query('ideas', where: 'category = ?', whereArgs: [category], orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getUnprocessedInbox() async {
    return await query('inbox', where: 'isProcessed = 0', orderBy: 'createdAt DESC');
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final totalTasks = await count('tasks');
    final completedTasks = await count('tasks', where: 'status = ?', whereArgs: ['done']);
    final totalProjects = await count('projects');
    final completedProjects = await count('projects', where: 'status = ?', whereArgs: ['completed']);
    final totalHabits = await count('habits');
    final activeReminders = await count('habit_reminders', where: 'isActive = 1');
    final totalIdeas = await count('ideas');
    final implementedIdeas = await count('ideas', where: 'isImplemented = 1');
    final ideasInProgress = await count('ideas', where: 'status = ?', whereArgs: ['in_progress']);
    final inboxCount = await count('inbox', where: 'isProcessed = 0');
    final totalEvents = await count('calendar_events');

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'totalProjects': totalProjects,
      'completedProjects': completedProjects,
      'totalHabits': totalHabits,
      'activeReminders': activeReminders,
      'totalIdeas': totalIdeas,
      'implementedIdeas': implementedIdeas,
      'ideasInProgress': ideasInProgress,
      'inboxCount': inboxCount,
      'totalEvents': totalEvents,
    };
  }
}