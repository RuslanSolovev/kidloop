// features/life_navigator/ui/widgets/ideas/ideas_common.dart
import 'dart:io';
import 'package:flutter/material.dart';

// ============================================================
// УТИЛИТЫ
// ============================================================

/// Возвращает ImageProvider в зависимости от типа пути (URL или локальный файл)
ImageProvider getImageProvider(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  } else {
    return FileImage(File(path));
  }
}

/// Обрезает текст до первых N слов
String getShortDescription(String text, {int wordCount = 10}) {
  final words = text.split(' ');
  if (words.length <= wordCount) return text;
  return words.take(wordCount).join(' ') + '...';
}

/// Показывает фото в полноэкранном режиме
void showFullscreenImage(BuildContext context, String imagePath, {bool isDark = false}) {
  Navigator.push(
    context,
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => _FullscreenImage(
        imagePath: imagePath,
        isDark: isDark,
      ),
    ),
  );
}

// ============================================================
// ПОЛНОЭКРАННОЕ ФОТО (ВНУТРЕННИЙ ВИДЖЕТ)
// ============================================================

class _FullscreenImage extends StatelessWidget {
  final String imagePath;
  final bool isDark;

  const _FullscreenImage({
    required this.imagePath,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: Center(
          child: Hero(
            tag: 'fullscreen_image_$imagePath',
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image(
                image: getImageProvider(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade800,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ОБЩИЕ ВИДЖЕТЫ
// ============================================================

/// Бейдж для отображения ICE-оценки с цветом в зависимости от значения
class IceScoreBadge extends StatelessWidget {
  final double score;

  const IceScoreBadge({super.key, required this.score});

  Color get _color {
    if (score >= 7) return const Color(0xFF00C853);
    if (score >= 4) return const Color(0xFFFF6B35);
    return const Color(0xFFFF1744);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.15), _color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color, width: 1.5),
      ),
      child: Text(
        'ICE ${score.toStringAsFixed(1)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _color,
        ),
      ),
    );
  }
}

/// Кнопка-иконка (лайк, редактирование, удаление) - УВЕЛИЧЕНА
class ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isActive;
  final double size;

  const ActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isActive = false,
    this.size = 22, // Увеличен с 14 до 22
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (isActive ? color : color.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: size,
          color: isActive ? Colors.white : color,
        ),
      ),
    );
  }
}

/// Строка со слайдером для параметров ICE
class SliderRow extends StatelessWidget {
  final String label;
  final int value;
  final Function(int) onChanged;
  final Color color;
  final bool isDark;

  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: color,
                inactiveTrackColor: color.withOpacity(0.15),
                thumbColor: color,
                overlayColor: color.withOpacity(0.1),
              ),
              child: Slider(
                value: value.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка выбора источника фото (Галерея, Камера, URL)
class ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const ImageSourceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Элемент детальной информации (используется в _IdeaDetailsSheet)
class DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const DetailItem({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Стеклянная кнопка (используется в хедере)
class GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final double size;
  final bool isDark;

  const GlassButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

/// Стеклянная иконка (используется в хедере)
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDark ? Colors.white54 : Colors.grey.shade600);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              c.withOpacity(isDark ? 0.06 : 0.04),
              c.withOpacity(isDark ? 0.02 : 0.01),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: c.withOpacity(isDark ? 0.08 : 0.06),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: c,
          size: 20,
        ),
      ),
    );
  }
}

/// Стеклянная кнопка с текстом (для действий: Фильтр, Поиск, Добавить)
class GlassActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isActive;
  final Color? color;

  const GlassActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    required this.isActive,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isActive ? const Color(0xFF7C4DFF) : (isDark ? Colors.white54 : Colors.grey.shade600));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
            colors: [
              c.withOpacity(0.12),
              c.withOpacity(0.04),
            ],
          )
              : null,
          color: isActive ? null : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? c.withOpacity(0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: c,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}