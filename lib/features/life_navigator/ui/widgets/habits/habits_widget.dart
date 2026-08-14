// features/life_navigator/ui/widgets/habits_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../../../../services/notification_service.dart';
import '../base_life_widget.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';

class HabitsWidget extends BaseLifeWidget {
  const HabitsWidget({super.key, required super.isDark, super.isCompact = true});
  @override
  State<HabitsWidget> createState() => _HabitsWidgetState();
}

class _HabitsWidgetState extends State<HabitsWidget>
    with LifeWidgetMixin<HabitsWidget> {
  String? _animatingHabitId;
  bool _showConfetti = false;
  bool _isExpanded = false;
  String _filterType = 'all';
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isFilterOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getAchievements(LifeHabit habit) {
    final a = <Map<String, dynamic>>[];
    final s = habit.currentStreak;
    if (s >= 3) a.add({'icon': '🌟', 'title': 'Первые шаги', 'desc': 'Стрик 3 дня', 'unlocked': true, 'color': Colors.blue});
    if (s >= 7) a.add({'icon': '🔥', 'title': 'Недельный герой', 'desc': 'Стрик 7 дней', 'unlocked': true, 'color': Colors.orange});
    if (s >= 14) a.add({'icon': '⚡', 'title': 'Дисциплина', 'desc': 'Стрик 14 дней', 'unlocked': true, 'color': Colors.purple});
    if (s >= 30) a.add({'icon': '🏆', 'title': 'Месячный марафон', 'desc': 'Стрик 30 дней', 'unlocked': true, 'color': Colors.amber});
    if (s >= 60) a.add({'icon': '💎', 'title': 'Железная воля', 'desc': 'Стрик 60 дней', 'unlocked': true, 'color': Colors.teal});
    if (s >= 100) a.add({'icon': '👑', 'title': 'Легенда', 'desc': 'Стрик 100 дней', 'unlocked': true, 'color': Colors.red});
    return a;
  }

  String getStreakPrediction(LifeHabit h) {
    final s = h.currentStreak;
    if (s == 0) return 'Начните сегодня! 🚀';
    if (s < 3) return 'До первого достижения: ${3 - s} дн.';
    if (s < 7) return 'До недельного стрика: ${7 - s} дн.';
    if (s < 14) return 'До 2 недель: ${14 - s} дн.';
    if (s < 30) return 'До месяца: ${30 - s} дн.';
    if (s < 60) return 'До 2 месяцев: ${60 - s} дн.';
    if (s < 100) return 'До 100 дней: ${100 - s} дн.';
    return 'Вы легенда! 👑';
  }

  List<Map<String, dynamic>> getMonthlyData(LifeHabit habit) {
    final d = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    for (int i = 0; i < 30; i++) {
      final date = start.add(Duration(days: i));
      if (date.month != now.month) break;
      final ds = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      d.add({'day': date.day, 'date': ds, 'done': habit.wasCompletedOn(date), 'isToday': date.day == now.day});
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final habits = provider.habits;

    List<LifeHabit> filtered = habits;
    if (_filterType == 'active') filtered = habits.where((h) => !h.isCompletedToday()).toList();
    if (_filterType == 'completed') filtered = habits.where((h) => h.isCompletedToday()).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((h) => h.title.toLowerCase().contains(q) || h.description.toLowerCase().contains(q) || h.icon.contains(q)).toList();
    }

    final totalHabits = habits.length;
    final completedToday = habits.where((h) => h.isCompletedToday()).length;
    final maxDisplay = widget.isCompact ? 5 : habits.length;
    final displayed = _isExpanded ? filtered : filtered.take(maxDisplay).toList();

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
            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.06),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(provider, totalHabits, completedToday),
            if (_isSearching) ...[const SizedBox(height: 12), _buildSearchBar()],
            if (_isFilterOpen) ...[const SizedBox(height: 12), _buildFilterPanel()],
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              _buildEmptyState()
            else
              ...displayed.map((h) {
                final c = Color(int.parse('0xFF${h.color.replaceFirst('#', '')}'));
                return _buildHabitCard(
                  habit: h,
                  habitColor: c,
                  isAnimating: _animatingHabitId == h.id,
                  isCompleted: h.isCompletedToday(),
                  canComplete: h.canCompleteToday(),
                  hasReminder: provider.hasActiveReminder(h.id),
                  provider: provider,
                );
              }),
            if (filtered.length > maxDisplay && !_isExpanded) _buildExpandButton(filtered.length - maxDisplay),
            if (_isExpanded && filtered.length > maxDisplay) _buildCollapseButton(),
            if (widget.isCompact) ...[const SizedBox(height: 10), _buildCompactHint()],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(LifeProvider provider, int total, int done) {
    final rate = total > 0 ? (done / total * 100).round() : 0;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Icon(Icons.fitness_center_rounded, color: Colors.white, size: widget.isCompact ? 22 : 26),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Привычки', style: TextStyle(fontSize: widget.isCompact ? 19 : 23, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : const Color(0xFF1A1D24), letterSpacing: -0.3)),
          Row(children: [
            Text('$total привычек', style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade500, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.08)]), borderRadius: BorderRadius.circular(8)),
              child: Text('$rate%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green.shade600)),
            ),
          ]),
        ]),
      ),
      _buildHeaderIcon(Icons.search_rounded, _isSearching, () { setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchController.clear(); _searchQuery = ''; } _isFilterOpen = false; }); }),
      const SizedBox(width: 4),
      _buildHeaderIcon(Icons.filter_list_rounded, _isFilterOpen, () => setState(() { _isFilterOpen = !_isFilterOpen; _isSearching = false; }), badge: _filterType != 'all'),
      const SizedBox(width: 4),
      _buildHeaderIcon(Icons.add_rounded, false, () => _showAddHabitDialog(context, widget.isDark, provider), isAdd: true),
    ]);
  }

  Widget _buildHeaderIcon(IconData icon, bool active, VoidCallback onTap, {bool badge = false, bool isAdd = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: isAdd ? const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: isAdd ? null : active ? const Color(0xFF00C853).withOpacity(0.12) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: active && !isAdd ? Border.all(color: const Color(0xFF00C853).withOpacity(0.25)) : null,
          boxShadow: isAdd ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Stack(children: [
          Icon(icon, size: 20, color: isAdd ? Colors.white : active ? const Color(0xFF00C853) : (widget.isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade600)),
          if (badge) Positioned(top: 0, right: 0, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF00C853), shape: BoxShape.circle))),
        ]),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200)),
      child: TextField(
        controller: _searchController, autofocus: true,
        style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Поиск привычек...', hintStyle: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400),
          suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.close_rounded, size: 18, color: widget.isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)),
      child: Row(children: [
        _buildFilterChip('Все', 'all', Colors.grey),
        const SizedBox(width: 6),
        _buildFilterChip('Активные', 'active', Colors.blue),
        const SizedBox(width: 6),
        _buildFilterChip('Готово', 'completed', Colors.green),
      ]),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final sel = _filterType == value;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _filterType = value); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: sel ? LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]) : null,
          color: sel ? null : (widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? color : Colors.transparent, width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? color : (widget.isDark ? Colors.white70 : Colors.grey.shade600))),
      ),
    );
  }

  Widget _buildHabitCard({
    required LifeHabit habit, required Color habitColor, required bool isAnimating,
    required bool isCompleted, required bool canComplete, required bool hasReminder, required LifeProvider provider,
  }) {
    final achievements = getAchievements(habit);
    final unlocked = achievements.where((a) => a['unlocked'] == true).toList();

    return GestureDetector(
      onTap: () => _showHabitDetails(context, habit, provider),
      onLongPress: () => _showHabitContextMenu(context, habit, provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCompleted
                ? [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.03)]
                : [habitColor.withOpacity(0.1), habitColor.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isCompleted ? Colors.green.withOpacity(0.2) : habitColor.withOpacity(0.12), width: 1.5),
          boxShadow: [BoxShadow(color: (isCompleted ? Colors.green : habitColor).withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isCompleted ? [Colors.green, Colors.green.shade700] : [habitColor, habitColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: (isCompleted ? Colors.green : habitColor).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: isAnimating
                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : Center(child: Text(habit.icon, style: const TextStyle(fontSize: 24), key: ValueKey(habit.icon))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(habit.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: widget.isCompact ? 14 : 16, color: widget.isDark ? Colors.white : Colors.black87, decoration: isCompleted ? TextDecoration.lineThrough : null, decorationColor: Colors.green.withOpacity(0.5)), overflow: TextOverflow.ellipsis)),
                if (hasReminder) Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.notifications_active_rounded, size: 16, color: Colors.purple.withOpacity(0.7))),
                if (unlocked.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), margin: const EdgeInsets.only(left: 4), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('🏆 ${unlocked.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber.shade700))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: (habit.currentStreak / 30).clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 600),
                        builder: (_, v, __) => Container(
                          width: v * double.infinity,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: isCompleted ? [Colors.green.shade300, Colors.green] : [habitColor.withOpacity(0.5), habitColor])),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${habit.currentStreak}д', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
                if (habit.targetCount > 1) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isCompleted ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text('${habit.completionsToday}/${habit.targetCount}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isCompleted ? Colors.green : Colors.orange))),
                ],
              ]),
              const SizedBox(height: 6),
              _buildWeekProgressDots(habit, isCompleted),
              const SizedBox(height: 8),
              _buildActionButton(habit, isCompleted, canComplete, isAnimating, provider, habitColor),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildActionButton(LifeHabit habit, bool isCompleted, bool canComplete, bool isAnimating, LifeProvider provider, Color habitColor) {
    return GestureDetector(
      onTap: () async {
        if (isCompleted) {
          HapticFeedback.mediumImpact();
          await provider.uncompleteHabit(habit.id);
        } else if (canComplete) {
          setState(() => _animatingHabitId = habit.id);
          HapticFeedback.lightImpact();
          await provider.completeHabit(habit.id);
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) setState(() => _animatingHabitId = null);
        } else {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(habit.frequency == 'weekly' ? '⏳ Только в определённые дни' : '✅ Цель достигнута!'), duration: const Duration(seconds: 2), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isCompleted
              ? LinearGradient(colors: [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)])
              : canComplete
              ? LinearGradient(colors: isAnimating ? [Colors.green, Colors.green.shade700] : [habitColor, habitColor.withOpacity(0.8)])
              : null,
          color: (!isCompleted && !canComplete) ? (widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCompleted ? Colors.green.withOpacity(0.2) : canComplete ? Colors.transparent : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
            width: 1,
          ),
          boxShadow: isAnimating ? [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 16, spreadRadius: 2)] : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isCompleted
              ? Row(mainAxisSize: MainAxisSize.min, key: const ValueKey('completed'), children: [Icon(Icons.check_circle_rounded, color: Colors.green, size: 18), const SizedBox(width: 6), Text('Готово', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w700))])
              : canComplete
              ? Row(mainAxisSize: MainAxisSize.min, key: ValueKey('do_$isAnimating'), children: [Icon(isAnimating ? Icons.check_circle_rounded : Icons.check_rounded, color: Colors.white, size: 18), const SizedBox(width: 6), Text(isAnimating ? 'Готово!' : 'Сделать', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))])
              : Icon(Icons.lock_rounded, key: const ValueKey('locked'), color: widget.isDark ? Colors.white38 : Colors.grey.shade400, size: 18),
        ),
      ),
    );
  }

  Widget _buildWeekProgressDots(LifeHabit habit, bool isCompletedToday) {
    final wp = habit.getWeekProgress();
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Row(children: [
      Text('Неделя: ', style: TextStyle(fontSize: widget.isCompact ? 9 : 11, color: widget.isDark ? Colors.white38 : Colors.grey.shade500)),
      ...wp.asMap().entries.map((e) {
        final done = e.value;
        final today = e.key == 6;
        return Container(
          margin: const EdgeInsets.only(right: 4),
          child: Column(children: [
            Container(
              width: widget.isCompact ? 14 : 18, height: widget.isCompact ? 14 : 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? (today ? Colors.green : Colors.green.withOpacity(0.6)) : (today && !isCompletedToday ? Colors.orange.withOpacity(0.3) : (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200)),
                border: today && !done ? Border.all(color: Colors.orange.withOpacity(0.5), width: 2) : null,
              ),
              child: done ? Icon(Icons.check_rounded, size: widget.isCompact ? 8 : 10, color: Colors.white) : null,
            ),
            const SizedBox(height: 2),
            Text(days[e.key], style: TextStyle(fontSize: widget.isCompact ? 6 : 8, color: widget.isDark ? Colors.white24 : Colors.grey.shade400)),
          ]),
        );
      }),
    ]);
  }

  Widget _buildEmptyState() {
    return Expanded(child: Center(child: Padding(
      padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 24 : 40),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.withOpacity(0.1), Colors.blue.withOpacity(0.1)]), shape: BoxShape.circle), child: const Text('🌟', style: TextStyle(fontSize: 48))),
        const SizedBox(height: 12),
        Text(_searchQuery.isNotEmpty ? 'Ничего не найдено' : 'Нет привычек', style: TextStyle(fontSize: widget.isCompact ? 16 : 20, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
        if (_searchQuery.isEmpty) ...[const SizedBox(height: 4), Text('Нажмите + чтобы создать', style: TextStyle(fontSize: widget.isCompact ? 12 : 14, color: widget.isDark ? Colors.white38 : Colors.grey.shade400))],
      ]),
    )));
  }

  Widget _buildExpandButton(int rem) {
    return GestureDetector(
      onTap: () { setState(() => _isExpanded = true); HapticFeedback.selectionClick(); },
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.withOpacity(widget.isDark ? 0.08 : 0.04), Colors.blue.withOpacity(widget.isDark ? 0.08 : 0.04)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(widget.isDark ? 0.1 : 0.04))),
        child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.expand_more_rounded, size: 18, color: Colors.green), const SizedBox(width: 6), Text('Показать ещё $rem', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green))])),
      ),
    );
  }

  Widget _buildCollapseButton() {
    return GestureDetector(
      onTap: () { setState(() => _isExpanded = false); HapticFeedback.selectionClick(); },
      child: Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)), child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.expand_less_rounded, size: 18, color: widget.isDark ? Colors.white54 : Colors.grey.shade600), const SizedBox(width: 6), Text('Свернуть', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : Colors.grey.shade600))]))),
    );
  }

  Widget _buildCompactHint() {
    return Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.withOpacity(0.1), Colors.blue.withOpacity(0.1)]), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.open_in_full_rounded, size: 14, color: Colors.green.withOpacity(0.5)), const SizedBox(width: 6), Text('Нажмите для полного просмотра', style: TextStyle(fontSize: 11, color: Colors.green.withOpacity(0.4), fontWeight: FontWeight.w500))])));
  }

  String _getReminderTooltip(LifeHabit habit, LifeProvider provider) {
    final r = provider.getRemindersForHabit(habit.id);
    if (r.isEmpty) return 'Нет напоминаний';
    final a = r.firstWhere((x) => x.isActive, orElse: () => r.first);
    return '🔔 ${a.formattedTime} (${a.daysDescription})';
  }

  // ==================== ДИАЛОГИ (без изменений) ====================
  void _showHabitDetails(BuildContext context, LifeHabit habit, LifeProvider provider) {
    final achievements = getAchievements(habit);
    final monthlyData = getMonthlyData(habit);
    final prediction = getStreakPrediction(habit);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(gradient: LinearGradient(colors: widget.isDark ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)] : [Colors.white, const Color(0xFFF8F9FA)], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(int.parse('0xFF${habit.color.replaceFirst('#', '')}')), Color(int.parse('0xFF${habit.color.replaceFirst('#', '')}')).withOpacity(0.7)]), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(habit.icon, style: const TextStyle(fontSize: 28)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(habit.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : const Color(0xFF1A1D24))), Text('Стрик: ${habit.currentStreak} дн. • ${habit.frequency}', style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white54 : Colors.grey.shade600))])),
              if (habit.isCompletedToday()) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.check_circle_rounded, color: Colors.green, size: 16), const SizedBox(width: 4), Text('Готово', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 12))])),
            ]),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber.withOpacity(0.1), Colors.amber.withOpacity(0.02)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.2))), child: Row(children: [const Text('🔮', style: TextStyle(fontSize: 20)), const SizedBox(width: 10), Expanded(child: Text(prediction, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white70 : Colors.grey.shade800)))])),
            const SizedBox(height: 16),
            Row(children: [_buildStatItem('🔥 Стрик', '${habit.currentStreak} дн.', Colors.orange), _buildStatItem('🎯 Сегодня', '${habit.completionsToday}/${habit.targetCount}', Colors.green), _buildStatItem('📅 Выполнено', '${habit.completedDates.length}', Colors.blue)]),
            if (achievements.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('🏆 Достижения', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: achievements.map((a) {
                final u = a['unlocked'] == true;
                return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: u ? (a['color'] as Color).withOpacity(0.15) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100), borderRadius: BorderRadius.circular(10), border: Border.all(color: u ? (a['color'] as Color).withOpacity(0.3) : Colors.transparent)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(a['icon'] as String, style: const TextStyle(fontSize: 14)), const SizedBox(width: 4), Text(a['title'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: u ? a['color'] as Color : (widget.isDark ? Colors.white38 : Colors.grey.shade400))), if (!u) ...[const SizedBox(width: 4), Icon(Icons.lock_rounded, size: 12, color: widget.isDark ? Colors.white24 : Colors.grey.shade400)]]));
              }).toList()),
            ],
            const SizedBox(height: 16),
            Text('📊 Прогресс за месяц', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)), child: Wrap(spacing: 4, runSpacing: 4, children: monthlyData.map((d) {
              final done = d['done'] == true;
              final today = d['isToday'] == true;
              return Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: done ? Colors.green : (today ? Colors.orange.withOpacity(0.3) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200)), border: today && !done ? Border.all(color: Colors.orange, width: 2) : null), child: Center(child: Text('${d['day']}', style: TextStyle(fontSize: 9, fontWeight: done ? FontWeight.w700 : FontWeight.w400, color: done ? Colors.white : (widget.isDark ? Colors.white38 : Colors.grey.shade500)))));
            }).toList())),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _showReminderDialog(context, habit, provider); }, icon: Icon(provider.hasActiveReminder(habit.id) ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, color: Colors.purple, size: 18), label: Text(provider.hasActiveReminder(habit.id) ? 'Напоминание' : 'Добавить напом.', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade700)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _showEditHabitDialog(context, habit, provider); }, icon: Icon(Icons.edit_rounded, color: Colors.blue, size: 18), label: Text('Редактировать', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade700)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)))),
            ]),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _confirmDeleteHabit(context, habit, provider); }, icon: Icon(Icons.delete_rounded, color: Colors.red, size: 18), label: Text('Удалить привычку', style: TextStyle(color: Colors.red)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.red.withOpacity(0.3))))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)), child: Text('Закрыть', style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 15)))),
          ]),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.1))), child: Column(children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)), Text(label, style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.white38 : Colors.grey.shade500))])));
  }

  void _showHabitContextMenu(BuildContext context, LifeHabit habit, LifeProvider provider) {
    HapticFeedback.mediumImpact();
    final hasReminder = provider.hasActiveReminder(habit.id);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [Text(habit.icon, style: const TextStyle(fontSize: 24)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(habit.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)), Text('Стрик: ${habit.currentStreak} дн. • ${habit.frequency}', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.grey.shade600))])]),
          const SizedBox(height: 20),
          _buildContextMenuItem(ctx, Icons.info_rounded, 'Подробности', Colors.blue, () { Navigator.pop(ctx); _showHabitDetails(context, habit, provider); }),
          _buildContextMenuItem(ctx, Icons.edit_rounded, 'Редактировать', Colors.blue, () { Navigator.pop(ctx); _showEditHabitDialog(context, habit, provider); }),
          _buildContextMenuItem(ctx, Icons.skip_next_rounded, 'Пропустить сегодня', Colors.orange, () { Navigator.pop(ctx); provider.skipHabit(habit.id); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⏭️ Стрик "${habit.title}" сброшен'), backgroundColor: Colors.orange, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating)); }),
          _buildContextMenuItem(ctx, hasReminder ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, hasReminder ? 'Изменить напоминание' : 'Добавить напоминание', Colors.purple, () { Navigator.pop(ctx); _showReminderDialog(context, habit, provider); }),
          _buildContextMenuItem(ctx, Icons.delete_rounded, 'Удалить', Colors.red, () { Navigator.pop(ctx); _confirmDeleteHabit(context, habit, provider); }, true),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Закрыть'))),
        ]),
      ),
    );
  }

  Widget _buildContextMenuItem(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap, [bool destructive = false]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: destructive ? Colors.red.withOpacity(0.2) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200))),
        child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 12), Expanded(child: Text(label, style: TextStyle(color: destructive ? Colors.red : (widget.isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w500, fontSize: 14))), Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20)]),
      ),
    );
  }

  void _confirmDeleteHabit(BuildContext context, LifeHabit habit, LifeProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1D24) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.warning_rounded, color: Colors.red, size: 24), const SizedBox(width: 8), const Text('Удалить привычку?')]),
        content: Text('Вы уверены, что хотите удалить "${habit.title}"?\n\n📊 Стрик: ${habit.currentStreak} дн.\n📅 Выполнено: ${habit.completedDates.length} раз\n🔔 Напоминания также будут удалены.', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600))),
          ElevatedButton(onPressed: () { provider.deleteHabit(habit.id); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🗑️ Привычка "${habit.title}" удалена'), backgroundColor: Colors.red, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating)); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Удалить')),
        ],
      ),
    );
  }

  void _showEditHabitDialog(BuildContext context, LifeHabit habit, LifeProvider provider) {
    final tc = TextEditingController(text: habit.title);
    final dc = TextEditingController(text: habit.description);
    String icon = habit.icon;
    String freq = habit.frequency;
    int target = habit.targetCount;
    final icons = ['⭐', '💪', '📚', '🏃', '🧘', '🎯', '💧', '🥗', '😴', '🧠', '🎨', '🌱', '🎵', '✍️', '🧹', '💊', '🚶', '🏋️'];
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: widget.isDark ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)] : [Colors.white, const Color(0xFFF8F9FA)], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue, Colors.blue.shade700]), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Редактировать', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : const Color(0xFF1A1D24))), Text('Измените данные', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white38 : Colors.grey.shade500))]))]),
            const SizedBox(height: 18),
            TextField(controller: tc, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Название', labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
            const SizedBox(height: 12),
            TextField(controller: dc, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87), maxLines: 2, decoration: InputDecoration(labelText: 'Описание', labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(value: icon, dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white, style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Иконка', labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), items: icons.map((i) => DropdownMenuItem(value: i, child: Text('$i  ', style: const TextStyle(fontSize: 24)))).toList(), onChanged: (v) { if (v != null) icon = v; })),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(value: freq, dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Частота', labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), items: const [DropdownMenuItem(value: 'daily', child: Text('📅 Ежедневно')), DropdownMenuItem(value: 'weekly', child: Text('📆 Еженедельно'))], onChanged: (v) { if (v != null) freq = v; })),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(value: target, dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Цель в день', labelStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), items: const [DropdownMenuItem(value: 1, child: Text('🎯 1 раз')), DropdownMenuItem(value: 2, child: Text('🎯 2 раза')), DropdownMenuItem(value: 3, child: Text('🎯 3 раза')), DropdownMenuItem(value: 4, child: Text('🎯 4 раза')), DropdownMenuItem(value: 5, child: Text('🎯 5 раз'))], onChanged: (v) { if (v != null) target = v; }),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: () async { if (tc.text.isNotEmpty) { await provider.updateHabit(habit.copyWith(title: tc.text, description: dc.text, icon: icon, frequency: freq, targetCount: target)); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✅ Привычка обновлена!'), backgroundColor: Colors.green, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating)); } }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(foregroundColor: widget.isDark ? Colors.white70 : Colors.grey.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)), child: const Text('Отмена'))),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showReminderDialog(BuildContext context, LifeHabit habit, LifeProvider provider) {
    final reminders = provider.getRemindersForHabit(habit.id);
    final active = reminders.isNotEmpty ? reminders.first : null;
    TimeOfDay time = active?.time ?? const TimeOfDay(hour: 8, minute: 0);
    bool isActive = active?.isActive ?? true;
    List<String> days = active?.daysOfWeek ?? [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1A1D24) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [Icon(Icons.notifications_active_rounded, color: Colors.purple, size: 24), const SizedBox(width: 10), Expanded(child: Text(active != null ? 'Напоминание' : 'Добавить', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)))]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Привычка: ${habit.icon} ${habit.title}', style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white70 : Colors.grey.shade600)),
              const SizedBox(height: 16),
              Text('Время', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async { final t = await showTimePicker(context: ctx, initialTime: time); if (t != null) setD(() => time = t); },
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300)), child: Row(children: [Icon(Icons.access_time_rounded, color: Colors.purple, size: 20), const SizedBox(width: 10), Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black87))])),
              ),
              if (habit.frequency == 'weekly') ...[
                const SizedBox(height: 16),
                Text('Дни', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
                const SizedBox(height: 6),
                Wrap(spacing: 4, runSpacing: 4, children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((d) {
                  final dm = {'Пн': 'Monday', 'Вт': 'Tuesday', 'Ср': 'Wednesday', 'Чт': 'Thursday', 'Пт': 'Friday', 'Сб': 'Saturday', 'Вс': 'Sunday'};
                  final de = dm[d]!;
                  final sel = days.contains(de);
                  return GestureDetector(
                    onTap: () { setD(() { if (sel) days.remove(de); else days.add(de); }); },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: sel ? Colors.purple.withOpacity(0.15) : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100), borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? Colors.purple.withOpacity(0.3) : (widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300))), child: Text(d, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.purple : (widget.isDark ? Colors.white54 : Colors.grey.shade600)))),
                  );
                }).toList()),
              ],
              const SizedBox(height: 12),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Активно', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: widget.isDark ? Colors.white : Colors.black87)), value: isActive, activeColor: Colors.purple, onChanged: (v) => setD(() => isActive = v)),
              if (active != null) ...[const SizedBox(height: 8), TextButton.icon(onPressed: () { provider.deleteHabitReminder(active.id); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('🗑️ Напоминание удалено'), backgroundColor: Colors.red, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating)); }, icon: Icon(Icons.delete_rounded, color: Colors.red, size: 18), label: Text('Удалить напоминание', style: TextStyle(color: Colors.red, fontSize: 13)))],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.grey.shade600))),
            ElevatedButton(
              onPressed: () async {
                if (active != null) {
                  await provider.updateHabitReminder(active.copyWith(time: time, daysOfWeek: habit.frequency == 'weekly' ? days : null, isActive: isActive));
                } else {
                  await provider.addHabitReminder(habitId: habit.id, time: time, daysOfWeek: habit.frequency == 'weekly' ? days : null);
                  if (!isActive) { final nr = provider.getRemindersForHabit(habit.id).last; await provider.toggleReminder(nr.id); }
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isActive ? '🔔 Напоминание сохранено' : '🔕 Напоминание выключено'), backgroundColor: Colors.purple, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHabitDialog(BuildContext context, bool isDark, LifeProvider provider) {
    final tc = TextEditingController();
    final dc = TextEditingController();
    String icon = '⭐';
    String freq = 'daily';
    TimeOfDay? remTime;
    int target = 1;
    final icons = ['⭐', '💪', '📚', '🏃', '🧘', '🎯', '💧', '🥗', '😴', '🧠', '🎨', '🌱', '🎵', '✍️', '🧹', '💊', '🚶', '🏋️'];
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)] : [Colors.white, const Color(0xFFF8F9FA)], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)]), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 22)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Новая привычка', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24))), Text('Создайте полезную привычку', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade500))]))]),
            const SizedBox(height: 18),
            TextField(controller: tc, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Название', labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
            const SizedBox(height: 12),
            TextField(controller: dc, style: TextStyle(color: isDark ? Colors.white : Colors.black87), maxLines: 2, decoration: InputDecoration(labelText: 'Описание', labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(value: icon, dropdownColor: isDark ? const Color(0xFF2A2D35) : Colors.white, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Иконка', labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), items: icons.map((i) => DropdownMenuItem(value: i, child: Text('$i  ', style: const TextStyle(fontSize: 24)))).toList(), onChanged: (v) { if (v != null) icon = v; })),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(value: freq, dropdownColor: isDark ? const Color(0xFF2A2D35) : Colors.white, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Частота', labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), items: const [DropdownMenuItem(value: 'daily', child: Text('📅 Ежедневно')), DropdownMenuItem(value: 'weekly', child: Text('📆 Еженедельно'))], onChanged: (v) { if (v != null) freq = v; })),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<int>(value: target, dropdownColor: isDark ? const Color(0xFF2A2D35) : Colors.white, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Цель', labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), items: const [DropdownMenuItem(value: 1, child: Text('🎯 1 раз')), DropdownMenuItem(value: 2, child: Text('🎯 2 раза')), DropdownMenuItem(value: 3, child: Text('🎯 3 раза')), DropdownMenuItem(value: 4, child: Text('🎯 4 раза')), DropdownMenuItem(value: 5, child: Text('🎯 5 раз'))], onChanged: (v) { if (v != null) target = v; })),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async { final t = await showTimePicker(context: context, initialTime: remTime ?? const TimeOfDay(hour: 8, minute: 0)); if (t != null) setState(() => remTime = t); },
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100, borderRadius: BorderRadius.circular(14), border: Border.all(color: remTime != null ? Colors.green.withOpacity(0.3) : Colors.transparent, width: 1.5)),
                      child: Row(children: [Icon(remTime != null ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, color: remTime != null ? Colors.green : Colors.grey, size: 18), const SizedBox(width: 8), Text(remTime != null ? '${remTime!.hour.toString().padLeft(2, '0')}:${remTime!.minute.toString().padLeft(2, '0')}' : 'Напомнить', style: TextStyle(fontSize: 13, color: remTime != null ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white54 : Colors.grey.shade600)))])),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: () async { if (tc.text.isNotEmpty) { final h = await provider.addHabit(title: tc.text, description: dc.text, icon: icon, frequency: freq, targetCount: target); if (remTime != null) await provider.addHabitReminder(habitId: h.id, time: remTime!); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Привычка "${tc.text}" создана!'), backgroundColor: Colors.green, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating)); } }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), child: const Text('Создать', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.white70 : Colors.grey.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)), child: const Text('Отмена'))),
            ]),
          ]),
        ),
      ),
    );
  }
}