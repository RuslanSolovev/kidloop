class SvCalculator {
  static final Map<String, int> categoryBase = {
    'Игрушки': 50,
    'LEGO': 120,
    'Самокат': 300,
    'Книги': 40,
    'Одежда': 70,
    'Коляска': 500,
    'Мебель': 400,
    'Техника': 350,
    'Развивашки': 80,
    'Спорт': 250,
    'Творчество': 60,
    'Пазлы': 45,
    'Конструктор': 130,
    'Куклы': 55,
    'Машинки': 65,
    'Настолки': 90,
    'Велосипед': 450,
    'Электроника': 200,
    'Детская посуда': 35,
    'Постель': 75,
    'Обувь': 100,
    'Школьное': 85,
    'Музыкальное': 180,
    'Игровая приставка': 600,
    'Надувное': 150,
  };

  static final Map<String, double> conditionMultiplier = {
    'Новый': 1.5,
    'Отличный': 1.2,
    'Хороший': 1.0,
    'Обычный': 0.7,
  };

  static int calculate({
    required String category,
    required String condition,
  }) {
    final base = categoryBase[category] ?? 50;
    final multiplier = conditionMultiplier[condition] ?? 1.0;
    return (base * multiplier).toInt();
  }
}