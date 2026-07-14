// pedometer_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:confetti/confetti.dart';
import 'journey_screen.dart';
import 'activity_log_screen.dart';

class PedometerScreen extends StatefulWidget {
  const PedometerScreen({super.key});

  @override
  State<PedometerScreen> createState() => _PedometerScreenState();
}

class _PedometerScreenState extends State<PedometerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

  // 🔥 Конфетти контроллер
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

  static const double _stepLength = 0.75;
  static const int _totalDistance = 9300;
  static const int _dailyGoal = 10000;
  static const Duration _pollInterval = Duration(seconds: 2);

  // 🔥 Достижения
  final List<Achievement> _allAchievements = [
    Achievement(id: 'first_steps', title: 'Первые шаги', description: 'Сделайте 100 шагов', icon: Icons.hiking_rounded, pointsRequired: 100, color: Colors.green),
    Achievement(id: 'walker', title: 'Ходок', description: '1000 шагов за день', icon: Icons.directions_walk_rounded, pointsRequired: 1000, color: Colors.blue),
    Achievement(id: 'marathon', title: 'Марафонец', description: '10000 шагов за день', icon: Icons.run_circle_rounded, pointsRequired: 10000, color: Colors.orange),
    Achievement(id: 'champion', title: 'Чемпион', description: '20000 шагов за день', icon: Icons.emoji_events_rounded, pointsRequired: 20000, color: Colors.amber),
    Achievement(id: 'legend', title: 'Легенда', description: '30000 шагов за день', icon: Icons.local_fire_department_rounded, pointsRequired: 30000, color: Colors.red),
    Achievement(id: 'streak_3', title: 'Настойчивый', description: '3 дня подряд с целью', icon: Icons.repeat_rounded, pointsRequired: 3, color: Colors.purple, isStreak: true),
    Achievement(id: 'streak_7', title: 'Неудержимый', description: '7 дней подряд с целью', icon: Icons.rocket_launch_rounded, pointsRequired: 7, color: Colors.deepPurple, isStreak: true),
    Achievement(id: 'total_100k', title: 'Путешественник', description: 'Всего 100,000 шагов', icon: Icons.map_rounded, pointsRequired: 100000, color: Colors.teal, isTotal: true),
    Achievement(id: 'total_500k', title: 'Исследователь', description: 'Всего 500,000 шагов', icon: Icons.explore_rounded, pointsRequired: 500000, color: Colors.indigo, isTotal: true),
    Achievement(id: 'total_1m', title: 'Колумб', description: 'Всего 1,000,000 шагов', icon: Icons.public_rounded, pointsRequired: 1000000, color: Colors.cyan, isTotal: true),
    Achievement(id: 'calories_500', title: 'Сжигатель калорий', description: 'Сжечь 500 ккал за день', icon: Icons.local_fire_department_rounded, pointsRequired: 500, color: Colors.deepOrange, isCalories: true),
    Achievement(id: 'weekly_goal', title: 'Недельная цель', description: 'Выполнить цель 10K 5 дней в неделю', icon: Icons.star_rounded, pointsRequired: 5, color: Colors.amber, isWeeklyGoal: true),
  ];

  // 🔥 Поддержка тёмной/светлой темы
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🔥 Инициализация конфетти
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

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

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _walkingGlowAnimation = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _walkingGlowController, curve: Curves.easeInOut),
    );
    _levelUpAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _levelUpController, curve: Curves.elasticOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

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
      setState(() => _permissionDenied = true);
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _statusSubscription?.cancel();
    _numberAnimController.dispose();
    _ringsAnimController.dispose();
    _pulseController.dispose();
    _walkingGlowController.dispose();
    _levelUpController.dispose();
    _inactivityTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDataFromPrefs();
      _loadLast10DaysStats();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  Future<bool> _checkAndRequestAllPermissions() async {
    if (!Platform.isAndroid) return true;
    Map<Permission, PermissionStatus> statuses = await [
      Permission.activityRecognition,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = true;
    List<String> deniedPermissions = [];

    if (statuses[Permission.activityRecognition]?.isGranted != true) {
      deniedPermissions.add('Физическая активность');
      allGranted = false;
    }
    if (statuses[Permission.locationWhenInUse]?.isGranted != true) {
      deniedPermissions.add('Местоположение');
    }
    _requestBatteryOptimizationAsync();
    if (await Permission.notification.isDenied) {
      Permission.notification.request();
    }
    if (!allGranted && deniedPermissions.contains('Физическая активность')) {
      _showAllPermissionsDialog(deniedPermissions);
      return false;
    }
    return true;
  }

  void _requestBatteryOptimizationAsync() async {
    try {
      const platform = MethodChannel('com.example.kid_loop/step_counter');
      await platform.invokeMethod('requestIgnoreBattery');
    } catch (e) {}
  }

  void _showAllPermissionsDialog(List<String> deniedPermissions) {
    final isDark = _isDarkMode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151932) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text('⚠️ Требуются разрешения',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Для корректной работы шагомера необходимо:',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            ...deniedPermissions.map((perm) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(perm, style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _permissionDenied = true);
            },
            child: Text('Позже', style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.deepOrange],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Открыть настройки',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startServiceAndListen() async {
    try {
      const platform = MethodChannel('com.example.kid_loop/step_counter');
      await platform.invokeMethod('startService');
    } catch (e) {}
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      _statusSubscription = Pedometer.pedestrianStatusStream.listen(
            (event) {
          if (mounted) setState(() => _isWalking = event.status == 'walking');
        },
        onError: (error) {},
      );
    } catch (e) {}
    await _loadDataFromPrefs();
    await _loadLast10DaysStats();
    _previousTodaySteps = _todaySteps;
    _previousTotalSteps = _totalSteps;
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted) _loadDataFromPrefs();
    });
  }

  Future<void> _loadDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final monthKey = _monthlyKey();
      await prefs.reload();

      final newToday = prefs.getInt('today_steps') ?? 0;
      final newWeekly = prefs.getInt('weekly_steps') ?? 0;
      final newMonthly = prefs.getInt(monthKey) ?? 0;
      final newTotal = prefs.getInt('total_steps') ?? 0;
      final newActive = prefs.getInt('active_minutes') ?? 0;

      if (newToday != _previousTodaySteps || newTotal != _previousTotalSteps || newActive != _activeMinutes) {
        final stepsDiff = newToday - _previousTodaySteps;
        setState(() {
          _todaySteps = newToday;
          _weeklySteps = newWeekly;
          _monthlySteps = newMonthly;
          _totalSteps = newTotal;
          _activeMinutes = newActive;
          _caloriesBurned = (_todaySteps * 0.04).round();
          _distanceKm = (_todaySteps * _stepLength) / 1000.0;
          final savedFeed = prefs.getString('activity_feed');
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
      }
    } catch (e) {}
  }

  void _calculateAdditionalMetrics() {
    final nonZeroDays = _dailyHistory.where((s) => s > 0).length;
    _avgStepsPerDay = nonZeroDays > 0 ? _weeklySteps / nonZeroDays : 0.0;
    _daysWithGoal = _dailyHistory.where((s) => s >= _dailyGoal).length;
    _bestStreak = 0;
    int currentStreak = 0;
    for (int i = 0; i < 7; i++) {
      if (_dailyHistory[i] >= _dailyGoal) {
        currentStreak++;
        if (currentStreak > _bestStreak) _bestStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    // 🔥 Расчет уровня и опыта
    _experience = _totalSteps;
    _level = (_experience / 50000).floor() + 1;
    _achievementPoints = _unlockedAchievements.length * 10;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final monthKey = _monthlyKey();
    setState(() {
      _todaySteps = prefs.getInt('today_steps') ?? 0;
      _weeklySteps = prefs.getInt('weekly_steps') ?? 0;
      _monthlySteps = prefs.getInt(monthKey) ?? 0;
      _totalSteps = prefs.getInt('total_steps') ?? 0;
      _dailyHistory = List.generate(7, (i) => prefs.getInt('day_$i') ?? 0);
      _bestDay = prefs.getInt('best_day') ?? 0;
      _bestDayDate = prefs.getString('best_day_date') ?? '';
      _activeMinutes = prefs.getInt('active_minutes') ?? 0;
      _caloriesBurned = (_todaySteps * 0.04).round();
      _distanceKm = (_todaySteps * _stepLength) / 1000.0;
      final savedFeed = prefs.getString('activity_feed');
      _activityFeed = (savedFeed != null && savedFeed.isNotEmpty)
          ? savedFeed.split('\n').take(50).toList()
          : [];
      _numberAnimController.value = 1.0;
    });
    _calculateAdditionalMetrics();
  }

  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('unlocked_achievements') ?? [];
    setState(() => _unlockedAchievements = saved);
  }

  Future<void> _saveAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('unlocked_achievements', _unlockedAchievements);
  }

  void _checkAchievements() {
    bool newAchievement = false;

    for (final achievement in _allAchievements) {
      if (_unlockedAchievements.contains(achievement.id)) continue;

      bool unlocked = false;
      if (achievement.isStreak == true) {
        unlocked = _bestStreak >= achievement.pointsRequired;
      } else if (achievement.isTotal == true) {
        unlocked = _totalSteps >= achievement.pointsRequired;
      } else if (achievement.isCalories == true) {
        unlocked = _caloriesBurned >= achievement.pointsRequired;
      } else if (achievement.isWeeklyGoal == true) {
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
    }
  }

  void _checkLevelUp() {
    final newLevel = (_totalSteps / 50000).floor() + 1;
    if (newLevel > _level) {
      setState(() => _level = newLevel);
      _levelUpController.forward(from: 0);
      _confettiController.play();
      _showLevelUpDialog();
    }
  }

  void _showAchievementUnlocked(Achievement achievement) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [achievement.color, achievement.color.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(achievement.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆 ДОСТИЖЕНИЕ РАЗБЛОКИРОВАНО!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber)),
                  Text(achievement.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(achievement.description,
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2D2D44),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showLevelUpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Stack(
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
                numberOfParticles: 20,
                gravity: 0.1,
                shouldLoop: false,
                colors: const [Colors.orange, Colors.amber, Colors.red, Colors.green, Colors.blue],
              ),
            ),
            AnimatedBuilder(
              animation: _levelUpAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _levelUpAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        const Text('УРОВЕНЬ ПОВЫШЕН!',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('$_level',
                              style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 16),
                        Text('$_achievementPoints очков достижений',
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _loadLast10DaysStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final List<DayStats> stats = [];
    for (int i = 0; i < 10; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateKey = 'stats_${date.year}_${date.month}_${date.day}';
      final steps = prefs.getInt(dateKey) ?? 0;
      final minutes = prefs.getInt('${dateKey}_minutes') ?? 0;
      stats.add(DayStats(date: date, steps: steps, activeMinutes: minutes));
    }
    setState(() => _last10DaysStats = stats);
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

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(midnight.difference(now), () {
      _resetDailyCounters();
      _scheduleMidnightReset();
    });
  }

  void _resetDailyCounters() async {
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

  void _checkMilestones() {
    const milestones = [1000, 2000, 5000, 10000, 15000, 20000, 30000];
    for (final m in milestones) {
      if (_todaySteps >= m && (_todaySteps - m) < 50) {
        _showMilestoneSnackbar(m);
      }
    }
  }

  void _showMilestoneSnackbar(int milestone) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('🎉 Достигли $milestone шагов!',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF2D5A27),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _animateNumber() {
    _numberAnimController.reset();
    _numberAnimController.forward();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (!_isWalking && _todaySteps < _dailyGoal && mounted) {
        _showInactivityNotification();
      }
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _startInactivityTimer();
  }

  void _showInactivityNotification() {
    if (!mounted) return;
    final remaining = _dailyGoal - _todaySteps;
    if (remaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.directions_walk, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Осталось $remaining шагов до цели! Прогуляйтесь! 🚶',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _showAchievements() {
    final isDark = _isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1A1A2E), const Color(0xFF0A0A1A)]
                    : [Colors.white, Colors.grey.shade50],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(isDark ? 0.15 : 0.08),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade500, Colors.grey.shade700],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Colors.deepOrange],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text('🏆 Достижения',
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 🔥 Уровень и прогресс
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.withOpacity(0.1), Colors.deepOrange.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.orange, Colors.deepOrange],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text('$_level',
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Уровень $_level',
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (_experience % 50000) / 50000,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey.withOpacity(0.2),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text('$_achievementPoints AP',
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // 🔥 Категории достижений
                      _buildAchievementCategory('Дневные достижения', Icons.today_rounded, _allAchievements.where((a) => a.isStreak != true && a.isTotal != true && a.isCalories != true && a.isWeeklyGoal != true).toList()),
                      const SizedBox(height: 16),
                      _buildAchievementCategory('Серии', Icons.repeat_rounded, _allAchievements.where((a) => a.isStreak == true).toList()),
                      const SizedBox(height: 16),
                      _buildAchievementCategory('Общий прогресс', Icons.trending_up_rounded, _allAchievements.where((a) => a.isTotal == true).toList()),
                      const SizedBox(height: 16),
                      _buildAchievementCategory('Особые', Icons.star_rounded, _allAchievements.where((a) => a.isCalories == true || a.isWeeklyGoal == true).toList()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAchievementCategory(String title, IconData icon, List<Achievement> achievements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 8),
        ...achievements.map((achievement) {
          final unlocked = _unlockedAchievements.contains(achievement.id);
          return _buildAchievementCard(achievement, unlocked);
        }),
      ],
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool unlocked) {
    final isDark = _isDarkMode;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: unlocked
              ? [achievement.color.withOpacity(isDark ? 0.15 : 0.08), isDark ? const Color(0xFF151932) : Colors.white]
              : [isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50, isDark ? const Color(0xFF151932) : Colors.white],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked ? achievement.color.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unlocked
                  ? LinearGradient(colors: [achievement.color, achievement.color.withOpacity(0.7)])
                  : LinearGradient(
                colors: [isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200, isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100],
              ),
            ),
            child: Icon(
              achievement.icon,
              color: unlocked ? Colors.white : (isDark ? Colors.grey : Colors.grey.shade400),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    color: unlocked ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.grey : Colors.grey.shade500),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color: unlocked ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600) : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: achievement.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.check_rounded, color: achievement.color, size: 20),
            ),
        ],
      ),
    );
  }

  void _showStatsDialog() {
    final isDark = _isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1E2040), const Color(0xFF0A0A1A)]
                    : [Colors.white, Colors.grey.shade50],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(isDark ? 0.15 : 0.08),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade500, Colors.grey.shade700],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.deepOrange],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.analytics, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Статистика за 10 дней',
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _last10DaysStats.length,
                    itemBuilder: (ctx, index) {
                      final stat = _last10DaysStats[index];
                      final isToday = index == 0;
                      final progress = (stat.steps / _dailyGoal).clamp(0.0, 1.0);
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 350 + (index * 60)),
                        curve: Curves.easeOutBack,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isToday
                                ? [Colors.orange.withOpacity(isDark ? 0.2 : 0.08), isDark ? const Color(0xFF151932) : Colors.white]
                                : [isDark ? const Color(0xFF151932) : Colors.white, isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade50],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isToday
                                ? Colors.orange.withOpacity(0.3)
                                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isToday
                                    ? const LinearGradient(
                                  colors: [Colors.orange, Colors.deepOrange],
                                )
                                    : LinearGradient(
                                  colors: [
                                    isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                                    isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100,
                                  ],
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _formatDayName(stat.date),
                                    style: TextStyle(
                                      color: isToday ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade600),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${stat.date.day}',
                                    style: TextStyle(
                                      color: isToday ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${stat.steps} шагов',
                                    style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${stat.activeMinutes} мин активности',
                                    style: TextStyle(
                                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isToday ? Colors.orange : const Color(0xFF4CAF50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (stat.steps > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isToday
                                        ? [Colors.orange.withOpacity(0.3), Colors.deepOrange.withOpacity(0.1)]
                                        : [const Color(0xFF4CAF50).withOpacity(0.3), const Color(0xFF4CAF50).withOpacity(0.1)],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  '${(progress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: isToday ? Colors.orange : const Color(0xFF4CAF50),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
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
      ),
    );
  }

  String _formatDayName(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) return 'СЕГ';
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.day == yesterday.day && date.month == yesterday.month) return 'ВЧЕ';
    const weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    return weekdays[date.weekday - 1];
  }

  // 🔥 Хелперы для цветов темы
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF0A0A1A) : Colors.white;
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _surfaceColor2 => _isDarkMode ? const Color(0xFF151932) : Colors.grey.shade50;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600;
  Color get _borderColor => _isDarkMode ? Colors.white.withOpacity(0.06) : Colors.grey.shade200;
  Color get _dividerColor => _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade300;

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Text('Загрузка шагомера...',
                  style: TextStyle(color: _subTextColor, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    if (_showJourney) return _buildJourneyView();
    if (_permissionDenied) return _buildPermissionDenied();
    return _buildMainView();
  }

  Widget _buildPermissionDenied() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(_isDarkMode ? 0.2 : 0.1),
                      Colors.deepOrange.withOpacity(_isDarkMode ? 0.1 : 0.05),
                    ],
                  ),
                ),
                child: Icon(Icons.sensors_off_rounded,
                    size: 52, color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
              ),
              const SizedBox(height: 28),
              Text('Доступ к шагомеру отклонён',
                  style: TextStyle(
                      color: _textColor, fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('Разрешите доступ в настройках телефона\nдля подсчёта шагов',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _subTextColor, fontSize: 14)),
              const SizedBox(height: 36),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    final granted = await _checkAndRequestAllPermissions();
                    if (granted) {
                      await _startServiceAndListen();
                      setState(() => _permissionDenied = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Попробовать снова',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _backgroundColor,
          appBar: _buildAppBar(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            children: [
              _buildHeroStepCounter(),
              const SizedBox(height: 28),
              _buildRings(),
              const SizedBox(height: 28),
              _buildPeriodCards(),
              const SizedBox(height: 28),
              _buildLevelCard(),
              const SizedBox(height: 28),
              _buildAchievementsCard(),
              const SizedBox(height: 28),
              _buildActiveTimeCard(),
              const SizedBox(height: 28),
              _buildWeeklyComparisonCard(),
              const SizedBox(height: 28),
              _buildForecast(),
              if (_bestDay > 0) ...[
                const SizedBox(height: 28),
                _buildRecord(),
              ],
              const SizedBox(height: 28),
              _buildWeeklyChart(),
              const SizedBox(height: 28),
              _buildActivityFeed(),
              if (_todaySteps < _dailyGoal) ...[
                const SizedBox(height: 28),
                _buildReminder(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
        // 🔥 Конфетти
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2,
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [Colors.orange, Colors.amber, Colors.red, Colors.green, Colors.blue],
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.deepOrange],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_walk, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('',
              style: TextStyle(
                  color: _textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.orange, size: 20),
            onPressed: _showPermissionsInfo,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.withOpacity(_isDarkMode ? 0.25 : 0.15),
                Colors.deepOrange.withOpacity(_isDarkMode ? 0.1 : 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: TextButton.icon(
            onPressed: () => setState(() => _showJourney = true),
            icon: const Icon(Icons.map_rounded, color: Colors.orange, size: 18),
            label: const Text('Путешествие',
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  void _showPermissionsInfo() {
    final isDark = _isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151932) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.info_outline, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text('ℹ️ Информация', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Шагомер работает даже при закрытом приложении!\n\nДля этого необходимы разрешения:',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 16),
            _buildPermissionStatusItem('Физическая активность', 'Для подсчёта шагов в фоне', Permission.activityRecognition),
            const SizedBox(height: 8),
            _buildPermissionStatusItem('Местоположение', 'Для фоновой работы', Permission.locationAlways),
            const SizedBox(height: 8),
            _buildPermissionStatusItem('Уведомления', 'Для статуса шагомера', Permission.notification),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(isDark ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.battery_charging_full, color: Colors.orange, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Отключите оптимизацию батареи для стабильной работы',
                      style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Закрыть', style: TextStyle(color: Colors.orange)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.deepOrange],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Открыть настройки',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatusItem(String name, String description, Permission permission) {
    final isDark = _isDarkMode;
    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (ctx, snapshot) {
        final isGranted = snapshot.data?.isGranted ?? false;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isGranted
                      ? const Color(0xFF4CAF50).withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                ),
                child: Icon(
                  isGranted ? Icons.check_circle : Icons.cancel,
                  color: isGranted ? const Color(0xFF4CAF50) : Colors.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                    Text(description,
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroStepCounter() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _walkingGlowAnimation]),
      builder: (_, child) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isWalking
                  ? [Colors.orange.withOpacity(_isDarkMode ? 0.3 : 0.15), _surfaceColor, _isDarkMode ? const Color(0xFF0F0F1A) : Colors.grey.shade50]
                  : [_surfaceColor, _surfaceColor2, _isDarkMode ? const Color(0xFF0F0F1A) : Colors.grey.shade50],
            ),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: _isWalking ? Colors.orange.withOpacity(0.4) : _borderColor,
            ),
            boxShadow: _isWalking
                ? [BoxShadow(color: Colors.orange.withOpacity(_walkingGlowAnimation.value), blurRadius: 40, spreadRadius: 8)]
                : [],
          ),
          child: Column(
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: _previousTodaySteps, end: _todaySteps),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, value, child) {
                  return ShaderMask(
                    shaderCallback: (b) => LinearGradient(
                      colors: _isWalking ? [Colors.orange, Colors.deepOrange] : [_textColor, _subTextColor],
                    ).createShader(b),
                    child: Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 88,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        letterSpacing: -4,
                        height: 1,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text('шагов сегодня',
                  style: TextStyle(color: _subTextColor, fontSize: 17, letterSpacing: 0.5)),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _stepProgress,
                  minHeight: 10,
                  backgroundColor: _isDarkMode ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isWalking ? Colors.orange : Colors.orange.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_stepProgress * 100).toInt()}%',
                    style: TextStyle(
                      color: _isWalking ? Colors.orange : Colors.orange.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('цель $_dailyGoal', style: TextStyle(color: _subTextColor, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: _isWalking
                      ? LinearGradient(colors: [const Color(0xFF4CAF50).withOpacity(0.2), const Color(0xFF4CAF50).withOpacity(0.05)])
                      : LinearGradient(colors: [_isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, _isDarkMode ? Colors.white.withOpacity(0.02) : Colors.grey.shade50]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isWalking ? const Color(0xFF4CAF50).withOpacity(0.3) : _borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isWalking ? const Color(0xFF4CAF50) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isWalking ? 'Идём! Продолжайте движение' : 'Вы отдыхаете',
                      style: TextStyle(
                        color: _isWalking ? const Color(0xFF4CAF50) : (_isDarkMode ? Colors.grey : Colors.grey.shade600),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

  Widget _buildRings() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ringCard('Шаги', _stepProgress, '$_todaySteps', Icons.directions_walk, Colors.orange),
        _ringCard('Км', _kmProgress, _todayKm.toStringAsFixed(1), Icons.straighten, const Color(0xFF4A90E2)),
        _ringCard('Ккал', _kcalProgress, '$_todayKcal', Icons.local_fire_department, const Color(0xFFFF9800)),
      ],
    );
  }

  Widget _ringCard(String label, double progress, String value, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _ringsAnimController,
      builder: (_, child) {
        final ap = (progress * _ringsAnimController.value).clamp(0.0, 1.0);
        return Column(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 10,
                    color: _isDarkMode ? Colors.white.withOpacity(0.04) : Colors.grey.shade200,
                  ),
                  CircularProgressIndicator(
                    value: ap,
                    strokeWidth: 10,
                    color: color,
                    backgroundColor: Colors.transparent,
                    strokeCap: StrokeCap.round,
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                      ),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: _subTextColor, fontSize: 12)),
          ],
        );
      },
    );
  }

  Widget _buildPeriodCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _periodCard('НЕДЕЛЯ', '$_weeklySteps шагов', '${_weeklyKm.toStringAsFixed(1)} км',
                  Icons.calendar_view_week, const Color(0xFF4A90E2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _periodCard('МЕСЯЦ', '$_monthlySteps шагов', '${_monthlyKm.toStringAsFixed(1)} км',
                  Icons.calendar_month, const Color(0xFF4CAF50)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _periodCardFull('ВСЁ ВРЕМЯ', '$_totalSteps шагов', '${_walkedKm.toStringAsFixed(1)} км',
            Icons.trending_up, const Color(0xFFFF9800)),
      ],
    );
  }

  Widget _periodCard(String title, String steps, String km, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(_isDarkMode ? 0.08 : 0.04), _surfaceColor2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(steps,
              style: TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(km, style: TextStyle(color: _subTextColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _periodCardFull(String title, String steps, String km, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(_isDarkMode ? 0.08 : 0.04), _surfaceColor2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(steps,
                  style: TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(km, style: TextStyle(color: _subTextColor, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withOpacity(_isDarkMode ? 0.12 : 0.06), _surfaceColor2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.deepPurple],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text('УРОВЕНЬ $_level',
                  style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('$_achievementPoints AP',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_experience % 50000) / 50000,
              minHeight: 8,
              backgroundColor: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          ),
          const SizedBox(height: 8),
          Text('${50000 - (_experience % 50000)} шагов до уровня ${_level + 1}',
              style: TextStyle(color: _subTextColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAchievementsCard() {
    return GestureDetector(
      onTap: _showAchievements,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.withOpacity(_isDarkMode ? 0.12 : 0.06), _surfaceColor2],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text('🏆 ДОСТИЖЕНИЯ',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_unlockedAchievements.length}/${_allAchievements.length}',
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _miniAchievement(icon: Icons.local_fire_department, value: '$_bestStreak дн.', label: 'Серия', unlocked: _bestStreak >= 3),
                const SizedBox(width: 10),
                _miniAchievement(icon: Icons.flag_rounded, value: '$_bestDay', label: 'Рекорд', unlocked: _bestDay >= 10000),
                const SizedBox(width: 10),
                _miniAchievement(icon: Icons.star_rounded, value: '$_daysWithGoal/7', label: 'Цели', unlocked: _daysWithGoal >= 3),
                const SizedBox(width: 10),
                _miniAchievement(icon: Icons.rocket_launch_rounded, value: '${_walkedKm.toStringAsFixed(0)} км', label: 'Всего', unlocked: _walkedKm >= 5),
              ],
            ),
          ],
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
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unlocked
              ? Colors.orange.withOpacity(_isDarkMode ? 0.1 : 0.05)
              : (_isDarkMode ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked ? Colors.orange.withOpacity(0.3) : _borderColor,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: unlocked ? Colors.orange : (_isDarkMode ? Colors.grey : Colors.grey.shade400), size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: unlocked ? _textColor : (_isDarkMode ? Colors.grey : Colors.grey.shade500), fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: TextStyle(color: unlocked ? (_isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600) : (_isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTimeCard() {
    return GestureDetector(
      onTap: _showStatsDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF4CAF50).withOpacity(_isDarkMode ? 0.1 : 0.05), _surfaceColor2],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF4CAF50).withOpacity(0.25), const Color(0xFF4CAF50).withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.timer_rounded, color: Color(0xFF4CAF50), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('АКТИВНОЕ ВРЕМЯ',
                      style: TextStyle(color: const Color(0xFF4CAF50).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text('$_activeMinutes мин',
                      style: TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('ходьбы сегодня', style: TextStyle(color: _subTextColor, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chevron_right_rounded, color: _isDarkMode ? Colors.grey : Colors.grey.shade500, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyComparisonCard() {
    final lastWeekSteps = (_weeklySteps * 0.8).round();
    final diff = _weeklySteps - lastWeekSteps;
    final diffPercent = lastWeekSteps > 0 ? ((diff / lastWeekSteps) * 100).round() : 0;
    final isPositive = diff >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF9C27B0).withOpacity(_isDarkMode ? 0.1 : 0.05), _surfaceColor2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE040FB)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('СРАВНЕНИЕ С ПРОШЛОЙ НЕДЕЛЕЙ',
                  style: TextStyle(color: Color(0xFFCE93D8), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('$_weeklySteps', style: TextStyle(color: _textColor, fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('эта неделя', style: TextStyle(color: _subTextColor, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isPositive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: isPositive ? Colors.green : Colors.red, size: 28),
                    const SizedBox(height: 4),
                    Text('${isPositive ? '+' : ''}$diffPercent%',
                        style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('$lastWeekSteps', style: TextStyle(color: _textColor, fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('прошлая неделя', style: TextStyle(color: _subTextColor, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForecast() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4A90E2).withOpacity(_isDarkMode ? 0.1 : 0.05), _surfaceColor2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF4A90E2).withOpacity(0.25), const Color(0xFF4A90E2).withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.trending_up_rounded, color: Color(0xFF4A90E2), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ПРОГНОЗ НА МЕСЯЦ',
                    style: TextStyle(color: const Color(0xFF4A90E2).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('Если так пойдёт — ${_monthlyProjection.toStringAsFixed(0)} км',
                    style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecord() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.withOpacity(_isDarkMode ? 0.1 : 0.05), _surfaceColor2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ЛИЧНЫЙ РЕКОРД',
                    style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('$_bestDay шагов', style: TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(_bestDayDate, style: TextStyle(color: _subTextColor, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.orange, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final today = DateTime.now().weekday - 1;
    final maxSteps = max(_dailyHistory.reduce((a, b) => a > b ? a : b), 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surfaceColor, _surfaceColor2],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bar_chart_rounded, color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 10),
            Text('ЗА НЕДЕЛЮ',
                style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$_weeklySteps шагов',
                  style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 28),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final steps = _dailyHistory[i];
                final h = maxSteps > 0 ? (steps / maxSteps * 100).clamp(6.0, 100.0) : 6.0;
                final isToday = i == today;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 400),
                          opacity: steps > 0 ? 1.0 : 0.0,
                          child: Text(
                            steps > 0 ? (steps > 999 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps') : '',
                            style: TextStyle(
                              color: isToday ? Colors.orange : _subTextColor,
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            width: double.infinity,
                            height: h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isToday
                                    ? [Colors.orange, Colors.orange.withOpacity(0.3)]
                                    : [Colors.orange.withOpacity(0.4), Colors.orange.withOpacity(0.15)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(dayNames[i],
                            style: TextStyle(
                              color: isToday ? _textColor : _subTextColor,
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    final Map<String, List<String>> groupedByDay = {};
    for (final entry in _activityFeed) {
      String dayKey = 'Ранее';
      if (entry.length >= 5 && entry.contains('.')) {
        dayKey = entry.substring(0, 5);
      }
      groupedByDay.putIfAbsent(dayKey, () => []).add(entry);
    }
    final sortedDays = groupedByDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ActivityLogScreen(feed: _activityFeed)),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_surfaceColor, _surfaceColor2]),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timeline_rounded, color: Color(0xFF4CAF50), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('АКТИВНОСТЬ',
                  style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.open_in_full_rounded, color: Color(0xFF4CAF50), size: 18),
              ),
            ]),
            if (_activityFeed.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...sortedDays.take(3).map((day) {
                final entries = groupedByDay[day]!;
                final isToday = day == _getTodayDateString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 10, height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: isToday ? const Color(0xFF4CAF50) : Colors.grey),
                          ),
                          const SizedBox(width: 10),
                          Text(isToday ? 'СЕГОДНЯ' : day,
                              style: TextStyle(color: isToday ? const Color(0xFF4CAF50) : Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${entries.length} зап.', style: TextStyle(color: _subTextColor, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...entries.take(2).map((entry) {
                        final time = entry.length >= 11 ? entry.substring(6, 11) : '';
                        final text = entry.length > 17 ? entry.substring(17) : entry;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6, left: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(time,
                                  style: TextStyle(color: _subTextColor, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(text, style: TextStyle(color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 12))),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text('Нет активности за сегодня', style: TextStyle(color: _subTextColor, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}';
  }

  Widget _buildReminder() {
    final remaining = _dailyGoal - _todaySteps;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.withOpacity(_isDarkMode ? 0.12 : 0.06), _surfaceColor2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('НЕ ЗАБУДЬТЕ',
                    style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('Осталось $remaining шагов до цели! Прогуляйтесь! 🚶',
                    style: TextStyle(color: _textColor, fontSize: 15, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyView() {
    return JourneyView(
      walkedKm: _walkedKm,
      totalSteps: _totalSteps,
      onBack: () => setState(() => _showJourney = false),
    );
  }
}

// 🔥 Модель достижения
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

  DayStats({required this.date, required this.steps, required this.activeMinutes});
}