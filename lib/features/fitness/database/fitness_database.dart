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
      version: 7, // 🔥 v7: система следования программам (program_sessions)
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
      createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
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

    // 🔥 v7: Таблица сессий прохождения программ
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

    await _createIndexes(db);
    await _seedDefaultExercises(db);
    await _seedDefaultTemplates(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Миграция фитнес БД: $oldVersion → $newVersion');
    try {
      if (oldVersion < 2) {
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'");
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
          'chest': 'REAL',
          'waist': 'REAL',
          'hips': 'REAL',
          'biceps': 'REAL',
          'thigh': 'REAL',
          'calf': 'REAL',
          'neck': 'REAL',
          'forearm': 'REAL',
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
          'moodEnergy': 'INTEGER',
          'moodSleep': 'INTEGER',
          'moodMotivation': 'INTEGER',
          'moodNotes': 'TEXT',
          'workoutPhotoPath': 'TEXT',
        };

        for (final entry in newColumns.entries) {
          if (!columnNames.contains(entry.key)) {
            try {
              await db.execute(
                  'ALTER TABLE workout_logs ADD COLUMN ${entry.key} ${entry.value}');
              debugPrint('  ✅ Добавлен столбец: ${entry.key}');
            } catch (e) {
              debugPrint('  ⚠️ Ошибка добавления ${entry.key}: $e');
            }
          }
        }
      }

      // 🔥 v7: Добавляем таблицу program_sessions
      if (oldVersion < 7) {
        debugPrint('🔧 v7: Добавляем таблицу program_sessions');
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((t) => t['name'] as String).toList();

        if (!tableNames.contains('program_sessions')) {
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
            summaryData TEXT DEFAULT '{}'
          )''');
          debugPrint('  ✅ Таблица program_sessions создана');
        }
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

      // 🔥 v7: Индексы для program_sessions
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_sessions_status ON program_sessions(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_sessions_program ON program_sessions(programId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_sessions_start ON program_sessions(startDate)');
    } catch (e) {
      debugPrint('⚠️ Ошибка создания индексов фитнес: $e');
    }
  }

  // ==================== НАЧАЛЬНЫЕ УПРАЖНЕНИЯ (30 шт) ====================

  Future<void> _seedDefaultExercises(Database db) async {
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM exercises');
    if ((count.first['count'] as int) > 0) {
      debugPrint('📦 Упражнения уже есть, пропускаем');
      return;
    }
    debugPrint('🌱 Заполняем базу начальными упражнениями (30 шт)...');
    final now = DateTime.now().toIso8601String();
    final defaultExercises = [
      {'id': 'ex_default_001', 'name': 'Жим штанги лёжа', 'description': 'Классический жим лёжа на горизонтальной скамье.', 'muscleGroups': '["chest","shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Держите лопатки сведёнными', 'commonMistakes': 'Отрыв таза от скамьи', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_002', 'name': 'Жим гантелей лёжа', 'description': 'Жим гантелей на горизонтальной скамье.', 'muscleGroups': '["chest","shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'В нижней точке растягивайте грудные', 'commonMistakes': 'Слишком тяжёлый вес', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_003', 'name': 'Разведение гантелей', 'description': 'Изолированное упражнение для грудных.', 'muscleGroups': '["chest"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Сохраняйте изгиб в локтях', 'commonMistakes': 'Прямые руки', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_004', 'name': 'Отжимания от пола', 'description': 'Базовое с собственным весом.', 'muscleGroups': '["chest","shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Держите тело прямым', 'commonMistakes': 'Провисание поясницы', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_005', 'name': 'Подтягивания', 'description': 'Базовое для спины и бицепса.', 'muscleGroups': '["back","biceps","lats"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Тянитесь грудью к перекладине', 'commonMistakes': 'Раскачивание', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_006', 'name': 'Тяга штанги в наклоне', 'description': 'Мощное для толщины спины.', 'muscleGroups': '["back","lats","biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Держите спину прямой', 'commonMistakes': 'Округление спины', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_007', 'name': 'Тяга верхнего блока', 'description': 'Аналог подтягиваний.', 'muscleGroups': '["back","lats","biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Тяните к верхней части груди', 'commonMistakes': 'Отклонение корпуса', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_008', 'name': 'Становая тяга', 'description': 'Король упражнений.', 'muscleGroups': '["back","glutes","hamstrings","lowerBack","traps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Держите спину прямой', 'commonMistakes': 'Округление спины', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_009', 'name': 'Жим штанги стоя', 'description': 'Армейский жим для дельт.', 'muscleGroups': '["shoulders","triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Держите пресс напряжённым', 'commonMistakes': 'Избыточный прогиб', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_010', 'name': 'Махи гантелями в стороны', 'description': 'Изоляция для средних дельт.', 'muscleGroups': '["shoulders"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Локти чуть выше кистей', 'commonMistakes': 'Раскачивание', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_011', 'name': 'Тяга штанги к подбородку', 'description': 'Для плеч и трапеций.', 'muscleGroups': '["shoulders","traps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Тяните локти вверх', 'commonMistakes': 'Слишком узкий хват', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_012', 'name': 'Приседания со штангой', 'description': 'Базовое для ног.', 'muscleGroups': '["quadriceps","glutes","hamstrings","lowerBack"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Колени в сторону носков', 'commonMistakes': 'Отрыв пяток', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_013', 'name': 'Жим ногами', 'description': 'В тренажёре.', 'muscleGroups': '["quadriceps","glutes","hamstrings"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Не выпрямляйте колени полностью', 'commonMistakes': 'Полное выпрямление', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_014', 'name': 'Выпады с гантелями', 'description': 'Для ног и ягодиц.', 'muscleGroups': '["quadriceps","glutes","hamstrings"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Колено не выходит за носок', 'commonMistakes': 'Наклон корпуса', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_015', 'name': 'Сгибания ног в тренажёре', 'description': 'Для бицепса бедра.', 'muscleGroups': '["hamstrings"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Не отрывайте таз', 'commonMistakes': 'Рывки', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_016', 'name': 'Подъёмы на носки стоя', 'description': 'Для икроножных.', 'muscleGroups': '["calves"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Максимальная амплитуда', 'commonMistakes': 'Быстрые движения', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_017', 'name': 'Подъём штанги на бицепс', 'description': 'Классика для бицепса.', 'muscleGroups': '["biceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Локти к корпусу', 'commonMistakes': 'Читинг', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_018', 'name': 'Французский жим', 'description': 'Для трицепса.', 'muscleGroups': '["triceps"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Локти фиксированы', 'commonMistakes': 'Разведение локтей', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_019', 'name': 'Молотки', 'description': 'Нейтральный хват.', 'muscleGroups': '["biceps","forearms"]', 'imageUrl': '', 'exerciseType': 'strength', 'isCustom': 0, 'techniqueTips': 'Кисти параллельно', 'commonMistakes': 'Раскачивание', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_020', 'name': 'Отжимания на брусьях', 'description': 'Для трицепса и груди.', 'muscleGroups': '["triceps","chest","shoulders"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Не разводите локти', 'commonMistakes': 'Неполная амплитуда', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_021', 'name': 'Скручивания', 'description': 'Базовое на пресс.', 'muscleGroups': '["abs"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Поясница прижата', 'commonMistakes': 'Рывки', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_022', 'name': 'Планка', 'description': 'Статика для кора.', 'muscleGroups': '["abs","obliques","lowerBack"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Тело прямая линия', 'commonMistakes': 'Провисание', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_023', 'name': 'Подъём ног в висе', 'description': 'Для нижнего пресса.', 'muscleGroups': '["abs","obliques"]', 'imageUrl': '', 'exerciseType': 'bodyweight', 'isCustom': 0, 'techniqueTips': 'Не раскачивайтесь', 'commonMistakes': 'Раскачивание', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_024', 'name': 'Бег на дорожке', 'description': 'Кардио.', 'muscleGroups': '["cardio_vascular","quadriceps","calves"]', 'imageUrl': '', 'exerciseType': 'cardio', 'isCustom': 0, 'techniqueTips': 'Ровный темп', 'commonMistakes': 'Быстрый старт', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_025', 'name': 'Велотренажёр', 'description': 'Кардио с низкой нагрузкой.', 'muscleGroups': '["cardio_vascular","quadriceps","glutes"]', 'imageUrl': '', 'exerciseType': 'cardio', 'isCustom': 0, 'techniqueTips': 'Настройте сиденье', 'commonMistakes': 'Низкое сиденье', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_026', 'name': 'Плавание', 'description': 'Кардио на всё тело.', 'muscleGroups': '["cardio_vascular","fullBody"]', 'imageUrl': '', 'exerciseType': 'cardio', 'isCustom': 0, 'techniqueTips': 'Следите за дыханием', 'commonMistakes': 'Задержка дыхания', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_027', 'name': 'Работа на груше', 'description': 'Ударная тренировка.', 'muscleGroups': '["shoulders","back","abs","fullBody"]', 'imageUrl': '', 'exerciseType': 'boxing', 'isCustom': 0, 'techniqueTips': 'Руки у подбородка', 'commonMistakes': 'Опускание рук', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_028', 'name': 'Бой с тенью', 'description': 'Имитация боя.', 'muscleGroups': '["shoulders","fullBody","cardio_vascular"]', 'imageUrl': '', 'exerciseType': 'boxing', 'isCustom': 0, 'techniqueTips': 'Двигайтесь на носках', 'commonMistakes': 'Статичность', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_029', 'name': 'Растяжка всего тела', 'description': 'Комплекс на гибкость.', 'muscleGroups': '["flexibility","fullBody"]', 'imageUrl': '', 'exerciseType': 'yoga', 'isCustom': 0, 'techniqueTips': 'Дышите глубоко', 'commonMistakes': 'Пружинистые движения', 'createdAt': now, 'updatedAt': now},
      {'id': 'ex_default_030', 'name': 'Собака мордой вниз', 'description': 'Классическая асана.', 'muscleGroups': '["flexibility","shoulders","hamstrings","calves"]', 'imageUrl': '', 'exerciseType': 'yoga', 'isCustom': 0, 'techniqueTips': 'Пятки к полу', 'commonMistakes': 'Округление спины', 'createdAt': now, 'updatedAt': now},
    ];
    for (final exercise in defaultExercises) {
      await db.insert('exercises', exercise);
    }
    debugPrint('✅ Добавлено ${defaultExercises.length} упражнений');
  }

  // ==================== ШАБЛОНЫ ПРОГРАММ ====================

  Future<void> _seedDefaultTemplates(Database db) async {
    debugPrint('🌱 Заполняем шаблоны программ...');

    // Удаляем старые шаблоны
    await db.delete('workout_templates');

    final uuid = const Uuid();
    final templates = [
      {
        'id': 'tpl_001', 'name': 'Грудь и жим', 'type': 'weekly', 'category': 'chest', 'recommendedLevel': 'intermediate',
        'description': 'Упор на грудные мышцы и жимовые движения.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_001','ex_default_002','ex_default_003','ex_default_020'], false],
          [2, ['ex_default_005','ex_default_006','ex_default_017'], false],
          [3, ['ex_default_012','ex_default_013','ex_default_014'], false],
          [4, ['ex_default_001','ex_default_009','ex_default_018'], false],
          [5, ['ex_default_004','ex_default_021','ex_default_022'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      {
        'id': 'tpl_002', 'name': 'Спина и становая', 'type': 'weekly', 'category': 'back', 'recommendedLevel': 'intermediate',
        'description': 'Упор на спину, тяги и становую тягу.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_008','ex_default_005','ex_default_006','ex_default_007'], false],
          [2, ['ex_default_010','ex_default_011','ex_default_019'], false],
          [3, ['ex_default_012','ex_default_015','ex_default_016'], false],
          [4, ['ex_default_008','ex_default_005','ex_default_017'], false],
          [5, ['ex_default_021','ex_default_022','ex_default_023'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      {
        'id': 'tpl_003', 'name': 'Ноги и присед', 'type': 'weekly', 'category': 'legs', 'recommendedLevel': 'intermediate',
        'description': 'Упор на ноги, приседания и объём.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_012','ex_default_013','ex_default_014','ex_default_015'], false],
          [2, ['ex_default_001','ex_default_009','ex_default_017'], false],
          [3, ['ex_default_012','ex_default_008','ex_default_005'], false],
          [4, ['ex_default_016','ex_default_014','ex_default_024'], false],
          [5, ['ex_default_021','ex_default_022','ex_default_025'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      {
        'id': 'tpl_004', 'name': 'Сбалансированная (три базы)', 'type': 'weekly', 'category': 'balanced', 'recommendedLevel': 'advanced',
        'description': 'Жим, становая и присед в одной программе.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_001','ex_default_008','ex_default_012'], false],
          [2, ['ex_default_005','ex_default_009','ex_default_017'], false],
          [3, ['ex_default_020','ex_default_021','ex_default_022'], false],
          [4, ['ex_default_001','ex_default_008','ex_default_012'], false],
          [5, ['ex_default_006','ex_default_010','ex_default_018'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
      {
        'id': 'tpl_005', 'name': 'Кардио и функционал', 'type': 'weekly', 'category': 'cardio', 'recommendedLevel': 'beginner',
        'description': 'Упор на кардио, собственный вес и бокс.',
        'days': jsonEncode(_createTemplateDays(uuid, [
          [1, ['ex_default_024','ex_default_027','ex_default_004'], false],
          [2, ['ex_default_025','ex_default_028','ex_default_021'], false],
          [3, ['ex_default_026','ex_default_029'], false],
          [4, ['ex_default_024','ex_default_027','ex_default_020'], false],
          [5, ['ex_default_030','ex_default_022','ex_default_023'], false],
          [6, [], true],
          [7, [], true],
        ])),
      },
    ];
    for (final t in templates) {
      await db.insert('workout_templates', t);
    }
    debugPrint('✅ Добавлено ${templates.length} шаблонов');
  }

  /// 🔥 ИСПРАВЛЕНО: exercises теперь List<Map>, НЕ jsonEncode
  List<Map<String, dynamic>> _createTemplateDays(Uuid uuid, List<List<dynamic>> daysData) {
    final result = <Map<String, dynamic>>[];
    for (final dayData in daysData) {
      final dayNumber = dayData[0] as int;
      final exerciseIds = List<String>.from(dayData[1] as List);
      final isRestDay = dayData[2] as bool;

      // 🔥 exercises как List<Map> — БЕЗ jsonEncode!
      final exercises = exerciseIds.map((exId) {
        return {
          'id': uuid.v4(),
          'exerciseId': exId,
          'order': 0,
          'sets': [
            {'setNumber': 1, 'reps': 10, 'weight': 0.0, 'isWarmup': true, 'status': 'pending', 'rpe': null, 'notes': null},
            {'setNumber': 2, 'reps': 10, 'weight': 0.0, 'isWarmup': false, 'status': 'pending', 'rpe': null, 'notes': null},
            {'setNumber': 3, 'reps': 10, 'weight': 0.0, 'isWarmup': false, 'status': 'pending', 'rpe': null, 'notes': null},
          ],
          'groupType': 'straight',
          'restBetweenSeconds': 90,
          'notes': null,
        };
      }).toList();

      // 🔥 exercises передаётся как List, НЕ строка
      result.add({
        'id': uuid.v4(),
        'programId': '',
        'dayNumber': dayNumber,
        'date': null,
        'exercises': exercises, // ← List<Map>, НЕ jsonEncode(exercises)!
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