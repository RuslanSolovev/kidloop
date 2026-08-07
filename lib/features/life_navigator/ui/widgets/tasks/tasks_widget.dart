// features/life_navigator/ui/widgets/tasks/tasks_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../base_life_widget.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'tasks_filter_bar.dart';
import 'tasks_card.dart';
import 'tasks_add_dialog.dart';

class TasksWidget extends BaseLifeWidget {
  const TasksWidget({super.key, required super.isDark, super.isCompact = true});

  @override
  State<TasksWidget> createState() => _TasksWidgetState();
}

class _TasksWidgetState extends State<TasksWidget> with LifeWidgetMixin<TasksWidget> {
  String _filter = 'all';
  String? _selectedTag;
  String _searchQuery = '';
  Set<String> _expandedTasks = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final allTasks = provider.tasks;

    var filteredTasks = _filterTasks(allTasks);
    filteredTasks = _sortTasks(filteredTasks);

    final rootTasks = filteredTasks.where((t) => t.parentId == null).toList();
    final allTags = _getAllTags(allTasks);

    final totalTasks = allTasks.length;
    final completedTasks = allTasks.where((t) => t.status == 'done').length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;
    final overdueTasks = allTasks.where((t) =>
    t.deadline != null &&
        t.deadline!.isBefore(DateTime.now()) &&
        t.status != 'done' &&
        t.status != 'postponed').toList();

    return GestureDetector(
      onTap: widget.isCompact ? openFullScreen : null,
      child: Container(
        padding: EdgeInsets.all(widget.isCompact ? 16 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isDark
                ? [const Color(0xFF151824), const Color(0xFF0D1117)]
                : [const Color(0xFFFCFCFD), const Color(0xFFF4F5F7)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.06),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(provider, totalTasks, completedTasks, completionRate, overdueTasks),
            const SizedBox(height: 16),

            if (allTasks.isNotEmpty) ...[
              TasksFilterBar(
                isDark: widget.isDark,
                currentFilter: _filter,
                selectedTag: _selectedTag,
                searchQuery: _searchQuery,
                overdueCount: overdueTasks.length,
                allTags: allTags,
                onFilterChanged: (f) => setState(() => _filter = f),
                onTagChanged: (t) => setState(() => _selectedTag = t),
                onSearchChanged: (q) => setState(() => _searchQuery = q),
              ),
              const SizedBox(height: 12),
            ],

            if (allTasks.isEmpty)
              _buildEmptyState()
            else
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: rootTasks.length,
                  itemBuilder: (context, index) {
                    final task = rootTasks[index];
                    return _buildTaskWithDescendants(task, provider, index == rootTasks.length - 1);
                  },
                ),
              ),

            const SizedBox(height: 16),
            _buildActionButtons(provider),

            if (widget.isCompact) ...[
              const SizedBox(height: 10),
              _buildCompactHint(),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== РЕКУРСИВНОЕ ПОСТРОЕНИЕ ====================

  Widget _buildTaskWithDescendants(LifeTask task, LifeProvider provider, bool isLast) {
    final isExpanded = _expandedTasks.contains(task.id);
    final subtasks = provider.tasks.where((t) => t.parentId == task.id).toList();

    return TasksCard(
      key: ValueKey(task.id),
      task: task,
      isDark: widget.isDark,
      provider: provider,
      depth: _getTaskDepth(task),
      isExpanded: isExpanded,
      onExpandToggle: subtasks.isNotEmpty
          ? () {
        setState(() {
          if (isExpanded) {
            _expandedTasks.remove(task.id);
          } else {
            _expandedTasks.add(task.id);
          }
        });
      }
          : null,
      onStatusChanged: (newStatus) {
        provider.updateTask(task.copyWith(status: newStatus));
      },
      onTaskUpdated: () {
        setState(() {});
      },
      isLastChild: isLast,
    );
  }

  int _getTaskDepth(LifeTask task) {
    int depth = 0;
    String? currentParentId = task.parentId;
    final allTasks = context.read<LifeProvider>().tasks;

    while (currentParentId != null) {
      depth++;
      final parent = allTasks.firstWhere(
            (t) => t.id == currentParentId,
        orElse: () => task,
      );
      currentParentId = parent.parentId;
    }

    return depth;
  }

  // ==================== ЗАГОЛОВОК ====================

  Widget _buildHeader(
      LifeProvider provider,
      int totalTasks,
      int completedTasks,
      int completionRate,
      List<LifeTask> overdueTasks,
      ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.account_tree_rounded,
            color: Colors.white,
            size: widget.isCompact ? 22 : 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Задачи',
                style: TextStyle(
                  fontSize: widget.isCompact ? 19 : 23,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '$totalTasks задач',
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.2),
                          Colors.green.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$completionRate%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (overdueTasks.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.red.shade400, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${overdueTasks.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF6B35).withOpacity(0.2),
                const Color(0xFFFF6B35).withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${totalTasks - completedTasks} ост.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF6B35),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== ПУСТОЕ СОСТОЯНИЕ ====================

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 40 : 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B35).withOpacity(0.12),
                      const Color(0xFFFF6B35).withOpacity(0.04),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Text('🚀', style: TextStyle(fontSize: 52)),
              ),
              const SizedBox(height: 16),
              Text(
                'Нет задач',
                style: TextStyle(
                  fontSize: widget.isCompact ? 18 : 22,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Нажмите «Добавить» чтобы создать первую задачу',
                style: TextStyle(
                  fontSize: widget.isCompact ? 13 : 15,
                  color: widget.isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== КНОПКИ ДЕЙСТВИЙ ====================

  Widget _buildActionButtons(LifeProvider provider) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showAddTaskDialog(context, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: widget.isCompact ? 20 : 22),
                  const SizedBox(width: 6),
                  Text(
                    'Добавить',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: widget.isCompact ? 15 : 17,
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
            onTap: () => _showQuickAddDialog(context, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: Colors.orange.shade400,
                      size: widget.isCompact ? 18 : 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Быстрая',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white.withOpacity(0.7) : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: widget.isCompact ? 15 : 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.1),
              const Color(0xFFF7931E).withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_full_rounded,
              size: 14,
              color: const Color(0xFFFF6B35).withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              'Нажмите для полного просмотра',
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFFFF6B35).withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ФИЛЬТРАЦИЯ И СОРТИРОВКА ====================

  List<LifeTask> _filterTasks(List<LifeTask> tasks) {
    var result = tasks;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((t) =>
      t.title.toLowerCase().contains(query) ||
          (t.description?.toLowerCase().contains(query) ?? false)).toList();
    }

    if (_selectedTag != null) {
      result = result.where((t) => t.tags.contains(_selectedTag)).toList();
    }

    switch (_filter) {
      case 'formulated':
        return result.where((t) => t.status == 'formulated').toList();
      case 'in_progress':
        return result.where((t) => t.status == 'in_progress').toList();
      case 'done':
        return result.where((t) => t.status == 'done').toList();
      case 'postponed':
        return result.where((t) => t.status == 'postponed').toList();
      case 'overdue':
        return result.where((t) =>
        t.deadline != null &&
            t.deadline!.isBefore(DateTime.now()) &&
            t.status != 'done' &&
            t.status != 'postponed').toList();
      default:
        return result;
    }
  }

  List<LifeTask> _sortTasks(List<LifeTask> tasks) {
    final sorted = List<LifeTask>.from(tasks);
    sorted.sort((a, b) {
      final priorityOrder = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
      final priorityCompare =
      (priorityOrder[a.priority] ?? 2).compareTo(priorityOrder[b.priority] ?? 2);
      if (priorityCompare != 0) return priorityCompare;
      if (a.deadline != null && b.deadline != null) return a.deadline!.compareTo(b.deadline!);
      if (a.deadline != null) return -1;
      if (b.deadline != null) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }

  List<String> _getAllTags(List<LifeTask> tasks) {
    final tags = <String>{};
    for (final t in tasks) {
      tags.addAll(t.tags);
    }
    return tags.toList()..sort();
  }

  // ==================== ДИАЛОГИ ====================

  void _showAddTaskDialog(BuildContext context, LifeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TasksAddDialog(
        isDark: widget.isDark,
        provider: provider,
      ),
    );
  }

  void _showQuickAddDialog(BuildContext context, LifeProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2233) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.bolt_rounded, color: const Color(0xFFFF6B35), size: 24),
            const SizedBox(width: 8),
            Text(
              '⚡ Быстрая задача',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Что нужно сделать?',
            hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade400),
            filled: true,
            fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.7) : Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.addTask(title: controller.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✅ Задача создана'),
                    backgroundColor: const Color(0xFFFF6B35),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}