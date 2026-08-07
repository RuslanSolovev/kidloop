// features/life_navigator/ui/widgets/notes/notes_backgrounds.dart
import 'package:flutter/material.dart';
import 'notes_constants.dart';

class NotesBackgrounds {
  /// Рисует фон для заметки в зависимости от типа
  static Widget build({
    required NoteBackgroundType type,
    required Widget child,
    Color? color,
  }) {
    switch (type) {
      case NoteBackgroundType.plain:
        return child;
      case NoteBackgroundType.grid:
        return CustomPaint(
          painter: _GridPainter(color: Colors.black.withOpacity(0.08)),
          child: child,
        );
      case NoteBackgroundType.lines:
        return CustomPaint(
          painter: _LinesPainter(color: Colors.blue.withOpacity(0.15)),
          child: child,
        );
      case NoteBackgroundType.dots:
        return CustomPaint(
          painter: _DotsPainter(color: Colors.black.withOpacity(0.06)),
          child: child,
        );
      case NoteBackgroundType.kraft:
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD7CCC8),
            border: Border.all(color: Colors.brown.shade200, width: 0.5),
          ),
          child: child,
        );
    }
  }
}

// ==================== ПАТТЕРНЫ ====================

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinesPainter extends CustomPainter {
  final Color color;
  _LinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const spacing = 24.0;
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Красная линия слева
    final redPaint = Paint()
      ..color = Colors.red.withOpacity(0.2)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(30, 0), Offset(30, size.height), redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotsPainter extends CustomPainter {
  final Color color;
  _DotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    const spacing = 20.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}