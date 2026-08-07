// features/life_navigator/ui/widgets/calendar/calendar_progress_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/life_models.dart';

class CalendarProgressBar extends StatelessWidget {
  final bool isDark;
  final List<CalendarEvent> events;
  final DateTime date;

  const CalendarProgressBar({
    super.key,
    required this.isDark,
    required this.events,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    // 🔥 ПРОГРЕСС ДНЯ (если сегодня)
    final dayProgress = isToday ? (now.hour * 60 + now.minute) / (24 * 60) : 0.0;
    final dayPercent = (dayProgress * 100).round();

    // 🔥 ПРОГРЕСС СОБЫТИЙ
    final completedEvents = events.where((e) => e.isCompleted).length;
    final totalEvents = events.length;
    final eventProgress = totalEvents > 0 ? completedEvents / totalEvents : 0.0;
    final eventPercent = (eventProgress * 100).round();

    // 🔥 ОПРЕДЕЛЕНИЕ ЦВЕТА ПРОГРЕССА
    final dayColor = _getProgressColor(dayProgress);
    final eventColor = _getProgressColor(eventProgress);

    // 🔥 ВРЕМЯ ДО КОНЦА ДНЯ
    final hoursLeft = 23 - now.hour;
    final minutesLeft = 59 - now.minute;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showProgressDetails(context, dayPercent, eventPercent, hoursLeft, minutesLeft, completedEvents, totalEvents);
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
          children: [
            // 🔥 ЗАГОЛОВОК
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed_rounded, size: 16, color: isDark ? Colors.white54 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Прогресс',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: dayColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$dayPercent% дня',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dayColor),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // 🔥 ПРОГРЕСС-БАР ДНЯ
            if (isToday) ...[
              _buildProgressRow(
                context: context,
                icon: Icons.wb_sunny_rounded,
                label: 'Время дня',
                progress: dayProgress,
                color: dayColor,
                percentText: '$dayPercent%',
                detailText: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
              ),
              const SizedBox(height: 8),
            ],

            // 🔥 ПРОГРЕСС-БАР СОБЫТИЙ
            if (totalEvents > 0) ...[
              _buildProgressRow(
                context: context,
                icon: Icons.check_circle_outline_rounded,
                label: 'События',
                progress: eventProgress,
                color: eventColor,
                percentText: '$eventPercent%',
                detailText: '$completedEvents / $totalEvents',
              ),
            ] else ...[
              // 🔥 НЕТ СОБЫТИЙ
              Row(
                children: [
                  Icon(Icons.event_busy_rounded, size: 14, color: isDark ? Colors.white24 : Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(
                    'Нет событий на сегодня',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.grey.shade400),
                  ),
                ],
              ),
            ],

            // 🔥 ПОДСКАЗКА
            if (isToday || totalEvents > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, size: 10, color: isDark ? Colors.white24 : Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Нажмите для подробностей',
                    style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== ПРОГРЕСС-СТРОКА ====================

  Widget _buildProgressRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required double progress,
    required Color color,
    required String percentText,
    required String detailText,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.grey.shade600),
            ),
            const Spacer(),
            Text(
              detailText,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(width: 8),
            Text(
              percentText,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  width: MediaQuery.of(context).size.width * 0.7 * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.6), color],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, spreadRadius: -1),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== ЦВЕТ ПО ПРОГРЕССУ ====================

  Color _getProgressColor(double progress) {
    if (progress < 0.33) return Colors.blue;
    if (progress < 0.66) return Colors.orange;
    return Colors.green;
  }

  // ==================== ПОКАЗ ДЕТАЛЕЙ ====================

  void _showProgressDetails(
      BuildContext context,
      int dayPercent,
      int eventPercent,
      int hoursLeft,
      int minutesLeft,
      int completedEvents,
      int totalEvents,
      ) {
    final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

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
            const SizedBox(height: 20),

            Text('📊 Детали прогресса', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),

            if (isToday) ...[
              _buildDetailCard(Icons.wb_sunny_rounded, 'Прогресс дня', '$dayPercent%', 'Осталось: ${hoursLeft}ч ${minutesLeft}мин', Colors.orange),
              const SizedBox(height: 8),
            ],
            _buildDetailCard(
              Icons.check_circle_outline_rounded,
              'События выполнено',
              '$eventPercent%',
              totalEvents > 0 ? '$completedEvents из $totalEvents' : 'Нет событий',
              Colors.green,
            ),

            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
              ],
            ),
          ),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}