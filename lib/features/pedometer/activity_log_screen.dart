import 'package:flutter/material.dart';

class ActivityLogScreen extends StatefulWidget {
  final List<String> feed;
  const ActivityLogScreen({super.key, required this.feed});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  double _headerOpacity = 1.0;
  double _headerHeight = 80.0;
  double _lastScrollOffset = 0;
  double _scrollAccumulator = 0;

  static const double _maxHeaderHeight = 80.0;
  static const double _scrollThreshold = 50.0;

  // 🔥 Поддержка тёмной/светлой темы
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    final delta = currentOffset - _lastScrollOffset;

    _scrollAccumulator += delta;
    _scrollAccumulator = _scrollAccumulator.clamp(-_scrollThreshold, _scrollThreshold);

    double targetProgress;
    if (_scrollAccumulator >= _scrollThreshold) {
      targetProgress = 1.0;
    } else if (_scrollAccumulator <= -_scrollThreshold) {
      targetProgress = 0.0;
    } else if (_scrollAccumulator > 0) {
      targetProgress = _scrollAccumulator / _scrollThreshold;
    } else {
      targetProgress = 0.0;
    }

    setState(() {
      _headerOpacity = 1.0 - targetProgress;
      _headerHeight = _maxHeaderHeight - (targetProgress * _maxHeaderHeight);
    });

    _lastScrollOffset = currentOffset;

    if (_scrollAccumulator >= _scrollThreshold || _scrollAccumulator <= -_scrollThreshold) {
      _scrollAccumulator = _scrollAccumulator.clamp(-_scrollThreshold, _scrollThreshold);
    }
  }

  // 🔥 Хелперы для цветов темы
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF0A0A1A) : Colors.white;
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _surfaceColor2 => _isDarkMode ? const Color(0xFF151932) : Colors.grey.shade50;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600;
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;
  Color get _dividerColor => _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade300;
  Color get _emptyIconBgColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey.shade100;

  // СИСТЕМА ДОСТИЖЕНИЙ
  List<Achievement> get _achievements {
    final achievements = <Achievement>[];

    int totalSteps = 0;
    int bestDaySteps = 0;
    final daySteps = <String, int>{};

    for (final entry in widget.feed) {
      if (entry.contains('Шагов:')) {
        final stepsStr = entry.split('Шагов:').last.trim();
        final steps = int.tryParse(stepsStr) ?? 0;
        totalSteps += steps;

        final day = entry.length >= 5 ? entry.substring(0, 5) : '';
        if (day.isNotEmpty) {
          daySteps[day] = (daySteps[day] ?? 0) + steps;
          if (daySteps[day]! > bestDaySteps) {
            bestDaySteps = daySteps[day]!;
          }
        }
      }
    }

    final activeDays = daySteps.keys.length;

    if (totalSteps >= 1000) {
      achievements.add(Achievement(
        title: 'Тысячник',
        description: 'Первая тысяча шагов',
        icon: Icons.looks_one,
        color: const Color(0xFFCDDC39),
        unlocked: true,
        date: _findAchievementDateBySteps(1000, daySteps),
      ));
    }

    if (totalSteps >= 10000) {
      achievements.add(Achievement(
        title: 'Первые 10 000',
        description: 'Пройдите 10 000 шагов',
        icon: Icons.directions_walk,
        color: const Color(0xFF4CAF50),
        unlocked: true,
        date: _findAchievementDateBySteps(10000, daySteps),
      ));
    }

    if (totalSteps >= 50000) {
      achievements.add(Achievement(
        title: 'Марафонец',
        description: 'Пройдите 50 000 шагов',
        icon: Icons.run_circle,
        color: const Color(0xFF2196F3),
        unlocked: true,
        date: _findAchievementDateBySteps(50000, daySteps),
      ));
    }

    if (totalSteps >= 100000) {
      achievements.add(Achievement(
        title: 'Покоритель вершин',
        description: 'Пройдите 100 000 шагов',
        icon: Icons.terrain,
        color: const Color(0xFF9C27B0),
        unlocked: true,
        date: _findAchievementDateBySteps(100000, daySteps),
      ));
    }

    if (bestDaySteps >= 5000) {
      achievements.add(Achievement(
        title: 'Активный день',
        description: 'Пройдите 5 000 шагов за день',
        icon: Icons.sunny,
        color: Colors.orange,
        unlocked: true,
        date: _findBestDayDate(5000, daySteps),
      ));
    }

    if (bestDaySteps >= 10000) {
      achievements.add(Achievement(
        title: 'Дневной марафон',
        description: 'Пройдите 10 000 шагов за день',
        icon: Icons.emoji_events,
        color: Colors.deepOrange,
        unlocked: true,
        date: _findBestDayDate(10000, daySteps),
      ));
    }

    if (bestDaySteps >= 20000) {
      achievements.add(Achievement(
        title: 'Ультра-марафонец',
        description: 'Пройдите 20 000 шагов за день',
        icon: Icons.whatshot,
        color: const Color(0xFFFF1744),
        unlocked: true,
        date: _findBestDayDate(20000, daySteps),
      ));
    }

    if (activeDays >= 5) {
      achievements.add(Achievement(
        title: 'Неделя активности',
        description: 'Будьте активны 5 разных дней',
        icon: Icons.date_range,
        color: const Color(0xFF00BCD4),
        unlocked: true,
        date: 'За всё время',
      ));
    }

    if (activeDays >= 10) {
      achievements.add(Achievement(
        title: 'Двухнедельный марафон',
        description: 'Будьте активны 10 разных дней',
        icon: Icons.calendar_month,
        color: const Color(0xFF3F51B5),
        unlocked: true,
        date: 'За всё время',
      ));
    }

    if (activeDays >= 30) {
      achievements.add(Achievement(
        title: 'Месяц движения',
        description: 'Будьте активны 30 разных дней',
        icon: Icons.workspace_premium,
        color: Colors.amber,
        unlocked: true,
        date: 'За всё время',
      ));
    }

    return achievements;
  }

  // СИСТЕМА РЕКОРДОВ
  List<Record> get _records {
    final records = <Record>[];
    final daySteps = <String, int>{};

    for (final entry in widget.feed) {
      if (entry.contains('Шагов:')) {
        final day = entry.length >= 5 ? entry.substring(0, 5) : '';
        final stepsStr = entry.split('Шагов:').last.trim();
        final steps = int.tryParse(stepsStr) ?? 0;
        if (day.isNotEmpty) {
          daySteps[day] = (daySteps[day] ?? 0) + steps;
        }
      }
    }

    final sortedDays = daySteps.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (int i = 0; i < sortedDays.length && i < 5; i++) {
      final day = sortedDays[i];
      records.add(Record(
        title: 'Лучший день #${i + 1}',
        value: '${_formatNumber(day.value)} шагов',
        date: day.key,
        icon: Icons.calendar_today,
        color: i == 0
            ? Colors.amber
            : i == 1
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32),
        isTop: i == 0,
      ));
    }

    if (sortedDays.length >= 3) {
      records.add(Record(
        title: 'Серия активности',
        value: '${sortedDays.length} дней',
        date: 'С активностью',
        icon: Icons.trending_up,
        color: const Color(0xFF4CAF50),
        isTop: false,
      ));
    }

    int totalSteps = 0;
    for (final entry in widget.feed) {
      if (entry.contains('Шагов:')) {
        final stepsStr = entry.split('Шагов:').last.trim();
        totalSteps += int.tryParse(stepsStr) ?? 0;
      }
    }

    records.add(Record(
      title: 'Всего пройдено',
      value: '${_formatNumber(totalSteps)} шагов',
      date: 'За всё время',
      icon: Icons.stars,
      color: Colors.orange,
      isTop: false,
    ));

    return records;
  }

  String _findAchievementDateBySteps(int target, Map<String, int> daySteps) {
    int cumulative = 0;
    final sortedEntries = daySteps.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in sortedEntries) {
      cumulative += entry.value;
      if (cumulative >= target) {
        return entry.key;
      }
    }
    return 'За всё время';
  }

  String _findBestDayDate(int target, Map<String, int> daySteps) {
    for (final entry in daySteps.entries) {
      if (entry.value >= target) {
        return entry.key;
      }
    }
    return '';
  }

  int get _totalSteps {
    int total = 0;
    for (final entry in widget.feed) {
      if (entry.contains('Шагов:')) {
        final stepsStr = entry.split('Шагов:').last.trim();
        total += int.tryParse(stepsStr) ?? 0;
      }
    }
    return total;
  }

  int get _achievementsCount => _achievements.where((a) => a.unlocked).length;

  int get _activeDays {
    final days = <String>{};
    for (final entry in widget.feed) {
      if (entry.length >= 5 && entry.contains('.')) {
        days.add(entry.substring(0, 5));
      }
    }
    return days.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: _backgroundColor,
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _isDarkMode ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: _textColor, size: 22),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('Журнал',
                  style: TextStyle(color: _textColor, fontSize: 24, fontWeight: FontWeight.w700)),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(_headerHeight + 52),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      height: _headerHeight,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        opacity: _headerOpacity,
                        child: _headerHeight > 10
                            ? _buildStatsHeader()
                            : const SizedBox.shrink(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _surfaceColor.withOpacity(0.9),
                            _surfaceColor2.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _cardBorderColor),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.deepOrange],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorWeight: 0,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(icon: Icon(Icons.list_alt_rounded, size: 22)),
                          Tab(icon: Icon(Icons.emoji_events_rounded, size: 22)),
                          Tab(icon: Icon(Icons.stars_rounded, size: 22)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAllActivityTab(),
            _buildAchievementsTab(),
            _buildRecordsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMiniStat(Icons.directions_walk_rounded, _formatNumber(_totalSteps), 'шагов', const Color(0xFF4CAF50)),
          Container(width: 1, height: 36, color: _dividerColor),
          _buildMiniStat(Icons.emoji_events_rounded, '$_achievementsCount', 'достижений', Colors.orange),
          Container(width: 1, height: 36, color: _dividerColor),
          _buildMiniStat(Icons.calendar_month_rounded, '$_activeDays', 'дней', const Color(0xFF4A90E2)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: _subTextColor, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  // ВКЛАДКА "ВСЕ"
  Widget _buildAllActivityTab() {
    final groupedByDay = _groupFeedByDay(widget.feed);
    final sortedDays = groupedByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    if (widget.feed.isEmpty) {
      return _buildEmptyState(
        'Нет записей',
        'Начните ходить, чтобы увидеть\nисторию активности',
        Icons.history_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: sortedDays.length,
      itemBuilder: (_, dayIndex) {
        final day = sortedDays[dayIndex];
        final entries = groupedByDay[day]!;
        return _buildDayGroup(day, entries);
      },
    );
  }

  // ВКЛАДКА "ДОСТИЖЕНИЯ"
  Widget _buildAchievementsTab() {
    final achievements = _achievements;
    final unlocked = achievements.where((a) => a.unlocked).toList();

    if (unlocked.isEmpty) {
      return _buildEmptyState(
        'Пока нет достижений',
        'Продолжайте ходить, чтобы\nполучать достижения!',
        Icons.emoji_events_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: unlocked.length,
      itemBuilder: (_, index) {
        final achievement = unlocked[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 400 + (index * 60)),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                achievement.color.withOpacity(_isDarkMode ? 0.12 : 0.06),
                _surfaceColor2.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: achievement.color.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: achievement.color.withOpacity(_isDarkMode ? 0.05 : 0.03),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      achievement.color.withOpacity(0.25),
                      achievement.color.withOpacity(0.08),
                    ],
                  ),
                  border: Border.all(color: achievement.color.withOpacity(0.35), width: 2),
                ),
                child: Icon(achievement.icon, color: achievement.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(achievement.title,
                        style: TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(achievement.description,
                        style: TextStyle(color: _subTextColor, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: achievement.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(achievement.date,
                          style: TextStyle(color: achievement.color.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 18),
              ),
            ],
          ),
        );
      },
    );
  }

  // ВКЛАДКА "РЕКОРДЫ"
  Widget _buildRecordsTab() {
    final records = _records;

    if (records.isEmpty) {
      return _buildEmptyState(
        'Рекордов пока нет',
        'Ваши лучшие результаты\nпоявятся здесь',
        Icons.stars_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: records.length,
      itemBuilder: (_, index) {
        final record = records[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 400 + (index * 60)),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: record.isTop
                  ? [Colors.amber.withOpacity(_isDarkMode ? 0.12 : 0.06), _surfaceColor2.withOpacity(0.6)]
                  : [record.color.withOpacity(_isDarkMode ? 0.06 : 0.03), _surfaceColor2.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: record.isTop ? Colors.amber.withOpacity(0.3) : record.color.withOpacity(0.15),
            ),
            boxShadow: record.isTop
                ? [BoxShadow(color: Colors.amber.withOpacity(_isDarkMode ? 0.12 : 0.06), blurRadius: 20, spreadRadius: 2)]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [record.color.withOpacity(0.25), record.color.withOpacity(0.08)],
                  ),
                  border: Border.all(color: record.color.withOpacity(0.35), width: 2),
                ),
                child: Icon(record.icon, color: record.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(record.title,
                            style: TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.w700)),
                        if (record.isTop) ...[
                          const SizedBox(width: 6),
                          const Text('👑', style: TextStyle(fontSize: 14)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(record.value,
                        style: TextStyle(color: record.color.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(record.date, style: TextStyle(color: _subTextColor, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [record.color.withOpacity(0.2), record.color.withOpacity(0.05)]),
                ),
                child: Center(
                  child: Text('#${index + 1}',
                      style: TextStyle(color: record.color, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ПУСТОЕ СОСТОЯНИЕ
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_emptyIconBgColor, _surfaceColor2]),
              border: Border.all(color: _cardBorderColor, width: 2),
            ),
            child: Icon(icon, size: 40, color: _subTextColor),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(color: _textColor, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: _subTextColor, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  // ГРУППИРОВКА ПО ДНЯМ
  Widget _buildDayGroup(String day, List<String> entries) {
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}';
    final isToday = day == todayStr;

    int daySteps = 0;
    for (final entry in entries) {
      if (entry.contains('Шагов:')) {
        final stepsStr = entry.split('Шагов:').last.trim();
        daySteps += int.tryParse(stepsStr) ?? 0;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isToday
                  ? [const Color(0xFF4CAF50).withOpacity(_isDarkMode ? 0.12 : 0.06), _surfaceColor2.withOpacity(0.4)]
                  : [_surfaceColor, _surfaceColor2],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isToday ? const Color(0xFF4CAF50).withOpacity(0.18) : _cardBorderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isToday
                        ? [const Color(0xFF4CAF50).withOpacity(0.25), const Color(0xFF4CAF50).withOpacity(0.08)]
                        : [_isDarkMode ? Colors.white.withOpacity(0.06) : Colors.grey.shade200, _isDarkMode ? Colors.white.withOpacity(0.02) : Colors.grey.shade100],
                  ),
                ),
                child: Icon(
                  isToday ? Icons.today_rounded : Icons.date_range_rounded,
                  color: isToday ? const Color(0xFF4CAF50) : (_isDarkMode ? Colors.grey : Colors.grey.shade500),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isToday ? 'Сегодня' : _formatFullDate(day),
                        style: TextStyle(
                          color: isToday ? const Color(0xFF4CAF50) : _textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 3),
                    Text('${entries.length} записей${daySteps > 0 ? ' • ${_formatNumber(daySteps)} шагов' : ''}',
                        style: TextStyle(color: _subTextColor, fontSize: 11)),
                  ],
                ),
              ),
              if (daySteps > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF4CAF50).withOpacity(0.2), const Color(0xFF4CAF50).withOpacity(0.06)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.25)),
                  ),
                  child: Text(_formatNumber(daySteps),
                      style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 14, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        ...entries.map((entry) {
          final time = entry.length >= 11 ? entry.substring(6, 11) : '';
          final text = entry.length > 17 ? entry.substring(17) : entry;

          Color accentColor;
          IconData icon;

          if (entry.contains('Начало')) {
            accentColor = const Color(0xFF4CAF50);
            icon = Icons.play_circle_filled;
          } else if (entry.contains('Конец')) {
            accentColor = Colors.red;
            icon = Icons.stop_circle;
          } else if (entry.contains('Достигли') || entry.contains('рекорд')) {
            accentColor = Colors.orange;
            icon = Icons.emoji_events;
          } else {
            accentColor = const Color(0xFF4A90E2);
            icon = Icons.circle;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _surfaceColor.withOpacity(0.6),
                  _surfaceColor2.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withOpacity(0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(time,
                          style: TextStyle(
                            color: accentColor.withOpacity(0.85),
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withOpacity(0.12),
                      ),
                      child: Icon(icon, color: accentColor, size: 14),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text,
                      style: TextStyle(
                        color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.4,
                      )),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  Map<String, List<String>> _groupFeedByDay(List<String> feed) {
    final Map<String, List<String>> grouped = {};
    for (final entry in feed) {
      String dayKey = 'Ранее';
      if (entry.length >= 5 && entry.contains('.')) {
        dayKey = entry.substring(0, 5);
      }
      grouped.putIfAbsent(dayKey, () => []).add(entry);
    }
    return grouped;
  }

  String _formatFullDate(String dayMonth) {
    final parts = dayMonth.split('.');
    if (parts.length != 2) return dayMonth;
    final day = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;
    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    if (month > 0 && month < 13) return '$day ${months[month]}';
    return dayMonth;
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }
}

// МОДЕЛИ ДАННЫХ
class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
  final String date;

  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
    required this.date,
  });
}

class Record {
  final String title;
  final String value;
  final String date;
  final IconData icon;
  final Color color;
  final bool isTop;

  Record({
    required this.title,
    required this.value,
    required this.date,
    required this.icon,
    required this.color,
    required this.isTop,
  });
}