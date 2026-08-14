import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';
import '../widgets/muscle_map_widget.dart';

class ProgramBuilderScreen extends StatefulWidget {
  final WorkoutProgram? existingProgram;
  final bool isDark;

  const ProgramBuilderScreen({
    super.key,
    this.existingProgram,
    this.isDark = false,
  });

  @override
  State<ProgramBuilderScreen> createState() => _ProgramBuilderScreenState();
}

class _ProgramBuilderScreenState extends State<ProgramBuilderScreen> {
  ProgramType _programType = ProgramType.weekly;
  List<WorkoutDay> _days = [];
  int _currentStep = 0;
  int _editingDayIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.existingProgram != null) {
      _programType = widget.existingProgram!.type;
      _days = widget.existingProgram!.days.map((d) {
        return WorkoutDay(
          id: d.id,
          programId: d.programId,
          dayNumber: d.dayNumber,
          isRestDay: d.isRestDay,
          notes: d.notes,
          exercises: d.exercises.map((e) {
            return WorkoutExercise(
              id: e.id,
              exerciseId: e.exerciseId,
              order: e.order,
              sets: e.sets.map((s) {
                return ExerciseSet(
                  setNumber: s.setNumber,
                  reps: s.reps,
                  weight: s.weight,
                  isWarmup: s.isWarmup,
                  status: s.status,
                );
              }).toList(),
              groupType: e.groupType,
              restBetweenSeconds: e.restBetweenSeconds,
            );
          }).toList(),
        );
      }).toList();
    } else {
      _initDays(_programType);
    }
  }

  void _initDays(ProgramType type) {
    int count;
    switch (type) {
      case ProgramType.daily:
        count = 1;
        break;
      case ProgramType.weekly:
        count = 7;
        break;
      case ProgramType.monthly:
        count = 30;
        break;
      default:
        count = 7;
    }
    _days = List.generate(count, (i) {
      return WorkoutDay(
        id: 'temp_${i}_${DateTime.now().millisecondsSinceEpoch}',
        programId: 'new',
        dayNumber: i + 1,
        isRestDay: (type == ProgramType.weekly && (i == 5 || i == 6)),
        exercises: [],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: _buildAppBar(isDark),
      body: _currentStep == 0
          ? _buildExerciseStep(isDark)
          : _buildConfigStep(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      elevation: 0,
      title: Text(
        widget.existingProgram != null ? 'Редактирование' : 'Новая программа',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        if (_currentStep == 0)
          TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text(
              'Далее →',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else ...[
          TextButton(
            onPressed: () => setState(() => _currentStep = 0),
            child: const Text(
              '← Назад',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton.icon(
            onPressed: () => _saveProgram(context),
            icon: const Icon(
              Icons.save_rounded,
              color: Color(0xFFFF6B35),
              size: 18,
            ),
            label: const Text(
              'Сохранить',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ==================== ШАГ 1: ВЫБОР УПРАЖНЕНИЙ ====================

  Widget _buildExerciseStep(bool isDark) {
    final provider = context.watch<FitnessProvider>();
    final day = _days[_editingDayIndex];

    return Column(
      children: [
        _buildTypeSelector(isDark),
        _buildDaysRow(isDark),
        const SizedBox(height: 8),
        _buildDayHeader(isDark, day),
        Expanded(child: _buildDayContent(isDark, day, provider)),
      ],
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: ProgramType.values.map((type) {
          final isSelected = _programType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _programType = type;
                  _initDays(type);
                  _editingDayIndex = 0;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFF6B35)
                      : (isDark ? const Color(0xFF1A1D24) : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  type.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDaysRow(bool isDark) {
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final isSelected = index == _editingDayIndex;
          final label = _programType == ProgramType.weekly
              ? dayNames[index % 7]
              : 'Д${index + 1}';
          return GestureDetector(
            onTap: () => setState(() => _editingDayIndex = index),
            child: Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6B35).withOpacity(0.2)
                    : (isDark ? const Color(0xFF1A1D24) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: const Color(0xFFFF6B35), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFFFF6B35)
                          : (isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                  ),
                  if (day.isRestDay)
                    const Icon(Icons.bedtime, size: 14, color: Colors.grey)
                  else
                    Text(
                      '${day.exercises.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayHeader(bool isDark, WorkoutDay day) {
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final dayLabel = _programType == ProgramType.weekly
        ? " (${dayNames[_editingDayIndex % 7]})"
        : "";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            'День ${day.dayNumber}$dayLabel',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            'Отдых',
            style: TextStyle(
              fontSize: 11,
              color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          Switch(
            value: day.isRestDay,
            onChanged: (v) {
              setState(() {
                _days[_editingDayIndex] = day.copyWith(isRestDay: v);
              });
            },
            activeColor: const Color(0xFFFF6B35),
          ),
          if (!day.isRestDay) ...[
            IconButton(
              icon: const Icon(Icons.search, color: Color(0xFFFF6B35), size: 22),
              onPressed: () => _showExerciseSearch(context),
            ),
            IconButton(
              icon: const Icon(Icons.list_alt, color: Color(0xFFFF6B35), size: 22),
              onPressed: () => _showExerciseList(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayContent(bool isDark, WorkoutDay day, FitnessProvider provider) {
    if (day.isRestDay) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bedtime_rounded,
              size: 80,
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'День отдыха',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Подсказка
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Нажмите на область мышц для фильтрации упражнений',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ),
        // Манекен БЕЗ SingleChildScrollView - занимает фиксированную высоту
        SizedBox(
          height: 380,
          child: InteractiveMuscleMap(
            onMuscleSelected: (muscle) {
              debugPrint('🎯 Выбрана мышца: ${muscle.displayName}');
              _showFilteredExercises(context, muscle);
            },
          ),
        ),
        // Добавленные упражнения
        if (day.exercises.isNotEmpty)
          Container(
            height: 80,
            margin: const EdgeInsets.all(12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: day.exercises.length,
              itemBuilder: (context, index) {
                final we = day.exercises[index];
                final exData = provider.exercises.firstWhere(
                      (e) => e.id == we.exerciseId,
                  orElse: () => Exercise(id: '', name: '???'),
                );
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: exData.muscleGroups.isNotEmpty
                          ? exData.muscleGroups.first.color.withOpacity(0.3)
                          : Colors.grey,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        exData.exerciseType.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exData.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${we.sets.length} подх.',
                        style: const TextStyle(
                          fontSize: 7,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ==================== ШТОРКИ БЕЗ ЛИШНИХ ОБЁРТОК ====================

  void _showExerciseSearch(BuildContext context) {
    debugPrint('🔍 Открытие поиска упражнений');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ExerciseSearchSheet(
          isDark: widget.isDark,
          onAdd: (exercise) => _addExerciseToDay(exercise),
          onRemove: (exercise) => _removeExerciseFromDay(exercise),
          addedIds: _days[_editingDayIndex]
              .exercises
              .map((e) => e.exerciseId)
              .toList(),
        );
      },
    );
  }

  void _showExerciseList(BuildContext context) {
    debugPrint('📋 Открытие списка упражнений');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ExerciseListSheet(
          isDark: widget.isDark,
          onAdd: (exercise) => _addExerciseToDay(exercise),
          onRemove: (exercise) => _removeExerciseFromDay(exercise),
          addedIds: _days[_editingDayIndex]
              .exercises
              .map((e) => e.exerciseId)
              .toList(),
        );
      },
    );
  }

  void _showFilteredExercises(BuildContext context, MuscleGroup muscle) {
    debugPrint('🎯 Фильтрация по мышце: ${muscle.displayName}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ExerciseListSheet(
          isDark: widget.isDark,
          onAdd: (exercise) => _addExerciseToDay(exercise),
          onRemove: (exercise) => _removeExerciseFromDay(exercise),
          addedIds: _days[_editingDayIndex]
              .exercises
              .map((e) => e.exerciseId)
              .toList(),
          filterMuscle: muscle,
        );
      },
    );
  }

  void _addExerciseToDay(Exercise exercise) {
    setState(() {
      final day = _days[_editingDayIndex];
      if (day.exercises.any((e) => e.exerciseId == exercise.id)) return;
      final we = WorkoutExercise(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        exerciseId: exercise.id,
        order: day.exercises.length,
        sets: [ExerciseSet(setNumber: 1, reps: 10, weight: 0)],
      );
      _days[_editingDayIndex] = day.copyWith(
        exercises: [...day.exercises, we],
      );
    });
  }

  void _removeExerciseFromDay(Exercise exercise) {
    setState(() {
      final day = _days[_editingDayIndex];
      _days[_editingDayIndex] = day.copyWith(
        exercises: day.exercises
            .where((e) => e.exerciseId != exercise.id)
            .toList(),
      );
    });
  }

  // ==================== ШАГ 2: НАСТРОЙКА ПОДХОДОВ ====================

  Widget _buildConfigStep(bool isDark) {
    final provider = context.watch<FitnessProvider>();
    final day = _days[_editingDayIndex];

    if (day.isRestDay) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bedtime_rounded,
              size: 64,
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'День отдыха — нечего настраивать',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (day.exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Добавьте упражнения на первом шаге',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildDaysRow(isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Настройка подходов',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                'День ${day.dayNumber}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Настройте вес и повторения сейчас или оставьте на потом. '
                        'Для кардио и йоги настройте время выполнения.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: day.exercises.length,
            itemBuilder: (context, exIndex) {
              final we = day.exercises[exIndex];
              final exData = provider.exercises.firstWhere(
                    (e) => e.id == we.exerciseId,
                orElse: () => Exercise(id: '', name: '???'),
              );
              return _buildExerciseConfigCard(isDark, exIndex, we, exData);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseConfigCard(
      bool isDark,
      int exIndex,
      WorkoutExercise we,
      Exercise exData,
      ) {
    final isTimeBased = exData.exerciseType == ExerciseType.cardio ||
        exData.exerciseType == ExerciseType.yoga ||
        exData.exerciseType == ExerciseType.other;

    return Card(
      color: isDark ? const Color(0xFF1A1D24) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: exData.muscleGroups.isNotEmpty
                ? exData.muscleGroups.first.color.withOpacity(0.2)
                : const Color(0xFFFF6B35).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              exData.exerciseType.emoji,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        title: Text(
          exData.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          '${we.sets.length} подходов${isTimeBased ? " • время" : ""}'
              '${_hasAnyConfigured(we) ? " • настроено" : " • не настроено"}',
          style: TextStyle(
            fontSize: 10,
            color: _hasAnyConfigured(we) ? const Color(0xFF4CAF50) : Colors.grey,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isTimeBased
                        ? '⏱️ Это упражнение на время. Настройте длительность и интенсивность.'
                        : '🏋️ Настройте вес и повторения для каждого подхода.',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ),
                ...we.sets.asMap().entries.map((setEntry) {
                  final setIndex = setEntry.key;
                  final set = setEntry.value;
                  return _buildSetConfigRow(
                    isDark, exIndex, setIndex, set, isTimeBased,
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      final day = _days[_editingDayIndex];
                      final exercises = List<WorkoutExercise>.from(day.exercises);
                      final sets = List<ExerciseSet>.from(exercises[exIndex].sets);
                      sets.add(ExerciseSet(
                        setNumber: sets.length + 1,
                        reps: 10,
                        weight: 0,
                      ));
                      exercises[exIndex] = exercises[exIndex].copyWith(sets: sets);
                      _days[_editingDayIndex] = day.copyWith(exercises: exercises);
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Добавить подход', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetConfigRow(
      bool isDark,
      int exIndex,
      int setIndex,
      ExerciseSet set,
      bool isTimeBased,
      ) {
    final day = _days[_editingDayIndex];
    final we = day.exercises[exIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: set.isWarmup
            ? Border.all(color: Colors.orange.withOpacity(0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Подход ${setIndex + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              if (set.isWarmup) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'разм.',
                    style: TextStyle(fontSize: 7, color: Colors.orange),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    final d = _days[_editingDayIndex];
                    final exs = List<WorkoutExercise>.from(d.exercises);
                    final sets = List<ExerciseSet>.from(exs[exIndex].sets);
                    sets[setIndex] = ExerciseSet(
                      setNumber: set.setNumber,
                      reps: set.reps,
                      weight: set.weight,
                      isWarmup: !set.isWarmup,
                    );
                    exs[exIndex] = exs[exIndex].copyWith(sets: sets);
                    _days[_editingDayIndex] = d.copyWith(exercises: exs);
                  });
                },
                child: Icon(
                  Icons.whatshot,
                  size: 16,
                  color: set.isWarmup ? Colors.orange : Colors.grey,
                ),
              ),
              if (we.sets.length > 1) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      final d = _days[_editingDayIndex];
                      final exs = List<WorkoutExercise>.from(d.exercises);
                      final sets = List<ExerciseSet>.from(exs[exIndex].sets);
                      sets.removeAt(setIndex);
                      for (int i = 0; i < sets.length; i++) {
                        sets[i] = ExerciseSet(
                          setNumber: i + 1,
                          reps: sets[i].reps,
                          weight: sets[i].weight,
                          isWarmup: sets[i].isWarmup,
                        );
                      }
                      exs[exIndex] = exs[exIndex].copyWith(sets: sets);
                      _days[_editingDayIndex] = d.copyWith(exercises: exs);
                    });
                  },
                  child: const Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (isTimeBased) ...[
            Row(
              children: [
                const Text('⏱️', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _getDuration(set).toDouble(),
                    min: 15,
                    max: 300,
                    divisions: 19,
                    label: _formatSeconds(_getDuration(set)),
                    onChanged: (v) {
                      _updateSet(exIndex, setIndex, duration: v.toInt());
                    },
                  ),
                ),
                Text(
                  _formatSeconds(_getDuration(set)),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Row(
              children: [
                const Text('💪', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _getIntensity(set).toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '${_getIntensity(set)}',
                    onChanged: (v) {
                      _updateSet(exIndex, setIndex, intensity: v.toInt());
                    },
                  ),
                ),
                Text(
                  '${_getIntensity(set)}/10',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Повторений',
                      labelStyle: const TextStyle(fontSize: 9, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: set.reps > 0 ? '${set.reps}' : '',
                    ),
                    onChanged: (v) {
                      _updateSet(exIndex, setIndex, reps: int.tryParse(v) ?? 0);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Вес (кг)',
                      labelStyle: const TextStyle(fontSize: 9, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: set.weight > 0 ? '${set.weight}' : '',
                    ),
                    onChanged: (v) {
                      _updateSet(exIndex, setIndex, weight: double.tryParse(v) ?? 0);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _updateSet(
      int exIndex,
      int setIndex, {
        int? reps,
        double? weight,
        int? duration,
        int? intensity,
      }) {
    setState(() {
      final day = _days[_editingDayIndex];
      final exercises = List<WorkoutExercise>.from(day.exercises);
      final sets = List<ExerciseSet>.from(exercises[exIndex].sets);
      final oldSet = sets[setIndex];
      if (duration != null) {
        sets[setIndex] = ExerciseSet(
          setNumber: oldSet.setNumber,
          reps: duration,
          weight: (intensity ?? 5).toDouble(),
          isWarmup: oldSet.isWarmup,
        );
      } else {
        sets[setIndex] = ExerciseSet(
          setNumber: oldSet.setNumber,
          reps: reps ?? oldSet.reps,
          weight: weight ?? oldSet.weight,
          isWarmup: oldSet.isWarmup,
        );
      }
      exercises[exIndex] = exercises[exIndex].copyWith(sets: sets);
      _days[_editingDayIndex] = day.copyWith(exercises: exercises);
    });
  }

  int _getDuration(ExerciseSet set) => set.reps > 0 ? set.reps : 60;
  int _getIntensity(ExerciseSet set) => set.weight > 0 ? set.weight.toInt() : 5;

  bool _hasAnyConfigured(WorkoutExercise we) {
    return we.sets.any((s) => s.reps > 0 || s.weight > 0);
  }

  String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}м${s}с' : '${s}с';
  }

  // ==================== СОХРАНЕНИЕ ====================

  Future<void> _saveProgram(BuildContext context) async {
    final provider = context.read<FitnessProvider>();
    final nameController = TextEditingController(
      text: widget.existingProgram?.name ?? '',
    );

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Название программы'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Введите название',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    // 🔥 ВАЖНО: Создаём новые WorkoutExercise с уникальными ID
    final daysData = _days.map((d) {
      final exercises = d.exercises.map((e) {
        return WorkoutExercise(
          id: 'ex_${DateTime.now().microsecondsSinceEpoch}_${e.order}',
          exerciseId: e.exerciseId,
          order: e.order,
          sets: e.sets.map((s) => ExerciseSet(
            setNumber: s.setNumber,
            reps: s.reps,
            weight: s.weight,
            isWarmup: s.isWarmup,
            status: SetStatus.pending,
          )).toList(),
          groupType: e.groupType,
          restBetweenSeconds: e.restBetweenSeconds,
          notes: e.notes,
        );
      }).toList();

      return {
        'dayNumber': d.dayNumber,
        'isRestDay': d.isRestDay,
        'notes': d.notes,
        'exercises': exercises,
      };
    }).toList();

    debugPrint('📋 Сохранение программы: $name');
    debugPrint('📋 Дней: ${daysData.length}');
    for (final dd in daysData) {
      final exList = dd['exercises'] as List;
      debugPrint('   День ${dd['dayNumber']}: ${exList.length} упражнений');
    }

    if (widget.existingProgram != null) {
      final updated = widget.existingProgram!.copyWith(
        name: name,
        type: _programType,
        days: _days,
      );
      await provider.updateProgram(updated);
    } else {
      await provider.addFullProgram(
        name: name,
        type: _programType,
        daysData: daysData,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Программа "$name" сохранена'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ====================

class _ExerciseSearchSheet extends StatefulWidget {
  final bool isDark;
  final Function(Exercise) onAdd;
  final Function(Exercise) onRemove;
  final List<String> addedIds;

  const _ExerciseSearchSheet({
    required this.isDark,
    required this.onAdd,
    required this.onRemove,
    required this.addedIds,
  });

  @override
  State<_ExerciseSearchSheet> createState() => _ExerciseSearchSheetState();
}

class _ExerciseSearchSheetState extends State<_ExerciseSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FitnessProvider>();
    final exercises = _query.isEmpty
        ? provider.exercises
        : provider.searchExercises(_query);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Поиск упражнений...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: widget.isDark
                  ? const Color(0xFF0F1115)
                  : const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final ex = exercises[index];
                final isAdded = widget.addedIds.contains(ex.id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ex.muscleGroups.isNotEmpty
                        ? ex.muscleGroups.first.color.withOpacity(0.2)
                        : Colors.grey,
                    child: Text(ex.exerciseType.emoji),
                  ),
                  title: Text(ex.name, style: const TextStyle(fontSize: 13)),
                  trailing: isAdded
                      ? IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => widget.onRemove(ex),
                  )
                      : IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFFFF6B35)),
                    onPressed: () => widget.onAdd(ex),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseListSheet extends StatelessWidget {
  final bool isDark;
  final Function(Exercise) onAdd;
  final Function(Exercise) onRemove;
  final List<String> addedIds;
  final MuscleGroup? filterMuscle;

  const _ExerciseListSheet({
    required this.isDark,
    required this.onAdd,
    required this.onRemove,
    required this.addedIds,
    this.filterMuscle,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FitnessProvider>();
    var exercises = provider.exercises.toList();
    if (filterMuscle != null) {
      exercises = exercises
          .where((e) => e.muscleGroups.contains(filterMuscle))
          .toList();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          if (filterMuscle != null)
            Text(
              '${filterMuscle!.emoji} ${filterMuscle!.displayName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final ex = exercises[index];
                final isAdded = addedIds.contains(ex.id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ex.muscleGroups.isNotEmpty
                        ? ex.muscleGroups.first.color.withOpacity(0.2)
                        : Colors.grey,
                    child: Text(ex.exerciseType.emoji),
                  ),
                  title: Text(ex.name, style: const TextStyle(fontSize: 13)),
                  trailing: isAdded
                      ? IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => onRemove(ex),
                  )
                      : IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFFFF6B35)),
                    onPressed: () => onAdd(ex),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}