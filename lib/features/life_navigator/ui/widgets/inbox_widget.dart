// features/life_navigator/ui/widgets/inbox_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/life_models.dart';
import '../../providers/life_provider.dart';

class InboxWidget extends StatefulWidget {
  final bool isDark;

  const InboxWidget({super.key, required this.isDark});

  @override
  State<InboxWidget> createState() => _InboxWidgetState();
}

class _InboxWidgetState extends State<InboxWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final inboxItems = provider.inbox.where((i) => !i.isProcessed).toList();
    final displayedItems = _isExpanded ? inboxItems : inboxItems.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== ЗАГОЛОВОК ==========
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inbox_rounded, color: Colors.cyan, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Входящие',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (inboxItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${inboxItems.length} новых',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ========== СПИСОК ==========
          if (inboxItems.isEmpty)
            _buildEmptyState()
          else
            ...displayedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final typeIcon = _getTypeIcon(item.type);
              final typeColor = _getTypeColor(item.type);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    // Тип элемента
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(typeIcon, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),

                    // Текст
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.text,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getTypeLabel(item.type),
                            style: TextStyle(
                              fontSize: 10,
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🔥 КНОПКИ ДЕЙСТВИЙ
                    _buildActionButtons(item, provider),
                  ],
                ),
              );
            }),

          // 🔥 ПОКАЗАТЬ ЕЩЁ
          if (inboxItems.length > 3 && !_isExpanded)
            GestureDetector(
              onTap: () {
                setState(() => _isExpanded = true);
                HapticFeedback.selectionClick();
              },
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.expand_more_rounded, size: 16, color: Colors.cyan),
                      const SizedBox(width: 4),
                      Text(
                        'Показать ещё ${inboxItems.length - 3}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isExpanded && inboxItems.length > 3)
            GestureDetector(
              onTap: () {
                setState(() => _isExpanded = false);
                HapticFeedback.selectionClick();
              },
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.expand_less_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Свернуть',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ========== КНОПКИ ДЕЙСТВИЙ ==========
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAddInboxDialog(context, widget.isDark, provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.cyan, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Добавить',
                          style: TextStyle(
                            color: Colors.cyan,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // TODO: Открыть все входящие
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Обработать все',
                        style: TextStyle(
                          color: widget.isDark ? Colors.white70 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== ПУСТОЕ СОСТОЯНИЕ ==========

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              '✨',
              style: TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              'Входящие пусты',
              style: TextStyle(
                color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Запишите мысль, чтобы не забыть',
              style: TextStyle(
                color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== КНОПКИ ДЕЙСТВИЙ ==========

  Widget _buildActionButtons(InboxItem item, LifeProvider provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 📋 Задача
        _buildMiniButton(
          icon: '📋',
          color: Colors.orange,
          tooltip: 'В задачу',
          onTap: () {
            HapticFeedback.lightImpact();
            provider.processInboxItem(item.id, 'task');
            _showSuccessSnackBar('📋 Преобразовано в задачу');
          },
        ),
        const SizedBox(width: 3),

        // 📝 Заметка
        _buildMiniButton(
          icon: '📝',
          color: Colors.purple,
          tooltip: 'В заметку',
          onTap: () {
            HapticFeedback.lightImpact();
            provider.processInboxItem(item.id, 'note');
            _showSuccessSnackBar('📝 Преобразовано в заметку');
          },
        ),
        const SizedBox(width: 3),

        // 💡 Идея
        _buildMiniButton(
          icon: '💡',
          color: Colors.amber,
          tooltip: 'В идею',
          onTap: () {
            HapticFeedback.lightImpact();
            provider.processInboxItem(item.id, 'idea');
            _showSuccessSnackBar('💡 Преобразовано в идею');
          },
        ),
        const SizedBox(width: 3),

        // 🔥 НОВОЕ: 💪 Привычка
        _buildMiniButton(
          icon: '💪',
          color: Colors.green,
          tooltip: 'В привычку',
          onTap: () {
            HapticFeedback.lightImpact();
            _showConvertToHabitDialog(context, item, provider);
          },
        ),
        const SizedBox(width: 3),

        // 🗑️ Удалить
        _buildMiniButton(
          icon: '✕',
          color: Colors.red,
          tooltip: 'Удалить',
          isText: true,
          onTap: () {
            HapticFeedback.mediumImpact();
            provider.deleteInboxItem(item.id);
          },
        ),
      ],
    );
  }

  Widget _buildMiniButton({
    required String icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    bool isText = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isText ? 6 : 5,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: isText
              ? Text(
            icon,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          )
              : Text(
            icon,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  // ========== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ==========

  String _getTypeIcon(String type) {
    switch (type) {
      case 'task': return '📋';
      case 'note': return '📝';
      case 'idea': return '💡';
      case 'habit': return '💪';
      case 'reminder': return '⏰';
      default: return '📌';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'task': return Colors.orange;
      case 'note': return Colors.purple;
      case 'idea': return Colors.amber;
      case 'habit': return Colors.green;
      case 'reminder': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'task': return 'Задача';
      case 'note': return 'Заметка';
      case 'idea': return 'Идея';
      case 'habit': return 'Привычка';
      case 'reminder': return 'Напоминание';
      default: return 'Прочее';
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ========== ДИАЛОГ КОНВЕРТАЦИИ В ПРИВЫЧКУ ==========

  void _showConvertToHabitDialog(BuildContext context, InboxItem item, LifeProvider provider) {
    String selectedIcon = '⭐';
    String selectedFrequency = 'daily';
    int selectedTarget = 1;

    final icons = ['⭐', '💪', '📚', '🏃', '🧘', '🎯', '💧', '🥗', '😴', '🧠', '🎨', '🌱', '🎵', '✍️', '🧹'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fitness_center_rounded, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Создать привычку',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${item.text}"',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),

              // Иконка
              Text(
                'Иконка',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedIcon,
                dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: icons.map((icon) {
                  return DropdownMenuItem(
                    value: icon,
                    child: Text('$icon  ', style: const TextStyle(fontSize: 20)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) selectedIcon = value;
                },
              ),

              const SizedBox(height: 12),

              // Частота
              Text(
                'Частота',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedFrequency,
                dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('📅 Ежедневно')),
                  DropdownMenuItem(value: 'weekly', child: Text('📆 Еженедельно')),
                  DropdownMenuItem(value: 'monthly', child: Text('🗓️ Ежемесячно')),
                ],
                onChanged: (value) {
                  if (value != null) selectedFrequency = value;
                },
              ),

              const SizedBox(height: 12),

              // Цель
              Text(
                'Цель в день',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: selectedTarget,
                dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('🎯 1 раз')),
                  DropdownMenuItem(value: 2, child: Text('🎯 2 раза')),
                  DropdownMenuItem(value: 3, child: Text('🎯 3 раза')),
                  DropdownMenuItem(value: 5, child: Text('🎯 5 раз')),
                ],
                onChanged: (value) {
                  if (value != null) selectedTarget = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // 🔥 Создаём привычку из входящего
              final habit = await provider.convertInboxToHabit(
                item.id,
                icon: selectedIcon,
                frequency: selectedFrequency,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('💪 Привычка "${habit.title}" создана!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Создать 💪'),
          ),
        ],
      ),
    );
  }

  // ========== ДИАЛОГ ДОБАВЛЕНИЯ (ОБНОВЛЁННЫЙ) ==========

  void _showAddInboxDialog(BuildContext context, bool isDark, LifeProvider provider) {
    final textController = TextEditingController();
    String selectedType = 'idea';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inbox_rounded, color: Colors.cyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Добавить во входящие',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: textController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Введите текст...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 🔥 ТИП ЭЛЕМЕНТА
              Text(
                'Тип элемента',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedType,
                dropdownColor: isDark ? const Color(0xFF2A2D35) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'idea', child: Text('💡 Идея')),
                  DropdownMenuItem(value: 'task', child: Text('📋 Задача')),
                  DropdownMenuItem(value: 'note', child: Text('📝 Заметка')),
                  DropdownMenuItem(value: 'habit', child: Text('💪 Привычка')),
                  DropdownMenuItem(value: 'reminder', child: Text('⏰ Напоминание')),
                ],
                onChanged: (value) {
                  if (value != null) selectedType = value;
                },
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (textController.text.isNotEmpty) {
                          // 🔥 Если выбран тип 'habit' — сразу создаём привычку
                          if (selectedType == 'habit') {
                            provider.convertInboxToHabit(
                              provider.inbox.last.id, // будет заменено на новый
                              icon: '⭐',
                              frequency: 'daily',
                            );
                            // Проще создать через addInboxItem + convertInboxToHabit
                            final item = InboxItem(
                              id: '', // временный
                              text: textController.text,
                              type: 'habit',
                            );
                            // Добавляем и сразу конвертируем
                            provider.addInboxItem(textController.text, type: 'habit').then((newItem) {
                              provider.convertInboxToHabit(newItem.id);
                            });
                          } else {
                            provider.addInboxItem(textController.text, type: selectedType);
                          }
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Добавить',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}