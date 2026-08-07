// features/life_navigator/ui/widgets/notes/notes_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'notes_card.dart';

class NotesList extends StatefulWidget {
  final List<LifeNote> notes;
  final bool isDark;
  final LifeProvider provider;

  const NotesList({
    super.key,
    required this.notes,
    required this.isDark,
    required this.provider,
  });

  @override
  State<NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<NotesList> {
  String? _expandedNoteId;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.notes.length,
      itemBuilder: (context, index) {
        final note = widget.notes[index];
        final isExpanded = _expandedNoteId == note.id;

        return Column(
          children: [
            NotesCard(
              note: note,
              isDark: widget.isDark,
              isGridView: false,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _expandedNoteId = isExpanded ? null : note.id;
                });
              },
              onLongPress: () => _showNoteMenu(note),
            ),
            // 🔥 РАЗВОРАЧИВАЮЩИЙСЯ ПРОСМОТР
            AnimatedCrossFade(
              firstChild: _buildExpandedContent(note),
              secondChild: const SizedBox.shrink(),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpandedContent(LifeNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Полный контент
          if (note.content.isNotEmpty) ...[
            Text(
              note.content,
              style: TextStyle(
                fontSize: 13,
                color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Теги
          if (note.tags.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: note.tags.map((tag) => Chip(
                label: Text('#$tag', style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.purple.withOpacity(0.1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
          // Действия
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionChip(Icons.push_pin_rounded, 'Закрепить', Colors.orange, () {}),
              const SizedBox(width: 6),
              _buildActionChip(Icons.edit_rounded, 'Ред.', Colors.blue, () {}),
              const SizedBox(width: 6),
              _buildActionChip(Icons.star_rounded, note.isFavorite ? 'Избр.' : 'В избр.', Colors.amber, () {
                widget.provider.updateNote(LifeNote(
                  id: note.id,
                  title: note.title,
                  content: note.content,
                  tags: note.tags,
                  color: note.color,
                  isFavorite: !note.isFavorite,
                  createdAt: note.createdAt,
                ));
              }),
              const SizedBox(width: 6),
              _buildActionChip(Icons.delete_rounded, 'Удалить', Colors.red, () {
                widget.provider.deleteNote(note.id);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showNoteMenu(LifeNote note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuAction(Icons.push_pin_rounded, 'Закрепить', Colors.orange, () {
              Navigator.pop(ctx);
            }),
            _buildMenuAction(Icons.edit_rounded, 'Редактировать', Colors.blue, () {
              Navigator.pop(ctx);
            }),
            _buildMenuAction(Icons.star_rounded, note.isFavorite ? 'Убрать из избранного' : 'В избранное', Colors.amber, () {
              widget.provider.updateNote(LifeNote(
                id: note.id,
                title: note.title,
                content: note.content,
                tags: note.tags,
                color: note.color,
                isFavorite: !note.isFavorite,
                createdAt: note.createdAt,
              ));
              Navigator.pop(ctx);
            }),
            _buildMenuAction(Icons.delete_rounded, 'Удалить', Colors.red, () {
              Navigator.pop(ctx);
              widget.provider.deleteNote(note.id);
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}