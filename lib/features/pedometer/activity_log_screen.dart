import 'package:flutter/material.dart';

class ActivityLogScreen extends StatefulWidget {
  final List<String> feed;

  /// Акцентный цвет, пришедший из шагомера.
  final Color accentColor;

  const ActivityLogScreen({
    super.key,
    required this.feed,
    this.accentColor = const Color(0xFFFF7548),
  });

  @override
  State<ActivityLogScreen> createState() =>
      _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final ScrollController _scrollController =
  ScrollController();

  double _headerOpacity = 1.0;
  double _headerHeight = 78.0;
  double _lastScrollOffset = 0;
  double _scrollAccumulator = 0;

  static const double _maxHeaderHeight = 78.0;
  static const double _scrollThreshold = 42.0;

  // ---------------------------------------------------------------------------
  // THEME
  // ---------------------------------------------------------------------------

  bool get _isDarkMode =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _backgroundColor =>
      _isDarkMode
          ? const Color(0xFF080B10)
          : const Color(0xFFF5F6F8);

  Color get _surfaceColor =>
      _isDarkMode
          ? const Color(0xFF11161E)
          : Colors.white;

  Color get _surfaceColor2 =>
      _isDarkMode
          ? const Color(0xFF171D26)
          : const Color(0xFFF9FAFB);

  Color get _surfaceColor3 =>
      _isDarkMode
          ? const Color(0xFF1B222C)
          : const Color(0xFFF0F2F4);

  Color get _textColor =>
      _isDarkMode
          ? const Color(0xFFF5F7FA)
          : const Color(0xFF161A20);

  Color get _secondaryTextColor =>
      _isDarkMode
          ? const Color(0xFF98A1AE)
          : const Color(0xFF727B86);

  Color get _mutedTextColor =>
      _isDarkMode
          ? const Color(0xFF626C79)
          : const Color(0xFFA1A8B0);

  Color get _borderColor =>
      _isDarkMode
          ? Colors.white.withOpacity(0.055)
          : Colors.black.withOpacity(0.055);

  Color get _dividerColor =>
      _isDarkMode
          ? Colors.white.withOpacity(0.07)
          : Colors.black.withOpacity(0.07);

  Color get _accent => widget.accentColor;

  Color get _accentDark =>
      Color.lerp(
        _accent,
        Colors.black,
        0.08,
      ) ??
          _accent;

  Color get _green =>
      const Color(0xFF31C48D);

  Color get _blue =>
      const Color(0xFF4B8DFF);

  Color get _red =>
      const Color(0xFFF05B68);

  Color get _gold =>
      const Color(0xFFF4B740);

  Color get _purple =>
      const Color(0xFF8B5CF6);

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    _scrollController.addListener(
      _onScroll,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();

    _scrollController.removeListener(
      _onScroll,
    );

    _scrollController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SCROLL
  // ---------------------------------------------------------------------------

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final currentOffset =
        _scrollController.offset;

    final delta =
        currentOffset - _lastScrollOffset;

    _scrollAccumulator += delta;

    _scrollAccumulator =
        _scrollAccumulator.clamp(
          -_scrollThreshold,
          _scrollThreshold,
        );

    double targetProgress;

    if (_scrollAccumulator >=
        _scrollThreshold) {
      targetProgress = 1.0;
    } else if (_scrollAccumulator <=
        -_scrollThreshold) {
      targetProgress = 0.0;
    } else if (_scrollAccumulator > 0) {
      targetProgress =
          _scrollAccumulator /
              _scrollThreshold;
    } else {
      targetProgress = 0.0;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _headerOpacity =
          1.0 - targetProgress;

      _headerHeight =
          _maxHeaderHeight -
              (targetProgress *
                  _maxHeaderHeight);
    });

    _lastScrollOffset = currentOffset;
  }

  // ---------------------------------------------------------------------------
  // PARSED DATA
  // ---------------------------------------------------------------------------

  List<WalkingSession> get _sessions =>
      _parseSessions(widget.feed);

  List<WalkingSession> get _completedSessions =>
      _sessions
          .where(
            (session) =>
        session.end != null,
      )
          .toList();

  WalkingSession? get _activeSession {
    for (final session in _sessions) {
      if (session.end == null) {
        return session;
      }
    }

    return null;
  }

  int get _totalSteps {
    int total = 0;

    for (final session
    in _completedSessions) {
      total += session.steps;
    }

    return total;
  }

  int get _activeMinutes {
    int total = 0;

    for (final session
    in _completedSessions) {
      total += session.durationMinutes;
    }

    final active = _activeSession;

    if (active != null) {
      final start =
          active.start;

      final duration =
          DateTime.now()
              .difference(start)
              .inMinutes;

      total += duration;
    }

    return total;
  }

  int get _walkCount =>
      _completedSessions.length +
          (_activeSession != null ? 1 : 0);

  int get _completedWalkCount =>
      _completedSessions.length;

  int get _activeDays {
    final days =
    <String>{};

    for (final session
    in _completedSessions) {
      days.add(
        _dateKey(
          session.start,
        ),
      );
    }

    final active = _activeSession;

    if (active != null) {
      days.add(
        _dateKey(
          active.start,
        ),
      );
    }

    return days.length;
  }

  double get _averageWalkSteps {
    if (_completedSessions.isEmpty) {
      return 0;
    }

    return _totalSteps /
        _completedSessions.length;
  }

  int get _longestWalkMinutes {
    int result = 0;

    for (final session
    in _completedSessions) {
      if (session.durationMinutes >
          result) {
        result =
            session.durationMinutes;
      }
    }

    return result;
  }

  int get _bestWalkSteps {
    int result = 0;

    for (final session
    in _completedSessions) {
      if (session.steps > result) {
        result = session.steps;
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // SESSION PARSER
  // ---------------------------------------------------------------------------

  List<WalkingSession> _parseSessions(
      List<String> feed,
      ) {
    final result =
    <WalkingSession>[];

    DateTime? currentStart;

    for (final raw in feed.reversed) {
      final line =
      raw.trim();

      if (line.isEmpty) {
        continue;
      }

      if (_isStartEntry(line)) {
        final dateTime =
        _parseFeedDateTime(line);

        if (dateTime != null) {
          if (currentStart != null) {
            result.add(
              WalkingSession(
                start: currentStart,
              ),
            );
          }

          currentStart =
              dateTime;
        }

        continue;
      }

      if (_isEndEntry(line)) {
        final parsed =
        _parseCompletion(line);

        if (parsed != null) {
          final sessionStart =
              currentStart ??
                  parsed.end.subtract(
                    Duration(
                      minutes:
                      parsed.durationMinutes,
                    ),
                  );

          result.add(
            WalkingSession(
              start: sessionStart,
              end: parsed.end,
              durationMinutes:
              parsed.durationMinutes,
              steps: parsed.steps,
            ),
          );

          currentStart = null;
        }
      }
    }

    if (currentStart != null) {
      result.add(
        WalkingSession(
          start: currentStart,
        ),
      );
    }

    result.sort(
          (a, b) =>
          b.start.compareTo(a.start),
    );

    return result;
  }

  bool _isStartEntry(
      String entry,
      ) {
    return entry.contains(
      'Начало ходьбы',
    );
  }

  bool _isEndEntry(
      String entry,
      ) {
    return entry.contains(
      'Ходьба завершена',
    ) &&
        entry.contains(
          'Шагов:',
        );
  }

  DateTime? _parseFeedDateTime(
      String entry,
      ) {
    if (entry.length < 11) {
      return null;
    }

    final datePart =
    entry.substring(0, 5);

    final timePart =
    entry.substring(6, 11);

    final date =
    datePart.split('.');

    final time =
    timePart.split(':');

    if (date.length != 2 ||
        time.length != 2) {
      return null;
    }

    final day =
    int.tryParse(date[0]);

    final month =
    int.tryParse(date[1]);

    final hour =
    int.tryParse(time[0]);

    final minute =
    int.tryParse(time[1]);

    if (day == null ||
        month == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    final now =
    DateTime.now();

    int year =
        now.year;

    final candidate =
    DateTime(
      year,
      month,
      day,
      hour,
      minute,
    );

    if (candidate
        .isAfter(
      now.add(
        const Duration(
          minutes: 2,
        ),
      ),
    )) {
      year--;
    }

    return DateTime(
      year,
      month,
      day,
      hour,
      minute,
    );
  }

  _CompletionData? _parseCompletion(
      String entry,
      ) {
    final end =
    _parseFeedDateTime(entry);

    if (end == null) {
      return null;
    }

    final durationMatch =
    RegExp(
      r'•\s*(\d+)\s*мин',
    ).firstMatch(
      entry,
    );

    final stepsMatch =
    RegExp(
      r'Шагов:\s*(\d+)',
    ).firstMatch(
      entry,
    );

    final duration =
    durationMatch == null
        ? 0
        : int.tryParse(
      durationMatch.group(1) ??
          '',
    ) ??
        0;

    final steps =
    stepsMatch == null
        ? 0
        : int.tryParse(
      stepsMatch.group(1) ??
          '',
    ) ??
        0;

    return _CompletionData(
      end: end,
      durationMinutes:
      duration,
      steps: steps,
    );
  }

  // ---------------------------------------------------------------------------
  // ACHIEVEMENTS
  // ---------------------------------------------------------------------------

  List<LogAchievement>
  get _achievements {
    final achievements =
    <LogAchievement>[];

    final totalSteps =
        _totalSteps;

    final bestWalk =
        _bestWalkSteps;

    final completedCount =
        _completedWalkCount;

    final activeDays =
        _activeDays;

    final longest =
        _longestWalkMinutes;

    if (totalSteps >= 1000) {
      achievements.add(
        LogAchievement(
          title: 'Первая тысяча',
          description:
          'Пройдено 1 000 шагов',
          icon:
          Icons.looks_one_rounded,
          color:
          const Color(
            0xFFB7CC3A,
          ),
        ),
      );
    }

    if (totalSteps >= 10000) {
      achievements.add(
        LogAchievement(
          title: '10K',
          description:
          'Пройдено 10 000 шагов',
          icon:
          Icons.directions_walk_rounded,
          color:
          _green,
        ),
      );
    }

    if (totalSteps >= 50000) {
      achievements.add(
        LogAchievement(
          title: 'Марафонец',
          description:
          'Пройдено 50 000 шагов',
          icon:
          Icons.directions_run_rounded,
          color:
          _blue,
        ),
      );
    }

    if (totalSteps >= 100000) {
      achievements.add(
        LogAchievement(
          title: 'Покоритель',
          description:
          'Пройдено 100 000 шагов',
          icon:
          Icons.terrain_rounded,
          color:
          _purple,
        ),
      );
    }

    if (bestWalk >= 5000) {
      achievements.add(
        LogAchievement(
          title: 'Длинная прогулка',
          description:
          '5 000 шагов за одну прогулку',
          icon:
          Icons.wb_sunny_rounded,
          color:
          _gold,
        ),
      );
    }

    if (bestWalk >= 10000) {
      achievements.add(
        LogAchievement(
          title: 'Дневной марафон',
          description:
          '10 000 шагов за одну прогулку',
          icon:
          Icons.emoji_events_rounded,
          color:
          _accent,
        ),
      );
    }

    if (completedCount >= 5) {
      achievements.add(
        LogAchievement(
          title: 'Пять прогулок',
          description:
          'Завершено 5 прогулок',
          icon:
          Icons.route_rounded,
          color:
          _blue,
        ),
      );
    }

    if (completedCount >= 10) {
      achievements.add(
        LogAchievement(
          title: 'Десять прогулок',
          description:
          'Завершено 10 прогулок',
          icon:
          Icons.alt_route_rounded,
          color:
          _purple,
        ),
      );
    }

    if (activeDays >= 5) {
      achievements.add(
        LogAchievement(
          title: 'Пять активных дней',
          description:
          'Активность минимум 5 дней',
          icon:
          Icons.calendar_month_rounded,
          color:
          const Color(
            0xFF22B8CF,
          ),
        ),
      );
    }

    if (activeDays >= 10) {
      achievements.add(
        LogAchievement(
          title: 'Десять активных дней',
          description:
          'Активность минимум 10 дней',
          icon:
          Icons.event_available_rounded,
          color:
          const Color(
            0xFF5C6BC0,
          ),
        ),
      );
    }

    if (longest >= 30) {
      achievements.add(
        LogAchievement(
          title: 'Полчаса движения',
          description:
          'Прогулка длилась 30 минут',
          icon:
          Icons.timer_rounded,
          color:
          _green,
        ),
      );
    }

    if (longest >= 60) {
      achievements.add(
        LogAchievement(
          title: 'Час движения',
          description:
          'Прогулка длилась 60 минут',
          icon:
          Icons.hourglass_bottom_rounded,
          color:
          _gold,
        ),
      );
    }

    return achievements;
  }

  // ---------------------------------------------------------------------------
  // RECORDS
  // ---------------------------------------------------------------------------

  List<LogRecord> get _records {
    final records =
    <LogRecord>[];

    if (_bestWalkSteps > 0) {
      final best =
      _completedSessions.reduce(
            (a, b) =>
        a.steps >= b.steps
            ? a
            : b,
      );

      records.add(
        LogRecord(
          title: 'Лучшая прогулка',
          value:
          '${_formatNumber(best.steps)} шагов',
          date:
          _formatDateTime(
            best.start,
          ),
          icon:
          Icons.emoji_events_rounded,
          color:
          _gold,
          isTop: true,
        ),
      );
    }

    if (_longestWalkMinutes > 0) {
      final longest =
      _completedSessions.reduce(
            (a, b) =>
        a.durationMinutes >=
            b.durationMinutes
            ? a
            : b,
      );

      records.add(
        LogRecord(
          title: 'Самая длинная прогулка',
          value:
          '${longest.durationMinutes} мин',
          date:
          _formatDateTime(
            longest.start,
          ),
          icon:
          Icons.timer_rounded,
          color:
          _blue,
          isTop: false,
        ),
      );
    }

    if (_completedWalkCount > 0) {
      records.add(
        LogRecord(
          title: 'Средняя прогулка',
          value:
          '${_formatNumber(_averageWalkSteps.round())} шагов',
          date:
          'За всё время',
          icon:
          Icons.analytics_rounded,
          color:
          _green,
          isTop: false,
        ),
      );
    }

    records.add(
      LogRecord(
        title: 'Всего пройдено',
        value:
        '${_formatNumber(_totalSteps)} шагов',
        date:
        'За всё время',
        icon:
        Icons.stars_rounded,
        color:
        _accent,
        isTop: false,
      ),
    );

    records.add(
      LogRecord(
        title: 'Всего прогулок',
        value:
        '$_walkCount',
        date:
        'За всё время',
        icon:
        Icons.directions_walk_rounded,
        color:
        _purple,
        isTop: false,
      ),
    );

    return records;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      _backgroundColor,
      body: NestedScrollView(
        controller:
        _scrollController,
        headerSliverBuilder:
            (
            context,
            innerBoxIsScrolled,
            ) {
          return [
            SliverAppBar(
              backgroundColor:
              _backgroundColor,
              foregroundColor:
              _textColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              pinned: true,
              leadingWidth: 64,
              leading: Padding(
                padding:
                const EdgeInsets.only(
                  left: 12,
                  top: 7,
                  bottom: 7,
                ),
                child: Material(
                  color:
                  _surfaceColor,
                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),
                  child: InkWell(
                    onTap:
                        () =>
                        Navigator.pop(
                          context,
                        ),
                    borderRadius:
                    BorderRadius.circular(
                      15,
                    ),
                    child: Icon(
                      Icons
                          .arrow_back_rounded,
                      color:
                      _textColor,
                      size: 21,
                    ),
                  ),
                ),
              ),
              title: Text(
                'Журнал',
                style: TextStyle(
                  color:
                  _textColor,
                  fontSize: 20,
                  fontWeight:
                  FontWeight.w800,
                  letterSpacing:
                  -0.4,
                ),
              ),
              bottom:
              PreferredSize(
                preferredSize:
                Size.fromHeight(
                  _headerHeight + 58,
                ),
                child:
                Column(
                  children: [
                    AnimatedContainer(
                      duration:
                      const Duration(
                        milliseconds: 180,
                      ),
                      curve:
                      Curves.easeOutCubic,
                      height:
                      _headerHeight,
                      child:
                      AnimatedOpacity(
                        duration:
                        const Duration(
                          milliseconds:
                          160,
                        ),
                        opacity:
                        _headerOpacity,
                        child:
                        _headerHeight >
                            8
                            ? _buildStatsHeader()
                            : const SizedBox
                            .shrink(),
                      ),
                    ),
                    _buildTabBar(),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller:
          _tabController,
          children: [
            _buildAllActivityTab(),
            _buildAchievementsTab(),
            _buildRecordsTab(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildStatsHeader() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        4,
        18,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              Icons
                  .directions_walk_rounded,
              _formatNumber(
                _totalSteps,
              ),
              'шагов',
              _green,
            ),
          ),
          _buildHeaderDivider(),
          Expanded(
            child: _buildMiniStat(
              Icons.timer_rounded,
              '$_activeMinutes',
              'минут',
              _blue,
            ),
          ),
          _buildHeaderDivider(),
          Expanded(
            child: _buildMiniStat(
              Icons.route_rounded,
              '$_walkCount',
              'прогулок',
              _accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDivider() {
    return Container(
      width: 1,
      height: 32,
      color: _dividerColor,
    );
  }

  Widget _buildMiniStat(
      IconData icon,
      String value,
      String label,
      Color color,
      ) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration:
          BoxDecoration(
            color:
            color.withOpacity(
              _isDarkMode
                  ? 0.11
                  : 0.08,
            ),
            borderRadius:
            BorderRadius.circular(
              11,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 17,
          ),
        ),
        const SizedBox(
          width: 7,
        ),
        Flexible(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 14,
                  fontWeight:
                  FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                label,
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                  _secondaryTextColor,
                  fontSize: 9,
                  fontWeight:
                  FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TABS
  // ---------------------------------------------------------------------------

  Widget _buildTabBar() {
    return Container(
      height: 48,
      margin:
      const EdgeInsets.fromLTRB(
        16,
        2,
        16,
        8,
      ),
      padding:
      const EdgeInsets.all(4),
      decoration:
      BoxDecoration(
        color: _surfaceColor,
        borderRadius:
        BorderRadius.circular(
          17,
        ),
        border:
        Border.all(
          color: _borderColor,
        ),
      ),
      child: TabBar(
        controller:
        _tabController,
        dividerColor:
        Colors.transparent,
        indicatorSize:
        TabBarIndicatorSize.tab,
        indicator:
        BoxDecoration(
          gradient:
          LinearGradient(
            colors: [
              _accent,
              _accentDark,
            ],
          ),
          borderRadius:
          BorderRadius.circular(
            13,
          ),
        ),
        labelColor:
        Colors.white,
        unselectedLabelColor:
        _secondaryTextColor,
        labelStyle:
        const TextStyle(
          fontSize: 10,
          fontWeight:
          FontWeight.w800,
        ),
        unselectedLabelStyle:
        const TextStyle(
          fontSize: 10,
          fontWeight:
          FontWeight.w600,
        ),
        tabs: const [
          Tab(
            icon: Icon(
              Icons.list_alt_rounded,
              size: 18,
            ),
            iconMargin:
            EdgeInsets.zero,
          ),
          Tab(
            icon: Icon(
              Icons
                  .emoji_events_rounded,
              size: 18,
            ),
            iconMargin:
            EdgeInsets.zero,
          ),
          Tab(
            icon: Icon(
              Icons.stars_rounded,
              size: 18,
            ),
            iconMargin:
            EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ALL ACTIVITY
  // ---------------------------------------------------------------------------

  Widget _buildAllActivityTab() {
    final sessions =
        _sessions;

    if (sessions.isEmpty) {
      return _buildEmptyState(
        title:
        'История пока пустая',
        subtitle:
        'Начните идти — здесь появится\nваша первая прогулка',
        icon:
        Icons.directions_walk_rounded,
      );
    }

    final grouped =
    <String,
        List<WalkingSession>>{};

    for (final session
    in sessions) {
      final key =
      _dateKey(
        session.start,
      );

      grouped
          .putIfAbsent(
        key,
            () =>
        <WalkingSession>[],
      )
          .add(session);
    }

    final sortedDays =
    grouped.keys.toList()
      ..sort(
            (a, b) =>
            b.compareTo(a),
      );

    return ListView.builder(
      physics:
      const BouncingScrollPhysics(),
      padding:
      const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24,
      ),
      itemCount:
      sortedDays.length,
      itemBuilder:
          (context, index) {
        final day =
        sortedDays[index];

        final daySessions =
        grouped[day]!;

        return _buildDayGroup(
          day,
          daySessions,
        );
      },
    );
  }

  Widget _buildDayGroup(
      String day,
      List<WalkingSession> sessions,
      ) {
    final isToday =
        day ==
            _todayKey();

    int steps = 0;
    int minutes = 0;

    for (final session
    in sessions) {
      steps +=
          session.steps;
      minutes +=
          session.durationMinutes;

      if (session.end == null) {
        final currentMinutes =
            DateTime.now()
                .difference(
              session.start,
            )
                .inMinutes;

        minutes +=
            currentMinutes;
      }
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          margin:
          const EdgeInsets.only(
            bottom: 10,
          ),
          padding:
          const EdgeInsets.all(
            14,
          ),
          decoration:
          BoxDecoration(
            color:
            isToday
                ? _accent.withOpacity(
              _isDarkMode
                  ? 0.07
                  : 0.04,
            )
                : _surfaceColor,
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            border:
            Border.all(
              color:
              isToday
                  ? _accent.withOpacity(
                0.14,
              )
                  : _borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                BoxDecoration(
                  color:
                  isToday
                      ? _accent
                      .withOpacity(
                    0.10,
                  )
                      : _surfaceColor3,
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  isToday
                      ? Icons
                      .today_rounded
                      : Icons
                      .date_range_rounded,
                  color:
                  isToday
                      ? _accent
                      : _secondaryTextColor,
                  size: 20,
                ),
              ),
              const SizedBox(
                width: 11,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday
                          ? 'Сегодня'
                          : _formatFullDate(
                        day,
                      ),
                      style: TextStyle(
                        color:
                        isToday
                            ? _accent
                            : _textColor,
                        fontSize: 14,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${sessions.length} ${_walkWord(sessions.length)}'
                          ' • '
                          '${_formatNumber(steps)} шагов'
                          ' • '
                          '$minutes мин',
                      style: TextStyle(
                        color:
                        _secondaryTextColor,
                        fontSize: 9.5,
                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...sessions.map(
          _buildSessionCard,
        ),
        const SizedBox(
          height: 7,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SESSION CARD
  // ---------------------------------------------------------------------------

  Widget _buildSessionCard(
      WalkingSession session,
      ) {
    final active =
        session.end == null;

    final end =
        session.end;

    final duration =
    active
        ? DateTime.now()
        .difference(
      session.start,
    )
        .inMinutes
        : session.durationMinutes;

    final steps =
        session.steps;

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
      const EdgeInsets.fromLTRB(
        14,
        13,
        14,
        14,
      ),
      decoration:
      BoxDecoration(
        color: _surfaceColor,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border:
        Border.all(
          color:
          active
              ? _green.withOpacity(
            0.20,
          )
              : _borderColor,
        ),
        boxShadow:
        active
            ? [
          BoxShadow(
            color:
            _green.withOpacity(
              0.06,
            ),
            blurRadius: 18,
            offset:
            const Offset(
              0,
              5,
            ),
          ),
        ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildTimelineNode(
                icon:
                active
                    ? Icons
                    .directions_walk_rounded
                    : Icons
                    .play_arrow_rounded,
                color:
                active
                    ? _green
                    : _accent,
              ),
              const SizedBox(
                width: 11,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            active
                                ? 'Идёт ходьба'
                                : 'Прогулка',
                            style:
                            TextStyle(
                              color:
                              _textColor,
                              fontSize:
                              14,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration:
                          BoxDecoration(
                            color:
                            active
                                ? _green
                                .withOpacity(
                              0.10,
                            )
                                : _accent
                                .withOpacity(
                              0.08,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              8,
                            ),
                          ),
                          child:
                          Text(
                            _formatTime(
                              session.start,
                            ),
                            style:
                            TextStyle(
                              color:
                              active
                                  ? _green
                                  : _accent,
                              fontSize:
                              9.5,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      active
                          ? 'Начало ходьбы • продолжается сейчас'
                          : 'Начало в ${_formatTime(session.start)}'
                          ' • завершение в ${_formatTime(end!)}',
                      style: TextStyle(
                        color:
                        _secondaryTextColor,
                        fontSize:
                        10.5,
                        height:
                        1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 10,
            ),
            decoration:
            BoxDecoration(
              color:
              _surfaceColor2,
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSessionMetric(
                    icon:
                    Icons.timer_outlined,
                    value:
                    '$duration мин',
                    label:
                    'время',
                    color:
                    _blue,
                  ),
                ),
                _buildMetricDivider(),
                Expanded(
                  child: _buildSessionMetric(
                    icon:
                    Icons
                        .directions_walk_rounded,
                    value:
                    steps > 0
                        ? _formatNumber(
                      steps,
                    )
                        : '—',
                    label:
                    'шагов',
                    color:
                    _green,
                  ),
                ),
                _buildMetricDivider(),
                Expanded(
                  child:
                  _buildSessionMetric(
                    icon:
                    Icons.speed_rounded,
                    value:
                    steps > 0 &&
                        duration > 0
                        ? _formatNumber(
                      (steps /
                          duration)
                          .round(),
                    )
                        : '—',
                    label:
                    'шаг/мин',
                    color:
                    _accent,
                  ),
                ),
              ],
            ),
          ),
          if (active) ...[
            const SizedBox(
              height: 9,
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                  BoxDecoration(
                    color:
                    _green,
                    shape:
                    BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                        _green.withOpacity(
                          0.35,
                        ),
                        blurRadius:
                        7,
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 7,
                ),
                Text(
                  'Журнал ждёт минуту без новых шагов',
                  style: TextStyle(
                    color:
                    _green,
                    fontSize:
                    10,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineNode({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration:
      BoxDecoration(
        color:
        color.withOpacity(0.10),
        borderRadius:
        BorderRadius.circular(
          14,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 21,
      ),
    );
  }

  Widget _buildSessionMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color:
          color,
          size: 16,
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          value,
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
          style: TextStyle(
            color:
            _textColor,
            fontSize: 11.5,
            fontWeight:
            FontWeight.w800,
          ),
        ),
        const SizedBox(
          height: 2,
        ),
        Text(
          label,
          style: TextStyle(
            color:
            _mutedTextColor,
            fontSize: 8.5,
            fontWeight:
            FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 28,
      color:
      _dividerColor,
    );
  }

  // ---------------------------------------------------------------------------
  // ACHIEVEMENTS
  // ---------------------------------------------------------------------------

  Widget _buildAchievementsTab() {
    final achievements =
        _achievements;

    if (achievements.isEmpty) {
      return _buildEmptyState(
        title:
        'Пока нет достижений',
        subtitle:
        'Начните ходить и первые награды\nпоявятся здесь',
        icon:
        Icons.emoji_events_rounded,
      );
    }

    return ListView.builder(
      physics:
      const BouncingScrollPhysics(),
      padding:
      const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24,
      ),
      itemCount:
      achievements.length,
      itemBuilder:
          (context, index) {
        return _buildAchievementCard(
          achievements[index],
          index,
        );
      },
    );
  }

  Widget _buildAchievementCard(
      LogAchievement achievement,
      int index,
      ) {
    final color =
        achievement.color;

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
      const EdgeInsets.all(
        15,
      ),
      decoration:
      BoxDecoration(
        color:
        _surfaceColor,
        borderRadius:
        BorderRadius.circular(
          21,
        ),
        border:
        Border.all(
          color:
          color.withOpacity(
            _isDarkMode
                ? 0.16
                : 0.11,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
            BoxDecoration(
              gradient:
              LinearGradient(
                begin:
                Alignment.topLeft,
                end:
                Alignment.bottomRight,
                colors: [
                  color.withOpacity(
                    0.20,
                  ),
                  color.withOpacity(
                    0.07,
                  ),
                ],
              ),
              borderRadius:
              BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              achievement.icon,
              color:
              color,
              size: 24,
            ),
          ),
          const SizedBox(
            width: 13,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    color:
                    _textColor,
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  achievement.description,
                  style:
                  TextStyle(
                    color:
                    _secondaryTextColor,
                    fontSize:
                    10.5,
                    height:
                    1.25,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Container(
            width: 29,
            height: 29,
            decoration:
            BoxDecoration(
              shape:
              BoxShape.circle,
              color:
              _green.withOpacity(
                0.10,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              color:
              _green,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECORDS
  // ---------------------------------------------------------------------------

  Widget _buildRecordsTab() {
    final records =
        _records;

    if (records.isEmpty) {
      return _buildEmptyState(
        title:
        'Рекордов пока нет',
        subtitle:
        'Лучшие результаты появятся\nпосле первой прогулки',
        icon:
        Icons.stars_rounded,
      );
    }

    return ListView.builder(
      physics:
      const BouncingScrollPhysics(),
      padding:
      const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24,
      ),
      itemCount:
      records.length,
      itemBuilder:
          (context, index) {
        return _buildRecordCard(
          records[index],
          index,
        );
      },
    );
  }

  Widget _buildRecordCard(
      LogRecord record,
      int index,
      ) {
    final color =
        record.color;

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
      const EdgeInsets.all(
        15,
      ),
      decoration:
      BoxDecoration(
        color:
        _surfaceColor,
        borderRadius:
        BorderRadius.circular(
          21,
        ),
        border:
        Border.all(
          color:
          record.isTop
              ? _gold.withOpacity(
            0.20,
          )
              : color.withOpacity(
            0.10,
          ),
        ),
        boxShadow:
        record.isTop
            ? [
          BoxShadow(
            color:
            _gold.withOpacity(
              _isDarkMode
                  ? 0.08
                  : 0.04,
            ),
            blurRadius:
            20,
            offset:
            const Offset(
              0,
              8,
            ),
          ),
        ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
            BoxDecoration(
              gradient:
              LinearGradient(
                colors: [
                  color.withOpacity(
                    0.20,
                  ),
                  color.withOpacity(
                    0.06,
                  ),
                ],
              ),
              borderRadius:
              BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              record.icon,
              color:
              color,
              size: 23,
            ),
          ),
          const SizedBox(
            width: 13,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        record.title,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        TextStyle(
                          color:
                          _textColor,
                          fontSize:
                          14,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ),
                    if (record.isTop) ...[
                      const SizedBox(
                        width: 6,
                      ),
                      const Text(
                        '👑',
                        style:
                        TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  record.value,
                  style:
                  TextStyle(
                    color:
                    color,
                    fontSize:
                    13,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  record.date,
                  style:
                  TextStyle(
                    color:
                    _secondaryTextColor,
                    fontSize:
                    9.5,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Container(
            width: 34,
            height: 34,
            decoration:
            BoxDecoration(
              color:
              color.withOpacity(
                0.08,
              ),
              borderRadius:
              BorderRadius.circular(
                11,
              ),
            ),
            child: Center(
              child: Text(
                '#${index + 1}',
                style:
                TextStyle(
                  color:
                  color,
                  fontSize:
                  10,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration:
              BoxDecoration(
                shape:
                BoxShape.circle,
                color:
                _surfaceColor,
                border:
                Border.all(
                  color:
                  _borderColor,
                ),
              ),
              child: Icon(
                icon,
                size: 38,
                color:
                _mutedTextColor,
              ),
            ),
            const SizedBox(
              height: 19,
            ),
            Text(
              title,
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                _textColor,
                fontSize:
                19,
                fontWeight:
                FontWeight.w800,
                letterSpacing:
                -0.3,
              ),
            ),
            const SizedBox(
              height: 7,
            ),
            Text(
              subtitle,
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                _secondaryTextColor,
                fontSize:
                12,
                height:
                1.45,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _dateKey(
      DateTime date,
      ) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _todayKey() {
    return _dateKey(
      DateTime.now(),
    );
  }

  String _formatTime(
      DateTime date,
      ) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(
      DateTime date,
      ) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')} '
        '${_formatTime(date)}';
  }

  String _formatFullDate(
      String key,
      ) {
    final parts =
    key.split('.');

    if (parts.length < 2) {
      return key;
    }

    final day =
        int.tryParse(
          parts[0],
        ) ??
            0;

    final month =
        int.tryParse(
          parts[1],
        ) ??
            0;

    const months = [
      '',
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    if (month >= 1 &&
        month <
            months.length) {
      return '$day ${months[month]}';
    }

    return key;
  }

  String _walkWord(
      int number,
      ) {
    final n =
        number % 100;

    if (n >= 11 && n <= 19) {
      return 'прогулок';
    }

    switch (number % 10) {
      case 1:
        return 'прогулка';
      case 2:
      case 3:
      case 4:
        return 'прогулки';
      default:
        return 'прогулок';
    }
  }

  String _formatNumber(
      int number,
      ) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }

    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }

    return number.toString();
  }
}

// =============================================================================
// MODELS
// =============================================================================

class WalkingSession {
  final DateTime start;
  final DateTime? end;
  final int durationMinutes;
  final int steps;

  WalkingSession({
    required this.start,
    this.end,
    this.durationMinutes = 0,
    this.steps = 0,
  });
}

class _CompletionData {
  final DateTime end;
  final int durationMinutes;
  final int steps;

  const _CompletionData({
    required this.end,
    required this.durationMinutes,
    required this.steps,
  });
}

class LogAchievement {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const LogAchievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class LogRecord {
  final String title;
  final String value;
  final String date;
  final IconData icon;
  final Color color;
  final bool isTop;

  const LogRecord({
    required this.title,
    required this.value,
    required this.date,
    required this.icon,
    required this.color,
    required this.isTop,
  });
}