// features/fitness/ui/screens/program_summary_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kidloop/features/fitness/models/enums.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/fitness_provider.dart';

// ==================== POWER MODE TOKENS ====================

class _Power {
  static const Color heroBase = Color(0xFF050505);
  static const Color heroDeep = Color(0xFF120700);

  static const Color volt = Color(0xFFFF5500);
  static const Color voltBright = Color(0xFFFF7A1A);
  static const Color magma = Color(0xFFFF2D55);
  static const Color plasma = Color(0xFFFFCC00);
  static const Color ice = Color(0xFF00E5FF);
  static const Color lime = Color(0xFFB4FF39);
  static const Color green = Color(0xFF00C853);
  static const Color red = Color(0xFFFF3B30);

  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCard2 = Color(0xFF2C2C2E);
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);

  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color card2(bool isDark) => isDark ? darkCard2 : const Color(0xFFF9FAFB);
  static Color textPrimary(bool isDark) => isDark ? Colors.white : Colors.black;
  static Color textSecondary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.6)
      : const Color(0xFF3C3C43).withOpacity(0.6);
  static Color textTertiary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.3)
      : const Color(0xFF3C3C43).withOpacity(0.3);
  static Color separator(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

  static List<BoxShadow> softGlow(Color color, {double strength = 0.18}) => [
    BoxShadow(color: color.withOpacity(strength), blurRadius: 16),
  ];

  static List<BoxShadow> glow(Color color,
      {double strength = 0.4, double blur = 24}) =>
      [
        BoxShadow(
          color: color.withOpacity(strength),
          blurRadius: blur,
          offset: const Offset(0, 6),
        ),
      ];
}

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
  late AnimationController _heroController;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final session = widget.session;
    final program = widget.program;
    final summary = session.summaryData;

    final completedDays = (summary['completedDays'] as num?)?.toInt() ??
        session.daySessions
            .where((d) => d.status == DaySessionStatus.completed)
            .length;
    final skippedDays = (summary['skippedDays'] as num?)?.toInt() ??
        session.daySessions
            .where((d) => d.status == DaySessionStatus.skipped)
            .length;
    final totalDays =
        (summary['totalDays'] as num?)?.toInt() ?? program.days.length;
    final durationDays =
        (summary['durationDays'] as num?)?.toInt() ?? session.durationDays;
    final exerciseStats =
        (summary['exerciseStats'] as Map<String, dynamic>?) ?? {};

    return Scaffold(
      backgroundColor: _Power.bg(isDark),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHero(isDark, program, session, durationDays),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildMainStats(
                    isDark, session, completedDays, totalDays, durationDays),
                const SizedBox(height: 16),
                _buildCompletionChart(
                    isDark, completedDays, skippedDays, totalDays),
                const SizedBox(height: 16),
                if (exerciseStats.isNotEmpty) ...[
                  _buildExerciseProgress(isDark, exerciseStats),
                  const SizedBox(height: 16),
                ],
                _buildPerformanceHighlights(isDark, session),
                const SizedBox(height: 16),
                _buildDailyTimeline(isDark, session, program),
                const SizedBox(height: 28),
                _buildActionButtons(isDark, session),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // HERO — TROPHY
  // =====================================================================

  Widget _buildHero(
      bool isDark,
      WorkoutProgram program,
      ProgramSession session,
      int durationDays,
      ) {
    final accent = program.accentColor;

    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF050505),
              Color(0xFF0F0700),
              Color(0xFF1A0A00),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Bottom accent line
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _Power.volt.withOpacity(0.0),
                      _Power.volt,
                      _Power.magma,
                      _Power.volt,
                      _Power.volt.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Trophy with rays
                  AnimatedBuilder(
                    animation: _heroController,
                    builder: (ctx, child) {
                      final scale = Curves.elasticOut.transform(
                        _heroController.value.clamp(0.0, 1.0),
                      );
                      return Transform.scale(
                        scale: 0.5 + scale * 0.5,
                        child: child,
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Rays
                        ...List.generate(8, (i) {
                          return Transform.rotate(
                            angle: (i * pi / 4),
                            child: Container(
                              width: 2,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    _Power.plasma.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                        // Radial glow
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _Power.volt.withOpacity(0.35),
                                _Power.volt.withOpacity(0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),

                        // Trophy ring
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _Power.darkCard,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _Power.volt.withOpacity(0.6),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _Power.volt.withOpacity(0.5),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '🏆',
                              style: TextStyle(fontSize: 60),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Small caps label
                  const Text(
                    'ПРОГРАММА ЗАВЕРШЕНА',
                    style: TextStyle(
                      color: _Power.volt,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Big program name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      program.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Dates
                  Text(
                    '${_formatDate(session.startDate)} — ${_formatDate(session.endDate ?? DateTime.now())}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Difficulty pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      _getDifficultyLabel(session.difficulty).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        height: 1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDifficultyLabel(ProgramDifficulty d) {
    switch (d) {
      case ProgramDifficulty.flexible:
        return '🟢 Гибкий';
      case ProgramDifficulty.standard:
        return '🟡 Стандарт';
      case ProgramDifficulty.hardcore:
        return '🔴 Хардкор';
    }
  }

  // =====================================================================
  // MAIN STATS
  // =====================================================================

  Widget _buildMainStats(
      bool isDark,
      ProgramSession session,
      int completed,
      int total,
      int duration,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Power.separator(isDark), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _Power.plasma.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow:
                  _Power.softGlow(_Power.plasma, strength: 0.2),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _Power.plasma,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ИТОГИ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  color: _Power.textPrimary(isDark),
                ),
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
                label: 'ДНЕЙ',
                color: _Power.ice,
              ),
              _mainDivider(isDark),
              _buildMainStat(
                isDark,
                emoji: '🏋️',
                value: '${session.totalWorkoutsCompleted}',
                label: 'ТРЕН.',
                color: _Power.volt,
              ),
              _mainDivider(isDark),
              _buildMainStat(
                isDark,
                emoji: '⚡',
                value:
                '${(session.totalVolumeCompleted / 1000).toStringAsFixed(1)}k',
                label: 'КГ',
                color: _Power.lime,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (total > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Power.card2(isDark),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        size: 15,
                        color: _Power.volt,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ВЫПОЛНЕНО $completed ИЗ $total',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: _Power.textSecondary(isDark),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${((completed / total) * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: _Power.volt,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0
                          ? (completed / total).clamp(0.0, 1.0)
                          : 0.0,
                      backgroundColor: _Power.separator(isDark),
                      valueColor:
                      const AlwaysStoppedAnimation(_Power.volt),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Power.plasma.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _Power.plasma.withOpacity(0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: _Power.plasma,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Нет данных о выполнении',
                      style: TextStyle(
                        color: _Power.textSecondary(isDark),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _mainDivider(bool isDark) {
    return Container(
      width: 0.5,
      height: 40,
      color: _Power.separator(isDark),
    );
  }

  Widget _buildMainStat(
      bool isDark, {
        required String emoji,
        required String value,
        required String label,
        required Color color,
      }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
              boxShadow: _Power.softGlow(color, strength: 0.15),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.9,
              height: 1,
              color: _Power.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: _Power.textTertiary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // DONUT CHART
  // =====================================================================

  Widget _buildCompletionChart(
      bool isDark,
      int completed,
      int skipped,
      int total,
      ) {
    final rest = total - completed - skipped;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Power.separator(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _Power.ice.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _Power.softGlow(_Power.ice, strength: 0.15),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: _Power.ice,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'РАСПРЕДЕЛЕНИЕ ДНЕЙ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  color: _Power.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    segments: [
                      _ChartSegment(
                        completed.toDouble(),
                        _Power.green,
                      ),
                      _ChartSegment(
                        skipped.toDouble(),
                        _Power.red,
                      ),
                      _ChartSegment(
                        rest.toDouble().clamp(0, double.infinity),
                        isDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.grey.shade300,
                      ),
                    ],
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$completed',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                            height: 1,
                            color: _Power.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ДНЕЙ',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            color: _Power.textTertiary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendRow(
                      isDark,
                      _Power.green,
                      'Выполнено',
                      '$completed',
                      total,
                    ),
                    const SizedBox(height: 12),
                    _buildLegendRow(
                      isDark,
                      _Power.red,
                      'Пропущено',
                      '$skipped',
                      total,
                    ),
                    const SizedBox(height: 12),
                    _buildLegendRow(
                      isDark,
                      isDark
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey.shade400,
                      'Отдых',
                      '$rest',
                      total,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(
      bool isDark,
      Color color,
      String label,
      String value,
      int total,
      ) {
    final intVal = int.tryParse(value) ?? 0;
    final percent = total > 0 ? (intVal / total * 100).toInt() : 0;
    final progressValue =
    total > 0 ? (intVal / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: _Power.softGlow(color, strength: 0.4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: _Power.textSecondary(isDark),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                height: 1,
                color: _Power.textPrimary(isDark),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($percent%)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _Power.textTertiary(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
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

  // =====================================================================
  // EXERCISE PROGRESS
  // =====================================================================

  Widget _buildExerciseProgress(
      bool isDark,
      Map<String, dynamic> exerciseStats,
      ) {
    final provider = context.read<FitnessProvider>();

    final sortedStats = exerciseStats.entries.toList()
      ..sort((a, b) {
        final aStats = a.value as Map<String, dynamic>;
        final bStats = b.value as Map<String, dynamic>;
        final aProgress =
            ((aStats['lastWeight'] as num?)?.toDouble() ?? 0) -
                ((aStats['firstWeight'] as num?)?.toDouble() ?? 0);
        final bProgress =
            ((bStats['lastWeight'] as num?)?.toDouble() ?? 0) -
                ((bStats['firstWeight'] as num?)?.toDouble() ?? 0);
        return bProgress.compareTo(aProgress);
      });

    final topStats = sortedStats.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Power.separator(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _Power.green.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow:
                  _Power.softGlow(_Power.green, strength: 0.15),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: _Power.green,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ПРОГРЕСС ПО УПРАЖНЕНИЯМ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                        color: _Power.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Топ-${topStats.length} по росту веса',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _Power.textTertiary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topStats.asMap().entries.map((entry) {
            final exerciseId = entry.value.key;
            final stats = entry.value.value as Map<String, dynamic>;

            final exercise = provider.exercises.firstWhere(
                  (e) => e.id == exerciseId,
              orElse: () => Exercise(id: exerciseId, name: 'Упражнение'),
            );

            final firstWeight =
                (stats['firstWeight'] as num?)?.toDouble() ?? 0;
            final lastWeight =
                (stats['lastWeight'] as num?)?.toDouble() ?? 0;
            final firstReps = (stats['firstReps'] as num?)?.toInt() ?? 0;
            final lastReps = (stats['lastReps'] as num?)?.toInt() ?? 0;
            final workouts = (stats['workouts'] as num?)?.toInt() ?? 0;

            final weightDiff = lastWeight - firstWeight;
            final percentChange = firstWeight > 0
                ? (weightDiff / firstWeight * 100)
                : 0.0;
            final isPositive = weightDiff >= 0;
            final accent = exercise.muscleGroups.isNotEmpty
                ? exercise.muscleGroups.first.color
                : _Power.volt;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Power.card2(isDark),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow:
                          _Power.softGlow(accent, strength: 0.15),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          exercise.exerciseType.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: _Power.textPrimary(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$workouts ${_getWorkoutsWord(workouts)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: _Power.textTertiary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (isPositive
                              ? _Power.green
                              : _Power.red)
                              .withOpacity(0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 11,
                              color: isPositive
                                  ? _Power.green
                                  : _Power.red,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${percentChange >= 0 ? "+" : ""}${percentChange.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                                height: 1,
                                color: isPositive
                                    ? _Power.green
                                    : _Power.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _Power.card(isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildWeightChip(
                          isDark,
                          'БЫЛО',
                          firstWeight,
                          firstReps,
                          _Power.textSecondary(isDark),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: _Power.textTertiary(isDark),
                        ),
                        const SizedBox(width: 8),
                        _buildWeightChip(
                          isDark,
                          'СТАЛО',
                          lastWeight,
                          lastReps,
                          isPositive ? _Power.green : _Power.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${weightDiff >= 0 ? "+" : ""}${weightDiff.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            height: 1,
                            color:
                            isPositive ? _Power.green : _Power.red,
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

  Widget _buildWeightChip(
      bool isDark,
      String label,
      double weight,
      int reps,
      Color color,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                height: 1,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${weight.toStringAsFixed(0)} кг',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                height: 1,
                color: _Power.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '× $reps',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _Power.textTertiary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // PERFORMANCE HIGHLIGHTS
  // =====================================================================

  Widget _buildPerformanceHighlights(
      bool isDark,
      ProgramSession session,
      ) {
    final achievements = <_Achievement>[];

    if (session.longestStreak >= 3) {
      achievements.add(_Achievement(
        emoji: '🔥',
        title: 'Серия ${session.longestStreak} дней',
        subtitle: 'Максимальная серия без пропусков',
        color: _Power.volt,
      ));
    }

    if (session.totalVolumeCompleted >= 10000) {
      achievements.add(_Achievement(
        emoji: '💪',
        title: '10 000+ КГ',
        subtitle: 'Общий тоннаж превысил 10 тонн',
        color: _Power.ice,
      ));
    }

    if (session.totalVolumeCompleted >= 50000) {
      achievements.add(_Achievement(
        emoji: '🏋️',
        title: '50 000+ КГ',
        subtitle: 'Полсотни тонн за программу',
        color: _Power.magma,
      ));
    }

    if (session.averageRpe >= 7) {
      achievements.add(_Achievement(
        emoji: '⚡',
        title: 'Интенсивная работа',
        subtitle: 'Средний RPE: ${session.averageRpe.toStringAsFixed(1)}',
        color: _Power.plasma,
      ));
    }

    if (session.totalWorkoutsSkipped == 0 &&
        session.totalWorkoutsCompleted > 0) {
      achievements.add(_Achievement(
        emoji: '🎯',
        title: 'Без пропусков',
        subtitle: 'Ни одной пропущенной тренировки',
        color: _Power.green,
      ));
    }

    if (session.durationDays <= 30 &&
        session.totalWorkoutsCompleted >= 15) {
      achievements.add(_Achievement(
        emoji: '⚡',
        title: 'Плотный график',
        subtitle:
        '${session.totalWorkoutsCompleted} тренировок за ${session.durationDays} дней',
        color: _Power.lime,
      ));
    }

    if (achievements.isEmpty) {
      achievements.add(_Achievement(
        emoji: '✨',
        title: 'Программа пройдена',
        subtitle: 'Вы успешно завершили программу',
        color: _Power.volt,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Power.separator(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _Power.plasma.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow:
                  _Power.softGlow(_Power.plasma, strength: 0.15),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: _Power.plasma,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ДОСТИЖЕНИЯ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  color: _Power.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...achievements.map((a) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: a.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: a.color.withOpacity(0.25),
                width: 0.8,
              ),
              boxShadow: _Power.softGlow(a.color, strength: 0.10),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: a.color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow:
                    _Power.softGlow(a.color, strength: 0.25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    a.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1.1,
                          color: _Power.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        a.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _Power.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.verified_rounded,
                  color: a.color,
                  size: 22,
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // =====================================================================
  // TIMELINE GRID
  // =====================================================================

  Widget _buildDailyTimeline(
      bool isDark,
      ProgramSession session,
      WorkoutProgram program,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Power.separator(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _Power.ice.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _Power.softGlow(_Power.ice, strength: 0.15),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: _Power.ice,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'КАЛЕНДАРЬ ПРОГРАММЫ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  color: _Power.textPrimary(isDark),
                ),
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
              Color accent;
              String emoji;

              switch (daySession.status) {
                case DaySessionStatus.completed:
                  accent = _Power.green;
                  emoji = '✓';
                  break;
                case DaySessionStatus.skipped:
                  accent = _Power.red;
                  emoji = '×';
                  break;
                case DaySessionStatus.current:
                  accent = _Power.volt;
                  emoji = '🔥';
                  break;
                default:
                  accent = _Power.textTertiary(isDark);
                  emoji = '—';
              }

              return Container(
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withOpacity(0.3),
                    width: 0.6,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      emoji,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: accent,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        height: 1,
                        color: _Power.textPrimary(isDark),
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

  // =====================================================================
  // ACTIONS
  // =====================================================================

  Widget _buildActionButtons(bool isDark, ProgramSession session) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => _shareResult(session),
            style: ElevatedButton.styleFrom(
              backgroundColor: _Power.ice,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              shadowColor: _Power.ice.withOpacity(0.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'ПОДЕЛИТЬСЯ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _Power.volt,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              shadowColor: _Power.volt.withOpacity(0.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'НОВАЯ ПРОГРАММА',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home_rounded,
                  size: 16,
                  color: _Power.textSecondary(isDark),
                ),
                const SizedBox(width: 6),
                Text(
                  'НА ГЛАВНУЮ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: _Power.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================================
  // SHARE
  // =====================================================================

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

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Результат скопирован!',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _Power.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    HapticFeedback.mediumImpact();
  }

  // =====================================================================
  // HELPERS
  // =====================================================================

  String _formatDate(DateTime date) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _getWorkoutsWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'тренировка';
    if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return 'тренировки';
    }
    return 'тренировок';
  }
}

// ==================== CUSTOM PAINTER ====================

class _DonutChartPainter extends CustomPainter {
  final List<_ChartSegment> segments;
  final bool isDark;

  _DonutChartPainter({
    required this.segments,
    required this.isDark,
  });

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

      // Glow для непустых сегментов
      if (segment.value > 0) {
        final glowPaint = Paint()
          ..color = segment.color.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 4
          ..strokeCap = StrokeCap.butt
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

        canvas.drawArc(
          Rect.fromCircle(
              center: center, radius: radius - strokeWidth / 2),
          startAngle,
          sweepAngle,
          false,
          glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(
            center: center, radius: radius - strokeWidth / 2),
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