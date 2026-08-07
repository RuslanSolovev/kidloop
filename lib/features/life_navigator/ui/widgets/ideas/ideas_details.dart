// features/life_navigator/ui/widgets/ideas/ideas_details.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';
import 'ideas_common.dart';

// ============================================================
// ДЕТАЛЬНЫЙ ПРОСМОТР (с кликом по фото)
// ============================================================

class IdeaDetailsSheet extends StatelessWidget {
  final bool isDark;
  final LifeIdea idea;
  final LifeProvider provider;
  final VoidCallback onClose;

  const IdeaDetailsSheet({
    super.key,
    required this.isDark,
    required this.idea,
    required this.provider,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> images = idea.images;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getStatusColor().withOpacity(0.15),
                        _getStatusColor().withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor().withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(_getStatusEmoji(), style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (idea.isFavorite)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.favorite_rounded, color: Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Избранное',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getIceColor(idea.iceScore).withOpacity(0.15),
                        _getIceColor(idea.iceScore).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getIceColor(idea.iceScore).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'ICE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _getIceColor(idea.iceScore).withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        idea.iceScore.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _getIceColor(idea.iceScore),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              idea.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1D24),
                height: 1.2,
              ),
            ),
            if (idea.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                idea.description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ],
            // ФОТО С ВОЗМОЖНОСТЬЮ КЛИКА
            if (images.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Фото:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (ctx, index) {
                    return GestureDetector(
                      onTap: () => showFullscreenImage(context, images[index], isDark: isDark),
                      child: Hero(
                        tag: 'fullscreen_image_${images[index]}',
                        child: Container(
                          width: 120,
                          height: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: getImageProvider(images[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                    isDark ? Colors.white.withOpacity(0.01) : Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  DetailItem(
                    label: 'Категория',
                    value: _getCategoryEmoji(idea.category),
                    color: Colors.purple,
                  ),
                  DetailItem(
                    label: 'Рейтинг',
                    value: '⭐' * idea.rating,
                    color: Colors.amber,
                  ),
                  DetailItem(
                    label: 'Приоритет',
                    value: _getPriorityLabel(idea.priority),
                    color: _getPriorityColor(idea.priority),
                  ),
                ],
              ),
            ),
            if (idea.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: idea.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withOpacity(0.12),
                        Colors.purple.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.purple.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple,
                    ),
                  ),
                )).toList(),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      String nextStatus;
                      if (idea.status == 'done') {
                        nextStatus = 'in_progress';
                      } else if (idea.status == 'in_progress') {
                        nextStatus = 'done';
                      } else {
                        nextStatus = 'in_progress';
                      }
                      provider.updateIdea(idea.copyWith(status: nextStatus));
                      onClose();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: idea.status == 'done' ? const Color(0xFFFF6B35) : const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          idea.status == 'done' ? Icons.refresh_rounded : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          idea.status == 'done' ? 'Вернуть в процесс' : 'Продвинуть',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      provider.deleteIdea(idea.id);
                      onClose();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Удалить', style: TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  'Закрыть',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (idea.status) {
      case 'idea':
        return const Color(0xFF4A9EFF);
      case 'in_progress':
        return const Color(0xFFFF6B35);
      case 'done':
        return const Color(0xFF00C853);
      default:
        return Colors.grey;
    }
  }

  String _getStatusEmoji() {
    switch (idea.status) {
      case 'idea':
        return '💡';
      case 'in_progress':
        return '⚡';
      case 'done':
        return '✅';
      default:
        return '';
    }
  }

  String _getStatusText() {
    switch (idea.status) {
      case 'idea':
        return 'Новая';
      case 'in_progress':
        return 'В процессе';
      case 'done':
        return 'Готово';
      default:
        return idea.status;
    }
  }

  Color _getIceColor(double score) {
    if (score >= 7) return const Color(0xFF00C853);
    if (score >= 4) return const Color(0xFFFF6B35);
    return const Color(0xFFFF1744);
  }

  String _getCategoryEmoji(String category) {
    final map = {
      'business': '💼',
      'creative': '🎨',
      'tech': '💻',
      'home': '🏠',
      'health': '❤️',
      'education': '📚',
    };
    return map[category] ?? '📋';
  }

  String _getPriorityLabel(int priority) {
    if (priority >= 8) return '🔥 Высокий';
    if (priority >= 5) return '📊 Средний';
    return '📉 Низкий';
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 8) return Colors.red;
    if (priority >= 5) return Colors.orange;
    return Colors.blue;
  }
}