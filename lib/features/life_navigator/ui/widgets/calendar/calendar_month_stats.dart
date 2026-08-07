// features/life_navigator/ui/widgets/calendar/calendar_month_stats.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/life_models.dart';

class CalendarMonthStats extends StatelessWidget {
  final bool isDark;
  final List<CalendarEvent> events;
  final int month;
  final int year;

  const CalendarMonthStats({
    super.key,
    required this.isDark,
    required this.events,
    required this.month,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 ТЕКУЩИЙ МЕСЯЦ
    final currentMonthEvents = events.where((e) => e.date.month == month && e.date.year == year).toList();
    final currentCount = currentMonthEvents.length;

    // 🔥 ПРЕДЫДУЩИЙ МЕСЯЦ
    final previousMonth = month == 1 ? 12 : month - 1;
    final previousYear = month == 1 ? year - 1 : year;
    final previousCount = events.where((e) => e.date.month == previousMonth && e.date.year == previousYear).length;

    // 🔥 ТРЕНД
    final diff = currentCount - previousCount;
    final trendIcon = diff > 0 ? Icons.trending_up_rounded : diff < 0 ? Icons.trending_down_rounded : Icons.trending_flat_rounded;
    final trendColor = diff > 0 ? Colors.green : diff < 0 ? Colors.red : Colors.grey;
    final trendText = diff > 0 ? '+$diff' : '$diff';

    // 🔥 РАСПРЕДЕЛЕНИЕ ПО КАТЕГОРИЯМ
    final Map<String, int> categoryCounts = {};
    for (final event in currentMonthEvents) {
      final category = _getCategoryName(event.color);
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    // 🔥 САМАЯ АКТИВНАЯ КАТЕГОРИЯ
    String topCategory = '—';
    int topCount = 0;
    categoryCounts.forEach((cat, count) {
      if (count > topCount) {
        topCount = count;
        topCategory = cat;
      }
    });

    // 🔥 ПРОЦЕНТ ВЫПОЛНЕННЫХ
    final completedCount = currentMonthEvents.where((e) => e.isCompleted).length;
    final completionPercent = currentCount > 0 ? (completedCount / currentCount * 100).round() : 0;

    // 🔥 НАЗВАНИЕ МЕСЯЦА
    final monthName = DateFormat('LLLL', 'ru').format(DateTime(year, month));

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showStatsDetails(context, currentCount, previousCount, diff, topCategory, topCount, completionPercent, categoryCounts, monthName);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 ЗАГОЛОВОК
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: Colors.purple, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    monthName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? Colors.white24 : Colors.grey.shade400),
              ],
            ),

            const SizedBox(height: 10),

            // 🔥 ОСНОВНЫЕ ЦИФРЫ
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$currentCount',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'событий',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                ),
                const Spacer(),
                // 🔥 ТРЕНД
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: trendColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, size: 14, color: trendColor),
                      const SizedBox(width: 3),
                      Text(
                        trendText,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: trendColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 🔥 МИНИ-СТАТИСТИКА
            Row(
              children: [
                _buildMiniStat('🏆', topCategory, topCount),
                const SizedBox(width: 8),
                _buildMiniStat('✅', '$completionPercent%', completedCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== МИНИ-СТАТ ====================

  Widget _buildMiniStat(String emoji, String label, int count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== КАТЕГОРИЯ ПО ЦВЕТУ ====================

  String _getCategoryName(String colorHex) {
    const map = {
      '#2196F3': 'Личное', '#FF6B00': 'Работа', '#4CAF50': 'Здоровье',
      '#9C27B0': 'Праздник', '#F44336': 'Важное', '#FF9800': 'Встреча',
      '#00BCD4': 'Учёба', '#E91E63': 'Другое',
    };
    return map[colorHex] ?? 'Другое';
  }

  // ==================== ДЕТАЛЬНАЯ СТАТИСТИКА ====================

  void _showStatsDetails(
      BuildContext context,
      int currentCount,
      int previousCount,
      int diff,
      String topCategory,
      int topCount,
      int completionPercent,
      Map<String, int> categoryCounts,
      String monthName,
      ) {
    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            Text('📊 Статистика за $monthName', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),

            // 🔥 КАРТОЧКИ С ЦИФРАМИ
            Row(
              children: [
                _buildStatCard('Всего', '$currentCount', 'событий', Colors.blue),
                const SizedBox(width: 8),
                _buildStatCard('Выполнено', '$completionPercent%', 'задач', Colors.green),
                const SizedBox(width: 8),
                _buildStatCard('Тренд', '${diff > 0 ? "+" : ""}$diff', 'к прошлому', diff >= 0 ? Colors.green : Colors.red),
              ],
            ),

            if (sortedCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('По категориям', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.grey.shade700)),
              const SizedBox(height: 8),
              ...sortedCategories.take(5).map((entry) => _buildCategoryRow(entry.key, entry.value, currentCount)),
            ],

            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String category, int count, int total) {
    final percent = total > 0 ? (count / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(category, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          const Spacer(),
          Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.grey.shade700)),
          const SizedBox(width: 8),
          Container(
            width: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                color: Colors.purple,
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}