// features/life_navigator/ui/widgets/tasks/tasks_view_switcher.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tasks_constants.dart';

class TasksViewSwitcher extends StatelessWidget {
  final bool isDark;
  final String currentView;
  final Function(String) onViewChanged;

  const TasksViewSwitcher({
    super.key,
    required this.isDark,
    required this.currentView,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    final views = [
      {'id': 'list', 'label': 'Список', 'icon': Icons.list_rounded},
      {'id': 'board', 'label': 'Доска', 'icon': Icons.view_column_rounded},
      {'id': 'kanban', 'label': 'Канбан', 'icon': Icons.grid_view_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: views.map((view) {
          final isSelected = currentView == view['id'];
          final icon = view['icon'] as IconData;
          final label = view['label'] as String;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onViewChanged(view['id'] as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [
                      const Color(0xFFFF6B35).withOpacity(0.15),
                      const Color(0xFFFF6B35).withOpacity(0.05),
                    ],
                  )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF6B35).withOpacity(0.3) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected
                          ? const Color(0xFFFF6B35)
                          : (isDark ? Colors.white38 : Colors.grey.shade500),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFFF6B35)
                            : (isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}