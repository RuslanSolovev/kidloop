// features/fitness/ui/screens/workout_log_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';

class WorkoutLogScreen extends StatefulWidget {
  final bool isDark;
  final bool isCompact;

  const WorkoutLogScreen({
    super.key,
    this.isDark = false,
    this.isCompact = false,
  });

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final logs = _getLogsForMonth(provider);

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          _buildMonthNavigator(isDark),
          _buildCalendarGrid(isDark, logs),
          const Divider(height: 1),
          Expanded(
            child: _selectedDate != null
                ? _buildDayLogs(isDark, provider, _selectedDate!)
                : _buildEmptyState(isDark),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor:
      isDark ? const Color(0xFF1A1D24) : Colors.white,
      elevation: 0,
      title: Text(
        'Журнал тренировок',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(bool isDark) {
    final monthNames = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
            },
            style: IconButton.styleFrom(
              foregroundColor:
              isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          GestureDetector(
            onTap: () => _showMonthPicker(context),
            child: Text(
              '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
            },
            style: IconButton.styleFrom(
              foregroundColor:
              isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(bool isDark, List<WorkoutLog> monthLogs) {
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;

    final Map<int, List<WorkoutLog>> logsByDay = {};
    for (final log in monthLogs) {
      final day = log.date.day;
      logsByDay[day] = [...logsByDay[day] ?? [], log];
    }

    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final today = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == today.year &&
        _selectedMonth.month == today.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: dayNames.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color:
                      isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemCount: firstWeekday - 1 + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox();
              }

              final day = index - (firstWeekday - 2);
              final dayLogs = logsByDay[day] ?? [];
              final isToday = isCurrentMonth && day == today.day;
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == _selectedMonth.year &&
                  _selectedDate!.month == _selectedMonth.month &&
                  _selectedDate!.day == day;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDate = DateTime(
                        _selectedMonth.year, _selectedMonth.month, day);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _getDayColor(
                        isDark, dayLogs, isToday, isSelected),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(
                        color: const Color(0xFFFF6B35), width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: _getTextColor(
                                isDark, dayLogs, isToday, isSelected),
                          ),
                        ),
                      ),
                      if (dayLogs.isNotEmpty)
                        Positioned(
                          bottom: 4,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: dayLogs.take(3).map((log) {
                              return Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 1),
                                decoration: BoxDecoration(
                                  color: log.status.color,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _getDayColor(
      bool isDark, List<WorkoutLog> logs, bool isToday, bool isSelected) {
    if (isSelected) return const Color(0xFFFF6B35).withOpacity(0.3);
    if (isToday) return const Color(0xFFFF6B35).withOpacity(0.1);
    if (logs.isEmpty) return Colors.transparent;

    final hasCompleted =
    logs.any((l) => l.status == WorkoutDayStatus.completed);
    final hasSkipped =
    logs.any((l) => l.status == WorkoutDayStatus.skipped);

    if (hasCompleted && hasSkipped) {
      return Colors.purple.withOpacity(0.2);
    }
    if (hasCompleted) return const Color(0xFF4CAF50).withOpacity(0.2);
    if (hasSkipped) return const Color(0xFFF44336).withOpacity(0.15);

    return isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100;
  }

  Color _getTextColor(
      bool isDark, List<WorkoutLog> logs, bool isToday, bool isSelected) {
    if (isSelected) return Colors.white;
    if (isToday) return const Color(0xFFFF6B35);
    if (logs.isEmpty) return isDark ? Colors.white38 : Colors.grey.shade400;
    return isDark ? Colors.white : Colors.black87;
  }

  Widget _buildDayLogs(
      bool isDark, FitnessProvider provider, DateTime date) {
    final logs = provider.getLogsForDate(date);

    // Загружаем данные шагомера
    final dayKey = 'stats_${date.year}_${date.month}_${date.day}';

    if (logs.isEmpty) {
      return FutureBuilder<Map<String, int>>(
        future: _getDaySteps(dayKey),
        builder: (context, snapshot) {
          final steps = snapshot.data?['steps'] ?? 0;
          if (steps == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 48,
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Нет данных в этот день',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}.${date.month}.${date.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white24 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDaySummary(isDark, 0, 0, 0, 0, steps, 0, 0),
            ],
          );
        },
      );
    }

    final totalVolume = logs.fold(
        0.0, (sum, l) => sum + (l.totalVolume ?? 0));
    final totalExercises =
    logs.fold(0, (sum, l) => sum + l.exercisesLog.length);
    final completedCount = logs
        .where((l) => l.status == WorkoutDayStatus.completed)
        .length;

    return FutureBuilder<Map<String, int>>(
      future: _getDaySteps(dayKey),
      builder: (context, snapshot) {
        final steps = snapshot.data?['steps'] ?? 0;
        final minutes = snapshot.data?['minutes'] ?? 0;
        final distanceKm = (steps * 0.75) / 1000.0;
        final calories = (steps * 0.04).round();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildDaySummary(
                isDark,
                logs.length,
                completedCount,
                totalVolume,
                totalExercises,
                steps,
                distanceKm,
                calories,
              );
            }
            final log = logs[index - 1];
            return _buildLogCard(isDark, log, provider);
          },
        );
      },
    );
  }

  Future<Map<String, int>> _getDaySteps(String dayKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'steps': prefs.getInt(dayKey) ?? 0,
        'minutes': prefs.getInt('${dayKey}_minutes') ?? 0,
      };
    } catch (_) {
      return {'steps': 0, 'minutes': 0};
    }
  }

  Widget _buildDaySummary(
      bool isDark,
      int totalWorkouts,
      int completed,
      double totalVolume,
      int totalExercises,
      int steps,
      double distanceKm,
      int calories,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.15),
            const Color(0xFFFF6B35).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B35).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Color(0xFFFF6B35), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Сводка дня',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDaySummaryItem('👟', '$steps', 'шагов'),
              _buildDaySummaryItem(
                  '📏', '${distanceKm.toStringAsFixed(1)}', 'км'),
              _buildDaySummaryItem('🔥', '$calories', 'ккал'),
            ],
          ),
          if (totalWorkouts > 0) ...[
            const SizedBox(height: 16),
            Divider(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              height: 1,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDaySummaryItem('🏋️', '$totalWorkouts', 'тренировок'),
                _buildDaySummaryItem('✅', '$completed', 'выполнено'),
                _buildDaySummaryItem(
                    '📊', '${totalVolume.toStringAsFixed(0)}', 'кг тоннаж'),
                _buildDaySummaryItem(
                    '💪', '$totalExercises', 'упражнений'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySummaryItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildLogCard(
      bool isDark, WorkoutLog log, FitnessProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: log.status.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(log.status.icon, color: log.status.color, size: 20),
        ),
        title: Text(
          log.status == WorkoutDayStatus.completed
              ? 'Тренировка выполнена'
              : 'Тренировка пропущена',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${log.date.hour}:${log.date.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
            if (log.comment != null && log.comment!.isNotEmpty)
              Text(
                log.comment!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
          ],
        ),
        children: [
          if (log.status == WorkoutDayStatus.completed) ...[
            _buildLogStats(isDark, log),
            const SizedBox(height: 12),

            if (log.hasMoodData) ...[
              _buildMoodSection(isDark, log),
              const SizedBox(height: 12),
            ],

            if (log.hasPhoto) ...[
              _buildWorkoutPhoto(isDark, log),
              const SizedBox(height: 12),
            ],

            if (log.exercisesLog.isNotEmpty) ...[
              Text(
                'Упражнения',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              ...log.exercisesLog.asMap().entries.map((entry) {
                final exercise = entry.value;
                final exerciseData = provider.exercises.firstWhere(
                      (e) => e.id == exercise.exerciseId,
                  orElse: () =>
                      Exercise(id: '', name: 'Упражнение удалено'),
                );
                return _buildLogExerciseTile(
                    isDark, exercise, exerciseData);
              }),
            ],

            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Добавить комментарий...',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0F1115)
                    : const Color(0xFFF5F7FA),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 12),
              maxLines: 2,
              onSubmitted: (value) {
                provider.updateLogComment(log.id, value);
              },
            ),
          ] else ...[
            TextField(
              decoration: InputDecoration(
                hintText: 'Почему пропустили тренировку?',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0F1115)
                    : const Color(0xFFF5F7FA),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 12),
              maxLines: 2,
              onSubmitted: (value) {
                provider.updateLogComment(log.id, value);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodSection(bool isDark, WorkoutLog log) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.1),
            Colors.orange.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mood_rounded,
                  color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Настроение',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (log.moodEnergy != null)
                _buildMoodChip('⚡', 'Энергия', log.moodEnergy!),
              if (log.moodSleep != null)
                _buildMoodChip('😴', 'Сон', log.moodSleep!),
              if (log.moodMotivation != null)
                _buildMoodChip('🎯', 'Мотивация', log.moodMotivation!),
            ],
          ),
          if (log.moodNotes != null && log.moodNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.moodNotes!,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodChip(String emoji, String label, int value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          '$value/10',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  // 🔥 ФОТО С ОТКРЫТИЕМ НА ВЕСЬ ЭКРАН
  Widget _buildWorkoutPhoto(bool isDark, WorkoutLog log) {
    final file = File(log.workoutPhotoPath!);
    return GestureDetector(
      onTap: () {
        if (file.existsSync()) {
          _showFullScreenPhoto(context, file);
        }
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade200,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                color: isDark
                    ? const Color(0xFF0F1115)
                    : Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.grey, size: 48),
                ),
              ),
              // Индикатор нажатия
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenPhoto(BuildContext context, File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogStats(bool isDark, WorkoutLog log) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLogStatItem('⏱️', _formatDuration(log.duration), 'время'),
          _buildLogStatItem('🏋️',
              '${log.totalVolume?.toStringAsFixed(0) ?? 0} кг', 'тоннаж'),
          _buildLogStatItem('📊',
              log.avgRpe != null ? '${log.avgRpe!.toStringAsFixed(1)}' : '--',
              'RPE'),
          _buildLogStatItem(
              '💪', '${log.exercisesLog.length}', 'упр.'),
        ],
      ),
    );
  }

  Widget _buildLogStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildLogExerciseTile(
      bool isDark, WorkoutExercise exercise, Exercise exerciseData) {
    final completedSets = exercise.sets
        .where((s) => s.status == SetStatus.completed)
        .toList();
    final exerciseVolume = completedSets.fold(
        0.0, (sum, s) => sum + s.volume);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                exerciseData.exerciseType.emoji,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  exerciseData.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${completedSets.length} подх.',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                  if (exerciseVolume > 0)
                    Text(
                      '${exerciseVolume.toStringAsFixed(0)} кг',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF6B35),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (completedSets.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: completedSets.map((set) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${set.weight.toStringAsFixed(0)}×${set.reps}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 64,
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Выберите день',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          Text(
            'чтобы посмотреть тренировки',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  List<WorkoutLog> _getLogsForMonth(FitnessProvider provider) {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    return provider.logs
        .where((log) =>
    log.date.isAfter(start.subtract(const Duration(days: 1))) &&
        log.date.isBefore(end.add(const Duration(days: 1))))
        .toList();
  }

  void _showMonthPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выберите месяц'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: YearPicker(
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            selectedDate: _selectedMonth,
            onChanged: (date) {
              setState(() => _selectedMonth = date);
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes;
    if (minutes >= 60) {
      return '${duration.inHours}ч ${minutes % 60}м';
    }
    return '${minutes}м';
  }
}