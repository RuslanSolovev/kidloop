// features/life_navigator/ui/widgets/ideas/ideas_details.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';
import 'ideas_common.dart';
import 'ideas_add_edit.dart';

// ============================================================
// ДЕТАЛЬНЫЙ ПРОСМОТР (с кликом по фото)
// ============================================================

class IdeaDetailsSheet extends StatefulWidget {
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
  State<IdeaDetailsSheet> createState() => _IdeaDetailsSheetState();
}

class _IdeaDetailsSheetState extends State<IdeaDetailsSheet> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.idea.isFavorite;
  }

  void _toggleFavorite() {
    HapticFeedback.lightImpact();
    final newValue = !_isFavorite;
    setState(() => _isFavorite = newValue);
    widget.provider.updateIdea(widget.idea.copyWith(isFavorite: newValue));
  }

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    final isDark = widget.isDark;
    final images = idea.images;

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
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Статус
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_getStatusColor().withOpacity(0.15), _getStatusColor().withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor().withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_getStatusEmoji(), style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(_getStatusText(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getStatusColor())),
                    ],
                  ),
                ),
                const Spacer(),
                // ICE Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_getIceColor(idea.iceScore).withOpacity(0.15), _getIceColor(idea.iceScore).withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getIceColor(idea.iceScore).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ICE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _getIceColor(idea.iceScore).withOpacity(0.7))),
                      const SizedBox(width: 6),
                      Text(idea.iceScore.toStringAsFixed(1), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _getIceColor(idea.iceScore))),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Название
            Text(
              idea.title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24), height: 1.2),
            ),

            // Описание
            if (idea.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                idea.description,
                style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ],

            // Фото
            if (images.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Фото:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.grey.shade600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (ctx, index) => GestureDetector(
                    onTap: () => showFullscreenImage(context, images[index], isDark: isDark),
                    child: Hero(
                      tag: 'fullscreen_image_${images[index]}',
                      child: Container(
                        width: 120, height: 120, margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(image: getImageProvider(images[index]), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Детали
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, isDark ? Colors.white.withOpacity(0.01) : Colors.white]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200, width: 1),
              ),
              child: Column(
                children: [
                  Row(children: [
                    DetailItem(label: 'Категория', value: _getCategoryEmoji(idea.category), color: Colors.purple),
                    DetailItem(label: 'Рейтинг', value: '⭐' * idea.rating, color: Colors.amber),
                    DetailItem(label: 'Приоритет', value: _getPriorityLabel(idea.priority), color: _getPriorityColor(idea.priority)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    DetailItem(label: 'Срочность', value: '${idea.impact}', color: _getIceColor(idea.impact.toDouble())),
                    DetailItem(label: 'Трудность', value: '${idea.confidence}', color: _getIceColor(idea.confidence.toDouble())),
                    DetailItem(label: 'Интерес', value: '${idea.ease}', color: _getIceColor(idea.ease.toDouble())),
                  ]),
                ],
              ),
            ),

            // Теги
            if (idea.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: idea.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.purple.withOpacity(0.12), Colors.purple.withOpacity(0.04)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.withOpacity(0.12)),
                  ),
                  child: Text('#$tag', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple)),
                )).toList(),
              ),
            ],

            const SizedBox(height: 20),

            // КНОПКИ: Избранное и Редактировать над Продвинуть и Удалить
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _toggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isFavorite ? Colors.red.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _isFavorite ? Colors.red.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: _isFavorite ? Colors.red : (isDark ? Colors.white.withOpacity(0.5) : Colors.grey),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isFavorite ? 'В избранном' : 'В избранное',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isFavorite ? Colors.red : (isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onClose();
                      _showEditDialog(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Редактировать',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Продвинуть и Удалить
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
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
                      widget.provider.updateIdea(idea.copyWith(status: nextStatus));
                      widget.onClose();
                    },
                    icon: Icon(idea.status == 'done' ? Icons.refresh_rounded : Icons.arrow_forward_rounded, size: 18),
                    label: Text(idea.status == 'done' ? 'Вернуть' : 'Продвинуть', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: idea.status == 'done' ? const Color(0xFFFF6B35) : const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _confirmDelete(context);
                    },
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    label: const Text('Удалить', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onClose,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300),
                ),
                child: Text('Закрыть', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить задачу?'),
        content: Text('"${widget.idea.title}" будет удалена без возможности восстановления', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.provider.deleteIdea(widget.idea.id);
              widget.onClose();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => EditIdeaSheet(
        isDark: widget.isDark,
        idea: widget.idea,
        provider: widget.provider,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.idea.status) {
      case 'idea': return const Color(0xFF4A9EFF);
      case 'in_progress': return const Color(0xFFFF6B35);
      case 'done': return const Color(0xFF00C853);
      default: return Colors.grey;
    }
  }

  String _getStatusEmoji() {
    switch (widget.idea.status) {
      case 'idea': return '💡';
      case 'in_progress': return '⚡';
      case 'done': return '✅';
      default: return '';
    }
  }

  String _getStatusText() {
    switch (widget.idea.status) {
      case 'idea': return 'Новая';
      case 'in_progress': return 'В процессе';
      case 'done': return 'Готово';
      default: return widget.idea.status;
    }
  }

  Color _getIceColor(double score) {
    if (score >= 7) return const Color(0xFF00C853);
    if (score >= 4) return const Color(0xFFFF6B35);
    return const Color(0xFFFF1744);
  }

  String _getCategoryEmoji(String category) {
    final map = {'business': '💼', 'creative': '🎨', 'tech': '💻', 'home': '🏠', 'health': '❤️', 'education': '📚'};
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