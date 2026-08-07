// features/life_navigator/ui/widgets/notes_widget.dart
// ============================================================
// ПОЛНОСТЬЮ ПЕРЕРАБОТАННЫЙ ВИДЖЕТ ЗАМЕТОК
// ============================================================

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

  static const List<String> categories = [
    'Все', 'Работа', 'Личное', 'Идеи', 'Рецепты', 'Финансы', 'Здоровье', 'Учёба', 'Проекты', 'Другое'
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
  String? _selectedCategory;
  String? _selectedTag;
  String _searchQuery = '';
  bool _isExpanded = false;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }

  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedView = prefs.getBool('notes_view_grid') ?? true;
      if (mounted) {
        setState(() => _isGridView = savedView);
      }
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

    final maxDisplayRegular = widget.isCompact ? 4 : regularNotes.length;
    final displayedRegular = _isExpanded ? regularNotes : regularNotes.take(maxDisplayRegular).toList();

    return GestureDetector(
      onTap: widget.isCompact ? openFullScreen : null,
      child: Container(
        padding: EdgeInsets.all(widget.isCompact ? 16 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isDark
                ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(provider, filteredNotes.length),
            const SizedBox(height: 12),
            if (notes.isNotEmpty) ...[
              _buildSearchAndFilters(allTags),
              const SizedBox(height: 12),
            ],
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
                          if (regularNotes.isNotEmpty)
                            Divider(
                              color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                              height: 1,
                            ),
                          const SizedBox(height: 8),
                        ],
                        if (regularNotes.isNotEmpty) ...[
                          if (pinnedNotes.isNotEmpty)
                            _buildSectionHeader('📝 Все заметки', regularNotes.length),
                          const SizedBox(height: 6),
                          _buildNotesGrid(displayedRegular, provider),
                        ],
                        if (regularNotes.isEmpty && pinnedNotes.isEmpty)
                          _buildNoResults(),
                        _buildExpandButtons(regularNotes),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _buildActionButtons(provider),
            if (widget.isCompact) ...[
              const SizedBox(height: 8),
              _buildCompactHint(),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ЗАГОЛОВОК
  // ============================================================

  Widget _buildHeader(LifeProvider provider, int filteredCount) {
    final totalNotes = provider.notes.length;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
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
          child: Icon(
            Icons.note_rounded,
            color: Colors.white,
            size: widget.isCompact ? 20 : 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Заметки',
                style: TextStyle(
                  fontSize: widget.isCompact ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  Text(
                    totalNotes > 0 ? '$totalNotes заметок' : 'Нет заметок',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedCategory != null || _selectedTag != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.withOpacity(0.2), Colors.purple.withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$filteredCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (totalNotes > 0)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final newValue = !_isGridView;
              setState(() => _isGridView = newValue);
              _saveViewPreference(newValue);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                size: widget.isCompact ? 18 : 20,
                color: widget.isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ),
        const SizedBox(width: 8),
        if (totalNotes > 0)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showFavoritesOnly = !_showFavoritesOnly);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _showFavoritesOnly ? Colors.amber.withOpacity(0.15) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _showFavoritesOnly ? Colors.amber.withOpacity(0.3) : (widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.star_rounded,
                size: widget.isCompact ? 18 : 20,
                color: _showFavoritesOnly ? Colors.amber : (widget.isDark ? Colors.white38 : Colors.grey.shade400),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // ПОИСК И ФИЛЬТРЫ
  // ============================================================

  Widget _buildSearchAndFilters(List<String> allTags) {
    return Column(
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: TextStyle(
              fontSize: 14,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: '🔍 Поиск заметок...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: widget.isDark ? Colors.white38 : Colors.grey.shade400),
                onPressed: () => setState(() => _searchQuery = ''),
              )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...NotesConstants.categories.map((cat) {
                final isSelected = _selectedCategory == cat || (cat == 'Все' && _selectedCategory == null);
                return _buildFilterChip(
                  label: cat,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat == 'Все' ? null : cat);
                  },
                );
              }),
              if (allTags.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(width: 1, height: 20, color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                const SizedBox(width: 4),
                ...allTags.map((tag) {
                  final isSelected = _selectedTag == tag;
                  return _buildFilterChip(
                    label: '#$tag',
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTag = isSelected ? null : tag);
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [Colors.purple.withOpacity(0.2), Colors.purple.withOpacity(0.05)],
          )
              : null,
          color: isSelected ? null : (widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.purple : (widget.isDark ? Colors.white70 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // СЕТКА ЗАМЕТОК
  // ============================================================

  Widget _buildNotesGrid(List<LifeNote> notes, LifeProvider provider) {
    if (notes.isEmpty) return const SizedBox.shrink();

    if (_isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.isCompact ? 2 : 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 30,
              child: FadeInAnimation(
                child: _buildNoteCard(note, provider, isGridView: true),
              ),
            ),
          );
        },
      );
    }

    return Column(
      children: notes.asMap().entries.map((entry) {
        final index = entry.key;
        final note = entry.value;
        return AnimationConfiguration.staggeredList(
          position: index,
          duration: const Duration(milliseconds: 300),
          child: SlideAnimation(
            verticalOffset: 20,
            child: FadeInAnimation(
              child: _buildNoteCard(note, provider, isGridView: false),
            ),
          ),
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
        padding: EdgeInsets.all(isGridView ? 12 : 14),
        decoration: BoxDecoration(
          color: noteColor,
          borderRadius: BorderRadius.circular(isGridView ? 14 : 10),
          border: Border.all(
            color: noteColor == Colors.white
                ? (widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300)
                : noteColor.withOpacity(0.3),
            width: noteColor == Colors.white ? 1 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isGridView ? 13 : 15,
                      color: textColor,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (note.isFavorite)
                  Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 16),
                const SizedBox(width: 4),
              ],
            ),
            if (note.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note.content,
                style: TextStyle(
                  fontSize: isGridView ? 11 : 13,
                  color: textColor.withOpacity(0.7),
                  height: 1.3,
                ),
                maxLines: isGridView ? 4 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Фото в карточке (увеличенные размеры)
            if (note.images.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: note.images.take(isGridView ? 3 : 4).map((imageUrl) {
                  return Container(
                    width: isGridView ? 28 : 32,
                    height: isGridView ? 28 : 32,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      image: DecorationImage(
                        image: _getImageProvider(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const Spacer(),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: note.tags.take(isGridView ? 2 : 3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 9,
                        color: textColor.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatDate(note.updatedAt),
                  style: TextStyle(
                    fontSize: 9,
                    color: textColor.withOpacity(0.4),
                  ),
                ),
                const Spacer(),
                Icon(
                  note.content.length > 100 ? Icons.article_rounded : Icons.more_vert_rounded,
                  size: 12,
                  color: textColor.withOpacity(0.3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    } else {
      return FileImage(File(path));
    }
  }

  // ============================================================
  // СЕКЦИЯ ЗАГОЛОВОК
  // ============================================================

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: widget.isCompact ? 12 : 14,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // КНОПКИ ДЕЙСТВИЙ
  // ============================================================

  Widget _buildActionButtons(LifeProvider provider) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showAddNoteDialog(context, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: widget.isCompact ? 18 : 20),
                  const SizedBox(width: 6),
                  Text(
                    'Добавить',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: widget.isCompact ? 14 : 16,
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
            onTap: () => _showAllNotesDialog(context, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  'Все заметки',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white70 : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: widget.isCompact ? 14 : 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showQuickActions(context, provider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: widget.isDark ? Colors.white70 : Colors.grey.shade600,
              size: widget.isCompact ? 18 : 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_full_rounded, size: 14, color: Colors.purple.withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(
              'Нажмите для полного просмотра',
              style: TextStyle(
                fontSize: 10,
                color: Colors.purple.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // КНОПКИ РАЗВОРАЧИВАНИЯ
  // ============================================================

  Widget _buildExpandButtons(List<LifeNote> regularNotes) {
    if (regularNotes.length <= 4 || !widget.isCompact) return const SizedBox.shrink();

    if (!_isExpanded) {
      return FadeInUp(
        child: GestureDetector(
          onTap: () {
            setState(() => _isExpanded = true);
            HapticFeedback.selectionClick();
          },
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.withOpacity(widget.isDark ? 0.08 : 0.04), Colors.blue.withOpacity(widget.isDark ? 0.08 : 0.04)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.purple.withOpacity(widget.isDark ? 0.1 : 0.04),
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.expand_more_rounded, size: 18, color: Colors.purple),
                  const SizedBox(width: 6),
                  Text(
                    'Показать ещё ${regularNotes.length - 4} заметок',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() => _isExpanded = false);
        HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_less_rounded, size: 18, color: widget.isDark ? Colors.white54 : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Свернуть',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ПУСТЫЕ СОСТОЯНИЯ
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 30 : 50),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Text('📝', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 12),
            Text(
              'Нет заметок',
              style: TextStyle(
                fontSize: widget.isCompact ? 16 : 20,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Создайте первую заметку!',
              style: TextStyle(
                fontSize: widget.isCompact ? 12 : 14,
                color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 20 : 30),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.withOpacity(0.1), Colors.red.withOpacity(0.1)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Text('🔍', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 8),
            Text(
              'Ничего не найдено',
              style: TextStyle(
                fontSize: widget.isCompact ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Попробуйте изменить параметры поиска',
              style: TextStyle(
                fontSize: widget.isCompact ? 11 : 13,
                color: widget.isDark ? Colors.white24 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ============================================================

  List<LifeNote> _filterNotes(List<LifeNote> notes) {
    var result = notes;

    if (_showFavoritesOnly) {
      result = result.where((n) => n.isFavorite).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((n) {
        return n.title.toLowerCase().contains(query) ||
            n.content.toLowerCase().contains(query) ||
            n.tags.any((t) => t.toLowerCase().contains(query));
      }).toList();
    }

    if (_selectedCategory != null && _selectedCategory != 'Все') {
      result = result.where((n) => n.tags.contains(_selectedCategory!.toLowerCase())).toList();
    }

    if (_selectedTag != null) {
      result = result.where((n) => n.tags.contains(_selectedTag)).toList();
    }

    return result;
  }

  List<LifeNote> _sortNotes(List<LifeNote> notes) {
    final sorted = List<LifeNote>.from(notes);
    sorted.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  List<String> _getAllTags(List<LifeNote> notes) {
    final tags = <String>{};
    for (final note in notes) {
      tags.addAll(note.tags);
    }
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

  // ============================================================
  // ДИАЛОГИ
  // ============================================================

  void _showAddNoteDialog(BuildContext context, LifeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => NotesAddDialog(
        isDark: widget.isDark,
        provider: provider,
      ),
    );
  }

  void _showEditNoteDialog(BuildContext context, LifeNote note) {
    final provider = context.read<LifeProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => NotesEditDialog(
        note: note,
        isDark: widget.isDark,
        provider: provider,
      ),
    );
  }

  void _showAllNotesDialog(BuildContext context, LifeProvider provider) {
    final notes = provider.notes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isDark
                ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.note_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Все заметки',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.withOpacity(0.2), Colors.purple.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${notes.length} шт.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (notes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📝', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(
                        'Нет заметок',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: notes.length,
                  itemBuilder: (ctx, index) {
                    final note = notes[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 50),
                      child: _buildNoteCard(note, provider, isGridView: false),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  'Закрыть',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActions(BuildContext context, LifeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '⚡ Быстрые действия',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickAction(
              icon: Icons.content_paste_rounded,
              label: 'Вставить из буфера',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(ctx);
                _pasteFromClipboard(context, provider);
              },
            ),
            _buildQuickAction(
              icon: Icons.bolt_rounded,
              label: 'Быстрая заметка',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(ctx);
                _showQuickAddDialog(context, provider);
              },
            ),
            _buildQuickAction(
              icon: Icons.photo_camera_rounded,
              label: 'Заметка с фото',
              color: Colors.green,
              onTap: () {
                Navigator.pop(ctx);
                _pickImageForNote(context, provider);
              },
            ),
            _buildQuickAction(
              icon: Icons.mic_rounded,
              label: 'Голосовая заметка',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(ctx);
                // TODO: Реализовать голосовую заметку
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ФОТО ДЛЯ ЗАМЕТОК
  // ============================================================

  Future<void> _pickImageForNote(BuildContext context, LifeProvider provider) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        final title = 'Фото ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}';
        await provider.addNote(
          title,
          '',
          images: [image.path],
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.photo_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('📸 Заметка с фото создана')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выборе фото: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showNoteMenu(BuildContext context, LifeNote note, LifeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(note.title.isNotEmpty ? note.title[0].toUpperCase() : '📝'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatDate(note.updatedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              icon: Icons.edit_rounded,
              label: 'Редактировать',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(ctx);
                _showEditNoteDialog(context, note);
              },
            ),
            _buildMenuItem(
              icon: Icons.star_rounded,
              label: note.isFavorite ? 'Убрать из избранного' : 'В избранное',
              color: Colors.amber,
              onTap: () {
                provider.updateNote(LifeNote(
                  id: note.id,
                  title: note.title,
                  content: note.content,
                  tags: note.tags,
                  color: note.color,
                  isFavorite: !note.isFavorite,
                  images: note.images,
                  createdAt: note.createdAt,
                ));
                Navigator.pop(ctx);
              },
            ),
            _buildMenuItem(
              icon: Icons.lightbulb_rounded,
              label: 'Конвертировать в идею',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(ctx);
                provider.addIdea(
                  title: note.title,
                  description: note.content,
                  tags: note.tags,
                  images: note.images, // <-- ПЕРЕДАЁМ ФОТО
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('💡 Заметка "${note.title}" → идея'),
                    backgroundColor: Colors.purple,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.content_copy_rounded,
              label: 'Дублировать',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(ctx);
                provider.addNote(
                  '${note.title} (копия)',
                  note.content,
                  tags: note.tags,
                  color: note.color,
                  images: note.images,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📝 Заметка дублирована'),
                    backgroundColor: Colors.purple,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.delete_rounded,
              label: 'Удалить',
              color: Colors.red,
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                provider.deleteNote(note.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ Заметка удалена'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withOpacity(0.2)
                : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red : (widget.isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // БЫСТРЫЕ ДЕЙСТВИЯ
  // ============================================================

  Future<void> _pasteFromClipboard(BuildContext context, LifeProvider provider) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📋 Буфер обмена пуст'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final text = data.text!;
    final lines = text.split('\n');
    final title = lines.first.length > 50 ? '${lines.first.substring(0, 50)}...' : lines.first;
    final content = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    await provider.addNote(title, content);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📝 Заметка "$title" создана из буфера'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQuickAddDialog(BuildContext context, LifeProvider provider) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.purple, size: 24),
            const SizedBox(width: 8),
            Text(
              '⚡ Быстрая заметка',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Введите текст заметки...',
            hintStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade400),
            filled: true,
            fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.addNote(controller.text, '');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✅ Заметка создана'),
                    backgroundColor: Colors.purple,
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
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
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildHeader(),
            const SizedBox(height: 18),
            _buildTitleField(),
            const SizedBox(height: 12),
            _buildContentField(),
            const SizedBox(height: 14),
            _buildColorPalette(),
            const SizedBox(height: 14),
            _buildTagsSection(),
            const SizedBox(height: 14),
            _buildCategoryDropdown(),
            const SizedBox(height: 12),
            _buildChecklistToggle(),
            if (isChecklist) _buildChecklistItems(),
            const SizedBox(height: 12),
            _buildPhotoSection(),
            const SizedBox(height: 18),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
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
          child: const Icon(Icons.note_add_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Новая заметка',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                ),
              ),
              Text(
                'Запишите свои мысли',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _pasteFromClipboard,
          icon: Icon(Icons.content_paste_rounded, color: Colors.purple.withOpacity(0.6), size: 20),
          tooltip: 'Вставить из буфера',
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: titleController,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: 'Заголовок',
        labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
        ),
        prefixIcon: Icon(Icons.title_rounded, color: Colors.purple.withOpacity(0.5), size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildContentField() {
    return TextField(
      controller: contentController,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Содержание',
        labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
        ),
        prefixIcon: Icon(Icons.article_rounded, color: Colors.purple.withOpacity(0.5), size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Цвет заметки',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: NotesConstants.colorPalette.map((noteColor) {
            final isSelected = selectedColor == NotesConstants.toHex(noteColor.color);
            return GestureDetector(
              onTap: () => setState(() => selectedColor = NotesConstants.toHex(noteColor.color)),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: noteColor.color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.purple : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 6)
                  ] : null,
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, color: noteColor.textColor, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Теги',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: tagController,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Добавить тег...',
                  hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.grey.shade400, fontSize: 13),
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addTag(tagController.text),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_rounded, color: Colors.purple, size: 20),
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: tags.map((tag) {
              return Chip(
                label: Text('#$tag', style: const TextStyle(fontSize: 11)),
                deleteIcon: Icon(Icons.close_rounded, size: 14),
                onDeleted: () => setState(() => tags.remove(tag)),
                backgroundColor: Colors.purple.withOpacity(0.1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: 'Личное',
      dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Категория',
        labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
        ),
        prefixIcon: Icon(Icons.category_rounded, color: Colors.purple.withOpacity(0.5), size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: NotesConstants.categories.map((cat) {
        return DropdownMenuItem(value: cat, child: Text(cat));
      }).toList(),
      onChanged: (value) {
        if (value != null && !tags.contains(value.toLowerCase())) {
          setState(() => tags.add(value.toLowerCase()));
        }
      },
    );
  }

  Widget _buildChecklistToggle() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Чек-лист',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        isChecklist ? 'Добавьте пункты списка' : 'Обычная заметка',
        style: TextStyle(
          fontSize: 11,
          color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
        ),
      ),
      value: isChecklist,
      activeColor: const Color(0xFF7C4DFF),
      onChanged: (value) => setState(() => isChecklist = value),
    );
  }

  Widget _buildChecklistItems() {
    return Column(
      children: [
        ...checklistItems.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.isChecked ? Colors.green.withOpacity(0.3) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      item.isChecked = !item.isChecked;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.isChecked
                          ? Colors.green
                          : (widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                      border: Border.all(
                        color: item.isChecked
                            ? Colors.green
                            : (widget.isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
                        width: 1,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: item.isChecked
                          ? Icon(Icons.check_rounded, key: const ValueKey('checked'), color: Colors.white, size: 18)
                          : const SizedBox.shrink(key: ValueKey('unchecked')),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: item.controller,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      decoration: item.isChecked ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.green,
                      decorationThickness: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Пункт ${i + 1}',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade300),
                  onPressed: () => setState(() => checklistItems.removeAt(i)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              checklistItems.add(ChecklistItem());
            });
          },
          icon: Icon(Icons.add_rounded, size: 16, color: Colors.purple),
          label: Text('Добавить пункт', style: TextStyle(color: Colors.purple, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Фото (до $maxImages)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + (images.length < maxImages ? 1 : 0),
            itemBuilder: (ctx, index) {
              if (index == images.length) {
                return GestureDetector(
                  onTap: _addImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
                      size: 32,
                    ),
                  ),
                );
              }
              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: _getImageProvider(images[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => images.removeAt(index)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    } else {
      return FileImage(File(path));
    }
  }

  Future<void> _addImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          if (images.length < maxImages) {
            images.add(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выборе фото: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _saveNote,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Создать',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.isDark ? Colors.white70 : Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(
                color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            child: const Text('Отмена'),
          ),
        ),
      ],
    );
  }

  void _addTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
      setState(() {
        tags.add(trimmed);
        tagController.clear();
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      if (titleController.text.isEmpty) {
        final lines = data.text!.split('\n');
        titleController.text = lines.first;
        contentController.text = lines.length > 1 ? lines.sublist(1).join('\n') : '';
      } else {
        contentController.text += '\n${data.text}';
      }
      setState(() {});
    }
  }

  void _saveNote() {
    String finalContent = contentController.text;

    if (isChecklist && checklistItems.isNotEmpty) {
      final checklistText = checklistItems
          .map((item) => '${item.isChecked ? '✅' : '☐'} ${item.controller.text}')
          .join('\n');
      if (finalContent.isNotEmpty) {
        finalContent += '\n\n--- Чек-лист ---\n$checklistText';
      } else {
        finalContent = checklistText;
      }
    }

    if (titleController.text.isNotEmpty || finalContent.isNotEmpty) {
      final title = titleController.text.isNotEmpty
          ? titleController.text
          : finalContent.substring(0, finalContent.length.clamp(0, 30));

      widget.provider.addNote(
        title,
        finalContent,
        tags: tags,
        color: selectedColor,
        images: images,
      );

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Заметка "$title" создана'),
          backgroundColor: Colors.purple,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ============================================================
// ДИАЛОГ РЕДАКТИРОВАНИЯ ЗАМЕТКИ (ИСПРАВЛЕНА ПРОБЛЕМА С ЧЕК-ЛИСТОМ)
// ============================================================

class NotesEditDialog extends StatefulWidget {
  final LifeNote note;
  final bool isDark;
  final LifeProvider provider;

  const NotesEditDialog({
    super.key,
    required this.note,
    required this.isDark,
    required this.provider,
  });

  @override
  State<NotesEditDialog> createState() => _NotesEditDialogState();
}

class _NotesEditDialogState extends State<NotesEditDialog> {
  late TextEditingController titleController;
  late TextEditingController contentController;
  late String selectedColor;
  late List<String> tags;
  late bool isFavorite;
  late bool isChecklist;
  late List<ChecklistItem> checklistItems;
  late List<String> images;
  final int maxImages = 5;
  Timer? _autoSaveTimer;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note.title);
    contentController = TextEditingController(text: widget.note.content);
    selectedColor = widget.note.color;
    tags = List.from(widget.note.tags);
    isFavorite = widget.note.isFavorite;
    images = List.from(widget.note.images);

    // Парсим чек-лист и УДАЛЯЕМ его из контента, чтобы избежать дублирования
    isChecklist = widget.note.content.contains('✅') || widget.note.content.contains('☐');
    checklistItems = [];
    if (isChecklist) {
      final lines = widget.note.content.split('\n');
      bool inChecklist = false;
      final List<String> contentLines = [];
      for (final line in lines) {
        if (line.contains('--- Чек-лист ---')) {
          inChecklist = true;
          continue;
        }
        if (inChecklist) {
          // Строки чек-листа: извлекаем пункты
          if (line.contains('✅') || line.contains('☐')) {
            final isChecked = line.contains('✅');
            final text = line.replaceAll('✅', '').replaceAll('☐', '').trim();
            if (text.isNotEmpty) {
              final item = ChecklistItem();
              item.controller.text = text;
              item.isChecked = isChecked;
              checklistItems.add(item);
            }
          }
          // Не добавляем строки чек-листа в contentLines
        } else {
          // Обычный текст
          if (line.isNotEmpty) {
            contentLines.add(line);
          }
        }
      }
      // Устанавливаем contentController.text как обычный текст без чек-листа
      contentController.text = contentLines.join('\n');
    }

    titleController.addListener(_onContentChanged);
    contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!_hasChanges) return;
    setState(() => _isSaving = true);

    String finalContent = contentController.text;
    if (isChecklist && checklistItems.isNotEmpty) {
      final checklistText = checklistItems
          .map((item) => '${item.isChecked ? '✅' : '☐'} ${item.controller.text}')
          .join('\n');
      if (finalContent.isNotEmpty) {
        finalContent += '\n\n--- Чек-лист ---\n$checklistText';
      } else {
        finalContent = checklistText;
      }
    }

    await widget.provider.updateNote(LifeNote(
      id: widget.note.id,
      title: titleController.text,
      content: finalContent,
      tags: tags,
      color: selectedColor,
      isFavorite: isFavorite,
      images: images,
      createdAt: widget.note.createdAt,
    ));

    if (mounted) {
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteColor = NotesConstants.fromHex(selectedColor);
    final textColor = NotesConstants.getTextColorForBackground(noteColor);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                if (_isSaving)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
                      const SizedBox(width: 4),
                      Text('Сохранение...', style: TextStyle(fontSize: 10, color: Colors.green)),
                    ],
                  )
                else if (!_hasChanges)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 12, color: Colors.green.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text('Сохранено', style: TextStyle(fontSize: 10, color: Colors.green.withOpacity(0.6))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: titleController,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Заголовок',
                hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.grey.shade400),
                filled: true,
                fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: contentController,
              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Содержание...',
                hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.grey.shade400),
                filled: true,
                fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),

            // Превью
            Text('Предпросмотр:', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: noteColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: noteColor == Colors.white ? Colors.grey.shade300 : Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titleController.text.isNotEmpty)
                    Text(titleController.text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textColor)),
                  if (contentController.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(contentController.text, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  if (titleController.text.isEmpty && contentController.text.isEmpty)
                    Text('Предпросмотр заметки', style: TextStyle(color: textColor.withOpacity(0.3), fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Цвета
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: NotesConstants.colorPalette.map((noteColor) {
                final isSelected = selectedColor == NotesConstants.toHex(noteColor.color);
                return GestureDetector(
                  onTap: () {
                    setState(() => selectedColor = NotesConstants.toHex(noteColor.color));
                    _onContentChanged();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: noteColor.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.purple : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected ? Icon(Icons.check_rounded, color: noteColor.textColor, size: 14) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Чек-лист
            _buildChecklistToggle(),
            if (isChecklist) _buildChecklistItems(),

            const SizedBox(height: 12),

            // Фото
            _buildPhotoSection(),

            const SizedBox(height: 12),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('В избранном', style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.white : Colors.black87)),
              value: isFavorite,
              activeColor: Colors.amber,
              onChanged: (v) {
                setState(() {
                  isFavorite = v;
                  _onContentChanged();
                });
              },
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _autoSave();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Готово',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _autoSave();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'Закрыть',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistToggle() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Чек-лист',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        isChecklist ? 'Редактируйте пункты списка' : 'Добавить чек-лист',
        style: TextStyle(
          fontSize: 11,
          color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
        ),
      ),
      value: isChecklist,
      activeColor: const Color(0xFF7C4DFF),
      onChanged: (value) {
        setState(() {
          isChecklist = value;
          _onContentChanged();
        });
      },
    );
  }

  // ============================================================
// УЛУЧШЕННЫЙ ЧЕК-ЛИСТ (ИСПРАВЛЕННЫЙ)
// ============================================================

  Widget _buildChecklistItems() {
    if (checklistItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: GestureDetector(
          onTap: () {
            setState(() {
              checklistItems.add(ChecklistItem());
              _onContentChanged();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 18, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Добавить пункт',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Заголовок чек-листа
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          margin: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 16,
                color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                'Чек-лист (${checklistItems.where((i) => i.isChecked).length}/${checklistItems.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        ...checklistItems.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: item.isChecked
                  ? (widget.isDark ? Colors.green.withOpacity(0.06) : Colors.green.withOpacity(0.04))
                  : (widget.isDark ? Colors.white.withOpacity(0.02) : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: item.isChecked
                    ? Colors.green.withOpacity(0.2)
                    : (widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Круглая кнопка с галочкой
                GestureDetector(
                  onTap: () {
                    setState(() {
                      item.isChecked = !item.isChecked;
                      _onContentChanged();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(left: 8, top: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.isChecked
                          ? Colors.green
                          : (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                      border: Border.all(
                        color: item.isChecked
                            ? Colors.green
                            : (widget.isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade400),
                        width: 2,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: item.isChecked
                          ? Icon(
                        Icons.check_rounded,
                        key: const ValueKey('checked'),
                        color: Colors.white,
                        size: 16,
                      )
                          : const SizedBox.shrink(key: ValueKey('unchecked')),
                    ),
                  ),
                ),
                // Текст с переносом
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: TextField(
                      controller: item.controller,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                        height: 1.4,
                        decoration: item.isChecked ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.green,
                        decorationThickness: 2,
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Пункт ${i + 1}',
                        hintStyle: TextStyle(
                          color: widget.isDark ? Colors.white24 : Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.only(top: 2, bottom: 2),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _onContentChanged();
                      },
                    ),
                  ),
                ),
                // Кнопка удаления
                GestureDetector(
                  onTap: () {
                    setState(() {
                      checklistItems.removeAt(i);
                      _onContentChanged();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(right: 4, top: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.red.shade300,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        // Кнопка добавления пункта
        GestureDetector(
          onTap: () {
            setState(() {
              checklistItems.add(ChecklistItem());
              _onContentChanged();
            });
          },
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16, color: Colors.purple),
                const SizedBox(width: 6),
                Text(
                  'Добавить пункт',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Фото (до $maxImages)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + (images.length < maxImages ? 1 : 0),
            itemBuilder: (ctx, index) {
              if (index == images.length) {
                return GestureDetector(
                  onTap: _addImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
                      size: 32,
                    ),
                  ),
                );
              }
              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: _getImageProvider(images[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => images.removeAt(index)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    } else {
      return FileImage(File(path));
    }
  }

  Future<void> _addImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          if (images.length < maxImages) {
            images.add(image.path);
            _onContentChanged();
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выборе фото: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ============================================================
// ВСПОМОГАТЕЛЬНЫЙ КЛАСС
// ============================================================

class ChecklistItem {
  final TextEditingController controller = TextEditingController();
  bool isChecked = false;
}