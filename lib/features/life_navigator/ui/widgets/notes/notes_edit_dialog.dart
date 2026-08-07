// features/life_navigator/ui/widgets/notes/notes_edit_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'notes_constants.dart';
import 'notes_backgrounds.dart';

class NotesEditDialog extends StatefulWidget {
  final LifeNote note;
  final bool isDark;
  final LifeProvider provider;

  const NotesEditDialog({
    super.key,
    required this.note,
    required this.isDark,
    required this.provider,
  });

  @override
  State<NotesEditDialog> createState() => _NotesEditDialogState();
}

class _NotesEditDialogState extends State<NotesEditDialog> {
  late TextEditingController titleController;
  late TextEditingController contentController;
  late String selectedColor;
  late List<String> tags;
  late bool isFavorite;
  late NoteBackgroundType selectedBackground;

  Timer? _autoSaveTimer;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note.title);
    contentController = TextEditingController(text: widget.note.content);
    selectedColor = widget.note.color;
    tags = List.from(widget.note.tags);
    isFavorite = widget.note.isFavorite;
    selectedBackground = NoteBackgroundType.plain;

    // Слушаем изменения
    titleController.addListener(_onContentChanged);
    contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
    // 🔥 АВТО-СОХРАНЕНИЕ ЧЕРЕЗ 2 СЕКУНДЫ ПОСЛЕ ПОСЛЕДНЕГО ИЗМЕНЕНИЯ
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!_hasChanges) return;

    setState(() => _isSaving = true);

    await widget.provider.updateNote(LifeNote(
      id: widget.note.id,
      title: titleController.text,
      content: contentController.text,
      tags: tags,
      color: selectedColor,
      isFavorite: isFavorite,
      createdAt: widget.note.createdAt,
    ));

    if (mounted) {
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteColor = NotesConstants.fromHex(selectedColor);
    final textColor = NotesConstants.getTextColorForBackground(noteColor);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Индикатор + авто-сохранение
            Row(
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                const Spacer(),
                // Индикатор авто-сохранения
                if (_isSaving)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
                      const SizedBox(width: 4),
                      Text('Сохранение...', style: TextStyle(fontSize: 10, color: Colors.green)),
                    ],
                  )
                else if (!_hasChanges)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 12, color: Colors.green.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text('Сохранено', style: TextStyle(fontSize: 10, color: Colors.green.withOpacity(0.6))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Заголовок
            TextField(
              controller: titleController,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Заголовок',
                hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.grey.shade400),
                filled: true,
                fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Контент
            TextField(
              controller: contentController,
              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Содержание...',
                hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.grey.shade400),
                filled: true,
                fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Превью цвета
            Text('Предпросмотр:', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(height: 6),
            NotesBackgrounds.build(
              type: selectedBackground,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: noteColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: noteColor == Colors.white ? Colors.grey.shade300 : Colors.transparent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (titleController.text.isNotEmpty)
                      Text(titleController.text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textColor)),
                    if (contentController.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(contentController.text, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)), maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                    if (titleController.text.isEmpty && contentController.text.isEmpty)
                      Text('Предпросмотр заметки', style: TextStyle(color: textColor.withOpacity(0.3), fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Палитра цветов
            _buildColorPalette(),
            const SizedBox(height: 12),

            // Обои
            _buildBackgroundSelector(),
            const SizedBox(height: 12),

            // Избранное
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('В избранном', style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.white : Colors.black87)),
              value: isFavorite,
              activeColor: Colors.amber,
              onChanged: (v) {
                setState(() {
                  isFavorite = v;
                  _onContentChanged();
                });
              },
            ),

            const SizedBox(height: 16),

            // Кнопки
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _autoSave();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: NotesConstants.colorPalette.map((noteColor) {
        final isSelected = selectedColor == NotesConstants.toHex(noteColor.color);
        return GestureDetector(
          onTap: () {
            setState(() => selectedColor = NotesConstants.toHex(noteColor.color));
            _onContentChanged();
          },
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: noteColor.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.purple : Colors.grey.withOpacity(0.3),
                width: isSelected ? 3 : 1,
              ),
            ),
            child: isSelected ? Icon(Icons.check_rounded, color: noteColor.textColor, size: 14) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBackgroundSelector() {
    return Wrap(
      spacing: 6,
      children: NotesConstants.backgrounds.map((bg) {
        final isSelected = selectedBackground == bg.type;
        return GestureDetector(
          onTap: () {
            setState(() => selectedBackground = bg.type);
            _onContentChanged();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.purple.withOpacity(0.15) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.purple.withOpacity(0.3) : Colors.transparent,
              ),
            ),
            child: Text(
              bg.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.purple : (widget.isDark ? Colors.white54 : Colors.grey.shade600),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}