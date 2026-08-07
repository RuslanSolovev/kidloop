// features/life_navigator/ui/widgets/tasks/tasks_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'tasks_constants.dart';
import 'tasks_details.dart';
import 'tasks_edit_dialog.dart';

class TasksCard extends StatefulWidget {
  final LifeTask task;
  final bool isDark;
  final LifeProvider provider;
  final int depth;
  final bool isExpanded;
  final VoidCallback? onExpandToggle;
  final Function(String) onStatusChanged;
  final VoidCallback? onTaskUpdated;
  final bool isLastChild;

  const TasksCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.provider,
    this.depth = 0,
    this.isExpanded = false,
    this.onExpandToggle,
    required this.onStatusChanged,
    this.onTaskUpdated,
    this.isLastChild = false,
  });

  @override
  State<TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends State<TasksCard> {
  late bool _localExpanded;

  @override
  void initState() {
    super.initState();
    _localExpanded = widget.isExpanded;
  }

  @override
  void didUpdateWidget(TasksCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) {
      _localExpanded = widget.isExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.task.statusColor;
    final priorityColor = widget.task.priorityColor;
    final isOverdue = widget.task.deadline != null &&
        widget.task.deadline!.isBefore(DateTime.now()) &&
        widget.task.status != 'done' &&
        widget.task.status != 'postponed';

    final subtasks = widget.provider.tasks.where((t) => t.parentId == widget.task.id).toList();
    final hasSubtasks = subtasks.isNotEmpty;
    final completedSubtasks = subtasks.where((t) => t.status == 'done').length;
    final totalSubtasks = subtasks.length;
    final connectorColor = _getLevelAccent(widget.depth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.depth > 0) _buildConnector(connectorColor),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showDetails(context),
                  child: Container(
                    margin: EdgeInsets.only(
                      left: widget.depth > 0 ? 0 : 4,
                      right: 4,
                      bottom: hasSubtasks && _localExpanded ? 2 : 8,
                      top: widget.depth > 0 ? 2 : 0,
                    ),
                    decoration: BoxDecoration(
                      gradient: _getLevelGradient(widget.depth),
                      borderRadius: BorderRadius.circular(widget.depth == 0 ? 16 : 12),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(widget.isDark ? 0.15 : 0.08),
                          blurRadius: widget.depth == 0 ? 12 : 6,
                          offset: Offset(0, widget.depth == 0 ? 4 : 2),
                        ),
                      ],
                      border: Border.all(
                        color: isOverdue
                            ? Colors.red.withOpacity(0.5)
                            : widget.depth == 0
                            ? statusColor.withOpacity(0.2)
                            : connectorColor.withOpacity(0.2),
                        width: widget.depth == 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusHeader(context, statusColor, priorityColor),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTitle(context),
                              if (widget.task.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                _buildDescription(),
                              ],
                              if (widget.task.images != null && widget.task.images!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildImagePreviews(),
                              ],
                              if (widget.task.tags.isNotEmpty || widget.task.deadline != null || widget.task.hasReminder == true) ...[
                                const SizedBox(height: 8),
                                _buildMetadata(isOverdue),
                              ],
                              if (hasSubtasks) ...[
                                const SizedBox(height: 6),
                                _buildExpandButton(completedSubtasks, totalSubtasks),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasSubtasks)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _localExpanded
                ? _buildSubtasksContainer(context, subtasks, connectorColor)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  LinearGradient _getLevelGradient(int level) {
    if (widget.isDark) {
      switch (level) {
        case 0:
          return const LinearGradient(
            colors: [Color(0xFF1E2233), Color(0xFF171A29)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 1:
          return const LinearGradient(
            colors: [Color(0xFF2A1F2E), Color(0xFF241B29)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 2:
          return const LinearGradient(
            colors: [Color(0xFF1F2A33), Color(0xFF1B2530)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        default:
          return const LinearGradient(
            colors: [Color(0xFF2A2D3A), Color(0xFF252835)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
      }
    } else {
      switch (level) {
        case 0:
          return const LinearGradient(
            colors: [Colors.white, Color(0xFFFCFCFD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 1:
          return const LinearGradient(
            colors: [Color(0xFFFFF0F0), Color(0xFFFDE8E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 2:
          return const LinearGradient(
            colors: [Color(0xFFF0F4FF), Color(0xFFE8EDFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        default:
          return const LinearGradient(
            colors: [Color(0xFFF5F5F5), Color(0xFFF0F0F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
      }
    }
  }

  Widget _buildConnector(Color color) {
    return SizedBox(
      width: 28,
      child: CustomPaint(
        painter: _ConnectorPainter(
          color: color,
          isLast: widget.isLastChild,
          hasChildren: widget.task.subtaskIds?.isNotEmpty == true && _localExpanded,
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, Color statusColor, Color priorityColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.15), statusColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(widget.depth == 0 ? 16 : 12)),
        border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.15), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4, spreadRadius: 1)],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showStatusSelector(context),
            child: Row(
              children: [
                Text(widget.task.statusDisplay, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.3)),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down_rounded, color: statusColor, size: 16),
              ],
            ),
          ),
          const Spacer(),
          if (widget.depth > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getLevelAccent(widget.depth).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _getLevelAccent(widget.depth).withOpacity(0.3), width: 1),
              ),
              child: Text('Ур.${widget.depth}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _getLevelAccent(widget.depth))),
            ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [priorityColor.withOpacity(0.15), priorityColor.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: priorityColor.withOpacity(0.2), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.task.priorityEmoji, style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(widget.task.priorityDisplay, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: priorityColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.depth > 0) ...[
          Container(
            width: 22, height: 22, margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_getLevelAccent(widget.depth).withOpacity(0.25), _getLevelAccent(widget.depth).withOpacity(0.08)]),
              border: Border.all(color: _getLevelAccent(widget.depth).withOpacity(0.4), width: 1.5),
            ),
            child: Center(child: Text('${_getSubtaskNumber()}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _getLevelAccent(widget.depth)))),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            widget.task.title,
            style: TextStyle(fontSize: widget.depth == 0 ? 15 : 14, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : const Color(0xFF1A1D24), height: 1.3),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () => _showEditDialog(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withOpacity(0.2))),
            child: Icon(Icons.edit_rounded, size: 14, color: Colors.blue.withOpacity(0.8)),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
      ),
      child: Text(widget.task.description, style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white.withOpacity(0.7) : Colors.grey.shade700, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildImagePreviews() {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.task.images!.length.clamp(0, 5),
        itemBuilder: (ctx, index) => Container(
          width: 56, height: 56, margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(image: _getImageProvider(widget.task.images![index]), fit: BoxFit.cover),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadata(bool isOverdue) {
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: [
        if (widget.task.tags.isNotEmpty)
          ...widget.task.tags.map((tag) {
            final tagColor = LifeTask.getTagColor(tag);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: tagColor.withOpacity(0.25))),
              child: Text('#$tag', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tagColor)),
            );
          }),
        if (widget.task.deadline != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOverdue ? Colors.red.withOpacity(0.12) : (widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isOverdue ? Colors.red.withOpacity(0.3) : (widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 11, color: isOverdue ? Colors.red : (widget.isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)),
                const SizedBox(width: 4),
                Text('${widget.task.deadline!.day}.${widget.task.deadline!.month}.${widget.task.deadline!.year}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isOverdue ? Colors.red : (widget.isDark ? Colors.white.withOpacity(0.7) : Colors.grey.shade700))),
              ],
            ),
          ),
        if (widget.task.hasReminder == true && widget.task.reminderTime != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.purple.withOpacity(0.25))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.alarm_rounded, size: 11, color: Colors.purple.withOpacity(0.8)),
                const SizedBox(width: 4),
                Text('${widget.task.reminderTime!.hour.toString().padLeft(2, '0')}:${widget.task.reminderTime!.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.purple.withOpacity(0.8))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildExpandButton(int completed, int total) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _localExpanded = !_localExpanded;
        });
        widget.onExpandToggle?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [(widget.isDark ? Colors.white : Colors.black).withOpacity(0.04), (widget.isDark ? Colors.white : Colors.black).withOpacity(0.02)]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(turns: _localExpanded ? 0.25 : 0, duration: const Duration(milliseconds: 250), child: Icon(Icons.chevron_right_rounded, size: 16, color: widget.isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)),
            const SizedBox(width: 6),
            Text(_localExpanded ? 'Скрыть' : 'Подзадачи', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade700)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: completed == total && total > 0 ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('$completed/$total', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: completed == total && total > 0 ? Colors.green : Colors.orange)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtasksContainer(BuildContext context, List<LifeTask> subtasks, Color connectorColor) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 4, bottom: 8),
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [connectorColor.withOpacity(widget.isDark ? 0.1 : 0.06), connectorColor.withOpacity(widget.isDark ? 0.04 : 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: connectorColor.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(color: connectorColor.withOpacity(widget.isDark ? 0.1 : 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: subtasks.asMap().entries.map((entry) {
          final subtask = entry.value;
          final isLast = entry.key == subtasks.length - 1;
          return TasksCard(
            key: ValueKey(subtask.id),
            task: subtask,
            isDark: widget.isDark,
            provider: widget.provider,
            depth: widget.depth + 1,
            isExpanded: false,
            onExpandToggle: () {},
            onStatusChanged: widget.onStatusChanged,
            onTaskUpdated: widget.onTaskUpdated,
            isLastChild: isLast,
          );
        }).toList(),
      ),
    );
  }

  Color _getLevelAccent(int level) {
    switch (level) {
      case 1: return const Color(0xFFE84A4A);
      case 2: return const Color(0xFF4A6FE8);
      default: return Colors.grey;
    }
  }

  int _getSubtaskNumber() {
    if (widget.depth <= 0) return 0;
    final siblings = widget.provider.tasks.where((t) => t.parentId == widget.task.parentId).toList();
    final index = siblings.indexWhere((t) => t.id == widget.task.id);
    return index >= 0 ? index + 1 : 0;
  }

  void _showStatusSelector(BuildContext context) {
    final statuses = [
      {'id': 'formulated', 'label': 'Сформулирована', 'emoji': '📝', 'color': const Color(0xFF4A9EFF)},
      {'id': 'in_progress', 'label': 'В процессе', 'emoji': '⚡', 'color': const Color(0xFFFF6B35)},
      {'id': 'done', 'label': 'Готова', 'emoji': '✅', 'color': const Color(0xFF00C853)},
      {'id': 'postponed', 'label': 'Отложена', 'emoji': '⏰', 'color': const Color(0xFF7C4DFF)},
    ];
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: widget.isDark ? [const Color(0xFF1E2233), const Color(0xFF151824)] : [Colors.white, const Color(0xFFF8F9FA)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Изменить статус', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : const Color(0xFF1A1D24))),
            const SizedBox(height: 16),
            ...statuses.map((s) {
              final isSelected = widget.task.status == s['id'];
              final color = s['color'] as Color;
              return GestureDetector(
                onTap: () { Navigator.pop(ctx); widget.onStatusChanged(s['id'] as String); widget.onTaskUpdated?.call(); },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isSelected ? LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]) : null,
                    color: isSelected ? null : (widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? color.withOpacity(0.4) : Colors.transparent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(s['emoji'] as String, style: const TextStyle(fontSize: 20))),
                      const SizedBox(width: 14),
                      Expanded(child: Text(s['label'] as String, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? color : (widget.isDark ? Colors.white : Colors.black87)))),
                      if (isSelected) Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 16)),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: widget.isDark ? Colors.white60 : Colors.grey.shade600)))),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (ctx) => TasksEditDialog(isDark: widget.isDark, task: widget.task, provider: widget.provider, onClose: () => Navigator.pop(ctx), onTaskUpdated: widget.onTaskUpdated));
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (ctx) => TasksDetailsSheet(isDark: widget.isDark, task: widget.task, provider: widget.provider, onClose: () => Navigator.pop(ctx), onStatusChanged: widget.onStatusChanged, onTaskUpdated: widget.onTaskUpdated));
  }

  ImageProvider _getImageProvider(String path) => path.startsWith('http') ? NetworkImage(path) : FileImage(File(path));
}

class _ConnectorPainter extends CustomPainter {
  final Color color;
  final bool isLast;
  final bool hasChildren;
  _ConnectorPainter({required this.color, required this.isLast, required this.hasChildren});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.3)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final centerX = size.width / 2;
    final midY = size.height / 2;
    final endY = isLast ? midY : size.height;
    if (!isLast || hasChildren) canvas.drawLine(Offset(centerX, 0), Offset(centerX, endY), paint);
    else canvas.drawLine(Offset(centerX, 0), Offset(centerX, midY), paint);
    canvas.drawLine(Offset(centerX, midY), Offset(size.width, midY), paint);
    canvas.drawCircle(Offset(centerX, midY), 3, Paint()..color = color.withOpacity(0.6)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(centerX, midY), 5, Paint()..color = color.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}