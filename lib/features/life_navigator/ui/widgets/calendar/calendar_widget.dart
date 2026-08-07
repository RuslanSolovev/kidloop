// features/life_navigator/ui/widgets/calendar/calendar_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import '../base_life_widget.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'calendar_mini_grid.dart';
import 'calendar_event_item.dart';
import 'calendar_progress_bar.dart';
import 'calendar_weather.dart';
import 'calendar_add_dialog.dart';
import 'calendar_month_stats.dart';
import 'calendar_active_day.dart';
import 'calendar_backgrounds.dart';

class CalendarWidget extends BaseLifeWidget {
  const CalendarWidget({
    super.key,
    required super.isDark,
    super.isCompact = true,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

// ✅ ВАЖНО: ПОРЯДОК МАТЕРИНСКИХ КЛАССОВ
// Сначала State<CalendarWidget>, потом SingleTickerProviderStateMixin, потом LifeWidgetMixin
class _CalendarWidgetState extends State<CalendarWidget>
    with SingleTickerProviderStateMixin, LifeWidgetMixin<CalendarWidget> {

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late ConfettiController _confettiController;
  bool _showConfetti = false;

  String _viewMode = 'month';
  DateTime _selectedDate = DateTime.now();

  bool _isWeatherExpanded = true;
  bool _isProgressExpanded = true;
  bool _isStatsExpanded = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,  // ✅ Теперь this является TickerProvider
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAllTasksDone();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _checkAllTasksDone() {
    final provider = context.read<LifeProvider>();
    final todayTasks = provider.getTodayTasks();
    final doneTasks = todayTasks.where((t) => t.status == 'done').length;

    if (todayTasks.isNotEmpty && doneTasks == todayTasks.length) {
      setState(() => _showConfetti = true);
      _confettiController.play();
    }
  }

  void _changeViewMode(String mode) {
    setState(() => _viewMode = mode);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final now = DateTime.now();
    final events = provider.getEventsForDate(_selectedDate);
    final allEvents = provider.events;

    final backgroundGradient = CalendarBackgrounds.getBackgroundGradient(_selectedDate.month, isDark: widget.isDark);
    final borderColor = CalendarBackgrounds.getBorderColor(_selectedDate.month, isDark: widget.isDark);
    final textColor = CalendarBackgrounds.getTextColor(_selectedDate.month, isDark: widget.isDark);
    final seasonEmoji = CalendarBackgrounds.getSeasonEmoji(_selectedDate.month);
    final seasonName = CalendarBackgrounds.getSeasonName(_selectedDate.month);

    return GestureDetector(
      onTap: widget.isCompact ? openFullScreen : null,
      child: Stack(
        children: [
          if (_showConfetti)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.red, Colors.amber],
                numberOfParticles: 30,
                maxBlastForce: 8,
                minBlastForce: 3,
              ),
            ),

          Container(
            decoration: BoxDecoration(
              gradient: backgroundGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.all(widget.isCompact ? 14 : 20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(provider, now, seasonEmoji, seasonName, textColor),
                          const SizedBox(height: 10),
                          MiniCalendarGrid(
                            isDark: widget.isDark,
                            selectedDate: _selectedDate,
                            events: allEvents,
                            onDateSelected: (date) {
                              setState(() => _selectedDate = date);
                              HapticFeedback.lightImpact();
                            },
                            onViewModeChanged: _changeViewMode,
                            viewMode: _viewMode,
                          ),
                          const SizedBox(height: 10),
                          _buildCollapsibleSection(
                            title: 'Погода',
                            icon: Icons.wb_sunny_rounded,
                            isExpanded: _isWeatherExpanded,
                            onToggle: () => setState(() => _isWeatherExpanded = !_isWeatherExpanded),
                            child: CalendarWeather(isDark: widget.isDark),
                          ),
                          const SizedBox(height: 10),
                          _buildEventsSection(events, provider, textColor),
                          const SizedBox(height: 10),
                          _buildCollapsibleSection(
                            title: 'Прогресс дня',
                            icon: Icons.speed_rounded,
                            isExpanded: _isProgressExpanded,
                            onToggle: () => setState(() => _isProgressExpanded = !_isProgressExpanded),
                            child: CalendarProgressBar(
                              isDark: widget.isDark,
                              events: events,
                              date: _selectedDate,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildCollapsibleSection(
                            title: 'Аналитика',
                            icon: Icons.analytics_rounded,
                            isExpanded: _isStatsExpanded,
                            onToggle: () => setState(() => _isStatsExpanded = !_isStatsExpanded),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: CalendarMonthStats(
                                        isDark: widget.isDark,
                                        events: allEvents,
                                        month: _selectedDate.month,
                                        year: _selectedDate.year,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: CalendarActiveDay(
                                        isDark: widget.isDark,
                                        events: allEvents,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (widget.isCompact) ...[
                            _buildActionButtons(provider, textColor),
                            const SizedBox(height: 8),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.open_in_full_rounded, size: 14, color: textColor.withOpacity(0.5)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Нажмите для полного просмотра',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: textColor.withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (widget.isCompact)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: openFullScreen,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.open_in_full_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== ЗАГОЛОВОК ====================

  Widget _buildHeader(LifeProvider provider, DateTime now, String seasonEmoji, String seasonName, Color textColor) {
    final totalEvents = provider.events.length;
    final todayEvents = provider.getEventsForDate(now).length;

    return Row(
      children: [
        Text('$seasonEmoji ', style: const TextStyle(fontSize: 20)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${CalendarBackgrounds.getMonthName(now.month)} ${now.year}',
              style: TextStyle(fontWeight: FontWeight.w800, color: textColor, fontSize: widget.isCompact ? 17 : 20),
            ),
            Text(
              seasonName,
              style: TextStyle(fontSize: widget.isCompact ? 10 : 12, color: textColor.withOpacity(0.5), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const Spacer(),

        if (todayEvents > 0)
          GestureDetector(
            onTap: () {
              setState(() => _selectedDate = now);
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.today_rounded, size: widget.isCompact ? 14 : 16, color: textColor.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    'Сегодня $todayEvents',
                    style: TextStyle(fontSize: widget.isCompact ? 11 : 13, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(width: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: textColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Всего $totalEvents',
            style: TextStyle(fontSize: widget.isCompact ? 11 : 13, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.6)),
          ),
        ),

        if (_showConfetti)
          GestureDetector(
            onTap: () => _confettiController.play(),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('🎉', style: TextStyle(fontSize: 18)),
            ),
          ),
      ],
    );
  }

  // ==================== СВОРАЧИВАЕМАЯ СЕКЦИЯ ====================

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: widget.isCompact ? 14 : 16, color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: widget.isCompact ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right_rounded, size: widget.isCompact ? 16 : 18, color: widget.isDark ? Colors.white24 : Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: child,
          secondChild: const SizedBox.shrink(),
          crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  // ==================== СОБЫТИЯ НА ДАТУ ====================

  Widget _buildEventsSection(List<CalendarEvent> events, LifeProvider provider, Color textColor) {
    final dateStr = DateFormat('d MMMM', 'ru').format(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_rounded, size: widget.isCompact ? 16 : 18, color: widget.isDark ? Colors.white70 : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              'События на $dateStr',
              style: TextStyle(
                fontSize: widget.isCompact ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            if (events.isNotEmpty)
              Text(
                '${events.length} ${_plural(events.length, "событие", "события", "событий")}',
                style: TextStyle(fontSize: widget.isCompact ? 11 : 13, color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
              ),
          ],
        ),

        const SizedBox(height: 6),

        if (events.isEmpty)
          GestureDetector(
            onTap: () {
              _showAddEventDialog(context, widget.isDark, provider, _selectedDate);
            },
            child: Container(
              padding: EdgeInsets.all(widget.isCompact ? 16 : 24),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: widget.isCompact ? 32 : 40, color: textColor.withOpacity(0.3)),
                  const SizedBox(height: 6),
                  Text(
                    'Нет событий на $dateStr',
                    style: TextStyle(fontSize: widget.isCompact ? 13 : 15, color: textColor.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Нажмите, чтобы добавить',
                    style: TextStyle(fontSize: widget.isCompact ? 11 : 13, color: Colors.blue.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              ...events.take(widget.isCompact ? 5 : events.length).map((event) {
                return CalendarEventItem(
                  event: event,
                  isDark: widget.isDark,
                  onDelete: () => provider.deleteEvent(event.id),
                  onEdit: () {
                    _showAddEventDialog(context, widget.isDark, provider, _selectedDate, eventToEdit: event);
                  },
                  onTap: () {},
                );
              }),
              if (widget.isCompact && events.length > 5)
                GestureDetector(
                  onTap: () => _showAllEventsDialog(context, widget.isDark, provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Показать ещё ${events.length - 5} ${_plural(events.length - 5, "событие", "события", "событий")}',
                        style: TextStyle(fontSize: widget.isCompact ? 12 : 14, fontWeight: FontWeight.w600, color: Colors.blue),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // ==================== КНОПКИ ДЕЙСТВИЙ ====================

  Widget _buildActionButtons(LifeProvider provider, Color textColor) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _showAddEventDialog(context, widget.isDark, provider, _selectedDate);
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: () => _showAllEventsDialog(context, widget.isDark, provider),
            icon: Icon(Icons.list_alt_rounded, size: 16, color: textColor),
            label: Text('Все', style: TextStyle(fontSize: 12, color: textColor)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: textColor.withOpacity(0.3)),
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () {
              final modes = ['month', 'week', 'day'];
              final currentIndex = modes.indexOf(_viewMode);
              final nextIndex = (currentIndex + 1) % modes.length;
              _changeViewMode(modes[nextIndex]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _viewMode == 'month' ? Icons.calendar_month_rounded : _viewMode == 'week' ? Icons.view_week_rounded : Icons.today_rounded,
                    color: Colors.purple,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _viewMode == 'month' ? 'Месяц' : _viewMode == 'week' ? 'Неделя' : 'День',
                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== ДИАЛОГ ДОБАВЛЕНИЯ ====================

  void _showAddEventDialog(
      BuildContext context,
      bool isDark,
      LifeProvider provider,
      DateTime selectedDate, {
        CalendarEvent? eventToEdit,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CalendarAddDialog(
        isDark: isDark,
        provider: provider,
        initialDate: selectedDate,
        eventToEdit: eventToEdit,
      ),
    );
  }

  // ==================== ВСЕ СОБЫТИЯ ====================

  void _showAllEventsDialog(BuildContext context, bool isDark, LifeProvider provider) {
    final allEvents = provider.events;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Все события',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${allEvents.length} ${_plural(allEvents.length, "событие", "события", "событий")}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (allEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.event_busy_rounded, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('Нет событий', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500)),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allEvents.length,
                  itemBuilder: (ctx, index) {
                    final event = allEvents[index];
                    return CalendarEventItem(
                      event: event,
                      isDark: isDark,
                      onDelete: () {
                        provider.deleteEvent(event.id);
                        Navigator.pop(ctx);
                      },
                      onEdit: () {
                        Navigator.pop(ctx);
                        _showAddEventDialog(context, isDark, provider, event.date, eventToEdit: event);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))),
          ],
        ),
      ),
    );
  }

  // ==================== СКЛОНЕНИЕ ====================

  String _plural(int count, String one, String two, String five) {
    if (count % 10 == 1 && count % 100 != 11) return '$count $one';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return '$count $two';
    return '$count $five';
  }
}