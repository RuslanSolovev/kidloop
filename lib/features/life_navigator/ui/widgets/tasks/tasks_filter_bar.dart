// features/life_navigator/ui/widgets/tasks/tasks_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tasks_constants.dart';

class TasksFilterBar extends StatelessWidget {
  final bool isDark;
  final String currentFilter;
  final String? selectedTag;
  final String searchQuery;
  final int overdueCount;
  final List<String> allTags;
  final Function(String) onFilterChanged;
  final Function(String?) onTagChanged;
  final Function(String) onSearchChanged;

  const TasksFilterBar({
    super.key,
    required this.isDark,
    required this.currentFilter,
    this.selectedTag,
    required this.searchQuery,
    required this.overdueCount,
    required this.allTags,
    required this.onFilterChanged,
    required this.onTagChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = [
      {'id': 'all', 'label': 'Все', 'icon': Icons.list_rounded, 'color': Colors.grey},
      {'id': 'formulated', 'label': 'Сформулирована', 'icon': Icons.edit_note_rounded, 'color': const Color(0xFF4A9EFF)},
      {'id': 'in_progress', 'label': 'В процессе', 'icon': Icons.play_circle_rounded, 'color': const Color(0xFFFF6B35)},
      {'id': 'postponed', 'label': 'Отложена', 'icon': Icons.pause_circle_rounded, 'color': const Color(0xFF7C4DFF)},
      {'id': 'done', 'label': 'Готова', 'icon': Icons.check_circle_rounded, 'color': const Color(0xFF00C853)},
      {'id': 'overdue', 'label': 'Просрочено', 'icon': Icons.warning_rounded, 'color': Colors.red},
    ];

    return Column(
      children: [
        // Поиск
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: TextField(
            onChanged: onSearchChanged,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: '🔍 Поиск задач...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white38 : Colors.grey.shade400),
                onPressed: () => onSearchChanged(''),
              )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Фильтры по статусу (в несколько рядов)
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: statuses.map((s) {
            final isSelected = currentFilter == s['id'];
            final color = s['color'] as Color;
            final icon = s['icon'] as IconData;
            final label = s['label'] as String;
            final badge = s['id'] == 'overdue' && overdueCount > 0 ? '$overdueCount' : null;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onFilterChanged(s['id'] as String);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.05),
                    ],
                  )
                      : null,
                  color: isSelected ? null : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: isSelected ? color : (isDark ? Colors.white38 : Colors.grey.shade500)),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Теги
        if (allTags.isNotEmpty) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTagChanged(null);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selectedTag == null
                          ? const Color(0xFFFF6B35).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedTag == null
                            ? const Color(0xFFFF6B35).withOpacity(0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      'Все',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selectedTag == null ? FontWeight.w700 : FontWeight.w500,
                        color: selectedTag == null
                            ? const Color(0xFFFF6B35)
                            : (isDark ? Colors.white38 : Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
                ...allTags.map((tag) {
                  final isSelected = selectedTag == tag;
                  final tagColor = _getTagColor(tag);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTagChanged(isSelected ? null : tag);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? tagColor.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? tagColor.withOpacity(0.3) : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? tagColor : (isDark ? Colors.white38 : Colors.grey.shade500),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _getTagColor(String tag) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    return colors[tag.hashCode.abs() % colors.length];
  }
}