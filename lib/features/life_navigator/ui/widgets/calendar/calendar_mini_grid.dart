// features/life_navigator/ui/widgets/calendar/calendar_mini_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/life_models.dart';

class MiniCalendarGrid extends StatelessWidget {
  final bool isDark;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final Function(DateTime) onDateSelected;
  final Function(String) onViewModeChanged;
  final String viewMode;

  const MiniCalendarGrid({
    super.key,
    required this.isDark,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
    required this.onViewModeChanged,
    required this.viewMode,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final firstWeekday = firstDay.weekday % 7;

    // 🔥 Группируем события по дням с подсчётом
    final Map<int, int> eventCounts = {};
    final Map<int, Color> dayColors = {};
    for (final event in events) {
      if (event.date.month == selectedDate.month && event.date.year == selectedDate.year) {
        final day = event.date.day;
        eventCounts[day] = (eventCounts[day] ?? 0) + 1;
        // Запоминаем цвет первого события для индикатора
        dayColors.putIfAbsent(day, () => Color(int.parse('0xFF${event.color.replaceFirst('#', '')}')));
      }
    }

    final today = DateTime.now();
    final isCurrentMonth = today.year == selectedDate.year && today.month == selectedDate.month;

    // 🔥 Дни с наибольшим количеством событий
    final maxEvents = eventCounts.values.isEmpty ? 0 : eventCounts.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // 🔥 ЗАГОЛОВОК С НАВИГАЦИЕЙ
          _buildMonthHeader(context),

          const SizedBox(height: 10),

          // 🔥 ДНИ НЕДЕЛИ
          Row(
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((day) {
              final isWeekend = day == 'Сб' || day == 'Вс';
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isWeekend
                          ? (isDark ? Colors.red.shade300 : Colors.red.shade400)
                          : (isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 6),

          // 🔥 СЕТКА ДНЕЙ
          ...List.generate((daysInMonth + firstWeekday + 6) ~/ 7, (weekIndex) {
            return Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;
                final isValid = dayNumber >= 1 && dayNumber <= daysInMonth;

                if (!isValid) {
                  return const Expanded(child: SizedBox());
                }

                final date = DateTime(selectedDate.year, selectedDate.month, dayNumber);
                final isSelected = dayNumber == selectedDate.day;
                final isToday = isCurrentMonth && dayNumber == today.day;
                final eventCount = eventCounts[dayNumber] ?? 0;
                final dayColor = dayColors[dayNumber];
                final isHot = maxEvents > 0 && eventCount == maxEvents && eventCount > 0;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onDateSelected(date);
                    },
                    onLongPress: () {
                      HapticFeedback.lightImpact();
                      // 🔥 При долгом нажатии показываем события дня
                      _showDayEvents(context, date);
                    },
                    child: Tooltip(
                      message: eventCount > 0 ? '$eventCount событий' : 'Нет событий',
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.blue.shade600
                              : isToday
                              ? Colors.orange.withOpacity(0.2)
                              : null,
                          border: isToday && !isSelected
                              ? Border.all(color: Colors.orange, width: 2)
                              : isHot && !isSelected
                              ? Border.all(color: dayColor?.withOpacity(0.5) ?? Colors.blue.withOpacity(0.5), width: 1.5)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)]
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 🔥 НОМЕР ДНЯ
                            Text(
                              '$dayNumber',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                    ? Colors.orange.shade700
                                    : isDark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),

                            // 🔥 ИНДИКАТОРЫ СОБЫТИЙ
                            if (eventCount > 0)
                              Positioned(
                                bottom: 3,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Одна точка за одно событие, две за 2, три за 3+
                                    for (int i = 0; i < (eventCount > 3 ? 3 : eventCount); i++)
                                      Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? Colors.white
                                              : dayColor ?? Colors.blue,
                                        ),
                                      ),
                                    if (eventCount > 3)
                                      Text(
                                        '+',
                                        style: TextStyle(
                                          fontSize: 6,
                                          fontWeight: FontWeight.w900,
                                          color: isSelected ? Colors.white70 : (dayColor ?? Colors.blue),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),

          const SizedBox(height: 8),

          // 🔥 ЛЕГЕНДА
          if (maxEvents > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withOpacity(0.3), border: Border.all(color: Colors.orange, width: 1.5))),
                const SizedBox(width: 4),
                Text('Сегодня', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                const SizedBox(width: 12),
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.shade600)),
                const SizedBox(width: 4),
                Text('Выбрано', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                const SizedBox(width: 12),
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5))),
                const SizedBox(width: 4),
                Text('Активно', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
              ],
            ),

          const SizedBox(height: 8),

          // 🔥 КНОПКИ ПЕРЕКЛЮЧЕНИЯ РЕЖИМА
          _buildViewModeButtons(),
        ],
      ),
    );
  }

  // ==================== ЗАГОЛОВОК МЕСЯЦА С НАВИГАЦИЕЙ ====================

  Widget _buildMonthHeader(BuildContext context) {
    final monthName = DateFormat('LLLL', 'ru').format(selectedDate);
    final capitalizedMonth = monthName[0].toUpperCase() + monthName.substring(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 🔥 Кнопка "Назад"
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            final prevMonth = DateTime(selectedDate.year, selectedDate.month - 1, 1);
            onDateSelected(prevMonth);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.chevron_left_rounded, size: 18, color: isDark ? Colors.white70 : Colors.grey.shade700),
          ),
        ),

        // 🔥 Название месяца (нажимаемое — возврат к сегодня)
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onDateSelected(DateTime.now());
          },
          child: Column(
            children: [
              Text(
                '$capitalizedMonth ${selectedDate.year}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (selectedDate.year != DateTime.now().year || selectedDate.month != DateTime.now().month)
                Text(
                  'нажмите для возврата',
                  style: TextStyle(fontSize: 8, color: isDark ? Colors.white24 : Colors.grey.shade400),
                ),
            ],
          ),
        ),

        // 🔥 Кнопка "Вперёд"
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            final nextMonth = DateTime(selectedDate.year, selectedDate.month + 1, 1);
            onDateSelected(nextMonth);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white70 : Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  // ==================== КНОПКИ РЕЖИМОВ ====================

  Widget _buildViewModeButtons() {
    final modes = [
      _ViewMode('month', 'Месяц', Icons.calendar_month_rounded),
      _ViewMode('week', 'Неделя', Icons.view_week_rounded),
      _ViewMode('day', 'День', Icons.today_rounded),
    ];

    return Row(
      children: modes.map((mode) {
        final isActive = viewMode == mode.id;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onViewModeChanged(mode.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.blue.withOpacity(0.15)
                    : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? Colors.blue.withOpacity(0.4) : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Icon(mode.icon, size: 16, color: isActive ? Colors.blue : (isDark ? Colors.white54 : Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Colors.blue : (isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== ПОКАЗ СОБЫТИЙ ДНЯ ====================

  void _showDayEvents(BuildContext context, DateTime date) {
    final dayEvents = events.where((e) =>
    e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day
    ).toList();

    if (dayEvents.isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Нет событий на ${DateFormat('d MMMM', 'ru').format(date)}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            const SizedBox(height: 16),
            Text(
              '${DateFormat('d MMMM', 'ru').format(date)} • ${dayEvents.length} событий',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 12),
            ...dayEvents.map((event) => ListTile(
              leading: Container(
                width: 8, height: 32,
                decoration: BoxDecoration(
                  color: Color(int.parse('0xFF${event.color.replaceFirst('#', '')}')),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: Text(event.title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
              subtitle: event.time != null
                  ? Text(DateFormat('HH:mm').format(event.time!), style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600))
                  : null,
              trailing: event.hasReminder
                  ? Icon(Icons.notifications_active_rounded, size: 18, color: Colors.orange)
                  : null,
            )),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))),
          ],
        ),
      ),
    );
  }
}

// ========== ВСПОМОГАТЕЛЬНЫЙ КЛАСС ==========
class _ViewMode {
  final String id;
  final String label;
  final IconData icon;
  const _ViewMode(this.id, this.label, this.icon);
}