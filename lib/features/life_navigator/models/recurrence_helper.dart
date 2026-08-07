// features/life_navigator/models/recurrence_helper.dart
import 'package:flutter/material.dart';

class RecurrenceHelper {
  static String getLabel(String recurrence) {
    switch (recurrence) {
      case 'daily': return 'Ежедневно';
      case 'weekly': return 'Еженедельно';
      case 'monthly': return 'Ежемесячно';
      case 'yearly': return 'Ежегодно';
      default: return 'Нет';
    }
  }

  static String getIcon(String recurrence) {
    switch (recurrence) {
      case 'daily': return '🔄';
      case 'weekly': return '📅';
      case 'monthly': return '📆';
      case 'yearly': return '🗓️';
      default: return '';
    }
  }

  static List<DateTime> generateRecurringDates({
    required DateTime startDate,
    required String recurrence,
    int maxOccurrences = 52,
    List<String>? weekDays,
  }) {
    final dates = <DateTime>[];
    DateTime currentDate = startDate;
    final endDate = startDate.add(const Duration(days: 365));

    int count = 0;
    while (currentDate.isBefore(endDate) && count < maxOccurrences) {
      if (recurrence == 'weekly' && weekDays != null) {
        final weekdayName = _weekDays[currentDate.weekday - 1];
        if (!weekDays.contains(weekdayName)) {
          currentDate = _addDuration(recurrence, currentDate);
          continue;
        }
      }
      dates.add(currentDate);
      currentDate = _addDuration(recurrence, currentDate);
      count++;
    }
    return dates;
  }

  static DateTime _addDuration(String recurrence, DateTime date) {
    switch (recurrence) {
      case 'daily': return date.add(const Duration(days: 1));
      case 'weekly': return date.add(const Duration(days: 7));
      case 'monthly': return DateTime(date.year, date.month + 1, date.day);
      case 'yearly': return DateTime(date.year + 1, date.month, date.day);
      default: return date;
    }
  }

  static const List<String> _weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  static String getWeekdayName(int weekday) {
    return _weekDays[weekday - 1];
  }
}