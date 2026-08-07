// features/life_navigator/ui/widgets/tasks_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/life_models.dart';
import '../../providers/life_provider.dart';

class TasksWidget extends StatelessWidget {
  final bool isDark;

  const TasksWidget({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final todayTasks = provider.getTodayTasks();
    final allTasks = provider.tasks;
    final todoTasks = allTasks.where((t) => t.status == 'todo').toList();
    final doneTasks = allTasks.where((t) => t.status == 'done').toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Задачи',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${todoTasks.length} осталось',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (todoTasks.isEmpty && doneTasks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Нет задач. Добавьте первую! 🚀',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else if (todoTasks.isNotEmpty)
            ...todoTasks.take(3).map((task) {
              return _buildTaskItem(task, isDark, provider);
            }),
          if (todoTasks.length > 3)
            Text(
              'и еще ${todoTasks.length - 3} задач...',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          if (doneTasks.isNotEmpty && todoTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  '🎉 Все задачи выполнены!',
                  style: TextStyle(
                    color: Colors.green.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAddTaskDialog(context, isDark, provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Добавить',
                          style: TextStyle(
                            color: Colors.orange,
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
                    // Открыть все задачи
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Все задачи',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
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

  Widget _buildTaskItem(LifeTask task, bool isDark, LifeProvider provider) {
    final priorityColor = task.priority == 'urgent' ? Colors.red :
    task.priority == 'high' ? Colors.orange :
    task.priority == 'medium' ? Colors.blue :
    Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final updated = LifeTask(
                id: task.id,
                title: task.title,
                description: task.description,
                projectId: task.projectId,
                goalId: task.goalId,
                tags: task.tags,
                priority: task.priority,
                status: task.status == 'todo' ? 'done' : 'todo',
                deadline: task.deadline,
                estimatedMinutes: task.estimatedMinutes,
                actualMinutes: task.actualMinutes,
                isRecurring: task.isRecurring,
                recurrenceRule: task.recurrenceRule,
                createdAt: task.createdAt,
                updatedAt: DateTime.now(),
              );
              provider.updateTask(updated);
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.status == 'done' ? Colors.green : priorityColor,
                  width: 2,
                ),
                color: task.status == 'done' ? Colors.green : Colors.transparent,
              ),
              child: task.status == 'done'
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontWeight: task.status == 'done' ? FontWeight.w400 : FontWeight.w600,
                fontSize: 13,
                color: task.status == 'done'
                    ? (isDark ? Colors.white54 : Colors.grey.shade600)
                    : (isDark ? Colors.white : Colors.black87),
                decoration: task.status == 'done' ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (task.deadline != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: task.deadline!.isBefore(DateTime.now()) && task.status != 'done'
                    ? Colors.red.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${task.deadline!.day}.${task.deadline!.month}',
                style: TextStyle(
                  fontSize: 10,
                  color: task.deadline!.isBefore(DateTime.now()) && task.status != 'done'
                      ? Colors.red.shade400
                      : (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, bool isDark, LifeProvider provider) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPriority = 'medium';
    DateTime? selectedDeadline;

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
              Text(
                'Новая задача',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Название задачи',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Описание',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          selectedDeadline = date;
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              selectedDeadline != null
                                  ? '${selectedDeadline!.day}.${selectedDeadline!.month}.${selectedDeadline!.year}'
                                  : 'Дедлайн',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedPriority,
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
                        DropdownMenuItem(value: 'low', child: Text('🟢 Низкий')),
                        DropdownMenuItem(value: 'medium', child: Text('🟡 Средний')),
                        DropdownMenuItem(value: 'high', child: Text('🟠 Высокий')),
                        DropdownMenuItem(value: 'urgent', child: Text('🔴 Срочный')),
                      ],
                      onChanged: (value) {
                        if (value != null) selectedPriority = value;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isNotEmpty) {
                          provider.addTask(
                            title: titleController.text,
                            description: descriptionController.text,
                            priority: selectedPriority,
                            deadline: selectedDeadline,
                          );
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
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