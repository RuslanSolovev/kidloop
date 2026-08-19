// features/fitness/ui/screens/workout_log_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../nutrition/providers/nutrition_provider.dart';
import '../../../../nutrition/models/nutrition_models.dart';
import '../../../../nutrition/ui/screens/fuel_dashboard_screen.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';

class WorkoutLogScreen extends StatefulWidget {
  final bool isDark;

  const WorkoutLogScreen({
    super.key,
    this.isDark = false,
  });

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;

  NutritionProvider? _nutritionProvider;
  Future<NutritionProvider>? _nutritionFuture;

  final List<String> _moodEmojis = [
    '😫', '😩', '😐', '🙂', '😊', '😁', '🤩', '🔥', '💪', '🚀'
  ];

  final List<String> _emptyStateQuotes = [
    '🌟 Каждый день — новая возможность',
    '💪 Сегодня ты можешь всё',
    '🔥 Начни с малого, стремись к большему',
    '🏆 Твой прогресс начинается с одного шага',
    '⭐ Верь в себя и действуй',
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _sheetController;
  late Animation<double> _sheetAnimation;

  // ТОЛЬКО 2 ПОЛОЖЕНИЯ
  bool _isSheetOpen = false;
  final double _sheetCollapsedHeight = 0.45; // ДО КАЛЕНДАРЯ
  final double _sheetExpandedHeight = 0.85;  // ПОЛНЫЙ ЭКРАН

  // Для плавного перетаскивания
  double _dragOffset = 0;
  bool _isDragging = false;
  double _dragStartY = 0;
  double _currentSheetHeight = 0;
  bool _isAnimating = false;

  // Храним состояние раскрытых карточек внутри шторки
  final Map<String, bool> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();

    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _sheetAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeOutQuart,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<NutritionProvider> _getNutritionProvider() {
    _nutritionFuture ??= _initNutritionProvider();
    return _nutritionFuture!;
  }

  Future<NutritionProvider> _initNutritionProvider() async {
    if (_nutritionProvider != null) return _nutritionProvider!;
    _nutritionProvider = NutritionProvider();
    await _nutritionProvider!.init();
    return _nutritionProvider!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final logs = _getLogsForMonth(provider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: _buildAppBar(isDark, provider),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Stack(
            children: [
              // Основной контент (календарь)
              Column(
                children: [
                  _buildMonthNavigator(isDark),
                  Expanded(
                    child: _buildCalendarGrid(isDark, logs),
                  ),
                ],
              ),

              // Затемнение фона при открытой шторке
              if (_isSheetOpen)
                GestureDetector(
                  onTap: _closeSheet,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),

              // Выдвижная шторка
              _buildBottomSheet(isDark, provider),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar(bool isDark, FitnessProvider provider) {
    final monthLogs = _getLogsForMonth(provider);
    final completedCount = monthLogs
        .where((l) => l.status == WorkoutDayStatus.completed)
        .length;
    final totalWorkouts = monthLogs.length;

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'Журнал',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          if (totalWorkouts > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$completedCount/$totalWorkouts',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF6B35),
                ),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF00FF9D)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt_rounded,
                color: Color(0xFF0A0E1A), size: 16),
          ),
          onPressed: () async {
            final nutrition = await _getNutritionProvider();
            if (!mounted) return;
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: nutrition,
                child: const FuelDashboardScreen(isDark: true),
              ),
            ));
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            Icons.calendar_month_rounded,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
          onPressed: () => _showMonthPicker(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ==================== MONTH NAVIGATOR ====================

  Widget _buildMonthNavigator(bool isDark) {
    const monthNames = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
            },
            style: IconButton.styleFrom(
              foregroundColor: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          GestureDetector(
            onTap: () => _showMonthPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
            },
            style: IconButton.styleFrom(
              foregroundColor: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CALENDAR ====================

  Widget _buildCalendarGrid(bool isDark, List<WorkoutLog> monthLogs) {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final firstWeekday = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    ).weekday;

    final Map<int, List<WorkoutLog>> logsByDay = {};
    for (final log in monthLogs) {
      final day = log.date.day;
      logsByDay[day] = [...logsByDay[day] ?? [], log];
    }

    const dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final today = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == today.year &&
        _selectedMonth.month == today.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: dayNames.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount: firstWeekday - 1 + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) {
                  return const SizedBox();
                }

                final day = index - (firstWeekday - 2);
                final dayLogs = logsByDay[day] ?? [];
                final isToday = isCurrentMonth && day == today.day;
                final isSelected = _selectedDate != null &&
                    _selectedDate!.year == _selectedMonth.year &&
                    _selectedDate!.month == _selectedMonth.month &&
                    _selectedDate!.day == day;

                final hasCompleted = dayLogs.any((l) => l.status == WorkoutDayStatus.completed);
                final hasSkipped = dayLogs.any((l) => l.status == WorkoutDayStatus.skipped);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedDate = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month,
                        day,
                      );
                      // ОТКРЫВАЕМ ДО КАЛЕНДАРЯ
                      _openSheet();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _getDayColor(isDark, dayLogs, isToday, isSelected),
                      borderRadius: BorderRadius.circular(10),
                      border: isToday
                          ? Border.all(color: const Color(0xFFFF6B35), width: 2.5)
                          : isSelected
                          ? Border.all(color: const Color(0xFFFF6B35).withOpacity(0.5), width: 1.5)
                          : null,
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday
                                  ? FontWeight.w800
                                  : isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _getTextColor(isDark, dayLogs, isToday, isSelected),
                            ),
                          ),
                        ),
                        if (dayLogs.isNotEmpty)
                          Positioned(
                            bottom: 4,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: hasCompleted
                                        ? const Color(0xFF4CAF50)
                                        : hasSkipped
                                        ? const Color(0xFFF44336)
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                if (dayLogs.length > 1)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: dayLogs.length > 2
                                          ? const Color(0xFFFF6B35)
                                          : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (dayLogs.length > 2)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4A9BFF),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(isDark, const Color(0xFF4CAF50), 'Выполнено'),
              const SizedBox(width: 12),
              _buildLegendItem(isDark, const Color(0xFFF44336), 'Пропущено'),
              const SizedBox(width: 12),
              _buildLegendItem(isDark, const Color(0xFFFF6B35), 'Несколько'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(bool isDark, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Color _getDayColor(
      bool isDark, List<WorkoutLog> logs, bool isToday, bool isSelected) {
    if (isSelected) return const Color(0xFFFF6B35).withOpacity(0.25);
    if (isToday) return const Color(0xFFFF6B35).withOpacity(0.08);
    if (logs.isEmpty) return Colors.transparent;

    final hasCompleted = logs.any((l) => l.status == WorkoutDayStatus.completed);
    final hasSkipped = logs.any((l) => l.status == WorkoutDayStatus.skipped);

    if (hasCompleted && hasSkipped) {
      return Colors.purple.withOpacity(0.15);
    }
    if (hasCompleted) return const Color(0xFF4CAF50).withOpacity(0.15);
    if (hasSkipped) return const Color(0xFFF44336).withOpacity(0.12);

    return isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100;
  }

  Color _getTextColor(
      bool isDark, List<WorkoutLog> logs, bool isToday, bool isSelected) {
    if (isSelected) return Colors.white;
    if (isToday) return const Color(0xFFFF6B35);
    if (logs.isEmpty) return isDark ? Colors.white38 : Colors.grey.shade400;

    final hasCompleted = logs.any((l) => l.status == WorkoutDayStatus.completed);
    if (hasCompleted) return isDark ? Colors.white : Colors.black87;

    return isDark ? Colors.white54 : Colors.grey.shade600;
  }

  // ==================== ШТОРКА ТОЛЬКО 2 ПОЗИЦИИ ====================

  Widget _buildBottomSheet(bool isDark, FitnessProvider provider) {
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _sheetAnimation,
      builder: (context, child) {
        double targetHeight;
        if (_isDragging) {
          final baseHeight = _isSheetOpen
              ? screenHeight * _sheetExpandedHeight
              : screenHeight * _sheetCollapsedHeight;
          targetHeight = (baseHeight - _dragOffset).clamp(
            screenHeight * _sheetCollapsedHeight,
            screenHeight * _sheetExpandedHeight,
          );
        } else {
          targetHeight = _isSheetOpen
              ? screenHeight * _sheetExpandedHeight
              : screenHeight * _sheetCollapsedHeight;
        }

        // Плавный переход
        final animatedHeight = _isDragging || _isAnimating
            ? targetHeight
            : _sheetAnimation.value * targetHeight +
            (1 - _sheetAnimation.value) *
                (_isSheetOpen
                    ? screenHeight * _sheetExpandedHeight
                    : screenHeight * _sheetCollapsedHeight);

        _currentSheetHeight = animatedHeight;

        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: animatedHeight,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D24) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildDraggableHandle(isDark),
                _buildSheetHeader(isDark),
                Expanded(
                  child: _buildSheetContent(isDark, provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== РУЧКА ====================

  Widget _buildDraggableHandle(bool isDark) {
    return GestureDetector(
      onVerticalDragStart: (details) {
        _dragStartY = details.globalPosition.dy;
        _dragOffset = 0;
        _isDragging = true;
        _isAnimating = false;
      },
      onVerticalDragUpdate: (details) {
        final delta = details.globalPosition.dy - _dragStartY;
        _dragOffset = delta;
        setState(() {});
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        _isDragging = false;

        final screenHeight = MediaQuery.of(context).size.height;
        final currentHeight = _isSheetOpen
            ? screenHeight * _sheetExpandedHeight - _dragOffset
            : screenHeight * _sheetCollapsedHeight - _dragOffset;

        final midPoint = (screenHeight * _sheetCollapsedHeight +
            screenHeight * _sheetExpandedHeight) /
            2;

        bool shouldOpen;
        if (velocity.abs() > 300) {
          shouldOpen = velocity < 0;
        } else {
          shouldOpen = currentHeight > midPoint;
        }

        if (shouldOpen) {
          _openSheet();
        } else {
          _closeSheet();
        }

        _dragOffset = 0;
        Future.delayed(const Duration(milliseconds: 500), () {
          _isAnimating = false;
        });
        setState(() {});
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        width: double.infinity,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _isSheetOpen
                    ? '⬇️ Свайп вниз, чтобы свернуть'
                    : '⬆️ Потяните вверх для деталей',
                key: ValueKey(_isSheetOpen),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ЗАГОЛОВОК ====================

  Widget _buildSheetHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedDate != null
                  ? _formatDateFull(_selectedDate!)
                  : 'Выберите день',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          if (_isSheetOpen)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                size: 26,
              ),
              onPressed: _closeSheet,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  // ==================== УПРАВЛЕНИЕ ====================

  void _openSheet() {
    if (!_isSheetOpen) {
      setState(() {
        _isSheetOpen = true;
        _isAnimating = true;
        _sheetController.forward(from: 0);
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        _isAnimating = false;
      });
    }
  }

  void _closeSheet() {
    if (_isSheetOpen) {
      setState(() {
        _isSheetOpen = false;
        _isAnimating = true;
        _sheetController.reverse(from: 1);
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        _isAnimating = false;
      });
    }
  }

  // ==================== КОНТЕНТ ====================

  Widget _buildSheetContent(bool isDark, FitnessProvider provider) {
    if (_selectedDate == null) {
      return Center(
        child: Text(
          'Нажмите на день в календаре',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      );
    }

    return _buildDayContent(isDark, provider, _selectedDate!);
  }

  // ==================== ДЕНЬ ====================

  Widget _buildDayContent(bool isDark, FitnessProvider provider, DateTime date) {
    final logs = provider.getLogsForDate(date);
    final dayKey = 'stats_${date.year}_${date.month}_${date.day}';

    final dayWellbeing = provider.wellbeingNotes.where((n) =>
    n.date.year == date.year &&
        n.date.month == date.month &&
        n.date.day == date.day).toList();

    final dayPhotos = provider.photos.where((p) =>
    p.date.year == date.year &&
        p.date.month == date.month &&
        p.date.day == date.day).toList();

    final hasWellbeing = dayWellbeing.isNotEmpty;
    final hasPhotos = dayPhotos.isNotEmpty;

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _getDaySteps(dayKey),
        _getNutritionProvider(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
            ),
          );
        }

        final stepsData = snapshot.data![0] as Map<String, int>;
        final nutrition = snapshot.data![1] as NutritionProvider;

        final steps = stepsData['steps'] ?? 0;
        final distanceKm = (steps * 0.75) / 1000.0;
        final stepsCalories = (steps * 0.04).round();

        final nutritionSummary = nutrition.getSummaryForDate(date);
        final nutritionGoals = nutrition.getGoalsForDate(date);

        final hasAnyData = logs.isNotEmpty ||
            steps > 0 ||
            nutritionSummary.entriesCount > 0 ||
            hasWellbeing ||
            hasPhotos;

        if (!hasAnyData) {
          return _buildEmptyDayState(isDark, date);
        }

        final totalVolume = logs.fold(0.0, (sum, l) => sum + (l.totalVolume ?? 0));
        final totalExercises = logs.fold(0, (sum, l) => sum + l.exercisesLog.length);
        final completedCount = logs
            .where((l) => l.status == WorkoutDayStatus.completed)
            .length;

        final sections = <Widget>[];

        sections.add(
          _buildDaySummary(
            isDark,
            logs.length,
            completedCount,
            totalVolume,
            totalExercises,
            steps,
            distanceKm,
            stepsCalories,
            nutritionSummary,
            nutritionGoals,
            nutrition,
          ),
        );

        if (hasWellbeing) {
          sections.add(const SizedBox(height: 12));
          sections.add(_buildDayWellbeingCard(isDark, dayWellbeing.first));
        }

        if (hasPhotos) {
          sections.add(const SizedBox(height: 12));
          sections.add(_buildDayPhotosGrid(isDark, dayPhotos));
        }

        if (logs.isNotEmpty) {
          sections.add(const SizedBox(height: 12));
          sections.add(
            Row(
              children: [
                const Icon(Icons.fitness_center_rounded,
                    color: Color(0xFFFF6B35), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Тренировки (${logs.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          );
          sections.add(const SizedBox(height: 8));
          for (final log in logs) {
            sections.add(_buildExpansionLogCard(isDark, log, provider));
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const BouncingScrollPhysics(),
          children: sections,
        );
      },
    );
  }

  // ==================== ОСТАЛЬНЫЕ МЕТОДЫ ====================

  Widget _buildEmptyDayState(bool isDark, DateTime date) {
    final randomQuote = _emptyStateQuotes[date.day % _emptyStateQuotes.length];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B35).withOpacity(0.1),
                  const Color(0xFFFF3D00).withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                ['🌟', '💪', '🔥', '🏆', '⭐'][date.day % 5],
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет данных за этот день',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            randomQuote,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayWellbeingCard(bool isDark, WellbeingNote note) {
    final energyEmoji = note.energyLevel >= 1 && note.energyLevel <= 10
        ? _moodEmojis[note.energyLevel - 1]
        : '🙂';
    final sleepEmoji = note.sleepQuality >= 1 && note.sleepQuality <= 10
        ? _moodEmojis[note.sleepQuality - 1]
        : '🙂';
    final motivationEmoji = note.motivationLevel >= 1 && note.motivationLevel <= 10
        ? _moodEmojis[note.motivationLevel - 1]
        : '🙂';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF34C759).withOpacity(0.12),
            const Color(0xFF34C759).withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF34C759).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFF34C759),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Самочувствие дня',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF34C759),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${note.date.hour}:${note.date.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSmallMoodStat(energyEmoji, 'Энергия', note.energyLevel, isDark),
              _buildSmallMoodStat(sleepEmoji, 'Сон', note.sleepQuality, isDark),
              _buildSmallMoodStat(motivationEmoji, 'Мотивация', note.motivationLevel, isDark),
            ],
          ),
          if (note.painAreas.isNotEmpty && !note.painAreas.contains('Нет болей')) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.healing_rounded,
                      color: Colors.orange, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Боли: ${note.painAreas.join(" • ")}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (note.notes != null && note.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('💭', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      note.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallMoodStat(String emoji, String label, int value, bool isDark) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 2),
        Text(
          '$value/10',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildDayPhotosGrid(bool isDark, List<FitnessPhoto> photos) {
    final displayPhotos = photos.take(4).toList();
    final remainingCount = photos.length - displayPhotos.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF9500).withOpacity(0.1),
            const Color(0xFFFF5722).withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF9500).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Color(0xFFFF9500),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Фото дня',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF9500),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${photos.length} шт.',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: displayPhotos.length == 1 ? 1 : 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: displayPhotos.length == 1 ? 1.8 : 1.0,
            ),
            itemCount: displayPhotos.length,
            itemBuilder: (context, index) {
              final photo = displayPhotos[index];
              return _buildSmallPhotoTile(isDark, photo);
            },
          ),
          if (remainingCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text(
                  '+ ещё $remainingCount фото',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallPhotoTile(bool isDark, FitnessPhoto photo) {
    final file = File(photo.imageUrl);
    final hasFile = file.existsSync();

    return GestureDetector(
      onTap: () {
        if (hasFile) {
          _showFullScreenPhoto(context, file);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasFile
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                color: isDark ? const Color(0xFF0F1115) : Colors.grey.shade200,
                child: const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.grey,
                  size: 24,
                ),
              ),
              if (photo.label != null && photo.label!.isNotEmpty)
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      photo.label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySummary(
      bool isDark,
      int totalWorkouts,
      int completed,
      double totalVolume,
      int totalExercises,
      int steps,
      double distanceKm,
      int calories,
      DailyNutritionSummary nutrition,
      NutritionGoals goals,
      NutritionProvider nutritionProvider,
      ) {
    final hasNutrition = nutrition.entriesCount > 0;
    final hasWorkouts = totalWorkouts > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.12),
            const Color(0xFFFF6B35).withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B35).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFFFF6B35),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Сводка дня',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('👟', '$steps', 'шагов'),
              _buildSummaryItem('📏', distanceKm.toStringAsFixed(1), 'км'),
              _buildSummaryItem('🔥', '$calories', 'ккал'),
            ],
          ),

          if (hasWorkouts) ...[
            const SizedBox(height: 12),
            Divider(color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('🏋️', '$totalWorkouts', 'тренировок'),
                _buildSummaryItem('✅', '$completed', 'выполнено'),
                _buildSummaryItem('📊', totalVolume.toStringAsFixed(0), 'кг'),
                _buildSummaryItem('💪', '$totalExercises', 'упражнений'),
              ],
            ),
          ],

          if (hasNutrition) ...[
            const SizedBox(height: 12),
            Divider(color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 12),
            _buildCompactNutrition(isDark, nutrition, goals),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: nutritionProvider,
                      child: const FuelDashboardScreen(isDark: true),
                    ),
                  ));
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('Подробнее о питании',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00D4FF),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCompactNutrition(
      bool isDark,
      DailyNutritionSummary summary,
      NutritionGoals goals,
      ) {
    final calPercent = summary.percentOf(goals);
    final pPercent = summary.proteinPercentOf(goals);
    final fPercent = summary.fatPercentOf(goals);
    final cPercent = summary.carbsPercentOf(goals);

    return Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: calPercent.clamp(0, 1),
                  strokeWidth: 6,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    calPercent > 1
                        ? const Color(0xFFFF2D55)
                        : const Color(0xFF00D4FF),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${summary.calories.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      height: 1,
                    ),
                  ),
                  const Text(
                    'ккал',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildSmallMacro('Б', summary.protein, goals.protein,
                  pPercent, const Color(0xFF00FF9D)),
              const SizedBox(height: 4),
              _buildSmallMacro('Ж', summary.fat, goals.fat,
                  fPercent, const Color(0xFFFF2D55)),
              const SizedBox(height: 4),
              _buildSmallMacro('У', summary.carbs, goals.carbs,
                  cPercent, const Color(0xFFFFD60A)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallMacro(
      String label,
      double current,
      double goal,
      double percent,
      Color color,
      ) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${current.round()}/${goal.round()}',
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionLogCard(bool isDark, WorkoutLog log, FitnessProvider provider) {
    final isCompleted = log.status == WorkoutDayStatus.completed;
    final cardKey = log.id;

    _expandedCards.putIfAbsent(cardKey, () => false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _expandedCards[cardKey] = !(_expandedCards[cardKey] ?? false);
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: log.status.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(log.status.icon, color: log.status.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCompleted
                              ? '💪 Тренировка выполнена'
                              : '⏭️ Тренировка пропущена',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${log.date.hour}:${log.date.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (isCompleted && log.totalVolume != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${log.totalVolume!.toStringAsFixed(0)} кг',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF6B35),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                            if (log.exercisesLog.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${log.exercisesLog.length} упр.',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (log.comment != null && log.comment!.isNotEmpty)
                          Text(
                            log.comment!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: (_expandedCards[cardKey] ?? false) ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildExpandedContent(isDark, log, provider),
            ),
            crossFadeState: (_expandedCards[cardKey] ?? false)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(bool isDark, WorkoutLog log, FitnessProvider provider) {
    if (log.status != WorkoutDayStatus.completed) {
      return _buildSkippedContent(isDark, log, provider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailedStats(isDark, log),
        const SizedBox(height: 12),
        if (log.moodEnergy != null || log.moodNotes != null) ...[
          _buildMoodSection(isDark, log),
          const SizedBox(height: 12),
        ],
        if (log.workoutPhotoPath != null && File(log.workoutPhotoPath!).existsSync()) ...[
          _buildWorkoutPhoto(isDark, log),
          const SizedBox(height: 12),
        ],
        if (log.exercisesLog.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.fitness_center_rounded,
                  color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text(
                'Упражнения (${log.exercisesLog.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...log.exercisesLog.asMap().entries.map((entry) {
            final exercise = entry.value;
            final exerciseData = provider.exercises.firstWhere(
                  (e) => e.id == exercise.exerciseId,
              orElse: () => Exercise(id: '', name: 'Упражнение удалено'),
            );
            return _buildDetailedExerciseTile(isDark, exercise, exerciseData);
          }),
        ],
        const SizedBox(height: 8),
        _buildCommentField(isDark, log, provider),
      ],
    );
  }

  Widget _buildSkippedContent(bool isDark, WorkoutLog log, FitnessProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_rounded, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Тренировка была пропущена',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCommentField(isDark, log, provider),
      ],
    );
  }

  Widget _buildDetailedStats(bool isDark, WorkoutLog log) {
    final duration = log.duration;
    final hours = duration?.inHours ?? 0;
    final minutes = duration?.inMinutes.remainder(60) ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailStat('⏱️',
              hours > 0 ? '${hours}ч ${minutes}м' : '${minutes}м',
              'время'),
          _buildDetailStat('🏋️',
              '${log.totalVolume?.toStringAsFixed(0) ?? 0} кг',
              'тоннаж'),
          _buildDetailStat('📊',
              log.avgRpe != null ? '${log.avgRpe!.toStringAsFixed(1)}' : '--',
              'RPE'),
          _buildDetailStat('💪',
              '${log.exercisesLog.length}',
              'упражнений'),
        ],
      ),
    );
  }

  Widget _buildDetailStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDetailedExerciseTile(
      bool isDark, WorkoutExercise exercise, Exercise exerciseData) {
    final completedSets = exercise.sets
        .where((s) => s.status == SetStatus.completed)
        .toList();
    final exerciseVolume = completedSets.fold(0.0, (sum, s) => sum + s.volume);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                exerciseData.exerciseType.emoji,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  exerciseData.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${completedSets.length} подходов',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                  if (exerciseVolume > 0)
                    Text(
                      '${exerciseVolume.toStringAsFixed(0)} кг',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF6B35),
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (completedSets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: completedSets.map((set) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    '${set.weight.toStringAsFixed(0)}×${set.reps}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodSection(bool isDark, WorkoutLog log) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.08),
            Colors.orange.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mood_rounded, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Text(
                'Настроение',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (log.moodEnergy != null)
                _buildMoodChip('⚡', 'Энергия', log.moodEnergy!, isDark),
              if (log.moodSleep != null)
                _buildMoodChip('😴', 'Сон', log.moodSleep!, isDark),
              if (log.moodMotivation != null)
                _buildMoodChip('🎯', 'Мотивация', log.moodMotivation!, isDark),
            ],
          ),
          if (log.moodNotes != null && log.moodNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '💭 ${log.moodNotes!}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodChip(String emoji, String label, int value, bool isDark) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(
          '$value/10',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildWorkoutPhoto(bool isDark, WorkoutLog log) {
    final file = File(log.workoutPhotoPath!);

    return GestureDetector(
      onTap: () {
        if (file.existsSync()) {
          _showFullScreenPhoto(context, file);
        }
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                color: isDark ? const Color(0xFF0F1115) : Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.grey, size: 40),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Увеличить',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenPhoto(BuildContext context, File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentField(bool isDark, WorkoutLog log, FitnessProvider provider) {
    final isCompleted = log.status == WorkoutDayStatus.completed;

    return TextField(
      decoration: InputDecoration(
        hintText: isCompleted
            ? 'Добавить комментарий к тренировке...'
            : 'Почему пропустили тренировку?',
        hintStyle: TextStyle(
          color: isDark ? Colors.white24 : Colors.grey.shade400,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
        contentPadding: const EdgeInsets.all(12),
        prefixIcon: const Icon(Icons.comment_rounded, size: 16, color: Colors.grey),
      ),
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 12,
      ),
      maxLines: 2,
      onSubmitted: (value) {
        if (value.isNotEmpty) {
          provider.updateLogComment(log.id, value);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Комментарий сохранён'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<Map<String, int>> _getDaySteps(String dayKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'steps': prefs.getInt(dayKey) ?? 0,
        'minutes': prefs.getInt('${dayKey}_minutes') ?? 0,
      };
    } catch (_) {
      return {'steps': 0, 'minutes': 0};
    }
  }

  List<WorkoutLog> _getLogsForMonth(FitnessProvider provider) {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    return provider.logs
        .where((log) =>
    log.date.isAfter(start.subtract(const Duration(days: 1))) &&
        log.date.isBefore(end.add(const Duration(days: 1))))
        .toList();
  }

  void _showMonthPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Выберите месяц и год',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(
                            _selectedMonth.year - 1,
                            _selectedMonth.month,
                          );
                        });
                      },
                      style: IconButton.styleFrom(
                        foregroundColor: widget.isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${_selectedMonth.year}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF6B35),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(
                            _selectedMonth.year + 1,
                            _selectedMonth.month,
                          );
                        });
                      },
                      style: IconButton.styleFrom(
                        foregroundColor: widget.isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.2,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final monthNames = [
                    'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
                    'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'
                  ];
                  final isSelected = _selectedMonth.month == month;
                  final isCurrent = DateTime.now().month == month &&
                      DateTime.now().year == _selectedMonth.year;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, month);
                      });
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF6B35)
                            : isCurrent
                            ? const Color(0xFFFF6B35).withOpacity(0.12)
                            : widget.isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF6B35)
                              : widget.isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.shade200,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ]
                            : null,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              monthNames[index],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : widget.isDark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                            if (isCurrent && !isSelected)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF6B35),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime.now();
                    });
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.today_rounded, size: 18),
                  label: const Text(
                    'Сегодня',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B35),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFFFF6B35).withOpacity(0.08),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateFull(DateTime date) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final now = DateTime.now();
    final isToday = date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;

    if (isToday) return 'Сегодня';

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year;

    if (isYesterday) return 'Вчера';

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}