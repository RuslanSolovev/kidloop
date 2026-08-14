import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';
import 'exercise_library_screen.dart';
import 'program_builder_screen.dart';
import 'program_view_screen.dart';
import 'workout_execution_screen.dart';
import 'workout_log_screen.dart';
import 'progress_screen.dart';
import 'photo_comparison_screen.dart';
import 'wellbeing_screen.dart';
import 'active_program_screen.dart';
import 'completed_programs_screen.dart';

class FitnessDashboard extends StatefulWidget {
  final bool isDark;

  const FitnessDashboard({super.key, this.isDark = false});

  @override
  State<FitnessDashboard> createState() => _FitnessDashboardState();
}

class _FitnessDashboardState extends State<FitnessDashboard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final stats = provider.getStats();
    final profile = provider.profile;
    final activeSession = provider.activeSession;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Верхняя панель с аватаром
            SliverToBoxAdapter(child: _buildHeroHeader(isDark, profile, stats)),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Баннер активной программы
            if (activeSession != null)
              SliverToBoxAdapter(
                child: _buildActiveProgramBanner(isDark, provider, activeSession),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // 🔥 НОВОЕ: Трекер недели (7 дней)
            SliverToBoxAdapter(child: _buildWeekTracker(isDark, provider)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Быстрые действия — сетка 2x2
            SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Быстрый доступ')),
            SliverToBoxAdapter(child: _buildQuickActionsGrid(isDark, provider, stats)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Ваши программы
            SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Ваши программы', onTap: () => _showProgramsList(context, isDark, provider))),
            SliverToBoxAdapter(child: _buildProgramsRow(isDark, provider)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Статистика прогресса
            SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Ваш прогресс', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgressScreen(isDark: isDark))));
            })),
            SliverToBoxAdapter(child: _buildProgressCards(isDark, stats)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Шаблоны
            if (provider.templates.isNotEmpty) ...[
              SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Готовые шаблоны')),
              SliverToBoxAdapter(child: _buildTemplatesGrid(isDark, provider)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // Ещё
            SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Ещё')),
            SliverToBoxAdapter(child: _buildExtraGrid(isDark, provider)),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  // ==================== HERO HEADER ====================

  Widget _buildHeroHeader(bool isDark, UserFitnessProfile? profile, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1D24), const Color(0xFF0F1115)]
              : [const Color(0xFFFF6B35), const Color(0xFFFF3D00)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Аватар
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFFFF6B35), const Color(0xFFFF3D00)]
                        : [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (profile?.name ?? 'А')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Привет, ${profile?.name ?? 'Атлет'}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Готов к тренировке? 💪',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Вес
              if (profile?.currentWeight != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${profile!.currentWeight!.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'кг',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Мини-статы в шапке
          Row(
            children: [
              _buildHeaderStat(
                '🔥',
                '${stats['currentStreak'] ?? 0}',
                'дней стрик',
                isDark,
              ),
              const SizedBox(width: 10),
              _buildHeaderStat(
                '💪',
                '${stats['workoutsThisWeek'] ?? 0}',
                'на неделе',
                isDark,
              ),
              const SizedBox(width: 10),
              _buildHeaderStat(
                '🏋️',
                '${stats['totalWorkouts'] ?? 0}',
                'всего',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String emoji, String value, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.white.withOpacity(0.8),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIVE PROGRAM BANNER ====================

  Widget _buildActiveProgramBanner(bool isDark, FitnessProvider provider, ProgramSession session) {
    final program = provider.programs.firstWhere(
          (p) => p.id == session.programId,
      orElse: () => WorkoutProgram(id: '', name: 'Неизвестная'),
    );

    final progress = session.progressPercent;
    final completedDays = session.daySessions.where((d) => d.status == DaySessionStatus.completed).length;
    final totalDays = session.daySessions.length;
    final currentDayIndex = session.currentDayIndex;
    final currentDay = currentDayIndex < program.days.length ? program.days[currentDayIndex] : null;
    final isRestDay = currentDay?.isRestDay ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: ActiveProgramScreen(program: program, isDark: isDark),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6B35), Color(0xFFFF3D00), Color(0xFFE91E63)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔥', style: TextStyle(fontSize: 11)),
                        SizedBox(width: 4),
                        Text(
                          'АКТИВНАЯ ПРОГРАММА',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (session.streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⚡ ${session.streak} ${_getDaysWord(session.streak)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                program.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                isRestDay
                    ? 'Сегодня: день отдыха 😴'
                    : 'День ${currentDayIndex + 1} из $totalDays • ${currentDay?.exercises.length ?? 0} упражнений',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completedDays / $totalDays дней',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ✅ СТАЛО (без const перед Icon):
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(  // ← УБРАН const!
                      isRestDay ? Icons.arrow_forward_rounded : Icons.play_arrow_rounded,
                      color: const Color(0xFFFF6B35),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRestDay ? 'ПЕРЕЙТИ К ПРОГРАММЕ' : 'ПРОДОЛЖИТЬ ТРЕНИРОВКУ',
                      style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 🔥 WEEK TRACKER (7 дней) ====================

  Widget _buildWeekTracker(bool isDark, FitnessProvider provider) {
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A9BFF), Color(0xFF00C7BE)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Последние 7 дней',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Нажмите на день для подробностей',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: WorkoutLogScreen(isDark: isDark),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9BFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Всё →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A9BFF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Сетка 7 дней
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: last7Days.asMap().entries.map((entry) {
                final i = entry.key;
                final date = entry.value;
                final isToday = _isSameDay(date, now);
                final logs = provider.getLogsForDate(date);
                final hasWorkout = logs.isNotEmpty;
                final completedWorkouts = logs.where((l) => l.status == WorkoutDayStatus.completed).length;
                final skippedWorkouts = logs.where((l) => l.status == WorkoutDayStatus.skipped).length;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showDayDetails(context, date, logs, isDark, provider);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Text(
                            dayNames[date.weekday - 1],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? const Color(0xFFFF6B35)
                                  : (isDark ? Colors.white38 : Colors.grey.shade500),
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getDayColor(hasWorkout, completedWorkouts, skippedWorkouts, isToday, isDark),
                              borderRadius: BorderRadius.circular(14),
                              border: isToday
                                  ? Border.all(color: const Color(0xFFFF6B35), width: 2)
                                  : null,
                              boxShadow: hasWorkout
                                  ? [
                                BoxShadow(
                                  color: _getDayColor(hasWorkout, completedWorkouts, skippedWorkouts, isToday, isDark)
                                      .withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                                  : null,
                            ),
                            child: Center(
                              child: _getDayIcon(hasWorkout, completedWorkouts, skippedWorkouts),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                              color: isToday
                                  ? const Color(0xFFFF6B35)
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          if (hasWorkout)
                            Text(
                              '$completedWorkouts',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4CAF50),
                              ),
                            )
                          else
                            const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Итоговая статистика за неделю
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWeekStat(
                    '✅',
                    '${last7Days.fold<int>(0, (sum, d) => sum + provider.getLogsForDate(d).where((l) => l.status == WorkoutDayStatus.completed).length)}',
                    'тренировок',
                    const Color(0xFF4CAF50),
                    isDark,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                  ),
                  _buildWeekStat(
                    '🏋️',
                    _formatVolume(last7Days.fold<double>(0, (sum, d) {
                      final logs = provider.getLogsForDate(d);
                      return sum + logs.fold<double>(0, (s, l) => s + (l.totalVolume ?? 0));
                    })),
                    'кг тоннаж',
                    const Color(0xFFFF6B35),
                    isDark,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                  ),
                  _buildWeekStat(
                    '⚡',
                    '${last7Days.where((d) {
                      return provider.getLogsForDate(d).any((l) => l.status == WorkoutDayStatus.completed);
                    }).length}/7',
                    'активных',
                    const Color(0xFF4A9BFF),
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekStat(String emoji, String value, String label, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Color _getDayColor(bool hasWorkout, int completed, int skipped, bool isToday, bool isDark) {
    if (!hasWorkout) {
      return isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100;
    }
    if (completed > 0) return const Color(0xFF4CAF50);
    if (skipped > 0) return const Color(0xFFF44336);
    return isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100;
  }

  Widget _getDayIcon(bool hasWorkout, int completed, int skipped) {
    if (!hasWorkout) {
      return Icon(
        Icons.remove_rounded,
        size: 20,
        color: Colors.grey.shade400,
      );
    }
    if (completed > 0) {
      return const Icon(Icons.check_rounded, color: Colors.white, size: 24);
    }
    if (skipped > 0) {
      return const Icon(Icons.close_rounded, color: Colors.white, size: 22);
    }
    return const Icon(Icons.remove_rounded, color: Colors.grey, size: 20);
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatVolume(double volume) {
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}k';
    }
    return volume.toStringAsFixed(0);
  }

  // ==================== ДИАЛОГ ДЕТАЛЕЙ ДНЯ ====================

  void _showDayDetails(BuildContext context, DateTime date, List<WorkoutLog> logs, bool isDark, FitnessProvider provider) {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('На ${_formatFullDate(date)} не было тренировок'),
          backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatFullDate(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${logs.length} ${_getWorkoutsWord(logs.length)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _buildDayLogCard(isDark, log, provider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayLogCard(bool isDark, WorkoutLog log, FitnessProvider provider) {
    final isCompleted = log.status == WorkoutDayStatus.completed;
    final isSkipped = log.status == WorkoutDayStatus.skipped;

    final totalVolume = log.totalVolume ?? 0;
    final avgRpe = log.avgRpe;
    final duration = log.duration;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : isSkipped
              ? const Color(0xFFF44336).withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF4CAF50).withOpacity(0.2)
                      : isSkipped
                      ? const Color(0xFFF44336).withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    isCompleted
                        ? Icons.check_rounded
                        : isSkipped
                        ? Icons.close_rounded
                        : Icons.schedule_rounded,
                    color: isCompleted
                        ? const Color(0xFF4CAF50)
                        : isSkipped
                        ? const Color(0xFFF44336)
                        : Colors.grey,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted ? 'Тренировка выполнена' : isSkipped ? 'Пропущена' : 'Не завершена',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (log.programId != null)
                      Text(
                        'День ${log.dayNumber ?? "?"} • ${log.exercisesLog.length} упр.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF4CAF50).withOpacity(0.15)
                      : isSkipped
                      ? const Color(0xFFF44336).withOpacity(0.15)
                      : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCompleted ? '✅' : isSkipped ? '❌' : '⏳',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLogStat('🏋️', '${totalVolume.toStringAsFixed(0)}', 'кг', const Color(0xFFFF6B35), isDark),
                  Container(width: 1, height: 24, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                  _buildLogStat('💪', '${log.exercisesLog.length}', 'упр.', const Color(0xFF4A9BFF), isDark),
                  Container(width: 1, height: 24, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                  _buildLogStat(
                    '⏱️',
                    duration != null ? '${duration.inMinutes}' : '—',
                    'мин',
                    const Color(0xFF00C7BE),
                    isDark,
                  ),
                  if (avgRpe != null) ...[
                    Container(width: 1, height: 24, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                    _buildLogStat('📊', avgRpe.toStringAsFixed(1), 'RPE', const Color(0xFFFFCC00), isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Упражнения
            ...log.exercisesLog.take(3).map((ex) {
              final exerciseData = provider.exercises.firstWhere(
                    (e) => e.id == ex.exerciseId,
                orElse: () => Exercise(id: '', name: 'Упражнение'),
              );
              final completedSets = ex.sets.where((s) => s.status == SetStatus.completed && !s.isWarmup).toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: exerciseData.muscleGroups.isNotEmpty
                            ? exerciseData.muscleGroups.first.color.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(exerciseData.exerciseType.emoji, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exerciseData.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${completedSets.length} подх.',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (log.exercisesLog.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${log.exercisesLog.length - 3} ещё...',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (log.comment != null && log.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.comment!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (log.hasMoodData) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF9C27B0).withOpacity(0.1),
                    const Color(0xFF673AB7).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (log.moodEnergy != null)
                    _buildMoodStat('⚡', '${log.moodEnergy}', 'энергия'),
                  if (log.moodSleep != null)
                    _buildMoodStat('😴', '${log.moodSleep}', 'сон'),
                  if (log.moodMotivation != null)
                    _buildMoodStat('🎯', '${log.moodMotivation}', 'мотив.'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodStat(String emoji, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLogStat(String emoji, String value, String label, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // ==================== SECTION HEADER ====================

  Widget _buildSectionHeader(bool isDark, String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Все →',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== QUICK ACTIONS GRID ====================

  Widget _buildQuickActionsGrid(bool isDark, FitnessProvider provider, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _buildQuickActionCard(
            isDark,
            icon: Icons.play_arrow_rounded,
            title: 'Быстрый старт',
            subtitle: 'Свободная тренировка',
            gradient: const [Color(0xFFFF6B35), Color(0xFFFF3D00)],
            onTap: () => _quickStartWorkout(context, isDark, provider),
          ),
          _buildQuickActionCard(
            isDark,
            icon: Icons.fitness_center_rounded,
            title: 'Упражнения',
            subtitle: '${stats['totalExercises']} в базе',
            gradient: const [Color(0xFF00C7BE), Color(0xFF009688)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ExerciseLibraryScreen(isDark: isDark))),
            ),
          ),
          _buildQuickActionCard(
            isDark,
            icon: Icons.book_rounded,
            title: 'Журнал',
            subtitle: '${stats['totalWorkouts']} записей',
            gradient: const [Color(0xFF4A9BFF), Color(0xFF2962FF)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: WorkoutLogScreen(isDark: isDark))),
            ),
          ),
          _buildQuickActionCard(
            isDark,
            icon: Icons.add_circle_rounded,
            title: 'Новая программа',
            subtitle: 'Создать свою',
            gradient: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
      bool isDark, {
        required IconData icon,
        required String title,
        required String subtitle,
        required List<Color> gradient,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PROGRAMS ROW ====================

  Widget _buildProgramsRow(bool isDark, FitnessProvider provider) {
    if (provider.programs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark))));
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A1D24), const Color(0xFF0F1115)]
                    : [Colors.white, const Color(0xFFF5F7FA)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Создать программу',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Создайте свою первую программу тренировок',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: provider.programs.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == provider.programs.length) {
            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark))));
              },
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_rounded, color: Color(0xFFFF6B35), size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Создать',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          }

          final program = provider.programs[index];
          final stats = _getProgramStats(program);
          final isActive = provider.activeSession?.programId == program.id;

          return GestureDetector(
            onTap: () {
              if (isActive) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: provider,
                      child: ActiveProgramScreen(program: program, isDark: isDark),
                    ),
                  ),
                );
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramViewScreen(program: program, isDark: isDark))));
              }
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showProgramOptions(context, isDark, program, provider);
            },
            child: Container(
              width: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B35), Color(0xFFFF3D00), Color(0xFFE91E63)],
                )
                    : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1A1D24), const Color(0xFF0F1115)]
                      : [Colors.white, const Color(0xFFF5F7FA)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: isActive
                    ? Border.all(color: Colors.white.withOpacity(0.3), width: 2)
                    : Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
                boxShadow: isActive
                    ? [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withOpacity(0.25)
                              : const Color(0xFFFF6B35).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isActive ? Icons.local_fire_department_rounded : Icons.fitness_center_rounded,
                          color: isActive ? Colors.white : const Color(0xFFFF6B35),
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'АКТИВНАЯ',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            program.type.displayName,
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    program.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (isActive && provider.activeSession != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: provider.activeSession!.progressPercent,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${(provider.activeSession!.progressPercent * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (provider.activeSession!.streak > 0)
                          Text(
                            '🔥${provider.activeSession!.streak}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        _buildProgramChip('${stats['completed']}', const Color(0xFF4CAF50), isActive),
                        const SizedBox(width: 6),
                        _buildProgramChip('${stats['pending']}', const Color(0xFFFFC107), isActive),
                        const SizedBox(width: 6),
                        Text(
                          '${program.days.length} дн.',
                          style: TextStyle(
                            fontSize: 10,
                            color: isActive
                                ? Colors.white.withOpacity(0.9)
                                : (isDark ? Colors.white38 : Colors.grey.shade500),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgramChip(String text, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.25) : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isActive ? Colors.white : color,
        ),
      ),
    );
  }

  Map<String, int> _getProgramStats(WorkoutProgram program) {
    int completed = 0, pending = 0, skipped = 0;
    for (final day in program.days) {
      switch (day.status) {
        case WorkoutDayStatus.completed:
          completed++;
          break;
        case WorkoutDayStatus.pending:
          pending++;
          break;
        case WorkoutDayStatus.skipped:
          skipped++;
          break;
        default:
          break;
      }
    }
    return {'completed': completed, 'pending': pending, 'skipped': skipped};
  }

  // ==================== PROGRESS CARDS ====================

  Widget _buildProgressCards(bool isDark, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildProgressCard(
              isDark,
              '🔥',
              '${stats['currentStreak'] ?? 0}',
              'дней стрик',
              const [Color(0xFFFF6B35), Color(0xFFFF3D00)],
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: context.read<FitnessProvider>(), child: ProgressScreen(isDark: isDark))));
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProgressCard(
              isDark,
              '🏋️',
              '${stats['totalWorkouts'] ?? 0}',
              'тренировок',
              const [Color(0xFF4A9BFF), Color(0xFF2962FF)],
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: context.read<FitnessProvider>(), child: WorkoutLogScreen(isDark: isDark))));
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProgressCard(
              isDark,
              '📊',
              '${stats['workoutsThisWeek'] ?? 0}',
              'за неделю',
              const [Color(0xFF00C7BE), Color(0xFF009688)],
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: context.read<FitnessProvider>(), child: ProgressScreen(isDark: isDark))));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark, String emoji, String value, String label, List<Color> gradient, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TEMPLATES GRID ====================

  Widget _buildTemplatesGrid(bool isDark, FitnessProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        itemCount: provider.templates.length,
        itemBuilder: (context, index) {
          final t = provider.templates[index];
          return GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final program = await provider.createProgramFromTemplate(t.id);
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramViewScreen(program: program, isDark: isDark))));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.download_rounded,
                        size: 16,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      t.description,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  // ==================== EXTRA GRID ====================

  Widget _buildExtraGrid(bool isDark, FitnessProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          _buildExtraCardWidget(
            isDark,
            icon: Icons.photo_camera_rounded,
            title: 'Фотоотчёты',
            subtitle: '${provider.photos.length} фото',
            gradient: const [Color(0xFFFF9500), Color(0xFFFF5722)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: PhotoComparisonScreen(isDark: isDark))),
            ),
          ),
          _buildWellbeingCardWidget(isDark, provider),
          _buildExtraCardWidget(
            isDark,
            icon: Icons.history_rounded,
            title: 'История программ',
            subtitle: '${provider.sessions.where((s) => s.status != ProgramSessionStatus.active).length} завершено',
            gradient: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: CompletedProgramsScreen(isDark: isDark),
                ),
              ),
            ),
          ),
          _buildExtraCardWidget(
            isDark,
            icon: Icons.trending_up_rounded,
            title: 'Детальный прогресс',
            subtitle: 'По упражнениям',
            gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgressScreen(isDark: isDark))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraCardWidget(
      bool isDark, {
        required IconData icon,
        required String title,
        required String subtitle,
        required List<Color> gradient,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWellbeingCardWidget(bool isDark, FitnessProvider provider) {
    final todayWellbeing = provider.getTodayWellbeing();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: WellbeingScreen(isDark: isDark),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34C759), Color(0xFF28A745)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34C759).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.mood_rounded, color: Colors.white, size: 22),
            ),
            const Spacer(),
            Text(
              'Самочувствие',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            if (todayWellbeing != null)
              Row(
                children: [
                  _buildMiniStat('⚡', '${todayWellbeing.energyLevel}'),
                  const SizedBox(width: 6),
                  _buildMiniStat('😴', '${todayWellbeing.sleepQuality}'),
                  const SizedBox(width: 6),
                  _buildMiniStat('🎯', '${todayWellbeing.motivationLevel}'),
                ],
              )
            else
              Text(
                'Записать',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF34C759),
          ),
        ),
      ],
    );
  }

  // ==================== PROGRAMS LIST DIALOG ====================

  void _showProgramsList(BuildContext context, bool isDark, FitnessProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Мои программы',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark))));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: provider.programs.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fitness_center_rounded, size: 60, color: isDark ? Colors.white12 : Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'Нет программ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.grey.shade500),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: provider.programs.length,
                itemBuilder: (context, index) {
                  final program = provider.programs[index];
                  final isActive = provider.activeSession?.programId == program.id;
                  final session = isActive ? provider.activeSession : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16),
                      border: isActive ? Border.all(color: const Color(0xFFFF6B35), width: 2) : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFFF6B35) : const Color(0xFFFF6B35).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isActive ? Icons.local_fire_department_rounded : Icons.fitness_center_rounded,
                          color: isActive ? Colors.white : const Color(0xFFFF6B35),
                        ),
                      ),
                      title: Text(
                        program.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${program.type.displayName} • ${program.days.length} дней',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                          ),
                          if (isActive && session != null) ...[
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: session.progressPercent,
                                backgroundColor: Colors.grey.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                                minHeight: 3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(session.progressPercent * 100).toInt()}% • День ${session.currentDayIndex + 1} • 🔥${session.streak}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFFFF6B35), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                      trailing: isActive
                          ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'АКТИВНАЯ',
                          style: TextStyle(fontSize: 8, color: Color(0xFFFF6B35), fontWeight: FontWeight.w900),
                        ),
                      )
                          : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (isActive) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ActiveProgramScreen(program: program, isDark: isDark))));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramViewScreen(program: program, isDark: isDark))));
                        }
                      },
                      onLongPress: () {
                        Navigator.pop(ctx);
                        _showProgramOptions(context, isDark, program, provider);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PROGRAM OPTIONS ====================

  void _showProgramOptions(BuildContext context, bool isDark, WorkoutProgram program, FitnessProvider provider) {
    final isActive = provider.activeSession?.programId == program.id;
    final hasActiveSession = provider.activeSession != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    program.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '🔥 АКТИВНАЯ',
                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (!isActive && !hasActiveSession)
              _buildMenuItem(
                icon: Icons.play_arrow_rounded,
                iconGradient: const [Color(0xFFFF6B35), Color(0xFFFF3D00)],
                title: 'Начать прохождение',
                subtitle: 'Режим последовательного выполнения',
                onTap: () {
                  Navigator.pop(ctx);
                  _showStartProgramDialog(context, isDark, program, provider);
                },
              ),
            if (isActive)
              _buildMenuItem(
                icon: Icons.play_circle_filled,
                iconColor: const Color(0xFF4CAF50),
                iconBgColor: const Color(0xFF4CAF50).withOpacity(0.15),
                title: 'Продолжить прохождение',
                subtitle: 'День ${provider.activeSession!.currentDayIndex + 1}',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ActiveProgramScreen(program: program, isDark: isDark))));
                },
              ),
            if (isActive)
              _buildMenuItem(
                icon: Icons.pause_circle_outline,
                iconColor: Colors.orange,
                iconBgColor: Colors.orange.withOpacity(0.15),
                title: 'Приостановить',
                onTap: () async {
                  Navigator.pop(ctx);
                  await provider.pauseProgramSession();
                },
              ),
            if (isActive)
              _buildMenuItem(
                icon: Icons.flag_outlined,
                iconColor: Colors.red.shade400,
                iconBgColor: Colors.red.withOpacity(0.1),
                title: 'Бросить программу',
                titleColor: Colors.red,
                subtitle: 'Отказаться от прохождения',
                subtitleColor: Colors.red,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmAbandonProgram(context, isDark, program, provider);
                },
              ),
            _buildMenuItem(
              icon: Icons.edit_rounded,
              iconColor: const Color(0xFFFF6B35),
              iconBgColor: const Color(0xFFFF6B35).withOpacity(0.15),
              title: 'Редактировать',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(existingProgram: program, isDark: isDark))));
              },
            ),
            _buildMenuItem(
              icon: Icons.delete_rounded,
              iconColor: Colors.red.shade400,
              iconBgColor: Colors.red.withOpacity(0.1),
              title: 'Удалить',
              titleColor: Colors.red,
              onTap: () async {
                Navigator.pop(ctx);
                if (isActive) {
                  await provider.abandonProgramSession(provider.activeSession!.id);
                }
                await provider.deleteProgram(program.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    List<Color>? iconGradient,
    Color? iconColor,
    Color? iconBgColor,
    required String title,
    Color? titleColor,
    String? subtitle,
    Color? subtitleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBgColor,
          gradient: iconGradient != null
              ? LinearGradient(colors: iconGradient)
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconGradient != null ? Colors.white : iconColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: TextStyle(fontSize: 11, color: subtitleColor ?? Colors.grey),
      )
          : null,
      onTap: onTap,
    );
  }

  // ==================== START PROGRAM DIALOG ====================

  void _showStartProgramDialog(BuildContext context, bool isDark, WorkoutProgram program, FitnessProvider provider) {
    ProgramDifficulty selectedDifficulty = ProgramDifficulty.standard;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🚀', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Начать "${program.name}"',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${program.days.length} дней • Выберите режим прохождения:',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              _buildDifficultyOption(
                isDark,
                emoji: '🟢',
                title: 'Гибкий',
                description: 'Можно пропускать дни без штрафов',
                isSelected: selectedDifficulty == ProgramDifficulty.flexible,
                onTap: () => setState(() => selectedDifficulty = ProgramDifficulty.flexible),
              ),
              const SizedBox(height: 8),
              _buildDifficultyOption(
                isDark,
                emoji: '🟡',
                title: 'Стандартный',
                description: 'Пропуск сбрасывает серию',
                isSelected: selectedDifficulty == ProgramDifficulty.standard,
                onTap: () => setState(() => selectedDifficulty = ProgramDifficulty.standard),
              ),
              const SizedBox(height: 8),
              _buildDifficultyOption(
                isDark,
                emoji: '🔴',
                title: 'Хардкор',
                description: 'Пропуск сбрасывает всю неделю',
                isSelected: selectedDifficulty == ProgramDifficulty.hardcore,
                onTap: () => setState(() => selectedDifficulty = ProgramDifficulty.hardcore),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await provider.startProgramSession(program.id, difficulty: selectedDifficulty);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: ActiveProgramScreen(program: program, isDark: isDark),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Начать!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(
      bool isDark, {
        required String emoji,
        required String title,
        required String description,
        required bool isSelected,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF6B35).withOpacity(0.15)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: const Color(0xFFFF6B35), width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFFF6B35), size: 22),
          ],
        ),
      ),
    );
  }

  // ==================== ABANDON DIALOG ====================

  void _confirmAbandonProgram(BuildContext context, bool isDark, WorkoutProgram program, FitnessProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Бросить программу?'),
          ],
        ),
        content: Text(
          'Весь прогресс по "${program.name}" будет потерян. Вы уверены?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.abandonProgramSession(provider.activeSession!.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Программа "${program.name}" остановлена'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Бросить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== QUICK START WORKOUT ====================

  void _quickStartWorkout(BuildContext context, bool isDark, FitnessProvider provider) {
    final quickDay = WorkoutDay(
      id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
      programId: 'quick',
      dayNumber: 1,
      exercises: [],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Быстрая тренировка',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Выберите упражнения для тренировки',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: provider.exercises.length,
                  itemBuilder: (context, index) {
                    final ex = provider.exercises[index];
                    final isAdded = quickDay.exercises.any((we) => we.exerciseId == ex.id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ex.muscleGroups.isNotEmpty
                            ? ex.muscleGroups.first.color.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        child: Text(ex.exerciseType.emoji),
                      ),
                      title: Text(
                        ex.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      trailing: isAdded
                          ? IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => setSheetState(
                              () => quickDay.exercises.removeWhere((we) => we.exerciseId == ex.id),
                        ),
                      )
                          : IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFFFF6B35)),
                        onPressed: () {
                          setSheetState(() {
                            quickDay.exercises.add(
                              WorkoutExercise(
                                id: 'quick_ex_${quickDay.exercises.length}',
                                exerciseId: ex.id,
                                order: quickDay.exercises.length,
                                sets: [ExerciseSet(setNumber: 1, reps: 10, weight: 0)],
                              ),
                            );
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              if (quickDay.exercises.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: provider,
                              child: WorkoutExecutionScreen(day: quickDay, isDark: isDark),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        'Начать (${quickDay.exercises.length} упр.)',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HELPERS ====================

  String _formatFullDate(DateTime date) {
    const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    const weekdays = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
    return '${weekdays[date.weekday % 7]}, ${date.day} ${months[date.month - 1]}';
  }

  String _getWorkoutsWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'тренировка';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'тренировки';
    return 'тренировок';
  }

  String _getDaysWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'день';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'дня';
    return 'дней';
  }
}