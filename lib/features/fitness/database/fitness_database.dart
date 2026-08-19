import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class FitnessDatabase {
  static final FitnessDatabase _instance = FitnessDatabase._internal();
  static Database? _database;

  FitnessDatabase._internal();

  factory FitnessDatabase() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> deleteDatabaseFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'fitness_app.db');

    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
      }
      final dbFile = File(path);
      if (await dbFile.exists()) await dbFile.delete();
      final walFile = File('$path-wal');
      if (await walFile.exists()) await walFile.delete();
      final shmFile = File('$path-shm');
      if (await shmFile.exists()) await shmFile.delete();
      debugPrint('✅ Все файлы БД фитнеса очищены');
    } catch (e) {
      debugPrint('⚠️ Ошибка удаления БД фитнеса: $e');
    }
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'fitness_app.db');
    return await openDatabase(
      path,
      version: 11,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('📦 Создание базы фитнеса версии $version');

    await db.execute('''CREATE TABLE exercises (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT DEFAULT '',
      muscleGroups TEXT DEFAULT '[]', imageUrl TEXT, exerciseType TEXT DEFAULT 'strength',
      isCustom INTEGER DEFAULT 0, videoUrl TEXT, techniqueTips TEXT, commonMistakes TEXT,
      createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE workout_programs (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT DEFAULT 'weekly',
      days TEXT DEFAULT '[]', templateName TEXT, description TEXT,
      createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL,
      emoji TEXT DEFAULT '💪',
      accentColorValue INTEGER DEFAULT 4294929975,
      difficulty TEXT DEFAULT 'medium',
      goal TEXT DEFAULT 'general',
      sessionDurationMinutes INTEGER DEFAULT 60
    )''');

    await db.execute('''CREATE TABLE workout_days (
      id TEXT PRIMARY KEY, programId TEXT NOT NULL, dayNumber INTEGER DEFAULT 1,
      date TEXT, exercises TEXT DEFAULT '[]', isRestDay INTEGER DEFAULT 0,
      notes TEXT, status TEXT DEFAULT 'pending',
      FOREIGN KEY (programId) REFERENCES workout_programs(id) ON DELETE CASCADE
    )''');

    await db.execute('''CREATE TABLE workout_logs (
      id TEXT PRIMARY KEY, date TEXT NOT NULL, programId TEXT, dayNumber INTEGER,
      status TEXT DEFAULT 'completed', comment TEXT, startTime TEXT, endTime TEXT,
      exercisesLog TEXT DEFAULT '[]', totalRestTime INTEGER, totalVolume REAL,
      avgRpe REAL, bodyWeight TEXT, createdAt TEXT NOT NULL,
      moodEnergy INTEGER, moodSleep INTEGER, moodMotivation INTEGER,
      moodNotes TEXT, workoutPhotoPath TEXT
    )''');

    await db.execute('''CREATE TABLE progress_records (
      id TEXT PRIMARY KEY, exerciseId TEXT NOT NULL, date TEXT NOT NULL,
      bestWeight REAL DEFAULT 0.0, bestReps INTEGER DEFAULT 0,
      estimated1RM REAL DEFAULT 0.0, totalVolume REAL DEFAULT 0.0,
      totalSets INTEGER DEFAULT 0, avgRpe REAL,
      FOREIGN KEY (exerciseId) REFERENCES exercises(id) ON DELETE CASCADE
    )''');

    await db.execute('''CREATE TABLE user_fitness_profile (
      id TEXT PRIMARY KEY, name TEXT DEFAULT 'Атлет', avatarUrl TEXT,
      bodyWeightHistory TEXT DEFAULT '[]', goal TEXT DEFAULT 'general',
      level TEXT DEFAULT 'intermediate', gender TEXT DEFAULT 'male',
      height REAL, age INTEGER, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE workout_templates (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT DEFAULT '',
      type TEXT DEFAULT 'weekly', days TEXT DEFAULT '[]',
      category TEXT DEFAULT 'custom', recommendedLevel TEXT DEFAULT 'intermediate'
    )''');

    await db.execute('''CREATE TABLE fitness_photos (
      id TEXT PRIMARY KEY, date TEXT NOT NULL, imageUrl TEXT NOT NULL,
      label TEXT, weight REAL, notes TEXT, createdAt TEXT NOT NULL,
      chest REAL, waist REAL, hips REAL, biceps REAL,
      thigh REAL, calf REAL, neck REAL, forearm REAL
    )''');

    await db.execute('''CREATE TABLE wellbeing_notes (
      id TEXT PRIMARY KEY, date TEXT NOT NULL, energyLevel INTEGER DEFAULT 5,
      sleepQuality INTEGER DEFAULT 5, motivationLevel INTEGER DEFAULT 5,
      painAreas TEXT DEFAULT '[]', notes TEXT, createdAt TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE program_sessions (
      id TEXT PRIMARY KEY,
      programId TEXT NOT NULL,
      startDate TEXT NOT NULL,
      endDate TEXT,
      currentDayIndex INTEGER DEFAULT 0,
      difficulty TEXT DEFAULT 'standard',
      status TEXT DEFAULT 'active',
      daySessions TEXT DEFAULT '[]',
      streak INTEGER DEFAULT 0,
      longestStreak INTEGER DEFAULT 0,
      totalVolumeCompleted REAL DEFAULT 0,
      totalWorkoutsCompleted INTEGER DEFAULT 0,
      totalWorkoutsSkipped INTEGER DEFAULT 0,
      averageRpe REAL DEFAULT 0,
      completedAt TEXT,
      summaryData TEXT DEFAULT '{}',
      FOREIGN KEY (programId) REFERENCES workout_programs(id) ON DELETE CASCADE
    )''');

    await db.execute('''CREATE TABLE fitness_targets (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT DEFAULT '',
      type TEXT NOT NULL,
      exerciseId TEXT,
      targetValue REAL NOT NULL,
      currentValue REAL DEFAULT 0,
      startValue REAL DEFAULT 0,
      unit TEXT NOT NULL,
      deadline TEXT,
      createdAt TEXT NOT NULL,
      completedAt TEXT,
      status TEXT DEFAULT 'active',
      accentColor INTEGER DEFAULT 4294929975,
      extra TEXT DEFAULT '{}',
      entries TEXT DEFAULT '[]'
    )''');

    await _createIndexes(db);
    await _seedDefaultExercises(db);
    await _seedDefaultTemplates(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Миграция фитнес БД: $oldVersion → $newVersion');
    try {
      if (oldVersion < 2) {
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((t) => t['name'] as String).toList();
        if (!tableNames.contains('fitness_photos')) {
          await db.execute('''CREATE TABLE fitness_photos (
          id TEXT PRIMARY KEY, date TEXT NOT NULL, imageUrl TEXT NOT NULL,
          label TEXT, weight REAL, notes TEXT, createdAt TEXT NOT NULL
        )''');
        }
        if (!tableNames.contains('wellbeing_notes')) {
          await db.execute('''CREATE TABLE wellbeing_notes (
          id TEXT PRIMARY KEY, date TEXT NOT NULL, energyLevel INTEGER DEFAULT 5,
          sleepQuality INTEGER DEFAULT 5, motivationLevel INTEGER DEFAULT 5,
          painAreas TEXT DEFAULT '[]', notes TEXT, createdAt TEXT NOT NULL
        )''');
        }
        if (!tableNames.contains('workout_templates')) {
          await db.execute('''CREATE TABLE workout_templates (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT DEFAULT '',
          type TEXT DEFAULT 'weekly', days TEXT DEFAULT '[]',
          category TEXT DEFAULT 'custom', recommendedLevel TEXT DEFAULT 'intermediate'
        )''');
          await _seedDefaultTemplates(db);
        }
      }

      if (oldVersion < 3) {
        await _seedDefaultTemplates(db);
      }

      if (oldVersion < 4) {
        debugPrint('🔧 v4: Пересоздаём шаблоны с правильной сериализацией');
        await db.delete('workout_templates');
        await _seedDefaultTemplates(db);
      }

      if (oldVersion < 5) {
        debugPrint('🔧 v5: Добавляем обхваты тела в fitness_photos');
        final columns = await db.rawQuery('PRAGMA table_info(fitness_photos)');
        final columnNames = columns.map((c) => c['name'] as String).toList();
        final newColumns = {
          'chest': 'REAL', 'waist': 'REAL', 'hips': 'REAL', 'biceps': 'REAL',
          'thigh': 'REAL', 'calf': 'REAL', 'neck': 'REAL', 'forearm': 'REAL',
        };
        for (final entry in newColumns.entries) {
          if (!columnNames.contains(entry.key)) {
            try {
              await db.execute('ALTER TABLE fitness_photos ADD COLUMN ${entry.key} ${entry.value}');
              debugPrint('  ✅ Добавлен столбец: ${entry.key}');
            } catch (e) {
              debugPrint('  ⚠️ Ошибка добавления ${entry.key}: $e');
            }
          }
        }
      }

      if (oldVersion < 6) {
        debugPrint('🔧 v6: Добавляем настроение и фото в workout_logs');
        final columns = await db.rawQuery('PRAGMA table_info(workout_logs)');
        final columnNames = columns.map((c) => c['name'] as String).toList();
        final newColumns = {
          'moodEnergy': 'INTEGER', 'moodSleep': 'INTEGER', 'moodMotivation': 'INTEGER',
          'moodNotes': 'TEXT', 'workoutPhotoPath': 'TEXT',
        };
        for (final entry in newColumns.entries) {
          if (!columnNames.contains(entry.key)) {
            try {
              await db.execute('ALTER TABLE workout_logs ADD COLUMN ${entry.key} ${entry.value}');
              debugPrint('  ✅ Добавлен столбец: ${entry.key}');
            } catch (e) {
              debugPrint('  ⚠️ Ошибка добавления ${entry.key}: $e');
            }
          }
        }
      }

      if (oldVersion < 7) {
        debugPrint('🔧 v7: Добавляем таблицу program_sessions');
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((t) => t['name'] as String).toList();
        if (!tableNames.contains('program_sessions')) {
          await db.execute('''CREATE TABLE program_sessions (
            id TEXT PRIMARY KEY, programId TEXT NOT NULL,
            startDate TEXT NOT NULL, endDate TEXT,
            currentDayIndex INTEGER DEFAULT 0, difficulty TEXT DEFAULT 'standard',
            status TEXT DEFAULT 'active', daySessions TEXT DEFAULT '[]',
            streak INTEGER DEFAULT 0, longestStreak INTEGER DEFAULT 0,
            totalVolumeCompleted REAL DEFAULT 0,
            totalWorkoutsCompleted INTEGER DEFAULT 0,
            totalWorkoutsSkipped INTEGER DEFAULT 0,
            averageRpe REAL DEFAULT 0, completedAt TEXT,
            summaryData TEXT DEFAULT '{}'
          )''');
          debugPrint('  ✅ Таблица program_sessions создана');
        }
      }

      if (oldVersion < 8) {
        debugPrint('🔧 v8: Добавляем таблицу fitness_targets');
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((t) => t['name'] as String).toList();
        if (!tableNames.contains('fitness_targets')) {
          await db.execute('''CREATE TABLE fitness_targets (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT DEFAULT '',
            type TEXT NOT NULL, exerciseId TEXT,
            targetValue REAL NOT NULL, currentValue REAL DEFAULT 0,
            startValue REAL DEFAULT 0, unit TEXT NOT NULL, deadline TEXT,
            createdAt TEXT NOT NULL, completedAt TEXT,
            status TEXT DEFAULT 'active', accentColor INTEGER DEFAULT 4294929975,
            extra TEXT DEFAULT '{}'
          )''');
          debugPrint('  ✅ Таблица fitness_targets создана');
        }
      }

      if (oldVersion < 9) {
        debugPrint('🔧 v9: Добавляем колонку entries в fitness_targets');
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((t) => t['name'] as String).toList();
        if (tableNames.contains('fitness_targets')) {
          final columns = await db.rawQuery('PRAGMA table_info(fitness_targets)');
          final columnNames = columns.map((c) => c['name'] as String).toList();
          if (!columnNames.contains('entries')) {
            try {
              await db.execute("ALTER TABLE fitness_targets ADD COLUMN entries TEXT DEFAULT '[]'");
              debugPrint('  ✅ Колонка entries добавлена в fitness_targets');
            } catch (e) {
              debugPrint('  ⚠️ Ошибка добавления колонки entries: $e');
            }
          }
        }
      }

      if (oldVersion < 10) {
        debugPrint('🔧 v10: Добавляем новые поля в workout_programs');
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((t) => t['name'] as String).toList();
        if (tableNames.contains('workout_programs')) {
          final columns = await db.rawQuery('PRAGMA table_info(workout_programs)');
          final columnNames = columns.map((c) => c['name'] as String).toList();
          final newColumns = {
            'emoji': "TEXT DEFAULT '💪'",
            'accentColorValue': 'INTEGER DEFAULT 4294929975',
            'difficulty': "TEXT DEFAULT 'medium'",
            'goal': "TEXT DEFAULT 'general'",
            'sessionDurationMinutes': 'INTEGER DEFAULT 60',
          };
          for (final entry in newColumns.entries) {
            if (!columnNames.contains(entry.key)) {
              try {
                await db.execute("ALTER TABLE workout_programs ADD COLUMN ${entry.key} ${entry.value}");
                debugPrint('  ✅ Колонка ${entry.key} добавлена в workout_programs');
              } catch (e) {
                debugPrint('  ⚠️ Ошибка добавления ${entry.key}: $e');
              }
            }
          }
        }
      }

      // 🔥 v11: БЕЗОПАСНОЕ обновление — сохраняем пользовательские упражнения
      if (oldVersion < 11) {
        debugPrint('🔧 v11: Обновляем базу упражнений до 60 шт и программ до 10');

        // Удаляем ТОЛЬКО стандартные упражнения (isCustom = 0)
        try {
          final deleted = await db.delete('exercises', where: 'isCustom = ?', whereArgs: [0]);
          debugPrint('  🗑️ Удалено $deleted стандартных упражнений');
        } catch (e) {
          debugPrint('  ⚠️ Ошибка удаления стандартных упражнений: $e');
        }

        // Принудительно удаляем старые дефолтные по ID (на случай если isCustom не был выставлен)
        for (int i = 1; i <= 30; i++) {
          final id = 'ex_default_${i.toString().padLeft(3, '0')}';
          try {
            await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
          } catch (_) {}
        }

        await _seedDefaultExercises(db);

        // Шаблоны можно пересоздать полностью — они системные
        await db.delete('workout_templates');
        await _seedDefaultTemplates(db);

        debugPrint('  ✅ База обновлена до v11 (пользовательские упражнения сохранены)');
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка миграции фитнес БД: $e');
    }
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_exercises_type ON exercises(exerciseType)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_exercises_custom ON exercises(isCustom)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_workout_days_program ON workout_days(programId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_workout_days_date ON workout_days(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_workout_logs_date ON workout_logs(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_workout_logs_program ON workout_logs(programId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_progress_exercise ON progress_records(exerciseId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_progress_date ON progress_records(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_fitness_photos_date ON fitness_photos(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_wellbeing_date ON wellbeing_notes(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_sessions_status ON program_sessions(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_sessions_program ON program_sessions(programId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_sessions_start ON program_sessions(startDate)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_fitness_targets_status ON fitness_targets(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_fitness_targets_type ON fitness_targets(type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_fitness_targets_exercise ON fitness_targets(exerciseId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_fitness_targets_created ON fitness_targets(createdAt)');
    } catch (e) {
      debugPrint('⚠️ Ошибка создания индексов фитнес: $e');
    }
  }

  // ==================== НАЧАЛЬНЫЕ УПРАЖНЕНИЯ (60 шт) ====================

  Future<void> _seedDefaultExercises(Database db) async {
    // Проверяем наличие дефолтных упражнений
    final existingDefault = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: ['ex_default_001'],
      limit: 1,
    );

    if (existingDefault.isNotEmpty) {
      // Если уже есть дефолтные — проверяем количество
      final allDefaults = await db.query(
        'exercises',
        where: 'isCustom = ?',
        whereArgs: [0],
      );
      if (allDefaults.length >= 60) {
        debugPrint('📦 Все 60 дефолтных упражнений уже есть, пропускаем');
        return;
      }
      debugPrint('⚠️ Найдено ${allDefaults.length}/60 дефолтных, дополняем...');
    } else {
      debugPrint('🌱 Заполняем базу начальными упражнениями (60 шт)...');
    }

    final now = DateTime.now().toIso8601String();

    final defaultExercises = [
      // === ГРУДНЫЕ (CHEST) — 8 упражнений ===
      {'id': 'ex_default_001', 'name': 'Жим штанги лёжа', 'description': 'Классический жим лёжа на горизонтальной скамье. Базовое упражнение для развития грудных мышц.', 'muscleGroups': '["chest","shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Держите лопатки сведёнными, прогиб в пояснице естественный', 'commonMistakes': 'Отрыв таза от скамьи, слишком широкий хват', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_002', 'name': 'Жим гантелей лёжа', 'description': 'Жим гантелей на горизонтальной скамье. Лучшая амплитуда для грудных.', 'muscleGroups': '["chest","shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'В нижней точке растягивайте грудные, сводите гантели вверху', 'commonMistakes': 'Слишком тяжёлый вес, потеря контроля', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_003', 'name': 'Разведение гантелей', 'description': 'Изолированное упражнение для грудных мышц. Отлично растягивает и прорабатывает среднюю часть груди.', 'muscleGroups': '["chest"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Сохраняйте небольшой изгиб в локтях, не выпрямляйте полностью', 'commonMistakes': 'Прямые руки, слишком тяжёлый вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_004', 'name': 'Отжимания от пола', 'description': 'Базовое упражнение с собственным весом. Развивает грудь, плечи и трицепс.', 'muscleGroups': '["chest","shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Держите тело прямым, локти под 45°, опускайтесь до касания грудью пола', 'commonMistakes': 'Провисание поясницы, неполная амплитуда', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_031', 'name': 'Жим гантелей на наклонной скамье', 'description': 'Жим гантелей на скамье с наклоном 30-45°. Акцент на верхнюю часть грудных.', 'muscleGroups': '["chest","shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Наклон 30-45°, сводите гантели в верхней точке', 'commonMistakes': 'Слишком большой наклон, переход на плечи', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_032', 'name': 'Сведение рук в кроссовере', 'description': 'Изолированное упражнение на верхнем блоке. Отличная пампинг-техника для груди.', 'muscleGroups': '["chest","shoulders"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Сводите руки перед собой, делайте паузу на пике сокращения', 'commonMistakes': 'Использование инерции, слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_033', 'name': 'Отжимания на брусьях (грудь)', 'description': 'Отжимания на брусьях с акцентом на грудные. Наклон корпуса вперёд.', 'muscleGroups': '["chest","shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Наклон корпуса вперёд, локти в стороны, опускайтесь глубоко', 'commonMistakes': 'Вертикальное положение, работа только трицепса', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_034', 'name': 'Жим штанги на наклонной скамье', 'description': 'Жим штанги на скамье с наклоном. Акцент на верх груди.', 'muscleGroups': '["chest","shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Наклон 30-45°, хват чуть шире плеч', 'commonMistakes': 'Слишком большой вес, потеря техники', 'createdAt': now, 'updatedAt': now},

      // === СПИНА (BACK) — 8 упражнений ===
      {'id': 'ex_default_005', 'name': 'Подтягивания', 'description': 'Базовое упражнение для спины и бицепса. Развивает широчайшие и бицепсы.', 'muscleGroups': '["back","biceps","lats"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Тянитесь грудью к перекладине, лопатки сведены', 'commonMistakes': 'Раскачивание, рывки, неполная амплитуда', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_006', 'name': 'Тяга штанги в наклоне', 'description': 'Мощное упражнение для толщины спины. Развивает широчайшие, ромбовидные и бицепсы.', 'muscleGroups': '["back","lats","biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Держите спину прямой, тяните штангу к животу', 'commonMistakes': 'Округление спины, рывки, слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_007', 'name': 'Тяга верхнего блока', 'description': 'Аналог подтягиваний на тренажёре. Хорошо прорабатывает широчайшие.', 'muscleGroups': '["back","lats","biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Тяните к верхней части груди, лопатки сведены', 'commonMistakes': 'Отклонение корпуса, рывки, слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_008', 'name': 'Становая тяга', 'description': 'Король упражнений. Развивает всё тело: спину, ноги, ягодицы, трапеции.', 'muscleGroups': '["back","glutes","hamstrings","lowerBack","traps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Держите спину прямой, штанга близко к ногам, включайте ноги', 'commonMistakes': 'Округление спины, отрыв штанги от ног, рывки', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_035', 'name': 'Тяга горизонтального блока сидя', 'description': 'Упражнение для проработки средней и нижней части широчайших. Хорошо для осанки.', 'muscleGroups': '["back","lats","biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Спина прямая, тянем рукоятку к животу, лопатки сведены', 'commonMistakes': 'Раскачивание корпусом, работа спиной и бицепсом', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_036', 'name': 'Тяга Т-грифа', 'description': 'Вариация тяги в наклоне. Хорошо прорабатывает середину спины.', 'muscleGroups': '["back","lats","biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Спина прямая, тяните гриф к груди, локти к телу', 'commonMistakes': 'Округление спины, работа бицепсом', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_037', 'name': 'Разведение рук с гантелями стоя', 'description': 'Разведение рук с гантелями в стороны стоя. Проработка средней и задней дельты.', 'muscleGroups': '["shoulders","back"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Локти чуть выше кистей, сохраняйте изгиб в локтях', 'commonMistakes': 'Раскачивание, слишком тяжёлый вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_038', 'name': 'Тяга гантели к поясу', 'description': 'Упражнение на проработку широчайших мышц спины. Опора на скамью.', 'muscleGroups': '["back","lats","biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Спина прямая, тянем гантель к поясу, локоть к корпусу', 'commonMistakes': 'Скручивание корпуса, работа бицепсом', 'createdAt': now, 'updatedAt': now},

      // === ПЛЕЧИ (SHOULDERS) — 6 упражнений ===
      {'id': 'ex_default_009', 'name': 'Жим штанги стоя', 'description': 'Армейский жим для дельт. Базовое упражнение для плеч.', 'muscleGroups': '["shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Держите пресс напряжённым, штанга за головой или перед собой', 'commonMistakes': 'Избыточный прогиб в пояснице, слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_010', 'name': 'Махи гантелями в стороны', 'description': 'Изолирующее упражнение для средних дельт. Создаёт ширину плеч.', 'muscleGroups': '["shoulders"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Локти чуть выше кистей, небольшой изгиб в локтях', 'commonMistakes': 'Раскачивание, слишком тяжёлый вес, использование трапеций', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_011', 'name': 'Тяга штанги к подбородку', 'description': 'Комплексное упражнение для плеч и трапеций.', 'muscleGroups': '["shoulders","traps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Тяните локти вверх, штанга к подбородку, хват чуть уже плеч', 'commonMistakes': 'Слишком узкий хват, травмоопасно для плеч', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_039', 'name': 'Жим гантелей сидя', 'description': 'Жим гантелей сидя. Хорошо прорабатывает передние и средние дельты.', 'muscleGroups': '["shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Спина прямая, гантели чуть выше плеч, выжимаем вверх', 'commonMistakes': 'Прогиб в пояснице, слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_040', 'name': 'Махи гантелями в наклоне', 'description': 'Изолирующее упражнение для задних дельт.', 'muscleGroups': '["shoulders","back"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Наклон вперёд, локти в стороны, разводим гантели', 'commonMistakes': 'Работа спиной, а не дельтами', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_041', 'name': 'Жим штанги из-за головы', 'description': 'Вариация жима стоя. Акцент на средние дельты.', 'muscleGroups': '["shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Осторожно с плечевыми суставами, опускайте до уровня ушей', 'commonMistakes': 'Слишком низкое опускание, травмоопасно', 'createdAt': now, 'updatedAt': now},

      // === НОГИ (LEGS) — 8 упражнений ===
      {'id': 'ex_default_012', 'name': 'Приседания со штангой', 'description': 'Базовое упражнение для ног. Развивает квадрицепсы, ягодицы, бицепс бедра.', 'muscleGroups': '["quadriceps","glutes","hamstrings","lowerBack"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Колени в сторону носков, спина прямая, глубина до параллели', 'commonMistakes': 'Отрыв пяток, округление спины, неполная амплитуда', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_013', 'name': 'Жим ногами', 'description': 'В тренажёре. Изолирует квадрицепсы, минимальная нагрузка на спину.', 'muscleGroups': '["quadriceps","glutes","hamstrings"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Не выпрямляйте колени полностью, сохраняйте контроль', 'commonMistakes': 'Полное выпрямление коленей, отрыв таза от сиденья', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_014', 'name': 'Выпады с гантелями', 'description': 'Для ног и ягодиц. Развивает баланс и координацию.', 'muscleGroups': '["quadriceps","glutes","hamstrings"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Колено не выходит за носок, спина прямая', 'commonMistakes': 'Наклон корпуса вперёд, потеря равновесия', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_015', 'name': 'Сгибания ног в тренажёре', 'description': 'Для бицепса бедра. Изолирующее упражнение.', 'muscleGroups': '["hamstrings"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Не отрывайте таз от сиденья, делайте пиковое сокращение', 'commonMistakes': 'Рывки, слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_016', 'name': 'Подъёмы на носки стоя', 'description': 'Для икроножных мышц. Базовое упражнение.', 'muscleGroups': '["calves"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Максимальная амплитуда, задержка в верхней точке', 'commonMistakes': 'Быстрые движения, неполная амплитуда', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_042', 'name': 'Румынская тяга', 'description': 'Для бицепса бедра и ягодиц. Полусогнутые ноги.', 'muscleGroups': '["hamstrings","glutes","lowerBack"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Спина прямая, наклон до растяжки в бицепсе бедра', 'commonMistakes': 'Округление спины, сгибание ног', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_043', 'name': 'Болгарские выпады', 'description': 'Выпады с задней ногой на возвышении. Хорошо прорабатывают ягодицы и квадрицепсы.', 'muscleGroups': '["quadriceps","glutes","hamstrings"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Переднее колено не выходит за носок, корпус вертикально', 'commonMistakes': 'Потеря равновесия, слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_044', 'name': 'Подъёмы на носки сидя', 'description': 'Для икр. Акцент на камбаловидную мышцу.', 'muscleGroups': '["calves"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Колени под 90°, максимальная амплитуда', 'commonMistakes': 'Неполная амплитуда, рывки', 'createdAt': now, 'updatedAt': now},

      // === РУКИ (ARMS) — 10 упражнений ===
      {'id': 'ex_default_017', 'name': 'Подъём штанги на бицепс', 'description': 'Классика для бицепса. Развивает двуглавую мышцу плеча.', 'muscleGroups': '["biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Локти к корпусу, не раскачивайтесь, делайте паузу на пике', 'commonMistakes': 'Читинг (раскачивание), слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_018', 'name': 'Французский жим', 'description': 'Для трицепса. Разгибание рук из-за головы.', 'muscleGroups': '["triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Локти фиксированы, опускайте штангу за голову', 'commonMistakes': 'Разведение локтей, травма локтевых суставов', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_019', 'name': 'Молотки', 'description': 'Нейтральный хват. Развивает бицепс и плечевую мышцу.', 'muscleGroups': '["biceps","forearms"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Кисти параллельно друг другу, локти фиксированы', 'commonMistakes': 'Раскачивание, работа не той мышцей', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_020', 'name': 'Отжимания на брусьях', 'description': 'Для трицепса и груди. Базовое упражнение с весом тела.', 'muscleGroups': '["triceps","chest","shoulders"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Не разводите локти, опускайтесь до параллели', 'commonMistakes': 'Неполная амплитуда, слишком широкий хват', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_045', 'name': 'Сгибания рук с гантелями сидя', 'description': 'Сгибания рук с гантелями сидя. Акцент на длинную головку бицепса.', 'muscleGroups': '["biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Локти к корпусу, гантели параллельно', 'commonMistakes': 'Раскачивание, работа плечами', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_046', 'name': 'Разгибание рук на блоке', 'description': 'Изолирующее упражнение для трицепса на верхнем блоке.', 'muscleGroups': '["triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Локти фиксированы, выпрямляем руки до полного сокращения', 'commonMistakes': 'Движение плечами, слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_047', 'name': 'Сгибание рук со штангой обратным хватом', 'description': 'Для развития плечевой мышцы и предплечий.', 'muscleGroups': '["biceps","forearms"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Хват сверху, локти к корпусу', 'commonMistakes': 'Слишком большой вес, работа запястьями', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_048', 'name': 'Трицепсовые отжимания от скамьи', 'description': 'Отжимания от скамьи сзади. Для трицепса с весом тела.', 'muscleGroups': '["triceps"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Локти назад, опускайтесь до угла 90°', 'commonMistakes': 'Локти в стороны, слишком низкое опускание', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_049', 'name': 'Концентрационные сгибания', 'description': 'Изолирующее упражнение для бицепса с акцентом на пиковое сокращение.', 'muscleGroups': '["biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Опора на колено, локтевой сустав фиксирован, максимальное сокращение', 'commonMistakes': 'Раскачивание, слишком большой вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_050', 'name': 'Сгибание запястий', 'description': 'Для развития мышц предплечья. Базовое упражнение.', 'muscleGroups': '["forearms"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Предплечья на коленях, сгибаем запястья вверх', 'commonMistakes': 'Рывки, слишком большой вес', 'createdAt': now, 'updatedAt': now},

      // === ПРЕСС И КОР (CORE) — 6 упражнений ===
      {'id': 'ex_default_021', 'name': 'Скручивания', 'description': 'Базовое упражнение на пресс. Проработка прямых мышц живота.', 'muscleGroups': '["abs"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Поясница прижата к полу, подбородок не касается груди', 'commonMistakes': 'Рывки, работа шеей, неполная амплитуда', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_022', 'name': 'Планка', 'description': 'Статическое упражнение для кора. Укрепляет мышцы живота и спины.', 'muscleGroups': '["abs","obliques","lowerBack"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Тело прямая линия, пресс напряжён, не прогибаться', 'commonMistakes': 'Провисание в пояснице, поднятый таз', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_023', 'name': 'Подъём ног в висе', 'description': 'Для нижнего пресса. Сложное упражнение, отличный результат.', 'muscleGroups': '["abs","obliques"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Не раскачивайтесь, поднимайте ноги до параллели с полом', 'commonMistakes': 'Раскачивание, работа сгибателями бедра', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_051', 'name': 'Боковая планка', 'description': 'Упражнение для косых мышц живота. Баланс и стабильность.', 'muscleGroups': '["obliques","abs","shoulders"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Тело прямая линия сбоку, таз не провисает', 'commonMistakes': 'Провисание таза, сгибание в пояснице', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_052', 'name': 'Вакуум живота', 'description': 'Дыхательное упражнение для мышц живота. Укрепляет поперечную мышцу.', 'muscleGroups': '["abs"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Максимально втяните живот, задержите дыхание, держите 15-30 секунд', 'commonMistakes': 'Поверхностное дыхание, неправильная техника', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_053', 'name': 'Ножницы ногами', 'description': 'Динамическое упражнение для нижнего пресса и бедер.', 'muscleGroups': '["abs","obliques","quadriceps"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Поясница прижата, ноги на весу, скрещиваем', 'commonMistakes': 'Отрыв поясницы, согнутые колени', 'createdAt': now, 'updatedAt': now},

      // === КАРДИО (CARDIO) — 4 упражнения ===
      {'id': 'ex_default_024', 'name': 'Бег на дорожке', 'description': 'Кардио тренировка. Отлично сжигает калории и укрепляет сердечно-сосудистую систему.', 'muscleGroups': '["cardio_vascular","quadriceps","calves"]', 'imageUrl': '', 'exerciseType': 'cardio', 'isCustom': 0, 'techniqueTips': 'Ровный темп, дыхание через нос, следите за пульсом', 'commonMistakes': 'Быстрый старт, неправильная постановка стопы', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_025', 'name': 'Велотренажёр', 'description': 'Кардио с низкой нагрузкой на суставы. Отлично для сжигания жира.', 'muscleGroups': '["cardio_vascular","quadriceps","glutes"]', 'imageUrl': '', 'exerciseType': 'cardio', 'isCustom': 0, 'techniqueTips': 'Настройте сиденье по высоте, ровный темп, педалируйте в полную амплитуду', 'commonMistakes': 'Низкое сиденье, слишком большое сопротивление', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_026', 'name': 'Плавание', 'description': 'Кардио на всё тело. Минимальная нагрузка на суставы, максимум пользы.', 'muscleGroups': '["cardio_vascular","fullBody"]', 'imageUrl': '', 'exerciseType': 'cardio', 'isCustom': 0, 'techniqueTips': 'Следите за дыханием, работайте ногами, правильная техника', 'commonMistakes': 'Задержка дыхания, неправильная техника', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_054', 'name': 'Прыжки на скакалке', 'description': 'Эффективное кардио для всего тела. Развивает выносливость.', 'muscleGroups': '["cardio_vascular","calves","shoulders"]', 'imageUrl': '', 'exerciseType': 'cardio', 'isCustom': 0, 'techniqueTips': 'Ритмичные прыжки, вращение кистями, мягкое приземление', 'commonMistakes': 'Сильное приземление, вращение плечами', 'createdAt': now, 'updatedAt': now},

      // === БОКС (BOXING) — 2 упражнения ===
      {'id': 'ex_default_027', 'name': 'Работа на груше', 'description': 'Ударная тренировка. Развивает координацию и взрывную силу.', 'muscleGroups': '["shoulders","back","abs","fullBody"]', 'imageUrl': '', 'exerciseType': 'boxing', 'isCustom': 0, 'techniqueTips': 'Руки у подбородка, работа ногами, дыхание', 'commonMistakes': 'Опускание рук, неправильная дистанция', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_028', 'name': 'Бой с тенью', 'description': 'Имитация боя. Отлично развивает координацию и выносливость.', 'muscleGroups': '["shoulders","fullBody","cardio_vascular"]', 'imageUrl': '', 'exerciseType': 'boxing', 'isCustom': 0, 'techniqueTips': 'Двигайтесь на носках, работайте ногами, дыхание через нос', 'commonMistakes': 'Статичность, опускание рук', 'createdAt': now, 'updatedAt': now},

      // === ЙОГА И РАСТЯЖКА (YOGA & FLEXIBILITY) — 4 упражнения ===
      {'id': 'ex_default_029', 'name': 'Растяжка всего тела', 'description': 'Комплекс упражнений на гибкость и расслабление.', 'muscleGroups': '["flexibility","fullBody"]', 'imageUrl': '', 'exerciseType': 'yoga', 'isCustom': 0, 'techniqueTips': 'Дышите глубоко, не делайте резких движений, слушайте тело', 'commonMistakes': 'Пружинистые движения, задержка дыхания', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_030', 'name': 'Собака мордой вниз', 'description': 'Классическая асана. Отлично растягивает и укрепляет всё тело.', 'muscleGroups': '["flexibility","shoulders","hamstrings","calves"]', 'imageUrl': '', 'exerciseType': 'yoga', 'isCustom': 0, 'techniqueTips': 'Пятки к полу, спина прямая, руки и ноги прямые', 'commonMistakes': 'Округление спины, отрыв пяток', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_055', 'name': 'Кобра', 'description': 'Прогиб назад. Укрепляет спину, раскрывает грудную клетку.', 'muscleGroups': '["flexibility","back","shoulders"]', 'imageUrl': '', 'exerciseType': 'yoga', 'isCustom': 0, 'techniqueTips': 'Начинайте с легкого прогиба, не переусердствуйте', 'commonMistakes': 'Резкий прогиб, перенапряжение', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_056', 'name': 'Растяжка подколенных сухожилий', 'description': 'Растяжка бицепса бедра и икроножных мышц.', 'muscleGroups': '["flexibility","hamstrings","calves"]', 'imageUrl': '', 'exerciseType': 'yoga', 'isCustom': 0, 'techniqueTips': 'Ноги вместе или на ширине плеч, наклон вперёд, спина прямая', 'commonMistakes': 'Округление спины, рывки', 'createdAt': now, 'updatedAt': now},

      // === ДОПОЛНИТЕЛЬНЫЕ (SPECIALIZED) — 4 упражнения ===
      {'id': 'ex_default_057', 'name': 'Гиперэкстензия', 'description': 'Упражнение для поясницы и ягодиц. Укрепляет позвоночник.', 'muscleGroups': '["lowerBack","glutes","hamstrings"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Медленный подъём, задержка в верхней точке', 'commonMistakes': 'Рывки, слишком высокий подъём', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_058', 'name': 'Берпи', 'description': 'Комплексное функциональное упражнение. Развивает взрывную силу и выносливость.', 'muscleGroups': '["fullBody","cardio_vascular","chest","quadriceps"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Плавные движения, дыхание, темп', 'commonMistakes': 'Рывки, неполная амплитуда', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_059', 'name': 'Запрыгивания на тумбу', 'description': 'Развивает взрывную силу ног. Плиометрическое упражнение.', 'muscleGroups': '["quadriceps","glutes","calves"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Мягкое приземление, работа коленями, безопасная высота', 'commonMistakes': 'Жесткое приземление, слишком высокая тумба', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_060', 'name': 'Русский твист', 'description': 'Упражнение для косых мышц живота и пресса. С весом или без.', 'muscleGroups': '["abs","obliques","shoulders"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Ноги на весу, поворачивайте корпус в стороны, держите спину прямой', 'commonMistakes': 'Работа ногами, а не корпусом', 'createdAt': now, 'updatedAt': now},
    ];

    int inserted = 0;
    for (final exercise in defaultExercises) {
      try {
        final existing = await db.query('exercises', where: 'id = ?', whereArgs: [exercise['id']], limit: 1);
        if (existing.isEmpty) {
          await db.insert('exercises', exercise);
          inserted++;
        }
      } catch (e) {
        debugPrint('  ⚠️ Пропуск ${exercise['id']}: $e');
      }
    }
    debugPrint('✅ Добавлено $inserted новых упражнений (всего дефолтных: 60)');
  }

  // ==================== ШАБЛОНЫ ПРОГРАММ (10 шт) ====================

  Future<void> _seedDefaultTemplates(Database db) async {
    debugPrint('🌱 Заполняем шаблоны программ (10 шт)...');
    await db.delete('workout_templates');

    final uuid = const Uuid();
    final templates = [
      // 1. Грудь и жим
      {
        'id': 'tpl_001', 'name': 'Грудь и жим', 'type': 'weekly', 'category': 'chest', 'recommendedLevel': 'intermediate',
        'description': 'Упор на грудные мышцы и жимовые движения. 5 тренировок в неделю.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_001','ex_default_002','ex_default_003','ex_default_020'], false],
          [2, ['ex_default_005','ex_default_006','ex_default_017','ex_default_035'], false],
          [3, ['ex_default_012','ex_default_013','ex_default_014','ex_default_015'], false],
          [4, ['ex_default_031','ex_default_032','ex_default_033','ex_default_034'], false],
          [5, ['ex_default_004','ex_default_021','ex_default_022','ex_default_023'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      // 2. Спина и становая
      {
        'id': 'tpl_002', 'name': 'Спина и становая', 'type': 'weekly', 'category': 'back', 'recommendedLevel': 'advanced',
        'description': 'Мощная программа для развития спины. Становая тяга, подтягивания и тяги.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_008','ex_default_005','ex_default_006','ex_default_007','ex_default_035'], false],
          [2, ['ex_default_010','ex_default_011','ex_default_019','ex_default_040'], false],
          [3, ['ex_default_012','ex_default_015','ex_default_016','ex_default_042'], false],
          [4, ['ex_default_008','ex_default_005','ex_default_017','ex_default_036'], false],
          [5, ['ex_default_021','ex_default_022','ex_default_023','ex_default_038'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      // 3. Ноги и присед
      {
        'id': 'tpl_003', 'name': 'Ноги и присед', 'type': 'weekly', 'category': 'legs', 'recommendedLevel': 'intermediate',
        'description': 'Интенсивная программа для ног. Приседания, жим ногами и выпады.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_012','ex_default_013','ex_default_014','ex_default_015','ex_default_043'], false],
          [2, ['ex_default_001','ex_default_009','ex_default_017','ex_default_018'], false],
          [3, ['ex_default_012','ex_default_008','ex_default_005','ex_default_042'], false],
          [4, ['ex_default_016','ex_default_014','ex_default_024','ex_default_044'], false],
          [5, ['ex_default_021','ex_default_022','ex_default_025','ex_default_058'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      // 4. Сбалансированная (три базы)
      {
        'id': 'tpl_004', 'name': 'Сбалансированная (три базы)', 'type': 'weekly', 'category': 'balanced', 'recommendedLevel': 'advanced',
        'description': 'Жим, становая и присед в одной программе. Для продвинутых атлетов.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_001','ex_default_008','ex_default_012','ex_default_002'], false],
          [2, ['ex_default_005','ex_default_009','ex_default_017','ex_default_010'], false],
          [3, ['ex_default_020','ex_default_021','ex_default_022','ex_default_023'], false],
          [4, ['ex_default_031','ex_default_006','ex_default_042','ex_default_013'], false],
          [5, ['ex_default_006','ex_default_010','ex_default_018','ex_default_019','ex_default_022'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      // 5. Кардио и функционал
      {
        'id': 'tpl_005', 'name': 'Кардио и функционал', 'type': 'weekly', 'category': 'cardio', 'recommendedLevel': 'beginner',
        'description': 'Упор на кардио, собственный вес и бокс. Для новичков.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_024','ex_default_027','ex_default_004','ex_default_054'], false],
          [2, ['ex_default_025','ex_default_028','ex_default_021','ex_default_022'], false],
          [3, ['ex_default_026','ex_default_029','ex_default_030','ex_default_055'], false],
          [4, ['ex_default_024','ex_default_027','ex_default_020','ex_default_053'], false],
          [5, ['ex_default_030','ex_default_022','ex_default_023','ex_default_056'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      // 6. Бицепс и трицепс
      {
        'id': 'tpl_006', 'name': 'Бицепс и трицепс', 'type': 'weekly', 'category': 'arms', 'recommendedLevel': 'intermediate',
        'description': 'Специализированная программа для рук. Бицепс + трицепс 2 раза в неделю.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_017','ex_default_018','ex_default_019','ex_default_046','ex_default_047'], false],
          [2, ['ex_default_001','ex_default_005','ex_default_012','ex_default_021'], false],
          [3, ['ex_default_045','ex_default_048','ex_default_049','ex_default_050','ex_default_020'], false],
          [4, ['ex_default_009','ex_default_006','ex_default_013','ex_default_022'], false],
          [5, ['ex_default_017','ex_default_046','ex_default_018','ex_default_019'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      // 7. Плечи и трапеции
      {
        'id': 'tpl_007', 'name': 'Плечи и трапеции', 'type': 'weekly', 'category': 'shoulders', 'recommendedLevel': 'intermediate',
        'description': 'Программа для развития дельт и трапеций. Красивые плечи.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_009','ex_default_010','ex_default_011','ex_default_039','ex_default_040'], false],
          [2, ['ex_default_001','ex_default_006','ex_default_012','ex_default_021'], false],
          [3, ['ex_default_041','ex_default_010','ex_default_011','ex_default_037','ex_default_040'], false],
          [4, ['ex_default_002','ex_default_005','ex_default_013','ex_default_022'], false],
          [5, ['ex_default_039','ex_default_009','ex_default_010','ex_default_011'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      // 8. Жиросжигание
      {
        'id': 'tpl_008', 'name': 'Жиросжигание', 'type': 'weekly', 'category': 'fatLoss', 'recommendedLevel': 'intermediate',
        'description': 'Интенсивная программа для сжигания жира. Кардио + круговые тренировки.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_024','ex_default_012','ex_default_001','ex_default_021'], false],
          [2, ['ex_default_025','ex_default_006','ex_default_017','ex_default_022','ex_default_054'], false],
          [3, ['ex_default_027','ex_default_028','ex_default_020','ex_default_023','ex_default_058'], false],
          [4, ['ex_default_026','ex_default_013','ex_default_005','ex_default_021','ex_default_051'], false],
          [5, ['ex_default_024','ex_default_014','ex_default_019','ex_default_022','ex_default_053'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      // 9. Набор массы
      {
        'id': 'tpl_009', 'name': 'Набор массы', 'type': 'weekly', 'category': 'hypertrophy', 'recommendedLevel': 'advanced',
        'description': 'Программа для увеличения мышечной массы. Высокий объём и интенсивность.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_001','ex_default_002','ex_default_003','ex_default_020','ex_default_033'], false],
          [2, ['ex_default_008','ex_default_005','ex_default_006','ex_default_007','ex_default_035'], false],
          [3, ['ex_default_012','ex_default_013','ex_default_014','ex_default_015','ex_default_043'], false],
          [4, ['ex_default_031','ex_default_032','ex_default_034','ex_default_004','ex_default_020'], false],
          [5, ['ex_default_005','ex_default_036','ex_default_038','ex_default_006','ex_default_017'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      // 10. Йога и гибкость
      {
        'id': 'tpl_010', 'name': 'Йога и гибкость', 'type': 'weekly', 'category': 'yoga', 'recommendedLevel': 'beginner',
        'description': 'Комплекс на развитие гибкости и восстановление. Йога, пилатес, стретчинг.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_029','ex_default_030','ex_default_021','ex_default_022','ex_default_055'], false],
          [2, ['ex_default_056','ex_default_030','ex_default_052','ex_default_053','ex_default_051'], false],
          [3, ['ex_default_029','ex_default_030','ex_default_021','ex_default_022','ex_default_055'], false],
          [4, ['ex_default_056','ex_default_030','ex_default_052','ex_default_053','ex_default_051'], false],
          [5, ['ex_default_029','ex_default_030','ex_default_055','ex_default_056','ex_default_021'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
    ];

    for (final t in templates) {
      await db.insert('workout_templates', t);
    }
    debugPrint('✅ Добавлено ${templates.length} шаблонов программ');
  }

  List<Map<String, dynamic>> _createTemplateDays(Uuid uuid, List<List<dynamic>> daysData) {
    final result = <Map<String, dynamic>>[];
    for (final dayData in daysData) {
      final dayNumber = dayData[0] as int;
      final exerciseIds = List<String>.from(dayData[1] as List);
      final isRestDay = dayData[2] as bool;

      final exercises = exerciseIds.map((exId) {
        return {
          'id': uuid.v4(),
          'exerciseId': exId,
          'order': 0,
          'sets': [
            {'setNumber': 1, 'reps': 12, 'weight': 0.0, 'isWarmup': true, 'status': 'pending', 'rpe': null, 'notes': null, 'restSeconds': 60},
            {'setNumber': 2, 'reps': 12, 'weight': 0.0, 'isWarmup': false, 'status': 'pending', 'rpe': null, 'notes': null, 'restSeconds': 90},
            {'setNumber': 3, 'reps': 12, 'weight': 0.0, 'isWarmup': false, 'status': 'pending', 'rpe': null, 'notes': null, 'restSeconds': 90},
            {'setNumber': 4, 'reps': 10, 'weight': 0.0, 'isWarmup': false, 'status': 'pending', 'rpe': null, 'notes': null, 'restSeconds': 90},
          ],
          'groupType': 'straight',
          'restBetweenSeconds': 90,
          'notes': null,
        };
      }).toList();

      result.add({
        'id': uuid.v4(),
        'programId': '',
        'dayNumber': dayNumber,
        'date': null,
        'exercises': exercises,
        'isRestDay': isRestDay,
        'notes': null,
        'status': 'pending',
      });
    }
    return result;
  }

  // ==================== ОБЩИЕ МЕТОДЫ ====================

  Future<void> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(String table, {bool? distinct, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async {
    final db = await database;
    return await db.query(table, distinct: distinct ?? false, where: where, whereArgs: whereArgs, groupBy: groupBy, having: having, orderBy: orderBy, limit: limit, offset: offset);
  }

  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> deleteAll(String table) async {
    final db = await database;
    await db.delete(table);
  }

  Future<int> count(String table, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    final result = await db.query(table, where: where, whereArgs: whereArgs, columns: ['COUNT(*) as count']);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}