// features/life_navigator/ui/widgets/notes/notes_add_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/life_provider.dart';
import 'notes_constants.dart';

class NotesAddDialog extends StatefulWidget {
  final bool isDark;
  final LifeProvider provider;

  const NotesAddDialog({
    super.key,
    required this.isDark,
    required this.provider,
  });

  @override
  State<NotesAddDialog> createState() => _NotesAddDialogState();
}

class _NotesAddDialogState extends State<NotesAddDialog> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final tagController = TextEditingController();

  String selectedColor = '#FFFFFF';
  List<String> tags = [];
  String selectedCategory = 'Личное';
  bool isChecklist = false;
  List<ChecklistItem> checklistItems = [];

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            // Индикатор
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // Заголовок
            _buildHeader(),
            const SizedBox(height: 16),

            // Поля ввода
            _buildTitleField(),
            const SizedBox(height: 12),
            _buildContentField(),
            const SizedBox(height: 12),

            // Палитра цветов
            _buildColorPalette(),
            const SizedBox(height: 12),

            // Теги
            _buildTagsSection(),
            const SizedBox(height: 12),

            // Категория
            _buildCategoryDropdown(),
            const SizedBox(height: 12),

            // Чек-лист
            _buildChecklistToggle(),
            if (isChecklist) _buildChecklistItems(),

            const SizedBox(height: 16),

            // Кнопки
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.note_add_rounded, color: Colors.purple, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          'Новая заметка',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        const Spacer(),
        // 🔥 БЫСТРАЯ ВСТАВКА ИЗ БУФЕРА
        IconButton(
          onPressed: _pasteFromClipboard,
          icon: Icon(Icons.content_paste_rounded, color: Colors.purple.withOpacity(0.6), size: 20),
          tooltip: 'Вставить из буфера',
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: titleController,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: 'Заголовок',
        labelStyle: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(Icons.title_rounded, color: Colors.purple.withOpacity(0.5), size: 18),
      ),
    );
  }

  Widget _buildContentField() {
    return TextField(
      controller: contentController,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Содержание',
        labelStyle: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(Icons.article_rounded, color: Colors.purple.withOpacity(0.5), size: 18),
      ),
    );
  }

  Widget _buildColorPalette() {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemSize = (screenWidth - 60) / 6 - 6; // 6 в ряд

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Цвет заметки',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: NotesConstants.colorPalette.map((noteColor) {
            final isSelected = selectedColor == NotesConstants.toHex(noteColor.color);
            return GestureDetector(
              onTap: () => setState(() => selectedColor = NotesConstants.toHex(noteColor.color)),
              child: Container(
                width: itemSize,
                height: itemSize,
                decoration: BoxDecoration(
                  color: noteColor.color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.purple : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 6)
                  ] : null,
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, color: noteColor.textColor, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Теги',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: tagController,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Добавить тег...',
                  hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.grey.shade400, fontSize: 13),
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addTag(tagController.text),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_rounded, color: Colors.purple, size: 18),
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: tags.map((tag) {
              return Chip(
                label: Text('#$tag', style: const TextStyle(fontSize: 11)),
                deleteIcon: Icon(Icons.close_rounded, size: 14),
                onDeleted: () => setState(() => tags.remove(tag)),
                backgroundColor: Colors.purple.withOpacity(0.1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedCategory,
      dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Категория',
        labelStyle: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: NotesConstants.categories.map((cat) {
        return DropdownMenuItem(value: cat, child: Text(cat));
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => selectedCategory = value);
      },
    );
  }

  Widget _buildChecklistToggle() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Чек-лист',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: widget.isDark ? Colors.white : Colors.black87),
      ),
      subtitle: Text(
        isChecklist ? 'Добавьте пункты списка' : 'Обычная заметка',
        style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
      ),
      value: isChecklist,
      activeColor: Colors.purple,
      onChanged: (value) => setState(() => isChecklist = value),
    );
  }

  Widget _buildChecklistItems() {
    return Column(
      children: [
        ...checklistItems.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Row(
            children: [
              Checkbox(
                value: item.isChecked,
                onChanged: (v) => setState(() => item.isChecked = v ?? false),
                activeColor: Colors.purple,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: TextField(
                  controller: item.controller,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black87,
                    decoration: item.isChecked ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.grey,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Пункт ${i + 1}',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade300),
                onPressed: () => setState(() => checklistItems.removeAt(i)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              checklistItems.add(ChecklistItem());
            });
          },
          icon: Icon(Icons.add_rounded, size: 16, color: Colors.purple),
          label: Text('Добавить пункт', style: TextStyle(color: Colors.purple, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _saveNote,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Создать', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.isDark ? Colors.white70 : Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Отмена'),
          ),
        ),
      ],
    );
  }

  // ==================== ДЕЙСТВИЯ ====================

  void _addTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
      setState(() {
        tags.add(trimmed);
        tagController.clear();
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      if (titleController.text.isEmpty) {
        // Первая строка — заголовок
        final lines = data.text!.split('\n');
        titleController.text = lines.first;
        contentController.text = lines.length > 1 ? lines.sublist(1).join('\n') : '';
      } else {
        contentController.text += '\n${data.text}';
      }
      setState(() {});
    }
  }

  void _saveNote() {
    if (titleController.text.isNotEmpty || contentController.text.isNotEmpty) {
      final title = titleController.text.isNotEmpty
          ? titleController.text
          : contentController.text.substring(0, contentController.text.length.clamp(0, 30));

      final content = isChecklist
          ? checklistItems.map((item) {
        return '${item.isChecked ? '☑' : '☐'} ${item.controller.text}';
      }).join('\n')
          : contentController.text;

      widget.provider.addNote(
        title,
        content,
        tags: tags,
        color: selectedColor,
      );

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Заметка "$title" создана'),
          backgroundColor: Colors.purple,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class ChecklistItem {
  final TextEditingController controller = TextEditingController();
  bool isChecked = false;
}