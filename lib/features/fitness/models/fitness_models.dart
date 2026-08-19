import 'dart:convert';
import 'package:flutter/material.dart';
import 'enums.dart';

// ==================== УПРАЖНЕНИЕ ====================

class Exercise {
  final String id;
  final String name;
  final String description;
  final List<MuscleGroup> muscleGroups;
  final String? imageUrl;
  final ExerciseType exerciseType;
  final bool isCustom;
  final String? videoUrl;
  final String? techniqueTips;
  final String? commonMistakes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Exercise({
    required this.id,
    required this.name,
    this.description = '',
    this.muscleGroups = const [],
    this.imageUrl,
    this.exerciseType = ExerciseType.strength,
    this.isCustom = false,
    this.videoUrl,
    this.techniqueTips,
    this.commonMistakes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'muscleGroups': jsonEncode(muscleGroups.map((e) => e.name).toList()),
      'imageUrl': imageUrl,
      'exerciseType': exerciseType.name,
      'isCustom': isCustom ? 1 : 0,
      'videoUrl': videoUrl,
      'techniqueTips': techniqueTips,
      'commonMistakes': commonMistakes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    List<MuscleGroup> muscles = [];
    if (map['muscleGroups'] != null) {
      try {
        final dynamic groupsRaw = map['muscleGroups'];
        final List<dynamic> groups = groupsRaw is String
            ? jsonDecode(groupsRaw) as List<dynamic>
            : groupsRaw as List<dynamic>;
        muscles = groups.map((e) {
          return MuscleGroup.values.firstWhere(
                (m) => m.name == e.toString(),
            orElse: () => MuscleGroup.fullBody,
          );
        }).toList();
      } catch (_) {}
    }

    ExerciseType type = ExerciseType.strength;
    try {
      type = ExerciseType.values.firstWhere(
            (t) => t.name == map['exerciseType'],
      );
    } catch (_) {}

    return Exercise(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      muscleGroups: muscles,
      imageUrl: map['imageUrl'],
      exerciseType: type,
      isCustom: (map['isCustom'] ?? 0) == 1,
      videoUrl: map['videoUrl'],
      techniqueTips: map['techniqueTips'],
      commonMistakes: map['commonMistakes'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Exercise copyWith({
    String? name,
    String? description,
    List<MuscleGroup>? muscleGroups,
    String? imageUrl,
    ExerciseType? exerciseType,
    bool? isCustom,
    String? videoUrl,
    String? techniqueTips,
    String? commonMistakes,
    DateTime? updatedAt,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      imageUrl: imageUrl ?? this.imageUrl,
      exerciseType: exerciseType ?? this.exerciseType,
      isCustom: isCustom ?? this.isCustom,
      videoUrl: videoUrl ?? this.videoUrl,
      techniqueTips: techniqueTips ?? this.techniqueTips,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class ExerciseSet {
  final int setNumber;
  final int reps;
  final double weight;
  final double? rpe;
  final bool isWarmup;
  final SetStatus status;
  final String? notes;
  final int? restSeconds;  // 🔥 НОВОЕ: индивидуальный отдых для подхода

  ExerciseSet({
    required this.setNumber,
    this.reps = 0,
    this.weight = 0.0,
    this.rpe,
    this.isWarmup = false,
    this.status = SetStatus.pending,
    this.notes,
    this.restSeconds,  // 🔥 НОВОЕ
  });

  Map<String, dynamic> toMap() {
    return {
      'setNumber': setNumber,
      'reps': reps,
      'weight': weight,
      'rpe': rpe,
      'isWarmup': isWarmup ? 1 : 0,
      'status': status.name,
      'notes': notes,
      'restSeconds': restSeconds,  // 🔥 НОВОЕ
    };
  }

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    SetStatus status = SetStatus.pending;
    try {
      status = SetStatus.values.firstWhere((s) => s.name == map['status']);
    } catch (_) {}

    return ExerciseSet(
      setNumber: map['setNumber'] ?? 1,
      reps: map['reps'] ?? 0,
      weight: (map['weight'] ?? 0.0).toDouble(),
      rpe: map['rpe']?.toDouble(),
      isWarmup: (map['isWarmup'] ?? 0) == 1,
      status: status,
      notes: map['notes'],
      restSeconds: (map['restSeconds'] as num?)?.toInt(),  // 🔥 НОВОЕ
    );
  }

  ExerciseSet copyWith({
    int? reps,
    double? weight,
    double? rpe,
    bool? isWarmup,
    SetStatus? status,
    String? notes,
    int? restSeconds,  // 🔥 НОВОЕ
  }) {
    return ExerciseSet(
      setNumber: setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      rpe: rpe ?? this.rpe,
      isWarmup: isWarmup ?? this.isWarmup,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      restSeconds: restSeconds ?? this.restSeconds,  // 🔥 НОВОЕ
    );
  }

  double get volume => weight * reps;
}

// ==================== УПРАЖНЕНИЕ В ТРЕНИРОВКЕ ====================

class WorkoutExercise {
  final String id;
  final String exerciseId;
  final int order;
  final List<ExerciseSet> sets;
  final String? notes;
  final ExerciseGroupType groupType;
  final int? groupId;
  final int? restBetweenSeconds;

  WorkoutExercise({
    required this.id,
    required this.exerciseId,
    this.order = 0,
    this.sets = const [],
    this.notes,
    this.groupType = ExerciseGroupType.straight,
    this.groupId,
    this.restBetweenSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'order': order,
      'sets': jsonEncode(sets.map((s) => s.toMap()).toList()),
      'notes': notes,
      'groupType': groupType.name,
      'groupId': groupId,
      'restBetweenSeconds': restBetweenSeconds,
    };
  }

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    List<ExerciseSet> sets = [];
    if (map['sets'] != null) {
      try {
        final dynamic setsRaw = map['sets'];
        final List<dynamic> setsList = setsRaw is String
            ? jsonDecode(setsRaw) as List<dynamic>
            : setsRaw as List<dynamic>;

        sets = setsList.map((s) {
          final Map<String, dynamic> setMap = {};
          (s as Map).forEach((key, value) {
            setMap[key.toString()] = value;
          });
          return ExerciseSet.fromMap(setMap);
        }).toList();
      } catch (e) {
        debugPrint('❌ Ошибка парсинга sets: $e');
        sets = [];
      }
    }

    ExerciseGroupType groupType = ExerciseGroupType.straight;
    try {
      groupType = ExerciseGroupType.values.firstWhere(
            (g) => g.name == map['groupType'],
      );
    } catch (_) {}

    return WorkoutExercise(
      id: map['id'] ?? '',
      exerciseId: map['exerciseId'] ?? '',
      order: map['order'] ?? 0,
      sets: sets,
      notes: map['notes'],
      groupType: groupType,
      groupId: map['groupId'],
      restBetweenSeconds: map['restBetweenSeconds'],
    );
  }

  WorkoutExercise copyWith({
    String? exerciseId,
    int? order,
    List<ExerciseSet>? sets,
    String? notes,
    ExerciseGroupType? groupType,
    int? groupId,
    int? restBetweenSeconds,
  }) {
    return WorkoutExercise(
      id: id,
      exerciseId: exerciseId ?? this.exerciseId,
      order: order ?? this.order,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
      groupType: groupType ?? this.groupType,
      groupId: groupId ?? this.groupId,
      restBetweenSeconds: restBetweenSeconds ?? this.restBetweenSeconds,
    );
  }
}

// ==================== ДЕНЬ ТРЕНИРОВКИ ====================

class WorkoutDay {
  final String id;
  final String programId;
  final int dayNumber;
  final DateTime? date;
  final List<WorkoutExercise> exercises;
  final bool isRestDay;
  final String? notes;
  final WorkoutDayStatus status;

  WorkoutDay({
    required this.id,
    required this.programId,
    this.dayNumber = 1,
    this.date,
    this.exercises = const [],
    this.isRestDay = false,
    this.notes,
    this.status = WorkoutDayStatus.pending,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'programId': programId,
      'dayNumber': dayNumber,
      'date': date?.toIso8601String(),
      'exercises': jsonEncode(exercises.map((e) => e.toMap()).toList()),
      'isRestDay': isRestDay ? 1 : 0,
      'notes': notes,
      'status': status.name,
    };
  }

  factory WorkoutDay.fromMap(Map<String, dynamic> map) {
    List<WorkoutExercise> exercises = [];
    if (map['exercises'] != null) {
      try {
        final dynamic exRaw = map['exercises'];
        final List<dynamic> exList = exRaw is String
            ? jsonDecode(exRaw) as List<dynamic>
            : exRaw as List<dynamic>;

        exercises = exList.map((e) {
          final Map<String, dynamic> exMap = {};
          (e as Map).forEach((key, value) {
            exMap[key.toString()] = value;
          });
          return WorkoutExercise.fromMap(exMap);
        }).toList();
      } catch (e) {
        debugPrint('❌ Ошибка парсинга exercises: $e');
        exercises = [];
      }
    }

    WorkoutDayStatus status = WorkoutDayStatus.pending;
    try {
      status = WorkoutDayStatus.values.firstWhere(
            (s) => s.name == map['status'],
      );
    } catch (_) {}

    return WorkoutDay(
      id: map['id'] ?? '',
      programId: map['programId'] ?? '',
      dayNumber: map['dayNumber'] ?? 1,
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      exercises: exercises,
      isRestDay: (map['isRestDay'] ?? 0) == 1,
      notes: map['notes'],
      status: status,
    );
  }

  WorkoutDay copyWith({
    String? id,             // 👈 ДОБАВЬ ЭТО
    String? programId,      // 👈 ДОБАВЬ ЭТО
    int? dayNumber,
    DateTime? date,
    List<WorkoutExercise>? exercises,
    bool? isRestDay,
    String? notes,
    WorkoutDayStatus? status,
  }) {
    return WorkoutDay(
      id: id ?? this.id,                       // 👈 ИЗМЕНИ ЗДЕСЬ
      programId: programId ?? this.programId,  // 👈 И ЗДЕСЬ
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      exercises: exercises ?? this.exercises,
      isRestDay: isRestDay ?? this.isRestDay,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

// ==================== ПРОГРАММА ТРЕНИРОВОК ====================

class WorkoutProgram {
  final String id;
  final String name;
  final ProgramType type;
  final List<WorkoutDay> days;
  final String? templateName;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 🔥 НОВЫЕ ПОЛЯ из мастера создания
  final String emoji;
  final int accentColorValue;
  final String difficulty;      // 'easy' | 'medium' | 'hardcore'
  final String goal;             // 'lose' | 'gain' | 'strength' | 'general'
  final int sessionDurationMinutes;

  WorkoutProgram({
    required this.id,
    required this.name,
    this.type = ProgramType.weekly,
    this.days = const [],
    this.templateName,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    // 🔥 НОВЫЕ параметры
    this.emoji = '💪',
    this.accentColorValue = 0xFFFF6B35,
    this.difficulty = 'medium',
    this.goal = 'general',
    this.sessionDurationMinutes = 60,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Удобный геттер для Color
  Color get accentColor => Color(accentColorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'days': jsonEncode(days.map((d) => d.toMap()).toList()),
      'templateName': templateName,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      // 🔥 НОВЫЕ поля
      'emoji': emoji,
      'accentColorValue': accentColorValue,
      'difficulty': difficulty,
      'goal': goal,
      'sessionDurationMinutes': sessionDurationMinutes,
    };
  }

  factory WorkoutProgram.fromMap(Map<String, dynamic> map) {
    List<WorkoutDay> days = [];
    if (map['days'] != null) {
      try {
        final dynamic daysRaw = map['days'];
        final List<dynamic> daysList = daysRaw is String
            ? jsonDecode(daysRaw) as List<dynamic>
            : daysRaw as List<dynamic>;

        days = daysList.map((d) {
          final Map<String, dynamic> dayMap = {};
          (d as Map).forEach((key, value) {
            dayMap[key.toString()] = value;
          });
          return WorkoutDay.fromMap(dayMap);
        }).toList();
      } catch (e) {
        debugPrint('❌ Ошибка парсинга days программы: $e');
        days = [];
      }
    }

    ProgramType type = ProgramType.weekly;
    try {
      type = ProgramType.values.firstWhere((t) => t.name == map['type']);
    } catch (_) {}

    return WorkoutProgram(
      id: map['id'],
      name: map['name'],
      type: type,
      days: days,
      templateName: map['templateName'],
      description: map['description'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      // 🔥 НОВЫЕ поля с fallback на значения по умолчанию
      emoji: map['emoji'] as String? ?? '💪',
      accentColorValue: (map['accentColorValue'] as num?)?.toInt() ?? 0xFFFF6B35,
      difficulty: map['difficulty'] as String? ?? 'medium',
      goal: map['goal'] as String? ?? 'general',
      sessionDurationMinutes: (map['sessionDurationMinutes'] as num?)?.toInt() ?? 60,
    );
  }

  WorkoutProgram copyWith({
    String? name,
    ProgramType? type,
    List<WorkoutDay>? days,
    String? templateName,
    String? description,
    DateTime? updatedAt,
    // 🔥 НОВЫЕ
    String? emoji,
    int? accentColorValue,
    String? difficulty,
    String? goal,
    int? sessionDurationMinutes,
  }) {
    return WorkoutProgram(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      days: days ?? this.days,
      templateName: templateName ?? this.templateName,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      emoji: emoji ?? this.emoji,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      difficulty: difficulty ?? this.difficulty,
      goal: goal ?? this.goal,
      sessionDurationMinutes: sessionDurationMinutes ?? this.sessionDurationMinutes,
    );
  }
}

// ==================== ЗАПИСЬ В ЖУРНАЛЕ ТРЕНИРОВОК ====================

class WorkoutLog {
  final String id;
  final DateTime date;
  final String? programId;
  final int? dayNumber;
  final WorkoutDayStatus status;
  final String? comment;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<WorkoutExercise> exercisesLog;
  final Duration? totalRestTime;
  final double? totalVolume;
  final double? avgRpe;
  final String? bodyWeight;
  final DateTime createdAt;

  // 🔥 НОВЫЕ ПОЛЯ: настроение во время тренировки
  final int? moodEnergy;
  final int? moodSleep;
  final int? moodMotivation;
  final String? moodNotes;

  // 🔥 НОВОЕ ПОЛЕ: фото тренировки
  final String? workoutPhotoPath;

  WorkoutLog({
    required this.id,
    required this.date,
    this.programId,
    this.dayNumber,
    this.status = WorkoutDayStatus.completed,
    this.comment,
    this.startTime,
    this.endTime,
    this.exercisesLog = const [],
    this.totalRestTime,
    this.totalVolume,
    this.avgRpe,
    this.bodyWeight,
    DateTime? createdAt,
    this.moodEnergy,
    this.moodSleep,
    this.moodMotivation,
    this.moodNotes,
    this.workoutPhotoPath,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'programId': programId,
      'dayNumber': dayNumber,
      'status': status.name,
      'comment': comment,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'exercisesLog': jsonEncode(exercisesLog.map((e) => e.toMap()).toList()),
      'totalRestTime': totalRestTime?.inSeconds,
      'totalVolume': totalVolume,
      'avgRpe': avgRpe,
      'bodyWeight': bodyWeight,
      'createdAt': createdAt.toIso8601String(),
      'moodEnergy': moodEnergy,
      'moodSleep': moodSleep,
      'moodMotivation': moodMotivation,
      'moodNotes': moodNotes,
      'workoutPhotoPath': workoutPhotoPath,
    };
  }

  factory WorkoutLog.fromMap(Map<String, dynamic> map) {
    List<WorkoutExercise> exercisesLog = [];
    if (map['exercisesLog'] != null) {
      try {
        final dynamic exRaw = map['exercisesLog'];
        final List<dynamic> exList = exRaw is String
            ? jsonDecode(exRaw) as List<dynamic>
            : exRaw as List<dynamic>;

        exercisesLog = exList.map((e) {
          final Map<String, dynamic> exMap = {};
          (e as Map).forEach((key, value) {
            exMap[key.toString()] = value;
          });
          return WorkoutExercise.fromMap(exMap);
        }).toList();
      } catch (e) {
        debugPrint('❌ Ошибка парсинга exercisesLog: $e');
        exercisesLog = [];
      }
    }

    WorkoutDayStatus status = WorkoutDayStatus.completed;
    try {
      status = WorkoutDayStatus.values.firstWhere(
            (s) => s.name == map['status'],
      );
    } catch (_) {}

    return WorkoutLog(
      id: map['id'],
      date: DateTime.parse(map['date']),
      programId: map['programId'],
      dayNumber: map['dayNumber'],
      status: status,
      comment: map['comment'],
      startTime: map['startTime'] != null
          ? DateTime.parse(map['startTime'])
          : null,
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'])
          : null,
      exercisesLog: exercisesLog,
      totalRestTime: map['totalRestTime'] != null
          ? Duration(seconds: map['totalRestTime'])
          : null,
      totalVolume: map['totalVolume']?.toDouble(),
      avgRpe: map['avgRpe']?.toDouble(),
      bodyWeight: map['bodyWeight'],
      createdAt: DateTime.parse(map['createdAt']),
      moodEnergy: map['moodEnergy'],
      moodSleep: map['moodSleep'],
      moodMotivation: map['moodMotivation'],
      moodNotes: map['moodNotes'],
      workoutPhotoPath: map['workoutPhotoPath'],
    );
  }

  WorkoutLog copyWith({
    WorkoutDayStatus? status,
    String? comment,
    DateTime? endTime,
    List<WorkoutExercise>? exercisesLog,
    Duration? totalRestTime,
    double? totalVolume,
    double? avgRpe,
    String? bodyWeight,
    int? moodEnergy,
    int? moodSleep,
    int? moodMotivation,
    String? moodNotes,
    String? workoutPhotoPath,
  }) {
    return WorkoutLog(
      id: id,
      date: date,
      programId: programId,
      dayNumber: dayNumber,
      status: status ?? this.status,
      comment: comment ?? this.comment,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      exercisesLog: exercisesLog ?? this.exercisesLog,
      totalRestTime: totalRestTime ?? this.totalRestTime,
      totalVolume: totalVolume ?? this.totalVolume,
      avgRpe: avgRpe ?? this.avgRpe,
      bodyWeight: bodyWeight ?? this.bodyWeight,
      createdAt: createdAt,
      moodEnergy: moodEnergy ?? this.moodEnergy,
      moodSleep: moodSleep ?? this.moodSleep,
      moodMotivation: moodMotivation ?? this.moodMotivation,
      moodNotes: moodNotes ?? this.moodNotes,
      workoutPhotoPath: workoutPhotoPath ?? this.workoutPhotoPath,
    );
  }

  Duration? get duration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
  }

  /// Есть ли данные о настроении
  bool get hasMoodData =>
      moodEnergy != null || moodSleep != null || moodMotivation != null;

  /// Есть ли фото тренировки
  bool get hasPhoto => workoutPhotoPath != null && workoutPhotoPath!.isNotEmpty;
}

// ==================== ЗАПИСЬ ПРОГРЕССА ====================

class ProgressRecord {
  final String id;
  final String exerciseId;
  final DateTime date;
  final double bestWeight;
  final int bestReps;
  final double estimated1RM;
  final double totalVolume;
  final int totalSets;
  final double? avgRpe;

  ProgressRecord({
    required this.id,
    required this.exerciseId,
    required this.date,
    this.bestWeight = 0.0,
    this.bestReps = 0,
    this.estimated1RM = 0.0,
    this.totalVolume = 0.0,
    this.totalSets = 0,
    this.avgRpe,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'date': date.toIso8601String(),
      'bestWeight': bestWeight,
      'bestReps': bestReps,
      'estimated1RM': estimated1RM,
      'totalVolume': totalVolume,
      'totalSets': totalSets,
      'avgRpe': avgRpe,
    };
  }

  factory ProgressRecord.fromMap(Map<String, dynamic> map) {
    return ProgressRecord(
      id: map['id'],
      exerciseId: map['exerciseId'],
      date: DateTime.parse(map['date']),
      bestWeight: (map['bestWeight'] ?? 0.0).toDouble(),
      bestReps: map['bestReps'] ?? 0,
      estimated1RM: (map['estimated1RM'] ?? 0.0).toDouble(),
      totalVolume: (map['totalVolume'] ?? 0.0).toDouble(),
      totalSets: map['totalSets'] ?? 0,
      avgRpe: map['avgRpe']?.toDouble(),
    );
  }
}

// ==================== ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ (ФИТНЕС) ====================

class UserFitnessProfile {
  final String id;
  final String name;
  final String? avatarUrl;
  final List<BodyWeightEntry> bodyWeightHistory;
  final FitnessGoal goal;
  final FitnessLevel level;
  final UserGender gender;
  final double? height;
  final int? age;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserFitnessProfile({
    required this.id,
    this.name = 'Атлет',
    this.avatarUrl,
    this.bodyWeightHistory = const [],
    this.goal = FitnessGoal.general,
    this.level = FitnessLevel.intermediate,
    this.gender = UserGender.male,
    this.height,
    this.age,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'bodyWeightHistory':
      jsonEncode(bodyWeightHistory.map((e) => e.toMap()).toList()),
      'goal': goal.name,
      'level': level.name,
      'gender': gender.name,
      'height': height,
      'age': age,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserFitnessProfile.fromMap(Map<String, dynamic> map) {
    List<BodyWeightEntry> weightHistory = [];
    if (map['bodyWeightHistory'] != null) {
      try {
        final dynamic raw = map['bodyWeightHistory'];
        final List<dynamic> data = raw is String
            ? jsonDecode(raw) as List<dynamic>
            : raw as List<dynamic>;
        weightHistory = data.map((e) {
          final Map<String, dynamic> itemMap = {};
          (e as Map).forEach((key, value) {
            itemMap[key.toString()] = value;
          });
          return BodyWeightEntry.fromMap(itemMap);
        }).toList();
      } catch (_) {}
    }

    FitnessGoal goal = FitnessGoal.general;
    try {
      goal = FitnessGoal.values.firstWhere(
            (g) => g.name == map['goal'],
      );
    } catch (_) {}

    FitnessLevel level = FitnessLevel.intermediate;
    try {
      level = FitnessLevel.values.firstWhere(
            (l) => l.name == map['level'],
      );
    } catch (_) {}

    UserGender gender = UserGender.male;
    try {
      gender = UserGender.values.firstWhere(
            (g) => g.name == map['gender'],
      );
    } catch (_) {}

    return UserFitnessProfile(
      id: map['id'],
      name: map['name'] ?? 'Атлет',
      avatarUrl: map['avatarUrl'],
      bodyWeightHistory: weightHistory,
      goal: goal,
      level: level,
      gender: gender,
      height: map['height']?.toDouble(),
      age: map['age'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  double? get currentWeight {
    if (bodyWeightHistory.isEmpty) return null;
    bodyWeightHistory.sort((a, b) => b.date.compareTo(a.date));
    return bodyWeightHistory.first.weight;
  }

  UserFitnessProfile copyWith({
    String? name,
    String? avatarUrl,
    List<BodyWeightEntry>? bodyWeightHistory,
    FitnessGoal? goal,
    FitnessLevel? level,
    UserGender? gender,
    double? height,
    int? age,
    DateTime? updatedAt,
  }) {
    return UserFitnessProfile(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bodyWeightHistory: bodyWeightHistory ?? this.bodyWeightHistory,
      goal: goal ?? this.goal,
      level: level ?? this.level,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      age: age ?? this.age,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

// ==================== ЗАПИСЬ ВЕСА ТЕЛА ====================

class BodyWeightEntry {
  final DateTime date;
  final double weight;

  BodyWeightEntry({
    required this.date,
    required this.weight,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'weight': weight,
    };
  }

  factory BodyWeightEntry.fromMap(Map<String, dynamic> map) {
    return BodyWeightEntry(
      date: DateTime.parse(map['date']),
      weight: (map['weight'] ?? 0.0).toDouble(),
    );
  }
}

// ==================== ШАБЛОН ПРОГРАММЫ ====================

class WorkoutTemplate {
  final String id;
  final String name;
  final String description;
  final ProgramType type;
  final List<WorkoutDay> days;
  final String category;
  final FitnessLevel recommendedLevel;

  WorkoutTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.type = ProgramType.weekly,
    this.days = const [],
    this.category = 'custom',
    this.recommendedLevel = FitnessLevel.intermediate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'days': jsonEncode(days.map((d) => d.toMap()).toList()),
      'category': category,
      'recommendedLevel': recommendedLevel.name,
    };
  }

  factory WorkoutTemplate.fromMap(Map<String, dynamic> map) {
    List<WorkoutDay> days = [];
    if (map['days'] != null) {
      try {
        final dynamic daysRaw = map['days'];
        final List<dynamic> daysList = daysRaw is String
            ? jsonDecode(daysRaw) as List<dynamic>
            : daysRaw as List<dynamic>;

        days = daysList.map((d) {
          final Map<String, dynamic> dayMap = {};
          (d as Map).forEach((key, value) {
            dayMap[key.toString()] = value;
          });
          return WorkoutDay.fromMap(dayMap);
        }).toList();

        debugPrint(
            '📋 Шаблон ${map['name']}: загружено ${days.length} дней');
      } catch (e) {
        debugPrint('❌ Ошибка парсинга days шаблона: $e');
        days = [];
      }
    }

    ProgramType type = ProgramType.weekly;
    try {
      type = ProgramType.values.firstWhere(
            (t) => t.name == map['type'],
      );
    } catch (_) {}

    FitnessLevel level = FitnessLevel.intermediate;
    try {
      level = FitnessLevel.values.firstWhere(
            (l) => l.name == map['recommendedLevel'],
      );
    } catch (_) {}

    return WorkoutTemplate(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      type: type,
      days: days,
      category: map['category'] ?? 'custom',
      recommendedLevel: level,
    );
  }
}

// ==================== ФОТООТЧЁТ ====================

class FitnessPhoto {
  final String id;
  final DateTime date;
  final String imageUrl;
  final String? label;
  final double? weight;
  final String? notes;
  final DateTime createdAt;

  // 📏 Обхваты тела (в см)
  final double? chest;      // грудь
  final double? waist;      // талия
  final double? hips;       // бёдра
  final double? biceps;     // бицепс
  final double? thigh;      // бедро
  final double? calf;       // икра
  final double? neck;       // шея
  final double? forearm;    // предплечье

  FitnessPhoto({
    required this.id,
    required this.date,
    required this.imageUrl,
    this.label,
    this.weight,
    this.notes,
    DateTime? createdAt,
    this.chest,
    this.waist,
    this.hips,
    this.biceps,
    this.thigh,
    this.calf,
    this.neck,
    this.forearm,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imageUrl': imageUrl,
      'label': label,
      'weight': weight,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'chest': chest,
      'waist': waist,
      'hips': hips,
      'biceps': biceps,
      'thigh': thigh,
      'calf': calf,
      'neck': neck,
      'forearm': forearm,
    };
  }

  factory FitnessPhoto.fromMap(Map<String, dynamic> map) {
    return FitnessPhoto(
      id: map['id'] ?? '',
      date: DateTime.parse(map['date']),
      imageUrl: map['imageUrl'] ?? '',
      label: map['label'],
      weight: map['weight']?.toDouble(),
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      chest: map['chest']?.toDouble(),
      waist: map['waist']?.toDouble(),
      hips: map['hips']?.toDouble(),
      biceps: map['biceps']?.toDouble(),
      thigh: map['thigh']?.toDouble(),
      calf: map['calf']?.toDouble(),
      neck: map['neck']?.toDouble(),
      forearm: map['forearm']?.toDouble(),
    );
  }

  FitnessPhoto copyWith({
    String? label,
    double? weight,
    String? notes,
    double? chest,
    double? waist,
    double? hips,
    double? biceps,
    double? thigh,
    double? calf,
    double? neck,
    double? forearm,
    bool clearChest = false,
    bool clearWaist = false,
    bool clearHips = false,
    bool clearBiceps = false,
    bool clearThigh = false,
    bool clearCalf = false,
    bool clearNeck = false,
    bool clearForearm = false,
  }) {
    return FitnessPhoto(
      id: id,
      date: date,
      imageUrl: imageUrl,
      label: label ?? this.label,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      chest: clearChest ? null : (chest ?? this.chest),
      waist: clearWaist ? null : (waist ?? this.waist),
      hips: clearHips ? null : (hips ?? this.hips),
      biceps: clearBiceps ? null : (biceps ?? this.biceps),
      thigh: clearThigh ? null : (thigh ?? this.thigh),
      calf: clearCalf ? null : (calf ?? this.calf),
      neck: clearNeck ? null : (neck ?? this.neck),
      forearm: clearForearm ? null : (forearm ?? this.forearm),
    );
  }

  /// Подсчёт количества заполненных измерений
  int get measurementsCount {
    int count = 0;
    if (weight != null) count++;
    if (chest != null) count++;
    if (waist != null) count++;
    if (hips != null) count++;
    if (biceps != null) count++;
    if (thigh != null) count++;
    if (calf != null) count++;
    if (neck != null) count++;
    if (forearm != null) count++;
    return count;
  }
}

// ==================== ЗАМЕТКА О САМОЧУВСТВИИ ====================

class WellbeingNote {
  final String id;
  final DateTime date;
  final int energyLevel;
  final int sleepQuality;
  final int motivationLevel;
  final List<String> painAreas;
  final String? notes;
  final DateTime createdAt;

  WellbeingNote({
    required this.id,
    required this.date,
    this.energyLevel = 5,
    this.sleepQuality = 5,
    this.motivationLevel = 5,
    this.painAreas = const [],
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'energyLevel': energyLevel,
      'sleepQuality': sleepQuality,
      'motivationLevel': motivationLevel,
      'painAreas': jsonEncode(painAreas),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WellbeingNote.fromMap(Map<String, dynamic> map) {
    List<String> painAreas = [];
    if (map['painAreas'] != null) {
      try {
        painAreas = (map['painAreas'] is String
            ? jsonDecode(map['painAreas'])
            : map['painAreas'] as List)
            .cast<String>();
      } catch (_) {}
    }

    return WellbeingNote(
      id: map['id'],
      date: DateTime.parse(map['date']),
      energyLevel: map['energyLevel'] ?? 5,
      sleepQuality: map['sleepQuality'] ?? 5,
      motivationLevel: map['motivationLevel'] ?? 5,
      painAreas: painAreas,
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  WellbeingNote copyWith({
    int? energyLevel,
    int? sleepQuality,
    int? motivationLevel,
    List<String>? painAreas,
    String? notes,
  }) {
    return WellbeingNote(
      id: id,
      date: date,
      energyLevel: energyLevel ?? this.energyLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      motivationLevel: motivationLevel ?? this.motivationLevel,
      painAreas: painAreas ?? this.painAreas,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

// ==================== НОВОЕ: СИСТЕМА СЛЕДОВАНИЯ ПРОГРАММАМ ====================

/// Статус дня в активной сессии программы
enum DaySessionStatus {
  pending,     // Ожидает
  current,     // Текущий (доступен для выполнения)
  completed,   // Выполнен
  skipped,     // Пропущен
  locked       // Заблокирован (ещё не доступен)
}

/// Статус сессии программы
enum ProgramSessionStatus {
  active,      // В процессе
  completed,   // Завершена успешно
  abandoned,   // Брошена
  paused       // На паузе
}

/// Уровень сложности программы (влияет на правила пропуска дней)
enum ProgramDifficulty {
  flexible,    // Можно пропускать без штрафов
  standard,    // Пропуск = сброс серии
  hardcore     // Пропуск = сброс недели
}

/// Состояние одного дня в активной сессии
class DaySession {
  final int dayIndex;
  final DaySessionStatus status;
  final DateTime? completedAt;
  final double? volumeDone;
  final double? avgRpe;
  final String? notes;

  DaySession({
    required this.dayIndex,
    this.status = DaySessionStatus.pending,
    this.completedAt,
    this.volumeDone,
    this.avgRpe,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'dayIndex': dayIndex,
    'status': status.name,
    'completedAt': completedAt?.toIso8601String(),
    'volumeDone': volumeDone,
    'avgRpe': avgRpe,
    'notes': notes,
  };

  factory DaySession.fromMap(Map<String, dynamic> map) => DaySession(
    dayIndex: map['dayIndex'] ?? 0,
    status: DaySessionStatus.values.firstWhere(
          (s) => s.name == map['status'],
      orElse: () => DaySessionStatus.pending,
    ),
    completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt']) : null,
    volumeDone: map['volumeDone']?.toDouble(),
    avgRpe: map['avgRpe']?.toDouble(),
    notes: map['notes'],
  );

  DaySession copyWith({
    DaySessionStatus? status,
    DateTime? completedAt,
    double? volumeDone,
    double? avgRpe,
    String? notes,
  }) => DaySession(
    dayIndex: dayIndex,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    volumeDone: volumeDone ?? this.volumeDone,
    avgRpe: avgRpe ?? this.avgRpe,
    notes: notes ?? this.notes,
  );

  /// Эмодзи для отображения статуса
  String get statusEmoji {
    switch (status) {
      case DaySessionStatus.completed: return '✅';
      case DaySessionStatus.current: return '🔥';
      case DaySessionStatus.skipped: return '❌';
      case DaySessionStatus.locked: return '🔒';
      case DaySessionStatus.pending: return '⏳';
    }
  }

  /// Цвет для отображения статуса
  Color get statusColor {
    switch (status) {
      case DaySessionStatus.completed: return const Color(0xFF4CAF50);
      case DaySessionStatus.current: return const Color(0xFFFF6B35);
      case DaySessionStatus.skipped: return const Color(0xFFF44336);
      case DaySessionStatus.locked: return Colors.grey;
      case DaySessionStatus.pending: return Colors.grey;
    }
  }
}

/// Сессия прохождения программы (активная или завершённая)
class ProgramSession {
  final String id;
  final String programId;
  final DateTime startDate;
  final DateTime? endDate;
  final int currentDayIndex;
  final ProgramDifficulty difficulty;
  final ProgramSessionStatus status;
  final List<DaySession> daySessions;

  // Статистика серии
  final int streak;                    // Текущая серия выполненных дней
  final int longestStreak;             // Максимальная серия за всё время

  // Общая статистика
  final double totalVolumeCompleted;   // Общий тоннаж
  final int totalWorkoutsCompleted;    // Выполнено тренировок
  final int totalWorkoutsSkipped;      // Пропущено тренировок
  final double averageRpe;             // Средний RPE

  // Для завершённых программ
  final DateTime? completedAt;
  final Map<String, dynamic> summaryData;

  ProgramSession({
    required this.id,
    required this.programId,
    required this.startDate,
    this.endDate,
    this.currentDayIndex = 0,
    this.difficulty = ProgramDifficulty.standard,
    this.status = ProgramSessionStatus.active,
    this.daySessions = const [],
    this.streak = 0,
    this.longestStreak = 0,
    this.totalVolumeCompleted = 0,
    this.totalWorkoutsCompleted = 0,
    this.totalWorkoutsSkipped = 0,
    this.averageRpe = 0,
    this.completedAt,
    this.summaryData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'programId': programId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'currentDayIndex': currentDayIndex,
      'difficulty': difficulty.name,
      'status': status.name,
      'daySessions': jsonEncode(daySessions.map((d) => d.toMap()).toList()),
      'streak': streak,
      'longestStreak': longestStreak,
      'totalVolumeCompleted': totalVolumeCompleted,
      'totalWorkoutsCompleted': totalWorkoutsCompleted,
      'totalWorkoutsSkipped': totalWorkoutsSkipped,
      'averageRpe': averageRpe,
      'completedAt': completedAt?.toIso8601String(),
      'summaryData': jsonEncode(summaryData),
    };
  }

  factory ProgramSession.fromMap(Map<String, dynamic> map) {
    List<DaySession> days = [];
    if (map['daySessions'] != null) {
      try {
        dynamic data = map['daySessions'];
        if (data is String) data = jsonDecode(data);
        if (data is List) {
          days = data.map((d) {
            final Map<String, dynamic> dayMap = {};
            (d as Map).forEach((key, value) {
              dayMap[key.toString()] = value;
            });
            return DaySession.fromMap(dayMap);
          }).toList();
        }
      } catch (_) {}
    }

    Map<String, dynamic> summary = {};
    if (map['summaryData'] != null) {
      try {
        dynamic data = map['summaryData'];
        if (data is String) {
          summary = jsonDecode(data) as Map<String, dynamic>;
        } else if (data is Map) {
          summary = Map<String, dynamic>.from(data);
        }
      } catch (_) {}
    }

    return ProgramSession(
      id: map['id'] ?? '',
      programId: map['programId'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.tryParse(map['endDate']) : null,
      currentDayIndex: map['currentDayIndex'] ?? 0,
      difficulty: ProgramDifficulty.values.firstWhere(
            (d) => d.name == map['difficulty'],
        orElse: () => ProgramDifficulty.standard,
      ),
      status: ProgramSessionStatus.values.firstWhere(
            (s) => s.name == map['status'],
        orElse: () => ProgramSessionStatus.active,
      ),
      daySessions: days,
      streak: map['streak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      totalVolumeCompleted: (map['totalVolumeCompleted'] ?? 0).toDouble(),
      totalWorkoutsCompleted: map['totalWorkoutsCompleted'] ?? 0,
      totalWorkoutsSkipped: map['totalWorkoutsSkipped'] ?? 0,
      averageRpe: (map['averageRpe'] ?? 0).toDouble(),
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt']) : null,
      summaryData: summary,
    );
  }

  ProgramSession copyWith({
    DateTime? endDate,
    int? currentDayIndex,
    ProgramDifficulty? difficulty,
    ProgramSessionStatus? status,
    List<DaySession>? daySessions,
    int? streak,
    int? longestStreak,
    double? totalVolumeCompleted,
    int? totalWorkoutsCompleted,
    int? totalWorkoutsSkipped,
    double? averageRpe,
    DateTime? completedAt,
    Map<String, dynamic>? summaryData,
  }) {
    return ProgramSession(
      id: id,
      programId: programId,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      currentDayIndex: currentDayIndex ?? this.currentDayIndex,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      daySessions: daySessions ?? this.daySessions,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalVolumeCompleted: totalVolumeCompleted ?? this.totalVolumeCompleted,
      totalWorkoutsCompleted: totalWorkoutsCompleted ?? this.totalWorkoutsCompleted,
      totalWorkoutsSkipped: totalWorkoutsSkipped ?? this.totalWorkoutsSkipped,
      averageRpe: averageRpe ?? this.averageRpe,
      completedAt: completedAt ?? this.completedAt,
      summaryData: summaryData ?? this.summaryData,
    );
  }

  /// Процент выполнения программы (0.0 - 1.0)
  double get progressPercent {
    if (daySessions.isEmpty) return 0;
    final completed = daySessions.where((d) => d.status == DaySessionStatus.completed).length;
    return completed / daySessions.length;
  }

  /// Эмодзи статуса сессии
  String get statusEmoji {
    switch (status) {
      case ProgramSessionStatus.active: return '🔥';
      case ProgramSessionStatus.completed: return '🏆';
      case ProgramSessionStatus.abandoned: return '❌';
      case ProgramSessionStatus.paused: return '⏸️';
    }
  }

  /// Активна ли сессия
  bool get isActive => status == ProgramSessionStatus.active;

  /// Завершена ли сессия
  bool get isCompleted => status == ProgramSessionStatus.completed;

  /// Длительность сессии в днях
  int get durationDays {
    final end = endDate ?? DateTime.now();
    return end.difference(startDate).inDays;
  }
}

// ==================== 📝 ЗАПИСЬ ПРОГРЕССА ЦЕЛИ ====================

/// 🔥 НОВОЕ: Запись в журнале прогресса фитнес-цели
class FitnessTargetEntry {
  final DateTime date;
  final double value;
  final String? note;
  final double? bodyWeight; // вес тела на момент записи (опционально)

  FitnessTargetEntry({
    required this.date,
    required this.value,
    this.note,
    this.bodyWeight,
  });

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'value': value,
    'note': note,
    'bodyWeight': bodyWeight,
  };

  factory FitnessTargetEntry.fromMap(Map<String, dynamic> map) => FitnessTargetEntry(
    date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    value: (map['value'] ?? 0).toDouble(),
    note: map['note'] as String?,
    bodyWeight: (map['bodyWeight'] as num?)?.toDouble(),
  );
}

// ==================== 🎯 ФИТНЕС-ЦЕЛЬ (TARGET) ====================

class FitnessTarget {
  final String id;
  final String name;
  final String description;
  final FitnessTargetType type;
  final String? exerciseId;           // Привязка к упражнению (опционально)
  final double targetValue;           // Целевое значение
  final double currentValue;          // Текущее значение (автообновляется)
  final double startValue;            // Значение на момент создания
  final String unit;                  // Единица измерения
  final DateTime? deadline;           // Дедлайн (опционально)
  final DateTime createdAt;
  final DateTime? completedAt;
  final FitnessTargetStatus status;
  final Color accentColor;            // Акцентный цвет для карточки
  final Map<String, dynamic> extra;   // Дополнительные параметры (напр. {reps: 50} для strengthReps)
  final List<FitnessTargetEntry> entries; // 🔥 НОВОЕ: журнал прогресса

  FitnessTarget({
    required this.id,
    required this.name,
    this.description = '',
    required this.type,
    this.exerciseId,
    required this.targetValue,
    this.currentValue = 0,
    this.startValue = 0,
    required this.unit,
    this.deadline,
    DateTime? createdAt,
    this.completedAt,
    this.status = FitnessTargetStatus.active,
    Color? accentColor,
    this.extra = const {},
    this.entries = const [], // 🔥 НОВОЕ
  })  : createdAt = createdAt ?? DateTime.now(),
        accentColor = accentColor ?? const Color(0xFFFF6B35);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'exerciseId': exerciseId,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'startValue': startValue,
      'unit': unit,
      'deadline': deadline?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'status': status.name,
      'accentColor': accentColor.value,
      'extra': jsonEncode(extra),
      'entries': jsonEncode(entries.map((e) => e.toMap()).toList()), // 🔥 НОВОЕ
    };
  }

  factory FitnessTarget.fromMap(Map<String, dynamic> map) {
    FitnessTargetType type = FitnessTargetType.custom;
    try {
      type = FitnessTargetType.values.firstWhere((t) => t.name == map['type']);
    } catch (_) {}

    FitnessTargetStatus status = FitnessTargetStatus.active;
    try {
      status = FitnessTargetStatus.values.firstWhere((s) => s.name == map['status']);
    } catch (_) {}

    Map<String, dynamic> extra = {};
    if (map['extra'] != null) {
      try {
        final raw = map['extra'];
        if (raw is String) {
          extra = jsonDecode(raw) as Map<String, dynamic>;
        } else if (raw is Map) {
          extra = Map<String, dynamic>.from(raw);
        }
      } catch (_) {}
    }

    // 🔥 НОВОЕ: парсинг entries
    List<FitnessTargetEntry> entries = [];
    if (map['entries'] != null) {
      try {
        final raw = map['entries'];
        final list = raw is String ? jsonDecode(raw) as List : raw as List;
        entries = list.map((e) {
          final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
          return FitnessTargetEntry.fromMap(m);
        }).toList();
      } catch (_) {
        entries = [];
      }
    }

    Color color = const Color(0xFFFF6B35);
    if (map['accentColor'] != null) {
      try {
        color = Color(map['accentColor'] as int);
      } catch (_) {}
    }

    return FitnessTarget(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: type,
      exerciseId: map['exerciseId'],
      targetValue: (map['targetValue'] ?? 0).toDouble(),
      currentValue: (map['currentValue'] ?? 0).toDouble(),
      startValue: (map['startValue'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      deadline: map['deadline'] != null ? DateTime.tryParse(map['deadline']) : null,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt']) : null,
      status: status,
      accentColor: color,
      extra: extra,
      entries: entries, // 🔥 НОВОЕ
    );
  }

  FitnessTarget copyWith({
    String? name,
    String? description,
    FitnessTargetType? type,
    String? exerciseId,
    double? targetValue,
    double? currentValue,
    double? startValue,
    String? unit,
    DateTime? deadline,
    DateTime? completedAt,
    FitnessTargetStatus? status,
    Color? accentColor,
    Map<String, dynamic>? extra,
    List<FitnessTargetEntry>? entries, // 🔥 НОВОЕ
  }) {
    return FitnessTarget(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      exerciseId: exerciseId ?? this.exerciseId,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      startValue: startValue ?? this.startValue,
      unit: unit ?? this.unit,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      accentColor: accentColor ?? this.accentColor,
      extra: extra ?? this.extra,
      entries: entries ?? this.entries, // 🔥 НОВОЕ
    );
  }

  /// Процент выполнения (0.0 - 1.0+)
  double get progressPercent {
    if (targetValue <= 0) return 0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  /// Осталось до цели (абсолютное значение)
  double get remaining {
    return (targetValue - currentValue).abs();
  }

  /// Достигнута ли цель (учитывает направление)
  bool get isCompleted {
    if (isAscending) {
      return currentValue >= targetValue;
    } else {
      return currentValue <= targetValue;
    }
  }

  /// 🔥 НОВОЕ: Направление прогресса (true = рост значения, false = убывание)
  /// Например: жим 100 кг = рост, похудение до 70 кг = убывание
  bool get isAscending => targetValue >= startValue;

  /// Дней до дедлайна (null если нет дедлайна)
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  /// Просрочена ли цель
  bool get isOverdue {
    if (deadline == null) return false;
    return deadline!.isBefore(DateTime.now()) && status == FitnessTargetStatus.active;
  }

  /// 🔥 НОВОЕ: Последняя запись в журнале
  FitnessTargetEntry? get latestEntry {
    if (entries.isEmpty) return null;
    return entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  }

  /// 🔥 НОВОЕ: Изменение с последней записи (может быть отрицательным)
  /// Полезно для отображения "улучшения" или "ухудшения"
  double get lastImprovement {
    if (entries.length < 2) return 0;
    final sorted = List<FitnessTargetEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted.last.value - sorted[sorted.length - 2].value;
  }

  /// Отображаемое текущее значение
  String get formattedCurrent {
    if (type == FitnessTargetType.strengthReps && extra.containsKey('reps')) {
      final reps = extra['reps'] as int? ?? 0;
      return '${currentValue.toStringAsFixed(0)}×$reps';
    }
    if (currentValue == currentValue.roundToDouble()) {
      return currentValue.toStringAsFixed(0);
    }
    return currentValue.toStringAsFixed(1);
  }

  String get formattedTarget {
    if (type == FitnessTargetType.strengthReps && extra.containsKey('reps')) {
      final reps = extra['reps'] as int? ?? 0;
      return '${targetValue.toStringAsFixed(0)}×$reps';
    }
    if (targetValue == targetValue.roundToDouble()) {
      return targetValue.toStringAsFixed(0);
    }
    return targetValue.toStringAsFixed(1);
  }

  /// 🔥 НОВОЕ: Оставшееся значение для отображения
  String get formattedRemaining {
    final rem = remaining;
    if (rem == rem.roundToDouble()) return rem.toStringAsFixed(0);
    return rem.toStringAsFixed(1);
  }
}