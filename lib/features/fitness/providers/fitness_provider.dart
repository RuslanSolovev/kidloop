import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/fitness_database.dart';
import '../models/fitness_models.dart';
import '../models/enums.dart';
import '../models/helpers.dart';

class FitnessProvider extends ChangeNotifier {
  final FitnessDatabase _db = FitnessDatabase();
  final Uuid _uuid = const Uuid();

  List<Exercise> _exercises = [];
  List<WorkoutProgram> _programs = [];
  List<WorkoutLog> _logs = [];
  List<ProgressRecord> _progressRecords = [];
  UserFitnessProfile? _profile;
  List<WorkoutTemplate> _templates = [];
  List<FitnessPhoto> _photos = [];
  List<WellbeingNote> _wellbeingNotes = [];

  // 🔥 v7: Сессии прохождения программ
  List<ProgramSession> _sessions = [];

  WorkoutDay? _activeWorkoutDay;
  WorkoutLog? _activeWorkoutLog;
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  bool _isWorkoutActive = false;
  DateTime? _workoutStartTime;
  Duration _totalRestTime = Duration.zero;
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isRestTimerActive = false;

  List<Exercise> get exercises => _exercises;
  List<WorkoutProgram> get programs => _programs;
  List<WorkoutLog> get logs => _logs;
  List<ProgressRecord> get progressRecords => _progressRecords;
  UserFitnessProfile? get profile => _profile;
  List<WorkoutTemplate> get templates => _templates;
  List<FitnessPhoto> get photos => _photos;
  List<WellbeingNote> get wellbeingNotes => _wellbeingNotes;

  // 🔥 v7: Геттеры для сессий
  List<ProgramSession> get sessions => _sessions;

  /// Текущая активная сессия программы (или null если нет активной)
  ProgramSession? get activeSession {
    try {
      return _sessions.firstWhere((s) => s.status == ProgramSessionStatus.active);
    } catch (_) {
      return null;
    }
  }

  /// История завершённых сессий
  List<ProgramSession> get completedSessions =>
      _sessions.where((s) => s.status == ProgramSessionStatus.completed).toList();

  WorkoutDay? get activeWorkoutDay => _activeWorkoutDay;
  WorkoutLog? get activeWorkoutLog => _activeWorkoutLog;
  int get currentExerciseIndex => _currentExerciseIndex;
  int get currentSetIndex => _currentSetIndex;
  bool get isWorkoutActive => _isWorkoutActive;
  DateTime? get workoutStartTime => _workoutStartTime;
  Duration get totalRestTime => _totalRestTime;
  int get restSecondsRemaining => _restSecondsRemaining;
  bool get isRestTimerActive => _isRestTimerActive;

  WorkoutExercise? get currentExercise {
    if (_activeWorkoutDay == null ||
        _currentExerciseIndex >= _activeWorkoutDay!.exercises.length) {
      return null;
    }
    return _activeWorkoutDay!.exercises[_currentExerciseIndex];
  }

  ExerciseSet? get currentSet {
    final exercise = currentExercise;
    if (exercise == null || _currentSetIndex >= exercise.sets.length) {
      return null;
    }
    return exercise.sets[_currentSetIndex];
  }

  Future<void> init() async {
    debugPrint('🏋️ Инициализация FitnessProvider...');
    await Future.wait([
      _loadExercises(),
      _loadPrograms(),
      _loadLogs(),
      _loadProgress(),
      _loadProfile(),
      _loadTemplates(),
      _loadPhotos(),
      _loadWellbeingNotes(),
      _loadSessions(), // 🔥 v7: Загрузка сессий
    ]);
    debugPrint('✅ FitnessProvider инициализирован');
    debugPrint('📋 Сессий программ: ${_sessions.length}, активных: ${activeSession != null ? 1 : 0}');
    notifyListeners();
  }

  Future<void> _loadExercises() async {
    final data = await _db.query('exercises', orderBy: 'name ASC');
    _exercises = data.map((e) => Exercise.fromMap(e)).toList();
  }

  Future<void> _loadPrograms() async {
    final data = await _db.query('workout_programs', orderBy: 'createdAt DESC');
    _programs = [];
    for (final p in data) {
      final program = WorkoutProgram.fromMap(p);
      final daysData = await _db.query('workout_days',
          where: 'programId = ?', whereArgs: [program.id], orderBy: 'dayNumber ASC');
      program.days.clear();
      program.days.addAll(daysData.map((d) => WorkoutDay.fromMap(d)));
      _programs.add(program);
    }
  }

  Future<void> _loadLogs() async {
    final data = await _db.query('workout_logs', orderBy: 'date DESC', limit: 1000);
    _logs = data.map((l) => WorkoutLog.fromMap(l)).toList();
  }

  Future<void> _loadProgress() async {
    final data = await _db.query('progress_records', orderBy: 'date ASC');
    _progressRecords = data.map((p) => ProgressRecord.fromMap(p)).toList();
    debugPrint('📊 Загружено записей прогресса: ${_progressRecords.length}');
  }

  Future<void> _loadProfile() async {
    final data = await _db.query('user_fitness_profile', limit: 1);
    if (data.isNotEmpty) {
      _profile = UserFitnessProfile.fromMap(data.first);
    }
  }

  Future<void> _loadTemplates() async {
    final data = await _db.query('workout_templates', orderBy: 'name ASC');
    _templates = data.map((t) => WorkoutTemplate.fromMap(t)).toList();
  }

  Future<void> _loadPhotos() async {
    final data = await _db.query('fitness_photos', orderBy: 'date DESC');
    _photos = data.map((p) => FitnessPhoto.fromMap(p)).toList();
  }

  Future<void> _loadWellbeingNotes() async {
    final data = await _db.query('wellbeing_notes', orderBy: 'date DESC');
    _wellbeingNotes = data.map((n) => WellbeingNote.fromMap(n)).toList();
  }

  // 🔥 v7: Загрузка сессий программ
  Future<void> _loadSessions() async {
    final data = await _db.query('program_sessions', orderBy: 'startDate DESC');
    _sessions = data.map((s) => ProgramSession.fromMap(s)).toList();
  }

  Future<void> createProfile(UserFitnessProfile profile) async {
    await _db.insert('user_fitness_profile', profile.toMap());
    _profile = profile;
    notifyListeners();
  }

  Future<void> updateProfile(UserFitnessProfile profile) async {
    await _db.update('user_fitness_profile', profile.toMap(),
        where: 'id = ?', whereArgs: [profile.id]);
    _profile = profile;
    notifyListeners();
  }

  Future<void> addBodyWeight(double weight) async {
    if (_profile == null) {
      await createProfile(UserFitnessProfile(id: _uuid.v4()));
    }
    final entry = BodyWeightEntry(date: DateTime.now(), weight: weight);
    final updatedHistory = List<BodyWeightEntry>.from(_profile!.bodyWeightHistory)..add(entry);
    final updatedProfile = _profile!.copyWith(bodyWeightHistory: updatedHistory);
    await updateProfile(updatedProfile);
  }

  Future<Exercise> addExercise({
    required String name,
    String description = '',
    List<MuscleGroup> muscleGroups = const [],
    String? imageUrl,
    ExerciseType exerciseType = ExerciseType.strength,
    String? videoUrl,
    String? techniqueTips,
    String? commonMistakes,
  }) async {
    final exercise = Exercise(
      id: _uuid.v4(),
      name: name,
      description: description,
      muscleGroups: muscleGroups,
      imageUrl: imageUrl,
      exerciseType: exerciseType,
      isCustom: true,
      videoUrl: videoUrl,
      techniqueTips: techniqueTips,
      commonMistakes: commonMistakes,
    );
    await _db.insert('exercises', exercise.toMap());
    _exercises.add(exercise);
    _exercises.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return exercise;
  }

  Future<void> updateExercise(Exercise exercise) async {
    await _db.update('exercises', exercise.toMap(), where: 'id = ?', whereArgs: [exercise.id]);
    final index = _exercises.indexWhere((e) => e.id == exercise.id);
    if (index != -1) _exercises[index] = exercise;
    notifyListeners();
  }

  Future<void> deleteExercise(String id) async {
    await _db.delete('exercises', where: 'id = ?', whereArgs: [id]);
    _exercises.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  List<Exercise> getExercisesByMuscle(MuscleGroup muscle) {
    return _exercises.where((e) => e.muscleGroups.contains(muscle)).toList();
  }

  List<Exercise> searchExercises(String query) {
    final lower = query.toLowerCase();
    return _exercises.where((e) =>
    e.name.toLowerCase().contains(lower) ||
        e.description.toLowerCase().contains(lower) ||
        e.muscleGroups.any((m) => m.displayName.toLowerCase().contains(lower))).toList();
  }

  List<Exercise> filterExercises({List<MuscleGroup>? muscles, ExerciseType? type, bool? isCustom}) {
    return _exercises.where((e) {
      if (muscles != null && !e.muscleGroups.any((m) => muscles.contains(m))) return false;
      if (type != null && e.exerciseType != type) return false;
      if (isCustom != null && e.isCustom != isCustom) return false;
      return true;
    }).toList();
  }

  Future<WorkoutProgram> createProgram({
    required String name,
    ProgramType type = ProgramType.weekly,
    String? description,
  }) async {
    final program = WorkoutProgram(id: _uuid.v4(), name: name, type: type, description: description);
    await _db.insert('workout_programs', program.toMap());
    _programs.insert(0, program);
    notifyListeners();
    return program;
  }

  Future<void> updateProgram(WorkoutProgram program) async {
    await _db.update('workout_programs', program.toMap(), where: 'id = ?', whereArgs: [program.id]);
    final index = _programs.indexWhere((p) => p.id == program.id);
    if (index != -1) _programs[index] = program;
    notifyListeners();
  }

  Future<void> deleteProgram(String id) async {
    await _db.delete('workout_programs', where: 'id = ?', whereArgs: [id]);
    _programs.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<WorkoutDay> addDayToProgram({
    required String programId,
    int dayNumber = 1,
    DateTime? date,
    bool isRestDay = false,
    String? notes,
  }) async {
    final day = WorkoutDay(
      id: _uuid.v4(),
      programId: programId,
      dayNumber: dayNumber,
      date: date,
      isRestDay: isRestDay,
      notes: notes,
    );
    await _db.insert('workout_days', day.toMap());
    final program = _programs.firstWhere((p) => p.id == programId);
    final updatedDays = List<WorkoutDay>.from(program.days)..add(day);
    final updatedProgram = program.copyWith(days: updatedDays);
    await updateProgram(updatedProgram);
    return day;
  }

  Future<void> updateDay(WorkoutDay day) async {
    await _db.update('workout_days', day.toMap(), where: 'id = ?', whereArgs: [day.id]);
    final program = _programs.firstWhere((p) => p.id == day.programId);
    final dayIndex = program.days.indexWhere((d) => d.id == day.id);
    if (dayIndex != -1) {
      final updatedDays = List<WorkoutDay>.from(program.days);
      updatedDays[dayIndex] = day;
      final updatedProgram = program.copyWith(days: updatedDays);
      await updateProgram(updatedProgram);
    }
  }

  Future<void> addExerciseToDay({
    required String dayId,
    required String exerciseId,
    int sets = 3,
    int reps = 10,
    double weight = 0.0,
    ExerciseGroupType groupType = ExerciseGroupType.straight,
    int? groupId,
    int? restBetweenSeconds,
  }) async {
    final program = _programs.firstWhere((p) => p.days.any((d) => d.id == dayId));
    final day = program.days.firstWhere((d) => d.id == dayId);
    final exerciseSets = List.generate(sets, (i) => ExerciseSet(setNumber: i + 1, reps: reps, weight: weight));
    final workoutExercise = WorkoutExercise(
      id: _uuid.v4(),
      exerciseId: exerciseId,
      order: day.exercises.length,
      sets: exerciseSets,
      groupType: groupType,
      groupId: groupId,
      restBetweenSeconds: restBetweenSeconds,
    );
    final updatedExercises = List<WorkoutExercise>.from(day.exercises)..add(workoutExercise);
    final updatedDay = day.copyWith(exercises: updatedExercises);
    await updateDay(updatedDay);
  }

  Future<void> removeExerciseFromDay(String dayId, String exerciseId) async {
    final program = _programs.firstWhere((p) => p.days.any((d) => d.id == dayId));
    final day = program.days.firstWhere((d) => d.id == dayId);
    final updatedExercises = day.exercises.where((e) => e.id != exerciseId).toList();
    for (int i = 0; i < updatedExercises.length; i++) {
      updatedExercises[i] = updatedExercises[i].copyWith(order: i);
    }
    final updatedDay = day.copyWith(exercises: updatedExercises);
    await updateDay(updatedDay);
  }

  Future<WorkoutProgram> addFullProgram({
    required String name,
    required ProgramType type,
    required List<Map<String, dynamic>> daysData,
  }) async {
    final program = WorkoutProgram(
      id: _uuid.v4(),
      name: name,
      type: type,
      description: '',
    );
    await _db.insert('workout_programs', program.toMap());

    final days = <WorkoutDay>[];
    for (final dayData in daysData) {
      final exercisesData = dayData['exercises'];
      final List<WorkoutExercise> exercises = [];

      if (exercisesData is List) {
        for (final exData in exercisesData) {
          if (exData is WorkoutExercise) {
            exercises.add(exData);
          } else if (exData is Map) {
            final Map<String, dynamic> exMap = {};
            (exData as Map).forEach((key, value) {
              exMap[key.toString()] = value;
            });
            exercises.add(WorkoutExercise.fromMap(exMap));
          }
        }
      }

      debugPrint('📋 День ${dayData['dayNumber']}: ${exercises.length} упражнений');

      final day = WorkoutDay(
        id: _uuid.v4(),
        programId: program.id,
        dayNumber: dayData['dayNumber'] ?? 1,
        isRestDay: dayData['isRestDay'] ?? false,
        notes: dayData['notes'],
        exercises: exercises,
      );

      await _db.insert('workout_days', day.toMap());
      days.add(day);
    }

    final updatedProgram = program.copyWith(days: days);
    await _db.update('workout_programs', updatedProgram.toMap(),
        where: 'id = ?', whereArgs: [program.id]);

    _programs.insert(0, updatedProgram);
    notifyListeners();

    debugPrint('✅ Программа создана: ${updatedProgram.name}, дней: ${updatedProgram.days.length}');
    return updatedProgram;
  }

  Future<void> createTemplateFromProgram(String programId, String templateName) async {
    final program = _programs.firstWhere((p) => p.id == programId);
    final template = WorkoutTemplate(
      id: _uuid.v4(),
      name: templateName,
      description: program.description ?? '',
      type: program.type,
      days: program.days,
      category: 'custom',
    );
    await _db.insert('workout_templates', template.toMap());
    _templates.add(template);
    notifyListeners();
  }

  Future<WorkoutProgram> createProgramFromTemplate(String templateId) async {
    final template = _templates.firstWhere((t) => t.id == templateId);

    debugPrint('📋 Создание программы из шаблона: ${template.name}');
    debugPrint('📋 Дней в шаблоне: ${template.days.length}');

    final program = WorkoutProgram(
      id: _uuid.v4(),
      name: template.name,
      type: template.type,
      description: template.description,
    );
    await _db.insert('workout_programs', program.toMap());

    final days = <WorkoutDay>[];
    for (final templateDay in template.days) {
      debugPrint('📋 День ${templateDay.dayNumber}: ${templateDay.exercises.length} упражнений');

      final exercises = templateDay.exercises.map((e) {
        final sets = e.sets.map((s) => ExerciseSet(
          setNumber: s.setNumber,
          reps: s.reps,
          weight: s.weight,
          isWarmup: s.isWarmup,
          rpe: s.rpe,
          status: SetStatus.pending,
        )).toList();

        return WorkoutExercise(
          id: _uuid.v4(),
          exerciseId: e.exerciseId,
          order: e.order,
          sets: sets,
          groupType: e.groupType,
          restBetweenSeconds: e.restBetweenSeconds,
          notes: e.notes,
        );
      }).toList();

      final day = WorkoutDay(
        id: _uuid.v4(),
        programId: program.id,
        dayNumber: templateDay.dayNumber,
        isRestDay: templateDay.isRestDay,
        notes: templateDay.notes,
        exercises: exercises,
      );

      await _db.insert('workout_days', day.toMap());
      days.add(day);
    }

    final updatedProgram = program.copyWith(days: days);
    await updateProgram(updatedProgram);

    _programs.insert(0, updatedProgram);
    notifyListeners();

    debugPrint('✅ Программа создана: ${updatedProgram.name}, дней: ${updatedProgram.days.length}');
    return updatedProgram;
  }

  Future<void> startWorkout(WorkoutDay day) async {
    _activeWorkoutDay = day;
    _currentExerciseIndex = 0;
    _currentSetIndex = 0;
    _isWorkoutActive = true;
    _workoutStartTime = DateTime.now();
    _totalRestTime = Duration.zero;
    _activeWorkoutLog = WorkoutLog(
      id: _uuid.v4(),
      date: DateTime.now(),
      programId: day.programId,
      dayNumber: day.dayNumber,
      startTime: _workoutStartTime,
      status: WorkoutDayStatus.pending,
    );
    notifyListeners();
  }

  Future<void> logSet({required int reps, required double weight, double? rpe, String? notes}) async {
    if (!_isWorkoutActive || currentExercise == null || currentSet == null) return;
    final updatedSet = currentSet!.copyWith(
        reps: reps, weight: weight, rpe: rpe, status: SetStatus.completed, notes: notes);
    final day = _activeWorkoutDay!;
    final exercises = List<WorkoutExercise>.from(day.exercises);
    final exercise = exercises[_currentExerciseIndex];
    final sets = List<ExerciseSet>.from(exercise.sets);
    sets[_currentSetIndex] = updatedSet;
    exercises[_currentExerciseIndex] = exercise.copyWith(sets: sets);
    _activeWorkoutDay = day.copyWith(exercises: exercises);
    _activeWorkoutLog = _activeWorkoutLog!.copyWith(exercisesLog: exercises);
    _startRestTimer(exercise.restBetweenSeconds ?? 90);
    notifyListeners();
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    _restSecondsRemaining = seconds;
    _isRestTimerActive = true;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining > 0) {
        _restSecondsRemaining--;
        _totalRestTime += const Duration(seconds: 1);
        notifyListeners();
      } else {
        timer.cancel();
        _isRestTimerActive = false;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void skipRest() {
    _restTimer?.cancel();
    _restSecondsRemaining = 0;
    _isRestTimerActive = false;
    notifyListeners();
  }

  Future<void> nextSet() async {
    if (!_isWorkoutActive || currentExercise == null) return;
    final exercise = currentExercise!;
    if (_currentSetIndex < exercise.sets.length - 1) {
      _currentSetIndex++;
    } else {
      _currentSetIndex = 0;
      _currentExerciseIndex++;
    }
    notifyListeners();
  }

  Future<void> skipExercise() async {
    if (!_isWorkoutActive) return;
    _currentSetIndex = 0;
    _currentExerciseIndex++;
    notifyListeners();
  }

  Future<WorkoutLog> finishWorkout({String? comment, String? bodyWeight}) async {
    if (!_isWorkoutActive) throw Exception('Нет активной тренировки');
    final endTime = DateTime.now();
    final exercises = _activeWorkoutDay!.exercises;
    final totalVolume = FitnessHelpers.calculateTotalVolume(exercises);
    final avgRpe = FitnessHelpers.calculateAverageRpe(exercises);
    final completedLog = _activeWorkoutLog!.copyWith(
      status: WorkoutDayStatus.completed,
      comment: comment,
      endTime: endTime,
      exercisesLog: exercises,
      totalRestTime: _totalRestTime,
      totalVolume: totalVolume,
      avgRpe: avgRpe,
      bodyWeight: bodyWeight,
    );
    await _db.insert('workout_logs', completedLog.toMap());
    _logs.insert(0, completedLog);
    await _updateProgress(exercises);
    final day = _activeWorkoutDay!;
    await updateDay(day.copyWith(status: WorkoutDayStatus.completed));

    // 🔥 v7: Обновляем активную сессию если она есть
    await _updateSessionAfterWorkout(totalVolume, avgRpe);

    _resetWorkoutState();
    notifyListeners();
    return completedLog;
  }

  Future<void> skipWorkout({String? comment}) async {
    if (!_isWorkoutActive) return;
    final skippedLog = _activeWorkoutLog!.copyWith(
        status: WorkoutDayStatus.skipped, comment: comment ?? 'Пропущена', endTime: DateTime.now());
    await _db.insert('workout_logs', skippedLog.toMap());
    _logs.insert(0, skippedLog);
    final day = _activeWorkoutDay!;
    await updateDay(day.copyWith(status: WorkoutDayStatus.skipped));

    // 🔥 v7: Обновляем сессию при пропуске
    await _skipCurrentDayInSession(comment ?? 'Пропущена');

    _resetWorkoutState();
    notifyListeners();
  }

  void _resetWorkoutState() {
    _restTimer?.cancel();
    _activeWorkoutDay = null;
    _activeWorkoutLog = null;
    _currentExerciseIndex = 0;
    _currentSetIndex = 0;
    _isWorkoutActive = false;
    _workoutStartTime = null;
    _totalRestTime = Duration.zero;
    _restSecondsRemaining = 0;
    _isRestTimerActive = false;
  }

  Future<void> _updateProgress(List<WorkoutExercise> exercises) async {
    final now = DateTime.now();
    for (final exercise in exercises) {
      final completedSets = exercise.sets.where((s) => s.status == SetStatus.completed && !s.isWarmup).toList();
      if (completedSets.isEmpty) continue;

      ExerciseSet bestSet = completedSets.first;
      for (final set in completedSets) {
        if (set.volume > bestSet.volume) bestSet = set;
      }

      final estimated1RM = FitnessHelpers.calculate1RM(bestSet.weight, bestSet.reps);
      final totalVolume = completedSets.fold(0.0, (sum, s) => sum + s.volume);
      final rpeValues = completedSets.where((s) => s.rpe != null).map((s) => s.rpe!).toList();

      final progressRecord = ProgressRecord(
        id: _uuid.v4(),
        exerciseId: exercise.exerciseId,
        date: now,
        bestWeight: bestSet.weight,
        bestReps: bestSet.reps,
        estimated1RM: estimated1RM,
        totalVolume: totalVolume,
        totalSets: completedSets.length,
        avgRpe: rpeValues.isNotEmpty ? rpeValues.reduce((a, b) => a + b) / rpeValues.length : null,
      );

      try {
        await _db.insert('progress_records', progressRecord.toMap());
        _progressRecords.add(progressRecord);
        debugPrint('✅ Прогресс сохранён для: ${exercise.exerciseId}');
      } catch (e) {
        debugPrint('❌ Ошибка сохранения прогресса: $e');
      }
    }
    notifyListeners();
  }

  Future<void> saveWorkoutLogDirect(WorkoutLog log) async {
    try {
      await _db.insert('workout_logs', log.toMap());
      _logs.insert(0, log);
      await _updateProgressFromExercises(log.exercisesLog, log.date);

      // 🔥 ИСПРАВЛЕНО: Обновляем сессию программы если это текущий день
      await _updateSessionFromLog(log);

      notifyListeners();
      debugPrint('✅ Лог тренировки сохранён: ${log.id}');
    } catch (e) {
      debugPrint('❌ Ошибка сохранения лога: $e');
    }
  }

  /// 🔥 НОВЫЙ МЕТОД: Обновление сессии из сохранённого лога
  Future<void> _updateSessionFromLog(WorkoutLog log) async {
    final session = activeSession;
    if (session == null) {
      debugPrint('ℹ️ Нет активной сессии, пропускаем обновление');
      return;
    }

    // Проверяем, что это лог для активной программы
    if (log.programId != session.programId) {
      debugPrint('ℹ️ Лог для другой программы (${log.programId}), пропускаем');
      return;
    }

    if (log.dayNumber == null) {
      debugPrint('⚠️ У лога нет dayNumber, пропускаем');
      return;
    }

    final program = _programs.firstWhere(
          (p) => p.id == session.programId,
      orElse: () => _programs.first,
    );

    // Находим индекс дня по номеру
    final dayIndex = program.days.indexWhere((d) => d.dayNumber == log.dayNumber);
    if (dayIndex == -1) {
      debugPrint('⚠️ День ${log.dayNumber} не найден в программе');
      return;
    }

    // Это должен быть текущий день
    if (dayIndex != session.currentDayIndex) {
      debugPrint('⚠️ Лог для дня ${log.dayNumber}, но текущий день ${session.currentDayIndex + 1}');
      return;
    }

    // Проверяем что день ещё не был помечен как выполненный
    if (session.daySessions[dayIndex].status == DaySessionStatus.completed) {
      debugPrint('⚠️ День ${log.dayNumber} уже помечен как выполненный');
      return;
    }

    debugPrint('📊 Обновляем сессию из лога: день ${log.dayNumber}');

    // Обновляем текущий день как выполненный
    final updatedDays = List<DaySession>.from(session.daySessions);
    updatedDays[dayIndex] = updatedDays[dayIndex].copyWith(
      status: DaySessionStatus.completed,
      completedAt: log.endTime ?? DateTime.now(),
      volumeDone: log.totalVolume,
      avgRpe: log.avgRpe,
    );

    // Находим следующий день
    int nextIndex = dayIndex + 1;
    bool isProgramComplete = nextIndex >= program.days.length;

    // Автоматически проходим дни отдыха
    while (nextIndex < program.days.length && program.days[nextIndex].isRestDay) {
      updatedDays[nextIndex] = updatedDays[nextIndex].copyWith(
        status: DaySessionStatus.completed,
        completedAt: DateTime.now(),
        notes: 'Автоматический день отдыха',
      );
      nextIndex++;
      if (nextIndex >= program.days.length) {
        isProgramComplete = true;
        break;
      }
    }

    // Открываем следующий рабочий день
    if (!isProgramComplete && nextIndex < program.days.length) {
      updatedDays[nextIndex] = updatedDays[nextIndex].copyWith(
        status: DaySessionStatus.current,
      );
    }

    // Обновляем статистику
    int newStreak = session.streak + 1;
    int newLongest = newStreak > session.longestStreak ? newStreak : session.longestStreak;
    final newCompleted = session.totalWorkoutsCompleted + 1;

    final newAvgRpe = log.avgRpe != null
        ? (session.averageRpe * session.totalWorkoutsCompleted + log.avgRpe!) / newCompleted
        : session.averageRpe;

    final updatedSession = session.copyWith(
      currentDayIndex: isProgramComplete ? session.currentDayIndex : nextIndex,
      daySessions: updatedDays,
      streak: newStreak,
      longestStreak: newLongest,
      totalVolumeCompleted: session.totalVolumeCompleted + (log.totalVolume ?? 0),
      totalWorkoutsCompleted: newCompleted,
      averageRpe: newAvgRpe,
      status: isProgramComplete ? ProgramSessionStatus.completed : ProgramSessionStatus.active,
      endDate: isProgramComplete ? DateTime.now() : null,
      completedAt: isProgramComplete ? DateTime.now() : null,
    );

    await _db.update('program_sessions', updatedSession.toMap(),
        where: 'id = ?', whereArgs: [session.id]);

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) _sessions[index] = updatedSession;

    debugPrint('✅ Сессия обновлена: день ${dayIndex + 1}/${program.days.length}, серия: $newStreak, прогресс: ${(updatedSession.progressPercent * 100).toInt()}%');

    // Если программа завершена — генерируем сводку
    if (isProgramComplete) {
      debugPrint('🏆 Программа завершена!');
      await _generateProgramSummary(updatedSession, program);
    }
  }

  Future<void> _updateProgressFromExercises(List<WorkoutExercise> exercises, DateTime date) async {
    int savedCount = 0;
    for (final exercise in exercises) {
      final completedSets = exercise.sets.where((s) => s.status == SetStatus.completed && !s.isWarmup).toList();
      if (completedSets.isEmpty) continue;

      ExerciseSet bestSet = completedSets.first;
      for (final set in completedSets) {
        if (set.volume > bestSet.volume) bestSet = set;
      }

      final estimated1RM = FitnessHelpers.calculate1RM(bestSet.weight, bestSet.reps);
      final totalVolume = completedSets.fold(0.0, (sum, s) => sum + s.volume);
      final rpeValues = completedSets.where((s) => s.rpe != null).map((s) => s.rpe!).toList();

      final record = ProgressRecord(
        id: _uuid.v4(),
        exerciseId: exercise.exerciseId,
        date: date,
        bestWeight: bestSet.weight,
        bestReps: bestSet.reps,
        estimated1RM: estimated1RM,
        totalVolume: totalVolume,
        totalSets: completedSets.length,
        avgRpe: rpeValues.isNotEmpty ? rpeValues.reduce((a, b) => a + b) / rpeValues.length : null,
      );

      try {
        await _db.insert('progress_records', record.toMap());
        _progressRecords.add(record);
        savedCount++;
      } catch (e) {
        debugPrint('❌ Ошибка сохранения прогресса: $e');
      }
    }
    debugPrint('📊 Сохранено записей прогресса: $savedCount');
    notifyListeners();
  }

  ExerciseDetailedSummary getExerciseDetailedSummary(String exerciseId) {
    final records = getExerciseProgress(exerciseId);
    if (records.isEmpty) {
      return ExerciseDetailedSummary.empty(exerciseId);
    }

    double minWeight = double.infinity;
    double maxWeight = 0;
    double totalWeight = 0;
    DateTime? minDate;
    DateTime? maxDate;
    int totalSets = 0;

    for (final r in records) {
      if (r.bestWeight < minWeight) {
        minWeight = r.bestWeight;
        minDate = r.date;
      }
      if (r.bestWeight > maxWeight) {
        maxWeight = r.bestWeight;
        maxDate = r.date;
      }
      totalWeight += r.bestWeight;
      totalSets += r.totalSets;
    }

    return ExerciseDetailedSummary(
      exerciseId: exerciseId,
      minWeight: minWeight == double.infinity ? 0 : minWeight,
      maxWeight: maxWeight,
      avgWeight: records.isNotEmpty ? totalWeight / records.length : 0,
      minDate: minDate,
      maxDate: maxDate,
      totalWorkouts: records.length,
      totalSets: totalSets,
      totalVolume: records.fold(0.0, (sum, r) => sum + r.totalVolume),
    );
  }

  Future<void> updateLogComment(String logId, String comment) async {
    final log = _logs.firstWhere((l) => l.id == logId);
    final updatedLog = log.copyWith(comment: comment);
    await _db.update('workout_logs', updatedLog.toMap(), where: 'id = ?', whereArgs: [logId]);
    final index = _logs.indexWhere((l) => l.id == logId);
    if (index != -1) _logs[index] = updatedLog;
    notifyListeners();
  }

  List<WorkoutLog> getLogsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _logs.where((l) => l.date.isAfter(start) && l.date.isBefore(end)).toList();
  }

  List<WorkoutLog> getLogsForDateRange(DateTime start, DateTime end) {
    return _logs.where((l) =>
    l.date.isAfter(start.subtract(const Duration(days: 1))) &&
        l.date.isBefore(end.add(const Duration(days: 1)))).toList();
  }

  Map<DateTime, List<WorkoutLog>> getLogsGroupedByDate(int days) {
    final map = <DateTime, List<WorkoutLog>>{};
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final logs = getLogsForDate(date);
      map[date] = logs;
    }
    return map;
  }

  List<ProgressRecord> getExerciseProgress(String exerciseId) {
    return _progressRecords.where((r) => r.exerciseId == exerciseId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  ProgressRecord? getLastProgress(String exerciseId) {
    final records = getExerciseProgress(exerciseId);
    return records.isNotEmpty ? records.last : null;
  }

  double getExerciseBest1RM(String exerciseId) {
    final records = getExerciseProgress(exerciseId);
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.estimated1RM).reduce((a, b) => a > b ? a : b);
  }

  TrendLine getExerciseTrend(String exerciseId) {
    return FitnessHelpers.calculateTrendLine(getExerciseProgress(exerciseId));
  }

  Future<FitnessPhoto> addPhoto({
    required String imageUrl,
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
  }) async {
    final photo = FitnessPhoto(
      id: _uuid.v4(),
      date: DateTime.now(),
      imageUrl: imageUrl,
      label: label,
      weight: weight,
      notes: notes,
      chest: chest,
      waist: waist,
      hips: hips,
      biceps: biceps,
      thigh: thigh,
      calf: calf,
      neck: neck,
      forearm: forearm,
    );
    await _db.insert('fitness_photos', photo.toMap());
    _photos.insert(0, photo);
    notifyListeners();
    return photo;
  }

  Future<void> updatePhoto(FitnessPhoto photo) async {
    await _db.update('fitness_photos', photo.toMap(), where: 'id = ?', whereArgs: [photo.id]);
    final index = _photos.indexWhere((p) => p.id == photo.id);
    if (index != -1) _photos[index] = photo;
    notifyListeners();
  }

  Future<void> deletePhoto(String id) async {
    await _db.delete('fitness_photos', where: 'id = ?', whereArgs: [id]);
    _photos.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<WellbeingNote> addWellbeingNote({
    int energyLevel = 5,
    int sleepQuality = 5,
    int motivationLevel = 5,
    List<String> painAreas = const [],
    String? notes,
  }) async {
    final note = WellbeingNote(
      id: _uuid.v4(),
      date: DateTime.now(),
      energyLevel: energyLevel,
      sleepQuality: sleepQuality,
      motivationLevel: motivationLevel,
      painAreas: painAreas,
      notes: notes,
    );
    await _db.insert('wellbeing_notes', note.toMap());
    _wellbeingNotes.insert(0, note);
    notifyListeners();
    return note;
  }

  WellbeingNote? getTodayWellbeing() {
    final now = DateTime.now();
    final index = _wellbeingNotes.indexWhere((n) =>
    n.date.year == now.year && n.date.month == now.month && n.date.day == now.day);
    return index != -1 ? _wellbeingNotes[index] : null;
  }

  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final weekLogs = _logs.where((l) => l.date.isAfter(weekStart)).toList();
    final monthLogs = _logs.where((l) => l.date.isAfter(monthStart)).toList();
    final rpeValues = _logs.where((l) => l.avgRpe != null).map((l) => l.avgRpe!).toList();
    return {
      'totalWorkouts': _logs.length,
      'workoutsThisWeek': weekLogs.length,
      'workoutsThisMonth': monthLogs.length,
      'currentStreak': _calculateStreak(),
      'totalVolume': _logs.fold(0.0, (sum, l) => sum + (l.totalVolume ?? 0)),
      'averageRpe': rpeValues.isNotEmpty ? rpeValues.reduce((a, b) => a + b) / rpeValues.length : 0,
      'totalExercises': _exercises.length,
      'customExercises': _exercises.where((e) => e.isCustom).length,
      'activePrograms': _programs.length,
    };
  }

  int _calculateStreak() {
    if (_logs.isEmpty) return 0;
    int streak = 0;
    final now = DateTime.now();
    final sortedLogs = _logs
        .where((l) => l.status == WorkoutDayStatus.completed)
        .map((l) => l.date)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (sortedLogs.isEmpty) return 0;
    for (int i = 0; i < sortedLogs.length; i++) {
      final expectedDate = now.subtract(Duration(days: i));
      final actualDate = DateTime(sortedLogs[i].year, sortedLogs[i].month, sortedLogs[i].day);
      final expectedDay = DateTime(expectedDate.year, expectedDate.month, expectedDate.day);
      if (actualDate == expectedDay) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Map<String, ExerciseTonnageInfo> getTonnageByExercise() {
    final map = <String, ExerciseTonnageInfo>{};

    for (final log in _logs) {
      for (final exLog in log.exercisesLog) {
        final volume = exLog.sets
            .where((s) => s.status == SetStatus.completed && !s.isWarmup)
            .fold(0.0, (sum, s) => sum + s.volume);

        if (volume == 0) continue;

        final info = map.putIfAbsent(exLog.exerciseId, () => ExerciseTonnageInfo());
        info.totalVolume += volume;
        info.totalWorkouts++;
        if (volume > info.maxSingleWorkoutVolume) {
          info.maxSingleWorkoutVolume = volume;
          info.maxDate = log.date;
        }
      }
    }

    return map;
  }

  Map<MuscleGroup, MuscleTonnageInfo> getTonnageByMuscle() {
    final map = <MuscleGroup, MuscleTonnageInfo>{};

    for (final log in _logs) {
      for (final exercise in log.exercisesLog) {
        final exData = _exercises.firstWhere((e) => e.id == exercise.exerciseId, orElse: () => Exercise(id: '', name: ''));
        final exVolume = exercise.sets.where((s) => s.status == SetStatus.completed && !s.isWarmup).fold(0.0, (sum, s) => sum + s.volume);
        final exSets = exercise.sets.where((s) => s.status == SetStatus.completed && !s.isWarmup).length;

        for (final muscle in exData.muscleGroups) {
          final info = map.putIfAbsent(muscle, () => MuscleTonnageInfo());
          info.totalVolume += exVolume;
          info.totalSets += exSets;
          info.totalWorkouts++;
        }
      }
    }

    return map;
  }

  // ==================== 🔥 СИСТЕМА СЛЕДОВАНИЯ ПРОГРАММАМ ====================

  /// Начать прохождение программы
  Future<ProgramSession> startProgramSession(
      String programId, {
        ProgramDifficulty difficulty = ProgramDifficulty.standard,
      }) async {
    // Проверяем, нет ли уже активной сессии
    if (activeSession != null) {
      throw Exception('У вас уже есть активная программа "${_programs.firstWhere((p) => p.id == activeSession!.programId).name}". Завершите или приостановите её.');
    }

    final program = _programs.firstWhere((p) => p.id == programId);

    // Создаём day sessions для каждого дня программы
    final daySessions = program.days.asMap().entries.map((entry) {
      final isFirst = entry.key == 0;
      return DaySession(
        dayIndex: entry.key,
        status: isFirst ? DaySessionStatus.current : DaySessionStatus.locked,
      );
    }).toList();

    final session = ProgramSession(
      id: _uuid.v4(),
      programId: programId,
      startDate: DateTime.now(),
      difficulty: difficulty,
      daySessions: daySessions,
    );

    await _db.insert('program_sessions', session.toMap());
    _sessions.insert(0, session);
    notifyListeners();

    debugPrint('✅ Начата программа: ${program.name} (${program.days.length} дней, сложность: ${difficulty.name})');
    return session;
  }

  /// Обновить активную сессию после завершения тренировки
  Future<void> _updateSessionAfterWorkout(double volume, double? avgRpe) async {
    final session = activeSession;
    if (session == null) return;

    final program = _programs.firstWhere((p) => p.id == session.programId);

    // Обновляем текущий день как выполненный
    final updatedDays = List<DaySession>.from(session.daySessions);
    updatedDays[session.currentDayIndex] = updatedDays[session.currentDayIndex].copyWith(
      status: DaySessionStatus.completed,
      completedAt: DateTime.now(),
      volumeDone: volume,
      avgRpe: avgRpe,
    );

    // Определяем следующий день
    int nextIndex = session.currentDayIndex + 1;
    bool isProgramComplete = nextIndex >= program.days.length;

    // Автоматически проходим дни отдыха
    while (nextIndex < program.days.length && program.days[nextIndex].isRestDay) {
      updatedDays[nextIndex] = updatedDays[nextIndex].copyWith(
        status: DaySessionStatus.completed,
        completedAt: DateTime.now(),
        notes: 'Автоматический день отдыха',
      );
      nextIndex++;
      if (nextIndex >= program.days.length) {
        isProgramComplete = true;
        break;
      }
    }

    // Открываем следующий рабочий день
    if (!isProgramComplete && nextIndex < program.days.length) {
      updatedDays[nextIndex] = updatedDays[nextIndex].copyWith(
        status: DaySessionStatus.current,
      );
    }

    // Обновляем статистику
    int newStreak = session.streak + 1;
    int newLongest = newStreak > session.longestStreak ? newStreak : session.longestStreak;
    final newCompleted = session.totalWorkoutsCompleted + 1;

    final newAvgRpe = avgRpe != null
        ? (session.averageRpe * session.totalWorkoutsCompleted + avgRpe) / newCompleted
        : session.averageRpe;

    final updatedSession = session.copyWith(
      currentDayIndex: isProgramComplete ? session.currentDayIndex : nextIndex,
      daySessions: updatedDays,
      streak: newStreak,
      longestStreak: newLongest,
      totalVolumeCompleted: session.totalVolumeCompleted + volume,
      totalWorkoutsCompleted: newCompleted,
      averageRpe: newAvgRpe,
      status: isProgramComplete ? ProgramSessionStatus.completed : ProgramSessionStatus.active,
      endDate: isProgramComplete ? DateTime.now() : null,
      completedAt: isProgramComplete ? DateTime.now() : null,
    );

    await _db.update('program_sessions', updatedSession.toMap(), where: 'id = ?', whereArgs: [session.id]);

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) _sessions[index] = updatedSession;

    debugPrint('📊 Сессия обновлена: день ${session.currentDayIndex + 1}/${program.days.length}, серия: $newStreak');

    // Если программа завершена — генерируем сводку
    if (isProgramComplete) {
      await _generateProgramSummary(updatedSession, program);
    }
  }

  /// Пропустить текущий день в активной сессии
  Future<void> _skipCurrentDayInSession(String reason) async {
    final session = activeSession;
    if (session == null) return;

    final program = _programs.firstWhere((p) => p.id == session.programId);
    final updatedDays = List<DaySession>.from(session.daySessions);

    // В режиме hardcore — сбрасываем текущую неделю
    if (session.difficulty == ProgramDifficulty.hardcore) {
      final weekStart = (session.currentDayIndex ~/ 7) * 7;
      for (int i = weekStart; i < session.currentDayIndex; i++) {
        if (i < updatedDays.length && updatedDays[i].status == DaySessionStatus.completed) {
          updatedDays[i] = updatedDays[i].copyWith(
            status: DaySessionStatus.pending,
            completedAt: null,
            volumeDone: null,
          );
        }
      }
      debugPrint('⚠️ Hardcore режим: сброшена неделя ${weekStart ~/ 7 + 1}');
    }

    // Помечаем текущий день как пропущенный
    updatedDays[session.currentDayIndex] = updatedDays[session.currentDayIndex].copyWith(
      status: DaySessionStatus.skipped,
      completedAt: DateTime.now(),
      notes: reason,
    );

    // Находим следующий день
    int nextIndex = session.currentDayIndex + 1;

    // Автоматически проходим дни отдыха
    while (nextIndex < program.days.length && program.days[nextIndex].isRestDay) {
      updatedDays[nextIndex] = updatedDays[nextIndex].copyWith(
        status: DaySessionStatus.completed,
        completedAt: DateTime.now(),
        notes: 'Автоматический день отдыха',
      );
      nextIndex++;
    }

    // Открываем следующий день
    if (nextIndex < program.days.length) {
      updatedDays[nextIndex] = updatedDays[nextIndex].copyWith(
        status: DaySessionStatus.current,
      );
    }

    // Сбрасываем серию (кроме flexible режима)
    final newStreak = session.difficulty == ProgramDifficulty.flexible ? session.streak : 0;

    final updatedSession = session.copyWith(
      currentDayIndex: nextIndex < program.days.length ? nextIndex : session.currentDayIndex,
      daySessions: updatedDays,
      streak: newStreak,
      totalWorkoutsSkipped: session.totalWorkoutsSkipped + 1,
    );

    await _db.update('program_sessions', updatedSession.toMap(), where: 'id = ?', whereArgs: [session.id]);

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) _sessions[index] = updatedSession;

    debugPrint('⏭️ День пропущен, следующий день: ${nextIndex + 1}');
  }

  /// Пропустить день вручную (из UI)
  Future<void> skipCurrentDay({String? reason}) async {
    await _skipCurrentDayInSession(reason ?? 'Пропущен вручную');
    notifyListeners();
  }

  /// Приостановить программу
  Future<void> pauseProgramSession() async {
    final session = activeSession;
    if (session == null) return;

    final updated = session.copyWith(status: ProgramSessionStatus.paused);
    await _db.update('program_sessions', updated.toMap(), where: 'id = ?', whereArgs: [session.id]);

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) _sessions[index] = updated;

    debugPrint('⏸️ Программа приостановлена');
    notifyListeners();
  }

  /// Возобновить программу
  Future<void> resumeProgramSession(String sessionId) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    if (session.status != ProgramSessionStatus.paused) return;

    if (activeSession != null) {
      throw Exception('Сначала завершите или приостановьте текущую активную программу');
    }

    final updated = session.copyWith(status: ProgramSessionStatus.active);
    await _db.update('program_sessions', updated.toMap(), where: 'id = ?', whereArgs: [session.id]);

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) _sessions[index] = updated;

    debugPrint('▶️ Программа возобновлена');
    notifyListeners();
  }

  /// Бросить программу (отказаться от прохождения)
  Future<void> abandonProgramSession(String sessionId) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);

    final updated = session.copyWith(
      status: ProgramSessionStatus.abandoned,
      endDate: DateTime.now(),
    );
    await _db.update('program_sessions', updated.toMap(), where: 'id = ?', whereArgs: [session.id]);

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) _sessions[index] = updated;

    debugPrint('❌ Программа брошена: ${_programs.firstWhere((p) => p.id == session.programId).name}');
    notifyListeners();
  }

  /// Генерация сводки по завершённой программе
  Future<void> _generateProgramSummary(ProgramSession session, WorkoutProgram program) async {
    debugPrint('🏆 Генерация сводки для: ${program.name}');

    final completedDays = session.daySessions.where((d) => d.status == DaySessionStatus.completed).toList();
    final skippedDays = session.daySessions.where((d) => d.status == DaySessionStatus.skipped).toList();

    // Собираем данные по упражнениям за время программы
    final exerciseStats = <String, Map<String, dynamic>>{};

    for (final log in _logs.where((l) => l.date.isAfter(session.startDate))) {
      for (final exLog in log.exercisesLog) {
        if (!exerciseStats.containsKey(exLog.exerciseId)) {
          exerciseStats[exLog.exerciseId] = {
            'totalVolume': 0.0,
            'totalSets': 0,
            'firstWeight': 0.0,
            'lastWeight': 0.0,
            'firstReps': 0,
            'lastReps': 0,
            'workouts': 0,
          };
        }

        final stats = exerciseStats[exLog.exerciseId]!;
        final volume = exLog.sets.where((s) => s.status == SetStatus.completed && !s.isWarmup)
            .fold(0.0, (sum, s) => sum + s.volume);

        stats['totalVolume'] = (stats['totalVolume'] as double) + volume;
        stats['totalSets'] = (stats['totalSets'] as int) + exLog.sets.where((s) => s.status == SetStatus.completed).length;
        stats['workouts'] = (stats['workouts'] as int) + 1;

        if (stats['workouts'] == 1) {
          final firstSet = exLog.sets.firstWhere((s) => !s.isWarmup, orElse: () => exLog.sets.first);
          stats['firstWeight'] = firstSet.weight;
          stats['firstReps'] = firstSet.reps;
        }

        final lastSet = exLog.sets.lastWhere((s) => !s.isWarmup, orElse: () => exLog.sets.last);
        stats['lastWeight'] = lastSet.weight;
        stats['lastReps'] = lastSet.reps;
      }
    }

    final summary = {
      'programName': program.name,
      'startDate': session.startDate.toIso8601String(),
      'endDate': DateTime.now().toIso8601String(),
      'durationDays': DateTime.now().difference(session.startDate).inDays,
      'completedDays': completedDays.length,
      'skippedDays': skippedDays.length,
      'totalDays': program.days.length,
      'totalVolume': session.totalVolumeCompleted,
      'averageRpe': session.averageRpe,
      'longestStreak': session.longestStreak,
      'difficulty': session.difficulty.name,
      'exerciseStats': exerciseStats,
    };

    final updatedSession = session.copyWith(summaryData: summary);
    await _db.update('program_sessions', updatedSession.toMap(), where: 'id = ?', whereArgs: [session.id]);

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) _sessions[index] = updatedSession;

    notifyListeners();

    debugPrint('🏆 Сводка сгенерирована: ${completedDays.length}/${program.days.length} дней, тоннаж: ${session.totalVolumeCompleted.toStringAsFixed(0)} кг');
  }

  /// Получить программу по ID сессии
  WorkoutProgram? getProgramForSession(String sessionId) {
    try {
      final session = _sessions.firstWhere((s) => s.id == sessionId);
      return _programs.firstWhere((p) => p.id == session.programId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ КЛАССЫ ====================

class ExerciseDetailedSummary {
  final String exerciseId;
  final double minWeight;
  final double maxWeight;
  final double avgWeight;
  final DateTime? minDate;
  final DateTime? maxDate;
  final int totalWorkouts;
  final int totalSets;
  final double totalVolume;

  ExerciseDetailedSummary({
    required this.exerciseId,
    required this.minWeight,
    required this.maxWeight,
    required this.avgWeight,
    this.minDate,
    this.maxDate,
    required this.totalWorkouts,
    required this.totalSets,
    required this.totalVolume,
  });

  factory ExerciseDetailedSummary.empty(String exerciseId) => ExerciseDetailedSummary(
    exerciseId: exerciseId,
    minWeight: 0,
    maxWeight: 0,
    avgWeight: 0,
    totalWorkouts: 0,
    totalSets: 0,
    totalVolume: 0,
  );
}

class ExerciseTonnageInfo {
  double totalVolume = 0;
  double maxSingleWorkoutVolume = 0;
  DateTime? maxDate;
  int totalWorkouts = 0;
}

class MuscleTonnageInfo {
  double totalVolume = 0;
  int totalSets = 0;
  int totalWorkouts = 0;
}

extension ListExtension<T> on List<T> {
  T let(T Function(List<T>) block) => block(this);
}