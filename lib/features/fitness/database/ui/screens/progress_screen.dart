import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../models/helpers.dart';
import '../../../providers/fitness_provider.dart';
import 'exercise_detail_screen.dart';

class ProgressScreen extends StatefulWidget {
  final bool isDark;
  final bool isCompact;

  const ProgressScreen({super.key, this.isDark = false, this.isCompact = false});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
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
            e.muscleGroups.any((m) => m.displayName.toLowerCase().contains(query))).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: _buildAppBar(isDark),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.white38 : Colors.grey.shade500,
                  indicator: BoxDecoration(color: const Color(0xFFFF6B35), borderRadius: BorderRadius.circular(10)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.all(3),
                  tabs: const [
                    Tab(text: 'Упражнения'),
                    Tab(text: 'Тоннаж'),
                    Tab(text: 'Мышцы'),
                  ],
                ),
              ),
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSearchOverlay(isDark, provider),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      elevation: 0,
      title: TextField(
        controller: _searchController,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Поиск упражнения...',
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 18),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(bool isDark, FitnessProvider provider) {
    return Container(
      color: isDark ? const Color(0xFF0A0D14).withValues(alpha: 0.95) : const Color(0xFFF2F5F9).withValues(alpha: 0.95),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D24) : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск упражнения...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 22),
                suffixIcon: IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Ничего не найдено',
                      style: TextStyle(fontSize: 16, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final ex = _searchResults[index];
                final summary = provider.getExerciseDetailedSummary(ex.id);
                return Card(
                  color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ex.muscleGroups.isNotEmpty
                          ? ex.muscleGroups.first.color.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      child: Text(ex.exerciseType.emoji, style: const TextStyle(fontSize: 16)),
                    ),
                    title: Text(ex.name,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: summary.totalWorkouts > 0
                        ? Text('${summary.totalWorkouts} тренировок • ${summary.totalSets} подходов',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500))
                        : Text('Нет данных',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.grey.shade400)),
                    trailing: summary.totalWorkouts > 0
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Макс: ${summary.maxWeight.toStringAsFixed(0)} кг',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFFF6B35))),
                        Text('Тоннаж: ${(summary.totalVolume / 1000).toStringAsFixed(1)}k кг',
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                      ],
                    )
                        : null,
                    onTap: () {
                      _searchController.clear();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(exercise: ex, isDark: isDark),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseProgress(bool isDark, FitnessProvider provider) {
    final exercises = provider.exercises.where((e) => provider.getExerciseProgress(e.id).isNotEmpty).toList();

    if (exercises.isEmpty) {
      return _buildEmptyState(isDark, 'Нет данных о прогрессе\nНачните тренироваться!');
    }

    exercises.sort((a, b) {
      final aProgress = provider.getExerciseProgress(a.id).length;
      final bProgress = provider.getExerciseProgress(b.id).length;
      return bProgress.compareTo(aProgress);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final summary = provider.getExerciseDetailedSummary(exercise.id);
        final progress = provider.getExerciseProgress(exercise.id);
        final lastRecord = progress.last;
        final trendLine = FitnessHelpers.calculateTrendLine(progress);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: exercise.muscleGroups.isNotEmpty
                    ? exercise.muscleGroups.first.color.withValues(alpha: 0.15)
                    : const Color(0xFFFF6B35).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(exercise.exerciseType.emoji, style: const TextStyle(fontSize: 22))),
            ),
            title: Text(exercise.name,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('${summary.totalWorkouts} тренировок • ${summary.totalSets} подходов',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(isDark, summary, lastRecord, progress),
                    const SizedBox(height: 16),
                    _buildModernChart(isDark, 'Динамика 1RM', progress, trendLine, true),
                    const SizedBox(height: 16),
                    _buildModernChart(isDark, 'Объём тренировки', progress, trendLine, false),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExerciseDetailScreen(exercise: exercise, isDark: isDark),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('Подробная история'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
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

  Widget _buildStatsGrid(bool isDark, ExerciseDetailedSummary summary, ProgressRecord lastRecord, List<ProgressRecord> progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1D24), const Color(0xFF0F1115)]
              : [const Color(0xFFF8F9FA), const Color(0xFFE9ECEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatBox(isDark, 'Мин. вес', '${summary.minWeight.toStringAsFixed(0)} кг',
                  summary.minDate != null ? '${summary.minDate!.day}.${summary.minDate!.month}.${summary.minDate!.year}' : '',
                  const Color(0xFF2196F3)),
              const SizedBox(width: 8),
              _buildStatBox(isDark, 'Макс. вес', '${summary.maxWeight.toStringAsFixed(0)} кг',
                  summary.maxDate != null ? '${summary.maxDate!.day}.${summary.maxDate!.month}.${summary.maxDate!.year}' : '',
                  const Color(0xFF4CAF50)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatBox(isDark, 'Средний вес', '${summary.avgWeight.toStringAsFixed(0)} кг', '', const Color(0xFFFF9800)),
              const SizedBox(width: 8),
              _buildStatBox(isDark, 'Последний 1RM', '${lastRecord.estimated1RM.toStringAsFixed(0)} кг',
                  '${lastRecord.date.day}.${lastRecord.date.month}.${lastRecord.date.year}', const Color(0xFFFF6B35)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatBox(isDark, 'Всего тренировок', '${summary.totalWorkouts}', '', const Color(0xFF9C27B0)),
              const SizedBox(width: 8),
              _buildStatBox(isDark, 'Всего подходов', '${summary.totalSets}', '', const Color(0xFF00BCD4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(bool isDark, String label, String value, String date, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accentColor)),
            if (date.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(date, style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernChart(bool isDark, String title, List<ProgressRecord> progress, TrendLine trendLine, bool show1RM) {
    if (progress.length < 2) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Text('Недостаточно данных для графика',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 12)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
              if (trendLine.slope != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trendLine.slope > 0 ? const Color(0xFF4CAF50).withValues(alpha: 0.1) : const Color(0xFFF44336).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendLine.slope > 0 ? Icons.trending_up : Icons.trending_down,
                          size: 14, color: trendLine.slope > 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336)),
                      const SizedBox(width: 4),
                      Text(
                        '${trendLine.slope > 0 ? "+" : ""}${(trendLine.slope * 30).toStringAsFixed(1)}/мес',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: trendLine.slope > 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: adjustedMinY,
                maxY: adjustedMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        show1RM ? '${value.toInt()}' : '${(value / 1000).toStringAsFixed(1)}k',
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (spots.last.x / 5).clamp(1, 30).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final date = firstDate.add(Duration(days: value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('${date.day}.${date.month}',
                              style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: const Color(0xFFFF6B35),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length < 15,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFFFF6B35),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFF6B35).withValues(alpha: 0.3),
                          const Color(0xFFFF6B35).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  if (predictionSpots.isNotEmpty)
                    LineChartBarData(
                      spots: predictionSpots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                      barWidth: 2,
                      dashArray: [5, 5],
                      dotData: const FlDotData(show: false),
                    ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipColor: (spot) => isDark ? const Color(0xFF1A1D24) : Colors.white,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} ${show1RM ? "кг" : "кг"}',
                          TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
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

  Widget _buildTonnageProgress(bool isDark, FitnessProvider provider) {
    final tonnageMap = provider.getTonnageByExercise();

    if (tonnageMap.isEmpty) {
      return _buildEmptyState(isDark, 'Нет данных о тоннаже\nЗавершите первую тренировку!');
    }

    final entries = tonnageMap.entries.toList()..sort((a, b) => b.value.totalVolume.compareTo(a.value.totalVolume));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final exData = provider.exercises.firstWhere((e) => e.id == entry.key, orElse: () => Exercise(id: '', name: 'Удалено'));
        final info = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
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
                      color: exData.muscleGroups.isNotEmpty
                          ? exData.muscleGroups.first.color.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(exData.exerciseType.emoji, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exData.name,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 2),
                        Text('${info.totalWorkouts} тренировок',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${(info.totalVolume / 1000).toStringAsFixed(1)}k кг',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFFFF6B35))),
                      Text('общий тоннаж', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Макс. за тренировку',
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                        Text('${info.maxSingleWorkoutVolume.toStringAsFixed(0)} кг',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                    if (info.maxDate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Дата', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                          Text('${info.maxDate!.day}.${info.maxDate!.month}.${info.maxDate!.year}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700)),
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

  Widget _buildMuscleProgress(bool isDark, FitnessProvider provider) {
    final muscleMap = provider.getTonnageByMuscle();

    if (muscleMap.isEmpty) {
      return _buildEmptyState(isDark, 'Нет данных о нагрузке на мышцы');
    }

    // ИСПРАВЛЕНО: используем fold<double> вместо reduce, чтобы избежать проблемы с num → double
    final maxVolume = muscleMap.values.fold<double>(0, (max, s) => s.totalVolume > max ? s.totalVolume : max);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFFFF6B35).withValues(alpha: 0.1),
                const Color(0xFFFF6B35).withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics_rounded, color: const Color(0xFFFF6B35), size: 20),
                    const SizedBox(width: 8),
                    Text('Объём по группам мышц',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('За всё время тренировок',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...MuscleGroup.values
              .where((m) => m != MuscleGroup.fullBody && m != MuscleGroup.cardio_vascular && m != MuscleGroup.flexibility)
              .map((muscle) {
            final stats = muscleMap[muscle];
            // ИСПРАВЛЕНО: используем totalVolume вместо volume
            final volume = stats?.totalVolume ?? 0.0;
            final progress = maxVolume > 0 ? volume / maxVolume : 0.0;

            if (volume == 0) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: muscle.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text(muscle.emoji, style: const TextStyle(fontSize: 18))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(muscle.displayName,
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                            if (stats != null)
                              Text('${stats.totalWorkouts} тренировок • ${stats.totalSets} подходов',
                                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Text('${(volume / 1000).toStringAsFixed(1)}k кг',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: muscle.color)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.05, 1.0),
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(muscle.color),
                      minHeight: 8,
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

  Widget _buildEmptyState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart_rounded, size: 80, color: isDark ? Colors.white12 : Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.grey.shade500),
          ),
          const SizedBox(height: 12),
          Text('Завершите тренировку, чтобы увидеть статистику',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.grey.shade400)),
        ],
      ),
    );
  }
}