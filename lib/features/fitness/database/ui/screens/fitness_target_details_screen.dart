import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';

class FitnessTargetDetailsScreen extends StatefulWidget {
  final FitnessTarget target;
  final bool isDark;

  const FitnessTargetDetailsScreen({
    super.key,
    required this.target,
    required this.isDark,
  });

  @override
  State<FitnessTargetDetailsScreen> createState() =>
      _FitnessTargetDetailsScreenState();
}

class _FitnessTargetDetailsScreenState
    extends State<FitnessTargetDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();

    // Берём актуальные данные из провайдера (реактивно обновляется)
    final target = provider.targets.firstWhere(
          (t) => t.id == widget.target.id,
      orElse: () => widget.target,
    );

    final entries = provider.getTargetEntries(target.id);
    final forecast = provider.calculateForecast(target);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(isDark, target, provider),
          SliverToBoxAdapter(child: _buildHeroCard(isDark, target, forecast)),
          SliverToBoxAdapter(child: _buildForecastCard(isDark, target, forecast)),
          SliverToBoxAdapter(child: _buildChartCard(isDark, target, entries)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'История записей (${entries.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyHistory(isDark))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final entry = entries[index];
                  final prev = index < entries.length - 1 ? entries[index + 1] : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildEntryCard(isDark, entry, prev, target),
                  );
                },
                childCount: entries.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: target.status == FitnessTargetStatus.active
          ? FloatingActionButton.extended(
        backgroundColor: target.accentColor,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEntrySheet(context, target, provider),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить запись',
            style: TextStyle(fontWeight: FontWeight.w800)),
      )
          : null,
    );
  }

  // ==================== APP BAR ====================

  Widget _buildSliverAppBar(
      bool isDark, FitnessTarget target, FitnessProvider provider) {
    return SliverAppBar.large(
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      title: Text(target.name,
          style: const TextStyle(fontWeight: FontWeight.w900)),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert,
              color: isDark ? Colors.white : Colors.black87),
          onSelected: (value) => _handleMenuAction(value, target, provider),
          itemBuilder: (ctx) => [
            if (target.status == FitnessTargetStatus.active)
              PopupMenuItem(
                value: 'edit_value',
                child: Row(children: [
                  Icon(Icons.edit_rounded,
                      color: target.accentColor, size: 20),
                  const SizedBox(width: 12),
                  const Text('Изменить текущее значение'),
                ]),
              ),
            if (target.status == FitnessTargetStatus.active)
              PopupMenuItem(
                value: 'complete',
                child: Row(children: [
                  Icon(Icons.emoji_events_rounded,
                      color: const Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 12),
                  const Text('Отметить как достигнутую'),
                ]),
              ),
            if (target.status == FitnessTargetStatus.active)
              PopupMenuItem(
                value: 'pause',
                child: Row(children: [
                  Icon(Icons.pause_circle_outline_rounded,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  const Text('Приостановить'),
                ]),
              ),
            if (target.status == FitnessTargetStatus.paused)
              PopupMenuItem(
                value: 'resume',
                child: Row(children: [
                  Icon(Icons.play_circle_outline_rounded,
                      color: const Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 12),
                  const Text('Возобновить'),
                ]),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400, size: 20),
                const SizedBox(width: 12),
                const Text('Удалить цель',
                    style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  void _handleMenuAction(
      String action, FitnessTarget target, FitnessProvider provider) async {
    switch (action) {
      case 'edit_value':
        _editCurrentValue(context, target, provider);
        break;
      case 'complete':
        await provider.completeTarget(target.id);
        break;
      case 'pause':
        await provider.pauseTarget(target.id);
        break;
      case 'resume':
        await provider.resumeTarget(target.id);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Удалить цель?'),
            content: Text('"${target.name}" и вся история будут удалены'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Удалить',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true && mounted) {
          await provider.deleteTarget(target.id);
          if (mounted) Navigator.pop(context);
        }
        break;
    }
  }

  // ==================== HERO CARD ====================

  Widget _buildHeroCard(
      bool isDark, FitnessTarget target, Map<String, dynamic> forecast) {
    final progress = target.progressPercent;
    final improvement = target.lastImprovement;

    // Определяем направление для правильной интерпретации улучшения
    final bool isImprovement = target.isAscending
        ? improvement > 0
        : improvement < 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              target.accentColor,
              target.accentColor.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: target.accentColor.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(target.type.emoji,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(target.type.displayName.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
                    ],
                  ),
                ),
                const Spacer(),
                if (target.deadline != null) ...[
                  Icon(Icons.calendar_today_rounded,
                      color: Colors.white.withOpacity(0.9), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _formatDeadline(target.deadline!),
                    style: TextStyle(
                        color: target.isOverdue
                            ? Colors.red.shade200
                            : Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  target.formattedCurrent,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    target.unit,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (improvement != 0 && target.entries.length >= 2)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isImprovement
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${improvement > 0 ? '+' : ''}${improvement.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  target.isAscending
                      ? 'из ${target.formattedTarget} ${target.unit}'
                      : 'до ${target.formattedTarget} ${target.unit}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (target.startValue > 0 && target.startValue != target.currentValue)
                  Text(
                    'стартовое: ${target.startValue == target.startValue.roundToDouble() ? target.startValue.toStringAsFixed(0) : target.startValue.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toInt()}% выполнено',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'осталось ${target.formattedRemaining} ${target.unit}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FORECAST CARD ====================

  Widget _buildForecastCard(
      bool isDark, FitnessTarget target, Map<String, dynamic> forecast) {
    final isRealistic = forecast['isRealistic'] as bool? ?? false;
    final days = forecast['days'] as int?;
    final date = forecast['date'] as DateTime?;
    final speed = (forecast['speed'] as double?) ?? 0;
    final reason = forecast['reason'] as String? ?? '';
    final trendDays = forecast['trendDays'] as int? ?? 0;

    Color cardColor;
    IconData icon;
    String title;
    String subtitle;

    if (!isRealistic || days == null) {
      cardColor = const Color(0xFF9E9E9E);
      icon = Icons.analytics_outlined;
      title = 'Прогноз недоступен';
      subtitle = reason;
    } else if (days <= 7) {
      cardColor = const Color(0xFF4CAF50);
      icon = Icons.bolt_rounded;
      title = 'Совсем скоро!';
      subtitle = 'Осталось $days ${_daysWord(days)}';
    } else if (days <= 30) {
      cardColor = const Color(0xFF2196F3);
      icon = Icons.trending_up_rounded;
      title = 'Отличный темп';
      subtitle = 'Примерно через $days ${_daysWord(days)}';
    } else if (days <= 180) {
      cardColor = const Color(0xFFFF9800);
      icon = Icons.schedule_rounded;
      title = 'Стабильный прогресс';
      subtitle = 'Ориентировочно ${_formatDate(date!)}';
    } else {
      cardColor = const Color(0xFF673AB7);
      icon = Icons.explore_rounded;
      title = 'Долгий путь';
      subtitle = '~${(days / 30).ceil()} месяцев';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cardColor, cardColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: cardColor.withOpacity(0.4), blurRadius: 10),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (isRealistic && speed > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${speed.toStringAsFixed(2)} ${target.unit}/дн',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: cardColor),
                    ),
                  ),
              ],
            ),
            if (trendDays > 0 && isRealistic) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 12,
                        color: isDark ? Colors.white38 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Прогноз на основе последних $trendDays ${_daysWord(trendDays)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== CHART CARD ====================

  Widget _buildChartCard(
      bool isDark, FitnessTarget target, List<FitnessTargetEntry> entries) {
    // Для одной записи рисуем просто точку
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    // Сортируем по дате для графика (возрастание)
    final sorted = List<FitnessTargetEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final values = sorted.map((e) => e.value).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);

    // Учитываем цель и стартовое значение в диапазоне
    final chartValues = [
      minVal,
      maxVal,
      target.targetValue,
      if (target.startValue > 0) target.startValue,
    ];
    final chartMin = chartValues.reduce((a, b) => a < b ? a : b);
    final chartMax = chartValues.reduce((a, b) => a > b ? a : b);
    final chartRange = (chartMax - chartMin).abs() == 0
        ? 1.0
        : (chartMax - chartMin).abs();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                Icon(Icons.show_chart_rounded,
                    color: target.accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Динамика',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (sorted.length >= 2)
                  Text(
                    '${sorted.first.date.day}.${sorted.first.date.month} — ${sorted.last.date.day}.${sorted.last.date.month}',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                        isDark ? Colors.white38 : Colors.grey.shade500),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: CustomPaint(
                size: const Size(double.infinity, 160),
                painter: _TargetChartPainter(
                  points: sorted
                      .map((e) => (
                  value: e.value,
                  date: e.date,
                  ))
                      .toList(),
                  targetValue: target.targetValue,
                  startValue: target.startValue,
                  accentColor: target.accentColor,
                  isDark: isDark,
                  chartMin: chartMin,
                  chartRange: chartRange,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildChartStat(isDark, 'Мин', minVal.toStringAsFixed(1),
                    target.accentColor.withOpacity(0.7)),
                _buildChartStat(isDark, 'Макс', maxVal.toStringAsFixed(1),
                    target.accentColor),
                _buildChartStat(isDark, 'Цель',
                    target.targetValue.toStringAsFixed(1), Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartStat(
      bool isDark, String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.grey.shade500)),
      ],
    );
  }

  // ==================== ENTRY CARD ====================

  Widget _buildEntryCard(bool isDark, FitnessTargetEntry entry,
      FitnessTargetEntry? prev, FitnessTarget target) {
    final diff = prev != null ? entry.value - prev.value : 0.0;
    final isImprovement = target.isAscending ? diff > 0 : diff < 0;
    final isWorsening = diff != 0 && !isImprovement;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  target.accentColor,
                  target.accentColor.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: target.accentColor.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                entry.value == entry.value.roundToDouble()
                    ? entry.value.toStringAsFixed(0)
                    : entry.value.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_formatDate(entry.date),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                              isDark ? Colors.white : Colors.black87)),
                    ),
                    if (diff != 0 && prev != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isImprovement
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336))
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isImprovement
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 12,
                              color: isImprovement
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFF44336),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isImprovement
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF44336),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry.note!,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (entry.bodyWeight != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.monitor_weight_rounded,
                          size: 10,
                          color:
                          isDark ? Colors.white24 : Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text('Вес тела: ${entry.bodyWeight!.toStringAsFixed(1)} кг',
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade500)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _confirmDeleteEntry(entry, target),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade400, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteEntry(
      FitnessTargetEntry entry, FitnessTarget target) async {
    final provider = context.read<FitnessProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить запись?'),
        content: Text('Запись за ${_formatDate(entry.date)} будет удалена'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await provider.removeTargetEntry(target.id, entry.date);
    }
  }

  // ==================== EDIT CURRENT VALUE ====================

  void _editCurrentValue(
      BuildContext context, FitnessTarget target, FitnessProvider provider) {
    final isDark = widget.isDark;
    final controller =
    TextEditingController(text: target.currentValue.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        title: Text('Текущее значение',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'Значение (${target.unit})',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F1115) : Colors.grey.shade100,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text) ?? target.currentValue;
              Navigator.pop(ctx);

              // Создаём новую запись с этим значением
              await provider.addTargetEntry(target.id, value,
                  note: 'Ручная корректировка');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: target.accentColor,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded,
                size: 48,
                color: isDark ? Colors.white12 : Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('История пуста',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color:
                    isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('Нажмите + чтобы добавить первую запись',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color:
                    isDark ? Colors.white24 : Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  // ==================== ADD ENTRY SHEET ====================

  void _showAddEntrySheet(BuildContext context, FitnessTarget target,
      FitnessProvider provider) {
    final isDark = widget.isDark;
    final controller =
    TextEditingController(text: target.currentValue.toStringAsFixed(1));
    final noteController = TextEditingController();

    // Подсказки на основе типа цели
    final String hintText = _getHintForType(target);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          target.accentColor,
                          target.accentColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(target.type.emoji,
                        style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  Text('Новая запись',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color:
                          isDark ? Colors.white : Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Текущий результат (${target.unit})',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                    isDark ? Colors.white54 : Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color:
                    isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: '0.0',
                  suffixText: target.unit,
                  suffixStyle: TextStyle(
                      fontSize: 14,
                      color:
                      isDark ? Colors.white38 : Colors.grey.shade500),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F1115)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Заметка (опционально)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                    isDark ? Colors.white54 : Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: hintText,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F1115)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final value =
                    double.tryParse(controller.text);
                    if (value == null || value < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Введите корректное значение'),
                            backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    provider.addTargetEntry(
                      target.id,
                      value,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    );
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  'Запись добавлена: $value ${target.unit}'),
                            ),
                          ],
                        ),
                        backgroundColor: target.accentColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('СОХРАНИТЬ',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: target.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getHintForType(FitnessTarget target) {
    switch (target.type) {
      case FitnessTargetType.strengthMax:
        return 'Например: "удалось пожать 90, осталось 10 кг!"';
      case FitnessTargetType.strengthReps:
        return 'Например: "сделал 8 повторов с 60 кг"';
      case FitnessTargetType.bodyweightReps:
        return 'Например: "подтянулся 7 раз без раскачки"';
      case FitnessTargetType.cardioDistance:
        return 'Например: "пробежал 3 км в парке"';
      case FitnessTargetType.cardioTime:
        return 'Например: "5 км за 28 минут"';
      case FitnessTargetType.endurance:
        return 'Например: "планка 90 секунд"';
      case FitnessTargetType.bodyMeasurement:
        return 'Например: "замер утром после душа"';
      case FitnessTargetType.bodyWeight:
        return 'Например: "взвесился утром натощак"';
      case FitnessTargetType.volume:
        return 'Например: "тяжёлая тренировка"';
      case FitnessTargetType.custom:
        return 'Любая заметка о прогрессе...';
    }
  }

  // ==================== HELPERS ====================

  String _formatDate(DateTime date) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDeadline(DateTime date) {
    final days = date.difference(DateTime.now()).inDays;
    if (days < 0) return 'Просрочено';
    if (days == 0) return 'Сегодня';
    if (days == 1) return 'Завтра';
    if (days <= 7) return '$days дн.';
    return '${date.day}.${date.month.toString().padLeft(2, '0')}';
  }

  String _daysWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) {
      return 'дня';
    }
    return 'дней';
  }
}

// ==================== CUSTOM PAINTER ДЛЯ ГРАФИКА ====================

class _TargetChartPainter extends CustomPainter {
  final List<({double value, DateTime date})> points;
  final double targetValue;
  final double startValue;
  final Color accentColor;
  final bool isDark;
  final double chartMin;
  final double chartRange;

  _TargetChartPainter({
    required this.points,
    required this.targetValue,
    required this.startValue,
    required this.accentColor,
    required this.isDark,
    required this.chartMin,
    required this.chartRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withOpacity(0.3),
          accentColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final targetPaint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final startPaint = Paint()
      ..color = Colors.orange.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final pointPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final pointBorder = Paint()
      ..color = isDark ? const Color(0xFF1A1D24) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Целевая линия (пунктир)
    _drawDashedLine(
      canvas, size, targetValue, targetPaint,
      dashWidth: 6.0, dashSpace: 4.0,
    );

    // Стартовая линия (если есть и отличается от цели)
    if (startValue > 0 && (startValue - targetValue).abs() > 0.01) {
      _drawDashedLine(
        canvas, size, startValue, startPaint,
        dashWidth: 3.0, dashSpace: 3.0,
      );
    }

    // Точки на графике
    final path = Path();
    final fillPath = Path();
    final coords = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final px = points.length == 1
          ? size.width / 2
          : (i / (points.length - 1)) * size.width;
      final normalized =
      ((points[i].value - chartMin) / chartRange).clamp(0.0, 1.0);
      final py = size.height - normalized * size.height;
      final point = Offset(px, py);
      coords.add(point);

      if (i == 0) {
        path.moveTo(px, py);
        fillPath.moveTo(px, size.height);
        fillPath.lineTo(px, py);
      } else {
        path.lineTo(px, py);
        fillPath.lineTo(px, py);
      }
    }

    if (coords.isNotEmpty) {
      fillPath.lineTo(coords.last.dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      if (coords.length > 1) {
        canvas.drawPath(path, linePaint);
      }

      // Рисуем точки
      for (final c in coords) {
        canvas.drawCircle(c, 6, pointBorder);
        canvas.drawCircle(c, 4, pointPaint);
      }
    }
  }

  void _drawDashedLine(
      Canvas canvas,
      Size size,
      double value,
      Paint paint, {
        required double dashWidth,
        required double dashSpace,
      }) {
    final y = size.height -
        ((value - chartMin) / chartRange).clamp(0.0, 1.0) * size.height;
    final clampedY = y.clamp(0.0, size.height);
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, clampedY),
        Offset((x + dashWidth).clamp(0.0, size.width), clampedY),
        paint,
      );
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TargetChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.targetValue != targetValue ||
        oldDelegate.chartMin != chartMin ||
        oldDelegate.chartRange != chartRange;
  }
}