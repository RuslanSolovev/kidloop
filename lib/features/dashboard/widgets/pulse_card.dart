// features/dashboard/widgets/pulse_card.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../fitness/database/ui/screens/fitness_dashboard.dart';
import '../../fitness/models/enums.dart';
import '../../fitness/models/fitness_models.dart';
import '../../fitness/providers/fitness_provider.dart';

import '../../nutrition/models/nutrition_models.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../../nutrition/ui/screens/fuel_dashboard_screen.dart';

// ============================================================
// DESIGN TOKENS
// ============================================================

class _P {
  static const Color accent = Color(0xFFFF6B00);
  static const Color accentDark = Color(0xFFE85D00);
  static const Color violet = Color(0xFF6C5CE7);
  static const Color blue = Color(0xFF4F7CFF);
  static const Color green = Color(0xFF00A884);
  static const Color ice = Color(0xFF00E5FF);
  static const Color plasma = Color(0xFFFFCC00);
  static const Color magma = Color(0xFFFF2D55);
  static const Color ink = Color(0xFF121216);

  static const Color darkCard = Color(0xFF1D1D20);
  static const Color darkCard2 = Color(0xFF25252A);
  static const Color darkBorder = Color(0xFF2A2A2E);

  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCard2 = Color(0xFFF7F7F5);
  static const Color lightBorder = Color(0xFFE8E8E4);
  static const Color textSecondary = Color(0xFF777777);

  static List<BoxShadow> get softShadow => const [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}

// ============================================================
// PULSE CARD
// ============================================================

class PulseCard extends StatefulWidget {
  final bool isDark;
  final NutritionProvider? nutritionProvider;
  final VoidCallback? onOpenFitness;
  final VoidCallback? onOpenNutrition;

  const PulseCard({
    super.key,
    required this.isDark,
    this.nutritionProvider,
    this.onOpenFitness,
    this.onOpenNutrition,
  });

  @override
  State<PulseCard> createState() => _PulseCardState();
}

class _PulseCardState extends State<PulseCard>
    with SingleTickerProviderStateMixin {
  NutritionProvider? _nutrition;
  Future<NutritionProvider>? _nutritionFuture;
  bool _expanded = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  Color get _card => widget.isDark ? _P.darkCard : _P.lightCard;
  Color get _card2 => widget.isDark ? _P.darkCard2 : _P.lightCard2;
  Color get _border => widget.isDark ? _P.darkBorder : _P.lightBorder;
  Color get _text => widget.isDark ? Colors.white : _P.ink;
  Color get _sub => widget.isDark ? Colors.white60 : _P.textSecondary;
  Color get _muted => widget.isDark ? Colors.white38 : Colors.black38;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    if (widget.nutritionProvider != null) {
      _nutrition = widget.nutritionProvider;
    } else {
      _nutritionFuture = _initNutrition();
    }
  }

  Future<NutritionProvider> _initNutrition() async {
    if (_nutrition != null) return _nutrition!;
    final p = NutritionProvider();
    await p.init();
    _nutrition = p;
    return p;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─────────── NAVIGATION ───────────
  Future<void> _openFitness() async {
    HapticFeedback.selectionClick();
    if (widget.onOpenFitness != null) {
      widget.onOpenFitness!();
      return;
    }
    final fp = context.read<FitnessProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: fp,
          child: FitnessDashboard(isDark: widget.isDark),
        ),
      ),
    );
  }

  Future<void> _openNutrition() async {
    HapticFeedback.selectionClick();
    if (widget.onOpenNutrition != null) {
      widget.onOpenNutrition!();
      return;
    }
    final p = _nutrition ?? await _initNutrition();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: p,
          child: FuelDashboardScreen(isDark: widget.isDark),
        ),
      ),
    );
  }

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  // ─────────── BUILD ───────────
  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FitnessProvider>();

    if (_nutrition == null) {
      return FutureBuilder<NutritionProvider>(
        future: _nutritionFuture,
        builder: (context, snap) {
          if (!snap.hasData) return _buildSkeleton();
          _nutrition = snap.data;
          return _buildContent(fp, _nutrition!);
        },
      );
    }
    return _buildContent(fp, _nutrition!);
  }

  Widget _buildContent(FitnessProvider fp, NutritionProvider np) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ПИТАНИЕ
    final summary = np.getSummaryForDate(today);
    final goals = np.getGoalsForDate(today);

    final kcalPct = goals.calories > 0
        ? (summary.calories / goals.calories).clamp(0.0, 2.0)
        : 0.0;
    final proteinPct = goals.protein > 0
        ? (summary.protein / goals.protein).clamp(0.0, 2.0)
        : 0.0;
    final fatPct =
    goals.fat > 0 ? (summary.fat / goals.fat).clamp(0.0, 2.0) : 0.0;
    final carbsPct =
    goals.carbs > 0 ? (summary.carbs / goals.carbs).clamp(0.0, 2.0) : 0.0;
    final waterPct = goals.waterMl > 0
        ? (summary.waterMl / goals.waterMl).clamp(0.0, 2.0)
        : 0.0;
    final proteinLeft =
    (goals.protein - summary.protein).clamp(0.0, 999.0).toDouble();
    final waterLeft = (goals.waterMl - summary.waterMl).clamp(0, 99999);

    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayCal = np.getSummaryForDate(yesterday).calories;
    final kcalDelta = summary.calories - yesterdayCal;

    // ТРЕНИРОВКА
    final session = fp.activeSession;
    final todayLogs = fp.getLogsForDate(today);
    final completedToday = todayLogs
        .where((l) => l.status == WorkoutDayStatus.completed)
        .toList();
    final isWorkoutActive = fp.isWorkoutActive;

    WorkoutDay? todayProgramDay;
    WorkoutProgram? activeProgram;
    if (session != null) {
      try {
        activeProgram =
            fp.programs.firstWhere((p) => p.id == session.programId);
        if (session.currentDayIndex >= 0 &&
            session.currentDayIndex < activeProgram.days.length) {
          todayProgramDay = activeProgram.days[session.currentDayIndex];
        }
      } catch (_) {}
    }

    // СТАТИСТИКА
    final week7 = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final weekKcal = week7
        .map((d) => np.getSummaryForDate(d).calories)
        .toList(growable: false);
    final weekWorkouts = week7
        .map((d) => fp
        .getLogsForDate(d)
        .where((l) => l.status == WorkoutDayStatus.completed)
        .length)
        .toList(growable: false);

    final weekKcalTotal = weekKcal.fold<double>(0, (s, v) => s + v);
    final monthKcalTotal = List.generate(30, (i) {
      return np.getSummaryForDate(today.subtract(Duration(days: i))).calories;
    }).fold<double>(0, (s, v) => s + v);

    final weekWorkoutsTotal = weekWorkouts.fold<int>(0, (s, v) => s + v);
    final monthWorkoutsTotal = List.generate(30, (i) {
      final d = today.subtract(Duration(days: i));
      return fp
          .getLogsForDate(d)
          .where((l) => l.status == WorkoutDayStatus.completed)
          .length;
    }).fold<int>(0, (s, v) => s + v);

    final prevWeekKcalTotal = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 13 - i));
      return np.getSummaryForDate(d).calories;
    }).fold<double>(0, (s, v) => s + v);

    final prevWeekWorkoutsTotal = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 13 - i));
      return fp
          .getLogsForDate(d)
          .where((l) => l.status == WorkoutDayStatus.completed)
          .length;
    }).fold<int>(0, (s, v) => s + v);

    final stats = fp.getStats();
    final streak = ((stats['currentStreak'] ?? 0) as num).toInt();
    final totalVolume = (stats['totalVolume'] as num?)?.toDouble() ?? 0;
    final totalWorkouts = (stats['totalWorkouts'] as num?)?.toInt() ?? 0;
    final avgRpe = (stats['averageRpe'] as num?)?.toDouble() ?? 0;

    final achievementsCount =
    _countUnlockedAchievements(fp, streak, weekWorkoutsTotal);
    final daysSinceLastWorkout = _daysSinceLastWorkout(fp, today);
    final completedPrograms = fp.completedSessions.length;
    final activeTargetsCount = fp.activeTargets.length;
    final recentPhotosCount = fp.photos
        .where((p) => DateTime.now().difference(p.date).inDays <= 14)
        .length;
    final hasWellbeingToday = fp.getTodayWellbeing() != null;
    final lastWellbeing = fp.getTodayWellbeing();

    // СОВЕТЫ
    final tips = _buildTips(
      hour: now.hour,
      weekday: now.weekday,
      kcalPct: kcalPct,
      proteinPct: proteinPct,
      fatPct: fatPct,
      carbsPct: carbsPct,
      waterPct: waterPct,
      proteinLeft: proteinLeft,
      waterLeft: waterLeft,
      kcalDelta: kcalDelta,
      summary: summary,
      goals: goals,
      hasSession: session != null,
      hasCompletedToday: completedToday.isNotEmpty,
      isWorkoutActive: isWorkoutActive,
      todayProgramDay: todayProgramDay,
      fp: fp,
      streak: streak,
      weekWorkouts: weekWorkoutsTotal,
      prevWeekWorkouts: prevWeekWorkoutsTotal,
      monthWorkouts: monthWorkoutsTotal,
      weekKcal: weekKcalTotal,
      prevWeekKcal: prevWeekKcalTotal,
      totalWorkouts: totalWorkouts,
      totalVolume: totalVolume,
      achievements: achievementsCount,
      daysSinceLastWorkout: daysSinceLastWorkout,
      avgRpe: avgRpe,
      completedPrograms: completedPrograms,
      activeTargetsCount: activeTargetsCount,
      recentPhotosCount: recentPhotosCount,
      hasWellbeingToday: hasWellbeingToday,
      lastWellbeing: lastWellbeing,
      activeProgram: activeProgram,
      session: session,
    );

    final visibleTips = _expanded
        ? tips.take(20).toList()
        : (tips.isEmpty ? <String>[] : [tips.first]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
            boxShadow: widget.isDark ? null : _P.softShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(streak, achievementsCount),
              if (!_expanded)
                _buildCompactBody(
                  summary: summary,
                  goals: goals,
                  kcalPct: kcalPct,
                  proteinPct: proteinPct,
                  fatPct: fatPct,
                  carbsPct: carbsPct,
                  waterPct: waterPct,
                  tips: visibleTips,
                  session: session,
                  completedToday: completedToday,
                  isWorkoutActive: isWorkoutActive,
                  streak: streak,
                  weekKcal: weekKcal,
                  weekWorkouts: weekWorkouts,
                  todayProgramDay: todayProgramDay,
                  activeProgram: activeProgram,
                )
              else
                _buildExpandedBody(
                  summary: summary,
                  goals: goals,
                  kcalPct: kcalPct,
                  proteinPct: proteinPct,
                  fatPct: fatPct,
                  carbsPct: carbsPct,
                  waterPct: waterPct,
                  tips: visibleTips,
                  session: session,
                  completedToday: completedToday,
                  isWorkoutActive: isWorkoutActive,
                  streak: streak,
                  weekKcal: weekKcal,
                  weekWorkouts: weekWorkouts,
                  todayProgramDay: todayProgramDay,
                  activeProgram: activeProgram,
                  weekKcalTotal: weekKcalTotal,
                  monthKcalTotal: monthKcalTotal,
                  weekWorkoutsTotal: weekWorkoutsTotal,
                  monthWorkoutsTotal: monthWorkoutsTotal,
                  totalVolume: totalVolume,
                ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(int streak, int achievements) {
    final now = DateTime.now();
    const wd = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const mo = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    final dateStr = '${wd[now.weekday - 1]}, ${now.day} ${mo[now.month - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_P.accent, _P.accentDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'ПУЛЬС ДНЯ',
                      style: TextStyle(
                        color: _P.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    if (achievements > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _P.plasma.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏆',
                                style: TextStyle(fontSize: 9, height: 1)),
                            const SizedBox(width: 3),
                            Text(
                              '$achievements',
                              style: const TextStyle(
                                color: _P.plasma,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (streak > 0) _buildStreakFlame(streak),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _toggleExpanded,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 220),
              turns: _expanded ? 0.5 : 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _P.accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _P.accent,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakFlame(int streak) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final glow = 0.25 + _pulseAnim.value * 0.35;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: _P.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: _P.accent.withOpacity(0.3),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: _P.accent.withOpacity(glow),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 1.0 + _pulseAnim.value * 0.12,
                child: const Text('🔥', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 4),
              Text(
                '$streak',
                style: const TextStyle(
                  color: _P.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                _daysWord(streak),
                style: TextStyle(
                  color: _P.accent.withOpacity(0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // COMPACT BODY
  // ============================================================

  Widget _buildCompactBody({
    required DailyNutritionSummary summary,
    required NutritionGoals goals,
    required double kcalPct,
    required double proteinPct,
    required double fatPct,
    required double carbsPct,
    required double waterPct,
    required List<String> tips,
    required ProgramSession? session,
    required List<WorkoutLog> completedToday,
    required bool isWorkoutActive,
    required int streak,
    required List<double> weekKcal,
    required List<int> weekWorkouts,
    required WorkoutDay? todayProgramDay,
    required WorkoutProgram? activeProgram,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _nutritionColumn(summary, goals, kcalPct, proteinPct,
                      fatPct, carbsPct, waterPct),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _fitnessColumn(session, completedToday,
                      isWorkoutActive, streak, todayProgramDay, activeProgram),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: _sparklineCard(weekKcal, weekWorkouts),
        ),
        if (tips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _tipRow(tips.first, _tipColor(tips.first)),
          ),
      ],
    );
  }

  // ============================================================
  // EXPANDED BODY
  // ============================================================

  Widget _buildExpandedBody({
    required DailyNutritionSummary summary,
    required NutritionGoals goals,
    required double kcalPct,
    required double proteinPct,
    required double fatPct,
    required double carbsPct,
    required double waterPct,
    required List<String> tips,
    required ProgramSession? session,
    required List<WorkoutLog> completedToday,
    required bool isWorkoutActive,
    required int streak,
    required List<double> weekKcal,
    required List<int> weekWorkouts,
    required WorkoutDay? todayProgramDay,
    required WorkoutProgram? activeProgram,
    required double weekKcalTotal,
    required double monthKcalTotal,
    required int weekWorkoutsTotal,
    required int monthWorkoutsTotal,
    required double totalVolume,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _nutritionColumn(summary, goals, kcalPct, proteinPct,
                      fatPct, carbsPct, waterPct),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _fitnessColumn(session, completedToday,
                      isWorkoutActive, streak, todayProgramDay, activeProgram),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: _sparklineCard(weekKcal, weekWorkouts),
        ),

        if (tips.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: _P.violet, size: 14),
                const SizedBox(width: 6),
                Text(
                  'СОВЕТЫ ДНЯ',
                  style: TextStyle(
                    color: _P.violet,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _P.violet.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${tips.length}',
                    style: const TextStyle(
                      color: _P.violet,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...tips.map((t) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: _tipRow(t, _tipColor(t)),
          )),
        ],

        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _periodsCard(
            weekKcalTotal: weekKcalTotal,
            monthKcalTotal: monthKcalTotal,
            weekWorkoutsTotal: weekWorkoutsTotal,
            monthWorkoutsTotal: monthWorkoutsTotal,
            totalVolume: totalVolume,
            weekKcalAvg: weekKcalTotal / 7,
            monthKcalAvg: monthKcalTotal / 30,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NUTRITION COLUMN
  // ============================================================

  Widget _nutritionColumn(
      DailyNutritionSummary summary,
      NutritionGoals goals,
      double kcalPct,
      double proteinPct,
      double fatPct,
      double carbsPct,
      double waterPct,
      ) {
    final kcalLeft = (goals.calories - summary.calories).round();
    final isOver = kcalLeft < 0;
    final accent = isOver ? _P.magma : _P.ice;

    return GestureDetector(
      onTap: _openNutrition,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _P.ice.withOpacity(widget.isDark ? 0.09 : 0.05),
              _P.ice.withOpacity(0.0),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.ice.withOpacity(0.20), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _P.ice.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.restaurant_rounded,
                      color: _P.ice, size: 13),
                ),
                const SizedBox(width: 7),
                const Text(
                  'ПИТАНИЕ',
                  style: TextStyle(
                    color: _P.ice,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _dualRing(kcalPct, proteinPct, accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.calories.round()}',
                        style: TextStyle(
                          color: _text,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'из ${goals.calories.round()}',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOver
                              ? '+${kcalLeft.abs()} перебор'
                              : 'осталось $kcalLeft',
                          style: TextStyle(
                            color: accent,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _macroBar('Б', summary.protein, goals.protein, proteinPct, _P.green),
            const SizedBox(height: 5),
            _macroBar('Ж', summary.fat, goals.fat, fatPct, _P.magma),
            const SizedBox(height: 5),
            _macroBar('У', summary.carbs, goals.carbs, carbsPct, _P.plasma),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.water_drop_rounded,
                    size: 12, color: _P.ice),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: waterPct.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: _P.ice.withOpacity(0.12),
                      valueColor: const AlwaysStoppedAnimation(_P.ice),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${summary.waterMl}мл',
                  style: TextStyle(
                    color: _sub,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                _waterQuickAdd(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dualRing(double kcalPct, double proteinPct, Color accent) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation(_P.ice.withOpacity(0.10)),
            ),
          ),
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: kcalPct.clamp(0.0, 1.0),
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: proteinPct.clamp(0.0, 1.0),
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              valueColor: const AlwaysStoppedAnimation(_P.green),
            ),
          ),
          Text(
            '${(kcalPct * 100).round()}%',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroBar(String label, double cur, double goal, double pct, Color c) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c.withOpacity(0.14),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: c.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation(c),
            ),
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 40,
          child: Text(
            '${cur.round()}/${goal.round()}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: _sub,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _waterQuickAdd() {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final p = _nutrition ?? await _initNutrition();
        await p.addWater(250, date: DateTime.now());
      },
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: _P.ice.withOpacity(0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.add_rounded, color: _P.ice, size: 13),
      ),
    );
  }

  // ============================================================
  // FITNESS COLUMN
  // ============================================================

  Widget _fitnessColumn(
      ProgramSession? session,
      List<WorkoutLog> completedToday,
      bool isWorkoutActive,
      int streak,
      WorkoutDay? todayProgramDay,
      WorkoutProgram? activeProgram,
      ) {
    final fp = context.read<FitnessProvider>();

    if (isWorkoutActive) return _fitnessActiveSession();

    if (session != null && activeProgram != null) {
      if (todayProgramDay != null && todayProgramDay.isRestDay) {
        return _fitnessRestDay();
      }
      if (todayProgramDay != null && todayProgramDay.exercises.isNotEmpty) {
        return _fitnessWorkoutDay(
          fp,
          activeProgram,
          todayProgramDay,
          session.currentDayIndex,
          session,
        );
      }
    }

    if (completedToday.isNotEmpty) return _fitnessCompletedFree(completedToday);

    return _fitnessNoProgram();
  }

  Widget _fitnessActiveSession() {
    return GestureDetector(
      onTap: _openFitness,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, _) {
          final glow = 0.15 + _pulseAnim.value * 0.25;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _P.green.withOpacity(widget.isDark ? 0.15 : 0.10),
                  _P.green.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _P.green.withOpacity(0.3 + _pulseAnim.value * 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _P.green.withOpacity(glow),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _P.green.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: _P.green, size: 15),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'В ПРОЦЕССЕ',
                      style: TextStyle(
                        color: _P.green,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Тренировка\nидёт',
                  style: TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _P.green,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: _P.green.withOpacity(0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 3),
                      Text(
                        'ПРОДОЛЖИТЬ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _fitnessNoProgram() {
    return GestureDetector(
      onTap: _openFitness,
      behavior: HitTestBehavior.opaque,
      child: _shell(
        accent: _P.accent,
        title: 'СВОБОДНЫЙ ДЕНЬ',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Программы нет',
              style: TextStyle(
                color: _text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Начни программу или сделай свободную',
              style: TextStyle(
                color: _sub,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const Spacer(),
            _ctaButton('НАЧАТЬ', _P.accent),
          ],
        ),
      ),
    );
  }

  Widget _fitnessWorkoutDay(
      FitnessProvider fp,
      WorkoutProgram program,
      WorkoutDay day,
      int idx,
      ProgramSession session,
      ) {
    final preview = day.exercises.take(2).toList();
    final totalDays = program.days.length;

    return GestureDetector(
      onTap: _openFitness,
      behavior: HitTestBehavior.opaque,
      child: _shell(
        accent: _P.accent,
        title: 'СЕГОДНЯ',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'День ${idx + 1}/$totalDays',
                    style: TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _P.accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${day.exercises.length} упр',
                    style: const TextStyle(
                      color: _P.accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...preview.map((we) {
              final ex = fp.exercises.firstWhere(
                    (e) => e.id == we.exerciseId,
                orElse: () => Exercise(id: '', name: '???'),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: _P.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ex.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _sub,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '×${we.sets.length}',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (day.exercises.length > preview.length)
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 1),
                child: Text(
                  '+ ещё ${day.exercises.length - preview.length}',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const Spacer(),
            _ctaButton('ТРЕНИРОВКА', _P.accent),
          ],
        ),
      ),
    );
  }

  Widget _fitnessRestDay() {
    return GestureDetector(
      onTap: _openFitness,
      behavior: HitTestBehavior.opaque,
      child: _shell(
        accent: _P.violet,
        title: 'ВОССТАНОВЛЕНИЕ',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🛏️', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              'День отдыха',
              style: TextStyle(
                color: _text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Мышцы растут в покое.\nПей воду, ешь белок.',
              style: TextStyle(
                color: _sub,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _P.violet.withOpacity(0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                'ВОССТАНОВЛЕНИЕ',
                style: TextStyle(
                  color: _P.violet,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fitnessCompletedFree(List<WorkoutLog> logs) {
    final log = logs.first;
    final vol = log.totalVolume?.round() ?? 0;
    final min = log.duration?.inMinutes ?? 0;
    final avgRpe = log.avgRpe?.toStringAsFixed(1);

    return GestureDetector(
      onTap: _openFitness,
      behavior: HitTestBehavior.opaque,
      child: _shell(
        accent: _P.green,
        title: 'ГОТОВО',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _P.green.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: _P.green, size: 15),
                ),
                const SizedBox(width: 7),
                Text(
                  'Тренировка',
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _chip('⏱', '$min мин', _P.green),
                _chip('🏋️', '$vol кг', _P.green),
                if (avgRpe != null) _chip('💪', 'RPE $avgRpe', _P.green),
              ],
            ),
            const Spacer(),
            Text(
              'Красава! Восстановление — это важно.',
              style: TextStyle(
                color: _sub,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shell({
    required Color accent,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(widget.isDark ? 0.09 : 0.05),
            accent.withOpacity(0.0),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.20), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.fitness_center_rounded,
                    color: accent, size: 13),
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _ctaButton(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String emoji, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$emoji $text',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  // ============================================================
  // SPARKLINE
  // ============================================================

  Widget _sparklineCard(List<double> weekKcal, List<int> weekWorkouts) {
    final maxKcal = weekKcal.isEmpty
        ? 1.0
        : weekKcal.reduce((a, b) => a > b ? a : b).clamp(1.0, 1e9);

    const days = ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'];
    final todayIdx = DateTime.now().weekday - 1;
    final todayPos = weekKcal.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  color: _P.accent, size: 13),
              const SizedBox(width: 6),
              const Text(
                'ДИНАМИКА ЗА НЕДЕЛЮ',
                style: TextStyle(
                  color: _P.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                '${_fmtKcal(weekKcal.fold<double>(0, (s, v) => s + v))} ккал',
                style: TextStyle(
                  color: _sub,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(weekKcal.length, (i) {
                final kcalRatio = (weekKcal[i] / maxKcal).clamp(0.0, 1.0);
                final isToday = i == todayPos;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (weekWorkouts[i] > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                weekWorkouts[i].clamp(0, 3),
                                    (_) => Container(
                                  width: 3,
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 0.5),
                                  decoration: const BoxDecoration(
                                    color: _P.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Container(
                          height: 30 * kcalRatio + 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isToday
                                  ? [_P.accent, _P.accentDark]
                                  : [
                                _P.accent.withOpacity(0.35),
                                _P.accent.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          days[(todayIdx - (todayPos - i) + 7) % 7],
                          style: TextStyle(
                            color: isToday ? _P.accent : _muted,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERIODS CARD
  // ============================================================

  Widget _periodsCard({
    required double weekKcalTotal,
    required double monthKcalTotal,
    required int weekWorkoutsTotal,
    required int monthWorkoutsTotal,
    required double totalVolume,
    required double weekKcalAvg,
    required double monthKcalAvg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: _P.violet,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'ПЕРИОДЫ',
                style: TextStyle(
                  color: _P.violet,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _periodStat(
                  label: 'НЕДЕЛЯ',
                  kcal: weekKcalTotal,
                  kcalAvg: weekKcalAvg,
                  workouts: weekWorkoutsTotal,
                  color: _P.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _periodStat(
                  label: 'МЕСЯЦ',
                  kcal: monthKcalTotal,
                  kcalAvg: monthKcalAvg,
                  workouts: monthWorkoutsTotal,
                  color: _P.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _P.ice.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.fitness_center_rounded,
                    color: _P.ice, size: 13),
                const SizedBox(width: 6),
                Text(
                  'Общий тоннаж:',
                  style: TextStyle(
                    color: _sub,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(totalVolume / 1000).toStringAsFixed(1)} т',
                  style: const TextStyle(
                    color: _P.ice,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodStat({
    required String label,
    required double kcal,
    required double kcalAvg,
    required int workouts,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.14), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$workouts',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  'трен.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmtKcal(kcal)} ккал',
            style: TextStyle(
              color: _sub,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ср. ${_fmtKcal(kcalAvg)}/д',
            style: TextStyle(
              color: _muted,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIP ROW
  // ============================================================

  Widget _tipRow(String tip, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.lightbulb_rounded, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: _text,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: _actionBtn(
              icon: Icons.fitness_center_rounded,
              label: 'Фитнес',
              color: _P.accent,
              onTap: _openFitness,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionBtn(
              icon: Icons.restaurant_rounded,
              label: 'Питание',
              color: _P.ice,
              onTap: _openNutrition,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SKELETON
  // ============================================================

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _border),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _P.accent,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _daysWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) {
      return 'дня';
    }
    return 'дней';
  }

  String _fmtKcal(double kcal) {
    if (kcal >= 1000) {
      final v = kcal / 1000;
      return '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}k';
    }
    return kcal.round().toString();
  }

  int _countUnlockedAchievements(
      FitnessProvider fp, int streak, int weekWorkouts) {
    int count = 0;
    final stats = fp.getStats();
    final total = (stats['totalWorkouts'] as num?)?.toInt() ?? 0;
    final volume = (stats['totalVolume'] as num?)?.toDouble() ?? 0;
    if (total >= 1) count++;
    if (total >= 10) count++;
    if (total >= 50) count++;
    if (total >= 100) count++;
    if (streak >= 3) count++;
    if (streak >= 7) count++;
    if (streak >= 30) count++;
    if (volume >= 10000) count++;
    if (volume >= 50000) count++;
    if (fp.completedSessions.isNotEmpty) count++;
    if (fp.completedSessions.length >= 3) count++;
    if (fp.activeTargets.isNotEmpty) count++;
    if (fp.photos.isNotEmpty) count++;
    if (fp.getTodayWellbeing() != null) count++;
    if (weekWorkouts >= 3) count++;
    if (weekWorkouts >= 5) count++;
    if (fp.programs.length >= 5) count++;
    return count;
  }

  int _daysSinceLastWorkout(FitnessProvider fp, DateTime today) {
    if (fp.logs.isEmpty) return 999;
    final completed = fp.logs
        .where((l) => l.status == WorkoutDayStatus.completed)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (completed.isEmpty) return 999;
    return today.difference(completed.first.date).inDays;
  }

  // ============================================================
  // TIPS ENGINE
  // ============================================================

  List<String> _buildTips({
    required int hour,
    required int weekday,
    required double kcalPct,
    required double proteinPct,
    required double fatPct,
    required double carbsPct,
    required double waterPct,
    required double proteinLeft,
    required int waterLeft,
    required double kcalDelta,
    required DailyNutritionSummary summary,
    required NutritionGoals goals,
    required bool hasSession,
    required bool hasCompletedToday,
    required bool isWorkoutActive,
    required ProgramSession? session,
    required WorkoutDay? todayProgramDay,
    required WorkoutProgram? activeProgram,
    required FitnessProvider fp,
    required int streak,
    required int weekWorkouts,
    required int prevWeekWorkouts,
    required int monthWorkouts,
    required double weekKcal,
    required double prevWeekKcal,
    required int totalWorkouts,
    required double totalVolume,
    required int achievements,
    required int daysSinceLastWorkout,
    required double avgRpe,
    required int completedPrograms,
    required int activeTargetsCount,
    required int recentPhotosCount,
    required bool hasWellbeingToday,
    required WellbeingNote? lastWellbeing,
  }) {
    final tips = <String>[];
    final isWeekend = weekday >= 6;
    final isMonday = weekday == 1;
    final isFriday = weekday == 5;
    final isMorning = hour >= 5 && hour < 12;
    final isNoon = hour >= 12 && hour < 15;
    final isAfternoon = hour >= 15 && hour < 18;
    final isEvening = hour >= 18 && hour < 22;
    final isNight = hour >= 22 || hour < 5;

    // ═══ КАЛОРИИ ═══
    if (kcalPct > 1.30) {
      final over = (summary.calories - goals.calories).round();
      tips.add('🚨 Перебор $over ккал — завтра держи дефицит');
    } else if (kcalPct > 1.15) {
      final over = (summary.calories - goals.calories).round();
      tips.add('🚨 Серьёзный профицит $over ккал — нужен лёгкий день');
    } else if (kcalPct > 1.05) {
      final over = (summary.calories - goals.calories).round();
      tips.add('🔥 Профицит $over ккал — 30 минут ходьбы сгладят');
    }

    if (kcalPct < 0.40 && isEvening) {
      final left = (goals.calories - summary.calories).round();
      tips.add('🚨 Сильный недоед — нужно ещё $left ккал');
    } else if (kcalPct < 0.55 && isEvening) {
      final left = (goals.calories - summary.calories).round();
      tips.add('🍽️ Мало поел — добавь $left ккал до сна');
    } else if (kcalPct < 0.70 && hour >= 21) {
      tips.add('🌙 Поздно, но поесть нужно — кефир или творог');
    }

    if (kcalDelta.abs() > 700 && hour >= 18) {
      final diff = kcalDelta > 0 ? 'больше' : 'меньше';
      tips.add('📊 Сегодня на ${kcalDelta.abs().round()} ккал $diff, чем вчера');
    }

    if (kcalPct >= 0.90 &&
        kcalPct <= 1.05 &&
        proteinPct >= 0.90 &&
        fatPct >= 0.80 &&
        fatPct <= 1.10 &&
        carbsPct >= 0.80 &&
        isEvening) {
      tips.add('🏆 Идеальный день по КБЖУ — так держать');
    }

    if (kcalPct < 0.15 && isNoon && summary.entriesCount <= 1) {
      tips.add('🍳 Полдня, а калорий почти 0 — поешь как следует');
    }

    if (kcalPct >= 0.25 &&
        kcalPct <= 0.35 &&
        isMorning &&
        summary.entriesCount > 0) {
      tips.add('✅ Отличный завтрак — правильный старт');
    }
    if (kcalPct >= 0.55 && kcalPct <= 0.65 && isNoon) {
      tips.add('✅ Обед по плану — держи темп');
    }
    if (kcalPct >= 0.80 && kcalPct <= 0.95 && isAfternoon) {
      tips.add('✅ В графике по калориям — оставь место для ужина');
    }

    // ═══ БЕЛОК ═══
    if (proteinPct < 0.25 && hour >= 12) {
      tips.add('🚨 Белка почти нет — нужно ${proteinLeft.round()} г срочно');
    } else if (proteinPct < 0.40 && hour >= 14) {
      tips.add('💪 Белка мало (${proteinLeft.round()} г) — творог, курица, яйца');
    } else if (proteinPct < 0.60 && hour >= 16) {
      tips.add('💪 Добери белок — ${proteinLeft.round()} г: рыба или творог');
    } else if (proteinPct < 0.80 && hour >= 19) {
      tips.add('💪 Белка не хватает (${proteinLeft.round()} г) — ужин с акцентом');
    } else if (proteinPct < 0.95 && hour >= 21) {
      tips.add('🥛 Казеин перед сном — ${proteinLeft.round()} г белка');
    }
    if (proteinPct > 1.40) {
      tips.add('🍖 Белка очень много — почкам тяжело');
    } else if (proteinPct > 1.20) {
      tips.add('🍖 Белка больше нормы — сбавь в следующем приёме');
    }
    if (proteinPct >= 0.90 && proteinPct <= 1.10 && isEvening) {
      tips.add('✅ Белок в норме — мышцы довольны');
    }
    if (hasCompletedToday && proteinPct < 0.60 && isAfternoon) {
      final need = proteinLeft.round();
      tips.add('🏋️ После тренировки нужно $need г белка — сейчас');
    }
    if (isWorkoutActive && proteinPct < 0.50) {
      tips.add('⚡ Во время тренировки белок не критичен — потом закрой 30 г');
    }
    if (proteinPct < 0.30 && isMorning && summary.entriesCount > 0) {
      tips.add('🥚 Добавь яйца или творог — утро без белка плохо');
    }

    // ═══ ЖИРЫ ═══
    if (fatPct > 1.40) {
      tips.add('🧈 Перебор жиров — лёгкий ужин');
    } else if (fatPct > 1.15 && isEvening) {
      tips.add('🧈 Жиров много — пропусти масло и жареное');
    }
    if (fatPct < 0.35 && isEvening) {
      tips.add('🥑 Мало жиров — орехи, авокадо или оливковое масло');
    } else if (fatPct < 0.50 && isAfternoon) {
      tips.add('🥑 Добавь полезных жиров — влияет на гормоны');
    }
    if (fatPct > 1.10 && carbsPct > 1.10) {
      tips.add('🍕 И жиры, и углеводы за шкалой — типичный читмил');
    }
    if (fatPct < 0.20 && kcalPct > 0.60) {
      tips.add('⚠️ Жиров почти нет — риск проблем с гормонами');
    }

    // ═══ УГЛЕВОДЫ ═══
    if (carbsPct > 1.40 && isEvening) {
      tips.add('🍞 Много углеводов вечером — перенеси на утро');
    } else if (carbsPct > 1.20 && isNight) {
      tips.add('🍞 Углеводы на ночь — отложатся в жир');
    }
    if (carbsPct < 0.35 && isAfternoon && !hasCompletedToday) {
      tips.add('🍌 Мало углеводов — силы для тренировки нужны');
    }
    if (carbsPct < 0.40 && isNight) {
      tips.add('⚡ Углеводов мало — энергии на завтра нет');
    }
    if (carbsPct < 0.50 && isWorkoutActive) {
      tips.add('⚡ Углеводов не хватит на всю тренировку');
    }
    if (carbsPct >= 0.60 &&
        carbsPct <= 0.85 &&
        isAfternoon &&
        !hasCompletedToday) {
      tips.add('✅ Углеводов достаточно для тренировки');
    }

    // ═══ ВОДА ═══
    if (waterPct < 0.15 && isNoon) {
      tips.add('🚨 Воды почти нет — выпей 500 мл сейчас');
    } else if (waterPct < 0.30 && isAfternoon) {
      tips.add('💧 Осталось пить $waterLeft мл — начни с 300');
    } else if (waterPct < 0.50 && isEvening) {
      tips.add('💧 Воды мало — до нормы ещё $waterLeft мл');
    } else if (waterPct < 0.75 && hour >= 20) {
      tips.add('💧 Финиш по воде — осталось $waterLeft мл');
    } else if (waterPct < 0.90 && hour >= 22) {
      tips.add('💧 Недопил воду — стакан перед сном');
    }
    if (waterPct > 1.50) {
      tips.add('💧 Воды слишком много — почки не справятся');
    }
    if (waterPct >= 1.00 && hour <= 18) {
      tips.add('✅ Вода на день закрыта — умница');
    }
    if (isWorkoutActive && waterPct < 0.60) {
      tips.add('⚡ Во время тренировки пей каждые 15 минут');
    }
    if (hasCompletedToday && waterPct < 0.70 && isAfternoon) {
      tips.add('🏋️ После тренировки нужна вода — минимум 500 мл');
    }

    // ═══ ПРИЁМЫ ПИЩИ ═══
    if (summary.entriesCount == 0 && hour >= 10 && hour <= 12) {
      tips.add('🌅 Пропустил завтрак — начни с белкового приёма');
    } else if (summary.entriesCount == 0 && hour >= 13) {
      tips.add('🚨 Ни одной записи за день — дневник вести важно');
    } else if (summary.entriesCount == 1 && hour >= 15) {
      tips.add('🍽️ Только 1 приём — добавь ещё 2-3 до конца дня');
    } else if (summary.entriesCount <= 2 && hour >= 20) {
      tips.add('🍽️ Мало приёмов — добавь перекус или ужин');
    }
    if (summary.entriesCount >= 9) {
      tips.add('🍴 ${summary.entriesCount} приёмов — попробуй 4-5 больших');
    } else if (summary.entriesCount >= 7 && isEvening) {
      tips.add('🍴 Много перекусов — собери их в один приём');
    }
    if (summary.entriesCount >= 3 &&
        summary.entriesCount <= 5 &&
        isEvening) {
      tips.add('✅ Отличный режим питания — ${summary.entriesCount} приёмов');
    }
    if (summary.entriesCount == 0 && isWorkoutActive) {
      tips.add('⚡ Тренировка без еды — риск гипогликемии');
    }

    // ═══ ТРЕНИРОВКА ═══
    if (isWorkoutActive) {
      tips.add('⚡ Тренировка идёт — отдых 60-90 сек между подходами');
    } else if (hasSession && todayProgramDay != null) {
      if (todayProgramDay.isRestDay) {
        tips.add('🛏️ День отдыха — мышцы растут в покое');
      } else if (todayProgramDay.exercises.isNotEmpty) {
        if (isMorning) {
          tips.add(
              '🏋️ Утро — тренировка дня ждёт (${todayProgramDay.exercises.length} упр)');
        } else if (isNoon) {
          tips.add('🏋️ Идеальное время для тренировки');
        } else if (isAfternoon) {
          tips.add('🏋️ Ещё не тренировался — до вечера успей');
        } else if (isEvening) {
          tips.add('🚨 Вечер, а тренировки дня не было');
        } else {
          tips.add('🚨 Поздно, но тренировку дня можно сделать короткой');
        }
      }
    } else if (hasCompletedToday) {
      tips.add('✅ Тренировка выполнена — восстановись');
    } else if (!hasSession && isNoon) {
      tips.add('⚡ Программы нет — начни или сделай свободную');
    } else if (!hasSession && isEvening) {
      tips.add('⚡ Вечер — самое время для тренировки');
    }

    // ═══ STREAK ═══
    if (streak == 1) {
      tips.add('🔥 Стрик начался — 1 день');
    } else if (streak == 3) {
      tips.add('🔥 3 дня подряд — привычка формируется');
    } else if (streak == 5) {
      tips.add('🔥 5 дней — половина недели позади');
    } else if (streak == 7) {
      tips.add('🔥🔥 Неделя без пропусков — это режим');
    } else if (streak == 14) {
      tips.add('💎 14 дней streak — ты машина');
    } else if (streak == 21) {
      tips.add('🏆 21 день — привычка закреплена');
    } else if (streak == 30) {
      tips.add('🏆 Месяц подряд — уважение');
    } else if (streak == 60) {
      tips.add('👑 60 дней — нереальный режим');
    } else if (streak == 100) {
      tips.add('👑 100 дней! Легенда');
    } else if (streak > 0 && streak % 7 == 0) {
      tips.add('🔥 Серия $streak дней — не сбавляй');
    }
    if (streak >= 3 && !hasCompletedToday && isEvening) {
      tips.add('⚡ Не сбей серию ($streak) — тренировка сегодня');
    }

    // ═══ ПАУЗА ═══
    if (daysSinceLastWorkout >= 30 && daysSinceLastWorkout < 999) {
      tips.add(
          '🚨 $daysSinceLastWorkout дней без тренировок — начни с 10 минут');
    } else if (daysSinceLastWorkout >= 14 && daysSinceLastWorkout < 999) {
      tips.add('🚨 2 недели без тренировок — срочно в зал');
    } else if (daysSinceLastWorkout >= 7 && daysSinceLastWorkout < 999) {
      tips.add('😴 Неделя отдыха — пора вернуться');
    } else if (daysSinceLastWorkout >= 3 && daysSinceLastWorkout < 999) {
      tips.add(
          '🏋️ $daysSinceLastWorkout дня без тренировок — мышцы ждут');
    } else if (daysSinceLastWorkout == 2) {
      tips.add('💪 Два дня отдыха — оптимально для восстановления');
    } else if (daysSinceLastWorkout == 1) {
      tips.add('✅ Вчера тренировался — сегодня можно восстановиться');
    }

    // ═══ НЕДЕЛЯ / МЕСЯЦ ═══
    if (weekWorkouts >= 6) {
      tips.add(
          '💎 $weekWorkouts тренировок за неделю — следи за восстановлением');
    } else if (weekWorkouts >= 5) {
      tips.add('🔥 $weekWorkouts тренировок за неделю — режим зверя');
    } else if (weekWorkouts == 4) {
      tips.add('✅ 4 тренировки за неделю — оптимально');
    } else if (weekWorkouts == 3) {
      tips.add('👍 3 тренировки за неделю — норма');
    } else if (weekWorkouts == 2 && isFriday) {
      tips.add('📅 Только 2 тренировки — успей сделать ещё одну');
    } else if (weekWorkouts < 2 && isWeekend) {
      tips.add('📅 Выходные — шанс добрать до 3 тренировок');
    }
    if (weekWorkouts > prevWeekWorkouts && prevWeekWorkouts > 0) {
      tips.add('📈 Тренировок больше, чем на прошлой неделе');
    } else if (weekWorkouts < prevWeekWorkouts && prevWeekWorkouts > 0) {
      tips.add('📉 Тренировок меньше, чем на прошлой неделе');
    }
    if (monthWorkouts >= 20) {
      tips.add('🏆 $monthWorkouts тренировок за месяц — элитный режим');
    } else if (monthWorkouts >= 15) {
      tips.add('🔥 $monthWorkouts тренировок за месяц — отличный темп');
    } else if (monthWorkouts >= 12) {
      tips.add('✅ $monthWorkouts тренировок за месяц — держишь план');
    } else if (monthWorkouts < 4 && hour >= 18) {
      tips.add('📉 Всего $monthWorkouts тренировок за месяц — включись');
    }
    if (weekKcal > prevWeekKcal * 1.15 && prevWeekKcal > 0) {
      final pct = ((weekKcal / prevWeekKcal - 1) * 100).round();
      tips.add('📈 Калорий на $pct% больше, чем на прошлой');
    } else if (weekKcal < prevWeekKcal * 0.85 && prevWeekKcal > 0) {
      final pct = ((1 - weekKcal / prevWeekKcal) * 100).round();
      tips.add('📉 Калорий на $pct% меньше, чем на прошлой');
    }

    // ═══ ПРОГРАММА ═══
    if (session != null && activeProgram != null) {
      final progress = session.progressPercent;
      final name = activeProgram.name;
      if (progress >= 0.95) {
        tips.add('🎯 «$name» почти готова — финиш');
      } else if (progress >= 0.90) {
        tips.add('🎯 Программа на ${(progress * 100).round()}% — финишируй');
      } else if (progress >= 0.75) {
        tips.add('📊 75% программы позади — последний рывок');
      } else if (progress >= 0.50 && progress < 0.55) {
        tips.add('📊 Половина «$name» позади');
      } else if (progress < 0.20 && session.currentDayIndex >= 1) {
        tips.add('📊 Начало «$name» — не сбавляй темп');
      }
    }
    if (completedPrograms == 1) {
      tips.add('🏆 Первая программа завершена — с почином');
    } else if (completedPrograms >= 3) {
      tips.add('🏆 $completedPrograms программ завершено — коллекция растёт');
    }
    if (session == null && totalWorkouts >= 5 && hour >= 12) {
      tips.add('⚡ Нет активной программы — выбери новую или создай');
    }

    // ═══ ЦЕЛИ ═══
    if (activeTargetsCount == 0 && totalWorkouts >= 5) {
      tips.add('🎯 Нет активных целей — поставь новую, это мотивирует');
    } else if (activeTargetsCount >= 5) {
      tips.add('🎯 $activeTargetsCount активных целей — сфокусируйся');
    }
    final upcomingDeadline = fp.activeTargets
        .where((t) => t.deadline != null)
        .map((t) => MapEntry(t, t.daysUntilDeadline ?? 999))
        .where((e) => e.value >= 0 && e.value <= 7)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    if (upcomingDeadline.isNotEmpty) {
      final t = upcomingDeadline.first;
      if (t.value == 0) {
        tips.add('⏰ Дедлайн цели «${t.key.name}» — сегодня!');
      } else if (t.value == 1) {
        tips.add('⏰ «${t.key.name}» — завтра дедлайн');
      } else if (t.value <= 3) {
        tips.add(
            '⏰ «${t.key.name}» — ${t.value} ${_daysWord(t.value)} до дедлайна');
      } else {
        tips.add('⏰ «${t.key.name}» — неделя до дедлайна');
      }
    }
    final almostDone = fp.activeTargets
        .where((t) => t.progressPercent >= 0.80 && !t.isCompleted)
        .toList();
    if (almostDone.isNotEmpty) {
      final t = almostDone.first;
      tips.add(
          '🎯 «${t.name}» на ${(t.progressPercent * 100).round()}% — осталось чуть-чуть');
    }
    final overdue = fp.activeTargets.where((t) => t.isOverdue).toList();
    if (overdue.isNotEmpty) {
      tips.add('🚨 Просрочена цель «${overdue.first.name}» — продли или заверши');
    }
    final staleTargets = fp.activeTargets.where((t) {
      if (t.entries.isEmpty) {
        return t.createdAt.difference(DateTime.now()).inDays.abs() > 7;
      }
      final last = t.entries
          .map((e) => e.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return DateTime.now().difference(last).inDays >= 14;
    }).toList();
    if (staleTargets.isNotEmpty) {
      tips.add('📌 По цели «${staleTargets.first.name}» нет записей давно');
    }

    // ═══ АЧИВКИ ═══
    if (achievements >= 15) {
      tips.add('👑 $achievements ачивок — почти собрал всё');
    } else if (achievements >= 10) {
      tips.add('🏆 $achievements ачивок — солидная коллекция');
    } else if (achievements >= 5) {
      tips.add('🏆 $achievements ачивок — неплохо');
    } else if (achievements >= 1 && achievements <= 2) {
      tips.add('🏆 Первые ачивки — начало положено');
    }

    // ═══ ФОТО ═══
    if (recentPhotosCount == 0 && totalWorkouts >= 20) {
      tips.add('📸 Давно не было фото прогресса — сделай сегодня');
    } else if (recentPhotosCount == 0 && totalWorkouts >= 5) {
      tips.add('📸 Попробуй фотоотчёт — визуально прогресс виднее');
    }
    if (recentPhotosCount >= 3) {
      tips.add('📸 $recentPhotosCount фото за 2 недели — молодец');
    } else if (recentPhotosCount >= 1) {
      tips.add('📸 Есть свежее фото — сравни с прошлым');
    }
    if (fp.photos.length >= 10) {
      tips.add('📸 10+ фото — есть большая история прогресса');
    }

    // ═══ САМОЧУВСТВИЕ ═══
    if (!hasWellbeingToday && isEvening) {
      tips.add('🧠 Не забудь отметить самочувствие перед сном');
    }
    if (lastWellbeing != null) {
      if (lastWellbeing.energyLevel <= 2) {
        tips.add('🚨 Энергия на минимуме — отдохни, поешь углеводов');
      } else if (lastWellbeing.energyLevel <= 4) {
        tips.add('😴 Низкая энергия — добавь сложные углеводы');
      } else if (lastWellbeing.energyLevel >= 9) {
        tips.add('⚡ Энергия на максимуме — используй');
      }
      if (lastWellbeing.sleepQuality <= 2) {
        tips.add('🚨 Плохой сон — сегодня без тяжёлых весов');
      } else if (lastWellbeing.sleepQuality <= 4) {
        tips.add('💤 Сон плохой — тренировка лёгкая');
      } else if (lastWellbeing.sleepQuality >= 9) {
        tips.add('💤 Отличный сон — можно интенсивно');
      }
      if (lastWellbeing.motivationLevel >= 9) {
        tips.add('🔥 Мотивация на пике — время сделать рекорд');
      } else if (lastWellbeing.motivationLevel <= 3) {
        tips.add('😐 Мотивация низкая — маленькая цель на сегодня');
      }
      if (lastWellbeing.painAreas.isNotEmpty) {
        tips.add(
            '⚠️ Есть боли: ${lastWellbeing.painAreas.join(", ")} — аккуратнее');
      }
    }

    // ═══ RPE / ТОННАЖ ═══
    if (avgRpe >= 9.0 && weekWorkouts >= 3) {
      tips.add('🚨 RPE ${avgRpe.toStringAsFixed(1)} — слишком тяжело, снизь');
    } else if (avgRpe >= 8.5 && weekWorkouts >= 3) {
      tips.add('😮 RPE ${avgRpe.toStringAsFixed(1)} — близко к отказу');
    } else if (avgRpe > 0 && avgRpe <= 4.5 && weekWorkouts >= 3) {
      tips.add('💪 RPE ${avgRpe.toStringAsFixed(1)} — можно добавить вес');
    } else if (avgRpe > 0 && avgRpe <= 6 && weekWorkouts >= 5) {
      tips.add('💪 Небольшой RPE — есть запас');
    }
    if (totalVolume >= 500000) {
      tips.add('🏋️ Тоннаж ${(totalVolume / 1000).toStringAsFixed(0)} т — космос');
    } else if (totalVolume >= 100000) {
      tips.add(
          '🏋️ Общий тоннаж ${(totalVolume / 1000).toStringAsFixed(0)} т — серьёзно');
    } else if (totalVolume >= 50000) {
      tips.add('💪 Тоннаж ${(totalVolume / 1000).toStringAsFixed(0)} т — растёт');
    }

    // ═══ ДЕНЬ НЕДЕЛИ ═══
    if (isMonday && isMorning && streak == 0) {
      tips.add('📅 Понедельник — отличный день начать');
    }
    if (isMonday && isMorning && streak >= 3) {
      tips.add('📅 Новая неделя со стриком $streak — продолжай');
    }
    if (isFriday && streak >= 5 && isEvening) {
      tips.add('🔥 Пятница со стриком $streak — заверши неделю сильно');
    }
    if (isFriday && weekWorkouts < 3 && isAfternoon) {
      tips.add('📅 Пятница — добери до 3 тренировок');
    }
    if (isWeekend && kcalPct > 0.80 && isEvening) {
      tips.add('🍕 Выходной — следи за калориями');
    }
    if (isWeekend && weekWorkouts >= 4) {
      tips.add('🔥 Выходные и $weekWorkouts трен. за неделю — топ');
    }
    if (isWeekend && isMorning && !hasCompletedToday) {
      tips.add('☀️ Утро выходного — лучший момент для тренировки');
    }
    if (isNight && !hasWellbeingToday) {
      tips.add('🌙 Не забудь про сон — 7-8 часов минимум');
    }

    // ═══ МИЛСТОУНЫ ═══
    if (totalWorkouts == 0 && hour >= 12) {
      tips.add('🏁 Ещё ни одной тренировки — начни с 15 минут');
    } else if (totalWorkouts == 1) {
      tips.add('🏁 Первая тренировка — с началом!');
    } else if (totalWorkouts == 5) {
      tips.add('💪 5 тренировок — привычка формируется');
    } else if (totalWorkouts == 10) {
      tips.add('💪 10 тренировок — новый уровень');
    } else if (totalWorkouts == 25) {
      tips.add('🔥 25 тренировок — опыт растёт');
    } else if (totalWorkouts == 50) {
      tips.add('💎 50 тренировок — элита');
    } else if (totalWorkouts == 100) {
      tips.add('👑 100 тренировок — нереально');
    } else if (totalWorkouts == 200) {
      tips.add('👑 200 тренировок — бог');
    } else if (totalWorkouts > 0 && totalWorkouts % 50 == 0) {
      tips.add('🏆 $totalWorkouts тренировок — круглая цифра');
    }

    // ═══ КОМБО ═══
    if (kcalPct > 0.95 && proteinPct < 0.6 && isEvening) {
      tips.add('🚨 Калорий достаточно, но белка мало — только белок на ужин');
    }
    if (kcalPct < 0.5 && proteinPct > 1.0 && isEvening) {
      tips.add('⚠️ Мало калорий, но много белка — добавь углеводы');
    }
    if (streak >= 5 && kcalPct >= 0.9 && proteinPct >= 0.9 && isEvening) {
      tips.add('🏆 Стрик $streak и день идеален — двойной успех');
    }
    if (hasCompletedToday && proteinPct < 0.7 && isAfternoon) {
      tips.add('🚨 После тренировки белка мало — нужно закрыть сейчас');
    }
    if (hasCompletedToday && waterPct < 0.5 && isAfternoon) {
      tips.add('💧 После тренировки много воды ушло — пей');
    }
    if (daysSinceLastWorkout >= 3 && weekWorkouts >= 2 && isAfternoon) {
      tips.add('📉 Давно не тренировался — не растеряй форму');
    }
    if (activeTargetsCount >= 1 && streak >= 3 && weekWorkouts >= 3) {
      tips.add('🎯 Стрик $streak, цели, тренировки — ты в потоке');
    }
    if (avgRpe >= 7.5 && daysSinceLastWorkout <= 1 && isMorning) {
      tips.add('😮 Вчера тяжёлая тренировка — сегодня отдохни');
    }
    if (kcalPct > 1.1 && waterPct < 0.5 && isEvening) {
      tips.add('⚠️ Профицит и мало воды — завтра разгрузка');
    }
    if (isWeekend && kcalPct > 1.0 && weekWorkouts < 3) {
      tips.add('🍕 Выходной, профицит, тренировок мало — завтра в зал');
    }
    if (proteinPct < 0.5 && kcalPct < 0.5 && isEvening) {
      tips.add('🚨 Мало еды и мало белка — 40 г белка + сложные углеводы');
    }
    if (hasWellbeingToday &&
        lastWellbeing != null &&
        lastWellbeing.energyLevel <= 4 &&
        isAfternoon) {
      tips.add('😴 Низкая энергия — отложи тяжёлую тренировку');
    }

    // FALLBACK
    if (tips.isEmpty) {
      tips.add('🌱 Хороший день — продолжай в том же духе');
    }

    // Дедупликация
    final seen = <String>{};
    final unique = <String>[];
    for (final t in tips) {
      final key = t.replaceAll(RegExp(r'\d+'), '');
      if (seen.add(key)) unique.add(t);
    }

    // Сортировка по приоритету
    unique.sort((a, b) => _tipPriority(b).compareTo(_tipPriority(a)));
    return unique;
  }

  // ============================================================
  // PRIORITY — без эмодзи в условиях
  // ============================================================

  int _tipPriority(String tip) {
    // === 100: КРИТИЧНО ===
    if (tip.contains('Перебор') && tip.contains('ккал')) return 100;
    if (tip.contains('Серьёзный профицит')) return 99;
    if (tip.contains('недоед')) return 99;
    if (tip.contains('Белка почти нет')) return 98;
    if (tip.contains('Воды почти нет')) return 98;
    if (tip.contains('Просрочена цель')) return 97;
    if (tip.contains('Ни одной записи')) return 96;
    if (tip.contains('слишком тяжело')) return 96;
    if (tip.contains('без тренировок')) return 95;
    if (tip.contains('Мало еды и мало белка')) return 95;
    if (tip.contains('Есть боли')) return 94;
    if (tip.contains('Энергия на минимуме')) return 94;
    if (tip.contains('Вечер, а тренировки')) return 93;
    if (tip.contains('Поздно, но тренировку')) return 92;
    if (tip.contains('Плохой сон')) return 91;

    // === 90: ТРЕНИРОВКА СЕЙЧАС ===
    if (tip.contains('Тренировка идёт')) return 91;
    if (tip.contains('Во время тренировки')) return 90;
    if (tip.contains('Тренировка без еды')) return 89;

    // === 85: СИЛЬНЫЙ ДЕФИЦИТ ===
    if (tip.contains('Белка мало')) return 88;
    if (tip.contains('Добери белок')) return 86;
    if (tip.contains('Осталось пить')) return 85;
    if (tip.contains('После тренировки нужно')) return 87;
    if (tip.contains('После тренировки белка мало')) return 86;
    if (tip.contains('После тренировки много воды')) return 84;
    if (tip.contains('Финиш по воде')) return 82;
    if (tip.contains('Недопил воду')) return 81;

    // === 80: ТРЕНИРОВКА ДНЯ ===
    if (tip.contains('Тренировка дня ждёт')) return 80;
    if (tip.contains('Утро — тренировка')) return 79;
    if (tip.contains('Идеальное время для тренировки')) return 78;
    if (tip.contains('Ещё не тренировался')) return 78;
    if (tip.contains('Не сбей серию')) return 80;
    if (tip.contains('Вечер — самое время')) return 77;
    if (tip.contains('День отдыха')) return 75;
    if (tip.contains('Тренировка выполнена')) return 70;
    if (tip.contains('Программы нет')) return 65;

    // === 85: ЦЕЛИ ===
    if (tip.contains('Дедлайн цели')) return 88;
    if (tip.contains('завтра дедлайн')) return 85;
    if (tip.contains('до дедлайна')) return 82;
    if (tip.contains('неделя до дедлайна')) return 70;
    if (tip.contains('осталось чуть-чуть')) return 76;
    if (tip.contains('нет записей давно')) return 74;
    if (tip.contains('активных целей')) return 60;
    if (tip.contains('Нет активных целей')) return 55;

    // === 75: УМЕРЕННЫЕ ===
    if (tip.contains('Белка не хватает')) return 73;
    if (tip.contains('Казеин')) return 72;
    if (tip.contains('Белок в норме')) return 20;

    // === 70: STREAK MILESTONES ===
    if (tip.contains('100 дней')) return 72;
    if (tip.contains('60 дней')) return 71;
    if (tip.contains('Месяц подряд')) return 70;
    if (tip.contains('21 день')) return 69;
    if (tip.contains('14 дней streak')) return 68;
    if (tip.contains('Неделя без пропусков')) return 67;
    if (tip.contains('5 дней — половина')) return 66;
    if (tip.contains('3 дня подряд')) return 65;
    if (tip.contains('Серия')) return 64;
    if (tip.contains('Стрик начался')) return 63;

    // === 62: МИЛСТОУНЫ ===
    if (tip.contains('200 тренировок')) return 68;
    if (tip.contains('100 тренировок')) return 67;
    if (tip.contains('50 тренировок')) return 66;
    if (tip.contains('25 тренировок')) return 64;
    if (tip.contains('10 тренировок')) return 62;
    if (tip.contains('5 тренировок')) return 61;
    if (tip.contains('Первая тренировка')) return 60;
    if (tip.contains('Ещё ни одной')) return 59;
    if (tip.contains('круглая цифра')) return 58;

    // === 60: КОМБО ===
    if (tip.contains('Калорий достаточно')) return 66;
    if (tip.contains('двойной успех')) return 62;
    if (tip.contains('ты в потоке')) return 61;
    if (tip.contains('Мало калорий, но много белка')) return 60;
    if (tip.contains('Вчера тяжёлая тренировка')) return 59;
    if (tip.contains('Профицит и мало воды')) return 58;
    if (tip.contains('Жиров почти нет')) return 58;
    if (tip.contains('Низкая энергия — отложи')) return 57;

    // === 55: ПРОГРАММА ===
    if (tip.contains('почти готова')) return 57;
    if (tip.contains('Программа на')) return 56;
    if (tip.contains('75% программы')) return 55;
    if (tip.contains('Половина')) return 54;
    if (tip.contains('Начало')) return 53;
    if (tip.contains('Нет активной программы')) return 52;
    if (tip.contains('программ завершено')) return 51;

    // === 50: ОТКЛОНЕНИЯ ПИТАНИЯ ===
    if (tip.contains('Профицит')) return 50;
    if (tip.contains('Много углеводов вечером')) return 49;
    if (tip.contains('Углеводы на ночь')) return 48;
    if (tip.contains('Перебор жиров')) return 47;
    if (tip.contains('Жиров много')) return 46;
    if (tip.contains('Белка очень много')) return 45;
    if (tip.contains('Белка больше нормы')) return 44;
    if (tip.contains('И жиры, и углеводы')) return 43;
    if (tip.contains('Выходной, профицит')) return 42;
    if (tip.contains('Выходной — следи')) return 41;

    // === 45: СРЕДНИЕ ПИТАНИЕ ===
    if (tip.contains('Мало поел')) return 45;
    if (tip.contains('Мало приёмов')) return 40;
    if (tip.contains('Только 1 приём')) return 39;
    if (tip.contains('приёмов — попробуй')) return 38;
    if (tip.contains('Много перекусов')) return 37;
    if (tip.contains('Пропустил завтрак')) return 50;
    if (tip.contains('Полдня')) return 49;
    if (tip.contains('Добавь яйца')) return 44;
    if (tip.contains('Поздно, но поесть')) return 47;
    if (tip.contains('Углеводов мало')) return 44;
    if (tip.contains('Углеводов не хватит')) return 43;
    if (tip.contains('Мало углеводов')) return 42;
    if (tip.contains('Мало жиров')) return 41;
    if (tip.contains('Добавь полезных жиров')) return 40;

    // === 35: ПАУЗА ===
    if (tip.contains('Неделя отдыха')) return 38;
    if (tip.contains('Низкая энергия — добавь')) return 37;
    if (tip.contains('дня без тренировок')) return 35;
    if (tip.contains('Два дня отдыха')) return 34;
    if (tip.contains('Вчера тренировался')) return 33;
    if (tip.contains('Пятница')) return 32;
    if (tip.contains('Выходные — шанс')) return 31;
    if (tip.contains('Выходные и')) return 30;
    if (tip.contains('Понедельник')) return 29;
    if (tip.contains('Новая неделя')) return 28;
    if (tip.contains('Тренировок меньше')) return 27;

    // === 25: RPE / ТОННАЖ ===
    if (tip.contains('RPE') && tip.contains('слишком тяжело')) return 60;
    if (tip.contains('RPE') && tip.contains('близко к отказу')) return 35;
    if (tip.contains('RPE') && tip.contains('можно добавить вес')) return 34;
    if (tip.contains('Небольшой RPE')) return 30;
    if (tip.contains('Тоннаж') && tip.contains('космос')) return 28;
    if (tip.contains('Общий тоннаж')) return 27;
    if (tip.contains('Тоннаж') && tip.contains('растёт')) return 26;
    if (tip.contains('тренировок за месяц')) return 25;
    if (tip.contains('тренировок за неделю')) return 24;
    if (tip.contains('4 тренировки за неделю')) return 23;
    if (tip.contains('3 тренировки за неделю')) return 22;
    if (tip.contains('Только 2 тренировки')) return 21;
    if (tip.contains('Всего') && tip.contains('тренировок за месяц')) return 20;

    // === 20: ФОТО / САМОЧУВСТВИЕ ===
    if (tip.contains('Давно не было фото')) return 22;
    if (tip.contains('Попробуй фотоотчёт')) return 21;
    if (tip.contains('фото за 2 недели')) return 20;
    if (tip.contains('Есть свежее фото')) return 19;
    if (tip.contains('10+ фото')) return 18;
    if (tip.contains('Не забудь отметить')) return 20;
    if (tip.contains('Отличный сон')) return 18;
    if (tip.contains('Сон плохой')) return 17;
    if (tip.contains('Мотивация на пике')) return 16;
    if (tip.contains('Мотивация низкая')) return 15;
    if (tip.contains('Энергия на максимуме')) return 14;
    if (tip.contains('Не забудь про сон')) return 13;

    // === 12: АЧИВКИ / ПОХВАЛА ===
    if (tip.contains('ачивок') && tip.contains('почти собрал')) return 15;
    if (tip.contains('ачивок') && tip.contains('солидная')) return 14;
    if (tip.contains('Первые ачивки')) return 13;
    if (tip.contains('Идеальный день')) return 12;
    if (tip.contains('Белок в норме')) return 11;
    if (tip.contains('Вода на день закрыта')) return 10;
    if (tip.contains('Отличный завтрак')) return 10;
    if (tip.contains('Обед по плану')) return 10;
    if (tip.contains('В графике')) return 10;
    if (tip.contains('Отличный режим питания')) return 10;
    if (tip.contains('Углеводов достаточно')) return 10;
    if (tip.contains('Тренировок больше')) return 12;

    // === 5: FALLBACK ===
    return 5;
  }

  // ============================================================
  // COLOR — без эмодзи в условиях
  // ============================================================

  Color _tipColor(String tip) {
    // Магма (красный) — критичное
    if (tip.contains('Перебор') ||
        tip.contains('недоед') ||
        tip.contains('слишком тяжело') ||
        tip.contains('Просрочена цель') ||
        tip.contains('Есть боли') ||
        tip.contains('Ни одной записи') ||
        tip.contains('без тренировок') ||
        tip.contains('Мало еды и мало белка') ||
        tip.contains('Вечер, а тренировки') ||
        tip.contains('Поздно, но тренировку') ||
        tip.contains('Энергия на минимуме') ||
        tip.contains('Плохой сон') ||
        tip.contains('Белка почти нет') ||
        tip.contains('Воды почти нет') ||
        tip.contains('Серьёзный профицит') ||
        tip.contains('И жиры, и углеводы') ||
        tip.contains('Мало калорий, но много белка') ||
        tip.contains('Профицит и мало воды') ||
        tip.contains('Жиров почти нет') ||
        tip.contains('Тренировка без еды') ||
        tip.contains('Белка очень много')) {
      return _P.magma;
    }

    // Вода (голубой)
    if (tip.contains('вод') ||
        tip.contains('Воды') ||
        tip.contains('Недопил') ||
        tip.contains('Осталось пить') ||
        tip.contains('Финиш по воде') ||
        tip.contains('После тренировки много воды')) {
      return _P.ice;
    }

    // Белок / жиры (violet)
    if (tip.contains('Казеин') ||
        tip.contains('Мало жиров') ||
        tip.contains('Добавь полезных жиров') ||
        tip.contains('День отдыха') ||
        tip.contains('Сон плохой') ||
        tip.contains('Мотивация низкая') ||
        tip.contains('Низкая энергия')) {
      return _P.violet;
    }

    // Зелёный — позитив
    if (tip.contains('Белок в норме') ||
        tip.contains('Вода на день закрыта') ||
        tip.contains('Отличный завтрак') ||
        tip.contains('Обед по плану') ||
        tip.contains('В графике') ||
        tip.contains('Отличный режим питания') ||
        tip.contains('Углеводов достаточно') ||
        tip.contains('Тренировка выполнена') ||
        tip.contains('Идеальный день') ||
        tip.contains('Тренировок больше') ||
        tip.contains('14 дней streak') ||
        tip.contains('50 тренировок') ||
        tip.contains('100 тренировок') ||
        tip.contains('200 тренировок') ||
        tip.contains('5 тренировок') ||
        tip.contains('10 тренировок') ||
        tip.contains('25 тренировок') ||
        tip.contains('Вчера тренировался') ||
        tip.contains('Два дня отдыха') ||
        tip.contains('Есть свежее фото') ||
        tip.contains('фото за 2 недели') ||
        tip.contains('10+ фото')) {
      return _P.green;
    }

    // Оранжевый (accent) — тренировки
    if (tip.contains('Тренировка') ||
        tip.contains('трениров')) {
      return _P.accent;
    }

    // Голубой (blue) — фото / день недели
    if (tip.contains('фото') ||
        tip.contains('Понедельник') ||
        tip.contains('Пятница') ||
        tip.contains('Выходные')) {
      return _P.blue;
    }

    // Плазма (жёлтый) — цели, ачивки, милстоуны
    if (tip.contains('Дедлайн') ||
        tip.contains('цель') ||
        tip.contains('цели') ||
        tip.contains('ачивок') ||
        tip.contains('Ачивк') ||
        tip.contains('Первые') ||
        tip.contains('21 день') ||
        tip.contains('Месяц подряд') ||
        tip.contains('60 дней') ||
        tip.contains('100 дней')) {
      return _P.plasma;
    }

    return _P.plasma;
  }
}