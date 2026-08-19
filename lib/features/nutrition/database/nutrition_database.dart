import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/nutrition_models.dart';

class NutritionDatabase {
  static final NutritionDatabase _instance = NutritionDatabase._internal();
  static Database? _database;

  NutritionDatabase._internal();
  factory NutritionDatabase() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> deleteDatabaseFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nutrition_app.db');
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
      debugPrint('✅ Все файлы БД питания очищены');
    } catch (e) {
      debugPrint('⚠️ Ошибка удаления БД питания: $e');
    }
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nutrition_app.db');
    return await openDatabase(
      path,
      version: 5, // ⬆️ v5: расширенная база продуктов (400+) и блюд (100+)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('📦 Создание БД питания версии $version');

    await db.execute('''CREATE TABLE food_products (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT DEFAULT 'other',
      calories REAL DEFAULT 0, protein REAL DEFAULT 0, fat REAL DEFAULT 0,
      carbs REAL DEFAULT 0, fiber REAL DEFAULT 0, isCustom INTEGER DEFAULT 0,
      barcode TEXT, imageUrl TEXT, isFavorite INTEGER DEFAULT 0, createdAt TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE food_diary (
      id TEXT PRIMARY KEY, date TEXT NOT NULL, mealType TEXT NOT NULL,
      productId TEXT NOT NULL, grams REAL NOT NULL, calories REAL DEFAULT 0,
      protein REAL DEFAULT 0, fat REAL DEFAULT 0, carbs REAL DEFAULT 0,
      time TEXT, note TEXT, createdAt TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE meal_templates (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, items TEXT DEFAULT '[]', createdAt TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE nutrition_goals (
      id TEXT PRIMARY KEY, date TEXT, calories REAL DEFAULT 0, protein REAL DEFAULT 0,
      fat REAL DEFAULT 0, carbs REAL DEFAULT 0, waterMl INTEGER DEFAULT 2000,
      isActive INTEGER DEFAULT 1, createdAt TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE water_entries (
      id TEXT PRIMARY KEY, date TEXT NOT NULL, amountMl INTEGER NOT NULL,
      time TEXT, createdAt TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE user_profile (
      id TEXT PRIMARY KEY,
      createdAt TEXT NOT NULL,
      gender TEXT NOT NULL,
      age INTEGER NOT NULL,
      weight REAL NOT NULL,
      height REAL NOT NULL,
      activityLevel TEXT NOT NULL,
      goalType TEXT NOT NULL,
      goalPace TEXT NOT NULL,
      targetWeight REAL,
      targetDays INTEGER,
      stepsPerDay INTEGER DEFAULT 5000,
      workoutsPerWeek INTEGER DEFAULT 0,
      bodyFatPercentage REAL DEFAULT 0
    )''');

    await _createIndexes(db);
    await _seedDefaultProducts(db);
    await _seedDefaultTemplates(db);
    await _seedDefaultGoals(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Миграция БД питания: $oldVersion → $newVersion');

    if (oldVersion < 2) {
      debugPrint('🔧 v2: пересоздаём продукты и шаблоны');
      await db.delete('food_products');
      await db.delete('meal_templates');
      await _seedDefaultProducts(db);
      await _seedDefaultTemplates(db);
    }

    if (oldVersion < 3) {
      debugPrint('🔧 v3: добавляем новые готовые блюда');
      await _addNewTemplates(db);
    }

    if (oldVersion < 4) {
      debugPrint('🔧 v4: добавляем яйца (C0, C1, C2, C3) и перепелиные');
      await _addNewProducts(db);
    }

    if (oldVersion < 5) {
      debugPrint('🔧 v5: добавляем новые продукты и блюда');
      await _addMoreProducts(db);
      await _addMoreTemplates(db);
    }

    // Создаём таблицу профиля если её нет
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        gender TEXT NOT NULL,
        age INTEGER NOT NULL,
        weight REAL NOT NULL,
        height REAL NOT NULL,
        activityLevel TEXT NOT NULL,
        goalType TEXT NOT NULL,
        goalPace TEXT NOT NULL,
        targetWeight REAL,
        targetDays INTEGER,
        stepsPerDay INTEGER DEFAULT 5000,
        workoutsPerWeek INTEGER DEFAULT 0,
        bodyFatPercentage REAL DEFAULT 0
      )''');
    } catch (e) {
      debugPrint('⚠️ Таблица user_profile уже существует');
    }

    await _createIndexes(db);
  }

  Future<void> _addNewProducts(Database db) async {
    final existing = await db.query('food_products');
    final existingNames = existing.map((e) => e['name'] as String).toSet();

    final newProducts = [
      ['Яйцо куриное C0', 'dairy', 155, 13, 11, 1.1, 0],
      ['Яйцо куриное C1', 'dairy', 150, 12.5, 10.5, 1.0, 0],
      ['Яйцо куриное C2', 'dairy', 145, 12, 10, 0.9, 0],
      ['Яйцо куриное C3', 'dairy', 140, 11.5, 9.5, 0.8, 0],
      ['Яйцо перепелиное', 'dairy', 168, 12, 11, 0.5, 0],
    ];

    int addedCount = 0;
    final uuid = const Uuid();
    final now = DateTime.now().toIso8601String();

    for (final p in newProducts) {
      if (!existingNames.contains(p[0])) {
        await db.insert('food_products', {
          'id': uuid.v4(),
          'name': p[0],
          'category': p[1],
          'calories': (p[2] as num).toDouble(),
          'protein': (p[3] as num).toDouble(),
          'fat': (p[4] as num).toDouble(),
          'carbs': (p[5] as num).toDouble(),
          'fiber': (p[6] as num).toDouble(),
          'isCustom': 0,
          'createdAt': now,
        });
        addedCount++;
      }
    }
    debugPrint('✅ Добавлено новых продуктов: $addedCount (яйца)');
  }

  Future<void> _addMoreProducts(Database db) async {
    final existing = await db.query('food_products');
    final existingNames = existing.map((e) => e['name'] as String).toSet();

    final newProducts = [
      // 🌾 ДОПОЛНИТЕЛЬНЫЕ КРУПЫ
      ['Полба варёная', 'grains', 127, 5.5, 0.8, 26, 3.5],
      ['Спельта варёная', 'grains', 132, 5.0, 0.9, 27, 4.0],
      ['Амарант варёный', 'grains', 102, 3.8, 1.6, 19, 2.1],
      ['Тефф варёный', 'grains', 101, 3.9, 0.7, 20, 2.0],
      ['Сорго варёный', 'grains', 116, 3.3, 1.2, 24, 2.5],
      ['Ячмень варёный', 'grains', 123, 2.3, 0.4, 28, 3.5],
      ['Овсяные отруби', 'grains', 246, 17, 7, 66, 15],
      ['Пшеничные отруби', 'grains', 216, 16, 4.3, 64, 42],
      ['Рисовая мука', 'grains', 366, 6, 1.4, 80, 2.4],
      ['Кукурузная мука', 'grains', 364, 7, 3.9, 76, 7.3],
      ['Гречневая мука', 'grains', 343, 13, 3.4, 72, 10],
      ['Овсяная мука', 'grains', 404, 14, 9, 68, 8],
      ['Нутовая мука', 'grains', 387, 22, 6.7, 58, 10],
      ['Чечевичная мука', 'grains', 353, 25, 1.1, 63, 8],
      ['Киноа мука', 'grains', 374, 14, 6, 64, 7],
      ['Кус-кус сухой', 'grains', 376, 13, 0.6, 77, 5],
      ['Булгур сухой', 'grains', 342, 12, 1.3, 70, 18],
      ['Макароны цельнозерновые', 'grains', 124, 5.3, 1.4, 24, 3.8],
      ['Спагетти варёные', 'grains', 158, 5.8, 0.9, 31, 1.8],
      ['Лапша рисовая варёная', 'grains', 109, 1.6, 0.2, 25, 0.8],
      ['Лапша гречневая варёная', 'grains', 99, 3.8, 0.3, 21, 1.3],
      ['Хлеб ржаной', 'grains', 210, 6.5, 1.2, 42, 6.5],
      ['Хлеб с отрубями', 'grains', 220, 11, 3.5, 38, 8],
      ['Хлеб безглютеновый', 'grains', 230, 4, 3, 45, 4],
      ['Хлеб кукурузный', 'grains', 265, 6, 3, 55, 5],
      ['Хлеб картофельный', 'grains', 248, 5, 2, 52, 3],
      ['Лаваш тонкий', 'grains', 220, 7.5, 1, 45, 2],
      ['Тортилья кукурузная', 'grains', 218, 5.7, 2.8, 44, 6],
      ['Тортилья пшеничная', 'grains', 300, 8, 7, 50, 4],
      ['Крекеры', 'grains', 450, 10, 15, 70, 3],
      ['Хлебцы гречневые', 'grains', 310, 12, 3, 62, 14],
      ['Хлебцы пшеничные', 'grains', 320, 11, 2, 68, 8],

      // 🥩 ДОПОЛНИТЕЛЬНОЕ МЯСО
      ['Гусь', 'meat', 371, 15, 33, 0, 0],
      ['Перепел', 'meat', 192, 21, 11, 0, 0],
      ['Свиной язык', 'meat', 228, 16, 17, 0, 0],
      ['Свиные уши', 'meat', 330, 22, 26, 0, 0],
      ['Свиные ножки', 'meat', 275, 20, 21, 0, 0],
      ['Бастурма', 'meat', 215, 28, 10, 0, 0],
      ['Суджук', 'meat', 280, 22, 20, 3, 0],
      ['Салями', 'meat', 350, 22, 28, 2, 0],
      ['Балык', 'meat', 194, 24, 10, 0, 0],
      ['Карбонад', 'meat', 210, 25, 12, 0, 0],
      ['Шейка свиная', 'meat', 290, 17, 24, 0, 0],
      ['Лопатка свиная', 'meat', 270, 20, 20, 0, 0],
      ['Окорок свиной', 'meat', 260, 21, 18, 0, 0],
      ['Грудинка свиная', 'meat', 420, 14, 40, 0, 0],
      ['Ребрышки свиные', 'meat', 320, 18, 27, 0, 0],
      ['Вырезка телячья', 'meat', 110, 21, 2.5, 0, 0],
      ['Телятина', 'meat', 130, 20, 5, 0, 0],
      ['Конина', 'meat', 143, 20, 7, 0, 0],
      ['Оленина', 'meat', 120, 22, 3.5, 0, 0],
      ['Мясо страуса', 'meat', 130, 22, 4, 0, 0],
      ['Фарш свиной', 'meat', 263, 16, 21, 0, 0],
      ['Фарш индюшиный', 'meat', 165, 18, 10, 0, 0],
      ['Фарш смешанный', 'meat', 235, 17, 18, 0, 0],
      ['Колбаса докторская', 'meat', 257, 13, 22, 1.5, 0],
      ['Колбаса любительская', 'meat', 301, 12, 27, 1.5, 0],
      ['Колбаса молочная', 'meat', 252, 11, 22, 2, 0],
      ['Колбаса сервелат', 'meat', 360, 15, 32, 2, 0],
      ['Колбаса краковская', 'meat', 310, 13, 28, 1.5, 0],
      ['Сосиски молочные', 'meat', 261, 10, 23, 4, 0],
      ['Сардельки', 'meat', 250, 11, 22, 3, 0],
      ['Шпикачки', 'meat', 300, 9, 28, 2, 0],
      ['Ветчина из индейки', 'meat', 120, 16, 5, 1.5, 0],
      ['Ветчина варёная', 'meat', 145, 18, 7, 1.5, 0],
      ['Ветчина копчёная', 'meat', 170, 16, 11, 1, 0],

      // 🐟 ДОПОЛНИТЕЛЬНАЯ РЫБА
      ['Палтус', 'fish', 186, 19, 12, 0, 0],
      ['Макрель', 'fish', 262, 18, 21, 0, 0],
      ['Кижуч', 'fish', 140, 21, 6, 0, 0],
      ['Нерка', 'fish', 152, 20, 8, 0, 0],
      ['Чавыча', 'fish', 148, 20, 7, 0, 0],
      ['Кета', 'fish', 127, 19, 5.5, 0, 0],
      ['Голец', 'fish', 135, 20, 6, 0, 0],
      ['Хариус', 'fish', 88, 17, 2, 0, 0],
      ['Ленок', 'fish', 93, 18, 2.2, 0, 0],
      ['Таймень', 'fish', 110, 19, 3.5, 0, 0],
      ['Щука', 'fish', 84, 18, 1, 0, 0],
      ['Жерех', 'fish', 86, 19, 0.7, 0, 0],
      ['Лещ', 'fish', 105, 17, 4, 0, 0],
      ['Карп', 'fish', 112, 16, 5, 0, 0],
      ['Сазан', 'fish', 97, 18, 2.5, 0, 0],
      ['Линь', 'fish', 88, 18, 1.5, 0, 0],
      ['Налим', 'fish', 79, 18, 0.8, 0, 0],
      ['Пикша', 'fish', 74, 17, 0.5, 0, 0],
      ['Мерланг', 'fish', 78, 18, 0.6, 0, 0],
      ['Мойва', 'fish', 118, 13, 7, 0, 0],
      ['Корюшка', 'fish', 112, 15, 5.5, 0, 0],
      ['Ряпушка', 'fish', 74, 16, 0.9, 0, 0],
      ['Снеток', 'fish', 82, 18, 1, 0, 0],
      ['Тунец консервированный', 'fish', 128, 28, 1.5, 0, 0],
      ['Сардины консервированные', 'fish', 208, 24, 11, 0, 0],
      ['Шпроты', 'fish', 362, 17, 32, 0, 0],
      ['Килька', 'fish', 137, 15, 8, 0, 0],
      ['Анчоусы', 'fish', 210, 20, 14, 0, 0],
      ['Угорь', 'fish', 262, 18, 21, 0, 0],
      ['Морской язык', 'fish', 91, 18, 1.8, 0, 0],
      ['Морской окунь', 'fish', 103, 18, 3, 0, 0],
      ['Зубатка', 'fish', 126, 18, 6, 0, 0],
      ['Луфарь', 'fish', 116, 20, 3.5, 0, 0],
      ['Барабулька', 'fish', 117, 19, 4, 0, 0],
      ['Кефаль', 'fish', 117, 19, 4, 0, 0],
      ['Пеламида', 'fish', 158, 20, 8, 0, 0],
      ['Ставрида', 'fish', 114, 19, 4, 0, 0],
      ['Сайра', 'fish', 213, 18, 15, 0, 0],

      // 🥛 ДОПОЛНИТЕЛЬНАЯ МОЛОЧКА
      ['Сливки 10%', 'dairy', 118, 2.8, 10, 4, 0],
      ['Сливки 20%', 'dairy', 206, 2.5, 20, 3.4, 0],
      ['Сливки 30%', 'dairy', 296, 2.2, 30, 3.4, 0],
      ['Сливки 35%', 'dairy', 345, 2.1, 35, 3.4, 0],
      ['Молоко топлёное', 'dairy', 84, 3, 4, 4.7, 0],
      ['Молоко козье', 'dairy', 68, 3.3, 4.2, 4.5, 0],
      ['Молоко овечье', 'dairy', 108, 5.5, 7, 5, 0],
      ['Кумыс', 'dairy', 50, 2.1, 1.9, 5, 0],
      ['Айран', 'dairy', 25, 1.5, 0.5, 4, 0],
      ['Тан', 'dairy', 30, 1.5, 0.5, 5, 0],
      ['Снежок', 'dairy', 80, 3, 3, 10, 0],
      ['Варенец', 'dairy', 53, 2.9, 2.5, 4.2, 0],
      ['Простокваша', 'dairy', 52, 2.9, 2.5, 4.2, 0],
      ['Масло сливочное 82.5%', 'dairy', 748, 0.8, 82.5, 0.8, 0],
      ['Масло топлёное', 'dairy', 876, 0.3, 99, 0, 0],
      ['Сыр рикотта', 'dairy', 174, 11, 13, 3, 0],
      ['Сыр маскарпоне', 'dairy', 429, 4, 43, 2.5, 0],
      ['Сыр гауда', 'dairy', 356, 25, 27, 2, 0],
      ['Сыр эдам', 'dairy', 330, 25, 24, 2, 0],
      ['Сыр горгонзола', 'dairy', 353, 21, 29, 1.5, 0],
      ['Сыр дор блю', 'dairy', 353, 21, 29, 1.5, 0],
      ['Сыр рокфор', 'dairy', 369, 22, 30, 1.5, 0],
      ['Сыр камамбер', 'dairy', 300, 20, 24, 1.5, 0],
      ['Сыр бри', 'dairy', 334, 21, 27, 1.5, 0],
      ['Сыр сулугуни', 'dairy', 285, 20, 22, 1, 0],
      ['Сыр чечил', 'dairy', 290, 19, 23, 1, 0],
      ['Сыр косичка', 'dairy', 295, 19, 23, 1, 0],
      ['Сыр халуми', 'dairy', 310, 22, 24, 2, 0],
      ['Сыр фетаки', 'dairy', 264, 14, 21, 4, 0],
      ['Творожный сыр', 'dairy', 120, 8, 9, 3, 0],
      ['Плавленый сыр 50%', 'dairy', 257, 21, 23, 2, 0],
      ['Плавленый сыр 30%', 'dairy', 190, 15, 12, 8, 0],
      ['Сметана 10%', 'dairy', 115, 2.6, 10, 3, 0],
      ['Сметана 25%', 'dairy', 247, 2.4, 25, 3.4, 0],
      ['Сметана 30%', 'dairy', 296, 2.3, 30, 3.4, 0],
      ['Сметана 40%', 'dairy', 395, 2.2, 40, 3.4, 0],
      ['Йогурт питьевой', 'dairy', 75, 3, 2.5, 10, 0],
      ['Йогурт с наполнителем', 'dairy', 85, 3, 2.8, 12, 0],
      ['Йогурт домашний', 'dairy', 62, 4.5, 3.2, 3.5, 0],

      // 🥬 ДОПОЛНИТЕЛЬНЫЕ ОВОЩИ
      ['Спаржа', 'vegetables', 20, 2.2, 0.1, 3.9, 2.1],
      ['Артишок', 'vegetables', 47, 3.3, 0.2, 11, 5.4],
      ['Топинамбур', 'vegetables', 73, 2, 0.1, 17, 1.6],
      ['Пастернак', 'vegetables', 75, 1.2, 0.3, 18, 4.9],
      ['Корень сельдерея', 'vegetables', 42, 1.5, 0.3, 9.2, 3.1],
      ['Петрушка корневая', 'vegetables', 47, 3.7, 0.8, 7.6, 3.3],
      ['Хрен', 'vegetables', 48, 2.4, 0.4, 11, 3.2],
      ['Редька', 'vegetables', 21, 1.2, 0.1, 4.1, 1.6],
      ['Репа', 'vegetables', 28, 0.9, 0.1, 6, 1.8],
      ['Брюква', 'vegetables', 38, 1.2, 0.1, 8, 2.3],
      ['Свекла листовая', 'vegetables', 19, 2.2, 0.2, 3.7, 1.5],
      ['Мангольд', 'vegetables', 19, 1.8, 0.2, 3.7, 1.6],
      ['Крапива', 'vegetables', 42, 3.5, 0.5, 7, 6.5],
      ['Щавель', 'vegetables', 22, 1.5, 0.3, 2.9, 2.9],
      ['Шпинат молодой', 'vegetables', 23, 2.9, 0.4, 3.6, 2.2],
      ['Рукола молодая', 'vegetables', 25, 2.6, 0.7, 3.7, 1.6],
      ['Кресс-салат', 'vegetables', 32, 2.6, 0.7, 5.5, 1.1],
      ['Латук', 'vegetables', 15, 1.4, 0.2, 2.9, 1.5],
      ['Радиччио', 'vegetables', 23, 1.4, 0.2, 4.5, 0.9],
      ['Эндивий', 'vegetables', 17, 1.3, 0.2, 3.4, 3.1],
      ['Фенхель', 'vegetables', 31, 1.2, 0.2, 7, 3.1],
      ['Лук-порей', 'vegetables', 36, 1.5, 0.3, 8, 1.8],
      ['Лук-шалот', 'vegetables', 72, 2.5, 0.1, 17, 3.2],
      ['Лук зеленый', 'vegetables', 32, 1.3, 0.1, 6.5, 1.8],
      ['Чеснок молодой', 'vegetables', 149, 6.4, 0.5, 33, 2.1],
      ['Стручковая фасоль', 'vegetables', 31, 1.8, 0.1, 7, 2.5],
      ['Горошек зелёный', 'vegetables', 81, 5.4, 0.4, 14, 5.7],
      ['Кукуруза сахарная', 'vegetables', 86, 3.2, 1.2, 19, 2.4],
      ['Перец чили', 'vegetables', 40, 1.8, 0.4, 8.8, 1.5],
      ['Перец сладкий красный', 'vegetables', 31, 1, 0.3, 6, 2.1],
      ['Перец сладкий жёлтый', 'vegetables', 27, 1, 0.2, 6.3, 1.8],
      ['Перец сладкий зелёный', 'vegetables', 20, 0.9, 0.2, 4.6, 1.7],
      ['Баклажан', 'vegetables', 25, 1, 0.2, 6, 3],
      ['Тыква мускатная', 'vegetables', 45, 1, 0.1, 12, 2],
      ['Тыква обыкновенная', 'vegetables', 26, 1, 0.1, 6.5, 0.5],
      ['Кабачок', 'vegetables', 17, 1.2, 0.3, 3.1, 1],
      ['Патиссон', 'vegetables', 19, 0.6, 0.1, 4.3, 0.9],
      ['Огурец корнишон', 'vegetables', 15, 0.8, 0.1, 3.6, 0.5],
      ['Огурец парниковый', 'vegetables', 14, 0.7, 0.1, 2.8, 0.7],
      ['Помидоры черри', 'vegetables', 18, 0.9, 0.2, 3.9, 1.2],
      ['Помидоры жёлтые', 'vegetables', 15, 0.9, 0.2, 3, 1.2],
      ['Томаты вяленые', 'vegetables', 258, 4, 2, 56, 8],
      ['Картофель молодой', 'vegetables', 77, 2, 0.4, 16, 1.8],
      ['Картофель красный', 'vegetables', 87, 2, 0.4, 17, 1.8],
      ['Батат оранжевый', 'vegetables', 86, 1.6, 0.1, 20, 3],
      ['Батат фиолетовый', 'vegetables', 90, 1.7, 0.1, 21, 3.2],

      // 🍎 ДОПОЛНИТЕЛЬНЫЕ ФРУКТЫ
      ['Папайя', 'fruits', 43, 0.5, 0.3, 11, 1.7],
      ['Гуава', 'fruits', 68, 2.6, 1, 14, 5.4],
      ['Маракуйя', 'fruits', 97, 2.2, 0.7, 23, 10.4],
      ['Фейхоа', 'fruits', 49, 1, 0.6, 11, 6.4],
      ['Хурма', 'fruits', 70, 0.6, 0.3, 18, 3.6],
      ['Кумкват', 'fruits', 71, 1.9, 0.9, 16, 6.5],
      ['Лайм', 'fruits', 30, 0.7, 0.2, 11, 2.8],
      ['Помело', 'fruits', 38, 0.8, 0.1, 10, 1],
      ['Свити', 'fruits', 43, 0.8, 0.1, 11, 1],
      ['Угли', 'fruits', 45, 0.8, 0.1, 11, 1.2],
      ['Мандарин', 'fruits', 53, 0.8, 0.3, 13, 1.8],
      ['Клементин', 'fruits', 47, 0.8, 0.2, 12, 1.7],
      ['Гранат', 'fruits', 83, 1.7, 1.2, 19, 4],
      ['Рамбутан', 'fruits', 84, 0.9, 0.4, 21, 0.9],
      ['Личи', 'fruits', 66, 0.8, 0.4, 16, 1.3],
      ['Лонган', 'fruits', 60, 1.3, 0.1, 15, 1.1],
      ['Джекфрут', 'fruits', 95, 1.7, 0.6, 23, 1.5],
      ['Дуриан', 'fruits', 147, 1.5, 5.3, 27, 3.8],
      ['Мангустин', 'fruits', 73, 0.4, 0.6, 18, 0.5],
      ['Сахарное яблоко', 'fruits', 94, 2.1, 0.3, 24, 4.4],
      ['Черимойя', 'fruits', 75, 1.6, 0.6, 18, 3.3],
      ['Сметанное яблоко', 'fruits', 66, 1, 0.3, 17, 3.3],
      ['Старфрут', 'fruits', 31, 1, 0.3, 7, 2.8],
      ['Карамбола', 'fruits', 31, 1, 0.3, 7, 2.8],
      ['Питахайя', 'fruits', 60, 1.2, 0.4, 13, 0.9],
      ['Кивано', 'fruits', 44, 2, 1, 7, 3],
      ['Пепино', 'fruits', 35, 1, 0.2, 8, 0.3],
      ['Томатильо', 'fruits', 32, 1, 1, 6, 1.9],
      ['Аки', 'fruits', 151, 2, 7, 20, 2],
      ['Саподилла', 'fruits', 83, 0.4, 0.5, 20, 5.3],
      ['Салак', 'fruits', 82, 1, 0.4, 21, 3.5],
      ['Момордика', 'fruits', 17, 1, 0.2, 3, 2],

      // 🥜 ДОПОЛНИТЕЛЬНЫЕ ОРЕХИ
      ['Макадамия', 'nuts', 718, 8, 76, 14, 9],
      ['Пекан', 'nuts', 691, 9, 72, 14, 10],
      ['Бразильский орех', 'nuts', 659, 14, 66, 12, 7.5],
      ['Орех кола', 'nuts', 550, 8, 30, 50, 10],
      ['Орех пили', 'nuts', 720, 10, 75, 10, 8],
      ['Орех чёрный', 'nuts', 619, 24, 59, 9, 6],
      ['Орех гикори', 'nuts', 691, 9, 72, 14, 10],
      ['Буковый орех', 'nuts', 576, 21, 50, 18, 5],
      ['Каштан сладкий', 'nuts', 213, 2.4, 2.3, 46, 3.4],
      ['Каштан японский', 'nuts', 200, 2.2, 2, 44, 3],
      ['Миндаль сладкий', 'nuts', 579, 21, 50, 22, 12],
      ['Миндаль горький', 'nuts', 579, 21, 50, 22, 12],
      ['Арахис сырой', 'nuts', 567, 26, 49, 16, 8],
      ['Арахис жареный', 'nuts', 585, 26, 52, 14, 8],
      ['Фисташки жареные', 'nuts', 572, 20, 46, 28, 10],
      ['Кешью жареные', 'nuts', 574, 18, 46, 30, 3.3],
      ['Грецкий орех зелёный', 'nuts', 340, 15, 35, 12, 4],
      ['Фундук жареный', 'nuts', 628, 15, 61, 17, 9.7],
      ['Ореховая паста', 'nuts', 590, 15, 55, 20, 6],
      ['Урбеч', 'nuts', 590, 15, 55, 20, 6],

      // 🌱 ДОПОЛНИТЕЛЬНЫЕ СЕМЕНА
      ['Семена конопли', 'seeds', 553, 25, 48, 8, 28],
      ['Семена мака', 'seeds', 525, 18, 42, 28, 20],
      ['Семена горчицы', 'seeds', 508, 26, 36, 28, 12],
      ['Семена тмина', 'seeds', 375, 17, 15, 50, 38],
      ['Семена укропа', 'seeds', 305, 15, 15, 40, 30],
      ['Семена аниса', 'seeds', 337, 18, 16, 50, 35],
      ['Семена фенхеля', 'seeds', 345, 16, 15, 52, 40],
      ['Семена сельдерея', 'seeds', 392, 18, 25, 41, 28],

      // 🫘 ДОПОЛНИТЕЛЬНЫЕ БОБОВЫЕ
      ['Маш', 'legumes', 129, 8, 0.5, 24, 5.8],
      ['Адзуки', 'legumes', 128, 7.5, 0.1, 25, 4.5],
      ['Вигна', 'legumes', 132, 8, 0.3, 24, 5],
      ['Бобы', 'legumes', 109, 7, 0.5, 20, 5],
      ['Бобы чёрные', 'legumes', 132, 9, 0.5, 23, 8.7],
      ['Бобы белые', 'legumes', 129, 9, 0.5, 23, 6.5],
      ['Бобы красные', 'legumes', 127, 8.7, 0.5, 22, 6.4],
      ['Нут чёрный', 'legumes', 164, 8.9, 2.6, 27, 7.6],
      ['Фасоль пинто', 'legumes', 114, 7, 0.5, 20, 6],
      ['Фасоль мунг', 'legumes', 127, 7, 0.5, 23, 5.5],
      ['Чечевица красная', 'legumes', 116, 9, 0.4, 20, 7.9],
      ['Чечевица зелёная', 'legumes', 116, 9, 0.4, 20, 7.9],
      ['Чечевица чёрная', 'legumes', 116, 9, 0.4, 20, 7.9],
      ['Чечевица французская', 'legumes', 116, 9, 0.4, 20, 7.9],
      ['Тофу твёрдый', 'legumes', 145, 15, 8, 3.5, 1],
      ['Тофу мягкий', 'legumes', 76, 8, 4.8, 1.9, 0.3],
      ['Тофу копчёный', 'legumes', 105, 10, 6, 2.5, 0.5],
      ['Темпе', 'legumes', 193, 19, 11, 9, 6],
      ['Натто', 'legumes', 200, 17, 9, 12, 8],
      ['Эдамаме варёные', 'legumes', 122, 11, 5, 9, 5.2],
      ['Бобовая паста', 'legumes', 250, 12, 5, 45, 10],

      // 🧂 ДОПОЛНИТЕЛЬНЫЕ СОУСЫ
      ['Соус песто красный', 'sauces', 200, 3, 18, 8, 2],
      ['Соус тартар', 'sauces', 390, 1, 42, 2, 0],
      ['Соус горчичный', 'sauces', 145, 4, 8, 15, 2],
      ['Соус барбекю сладкий', 'sauces', 215, 1, 0.5, 52, 1],
      ['Соус карри', 'sauces', 180, 2, 10, 20, 3],
      ['Соус устричный', 'sauces', 65, 3, 0.5, 13, 0.5],
      ['Соус рыбовый', 'sauces', 50, 4, 0.5, 8, 0],
      ['Соус вустерский', 'sauces', 70, 2, 0, 15, 0],
      ['Соус чили', 'sauces', 70, 1, 0.5, 15, 1],
      ['Аджика', 'sauces', 60, 1.5, 0.5, 12, 2],
      ['Ткемали', 'sauces', 70, 1, 1, 15, 2],
      ['Сацибели', 'sauces', 80, 2, 3, 12, 2],
      ['Наршараб', 'sauces', 210, 0.5, 0, 55, 0.5],
      ['Бальзамический уксус', 'sauces', 80, 0, 0, 20, 0],
      ['Яблочный уксус', 'sauces', 15, 0, 0, 4, 0],
      ['Винный уксус', 'sauces', 20, 0, 0, 5, 0],
      ['Рисовый уксус', 'sauces', 20, 0, 0, 5, 0],
      ['Имбирь маринованный', 'sauces', 20, 0.5, 0.1, 4.5, 0.3],
      ['Васаби', 'sauces', 55, 1.5, 0.5, 12, 2],
      ['Хрен столовый', 'sauces', 48, 2.4, 0.4, 11, 3.2],

      // ☕ ДОПОЛНИТЕЛЬНЫЕ НАПИТКИ
      ['Матча', 'drinks', 3, 0.6, 0, 0.5, 0.1],
      ['Ройбуш', 'drinks', 1, 0.1, 0, 0.1, 0],
      ['Каркаде', 'drinks', 1, 0.1, 0, 0.1, 0],
      ['Молочный улун', 'drinks', 1, 0.1, 0, 0.1, 0],
      ['Пуэр', 'drinks', 1, 0.1, 0, 0.1, 0],
      ['Сок гранатовый', 'drinks', 60, 0.2, 0.2, 14, 0.1],
      ['Сок морковный', 'drinks', 40, 1, 0.1, 9, 0.3],
      ['Сок свекольный', 'drinks', 42, 1, 0.1, 10, 0.5],
      ['Сок тыквенный', 'drinks', 35, 0.5, 0.1, 8, 0.2],
      ['Сок томатный', 'drinks', 17, 0.9, 0.1, 3.8, 0.4],
      ['Сок сельдерея', 'drinks', 16, 0.9, 0.2, 3, 1.6],
      ['Сок лимона', 'drinks', 29, 1.1, 0.3, 9, 2.8],
      ['Сок лайма', 'drinks', 30, 0.7, 0.2, 11, 2.8],
      ['Сок клюквы', 'drinks', 46, 0.4, 0.1, 12, 0.5],
      ['Морс клюквенный', 'drinks', 30, 0.2, 0.1, 8, 0.2],
      ['Компот из сухофруктов', 'drinks', 60, 0.3, 0.1, 15, 0.5],
      ['Кисель', 'drinks', 80, 0.5, 0, 20, 0.5],
      ['Морс ягодный', 'drinks', 35, 0.2, 0.1, 9, 0.2],
      ['Шиповник настой', 'drinks', 15, 0.3, 0, 3.5, 0.5],
      ['Зелёный смузи', 'drinks', 35, 1.5, 0.5, 7, 2],

      // 🍫 ДОПОЛНИТЕЛЬНЫЕ СЛАДОСТИ
      ['Мёд гречишный', 'sweets', 309, 0.3, 0, 83, 0.2],
      ['Мёд акациевый', 'sweets', 304, 0.3, 0, 82, 0.2],
      ['Мёд липовый', 'sweets', 320, 0.3, 0, 80, 0.2],
      ['Мёд горный', 'sweets', 310, 0.3, 0, 82, 0.2],
      ['Сироп кленовый', 'sweets', 260, 0, 0, 67, 0],
      ['Сироп агавы', 'sweets', 310, 0, 0, 76, 0],
      ['Сироп топинамбура', 'sweets', 267, 0, 0, 70, 0],
      ['Финиковая паста', 'sweets', 282, 2.5, 0.4, 75, 7],
      ['Инжир сушёный', 'sweets', 249, 3.3, 0.9, 63, 9.8],
      ['Курага', 'sweets', 241, 3.4, 0.5, 63, 7.3],
      ['Чернослив', 'sweets', 240, 2.3, 0.4, 63, 7.1],
      ['Изюм светлый', 'sweets', 299, 3.1, 0.5, 79, 3.7],
      ['Изюм тёмный', 'sweets', 290, 3, 0.5, 77, 3.7],
      ['Цукаты', 'sweets', 300, 0.5, 0.3, 78, 2],
      ['Мармелад желейный', 'sweets', 293, 0.1, 0, 77, 0.5],
      ['Мармелад фруктовый', 'sweets', 280, 0.2, 0, 72, 1],
      ['Зефир ванильный', 'sweets', 326, 0.8, 0.1, 80, 0.5],
      ['Зефир шоколадный', 'sweets', 350, 1, 5, 78, 0.5],
      ['Пастила', 'sweets', 310, 0.5, 0.1, 78, 0.5],
      ['Нуга', 'sweets', 380, 5, 10, 70, 1],
      ['Халва подсолнечная', 'sweets', 516, 12, 30, 54, 4],
      ['Халва тахинная', 'sweets', 500, 15, 28, 50, 5],
      ['Козинак', 'sweets', 520, 15, 30, 50, 5],
      ['Чурчхела', 'sweets', 400, 5, 10, 75, 2],
      ['Леденец', 'sweets', 380, 0, 0, 95, 0],
      ['Ирис', 'sweets', 380, 3, 10, 75, 0.5],
      ['Карамель', 'sweets', 380, 0, 0, 95, 0],
      ['Шоколад белый', 'sweets', 539, 6, 32, 59, 0.1],
      ['Шоколад с орехами', 'sweets', 550, 8, 35, 50, 5],
      ['Шоколад с изюмом', 'sweets', 520, 7, 30, 55, 4],
      ['Шоколад пористый', 'sweets', 520, 6, 28, 60, 2],
      ['Батончик мюсли', 'sweets', 380, 8, 12, 60, 5],
      ['Батончик протеиновый', 'sweets', 350, 30, 12, 35, 3],
      ['Пряники', 'sweets', 360, 5, 5, 75, 2],
      ['Коврижка', 'sweets', 350, 4, 6, 72, 2],
      ['Сухарики', 'sweets', 370, 10, 5, 72, 3],
      ['Бублики', 'sweets', 250, 8, 1.5, 50, 2],
      ['Сушки', 'sweets', 250, 8, 1.5, 50, 2],
      ['Баранки', 'sweets', 250, 8, 1.5, 50, 2],
      ['Кекс', 'sweets', 380, 5, 18, 50, 1.5],
      ['Маффин шоколадный', 'sweets', 400, 5, 20, 50, 1.5],
      ['Капкейк', 'sweets', 380, 4, 18, 52, 1],
    ];

    int addedCount = 0;
    final uuid = const Uuid();
    final now = DateTime.now().toIso8601String();

    for (final p in newProducts) {
      if (!existingNames.contains(p[0])) {
        await db.insert('food_products', {
          'id': uuid.v4(),
          'name': p[0],
          'category': p[1],
          'calories': (p[2] as num).toDouble(),
          'protein': (p[3] as num).toDouble(),
          'fat': (p[4] as num).toDouble(),
          'carbs': (p[5] as num).toDouble(),
          'fiber': (p[6] as num).toDouble(),
          'isCustom': 0,
          'createdAt': now,
        });
        addedCount++;
      }
    }
    debugPrint('✅ Добавлено новых продуктов: $addedCount (v5)');
  }

  Future<void> _addMoreTemplates(Database db) async {
    final existing = await db.query('meal_templates');
    final existingNames = existing.map((e) => e['name'] as String).toSet();

    final newTemplates = await _getMoreTemplates(db);
    int addedCount = 0;

    for (final t in newTemplates) {
      if (!existingNames.contains(t['name'])) {
        await db.insert('meal_templates', t);
        addedCount++;
      }
    }
    debugPrint('✅ Добавлено новых блюд: $addedCount (v5)');
  }

  Future<List<Map<String, dynamic>>> _getMoreTemplates(Database db) async {
    final now = DateTime.now().toIso8601String();
    final uuid = const Uuid();
    final products = await db.query('food_products', limit: 600);

    FoodProduct? find(String name) {
      try {
        final row = products.firstWhere((p) => p['name'] == name);
        return FoodProduct(
          id: row['id'] as String,
          name: row['name'] as String,
          category: (row['category'] as String?) ?? 'other',
          calories: (row['calories'] as num?)?.toDouble() ?? 0,
          protein: (row['protein'] as num?)?.toDouble() ?? 0,
          fat: (row['fat'] as num?)?.toDouble() ?? 0,
          carbs: (row['carbs'] as num?)?.toDouble() ?? 0,
          fiber: (row['fiber'] as num?)?.toDouble() ?? 0,
        );
      } catch (_) {
        return null;
      }
    }

    final templates = <Map<String, dynamic>>[];

    void addTemplate(String name, List<MapEntry<String, double>> items) {
      final list = <Map<String, dynamic>>[];
      for (final item in items) {
        final p = find(item.key);
        if (p != null) {
          list.add({'productId': p.id, 'grams': item.value, 'name': p.name});
        }
      }
      if (list.isNotEmpty) {
        templates.add({
          'id': uuid.v4(),
          'name': name,
          'items': jsonEncode(list),
          'createdAt': now,
        });
      }
    }

    // ==================== 🌅 ЗАВТРАКИ (дополнительные) ====================
    addTemplate('Яичница с помидорами и сыром', [
      MapEntry('Яйцо куриное C0', 120), MapEntry('Помидор', 100),
      MapEntry('Сыр твёрдый', 30), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Бутерброд с лососем и сливочным сыром', [
      MapEntry('Хлеб цельнозерновой', 60), MapEntry('Лосось', 60),
      MapEntry('Сыр сливочный', 30), MapEntry('Лимон', 10),
    ]);
    addTemplate('Овсянка с тыквой и специями', [
      MapEntry('Овсянка', 50), MapEntry('Тыква', 100),
      MapEntry('Молоко 2.5%', 150), MapEntry('Корица', 2),
    ]);
    addTemplate('Запечённые яблоки с творогом', [
      MapEntry('Яблоко', 150), MapEntry('Творог 5%', 100),
      MapEntry('Мёд', 15), MapEntry('Корица', 2),
    ]);
    addTemplate('Гречка с яйцом и зеленью', [
      MapEntry('Гречка варёная', 150), MapEntry('Яйцо куриное C0', 60),
      MapEntry('Укроп', 10), MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Рисовая каша с изюмом', [
      MapEntry('Каша рисовая на молоке', 200), MapEntry('Изюм', 20),
      MapEntry('Масло сливочное', 10), MapEntry('Корица', 2),
    ]);
    addTemplate('Манная каша с вареньем', [
      MapEntry('Манная каша', 200), MapEntry('Варенье', 30),
      MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Омлет с шпинатом и сыром фета', [
      MapEntry('Яйцо куриное C0', 120), MapEntry('Шпинат', 60),
      MapEntry('Сыр фета', 40), MapEntry('Молоко 2.5%', 50),
    ]);
    addTemplate('Тост с хумусом и овощами', [
      MapEntry('Хлеб цельнозерновой', 60), MapEntry('Хумус', 40),
      MapEntry('Огурец', 50), MapEntry('Помидор', 50),
    ]);
    addTemplate('Смузи боул с гранолой', [
      MapEntry('Банан', 80), MapEntry('Клубника', 60),
      MapEntry('Йогурт греческий', 100), MapEntry('Гранола', 30),
    ]);

    // ==================== 🥗 ЗДОРОВЫЕ ОБЕДЫ ====================
    addTemplate('Киноа с овощами и тофу', [
      MapEntry('Киноа варёная', 150), MapEntry('Тофу', 100),
      MapEntry('Брокколи', 80), MapEntry('Морковь', 50),
      MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Запечённый лосось с овощами', [
      MapEntry('Лосось', 150), MapEntry('Брокколи', 100),
      MapEntry('Морковь', 50), MapEntry('Масло оливковое', 10),
      MapEntry('Лимон', 20),
    ]);
    addTemplate('Куриная грудка с киноа и авокадо', [
      MapEntry('Куриная грудка', 150), MapEntry('Киноа варёная', 120),
      MapEntry('Авокадо', 80), MapEntry('Помидор', 60),
    ]);
    addTemplate('Индейка с овощным рагу', [
      MapEntry('Индейка', 150), MapEntry('Кабачок', 80),
      MapEntry('Морковь', 50), MapEntry('Перец болгарский', 50),
      MapEntry('Паста томатная', 30),
    ]);
    addTemplate('Рыбное филе с рисом и шпинатом', [
      MapEntry('Минтай', 150), MapEntry('Рис белый варёный', 120),
      MapEntry('Шпинат', 80), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Куриные котлеты с гречкой', [
      MapEntry('Котлеты домашние', 150), MapEntry('Гречка варёная', 150),
      MapEntry('Огурец', 80), MapEntry('Сметана 15%', 20),
    ]);
    addTemplate('Вегетарианский бургер', [
      MapEntry('Бургер', 200), MapEntry('Тофу', 80),
      MapEntry('Салат листовой', 30), MapEntry('Помидор', 50),
      MapEntry('Сыр твёрдый', 20),
    ]);
    addTemplate('Булгур с овощами и нутом', [
      MapEntry('Булгур варёный', 150), MapEntry('Нут варёный', 100),
      MapEntry('Морковь', 50), MapEntry('Перец болгарский', 50),
      MapEntry('Масло оливковое', 10),
    ]);

    // ==================== 🥗 САЛАТЫ (дополнительные) ====================
    addTemplate('Нисуаз с тунцом', [
      MapEntry('Тунец', 100), MapEntry('Яйцо куриное C0', 60),
      MapEntry('Огурец', 80), MapEntry('Помидор', 80),
      MapEntry('Фасоль стручковая', 50), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Тёплый салат с курицей', [
      MapEntry('Куриная грудка', 100), MapEntry('Руккола', 40),
      MapEntry('Помидор', 80), MapEntry('Сыр пармезан', 20),
      MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Салат с киноа и гранатом', [
      MapEntry('Киноа варёная', 100), MapEntry('Гранат', 80),
      MapEntry('Руккола', 40), MapEntry('Огурец', 60),
      MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Салат с креветками и манго', [
      MapEntry('Креветки', 100), MapEntry('Манго', 80),
      MapEntry('Авокадо', 60), MapEntry('Салат листовой', 40),
      MapEntry('Лимон', 10),
    ]);
    addTemplate('Салат с фасолью и киноа', [
      MapEntry('Фасоль варёная', 100), MapEntry('Киноа варёная', 80),
      MapEntry('Огурец', 60), MapEntry('Помидор', 60),
      MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Салат с яблоком и орехами', [
      MapEntry('Яблоко', 100), MapEntry('Салат листовой', 50),
      MapEntry('Грецкий орех', 30), MapEntry('Сыр твёрдый', 30),
      MapEntry('Масло оливковое', 10),
    ]);

    // ==================== 🌙 УЖИНЫ (дополнительные) ====================
    addTemplate('Курица с бататом и брокколи', [
      MapEntry('Куриная грудка', 150), MapEntry('Батат', 150),
      MapEntry('Брокколи', 100), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Рыба с киноа и овощами', [
      MapEntry('Минтай', 150), MapEntry('Киноа варёная', 120),
      MapEntry('Цветная капуста', 100), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Тофу с овощами в азиатском стиле', [
      MapEntry('Тофу', 120), MapEntry('Перец болгарский', 80),
      MapEntry('Брокколи', 80), MapEntry('Соевый соус', 20),
      MapEntry('Масло кунжутное', 10),
    ]);
    addTemplate('Запеканка с индейкой и овощами', [
      MapEntry('Индейка', 120), MapEntry('Кабачок', 80),
      MapEntry('Морковь', 50), MapEntry('Сыр твёрдый', 30),
      MapEntry('Яйцо куриное C0', 60),
    ]);
    addTemplate('Куриные рулетики с сыром', [
      MapEntry('Куриная грудка', 120), MapEntry('Сыр твёрдый', 30),
      MapEntry('Шпинат', 40), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Лосось с рисом и спаржей', [
      MapEntry('Лосось', 150), MapEntry('Рис белый варёный', 120),
      MapEntry('Спаржа', 80), MapEntry('Масло оливковое', 10),
      MapEntry('Лимон', 20),
    ]);
    addTemplate('Овощное рагу с нутом', [
      MapEntry('Нут варёный', 120), MapEntry('Кабачок', 80),
      MapEntry('Морковь', 50), MapEntry('Перец болгарский', 50),
      MapEntry('Паста томатная', 30),
    ]);

    // ==================== 🍎 ПЕРЕКУСЫ (дополнительные) ====================
    addTemplate('Хумус с овощами', [
      MapEntry('Хумус', 60), MapEntry('Морковь', 80),
      MapEntry('Огурец', 80), MapEntry('Перец болгарский', 60),
    ]);
    addTemplate('Греческий йогурт с мёдом', [
      MapEntry('Йогурт греческий', 150), MapEntry('Мёд', 15),
      MapEntry('Грецкий орех', 15),
    ]);
    addTemplate('Смузи с ананасом и шпинатом', [
      MapEntry('Ананас', 100), MapEntry('Шпинат', 40),
      MapEntry('Банан', 80), MapEntry('Молоко 2.5%', 150),
    ]);
    addTemplate('Творог с зеленью и огурцом', [
      MapEntry('Творог 5%', 150), MapEntry('Огурец', 60),
      MapEntry('Укроп', 10), MapEntry('Зелёный лук', 10),
    ]);
    addTemplate('Яблочные дольки с ореховой пастой', [
      MapEntry('Яблоко', 150), MapEntry('Арахисовая паста', 20),
    ]);
    addTemplate('Смузи с манго и бананом', [
      MapEntry('Манго', 100), MapEntry('Банан', 80),
      MapEntry('Йогурт греческий', 100), MapEntry('Молоко 2.5%', 100),
    ]);
    addTemplate('Овощные палочки с гуакамоле', [
      MapEntry('Авокадо', 80), MapEntry('Помидор', 40),
      MapEntry('Лук репчатый', 20), MapEntry('Морковь', 60),
      MapEntry('Огурец', 60),
    ]);

    // ==================== 🥤 НАПИТКИ (дополнительные) ====================
    addTemplate('Зелёный смузи с яблоком', [
      MapEntry('Яблоко', 100), MapEntry('Шпинат', 40),
      MapEntry('Банан', 80), MapEntry('Вода', 150),
    ]);
    addTemplate('Смузи с клубникой и бананом', [
      MapEntry('Клубника', 80), MapEntry('Банан', 80),
      MapEntry('Молоко 2.5%', 150), MapEntry('Мёд', 10),
    ]);
    addTemplate('Смузи с манго и маракуйей', [
      MapEntry('Манго', 100), MapEntry('Маракуйя', 60),
      MapEntry('Йогурт греческий', 100), MapEntry('Сок апельсиновый', 100),
    ]);
    addTemplate('Зелёный чай с мятой', [
      MapEntry('Чай зелёный', 250), MapEntry('Мята', 10),
      MapEntry('Лимон', 10), MapEntry('Мёд', 10),
    ]);

    // ==================== 🍳 ВЕГАНСКИЕ (дополнительные) ====================
    addTemplate('Тофу-болоньезе с пастой', [
      MapEntry('Тофу', 120), MapEntry('Макароны варёные', 150),
      MapEntry('Паста томатная', 40), MapEntry('Морковь', 30),
      MapEntry('Лук репчатый', 30),
    ]);
    addTemplate('Чечевичный суп с овощами', [
      MapEntry('Чечевица варёная', 150), MapEntry('Морковь', 50),
      MapEntry('Лук репчатый', 30), MapEntry('Паста томатная', 30),
      MapEntry('Чеснок', 10),
    ]);
    addTemplate('Нут-бургер с овощами', [
      MapEntry('Нут варёный', 120), MapEntry('Хлеб цельнозерновой', 50),
      MapEntry('Салат листовой', 30), MapEntry('Помидор', 50),
      MapEntry('Лук репчатый', 20),
    ]);
    addTemplate('Киноа с овощами и соевым соусом', [
      MapEntry('Киноа варёная', 150), MapEntry('Брокколи', 80),
      MapEntry('Морковь', 50), MapEntry('Соевый соус', 20),
    ]);

    // ==================== 🏋️ СПОРТИВНЫЕ (дополнительные) ====================
    addTemplate('Протеиновый омлет с овощами', [
      MapEntry('Яйцо куриное C0', 120), MapEntry('Протеин сывороточный', 20),
      MapEntry('Помидор', 60), MapEntry('Шпинат', 40),
      MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Куриная грудка с бататом', [
      MapEntry('Куриная грудка', 150), MapEntry('Батат', 150),
      MapEntry('Брокколи', 100), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Творог с фруктами и орехами', [
      MapEntry('Творог 5%', 200), MapEntry('Банан', 80),
      MapEntry('Клубника', 60), MapEntry('Грецкий орех', 20),
    ]);
    addTemplate('Протеиновые панкейки с ягодами', [
      MapEntry('Протеин сывороточный', 30), MapEntry('Яйцо куриное C0', 30),
      MapEntry('Овсянка', 20), MapEntry('Клубника', 60),
      MapEntry('Мёд', 10),
    ]);

    return templates;
  }

  Future<void> _addNewTemplates(Database db) async {
    final existing = await db.query('meal_templates');
    final existingNames = existing.map((e) => e['name'] as String).toSet();

    final newTemplates = await _getNewTemplates(db);
    int addedCount = 0;

    for (final t in newTemplates) {
      if (!existingNames.contains(t['name'])) {
        await db.insert('meal_templates', t);
        addedCount++;
      }
    }
    debugPrint('✅ Добавлено новых блюд: $addedCount');
  }

  Future<List<Map<String, dynamic>>> _getNewTemplates(Database db) async {
    final now = DateTime.now().toIso8601String();
    final uuid = const Uuid();
    final products = await db.query('food_products', limit: 500);

    FoodProduct? find(String name) {
      try {
        final row = products.firstWhere((p) => p['name'] == name);
        return FoodProduct(
          id: row['id'] as String,
          name: row['name'] as String,
          category: (row['category'] as String?) ?? 'other',
          calories: (row['calories'] as num?)?.toDouble() ?? 0,
          protein: (row['protein'] as num?)?.toDouble() ?? 0,
          fat: (row['fat'] as num?)?.toDouble() ?? 0,
          carbs: (row['carbs'] as num?)?.toDouble() ?? 0,
          fiber: (row['fiber'] as num?)?.toDouble() ?? 0,
        );
      } catch (_) {
        return null;
      }
    }

    final templates = <Map<String, dynamic>>[];

    void addTemplate(String name, List<MapEntry<String, double>> items) {
      final list = <Map<String, dynamic>>[];
      for (final item in items) {
        final p = find(item.key);
        if (p != null) {
          list.add({'productId': p.id, 'grams': item.value, 'name': p.name});
        }
      }
      if (list.isNotEmpty) {
        templates.add({
          'id': uuid.v4(),
          'name': name,
          'items': jsonEncode(list),
          'createdAt': now,
        });
      }
    }

    // ==================== 🌅 ЗАВТРАКИ (дополнительные) ====================
    addTemplate('Гранола с йогуртом и ягодами', [
      MapEntry('Гранола', 40), MapEntry('Йогурт греческий', 150),
      MapEntry('Клубника', 60), MapEntry('Черника', 40),
    ]);
    addTemplate('Творожная запеканка с изюмом', [
      MapEntry('Творог 5%', 200), MapEntry('Яйцо куриное C0', 60),
      MapEntry('Манка', 20), MapEntry('Изюм', 20), MapEntry('Сметана 15%', 20),
    ]);
    addTemplate('Блины с творогом', [
      MapEntry('Блинчики', 120), MapEntry('Творог 5%', 100),
      MapEntry('Сметана 15%', 20), MapEntry('Мёд', 10),
    ]);
    addTemplate('Овсянка с яблоком и корицей', [
      MapEntry('Овсянка', 50), MapEntry('Яблоко', 120),
      MapEntry('Молоко 2.5%', 150), MapEntry('Мёд', 10),
    ]);
    addTemplate('Гречневая каша с творогом', [
      MapEntry('Гречка варёная', 150), MapEntry('Творог 5%', 100),
      MapEntry('Молоко 2.5%', 100), MapEntry('Масло сливочное', 10),
    ]);

    // ==================== ☀️ ОБЕДЫ (дополнительные) ====================
    addTemplate('Курица с картофелем и зеленью', [
      MapEntry('Куриная грудка', 150), MapEntry('Картофель варёный', 150),
      MapEntry('Укроп', 10), MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Говядина с овощами в сметане', [
      MapEntry('Говядина', 120), MapEntry('Морковь', 50),
      MapEntry('Лук репчатый', 30), MapEntry('Сметана 15%', 40),
    ]);
    addTemplate('Рыба запечённая с лимоном', [
      MapEntry('Лосось', 150), MapEntry('Лимон', 20),
      MapEntry('Брокколи', 100), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Куриный плов', [
      MapEntry('Куриная грудка', 120), MapEntry('Рис белый варёный', 180),
      MapEntry('Морковь', 50), MapEntry('Лук репчатый', 30),
    ]);
    addTemplate('Фаршированные перцы', [
      MapEntry('Перец болгарский', 120), MapEntry('Фарш куриный', 80),
      MapEntry('Рис белый варёный', 50), MapEntry('Паста томатная', 30),
    ]);
    addTemplate('Индейка с киноа', [
      MapEntry('Индейка', 150), MapEntry('Киноа варёная', 120),
      MapEntry('Помидор', 80), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Рыбные котлеты с рисом', [
      MapEntry('Треска', 150), MapEntry('Рис белый варёный', 120),
      MapEntry('Яйцо куриное C0', 30), MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Суп с фрикадельками', [
      MapEntry('Суп куриный', 300), MapEntry('Фарш куриный', 60),
      MapEntry('Макароны варёные', 30), MapEntry('Морковь', 30),
    ]);

    // ==================== 🥗 САЛАТЫ (дополнительные) ====================
    addTemplate('Салат с курицей и ананасом', [
      MapEntry('Куриная грудка', 100), MapEntry('Ананас', 80),
      MapEntry('Сыр твёрдый', 30), MapEntry('Сметана 15%', 20),
      MapEntry('Салат листовой', 30),
    ]);
    addTemplate('Салат с тунцом и фасолью', [
      MapEntry('Тунец', 100), MapEntry('Фасоль варёная', 80),
      MapEntry('Лук репчатый', 20), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Салат с креветками и авокадо', [
      MapEntry('Креветки', 100), MapEntry('Авокадо', 80),
      MapEntry('Помидор', 60), MapEntry('Лимон', 10),
    ]);
    addTemplate('Салат с киноа и огурцом', [
      MapEntry('Киноа варёная', 100), MapEntry('Огурец', 80),
      MapEntry('Помидор', 60), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Салат с яйцом и зеленью', [
      MapEntry('Яйцо куриное C0', 60), MapEntry('Салат листовой', 40),
      MapEntry('Помидор', 60), MapEntry('Сметана 15%', 20),
    ]);
    addTemplate('Салат с сельдью и свёклой', [
      MapEntry('Сельдь', 80), MapEntry('Свёкла', 100),
      MapEntry('Лук репчатый', 20), MapEntry('Масло подсолнечное', 10),
    ]);

    // ==================== 🌙 УЖИНЫ (дополнительные) ====================
    addTemplate('Курица с цветной капустой', [
      MapEntry('Куриная грудка', 150), MapEntry('Капуста цветная', 150),
      MapEntry('Масло сливочное', 10), MapEntry('Сыр твёрдый', 20),
    ]);
    addTemplate('Рыба с овощным рагу', [
      MapEntry('Минтай', 150), MapEntry('Кабачок', 80),
      MapEntry('Морковь', 50), MapEntry('Паста томатная', 30),
    ]);
    addTemplate('Тофу с рисом и соевым соусом', [
      MapEntry('Тофу', 120), MapEntry('Рис белый варёный', 120),
      MapEntry('Соевый соус', 20), MapEntry('Зелёный лук', 10),
    ]);
    addTemplate('Омлет с шампиньонами', [
      MapEntry('Яйцо куриное C0', 120), MapEntry('Шампиньоны', 80),
      MapEntry('Сыр твёрдый', 30), MapEntry('Молоко 2.5%', 50),
    ]);
    addTemplate('Курица в сливочном соусе', [
      MapEntry('Куриная грудка', 120), MapEntry('Молоко 2.5%', 100),
      MapEntry('Шампиньоны', 60), MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Индейка с картофелем', [
      MapEntry('Индейка', 150), MapEntry('Картофель варёный', 150),
      MapEntry('Морковь', 50), MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Запеканка из цветной капусты', [
      MapEntry('Капуста цветная', 150), MapEntry('Яйцо куриное C0', 60),
      MapEntry('Сыр твёрдый', 40), MapEntry('Молоко 2.5%', 80),
    ]);

    // ==================== 🥤 НАПИТКИ (дополнительные) ====================
    addTemplate('Смузи с бананом и шпинатом', [
      MapEntry('Банан', 100), MapEntry('Шпинат', 40),
      MapEntry('Молоко 2.5%', 200), MapEntry('Мёд', 10),
    ]);
    addTemplate('Смузи с клубникой и бананом', [
      MapEntry('Клубника', 80), MapEntry('Банан', 80),
      MapEntry('Молоко 2.5%', 200), MapEntry('Мёд', 10),
    ]);
    addTemplate('Протеиновый коктейль с овсянкой', [
      MapEntry('Протеин сывороточный', 30), MapEntry('Овсянка', 30),
      MapEntry('Банан', 80), MapEntry('Молоко 2.5%', 250),
    ]);
    addTemplate('Кофе с овсяным молоком', [
      MapEntry('Кофе чёрный', 200), MapEntry('Молоко миндальное', 100),
    ]);
    addTemplate('Чай с мёдом и лимоном', [
      MapEntry('Чай зелёный', 200), MapEntry('Мёд', 15), MapEntry('Лимон', 10),
    ]);

    // ==================== 🍌 ПЕРЕКУСЫ (дополнительные) ====================
    addTemplate('Яблоко с миндальной пастой', [
      MapEntry('Яблоко', 150), MapEntry('Миндаль', 20),
    ]);
    addTemplate('Банан с арахисовой пастой', [
      MapEntry('Банан', 120), MapEntry('Арахисовая паста', 20),
    ]);
    addTemplate('Творог с зеленью', [
      MapEntry('Творог 5%', 150), MapEntry('Укроп', 10),
      MapEntry('Огурец', 50), MapEntry('Соль', 1),
    ]);
    addTemplate('Овощные палочки с хумусом', [
      MapEntry('Морковь', 80), MapEntry('Огурец', 80),
      MapEntry('Хумус', 40), MapEntry('Перец болгарский', 50),
    ]);
    addTemplate('Рисовые хлебцы с авокадо', [
      MapEntry('Хлебцы рисовые', 20), MapEntry('Авокадо', 60),
      MapEntry('Помидор', 40), MapEntry('Соль', 1),
    ]);
    addTemplate('Протеиновые панкейки', [
      MapEntry('Протеин сывороточный', 30), MapEntry('Яйцо куриное C0', 30),
      MapEntry('Овсянка', 20), MapEntry('Банан', 60),
    ]);

    // ==================== 🍳 ВЕГАНСКИЕ БЛЮДА (дополнительные) ====================
    addTemplate('Чечевичный суп', [
      MapEntry('Чечевица варёная', 150), MapEntry('Морковь', 50),
      MapEntry('Лук репчатый', 30), MapEntry('Паста томатная', 30),
    ]);
    addTemplate('Нут с овощами', [
      MapEntry('Нут варёный', 150), MapEntry('Перец болгарский', 80),
      MapEntry('Морковь', 50), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Тофу-скрембл', [
      MapEntry('Тофу', 120), MapEntry('Перец болгарский', 60),
      MapEntry('Лук репчатый', 30), MapEntry('Куркума', 2),
    ]);
    addTemplate('Салат с киноа и нутом', [
      MapEntry('Киноа варёная', 100), MapEntry('Нут варёный', 80),
      MapEntry('Огурец', 60), MapEntry('Помидор', 60),
    ]);
    addTemplate('Чечевичные котлеты', [
      MapEntry('Чечевица варёная', 120), MapEntry('Лук репчатый', 30),
      MapEntry('Морковь', 30), MapEntry('Масло оливковое', 10),
    ]);

    // ==================== 🍰 ДЕСЕРТЫ (дополнительные) ====================
    addTemplate('Творожный десерт с ягодами', [
      MapEntry('Творог 5%', 150), MapEntry('Клубника', 60),
      MapEntry('Черника', 40), MapEntry('Мёд', 15),
    ]);
    addTemplate('Шоколадный протеиновый пудинг', [
      MapEntry('Протеин сывороточный', 30), MapEntry('Молоко 2.5%', 150),
      MapEntry('Какао', 10), MapEntry('Мёд', 10),
    ]);

    return templates;
  }

  Future<void> _createIndexes(Database db) async {
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_category ON food_products(category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_custom ON food_products(isCustom)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_favorite ON food_products(isFavorite)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_diary_date ON food_diary(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_water_date ON water_entries(date)');
    } catch (e) {
      debugPrint('⚠️ Ошибка создания индексов: $e');
    }
  }

  // ==================== 320+ ПРОДУКТОВ (основная база) ====================

  Future<void> _seedDefaultProducts(Database db) async {
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM food_products');
    if ((count.first['count'] as int) > 0) return;
    debugPrint('🌱 Заполняем базу продуктов (320+)...');

    final now = DateTime.now().toIso8601String();
    // [name, category, kcal, protein, fat, carbs, fiber]
    final products = [
      // 🥩 МЯСО И ПТИЦА (30+)
      ['Куриная грудка', 'meat', 165, 31, 3.6, 0, 0],
      ['Куриное бедро', 'meat', 209, 26, 10.9, 0, 0],
      ['Куриное крыло', 'meat', 222, 24, 12, 0, 0],
      ['Куриная печень', 'meat', 136, 19, 6, 0, 0],
      ['Куриные сердечки', 'meat', 158, 16, 10, 0, 0],
      ['Говядина', 'meat', 250, 26, 15, 0, 0],
      ['Говяжья печень', 'meat', 127, 20, 3, 0, 0],
      ['Говяжий язык', 'meat', 250, 14, 19, 0, 0],
      ['Свинина', 'meat', 242, 27, 14, 0, 0],
      ['Свиная печень', 'meat', 109, 19, 4, 0, 0],
      ['Индейка', 'meat', 189, 29, 7, 0, 0],
      ['Кролик', 'meat', 156, 21, 8, 0, 0],
      ['Баранина', 'meat', 294, 25, 21, 0, 0],
      ['Утка', 'meat', 337, 19, 28, 0, 0],
      ['Сосиски', 'meat', 277, 11, 23, 3.7, 0],
      ['Колбаса варёная', 'meat', 260, 12, 22, 2, 0],
      ['Бекон', 'meat', 541, 37, 42, 1.4, 0],
      ['Ветчина', 'meat', 145, 18, 7, 1.5, 0],
      ['Курица копчёная', 'meat', 184, 27, 8, 0, 0],
      ['Фарш говяжий', 'meat', 241, 17, 19, 0, 0],
      ['Фарш куриный', 'meat', 143, 17, 8, 0, 0],
      ['Котлеты домашние', 'meat', 215, 17, 15, 2, 0],
      ['Стейк говяжий', 'meat', 271, 26, 18, 0, 0],
      ['Индейка копчёная', 'meat', 189, 29, 7, 0, 0],
      ['Гусь', 'meat', 371, 15, 33, 0, 0],
      ['Перепел', 'meat', 192, 21, 11, 0, 0],
      ['Свиной язык', 'meat', 228, 16, 17, 0, 0],
      ['Свиные уши', 'meat', 330, 22, 26, 0, 0],
      ['Свиные ножки', 'meat', 275, 20, 21, 0, 0],
      ['Бастурма', 'meat', 215, 28, 10, 0, 0],
      ['Суджук', 'meat', 280, 22, 20, 3, 0],
      ['Салями', 'meat', 350, 22, 28, 2, 0],
      ['Балык', 'meat', 194, 24, 10, 0, 0],
      ['Карбонад', 'meat', 210, 25, 12, 0, 0],
      ['Шейка свиная', 'meat', 290, 17, 24, 0, 0],
      ['Лопатка свиная', 'meat', 270, 20, 20, 0, 0],
      ['Окорок свиной', 'meat', 260, 21, 18, 0, 0],
      ['Грудинка свиная', 'meat', 420, 14, 40, 0, 0],
      ['Ребрышки свиные', 'meat', 320, 18, 27, 0, 0],
      ['Вырезка телячья', 'meat', 110, 21, 2.5, 0, 0],
      ['Телятина', 'meat', 130, 20, 5, 0, 0],
      ['Конина', 'meat', 143, 20, 7, 0, 0],
      ['Оленина', 'meat', 120, 22, 3.5, 0, 0],
      ['Мясо страуса', 'meat', 130, 22, 4, 0, 0],
      ['Фарш свиной', 'meat', 263, 16, 21, 0, 0],
      ['Фарш индюшиный', 'meat', 165, 18, 10, 0, 0],
      ['Фарш смешанный', 'meat', 235, 17, 18, 0, 0],
      ['Колбаса докторская', 'meat', 257, 13, 22, 1.5, 0],
      ['Колбаса любительская', 'meat', 301, 12, 27, 1.5, 0],
      ['Колбаса молочная', 'meat', 252, 11, 22, 2, 0],
      ['Колбаса сервелат', 'meat', 360, 15, 32, 2, 0],
      ['Колбаса краковская', 'meat', 310, 13, 28, 1.5, 0],
      ['Сосиски молочные', 'meat', 261, 10, 23, 4, 0],
      ['Сардельки', 'meat', 250, 11, 22, 3, 0],
      ['Шпикачки', 'meat', 300, 9, 28, 2, 0],
      ['Ветчина из индейки', 'meat', 120, 16, 5, 1.5, 0],
      ['Ветчина варёная', 'meat', 145, 18, 7, 1.5, 0],
      ['Ветчина копчёная', 'meat', 170, 16, 11, 1, 0],

      // 🐟 РЫБА И МОРЕПРОДУКТЫ (40+)
      ['Лосось', 'fish', 208, 20, 13, 0, 0],
      ['Горбуша', 'fish', 140, 20, 6, 0, 0],
      ['Форель', 'fish', 208, 20, 13, 0, 0],
      ['Тунец', 'fish', 132, 28, 1, 0, 0],
      ['Треска', 'fish', 82, 18, 0.7, 0, 0],
      ['Минтай', 'fish', 79, 16, 1, 0, 0],
      ['Сельдь', 'fish', 217, 18, 15, 0, 0],
      ['Скумбрия', 'fish', 262, 18, 21, 0, 0],
      ['Окунь морской', 'fish', 124, 18, 5, 0, 0],
      ['Дорадо', 'fish', 96, 19, 1.5, 0, 0],
      ['Судак', 'fish', 84, 19, 1, 0, 0],
      ['Креветки', 'fish', 99, 24, 0.3, 0.2, 0],
      ['Кальмар', 'fish', 92, 18, 2, 0, 0],
      ['Осьминог', 'fish', 82, 15, 1, 0, 0],
      ['Мидии', 'fish', 77, 12, 2, 0, 0],
      ['Краб', 'fish', 84, 18, 1, 0, 0],
      ['Крабовые палочки', 'fish', 73, 6, 0.5, 10, 0],
      ['Икра красная', 'fish', 252, 24, 18, 0, 0],
      ['Сёмга', 'fish', 219, 20, 15, 0, 0],
      ['Сардины', 'fish', 208, 24, 11, 0, 0],
      ['Палтус', 'fish', 186, 19, 12, 0, 0],
      ['Макрель', 'fish', 262, 18, 21, 0, 0],
      ['Кижуч', 'fish', 140, 21, 6, 0, 0],
      ['Нерка', 'fish', 152, 20, 8, 0, 0],
      ['Чавыча', 'fish', 148, 20, 7, 0, 0],
      ['Кета', 'fish', 127, 19, 5.5, 0, 0],
      ['Голец', 'fish', 135, 20, 6, 0, 0],
      ['Хариус', 'fish', 88, 17, 2, 0, 0],
      ['Ленок', 'fish', 93, 18, 2.2, 0, 0],
      ['Таймень', 'fish', 110, 19, 3.5, 0, 0],
      ['Щука', 'fish', 84, 18, 1, 0, 0],
      ['Жерех', 'fish', 86, 19, 0.7, 0, 0],
      ['Лещ', 'fish', 105, 17, 4, 0, 0],
      ['Карп', 'fish', 112, 16, 5, 0, 0],
      ['Сазан', 'fish', 97, 18, 2.5, 0, 0],
      ['Линь', 'fish', 88, 18, 1.5, 0, 0],
      ['Налим', 'fish', 79, 18, 0.8, 0, 0],
      ['Пикша', 'fish', 74, 17, 0.5, 0, 0],
      ['Мерланг', 'fish', 78, 18, 0.6, 0, 0],
      ['Мойва', 'fish', 118, 13, 7, 0, 0],
      ['Корюшка', 'fish', 112, 15, 5.5, 0, 0],
      ['Ряпушка', 'fish', 74, 16, 0.9, 0, 0],
      ['Снеток', 'fish', 82, 18, 1, 0, 0],
      ['Тунец консервированный', 'fish', 128, 28, 1.5, 0, 0],
      ['Сардины консервированные', 'fish', 208, 24, 11, 0, 0],
      ['Шпроты', 'fish', 362, 17, 32, 0, 0],
      ['Килька', 'fish', 137, 15, 8, 0, 0],
      ['Анчоусы', 'fish', 210, 20, 14, 0, 0],
      ['Угорь', 'fish', 262, 18, 21, 0, 0],
      ['Морской язык', 'fish', 91, 18, 1.8, 0, 0],
      ['Морской окунь', 'fish', 103, 18, 3, 0, 0],
      ['Зубатка', 'fish', 126, 18, 6, 0, 0],
      ['Луфарь', 'fish', 116, 20, 3.5, 0, 0],
      ['Барабулька', 'fish', 117, 19, 4, 0, 0],
      ['Кефаль', 'fish', 117, 19, 4, 0, 0],
      ['Пеламида', 'fish', 158, 20, 8, 0, 0],
      ['Ставрида', 'fish', 114, 19, 4, 0, 0],
      ['Сайра', 'fish', 213, 18, 15, 0, 0],

      // 🥛 МОЛОЧКА И ЯЙЦА (60+)
      ['Яйцо куриное', 'dairy', 155, 13, 11, 1.1, 0],
      ['Яйцо перепелиное', 'dairy', 168, 12, 11, 0.5, 0],
      ['Яйцо куриное C0', 'dairy', 155, 13, 11, 1.1, 0],
      ['Яйцо куриное C1', 'dairy', 150, 12.5, 10.5, 1.0, 0],
      ['Яйцо куриное C2', 'dairy', 145, 12, 10, 0.9, 0],
      ['Яйцо куриное C3', 'dairy', 140, 11.5, 9.5, 0.8, 0],
      ['Творог 5%', 'dairy', 121, 17, 5, 1.8, 0],
      ['Творог обезжиренный', 'dairy', 71, 18, 0.6, 1.8, 0],
      ['Творог 9%', 'dairy', 156, 18, 9, 2, 0],
      ['Молоко 2.5%', 'dairy', 52, 2.8, 2.5, 4.7, 0],
      ['Молоко 3.2%', 'dairy', 60, 3, 3.2, 4.7, 0],
      ['Молоко обезжиренное', 'dairy', 35, 3.2, 0.1, 5, 0],
      ['Кефир 1%', 'dairy', 40, 3, 1, 4, 0],
      ['Кефир 2.5%', 'dairy', 50, 2.9, 2.5, 4, 0],
      ['Ряженка', 'dairy', 67, 2.8, 4, 4.2, 0],
      ['Йогурт натуральный', 'dairy', 60, 4, 3.2, 3.5, 0],
      ['Йогурт греческий', 'dairy', 59, 8, 0.4, 3.6, 0],
      ['Сметана 15%', 'dairy', 115, 2.6, 15, 3, 0],
      ['Сметана 20%', 'dairy', 206, 2.5, 20, 3.4, 0],
      ['Сыр твёрдый', 'dairy', 350, 25, 27, 2, 0],
      ['Сыр моцарелла', 'dairy', 280, 28, 17, 2.2, 0],
      ['Сыр пармезан', 'dairy', 392, 33, 28, 3, 0],
      ['Сыр адыгейский', 'dairy', 240, 19, 14, 0, 0],
      ['Сыр фета', 'dairy', 264, 14, 21, 4, 0],
      ['Сыр плавленый', 'dairy', 257, 21, 23, 2, 0],
      ['Сливки 10%', 'dairy', 118, 2.8, 10, 4, 0],
      ['Сливки 20%', 'dairy', 206, 2.5, 20, 3.4, 0],
      ['Сливки 30%', 'dairy', 296, 2.2, 30, 3.4, 0],
      ['Сливки 35%', 'dairy', 345, 2.1, 35, 3.4, 0],
      ['Молоко топлёное', 'dairy', 84, 3, 4, 4.7, 0],
      ['Молоко козье', 'dairy', 68, 3.3, 4.2, 4.5, 0],
      ['Молоко овечье', 'dairy', 108, 5.5, 7, 5, 0],
      ['Кумыс', 'dairy', 50, 2.1, 1.9, 5, 0],
      ['Айран', 'dairy', 25, 1.5, 0.5, 4, 0],
      ['Тан', 'dairy', 30, 1.5, 0.5, 5, 0],
      ['Снежок', 'dairy', 80, 3, 3, 10, 0],
      ['Варенец', 'dairy', 53, 2.9, 2.5, 4.2, 0],
      ['Простокваша', 'dairy', 52, 2.9, 2.5, 4.2, 0],
      ['Масло сливочное 82.5%', 'dairy', 748, 0.8, 82.5, 0.8, 0],
      ['Масло топлёное', 'dairy', 876, 0.3, 99, 0, 0],
      ['Сыр рикотта', 'dairy', 174, 11, 13, 3, 0],
      ['Сыр маскарпоне', 'dairy', 429, 4, 43, 2.5, 0],
      ['Сыр гауда', 'dairy', 356, 25, 27, 2, 0],
      ['Сыр эдам', 'dairy', 330, 25, 24, 2, 0],
      ['Сыр горгонзола', 'dairy', 353, 21, 29, 1.5, 0],
      ['Сыр дор блю', 'dairy', 353, 21, 29, 1.5, 0],
      ['Сыр рокфор', 'dairy', 369, 22, 30, 1.5, 0],
      ['Сыр камамбер', 'dairy', 300, 20, 24, 1.5, 0],
      ['Сыр бри', 'dairy', 334, 21, 27, 1.5, 0],
      ['Сыр сулугуни', 'dairy', 285, 20, 22, 1, 0],
      ['Сыр чечил', 'dairy', 290, 19, 23, 1, 0],
      ['Сыр косичка', 'dairy', 295, 19, 23, 1, 0],
      ['Сыр халуми', 'dairy', 310, 22, 24, 2, 0],
      ['Сыр фетаки', 'dairy', 264, 14, 21, 4, 0],
      ['Творожный сыр', 'dairy', 120, 8, 9, 3, 0],
      ['Плавленый сыр 50%', 'dairy', 257, 21, 23, 2, 0],
      ['Плавленый сыр 30%', 'dairy', 190, 15, 12, 8, 0],
      ['Сметана 10%', 'dairy', 115, 2.6, 10, 3, 0],
      ['Сметана 25%', 'dairy', 247, 2.4, 25, 3.4, 0],
      ['Сметана 30%', 'dairy', 296, 2.3, 30, 3.4, 0],
      ['Сметана 40%', 'dairy', 395, 2.2, 40, 3.4, 0],
      ['Йогурт питьевой', 'dairy', 75, 3, 2.5, 10, 0],
      ['Йогурт с наполнителем', 'dairy', 85, 3, 2.8, 12, 0],
      ['Йогурт домашний', 'dairy', 62, 4.5, 3.2, 3.5, 0],

      // 🌾 КРУПЫ И ЗЛАКИ (35+)
      ['Овсянка', 'grains', 366, 12, 6, 60, 10],
      ['Гречка сухая', 'grains', 343, 13, 3.4, 72, 10],
      ['Гречка варёная', 'grains', 92, 3.4, 0.6, 20, 2.7],
      ['Рис белый сухой', 'grains', 344, 6.7, 0.7, 78, 1],
      ['Рис белый варёный', 'grains', 130, 2.7, 0.3, 28, 0.4],
      ['Рис бурый варёный', 'grains', 111, 2.6, 0.9, 23, 1.8],
      ['Макароны варёные', 'grains', 131, 5, 1.1, 25, 1.8],
      ['Макароны сухие', 'grains', 344, 12, 1.5, 70, 3],
      ['Хлеб цельнозерновой', 'grains', 247, 13, 3.4, 41, 7],
      ['Хлеб белый', 'grains', 265, 9, 3.2, 49, 2.7],
      ['Хлеб бородинский', 'grains', 208, 6.9, 1.2, 41, 8],
      ['Киноа варёная', 'grains', 120, 4.4, 1.9, 21, 2.8],
      ['Булгур варёный', 'grains', 83, 3.1, 0.2, 18, 4.5],
      ['Кус-кус варёный', 'grains', 112, 3.8, 0.2, 23, 1.4],
      ['Перловка варёная', 'grains', 109, 3.1, 0.4, 23, 3],
      ['Пшено варёное', 'grains', 90, 3.5, 1, 21, 1.5],
      ['Хлебцы ржаные', 'grains', 310, 11, 2.7, 63, 16],
      ['Овсяные хлопья', 'grains', 363, 12, 6, 60, 10],
      ['Мюсли', 'grains', 325, 10, 5, 60, 8],
      ['Гранола', 'grains', 471, 10, 20, 60, 7],
      ['Хлебцы рисовые', 'grains', 387, 8, 1, 80, 2],
      ['Манка', 'grains', 338, 10, 1, 73, 3],
      ['Каша рисовая на молоке', 'grains', 97, 3.2, 2.7, 16, 0.3],
      ['Манная каша', 'grains', 98, 3, 3.2, 15, 0.5],
      ['Каша овсяная на молоке', 'grains', 105, 4, 4, 15, 2],
      ['Полба варёная', 'grains', 127, 5.5, 0.8, 26, 3.5],
      ['Спельта варёная', 'grains', 132, 5.0, 0.9, 27, 4.0],
      ['Амарант варёный', 'grains', 102, 3.8, 1.6, 19, 2.1],
      ['Тефф варёный', 'grains', 101, 3.9, 0.7, 20, 2.0],
      ['Сорго варёный', 'grains', 116, 3.3, 1.2, 24, 2.5],
      ['Ячмень варёный', 'grains', 123, 2.3, 0.4, 28, 3.5],
      ['Овсяные отруби', 'grains', 246, 17, 7, 66, 15],
      ['Пшеничные отруби', 'grains', 216, 16, 4.3, 64, 42],
      ['Рисовая мука', 'grains', 366, 6, 1.4, 80, 2.4],
      ['Кукурузная мука', 'grains', 364, 7, 3.9, 76, 7.3],
      ['Гречневая мука', 'grains', 343, 13, 3.4, 72, 10],
      ['Овсяная мука', 'grains', 404, 14, 9, 68, 8],
      ['Нутовая мука', 'grains', 387, 22, 6.7, 58, 10],
      ['Чечевичная мука', 'grains', 353, 25, 1.1, 63, 8],
      ['Киноа мука', 'grains', 374, 14, 6, 64, 7],
      ['Кус-кус сухой', 'grains', 376, 13, 0.6, 77, 5],
      ['Булгур сухой', 'grains', 342, 12, 1.3, 70, 18],
      ['Макароны цельнозерновые', 'grains', 124, 5.3, 1.4, 24, 3.8],
      ['Спагетти варёные', 'grains', 158, 5.8, 0.9, 31, 1.8],
      ['Лапша рисовая варёная', 'grains', 109, 1.6, 0.2, 25, 0.8],
      ['Лапша гречневая варёная', 'grains', 99, 3.8, 0.3, 21, 1.3],
      ['Хлеб ржаной', 'grains', 210, 6.5, 1.2, 42, 6.5],
      ['Хлеб с отрубями', 'grains', 220, 11, 3.5, 38, 8],
      ['Хлеб безглютеновый', 'grains', 230, 4, 3, 45, 4],
      ['Хлеб кукурузный', 'grains', 265, 6, 3, 55, 5],
      ['Хлеб картофельный', 'grains', 248, 5, 2, 52, 3],
      ['Лаваш тонкий', 'grains', 220, 7.5, 1, 45, 2],
      ['Тортилья кукурузная', 'grains', 218, 5.7, 2.8, 44, 6],
      ['Тортилья пшеничная', 'grains', 300, 8, 7, 50, 4],
      ['Крекеры', 'grains', 450, 10, 15, 70, 3],
      ['Хлебцы гречневые', 'grains', 310, 12, 3, 62, 14],
      ['Хлебцы пшеничные', 'grains', 320, 11, 2, 68, 8],

      // 🥬 ОВОЩИ И ЗЕЛЕНЬ (50+)
      ['Огурец', 'vegetables', 15, 0.8, 0.1, 3.6, 0.5],
      ['Помидор', 'vegetables', 18, 0.9, 0.2, 3.9, 1.2],
      ['Морковь', 'vegetables', 41, 0.9, 0.2, 10, 2.8],
      ['Брокколи', 'vegetables', 34, 2.8, 0.4, 7, 2.6],
      ['Шпинат', 'vegetables', 23, 2.9, 0.4, 3.6, 2.2],
      ['Картофель варёный', 'vegetables', 87, 2, 0.4, 17, 1.8],
      ['Картофель жареный', 'vegetables', 192, 2.5, 9.5, 23, 2],
      ['Батат', 'vegetables', 86, 1.6, 0.1, 20, 3],
      ['Перец болгарский', 'vegetables', 31, 1, 0.3, 6, 2.1],
      ['Лук репчатый', 'vegetables', 40, 1.1, 0.1, 9, 1.7],
      ['Капуста белокочанная', 'vegetables', 25, 1.3, 0.1, 6, 2.5],
      ['Капуста цветная', 'vegetables', 25, 1.9, 0.3, 5, 2],
      ['Кабачок', 'vegetables', 17, 1.2, 0.3, 3.1, 1],
      ['Баклажан', 'vegetables', 25, 1, 0.2, 6, 3],
      ['Свёкла', 'vegetables', 43, 1.6, 0.2, 10, 2.8],
      ['Редис', 'vegetables', 16, 0.7, 0.1, 3.4, 1.6],
      ['Сельдерей', 'vegetables', 16, 0.9, 0.2, 3, 1.6],
      ['Фасоль стручковая', 'vegetables', 31, 1.8, 0.1, 7, 2.5],
      ['Кукуруза', 'vegetables', 86, 3.2, 1.2, 19, 2.4],
      ['Тыква', 'vegetables', 26, 1, 0.1, 6.5, 0.5],
      ['Шампиньоны', 'vegetables', 27, 4.3, 1, 0.1, 1],
      ['Грибы белые', 'vegetables', 22, 3.1, 0.3, 3.3, 1],
      ['Огурцы солёные', 'vegetables', 11, 0.3, 0.1, 2, 1],
      ['Капуста квашеная', 'vegetables', 19, 1.6, 0.1, 4.3, 2.5],
      ['Оливки', 'vegetables', 115, 0.8, 10.7, 6, 3.2],
      ['Салат листовой', 'vegetables', 15, 1.4, 0.2, 2.9, 1.5],
      ['Руккола', 'vegetables', 25, 2.6, 0.7, 3.7, 1.6],
      ['Укроп', 'vegetables', 43, 3.5, 1.1, 7, 2.1],
      ['Петрушка', 'vegetables', 47, 3.7, 0.8, 7.6, 3.3],
      ['Базилик', 'vegetables', 23, 3.2, 0.6, 2.7, 1.6],
      ['Чеснок', 'vegetables', 149, 6.4, 0.5, 33, 2.1],
      ['Имбирь', 'vegetables', 80, 1.8, 0.8, 18, 2],
      ['Спаржа', 'vegetables', 20, 2.2, 0.1, 3.9, 2.1],
      ['Артишок', 'vegetables', 47, 3.3, 0.2, 11, 5.4],
      ['Топинамбур', 'vegetables', 73, 2, 0.1, 17, 1.6],
      ['Пастернак', 'vegetables', 75, 1.2, 0.3, 18, 4.9],
      ['Корень сельдерея', 'vegetables', 42, 1.5, 0.3, 9.2, 3.1],
      ['Петрушка корневая', 'vegetables', 47, 3.7, 0.8, 7.6, 3.3],
      ['Хрен', 'vegetables', 48, 2.4, 0.4, 11, 3.2],
      ['Редька', 'vegetables', 21, 1.2, 0.1, 4.1, 1.6],
      ['Репа', 'vegetables', 28, 0.9, 0.1, 6, 1.8],
      ['Брюква', 'vegetables', 38, 1.2, 0.1, 8, 2.3],
      ['Свекла листовая', 'vegetables', 19, 2.2, 0.2, 3.7, 1.5],
      ['Мангольд', 'vegetables', 19, 1.8, 0.2, 3.7, 1.6],
      ['Крапива', 'vegetables', 42, 3.5, 0.5, 7, 6.5],
      ['Щавель', 'vegetables', 22, 1.5, 0.3, 2.9, 2.9],
      ['Шпинат молодой', 'vegetables', 23, 2.9, 0.4, 3.6, 2.2],
      ['Рукола молодая', 'vegetables', 25, 2.6, 0.7, 3.7, 1.6],
      ['Кресс-салат', 'vegetables', 32, 2.6, 0.7, 5.5, 1.1],
      ['Латук', 'vegetables', 15, 1.4, 0.2, 2.9, 1.5],
      ['Радиччио', 'vegetables', 23, 1.4, 0.2, 4.5, 0.9],
      ['Эндивий', 'vegetables', 17, 1.3, 0.2, 3.4, 3.1],
      ['Фенхель', 'vegetables', 31, 1.2, 0.2, 7, 3.1],
      ['Лук-порей', 'vegetables', 36, 1.5, 0.3, 8, 1.8],
      ['Лук-шалот', 'vegetables', 72, 2.5, 0.1, 17, 3.2],
      ['Лук зеленый', 'vegetables', 32, 1.3, 0.1, 6.5, 1.8],
      ['Чеснок молодой', 'vegetables', 149, 6.4, 0.5, 33, 2.1],
      ['Стручковая фасоль', 'vegetables', 31, 1.8, 0.1, 7, 2.5],
      ['Горошек зелёный', 'vegetables', 81, 5.4, 0.4, 14, 5.7],
      ['Кукуруза сахарная', 'vegetables', 86, 3.2, 1.2, 19, 2.4],
      ['Перец чили', 'vegetables', 40, 1.8, 0.4, 8.8, 1.5],
      ['Перец сладкий красный', 'vegetables', 31, 1, 0.3, 6, 2.1],
      ['Перец сладкий жёлтый', 'vegetables', 27, 1, 0.2, 6.3, 1.8],
      ['Перец сладкий зелёный', 'vegetables', 20, 0.9, 0.2, 4.6, 1.7],
      ['Тыква мускатная', 'vegetables', 45, 1, 0.1, 12, 2],
      ['Тыква обыкновенная', 'vegetables', 26, 1, 0.1, 6.5, 0.5],
      ['Патиссон', 'vegetables', 19, 0.6, 0.1, 4.3, 0.9],
      ['Огурец корнишон', 'vegetables', 15, 0.8, 0.1, 3.6, 0.5],
      ['Огурец парниковый', 'vegetables', 14, 0.7, 0.1, 2.8, 0.7],
      ['Помидоры черри', 'vegetables', 18, 0.9, 0.2, 3.9, 1.2],
      ['Помидоры жёлтые', 'vegetables', 15, 0.9, 0.2, 3, 1.2],
      ['Томаты вяленые', 'vegetables', 258, 4, 2, 56, 8],
      ['Картофель молодой', 'vegetables', 77, 2, 0.4, 16, 1.8],
      ['Картофель красный', 'vegetables', 87, 2, 0.4, 17, 1.8],
      ['Батат оранжевый', 'vegetables', 86, 1.6, 0.1, 20, 3],
      ['Батат фиолетовый', 'vegetables', 90, 1.7, 0.1, 21, 3.2],

      // 🍎 ФРУКТЫ И ЯГОДЫ (40+)
      ['Яблоко', 'fruits', 52, 0.3, 0.2, 14, 2.4],
      ['Банан', 'fruits', 89, 1.1, 0.3, 23, 2.6],
      ['Апельсин', 'fruits', 47, 0.9, 0.1, 12, 2.4],
      ['Клубника', 'fruits', 32, 0.7, 0.3, 7.7, 2],
      ['Черника', 'fruits', 57, 0.7, 0.3, 14, 2.4],
      ['Виноград', 'fruits', 69, 0.7, 0.2, 18, 0.9],
      ['Авокадо', 'fruits', 160, 2, 15, 9, 7],
      ['Манго', 'fruits', 60, 0.8, 0.4, 15, 1.6],
      ['Груша', 'fruits', 57, 0.4, 0.1, 15, 3.1],
      ['Персик', 'fruits', 39, 0.9, 0.3, 10, 1.5],
      ['Ананас', 'fruits', 50, 0.5, 0.1, 13, 1.4],
      ['Киви', 'fruits', 61, 1.1, 0.5, 15, 3],
      ['Грейпфрут', 'fruits', 42, 0.8, 0.1, 11, 2],
      ['Арбуз', 'fruits', 30, 0.6, 0.2, 7.6, 0.4],
      ['Дыня', 'fruits', 34, 0.6, 0.2, 8.2, 0.9],
      ['Вишня', 'fruits', 50, 1.1, 0.3, 12, 1.6],
      ['Черешня', 'fruits', 63, 1.1, 0.4, 16, 1.4],
      ['Слива', 'fruits', 46, 0.7, 0.3, 11.4, 1.4],
      ['Абрикос', 'fruits', 48, 1.4, 0.4, 11, 2],
      ['Гранат', 'fruits', 83, 1.7, 1.2, 19, 4],
      ['Лимон', 'fruits', 29, 1.1, 0.3, 9, 2.8],
      ['Малина', 'fruits', 52, 1.2, 0.7, 12, 6.5],
      ['Смородина', 'fruits', 63, 1.4, 0.4, 15, 4.3],
      ['Сухофрукты', 'fruits', 286, 3.4, 0.5, 70, 8],
      ['Финики', 'fruits', 282, 2.5, 0.4, 75, 7],
      ['Изюм', 'fruits', 299, 3.1, 0.5, 79, 3.7],
      ['Папайя', 'fruits', 43, 0.5, 0.3, 11, 1.7],
      ['Гуава', 'fruits', 68, 2.6, 1, 14, 5.4],
      ['Маракуйя', 'fruits', 97, 2.2, 0.7, 23, 10.4],
      ['Фейхоа', 'fruits', 49, 1, 0.6, 11, 6.4],
      ['Хурма', 'fruits', 70, 0.6, 0.3, 18, 3.6],
      ['Кумкват', 'fruits', 71, 1.9, 0.9, 16, 6.5],
      ['Лайм', 'fruits', 30, 0.7, 0.2, 11, 2.8],
      ['Помело', 'fruits', 38, 0.8, 0.1, 10, 1],
      ['Свити', 'fruits', 43, 0.8, 0.1, 11, 1],
      ['Угли', 'fruits', 45, 0.8, 0.1, 11, 1.2],
      ['Мандарин', 'fruits', 53, 0.8, 0.3, 13, 1.8],
      ['Клементин', 'fruits', 47, 0.8, 0.2, 12, 1.7],
      ['Рамбутан', 'fruits', 84, 0.9, 0.4, 21, 0.9],
      ['Личи', 'fruits', 66, 0.8, 0.4, 16, 1.3],
      ['Лонган', 'fruits', 60, 1.3, 0.1, 15, 1.1],
      ['Джекфрут', 'fruits', 95, 1.7, 0.6, 23, 1.5],
      ['Дуриан', 'fruits', 147, 1.5, 5.3, 27, 3.8],
      ['Мангустин', 'fruits', 73, 0.4, 0.6, 18, 0.5],
      ['Сахарное яблоко', 'fruits', 94, 2.1, 0.3, 24, 4.4],
      ['Черимойя', 'fruits', 75, 1.6, 0.6, 18, 3.3],
      ['Сметанное яблоко', 'fruits', 66, 1, 0.3, 17, 3.3],
      ['Старфрут', 'fruits', 31, 1, 0.3, 7, 2.8],
      ['Карамбола', 'fruits', 31, 1, 0.3, 7, 2.8],
      ['Питахайя', 'fruits', 60, 1.2, 0.4, 13, 0.9],
      ['Кивано', 'fruits', 44, 2, 1, 7, 3],
      ['Пепино', 'fruits', 35, 1, 0.2, 8, 0.3],
      ['Томатильо', 'fruits', 32, 1, 1, 6, 1.9],
      ['Аки', 'fruits', 151, 2, 7, 20, 2],
      ['Саподилла', 'fruits', 83, 0.4, 0.5, 20, 5.3],
      ['Салак', 'fruits', 82, 1, 0.4, 21, 3.5],
      ['Момордика', 'fruits', 17, 1, 0.2, 3, 2],

      // 🥜 ОРЕХИ (12+)
      ['Миндаль', 'nuts', 579, 21, 50, 22, 12],
      ['Грецкий орех', 'nuts', 654, 15, 65, 14, 7],
      ['Арахис', 'nuts', 567, 26, 49, 16, 8],
      ['Кешью', 'nuts', 553, 18, 44, 30, 3.3],
      ['Фисташки', 'nuts', 562, 20, 45, 28, 10],
      ['Фундук', 'nuts', 628, 15, 61, 17, 9.7],
      ['Кедровые орехи', 'nuts', 673, 14, 68, 13, 3.7],
      ['Арахисовая паста', 'nuts', 588, 25, 50, 20, 6],
      ['Макадамия', 'nuts', 718, 8, 76, 14, 9],
      ['Пекан', 'nuts', 691, 9, 72, 14, 10],
      ['Бразильский орех', 'nuts', 659, 14, 66, 12, 7.5],
      ['Орех кола', 'nuts', 550, 8, 30, 50, 10],
      ['Орех пили', 'nuts', 720, 10, 75, 10, 8],
      ['Орех чёрный', 'nuts', 619, 24, 59, 9, 6],
      ['Орех гикори', 'nuts', 691, 9, 72, 14, 10],
      ['Буковый орех', 'nuts', 576, 21, 50, 18, 5],
      ['Каштан сладкий', 'nuts', 213, 2.4, 2.3, 46, 3.4],
      ['Каштан японский', 'nuts', 200, 2.2, 2, 44, 3],
      ['Миндаль сладкий', 'nuts', 579, 21, 50, 22, 12],
      ['Миндаль горький', 'nuts', 579, 21, 50, 22, 12],
      ['Арахис сырой', 'nuts', 567, 26, 49, 16, 8],
      ['Арахис жареный', 'nuts', 585, 26, 52, 14, 8],
      ['Фисташки жареные', 'nuts', 572, 20, 46, 28, 10],
      ['Кешью жареные', 'nuts', 574, 18, 46, 30, 3.3],
      ['Грецкий орех зелёный', 'nuts', 340, 15, 35, 12, 4],
      ['Фундук жареный', 'nuts', 628, 15, 61, 17, 9.7],
      ['Ореховая паста', 'nuts', 590, 15, 55, 20, 6],
      ['Урбеч', 'nuts', 590, 15, 55, 20, 6],

      // 🌱 СЕМЕНА (10+)
      ['Семена чиа', 'seeds', 486, 17, 31, 42, 34],
      ['Семена льна', 'seeds', 534, 18, 42, 29, 27],
      ['Тыквенные семечки', 'seeds', 559, 30, 49, 11, 6],
      ['Кунжут', 'seeds', 573, 18, 49, 23, 12],
      ['Семена подсолнуха', 'seeds', 584, 21, 50, 20, 8.6],
      ['Семена конопли', 'seeds', 553, 25, 48, 8, 28],
      ['Семена мака', 'seeds', 525, 18, 42, 28, 20],
      ['Семена горчицы', 'seeds', 508, 26, 36, 28, 12],
      ['Семена тмина', 'seeds', 375, 17, 15, 50, 38],
      ['Семена укропа', 'seeds', 305, 15, 15, 40, 30],
      ['Семена аниса', 'seeds', 337, 18, 16, 50, 35],
      ['Семена фенхеля', 'seeds', 345, 16, 15, 52, 40],
      ['Семена сельдерея', 'seeds', 392, 18, 25, 41, 28],

      // 🫘 БОБОВЫЕ (15+)
      ['Фасоль варёная', 'legumes', 123, 8.7, 0.5, 22, 7.4],
      ['Чечевица варёная', 'legumes', 116, 9, 0.4, 20, 7.9],
      ['Нут варёный', 'legumes', 164, 8.9, 2.6, 27, 7.6],
      ['Горох', 'legumes', 81, 5.4, 0.4, 14, 5.7],
      ['Тофу', 'legumes', 76, 8, 4.8, 1.9, 0.3],
      ['Соя', 'legumes', 381, 36, 17, 30, 9.3],
      ['Эдамаме', 'legumes', 122, 11, 5, 9, 5.2],
      ['Маш', 'legumes', 129, 8, 0.5, 24, 5.8],
      ['Адзуки', 'legumes', 128, 7.5, 0.1, 25, 4.5],
      ['Вигна', 'legumes', 132, 8, 0.3, 24, 5],
      ['Бобы', 'legumes', 109, 7, 0.5, 20, 5],
      ['Бобы чёрные', 'legumes', 132, 9, 0.5, 23, 8.7],
      ['Бобы белые', 'legumes', 129, 9, 0.5, 23, 6.5],
      ['Бобы красные', 'legumes', 127, 8.7, 0.5, 22, 6.4],
      ['Нут чёрный', 'legumes', 164, 8.9, 2.6, 27, 7.6],
      ['Фасоль пинто', 'legumes', 114, 7, 0.5, 20, 6],
      ['Фасоль мунг', 'legumes', 127, 7, 0.5, 23, 5.5],
      ['Чечевица красная', 'legumes', 116, 9, 0.4, 20, 7.9],
      ['Чечевица зелёная', 'legumes', 116, 9, 0.4, 20, 7.9],
      ['Чечевица чёрная', 'legumes', 116, 9, 0.4, 20, 7.9],
      ['Чечевица французская', 'legumes', 116, 9, 0.4, 20, 7.9],
      ['Тофу твёрдый', 'legumes', 145, 15, 8, 3.5, 1],
      ['Тофу мягкий', 'legumes', 76, 8, 4.8, 1.9, 0.3],
      ['Тофу копчёный', 'legumes', 105, 10, 6, 2.5, 0.5],
      ['Темпе', 'legumes', 193, 19, 11, 9, 6],
      ['Натто', 'legumes', 200, 17, 9, 12, 8],
      ['Эдамаме варёные', 'legumes', 122, 11, 5, 9, 5.2],
      ['Бобовая паста', 'legumes', 250, 12, 5, 45, 10],

      // 🫒 МАСЛА
      ['Масло оливковое', 'oils', 884, 0, 100, 0, 0],
      ['Масло подсолнечное', 'oils', 884, 0, 100, 0, 0],
      ['Масло сливочное', 'oils', 717, 0.9, 81, 0.1, 0],
      ['Масло кокосовое', 'oils', 862, 0, 99, 0, 0],
      ['Масло льняное', 'oils', 884, 0, 100, 0, 0],
      ['Масло топлёное', 'oils', 876, 0.3, 99, 0, 0],

      // 🍫 СЛАДОСТИ (30+)
      ['Мёд', 'sweets', 304, 0.3, 0, 82, 0.2],
      ['Шоколад тёмный 70%', 'sweets', 598, 7.8, 43, 46, 11],
      ['Шоколад молочный', 'sweets', 535, 8, 30, 59, 3.4],
      ['Мороженое', 'sweets', 207, 3.5, 11, 20, 0.7],
      ['Халва', 'sweets', 516, 12, 30, 54, 4],
      ['Зефир', 'sweets', 326, 0.8, 0.1, 80, 0.5],
      ['Мармелад', 'sweets', 293, 0.1, 0, 77, 0.5],
      ['Печенье', 'sweets', 417, 7.5, 21, 67, 2],
      ['Торт', 'sweets', 349, 5, 22, 45, 1],
      ['Пончик', 'sweets', 426, 5, 25, 51, 1.5],
      ['Блинчики', 'sweets', 233, 6, 7, 37, 1],
      ['Сырники', 'sweets', 183, 15, 10, 15, 0.5],
      ['Варенье', 'sweets', 271, 0.4, 0.1, 70, 0.5],
      ['Сахар', 'sweets', 387, 0, 0, 100, 0],
      ['Мёд гречишный', 'sweets', 309, 0.3, 0, 83, 0.2],
      ['Мёд акациевый', 'sweets', 304, 0.3, 0, 82, 0.2],
      ['Мёд липовый', 'sweets', 320, 0.3, 0, 80, 0.2],
      ['Мёд горный', 'sweets', 310, 0.3, 0, 82, 0.2],
      ['Сироп кленовый', 'sweets', 260, 0, 0, 67, 0],
      ['Сироп агавы', 'sweets', 310, 0, 0, 76, 0],
      ['Сироп топинамбура', 'sweets', 267, 0, 0, 70, 0],
      ['Финиковая паста', 'sweets', 282, 2.5, 0.4, 75, 7],
      ['Инжир сушёный', 'sweets', 249, 3.3, 0.9, 63, 9.8],
      ['Курага', 'sweets', 241, 3.4, 0.5, 63, 7.3],
      ['Чернослив', 'sweets', 240, 2.3, 0.4, 63, 7.1],
      ['Изюм светлый', 'sweets', 299, 3.1, 0.5, 79, 3.7],
      ['Изюм тёмный', 'sweets', 290, 3, 0.5, 77, 3.7],
      ['Цукаты', 'sweets', 300, 0.5, 0.3, 78, 2],
      ['Мармелад желейный', 'sweets', 293, 0.1, 0, 77, 0.5],
      ['Мармелад фруктовый', 'sweets', 280, 0.2, 0, 72, 1],
      ['Зефир ванильный', 'sweets', 326, 0.8, 0.1, 80, 0.5],
      ['Зефир шоколадный', 'sweets', 350, 1, 5, 78, 0.5],
      ['Пастила', 'sweets', 310, 0.5, 0.1, 78, 0.5],
      ['Нуга', 'sweets', 380, 5, 10, 70, 1],
      ['Халва подсолнечная', 'sweets', 516, 12, 30, 54, 4],
      ['Халва тахинная', 'sweets', 500, 15, 28, 50, 5],
      ['Козинак', 'sweets', 520, 15, 30, 50, 5],
      ['Чурчхела', 'sweets', 400, 5, 10, 75, 2],
      ['Леденец', 'sweets', 380, 0, 0, 95, 0],
      ['Ирис', 'sweets', 380, 3, 10, 75, 0.5],
      ['Карамель', 'sweets', 380, 0, 0, 95, 0],
      ['Шоколад белый', 'sweets', 539, 6, 32, 59, 0.1],
      ['Шоколад с орехами', 'sweets', 550, 8, 35, 50, 5],
      ['Шоколад с изюмом', 'sweets', 520, 7, 30, 55, 4],
      ['Шоколад пористый', 'sweets', 520, 6, 28, 60, 2],
      ['Батончик мюсли', 'sweets', 380, 8, 12, 60, 5],
      ['Батончик протеиновый', 'sweets', 350, 30, 12, 35, 3],
      ['Пряники', 'sweets', 360, 5, 5, 75, 2],
      ['Коврижка', 'sweets', 350, 4, 6, 72, 2],
      ['Сухарики', 'sweets', 370, 10, 5, 72, 3],
      ['Бублики', 'sweets', 250, 8, 1.5, 50, 2],
      ['Сушки', 'sweets', 250, 8, 1.5, 50, 2],
      ['Баранки', 'sweets', 250, 8, 1.5, 50, 2],
      ['Кекс', 'sweets', 380, 5, 18, 50, 1.5],
      ['Маффин шоколадный', 'sweets', 400, 5, 20, 50, 1.5],
      ['Капкейк', 'sweets', 380, 4, 18, 52, 1],

      // ☕ НАПИТКИ (20+)
      ['Кофе чёрный', 'drinks', 2, 0.3, 0, 0, 0],
      ['Кофе латте', 'drinks', 40, 2, 1.5, 4.5, 0],
      ['Кофе капучино', 'drinks', 35, 1.8, 1.5, 4, 0],
      ['Чай зелёный', 'drinks', 1, 0.2, 0, 0, 0],
      ['Чай чёрный', 'drinks', 1, 0.2, 0, 0.3, 0],
      ['Сок апельсиновый', 'drinks', 45, 0.7, 0.2, 10, 0.2],
      ['Сок яблочный', 'drinks', 46, 0.1, 0.1, 11, 0.2],
      ['Кока-кола', 'drinks', 42, 0, 0, 11, 0],
      ['Протеиновый коктейль', 'drinks', 60, 12, 1, 2, 0],
      ['Молоко миндальное', 'drinks', 24, 0.6, 1.1, 3, 0.4],
      ['Какао', 'drinks', 88, 3, 3.5, 12, 1],
      ['Компот', 'drinks', 60, 0.2, 0, 15, 0.3],
      ['Вода', 'drinks', 0, 0, 0, 0, 0],
      ['Квас', 'drinks', 27, 0.2, 0, 6.5, 0],
      ['Матча', 'drinks', 3, 0.6, 0, 0.5, 0.1],
      ['Ройбуш', 'drinks', 1, 0.1, 0, 0.1, 0],
      ['Каркаде', 'drinks', 1, 0.1, 0, 0.1, 0],
      ['Молочный улун', 'drinks', 1, 0.1, 0, 0.1, 0],
      ['Пуэр', 'drinks', 1, 0.1, 0, 0.1, 0],
      ['Сок гранатовый', 'drinks', 60, 0.2, 0.2, 14, 0.1],
      ['Сок морковный', 'drinks', 40, 1, 0.1, 9, 0.3],
      ['Сок свекольный', 'drinks', 42, 1, 0.1, 10, 0.5],
      ['Сок тыквенный', 'drinks', 35, 0.5, 0.1, 8, 0.2],
      ['Сок томатный', 'drinks', 17, 0.9, 0.1, 3.8, 0.4],
      ['Сок сельдерея', 'drinks', 16, 0.9, 0.2, 3, 1.6],
      ['Сок лимона', 'drinks', 29, 1.1, 0.3, 9, 2.8],
      ['Сок лайма', 'drinks', 30, 0.7, 0.2, 11, 2.8],
      ['Сок клюквы', 'drinks', 46, 0.4, 0.1, 12, 0.5],
      ['Морс клюквенный', 'drinks', 30, 0.2, 0.1, 8, 0.2],
      ['Компот из сухофруктов', 'drinks', 60, 0.3, 0.1, 15, 0.5],
      ['Кисель', 'drinks', 80, 0.5, 0, 20, 0.5],
      ['Морс ягодный', 'drinks', 35, 0.2, 0.1, 9, 0.2],
      ['Шиповник настой', 'drinks', 15, 0.3, 0, 3.5, 0.5],
      ['Зелёный смузи', 'drinks', 35, 1.5, 0.5, 7, 2],

      // 🥐 ВЫПЕЧКА
      ['Круассан', 'bakery', 406, 8.2, 21, 45, 2.6],
      ['Багет', 'bakery', 274, 10, 2.6, 52, 2.4],
      ['Булочка с маком', 'bakery', 330, 9, 9, 60, 2],
      ['Лаваш', 'bakery', 236, 7.9, 1, 48, 2],
      ['Пита', 'bakery', 275, 9, 1.2, 56, 2.5],
      ['Бублик', 'bakery', 250, 8, 1.5, 50, 2],
      ['Маффин', 'bakery', 375, 5, 17, 53, 1.5],
      ['Чизкейк', 'bakery', 321, 8, 22, 25, 0.5],

      // 🍔 ФАСТФУД
      ['Пицца маргарита', 'fastfood', 266, 11, 10, 33, 2],
      ['Пицца пепперони', 'fastfood', 298, 12, 13, 33, 2],
      ['Бургер', 'fastfood', 295, 17, 14, 24, 1],
      ['Чизбургер', 'fastfood', 303, 15, 15, 27, 1],
      ['Картофель фри', 'fastfood', 312, 3.4, 15, 41, 3.8],
      ['Хот-дог', 'fastfood', 290, 10, 18, 24, 1],
      ['Шаурма', 'fastfood', 210, 12, 12, 17, 1.5],
      ['Наггетсы', 'fastfood', 296, 15, 18, 17, 1],
      ['Суши с лососем', 'fastfood', 150, 6, 1.5, 28, 1],
      ['Ролл Филадельфия', 'fastfood', 142, 6, 4, 20, 1],

      // 💊 ДОБАВКИ
      ['Протеин сывороточный', 'supplements', 370, 80, 5, 10, 0],
      ['Казеин', 'supplements', 360, 70, 5, 10, 0],
      ['Протеиновый батончик', 'supplements', 350, 30, 12, 35, 3],
      ['BCAA', 'supplements', 0, 0, 0, 0, 0],
      ['Креатин', 'supplements', 0, 0, 0, 0, 0],
      ['Омега-3', 'supplements', 902, 0, 100, 0, 0],
      ['Гейнер', 'supplements', 380, 15, 5, 70, 1],
      ['Коллаген', 'supplements', 355, 90, 0, 0, 0],

      // 🧂 СОУСЫ (20+)
      ['Соевый соус', 'sauces', 53, 5, 0, 8, 0],
      ['Майонез', 'sauces', 680, 1, 75, 2.6, 0],
      ['Кетчуп', 'sauces', 112, 1.7, 0.1, 26, 0.3],
      ['Мустард', 'sauces', 66, 4, 3, 6, 0],
      ['Паста томатная', 'sauces', 29, 1.3, 0.1, 6, 1.1],
      ['Песто', 'sauces', 387, 5, 38, 6, 1.5],
      ['Хумус', 'sauces', 166, 8, 10, 14, 6],
      ['Соус BBQ', 'sauces', 172, 1, 0.6, 41, 1],
      ['Соус терияки', 'sauces', 141, 5, 0, 28, 0.5],
      ['Соус сырный', 'sauces', 245, 6, 22, 8, 0],
      ['Соус песто красный', 'sauces', 200, 3, 18, 8, 2],
      ['Соус тартар', 'sauces', 390, 1, 42, 2, 0],
      ['Соус горчичный', 'sauces', 145, 4, 8, 15, 2],
      ['Соус барбекю сладкий', 'sauces', 215, 1, 0.5, 52, 1],
      ['Соус карри', 'sauces', 180, 2, 10, 20, 3],
      ['Соус устричный', 'sauces', 65, 3, 0.5, 13, 0.5],
      ['Соус рыбовый', 'sauces', 50, 4, 0.5, 8, 0],
      ['Соус вустерский', 'sauces', 70, 2, 0, 15, 0],
      ['Соус чили', 'sauces', 70, 1, 0.5, 15, 1],
      ['Аджика', 'sauces', 60, 1.5, 0.5, 12, 2],
      ['Ткемали', 'sauces', 70, 1, 1, 15, 2],
      ['Сацибели', 'sauces', 80, 2, 3, 12, 2],
      ['Наршараб', 'sauces', 210, 0.5, 0, 55, 0.5],
      ['Бальзамический уксус', 'sauces', 80, 0, 0, 20, 0],
      ['Яблочный уксус', 'sauces', 15, 0, 0, 4, 0],
      ['Винный уксус', 'sauces', 20, 0, 0, 5, 0],
      ['Рисовый уксус', 'sauces', 20, 0, 0, 5, 0],
      ['Имбирь маринованный', 'sauces', 20, 0.5, 0.1, 4.5, 0.3],
      ['Васаби', 'sauces', 55, 1.5, 0.5, 12, 2],
      ['Хрен столовый', 'sauces', 48, 2.4, 0.4, 11, 3.2],

      // 🍽️ ГОТОВЫЕ БЛЮДА
      ['Пельмени', 'other', 275, 11, 12, 30, 1],
      ['Вареники с творогом', 'other', 185, 10, 4, 27, 0],
      ['Суп куриный', 'other', 36, 4, 1, 3, 0],
      ['Борщ', 'other', 49, 1.9, 2.2, 5.5, 1],
      ['Салат цезарь', 'other', 190, 14, 11, 7, 1],
      ['Салат греческий', 'other', 70, 3, 5, 4, 1],
      ['Оливье', 'other', 198, 4.4, 16, 10, 1],
      ['Плов', 'other', 210, 6, 11, 22, 1],
    ];

    final uuid = const Uuid();
    for (final p in products) {
      await db.insert('food_products', {
        'id': uuid.v4(),
        'name': p[0],
        'category': p[1],
        'calories': (p[2] as num).toDouble(),
        'protein': (p[3] as num).toDouble(),
        'fat': (p[4] as num).toDouble(),
        'carbs': (p[5] as num).toDouble(),
        'fiber': (p[6] as num).toDouble(),
        'isCustom': 0,
        'createdAt': now,
      });
    }
    debugPrint('✅ Добавлено ${products.length} продуктов');
  }

  // ==================== ОСНОВНЫЕ ГОТОВЫЕ БЛЮДА (60+) ====================

  Future<void> _seedDefaultTemplates(Database db) async {
    final now = DateTime.now().toIso8601String();
    final uuid = const Uuid();
    final products = await db.query('food_products', limit: 600);

    FoodProduct? find(String name) {
      try {
        final row = products.firstWhere((p) => p['name'] == name);
        return FoodProduct(
          id: row['id'] as String,
          name: row['name'] as String,
          category: (row['category'] as String?) ?? 'other',
          calories: (row['calories'] as num?)?.toDouble() ?? 0,
          protein: (row['protein'] as num?)?.toDouble() ?? 0,
          fat: (row['fat'] as num?)?.toDouble() ?? 0,
          carbs: (row['carbs'] as num?)?.toDouble() ?? 0,
          fiber: (row['fiber'] as num?)?.toDouble() ?? 0,
        );
      } catch (_) {
        return null;
      }
    }

    final templates = <Map<String, dynamic>>[];

    void addTemplate(String name, List<MapEntry<String, double>> items) {
      final list = <Map<String, dynamic>>[];
      for (final item in items) {
        final p = find(item.key);
        if (p != null) {
          list.add({'productId': p.id, 'grams': item.value, 'name': p.name});
        }
      }
      if (list.isNotEmpty) {
        templates.add({
          'id': uuid.v4(),
          'name': name,
          'items': jsonEncode(list),
          'createdAt': now,
        });
      }
    }

    // ==================== 🌅 ЗАВТРАКИ (15) ====================
    addTemplate('Овсянка с бананом и орехами', [
      MapEntry('Овсянка', 50), MapEntry('Банан', 100),
      MapEntry('Молоко 2.5%', 200), MapEntry('Грецкий орех', 15),
    ]);
    addTemplate('Овсянка с ягодами и мёдом', [
      MapEntry('Овсянка', 50), MapEntry('Клубника', 80),
      MapEntry('Черника', 50), MapEntry('Мёд', 15),
    ]);
    addTemplate('Овсянка с орехами и сухофруктами', [
      MapEntry('Овсянка', 50), MapEntry('Миндаль', 20),
      MapEntry('Изюм', 20), MapEntry('Мёд', 10),
    ]);
    addTemplate('Яичница с авокадо', [
      MapEntry('Яйцо куриное C0', 120), MapEntry('Авокадо', 100),
      MapEntry('Хлеб цельнозерновой', 40), MapEntry('Масло оливковое', 5),
    ]);
    addTemplate('Омлет с овощами и сыром', [
      MapEntry('Яйцо куриное C0', 120), MapEntry('Помидор', 80),
      MapEntry('Перец болгарский', 50), MapEntry('Сыр твёрдый', 30),
      MapEntry('Молоко 2.5%', 50),
    ]);
    addTemplate('Сырники со сметаной и ягодами', [
      MapEntry('Сырники', 150), MapEntry('Сметана 15%', 30),
      MapEntry('Клубника', 50), MapEntry('Мёд', 10),
    ]);
    addTemplate('Творог с мёдом и орехами', [
      MapEntry('Творог 5%', 200), MapEntry('Мёд', 20),
      MapEntry('Грецкий орех', 20), MapEntry('Черника', 30),
    ]);
    addTemplate('Творог с бананом и корицей', [
      MapEntry('Творог 5%', 200), MapEntry('Банан', 100),
      MapEntry('Мёд', 10),
    ]);
    addTemplate('Бутерброд с авокадо и яйцом', [
      MapEntry('Хлеб цельнозерновой', 50), MapEntry('Авокадо', 80),
      MapEntry('Яйцо куриное C0', 60), MapEntry('Лимон', 10),
    ]);
    addTemplate('Бутерброд с сыром и ветчиной', [
      MapEntry('Хлеб белый', 60), MapEntry('Сыр твёрдый', 30),
      MapEntry('Ветчина', 30), MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Гречневая каша с молоком', [
      MapEntry('Гречка варёная', 150), MapEntry('Молоко 2.5%', 150),
      MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Рисовая каша с яблоком', [
      MapEntry('Каша рисовая на молоке', 200), MapEntry('Яблоко', 80),
    ]);
    addTemplate('Яичница с помидорами и сыром', [
      MapEntry('Яйцо куриное C0', 120), MapEntry('Помидор', 100),
      MapEntry('Сыр твёрдый', 30), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Бутерброд с лососем и сливочным сыром', [
      MapEntry('Хлеб цельнозерновой', 60), MapEntry('Лосось', 60),
      MapEntry('Сыр сливочный', 30), MapEntry('Лимон', 10),
    ]);
    addTemplate('Овсянка с тыквой и специями', [
      MapEntry('Овсянка', 50), MapEntry('Тыква', 100),
      MapEntry('Молоко 2.5%', 150), MapEntry('Корица', 2),
    ]);

    // ==================== ☀️ ОБЕДЫ (18) ====================
    addTemplate('Куриная грудка с гречкой и огурцом', [
      MapEntry('Куриная грудка', 150), MapEntry('Гречка варёная', 150),
      MapEntry('Огурец', 100), MapEntry('Масло оливковое', 5),
    ]);
    addTemplate('Куриная грудка с рисом и овощами', [
      MapEntry('Куриная грудка', 150), MapEntry('Рис белый варёный', 150),
      MapEntry('Брокколи', 100), MapEntry('Морковь', 50),
    ]);
    addTemplate('Курица с пастой и томатным соусом', [
      MapEntry('Макароны варёные', 150), MapEntry('Куриная грудка', 120),
      MapEntry('Паста томатная', 40), MapEntry('Сыр твёрдый', 20),
    ]);
    addTemplate('Куриные котлеты с пюре', [
      MapEntry('Котлеты домашние', 150), MapEntry('Картофель варёный', 200),
      MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Говядина с гречкой и салатом', [
      MapEntry('Говядина', 150), MapEntry('Гречка варёная', 150),
      MapEntry('Огурец', 80), MapEntry('Помидор', 80),
    ]);
    addTemplate('Плов с говядиной и морковью', [
      MapEntry('Плов', 250), MapEntry('Говядина', 80),
    ]);
    addTemplate('Лосось с рисом и спаржей', [
      MapEntry('Лосось', 150), MapEntry('Рис белый варёный', 150),
      MapEntry('Брокколи', 100), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Треска с картофелем и зеленью', [
      MapEntry('Треска', 180), MapEntry('Картофель варёный', 150),
      MapEntry('Укроп', 10), MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Стейк с овощами гриль', [
      MapEntry('Стейк говяжий', 150), MapEntry('Перец болгарский', 100),
      MapEntry('Кабачок', 80), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Борщ со сметаной и хлебом', [
      MapEntry('Борщ', 300), MapEntry('Хлеб белый', 40),
      MapEntry('Сметана 15%', 20),
    ]);
    addTemplate('Куриный суп с лапшой', [
      MapEntry('Суп куриный', 300), MapEntry('Макароны варёные', 50),
      MapEntry('Хлеб белый', 30),
    ]);
    addTemplate('Суп-пюре из тыквы', [
      MapEntry('Тыква', 200), MapEntry('Морковь', 50),
      MapEntry('Молоко 2.5%', 100), MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Фасолевый суп с мясом', [
      MapEntry('Фасоль варёная', 150), MapEntry('Говядина', 80),
      MapEntry('Морковь', 50), MapEntry('Лук репчатый', 30),
    ]);
    addTemplate('Индейка с киноа и авокадо', [
      MapEntry('Индейка', 150), MapEntry('Киноа варёная', 150),
      MapEntry('Авокадо', 80), MapEntry('Помидор', 50),
    ]);
    addTemplate('Овощное рагу с курицей', [
      MapEntry('Куриная грудка', 120), MapEntry('Кабачок', 100),
      MapEntry('Морковь', 50), MapEntry('Перец болгарский', 50),
      MapEntry('Паста томатная', 30),
    ]);
    addTemplate('Киноа с овощами и тофу', [
      MapEntry('Киноа варёная', 150), MapEntry('Тофу', 100),
      MapEntry('Брокколи', 80), MapEntry('Морковь', 50),
      MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Запечённый лосось с овощами', [
      MapEntry('Лосось', 150), MapEntry('Брокколи', 100),
      MapEntry('Морковь', 50), MapEntry('Масло оливковое', 10),
      MapEntry('Лимон', 20),
    ]);
    addTemplate('Куриная грудка с киноа и авокадо', [
      MapEntry('Куриная грудка', 150), MapEntry('Киноа варёная', 120),
      MapEntry('Авокадо', 80), MapEntry('Помидор', 60),
    ]);

    // ==================== 🥗 САЛАТЫ (12) ====================
    addTemplate('Греческий салат с фетой', [
      MapEntry('Салат греческий', 200), MapEntry('Сыр фета', 50),
      MapEntry('Оливки', 30), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Цезарь с курицей', [
      MapEntry('Салат цезарь', 200), MapEntry('Куриная грудка', 100),
      MapEntry('Сыр твёрдый', 30), MapEntry('Хлеб белый', 30),
    ]);
    addTemplate('Салат с тунцом и яйцом', [
      MapEntry('Тунец', 120), MapEntry('Яйцо куриное C0', 60),
      MapEntry('Огурец', 80), MapEntry('Помидор', 80),
      MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Оливье с курицей', [
      MapEntry('Оливье', 200), MapEntry('Куриная грудка', 80),
    ]);
    addTemplate('Салат с авокадо и креветками', [
      MapEntry('Креветки', 100), MapEntry('Авокадо', 100),
      MapEntry('Помидор', 80), MapEntry('Лимон', 10),
    ]);
    addTemplate('Салат с рукколой и пармезаном', [
      MapEntry('Руккола', 50), MapEntry('Сыр пармезан', 30),
      MapEntry('Помидор', 80), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Салат с фасолью и тунцом', [
      MapEntry('Фасоль варёная', 100), MapEntry('Тунец', 80),
      MapEntry('Лук репчатый', 30), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Салат из свежих овощей', [
      MapEntry('Огурец', 100), MapEntry('Помидор', 100),
      MapEntry('Перец болгарский', 50), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Салат с курицей и ананасом', [
      MapEntry('Куриная грудка', 100), MapEntry('Ананас', 80),
      MapEntry('Сыр твёрдый', 30), MapEntry('Сметана 15%', 20),
    ]);
    addTemplate('Салат с киноа и овощами', [
      MapEntry('Киноа варёная', 120), MapEntry('Огурец', 80),
      MapEntry('Помидор', 80), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Нисуаз с тунцом', [
      MapEntry('Тунец', 100), MapEntry('Яйцо куриное C0', 60),
      MapEntry('Огурец', 80), MapEntry('Помидор', 80),
      MapEntry('Фасоль стручковая', 50), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Тёплый салат с курицей', [
      MapEntry('Куриная грудка', 100), MapEntry('Руккола', 40),
      MapEntry('Помидор', 80), MapEntry('Сыр пармезан', 20),
      MapEntry('Масло оливковое', 10),
    ]);

    // ==================== 🌙 УЖИНЫ (15) ====================
    addTemplate('Куриная грудка с овощами', [
      MapEntry('Куриная грудка', 150), MapEntry('Брокколи', 100),
      MapEntry('Морковь', 50), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Рыба с овощами и лимоном', [
      MapEntry('Треска', 180), MapEntry('Кабачок', 100),
      MapEntry('Помидор', 80), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Творожная запеканка', [
      MapEntry('Творог 5%', 200), MapEntry('Яйцо куриное C0', 60),
      MapEntry('Манка', 20), MapEntry('Сметана 15%', 20),
    ]);
    addTemplate('Омлет с грибами и сыром', [
      MapEntry('Яйцо куриное C0', 120), MapEntry('Шампиньоны', 80),
      MapEntry('Сыр твёрдый', 30), MapEntry('Молоко 2.5%', 50),
    ]);
    addTemplate('Индейка с цветной капустой', [
      MapEntry('Индейка', 150), MapEntry('Капуста цветная', 150),
      MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Стейк с салатом', [
      MapEntry('Стейк говяжий', 150), MapEntry('Салат листовой', 50),
      MapEntry('Помидор', 80), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Рыба с киноа', [
      MapEntry('Лосось', 150), MapEntry('Киноа варёная', 120),
      MapEntry('Брокколи', 100), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Овощное рагу с тофу', [
      MapEntry('Тофу', 120), MapEntry('Кабачок', 100),
      MapEntry('Морковь', 50), MapEntry('Перец болгарский', 50),
    ]);
    addTemplate('Курица с шампиньонами в сливках', [
      MapEntry('Куриная грудка', 120), MapEntry('Шампиньоны', 100),
      MapEntry('Молоко 2.5%', 100), MapEntry('Масло сливочное', 10),
    ]);
    addTemplate('Запечённая фасоль с овощами', [
      MapEntry('Фасоль варёная', 150), MapEntry('Помидор', 80),
      MapEntry('Лук репчатый', 30), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Курица с бататом и брокколи', [
      MapEntry('Куриная грудка', 150), MapEntry('Батат', 150),
      MapEntry('Брокколи', 100), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Рыба с киноа и овощами', [
      MapEntry('Минтай', 150), MapEntry('Киноа варёная', 120),
      MapEntry('Цветная капуста', 100), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Тофу с овощами в азиатском стиле', [
      MapEntry('Тофу', 120), MapEntry('Перец болгарский', 80),
      MapEntry('Брокколи', 80), MapEntry('Соевый соус', 20),
      MapEntry('Масло кунжутное', 10),
    ]);
    addTemplate('Запеканка с индейкой и овощами', [
      MapEntry('Индейка', 120), MapEntry('Кабачок', 80),
      MapEntry('Морковь', 50), MapEntry('Сыр твёрдый', 30),
      MapEntry('Яйцо куриное C0', 60),
    ]);
    addTemplate('Куриные рулетики с сыром', [
      MapEntry('Куриная грудка', 120), MapEntry('Сыр твёрдый', 30),
      MapEntry('Шпинат', 40), MapEntry('Масло оливковое', 10),
    ]);

    // ==================== 🍎 ПЕРЕКУСЫ И СНЕКИ (12) ====================
    addTemplate('Протеиновый коктейль с бананом', [
      MapEntry('Протеин сывороточный', 30), MapEntry('Банан', 100),
      MapEntry('Молоко 2.5%', 250),
    ]);
    addTemplate('Протеиновый смузи с ягодами', [
      MapEntry('Протеин сывороточный', 30), MapEntry('Клубника', 80),
      MapEntry('Черника', 50), MapEntry('Молоко 2.5%', 200),
    ]);
    addTemplate('Кефир с мюсли и бананом', [
      MapEntry('Кефир 2.5%', 250), MapEntry('Банан', 100),
      MapEntry('Мюсли', 30),
    ]);
    addTemplate('Йогурт с гранолой и ягодами', [
      MapEntry('Йогурт греческий', 150), MapEntry('Гранола', 40),
      MapEntry('Черника', 50),
    ]);
    addTemplate('Творог с ягодами и мёдом', [
      MapEntry('Творог 5%', 150), MapEntry('Клубника', 80),
      MapEntry('Мёд', 15),
    ]);
    addTemplate('Орехи с сухофруктами', [
      MapEntry('Миндаль', 30), MapEntry('Грецкий орех', 20),
      MapEntry('Изюм', 20), MapEntry('Финики', 20),
    ]);
    addTemplate('Яблоко с арахисовой пастой', [
      MapEntry('Яблоко', 150), MapEntry('Арахисовая паста', 20),
    ]);
    addTemplate('Сельдерей с арахисовой пастой', [
      MapEntry('Сельдерей', 80), MapEntry('Арахисовая паста', 20),
    ]);
    addTemplate('Тост с авокадо', [
      MapEntry('Хлеб цельнозерновой', 50), MapEntry('Авокадо', 80),
      MapEntry('Лимон', 10),
    ]);
    addTemplate('Рисовые хлебцы с творогом', [
      MapEntry('Хлебцы рисовые', 30), MapEntry('Творог 5%', 80),
      MapEntry('Огурец', 50),
    ]);
    addTemplate('Хумус с овощами', [
      MapEntry('Хумус', 60), MapEntry('Морковь', 80),
      MapEntry('Огурец', 80), MapEntry('Перец болгарский', 60),
    ]);
    addTemplate('Греческий йогурт с мёдом', [
      MapEntry('Йогурт греческий', 150), MapEntry('Мёд', 15),
      MapEntry('Грецкий орех', 15),
    ]);

    // ==================== 🥤 НАПИТКИ (6) ====================
    addTemplate('Кофе с молоком', [
      MapEntry('Кофе латте', 250), MapEntry('Молоко 2.5%', 50),
    ]);
    addTemplate('Какао с молоком', [
      MapEntry('Какао', 200), MapEntry('Молоко 2.5%', 200),
    ]);
    addTemplate('Зелёный смузи', [
      MapEntry('Шпинат', 80), MapEntry('Банан', 100),
      MapEntry('Яблоко', 80), MapEntry('Вода', 200),
    ]);
    addTemplate('Смузи из ягод', [
      MapEntry('Клубника', 80), MapEntry('Черника', 50),
      MapEntry('Молоко 2.5%', 200), MapEntry('Мёд', 10),
    ]);
    addTemplate('Фруктовый компот', [
      MapEntry('Компот', 250), MapEntry('Яблоко', 50),
    ]);
    addTemplate('Зелёный чай с мятой', [
      MapEntry('Чай зелёный', 250), MapEntry('Мята', 10),
      MapEntry('Лимон', 10), MapEntry('Мёд', 10),
    ]);

    // ==================== 🍳 ВЕГЕТАРИАНСКИЕ (8) ====================
    addTemplate('Гречка с грибами и луком', [
      MapEntry('Гречка варёная', 150), MapEntry('Шампиньоны', 80),
      MapEntry('Лук репчатый', 30), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Рис с овощами и тофу', [
      MapEntry('Рис белый варёный', 150), MapEntry('Тофу', 120),
      MapEntry('Морковь', 50), MapEntry('Перец болгарский', 50),
    ]);
    addTemplate('Чечевица с овощами', [
      MapEntry('Чечевица варёная', 150), MapEntry('Морковь', 50),
      MapEntry('Лук репчатый', 30), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Нут с томатами и специями', [
      MapEntry('Нут варёный', 150), MapEntry('Помидор', 100),
      MapEntry('Лук репчатый', 30), MapEntry('Масло оливковое', 10),
    ]);
    addTemplate('Тофу с овощами в соусе терияки', [
      MapEntry('Тофу', 120), MapEntry('Перец болгарский', 80),
      MapEntry('Соус терияки', 30), MapEntry('Рис белый варёный', 100),
    ]);
    addTemplate('Тофу-болоньезе с пастой', [
      MapEntry('Тофу', 120), MapEntry('Макароны варёные', 150),
      MapEntry('Паста томатная', 40), MapEntry('Морковь', 30),
      MapEntry('Лук репчатый', 30),
    ]);
    addTemplate('Чечевичный суп с овощами', [
      MapEntry('Чечевица варёная', 150), MapEntry('Морковь', 50),
      MapEntry('Лук репчатый', 30), MapEntry('Паста томатная', 30),
      MapEntry('Чеснок', 10),
    ]);
    addTemplate('Нут-бургер с овощами', [
      MapEntry('Нут варёный', 120), MapEntry('Хлеб цельнозерновой', 50),
      MapEntry('Салат листовой', 30), MapEntry('Помидор', 50),
      MapEntry('Лук репчатый', 20),
    ]);

    // ==================== 🏋️ СПОРТИВНЫЕ (6) ====================
    addTemplate('Протеин после тренировки', [
      MapEntry('Протеин сывороточный', 30), MapEntry('Банан', 100),
      MapEntry('Молоко 2.5%', 250),
    ]);
    addTemplate('Гейнер с творогом', [
      MapEntry('Гейнер', 50), MapEntry('Творог 5%', 100),
      MapEntry('Банан', 80), MapEntry('Молоко 2.5%', 200),
    ]);
    addTemplate('BCAA с водой', [
      MapEntry('BCAA', 10), MapEntry('Вода', 300),
    ]);
    addTemplate('Куриная грудка с рисом (after workout)', [
      MapEntry('Куриная грудка', 150), MapEntry('Рис белый варёный', 150),
      MapEntry('Брокколи', 100),
    ]);
    addTemplate('Протеиновый батончик с кефиром', [
      MapEntry('Протеиновый батончик', 50), MapEntry('Кефир 2.5%', 200),
    ]);
    addTemplate('Протеиновый омлет с овощами', [
      MapEntry('Яйцо куриное C0', 120), MapEntry('Протеин сывороточный', 20),
      MapEntry('Помидор', 60), MapEntry('Шпинат', 40),
      MapEntry('Масло оливковое', 10),
    ]);

    for (final t in templates) {
      await db.insert('meal_templates', t);
    }
    debugPrint('✅ Добавлено ${templates.length} основных готовых блюд');
  }

  Future<void> _seedDefaultGoals(Database db) async {
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM nutrition_goals');
    if ((count.first['count'] as int) > 0) return;

    final now = DateTime.now().toIso8601String();
    await db.insert('nutrition_goals', {
      'id': const Uuid().v4(),
      'date': null,
      'calories': 2200.0,
      'protein': 140.0,
      'fat': 70.0,
      'carbs': 250.0,
      'waterMl': 2500,
      'isActive': 1,
      'createdAt': now,
    });
    debugPrint('✅ Созданы дефолтные цели питания');
  }

  // ==================== CRUD ====================

  Future<void> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(String table,
      {String? where, List<Object?>? whereArgs, String? orderBy, int? limit}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<int> update(String table, Map<String, dynamic> values,
      {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }
}