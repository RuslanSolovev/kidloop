// features/life_navigator/ui/widgets/calendar/calendar_add_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../../services/notification_service.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';

class CalendarAddDialog extends StatefulWidget {
  final bool isDark;
  final LifeProvider provider;
  final DateTime initialDate;
  final CalendarEvent? eventToEdit;

  const CalendarAddDialog({
    super.key,
    required this.isDark,
    required this.provider,
    required this.initialDate,
    this.eventToEdit,
  });

  @override
  State<CalendarAddDialog> createState() => _CalendarAddDialogState();
}

class _CalendarAddDialogState extends State<CalendarAddDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController(); // 🔥 НОВОЕ: локация
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  String _selectedColor = '#2196F3';
  bool _hasReminder = false;
  int _reminderMinutes = 5; // 🔥 По умолчанию 5 минут
  String _recurrence = 'none';
  List<String> _selectedWeekDays = [];

  // 🔥 НОВОЕ: предустановленные варианты напоминаний + своё время
  final List<int> _quickReminders = [0, 5, 15, 30, 60, 120, 1440]; // 0 = в точное время
  bool _customReminder = false;
  final _customReminderController = TextEditingController();

  final List<_CategoryOption> _categories = [
    _CategoryOption('#2196F3', 'Личное', Icons.person_outline),
    _CategoryOption('#FF6B00', 'Работа', Icons.work_outline),
    _CategoryOption('#4CAF50', 'Здоровье', Icons.favorite_outline),
    _CategoryOption('#9C27B0', 'Праздник', Icons.celebration_outlined),
    _CategoryOption('#F44336', 'Важное', Icons.star_outline),
    _CategoryOption('#FF9800', 'Встреча', Icons.handshake_outlined),
    _CategoryOption('#00BCD4', 'Учёба', Icons.school_outlined),
    _CategoryOption('#E91E63', 'Другое', Icons.push_pin_outlined),
  ];

  final List<String> _weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;

    if (widget.eventToEdit != null) {
      _isEditing = true;
      final event = widget.eventToEdit!;
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _locationController.text = event.location ?? '';
      _selectedDate = event.date;
      if (event.time != null) {
        _selectedTime = TimeOfDay.fromDateTime(event.time!);
      }
      _selectedColor = event.color;
      _hasReminder = event.hasReminder;
      _reminderMinutes = event.reminderMinutes;
      _recurrence = event.recurrence;
      if (event.recurrenceDays.isNotEmpty) {
        try {
          _selectedWeekDays = List<String>.from(jsonDecode(event.recurrenceDays));
        } catch (_) {
          _selectedWeekDays = [];
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _customReminderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // 🔥 ЗАГОЛОВОК
            _buildHeader(isDark),
            const SizedBox(height: 20),

            // 🔥 НАЗВАНИЕ
            _buildTextField(
              controller: _titleController,
              label: 'Название события',
              icon: Icons.title_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // 🔥 ОПИСАНИЕ
            _buildTextField(
              controller: _descriptionController,
              label: 'Описание',
              icon: Icons.description_rounded,
              isDark: isDark,
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // 🔥 ЛОКАЦИЯ (НОВОЕ)
            _buildTextField(
              controller: _locationController,
              label: 'Место проведения',
              icon: Icons.location_on_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // 🔥 ДАТА И ВРЕМЯ
            _buildSectionTitle('Дата и время', Icons.schedule_rounded, isDark),
            const SizedBox(height: 8),
            _buildDateTimePickers(isDark),
            const SizedBox(height: 16),

            // 🔥 КАТЕГОРИЯ
            _buildSectionTitle('Категория', Icons.category_rounded, isDark),
            const SizedBox(height: 8),
            _buildCategorySelector(isDark),
            const SizedBox(height: 16),

            // 🔥 НАПОМИНАНИЕ
            _buildSectionTitle('Напоминание', Icons.notifications_active_rounded, isDark),
            const SizedBox(height: 8),
            _buildReminderSection(isDark),
            const SizedBox(height: 16),

            // 🔥 ПОВТОРЕНИЕ
            _buildSectionTitle('Повторение', Icons.repeat_rounded, isDark),
            const SizedBox(height: 8),
            _buildRecurrenceSection(isDark),

            const SizedBox(height: 20),

            // 🔥 КНОПКИ
            _buildActionButtons(isDark),
          ],
        ),
      ),
    );
  }

  // ==================== ЗАГОЛОВОК ====================

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _isEditing ? Colors.orange.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _isEditing ? Icons.edit_rounded : Icons.add_rounded,
            color: _isEditing ? Colors.orange : Colors.blue,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _isEditing ? 'Редактировать событие' : 'Новое событие',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
      ],
    );
  }

  // ==================== ЗАГОЛОВОК СЕКЦИИ ====================

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.grey.shade700),
        ),
      ],
    );
  }

  // ==================== ТЕКСТОВОЕ ПОЛЕ ====================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white38 : Colors.grey.shade500),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ==================== ДАТА И ВРЕМЯ ====================

  Widget _buildDateTimePickers(bool isDark) {
    return Row(
      children: [
        // 🔥 ДАТА
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                locale: const Locale('ru'),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('d MMM yyyy', 'ru').format(_selectedDate),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // 🔥 ВРЕМЯ
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              final time = await showTimePicker(
                context: context,
                initialTime: _selectedTime ?? TimeOfDay.now(),
              );
              if (time != null) setState(() => _selectedTime = time);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    _selectedTime != null
                        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                        : 'Время',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _selectedTime != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== КАТЕГОРИИ ====================

  Widget _buildCategorySelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedColor == cat.color;
        final color = Color(int.parse('0xFF${cat.color.replaceFirst('#', '')}'));
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedColor = cat.color);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  cat.name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey.shade600)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== НАПОМИНАНИЕ ====================

  Widget _buildReminderSection(bool isDark) {
    return Column(
      children: [
        // 🔥 ВКЛ/ВЫКЛ
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Включить напоминание', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700)),
          value: _hasReminder,
          onChanged: (v) => setState(() => _hasReminder = v),
          activeColor: Colors.orange,
        ),

        if (_hasReminder) ...[
          const SizedBox(height: 8),

          // 🔥 БЫСТРЫЕ ВАРИАНТЫ
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickReminders.map((minutes) {
              final isSelected = !_customReminder && _reminderMinutes == minutes;
              final label = minutes == 0 ? 'Точно' : minutes < 60 ? '${minutes}м' : minutes < 1440 ? '${minutes ~/ 60}ч' : '1д';
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _reminderMinutes = minutes;
                    _customReminder = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Colors.orange : Colors.transparent),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.orange : (isDark ? Colors.white54 : Colors.grey.shade600)),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // 🔥 СВОЁ ВРЕМЯ
          GestureDetector(
            onTap: () => setState(() => _customReminder = !_customReminder),
            child: Row(
              children: [
                Icon(
                  _customReminder ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: _customReminder ? Colors.orange : (isDark ? Colors.white38 : Colors.grey.shade500),
                ),
                const SizedBox(width: 8),
                Text('Своё время', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600)),
              ],
            ),
          ),

          if (_customReminder) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _customReminderController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Минуты',
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (v) {
                        final minutes = int.tryParse(v);
                        if (minutes != null) {
                          setState(() => _reminderMinutes = minutes);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('мин', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600)),
              ],
            ),
          ],

          // 🔥 ПОЯСНЕНИЕ
          const SizedBox(height: 4),
          Text(
            _reminderMinutes == 0
                ? 'Уведомление придёт точно в указанное время'
                : 'Уведомление придёт за $_reminderMinutes мин до события',
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.grey.shade400),
          ),
        ],
      ],
    );
  }

  // ==================== ПОВТОРЕНИЕ ====================

  Widget _buildRecurrenceSection(bool isDark) {
    return Column(
      children: [
        // 🔥 ВЫБОР ТИПА ПОВТОРЕНИЯ
        Row(
          children: [
            _buildRecurrenceChip('none', 'Нет', isDark),
            const SizedBox(width: 6),
            _buildRecurrenceChip('daily', 'День', isDark),
            const SizedBox(width: 6),
            _buildRecurrenceChip('weekly', 'Неделя', isDark),
            const SizedBox(width: 6),
            _buildRecurrenceChip('monthly', 'Месяц', isDark),
            const SizedBox(width: 6),
            _buildRecurrenceChip('yearly', 'Год', isDark),
          ],
        ),

        // 🔥 ДНИ НЕДЕЛИ ДЛЯ ЕЖЕНЕДЕЛЬНОГО
        if (_recurrence == 'weekly') ...[
          const SizedBox(height: 12),
          Row(
            children: _weekDays.map((day) {
              final isSelected = _selectedWeekDays.contains(day);
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSelected) {
                        _selectedWeekDays.remove(day);
                      } else {
                        _selectedWeekDays.add(day);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? Colors.blue : Colors.transparent),
                    ),
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.blue : (isDark ? Colors.white54 : Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // 🔥 ПОЯСНЕНИЕ
        if (_recurrence != 'none') ...[
          const SizedBox(height: 6),
          Text(
            _recurrence == 'daily' ? 'Повторяется каждый день' :
            _recurrence == 'weekly' ? 'Повторяется в выбранные дни недели' :
            _recurrence == 'monthly' ? 'Повторяется каждый месяц' : 'Повторяется каждый год',
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.grey.shade400),
          ),
        ],
      ],
    );
  }

  Widget _buildRecurrenceChip(String value, String label, bool isDark) {
    final isSelected = _recurrence == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _recurrence = value;
          if (value != 'weekly') _selectedWeekDays = [];
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.purple : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.purple : (isDark ? Colors.white54 : Colors.grey.shade600)),
        ),
      ),
    );
  }

  // ==================== КНОПКИ ====================

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton(
            onPressed: _saveEvent,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isEditing ? Colors.orange : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              _isEditing ? 'Сохранить' : 'Добавить событие',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
            ),
            child: const Text('Отмена', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // ==================== СОХРАНЕНИЕ ====================

  Future<void> _saveEvent() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название события'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final eventTime = _selectedTime != null
        ? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime!.hour, _selectedTime!.minute)
        : null;

    if (_isEditing) {
      final updatedEvent = CalendarEvent(
        id: widget.eventToEdit!.id,
        title: _titleController.text,
        description: _descriptionController.text,
        date: _selectedDate,
        time: eventTime,
        location: _locationController.text.isNotEmpty ? _locationController.text : null,
        color: _selectedColor,
        hasReminder: _hasReminder,
        reminderMinutes: _reminderMinutes,
        isCompleted: widget.eventToEdit!.isCompleted,
        recurrence: _recurrence,
        recurrenceDays: jsonEncode(_selectedWeekDays),
      );
      await widget.provider.updateEvent(updatedEvent);

      if (_hasReminder && eventTime != null) {
        final ns = NotificationService();
        await ns.cancelNotification(updatedEvent.id.hashCode);
        await ns.scheduleEventReminder(eventId: updatedEvent.id, eventTitle: updatedEvent.title, eventTime: eventTime, reminderMinutes: _reminderMinutes);
      }
    } else {
      final newEvent = await widget.provider.addEvent(
        title: _titleController.text,
        description: _descriptionController.text,
        date: _selectedDate,
        time: eventTime,
        location: _locationController.text.isNotEmpty ? _locationController.text : null,
        color: _selectedColor,
        hasReminder: _hasReminder,
        reminderMinutes: _reminderMinutes,
      );

      if (_hasReminder && eventTime != null) {
        final ns = NotificationService();
        await ns.scheduleEventReminder(eventId: newEvent.id, eventTitle: newEvent.title, eventTime: eventTime, reminderMinutes: _reminderMinutes);
      }

      if (_recurrence != 'none') {
        _createRecurringEvents(newEvent);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${_isEditing ? "Сохранено" : "Создано"}: "${_titleController.text}"'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  // ==================== ПОВТОРЯЮЩИЕСЯ СОБЫТИЯ ====================

  void _createRecurringEvents(CalendarEvent baseEvent) {
    final provider = widget.provider;
    const int maxOccurrences = 52;
    DateTime currentDate = baseEvent.date;
    final endDate = baseEvent.date.add(const Duration(days: 365));
    int count = 0;

    while (currentDate.isBefore(endDate) && count < maxOccurrences) {
      switch (_recurrence) {
        case 'daily': currentDate = currentDate.add(const Duration(days: 1)); break;
        case 'weekly':
          currentDate = currentDate.add(const Duration(days: 1));
          if (_selectedWeekDays.isNotEmpty) {
            final dayName = _weekDays[currentDate.weekday - 1];
            if (!_selectedWeekDays.contains(dayName)) continue;
          } else {
            if (currentDate.weekday != baseEvent.date.weekday) continue;
          }
          break;
        case 'monthly': currentDate = DateTime(currentDate.year, currentDate.month + 1, currentDate.day); break;
        case 'yearly': currentDate = DateTime(currentDate.year + 1, currentDate.month, currentDate.day); break;
        default: continue;
      }

      if (currentDate.isAfter(endDate)) break;

      final eventTime = baseEvent.time != null
          ? DateTime(currentDate.year, currentDate.month, currentDate.day, baseEvent.time!.hour, baseEvent.time!.minute)
          : null;

      provider.addEvent(
        title: baseEvent.title,
        description: baseEvent.description,
        date: currentDate,
        time: eventTime,
        location: baseEvent.location,
        color: baseEvent.color,
        hasReminder: baseEvent.hasReminder,
        reminderMinutes: baseEvent.reminderMinutes,
      ).then((newEvent) {
        if (baseEvent.hasReminder && eventTime != null) {
          NotificationService().scheduleEventReminder(eventId: newEvent.id, eventTitle: newEvent.title, eventTime: eventTime, reminderMinutes: baseEvent.reminderMinutes);
        }
      });

      count++;
    }
  }
}

// ========== МОДЕЛЬ КАТЕГОРИИ ==========
class _CategoryOption {
  final String color;
  final String name;
  final IconData icon;
  const _CategoryOption(this.color, this.name, this.icon);
}