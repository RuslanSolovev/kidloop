// features/life_navigator/ui/widgets/notes/notes_grid.dart
import 'package:flutter/material.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'notes_card.dart';

class NotesGrid extends StatelessWidget {
  final List<LifeNote> notes;
  final bool isDark;
  final LifeProvider provider;

  const NotesGrid({
    super.key,
    required this.notes,
    required this.isDark,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.85,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return NotesCard(
          note: note,
          isDark: isDark,
          isGridView: true,
          onTap: () => _showNoteDetail(context, note),
          onLongPress: () => _showNoteMenu(context, note),
        );
      },
    );
  }

  void _showNoteDetail(BuildContext context, LifeNote note) {
    // TODO: Открыть детальный просмотр
  }

  void _showNoteMenu(BuildContext context, LifeNote note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
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
              provider.updateNote(LifeNote(
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
              provider.deleteNote(note.id);
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
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}