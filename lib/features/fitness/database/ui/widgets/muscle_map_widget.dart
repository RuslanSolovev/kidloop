import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/enums.dart';

class MuscleMapWidget extends StatefulWidget {
  final MuscleGroup? selectedMuscle;
  final Function(MuscleGroup)? onMuscleTap;
  final bool isInteractive;
  final Map<MuscleGroup, double>? volumeData;
  final bool showBack;

  const MuscleMapWidget({
    super.key,
    this.selectedMuscle,
    this.onMuscleTap,
    this.isInteractive = true,
    this.volumeData,
    this.showBack = false,
  });

  @override
  State<MuscleMapWidget> createState() => _MuscleMapWidgetState();
}

class _MuscleMapWidgetState extends State<MuscleMapWidget> {
  MuscleGroup? _hoveredMuscle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 420,
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 2.5,
              child: CustomPaint(
                size: const Size(260, 420),
                painter: MuscleMapPainter(
                  selectedMuscle: widget.selectedMuscle,
                  hoveredMuscle: _hoveredMuscle,
                  volumeData: widget.volumeData,
                  isDark: isDark,
                  showBack: widget.showBack,
                ),
              ),
            ),
          ),
          if (widget.isInteractive) ...[
            const SizedBox(height: 6),
            Text(
              _hoveredMuscle?.displayName ?? widget.selectedMuscle?.displayName ?? 'Нажмите на зону',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _hoveredMuscle != null || widget.selectedMuscle != null
                    ? const Color(0xFFFF6B35)
                    : (isDark ? Colors.white38 : Colors.grey.shade500),
                fontStyle: _hoveredMuscle == null && widget.selectedMuscle == null
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MuscleMapPainter extends CustomPainter {
  final MuscleGroup? selectedMuscle;
  final MuscleGroup? hoveredMuscle;
  final Map<MuscleGroup, double>? volumeData;
  final bool isDark;
  final bool showBack;

  MuscleMapPainter({
    this.selectedMuscle,
    this.hoveredMuscle,
    this.volumeData,
    this.isDark = false,
    this.showBack = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 260;
    final double sy = size.height / 420;

    // Фон
    _drawBackground(canvas, sx, sy);

    // Тень под фигурой
    _drawGroundShadow(canvas, sx, sy);

    // Силуэт тела с рельефом
    _drawBodySilhouette(canvas, sx, sy);

    // Мышцы
    if (showBack) {
      _drawBackMuscles(canvas, sx, sy);
    } else {
      _drawFrontMuscles(canvas, sx, sy);
    }

    // Детали мышц
    _drawMuscleDetails(canvas, sx, sy);

    // Свечение для выделенных
    if (selectedMuscle != null) {
      _drawSelectionGlow(canvas, sx, sy);
    }
  }

  // ==================== ФОН ====================

  void _drawBackground(Canvas canvas, double sx, double sy) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          (isDark ? const Color(0x1AFFFFFF) : const Color(0x08000000)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, 260 * sx, 420 * sy));

    canvas.drawRect(Rect.fromLTWH(0, 0, 260 * sx, 420 * sy), bgPaint);
  }

  // ==================== ТЕНЬ ПОД ФИГУРОЙ ====================

  void _drawGroundShadow(Canvas canvas, double sx, double sy) {
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withOpacity(0.25),
          Colors.black.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(130 * sx, 390 * sy),
        width: 180 * sx,
        height: 30 * sy,
      ));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(130 * sx, 390 * sy),
        width: 180 * sx,
        height: 24 * sy,
      ),
      shadowPaint,
    );
  }

  // ==================== СИЛУЭТ ТЕЛА С РЕЛЬЕФОМ ====================

  void _drawBodySilhouette(Canvas canvas, double sx, double sy) {
    // Основной градиент тела
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          (isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000)),
          (isDark ? const Color(0x0FFFFFFF) : const Color(0x05000000)),
          (isDark ? const Color(0x1AFFFFFF) : const Color(0x08000000)),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, 260 * sx, 420 * sy))
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // === ГОЛОВА (детализированная) ===
    path.moveTo(112 * sx, 16 * sy);
    // Верхняя часть черепа
    path.cubicTo(102 * sx, 14 * sy, 94 * sx, 24 * sy, 94 * sx, 38 * sy);
    // Височная область
    path.cubicTo(94 * sx, 52 * sy, 98 * sx, 62 * sy, 104 * sx, 66 * sy);
    // Скула левая
    path.cubicTo(108 * sx, 70 * sy, 112 * sx, 72 * sy, 118 * sx, 74 * sy);
    // Подбородок
    path.cubicTo(122 * sx, 76 * sy, 138 * sx, 76 * sy, 142 * sx, 74 * sy);
    // Скула правая
    path.cubicTo(148 * sx, 72 * sy, 152 * sx, 70 * sy, 156 * sx, 66 * sy);
    // Височная область правая
    path.cubicTo(162 * sx, 62 * sy, 166 * sx, 52 * sy, 166 * sx, 38 * sy);
    // Верх черепа правая
    path.cubicTo(166 * sx, 24 * sy, 158 * sx, 14 * sy, 148 * sx, 16 * sy);
    // Затылок
    path.cubicTo(138 * sx, 12 * sy, 122 * sx, 12 * sy, 112 * sx, 16 * sy);
    path.close();

    // === ШЕЯ (с мышечным рельефом) ===
    path.moveTo(108 * sx, 68 * sy);
    // Левая сторона шеи
    path.cubicTo(104 * sx, 76 * sy, 100 * sx, 84 * sy, 96 * sx, 90 * sy);
    // Переход к плечу
    path.cubicTo(94 * sx, 94 * sy, 92 * sx, 98 * sy, 88 * sx, 100 * sy);
    // Правая сторона шеи
    path.moveTo(152 * sx, 68 * sy);
    path.cubicTo(156 * sx, 76 * sy, 160 * sx, 84 * sy, 164 * sx, 90 * sy);
    path.cubicTo(166 * sx, 94 * sy, 168 * sx, 98 * sy, 172 * sx, 100 * sy);

    // === ТОРС (V-образный, атлетичный) ===
    // Левое плечо (дельтовидная)
    path.moveTo(88 * sx, 100 * sy);
    path.cubicTo(74 * sx, 98 * sy, 62 * sx, 102 * sy, 52 * sx, 112 * sy);
    // Верх дельты
    path.cubicTo(46 * sx, 118 * sy, 44 * sx, 126 * sy, 46 * sx, 134 * sy);
    // Переход к бицепсу
    path.cubicTo(48 * sx, 140 * sy, 52 * sx, 144 * sy, 56 * sx, 146 * sy);

    // Левая сторона торса (широчайшие)
    path.cubicTo(58 * sx, 162 * sy, 62 * sx, 182 * sy, 66 * sx, 202 * sy);
    // Косые мышцы
    path.cubicTo(68 * sx, 218 * sy, 70 * sx, 234 * sy, 72 * sx, 248 * sy);
    // Таз
    path.cubicTo(74 * sx, 262 * sy, 76 * sx, 268 * sy, 80 * sx, 272 * sy);

    // Низ торса
    path.lineTo(180 * sx, 272 * sy);

    // Правая сторона торса
    path.cubicTo(184 * sx, 268 * sy, 186 * sx, 262 * sy, 188 * sx, 248 * sy);
    path.cubicTo(190 * sx, 234 * sy, 192 * sx, 218 * sy, 194 * sx, 202 * sy);
    path.cubicTo(198 * sx, 182 * sy, 202 * sx, 162 * sy, 204 * sx, 146 * sy);

    // Правое плечо
    path.cubicTo(208 * sx, 144 * sy, 212 * sx, 140 * sy, 214 * sx, 134 * sy);
    path.cubicTo(216 * sx, 126 * sy, 214 * sx, 118 * sy, 208 * sx, 112 * sy);
    path.cubicTo(198 * sx, 102 * sy, 186 * sx, 98 * sy, 172 * sx, 100 * sy);

    // === ЛЕВАЯ РУКА (детализированная) ===
    path.moveTo(56 * sx, 146 * sy);
    // Дельта
    path.cubicTo(42 * sx, 148 * sy, 32 * sx, 156 * sy, 28 * sx, 170 * sy);
    // Бицепс (выпуклость)
    path.cubicTo(24 * sx, 186 * sy, 22 * sx, 206 * sy, 24 * sx, 224 * sy);
    path.cubicTo(26 * sx, 236 * sy, 30 * sx, 242 * sy, 34 * sx, 246 * sy);
    // Локоть
    path.cubicTo(36 * sx, 252 * sy, 38 * sx, 256 * sy, 38 * sx, 260 * sy);
    // Предплечье
    path.cubicTo(40 * sx, 280 * sy, 42 * sx, 304 * sy, 42 * sx, 324 * sy);
    // Запястье
    path.cubicTo(42 * sx, 332 * sy, 44 * sx, 338 * sy, 48 * sx, 342 * sy);
    // Кисть
    path.cubicTo(54 * sx, 346 * sy, 58 * sx, 356 * sy, 56 * sx, 366 * sy);
    path.cubicTo(54 * sx, 374 * sy, 50 * sx, 378 * sy, 52 * sx, 380 * sy);
    // Внутренняя сторона руки
    path.cubicTo(62 * sx, 378 * sy, 66 * sx, 370 * sy, 66 * sx, 360 * sy);
    path.cubicTo(66 * sx, 346 * sy, 60 * sx, 336 * sy, 58 * sx, 324 * sy);
    path.cubicTo(58 * sx, 302 * sy, 64 * sx, 276 * sy, 66 * sx, 258 * sy);
    // Внутренняя сторона локтя
    path.cubicTo(68 * sx, 252 * sy, 70 * sx, 248 * sy, 70 * sx, 242 * sy);
    // Трицепс
    path.cubicTo(74 * sx, 222 * sy, 76 * sx, 198 * sy, 76 * sx, 180 * sy);
    path.cubicTo(76 * sx, 168 * sy, 74 * sx, 158 * sy, 72 * sx, 150 * sy);
    path.cubicTo(70 * sx, 146 * sy, 68 * sx, 146 * sy, 66 * sx, 146 * sy);

    // === ПРАВАЯ РУКА (детализированная) ===
    path.moveTo(204 * sx, 146 * sy);
    // Дельта
    path.cubicTo(218 * sx, 148 * sy, 228 * sx, 156 * sy, 232 * sx, 170 * sy);
    // Бицепс
    path.cubicTo(236 * sx, 186 * sy, 238 * sx, 206 * sy, 236 * sx, 224 * sy);
    path.cubicTo(234 * sx, 236 * sy, 230 * sx, 242 * sy, 226 * sx, 246 * sy);
    // Локоть
    path.cubicTo(224 * sx, 252 * sy, 222 * sx, 256 * sy, 222 * sx, 260 * sy);
    // Предплечье
    path.cubicTo(220 * sx, 280 * sy, 218 * sx, 304 * sy, 218 * sx, 324 * sy);
    // Запястье
    path.cubicTo(218 * sx, 332 * sy, 216 * sx, 338 * sy, 212 * sx, 342 * sy);
    // Кисть
    path.cubicTo(206 * sx, 346 * sy, 202 * sx, 356 * sy, 204 * sx, 366 * sy);
    path.cubicTo(206 * sx, 374 * sy, 210 * sx, 378 * sy, 208 * sx, 380 * sy);
    // Внутренняя сторона
    path.cubicTo(198 * sx, 378 * sy, 194 * sx, 370 * sy, 194 * sx, 360 * sy);
    path.cubicTo(194 * sx, 346 * sy, 200 * sx, 336 * sy, 202 * sx, 324 * sy);
    path.cubicTo(202 * sx, 302 * sy, 196 * sx, 276 * sy, 194 * sx, 258 * sy);
    // Локоть
    path.cubicTo(192 * sx, 252 * sy, 190 * sx, 248 * sy, 190 * sx, 242 * sy);
    // Трицепс
    path.cubicTo(186 * sx, 222 * sy, 184 * sx, 198 * sy, 184 * sx, 180 * sy);
    path.cubicTo(184 * sx, 168 * sy, 186 * sx, 158 * sy, 188 * sx, 150 * sy);
    path.cubicTo(190 * sx, 146 * sy, 192 * sx, 146 * sy, 194 * sx, 146 * sy);

    // === ЛЕВАЯ НОГА (атлетичная) ===
    path.moveTo(80 * sx, 272 * sy);
    // Квадрицепс
    path.cubicTo(76 * sx, 290 * sy, 72 * sx, 312 * sy, 72 * sx, 336 * sy);
    // Колено
    path.cubicTo(72 * sx, 346 * sy, 76 * sx, 356 * sy, 80 * sx, 364 * sy);
    // Икра (выпуклость)
    path.cubicTo(80 * sx, 380 * sy, 78 * sx, 398 * sy, 76 * sx, 410 * sy);
    // Лодыжка
    path.cubicTo(76 * sx, 418 * sy, 78 * sx, 424 * sy, 82 * sx, 426 * sy);
    // Стопа
    path.cubicTo(88 * sx, 428 * sy, 98 * sx, 428 * sy, 106 * sx, 426 * sy);
    path.cubicTo(112 * sx, 424 * sy, 112 * sx, 418 * sy, 110 * sx, 412 * sy);
    // Внутренняя сторона
    path.cubicTo(106 * sx, 402 * sy, 106 * sx, 390 * sy, 108 * sx, 378 * sy);
    path.cubicTo(110 * sx, 362 * sy, 110 * sx, 346 * sy, 108 * sx, 334 * sy);
    // Внутренняя часть бедра
    path.cubicTo(106 * sx, 312 * sy, 110 * sx, 292 * sy, 114 * sx, 272 * sy);

    // === ПРАВАЯ НОГА (атлетичная) ===
    path.moveTo(180 * sx, 272 * sy);
    // Квадрицепс
    path.cubicTo(184 * sx, 290 * sy, 188 * sx, 312 * sy, 188 * sx, 336 * sy);
    // Колено
    path.cubicTo(188 * sx, 346 * sy, 184 * sx, 356 * sy, 180 * sx, 364 * sy);
    // Икра
    path.cubicTo(180 * sx, 380 * sy, 182 * sx, 398 * sy, 184 * sx, 410 * sy);
    // Лодыжка
    path.cubicTo(184 * sx, 418 * sy, 182 * sx, 424 * sy, 178 * sx, 426 * sy);
    // Стопа
    path.cubicTo(172 * sx, 428 * sy, 162 * sx, 428 * sy, 154 * sx, 426 * sy);
    path.cubicTo(148 * sx, 424 * sy, 148 * sx, 418 * sy, 150 * sx, 412 * sy);
    // Внутренняя сторона
    path.cubicTo(154 * sx, 402 * sy, 154 * sx, 390 * sy, 152 * sx, 378 * sy);
    path.cubicTo(150 * sx, 362 * sy, 150 * sx, 346 * sy, 152 * sx, 334 * sy);
    // Внутренняя часть бедра
    path.cubicTo(154 * sx, 312 * sy, 150 * sx, 292 * sy, 146 * sx, 272 * sy);

    canvas.drawPath(path, bodyPaint);
    canvas.drawPath(path, outlinePaint);
  }

  // ==================== ДЕТАЛИ МЫШЦ (улучшенные) ====================

  void _drawMuscleDetails(Canvas canvas, double sx, double sy) {
    final detailPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    if (!showBack) {
      // Линия грудины
      final chestLine = Path()
        ..moveTo(130 * sx, 96 * sy)
        ..cubicTo(130 * sx, 110 * sy, 130 * sx, 124 * sy, 130 * sy, 138 * sy);
      canvas.drawPath(chestLine, detailPaint);

      // Линия пресса (белая линия живота)
      final absLine = Path()
        ..moveTo(130 * sx, 142 * sy)
        ..cubicTo(130 * sx, 164 * sy, 130 * sx, 186 * sy, 130 * sy, 238 * sy);
      canvas.drawPath(absLine, detailPaint);

      // Горизонтальные линии пресса (сухожилия)
      final abs1 = Path()
        ..moveTo(104 * sx, 158 * sy)
        ..cubicTo(116 * sx, 156 * sy, 144 * sx, 156 * sy, 156 * sx, 158 * sy);
      final abs2 = Path()
        ..moveTo(102 * sx, 182 * sy)
        ..cubicTo(116 * sx, 180 * sy, 144 * sx, 180 * sy, 158 * sx, 182 * sy);
      final abs3 = Path()
        ..moveTo(102 * sx, 206 * sy)
        ..cubicTo(116 * sx, 204 * sy, 144 * sx, 204 * sy, 158 * sx, 206 * sy);
      canvas.drawPath(abs1, detailPaint);
      canvas.drawPath(abs2, detailPaint);
      canvas.drawPath(abs3, detailPaint);

      // Разделители квадрицепсов
      final quad1 = Path()
        ..moveTo(98 * sx, 282 * sy)
        ..cubicTo(98 * sx, 308 * sy, 98 * sx, 334 * sy, 98 * sy, 362 * sy);
      final quad2 = Path()
        ..moveTo(162 * sx, 282 * sy)
        ..cubicTo(162 * sx, 308 * sy, 162 * sx, 334 * sy, 162 * sy, 362 * sy);
      canvas.drawPath(quad1, detailPaint);
      canvas.drawPath(quad2, detailPaint);

      // Линии бицепсов
      final bicep1 = Path()
        ..moveTo(42 * sx, 178 * sy)
        ..cubicTo(44 * sx, 196 * sy, 44 * sx, 214 * sy, 42 * sx, 232 * sy);
      final bicep2 = Path()
        ..moveTo(218 * sx, 178 * sy)
        ..cubicTo(216 * sx, 196 * sy, 216 * sx, 214 * sy, 218 * sx, 232 * sy);
      canvas.drawPath(bicep1, detailPaint);
      canvas.drawPath(bicep2, detailPaint);
    } else {
      // Линия позвоночника
      final spine = Path()
        ..moveTo(130 * sx, 94 * sy)
        ..cubicTo(130 * sx, 134 * sy, 130 * sx, 174 * sy, 130 * sy, 220 * sy);
      canvas.drawPath(spine, detailPaint);

      // Линия между ягодицами
      final gluteLine = Path()
        ..moveTo(130 * sx, 246 * sy)
        ..cubicTo(130 * sx, 260 * sy, 130 * sx, 274 * sy, 130 * sy, 286 * sy);
      canvas.drawPath(gluteLine, detailPaint);

      // Разделители бицепсов бедра
      final ham1 = Path()
        ..moveTo(98 * sx, 292 * sy)
        ..cubicTo(98 * sx, 316 * sy, 98 * sx, 340 * sy, 98 * sy, 362 * sy);
      final ham2 = Path()
        ..moveTo(162 * sx, 292 * sy)
        ..cubicTo(162 * sx, 316 * sy, 162 * sx, 340 * sy, 162 * sy, 362 * sy);
      canvas.drawPath(ham1, detailPaint);
      canvas.drawPath(ham2, detailPaint);

      // Линии широчайших
      final lat1 = Path()
        ..moveTo(72 * sx, 158 * sy)
        ..cubicTo(78 * sx, 180 * sy, 84 * sx, 202 * sy, 90 * sx, 224 * sy);
      final lat2 = Path()
        ..moveTo(188 * sx, 158 * sy)
        ..cubicTo(182 * sx, 180 * sy, 176 * sx, 202 * sy, 170 * sx, 224 * sy);
      canvas.drawPath(lat1, detailPaint);
      canvas.drawPath(lat2, detailPaint);
    }
  }

  // ==================== ЭФФЕКТ СВЕЧЕНИЯ ====================

  void _drawSelectionGlow(Canvas canvas, double sx, double sy) {
    final muscle = selectedMuscle!;
    final paths = _getMusclePaths(muscle, sx, sy);
    final color = muscle.color;

    for (final path in paths) {
      final bounds = path.getBounds();

      // Внешнее свечение
      final outerGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.5),
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCenter(
          center: bounds.center,
          width: bounds.width * 2.5,
          height: bounds.height * 2.5,
        ))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

      canvas.drawPath(path, outerGlow);

      // Внутреннее свечение
      final innerGlow = Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawPath(path, innerGlow);
    }
  }

  // ==================== ОТРИСОВКА МЫШЕЧНОЙ ЗОНЫ (многослойная) ====================

  void _drawMuscleZone(Canvas canvas, MuscleGroup muscle, Path path) {
    final isSelected = selectedMuscle == muscle;
    final isHovered = hoveredMuscle == muscle;
    final volume = volumeData?[muscle] ?? 0;
    final volumes = volumeData?.values;
    double maxVolume = 1.0;
    if (volumes != null && volumes.isNotEmpty) {
      maxVolume = volumes.reduce((a, b) => a > b ? a : b);
    }

    Color baseColor = muscle.color;
    double opacity = 0.4;

    if (isSelected) {
      opacity = 0.9;
    } else if (isHovered) {
      opacity = 0.75;
    } else if (volumeData != null && volume > 0 && maxVolume > 0) {
      final intensity = volume / maxVolume;
      opacity = 0.3 + (intensity * 0.5);
    }

    final bounds = path.getBounds();

    // Слой 1: Базовый цвет с градиентом
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          baseColor.withOpacity(opacity * 1.2),
          baseColor.withOpacity(opacity * 0.9),
          baseColor.withOpacity(opacity * 1.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, basePaint);

    // Слой 2: Внутренняя тень (верхний левый угол темнее)
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.5,
        colors: [
          Colors.black.withOpacity(opacity * 0.4),
          Colors.black.withOpacity(opacity * 0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(bounds)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, shadowPaint);

    // Слой 3: Подсветка (нижний правый угол светлее)
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomRight,
        radius: 1.2,
        colors: [
          Colors.white.withOpacity(opacity * 0.25),
          Colors.white.withOpacity(opacity * 0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, highlightPaint);

    // Слой 4: Обводка
    final strokePaint = Paint()
      ..color = baseColor.withOpacity(isSelected ? 0.95 : isHovered ? 0.8 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);
  }

  // ==================== ПЕРЕДНЯЯ ЧАСТЬ - МЫШЦЫ ====================

  void _drawFrontMuscles(Canvas canvas, double sx, double sy) {
    for (final path in _getTrapsFrontPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.traps, path);
    }
    for (final path in _getShouldersFrontPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.shoulders, path);
    }
    for (final path in _getChestPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.chest, path);
    }
    for (final path in _getBicepsFrontPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.biceps, path);
    }
    for (final path in _getTricepsFrontPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.triceps, path);
    }
    for (final path in _getForearmsFrontPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.forearms, path);
    }
    _drawMuscleZone(canvas, MuscleGroup.abs, _getAbsPath(sx, sy));
    for (final path in _getObliquesPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.obliques, path);
    }
    for (final path in _getQuadricepsPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.quadriceps, path);
    }
    for (final path in _getCalvesFrontPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.calves, path);
    }
  }

  void _drawBackMuscles(Canvas canvas, double sx, double sy) {
    for (final path in _getTrapsBackPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.traps, path);
    }
    for (final path in _getShouldersBackPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.shoulders, path);
    }
    for (final path in _getBackPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.back, path);
    }
    for (final path in _getLatsPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.lats, path);
    }
    for (final path in _getTricepsBackPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.triceps, path);
    }
    for (final path in _getForearmsBackPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.forearms, path);
    }
    _drawMuscleZone(canvas, MuscleGroup.lowerBack, _getLowerBackPath(sx, sy));
    for (final path in _getGlutesPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.glutes, path);
    }
    for (final path in _getHamstringsPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.hamstrings, path);
    }
    for (final path in _getCalvesBackPaths(sx, sy)) {
      _drawMuscleZone(canvas, MuscleGroup.calves, path);
    }
  }

  // ==================== ПУТИ МЫШЦ (ПЕРЕД) - УЛУЧШЕННЫЕ ====================

  List<Path> _getTrapsFrontPaths(double sx, double sy) {
    return [
      Path()
        ..moveTo(104 * sx, 78 * sy)
        ..cubicTo(108 * sx, 74 * sy, 120 * sx, 72 * sy, 130 * sx, 72 * sy)
        ..cubicTo(140 * sx, 72 * sy, 152 * sx, 74 * sy, 156 * sx, 78 * sy)
        ..cubicTo(162 * sx, 86 * sy, 164 * sx, 96 * sy, 156 * sx, 102 * sy)
        ..cubicTo(148 * sx, 98 * sy, 140 * sx, 96 * sy, 130 * sx, 96 * sy)
        ..cubicTo(120 * sx, 96 * sy, 112 * sx, 98 * sy, 104 * sx, 102 * sy)
        ..cubicTo(96 * sx, 96 * sy, 98 * sx, 86 * sy, 104 * sx, 78 * sy)
        ..close(),
    ];
  }

  List<Path> _getShouldersFrontPaths(double sx, double sy) {
    return [
      // Левое плечо (трёхглавая дельта)
      Path()
        ..moveTo(78 * sx, 98 * sy)
        ..cubicTo(66 * sx, 98 * sy, 56 * sx, 104 * sy, 50 * sx, 114 * sy)
        ..cubicTo(46 * sx, 124 * sy, 50 * sx, 138 * sy, 60 * sx, 146 * sy)
        ..cubicTo(68 * sx, 140 * sy, 76 * sx, 132 * sy, 80 * sx, 122 * sy)
        ..cubicTo(84 * sx, 112 * sy, 84 * sx, 104 * sy, 78 * sx, 98 * sy)
        ..close(),
      // Правое плечо
      Path()
        ..moveTo(182 * sx, 98 * sy)
        ..cubicTo(194 * sx, 98 * sy, 204 * sx, 104 * sy, 210 * sx, 114 * sy)
        ..cubicTo(214 * sx, 124 * sy, 210 * sx, 138 * sy, 200 * sx, 146 * sy)
        ..cubicTo(192 * sx, 140 * sy, 184 * sx, 132 * sy, 180 * sx, 122 * sy)
        ..cubicTo(176 * sx, 112 * sy, 176 * sx, 104 * sy, 182 * sx, 98 * sy)
        ..close(),
    ];
  }

  List<Path> _getChestPaths(double sx, double sy) {
    return [
      // Левая грудная (большая)
      Path()
        ..moveTo(84 * sx, 104 * sy)
        ..cubicTo(94 * sx, 100 * sy, 112 * sx, 100 * sy, 128 * sx, 104 * sy)
        ..cubicTo(128 * sx, 114 * sy, 128 * sx, 126 * sy, 128 * sx, 138 * sy)
        ..cubicTo(116 * sx, 144 * sy, 102 * sx, 144 * sy, 90 * sx, 142 * sy)
        ..cubicTo(82 * sx, 138 * sy, 78 * sx, 128 * sy, 78 * sx, 118 * sy)
        ..cubicTo(78 * sx, 110 * sy, 80 * sx, 106 * sy, 84 * sx, 104 * sy)
        ..close(),
      // Правая грудная
      Path()
        ..moveTo(176 * sx, 104 * sy)
        ..cubicTo(166 * sx, 100 * sy, 148 * sx, 100 * sy, 132 * sx, 104 * sy)
        ..cubicTo(132 * sx, 114 * sy, 132 * sx, 126 * sy, 132 * sx, 138 * sy)
        ..cubicTo(144 * sx, 144 * sy, 158 * sx, 144 * sy, 170 * sx, 142 * sy)
        ..cubicTo(178 * sx, 138 * sy, 182 * sx, 128 * sy, 182 * sx, 118 * sy)
        ..cubicTo(182 * sx, 110 * sy, 180 * sx, 106 * sy, 176 * sx, 104 * sy)
        ..close(),
    ];
  }

  List<Path> _getBicepsFrontPaths(double sx, double sy) {
    return [
      // Левый бицепс
      Path()
        ..moveTo(64 * sx, 134 * sy)
        ..cubicTo(58 * sx, 142 * sy, 52 * sx, 154 * sy, 50 * sx, 168 * sy)
        ..cubicTo(48 * sx, 182 * sy, 50 * sx, 192 * sy, 58 * sx, 198 * sy)
        ..cubicTo(66 * sx, 198 * sy, 72 * sx, 192 * sy, 76 * sx, 182 * sy)
        ..cubicTo(80 * sx, 168 * sy, 78 * sx, 150 * sy, 74 * sx, 140 * sy)
        ..cubicTo(72 * sx, 136 * sy, 68 * sx, 134 * sy, 64 * sx, 134 * sy)
        ..close(),
      // Правый бицепс
      Path()
        ..moveTo(196 * sx, 134 * sy)
        ..cubicTo(202 * sx, 142 * sy, 208 * sx, 154 * sy, 210 * sx, 168 * sy)
        ..cubicTo(212 * sx, 182 * sy, 210 * sx, 192 * sy, 202 * sx, 198 * sy)
        ..cubicTo(194 * sx, 198 * sy, 188 * sx, 192 * sy, 184 * sx, 182 * sy)
        ..cubicTo(180 * sx, 168 * sy, 182 * sx, 150 * sy, 186 * sx, 140 * sy)
        ..cubicTo(188 * sx, 136 * sy, 192 * sx, 134 * sy, 196 * sx, 134 * sy)
        ..close(),
    ];
  }

  List<Path> _getTricepsFrontPaths(double sx, double sy) {
    return [
      // Левый трицепс (частично виден)
      Path()
        ..moveTo(74 * sx, 132 * sy)
        ..cubicTo(78 * sx, 144 * sy, 82 * sx, 160 * sy, 80 * sx, 176 * sy)
        ..cubicTo(78 * sx, 186 * sy, 74 * sx, 192 * sy, 70 * sx, 192 * sy)
        ..cubicTo(78 * sx, 188 * sy, 84 * sx, 180 * sy, 86 * sx, 168 * sy)
        ..cubicTo(88 * sx, 152 * sy, 86 * sx, 138 * sy, 82 * sx, 128 * sy)
        ..cubicTo(80 * sx, 128 * sy, 76 * sx, 130 * sy, 74 * sx, 132 * sy)
        ..close(),
      // Правый трицепс
      Path()
        ..moveTo(186 * sx, 132 * sy)
        ..cubicTo(182 * sx, 144 * sy, 178 * sx, 160 * sy, 180 * sx, 176 * sy)
        ..cubicTo(182 * sx, 186 * sy, 186 * sx, 192 * sy, 190 * sx, 192 * sy)
        ..cubicTo(182 * sx, 188 * sy, 176 * sx, 180 * sy, 174 * sx, 168 * sy)
        ..cubicTo(172 * sx, 152 * sy, 174 * sx, 138 * sy, 178 * sx, 128 * sy)
        ..cubicTo(180 * sx, 128 * sy, 184 * sx, 130 * sy, 186 * sx, 132 * sy)
        ..close(),
    ];
  }

  List<Path> _getForearmsFrontPaths(double sx, double sy) {
    return [
      // Левое предплечье
      Path()
        ..moveTo(54 * sx, 196 * sy)
        ..cubicTo(48 * sx, 212 * sy, 46 * sx, 232 * sy, 46 * sx, 254 * sy)
        ..cubicTo(46 * sx, 272 * sy, 48 * sx, 286 * sy, 56 * sx, 292 * sy)
        ..cubicTo(64 * sx, 288 * sy, 70 * sx, 278 * sy, 70 * sx, 264 * sy)
        ..cubicTo(70 * sx, 240 * sy, 66 * sx, 216 * sy, 62 * sx, 204 * sy)
        ..cubicTo(60 * sx, 200 * sy, 58 * sx, 196 * sy, 54 * sx, 196 * sy)
        ..close(),
      // Правое предплечье
      Path()
        ..moveTo(206 * sx, 196 * sy)
        ..cubicTo(212 * sx, 212 * sy, 214 * sx, 232 * sy, 214 * sx, 254 * sy)
        ..cubicTo(214 * sx, 272 * sy, 212 * sx, 286 * sy, 204 * sx, 292 * sy)
        ..cubicTo(196 * sx, 288 * sy, 190 * sx, 278 * sy, 190 * sx, 264 * sy)
        ..cubicTo(190 * sx, 240 * sy, 194 * sx, 216 * sy, 198 * sx, 204 * sy)
        ..cubicTo(200 * sx, 200 * sy, 202 * sx, 196 * sy, 206 * sx, 196 * sy)
        ..close(),
    ];
  }

  Path _getAbsPath(double sx, double sy) {
    return Path()
      ..moveTo(106 * sx, 144 * sy)
      ..cubicTo(116 * sx, 142 * sy, 144 * sx, 142 * sy, 154 * sx, 144 * sy)
      ..cubicTo(156 * sx, 168 * sy, 156 * sx, 194 * sy, 156 * sx, 220 * sy)
      ..cubicTo(156 * sx, 236 * sy, 154 * sx, 250 * sy, 148 * sx, 258 * sy)
      ..cubicTo(140 * sx, 262 * sy, 120 * sx, 262 * sy, 112 * sx, 258 * sy)
      ..cubicTo(106 * sx, 250 * sy, 104 * sx, 236 * sy, 104 * sx, 220 * sy)
      ..cubicTo(104 * sx, 194 * sy, 104 * sx, 168 * sy, 106 * sx, 144 * sy)
      ..close();
  }

  List<Path> _getObliquesPaths(double sx, double sy) {
    return [
      // Левые косые
      Path()
        ..moveTo(86 * sx, 148 * sy)
        ..cubicTo(90 * sx, 144 * sy, 100 * sx, 144 * sy, 106 * sx, 146 * sy)
        ..cubicTo(106 * sx, 174 * sy, 104 * sx, 204 * sy, 100 * sx, 234 * sy)
        ..cubicTo(94 * sx, 242 * sy, 88 * sx, 248 * sy, 82 * sx, 246 * sy)
        ..cubicTo(78 * sx, 236 * sy, 78 * sx, 218 * sy, 80 * sx, 192 * sy)
        ..cubicTo(82 * sx, 170 * sy, 84 * sx, 156 * sy, 86 * sx, 148 * sy)
        ..close(),
      // Правые косые
      Path()
        ..moveTo(174 * sx, 148 * sy)
        ..cubicTo(170 * sx, 144 * sy, 160 * sx, 144 * sy, 154 * sx, 146 * sy)
        ..cubicTo(154 * sx, 174 * sy, 156 * sx, 204 * sy, 160 * sx, 234 * sy)
        ..cubicTo(166 * sx, 242 * sy, 172 * sx, 248 * sy, 178 * sx, 246 * sy)
        ..cubicTo(182 * sx, 236 * sy, 182 * sx, 218 * sy, 180 * sx, 192 * sy)
        ..cubicTo(178 * sx, 170 * sy, 176 * sx, 156 * sy, 174 * sx, 148 * sy)
        ..close(),
    ];
  }

  List<Path> _getQuadricepsPaths(double sx, double sy) {
    return [
      // Левый квадрицепс
      Path()
        ..moveTo(92 * sx, 276 * sy)
        ..cubicTo(102 * sx, 274 * sy, 112 * sx, 276 * sy, 118 * sx, 282 * sy)
        ..cubicTo(120 * sx, 306 * sy, 118 * sx, 334 * sy, 114 * sx, 362 * sy)
        ..cubicTo(108 * sx, 370 * sy, 98 * sx, 370 * sy, 90 * sx, 366 * sy)
        ..cubicTo(86 * sx, 340 * sy, 86 * sx, 310 * sy, 92 * sx, 276 * sy)
        ..close(),
      // Правый квадрицепс
      Path()
        ..moveTo(168 * sx, 276 * sy)
        ..cubicTo(158 * sx, 274 * sy, 148 * sx, 276 * sy, 142 * sx, 282 * sy)
        ..cubicTo(140 * sx, 306 * sy, 142 * sx, 334 * sy, 146 * sx, 362 * sy)
        ..cubicTo(152 * sx, 370 * sy, 162 * sx, 370 * sy, 170 * sx, 366 * sy)
        ..cubicTo(174 * sx, 340 * sy, 174 * sx, 310 * sy, 168 * sx, 276 * sy)
        ..close(),
    ];
  }

  List<Path> _getCalvesFrontPaths(double sx, double sy) {
    return [
      // Левая икра (передняя большеберцовая)
      Path()
        ..moveTo(90 * sx, 366 * sy)
        ..cubicTo(98 * sx, 364 * sy, 108 * sx, 366 * sy, 114 * sx, 372 * sy)
        ..cubicTo(116 * sx, 390 * sy, 112 * sx, 406 * sy, 106 * sx, 418 * sy)
        ..cubicTo(100 * sx, 422 * sy, 92 * sx, 422 * sy, 86 * sx, 418 * sy)
        ..cubicTo(84 * sx, 404 * sy, 84 * sx, 386 * sy, 90 * sx, 366 * sy)
        ..close(),
      // Правая икра
      Path()
        ..moveTo(170 * sx, 366 * sy)
        ..cubicTo(162 * sx, 364 * sy, 152 * sx, 366 * sy, 146 * sx, 372 * sy)
        ..cubicTo(144 * sx, 390 * sy, 148 * sx, 406 * sy, 154 * sx, 418 * sy)
        ..cubicTo(160 * sx, 422 * sy, 168 * sx, 422 * sy, 174 * sx, 418 * sy)
        ..cubicTo(176 * sx, 404 * sy, 176 * sx, 386 * sy, 170 * sx, 366 * sy)
        ..close(),
    ];
  }

  // ==================== ПУТИ МЫШЦ (СПИНА) - УЛУЧШЕННЫЕ ====================

  List<Path> _getTrapsBackPaths(double sx, double sy) {
    return [
      Path()
        ..moveTo(100 * sx, 76 * sy)
        ..cubicTo(110 * sx, 74 * sy, 122 * sx, 72 * sy, 130 * sx, 72 * sy)
        ..cubicTo(138 * sx, 72 * sy, 150 * sx, 74 * sy, 160 * sx, 76 * sy)
        ..cubicTo(170 * sx, 88 * sy, 172 * sx, 106 * sy, 164 * sx, 120 * sy)
        ..cubicTo(154 * sx, 114 * sy, 142 * sx, 110 * sy, 130 * sx, 110 * sy)
        ..cubicTo(118 * sx, 110 * sy, 106 * sx, 114 * sy, 96 * sx, 120 * sy)
        ..cubicTo(88 * sx, 106 * sy, 90 * sx, 88 * sy, 100 * sx, 76 * sy)
        ..close(),
    ];
  }

  List<Path> _getShouldersBackPaths(double sx, double sy) {
    return [
      // Левое плечо (задний пучок)
      Path()
        ..moveTo(78 * sx, 98 * sy)
        ..cubicTo(66 * sx, 98 * sy, 54 * sx, 104 * sy, 48 * sx, 114 * sy)
        ..cubicTo(44 * sx, 126 * sy, 50 * sx, 140 * sy, 62 * sx, 146 * sy)
        ..cubicTo(72 * sx, 140 * sy, 80 * sx, 130 * sy, 82 * sx, 118 * sy)
        ..cubicTo(84 * sx, 108 * sy, 82 * sx, 102 * sy, 78 * sx, 98 * sy)
        ..close(),
      // Правое плечо
      Path()
        ..moveTo(182 * sx, 98 * sy)
        ..cubicTo(194 * sx, 98 * sy, 206 * sx, 104 * sy, 212 * sx, 114 * sy)
        ..cubicTo(216 * sx, 126 * sy, 210 * sx, 140 * sy, 198 * sx, 146 * sy)
        ..cubicTo(188 * sx, 140 * sy, 180 * sx, 130 * sy, 178 * sx, 118 * sy)
        ..cubicTo(176 * sx, 108 * sy, 178 * sx, 102 * sy, 182 * sx, 98 * sy)
        ..close(),
    ];
  }

  List<Path> _getBackPaths(double sx, double sy) {
    return [
      // Ромбовидные и средняя часть спины
      Path()
        ..moveTo(94 * sx, 112 * sy)
        ..cubicTo(106 * sx, 108 * sy, 122 * sx, 106 * sy, 130 * sx, 106 * sy)
        ..cubicTo(138 * sx, 106 * sy, 154 * sx, 108 * sy, 166 * sx, 112 * sy)
        ..cubicTo(170 * sx, 130 * sy, 166 * sx, 148 * sy, 158 * sy, 162 * sy)
        ..cubicTo(148 * sx, 158 * sy, 138 * sx, 154 * sy, 130 * sx, 154 * sy)
        ..cubicTo(122 * sx, 154 * sy, 112 * sx, 158 * sy, 102 * sx, 162 * sy)
        ..cubicTo(94 * sx, 148 * sy, 90 * sx, 130 * sy, 94 * sx, 112 * sy)
        ..close(),
    ];
  }

  List<Path> _getLatsPaths(double sx, double sy) {
    return [
      // Левая широчайшая
      Path()
        ..moveTo(86 * sx, 140 * sy)
        ..cubicTo(82 * sx, 160 * sy, 82 * sx, 186 * sy, 88 * sx, 212 * sy)
        ..cubicTo(94 * sx, 222 * sy, 104 * sx, 226 * sy, 116 * sx, 222 * sy)
        ..cubicTo(124 * sx, 210 * sy, 128 * sx, 190 * sy, 126 * sx, 166 * sy)
        ..cubicTo(118 * sx, 152 * sy, 104 * sx, 144 * sy, 86 * sx, 140 * sy)
        ..close(),
      // Правая широчайшая
      Path()
        ..moveTo(174 * sx, 140 * sy)
        ..cubicTo(178 * sx, 160 * sy, 178 * sx, 186 * sy, 172 * sx, 212 * sy)
        ..cubicTo(166 * sx, 222 * sy, 156 * sx, 226 * sy, 144 * sx, 222 * sy)
        ..cubicTo(136 * sx, 210 * sy, 132 * sx, 190 * sy, 134 * sx, 166 * sy)
        ..cubicTo(142 * sx, 152 * sy, 156 * sx, 144 * sy, 174 * sx, 140 * sy)
        ..close(),
    ];
  }

  List<Path> _getTricepsBackPaths(double sx, double sy) {
    return [
      Path()
        ..moveTo(68 * sx, 136 * sy)
        ..cubicTo(60 * sx, 148 * sy, 56 * sx, 166 * sy, 58 * sx, 186 * sy)
        ..cubicTo(60 * sx, 198 * sy, 66 * sx, 204 * sy, 74 * sx, 202 * sy)
        ..cubicTo(80 * sx, 192 * sy, 82 * sx, 174 * sy, 80 * sx, 156 * sy)
        ..cubicTo(78 * sx, 146 * sy, 74 * sx, 138 * sy, 68 * sx, 136 * sy)
        ..close(),
      Path()
        ..moveTo(192 * sx, 136 * sy)
        ..cubicTo(200 * sx, 148 * sy, 204 * sx, 166 * sy, 202 * sx, 186 * sy)
        ..cubicTo(200 * sx, 198 * sy, 194 * sx, 204 * sy, 186 * sx, 202 * sy)
        ..cubicTo(180 * sx, 192 * sy, 178 * sx, 174 * sy, 180 * sx, 156 * sy)
        ..cubicTo(182 * sx, 146 * sy, 186 * sx, 138 * sy, 192 * sx, 136 * sy)
        ..close(),
    ];
  }

  List<Path> _getForearmsBackPaths(double sx, double sy) {
    return [
      Path()
        ..moveTo(58 * sx, 200 * sy)
        ..cubicTo(52 * sx, 218 * sy, 48 * sx, 240 * sy, 50 * sx, 264 * sy)
        ..cubicTo(52 * sx, 280 * sy, 58 * sx, 292 * sy, 68 * sx, 294 * sy)
        ..cubicTo(74 * sx, 284 * sy, 76 * sx, 268 * sy, 74 * sx, 248 * sy)
        ..cubicTo(72 * sx, 224 * sy, 68 * sx, 208 * sy, 64 * sx, 200 * sy)
        ..cubicTo(62 * sx, 198 * sy, 60 * sx, 198 * sy, 58 * sx, 200 * sy)
        ..close(),
      Path()
        ..moveTo(202 * sx, 200 * sy)
        ..cubicTo(208 * sx, 218 * sy, 212 * sx, 240 * sy, 210 * sx, 264 * sy)
        ..cubicTo(208 * sx, 280 * sy, 202 * sx, 292 * sy, 192 * sx, 294 * sy)
        ..cubicTo(186 * sx, 284 * sy, 184 * sx, 268 * sy, 186 * sx, 248 * sy)
        ..cubicTo(188 * sx, 224 * sy, 192 * sx, 208 * sy, 196 * sx, 200 * sy)
        ..cubicTo(198 * sx, 198 * sy, 200 * sx, 198 * sy, 202 * sx, 200 * sy)
        ..close(),
    ];
  }

  Path _getLowerBackPath(double sx, double sy) {
    return Path()
      ..moveTo(100 * sx, 222 * sy)
      ..cubicTo(112 * sx, 220 * sy, 148 * sx, 220 * sy, 160 * sx, 222 * sy)
      ..cubicTo(162 * sx, 240 * sy, 162 * sx, 258 * sy, 160 * sx, 274 * sy)
      ..cubicTo(148 * sx, 280 * sy, 112 * sx, 280 * sy, 100 * sx, 274 * sy)
      ..cubicTo(98 * sx, 258 * sy, 98 * sx, 240 * sy, 100 * sx, 222 * sy)
      ..close();
  }

  List<Path> _getGlutesPaths(double sx, double sy) {
    return [
      // Левая ягодица
      Path()
        ..moveTo(92 * sx, 258 * sy)
        ..cubicTo(100 * sx, 256 * sy, 118 * sx, 256 * sy, 130 * sx, 258 * sy)
        ..cubicTo(130 * sx, 280 * sy, 126 * sx, 298 * sy, 116 * sx, 304 * sy)
        ..cubicTo(104 * sx, 304 * sy, 92 * sx, 296 * sy, 86 * sx, 284 * sy)
        ..cubicTo(86 * sx, 274 * sy, 88 * sx, 266 * sy, 92 * sx, 258 * sy)
        ..close(),
      // Правая ягодица
      Path()
        ..moveTo(168 * sx, 258 * sy)
        ..cubicTo(160 * sx, 256 * sy, 142 * sx, 256 * sy, 130 * sx, 258 * sy)
        ..cubicTo(130 * sx, 280 * sy, 134 * sx, 298 * sy, 144 * sx, 304 * sy)
        ..cubicTo(156 * sx, 304 * sy, 168 * sx, 296 * sy, 174 * sx, 284 * sy)
        ..cubicTo(174 * sx, 274 * sy, 172 * sx, 266 * sy, 168 * sx, 258 * sy)
        ..close(),
    ];
  }

  List<Path> _getHamstringsPaths(double sx, double sy) {
    return [
      // Левое бедро (бицепс бедра)
      Path()
        ..moveTo(92 * sx, 292 * sy)
        ..cubicTo(100 * sx, 290 * sy, 112 * sx, 292 * sy, 118 * sx, 298 * sy)
        ..cubicTo(120 * sx, 322 * sy, 118 * sx, 348 * sy, 114 * sx, 370 * sy)
        ..cubicTo(108 * sx, 376 * sy, 98 * sx, 376 * sy, 90 * sx, 372 * sy)
        ..cubicTo(86 * sx, 348 * sy, 86 * sx, 320 * sy, 92 * sx, 292 * sy)
        ..close(),
      // Правое бедро
      Path()
        ..moveTo(168 * sx, 292 * sy)
        ..cubicTo(160 * sx, 290 * sy, 148 * sx, 292 * sy, 142 * sx, 298 * sy)
        ..cubicTo(140 * sx, 322 * sy, 142 * sx, 348 * sy, 146 * sx, 370 * sy)
        ..cubicTo(152 * sx, 376 * sy, 162 * sx, 376 * sy, 170 * sx, 372 * sy)
        ..cubicTo(174 * sx, 348 * sy, 174 * sx, 320 * sy, 168 * sx, 292 * sy)
        ..close(),
    ];
  }

  List<Path> _getCalvesBackPaths(double sx, double sy) {
    return [
      // Левая икра (икроножная)
      Path()
        ..moveTo(90 * sx, 372 * sy)
        ..cubicTo(98 * sx, 370 * sy, 110 * sx, 372 * sy, 116 * sx, 378 * sy)
        ..cubicTo(118 * sx, 398 * sy, 114 * sy, 416 * sy, 108 * sx, 424 * sy)
        ..cubicTo(102 * sx, 428 * sy, 94 * sx, 428 * sy, 88 * sx, 424 * sy)
        ..cubicTo(86 * sx, 412 * sy, 86 * sx, 392 * sy, 90 * sx, 372 * sy)
        ..close(),
      // Правая икра
      Path()
        ..moveTo(170 * sx, 372 * sy)
        ..cubicTo(162 * sx, 370 * sy, 150 * sx, 372 * sy, 144 * sx, 378 * sy)
        ..cubicTo(142 * sx, 398 * sy, 146 * sx, 416 * sy, 152 * sx, 424 * sy)
        ..cubicTo(158 * sx, 428 * sy, 166 * sx, 428 * sy, 172 * sx, 424 * sy)
        ..cubicTo(174 * sx, 412 * sy, 174 * sx, 392 * sy, 170 * sx, 372 * sy)
        ..close(),
    ];
  }

  // ==================== ХИТ-ТЕСТ ПО МЫШЦАМ ====================

  List<Path> _getMusclePaths(MuscleGroup muscle, double sx, double sy) {
    if (showBack) {
      switch (muscle) {
        case MuscleGroup.traps:
          return _getTrapsBackPaths(sx, sy);
        case MuscleGroup.shoulders:
          return _getShouldersBackPaths(sx, sy);
        case MuscleGroup.back:
          return _getBackPaths(sx, sy);
        case MuscleGroup.lats:
          return _getLatsPaths(sx, sy);
        case MuscleGroup.triceps:
          return _getTricepsBackPaths(sx, sy);
        case MuscleGroup.forearms:
          return _getForearmsBackPaths(sx, sy);
        case MuscleGroup.lowerBack:
          return [_getLowerBackPath(sx, sy)];
        case MuscleGroup.glutes:
          return _getGlutesPaths(sx, sy);
        case MuscleGroup.hamstrings:
          return _getHamstringsPaths(sx, sy);
        case MuscleGroup.calves:
          return _getCalvesBackPaths(sx, sy);
        default:
          return [];
      }
    } else {
      switch (muscle) {
        case MuscleGroup.traps:
          return _getTrapsFrontPaths(sx, sy);
        case MuscleGroup.shoulders:
          return _getShouldersFrontPaths(sx, sy);
        case MuscleGroup.chest:
          return _getChestPaths(sx, sy);
        case MuscleGroup.biceps:
          return _getBicepsFrontPaths(sx, sy);
        case MuscleGroup.triceps:
          return _getTricepsFrontPaths(sx, sy);
        case MuscleGroup.forearms:
          return _getForearmsFrontPaths(sx, sy);
        case MuscleGroup.abs:
          return [_getAbsPath(sx, sy)];
        case MuscleGroup.obliques:
          return _getObliquesPaths(sx, sy);
        case MuscleGroup.quadriceps:
          return _getQuadricepsPaths(sx, sy);
        case MuscleGroup.calves:
          return _getCalvesFrontPaths(sx, sy);
        default:
          return [];
      }
    }
  }

  @override
  bool shouldRepaint(covariant MuscleMapPainter oldDelegate) {
    return oldDelegate.selectedMuscle != selectedMuscle ||
        oldDelegate.hoveredMuscle != hoveredMuscle ||
        oldDelegate.volumeData != volumeData ||
        oldDelegate.showBack != showBack;
  }
}

// ==================== ИНТЕРАКТИВНАЯ ВЕРСИЯ ====================

class InteractiveMuscleMap extends StatefulWidget {
  final Function(MuscleGroup)? onMuscleSelected;
  final MuscleGroup? initialSelected;
  final Map<MuscleGroup, double>? volumeData;

  const InteractiveMuscleMap({
    super.key,
    this.onMuscleSelected,
    this.initialSelected,
    this.volumeData,
  });

  @override
  State<InteractiveMuscleMap> createState() => _InteractiveMuscleMapState();
}

class _InteractiveMuscleMapState extends State<InteractiveMuscleMap> {
  MuscleGroup? _selected;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewButton('Перед', !_showBack, () {
                setState(() => _showBack = false);
              }, isDark),
              const SizedBox(width: 2),
              _buildViewButton('Спина', _showBack, () {
                setState(() => _showBack = true);
              }, isDark),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (details) {
                  final muscle = _hitTestMuscle(
                    details.localPosition,
                    Size(constraints.maxWidth, constraints.maxHeight),
                  );
                  if (muscle != null) {
                    HapticFeedback.lightImpact();
                    setState(() => _selected = muscle);
                    widget.onMuscleSelected?.call(muscle);
                  }
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: MuscleMapPainter(
                    selectedMuscle: _selected,
                    hoveredMuscle: null,
                    volumeData: widget.volumeData,
                    isDark: isDark,
                    showBack: _showBack,
                  ),
                ),
              );
            },
          ),
        ),
        if (_selected != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _selected!.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _selected!.color.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fitness_center, size: 14, color: _selected!.color),
                const SizedBox(width: 6),
                Text(
                  'Выбрано: ${_selected!.displayName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selected!.color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildViewButton(String label, bool isActive, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF6B35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : (isDark ? Colors.white38 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  MuscleGroup? _hitTestMuscle(Offset position, Size size) {
    final sx = size.width / 260;
    final sy = size.height / 420;

    final paths = <MapEntry<MuscleGroup, List<Path>>>[];

    if (_showBack) {
      paths.addAll([
        MapEntry(MuscleGroup.shoulders, _getShouldersBackPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.traps, _getTrapsBackPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.triceps, _getTricepsBackPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.forearms, _getForearmsBackPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.back, _getBackPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.lats, _getLatsPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.lowerBack, [_getLowerBackPathStatic(sx, sy)]),
        MapEntry(MuscleGroup.glutes, _getGlutesPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.hamstrings, _getHamstringsPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.calves, _getCalvesBackPathsStatic(sx, sy)),
      ]);
    } else {
      paths.addAll([
        MapEntry(MuscleGroup.shoulders, _getShouldersFrontPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.traps, _getTrapsFrontPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.chest, _getChestPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.biceps, _getBicepsFrontPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.triceps, _getTricepsFrontPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.forearms, _getForearmsFrontPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.abs, [_getAbsPathStatic(sx, sy)]),
        MapEntry(MuscleGroup.obliques, _getObliquesPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.quadriceps, _getQuadricepsPathsStatic(sx, sy)),
        MapEntry(MuscleGroup.calves, _getCalvesFrontPathsStatic(sx, sy)),
      ]);
    }

    for (final entry in paths) {
      for (final path in entry.value) {
        if (path.contains(position)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  static List<Path> _getTrapsFrontPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(104 * sx, 78 * sy)
        ..cubicTo(108 * sx, 74 * sy, 120 * sx, 72 * sy, 130 * sx, 72 * sy)
        ..cubicTo(140 * sx, 72 * sy, 152 * sx, 74 * sy, 156 * sx, 78 * sy)
        ..cubicTo(162 * sx, 86 * sy, 164 * sx, 96 * sy, 156 * sx, 102 * sy)
        ..cubicTo(148 * sx, 98 * sy, 140 * sx, 96 * sy, 130 * sx, 96 * sy)
        ..cubicTo(120 * sx, 96 * sy, 112 * sx, 98 * sy, 104 * sx, 102 * sy)
        ..cubicTo(96 * sx, 96 * sy, 98 * sx, 86 * sy, 104 * sx, 78 * sy)
        ..close(),
    ];
  }

  static List<Path> _getShouldersFrontPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(78 * sx, 98 * sy)
        ..cubicTo(66 * sx, 98 * sy, 56 * sx, 104 * sy, 50 * sx, 114 * sy)
        ..cubicTo(46 * sx, 124 * sy, 50 * sx, 138 * sy, 60 * sx, 146 * sy)
        ..cubicTo(68 * sx, 140 * sy, 76 * sx, 132 * sy, 80 * sx, 122 * sy)
        ..cubicTo(84 * sx, 112 * sy, 84 * sx, 104 * sy, 78 * sx, 98 * sy)
        ..close(),
      Path()
        ..moveTo(182 * sx, 98 * sy)
        ..cubicTo(194 * sx, 98 * sy, 204 * sx, 104 * sy, 210 * sx, 114 * sy)
        ..cubicTo(214 * sx, 124 * sy, 210 * sx, 138 * sy, 200 * sx, 146 * sy)
        ..cubicTo(192 * sx, 140 * sy, 184 * sx, 132 * sy, 180 * sx, 122 * sy)
        ..cubicTo(176 * sx, 112 * sy, 176 * sx, 104 * sy, 182 * sx, 98 * sy)
        ..close(),
    ];
  }

  static List<Path> _getChestPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(84 * sx, 104 * sy)
        ..cubicTo(94 * sx, 100 * sy, 112 * sx, 100 * sy, 128 * sx, 104 * sy)
        ..cubicTo(128 * sx, 114 * sy, 128 * sx, 126 * sy, 128 * sx, 138 * sy)
        ..cubicTo(116 * sx, 144 * sy, 102 * sx, 144 * sy, 90 * sx, 142 * sy)
        ..cubicTo(82 * sx, 138 * sy, 78 * sx, 128 * sy, 78 * sx, 118 * sy)
        ..cubicTo(78 * sx, 110 * sy, 80 * sx, 106 * sy, 84 * sx, 104 * sy)
        ..close(),
      Path()
        ..moveTo(176 * sx, 104 * sy)
        ..cubicTo(166 * sx, 100 * sy, 148 * sx, 100 * sy, 132 * sx, 104 * sy)
        ..cubicTo(132 * sx, 114 * sy, 132 * sx, 126 * sy, 132 * sx, 138 * sy)
        ..cubicTo(144 * sx, 144 * sy, 158 * sx, 144 * sy, 170 * sx, 142 * sy)
        ..cubicTo(178 * sx, 138 * sy, 182 * sx, 128 * sy, 182 * sx, 118 * sy)
        ..cubicTo(182 * sx, 110 * sy, 180 * sx, 106 * sy, 176 * sx, 104 * sy)
        ..close(),
    ];
  }

  static List<Path> _getBicepsFrontPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(64 * sx, 134 * sy)
        ..cubicTo(58 * sx, 142 * sy, 52 * sx, 154 * sy, 50 * sx, 168 * sy)
        ..cubicTo(48 * sx, 182 * sy, 50 * sx, 192 * sy, 58 * sx, 198 * sy)
        ..cubicTo(66 * sx, 198 * sy, 72 * sx, 192 * sy, 76 * sx, 182 * sy)
        ..cubicTo(80 * sx, 168 * sy, 78 * sx, 150 * sy, 74 * sx, 140 * sy)
        ..cubicTo(72 * sx, 136 * sy, 68 * sx, 134 * sy, 64 * sx, 134 * sy)
        ..close(),
      Path()
        ..moveTo(196 * sx, 134 * sy)
        ..cubicTo(202 * sx, 142 * sy, 208 * sx, 154 * sy, 210 * sx, 168 * sy)
        ..cubicTo(212 * sx, 182 * sy, 210 * sx, 192 * sy, 202 * sx, 198 * sy)
        ..cubicTo(194 * sx, 198 * sy, 188 * sx, 192 * sy, 184 * sx, 182 * sy)
        ..cubicTo(180 * sx, 168 * sy, 182 * sx, 150 * sy, 186 * sx, 140 * sy)
        ..cubicTo(188 * sx, 136 * sy, 192 * sx, 134 * sy, 196 * sx, 134 * sy)
        ..close(),
    ];
  }

  static List<Path> _getTricepsFrontPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(74 * sx, 132 * sy)
        ..cubicTo(78 * sx, 144 * sy, 82 * sx, 160 * sy, 80 * sx, 176 * sy)
        ..cubicTo(78 * sx, 186 * sy, 74 * sx, 192 * sy, 70 * sx, 192 * sy)
        ..cubicTo(78 * sx, 188 * sy, 84 * sx, 180 * sy, 86 * sx, 168 * sy)
        ..cubicTo(88 * sx, 152 * sy, 86 * sx, 138 * sy, 82 * sx, 128 * sy)
        ..cubicTo(80 * sx, 128 * sy, 76 * sx, 130 * sy, 74 * sx, 132 * sy)
        ..close(),
      Path()
        ..moveTo(186 * sx, 132 * sy)
        ..cubicTo(182 * sx, 144 * sy, 178 * sx, 160 * sy, 180 * sx, 176 * sy)
        ..cubicTo(182 * sx, 186 * sy, 186 * sx, 192 * sy, 190 * sx, 192 * sy)
        ..cubicTo(182 * sx, 188 * sy, 176 * sx, 180 * sy, 174 * sx, 168 * sy)
        ..cubicTo(172 * sx, 152 * sy, 174 * sx, 138 * sy, 178 * sx, 128 * sy)
        ..cubicTo(180 * sx, 128 * sy, 184 * sx, 130 * sy, 186 * sx, 132 * sy)
        ..close(),
    ];
  }

  static List<Path> _getForearmsFrontPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(54 * sx, 196 * sy)
        ..cubicTo(48 * sx, 212 * sy, 46 * sx, 232 * sy, 46 * sx, 254 * sy)
        ..cubicTo(46 * sx, 272 * sy, 48 * sx, 286 * sy, 56 * sx, 292 * sy)
        ..cubicTo(64 * sx, 288 * sy, 70 * sx, 278 * sy, 70 * sx, 264 * sy)
        ..cubicTo(70 * sx, 240 * sy, 66 * sx, 216 * sy, 62 * sx, 204 * sy)
        ..cubicTo(60 * sx, 200 * sy, 58 * sx, 196 * sy, 54 * sx, 196 * sy)
        ..close(),
      Path()
        ..moveTo(206 * sx, 196 * sy)
        ..cubicTo(212 * sx, 212 * sy, 214 * sx, 232 * sy, 214 * sx, 254 * sy)
        ..cubicTo(214 * sx, 272 * sy, 212 * sx, 286 * sy, 204 * sx, 292 * sy)
        ..cubicTo(196 * sx, 288 * sy, 190 * sx, 278 * sy, 190 * sx, 264 * sy)
        ..cubicTo(190 * sx, 240 * sy, 194 * sx, 216 * sy, 198 * sx, 204 * sy)
        ..cubicTo(200 * sx, 200 * sy, 202 * sx, 196 * sy, 206 * sx, 196 * sy)
        ..close(),
    ];
  }

  static Path _getAbsPathStatic(double sx, double sy) {
    return Path()
      ..moveTo(106 * sx, 144 * sy)
      ..cubicTo(116 * sx, 142 * sy, 144 * sx, 142 * sy, 154 * sx, 144 * sy)
      ..cubicTo(156 * sx, 168 * sy, 156 * sx, 194 * sy, 156 * sx, 220 * sy)
      ..cubicTo(156 * sx, 236 * sy, 154 * sx, 250 * sy, 148 * sx, 258 * sy)
      ..cubicTo(140 * sx, 262 * sy, 120 * sx, 262 * sy, 112 * sx, 258 * sy)
      ..cubicTo(106 * sx, 250 * sy, 104 * sx, 236 * sy, 104 * sx, 220 * sy)
      ..cubicTo(104 * sx, 194 * sy, 104 * sx, 168 * sy, 106 * sx, 144 * sy)
      ..close();
  }

  static List<Path> _getObliquesPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(86 * sx, 148 * sy)
        ..cubicTo(90 * sx, 144 * sy, 100 * sx, 144 * sy, 106 * sx, 146 * sy)
        ..cubicTo(106 * sx, 174 * sy, 104 * sx, 204 * sy, 100 * sx, 234 * sy)
        ..cubicTo(94 * sx, 242 * sy, 88 * sx, 248 * sy, 82 * sx, 246 * sy)
        ..cubicTo(78 * sx, 236 * sy, 78 * sx, 218 * sy, 80 * sx, 192 * sy)
        ..cubicTo(82 * sx, 170 * sy, 84 * sx, 156 * sy, 86 * sx, 148 * sy)
        ..close(),
      Path()
        ..moveTo(174 * sx, 148 * sy)
        ..cubicTo(170 * sx, 144 * sy, 160 * sx, 144 * sy, 154 * sx, 146 * sy)
        ..cubicTo(154 * sx, 174 * sy, 156 * sx, 204 * sy, 160 * sx, 234 * sy)
        ..cubicTo(166 * sx, 242 * sy, 172 * sx, 248 * sy, 178 * sx, 246 * sy)
        ..cubicTo(182 * sx, 236 * sy, 182 * sx, 218 * sy, 180 * sx, 192 * sy)
        ..cubicTo(178 * sx, 170 * sy, 176 * sx, 156 * sy, 174 * sx, 148 * sy)
        ..close(),
    ];
  }

  static List<Path> _getQuadricepsPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(92 * sx, 276 * sy)
        ..cubicTo(102 * sx, 274 * sy, 112 * sx, 276 * sy, 118 * sx, 282 * sy)
        ..cubicTo(120 * sx, 306 * sy, 118 * sx, 334 * sy, 114 * sx, 362 * sy)
        ..cubicTo(108 * sx, 370 * sy, 98 * sx, 370 * sy, 90 * sx, 366 * sy)
        ..cubicTo(86 * sx, 340 * sy, 86 * sx, 310 * sy, 92 * sx, 276 * sy)
        ..close(),
      Path()
        ..moveTo(168 * sx, 276 * sy)
        ..cubicTo(158 * sx, 274 * sy, 148 * sx, 276 * sy, 142 * sx, 282 * sy)
        ..cubicTo(140 * sx, 306 * sy, 142 * sx, 334 * sy, 146 * sx, 362 * sy)
        ..cubicTo(152 * sx, 370 * sy, 162 * sx, 370 * sy, 170 * sx, 366 * sy)
        ..cubicTo(174 * sx, 340 * sy, 174 * sx, 310 * sy, 168 * sx, 276 * sy)
        ..close(),
    ];
  }

  static List<Path> _getCalvesFrontPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(90 * sx, 366 * sy)
        ..cubicTo(98 * sx, 364 * sy, 108 * sx, 366 * sy, 114 * sx, 372 * sy)
        ..cubicTo(116 * sx, 390 * sy, 112 * sx, 406 * sy, 106 * sx, 418 * sy)
        ..cubicTo(100 * sx, 422 * sy, 92 * sx, 422 * sy, 86 * sx, 418 * sy)
        ..cubicTo(84 * sx, 404 * sy, 84 * sx, 386 * sy, 90 * sx, 366 * sy)
        ..close(),
      Path()
        ..moveTo(170 * sx, 366 * sy)
        ..cubicTo(162 * sx, 364 * sy, 152 * sx, 366 * sy, 146 * sx, 372 * sy)
        ..cubicTo(144 * sx, 390 * sy, 148 * sx, 406 * sy, 154 * sx, 418 * sy)
        ..cubicTo(160 * sx, 422 * sy, 168 * sx, 422 * sy, 174 * sx, 418 * sy)
        ..cubicTo(176 * sx, 404 * sy, 176 * sx, 386 * sy, 170 * sx, 366 * sy)
        ..close(),
    ];
  }

  static List<Path> _getTrapsBackPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(100 * sx, 76 * sy)
        ..cubicTo(110 * sx, 74 * sy, 122 * sx, 72 * sy, 130 * sx, 72 * sy)
        ..cubicTo(138 * sx, 72 * sy, 150 * sx, 74 * sy, 160 * sx, 76 * sy)
        ..cubicTo(170 * sx, 88 * sy, 172 * sx, 106 * sy, 164 * sx, 120 * sy)
        ..cubicTo(154 * sx, 114 * sy, 142 * sx, 110 * sy, 130 * sx, 110 * sy)
        ..cubicTo(118 * sx, 110 * sy, 106 * sx, 114 * sy, 96 * sx, 120 * sy)
        ..cubicTo(88 * sx, 106 * sy, 90 * sx, 88 * sy, 100 * sx, 76 * sy)
        ..close(),
    ];
  }

  static List<Path> _getShouldersBackPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(78 * sx, 98 * sy)
        ..cubicTo(66 * sx, 98 * sy, 54 * sx, 104 * sy, 48 * sx, 114 * sy)
        ..cubicTo(44 * sx, 126 * sy, 50 * sx, 140 * sy, 62 * sx, 146 * sy)
        ..cubicTo(72 * sx, 140 * sy, 80 * sx, 130 * sy, 82 * sx, 118 * sy)
        ..cubicTo(84 * sx, 108 * sy, 82 * sx, 102 * sy, 78 * sx, 98 * sy)
        ..close(),
      Path()
        ..moveTo(182 * sx, 98 * sy)
        ..cubicTo(194 * sx, 98 * sy, 206 * sx, 104 * sy, 212 * sx, 114 * sy)
        ..cubicTo(216 * sx, 126 * sy, 210 * sx, 140 * sy, 198 * sx, 146 * sy)
        ..cubicTo(188 * sx, 140 * sy, 180 * sx, 130 * sy, 178 * sx, 118 * sy)
        ..cubicTo(176 * sx, 108 * sy, 178 * sx, 102 * sy, 182 * sx, 98 * sy)
        ..close(),
    ];
  }

  static List<Path> _getBackPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(94 * sx, 112 * sy)
        ..cubicTo(106 * sx, 108 * sy, 122 * sx, 106 * sy, 130 * sx, 106 * sy)
        ..cubicTo(138 * sx, 106 * sy, 154 * sx, 108 * sy, 166 * sx, 112 * sy)
        ..cubicTo(170 * sx, 130 * sy, 166 * sx, 148 * sy, 158 * sy, 162 * sy)
        ..cubicTo(148 * sx, 158 * sy, 138 * sx, 154 * sy, 130 * sx, 154 * sy)
        ..cubicTo(122 * sx, 154 * sy, 112 * sx, 158 * sy, 102 * sx, 162 * sy)
        ..cubicTo(94 * sx, 148 * sy, 90 * sx, 130 * sy, 94 * sx, 112 * sy)
        ..close(),
    ];
  }

  static List<Path> _getLatsPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(86 * sx, 140 * sy)
        ..cubicTo(82 * sx, 160 * sy, 82 * sx, 186 * sy, 88 * sx, 212 * sy)
        ..cubicTo(94 * sx, 222 * sy, 104 * sx, 226 * sy, 116 * sx, 222 * sy)
        ..cubicTo(124 * sx, 210 * sy, 128 * sx, 190 * sy, 126 * sx, 166 * sy)
        ..cubicTo(118 * sx, 152 * sy, 104 * sx, 144 * sy, 86 * sx, 140 * sy)
        ..close(),
      Path()
        ..moveTo(174 * sx, 140 * sy)
        ..cubicTo(178 * sx, 160 * sy, 178 * sx, 186 * sy, 172 * sx, 212 * sy)
        ..cubicTo(166 * sx, 222 * sy, 156 * sx, 226 * sy, 144 * sx, 222 * sy)
        ..cubicTo(136 * sx, 210 * sy, 132 * sx, 190 * sy, 134 * sx, 166 * sy)
        ..cubicTo(142 * sx, 152 * sy, 156 * sx, 144 * sy, 174 * sx, 140 * sy)
        ..close(),
    ];
  }

  static List<Path> _getTricepsBackPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(68 * sx, 136 * sy)
        ..cubicTo(60 * sx, 148 * sy, 56 * sx, 166 * sy, 58 * sx, 186 * sy)
        ..cubicTo(60 * sx, 198 * sy, 66 * sx, 204 * sy, 74 * sx, 202 * sy)
        ..cubicTo(80 * sx, 192 * sy, 82 * sx, 174 * sy, 80 * sx, 156 * sy)
        ..cubicTo(78 * sx, 146 * sy, 74 * sx, 138 * sy, 68 * sx, 136 * sy)
        ..close(),
      Path()
        ..moveTo(192 * sx, 136 * sy)
        ..cubicTo(200 * sx, 148 * sy, 204 * sx, 166 * sy, 202 * sx, 186 * sy)
        ..cubicTo(200 * sx, 198 * sy, 194 * sx, 204 * sy, 186 * sx, 202 * sy)
        ..cubicTo(180 * sx, 192 * sy, 178 * sx, 174 * sy, 180 * sx, 156 * sy)
        ..cubicTo(182 * sx, 146 * sy, 186 * sx, 138 * sy, 192 * sx, 136 * sy)
        ..close(),
    ];
  }

  static List<Path> _getForearmsBackPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(58 * sx, 200 * sy)
        ..cubicTo(52 * sx, 218 * sy, 48 * sx, 240 * sy, 50 * sx, 264 * sy)
        ..cubicTo(52 * sx, 280 * sy, 58 * sx, 292 * sy, 68 * sx, 294 * sy)
        ..cubicTo(74 * sx, 284 * sy, 76 * sx, 268 * sy, 74 * sx, 248 * sy)
        ..cubicTo(72 * sx, 224 * sy, 68 * sx, 208 * sy, 64 * sx, 200 * sy)
        ..cubicTo(62 * sx, 198 * sy, 60 * sx, 198 * sy, 58 * sx, 200 * sy)
        ..close(),
      Path()
        ..moveTo(202 * sx, 200 * sy)
        ..cubicTo(208 * sx, 218 * sy, 212 * sx, 240 * sy, 210 * sx, 264 * sy)
        ..cubicTo(208 * sx, 280 * sy, 202 * sx, 292 * sy, 192 * sx, 294 * sy)
        ..cubicTo(186 * sx, 284 * sy, 184 * sx, 268 * sy, 186 * sx, 248 * sy)
        ..cubicTo(188 * sx, 224 * sy, 192 * sx, 208 * sy, 196 * sx, 200 * sy)
        ..cubicTo(198 * sx, 198 * sy, 200 * sx, 198 * sy, 202 * sx, 200 * sy)
        ..close(),
    ];
  }

  static Path _getLowerBackPathStatic(double sx, double sy) {
    return Path()
      ..moveTo(100 * sx, 222 * sy)
      ..cubicTo(112 * sx, 220 * sy, 148 * sx, 220 * sy, 160 * sx, 222 * sy)
      ..cubicTo(162 * sx, 240 * sy, 162 * sx, 258 * sy, 160 * sx, 274 * sy)
      ..cubicTo(148 * sx, 280 * sy, 112 * sx, 280 * sy, 100 * sx, 274 * sy)
      ..cubicTo(98 * sx, 258 * sy, 98 * sx, 240 * sy, 100 * sx, 222 * sy)
      ..close();
  }

  static List<Path> _getGlutesPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(92 * sx, 258 * sy)
        ..cubicTo(100 * sx, 256 * sy, 118 * sx, 256 * sy, 130 * sx, 258 * sy)
        ..cubicTo(130 * sx, 280 * sy, 126 * sx, 298 * sy, 116 * sx, 304 * sy)
        ..cubicTo(104 * sx, 304 * sy, 92 * sx, 296 * sy, 86 * sx, 284 * sy)
        ..cubicTo(86 * sx, 274 * sy, 88 * sx, 266 * sy, 92 * sx, 258 * sy)
        ..close(),
      Path()
        ..moveTo(168 * sx, 258 * sy)
        ..cubicTo(160 * sx, 256 * sy, 142 * sx, 256 * sy, 130 * sx, 258 * sy)
        ..cubicTo(130 * sx, 280 * sy, 134 * sx, 298 * sy, 144 * sx, 304 * sy)
        ..cubicTo(156 * sx, 304 * sy, 168 * sx, 296 * sy, 174 * sx, 284 * sy)
        ..cubicTo(174 * sx, 274 * sy, 172 * sx, 266 * sy, 168 * sx, 258 * sy)
        ..close(),
    ];
  }

  static List<Path> _getHamstringsPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(92 * sx, 292 * sy)
        ..cubicTo(100 * sx, 290 * sy, 112 * sx, 292 * sy, 118 * sx, 298 * sy)
        ..cubicTo(120 * sx, 322 * sy, 118 * sx, 348 * sy, 114 * sx, 370 * sy)
        ..cubicTo(108 * sx, 376 * sy, 98 * sx, 376 * sy, 90 * sx, 372 * sy)
        ..cubicTo(86 * sx, 348 * sy, 86 * sx, 320 * sy, 92 * sx, 292 * sy)
        ..close(),
      Path()
        ..moveTo(168 * sx, 292 * sy)
        ..cubicTo(160 * sx, 290 * sy, 148 * sx, 292 * sy, 142 * sx, 298 * sy)
        ..cubicTo(140 * sx, 322 * sy, 142 * sx, 348 * sy, 146 * sx, 370 * sy)
        ..cubicTo(152 * sx, 376 * sy, 162 * sx, 376 * sy, 170 * sx, 372 * sy)
        ..cubicTo(174 * sx, 348 * sy, 174 * sx, 320 * sy, 168 * sx, 292 * sy)
        ..close(),
    ];
  }

  static List<Path> _getCalvesBackPathsStatic(double sx, double sy) {
    return [
      Path()
        ..moveTo(90 * sx, 372 * sy)
        ..cubicTo(98 * sx, 370 * sy, 110 * sx, 372 * sy, 116 * sx, 378 * sy)
        ..cubicTo(118 * sx, 398 * sy, 114 * sx, 416 * sy, 108 * sx, 424 * sy)
        ..cubicTo(102 * sx, 428 * sy, 94 * sx, 428 * sy, 88 * sx, 424 * sy)
        ..cubicTo(86 * sx, 412 * sy, 86 * sx, 392 * sy, 90 * sx, 372 * sy)
        ..close(),
      Path()
        ..moveTo(170 * sx, 372 * sy)
        ..cubicTo(162 * sx, 370 * sy, 150 * sx, 372 * sy, 144 * sx, 378 * sy)
        ..cubicTo(142 * sx, 398 * sy, 146 * sx, 416 * sy, 152 * sx, 424 * sy)
        ..cubicTo(158 * sx, 428 * sy, 166 * sx, 428 * sy, 172 * sx, 424 * sy)
        ..cubicTo(174 * sx, 412 * sy, 174 * sx, 392 * sy, 170 * sx, 372 * sy)
        ..close(),
    ];
  }
}