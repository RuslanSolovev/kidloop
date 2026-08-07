// features/life_navigator/ui/widgets/ideas/ideas_fullscreen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';
import 'ideas_common.dart';
import 'ideas_details.dart';
import 'ideas_favorites.dart';
import 'ideas_add_edit.dart';

// ============================================================
// ПОЛНОЭКРАННЫЙ РЕЖИМ
// ============================================================

class FullscreenIdeasView extends StatefulWidget {
  final bool isDark;
  final List<LifeIdea> ideas;
  final LifeProvider provider;
  final VoidCallback onClose;

  const FullscreenIdeasView({
    super.key,
    required this.isDark,
    required this.ideas,
    required this.provider,
    required this.onClose,
  });

  @override
  State<FullscreenIdeasView> createState() => _FullscreenIdeasViewState();
}

class _FullscreenIdeasViewState extends State<FullscreenIdeasView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _selectedFilter = 'all';
  String _selectedPriorityFilter = 'all';
  String _sortBy = 'ice';
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showFilters = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _filters = [
    {'id': 'all', 'label': 'Все', 'emoji': '✨', 'color': Colors.grey},
    {'id': 'business', 'label': 'Бизнес', 'emoji': '💼', 'color': const Color(0xFF4A9EFF)},
    {'id': 'creative', 'label': 'Творчество', 'emoji': '🎨', 'color': const Color(0xFFFF6B9D)},
    {'id': 'tech', 'label': 'Технологии', 'emoji': '💻', 'color': const Color(0xFF00BCD4)},
    {'id': 'home', 'label': 'Дом', 'emoji': '🏠', 'color': const Color(0xFFFFA726)},
    {'id': 'health', 'label': 'Здоровье', 'emoji': '❤️', 'color': const Color(0xFFFF1744)},
    {'id': 'education', 'label': 'Образование', 'emoji': '📚', 'color': const Color(0xFF7C4DFF)},
  ];

  final List<Map<String, dynamic>> _priorityFilters = [
    {'id': 'all', 'label': 'Все', 'color': Colors.grey},
    {'id': 'high', 'label': 'Высокий', 'color': Colors.red},
    {'id': 'medium', 'label': 'Средний', 'color': Colors.orange},
    {'id': 'low', 'label': 'Низкий', 'color': Colors.blue},
  ];

  final sorts = const [
    {'id': 'ice', 'label': 'ICE', 'icon': Icons.trending_up_rounded},
    {'id': 'rating', 'label': 'Рейтинг', 'icon': Icons.star_rounded},
    {'id': 'date', 'label': 'Новые', 'icon': Icons.access_time_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<LifeIdea> get _filteredIdeas {
    var result = _selectedFilter == 'all'
        ? widget.ideas
        : widget.ideas.where((i) => i.category == _selectedFilter).toList();

    if (_selectedPriorityFilter != 'all') {
      result = result.where((i) {
        if (_selectedPriorityFilter == 'high') return i.priority >= 7;
        if (_selectedPriorityFilter == 'medium') return i.priority >= 4 && i.priority <= 6;
        if (_selectedPriorityFilter == 'low') return i.priority <= 3;
        return true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((i) =>
      i.title.toLowerCase().contains(query) ||
          i.description.toLowerCase().contains(query) ||
          i.tags.any((t) => t.toLowerCase().contains(query))).toList();
    }

    switch (_sortBy) {
      case 'ice':
        result.sort((a, b) => b.iceScore.compareTo(a.iceScore));
        break;
      case 'rating':
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'date':
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredIdeas;
    final isDark = widget.isDark;

    return Column(
      children: [
        _FullscreenHeader(
          isDark: isDark,
          ideas: widget.ideas,
          onClose: widget.onClose,
          onAdd: () => _showAddDialog(context),
          isSearching: _isSearching,
          onSearchToggle: () => setState(() => _isSearching = !_isSearching),
          searchController: _searchController,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          onFilterToggle: () => setState(() => _showFilters = !_showFilters),
          showFilters: _showFilters,
          onShowFavorites: () => _showFavoritesDialog(context),
          favoritesCount: widget.ideas.where((i) => i.isFavorite).length,
        ),
        _FullscreenActions(
          isDark: isDark,
          onShowFavorites: () => _showFavoritesDialog(context),
          favoritesCount: widget.ideas.where((i) => i.isFavorite).length,
          onFilterToggle: () => setState(() => _showFilters = !_showFilters),
          showFilters: _showFilters,
          isSearching: _isSearching,
          onSearchToggle: () => setState(() => _isSearching = !_isSearching),
          searchController: _searchController,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          onAdd: () => _showAddDialog(context),
        ),
        _FullscreenStats(isDark: isDark, ideas: widget.ideas),
        if (_showFilters)
          _FullscreenFilters(
            isDark: isDark,
            filters: _filters,
            selectedFilter: _selectedFilter,
            priorityFilters: _priorityFilters,
            selectedPriorityFilter: _selectedPriorityFilter,
            sortBy: _sortBy,
            onFilterChanged: (f) => setState(() => _selectedFilter = f),
            onPriorityFilterChanged: (p) => setState(() => _selectedPriorityFilter = p),
            onSortChanged: (s) => setState(() => _sortBy = s),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _FullscreenKanban(
              key: ValueKey(_selectedFilter + _selectedPriorityFilter + _sortBy + _searchQuery),
              isDark: isDark,
              ideas: filtered,
              provider: widget.provider,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AddIdeaSheet(
        isDark: widget.isDark,
        provider: widget.provider,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showFavoritesDialog(BuildContext context) {
    final favorites = widget.ideas.where((i) => i.isFavorite).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FavoritesSheet(
        isDark: widget.isDark,
        favorites: favorites,
        provider: widget.provider,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }
}

// ============================================================
// ПОЛНОЭКРАННЫЙ ЗАГОЛОВОК
// ============================================================

class _FullscreenHeader extends StatelessWidget {
  final bool isDark;
  final List<LifeIdea> ideas;
  final VoidCallback onClose;
  final VoidCallback onAdd;
  final bool isSearching;
  final VoidCallback onSearchToggle;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final VoidCallback onFilterToggle;
  final bool showFilters;
  final VoidCallback onShowFavorites;
  final int favoritesCount;

  const _FullscreenHeader({
    required this.isDark,
    required this.ideas,
    required this.onClose,
    required this.onAdd,
    required this.isSearching,
    required this.onSearchToggle,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterToggle,
    required this.showFilters,
    required this.onShowFavorites,
    required this.favoritesCount,
  });

  @override
  Widget build(BuildContext context) {
    final active = ideas.where((i) => i.status != 'done').length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Задачи',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1D24),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7C4DFF).withOpacity(0.2),
                            const Color(0xFFB388FF).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$active',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C4DFF),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${ideas.length} задач • ${ideas.where((i) => i.status == 'in_progress').length} в работе',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          GlassIconButton(
            icon: Icons.close_rounded,
            onTap: onClose,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ПОЛНОЭКРАННЫЕ ДЕЙСТВИЯ
// ============================================================

class _FullscreenActions extends StatelessWidget {
  final bool isDark;
  final VoidCallback onShowFavorites;
  final int favoritesCount;
  final VoidCallback onFilterToggle;
  final bool showFilters;
  final bool isSearching;
  final VoidCallback onSearchToggle;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final VoidCallback onAdd;

  const _FullscreenActions({
    required this.isDark,
    required this.onShowFavorites,
    required this.favoritesCount,
    required this.onFilterToggle,
    required this.showFilters,
    required this.isSearching,
    required this.onSearchToggle,
    required this.searchController,
    required this.onSearchChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onShowFavorites,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: favoritesCount > 0 ? Colors.red.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: favoritesCount > 0 ? Colors.red.withOpacity(0.2) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: favoritesCount > 0 ? Colors.red : (isDark ? Colors.white38 : Colors.grey.shade400),
                        size: 18,
                      ),
                      if (favoritesCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$favoritesCount',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassActionButton(
                icon: showFilters ? Icons.close_rounded : Icons.filter_list_rounded,
                label: showFilters ? 'Скрыть' : 'Фильтр',
                onTap: onFilterToggle,
                isDark: isDark,
                isActive: showFilters,
              ),
              const SizedBox(width: 8),
              GlassActionButton(
                icon: isSearching ? Icons.close_rounded : Icons.search_rounded,
                label: isSearching ? 'Закрыть' : 'Поиск',
                onTap: () {
                  if (isSearching) {
                    searchController.clear();
                    onSearchChanged('');
                  }
                  onSearchToggle();
                },
                isDark: isDark,
                isActive: isSearching,
              ),
              const Spacer(),
              GlassActionButton(
                icon: Icons.add_rounded,
                label: 'Добавить',
                onTap: onAdd,
                isDark: isDark,
                isActive: true,
                color: const Color(0xFF7C4DFF),
              ),
            ],
          ),
          if (isSearching) ...[
            const SizedBox(height: 8),
            Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                    isDark ? Colors.white.withOpacity(0.02) : Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: searchController,
                autofocus: true,
                onChanged: onSearchChanged,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Поиск задач...',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// ПОЛНОЭКРАННАЯ СТАТИСТИКА
// ============================================================

class _FullscreenStats extends StatelessWidget {
  final bool isDark;
  final List<LifeIdea> ideas;

  const _FullscreenStats({
    required this.isDark,
    required this.ideas,
  });

  @override
  Widget build(BuildContext context) {
    final total = ideas.length;
    final active = ideas.where((i) => i.status != 'done').length;
    final inProgress = ideas.where((i) => i.status == 'in_progress').length;
    final done = ideas.where((i) => i.status == 'done').length;

    final stats = [
      {'label': 'Всего', 'value': '$total', 'color': const Color(0xFF4A9EFF)},
      {'label': 'Активные', 'value': '$active', 'color': const Color(0xFFFF6B35)},
      {'label': 'В процессе', 'value': '$inProgress', 'color': const Color(0xFF7C4DFF)},
      {'label': 'Готово', 'value': '$done', 'color': const Color(0xFF00C853)},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: stats.map((stat) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (stat['color'] as Color).withOpacity(isDark ? 0.08 : 0.04),
                  (stat['color'] as Color).withOpacity(isDark ? 0.03 : 0.01),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (stat['color'] as Color).withOpacity(isDark ? 0.1 : 0.04),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  stat['value'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: stat['color'] as Color,
                  ),
                ),
                Text(
                  stat['label'] as String,
                  style: TextStyle(
                    fontSize: 8,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ============================================================
// ПОЛНОЭКРАННЫЕ ФИЛЬТРЫ
// ============================================================

class _FullscreenFilters extends StatelessWidget {
  final bool isDark;
  final List<Map<String, dynamic>> filters;
  final String selectedFilter;
  final List<Map<String, dynamic>> priorityFilters;
  final String selectedPriorityFilter;
  final String sortBy;
  final Function(String) onFilterChanged;
  final Function(String) onPriorityFilterChanged;
  final Function(String) onSortChanged;

  const _FullscreenFilters({
    required this.isDark,
    required this.filters,
    required this.selectedFilter,
    required this.priorityFilters,
    required this.selectedPriorityFilter,
    required this.sortBy,
    required this.onFilterChanged,
    required this.onPriorityFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Категория:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    itemBuilder: (ctx, index) {
                      final filter = filters[index];
                      final isSelected = selectedFilter == filter['id'];
                      final color = filter['color'] as Color? ?? Colors.grey;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onFilterChanged(filter['id'] as String);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                color.withOpacity(0.2),
                                color.withOpacity(0.08),
                              ],
                            )
                                : null,
                            color: isSelected
                                ? null
                                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? color : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                filter['emoji'] as String,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                filter['label'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? color
                                      : (isDark ? Colors.white70 : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Приоритет:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              ...priorityFilters.map((pf) {
                final isSelected = selectedPriorityFilter == pf['id'];
                final color = pf['color'] as Color;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPriorityFilterChanged(pf['id'] as String);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                        colors: [
                          color.withOpacity(0.2),
                          color.withOpacity(0.08),
                        ],
                      )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      pf['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Сортировка:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              ...sorts.map((s) {
                final isSelected = sortBy == s['id'];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSortChanged(s['id'] as String);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                        colors: [
                          const Color(0xFF7C4DFF).withOpacity(0.2),
                          const Color(0xFF7C4DFF).withOpacity(0.08),
                        ],
                      )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7C4DFF)
                            : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          s['icon'] as IconData,
                          size: 12,
                          color: isSelected
                              ? const Color(0xFF7C4DFF)
                              : (isDark ? Colors.white38 : Colors.grey.shade500),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          s['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF7C4DFF)
                                : (isDark ? Colors.white54 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  final sorts = const [
    {'id': 'ice', 'label': 'ICE', 'icon': Icons.trending_up_rounded},
    {'id': 'rating', 'label': 'Рейтинг', 'icon': Icons.star_rounded},
    {'id': 'date', 'label': 'Новые', 'icon': Icons.access_time_rounded},
  ];
}

// ============================================================
// ПОЛНОЭКРАННЫЙ КАНБАН
// ============================================================

class _FullscreenKanban extends StatelessWidget {
  final bool isDark;
  final List<LifeIdea> ideas;
  final LifeProvider provider;

  const _FullscreenKanban({
    super.key,
    required this.isDark,
    required this.ideas,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final columns = [
      ideas.where((i) => i.status == 'idea').toList(),
      ideas.where((i) => i.status == 'in_progress').toList(),
      ideas.where((i) => i.status == 'done').toList(),
    ];

    final colors = [
      const Color(0xFF4A9EFF),
      const Color(0xFFFF6B35),
      const Color(0xFF00C853),
    ];

    final titles = ['Новые', 'В процессе', 'Готово'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (index) {
        return Expanded(
          child: _FullscreenColumn(
            isDark: isDark,
            title: titles[index],
            ideas: columns[index],
            color: colors[index],
            provider: provider,
          ),
        );
      }),
    );
  }
}

class _FullscreenColumn extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<LifeIdea> ideas;
  final Color color;
  final LifeProvider provider;

  const _FullscreenColumn({
    required this.isDark,
    required this.title,
    required this.ideas,
    required this.color,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(isDark ? 0.06 : 0.02),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.08 : 0.03),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(isDark ? 0.1 : 0.04),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${ideas.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (ideas.isEmpty)
            const SizedBox(height: 20)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(4),
              itemCount: ideas.length,
              itemBuilder: (_, i) => _FullscreenIdeaCard(
                isDark: isDark,
                idea: ideas[i],
                provider: provider,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// ПОЛНОЭКРАННАЯ КАРТОЧКА (с фото в сетке 2x2)
// ============================================================

class _FullscreenIdeaCard extends StatelessWidget {
  final bool isDark;
  final LifeIdea idea;
  final LifeProvider provider;
  final Color color;

  const _FullscreenIdeaCard({
    required this.isDark,
    required this.idea,
    required this.provider,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> images = idea.images;

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(isDark ? 0.1 : 0.04),
              isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.08 : 0.03),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Название
            Text(
              idea.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Описание
            if (idea.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                getShortDescription(idea.description, wordCount: 8),
                style: TextStyle(
                  fontSize: 9,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Фото в сетке 2x2
            if (images.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildPhotoGrid(context, images),
            ],
            // ICE
            const SizedBox(height: 6),
            Center(
              child: IceScoreBadge(score: idea.iceScore),
            ),
            // Кнопки: редактирование и удаление в ряд
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ActionButton(
                  icon: Icons.edit_rounded,
                  color: Colors.blue,
                  size: 20,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showEditDialog(context);
                  },
                ),
                const SizedBox(width: 16),
                ActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _confirmDelete(context);
                  },
                ),
              ],
            ),
            // Лайк отдельно снизу
            const SizedBox(height: 2),
            Center(
              child: ActionButton(
                icon: Icons.favorite_rounded,
                color: Colors.red,
                isActive: idea.isFavorite,
                size: 22,
                onTap: () {
                  HapticFeedback.lightImpact();
                  provider.updateIdea(idea.copyWith(isFavorite: !idea.isFavorite));
                },
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(BuildContext context, List<String> images) {
    final displayImages = images.take(4).toList();
    final remaining = images.length - 4;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.2,
        children: List.generate(displayImages.length, (index) {
          final imageUrl = displayImages[index];
          return GestureDetector(
            onTap: () => showFullscreenImage(context, imageUrl, isDark: isDark),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                image: DecorationImage(
                  image: getImageProvider(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: (index == 3 && remaining > 0)
                  ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
                  : null,
            ),
          );
        }),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить задачу?'),
        content: Text('"${idea.title}" будет удалена без возможности восстановления'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteIdea(idea.id);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => EditIdeaSheet(
        isDark: isDark,
        idea: idea,
        provider: provider,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => IdeaDetailsSheet(
        isDark: isDark,
        idea: idea,
        provider: provider,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }
}