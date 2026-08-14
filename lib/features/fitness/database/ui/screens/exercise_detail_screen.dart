// features/fitness/ui/screens/exercise_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/enums.dart';
import '../../../models/fitness_models.dart';
import '../../../models/helpers.dart';
import '../../../providers/fitness_provider.dart';
import 'package:fl_chart/fl_chart.dart';

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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.exercise.name,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          if (widget.exercise.isCustom)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Color(0xFFFF6B35)),
              onPressed: () => _showEditDialog(context, isDark, provider),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение и тип
            _buildHeader(isDark),
            const SizedBox(height: 16),

            // Группы мышц
            _buildMuscleGroups(isDark),
            const SizedBox(height: 20),

            // Статистика
            _buildStatsCards(isDark, lastRecord, progressRecords, trendLine),
            const SizedBox(height: 20),

            // Табы
            _buildTabs(isDark),
            const SizedBox(height: 16),

            // Содержимое табов
            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(isDark),
                  _buildProgressTab(isDark, provider, progressRecords, trendLine),
                  _buildHistoryTab(isDark, progressRecords),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.exercise.muscleGroups.isNotEmpty
                ? widget.exercise.muscleGroups.first.color.withOpacity(0.2)
                : const Color(0xFFFF6B35).withOpacity(0.2),
            widget.exercise.muscleGroups.isNotEmpty
                ? widget.exercise.muscleGroups.first.color.withOpacity(0.05)
                : const Color(0xFFFF6B35).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          // Иконка и тип
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: (widget.exercise.muscleGroups.isNotEmpty
                  ? widget.exercise.muscleGroups.first.color
                  : const Color(0xFFFF6B35)).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getExerciseIcon(widget.exercise.exerciseType),
              size: 40,
              color: widget.exercise.muscleGroups.isNotEmpty
                  ? widget.exercise.muscleGroups.first.color
                  : const Color(0xFFFF6B35),
            ),
          ),
          const SizedBox(height: 12),
          // Тип и теги
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.exercise.exerciseType.emoji} ${widget.exercise.exerciseType.displayName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
              if (widget.exercise.isCustom) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Моё',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleGroups(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.exercise.muscleGroups.map((muscle) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: muscle.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: muscle.color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(muscle.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                muscle.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muscle.color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatsCards(
      bool isDark,
      ProgressRecord? lastRecord,
      List<ProgressRecord> progressRecords,
      TrendLine trendLine,
      ) {
    final best1RM = progressRecords.isNotEmpty
        ? progressRecords.map((r) => r.estimated1RM).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final totalVolume = progressRecords.fold(0.0, (sum, r) => sum + r.totalVolume);

    return Row(
      children: [
        _buildStatCard(
          isDark,
          icon: Icons.trending_up_rounded,
          title: 'Лучший 1RM',
          value: '${best1RM.toStringAsFixed(1)} кг',
          color: const Color(0xFF4CAF50),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          isDark,
          icon: Icons.fitness_center_rounded,
          title: 'Последний',
          value: lastRecord != null
              ? '${lastRecord.bestWeight.toStringAsFixed(0)}×${lastRecord.bestReps}'
              : 'Нет данных',
          color: const Color(0xFFFF6B35),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          isDark,
          icon: Icons.bar_chart_rounded,
          title: 'Прогноз',
          value: trendLine.slope > 0
              ? '+${(trendLine.slope * 30).toStringAsFixed(1)}/мес'
              : 'Нет данных',
          color: const Color(0xFF2196F3),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      bool isDark, {
        required IconData icon,
        required String title,
        required String value,
        required Color color,
      }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white38 : Colors.grey.shade500,
        indicator: BoxDecoration(
          color: const Color(0xFFFF6B35),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.all(3),
        tabs: const [
          Tab(text: 'Описание'),
          Tab(text: 'Прогресс'),
          Tab(text: 'История'),
        ],
      ),
    );
  }

  Widget _buildInfoTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Описание
          if (widget.exercise.description.isNotEmpty) ...[
            _buildInfoSection(
              isDark,
              icon: Icons.description_rounded,
              title: 'Описание',
              content: widget.exercise.description,
            ),
            const SizedBox(height: 16),
          ],

          // Советы по технике
          if (widget.exercise.techniqueTips != null && widget.exercise.techniqueTips!.isNotEmpty) ...[
            _buildInfoSection(
              isDark,
              icon: Icons.lightbulb_rounded,
              title: 'Советы по технике',
              content: widget.exercise.techniqueTips!,
              color: const Color(0xFFFFC107),
            ),
            const SizedBox(height: 16),
          ],

          // Частые ошибки
          if (widget.exercise.commonMistakes != null && widget.exercise.commonMistakes!.isNotEmpty) ...[
            _buildInfoSection(
              isDark,
              icon: Icons.warning_rounded,
              title: 'Частые ошибки',
              content: widget.exercise.commonMistakes!,
              color: const Color(0xFFF44336),
            ),
            const SizedBox(height: 16),
          ],

          // Видео-ссылка
          if (widget.exercise.videoUrl != null && widget.exercise.videoUrl!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_rounded, color: Color(0xFFF44336), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Видео-инструкция',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Открыть в браузере',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, color: Colors.grey, size: 18),
                ],
              ),
            ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color ?? const Color(0xFFFF6B35), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTab(
      bool isDark,
      FitnessProvider provider,
      List<ProgressRecord> records,
      TrendLine trendLine,
      ) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Нет данных о прогрессе',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
            ),
            Text(
              'Начните тренироваться!',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    final spots = <FlSpot>[];
    final firstDate = records.first.date;

    for (int i = 0; i < records.length; i++) {
      final x = records[i].date.difference(firstDate).inDays.toDouble();
      final y = records[i].estimated1RM;
      spots.add(FlSpot(x, y));
    }

    // Прогнозные точки
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

    return Padding(
      padding: const EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              strokeWidth: 1,
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
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
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
                  return Text(
                    '${date.day}.${date.month}',
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Основной график
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFFFF6B35),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: const Color(0xFFFF6B35),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFFF6B35).withOpacity(0.1),
              ),
            ),
            // Прогноз
            if (predictionSpots.isNotEmpty)
              LineChartBarData(
                spots: predictionSpots,
                isCurved: true,
                color: const Color(0xFFFF6B35).withOpacity(0.4),
                barWidth: 2,
                dashArray: [5, 5],
                dotData: const FlDotData(show: false),
              ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} кг',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark, List<ProgressRecord> records) {
    if (records.isEmpty) {
      return Center(
        child: Text(
          'История тренировок появится здесь',
          style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
        ),
      );
    }

    final sortedRecords = List<ProgressRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      itemCount: sortedRecords.length,
      itemBuilder: (context, index) {
        final record = sortedRecords[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFFFF6B35), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.date.day}.${record.date.month}.${record.date.year}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${record.totalSets} подходов • ${record.totalVolume.toStringAsFixed(0)} кг объём',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${record.bestWeight.toStringAsFixed(0)} × ${record.bestReps}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '1RM: ${record.estimated1RM.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, bool isDark, FitnessProvider provider) {
    final nameController = TextEditingController(text: widget.exercise.name);
    final descController = TextEditingController(text: widget.exercise.description);
    final tipsController = TextEditingController(text: widget.exercise.techniqueTips ?? '');
    final mistakesController = TextEditingController(text: widget.exercise.commonMistakes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        title: Text(
          'Редактировать',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tipsController,
                maxLines: 2,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Советы',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mistakesController,
                maxLines: 2,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Ошибки',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final updated = widget.exercise.copyWith(
                name: nameController.text.trim(),
                description: descController.text.trim(),
                techniqueTips: tipsController.text.trim().isNotEmpty ? tipsController.text.trim() : null,
                commonMistakes: mistakesController.text.trim().isNotEmpty ? mistakesController.text.trim() : null,
              );
              await provider.updateExercise(updated);
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить', style: TextStyle(color: Color(0xFFFF6B35))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(context, isDark, provider);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, bool isDark, FitnessProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить упражнение?'),
        content: Text('"${widget.exercise.name}" будет удалено безвозвратно'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteExercise(widget.exercise.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  IconData _getExerciseIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.strength: return Icons.fitness_center_rounded;
      case ExerciseType.cardio: return Icons.directions_run_rounded;
      case ExerciseType.bodyweight: return Icons.accessibility_new_rounded;
      case ExerciseType.boxing: return Icons.sports_mma_rounded;
      case ExerciseType.yoga: return Icons.self_improvement_rounded;
      case ExerciseType.other: return Icons.more_horiz_rounded;
    }
  }
}