class LevelCalculator {
  // 🔥 Единая формула расчёта уровня
  static int calculateLevel({
    required int totalSteps,
    required int itemsCount,
    required int completedTrades,
    required int sentOffers,
  }) {
    final score = totalSteps ~/ 1000 + itemsCount * 2 + completedTrades * 5 + sentOffers;

    if (score < 10) return 1;
    if (score < 25) return 2;
    if (score < 50) return 3;
    if (score < 100) return 4;
    if (score < 200) return 5;
    if (score < 350) return 6;
    if (score < 550) return 7;
    if (score < 800) return 8;
    if (score < 1100) return 9;
    return 10;
  }

  // 🔥 Название уровня
  static String getLevelName(int level) {
    switch (level) {
      case 1: return 'Новичок';
      case 2: return 'Любитель';
      case 3: return 'Исследователь';
      case 4: return 'Коллекционер';
      case 5: return 'Меняла';
      case 6: return 'Бизнесмен';
      case 7: return 'Профи';
      case 8: return 'Эксперт';
      case 9: return 'Мастер';
      case 10: return 'Легенда';
      default: return 'Новичок';
    }
  }

  // 🔥 Прогресс до следующего уровня (0.0 - 1.0)
  static double getLevelProgress(int score) {
    if (score < 10) return score / 10;
    if (score < 25) return (score - 10) / 15;
    if (score < 50) return (score - 25) / 25;
    if (score < 100) return (score - 50) / 50;
    if (score < 200) return (score - 100) / 100;
    if (score < 350) return (score - 200) / 150;
    if (score < 550) return (score - 350) / 200;
    if (score < 800) return (score - 550) / 250;
    if (score < 1100) return (score - 800) / 300;
    return 1.0;
  }

  // 🔥 Сколько очков нужно до следующего уровня
  static int getScoreToNextLevel(int score) {
    if (score < 10) return 10 - score;
    if (score < 25) return 25 - score;
    if (score < 50) return 50 - score;
    if (score < 100) return 100 - score;
    if (score < 200) return 200 - score;
    if (score < 350) return 350 - score;
    if (score < 550) return 550 - score;
    if (score < 800) return 800 - score;
    if (score < 1100) return 1100 - score;
    return 0;
  }

  // 🔥 Общий счёт
  static int calculateScore({
    required int totalSteps,
    required int itemsCount,
    required int completedTrades,
    required int sentOffers,
  }) {
    return totalSteps ~/ 1000 + itemsCount * 2 + completedTrades * 5 + sentOffers;
  }
}