// features/life_navigator/ui/widgets/calendar/calendar_event_item.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/life_models.dart';

class CalendarEventItem extends StatelessWidget {
  final CalendarEvent event;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onTap; // 🔥 НОВОЕ: нажатие на карточку

  const CalendarEventItem({
    super.key,
    required this.event,
    required this.isDark,
    required this.onDelete,
    required this.onEdit,
    this.onTap,
  });

  // ========== КОНФИГУРАЦИЯ КАТЕГОРИЙ ==========
  static const Map<String, _CategoryConfig> _categories = {
    '#2196F3': _CategoryConfig('Личное', '👤', Icons.person_outline),
    '#FF6B00': _CategoryConfig('Работа', '💼', Icons.work_outline),
    '#4CAF50': _CategoryConfig('Здоровье', '❤️', Icons.favorite_outline),
    '#9C27B0': _CategoryConfig('Праздник', '🎉', Icons.celebration_outlined),
    '#F44336': _CategoryConfig('Важное', '⭐', Icons.star_outline),
    '#FF9800': _CategoryConfig('Встреча', '🤝', Icons.handshake_outlined),
    '#00BCD4': _CategoryConfig('Учёба', '📚', Icons.school_outlined),
    '#E91E63': _CategoryConfig('Другое', '📌', Icons.push_pin_outlined),
  };

  _CategoryConfig get _config => _categories[event.color] ?? _categories['#E91E63']!;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('0xFF${event.color.replaceFirst('#', '')}'));
    final timeStr = event.time != null
        ? '${event.time!.hour.toString().padLeft(2, '0')}:${event.time!.minute.toString().padLeft(2, '0')}'
        : null;
    final dateStr = DateFormat('d MMM', 'ru').format(event.date);

    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить событие?'),
            content: Text('"${event.title}" будет удалено безвозвратно'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          // 🔥 При нажатии показываем детали события
          _showEventDetails(context, color);
          onTap?.call();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onEdit();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // 🔥 ЛЕВАЯ ЦВЕТОВАЯ ПОЛОСА + ИКОНКА
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_config.icon, color: color, size: 18),
                ),

                const SizedBox(width: 10),

                // 🔥 ЦЕНТР: ИНФОРМАЦИЯ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок
                      Text(
                        event.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                          decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Строка с датой, временем, категорией
                      Row(
                        children: [
                          if (timeStr != null) ...[
                            Icon(Icons.access_time_rounded, size: 12, color: color.withOpacity(0.7)),
                            const SizedBox(width: 3),
                            Text(
                              timeStr,
                              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 6),
                            Text('•', style: TextStyle(fontSize: 8, color: Colors.grey.shade400)),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            dateStr,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                          // Категория
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _config.name,
                              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // 🔥 ПРАВАЯ ЧАСТЬ: БЕЙДЖИ
                Column(
                  children: [
                    if (event.hasReminder)
                      _buildBadge(Icons.notifications_active_rounded, Colors.orange, '${event.reminderMinutes}м'),
                    if (event.isAllDay)
                      _buildBadge(Icons.wb_sunny_rounded, Colors.amber, '24ч'),
                    if (event.recurrence != 'none')
                      _buildBadge(Icons.repeat_rounded, Colors.purple, event.recurrence == 'daily' ? 'день' : event.recurrence == 'weekly' ? 'нед' : 'мес'),
                    if (event.location != null && event.location!.isNotEmpty)
                      _buildBadge(Icons.location_on_rounded, Colors.teal, ''),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 МИНИ-БЕЙДЖ
  Widget _buildBadge(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            if (text.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(text, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }

  // 🔥 ПОКАЗ ДЕТАЛЕЙ СОБЫТИЯ
  void _showEventDetails(BuildContext context, Color color) {
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
            // Ручка
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            // Иконка + заголовок
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                  child: Icon(_config.icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      Text(_config.name, style: TextStyle(fontSize: 13, color: color)),
                    ],
                  ),
                ),
              ],
            ),

            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(event.description, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey.shade700)),
              ),
            ],

            const SizedBox(height: 16),

            // Инфо-плитки
            Row(
              children: [
                _buildInfoTile(Icons.calendar_today_rounded, 'Дата', DateFormat('d MMMM yyyy', 'ru').format(event.date)),
                const SizedBox(width: 8),
                _buildInfoTile(Icons.access_time_rounded, 'Время', event.time != null ? DateFormat('HH:mm').format(event.time!) : 'Весь день'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoTile(Icons.notifications_rounded, 'Напоминание', event.hasReminder ? 'За ${event.reminderMinutes} мин' : 'Нет'),
                const SizedBox(width: 8),
                _buildInfoTile(Icons.repeat_rounded, 'Повтор', event.recurrence == 'none' ? 'Нет' : event.recurrence),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }
}

// ========== ВСПОМОГАТЕЛЬНЫЙ КЛАСС ==========
class _CategoryConfig {
  final String name;
  final String emoji;
  final IconData icon;
  const _CategoryConfig(this.name, this.emoji, this.icon);
}