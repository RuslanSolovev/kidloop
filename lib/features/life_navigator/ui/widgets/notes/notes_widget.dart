// features/life_navigator/ui/widgets/notes/notes_widget.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import '../base_life_widget.dart';

// ============================================================
// КОНСТАНТЫ
// ============================================================

class NotesConstants {
  static const List<NoteColor> colorPalette = [
    NoteColor(name: 'Белый', color: Color(0xFFFFFFFF), textColor: Color(0xFF202124)),
    NoteColor(name: 'Красный', color: Color(0xFFF28B82), textColor: Color(0xFF202124)),
    NoteColor(name: 'Оранжевый', color: Color(0xFFFBBC04), textColor: Color(0xFF202124)),
    NoteColor(name: 'Жёлтый', color: Color(0xFFFFF475), textColor: Color(0xFF202124)),
    NoteColor(name: 'Зелёный', color: Color(0xFFCCFF90), textColor: Color(0xFF202124)),
    NoteColor(name: 'Бирюзовый', color: Color(0xFFA7FFEB), textColor: Color(0xFF202124)),
    NoteColor(name: 'Голубой', color: Color(0xFFCBF0F8), textColor: Color(0xFF202124)),
    NoteColor(name: 'Синий', color: Color(0xFFAECBFA), textColor: Color(0xFF202124)),
    NoteColor(name: 'Фиолетовый', color: Color(0xFFD7AEFB), textColor: Color(0xFF202124)),
    NoteColor(name: 'Розовый', color: Color(0xFFFDCFE8), textColor: Color(0xFF202124)),
    NoteColor(name: 'Серый', color: Color(0xFFE8EAED), textColor: Color(0xFF202124)),
    NoteColor(name: 'Тёмный', color: Color(0xFF3C4043), textColor: Color(0xFFFFFFFF)),
  ];

  static Color fromHex(String hex) {
    return Color(int.parse('0xFF${hex.replaceFirst('#', '')}'));
  }

  static String toHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  static Color getTextColorForBackground(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF202124) : const Color(0xFFFFFFFF);
  }
}

class NoteColor {
  final String name;
  final Color color;
  final Color textColor;
  const NoteColor({required this.name, required this.color, required this.textColor});
}

// ============================================================
// ОСНОВНОЙ ВИДЖЕТ
// ============================================================

class NotesWidget extends BaseLifeWidget {
  const NotesWidget({super.key, required super.isDark, super.isCompact = true});

  @override
  State<NotesWidget> createState() => _NotesWidgetState();
}

class _NotesWidgetState extends State<NotesWidget> with LifeWidgetMixin<NotesWidget> {
  bool _isGridView = true;
  String? _selectedTag;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isFilterOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }

  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedView = prefs.getBool('notes_view_grid') ?? true;
      if (mounted) setState(() => _isGridView = savedView);
    } catch (_) {}
  }

  Future<void> _saveViewPreference(bool isGrid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notes_view_grid', isGrid);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final notes = provider.notes;

    var filteredNotes = _filterNotes(notes);
    filteredNotes = _sortNotes(filteredNotes);

    final pinnedNotes = filteredNotes.where((n) => n.isFavorite).toList();
    final regularNotes = filteredNotes.where((n) => !n.isFavorite).toList();
    final allTags = _getAllTags(notes);
    final totalNotes = notes.length;
    final favoritesCount = notes.where((n) => n.isFavorite).length;

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
          border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04), width: 1.5),
          boxShadow: [
            BoxShadow(color: widget.isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.06), blurRadius: 40, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(provider, totalNotes, favoritesCount, allTags),
            if (_isSearching) ...[const SizedBox(height: 12), _buildSearchBar()],
            if (_isFilterOpen) ...[const SizedBox(height: 12), _buildFilterPanel(allTags)],
            const SizedBox(height: 12),
            if (notes.isEmpty)
              _buildEmptyState()
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: AnimationLimiter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pinnedNotes.isNotEmpty) ...[
                          _buildSectionHeader('📌 Закреплённые', pinnedNotes.length),
                          const SizedBox(height: 6),
                          _buildNotesGrid(pinnedNotes, provider),
                          const SizedBox(height: 12),
                          if (regularNotes.isNotEmpty) Divider(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200, height: 1),
                          const SizedBox(height: 8),
                        ],
                        if (regularNotes.isNotEmpty) ...[
                          if (pinnedNotes.isNotEmpty) _buildSectionHeader('📝 Все заметки', regularNotes.length),
                          const SizedBox(height: 6),
                          _buildNotesGrid(regularNotes, provider),
                        ],
                        if (regularNotes.isEmpty && pinnedNotes.isEmpty) _buildNoResults(),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.isCompact) ...[const SizedBox(height: 10), _buildCompactHint()],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ЗАГОЛОВОК С КНОПКАМИ
  // ============================================================

  Widget _buildHeader(LifeProvider provider, int totalNotes, int favoritesCount, List<String> allTags) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Icon(Icons.note_rounded, color: Colors.white, size: widget.isCompact ? 22 : 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Заметки', style: TextStyle(fontSize: widget.isCompact ? 19 : 23, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : const Color(0xFF1A1D24), letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text('$totalNotes заметок', style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  if (favoritesCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber.withOpacity(0.2), Colors.amber.withOpacity(0.08)]), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade600),
                        const SizedBox(width: 4),
                        Text('$favoritesCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber.shade600)),
                      ]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        _buildHeaderIcon(icon: Icons.grid_view_rounded, isActive: _isGridView, onTap: () { HapticFeedback.lightImpact(); final v = !_isGridView; setState(() => _isGridView = v); _saveViewPreference(v); }),
        const SizedBox(width: 4),
        _buildHeaderIcon(icon: Icons.search_rounded, isActive: _isSearching, onTap: () { setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchController.clear(); _searchQuery = ''; } _isFilterOpen = false; }); }),
        const SizedBox(width: 4),
        _buildHeaderIcon(icon: Icons.filter_list_rounded, isActive: _isFilterOpen, hasBadge: _selectedTag != null, onTap: () { setState(() { _isFilterOpen = !_isFilterOpen; _isSearching = false; }); }),
        const SizedBox(width: 4),
        _buildHeaderIcon(icon: Icons.add_rounded, isActive: false, isAddButton: true, onTap: () => _showAddNoteDialog(context, provider)),
      ],
    );
  }

  Widget _buildHeaderIcon({required IconData icon, required bool isActive, required VoidCallback onTap, bool hasBadge = false, bool isAddButton = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: isAddButton ? const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: isAddButton ? null : isActive ? const Color(0xFF7C4DFF).withOpacity(0.15) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: isActive && !isAddButton ? Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3), width: 1.5) : null,
          boxShadow: isAddButton ? [BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Stack(
          children: [
            Icon(icon, size: 20, color: isAddButton ? Colors.white : isActive ? const Color(0xFF7C4DFF) : (widget.isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade600)),
            if (hasBadge) Positioned(top: 0, right: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF7C4DFF), shape: BoxShape.circle))),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200)),
      child: TextField(
        controller: _searchController, autofocus: true,
        style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Поиск заметок...', hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400),
          suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.close_rounded, size: 18, color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildFilterPanel(List<String> allTags) {
    if (allTags.isEmpty) {
      return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)), child: Center(child: Text('Нет тегов', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade500))));
    }
    return Container(
      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Теги', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          GestureDetector(onTap: () => setState(() => _selectedTag = null), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _selectedTag == null ? const Color(0xFF7C4DFF).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedTag == null ? const Color(0xFF7C4DFF).withOpacity(0.4) : Colors.transparent)), child: Text('Все', style: TextStyle(fontSize: 11, fontWeight: _selectedTag == null ? FontWeight.w700 : FontWeight.w500, color: _selectedTag == null ? const Color(0xFF7C4DFF) : (widget.isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600))))),
          ...allTags.map((tag) {
            final isSelected = _selectedTag == tag;
            final tagColor = _getTagColor(tag);
            return GestureDetector(onTap: () => setState(() => _selectedTag = isSelected ? null : tag), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isSelected ? tagColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? tagColor.withOpacity(0.4) : Colors.transparent)), child: Text('#$tag', style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? tagColor : (widget.isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)))));
          }),
        ]),
      ]),
    );
  }

  Color _getTagColor(String tag) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.indigo, Colors.cyan];
    return colors[tag.hashCode.abs() % colors.length];
  }

  // ============================================================
  // СЕТКА ЗАМЕТОК - АДАПТИВНАЯ ВЫСОТА
  // ============================================================

  Widget _buildNotesGrid(List<LifeNote> notes, LifeProvider provider) {
    if (notes.isEmpty) return const SizedBox.shrink();

    if (_isGridView) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = widget.isCompact ? 2 : 3;
          final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 8) / crossAxisCount;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: notes.asMap().entries.map((entry) {
              final note = entry.value;
              return AnimationConfiguration.staggeredList(
                position: entry.key,
                duration: const Duration(milliseconds: 400),
                child: SlideAnimation(
                  verticalOffset: 30,
                  child: FadeInAnimation(
                    child: SizedBox(
                      width: itemWidth,
                      child: _buildNoteCard(note, provider, isGridView: true),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      );
    }

    return Column(
      children: notes.asMap().entries.map((entry) {
        return AnimationConfiguration.staggeredList(
          position: entry.key,
          duration: const Duration(milliseconds: 300),
          child: SlideAnimation(verticalOffset: 20, child: FadeInAnimation(child: _buildNoteCard(entry.value, provider, isGridView: false))),
        );
      }).toList(),
    );
  }

  // ============================================================
  // КАРТОЧКА ЗАМЕТКИ
  // ============================================================

  Widget _buildNoteCard(LifeNote note, LifeProvider provider, {required bool isGridView}) {
    final noteColor = NotesConstants.fromHex(note.color);
    final textColor = NotesConstants.getTextColorForBackground(noteColor);

    return GestureDetector(
      onTap: () => _showEditNoteDialog(context, note),
      onLongPress: () => _showNoteMenu(context, note, provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.all(isGridView ? 10 : 14),
        decoration: BoxDecoration(
          color: noteColor,
          borderRadius: BorderRadius.circular(isGridView ? 14 : 10),
          border: Border.all(color: noteColor == Colors.white ? (widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300) : noteColor.withOpacity(0.3), width: noteColor == Colors.white ? 1 : 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _MarqueeText(text: note.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: isGridView ? 11 : 15, color: textColor, height: 1.2), maxLines: 2)),
            if (note.isFavorite) Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Icon(Icons.star_rounded, color: Colors.amber.shade700, size: isGridView ? 14 : 16)),
          ]),
          if (note.content.isNotEmpty) ...[
            SizedBox(height: isGridView ? 4 : 6),
            Text(note.content, style: TextStyle(fontSize: isGridView ? 10 : 13, color: textColor.withOpacity(0.7), height: 1.3), maxLines: isGridView ? 3 : 2, overflow: TextOverflow.ellipsis),
          ],
          if (note.images.isNotEmpty) ...[
            SizedBox(height: isGridView ? 6 : 8),
            Wrap(spacing: 4, runSpacing: 4, children: note.images.take(5).map((url) => ClipRRect(borderRadius: BorderRadius.circular(isGridView ? 5 : 8), child: Image(image: _getImageProvider(url), width: isGridView ? 36 : 48, height: isGridView ? 36 : 48, fit: BoxFit.cover))).toList()),
          ],
          if (note.tags.isNotEmpty) ...[
            SizedBox(height: isGridView ? 6 : 8),
            Wrap(spacing: 4, runSpacing: 4, children: note.tags.take(isGridView ? 3 : 5).map((tag) => Container(padding: EdgeInsets.symmetric(horizontal: isGridView ? 6 : 8, vertical: isGridView ? 3 : 4), decoration: BoxDecoration(color: textColor.withOpacity(0.08), borderRadius: BorderRadius.circular(isGridView ? 4 : 6)), child: Text('#$tag', style: TextStyle(fontSize: isGridView ? 8 : 10, color: textColor.withOpacity(0.6), fontWeight: FontWeight.w500)))).toList()),
          ],
          SizedBox(height: isGridView ? 6 : 8),
          Row(children: [
            Text(_formatDate(note.updatedAt), style: TextStyle(fontSize: isGridView ? 8 : 10, color: textColor.withOpacity(0.4))),
            const Spacer(),
            if (note.content.length > 100) Icon(Icons.article_rounded, size: isGridView ? 10 : 12, color: textColor.withOpacity(0.3)),
          ]),
        ]),
      ),
    );
  }

  ImageProvider _getImageProvider(String path) => path.startsWith('http') ? NetworkImage(path) : FileImage(File(path));

  Widget _buildSectionHeader(String title, int count) {
    return Row(children: [
      Text(title, style: TextStyle(fontSize: widget.isCompact ? 12 : 14, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white70 : Colors.grey.shade700, letterSpacing: 0.3)),
      const SizedBox(width: 6),
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white38 : Colors.grey.shade500))),
    ]);
  }

  Widget _buildCompactHint() {
    return Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.purple.withOpacity(0.1), Colors.blue.withOpacity(0.1)]), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.open_in_full_rounded, size: 14, color: Colors.purple.withOpacity(0.5)), const SizedBox(width: 4), Text('Нажмите для полного просмотра', style: TextStyle(fontSize: 10, color: Colors.purple.withOpacity(0.4)))])));
  }

  Widget _buildEmptyState() {
    return Expanded(child: Center(child: Padding(padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 30 : 50), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.purple.withOpacity(0.1), Colors.blue.withOpacity(0.1)]), shape: BoxShape.circle), child: const Text('📝', style: TextStyle(fontSize: 48))),
      const SizedBox(height: 12),
      Text('Нет заметок', style: TextStyle(fontSize: widget.isCompact ? 16 : 20, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white60 : Colors.grey.shade600)),
      const SizedBox(height: 4),
      Text('Нажмите + чтобы создать первую заметку', style: TextStyle(fontSize: widget.isCompact ? 12 : 14, color: widget.isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400)),
    ]))));
  }

  Widget _buildNoResults() {
    return Center(child: Padding(padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 20 : 30), child: Column(children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange.withOpacity(0.1), Colors.red.withOpacity(0.1)]), shape: BoxShape.circle), child: const Text('🔍', style: TextStyle(fontSize: 32))),
      const SizedBox(height: 8),
      Text('Ничего не найдено', style: TextStyle(fontSize: widget.isCompact ? 14 : 16, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white38 : Colors.grey.shade500)),
      const SizedBox(height: 4),
      Text('Попробуйте изменить параметры поиска', style: TextStyle(fontSize: widget.isCompact ? 11 : 13, color: widget.isDark ? Colors.white24 : Colors.grey.shade400)),
    ])));
  }

  List<LifeNote> _filterNotes(List<LifeNote> notes) {
    var result = notes;
    if (_searchQuery.isNotEmpty) { final q = _searchQuery.toLowerCase(); result = result.where((n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q) || n.tags.any((t) => t.toLowerCase().contains(q))).toList(); }
    if (_selectedTag != null) result = result.where((n) => n.tags.contains(_selectedTag)).toList();
    return result;
  }

  List<LifeNote> _sortNotes(List<LifeNote> notes) {
    final sorted = List<LifeNote>.from(notes);
    sorted.sort((a, b) { if (a.isFavorite && !b.isFavorite) return -1; if (!a.isFavorite && b.isFavorite) return 1; return b.updatedAt.compareTo(a.updatedAt); });
    return sorted;
  }

  List<String> _getAllTags(List<LifeNote> notes) {
    final tags = <String>{};
    for (final n in notes) tags.addAll(n.tags);
    return tags.toList()..sort();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин.';
    if (diff.inHours < 24) return '${diff.inHours} ч.';
    if (diff.inDays < 7) return '${diff.inDays} дн.';
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showAddNoteDialog(BuildContext context, LifeProvider provider) { showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (ctx) => NotesAddDialog(isDark: widget.isDark, provider: provider)); }
  void _showEditNoteDialog(BuildContext context, LifeNote note) { final p = context.read<LifeProvider>(); showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (ctx) => NotesEditDialog(note: note, isDark: widget.isDark, provider: p)); }

  void _showNoteMenu(BuildContext context, LifeNote note, LifeProvider provider) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(note.title.isNotEmpty ? note.title[0].toUpperCase() : '📝'))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(note.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis), Text(_formatDate(note.updatedAt), style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500))])),
        ]),
        const SizedBox(height: 16),
        _buildMenuItem(ctx, icon: Icons.edit_rounded, label: 'Редактировать', color: Colors.blue, onTap: () { Navigator.pop(ctx); _showEditNoteDialog(context, note); }),
        _buildMenuItem(ctx, icon: Icons.star_rounded, label: note.isFavorite ? 'Убрать из избранного' : 'В избранное', color: Colors.amber, onTap: () { provider.updateNote(LifeNote(id: note.id, title: note.title, content: note.content, tags: note.tags, color: note.color, isFavorite: !note.isFavorite, images: note.images, createdAt: note.createdAt)); Navigator.pop(ctx); }),
        _buildMenuItem(ctx, icon: Icons.delete_rounded, label: 'Удалить', color: Colors.red, isDestructive: true, onTap: () { Navigator.pop(ctx); provider.deleteNote(note.id); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🗑️ Заметка удалена'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))),
      ]),
    ));
  }

  Widget _buildMenuItem(BuildContext ctx, {required IconData icon, required String label, required Color color, required VoidCallback onTap, bool isDestructive = false}) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDestructive ? Colors.red.withOpacity(0.2) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200))), child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 12), Expanded(child: Text(label, style: TextStyle(color: isDestructive ? Colors.red : (widget.isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w500, fontSize: 14))), Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20)])));
  }
}

// ============================================================
// ПЛАВНАЯ АВТО-ПРОКРУТКА "ПАРОВОЗИК"
// ============================================================

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  const _MarqueeText({required this.text, required this.style, this.maxLines = 2});
  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<Offset>? _animation;
  final GlobalKey _textKey = GlobalKey();
  double _textWidth = 0;
  double _containerWidth = 0;
  bool _needsScroll = false;
  bool _initialized = false;
  Timer? _pauseTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (_initialized) return;
    _initialized = true;
    final renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && _containerWidth > 0) {
      _textWidth = renderBox.size.width;
      _needsScroll = _textWidth > _containerWidth;
      if (_needsScroll) _startScroll();
    }
  }

  void _startScroll() {
    final scrollDistance = _textWidth - _containerWidth + 60;
    _controller.duration = Duration(milliseconds: (scrollDistance * 30).toInt().clamp(2000, 8000));
    _animation = Tween<Offset>(begin: Offset.zero, end: Offset(-scrollDistance, 0)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.addStatusListener(_onStatusChange);
    _pauseTimer = Timer(const Duration(milliseconds: 800), () { if (mounted) _controller.forward(); });
  }

  void _onStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _pauseTimer = Timer(const Duration(seconds: 1), () { if (mounted) _controller.reverse(); });
    } else if (status == AnimationStatus.dismissed) {
      _pauseTimer = Timer(const Duration(seconds: 1), () { if (mounted) _controller.forward(); });
    }
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _containerWidth = constraints.maxWidth;
      return ClipRect(
        child: _needsScroll && _animation != null
            ? AnimatedBuilder(animation: _controller, builder: (context, child) => SlideTransition(position: _animation!, child: child!),
            child: Text(widget.text, key: _textKey, style: widget.style, maxLines: 1, softWrap: false))
            : Text(widget.text, key: _textKey, style: widget.style, maxLines: widget.maxLines, overflow: TextOverflow.ellipsis),
      );
    });
  }
}

// Стандартный AnimatedBuilder из Flutter
class AnimatedBuilder extends AnimatedWidget {
  final Widget? child;
  final Widget Function(BuildContext, Widget?) builder;
  const AnimatedBuilder({super.key, required Animation<double> animation, required this.builder, this.child}) : super(listenable: animation);
  @override
  Widget build(BuildContext context) => builder(context, child);
}

// ============================================================
// ДИАЛОГ ДОБАВЛЕНИЯ ЗАМЕТКИ
// ============================================================

class NotesAddDialog extends StatefulWidget {
  final bool isDark;
  final LifeProvider provider;
  const NotesAddDialog({super.key, required this.isDark, required this.provider});
  @override
  State<NotesAddDialog> createState() => _NotesAddDialogState();
}

class _NotesAddDialogState extends State<NotesAddDialog> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final tagController = TextEditingController();
  String selectedColor = '#FFFFFF';
  List<String> tags = [];
  bool isChecklist = false;
  final List<ChecklistItem> checklistItems = [];
  final List<String> images = [];
  final int maxImages = 5;

  @override
  void dispose() { titleController.dispose(); contentController.dispose(); tagController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: widget.isDark ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)] : [Colors.white, const Color(0xFFF8F9FA)], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))]), child: const Icon(Icons.note_add_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Новая заметка', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : const Color(0xFF1A1D24))), Text('Запишите свои мысли', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500))])),
          IconButton(onPressed: _pasteFromClipboard, icon: Icon(Icons.content_paste_rounded, color: Colors.purple.withOpacity(0.6), size: 20), tooltip: 'Вставить из буфера'),
        ]),
        const SizedBox(height: 18),
        TextField(controller: titleController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Заголовок', labelStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2)), prefixIcon: Icon(Icons.title_rounded, color: Colors.purple.withOpacity(0.5), size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
        const SizedBox(height: 12),
        TextField(controller: contentController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87), maxLines: 4, decoration: InputDecoration(labelText: 'Содержание', labelStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2)), prefixIcon: Icon(Icons.article_rounded, color: Colors.purple.withOpacity(0.5), size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
        const SizedBox(height: 14),
        _buildColorPalette(),
        const SizedBox(height: 14),
        _buildTagsSection(),
        const SizedBox(height: 12),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Чек-лист', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black87)), subtitle: Text(isChecklist ? 'Добавьте пункты списка' : 'Обычная заметка', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500)), value: isChecklist, activeColor: const Color(0xFF7C4DFF), onChanged: (v) => setState(() => isChecklist = v)),
        if (isChecklist) _buildChecklistItems(),
        const SizedBox(height: 12),
        _buildPhotoSection(),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: _saveNote, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), child: const Text('Создать', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: widget.isDark ? Colors.white70 : Colors.grey.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300)), child: const Text('Отмена'))),
        ]),
      ])),
    );
  }

  Widget _buildColorPalette() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Цвет заметки', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: NotesConstants.colorPalette.map((nc) {
        final sel = selectedColor == NotesConstants.toHex(nc.color);
        return GestureDetector(onTap: () => setState(() => selectedColor = NotesConstants.toHex(nc.color)), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: nc.color, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? Colors.purple : Colors.grey.withOpacity(0.3), width: sel ? 3 : 1), boxShadow: sel ? [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 6)] : null), child: sel ? Icon(Icons.check_rounded, color: nc.textColor, size: 16) : null));
      }).toList()),
    ]);
  }

  Widget _buildTagsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Теги', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: tagController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13), decoration: InputDecoration(hintText: 'Добавить тег...', hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade400, fontSize: 13), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), onSubmitted: _addTag)),
        const SizedBox(width: 8),
        GestureDetector(onTap: () => _addTag(tagController.text), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.add_rounded, color: Colors.purple, size: 20))),
      ]),
      if (tags.isNotEmpty) ...[const SizedBox(height: 8), Wrap(spacing: 4, runSpacing: 4, children: tags.map((t) => Chip(label: Text('#$t', style: const TextStyle(fontSize: 11)), deleteIcon: Icon(Icons.close_rounded, size: 14), onDeleted: () => setState(() => tags.remove(t)), backgroundColor: Colors.purple.withOpacity(0.1), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 4))).toList())],
    ]);
  }

  Widget _buildChecklistItems() {
    return Column(children: [
      ...checklistItems.asMap().entries.map((e) => Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: e.value.isChecked ? Colors.green.withOpacity(0.3) : Colors.transparent, width: 1.5)), child: Row(children: [
        GestureDetector(onTap: () => setState(() => e.value.isChecked = !e.value.isChecked), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: e.value.isChecked ? Colors.green : (widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200), border: Border.all(color: e.value.isChecked ? Colors.green : (widget.isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300), width: 1)), child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: e.value.isChecked ? Icon(Icons.check_rounded, key: const ValueKey('checked'), color: Colors.white, size: 18) : const SizedBox.shrink(key: ValueKey('unchecked'))))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: e.value.controller, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, decoration: e.value.isChecked ? TextDecoration.lineThrough : null, decorationColor: Colors.green, decorationThickness: 1.5), decoration: InputDecoration(hintText: 'Пункт ${e.key + 1}', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), onChanged: (_) => setState(() {}))),
        IconButton(icon: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade300), onPressed: () => setState(() => checklistItems.removeAt(e.key)), visualDensity: VisualDensity.compact),
      ]))),
      TextButton.icon(onPressed: () => setState(() => checklistItems.add(ChecklistItem())), icon: Icon(Icons.add_rounded, size: 16, color: Colors.purple), label: Text('Добавить пункт', style: TextStyle(color: Colors.purple, fontSize: 12))),
    ]);
  }

  Widget _buildPhotoSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Фото (до $maxImages)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
      const SizedBox(height: 8),
      SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: images.length + (images.length < maxImages ? 1 : 0), itemBuilder: (ctx, i) {
        if (i == images.length) return GestureDetector(onTap: _addImage, child: Container(width: 80, height: 80, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300, width: 2)), child: Icon(Icons.add_photo_alternate_outlined, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade400, size: 32)));
        return Stack(children: [Container(width: 80, height: 80, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: _getImageProvider(images[i]), fit: BoxFit.cover))), Positioned(top: 4, right: 12, child: GestureDetector(onTap: () => setState(() => images.removeAt(i)), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14))))]);
      })),
    ]);
  }

  ImageProvider _getImageProvider(String p) => p.startsWith('http') ? NetworkImage(p) : FileImage(File(p));

  Future<void> _addImage() async {
    try { final i = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80); if (i != null && images.length < maxImages) setState(() => images.add(i.path)); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)); }
  }

  void _addTag(String t) { final tr = t.trim().toLowerCase(); if (tr.isNotEmpty && !tags.contains(tr)) setState(() { tags.add(tr); tagController.clear(); }); }

  Future<void> _pasteFromClipboard() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null && d!.text!.isNotEmpty) {
      if (titleController.text.isEmpty) { final ls = d.text!.split('\n'); titleController.text = ls.first; contentController.text = ls.length > 1 ? ls.sublist(1).join('\n') : ''; }
      else contentController.text += '\n${d.text}';
      setState(() {});
    }
  }

  void _saveNote() {
    String fc = contentController.text;
    if (isChecklist && checklistItems.isNotEmpty) { final ct = checklistItems.map((i) => '${i.isChecked ? '✅' : '☐'} ${i.controller.text}').join('\n'); fc = fc.isNotEmpty ? '$fc\n\n--- Чек-лист ---\n$ct' : ct; }
    if (titleController.text.isNotEmpty || fc.isNotEmpty) {
      final t = titleController.text.isNotEmpty ? titleController.text : fc.substring(0, fc.length.clamp(0, 30));
      widget.provider.addNote(t, fc, tags: tags, color: selectedColor, images: images);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Заметка "$t" создана'), backgroundColor: Colors.purple, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
    }
  }
}

// ============================================================
// ДИАЛОГ РЕДАКТИРОВАНИЯ ЗАМЕТКИ
// ============================================================

class NotesEditDialog extends StatefulWidget {
  final LifeNote note; final bool isDark; final LifeProvider provider;
  const NotesEditDialog({super.key, required this.note, required this.isDark, required this.provider});
  @override
  State<NotesEditDialog> createState() => _NotesEditDialogState();
}

class _NotesEditDialogState extends State<NotesEditDialog> {
  late TextEditingController titleController, contentController;
  late String selectedColor;
  late List<String> tags;
  late bool isFavorite, isChecklist;
  late List<ChecklistItem> checklistItems;
  late List<String> images;
  final int maxImages = 5;
  Timer? _autoSaveTimer;
  bool _isSaving = false, _hasChanges = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note.title);
    contentController = TextEditingController(text: widget.note.content);
    selectedColor = widget.note.color; tags = List.from(widget.note.tags); isFavorite = widget.note.isFavorite; images = List.from(widget.note.images);
    isChecklist = widget.note.content.contains('✅') || widget.note.content.contains('☐');
    checklistItems = [];
    if (isChecklist) {
      final ls = widget.note.content.split('\n'); bool ic = false; final cl = <String>[];
      for (final l in ls) { if (l.contains('--- Чек-лист ---')) { ic = true; continue; } if (ic) { if (l.contains('✅') || l.contains('☐')) { final ck = l.contains('✅'); final tx = l.replaceAll('✅', '').replaceAll('☐', '').trim(); if (tx.isNotEmpty) { final it = ChecklistItem(); it.controller.text = tx; it.isChecked = ck; checklistItems.add(it); } } } else { if (l.isNotEmpty) cl.add(l); } }
      contentController.text = cl.join('\n');
    }
    titleController.addListener(_onChanged); contentController.addListener(_onChanged);
  }

  @override
  void dispose() { _autoSaveTimer?.cancel(); titleController.dispose(); contentController.dispose(); super.dispose(); }

  void _onChanged() { if (!_hasChanges) setState(() => _hasChanges = true); _autoSaveTimer?.cancel(); _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave); }

  Future<void> _autoSave() async {
    if (!_hasChanges) return; setState(() => _isSaving = true);
    String fc = contentController.text;
    if (isChecklist && checklistItems.isNotEmpty) { final ct = checklistItems.map((i) => '${i.isChecked ? '✅' : '☐'} ${i.controller.text}').join('\n'); fc = fc.isNotEmpty ? '$fc\n\n--- Чек-лист ---\n$ct' : ct; }
    await widget.provider.updateNote(LifeNote(id: widget.note.id, title: titleController.text, content: fc, tags: tags, color: selectedColor, isFavorite: isFavorite, images: images, createdAt: widget.note.createdAt));
    if (mounted) setState(() { _hasChanges = false; _isSaving = false; });
  }

  @override
  Widget build(BuildContext context) {
    final nc = NotesConstants.fromHex(selectedColor);
    final tc = NotesConstants.getTextColorForBackground(nc);
    return Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: widget.isDark ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)] : [Colors.white, const Color(0xFFF8F9FA)], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))), const Spacer(), if (_isSaving) Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)), const SizedBox(width: 4), Text('Сохранение...', style: TextStyle(fontSize: 10, color: Colors.green))]) else if (!_hasChanges) Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_done_rounded, size: 12, color: Colors.green.withOpacity(0.6)), const SizedBox(width: 4), Text('Сохранено', style: TextStyle(fontSize: 10, color: Colors.green.withOpacity(0.6)))])]),
        const SizedBox(height: 20),
        TextField(controller: titleController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: 'Заголовок', hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade400), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
        const SizedBox(height: 12),
        TextField(controller: contentController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87), maxLines: 6, decoration: InputDecoration(hintText: 'Содержание...', hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade400), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
        const SizedBox(height: 14),
        Text('Предпросмотр:', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500)), const SizedBox(height: 6),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: nc, borderRadius: BorderRadius.circular(14), border: Border.all(color: nc == Colors.white ? Colors.grey.shade300 : Colors.transparent)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (titleController.text.isNotEmpty) Text(titleController.text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tc)), if (contentController.text.isNotEmpty) ...[const SizedBox(height: 4), Text(contentController.text, style: TextStyle(fontSize: 12, color: tc.withOpacity(0.7)), maxLines: 3, overflow: TextOverflow.ellipsis)], if (titleController.text.isEmpty && contentController.text.isEmpty) Text('Предпросмотр заметки', style: TextStyle(color: tc.withOpacity(0.3), fontStyle: FontStyle.italic))])),
        const SizedBox(height: 14),
        Wrap(spacing: 4, runSpacing: 4, children: NotesConstants.colorPalette.map((nc) { final sel = selectedColor == NotesConstants.toHex(nc.color); return GestureDetector(onTap: () { setState(() => selectedColor = NotesConstants.toHex(nc.color)); _onChanged(); }, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: nc.color, shape: BoxShape.circle, border: Border.all(color: sel ? Colors.purple : Colors.grey.withOpacity(0.3), width: sel ? 3 : 1)), child: sel ? Icon(Icons.check_rounded, color: nc.textColor, size: 14) : null)); }).toList()),
        const SizedBox(height: 12),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Чек-лист', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black87)), subtitle: Text(isChecklist ? 'Редактируйте пункты списка' : 'Добавить чек-лист', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500)), value: isChecklist, activeColor: const Color(0xFF7C4DFF), onChanged: (v) { setState(() { isChecklist = v; _onChanged(); }); }),
        if (isChecklist) _buildChecklistItems(), const SizedBox(height: 12), _buildPhotoSection(), const SizedBox(height: 12),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('В избранном', style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.white : Colors.black87)), value: isFavorite, activeColor: Colors.amber, onChanged: (v) { setState(() { isFavorite = v; _onChanged(); }); }),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: ElevatedButton(onPressed: () { _autoSave(); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)))), const SizedBox(width: 10), Expanded(child: OutlinedButton(onPressed: () { _autoSave(); Navigator.pop(context); }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300)), child: Text('Закрыть', style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 15))))]),
      ])),
    );
  }

  Widget _buildChecklistItems() {
    if (checklistItems.isEmpty) return GestureDetector(onTap: () { setState(() { checklistItems.add(ChecklistItem()); _onChanged(); }); }, child: Container(margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 18, color: Colors.purple), const SizedBox(width: 8), Text('Добавить пункт', style: TextStyle(color: Colors.purple, fontSize: 13, fontWeight: FontWeight.w600))])));
    return Column(children: [
      Container(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4), margin: const EdgeInsets.only(bottom: 4), child: Row(children: [Icon(Icons.checklist_rounded, size: 16, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500), const SizedBox(width: 6), Text('Чек-лист (${checklistItems.where((i) => i.isChecked).length}/${checklistItems.length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500))])),
      ...checklistItems.asMap().entries.map((e) => Container(margin: const EdgeInsets.only(bottom: 4), decoration: BoxDecoration(color: e.value.isChecked ? (widget.isDark ? Colors.green.withOpacity(0.06) : Colors.green.withOpacity(0.04)) : (widget.isDark ? Colors.white.withOpacity(0.02) : Colors.white), borderRadius: BorderRadius.circular(10), border: Border.all(color: e.value.isChecked ? Colors.green.withOpacity(0.2) : (widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(onTap: () { setState(() { e.value.isChecked = !e.value.isChecked; _onChanged(); }); }, child: AnimatedContainer(duration: const Duration(milliseconds: 250), width: 28, height: 28, margin: const EdgeInsets.only(left: 8, top: 6), decoration: BoxDecoration(shape: BoxShape.circle, color: e.value.isChecked ? Colors.green : (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200), border: Border.all(color: e.value.isChecked ? Colors.green : (widget.isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade400), width: 2)), child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: e.value.isChecked ? Icon(Icons.check_rounded, key: const ValueKey('checked'), color: Colors.white, size: 16) : const SizedBox.shrink(key: ValueKey('unchecked'))))),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), child: TextField(controller: e.value.controller, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13, height: 1.4, decoration: e.value.isChecked ? TextDecoration.lineThrough : null, decorationColor: Colors.green, decorationThickness: 2), maxLines: null, keyboardType: TextInputType.multiline, textInputAction: TextInputAction.newline, decoration: InputDecoration(hintText: 'Пункт ${e.key + 1}', hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade400, fontSize: 13), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.only(top: 2, bottom: 2)), onChanged: (_) { setState(() {}); _onChanged(); }))),
        GestureDetector(onTap: () { setState(() { checklistItems.removeAt(e.key); _onChanged(); }); }, child: Container(padding: const EdgeInsets.all(6), margin: const EdgeInsets.only(right: 4, top: 4), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade300))),
      ]))),
      GestureDetector(onTap: () { setState(() { checklistItems.add(ChecklistItem()); _onChanged(); }); }, child: Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 16, color: Colors.purple), const SizedBox(width: 6), Text('Добавить пункт', style: TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.w600))]))),
    ]);
  }

  Widget _buildPhotoSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Фото (до $maxImages)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)), const SizedBox(height: 8), SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: images.length + (images.length < maxImages ? 1 : 0), itemBuilder: (ctx, i) { if (i == images.length) return GestureDetector(onTap: _addImage, child: Container(width: 80, height: 80, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300, width: 2)), child: Icon(Icons.add_photo_alternate_outlined, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade400, size: 32))); return Stack(children: [Container(width: 80, height: 80, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: _getImageProvider(images[i]), fit: BoxFit.cover))), Positioned(top: 4, right: 12, child: GestureDetector(onTap: () => setState(() => images.removeAt(i)), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14))))]); }))]);
  }

  ImageProvider _getImageProvider(String p) => p.startsWith('http') ? NetworkImage(p) : FileImage(File(p));

  Future<void> _addImage() async { try { final i = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80); if (i != null && images.length < maxImages) setState(() { images.add(i.path); _onChanged(); }); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)); } }
}

class ChecklistItem {
  final TextEditingController controller = TextEditingController();
  bool isChecked = false;
}