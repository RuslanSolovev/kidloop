import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
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

  late AnimationController _numberAnimController;
  late AnimationController _ringsAnimController;
  late AnimationController _pulseController;
  late AnimationController _walkingGlowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _walkingGlowAnimation;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _walkingGlowAnimation = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _walkingGlowController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    await _loadData();
    await _loadLast10DaysStats();

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
    _inactivityTimer?.cancel();
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

  // ... (остальные методы _checkAndRequestAllPermissions, _loadData, и т.д. остаются без изменений)

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151932),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('⚠️ Требуются разрешения',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Для корректной работы шагомера необходимо:',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ...deniedPermissions.map((perm) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Color(0xFFFF6B6B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(perm, style: const TextStyle(color: Colors.white))),
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
            child: const Text('Позже', style: TextStyle(color: Colors.grey)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
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
          final savedFeed = prefs.getString('activity_feed');
          if (savedFeed != null && savedFeed.isNotEmpty) {
            _activityFeed = savedFeed.split('\n').take(50).toList();
          }
        });
        if (stepsDiff > 0) {
          _animateNumber();
          _checkMilestones();
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
      }
    } catch (e) {}
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
      final savedFeed = prefs.getString('activity_feed');
      _activityFeed = (savedFeed != null && savedFeed.isNotEmpty)
          ? savedFeed.split('\n').take(50).toList()
          : [];
      _numberAnimController.value = 1.0;
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
          backgroundColor: const Color(0xFFFF6B6B),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _showStatsDialog() {
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
                colors: [
                  const Color(0xFF1E2040),
                  const Color(0xFF0A0A1A),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.1),
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
                      colors: [
                        Colors.grey.shade500,
                        Colors.grey.shade700,
                      ],
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
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.analytics, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Статистика за 10 дней',
                          style: TextStyle(
                              color: Colors.white,
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
                                ? [
                              const Color(0xFFFF6B6B).withOpacity(0.15),
                              const Color(0xFF151932),
                            ]
                                : [
                              const Color(0xFF151932),
                              const Color(0xFF0F0F1A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isToday
                                ? const Color(0xFFFF6B6B).withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
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
                                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                                )
                                    : LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.08),
                                    Colors.white.withOpacity(0.03),
                                  ],
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _formatDayName(stat.date),
                                    style: TextStyle(
                                      color: isToday ? Colors.white : Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${stat.date.day}',
                                    style: TextStyle(
                                      color: isToday ? Colors.white : Colors.white,
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
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${stat.activeMinutes} мин активности',
                                    style: TextStyle(
                                        color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: Colors.white.withOpacity(0.08),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isToday
                                            ? const Color(0xFFFF6B6B)
                                            : const Color(0xFF4CAF50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (stat.steps > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isToday
                                        ? [
                                      const Color(0xFFFF6B6B).withOpacity(0.3),
                                      const Color(0xFFFF8E8E).withOpacity(0.1),
                                    ]
                                        : [
                                      const Color(0xFF4CAF50).withOpacity(0.3),
                                      const Color(0xFF4CAF50).withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  '${(progress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: isToday
                                        ? const Color(0xFFFF6B6B)
                                        : const Color(0xFF4CAF50),
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

  // Геттеры
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
        backgroundColor: const Color(0xFF0A0A1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Загрузка шагомера...',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
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
      backgroundColor: const Color(0xFF0A0A1A),
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
                      Colors.grey.shade800.withOpacity(0.3),
                      Colors.grey.shade900.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Icon(Icons.sensors_off_rounded,
                    size: 52, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 28),
              const Text('Доступ к шагомеру отклонён',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('Разрешите доступ в настройках телефона\nдля подсчёта шагов',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              const SizedBox(height: 36),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroStepCounter(),
          const SizedBox(height: 28),
          _buildRings(),
          const SizedBox(height: 28),
          _buildPeriodCards(),
          const SizedBox(height: 28),
          _buildActiveTimeCard(),
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
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_walk, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Шагомер',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFFFF6B6B), size: 20),
            onPressed: _showPermissionsInfo,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF6B6B).withOpacity(0.25),
                const Color(0xFFFF8E8E).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
          ),
          child: TextButton.icon(
            onPressed: () => setState(() => _showJourney = true),
            icon: const Icon(Icons.map_rounded, color: Color(0xFFFF6B6B), size: 18),
            label: const Text('Путешествие',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151932),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.info_outline, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('ℹ️ Информация', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Шагомер работает даже при закрытом приложении!\n\nДля этого необходимы разрешения:',
              style: TextStyle(color: Colors.white70),
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
                color: const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.battery_charging_full, color: Color(0xFFFF9800), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Отключите оптимизацию батареи для стабильной работы',
                      style: TextStyle(color: Color(0xFFFFCC80), fontSize: 12),
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
            child: const Text('Закрыть', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
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
    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (ctx, snapshot) {
        final isGranted = snapshot.data?.isGranted ?? false;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
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
                      : const Color(0xFFFF6B6B).withOpacity(0.2),
                ),
                child: Icon(
                  isGranted ? Icons.check_circle : Icons.cancel,
                  color: isGranted ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(description,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                  ? [
                const Color(0xFFFF6B6B).withOpacity(0.25),
                const Color(0xFF1A1A2E),
                const Color(0xFF0F0F1A),
              ]
                  : [
                const Color(0xFF1A1A2E),
                const Color(0xFF151932),
                const Color(0xFF0F0F1A),
              ],
            ),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: _isWalking
                  ? const Color(0xFFFF6B6B).withOpacity(0.35)
                  : Colors.white.withOpacity(0.06),
            ),
            boxShadow: _isWalking
                ? [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(_walkingGlowAnimation.value),
                blurRadius: 40,
                spreadRadius: 8,
              )
            ]
                : [],
          ),
          child: Column(
            children: [
              // Анимированный счётчик
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: _previousTodaySteps, end: _todaySteps),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, value, child) {
                  return ShaderMask(
                    shaderCallback: (b) => LinearGradient(
                      colors: _isWalking
                          ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)]
                          : [Colors.white, const Color(0xFFCCCCCC)],
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
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 17, letterSpacing: 0.5)),
              const SizedBox(height: 20),

              // Прогресс-бар
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _stepProgress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isWalking ? const Color(0xFFFF6B6B) : const Color(0xFFFF6B6B).withOpacity(0.7),
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
                      color: _isWalking ? const Color(0xFFFF6B6B) : const Color(0xFFFF6B6B).withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'цель $_dailyGoal',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),

              // Статус ходьбы
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: _isWalking
                      ? LinearGradient(
                    colors: [
                      const Color(0xFF4CAF50).withOpacity(0.2),
                      const Color(0xFF4CAF50).withOpacity(0.05),
                    ],
                  )
                      : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isWalking
                        ? const Color(0xFF4CAF50).withOpacity(0.3)
                        : Colors.white.withOpacity(0.05),
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
                        color: _isWalking ? const Color(0xFF4CAF50) : Colors.grey,
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
        _ringCard('Шаги', _stepProgress, '$_todaySteps', Icons.directions_walk, const Color(0xFFFF6B6B)),
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
                    color: Colors.white.withOpacity(0.04),
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
                        colors: [
                          color.withOpacity(0.2),
                          color.withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
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
              child: _periodCard('НЕДЕЛЯ', '$_weeklySteps', '${_weeklyKm.toStringAsFixed(1)} км',
                  Icons.calendar_view_week, const Color(0xFF4A90E2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _periodCard('МЕСЯЦ', '$_monthlySteps', '${_monthlyKm.toStringAsFixed(1)} км',
                  Icons.calendar_month, const Color(0xFF4CAF50)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _periodCardFull('ВСЁ ВРЕМЯ', '$_totalSteps', '${_walkedKm.toStringAsFixed(1)} км',
            Icons.trending_up, const Color(0xFFFF9800)),
      ],
    );
  }

  Widget _periodCard(String title, String steps, String km, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            const Color(0xFF151932).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 14),
          Text(steps,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(km, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _periodCardFull(String title, String steps, String km, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            const Color(0xFF151932).withOpacity(0.5),
          ],
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
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text(steps,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(km, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ],
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
            colors: [
              const Color(0xFF4CAF50).withOpacity(0.1),
              const Color(0xFF151932).withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4CAF50).withOpacity(0.25),
                    const Color(0xFF4CAF50).withOpacity(0.1),
                  ],
                ),
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
                      style: TextStyle(
                          color: const Color(0xFF4CAF50).withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text('$_activeMinutes мин',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('ходьбы сегодня',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecast() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4A90E2).withOpacity(0.1),
            const Color(0xFF151932).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4A90E2).withOpacity(0.25),
                  const Color(0xFF4A90E2).withOpacity(0.1),
                ],
              ),
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
                    style: TextStyle(
                        color: const Color(0xFF4A90E2).withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(
                  'Если так пойдёт — ${_monthlyProjection.toStringAsFixed(0)} км',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
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
          colors: [
            const Color(0xFFFF9800).withOpacity(0.1),
            const Color(0xFF151932).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF9800).withOpacity(0.25),
                  const Color(0xFFFF9800).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFF9800), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ЛИЧНЫЙ РЕКОРД',
                    style: TextStyle(
                        color: const Color(0xFFFF9800).withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('$_bestDay шагов',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(_bestDayDate,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium, color: Color(0xFFFF9800), size: 28),
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
          colors: [
            const Color(0xFF1A1A2E).withOpacity(0.8),
            const Color(0xFF151932).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bar_chart_rounded, color: Color(0xFFFF6B6B), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('ЗА НЕДЕЛЮ',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$_weeklySteps шагов',
                  style: TextStyle(color: const Color(0xFFFF6B6B).withOpacity(0.8), fontSize: 12)),
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
                              color: isToday ? const Color(0xFFFF6B6B) : Colors.grey.shade600,
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
                                    ? [const Color(0xFFFF6B6B), const Color(0xFFFF6B6B).withOpacity(0.3)]
                                    : [const Color(0xFFFF6B6B).withOpacity(0.4), const Color(0xFFFF6B6B).withOpacity(0.15)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          dayNames[i],
                          style: TextStyle(
                            color: isToday ? Colors.white : Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
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
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A2E).withOpacity(0.8),
              const Color(0xFF151932).withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                  style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
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
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToday ? const Color(0xFF4CAF50) : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isToday ? 'СЕГОДНЯ' : day,
                            style: TextStyle(
                              color: isToday ? const Color(0xFF4CAF50) : Colors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${entries.length} зап.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
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
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(time,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(text,
                                    style: TextStyle(
                                        color: Colors.grey.shade300, fontSize: 12)),
                              ),
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
                child: Text('Нет активности за сегодня',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.12),
            const Color(0xFF151932).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B6B).withOpacity(0.25),
                  const Color(0xFFFF6B6B).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFFF6B6B), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('НЕ ЗАБУДЬТЕ',
                    style: TextStyle(
                        color: const Color(0xFFFF6B6B).withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(
                  'Осталось $remaining шагов до цели! Прогуляйтесь! 🚶',
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
                ),
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

class DayStats {
  final DateTime date;
  final int steps;
  final int activeMinutes;

  DayStats({required this.date, required this.steps, required this.activeMinutes});
}