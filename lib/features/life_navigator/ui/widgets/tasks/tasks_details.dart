// features/life_navigator/ui/widgets/tasks/tasks_details.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'tasks_constants.dart';
import 'tasks_edit_dialog.dart';
import 'tasks_add_dialog.dart';

class TasksDetailsSheet extends StatefulWidget {
  final bool isDark;
  final LifeTask task;
  final LifeProvider provider;
  final VoidCallback onClose;
  final Function(String) onStatusChanged;
  final VoidCallback? onTaskUpdated;

  const TasksDetailsSheet({
    super.key,
    required this.isDark,
    required this.task,
    required this.provider,
    required this.onClose,
    required this.onStatusChanged,
    this.onTaskUpdated,
  });

  @override
  State<TasksDetailsSheet> createState() => _TasksDetailsSheetState();
}

class _TasksDetailsSheetState extends State<TasksDetailsSheet> {
  bool _showSubtasks = true;
  late List<LifeTask> _subtasks;

  @override
  void initState() {
    super.initState();
    _loadSubtasks();
  }

  void _loadSubtasks() {
    _subtasks = widget.provider.tasks
        .where((t) => t.parentId == widget.task.id)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.task.statusColor;
    final priorityColor = widget.task.priorityColor;
    final isOverdue = widget.task.deadline != null &&
        widget.task.deadline!.isBefore(DateTime.now()) &&
        widget.task.status != 'done' &&
        widget.task.status != 'postponed';

    _subtasks = widget.provider.tasks
        .where((t) => t.parentId == widget.task.id)
        .toList();

    final completedSubtasks = _subtasks.where((t) => t.status == 'done').length;
    final totalSubtasks = _subtasks.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.isDark
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
                  color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Заголовок с кнопкой редактирования
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      widget.task.statusEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showStatusSelector(context),
                            child: Row(
                              children: [
                                Text(
                                  widget.task.statusDisplay,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down_rounded, color: statusColor, size: 16),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.task.priorityEmoji,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showEditDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 20,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (widget.task.description.isNotEmpty) ...[
              Text(
                '📝 Описание',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.task.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Детали
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Дедлайн',
                    value: widget.task.deadline != null
                        ? '${widget.task.deadline!.day}.${widget.task.deadline!.month}.${widget.task.deadline!.year}'
                        : 'Не установлен',
                    color: isOverdue ? Colors.red : Colors.blue,
                  ),
                  if (widget.task.reminderTime != null) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      icon: Icons.alarm_rounded,
                      label: 'Напоминание',
                      value: '${widget.task.reminderTime!.hour.toString().padLeft(2, '0')}:${widget.task.reminderTime!.minute.toString().padLeft(2, '0')}',
                      color: Colors.purple,
                    ),
                  ],
                  if (widget.task.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      icon: Icons.local_offer_rounded,
                      label: 'Теги',
                      value: widget.task.tags.map((t) => '#$t').join(' '),
                      color: Colors.grey,
                    ),
                  ],
                  if (widget.task.images != null && widget.task.images!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      icon: Icons.photo_rounded,
                      label: 'Фото',
                      value: '${widget.task.images!.length} шт.',
                      color: Colors.green,
                    ),
                  ],
                  if (_subtasks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      icon: Icons.checklist_rounded,
                      label: 'Подзадачи',
                      value: '$completedSubtasks/$totalSubtasks',
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
            ),

            // Фото (увеличенные и с возможностью открытия на весь экран)
            if (widget.task.images != null && widget.task.images!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '🖼️ Фото',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 200, // увеличен размер превью
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.task.images!.length,
                  itemBuilder: (ctx, index) {
                    final imagePath = widget.task.images![index];
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showFullScreenImage(imagePath, context),
                          child: Container(
                            width: 200,
                            height: 200,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: _getImageProvider(imagePath),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 10,
                          child: GestureDetector(
                            onTap: () {
                              final updatedImages = List<String>.from(widget.task.images!)
                                ..removeAt(index);
                              final updatedTask = widget.task.copyWith(images: updatedImages);
                              widget.provider.updateTask(updatedTask);
                              setState(() {});
                              if (widget.onTaskUpdated != null) widget.onTaskUpdated!();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Подзадачи (оставлено без изменений)
            if (_subtasks.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    '📋 Подзадачи ($completedSubtasks/$totalSubtasks)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showSubtasks = !_showSubtasks),
                    child: Icon(
                      _showSubtasks ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              if (_showSubtasks) ...[
                const SizedBox(height: 6),
                ..._subtasks.map((subtask) {
                  final subtaskStatusColor = subtask.statusColor;
                  final isDone = subtask.status == 'done';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDone ? Colors.green.withOpacity(0.05) : widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDone ? Colors.green.withOpacity(0.2) : widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final newStatus = isDone ? 'formulated' : 'done';
                            widget.onStatusChanged(newStatus);
                            widget.provider.updateTask(subtask.copyWith(status: newStatus));
                            setState(() {});
                            if (widget.onTaskUpdated != null) widget.onTaskUpdated!();
                          },
                          child: Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isDone ? Colors.green : Colors.grey, width: 2), color: isDone ? Colors.green : Colors.transparent),
                            child: isDone ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(subtask.title, style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white : Colors.black87, decoration: isDone ? TextDecoration.lineThrough : null))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: subtaskStatusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(subtask.statusEmoji, style: TextStyle(fontSize: 10))),
                        GestureDetector(
                          onTap: () {
                            widget.provider.deleteTask(subtask.id);
                            setState(() {});
                            if (widget.onTaskUpdated != null) widget.onTaskUpdated!();
                          },
                          child: Container(padding: const EdgeInsets.all(4), margin: const EdgeInsets.only(left: 4), child: Icon(Icons.close_rounded, size: 14, color: Colors.red.shade300)),
                        ),
                      ],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => _showAddSubtaskDialog(context),
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 16, color: const Color(0xFFFF6B35)),
                      const SizedBox(width: 4),
                      Text('Добавить подзадачу', style: TextStyle(fontSize: 12, color: const Color(0xFFFF6B35), fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],

            // Кнопки действий (исправлена кнопка "Сменить статус")
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showStatusSelector(context); // теперь открывает выбор
                    },
                    icon: const Icon(Icons.autorenew_rounded, size: 18),
                    label: const Text('Изменить статус'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
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
                      widget.onClose();
                      _confirmDelete();
                    },
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    label: const Text('Удалить'),
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onClose,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300),
                ),
                child: Text('Закрыть', style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ПОЛНОЭКРАННЫЙ ПРОСМОТР ====================
  void _showFullScreenImage(String imagePath, BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: _getImageProvider(imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
  Widget _buildDetailRow({required IconData icon, required String label, required String value, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white38 : Colors.grey.shade500))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black87))),
      ],
    );
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    } else {
      return FileImage(File(path));
    }
  }

  void _showStatusSelector(BuildContext context) {
    final statuses = [
      {'id': 'formulated', 'label': 'Сформулирована', 'emoji': '📝', 'color': const Color(0xFF4A9EFF)},
      {'id': 'in_progress', 'label': 'В процессе', 'emoji': '⚡', 'color': const Color(0xFFFF6B35)},
      {'id': 'done', 'label': 'Готова', 'emoji': '✅', 'color': const Color(0xFF00C853)},
      {'id': 'postponed', 'label': 'Отложена', 'emoji': '⏰', 'color': const Color(0xFF7C4DFF)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Изменить статус', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            ...statuses.map((s) {
              final isSelected = widget.task.status == s['id'];
              final color = s['color'] as Color;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onStatusChanged(s['id'] as String);
                  if (widget.onTaskUpdated != null) widget.onTaskUpdated!();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.1) : (widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(s['emoji'] as String, style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s['label'] as String, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? color : (widget.isDark ? Colors.white : Colors.black87)))),
                      if (isSelected) Icon(Icons.check_circle_rounded, color: color, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена'))),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TasksEditDialog(
        isDark: widget.isDark,
        task: widget.task,
        provider: widget.provider,
        onClose: () => Navigator.pop(ctx),
        onTaskUpdated: widget.onTaskUpdated,
      ),
    );
  }

  void _showAddSubtaskDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TasksAddDialog(
        isDark: widget.isDark,
        provider: widget.provider,
        parentTask: widget.task,
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить задачу?'),
        content: Text('Вы уверены, что хотите удалить "${widget.task.title}" и все её подзадачи?', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () {
              widget.provider.deleteTask(widget.task.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🗑️ Задача и подзадачи удалены'), backgroundColor: Colors.red, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}