// features/life_navigator/ui/widgets/calendar/calendar_backgrounds.dart
import 'package:flutter/material.dart';

class CalendarBackgrounds {
  // ========== СЕЗОННЫЕ ЦВЕТА ДЛЯ ФОНА ==========
  static Color getBackgroundColor(int month, {bool isDark = false}) {
    final colors = {
      1: isDark ? const Color(0xFF1A237E) : const Color(0xFFBBDEFB),   // Январь - зимний синий
      2: isDark ? const Color(0xFF1A237E) : const Color(0xFFBBDEFB),   // Февраль - зимний синий
      3: isDark ? const Color(0xFF1B5E20) : const Color(0xFFC8E6C9),   // Март - весенний зелёный
      4: isDark ? const Color(0xFF1B5E20) : const Color(0xFFC8E6C9),   // Апрель - весенний зелёный
      5: isDark ? const Color(0xFF1B5E20) : const Color(0xFFC8E6C9),   // Май - весенний зелёный
      6: isDark ? const Color(0xFFF57F17) : const Color(0xFFFFF9C4),   // Июнь - летний жёлтый
      7: isDark ? const Color(0xFFF57F17) : const Color(0xFFFFF9C4),   // Июль - летний жёлтый
      8: isDark ? const Color(0xFFF57F17) : const Color(0xFFFFF9C4),   // Август - летний жёлтый
      9: isDark ? const Color(0xFFE65100) : const Color(0xFFFFE0B2),   // Сентябрь - осенний оранжевый
      10: isDark ? const Color(0xFFE65100) : const Color(0xFFFFE0B2),  // Октябрь - осенний оранжевый
      11: isDark ? const Color(0xFFE65100) : const Color(0xFFFFE0B2),  // Ноябрь - осенний оранжевый
      12: isDark ? const Color(0xFF1A237E) : const Color(0xFFBBDEFB),  // Декабрь - зимний синий
    };
    return colors[month] ?? (isDark ? const Color(0xFF1A1D24) : Colors.white);
  }

  // ========== СЕЗОННЫЕ ГРАДИЕНТЫ ДЛЯ ФОНА ==========
  static Gradient getBackgroundGradient(int month, {bool isDark = false}) {
    final baseColor = getBackgroundColor(month, isDark: isDark);

    // Для тёмной темы используем более тёмные оттенки
    if (isDark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          baseColor.withOpacity(0.8),
          baseColor.withOpacity(0.4),
          const Color(0xFF0F1115).withOpacity(0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }

    // Для светлой темы — светлые и прозрачные
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        baseColor.withOpacity(0.3),
        baseColor.withOpacity(0.1),
        Colors.white.withOpacity(0.5),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
  }

  // ========== СЕЗОННЫЕ ЭМОДЗИ ==========
  static String getSeasonEmoji(int month) {
    if (month >= 3 && month <= 5) return '🌸';   // Весна
    if (month >= 6 && month <= 8) return '☀️';   // Лето
    if (month >= 9 && month <= 11) return '🍂';  // Осень
    return '❄️';                                 // Зима
  }

  // ========== НАЗВАНИЕ МЕСЯЦА ==========
  static String getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }

  // ========== НАЗВАНИЕ СЕЗОНА ==========
  static String getSeasonName(int month) {
    if (month >= 3 && month <= 5) return 'Весна';
    if (month >= 6 && month <= 8) return 'Лето';
    if (month >= 9 && month <= 11) return 'Осень';
    return 'Зима';
  }

  // ========== ЦВЕТА ДЛЯ ТЕКСТА (контрастность) ==========
  static Color getTextColor(int month, {bool isDark = false}) {
    if (isDark) return Colors.white;

    // Для светлой темы определяем контрастность
    final color = getBackgroundColor(month, isDark: false);
    final brightness = (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114) / 255;

    return brightness > 0.5
        ? const Color(0xFF1A1D24)  // Тёмный текст на светлом фоне
        : Colors.white;            // Белый текст на тёмном фоне
  }

  // ========== ВСПОМОГАТЕЛЬНАЯ ДЛЯ КОНТРАСТА ==========
  static Color getSecondaryColor(int month, {bool isDark = false}) {
    final color = getBackgroundColor(month, isDark: isDark);
    if (isDark) {
      return color.withOpacity(0.3);
    }
    return color.withOpacity(0.15);
  }

  // ========== СЕЗОННЫЙ БОРДЕР ==========
  static Color getBorderColor(int month, {bool isDark = false}) {
    final color = getBackgroundColor(month, isDark: isDark);
    if (isDark) {
      return color.withOpacity(0.3);
    }
    return color.withOpacity(0.2);
  }
}