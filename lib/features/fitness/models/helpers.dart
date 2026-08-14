// features/fitness/models/helpers.dart
import 'dart:math';
import 'fitness_models.dart';
import 'enums.dart';

class FitnessHelpers {
  // ==================== КАЛЬКУЛЯТОР 1RM ====================

  /// Вычисляет одноповторный максимум (1RM) по формуле Эпли
  /// weight - рабочий вес, reps - количество повторений
  static double calculate1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0.0;
    if (reps == 1) return weight;

    // Формула Эпли: 1RM = weight × (1 + reps/30)
    return weight * (1 + reps / 30.0);
  }

  /// Альтернативная формула Бжицки
  static double calculate1RMBrzycki(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0.0;
    if (reps == 1) return weight;

    // Формула Бжицки: 1RM = weight / (1.0278 - 0.0278 × reps)
    return weight / (1.0278 - 0.0278 * reps);
  }

  /// Вычисляет процент от 1RM
  static double calculateWeightFromPercentage(double oneRM, double percentage) {
    return oneRM * (percentage / 100.0);
  }

  /// Вычисляет количество повторений для заданного процента от 1RM
  static int estimateRepsFromPercentage(double percentage) {
    if (percentage >= 100) return 1;
    if (percentage >= 95) return 2;
    if (percentage >= 90) return 3;
    if (percentage >= 85) return 5;
    if (percentage >= 80) return 8;
    if (percentage >= 75) return 10;
    if (percentage >= 70) return 12;
    if (percentage >= 65) return 15;
    return 20;
  }

  /// Возвращает интенсивность тренировки (процент от 1RM)
  static double calculateIntensity(double weight, double oneRM) {
    if (oneRM <= 0) return 0.0;
    return (weight / oneRM) * 100.0;
  }

  // ==================== РАСЧЁТ РАЗМИНОЧНЫХ ПОДХОДОВ ====================

  /// Генерирует разминочные подходы на основе рабочего веса
  static List<ExerciseSet> generateWarmupSets(double workWeight, {int totalWarmupSets = 3}) {
    final warmupSets = <ExerciseSet>[];
    final percentages = [0.5, 0.7, 0.9]; // 50%, 70%, 90%
    final reps = [10, 5, 2];

    for (int i = 0; i < min(totalWarmupSets, percentages.length); i++) {
      warmupSets.add(ExerciseSet(
        setNumber: i + 1,
        weight: (workWeight * percentages[i]).roundToDouble(),
        reps: reps[i],
        isWarmup: true,
        status: SetStatus.pending,
        rpe: percentages[i] <= 0.5 ? 3.0 : (percentages[i] <= 0.7 ? 5.0 : 7.0),
      ));
    }

    return warmupSets;
  }

  /// Расширенная генерация разминки с учётом уровня подготовки
  static List<ExerciseSet> generateAdvancedWarmup(
      double workWeight, {
        FitnessLevel level = FitnessLevel.intermediate,
      }) {
    switch (level) {
      case FitnessLevel.beginner:
        return generateWarmupSets(workWeight, totalWarmupSets: 4);
      case FitnessLevel.intermediate:
        return generateWarmupSets(workWeight, totalWarmupSets: 3);
      case FitnessLevel.advanced:
      case FitnessLevel.elite:
        return generateWarmupSets(workWeight, totalWarmupSets: 5);
    }
  }

  // ==================== УМНАЯ ПРОГРЕССИЯ НАГРУЗКИ ====================

  /// Предлагает увеличение веса на основе прошлых тренировок
  static double? suggestWeightIncrease({
    required List<ProgressRecord> recentRecords,
    required double currentWeight,
    int lookbackPeriod = 3, // последние N тренировок
    int targetReps = 8,
    double repsTolerance = 1.0, // допустимое отклонение повторений
  }) {
    if (recentRecords.isEmpty) return null;

    // Берём последние записи
    final recent = recentRecords
        .where((r) => r.bestWeight > 0 && r.bestReps > 0)
        .take(lookbackPeriod)
        .toList();

    if (recent.isEmpty) return null;

    // Проверяем, все ли подходы выполнены с целевыми повторениями
    bool allCompleted = recent.every((r) => r.bestReps >= targetReps - repsTolerance);

    if (!allCompleted) return null;

    // Вычисляем средний вес
    double avgWeight = recent.map((r) => r.bestWeight).reduce((a, b) => a + b) / recent.length;

    // Предлагаем увеличение
    double increment;
    if (currentWeight <= 20) {
      increment = 1.0; // 1 кг для маленьких весов
    } else if (currentWeight <= 50) {
      increment = 2.5;
    } else if (currentWeight <= 100) {
      increment = 5.0;
    } else {
      increment = 10.0;
    }

    double suggestedWeight = avgWeight + increment;

    // Проверяем, не превышает ли 5%
    if (suggestedWeight > avgWeight * 1.05) {
      suggestedWeight = (avgWeight * 1.05).roundToDouble();
    }

    return suggestedWeight;
  }

  /// Проверяет готовность к прогрессии
  static ProgressionStatus checkProgressionReadiness({
    required List<ExerciseSet> completedSets,
    required int targetReps,
    required double targetRpe,
  }) {
    if (completedSets.isEmpty) {
      return ProgressionStatus.insufficientData;
    }

    // Проверяем, все ли подходы выполнены
    bool allCompleted = completedSets.every((s) => s.status == SetStatus.completed);
    if (!allCompleted) {
      return ProgressionStatus.notAllSetsCompleted;
    }

    // Проверяем повторения
    bool repsAchieved = completedSets.every((s) => s.reps >= targetReps);

    // Проверяем RPE
    double avgRpe = completedSets
        .where((s) => s.rpe != null)
        .map((s) => s.rpe!)
        .reduce((a, b) => a + b) / completedSets.length;

    if (repsAchieved && avgRpe < targetRpe) {
      return ProgressionStatus.readyToIncrease;
    } else if (repsAchieved && avgRpe <= targetRpe) {
      return ProgressionStatus.maintain;
    } else {
      return ProgressionStatus.needsMoreWork;
    }
  }

  // ==================== АНАЛИЗ МЫШЕЧНОГО ДИСБАЛАНСА ====================

  /// Анализирует объём тренировок по группам мышц и находит отстающие
  static Map<MuscleGroup, double> calculateMuscleVolume(
      List<WorkoutLog> recentLogs, {
        int lookbackWeeks = 4,
      }) {
    final volumeByMuscle = <MuscleGroup, double>{};
    final cutoffDate = DateTime.now().subtract(Duration(days: lookbackWeeks * 7));

    for (final log in recentLogs) {
      if (log.date.isBefore(cutoffDate)) continue;

      for (final exercise in log.exercisesLog) {
        // Нужно получить упражнение из базы, здесь заглушка
        double exerciseVolume = exercise.sets
            .where((s) => s.status == SetStatus.completed)
            .fold(0.0, (sum, set) => sum + set.volume);

        // Распределяем объём по группам мышц (будет доработано в провайдере)
        // Здесь просто пример структуры
      }
    }

    return volumeByMuscle;
  }

  /// Находит несбалансированные группы мышц
  static List<MuscleImbalance> detectImbalances(
      Map<MuscleGroup, double> volumeByMuscle, {
        double imbalanceThreshold = 0.3, // 30% разница считается дисбалансом
      }) {
    final imbalances = <MuscleImbalance>[];

    // Проверяем антагонисты
    final antagonistPairs = [
      [MuscleGroup.chest, MuscleGroup.back],
      [MuscleGroup.biceps, MuscleGroup.triceps],
      [MuscleGroup.quadriceps, MuscleGroup.hamstrings],
      [MuscleGroup.abs, MuscleGroup.lowerBack],
      [MuscleGroup.shoulders, MuscleGroup.lats],
    ];

    for (final pair in antagonistPairs) {
      final first = volumeByMuscle[pair[0]] ?? 0;
      final second = volumeByMuscle[pair[1]] ?? 0;

      if (first == 0 && second == 0) continue;

      double ratio;
      MuscleGroup weaker;
      MuscleGroup stronger;

      if (first > second) {
        ratio = second / (first == 0 ? 1 : first);
        weaker = pair[1];
        stronger = pair[0];
      } else {
        ratio = first / (second == 0 ? 1 : second);
        weaker = pair[0];
        stronger = pair[1];
      }

      if (ratio < (1 - imbalanceThreshold)) {
        imbalances.add(MuscleImbalance(
          weakerMuscle: weaker,
          strongerMuscle: stronger,
          ratio: ratio,
          recommendation: 'Увеличьте объём на ${weaker.displayName}',
        ));
      }
    }

    return imbalances;
  }

  // ==================== ПРОГНОЗ ПРОГРЕССА ====================

  /// Прогнозирует, когда будет достигнута цель
  static DateTime? predictGoalAchievement({
    required List<ProgressRecord> history,
    required double goalWeight,
    double weeklyIncrease = 2.5, // средний прирост в неделю
  }) {
    if (history.isEmpty || weeklyIncrease <= 0) return null;

    // Берём последнюю запись
    history.sort((a, b) => a.date.compareTo(b.date));
    final lastRecord = history.last;

    if (lastRecord.estimated1RM >= goalWeight) return null;

    // Вычисляем, сколько недель нужно
    double remaining = goalWeight - lastRecord.estimated1RM;
    int weeksNeeded = (remaining / weeklyIncrease).ceil();

    return lastRecord.date.add(Duration(days: weeksNeeded * 7));
  }

  /// Вычисляет тренд прогресса (линейная регрессия)
  static TrendLine calculateTrendLine(List<ProgressRecord> history) {
    if (history.length < 2) {
      return TrendLine(slope: 0, intercept: 0, confidence: 0);
    }

    final n = history.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    // X = дни от первой записи
    final firstDate = history.first.date;
    final List<double> xValues = [];
    final List<double> yValues = [];

    for (final record in history) {
      double x = record.date.difference(firstDate).inDays.toDouble();
      double y = record.estimated1RM;
      xValues.add(x);
      yValues.add(y);
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    // Наклон линии тренда
    double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    double intercept = (sumY - slope * sumX) / n;

    // Коэффициент детерминации R²
    double yMean = sumY / n;
    double ssRes = 0, ssTot = 0;
    for (int i = 0; i < n; i++) {
      double yPred = slope * xValues[i] + intercept;
      ssRes += pow(yValues[i] - yPred, 2);
      ssTot += pow(yValues[i] - yMean, 2);
    }
    double rSquared = ssTot > 0 ? 1 - (ssRes / ssTot) : 0;

    return TrendLine(slope: slope, intercept: intercept, confidence: rSquared);
  }

  /// Прогнозирует значение 1RM через N дней
  static double predictFuture1RM(TrendLine trend, int daysFromNow) {
    return trend.slope * daysFromNow + trend.intercept;
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  /// Вычисляет общий тоннаж тренировки
  static double calculateTotalVolume(List<WorkoutExercise> exercises) {
    return exercises.fold(0.0, (sum, exercise) {
      return sum + exercise.sets
          .where((s) => s.status == SetStatus.completed)
          .fold(0.0, (setSum, set) => setSum + set.volume);
    });
  }

  /// Вычисляет средний RPE тренировки
  static double? calculateAverageRpe(List<WorkoutExercise> exercises) {
    final rpeValues = <double>[];
    for (final exercise in exercises) {
      for (final set in exercise.sets) {
        if (set.rpe != null && set.status == SetStatus.completed) {
          rpeValues.add(set.rpe!);
        }
      }
    }
    if (rpeValues.isEmpty) return null;
    return rpeValues.reduce((a, b) => a + b) / rpeValues.length;
  }

  /// Вычисляет длительность тренировки
  static Duration? calculateWorkoutDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    return end.difference(start);
  }

  /// Форматирует длительность в читаемый вид
  static String formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    }
    return '${minutes}м';
  }

  /// Получает рекомендуемое время отдыха между подходами
  static int getRecommendedRestSeconds(double intensity) {
    if (intensity >= 90) return 180; // 3 минуты для максимальных весов
    if (intensity >= 80) return 120; // 2 минуты
    if (intensity >= 70) return 90;  // 1.5 минуты
    if (intensity >= 60) return 60;  // 1 минута
    return 45;
  }

  /// Вычисляет мышечную стимуляцию (гипотетический показатель)
  static double calculateStimulation(List<ExerciseSet> sets) {
    if (sets.isEmpty) return 0.0;
    return sets
        .where((s) => s.status == SetStatus.completed)
        .fold(0.0, (sum, set) {
      // Стимуляция ≈ вес × повторения × (1 - RPE/10)
      double rpeFactor = set.rpe != null ? (1 - set.rpe! / 10) : 0.3;
      return sum + (set.volume * rpeFactor);
    });
  }

  // ==================== ШАБЛОНЫ УПРАЖНЕНИЙ ДЛЯ СУПЕРСЕТОВ ====================

  /// Предлагает упражнения-антагонисты для суперсетов
  static List<MuscleGroup> getAntagonistMuscles(MuscleGroup muscle) {
    switch (muscle) {
      case MuscleGroup.chest:
        return [MuscleGroup.back, MuscleGroup.lats];
      case MuscleGroup.back:
      case MuscleGroup.lats:
        return [MuscleGroup.chest];
      case MuscleGroup.biceps:
        return [MuscleGroup.triceps];
      case MuscleGroup.triceps:
        return [MuscleGroup.biceps];
      case MuscleGroup.quadriceps:
        return [MuscleGroup.hamstrings];
      case MuscleGroup.hamstrings:
        return [MuscleGroup.quadriceps];
      case MuscleGroup.abs:
        return [MuscleGroup.lowerBack];
      case MuscleGroup.lowerBack:
        return [MuscleGroup.abs];
      case MuscleGroup.shoulders:
        return [MuscleGroup.lats, MuscleGroup.back];
      default:
        return [];
    }
  }

  /// Проверяет, можно ли объединить упражнения в суперсет
  static bool canFormSuperset(MuscleGroup muscle1, MuscleGroup muscle2) {
    return getAntagonistMuscles(muscle1).contains(muscle2) ||
        getAntagonistMuscles(muscle2).contains(muscle1);
  }
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ КЛАССЫ ====================

/// Статус готовности к прогрессии
enum ProgressionStatus {
  readyToIncrease,     // можно увеличивать вес
  maintain,            // оставить текущий вес
  needsMoreWork,       // нужно ещё поработать
  notAllSetsCompleted, // не все подходы выполнены
  insufficientData,    // недостаточно данных
}

extension ProgressionStatusExtension on ProgressionStatus {
  String get displayName {
    switch (this) {
      case ProgressionStatus.readyToIncrease: return 'Можно увеличить вес';
      case ProgressionStatus.maintain: return 'Сохранить текущий вес';
      case ProgressionStatus.needsMoreWork: return 'Нужно ещё поработать';
      case ProgressionStatus.notAllSetsCompleted: return 'Не все подходы выполнены';
      case ProgressionStatus.insufficientData: return 'Недостаточно данных';
    }
  }

  String get emoji {
    switch (this) {
      case ProgressionStatus.readyToIncrease: return '⬆️';
      case ProgressionStatus.maintain: return '➡️';
      case ProgressionStatus.needsMoreWork: return '💪';
      case ProgressionStatus.notAllSetsCompleted: return '⚠️';
      case ProgressionStatus.insufficientData: return '📊';
    }
  }
}

/// Информация о мышечном дисбалансе
class MuscleImbalance {
  final MuscleGroup weakerMuscle;
  final MuscleGroup strongerMuscle;
  final double ratio;        // отношение слабой к сильной (0-1)
  final String recommendation;

  MuscleImbalance({
    required this.weakerMuscle,
    required this.strongerMuscle,
    required this.ratio,
    required this.recommendation,
  });

  double get imbalancePercent => ((1 - ratio) * 100).roundToDouble();
}

/// Линия тренда для прогноза
class TrendLine {
  final double slope;       // наклон (прирост в день)
  final double intercept;   // пересечение (начальное значение)
  final double confidence;  // R² (0-1)

  TrendLine({
    required this.slope,
    required this.intercept,
    required this.confidence,
  });

  /// Прогноз на указанный день
  double predict(int day) => slope * day + intercept;

  /// Качество прогноза
  String get confidenceLevel {
    if (confidence > 0.8) return 'Высокая точность';
    if (confidence > 0.5) return 'Средняя точность';
    return 'Низкая точность';
  }
}