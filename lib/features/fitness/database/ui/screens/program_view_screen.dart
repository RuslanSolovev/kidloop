// features/fitness/ui/screens/program_view_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';
import 'workout_execution_screen.dart';
import 'program_builder_screen.dart';

class ProgramViewScreen extends StatefulWidget {
  final WorkoutProgram program;
  final bool isDark;

  const ProgramViewScreen({
    super.key,
    required this.program,
    this.isDark = false,
  });

  @override
  State<ProgramViewScreen> createState() => _ProgramViewScreenState();
}

class _ProgramViewScreenState extends State<ProgramViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Определяем текущий день
    if (widget.program.type == ProgramType.weekly) {
      _selectedDayIndex = DateTime.now().weekday - 1;
      if (_selectedDayIndex < 0) _selectedDayIndex = 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();

    // Находим актуальную программу
    WorkoutProgram program;
    try {
      program = provider.programs.firstWhere(
            (p) => p.id == widget.program.id,
      );
    } catch (_) {
      program = widget.program;
    }

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: _buildAppBar(isDark, program, provider),
      body: program.days.isEmpty
          ? _buildEmptyProgram(isDark)
          : Column(
        children: [
          _buildProgramHeader(isDark, program),
          // Переключатель вкладок
          Container(
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
              isDark ? const Color(0xFF1A1D24) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: isDark
                  ? Colors.white38
                  : Colors.grey.shade500,
              indicator: BoxDecoration(
                color: const Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.all(3),
              tabs: const [
                Tab(text: 'День'),
                Tab(text: 'Обзор'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDayView(isDark, program),
                _buildOverviewView(isDark, program),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, WorkoutProgram program,
      FitnessProvider provider) {
    return AppBar(
      backgroundColor:
      isDark ? const Color(0xFF1A1D24) : Colors.white,
      elevation: 0,
      title: Text(
        program.name,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded,
              color: Color(0xFFFF6B35)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChangeNotifierProvider.value(
                      value: provider,
                      child: ProgramBuilderScreen(
                        existingProgram: program,
                        isDark: isDark,
                      ),
                    ),
              ),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.delete_rounded,
              color: Colors.red.shade300),
          onPressed: () =>
              _confirmDelete(context, isDark, program, provider),
        ),
      ],
    );
  }

  Widget _buildProgramHeader(bool isDark, WorkoutProgram program) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  program.type.displayName,
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${program.days.length} ${_getDaysWord(program.days.length)}',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white54
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (program.description != null &&
              program.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              program.description!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== ВКЛАДКА "ДЕНЬ" ====================

  Widget _buildDayView(bool isDark, WorkoutProgram program) {
    if (program.days.isEmpty) {
      return _buildEmptyProgram(isDark);
    }

    // Выбор дня
    final day = program.days[_selectedDayIndex.clamp(
        0, program.days.length - 1)];

    return Column(
      children: [
        // Горизонтальный выбор дня
        _buildDaySelector(isDark, program),
        const SizedBox(height: 8),
        // Содержимое дня
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDayCard(isDark, day),
                if (!day.isRestDay && day.exercises.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Упражнения',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...day.exercises.asMap().entries.map((entry) {
                    return _buildExerciseCard(
                        isDark, entry.value, entry.key);
                  }),
                ],
                if (day.notes != null && day.notes!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildNotesCard(isDark, day.notes!),
                ],
              ],
            ),
          ),
        ),
        // Кнопка начала тренировки
        if (!day.isRestDay && day.exercises.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _startWorkout(context, day),
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text(
                  'НАЧАТЬ ТРЕНИРОВКУ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDaySelector(bool isDark, WorkoutProgram program) {
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final today = DateTime.now().weekday - 1;

    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: program.days.length,
        itemBuilder: (context, index) {
          final day = program.days[index];
          final isSelected = index == _selectedDayIndex;
          final isToday = index == today && program.type == ProgramType.weekly;

          final label = program.type == ProgramType.weekly
              ? dayNames[index % 7]
              : 'Д${index + 1}';

          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6B35).withOpacity(0.2)
                    : (isDark
                    ? const Color(0xFF1A1D24)
                    : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: isSelected
                    ? Border.all(
                    color: const Color(0xFFFF6B35), width: 2)
                    : isToday
                    ? Border.all(
                    color: Colors.orange.withOpacity(0.5),
                    width: 1)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFFFF6B35)
                          : (isDark
                          ? Colors.white54
                          : Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (day.isRestDay)
                    const Icon(Icons.bedtime_rounded,
                        size: 16, color: Colors.grey)
                  else
                    Text(
                      '${day.exercises.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : Colors.black87,
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

  Widget _buildDayCard(bool isDark, WorkoutDay day) {
    final statusColor = day.status.color;
    final statusIcon = day.status.icon;
    final statusText = day.status.displayName;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'День ${day.dayNumber}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  day.isRestDay ? 'День отдыха' : statusText,
                  style: TextStyle(
                    fontSize: 13,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!day.isRestDay && day.exercises.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${day.exercises.length} упр.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
      bool isDark, WorkoutExercise exercise, int index) {
    final provider = context.read<FitnessProvider>();
    final exerciseData = provider.exercises.firstWhere(
          (e) => e.id == exercise.exerciseId,
      orElse: () => Exercise(id: '', name: 'Упражнение удалено'),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Номер упражнения
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Иконка типа
              Text(
                exerciseData.exerciseType.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseData.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (exerciseData.muscleGroups.isNotEmpty)
                      Text(
                        exerciseData.muscleGroups
                            .map((m) => m.displayName)
                            .join(' • '),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors.white38
                              : Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Подходы
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: exercise.sets.map((set) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: set.isWarmup
                      ? Colors.orange.withOpacity(0.1)
                      : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(10),
                  border: set.isWarmup
                      ? Border.all(
                      color: Colors.orange.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${set.setNumber}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${set.reps} × ${set.weight.toStringAsFixed(0)}кг',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (set.isWarmup) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '🔥',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(bool isDark, String notes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                'Заметки',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ВКЛАДКА "ОБЗОР" ====================

  Widget _buildOverviewView(bool isDark, WorkoutProgram program) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Сетка дней
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: program.type == ProgramType.monthly ? 7 : 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.9,
            ),
            itemCount: program.days.length,
            itemBuilder: (context, index) {
              final day = program.days[index];
              return _buildOverviewDayCard(isDark, day, index);
            },
          ),
          const SizedBox(height: 20),
          // Сводка
          _buildOverviewSummary(isDark, program),
        ],
      ),
    );
  }

  Widget _buildOverviewDayCard(
      bool isDark, WorkoutDay day, int index) {
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final today = DateTime.now().weekday - 1;
    final isToday = index == today && widget.program.type == ProgramType.weekly;
    final label = widget.program.type == ProgramType.weekly
        ? dayNames[index % 7]
        : '${index + 1}';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDayIndex = index;
          _tabController.animateTo(0);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: day.isRestDay
              ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
              : day.status == WorkoutDayStatus.completed
              ? const Color(0xFF4CAF50).withOpacity(0.2)
              : day.status == WorkoutDayStatus.skipped
              ? const Color(0xFFF44336).withOpacity(0.15)
              : (isDark
              ? const Color(0xFF1A1D24)
              : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: isToday
              ? Border.all(color: Colors.orange, width: 2)
              : Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            if (day.isRestDay)
              const Icon(Icons.bedtime_rounded,
                  size: 20, color: Colors.grey)
            else if (day.exercises.isEmpty)
              Text(
                '—',
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              )
            else
              Column(
                children: [
                  Text(
                    '${day.exercises.length}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'упр.',
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark
                          ? Colors.white38
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSummary(bool isDark, WorkoutProgram program) {
    int totalExercises = 0;
    int totalSets = 0;
    int restDays = 0;

    for (final day in program.days) {
      if (day.isRestDay) {
        restDays++;
      } else {
        totalExercises += day.exercises.length;
        for (final ex in day.exercises) {
          totalSets += ex.sets.length;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.1),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF6B35).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                  '📅', '${program.days.length}', 'дней'),
              _buildSummaryItem('💪', '$totalExercises', 'упражнений'),
              _buildSummaryItem('📊', '$totalSets', 'подходов'),
              _buildSummaryItem('😴', '$restDays', 'отдыха'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildEmptyProgram(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 64,
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Программа пуста',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте упражнения через редактирование',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  void _startWorkout(BuildContext context, WorkoutDay day) {
    final provider = context.read<FitnessProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: WorkoutExecutionScreen(
            day: day,
            isDark: widget.isDark,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, bool isDark,
      WorkoutProgram program, FitnessProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить программу?'),
        content: Text('"${program.name}" будет удалена безвозвратно'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteProgram(program.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Удалить',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getDaysWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'день';
    if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100))
      return 'дня';
    return 'дней';
  }
}