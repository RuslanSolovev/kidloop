// features/life_navigator/ui/widgets/tasks/tasks_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../base_life_widget.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'tasks_card.dart';
import 'tasks_add_dialog.dart';
import 'tasks_constants.dart';

class TasksWidget extends BaseLifeWidget {
  const TasksWidget(
      {super.key, required super.isDark, super.isCompact = true});

  @override
  State<TasksWidget> createState() => _TasksWidgetState();
}

class _TasksWidgetState extends State<TasksWidget>
    with LifeWidgetMixin<TasksWidget> {
  String _filter = 'all';
  String? _selectedTag;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isFilterOpen = false;
  Set<String> _expandedTasks = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final allTasks = provider.tasks;

    var filteredTasks = _filterTasks(allTasks);
    filteredTasks = _sortTasks(filteredTasks);

    final rootTasks =
    filteredTasks.where((t) => t.parentId == null).toList();
    final allTags = _getAllTags(allTasks);

    final totalTasks = allTasks.length;
    final completedTasks =
        allTasks.where((t) => t.status == 'done').length;
    final completionRate = totalTasks > 0
        ? (completedTasks / totalTasks * 100).round()
        : 0;
    final overdueTasks = allTasks
        .where((t) =>
    t.deadline != null &&
        t.deadline!.isBefore(DateTime.now()) &&
        t.status != 'done' &&
        t.status != 'postponed')
        .toList();

    return GestureDetector(
      onTap: widget.isCompact ? openFullScreen : null,
      child: Container(
        padding: EdgeInsets.fromLTRB(2, widget.isCompact ? 16 : 24, 2, widget.isCompact ? 16 : 24),
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
            color: widget.isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
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
            _buildHeader(
              provider,
              totalTasks,
              completedTasks,
              completionRate,
              overdueTasks,
              allTags,
            ),
            if (_isSearching) ...[
              const SizedBox(height: 12),
              _buildSearchBar(),
            ],
            if (_isFilterOpen) ...[
              const SizedBox(height: 12),
              _buildFilterPanel(allTags),
            ],
            const SizedBox(height: 12),

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
                    return _buildTaskWithDescendants(
                        provider, task, index == rootTasks.length - 1);
                  },
                ),
              ),

            if (widget.isCompact) ...[
              const SizedBox(height: 10),
              _buildCompactHint(),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== ЗАГОЛОВОК С КНОПКАМИ ====================

  Widget _buildHeader(
      LifeProvider provider,
      int totalTasks,
      int completedTasks,
      int completionRate,
      List<LifeTask> overdueTasks,
      List<String> allTags,
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
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.4)
                          : Colors.grey.shade500,
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
        if (overdueTasks.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_rounded,
                    color: Colors.red.shade400, size: 16),
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
        ],
        _buildHeaderIcon(
          icon: Icons.search_rounded,
          isActive: _isSearching,
          onTap: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _searchQuery = '';
              }
              _isFilterOpen = false;
            });
          },
        ),
        const SizedBox(width: 4),
        _buildHeaderIcon(
          icon: Icons.filter_list_rounded,
          isActive: _isFilterOpen,
          hasBadge: _filter != 'all' || _selectedTag != null,
          onTap: () {
            setState(() {
              _isFilterOpen = !_isFilterOpen;
              _isSearching = false;
            });
          },
        ),
        const SizedBox(width: 4),
        _buildHeaderIcon(
          icon: Icons.add_rounded,
          isActive: false,
          isAddButton: true,
          onTap: () => _showAddTaskDialog(context, provider),
        ),
      ],
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool hasBadge = false,
    bool isAddButton = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF6B35).withOpacity(0.15)
              : (widget.isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(
              color: const Color(0xFFFF6B35).withOpacity(0.3),
              width: 1.5)
              : null,
        ),
        child: Stack(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? const Color(0xFFFF6B35)
                  : (widget.isDark
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade600),
            ),
            if (hasBadge)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== ПОИСК ====================

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(
          color: widget.isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Поиск задач...',
          hintStyle: TextStyle(
            color: widget.isDark
                ? Colors.white.withOpacity(0.4)
                : Colors.grey.shade400,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: widget.isDark
                ? Colors.white.withOpacity(0.4)
                : Colors.grey.shade400,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: widget.isDark
                  ? Colors.white.withOpacity(0.4)
                  : Colors.grey.shade400,
            ),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  // ==================== ПАНЕЛЬ ФИЛЬТРОВ ====================

  Widget _buildFilterPanel(List<String> allTags) {
    final statuses = [
      {
        'id': 'all',
        'label': 'Все',
        'emoji': '📋',
        'color': Colors.grey
      },
      {
        'id': 'formulated',
        'label': 'Сформулирована',
        'emoji': '📝',
        'color': const Color(0xFF4A9EFF)
      },
      {
        'id': 'in_progress',
        'label': 'В процессе',
        'emoji': '⚡',
        'color': const Color(0xFFFF6B35)
      },
      {
        'id': 'done',
        'label': 'Готово',
        'emoji': '✅',
        'color': const Color(0xFF00C853)
      },
      {
        'id': 'postponed',
        'label': 'Отложено',
        'emoji': '⏰',
        'color': const Color(0xFF7C4DFF)
      },
      {
        'id': 'overdue',
        'label': 'Просрочено',
        'emoji': '⚠️',
        'color': Colors.red
      },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статус',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.isDark
                  ? Colors.white.withOpacity(0.5)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: statuses.map((s) {
              final isSelected = _filter == s['id'] && _selectedTag == null;
              final color = s['color'] as Color;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _filter = s['id'] as String;
                    _selectedTag = null;
                  });
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? color.withOpacity(0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '${s['emoji']} ${s['label']}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? color
                          : (widget.isDark
                          ? Colors.white.withOpacity(0.5)
                          : Colors.grey.shade600),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (allTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Теги',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedTag = null;
                    if (_filter == 'all') _filter = 'all';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _selectedTag == null && _filter != 'all'
                          ? Colors.transparent
                          : _selectedTag == null
                          ? const Color(0xFFFF6B35).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedTag == null && _filter != 'all'
                            ? Colors.transparent
                            : _selectedTag == null
                            ? const Color(0xFFFF6B35).withOpacity(0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      'Все теги',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedTag == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedTag == null
                            ? const Color(0xFFFF6B35)
                            : (widget.isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
                ...allTags.map((tag) {
                  final isSelected = _selectedTag == tag;
                  final tagColor = LifeTask.getTagColor(tag);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTag = isSelected ? null : tag;
                        _filter = 'all';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tagColor.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? tagColor.withOpacity(0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? tagColor
                              : (widget.isDark
                              ? Colors.white.withOpacity(0.5)
                              : Colors.grey.shade600),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==================== РЕКУРСИВНОЕ ПОСТРОЕНИЕ ====================

  Widget _buildTaskWithDescendants(
      LifeProvider provider, LifeTask task, bool isLast) {
    final isExpanded = _expandedTasks.contains(task.id);
    final subtasks =
    provider.tasks.where((t) => t.parentId == task.id).toList();

    return TasksCard(
      key: ValueKey(task.id),
      task: task,
      isDark: widget.isDark,
      provider: provider,
      depth: _getTaskDepth(task, provider),
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

  int _getTaskDepth(LifeTask task, LifeProvider provider) {
    int depth = 0;
    String? currentParentId = task.parentId;
    while (currentParentId != null) {
      depth++;
      final parent = provider.tasks.firstWhere(
            (t) => t.id == currentParentId,
        orElse: () => task,
      );
      currentParentId = parent.parentId;
    }
    return depth;
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
                'Нажмите + чтобы создать первую задачу',
                style: TextStyle(
                  fontSize: widget.isCompact ? 13 : 15,
                  color: widget.isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
      result = result
          .where((t) =>
      t.title.toLowerCase().contains(query) ||
          (t.description?.toLowerCase().contains(query) ?? false))
          .toList();
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
        return result
            .where((t) =>
        t.deadline != null &&
            t.deadline!.isBefore(DateTime.now()) &&
            t.status != 'done' &&
            t.status != 'postponed')
            .toList();
      default:
        return result;
    }
  }

  List<LifeTask> _sortTasks(List<LifeTask> tasks) {
    final sorted = List<LifeTask>.from(tasks);
    sorted.sort((a, b) {
      final priorityOrder = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
      final priorityCompare = (priorityOrder[a.priority] ?? 2)
          .compareTo(priorityOrder[b.priority] ?? 2);
      if (priorityCompare != 0) return priorityCompare;
      if (a.deadline != null && b.deadline != null) {
        return a.deadline!.compareTo(b.deadline!);
      }
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

  // ==================== ДИАЛОГ ====================

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
}