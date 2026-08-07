// features/life_navigator/ui/widgets/calendar/calendar_active_day.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/life_models.dart';

class CalendarActiveDay extends StatelessWidget {
  final bool isDark;
  final List<CalendarEvent> events;

  const CalendarActiveDay({
    super.key,
    required this.isDark,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 ГРУППИРОВКА ПО ДНЯМ НЕДЕЛИ
    final weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final Map<int, int> dayCounts = {};
    final Map<int, List<CalendarEvent>> dayEvents = {};

    for (final event in events) {
      final dayIndex = (event.date.weekday - 1) % 7; // 0 = Пн
      dayCounts[dayIndex] = (dayCounts[dayIndex] ?? 0) + 1;
      dayEvents.putIfAbsent(dayIndex, () => []).add(event);
    }

    // 🔥 ПОИСК ПИКОВОГО ДНЯ
    int maxCount = 0;
    int maxDayIndex = 0;
    dayCounts.forEach((day, count) {
      if (count > maxCount) {
        maxCount = count;
        maxDayIndex = day;
      }
    });

    // 🔥 ВТОРОЙ ПО АКТИВНОСТИ
    int secondCount = 0;
    int secondDayIndex = 0;
    dayCounts.forEach((day, count) {
      if (count > secondCount && day != maxDayIndex) {
        secondCount = count;
        secondDayIndex = day;
      }
    });

    // 🔥 ЭМОДЗИ ПО УРОВНЮ АКТИВНОСТИ
    final emoji = maxCount > 10 ? '🔥🔥' : maxCount > 5 ? '🔥' : maxCount > 2 ? '⚡' : '📌';
    final label = maxCount > 10 ? 'Супер-день!' : maxCount > 5 ? 'Активный' : maxCount > 2 ? 'Умеренный' : 'Спокойный';

    // 🔥 ЦВЕТ ПО АКТИВНОСТИ
    final activityColor = maxCount > 10 ? Colors.red : maxCount > 5 ? Colors.orange : maxCount > 2 ? Colors.amber : Colors.grey;

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 28, color: isDark ? Colors.white24 : Colors.grey.shade400),
            const SizedBox(height: 6),
            Text('Нет событий', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade500)),
            Text('для анализа', style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.grey.shade400)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showActivityDetails(context, dayCounts, dayEvents, weekDays, maxDayIndex, maxCount, activityColor);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activityColor.withOpacity(0.3),
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
                    color: activityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_fire_department_rounded, color: activityColor, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Пик активности',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? Colors.white24 : Colors.grey.shade400),
              ],
            ),

            const SizedBox(height: 10),

            // 🔥 ОСНОВНАЯ ИНФОРМАЦИЯ
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$emoji ${weekDays[maxDayIndex]}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: activityColor),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // 🔥 КОЛИЧЕСТВО СОБЫТИЙ
            Text(
              '$maxCount ${_pluralEvents(maxCount)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: activityColor),
            ),

            // 🔥 МИНИ-БАРЫ ДНЕЙ НЕДЕЛИ
            if (maxCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final count = dayCounts[index] ?? 0;
                  final maxBarHeight = 24.0;
                  final barHeight = maxCount > 0 ? (count / maxCount * maxBarHeight) : 0.0;
                  final isPeak = index == maxDayIndex;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(
                        children: [
                          Container(
                            height: barHeight < 4 ? 4 : barHeight,
                            decoration: BoxDecoration(
                              color: isPeak ? activityColor : activityColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            weekDays[index],
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: isPeak ? FontWeight.w800 : FontWeight.w500,
                              color: isPeak ? activityColor : (isDark ? Colors.white38 : Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],

            // 🔥 ВТОРОЙ АКТИВНЫЙ ДЕНЬ
            if (secondCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '🥈 ${weekDays[secondDayIndex]} — $secondCount ${_pluralEvents(secondCount)}',
                style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== СКЛОНЕНИЕ ====================

  String _pluralEvents(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'событие';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'события';
    return 'событий';
  }

  // ==================== ДЕТАЛЬНАЯ АКТИВНОСТЬ ====================

  void _showActivityDetails(
      BuildContext context,
      Map<int, int> dayCounts,
      Map<int, List<CalendarEvent>> dayEvents,
      List<String> weekDays,
      int maxDayIndex,
      int maxCount,
      Color activityColor,
      ) {
    final sortedDays = dayCounts.entries.toList()
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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            Text('📊 Активность по дням', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: sortedDays.map((entry) {
                  final dayIndex = entry.key;
                  final count = entry.value;
                  final isPeak = dayIndex == maxDayIndex;
                  final percent = maxCount > 0 ? (count / maxCount) : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPeak ? activityColor.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: isPeak ? Border.all(color: activityColor.withOpacity(0.3)) : null,
                    ),
                    child: Row(
                      children: [
                        Text(
                          isPeak ? '🔥' : '📌',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                weekDays[dayIndex],
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                                  color: activityColor,
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$count',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isPeak ? activityColor : (isDark ? Colors.white70 : Colors.grey.shade700)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))),
          ],
        ),
      ),
    );
  }
}