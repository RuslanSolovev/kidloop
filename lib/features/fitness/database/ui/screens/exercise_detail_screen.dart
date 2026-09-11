// features/fitness/ui/screens/exercise_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/enums.dart';
import '../../../models/fitness_models.dart';
import '../../../models/helpers.dart';
import '../../../providers/fitness_provider.dart';
import 'package:fl_chart/fl_chart.dart';

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

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  final bool isDark;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    this.isDark = false,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final progressRecords = provider.getExerciseProgress(widget.exercise.id);
    final trendLine = FitnessHelpers.calculateTrendLine(progressRecords);
    final lastRecord = provider.getLastProgress(widget.exercise.id);

    final accent = widget.exercise.muscleGroups.isNotEmpty
        ? widget.exercise.muscleGroups.first.color
        : _Power.volt;

    return Scaffold(
      backgroundColor: _Power.bg(isDark),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: _Power.bg(isDark).withOpacity(0.85),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: 60,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: _Power.textPrimary(isDark),
                    size: 22,
                  ),
                ),
              ),
            ),
            title: Text(
              widget.exercise.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: _Power.textPrimary(isDark),
              ),
            ),
            centerTitle: true,
            actions: [
              if (widget.exercise.isCustom)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showEditDialog(context, isDark, provider);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _Power.volt.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: _Power.volt,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Large title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.exercise.isCustom
                        ? 'МОЁ УПРАЖНЕНИЕ'
                        : 'УПРАЖНЕНИЕ',
                    style: const TextStyle(
                      color: _Power.volt,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.exercise.name,
                    style: TextStyle(
                      color: _Power.textPrimary(isDark),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      height: 1.08,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hero card
          SliverToBoxAdapter(
            child: _buildHeroCard(isDark, accent),
          ),

          // Muscle groups
          if (widget.exercise.muscleGroups.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildMuscleGroups(isDark),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Stats
          SliverToBoxAdapter(
            child: _buildStatsCards(
              isDark,
              lastRecord,
              progressRecords,
              trendLine,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Tabs
          SliverToBoxAdapter(
            child: _buildTabs(isDark),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Tab content
          SliverToBoxAdapter(
            child: SizedBox(
              height: 420,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(isDark),
                  _buildProgressTab(isDark, provider, progressRecords, trendLine),
                  _buildHistoryTab(isDark, progressRecords),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  // =====================================================================
  // HERO CARD
  // =====================================================================

  Widget _buildHeroCard(bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.18),
            accent.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withOpacity(0.3),
          width: 0.8,
        ),
        boxShadow: _Power.softGlow(accent, strength: 0.12),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(24),
              boxShadow: _Power.softGlow(accent, strength: 0.25),
            ),
            child: Icon(
              _getExerciseIcon(widget.exercise.exerciseType),
              size: 42,
              color: accent,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeroChip(
                isDark,
                '${widget.exercise.exerciseType.emoji} ${widget.exercise.exerciseType.displayName}',
                accent,
              ),
              if (widget.exercise.isCustom) ...[
                const SizedBox(width: 8),
                _buildHeroChip(isDark, 'МОЁ', _Power.volt),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(bool isDark, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: accent,
        ),
      ),
    );
  }

  // =====================================================================
  // MUSCLE GROUPS
  // =====================================================================

  Widget _buildMuscleGroups(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.exercise.muscleGroups.map((muscle) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: muscle.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: muscle.color.withOpacity(0.28),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(muscle.emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  muscle.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                    color: muscle.color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // =====================================================================
  // STATS CARDS
  // =====================================================================

  Widget _buildStatsCards(
      bool isDark,
      ProgressRecord? lastRecord,
      List<ProgressRecord> progressRecords,
      TrendLine trendLine,
      ) {
    final best1RM = progressRecords.isNotEmpty
        ? progressRecords
        .map((r) => r.estimated1RM)
        .reduce((a, b) => a > b ? a : b)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            isDark,
            icon: Icons.trending_up_rounded,
            title: 'ЛУЧШИЙ 1RM',
            value: best1RM > 0 ? best1RM.toStringAsFixed(1) : '—',
            unit: best1RM > 0 ? 'кг' : '',
            color: _Power.green,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            isDark,
            icon: Icons.fitness_center_rounded,
            title: 'ПОСЛЕДНИЙ',
            value: lastRecord != null
                ? '${lastRecord.bestWeight.toStringAsFixed(0)}×${lastRecord.bestReps}'
                : '—',
            unit: lastRecord != null ? 'кг' : '',
            color: _Power.volt,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            isDark,
            icon: Icons.trending_up_rounded,
            title: 'ПРОГНОЗ',
            value: trendLine.slope > 0
                ? '+${(trendLine.slope * 30).toStringAsFixed(1)}'
                : '—',
            unit: trendLine.slope > 0 ? '/мес' : '',
            color: _Power.ice,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      bool isDark, {
        required IconData icon,
        required String title,
        required String value,
        required String unit,
        required Color color,
      }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _Power.card(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(0.18),
            width: 0.8,
          ),
          boxShadow: _Power.softGlow(color, strength: 0.06),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      height: 1,
                      color: _Power.textPrimary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 1),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _Power.textTertiary(isDark),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: _Power.textTertiary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // TABS
  // =====================================================================

  Widget _buildTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _Power.card2(isDark),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: _Power.textSecondary(isDark),
          indicator: BoxDecoration(
            color: _Power.volt,
            borderRadius: BorderRadius.circular(11),
            boxShadow: _Power.softGlow(_Power.volt, strength: 0.3),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          tabs: const [
            Tab(text: 'ИНФО'),
            Tab(text: 'ПРОГРЕСС'),
            Tab(text: 'ИСТОРИЯ'),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // INFO TAB
  // =====================================================================

  Widget _buildInfoTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.exercise.description.isNotEmpty)
            _buildInfoSection(
              isDark,
              icon: Icons.description_rounded,
              title: 'ОПИСАНИЕ',
              content: widget.exercise.description,
              color: _Power.volt,
            ),

          if (widget.exercise.techniqueTips != null &&
              widget.exercise.techniqueTips!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoSection(
              isDark,
              icon: Icons.lightbulb_rounded,
              title: 'СОВЕТЫ ПО ТЕХНИКЕ',
              content: widget.exercise.techniqueTips!,
              color: _Power.plasma,
            ),
          ],

          if (widget.exercise.commonMistakes != null &&
              widget.exercise.commonMistakes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoSection(
              isDark,
              icon: Icons.warning_rounded,
              title: 'ЧАСТЫЕ ОШИБКИ',
              content: widget.exercise.commonMistakes!,
              color: _Power.red,
            ),
          ],

          if (widget.exercise.videoUrl != null &&
              widget.exercise.videoUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildVideoLink(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(
      bool isDark, {
        required IconData icon,
        required String title,
        required String content,
        Color? color,
      }) {
    final accent = color ?? _Power.volt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(18),
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
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: _Power.textPrimary(isDark).withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLink(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // Логика открытия видео уже есть в проекте
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Power.card(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _Power.separator(isDark), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _Power.red.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _Power.softGlow(_Power.red, strength: 0.2),
              ),
              child: const Icon(
                Icons.play_circle_rounded,
                color: _Power.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ВИДЕО-ИНСТРУКЦИЯ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: _Power.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Открыть в браузере',
                    style: TextStyle(
                      fontSize: 12,
                      color: _Power.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              color: _Power.textTertiary(isDark),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // PROGRESS TAB
  // =====================================================================

  Widget _buildProgressTab(
      bool isDark,
      FitnessProvider provider,
      List<ProgressRecord> records,
      TrendLine trendLine,
      ) {
    if (records.isEmpty) {
      return _buildEmptyChart(isDark);
    }

    final spots = <FlSpot>[];
    final firstDate = records.first.date;

    for (int i = 0; i < records.length; i++) {
      final x = records[i].date.difference(firstDate).inDays.toDouble();
      final y = records[i].estimated1RM;
      spots.add(FlSpot(x, y));
    }

    final predictionSpots = <FlSpot>[];
    if (trendLine.slope > 0) {
      final lastX = spots.last.x;
      for (int i = 1; i <= 30; i++) {
        predictionSpots.add(FlSpot(
          lastX + i,
          trendLine.predict((lastX + i).toInt()),
        ));
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Power.separator(isDark), width: 0.5),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) => FlLine(
              color: _Power.separator(isDark),
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _Power.textTertiary(isDark),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 7,
                getTitlesWidget: (value, meta) {
                  final date = firstDate.add(Duration(days: value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${date.day}.${date.month}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _Power.textTertiary(isDark),
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _Power.volt,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: _Power.volt,
                      strokeWidth: 2,
                      strokeColor: _Power.bg(isDark),
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _Power.volt.withOpacity(0.25),
                    _Power.volt.withOpacity(0.0),
                  ],
                ),
              ),
            ),
            if (predictionSpots.isNotEmpty)
              LineChartBarData(
                spots: predictionSpots,
                isCurved: true,
                color: _Power.volt.withOpacity(0.35),
                barWidth: 2,
                dashArray: [5, 5],
                dotData: const FlDotData(show: false),
              ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) =>
                  _Power.card2(isDark),
              tooltipRoundedRadius: 12,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} кг',
                    const TextStyle(
                      color: _Power.volt,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChart(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _Power.volt.withOpacity(0.10),
              shape: BoxShape.circle,
              boxShadow: _Power.softGlow(_Power.volt, strength: 0.15),
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              size: 36,
              color: _Power.volt,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'НЕТ ДАННЫХ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: _Power.volt,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Прогресс появится здесь',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: _Power.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Начните тренироваться!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _Power.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // HISTORY TAB
  // =====================================================================

  Widget _buildHistoryTab(bool isDark, List<ProgressRecord> records) {
    if (records.isEmpty) {
      return Center(
        child: Text(
          'История появится после тренировок',
          style: TextStyle(
            fontSize: 13,
            color: _Power.textSecondary(isDark),
          ),
        ),
      );
    }

    final sortedRecords = List<ProgressRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedRecords.length,
      itemBuilder: (context, index) {
        final record = sortedRecords[index];
        return _buildHistoryRow(isDark, record, index);
      },
    );
  }

  Widget _buildHistoryRow(
      bool isDark,
      ProgressRecord record,
      int index,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Power.separator(isDark), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _Power.volt.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _Power.softGlow(_Power.volt, strength: 0.15),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: _Power.volt,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.date.day.toString().padLeft(2, '0')}.${record.date.month.toString().padLeft(2, '0')}.${record.date.year}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: _Power.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.totalSets} подх. • ${record.totalVolume.toStringAsFixed(0)} кг',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _Power.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record.bestWeight.toStringAsFixed(0)}×${record.bestReps}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: _Power.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '1RM ${record.estimated1RM.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _Power.volt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // EDIT DIALOG — iOS Sheet
  // =====================================================================

  void _showEditDialog(
      BuildContext context,
      bool isDark,
      FitnessProvider provider,
      ) {
    final nameController = TextEditingController(text: widget.exercise.name);
    final descController =
    TextEditingController(text: widget.exercise.description);
    final tipsController =
    TextEditingController(text: widget.exercise.techniqueTips ?? '');
    final mistakesController =
    TextEditingController(text: widget.exercise.commonMistakes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: _Power.card(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _Power.textTertiary(isDark),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'РЕДАКТИРОВАТЬ',
                style: TextStyle(
                  color: _Power.volt,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Упражнение',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: _Power.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 20),

              _buildField(
                controller: nameController,
                label: 'НАЗВАНИЕ',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: descController,
                label: 'ОПИСАНИЕ',
                isDark: isDark,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: tipsController,
                label: 'СОВЕТЫ',
                isDark: isDark,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: mistakesController,
                label: 'ОШИБКИ',
                isDark: isDark,
                maxLines: 2,
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _Power.textSecondary(isDark),
                          side: BorderSide(color: _Power.separator(isDark)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Отмена',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final updated = widget.exercise.copyWith(
                            name: nameController.text.trim(),
                            description: descController.text.trim(),
                            techniqueTips:
                            tipsController.text.trim().isNotEmpty
                                ? tipsController.text.trim()
                                : null,
                            commonMistakes:
                            mistakesController.text.trim().isNotEmpty
                                ? mistakesController.text.trim()
                                : null,
                          );
                          await provider.updateExercise(updated);
                          if (ctx.mounted) Navigator.pop(ctx);
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
                        child: const Text(
                          'СОХРАНИТЬ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Delete
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    _confirmDelete(context, isDark, provider);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _Power.red,
                    backgroundColor: _Power.red.withOpacity(0.10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'УДАЛИТЬ УПРАЖНЕНИЕ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              color: _Power.textTertiary(isDark),
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _Power.textPrimary(isDark),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _Power.card2(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  // =====================================================================
  // DELETE CONFIRM — iOS Alert
  // =====================================================================

  void _confirmDelete(
      BuildContext context,
      bool isDark,
      FitnessProvider provider,
      ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 60),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? _Power.darkCard2 : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  children: [
                    Text(
                      'Удалить упражнение?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _Power.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '«${widget.exercise.name}» будет удалено безвозвратно',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _Power.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 0.5, color: _Power.separator(isDark)),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: const Text(
                          'Отмена',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            color: _Power.volt,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 0.5,
                    height: 50,
                    color: _Power.separator(isDark),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await provider.deleteExercise(widget.exercise.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: const Text(
                          'Удалить',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _Power.red,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // HELPERS
  // =====================================================================

  IconData _getExerciseIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.strength:
        return Icons.fitness_center_rounded;
      case ExerciseType.cardio:
        return Icons.directions_run_rounded;
      case ExerciseType.bodyweight:
        return Icons.accessibility_new_rounded;
      case ExerciseType.boxing:
        return Icons.sports_mma_rounded;
      case ExerciseType.yoga:
        return Icons.self_improvement_rounded;
      case ExerciseType.other:
        return Icons.more_horiz_rounded;
    }
  }
}