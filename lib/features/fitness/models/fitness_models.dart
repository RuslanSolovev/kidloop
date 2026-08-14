// features/fitness/models/fitness_models.dart
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

// ==================== ПОДХОД ====================

class ExerciseSet {
  final int setNumber;
  final int reps;
  final double weight;
  final double? rpe;
  final bool isWarmup;
  final SetStatus status;
  final String? notes;

  ExerciseSet({
    required this.setNumber,
    this.reps = 0,
    this.weight = 0.0,
    this.rpe,
    this.isWarmup = false,
    this.status = SetStatus.pending,
    this.notes,
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
    };
  }

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    SetStatus status = SetStatus.pending;
    try {
      status = SetStatus.values.firstWhere(
            (s) => s.name == map['status'],
      );
    } catch (_) {}

    return ExerciseSet(
      setNumber: map['setNumber'] ?? 1,
      reps: map['reps'] ?? 0,
      weight: (map['weight'] ?? 0.0).toDouble(),
      rpe: map['rpe']?.toDouble(),
      isWarmup: (map['isWarmup'] ?? 0) == 1,
      status: status,
      notes: map['notes'],
    );
  }

  ExerciseSet copyWith({
    int? reps,
    double? weight,
    double? rpe,
    bool? isWarmup,
    SetStatus? status,
    String? notes,
  }) {
    return ExerciseSet(
      setNumber: setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      rpe: rpe ?? this.rpe,
      isWarmup: isWarmup ?? this.isWarmup,
      status: status ?? this.status,
      notes: notes ?? this.notes,
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
    int? dayNumber,
    DateTime? date,
    List<WorkoutExercise>? exercises,
    bool? isRestDay,
    String? notes,
    WorkoutDayStatus? status,
  }) {
    return WorkoutDay(
      id: id,
      programId: programId,
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

  WorkoutProgram({
    required this.id,
    required this.name,
    this.type = ProgramType.weekly,
    this.days = const [],
    this.templateName,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
      type = ProgramType.values.firstWhere(
            (t) => t.name == map['type'],
      );
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
    );
  }

  WorkoutProgram copyWith({
    String? name,
    ProgramType? type,
    List<WorkoutDay>? days,
    String? templateName,
    String? description,
    DateTime? updatedAt,
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