// features/life_navigator/ui/widgets/notes/notes_quick_add.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../providers/life_provider.dart';

class NotesQuickAdd {
  /// Быстрое добавление заметки из буфера обмена
  static Future<void> fromClipboard(BuildContext context, LifeProvider provider) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📋 Буфер обмена пуст'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final text = data.text!;
    final lines = text.split('\n');
    final title = lines.first.length > 50
        ? '${lines.first.substring(0, 50)}...'
        : lines.first;
    final content = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    await provider.addNote(title, content);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📝 Заметка "$title" создана из буфера'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Быстрая заметка (только заголовок)
  static void showQuickAddDialog(BuildContext context, bool isDark, LifeProvider provider) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.purple, size: 24),
            const SizedBox(width: 8),
            Text('⚡ Быстрая заметка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Введите текст заметки...',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.addNote(controller.text, '');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Заметка создана'),
                    backgroundColor: Colors.purple,
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}