// pedometer_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_log_screen.dart';
import 'journey_screen.dart';

class PedometerScreen extends StatefulWidget {
  const PedometerScreen({super.key});

  @override
  State<PedometerScreen> createState() => _PedometerScreenState();
}

class _PedometerScreenState extends State<PedometerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ---------------------------------------------------------------------------
  // Данные
  // ---------------------------------------------------------------------------

  int _todaySteps = 0;
  int _weeklySteps = 0;
  int _monthlySteps = 0;
  int _totalSteps = 0;

  bool _isWalking = false;
  bool _permissionDenied = false;
  bool _isLoading = true;

  List<int> _dailyHistory = [0, 0, 0, 0, 0, 0, 0];

  List<String> _activityFeed = [];

  int _bestDay = 0;
  String _bestDayDate = '';
  int _activeMinutes = 0;

  List<DayStats> _last10DaysStats = [];

  int _caloriesBurned = 0;
  double _distanceKm = 0.0;

  int _stepsThisHour = 0;
  int _currentHourStreak = 0;
  int _bestStreak = 0;

  double _avgStepsPerDay = 0.0;
  int _daysWithGoal = 0;

  int _level = 1;
  int _experience = 0;
  int _achievementPoints = 0;

  List<String> _unlockedAchievements = [];

  int _consecutiveDays = 0;
  int _weeklyGoalCompletions = 0;

  // ---------------------------------------------------------------------------
  // СЕССИЯ ХОДЬБЫ
  //
  // ВАЖНО:
  // Сессиями управляет НАТИВНЫЙ сервис StepCounterService
  // (он пишет "Начало ходьбы" / "Ходьба завершена" в activity_feed
  // и is_in_walk_session в prefs).
  //
  // Flutter только читает эти значения — никаких Dart-таймеров
  // для закрытия прогулки нет, поэтому журнал работает и в фоне.
  // ---------------------------------------------------------------------------

  bool _walkSessionActive = false;

  // ---------------------------------------------------------------------------
  // Константы
  // ---------------------------------------------------------------------------

  static const double _stepLength = 0.75;
  static const int _totalDistance = 9300;
  static const int _dailyGoal = 10000;

  static const Duration _pollInterval = Duration(seconds: 2);

  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------

  late ConfettiController _confettiController;

  late AnimationController _numberAnimController;
  late AnimationController _ringsAnimController;
  late AnimationController _pulseController;
  late AnimationController _walkingGlowController;
  late AnimationController _levelUpController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _walkingGlowAnimation;
  late Animation<double> _levelUpAnimation;

  StreamSubscription<PedestrianStatus>? _statusSubscription;

  Timer? _pollTimer;
  Timer? _inactivityTimer;
  Timer? _midnightTimer;

  bool _showJourney = false;

  int _previousTodaySteps = 0;
  int _previousTotalSteps = 0;

  // ---------------------------------------------------------------------------
  // Достижения
  // ---------------------------------------------------------------------------

  final List<Achievement> _allAchievements = [
    Achievement(
      id: 'first_steps',
      title: 'Первые шаги',
      description: 'Сделайте 100 шагов',
      icon: Icons.hiking_rounded,
      pointsRequired: 100,
      color: const Color(0xFF4CAF50),
    ),
    Achievement(
      id: 'walker',
      title: 'Ходок',
      description: '1000 шагов за день',
      icon: Icons.directions_walk_rounded,
      pointsRequired: 1000,
      color: const Color(0xFF4B8DFF),
    ),
    Achievement(
      id: 'marathon',
      title: 'Марафонец',
      description: '10000 шагов за день',
      icon: Icons.run_circle_rounded,
      pointsRequired: 10000,
      color: const Color(0xFFFF7548),
    ),
    Achievement(
      id: 'champion',
      title: 'Чемпион',
      description: '20000 шагов за день',
      icon: Icons.emoji_events_rounded,
      pointsRequired: 20000,
      color: const Color(0xFFFFB020),
    ),
    Achievement(
      id: 'legend',
      title: 'Легенда',
      description: '30000 шагов за день',
      icon: Icons.local_fire_department_rounded,
      pointsRequired: 30000,
      color: const Color(0xFFFF5B61),
    ),
    Achievement(
      id: 'streak_3',
      title: 'Настойчивый',
      description: '3 дня подряд с целью',
      icon: Icons.repeat_rounded,
      pointsRequired: 3,
      color: const Color(0xFF8B5CF6),
      isStreak: true,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Неудержимый',
      description: '7 дней подряд с целью',
      icon: Icons.rocket_launch_rounded,
      pointsRequired: 7,
      color: const Color(0xFF6D28D9),
      isStreak: true,
    ),
    Achievement(
      id: 'total_100k',
      title: 'Путешественник',
      description: 'Всего 100000 шагов',
      icon: Icons.map_rounded,
      pointsRequired: 100000,
      color: const Color(0xFF14B8A6),
      isTotal: true,
    ),
    Achievement(
      id: 'total_500k',
      title: 'Исследователь',
      description: 'Всего 500000 шагов',
      icon: Icons.explore_rounded,
      pointsRequired: 500000,
      color: const Color(0xFF6366F1),
      isTotal: true,
    ),
    Achievement(
      id: 'total_1m',
      title: 'Колумб',
      description: 'Всего 1000000 шагов',
      icon: Icons.public_rounded,
      pointsRequired: 1000000,
      color: const Color(0xFF06B6D4),
      isTotal: true,
    ),
    Achievement(
      id: 'calories_500',
      title: 'Сжигатель калорий',
      description: 'Сжечь 500 ккал за день',
      icon: Icons.local_fire_department_rounded,
      pointsRequired: 500,
      color: const Color(0xFFFF6B35),
      isCalories: true,
    ),
    Achievement(
      id: 'weekly_goal',
      title: 'Недельная цель',
      description: 'Выполнить цель 10K 5 дней',
      icon: Icons.star_rounded,
      pointsRequired: 5,
      color: const Color(0xFFF59E0B),
      isWeeklyGoal: true,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _backgroundColor =>
      _isDarkMode ? const Color(0xFF070A10) : const Color(0xFFF5F6F8);

  Color get _surfaceColor =>
      _isDarkMode ? const Color(0xFF10151D) : Colors.white;

  Color get _surfaceColor2 =>
      _isDarkMode ? const Color(0xFF141A23) : const Color(0xFFF9FAFB);

  Color get _textColor =>
      _isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF15191F);

  Color get _subTextColor =>
      _isDarkMode ? const Color(0xFF8993A1) : const Color(0xFF7D8692);

  Color get _mutedTextColor =>
      _isDarkMode ? const Color(0xFF5F6875) : const Color(0xFFA0A7B0);

  Color get _borderColor => _isDarkMode
      ? Colors.white.withOpacity(0.055)
      : Colors.black.withOpacity(0.055);

  Color get _accent => const Color(0xFFFF7548);

  Color get _accentSoft => const Color(0xFFFF9A73);

  Color get _accentDeep => const Color(0xFFE85D32);

  // ---------------------------------------------------------------------------
  // Calculated
  // ---------------------------------------------------------------------------

  double get _walkedKm => (_totalSteps * _stepLength) / 1000.0;

  double get _todayKm => (_todaySteps * _stepLength) / 1000.0;

  double get _weeklyKm => (_weeklySteps * _stepLength) / 1000.0;

  double get _monthlyKm => (_monthlySteps * _stepLength) / 1000.0;

  int get _todayKcal => (_todaySteps * 0.04).round();

  double get _stepProgress => (_todaySteps / _dailyGoal).clamp(0.0, 1.0);

  double get _kmProgress => (_todayKm / 10).clamp(0.0, 1.0);

  double get _kcalProgress => (_todayKcal / 400).clamp(0.0, 1.0);

  double get _monthlyProjection {
    if (_monthlySteps == 0) return 0;

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day;

    if (daysPassed == 0) return 0;

    final avgPerDay = _monthlySteps / daysPassed;
    return (avgPerDay * daysInMonth * _stepLength) / 1000.0;
  }

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _numberAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _ringsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _walkingGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _walkingGlowAnimation = Tween<double>(begin: 0.04, end: 0.22).animate(
      CurvedAnimation(parent: _walkingGlowController, curve: Curves.easeInOut),
    );

    _levelUpAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _levelUpController, curve: Curves.elasticOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _midnightTimer?.cancel();
    _inactivityTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    _statusSubscription?.cancel();

    _numberAnimController.dispose();
    _ringsAnimController.dispose();
    _pulseController.dispose();
    _walkingGlowController.dispose();
    _levelUpController.dispose();

    _confettiController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      () async {
        await _loadDataFromPrefs();
        await _loadLast10DaysStats();

        _previousTodaySteps = _todaySteps;
        _previousTotalSteps = _totalSteps;

        if (mounted) {
          setState(() {});
        }

        _startPolling();
      }();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pollTimer?.cancel();
    }
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> _initializeApp() async {
    await _loadData();
    await _loadLast10DaysStats();
    await _loadAchievements();

    final allGranted = await _checkAndRequestAllPermissions().timeout(
      const Duration(seconds: 5),
      onTimeout: () => true,
    );

    if (allGranted) {
      await _startServiceAndListen();

      _ringsAnimController.forward();

      _startInactivityTimer();
      _scheduleMidnightReset();
    } else {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  Future<bool> _checkAndRequestAllPermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await [
      Permission.activityRecognition,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = true;

    final deniedPermissions = <String>[];

    if (statuses[Permission.activityRecognition]?.isGranted != true) {
      deniedPermissions.add('Физическая активность');
      allGranted = false;
    }

    if (statuses[Permission.locationWhenInUse]?.isGranted != true) {
      deniedPermissions.add('Местоположение');
    }

    _requestBatteryOptimizationAsync();

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (!allGranted && deniedPermissions.contains('Физическая активность')) {
      _showAllPermissionsDialog(deniedPermissions);
      return false;
    }

    return true;
  }

  Future<void> _requestBatteryOptimizationAsync() async {
    try {
      const platform = MethodChannel('com.example.kid_loop/step_counter');
      await platform.invokeMethod('requestIgnoreBattery');
    } catch (_) {}
  }

  void _showAllPermissionsDialog(List<String> deniedPermissions) {
    final isDark = _isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor:
          isDark ? const Color(0xFF11161E) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Row(
            children: [
              _buildIconSquare(
                icon: Icons.warning_amber_rounded,
                color: _accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Нужен доступ',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF171B21),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Чтобы шагомер работал корректно, разрешите доступ к физической активности.',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF9AA4B2)
                      : const Color(0xFF737C88),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ...deniedPermissions.map(
                    (permission) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.035)
                          : Colors.black.withOpacity(0.025),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          color: Colors.redAccent,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            permission,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF171B21),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _permissionDenied = true;
                });
              },
              child: Text(
                'Позже',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF8993A1)
                      : const Color(0xFF7E8794),
                ),
              ),
            ),
            _buildGradientButton(
              label: 'Настройки',
              icon: Icons.settings_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Service
  // ---------------------------------------------------------------------------

  Future<void> _startServiceAndListen() async {
    try {
      const platform = MethodChannel('com.example.kid_loop/step_counter');
      await platform.invokeMethod('startService');
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));

    await _loadDataFromPrefs();
    await _loadLast10DaysStats();

    _previousTodaySteps = _todaySteps;
    _previousTotalSteps = _totalSteps;

    try {
      await _statusSubscription?.cancel();

      _statusSubscription = Pedometer.pedestrianStatusStream.listen(
            (event) {
          if (!mounted) return;

          final walking = event.status == 'walking';

          setState(() {
            _isWalking = walking;
          });
          // Ничего больше не делаем — сессиями управляет
          // нативный StepCounterService.
        },
        onError: (_) {},
      );
    } catch (_) {}

    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(
      _pollInterval,
          (_) {
        if (mounted) {
          _loadDataFromPrefs();
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _loadDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final monthKey = _monthlyKey();

      final newToday = prefs.getInt('today_steps') ?? 0;
      final newWeekly = prefs.getInt('weekly_steps') ?? 0;
      final newMonthly = prefs.getInt(monthKey) ?? 0;
      final newTotal = prefs.getInt('total_steps') ?? 0;
      final newActive = prefs.getInt('active_minutes') ?? 0;

      // Нативный сервис сам решает, идёт ли прогулка сейчас.
      final nativeSessionActive =
          prefs.getBool('is_in_walk_session') ?? false;

      final stepsDiff = newToday - _previousTodaySteps;

      if (newToday != _previousTodaySteps ||
          newTotal != _previousTotalSteps ||
          newActive != _activeMinutes ||
          nativeSessionActive != _walkSessionActive) {
        final savedFeed = prefs.getString('activity_feed');

        setState(() {
          _todaySteps = newToday;
          _weeklySteps = newWeekly;
          _monthlySteps = newMonthly;
          _totalSteps = newTotal;

          _activeMinutes = newActive;
          _walkSessionActive = nativeSessionActive;

          _caloriesBurned = (_todaySteps * 0.04).round();
          _distanceKm = (_todaySteps * _stepLength) / 1000.0;

          if (savedFeed != null && savedFeed.isNotEmpty) {
            _activityFeed = savedFeed.split('\n').take(50).toList();
          }
        });

        if (stepsDiff > 0) {
          _animateNumber();
          _checkMilestones();
          _checkAchievements();

          if (_todaySteps > _bestDay) {
            _bestDay = _todaySteps;
            _bestDayDate = DateTime.now().toString().substring(0, 10);
            _saveMeta();
          }

          final today = DateTime.now().weekday - 1;
          _dailyHistory[today] = _todaySteps;
          _saveDailyHistory();

          _resetInactivityTimer();
        }

        _previousTodaySteps = newToday;
        _previousTotalSteps = newTotal;

        _calculateAdditionalMetrics();

        if (mounted) {
          setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final monthKey = _monthlyKey();

    if (!mounted) return;

    setState(() {
      _todaySteps = prefs.getInt('today_steps') ?? 0;
      _weeklySteps = prefs.getInt('weekly_steps') ?? 0;
      _monthlySteps = prefs.getInt(monthKey) ?? 0;
      _totalSteps = prefs.getInt('total_steps') ?? 0;

      _dailyHistory = List.generate(
        7,
            (i) => prefs.getInt('day_$i') ?? 0,
      );

      _bestDay = prefs.getInt('best_day') ?? 0;
      _bestDayDate = prefs.getString('best_day_date') ?? '';
      _activeMinutes = prefs.getInt('active_minutes') ?? 0;

      _walkSessionActive = prefs.getBool('is_in_walk_session') ?? false;

      _caloriesBurned = (_todaySteps * 0.04).round();
      _distanceKm = (_todaySteps * _stepLength) / 1000.0;

      final savedFeed = prefs.getString('activity_feed');

      _activityFeed = savedFeed != null && savedFeed.isNotEmpty
          ? savedFeed.split('\n').take(50).toList()
          : [];

      _numberAnimController.value = 1.0;
    });

    _calculateAdditionalMetrics();
  }

  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('unlocked_achievements') ?? [];

    if (!mounted) return;

    setState(() {
      _unlockedAchievements = saved;
    });

    _calculateAdditionalMetrics();
  }

  Future<void> _saveAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('unlocked_achievements', _unlockedAchievements);
  }

  // ---------------------------------------------------------------------------
  // Calculations
  // ---------------------------------------------------------------------------

  void _calculateAdditionalMetrics() {
    final nonZeroDays = _dailyHistory.where((steps) => steps > 0).length;

    _avgStepsPerDay =
    nonZeroDays > 0 ? _weeklySteps / nonZeroDays : 0.0;

    _daysWithGoal =
        _dailyHistory.where((steps) => steps >= _dailyGoal).length;

    _bestStreak = 0;
    int currentStreak = 0;

    for (int i = 0; i < 7; i++) {
      if (_dailyHistory[i] >= _dailyGoal) {
        currentStreak++;
        if (currentStreak > _bestStreak) {
          _bestStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
    }

    _experience = _totalSteps;
    _level = (_experience / 50000).floor() + 1;
    _achievementPoints = _unlockedAchievements.length * 10;
  }

  // ---------------------------------------------------------------------------
  // Achievements
  // ---------------------------------------------------------------------------

  void _checkAchievements() {
    bool newAchievement = false;

    for (final achievement in _allAchievements) {
      if (_unlockedAchievements.contains(achievement.id)) continue;

      bool unlocked = false;

      if (achievement.isStreak) {
        unlocked = _bestStreak >= achievement.pointsRequired;
      } else if (achievement.isTotal) {
        unlocked = _totalSteps >= achievement.pointsRequired;
      } else if (achievement.isCalories) {
        unlocked = _caloriesBurned >= achievement.pointsRequired;
      } else if (achievement.isWeeklyGoal) {
        unlocked = _daysWithGoal >= achievement.pointsRequired;
      } else {
        unlocked = _todaySteps >= achievement.pointsRequired;
      }

      if (unlocked) {
        _unlockedAchievements.add(achievement.id);
        newAchievement = true;
        _showAchievementUnlocked(achievement);
      }
    }

    if (newAchievement) {
      _saveAchievements();
      _checkLevelUp();

      if (mounted) setState(() {});
    }
  }

  void _checkLevelUp() {
    final newLevel = (_totalSteps / 50000).floor() + 1;

    if (newLevel > _level) {
      setState(() {
        _level = newLevel;
      });

      _levelUpController.forward(from: 0);
      _confettiController.play();
      _showLevelUpDialog();
    }
  }

  void _showAchievementUnlocked(Achievement achievement) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: achievement.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                achievement.icon,
                color: achievement.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ДОСТИЖЕНИЕ',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    achievement.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    achievement.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF181E27),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Level dialog
  // ---------------------------------------------------------------------------

  void _showLevelUpDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: pi / 2,
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 24,
                  gravity: 0.1,
                  shouldLoop: false,
                  colors: const [
                    Color(0xFFFF7548),
                    Color(0xFFFFB020),
                    Color(0xFFFF5B61),
                    Color(0xFF4CAF50),
                    Color(0xFF4B8DFF),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _levelUpAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _levelUpAnimation.value,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF8B63),
                            Color(0xFFE95E33),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withOpacity(0.45),
                            blurRadius: 35,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'УРОВЕНЬ ПОВЫШЕН',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: 116,
                            height: 116,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$_level',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 68,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$_achievementPoints AP',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    Future.delayed(
      const Duration(seconds: 2),
          () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  Future<void> _loadLast10DaysStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final stats = <DayStats>[];

    for (int i = 0; i < 10; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateKey = 'stats_${date.year}_${date.month}_${date.day}';

      final steps = prefs.getInt(dateKey) ?? 0;
      final minutes = prefs.getInt('${dateKey}_minutes') ?? 0;

      stats.add(
        DayStats(
          date: date,
          steps: steps,
          activeMinutes: minutes,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _last10DaysStats = stats;
    });
  }

  Future<void> _saveMeta() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('best_day', _bestDay);
    await prefs.setString('best_day_date', _bestDayDate);
  }

  Future<void> _saveDailyHistory() async {
    final prefs = await SharedPreferences.getInstance();

    for (int i = 0; i < 7; i++) {
      await prefs.setInt('day_$i', _dailyHistory[i]);
    }
  }

  // ---------------------------------------------------------------------------
  // Midnight
  // ---------------------------------------------------------------------------

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);

    _midnightTimer = Timer(
      midnight.difference(now),
          () {
        _resetDailyCounters();
        _scheduleMidnightReset();
      },
    );
  }

  Future<void> _resetDailyCounters() async {
    if (!mounted) return;

    setState(() {
      _todaySteps = 0;
      _activeMinutes = 0;
    });

    await _loadLast10DaysStats();
  }

  String _monthlyKey() {
    final now = DateTime.now();
    return 'monthly_${now.year}_${now.month}';
  }

  // ---------------------------------------------------------------------------
  // Milestones
  // ---------------------------------------------------------------------------

  void _checkMilestones() {
    const milestones = [
      1000,
      2000,
      5000,
      10000,
      15000,
      20000,
      30000,
    ];

    for (final milestone in milestones) {
      if (_todaySteps >= milestone && (_todaySteps - milestone) < 50) {
        _showMilestoneSnackbar(milestone);
      }
    }
  }

  void _showMilestoneSnackbar(int milestone) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.13),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🎉 Достигнуто $milestone шагов',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1C2520),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  void _animateNumber() {
    _numberAnimController
      ..reset()
      ..forward();
  }

  // ---------------------------------------------------------------------------
  // Inactivity
  // ---------------------------------------------------------------------------

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();

    _inactivityTimer = Timer.periodic(
      const Duration(minutes: 30),
          (_) {
        if (!_isWalking && _todaySteps < _dailyGoal && mounted) {
          _showInactivityNotification();
        }
      },
    );
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _startInactivityTimer();
  }

  void _showInactivityNotification() {
    if (!mounted) return;

    final remaining = _dailyGoal - _todaySteps;
    if (remaining <= 0) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.directions_walk_rounded,
              color: _accentSoft,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Осталось $remaining шагов до цели',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF202731),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();
    if (_showJourney) return _buildJourneyView();
    if (_permissionDenied) return _buildPermissionDenied();

    return _buildMainView();
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_accentSoft, _accentDeep],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(0.24),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_walk_rounded,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Подготавливаем шагомер',
              style: TextStyle(
                color: _textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Синхронизируем активность',
              style: TextStyle(
                color: _subTextColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Permission denied
  // ---------------------------------------------------------------------------

  Widget _buildPermissionDenied() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withOpacity(0.09),
                  ),
                  child: Icon(
                    Icons.sensors_off_rounded,
                    size: 52,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Шагомер не подключён',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Разрешите доступ к физической активности в настройках телефона.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                _buildGradientButton(
                  label: 'Попробовать снова',
                  icon: Icons.refresh_rounded,
                  expanded: true,
                  onPressed: () async {
                    final granted = await _checkAndRequestAllPermissions();

                    if (granted) {
                      await _startServiceAndListen();

                      if (!mounted) return;

                      setState(() {
                        _permissionDenied = false;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main
  // ---------------------------------------------------------------------------

  Widget _buildMainView() {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _backgroundColor,
          appBar: _buildAppBar(),
          body: RefreshIndicator(
            color: _accent,
            backgroundColor: _surfaceColor,
            displacement: 30,
            onRefresh: () async {
              await _loadDataFromPrefs();
              await _loadLast10DaysStats();
              await _loadAchievements();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                _buildHeroSection(),
                const SizedBox(height: 16),
                _buildQuickStats(),
                const SizedBox(height: 16),
                _buildLevelCard(),
                const SizedBox(height: 16),
                _buildAchievementsCard(),
                const SizedBox(height: 16),
                _buildActivityCard(),
                const SizedBox(height: 16),
                _buildComparisonCard(),
                const SizedBox(height: 16),
                _buildForecastCard(),
                if (_bestDay > 0) ...[
                  const SizedBox(height: 16),
                  _buildRecordCard(),
                ],
                const SizedBox(height: 16),
                _buildWeeklyChart(),
                const SizedBox(height: 16),
                _buildActivityFeed(),
                if (_todaySteps < _dailyGoal) ...[
                  const SizedBox(height: 16),
                  _buildReminder(),
                ],
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Color(0xFFFF7548),
                Color(0xFFFFB020),
                Color(0xFFFF5B61),
                Color(0xFF4CAF50),
                Color(0xFF4B8DFF),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: _backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 70,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accentSoft, _accentDeep],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Шагомер',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                _isWalking
                    ? 'Вы сейчас в движении'
                    : _walkSessionActive
                    ? 'Отслеживаем прогулку'
                    : 'Активность сегодня',
                style: TextStyle(
                  color: _isWalking ? _accent : _subTextColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        _buildTopAction(
          icon: Icons.settings_outlined,
          onTap: _showPermissionsInfo,
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _buildTopJourneyButton(),
        ),
      ],
    );
  }

  Widget _buildTopAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.025),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _borderColor,
              width: 0.7,
            ),
          ),
          child: Icon(
            icon,
            color: _subTextColor,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildTopJourneyButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _showJourney = true;
        }),
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _accent.withOpacity(0.11),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_rounded,
                color: _accent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Путь',
                style: TextStyle(
                  color: _accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _buildHeroSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseAnimation,
        _walkingGlowAnimation,
      ]),
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            gradient: _isWalking
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _accent.withOpacity(_isDarkMode ? 0.17 : 0.10),
                _surfaceColor,
                _surfaceColor2,
              ],
            )
                : LinearGradient(
              colors: [_surfaceColor, _surfaceColor2],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isWalking
                  ? _accent.withOpacity(0.26)
                  : _borderColor,
              width: 0.8,
            ),
            boxShadow: _isWalking
                ? [
              BoxShadow(
                color: _accent.withOpacity(
                  _walkingGlowAnimation.value,
                ),
                blurRadius: 35,
                spreadRadius: 3,
              ),
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(
                  _isDarkMode ? 0.10 : 0.025,
                ),
                blurRadius: 20,
                offset: const Offset(0, 7),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildHeroLabel()),
                  _buildWalkingStatus(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildLargeStepNumber()),
                  _buildProgressRing(),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'шагов сегодня',
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'цель $_dailyGoal',
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              _buildGoalProgress(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroLabel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isWalking || _walkSessionActive ? 'СЕЙЧАС В ДВИЖЕНИИ' : 'СЕГОДНЯ',
          style: TextStyle(
            color: _isWalking ? _accent : _subTextColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _todaySteps >= _dailyGoal
              ? 'Цель выполнена'
              : _walkSessionActive
              ? 'Идёт запись прогулки'
              : 'Продолжайте двигаться',
          style: TextStyle(
            color: _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildWalkingStatus() {
    final active = _isWalking || _walkSessionActive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF30B47A).withOpacity(0.10)
            : _softCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? const Color(0xFF30B47A).withOpacity(0.18)
              : _borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? const Color(0xFF30B47A)
                  : _mutedTextColor,
              boxShadow: active
                  ? [
                BoxShadow(
                  color: const Color(0xFF30B47A).withOpacity(0.35),
                  blurRadius: 7,
                ),
              ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isWalking
                ? 'Идём'
                : _walkSessionActive
                ? 'Запись'
                : 'Покой',
            style: TextStyle(
              color: active
                  ? const Color(0xFF30B47A)
                  : _subTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color get _softCardColor => _isDarkMode
      ? Colors.white.withOpacity(0.035)
      : Colors.black.withOpacity(0.025);

  Widget _buildLargeStepNumber() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(
        begin: _previousTodaySteps,
        end: _todaySteps,
      ),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '$value',
          style: TextStyle(
            color: _textColor,
            fontSize: 61,
            height: 0.95,
            fontWeight: FontWeight.w800,
            letterSpacing: -3,
          ),
        );
      },
    );
  }

  Widget _buildProgressRing() {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 8,
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.045)
                  : Colors.black.withOpacity(0.045),
            ),
          ),
          AnimatedBuilder(
            animation: _ringsAnimController,
            builder: (context, child) {
              return SizedBox(
                width: 104,
                height: 104,
                child: CircularProgressIndicator(
                  value: _stepProgress * _ringsAnimController.value,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: _accent,
                  backgroundColor: Colors.transparent,
                ),
              );
            },
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withOpacity(_isDarkMode ? 0.08 : 0.06),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(_stepProgress * 100).round()}%',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'цель',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgress() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Container(
            height: 9,
            color: _isDarkMode
                ? Colors.white.withOpacity(0.045)
                : Colors.black.withOpacity(0.045),
          ),
          FractionallySizedBox(
            widthFactor: _stepProgress,
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accent, _accentSoft],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick stats
  // ---------------------------------------------------------------------------

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildMiniMetric(
            value: _todayKm.toStringAsFixed(1),
            unit: 'км',
            label: 'Дистанция',
            icon: Icons.straighten_rounded,
            color: const Color(0xFF4B8DFF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniMetric(
            value: '$_todayKcal',
            unit: 'ккал',
            label: 'Расход',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFFF7548),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniMetric(
            value: '$_activeMinutes',
            unit: 'мин',
            label: 'Активность',
            icon: Icons.timer_outlined,
            color: const Color(0xFF32C98B),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric({
    required String value,
    required String unit,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _borderColor,
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.06 : 0.018),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: _subTextColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Level
  // ---------------------------------------------------------------------------

  Widget _buildLevelCard() {
    final progress = (_experience % 50000) / 50000;
    final remaining = 50000 - (_experience % 50000);

    return _buildSectionCard(
      child: Column(
        children: [
          Row(
            children: [
              _buildIconSquare(
                icon: Icons.auto_awesome,
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'УРОВЕНЬ',
                      style: TextStyle(
                        color: Color(0xFF9B74F8),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_level',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$remaining шагов до следующего уровня',
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$_achievementPoints AP',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: _isDarkMode
                  ? Colors.white.withOpacity(0.045)
                  : Colors.black.withOpacity(0.045),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF8B5CF6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Achievements
  // ---------------------------------------------------------------------------

  Widget _buildAchievementsCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showAchievements,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _borderColor,
              width: 0.7,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildIconSquare(
                    icon: Icons.emoji_events_rounded,
                    color: _accent,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ДОСТИЖЕНИЯ',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Ваш прогресс и награды',
                          style: TextStyle(
                            color: _subTextColor,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_unlockedAchievements.length}/${_allAchievements.length}',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _mutedTextColor,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _miniAchievement(
                    icon: Icons.local_fire_department_rounded,
                    value: '$_bestStreak',
                    label: 'Серия',
                    unlocked: _bestStreak >= 3,
                  ),
                  const SizedBox(width: 8),
                  _miniAchievement(
                    icon: Icons.emoji_events_rounded,
                    value: '$_bestDay',
                    label: 'Рекорд',
                    unlocked: _bestDay >= _dailyGoal,
                  ),
                  const SizedBox(width: 8),
                  _miniAchievement(
                    icon: Icons.flag_rounded,
                    value: '$_daysWithGoal',
                    label: 'Цели',
                    unlocked: _daysWithGoal >= 3,
                  ),
                  const SizedBox(width: 8),
                  _miniAchievement(
                    icon: Icons.map_rounded,
                    value: _walkedKm.toStringAsFixed(0),
                    label: 'Км',
                    unlocked: _walkedKm >= 5,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniAchievement({
    required IconData icon,
    required String value,
    required String label,
    required bool unlocked,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 3,
        ),
        decoration: BoxDecoration(
          color: unlocked ? _accent.withOpacity(0.055) : _softCardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: unlocked ? _accent.withOpacity(0.18) : _borderColor,
            width: 0.7,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: unlocked ? _accent : _mutedTextColor,
              size: 19,
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unlocked ? _textColor : _mutedTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: _mutedTextColor,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Activity
  // ---------------------------------------------------------------------------

  Widget _buildActivityCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showStatsDialog,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _borderColor,
              width: 0.7,
            ),
          ),
          child: Row(
            children: [
              _buildIconSquare(
                icon: Icons.timer_rounded,
                color: const Color(0xFF32C98B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'АКТИВНОЕ ВРЕМЯ',
                      style: TextStyle(
                        color: Color(0xFF32C98B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_activeMinutes мин',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _mutedTextColor,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Comparison
  // ---------------------------------------------------------------------------

  Widget _buildComparisonCard() {
    final lastWeekSteps = (_weeklySteps * 0.8).round();
    final diff = _weeklySteps - lastWeekSteps;
    final diffPercent =
    lastWeekSteps > 0 ? ((diff / lastWeekSteps) * 100).round() : 0;
    final positive = diff >= 0;
    final comparisonColor =
    positive ? const Color(0xFF32C98B) : const Color(0xFFFF5B61);

    return _buildSectionCard(
      child: Column(
        children: [
          Row(
            children: [
              _buildIconSquare(
                icon: Icons.compare_arrows_rounded,
                color: const Color(0xFF9B74F8),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'СРАВНЕНИЕ',
                      style: TextStyle(
                        color: Color(0xFF9B74F8),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Текущая неделя против прошлой',
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: comparisonColor.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${positive ? '+' : ''}$diffPercent%',
                  style: TextStyle(
                    color: comparisonColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildComparisonValue(
                  title: 'Эта неделя',
                  value: '$_weeklySteps',
                  color: _accent,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: _borderColor,
              ),
              Expanded(
                child: _buildComparisonValue(
                  title: 'Прошлая',
                  value: '$lastWeekSteps',
                  color: _subTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonValue({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: _textColor,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Forecast
  // ---------------------------------------------------------------------------

  Widget _buildForecastCard() {
    return _buildSectionCard(
      child: Row(
        children: [
          _buildIconSquare(
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF4B8DFF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ПРОГНОЗ НА МЕСЯЦ',
                  style: TextStyle(
                    color: Color(0xFF4B8DFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_monthlyProjection.toStringAsFixed(0)} км',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'при текущем темпе',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Record
  // ---------------------------------------------------------------------------

  Widget _buildRecordCard() {
    return _buildSectionCard(
      child: Row(
        children: [
          _buildIconSquare(
            icon: Icons.workspace_premium_rounded,
            color: const Color(0xFFFFB020),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ЛИЧНЫЙ РЕКОРД',
                  style: TextStyle(
                    color: Color(0xFFFFB020),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_bestDay шагов',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _bestDayDate,
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.amber,
              size: 25,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chart
  // ---------------------------------------------------------------------------

  Widget _buildWeeklyChart() {
    const dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    final today = DateTime.now().weekday - 1;

    final maxValue = max(
      _dailyHistory.reduce((a, b) => a > b ? a : b),
      1,
    ).toDouble();

    return _buildSectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconSquare(
                icon: Icons.bar_chart_rounded,
                color: _accent,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ЗА НЕДЕЛЮ',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_weeklySteps шагов',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 168,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                    (index) {
                  final steps = _dailyHistory[index];

                  final height = maxValue > 0
                      ? (steps / maxValue * 105).clamp(8.0, 105.0)
                      : 8.0;

                  final isToday = index == today;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 350),
                            opacity: steps > 0 ? 1 : 0,
                            child: Text(
                              steps > 999
                                  ? '${(steps / 1000).toStringAsFixed(1)}k'
                                  : '$steps',
                              style: TextStyle(
                                color:
                                isToday ? _accent : _subTextColor,
                                fontSize: 9.5,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            height: height,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isToday
                                    ? [
                                  _accent,
                                  _accentSoft.withOpacity(0.45),
                                ]
                                    : [
                                  _accent.withOpacity(0.38),
                                  _accent.withOpacity(0.10),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: isToday
                                  ? [
                                BoxShadow(
                                  color: _accent.withOpacity(0.18),
                                  blurRadius: 10,
                                ),
                              ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dayNames[index],
                            style: TextStyle(
                              color:
                              isToday ? _textColor : _subTextColor,
                              fontSize: 10.5,
                              fontWeight: isToday
                                  ? FontWeight.w800
                                  : FontWeight.w500,
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
    );
  }

  // ---------------------------------------------------------------------------
  // Activity feed
  // ---------------------------------------------------------------------------

  Widget _buildActivityFeed() {
    final grouped = <String, List<String>>{};

    for (final entry in _activityFeed) {
      String dayKey = 'Ранее';

      if (entry.length >= 5 && entry.contains('.')) {
        dayKey = entry.substring(0, 5);
      }

      grouped.putIfAbsent(dayKey, () => []).add(entry);
    }

    final sortedDays = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActivityLogScreen(
                feed: _activityFeed,
                accentColor: _accent,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _borderColor,
              width: 0.7,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildIconSquare(
                    icon: Icons.timeline_rounded,
                    color: const Color(0xFF32C98B),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'АКТИВНОСТЬ',
                          style: TextStyle(
                            color: Color(0xFF32C98B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.35,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Журнал ваших прогулок',
                          style: TextStyle(
                            color: _subTextColor,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_full_rounded,
                    color: _mutedTextColor,
                    size: 19,
                  ),
                ],
              ),
              if (_activityFeed.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...sortedDays.take(3).map(
                      (day) {
                    final entries = grouped[day]!;
                    final isToday = day == _getTodayDateString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildFeedDay(
                        day: day,
                        entries: entries,
                        isToday: isToday,
                      ),
                    );
                  },
                ),
              ] else ...[
                const SizedBox(height: 14),
                Text(
                  'Нет активности за сегодня',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedDay({
    required String day,
    required List<String> entries,
    required bool isToday,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isToday
                    ? const Color(0xFF32C98B)
                    : _mutedTextColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isToday ? 'СЕГОДНЯ' : day,
              style: TextStyle(
                color: isToday
                    ? const Color(0xFF32C98B)
                    : _subTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              '${entries.length} зап.',
              style: TextStyle(
                color: _mutedTextColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ...entries.take(2).map(
              (entry) {
            final time = entry.length >= 11 ? entry.substring(6, 11) : '';
            final text = entry.length > 17 ? entry.substring(17) : entry;

            return Container(
              margin: const EdgeInsets.only(left: 16, bottom: 6),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _softCardColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: _mutedTextColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _getTodayDateString() {
    final now = DateTime.now();

    return '${now.day.toString().padLeft(2, '0')}.'
        '${now.month.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Reminder
  // ---------------------------------------------------------------------------

  Widget _buildReminder() {
    final remaining = _dailyGoal - _todaySteps;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accent.withOpacity(_isDarkMode ? 0.12 : 0.065),
            _surfaceColor,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _accent.withOpacity(0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          _buildIconSquare(
            icon: Icons.directions_walk_rounded,
            color: _accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ЕЩЁ НЕМНОГО',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Осталось $remaining шагов до цели',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared components
  // ---------------------------------------------------------------------------

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _borderColor,
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.07 : 0.018),
            blurRadius: 14,
            offset: const Offset(0, 5),
            spreadRadius: -5,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildIconSquare({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: color,
        size: 21,
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool expanded = false,
  }) {
    return Container(
      width: expanded ? double.infinity : null,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accentSoft, _accentDeep],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.20),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Permissions info
  // ---------------------------------------------------------------------------

  void _showPermissionsInfo() {
    final isDark = _isDarkMode;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF11161E) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Row(
            children: [
              _buildIconSquare(
                icon: Icons.info_outline_rounded,
                color: _accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Шагомер',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF171B21),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Приложение отслеживает шаги даже при закрытом экране.',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF9AA4B2)
                      : const Color(0xFF737C88),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _buildPermissionStatusItem(
                'Физическая активность',
                'Для подсчёта шагов',
                Permission.activityRecognition,
              ),
              const SizedBox(height: 8),
              _buildPermissionStatusItem(
                'Местоположение',
                'Для фоновой работы',
                Permission.locationAlways,
              ),
              const SizedBox(height: 8),
              _buildPermissionStatusItem(
                'Уведомления',
                'Для статуса активности',
                Permission.notification,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.battery_saver_outlined,
                      color: _accent,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Для стабильной работы отключите оптимизацию батареи.',
                        style: TextStyle(
                          color: _subTextColor,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Закрыть',
                style: TextStyle(
                  color: _subTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildGradientButton(
              label: 'Настройки',
              icon: Icons.settings_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionStatusItem(
      String name,
      String description,
      Permission permission,
      ) {
    final isDark = _isDarkMode;

    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (ctx, snapshot) {
        final granted = snapshot.data?.isGranted ?? false;
        final color =
        granted ? const Color(0xFF32C98B) : Colors.redAccent;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.035)
                : Colors.black.withOpacity(0.025),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  granted
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF171B21),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Achievements sheet
  // ---------------------------------------------------------------------------

  void _showAchievements() {
    final isDark = _isDarkMode;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          snap: true,
          snapSizes: const [0.78, 0.95],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF10151D) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _mutedTextColor.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildIconSquare(
                              icon: Icons.emoji_events_rounded,
                              color: _accent,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'Достижения',
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            Text(
                              '${_unlockedAchievements.length}/${_allAchievements.length}',
                              style: TextStyle(
                                color: _accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildSheetLevelSummary(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        _buildAchievementCategory(
                          'Дневные',
                          Icons.today_rounded,
                          _allAchievements
                              .where(
                                (a) =>
                            !a.isStreak &&
                                !a.isTotal &&
                                !a.isCalories &&
                                !a.isWeeklyGoal,
                          )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildAchievementCategory(
                          'Серии',
                          Icons.repeat_rounded,
                          _allAchievements
                              .where((a) => a.isStreak)
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildAchievementCategory(
                          'Общий прогресс',
                          Icons.trending_up_rounded,
                          _allAchievements
                              .where((a) => a.isTotal)
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildAchievementCategory(
                          'Особые',
                          Icons.star_rounded,
                          _allAchievements
                              .where((a) => a.isCalories || a.isWeeklyGoal)
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetLevelSummary() {
    final progress = (_experience % 50000) / 50000;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _softCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Text(
              '$_level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Уровень $_level',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: _isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$_achievementPoints AP',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCategory(
      String title,
      IconData icon,
      List<Achievement> achievements,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: _accent,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: _accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ...achievements.map(
              (achievement) {
            final unlocked =
            _unlockedAchievements.contains(achievement.id);

            return _buildAchievementSheetCard(achievement, unlocked);
          },
        ),
      ],
    );
  }

  Widget _buildAchievementSheetCard(
      Achievement achievement,
      bool unlocked,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surfaceColor2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked
              ? achievement.color.withOpacity(0.25)
              : _borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: unlocked
                  ? achievement.color.withOpacity(0.11)
                  : _softCardColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              achievement.icon,
              color: unlocked ? achievement.color : _mutedTextColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    color: unlocked ? _textColor : _mutedTextColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color:
                    unlocked ? _subTextColor : _mutedTextColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: achievement.color.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: achievement.color,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats sheet
  // ---------------------------------------------------------------------------

  void _showStatsDialog() {
    final isDark = _isDarkMode;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.40,
          maxChildSize: 0.94,
          expand: false,
          snap: true,
          snapSizes: const [0.70, 0.94],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF10151D) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _mutedTextColor.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Row(
                      children: [
                        _buildIconSquare(
                          icon: Icons.analytics_rounded,
                          color: const Color(0xFF4B8DFF),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            '10 дней',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Text(
                          'Статистика',
                          style: TextStyle(
                            color: _subTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
                      itemCount: _last10DaysStats.length,
                      itemBuilder: (ctx, index) {
                        final stat = _last10DaysStats[index];
                        final isToday = index == 0;

                        final progress =
                        (stat.steps / _dailyGoal).clamp(0.0, 1.0);

                        final dayColor = isToday
                            ? _accent
                            : const Color(0xFF4B8DFF);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isToday
                                  ? _accent.withOpacity(0.16)
                                  : _borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: dayColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatDayName(stat.date),
                                      style: TextStyle(
                                        color: dayColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${stat.date.day}',
                                      style: TextStyle(
                                        color: _textColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${stat.steps} шагов',
                                      style: TextStyle(
                                        color: _textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${stat.activeMinutes} мин активности',
                                      style: TextStyle(
                                        color: _subTextColor,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 5,
                                        backgroundColor: _isDarkMode
                                            ? Colors.white
                                            .withOpacity(0.045)
                                            : Colors.black
                                            .withOpacity(0.045),
                                        valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                          dayColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${(progress * 100).round()}%',
                                style: TextStyle(
                                  color: dayColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDayName(DateTime date) {
    final now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'СЕГ';
    }

    final yesterday = now.subtract(const Duration(days: 1));

    if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return 'ВЧЕ';
    }

    const weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    return weekdays[date.weekday - 1];
  }

  // ---------------------------------------------------------------------------
  // Journey
  // ---------------------------------------------------------------------------

  Widget _buildJourneyView() {
    return JourneyView(
      walkedKm: _walkedKm,
      totalSteps: _totalSteps,
      onBack: () {
        if (!mounted) return;

        setState(() {
          _showJourney = false;
        });
      },
    );
  }
}

// =============================================================================
// Models
// =============================================================================

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int pointsRequired;
  final Color color;

  final bool isStreak;
  final bool isTotal;
  final bool isCalories;
  final bool isWeeklyGoal;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.pointsRequired,
    required this.color,
    this.isStreak = false,
    this.isTotal = false,
    this.isCalories = false,
    this.isWeeklyGoal = false,
  });
}

class DayStats {
  final DateTime date;
  final int steps;
  final int activeMinutes;

  DayStats({
    required this.date,
    required this.steps,
    required this.activeMinutes,
  });
}