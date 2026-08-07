// features/life_navigator/ui/widgets/notes/notes_constants.dart
import 'package:flutter/material.dart';

class NotesConstants {
  // 🔥 ПАЛИТРА ИЗ 12 ЦВЕТОВ (как Google Keep)
  static const List<NoteColor> colorPalette = [
    NoteColor(name: 'Белый', color: Color(0xFFFFFFFF), textColor: Color(0xFF202124)),
    NoteColor(name: 'Красный', color: Color(0xFFF28B82), textColor: Color(0xFF202124)),
    NoteColor(name: 'Оранжевый', color: Color(0xFFFBBC04), textColor: Color(0xFF202124)),
    NoteColor(name: 'Жёлтый', color: Color(0xFFFFF475), textColor: Color(0xFF202124)),
    NoteColor(name: 'Зелёный', color: Color(0xFFCCFF90), textColor: Color(0xFF202124)),
    NoteColor(name: 'Бирюзовый', color: Color(0xFFA7FFEB), textColor: Color(0xFF202124)),
    NoteColor(name: 'Голубой', color: Color(0xFFCBF0F8), textColor: Color(0xFF202124)),
    NoteColor(name: 'Синий', color: Color(0xFFAECBFA), textColor: Color(0xFF202124)),
    NoteColor(name: 'Фиолетовый', color: Color(0xFFD7AEFB), textColor: Color(0xFF202124)),
    NoteColor(name: 'Розовый', color: Color(0xFFFDCFE8), textColor: Color(0xFF202124)),
    NoteColor(name: 'Серый', color: Color(0xFFE8EAED), textColor: Color(0xFF202124)),
    NoteColor(name: 'Тёмный', color: Color(0xFF3C4043), textColor: Color(0xFFFFFFFF)),
  ];

  // 🔥 КАТЕГОРИИ
  static const List<String> categories = [
    'Все',
    'Работа',
    'Личное',
    'Идеи',
    'Рецепты',
    'Финансы',
    'Здоровье',
    'Учёба',
    'Проекты',
    'Другое',
  ];

  // 🔥 ОБОИ ДЛЯ ЗАМЕТОК
  static const List<NoteBackground> backgrounds = [
    NoteBackground(name: 'Чистый', type: NoteBackgroundType.plain),
    NoteBackground(name: 'Сетка', type: NoteBackgroundType.grid),
    NoteBackground(name: 'Линии', type: NoteBackgroundType.lines),
    NoteBackground(name: 'Точки', type: NoteBackgroundType.dots),
    NoteBackground(name: 'Крафт', type: NoteBackgroundType.kraft),
  ];

  // 🔥 ЦВЕТА ДЛЯ HEX-КОДОВ В БД
  static Color fromHex(String hex) {
    return Color(int.parse('0xFF${hex.replaceFirst('#', '')}'));
  }

  static String toHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  // 🔥 ПОЛУЧИТЬ ЦВЕТ ТЕКСТА ДЛЯ ФОНА
  static Color getTextColorForBackground(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF202124) : const Color(0xFFFFFFFF);
  }
}

// ==================== МОДЕЛИ ====================

class NoteColor {
  final String name;
  final Color color;
  final Color textColor;

  const NoteColor({
    required this.name,
    required this.color,
    required this.textColor,
  });
}

enum NoteBackgroundType {
  plain,
  grid,
  lines,
  dots,
  kraft,
}

class NoteBackground {
  final String name;
  final NoteBackgroundType type;

  const NoteBackground({
    required this.name,
    required this.type,
  });
}