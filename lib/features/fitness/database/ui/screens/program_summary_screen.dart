import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kidloop/features/fitness/models/enums.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/fitness_provider.dart';

class ProgramSummaryScreen extends StatefulWidget {
  final ProgramSession session;
  final WorkoutProgram program;
  final bool isDark;

  const ProgramSummaryScreen({
    super.key,
    required this.session,
    required this.program,
    required this.isDark,
  });

  @override
  State<ProgramSummaryScreen> createState() => _ProgramSummaryScreenState();
}

class _ProgramSummaryScreenState extends State<ProgramSummaryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final session = widget.session;
    final program = widget.program;
    final summary = session.summaryData;

    final completedDays = (summary['completedDays'] as num?)?.toInt() ??
        session.daySessions.where((d) => d.status == DaySessionStatus.completed).length;
    final skippedDays = (summary['skippedDays'] as num?)?.toInt() ??
        session.daySessions.where((d) => d.status == DaySessionStatus.skipped).length;
    final totalDays = (summary['totalDays'] as num?)?.toInt() ?? program.days.length;
    final durationDays = (summary['durationDays'] as num?)?.toInt() ?? session.durationDays;
    final exerciseStats = (summary['exerciseStats'] as Map<String, dynamic>?) ?? {};

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      body: CustomScrollView(
        slivers: [
          _buildHeroTrophy(isDark, program, session, durationDays),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildMainStats(isDark, session, completedDays, totalDays, durationDays),
                const SizedBox(height: 16),
                _buildCompletionChart(isDark, completedDays, skippedDays, totalDays),
                const SizedBox(height: 16),
                if (exerciseStats.isNotEmpty) ...[
                  _buildExerciseProgress(isDark, exerciseStats),
                  const SizedBox(height: 16),
                ],
                _buildPerformanceHighlights(isDark, session),
                const SizedBox(height: 16),
                _buildDailyTimeline(isDark, session, program),
                const SizedBox(height: 24),
                _buildActionButtons(isDark, session),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HERO С ТРОФЕЕМ ====================

  Widget _buildHeroTrophy(bool isDark, WorkoutProgram program, ProgramSession session, int durationDays) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD700), Color(0xFFFF6B35), Color(0xFFFF3D00)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Кнопка назад
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // Анимированный трофей
              AnimatedBuilder(
                animation: _confettiController,
                builder: (ctx, child) {
                  final scale = Curves.elasticOut.transform(
                    _confettiController.value.clamp(0.0, 1.0),
                  );
                  return Transform.scale(
                    scale: 0.5 + scale * 0.5,
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Лучи
                    ...List.generate(8, (i) {
                      return Transform.rotate(
                        angle: (i * pi / 4),
                        child: Container(
                          width: 2,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    // Круглое свечение
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Сам трофей
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🏆', style: TextStyle(fontSize: 64)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'ПРОГРАММА ЗАВЕРШЕНА!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  program.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatDate(session.startDate)} — ${_formatDate(session.endDate ?? DateTime.now())}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              // Сложность
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getDifficultyLabel(session.difficulty),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getDifficultyLabel(ProgramDifficulty d) {
    switch (d) {
      case ProgramDifficulty.flexible: return '🟢 Гибкий режим';
      case ProgramDifficulty.standard: return '🟡 Стандартный режим';
      case ProgramDifficulty.hardcore: return '🔴 Хардкор режим';
    }
  }

  // ==================== ОСНОВНАЯ СТАТИСТИКА ====================

  Widget _buildMainStats(bool isDark, ProgramSession session, int completed, int total, int duration) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: const Color(0xFFFF6B35), size: 22),
              const SizedBox(width: 8),
              Text(
                'Итоги программы',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMainStat(
                isDark,
                emoji: '📅',
                value: '$duration',
                label: 'дней',
                color: const Color(0xFF4A9BFF),
              ),
              _buildMainStat(
                isDark,
                emoji: '🏋️',
                value: '${session.totalWorkoutsCompleted}',
                label: 'тренировок',
                color: const Color(0xFFFF6B35),
              ),
              _buildMainStat(
                isDark,
                emoji: '⚡',
                value: '${(session.totalVolumeCompleted / 1000).toStringAsFixed(1)}k',
                label: 'кг тоннаж',
                color: const Color(0xFF00C7BE),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 🔥 Защита от деления на ноль
          if (total > 0) ...[
            Row(
              children: [
                Icon(Icons.flag_rounded, size: 16, color: isDark ? Colors.white54 : Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Выполнение: $completed из $total дней',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${((completed / total) * 100).toInt()}%',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFFF6B35)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0,
                backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                minHeight: 10,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text('Нет данных о выполнении', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainStat(bool isDark, {required String emoji, required String value, required String label, required Color color}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ==================== ДИАГРАММА ВЫПОЛНЕНИЯ ====================

  Widget _buildCompletionChart(bool isDark, int completed, int skipped, int total) {
    final rest = total - completed - skipped;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: const Color(0xFFFF6B35), size: 22),
              const SizedBox(width: 8),
              Text(
                'Распределение дней',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Круговая диаграмма
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    segments: [
                      _ChartSegment(completed.toDouble(), const Color(0xFF4CAF50)),
                      _ChartSegment(skipped.toDouble(), const Color(0xFFF44336)),
                      _ChartSegment(rest.toDouble().clamp(0, double.infinity), Colors.grey.shade400),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$completed',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                        ),
                        Text(
                          'дней',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Легенда
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendRow(isDark, const Color(0xFF4CAF50), '✅ Выполнено', '$completed', total),
                    const SizedBox(height: 10),
                    _buildLegendRow(isDark, const Color(0xFFF44336), '❌ Пропущено', '$skipped', total),
                    const SizedBox(height: 10),
                    _buildLegendRow(isDark, Colors.grey.shade400, '😴 Отдых', '$rest', total),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(bool isDark, Color color, String label, String value, int total) {
    final intVal = int.tryParse(value) ?? 0;
    final percent = total > 0 ? (intVal / total * 100).toInt() : 0;
    final progressValue = total > 0 ? (intVal / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 4),
            Text(
              '($percent%)',
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progressValue,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3,
          ),
        ),
      ],
    );
  }

  // ==================== ПРОГРЕСС ПО УПРАЖНЕНИЯМ ====================

  Widget _buildExerciseProgress(bool isDark, Map<String, dynamic> exerciseStats) {
    final provider = context.read<FitnessProvider>();

    // Собираем топ-5 упражнений с наибольшим прогрессом
    final sortedStats = exerciseStats.entries.toList()
      ..sort((a, b) {
        final aStats = a.value as Map<String, dynamic>;
        final bStats = b.value as Map<String, dynamic>;
        final aProgress = ((aStats['lastWeight'] as num?)?.toDouble() ?? 0) - ((aStats['firstWeight'] as num?)?.toDouble() ?? 0);
        final bProgress = ((bStats['lastWeight'] as num?)?.toDouble() ?? 0) - ((bStats['firstWeight'] as num?)?.toDouble() ?? 0);
        return bProgress.compareTo(aProgress);
      });

    final topStats = sortedStats.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: const Color(0xFF4CAF50), size: 22),
              const SizedBox(width: 8),
              Text(
                'Прогресс по упражнениям',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Топ-${topStats.length} по росту рабочего веса',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ...topStats.asMap().entries.map((entry) {
            final exerciseId = entry.value.key;
            final stats = entry.value.value as Map<String, dynamic>;

            final exercise = provider.exercises.firstWhere(
                  (e) => e.id == exerciseId,
              orElse: () => Exercise(id: exerciseId, name: 'Упражнение'),
            );

            final firstWeight = (stats['firstWeight'] as num?)?.toDouble() ?? 0;
            final lastWeight = (stats['lastWeight'] as num?)?.toDouble() ?? 0;
            final firstReps = (stats['firstReps'] as num?)?.toInt() ?? 0;
            final lastReps = (stats['lastReps'] as num?)?.toInt() ?? 0;
            final workouts = (stats['workouts'] as num?)?.toInt() ?? 0;

            final weightDiff = lastWeight - firstWeight;
            final percentChange = firstWeight > 0 ? (weightDiff / firstWeight * 100) : 0.0;
            final isPositive = weightDiff >= 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: exercise.muscleGroups.isNotEmpty
                              ? exercise.muscleGroups.first.color.withOpacity(0.2)
                              : const Color(0xFFFF6B35).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(exercise.exerciseType.emoji, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.name,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$workouts ${_getWorkoutsWord(workouts)}',
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositive ? const Color(0xFF4CAF50).withOpacity(0.15) : const Color(0xFFF44336).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 12,
                              color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${percentChange >= 0 ? "+" : ""}${percentChange.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // "До → После"
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildWeightChip(isDark, 'Было', firstWeight, firstReps, Colors.grey),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey.shade400),
                        const SizedBox(width: 8),
                        _buildWeightChip(
                          isDark,
                          'Стало',
                          lastWeight,
                          lastReps,
                          isPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                        ),
                        const Spacer(),
                        Text(
                          '${weightDiff >= 0 ? "+" : ""}${weightDiff.toStringAsFixed(1)} кг',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeightChip(bool isDark, String label, double weight, int reps, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${weight.toStringAsFixed(0)} кг',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
            ),
            Text(
              '× $reps повт.',
              style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ХАЙЛАЙТЫ ПРОИЗВОДИТЕЛЬНОСТИ ====================

  Widget _buildPerformanceHighlights(bool isDark, ProgramSession session) {
    final achievements = <_Achievement>[];

    if (session.longestStreak >= 3) {
      achievements.add(_Achievement(
        emoji: '🔥',
        title: 'Серия ${session.longestStreak} дней',
        subtitle: 'Максимальная серия без пропусков',
        color: const Color(0xFFFF6B35),
      ));
    }

    if (session.totalVolumeCompleted >= 10000) {
      achievements.add(_Achievement(
        emoji: '💪',
        title: '10 000+ кг',
        subtitle: 'Общий тоннаж превысил 10 тонн',
        color: const Color(0xFF4A9BFF),
      ));
    }

    if (session.totalVolumeCompleted >= 50000) {
      achievements.add(_Achievement(
        emoji: '🏋️',
        title: '50 000+ кг',
        subtitle: 'Полсотни тонн за программу!',
        color: const Color(0xFFE91E63),
      ));
    }

    if (session.averageRpe >= 7) {
      achievements.add(_Achievement(
        emoji: '⚡',
        title: 'Интенсивная работа',
        subtitle: 'Средний RPE: ${session.averageRpe.toStringAsFixed(1)}',
        color: const Color(0xFFFFCC00),
      ));
    }

    if (session.totalWorkoutsSkipped == 0 && session.totalWorkoutsCompleted > 0) {
      achievements.add(_Achievement(
        emoji: '🎯',
        title: 'Без пропусков',
        subtitle: 'Ни одной пропущенной тренировки',
        color: const Color(0xFF4CAF50),
      ));
    }

    if (session.durationDays <= 30 && session.totalWorkoutsCompleted >= 15) {
      achievements.add(_Achievement(
        emoji: '⚡',
        title: 'Плотный график',
        subtitle: '${session.totalWorkoutsCompleted} тренировок за ${session.durationDays} дней',
        color: const Color(0xFF00C7BE),
      ));
    }

    if (achievements.isEmpty) {
      achievements.add(_Achievement(
        emoji: '✨',
        title: 'Программа пройдена',
        subtitle: 'Вы успешно завершили программу',
        color: const Color(0xFFFF6B35),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: const Color(0xFFFFCC00), size: 22),
              const SizedBox(width: 8),
              Text(
                'Достижения',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...achievements.map((a) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  a.color.withOpacity(0.15),
                  a.color.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: a.color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: a.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(a.emoji, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                      ),
                      Text(
                        a.subtitle,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.verified_rounded, color: a.color, size: 22),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ==================== ТАЙМЛАЙН ДНЕЙ ====================

  Widget _buildDailyTimeline(bool isDark, ProgramSession session, WorkoutProgram program) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: const Color(0xFF4A9BFF), size: 22),
              const SizedBox(width: 8),
              Text(
                'Календарь программы',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: session.daySessions.length,
            itemBuilder: (ctx, index) {
              final daySession = session.daySessions[index];
              Color bgColor;
              String emoji;

              switch (daySession.status) {
                case DaySessionStatus.completed:
                  bgColor = const Color(0xFF4CAF50);
                  emoji = '✅';
                  break;
                case DaySessionStatus.skipped:
                  bgColor = const Color(0xFFF44336);
                  emoji = '❌';
                  break;
                case DaySessionStatus.current:
                  bgColor = const Color(0xFFFF6B35);
                  emoji = '🔥';
                  break;
                default:
                  bgColor = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200;
                  emoji = '—';
              }

              return Container(
                decoration: BoxDecoration(
                  color: bgColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: bgColor.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== КНОПКИ ДЕЙСТВИЙ ====================

  Widget _buildActionButtons(bool isDark, ProgramSession session) {
    return Column(
      children: [
        // 🔥 Поделиться результатом (через буфер обмена - без внешних зависимостей)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _shareResult(session),
            icon: const Icon(Icons.share_rounded),
            label: const Text('ПОДЕЛИТЬСЯ РЕЗУЛЬТАТОМ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A9BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Новая программа
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('НАЧАТЬ НОВУЮ ПРОГРАММУ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // На главную
        TextButton.icon(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          icon: const Icon(Icons.home_rounded),
          label: const Text('На главную'),
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ ====================

  void _shareResult(ProgramSession session) {
    final program = widget.program;
    final text = '''
🏆 Я завершил программу "${program.name}"!

📅 Длительность: ${session.durationDays} дней
🏋️ Тренировок: ${session.totalWorkoutsCompleted}
⚡ Тоннаж: ${(session.totalVolumeCompleted / 1000).toStringAsFixed(1)}k кг
🔥 Макс. серия: ${session.longestStreak} дней
📊 Средний RPE: ${session.averageRpe.toStringAsFixed(1)}

💪 Присоединяйся к тренировкам!
''';

    // 🔥 Копируем в буфер обмена (без внешних зависимостей)
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text('Результат скопирован! Вставьте в мессенджер', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    HapticFeedback.mediumImpact();
  }

  String _formatDate(DateTime date) {
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _getWorkoutsWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'тренировка';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'тренировки';
    return 'тренировок';
  }
}

// ==================== КАСТОМНЫЕ ПАИНТЕРЫ ====================

class _DonutChartPainter extends CustomPainter {
  final List<_ChartSegment> segments;

  _DonutChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.28;

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total == 0) return;

    double startAngle = -pi / 2;

    for (final segment in segments) {
      final sweepAngle = (segment.value / total) * 2 * pi;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) => true;
}

class _ChartSegment {
  final double value;
  final Color color;

  _ChartSegment(this.value, this.color);
}

class _Achievement {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  _Achievement({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}