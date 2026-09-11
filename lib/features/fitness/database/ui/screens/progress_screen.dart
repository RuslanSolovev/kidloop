// features/fitness/ui/screens/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../models/helpers.dart';
import '../../../providers/fitness_provider.dart';
import 'exercise_detail_screen.dart';

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

class ProgressScreen extends StatefulWidget {
  final bool isDark;
  final bool isCompact;

  const ProgressScreen({
    super.key,
    this.isDark = false,
    this.isCompact = false,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Exercise> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final provider = context.read<FitnessProvider>();
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        _searchResults = provider.exercises.where((e) =>
        e.name.toLowerCase().contains(query) ||
            e.description.toLowerCase().contains(query) ||
            e.muscleGroups
                .any((m) => m.displayName.toLowerCase().contains(query))).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();

    return Scaffold(
      backgroundColor: _Power.bg(isDark),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(isDark),
                _buildTabBar(isDark),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildExerciseProgress(isDark, provider),
                      _buildTonnageProgress(isDark, provider),
                      _buildMuscleProgress(isDark, provider),
                    ],
                  ),
                ),
              ],
            ),
            if (_isSearching)
              Positioned.fill(
                child: _buildSearchOverlay(isDark, provider),
              ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // HEADER
  // =====================================================================

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ПРОГРЕСС',
                      style: TextStyle(
                        color: _Power.volt,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Аналитика',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.1,
                        color: _Power.textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Search
          Container(
            decoration: BoxDecoration(
              color: _Power.card(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _Power.separator(isDark),
                width: 0.5,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _Power.textPrimary(isDark),
              ),
              decoration: InputDecoration(
                hintText: 'Поиск упражнения…',
                hintStyle: TextStyle(
                  color: _Power.textTertiary(isDark),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _Power.textTertiary(isDark),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _searchController.clear();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _Power.textTertiary(isDark)
                          .withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: _Power.textSecondary(isDark),
                      size: 14,
                    ),
                  ),
                )
                    : null,
                filled: false,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // TAB BAR
  // =====================================================================

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
            boxShadow: _Power.softGlow(_Power.volt, strength: 0.35),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          tabs: const [
            Tab(text: 'УПРАЖНЕНИЯ'),
            Tab(text: 'ТОННАЖ'),
            Tab(text: 'МЫШЦЫ'),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // SEARCH OVERLAY
  // =====================================================================

  Widget _buildSearchOverlay(bool isDark, FitnessProvider provider) {
    return Container(
      color: _Power.bg(isDark),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: _Power.card(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _Power.volt.withOpacity(0.4),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _Power.textPrimary(isDark),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Поиск…',
                    hintStyle: TextStyle(
                      color: _Power.textTertiary(isDark),
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _Power.volt,
                      size: 20,
                    ),
                    suffixIcon: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _searchController.clear();
                      },
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color:
                          _Power.textTertiary(isDark).withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: _Power.textSecondary(isDark),
                          size: 14,
                        ),
                      ),
                    ),
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _searchResults.isEmpty
                  ? _buildSearchEmpty(isDark)
                  : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final ex = _searchResults[index];
                  final summary =
                  provider.getExerciseDetailedSummary(ex.id);
                  final accent = ex.muscleGroups.isNotEmpty
                      ? ex.muscleGroups.first.color
                      : _Power.volt;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _searchController.clear();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(
                            exercise: ex,
                            isDark: isDark,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _Power.card(isDark),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _Power.separator(isDark),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              ex.exerciseType.emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color:
                                    _Power.textPrimary(isDark),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                if (summary.totalWorkouts > 0)
                                  Text(
                                    '${summary.totalWorkouts} трен. • ${summary.totalSets} подх.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _Power.textTertiary(
                                          isDark),
                                    ),
                                  )
                                else
                                  Text(
                                    'НЕТ ДАННЫХ',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                      color: _Power.textTertiary(
                                          isDark),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (summary.totalWorkouts > 0)
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${summary.maxWeight.toStringAsFixed(0)} кг',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    color: _Power.volt,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'ТОННАЖ ${(summary.totalVolume / 1000).toStringAsFixed(1)}k',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color:
                                    _Power.textTertiary(isDark),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
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

  Widget _buildSearchEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: _Power.volt.withOpacity(0.10),
              shape: BoxShape.circle,
              boxShadow: _Power.softGlow(_Power.volt, strength: 0.15),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: _Power.volt,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'ПОИСК',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: _Power.volt,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ничего не найдено',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: _Power.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте изменить запрос',
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
  // EXERCISE PROGRESS TAB
  // =====================================================================

  Widget _buildExerciseProgress(bool isDark, FitnessProvider provider) {
    final exercises = provider.exercises
        .where((e) => provider.getExerciseProgress(e.id).isNotEmpty)
        .toList();

    if (exercises.isEmpty) {
      return _buildEmptyState(
        isDark,
        'НЕТ ДАННЫХ',
        'Начните тренироваться',
        'Прогресс появится здесь',
      );
    }

    exercises.sort((a, b) {
      final aProgress = provider.getExerciseProgress(a.id).length;
      final bProgress = provider.getExerciseProgress(b.id).length;
      return bProgress.compareTo(aProgress);
    });

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final summary = provider.getExerciseDetailedSummary(exercise.id);
        final progress = provider.getExerciseProgress(exercise.id);
        final lastRecord = progress.last;
        final trendLine = FitnessHelpers.calculateTrendLine(progress);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _Power.card(isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _Power.separator(isDark),
              width: 0.5,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              childrenPadding:
              const EdgeInsets.fromLTRB(12, 0, 12, 12),
              iconColor: _Power.volt,
              collapsedIconColor: _Power.textSecondary(isDark),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: exercise.muscleGroups.isNotEmpty
                      ? exercise.muscleGroups.first.color
                      .withOpacity(0.14)
                      : _Power.volt.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: _Power.softGlow(
                    exercise.muscleGroups.isNotEmpty
                        ? exercise.muscleGroups.first.color
                        : _Power.volt,
                    strength: 0.15,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  exercise.exerciseType.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              title: Text(
                exercise.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: _Power.textPrimary(isDark),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${summary.totalWorkouts} ТРЕН. • ${summary.totalSets} ПОДХ.',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: _Power.textTertiary(isDark),
                  ),
                ),
              ),
              children: [
                _buildStatsGrid(isDark, summary, lastRecord, progress),
                const SizedBox(height: 14),
                _buildModernChart(
                    isDark, 'ДИНАМИКА 1RM', progress, trendLine, true),
                const SizedBox(height: 14),
                _buildModernChart(
                    isDark, 'ОБЪЁМ ТРЕНИРОВКИ', progress, trendLine, false),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExerciseDetailScreen(
                            exercise: exercise,
                            isDark: isDark,
                          ),
                        ),
                      );
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
                        Icon(Icons.history_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'ПОДРОБНАЯ ИСТОРИЯ',
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
        );
      },
    );
  }

  Widget _buildStatsGrid(
      bool isDark,
      ExerciseDetailedSummary summary,
      ProgressRecord lastRecord,
      List<ProgressRecord> progress,
      ) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatBox(
              isDark,
              'МИН',
              '${summary.minWeight.toStringAsFixed(0)} кг',
              summary.minDate != null
                  ? '${summary.minDate!.day}.${summary.minDate!.month}'
                  : '',
              _Power.ice,
            ),
            const SizedBox(width: 8),
            _buildStatBox(
              isDark,
              'МАКС',
              '${summary.maxWeight.toStringAsFixed(0)} кг',
              summary.maxDate != null
                  ? '${summary.maxDate!.day}.${summary.maxDate!.month}'
                  : '',
              _Power.green,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatBox(
              isDark,
              'СРЕДНЕЕ',
              '${summary.avgWeight.toStringAsFixed(0)} кг',
              '',
              _Power.plasma,
            ),
            const SizedBox(width: 8),
            _buildStatBox(
              isDark,
              '1RM',
              '${lastRecord.estimated1RM.toStringAsFixed(0)} кг',
              '${lastRecord.date.day}.${lastRecord.date.month}',
              _Power.volt,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatBox(
              isDark,
              'ТРЕНИРОВОК',
              '${summary.totalWorkouts}',
              '',
              _Power.magma,
            ),
            const SizedBox(width: 8),
            _buildStatBox(
              isDark,
              'ПОДХОДОВ',
              '${summary.totalSets}',
              '',
              _Power.lime,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox(
      bool isDark,
      String label,
      String value,
      String date,
      Color accentColor,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _Power.card2(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withOpacity(0.2),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: _Power.textTertiary(isDark),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1,
                color: accentColor,
              ),
            ),
            if (date.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                date,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _Power.textTertiary(isDark),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernChart(
      bool isDark,
      String title,
      List<ProgressRecord> progress,
      TrendLine trendLine,
      bool show1RM,
      ) {
    if (progress.length < 2) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _Power.card2(isDark),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: _Power.textTertiary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Недостаточно данных',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _Power.textSecondary(isDark),
              ),
            ),
          ],
        ),
      );
    }

    final spots = <FlSpot>[];
    final firstDate = progress.first.date;
    double maxY = 0;
    double minY = double.infinity;

    for (final record in progress) {
      final x = record.date.difference(firstDate).inDays.toDouble();
      final y = show1RM ? record.estimated1RM : record.totalVolume;
      spots.add(FlSpot(x, y));
      if (y > maxY) maxY = y;
      if (y < minY) minY = y;
    }

    final predictionSpots = <FlSpot>[];
    if (trendLine.slope != 0 && spots.isNotEmpty) {
      final lastX = spots.last.x;
      for (int i = 1; i <= 14; i++) {
        final predictedY = trendLine.predict((lastX + i).toInt());
        predictionSpots.add(FlSpot(lastX + i, predictedY));
        if (predictedY > maxY) maxY = predictedY;
      }
    }

    final yRange = maxY - minY;
    final padding = yRange * 0.1;
    final adjustedMaxY = maxY + padding;
    final adjustedMinY = minY > padding ? minY - padding : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Power.card2(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _Power.separator(isDark),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: _Power.textPrimary(isDark),
                ),
              ),
              const Spacer(),
              if (trendLine.slope != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (trendLine.slope > 0
                        ? _Power.green
                        : _Power.red)
                        .withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendLine.slope > 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color: trendLine.slope > 0
                            ? _Power.green
                            : _Power.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trendLine.slope > 0 ? "+" : ""}${(trendLine.slope * 30).toStringAsFixed(1)}/мес',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          height: 1,
                          color: trendLine.slope > 0
                              ? _Power.green
                              : _Power.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minY: adjustedMinY,
                maxY: adjustedMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: _Power.separator(isDark),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (value, meta) => Text(
                        show1RM
                            ? '${value.toInt()}'
                            : '${(value / 1000).toStringAsFixed(1)}k',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _Power.textTertiary(isDark),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (spots.last.x / 5).clamp(1, 30).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final date = firstDate
                            .add(Duration(days: value.toInt()));
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
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: _Power.volt,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length < 15,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: _Power.bg(isDark),
                            strokeWidth: 2,
                            strokeColor: _Power.volt,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _Power.volt.withOpacity(0.3),
                          _Power.volt.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  if (predictionSpots.isNotEmpty)
                    LineChartBarData(
                      spots: predictionSpots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: _Power.volt.withOpacity(0.4),
                      barWidth: 2,
                      dashArray: [5, 5],
                      dotData: const FlDotData(show: false),
                    ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    getTooltipColor: (spot) => _Power.card(isDark),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} кг',
                          const TextStyle(
                            color: _Power.volt,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // TONNAGE TAB
  // =====================================================================

  Widget _buildTonnageProgress(bool isDark, FitnessProvider provider) {
    final tonnageMap = provider.getTonnageByExercise();

    if (tonnageMap.isEmpty) {
      return _buildEmptyState(
        isDark,
        'ТОННАЖ',
        'Нет данных',
        'Завершите первую тренировку',
      );
    }

    final entries = tonnageMap.entries.toList()
      ..sort((a, b) => b.value.totalVolume.compareTo(a.value.totalVolume));

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final exData = provider.exercises.firstWhere(
              (e) => e.id == entry.key,
          orElse: () => Exercise(id: '', name: 'Удалено'),
        );
        final info = entry.value;
        final accent = exData.muscleGroups.isNotEmpty
            ? exData.muscleGroups.first.color
            : _Power.volt;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _Power.card(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _Power.separator(isDark),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow:
                      _Power.softGlow(accent, strength: 0.15),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      exData.exerciseType.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exData.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: _Power.textPrimary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${info.totalWorkouts} ТРЕНИРОВОК',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: _Power.textTertiary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(info.totalVolume / 1000).toStringAsFixed(1)}k',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          height: 1,
                          color: _Power.volt,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'КГ',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: _Power.textTertiary(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _Power.card2(isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'МАКС ЗА ТРЕНИРОВКУ',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: _Power.textTertiary(isDark),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${info.maxSingleWorkoutVolume.toStringAsFixed(0)} кг',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              height: 1,
                              color: _Power.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (info.maxDate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ДАТА',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: _Power.textTertiary(isDark),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${info.maxDate!.day}.${info.maxDate!.month.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              height: 1,
                              color: _Power.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================================================================
  // MUSCLE TAB
  // =====================================================================

  Widget _buildMuscleProgress(bool isDark, FitnessProvider provider) {
    final muscleMap = provider.getTonnageByMuscle();

    if (muscleMap.isEmpty) {
      return _buildEmptyState(
        isDark,
        'МЫШЦЫ',
        'Нет данных',
        'Завершите первую тренировку',
      );
    }

    final maxVolume = muscleMap.values.fold<double>(
      0,
          (max, s) => s.totalVolume > max ? s.totalVolume : max,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _Power.volt.withOpacity(0.10),
                  _Power.volt.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _Power.volt.withOpacity(0.2),
                width: 0.8,
              ),
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
                        color: _Power.volt.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: _Power.volt,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'ОБЪЁМ ПО ГРУППАМ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                        color: _Power.volt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'За всё время тренировок',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _Power.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...MuscleGroup.values
              .where((m) =>
          m != MuscleGroup.fullBody &&
              m != MuscleGroup.cardio_vascular &&
              m != MuscleGroup.flexibility)
              .map((muscle) {
            final stats = muscleMap[muscle];
            final volume = stats?.totalVolume ?? 0.0;
            final progress = maxVolume > 0 ? volume / maxVolume : 0.0;

            if (volume == 0) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Power.card(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _Power.separator(isDark),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: muscle.color.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: _Power.softGlow(muscle.color,
                              strength: 0.2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          muscle.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              muscle.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: _Power.textPrimary(isDark),
                              ),
                            ),
                            if (stats != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                '${stats.totalWorkouts} ТРЕН. • ${stats.totalSets} ПОДХ.',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color:
                                  _Power.textTertiary(isDark),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${(volume / 1000).toStringAsFixed(1)}k',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          height: 1,
                          color: muscle.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.05, 1.0),
                      backgroundColor: _Power.separator(isDark),
                      valueColor:
                      AlwaysStoppedAnimation<Color>(muscle.color),
                      minHeight: 6,
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

  // =====================================================================
  // EMPTY STATE
  // =====================================================================

  Widget _buildEmptyState(
      bool isDark,
      String caps,
      String title,
      String subtitle,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _Power.volt.withOpacity(0.10),
                shape: BoxShape.circle,
                boxShadow: _Power.softGlow(_Power.volt, strength: 0.15),
              ),
              child: const Icon(
                Icons.show_chart_rounded,
                size: 40,
                color: _Power.volt,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              caps,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
                color: _Power.volt,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                color: _Power.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _Power.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}