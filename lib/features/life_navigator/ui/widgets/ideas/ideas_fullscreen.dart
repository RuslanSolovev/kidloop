// features/life_navigator/ui/widgets/ideas/ideas_fullscreen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';
import 'ideas_common.dart';
import 'ideas_details.dart';
import 'ideas_favorites.dart';
import 'ideas_add_edit.dart';

class FullscreenIdeasView extends StatefulWidget {
  final bool isDark;
  final List<LifeIdea> ideas;
  final LifeProvider provider;
  final VoidCallback onClose;
  const FullscreenIdeasView({super.key, required this.isDark, required this.ideas, required this.provider, required this.onClose});
  @override
  State<FullscreenIdeasView> createState() => _FullscreenIdeasViewState();
}

class _FullscreenIdeasViewState extends State<FullscreenIdeasView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _selectedFilter = 'all';
  String _sortBy = 'ice';
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showFilters = false;
  final TextEditingController _searchController = TextEditingController();

  final _filters = const [
    {'id': 'all', 'label': 'Все', 'emoji': '✨', 'color': Colors.grey},
    {'id': 'business', 'label': 'Бизнес', 'emoji': '💼', 'color': Color(0xFF4A9EFF)},
    {'id': 'creative', 'label': 'Творчество', 'emoji': '🎨', 'color': Color(0xFFFF6B9D)},
    {'id': 'tech', 'label': 'Технологии', 'emoji': '💻', 'color': Color(0xFF00BCD4)},
    {'id': 'home', 'label': 'Дом', 'emoji': '🏠', 'color': Color(0xFFFFA726)},
    {'id': 'health', 'label': 'Здоровье', 'emoji': '❤️', 'color': Color(0xFFFF1744)},
    {'id': 'education', 'label': 'Образование', 'emoji': '📚', 'color': Color(0xFF7C4DFF)},
  ];

  final sorts = const [
    {'id': 'ice', 'label': 'ICE', 'icon': Icons.trending_up_rounded},
    {'id': 'rating', 'label': 'Рейтинг', 'icon': Icons.star_rounded},
    {'id': 'date', 'label': 'Новые', 'icon': Icons.access_time_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<LifeIdea> get _filteredIdeas {
    var r = _selectedFilter == 'all'
        ? widget.ideas
        : widget.ideas.where((i) => i.category == _selectedFilter).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      r = r.where((i) => i.title.toLowerCase().contains(q) || i.description.toLowerCase().contains(q) || i.tags.any((t) => t.toLowerCase().contains(q))).toList();
    }
    switch (_sortBy) {
      case 'ice': r.sort((a, b) => b.iceScore.compareTo(a.iceScore)); break;
      case 'rating': r.sort((a, b) => b.rating.compareTo(a.rating)); break;
      case 'date': r.sort((a, b) => b.createdAt.compareTo(a.createdAt)); break;
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredIdeas;
    final isDark = widget.isDark;
    final favCount = widget.ideas.where((i) => i.isFavorite).length;
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(8, topPadding + 4, 8, 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: isDark ? [const Color(0xFF1A1D2E), const Color(0xFF151824)] : [Colors.white, const Color(0xFFF8F9FA)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.02), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Идеи - Задачи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24), letterSpacing: -0.3)),
            Text('${widget.ideas.length} задач', style: TextStyle(fontSize: 11, color: isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade500)),
          ])),
          _hdrIcon(Icons.search_rounded, _isSearching, () { setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchController.clear(); _searchQuery = ''; } _showFilters = false; }); }),
          const SizedBox(width: 3),
          _hdrIcon(Icons.filter_list_rounded, _showFilters, () => setState(() { _showFilters = !_showFilters; _isSearching = false; }), badge: _selectedFilter != 'all'),
          const SizedBox(width: 3),
          _hdrIcon(Icons.favorite_rounded, false, () => _showFav(context), badge: favCount > 0, badgeColor: Colors.red),
          const SizedBox(width: 3),
          _hdrIcon(Icons.add_rounded, false, () => _showAdd(context), isAdd: true),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade600),
            ),
          ),
        ]),
      ),

      if (_isSearching) Container(padding: const EdgeInsets.fromLTRB(8, 0, 8, 6), child: Container(height: 36, decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200)), child: TextField(controller: _searchController, autofocus: true, onChanged: (v) => setState(() => _searchQuery = v), style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(hintText: 'Поиск...', hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400), prefixIcon: Icon(Icons.search_rounded, size: 16, color: isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6))))),

      if (_showFilters) Container(padding: const EdgeInsets.fromLTRB(8, 0, 8, 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Категория', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)),
        const SizedBox(height: 3),
        Wrap(spacing: 4, runSpacing: 4, children: _filters.map((f) {
          final sel = _selectedFilter == f['id'];
          final c = f['color'] as Color;
          return GestureDetector(onTap: () => setState(() => _selectedFilter = f['id'] as String), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: sel ? c.withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: sel ? c.withOpacity(0.3) : Colors.transparent)), child: Text('${f['emoji']} ${f['label']}', style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? c : (isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)))));
        }).toList()),
        const SizedBox(height: 6),
        Text('Сортировка', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)),
        const SizedBox(height: 3),
        Wrap(spacing: 4, children: sorts.map((s) {
          final sel = _sortBy == s['id'];
          return GestureDetector(onTap: () => setState(() => _sortBy = s['id'] as String), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: sel ? const Color(0xFF7C4DFF).withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: sel ? const Color(0xFF7C4DFF).withOpacity(0.3) : Colors.transparent)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(s['icon'] as IconData, size: 13, color: sel ? const Color(0xFF7C4DFF) : (isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade500)), const SizedBox(width: 3), Text(s['label'] as String, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? const Color(0xFF7C4DFF) : (isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)))])));
        }).toList()),
      ])),

      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _KanbanBoard(isDark: isDark, ideas: filtered, provider: widget.provider))),
    ]);
  }

  Widget _hdrIcon(IconData icon, bool active, VoidCallback onTap, {bool badge = false, Color badgeColor = const Color(0xFF7C4DFF), bool isAdd = false}) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: isAdd ? const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        color: isAdd ? null : active ? const Color(0xFF7C4DFF).withOpacity(0.12) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(10),
        border: active && !isAdd ? Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.25)) : null,
        boxShadow: isAdd ? [BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
      ),
      child: Stack(children: [
        Icon(icon, size: 22, color: isAdd ? Colors.white : active ? const Color(0xFF7C4DFF) : (widget.isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade600)),
        if (badge) Positioned(top: 0, right: 0, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle))),
      ]),
    ));
  }

  void _showAdd(BuildContext ctx) { showModalBottomSheet(context: ctx, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (c) => AddIdeaSheet(isDark: widget.isDark, provider: widget.provider, onClose: () => Navigator.pop(c))); }
  void _showFav(BuildContext ctx) { final f = widget.ideas.where((i) => i.isFavorite).toList(); showModalBottomSheet(context: ctx, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (c) => FavoritesSheet(isDark: widget.isDark, favorites: f, provider: widget.provider, onClose: () => Navigator.pop(c))); }
}

// ============================================================
// КАНБАН
// ============================================================

class _KanbanBoard extends StatelessWidget {
  final bool isDark;
  final List<LifeIdea> ideas;
  final LifeProvider provider;
  const _KanbanBoard({required this.isDark, required this.ideas, required this.provider});

  @override
  Widget build(BuildContext context) {
    final cols = [
      ideas.where((i) => i.status == 'idea').toList(),
      ideas.where((i) => i.status == 'in_progress').toList(),
      ideas.where((i) => i.status == 'done').toList(),
    ];
    final colors = [const Color(0xFF3D8BFD), const Color(0xFFFD7E3D), const Color(0xFF3DD97E)];
    final titles = ['Новые', 'В работе', 'Готово'];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(3, (i) => Expanded(child: _Col(isDark: isDark, title: titles[i], ideas: cols[i], color: colors[i], provider: provider))));
  }
}

class _Col extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<LifeIdea> ideas;
  final Color color;
  final LifeProvider provider;
  const _Col({required this.isDark, required this.title, required this.ideas, required this.color, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.03 : 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(isDark ? 0.06 : 0.04), width: 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color.withOpacity(isDark ? 0.08 : 0.06)))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
              child: Text('${ideas.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(width: 5),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
        Expanded(
          child: ideas.isEmpty
              ? Center(child: Text('—', style: TextStyle(fontSize: 14, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300)))
              : ListView.builder(padding: const EdgeInsets.all(3), itemCount: ideas.length, itemBuilder: (_, i) => _Card(isDark: isDark, idea: ideas[i], provider: provider, color: color)),
        ),
      ]),
    );
  }
}

// ============================================================
// КАРТОЧКА
// ============================================================

class _Card extends StatelessWidget {
  final bool isDark;
  final LifeIdea idea;
  final LifeProvider provider;
  final Color color;
  const _Card({required this.isDark, required this.idea, required this.provider, required this.color});

  @override
  Widget build(BuildContext context) {
    final imgs = idea.images;
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.35 : 0.25),
            width: 2.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Text(
              idea.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (idea.description.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Text(
              getShortDescription(idea.description, wordCount: 5),
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white.withOpacity(0.45) : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (imgs.isNotEmpty) ...[
            const SizedBox(height: 4),
            _photoGrid(context, imgs),
          ],
          const SizedBox(height: 5),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: IceScoreBadge(score: idea.iceScore),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _photoGrid(BuildContext ctx, List<String> imgs) {
    final d = imgs.take(4).toList();
    final hasFive = imgs.length > 4;
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = w * 0.7;
      return Column(children: [
        Row(children: [
          _img(ctx, d, 0, w / 2, h),
          const SizedBox(width: 3),
          _img(ctx, d, 1, w / 2, h),
        ]),
        const SizedBox(height: 3),
        Row(children: [
          _img(ctx, d, 2, w / 2, h),
          const SizedBox(width: 3),
          _img(ctx, d, 3, w / 2, h, overlay: hasFive ? '+${imgs.length - 4}' : null),
        ]),
      ]);
    });
  }

  Widget _img(BuildContext ctx, List<String> imgs, int idx, double w, double h, {String? overlay}) {
    if (idx >= imgs.length) return SizedBox(width: w, height: h);
    return GestureDetector(
      onTap: () => showFullscreenImage(ctx, imgs[idx], isDark: isDark),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: w, height: h,
          child: Stack(children: [
            Image(image: getImageProvider(imgs[idx]), width: w, height: h, fit: BoxFit.cover),
            if (overlay != null)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Text(
                    overlay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  void _showDetails(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (c) => IdeaDetailsSheet(
        isDark: isDark,
        idea: idea,
        provider: provider,
        onClose: () => Navigator.pop(c),
      ),
    );
  }
}