// features/fitness/models/enums.dart
import 'package:flutter/material.dart';


/// Тип упражнения
enum ExerciseType {
  strength,    // силовое (тренажёры, свободные веса)
  cardio,      // кардио (бег, велосипед, плавание)
  bodyweight,  // с собственным весом
  boxing,      // бокс/груша
  yoga,        // йога/растяжка
  other,       // другое
}

/// Группы мышц (основные)
enum MuscleGroup {
  chest,         // грудь
  back,          // спина
  shoulders,     // плечи
  biceps,        // бицепс
  triceps,       // трицепс
  forearms,      // предплечья
  abs,           // пресс
  obliques,      // косые мышцы живота
  glutes,        // ягодицы
  quadriceps,    // квадрицепс
  hamstrings,    // бицепс бедра
  calves,        // икры
  traps,         // трапеции
  lats,          // широчайшие
  lowerBack,     // поясница
  fullBody,      // всё тело
  cardio_vascular, // сердечно-сосудистая
  flexibility,   // гибкость
}

/// Тип тренировочной программы
enum ProgramType {
  daily,    // на один день
  weekly,   // на неделю
  monthly,  // на месяц
}

/// Статус выполнения дня тренировки
enum WorkoutDayStatus {
  pending,    // ожидает
  completed,  // выполнена
  skipped,    // пропущена
  rest,       // день отдыха
}

/// Тип группировки упражнений
enum ExerciseGroupType {
  straight,  // обычный порядок
  superset,  // суперсет (2 упражнения)
  circuit,   // круговая (3+ упражнений)
}

/// Статус подхода
enum SetStatus {
  pending,    // не начат
  inProgress, // выполняется
  completed,  // завершён
  skipped,    // пропущен
  failed,     // не выполнен (отказ)
}

/// Пол пользователя (для схематической фигуры)
enum UserGender {
  male,
  female,
}

/// Уровень подготовки
enum FitnessLevel {
  beginner,      // новичок
  intermediate,  // средний
  advanced,      // продвинутый
  elite,         // элитный
}

/// Цель тренировок
enum FitnessGoal {
  strength,      // сила
  hypertrophy,   // масса
  endurance,     // выносливость
  weightLoss,    // похудение
  flexibility,   // гибкость
  general,       // общая физподготовка
}

/// Расширения для удобного отображения
extension ExerciseTypeExtension on ExerciseType {
  String get displayName {
    switch (this) {
      case ExerciseType.strength: return 'Силовое';
      case ExerciseType.cardio: return 'Кардио';
      case ExerciseType.bodyweight: return 'Свой вес';
      case ExerciseType.boxing: return 'Бокс';
      case ExerciseType.yoga: return 'Йога';
      case ExerciseType.other: return 'Другое';
    }
  }

  String get emoji {
    switch (this) {
      case ExerciseType.strength: return '🏋️';
      case ExerciseType.cardio: return '🏃';
      case ExerciseType.bodyweight: return '🤸';
      case ExerciseType.boxing: return '🥊';
      case ExerciseType.yoga: return '🧘';
      case ExerciseType.other: return '🔧';
    }
  }
}

extension MuscleGroupExtension on MuscleGroup {
  String get displayName {
    switch (this) {
      case MuscleGroup.chest: return 'Грудь';
      case MuscleGroup.back: return 'Спина';
      case MuscleGroup.shoulders: return 'Плечи';
      case MuscleGroup.biceps: return 'Бицепс';
      case MuscleGroup.triceps: return 'Трицепс';
      case MuscleGroup.forearms: return 'Предплечья';
      case MuscleGroup.abs: return 'Пресс';
      case MuscleGroup.obliques: return 'Косые';
      case MuscleGroup.glutes: return 'Ягодицы';
      case MuscleGroup.quadriceps: return 'Квадрицепс';
      case MuscleGroup.hamstrings: return 'Бицепс бедра';
      case MuscleGroup.calves: return 'Икры';
      case MuscleGroup.traps: return 'Трапеции';
      case MuscleGroup.lats: return 'Широчайшие';
      case MuscleGroup.lowerBack: return 'Поясница';
      case MuscleGroup.fullBody: return 'Всё тело';
      case MuscleGroup.cardio_vascular: return 'Кардио';
      case MuscleGroup.flexibility: return 'Гибкость';
    }
  }

  String get emoji {
    switch (this) {
      case MuscleGroup.chest: return '🦾';
      case MuscleGroup.back: return '🔙';
      case MuscleGroup.shoulders: return '🦿';
      case MuscleGroup.biceps: return '💪';
      case MuscleGroup.triceps: return '💪';
      case MuscleGroup.forearms: return '🤲';
      case MuscleGroup.abs: return '🏋️';
      case MuscleGroup.obliques: return '🔄';
      case MuscleGroup.glutes: return '🍑';
      case MuscleGroup.quadriceps: return '🦵';
      case MuscleGroup.hamstrings: return '🦵';
      case MuscleGroup.calves: return '🦶';
      case MuscleGroup.traps: return '🏔️';
      case MuscleGroup.lats: return '🦅';
      case MuscleGroup.lowerBack: return '🔻';
      case MuscleGroup.fullBody: return '🧍';
      case MuscleGroup.cardio_vascular: return '❤️';
      case MuscleGroup.flexibility: return '🧘';
    }
  }

  /// Цвет для отображения на схеме мышц
  Color get color {
    switch (this) {
      case MuscleGroup.chest: return const Color(0xFFE53935);
      case MuscleGroup.back: return const Color(0xFF1E88E5);
      case MuscleGroup.shoulders: return const Color(0xFFFF9800);
      case MuscleGroup.biceps: return const Color(0xFF43A047);
      case MuscleGroup.triceps: return const Color(0xFF66BB6A);
      case MuscleGroup.forearms: return const Color(0xFFA1887F);
      case MuscleGroup.abs: return const Color(0xFFFDD835);
      case MuscleGroup.obliques: return const Color(0xFFFFB300);
      case MuscleGroup.glutes: return const Color(0xFF8D6E63);
      case MuscleGroup.quadriceps: return const Color(0xFF1565C0);
      case MuscleGroup.hamstrings: return const Color(0xFF1976D2);
      case MuscleGroup.calves: return const Color(0xFF64B5F6);
      case MuscleGroup.traps: return const Color(0xFF9C27B0);
      case MuscleGroup.lats: return const Color(0xFF7B1FA2);
      case MuscleGroup.lowerBack: return const Color(0xFF6A1B9A);
      case MuscleGroup.fullBody: return const Color(0xFF607D8B);
      case MuscleGroup.cardio_vascular: return const Color(0xFFF44336);
      case MuscleGroup.flexibility: return const Color(0xFF4CAF50);
    }
  }
}

extension ProgramTypeExtension on ProgramType {
  String get displayName {
    switch (this) {
      case ProgramType.daily: return 'На день';
      case ProgramType.weekly: return 'На неделю';
      case ProgramType.monthly: return 'На месяц';
    }
  }
}

extension WorkoutDayStatusExtension on WorkoutDayStatus {
  String get displayName {
    switch (this) {
      case WorkoutDayStatus.pending: return 'Ожидает';
      case WorkoutDayStatus.completed: return 'Выполнена';
      case WorkoutDayStatus.skipped: return 'Пропущена';
      case WorkoutDayStatus.rest: return 'Отдых';
    }
  }

  Color get color {
    switch (this) {
      case WorkoutDayStatus.pending: return const Color(0xFFBDBDBD);
      case WorkoutDayStatus.completed: return const Color(0xFF4CAF50);
      case WorkoutDayStatus.skipped: return const Color(0xFFF44336);
      case WorkoutDayStatus.rest: return const Color(0xFF9E9E9E);
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutDayStatus.pending: return Icons.schedule;
      case WorkoutDayStatus.completed: return Icons.check_circle;
      case WorkoutDayStatus.skipped: return Icons.cancel;
      case WorkoutDayStatus.rest: return Icons.bedtime;
    }
  }
}

extension FitnessGoalExtension on FitnessGoal {
  String get displayName {
    switch (this) {
      case FitnessGoal.strength: return 'Сила';
      case FitnessGoal.hypertrophy: return 'Масса';
      case FitnessGoal.endurance: return 'Выносливость';
      case FitnessGoal.weightLoss: return 'Похудение';
      case FitnessGoal.flexibility: return 'Гибкость';
      case FitnessGoal.general: return 'ОФП';
    }
  }
}

