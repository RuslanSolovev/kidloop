// features/life_navigator/ui/widgets/notes/notes_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notes_constants.dart';

class NotesFilterBar extends StatefulWidget {
  final bool isDark;
  final String? selectedCategory;
  final String? selectedTag;
  final String searchQuery;
  final void Function(String?) onCategoryChanged;
  final void Function(String?) onTagChanged;
  final void Function(String) onSearchChanged;
  final List<String> allTags;

  const NotesFilterBar({
    super.key,
    required this.isDark,
    this.selectedCategory,
    this.selectedTag,
    required this.searchQuery,
    required this.onCategoryChanged,
    required this.onTagChanged,
    required this.onSearchChanged,
    required this.allTags,
  });

  @override
  State<NotesFilterBar> createState() => _NotesFilterBarState();
}

class _NotesFilterBarState extends State<NotesFilterBar> {
  final searchController = TextEditingController();
  bool showSearch = false;

  @override
  void initState() {
    super.initState();
    searchController.text = widget.searchQuery;
  }

  @override
  void didUpdateWidget(NotesFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != searchController.text) {
      searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔍 ПОИСК + КАТЕГОРИИ
        Row(
          children: [
            // Кнопка поиска
            GestureDetector(
              onTap: () {
                setState(() => showSearch = !showSearch);
                if (!showSearch) {
                  searchController.clear();
                  widget.onSearchChanged('');
                }
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  showSearch ? Icons.close_rounded : Icons.search_rounded,
                  size: 18,
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Строка поиска или категории
            Expanded(
              child: showSearch
                  ? TextField(
                controller: searchController,
                autofocus: true,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Поиск по заметкам...',
                  hintStyle: TextStyle(
                    color: widget.isDark ? Colors.white24 : Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                onChanged: widget.onSearchChanged,
              )
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: NotesConstants.categories.map((cat) {
                    final isSelected = widget.selectedCategory == cat ||
                        (cat == 'Все' && widget.selectedCategory == null);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onCategoryChanged(cat == 'Все' ? null : cat);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.purple.withOpacity(0.15)
                                : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purple.withOpacity(0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.purple
                                  : (widget.isDark ? Colors.white54 : Colors.grey.shade600),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),

        // 🏷️ ТЕГИ
        if (widget.allTags.isNotEmpty && !showSearch) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "Все теги"
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTagChanged(null);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.selectedTag == null
                          ? Colors.amber.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.selectedTag == null
                            ? Colors.amber.withOpacity(0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      'Все',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: widget.selectedTag == null ? FontWeight.w700 : FontWeight.w500,
                        color: widget.selectedTag == null
                            ? Colors.amber.shade700
                            : (widget.isDark ? Colors.white38 : Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
                ...widget.allTags.map((tag) {
                  final isSelected = widget.selectedTag == tag;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onTagChanged(isSelected ? null : tag);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.purple.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.purple.withOpacity(0.3)
                              : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.purple
                              : (widget.isDark ? Colors.white54 : Colors.grey.shade600),
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
}