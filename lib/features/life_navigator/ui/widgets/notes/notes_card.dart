// features/life_navigator/ui/widgets/notes/notes_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'notes_constants.dart';
import 'notes_backgrounds.dart';

class NotesCard extends StatelessWidget {
  final LifeNote note;
  final bool isDark;
  final bool isGridView;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const NotesCard({
    super.key,
    required this.note,
    required this.isDark,
    this.isGridView = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final noteColor = NotesConstants.fromHex(note.color);
    final textColor = NotesConstants.getTextColorForBackground(noteColor);
    final noteBackground = _getBackground();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: NotesBackgrounds.build(
        type: noteBackground,
        color: noteColor,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: noteColor,
            borderRadius: BorderRadius.circular(isGridView ? 12 : 8),
            border: Border.all(
              color: noteColor == Colors.white
                  ? Colors.grey.shade300
                  : noteColor.withOpacity(0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: isGridView ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // 🔥 ЗАГОЛОВОК + ИЗБРАННОЕ
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isGridView ? 12 : 13,
                        color: textColor,
                        height: 1.2,
                      ),
                      maxLines: isGridView ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.isFavorite)
                    Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 16),
                  if (note.isFavorite) const SizedBox(width: 4),
                ],
              ),

              // 🔥 КОНТЕНТ
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    note.content,
                    style: TextStyle(
                      fontSize: isGridView ? 10 : 11,
                      color: textColor.withOpacity(0.7),
                      height: 1.3,
                    ),
                    maxLines: isGridView ? 5 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // 🔥 ТЕГИ
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: note.tags.take(isGridView ? 2 : 3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 9,
                          color: textColor.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const Spacer(),

              // 🔥 ДАТА + ФОТО-ИНДИКАТОР
              Row(
                children: [
                  Text(
                    _formatDate(note.updatedAt),
                    style: TextStyle(
                      fontSize: 9,
                      color: textColor.withOpacity(0.4),
                    ),
                  ),
                  const Spacer(),
                  if (note.content.length > 100)
                    Icon(Icons.article_rounded, size: 12, color: textColor.withOpacity(0.3)),
                  if (note.content.length > 100) const SizedBox(width: 4),
                  Icon(
                    Icons.more_vert_rounded,
                    size: 14,
                    color: textColor.withOpacity(0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  NoteBackgroundType _getBackground() {
    // Пока возвращаем plain, в будущем можно хранить в БД
    return NoteBackgroundType.plain;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${date.day}.${date.month}.${date.year}';
  }
}