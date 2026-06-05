import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================================
// 🚶 ЭКРАН ШАГОМЕРА — ПОЛНАЯ ВЕРСИЯ С ФОНОВОЙ РАБОТОЙ
// ============================================================================

class PedometerScreen extends StatefulWidget {
  const PedometerScreen({super.key});

  @override
  State<PedometerScreen> createState() => _PedometerScreenState();
}

class _PedometerScreenState extends State<PedometerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ─── Счётчики шагов ──────────────────────────────────────────────────────
  int _todaySteps = 0;
  int _weeklySteps = 0;
  int _monthlySteps = 0;
  int _totalSteps = 0;
  bool _isWalking = false;
  bool _permissionDenied = false;
  bool _isLoading = true;

  // ─── История и рекорды ───────────────────────────────────────────────────
  List<int> _dailyHistory = [0, 0, 0, 0, 0, 0, 0];
  List<String> _activityFeed = [];
  int _bestDay = 0;
  String _bestDayDate = '';

  // ─── Активное время ──────────────────────────────────────────────────────
  int _activeMinutes = 0;

  // ─── Дневная статистика (последние 10 дней) ──────────────────────────────
  List<DayStats> _last10DaysStats = [];

  // ─── Анимации ────────────────────────────────────────────────────────────
  late AnimationController _numberAnimController;
  late AnimationController _ringsAnimController;

  // ─── Подписки и таймеры ──────────────────────────────────────────────────
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  Timer? _pollTimer;
  Timer? _inactivityTimer;
  Timer? _midnightTimer;
  bool _showJourney = false;

  // ─── Предыдущие значения для отслеживания изменений ─────────────────────
  int _previousTodaySteps = 0;
  int _previousTotalSteps = 0;

  // ─── Константы ───────────────────────────────────────────────────────────
  static const double _stepLength = 0.75;
  static const int _totalDistance = 9300;
  static const int _dailyGoal = 10000;
  static const Duration _pollInterval = Duration(seconds: 2);

  // ==========================================================================
  // ЖИЗНЕННЫЙ ЦИКЛ
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _numberAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _ringsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Сначала загружаем данные
    await _loadData();
    await _loadLast10DaysStats();

    // Запрашиваем разрешения с таймаутом
    final allGranted = await _checkAndRequestAllPermissions().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('⚠️ Таймаут запроса разрешений, продолжаем...');
        return true; // Продолжаем работу даже если разрешения не все получены
      },
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

  // ==========================================================================
  // ПРОВЕРКА И ЗАПРОС ВСЕХ РАЗРЕШЕНИЙ СРАЗУ
  // ==========================================================================

  Future<bool> _checkAndRequestAllPermissions() async {
    if (!Platform.isAndroid) return true;

    print('🔍 Запрос всех разрешений для шагомера...');

    // Запрашиваем только критичные разрешения
    Map<Permission, PermissionStatus> statuses = await [
      Permission.activityRecognition,
      Permission.locationWhenInUse, // Только in use, не always
    ].request();

    // Проверяем результаты
    bool allGranted = true;
    List<String> deniedPermissions = [];

    if (statuses[Permission.activityRecognition]?.isGranted != true) {
      deniedPermissions.add('Физическая активность');
      allGranted = false;
    }

    if (statuses[Permission.locationWhenInUse]?.isGranted != true) {
      deniedPermissions.add('Местоположение');
      // Не критично для шагомера на большинстве устройств
      print('⚠️ Местоположение не получено, но продолжаем');
    }

    // Запрашиваем battery optimization в фоне, без ожидания
    _requestBatteryOptimizationAsync();

    // Пытаемся запросить notification (не критично)
    if (await Permission.notification.isDenied) {
      Permission.notification.request();
    }

    if (!allGranted && deniedPermissions.contains('Физическая активность')) {
      print('⚠️ Критичные разрешения не получены');
      _showAllPermissionsDialog(deniedPermissions);
      return false;
    }

    print('✅ Минимальные разрешения получены!');
    return true;
  }

// Асинхронный запрос battery optimization
  void _requestBatteryOptimizationAsync() async {
    try {
      const platform = MethodChannel('com.example.kid_loop/step_counter');
      await platform.invokeMethod('requestIgnoreBattery');
      print('✅ Запрошено игнорирование оптимизации батареи');
    } catch (e) {
      print('❌ Ошибка запроса игнорирования батареи: $e');
    }
  }

  void _showAllPermissionsDialog(List<String> deniedPermissions) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('⚠️ Требуются разрешения',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Для корректной работы шагомера необходимо:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ...deniedPermissions.map((perm) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: Color(0xFFFF6B6B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(perm, style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              const Text(
                'Пожалуйста, включите все разрешения в настройках телефона.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _permissionDenied = true);
            },
            child: const Text('Позже', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Открыть настройки',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ЗАПУСК СЕРВИСА И ОПРОС ДАННЫХ
  // ==========================================================================

  Future<void> _startServiceAndListen() async {
    // Запускаем фоновый сервис
    try {
      const platform = MethodChannel('com.example.kid_loop/step_counter');
      await platform.invokeMethod('startService');
      print('✅ Фоновый сервис шагомера запущен');
    } catch (e) {
      print('❌ Ошибка запуска сервиса: $e');
      return;
    }

    // Даем сервису время инициализироваться
    await Future.delayed(const Duration(milliseconds: 500));

    // Подписываемся только на статус ходьбы (шаги будут из SharedPreferences)
    try {
      _statusSubscription = Pedometer.pedestrianStatusStream.listen(
            (event) {
          if (mounted) setState(() => _isWalking = event.status == 'walking');
        },
        onError: (error) {
          print("Ошибка статуса пешехода: $error");
        },
      );
    } catch (e) {
      print("Ошибка подписки на статус: $e");
    }

    // Загружаем начальные данные
    await _loadDataFromPrefs();

    // Обновляем статистику за 10 дней
    await _loadLast10DaysStats();

    // Запоминаем текущие значения
    _previousTodaySteps = _todaySteps;
    _previousTotalSteps = _totalSteps;

    // Запускаем периодический опрос
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted) {
        _loadDataFromPrefs();
      }
    });
    print('🔄 Опрос данных запущен (каждые ${_pollInterval.inSeconds} сек)');
  }

  // ==========================================================================
  // ЗАГРУЗКА ДАННЫХ ИЗ SHAREDPREFERENCES
  // ==========================================================================

  Future<void> _loadDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final monthKey = _monthlyKey();

      await prefs.reload();

      // Читаем данные БЕЗ префикса flutter. (сервис должен писать так же)
      final newToday = prefs.getInt('today_steps') ?? 0;
      final newWeekly = prefs.getInt('weekly_steps') ?? 0;
      final newMonthly = prefs.getInt(monthKey) ?? 0;
      final newTotal = prefs.getInt('total_steps') ?? 0;
      final newActive = prefs.getInt('active_minutes') ?? 0;

      // Проверяем, изменились ли данные
      if (newToday != _previousTodaySteps ||
          newTotal != _previousTotalSteps ||
          newActive != _activeMinutes) {

        final stepsDiff = newToday - _previousTodaySteps;

        setState(() {
          _todaySteps = newToday;
          _weeklySteps = newWeekly;
          _monthlySteps = newMonthly;
          _totalSteps = newTotal;
          _activeMinutes = newActive;

          // Обновляем историю активности
          final savedFeed = prefs.getString('activity_feed');
          if (savedFeed != null && savedFeed.isNotEmpty) {
            _activityFeed = savedFeed.split('\n').take(50).toList();
          }
        });

        // Анимируем, если есть новые шаги
        if (stepsDiff > 0) {
          _animateNumber();
          _checkMilestones();

          if (_todaySteps > _bestDay) {
            _bestDay = _todaySteps;
            _bestDayDate = DateTime.now().toString().substring(0, 10);
            _saveMeta();
          }

          // Обновляем историю по дням
          final today = DateTime.now().weekday - 1;
          _dailyHistory[today] = _todaySteps;
          _saveDailyHistory();

          _resetInactivityTimer();
        }

        // Обновляем предыдущие значения
        _previousTodaySteps = newToday;
        _previousTotalSteps = newTotal;

        print('📊 UI обновлён: сегодня=$newToday, всего=$newTotal');
      }
    } catch (e) {
      print('❌ Ошибка опроса данных: $e');
    }
  }

  // ==========================================================================
  // ПЕРВИЧНАЯ ЗАГРУЗКА
  // ==========================================================================

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
      if (savedFeed != null && savedFeed.isNotEmpty) {
        _activityFeed = savedFeed.split('\n').take(50).toList();
      } else {
        _activityFeed = [];
      }

      _numberAnimController.value = 1.0;
    });

    print("📊 Загружены данные: сегодня=$_todaySteps, всего=$_totalSteps");
  }

  Future<void> _loadLast10DaysStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // 👈 Добавить эту строку

    final List<DayStats> stats = [];

    for (int i = 0; i < 10; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateKey = 'stats_${date.year}_${date.month}_${date.day}';
      final steps = prefs.getInt(dateKey) ?? 0;
      final minutes = prefs.getInt('${dateKey}_minutes') ?? 0;

      print('📊 Статистика ${date.day}.${date.month}: $steps шагов, $minutes мин');

      stats.add(DayStats(date: date, steps: steps, activeMinutes: minutes));
    }

    setState(() {
      _last10DaysStats = stats;
    });
  }

  // ==========================================================================
  // СОХРАНЕНИЕ МЕТА-ДАННЫХ
  // ==========================================================================

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

  // ==========================================================================
  // ПОЛУНОЧНЫЙ СБРОС
  // ==========================================================================

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = midnight.difference(now);

    _midnightTimer = Timer(durationUntilMidnight, () {
      _resetDailyCounters();
      _scheduleMidnightReset();
    });
  }

  void _resetDailyCounters() async {
    // Сервис сам сохранит вчерашнюю статистику и сбросит счётчики в SharedPreferences
    // Здесь только обновляем UI
    setState(() {
      _todaySteps = 0;
      _activeMinutes = 0;
    });

    // Обновляем статистику за 10 дней
    await _loadLast10DaysStats();

    print('🔄 UI сброшен для нового дня');
  }

  String _monthlyKey() {
    final now = DateTime.now();
    return 'monthly_${now.year}_${now.month}';
  }

  // ==========================================================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ==========================================================================

  String _formatTimeOfDay(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}ч ${minutes}мин';
    } else if (minutes > 0) {
      return '${minutes}мин ${secs}сек';
    } else {
      return '${secs}сек';
    }
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
        content: Text('🎉 Достигли $milestone шагов!'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _animateNumber() {
    _numberAnimController.reset();
    _numberAnimController.forward();
  }

  // ==========================================================================
  // НАПОМИНАНИЯ
  // ==========================================================================

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
          content: Text('Осталось $remaining шагов до цели! Прогуляйтесь! 🚶'),
          backgroundColor: const Color(0xFFFF6B6B),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ==========================================================================
  // ДИАЛОГ СТАТИСТИКИ ЗА 10 ДНЕЙ
  // ==========================================================================

  void _showStatsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Статистика за 10 дней',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _last10DaysStats.length,
                    itemBuilder: (ctx, index) {
                      final stat = _last10DaysStats[index];
                      final isToday = index == 0;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.orange.withOpacity(0.15)
                              : const Color(0xFF0F0F1A),
                          borderRadius: BorderRadius.circular(12),
                          border: isToday
                              ? Border.all(color: Colors.orange, width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Text(
                                    _formatDayName(stat.date),
                                    style: TextStyle(
                                      color: isToday ? Colors.orange : Colors.white70,
                                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    '${stat.date.day}',
                                    style: TextStyle(
                                      color: isToday ? Colors.orange : Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_walk, size: 16, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${stat.steps} шагов',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.timer, size: 16, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${stat.activeMinutes} мин активности',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (stat.steps > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${(stat.steps / _dailyGoal * 100).toInt()}%',
                                  style: const TextStyle(color: Colors.green, fontSize: 12),
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
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'СЕГОДНЯ';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.day == yesterday.day && date.month == yesterday.month) {
      return 'ВЧЕРА';
    }
    const weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    return weekdays[date.weekday - 1];
  }

  // ==========================================================================
  // ВЫЧИСЛЯЕМЫЕ ЗНАЧЕНИЯ
  // ==========================================================================

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

  // ==========================================================================
  // ГОРОДА
  // ==========================================================================

  City get _currentCity => _cities.lastWhere(
        (c) => c.distanceFromMoscow <= _walkedKm,
    orElse: () => _cities.first,
  );
  final List<City> _cities = _getCities();

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A1A),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B6B)),
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sensors_off, size: 64, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              const Text('Доступ к шагомеру отклонён',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Разрешите в настройках телефона',
                  style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final granted = await _checkAndRequestAllPermissions();
                  if (granted) {
                    await _startServiceAndListen();
                    setState(() => _permissionDenied = false);
                  }
                },
                child: const Text('Попробовать снова'),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Шагомер',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFFFF6B6B)),
            onPressed: _showPermissionsInfo,
          ),
          TextButton.icon(
            onPressed: () => setState(() => _showJourney = true),
            icon: const Icon(Icons.map, color: Color(0xFFFF6B6B)),
            label: const Text('Путешествие',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStepCounter(),
          const SizedBox(height: 20),
          _buildRings(),
          const SizedBox(height: 24),
          _buildPeriodCards(),
          const SizedBox(height: 24),
          _buildActiveTimeCard(),
          const SizedBox(height: 24),
          _buildForecast(),
          const SizedBox(height: 24),
          if (_bestDay > 0) ...[
            _buildRecord(),
            const SizedBox(height: 24),
          ],
          _buildWeeklyChart(),
          const SizedBox(height: 24),
          _buildActivityFeed(),
          const SizedBox(height: 24),
          if (_todaySteps < _dailyGoal) _buildReminder(),
        ],
      ),
    );
  }

  void _showPermissionsInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('ℹ️ Информация', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Шагомер работает даже при закрытом приложении!\n\n'
                  'Для этого необходимы разрешения:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildPermissionStatusItem(
              'Физическая активность',
              'Для подсчёта шагов в фоне',
              Permission.activityRecognition,
            ),
            const SizedBox(height: 8),
            _buildPermissionStatusItem(
              'Местоположение',
              'Для фоновой работы на некоторых устройствах',
              Permission.locationAlways,
            ),
            const SizedBox(height: 8),
            _buildPermissionStatusItem(
              'Уведомления',
              'Для отображения статуса шагомера',
              Permission.notification,
            ),
            const SizedBox(height: 8),
            const Text(
              '⚡ Оптимизация батареи',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Отключите в настройках телефона',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Открыть настройки', style: TextStyle(color: Colors.white)),
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(
                isGranted ? Icons.check_circle : Icons.cancel,
                color: isGranted ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B),
                size: 20,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // ВИДЖЕТЫ
  // ==========================================================================

  Widget _buildStepCounter() {
    return Center(
      child: AnimatedBuilder(
        animation: _numberAnimController,
        builder: (_, child) {
          return Column(
            children: [
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: _isWalking
                      ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)]
                      : [Colors.white, Colors.white70],
                ).createShader(b),
                child: Text(
                  '$_todaySteps',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    letterSpacing: -2,
                  ),
                ),
              ),
              Text('шагов сегодня',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                width: 200,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _stepProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRings() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ringCard('Шаги', _stepProgress, '$_todaySteps', Icons.directions_walk,
            const Color(0xFFFF6B6B)),
        _ringCard('Км', _kmProgress, _todayKm.toStringAsFixed(1),
            Icons.straighten, const Color(0xFF4A90E2)),
        _ringCard('Ккал', _kcalProgress, '$_todayKcal',
            Icons.local_fire_department, const Color(0xFFFF9800)),
      ],
    );
  }

  Widget _ringCard(
      String label, double progress, String value, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _ringsAnimController,
      builder: (_, child) {
        final ap = (progress * _ringsAnimController.value).clamp(0.0, 1.0);
        return Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1, strokeWidth: 6, color: Colors.grey.shade800,
                  ),
                  CircularProgressIndicator(
                    value: ap, strokeWidth: 6, color: color,
                    backgroundColor: Colors.transparent,
                  ),
                  Icon(icon, color: color, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
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
              child: _periodCard('ЗА НЕДЕЛЮ', '$_weeklySteps шагов',
                  '${_weeklyKm.toStringAsFixed(1)} км', Icons.calendar_view_week,
                  const Color(0xFF4A90E2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _periodCard('ЗА МЕСЯЦ', '$_monthlySteps шагов',
                  '${_monthlyKm.toStringAsFixed(1)} км', Icons.calendar_month,
                  const Color(0xFF4CAF50)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _periodCardFull('ЗА ВСЁ ВРЕМЯ', '$_totalSteps шагов',
            '${_walkedKm.toStringAsFixed(1)} км', Icons.trending_up,
            const Color(0xFFFF9800)),
      ],
    );
  }

  Widget _periodCard(
      String title, String steps, String km, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ]),
          const SizedBox(height: 10),
          Text(steps,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          Text(km, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _periodCardFull(
      String title, String steps, String km, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(steps,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(km,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF4CAF50).withOpacity(0.15),
            const Color(0xFF1A1A2E)
          ]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer, color: Color(0xFF4CAF50), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('АКТИВНОЕ ВРЕМЯ СЕГОДНЯ',
                      style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 11,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('$_activeMinutes мин',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text('чистого времени ходьбы',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildForecast() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF4A90E2).withOpacity(0.15),
          const Color(0xFF1A1A2E)
        ]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: Color(0xFF4A90E2), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ПРОГНОЗ НА МЕСЯЦ',
                    style: TextStyle(
                        color: Color(0xFF4A90E2),
                        fontSize: 11,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(
                    'Если так пойдёт — ${_monthlyProjection.toStringAsFixed(0)} км',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecord() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFF9800).withOpacity(0.15),
          const Color(0xFF1A1A2E)
        ]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ЛИЧНЫЙ РЕКОРД',
                    style: TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 11,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('$_bestDay шагов ($_bestDayDate)',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ],
            ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bar_chart, color: Color(0xFFFF6B6B), size: 18),
            const SizedBox(width: 8),
            const Text('ЗА НЕДЕЛЮ',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const Spacer(),
            Text('$_weeklySteps шагов',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final steps = _dailyHistory[i];
                final h = maxSteps > 0
                    ? (steps / maxSteps * 90).clamp(4.0, 90.0)
                    : 4.0;
                final isToday = i == today;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          steps > 0
                              ? (steps > 999
                              ? '${(steps / 1000).toStringAsFixed(1)}k'
                              : '$steps')
                              : '',
                          style: TextStyle(
                            color: isToday
                                ? const Color(0xFFFF6B6B)
                                : Colors.grey.shade500,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Container(
                            width: double.infinity,
                            height: h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isToday
                                    ? [
                                  const Color(0xFFFF6B6B),
                                  const Color(0xFFFF6B6B).withOpacity(0.4)
                                ]
                                    : [
                                  const Color(0xFFFF6B6B).withOpacity(0.4),
                                  const Color(0xFFFF6B6B).withOpacity(0.15)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayNames[i],
                          style: TextStyle(
                            color: isToday
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontSize: 10,
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
    // Группируем записи по дням
    final Map<String, List<String>> groupedByDay = {};

    for (final entry in _activityFeed) {
      // Извлекаем дату из записи (формат: "05.06 12:34 - текст")
      String dayKey = 'Ранее';
      if (entry.length >= 5 && entry.contains('.')) {
        dayKey = entry.substring(0, 5); // "05.06"
      }
      groupedByDay.putIfAbsent(dayKey, () => []).add(entry);
    }

    // Сортируем дни (сначала новые)
    final sortedDays = groupedByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FullActivityScreen(feed: _activityFeed),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.timeline, color: Color(0xFF4CAF50), size: 18),
                  const SizedBox(width: 8),
                  const Text('АКТИВНОСТЬ',
                      style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const Spacer(),
                  const Icon(Icons.open_in_full, color: Color(0xFF4CAF50), size: 16),
                ]),
                if (_activityFeed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Показываем последние 3 дня с записями
                  ...sortedDays.take(3).map((day) {
                    final entries = groupedByDay[day]!;
                    final isToday = day == _getTodayDateString();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isToday ? const Color(0xFF4CAF50) : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isToday ? 'СЕГОДНЯ' : day,
                                style: TextStyle(
                                  color: isToday ? const Color(0xFF4CAF50) : Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${entries.length} зап.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...entries.take(2).map((entry) {
                          // Убираем дату из начала записи для компактности
                          final cleanEntry = entry.length > 17 ? entry.substring(17) : entry;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.substring(6, 11), // "12:34"
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cleanEntry,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Нет активности за сегодня',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}';
  }

  Widget _buildReminder() {
    final remaining = _dailyGoal - _todaySteps;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFF6B6B).withOpacity(0.15),
          const Color(0xFF1A1A2E)
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active,
              color: Color(0xFFFF6B6B), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                'Осталось $remaining шагов до цели! Прогуляйтесь! 🚶',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ПУТЕШЕСТВИЕ
  // ==========================================================================

  Widget _buildJourneyView() {
    final nextIndex = _cities.indexOf(_currentCity) + 1;
    final nextCity = nextIndex < _cities.length ? _cities[nextIndex] : null;
    final progressToNext = nextCity != null
        ? ((_walkedKm - _currentCity.distanceFromMoscow) /
        (nextCity.distanceFromMoscow - _currentCity.distanceFromMoscow))
        .clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFF6B6B)),
          onPressed: () => setState(() => _showJourney = false),
        ),
        title: const Text('Путь к Владивостоку',
            style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _journeyProgressCard(),
          const SizedBox(height: 16),
          _buildCityCard(_currentCity, isCurrent: true),
          if (nextCity != null) ...[
            const SizedBox(height: 12),
            _buildNextCityCard(nextCity, progressToNext),
          ],
          const SizedBox(height: 16),
          _journeyTimeline(),
          const SizedBox(height: 24),
          const Text(
            '«Дорога в тысячу миль начинается с одного шага»',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF8888AA), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _journeyProgressCard() {
    final p = (_walkedKm / _totalDistance).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: [
        Text('${(p * 100).toStringAsFixed(3)}%',
            style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B6B))),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 10,
            backgroundColor: const Color(0xFF2D2D44),
            color: const Color(0xFFFF6B6B),
          ),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _miniStat('👣', '$_totalSteps'),
          _miniStat('📏', '${_walkedKm.toStringAsFixed(1)} км'),
          _miniStat('🎯', '${(_totalDistance - _walkedKm).toStringAsFixed(0)} км'),
        ]),
      ]),
    );
  }

  Widget _buildCityCard(City city, {bool isCurrent = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF16213E) : const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(24),
        border: isCurrent
            ? Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3))
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on,
                color: Color(0xFFFF6B6B), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isCurrent ? '📍 ТЕКУЩАЯ' : city.name,
                  style: TextStyle(
                      color: isCurrent ? const Color(0xFFFF6B6B) : Colors.white,
                      fontSize: isCurrent ? 11 : 20,
                      fontWeight: isCurrent ? FontWeight.normal : FontWeight.bold)),
              if (isCurrent)
                Text(city.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              Text('${city.distanceFromMoscow} км',
                  style: TextStyle(
                      color: isCurrent
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF8888AA),
                      fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        _factRow(city.fact),
        _factRow(city.funFact1),
        _factRow(city.funFact2),
        if (city.cuisine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('🍽️ ${city.cuisine}',
                style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
          ),
      ]),
    );
  }

  Widget _buildNextCityCard(City city, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🎯 СЛЕДУЮЩАЯ',
              style: TextStyle(color: Color(0xFF8888AA), fontSize: 11)),
          const Spacer(),
          Text('${(progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                  color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Text(city.name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        Text('${city.distanceFromMoscow} км',
            style: const TextStyle(color: Color(0xFF8888AA), fontSize: 13)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFF2D2D44),
            color: const Color(0xFFFF6B6B),
          ),
        ),
      ]),
    );
  }

  Widget _journeyTimeline() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12),
        child: Text('🗺️ МАРШРУТ • ${_cities.length} ГОРОДОВ',
            style: const TextStyle(
                color: Color(0xFFFF6B6B), fontSize: 12, letterSpacing: 2)),
      ),
      ..._cities.map((city) {
        final isReached = city.distanceFromMoscow <= _walkedKm;
        return InkWell(
          onTap: () => _showCityInfo(city),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 30, child: Column(children: [
              Container(
                width: city.isMajor ? 20 : 14,
                height: city.isMajor ? 20 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isReached
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF2D2D44),
                ),
                child: isReached && city.isMajor
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : null,
              ),
              if (city != _cities.last)
                Container(
                  width: 2,
                  height: 35,
                  color: isReached
                      ? const Color(0xFFFF6B6B).withOpacity(0.5)
                      : const Color(0xFF2D2D44),
                ),
            ])),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isReached
                      ? const Color(0xFFFF6B6B).withOpacity(0.12)
                      : const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(city.name,
                          style: TextStyle(
                            color: isReached
                                ? const Color(0xFFFF6B6B)
                                : Colors.white,
                            fontSize: city.isMajor ? 14 : 12,
                          )),
                      Text('${city.distanceFromMoscow} км',
                          style: const TextStyle(
                              color: Color(0xFF8888AA), fontSize: 10)),
                    ]),
              ),
            ),
          ]),
        );
      }),
    ]);
  }

  void _showCityInfo(City city) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A1A),
        title: Row(children: [
          Text(city.name,
              style: const TextStyle(
                  color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('(${city.distanceFromMoscow} км)',
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 14)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoSection('📊 ОСНОВНАЯ', [
                '👥 ${city.population}',
                '🗺️ ${city.area}',
                '📅 ${city.founded}',
              ]),
              _infoSection('📜 ИСТОРИЯ', [city.fact]),
              _infoSection('✨ ФАКТЫ', [
                city.funFact1,
                city.funFact2,
                city.funFact3,
                city.funFact4,
              ]),
              if (city.cuisine.isNotEmpty) _infoSection('🍽️', [city.cuisine]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _infoSection(String title, List<String> lines) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11)),
        const SizedBox(height: 8),
        ...lines.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l,
              style: const TextStyle(
                  color: Color(0xFFAAAAAA), fontSize: 13)),
        )),
      ]),
    );
  }

  Widget _miniStat(String emoji, String value) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
    ]);
  }

  Widget _factRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✨ ',
            style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFFAAAAAA), fontSize: 13))),
      ]),
    );
  }

  static List<City> _getCities() {
    return [
      City("Москва", 0, "12,7 млн", "2 561 км²", "1147 г.", "🏛️ Сердце России. Москва — политический, экономический и культурный центр страны.", "Кремль — самая большая средневековая крепость в Европе, её стены протянулись на 2,2 км.", "В Москве 17 действующих вокзалов и 5 аэропортов, а также самое большое метро в Европе.", "Красная площадь — главная площадь страны, здесь находятся Храм Василия Блаженного и Мавзолей.", "Московский Кремль — резиденция президента РФ и объект Всемирного наследия ЮНЕСКО.", "Блины, пельмени, борщ", true),
      City("Балашиха", 22, "520 тыс.", "97 км²", "1830 г.", "🏭 Балашиха — крупнейший город-спутник Москвы, важный промышленный центр.", "В городе находится знаменитая усадьба Пехра-Яковлевское — образец русского классицизма.", "Балашихинский литейно-механический завод — одно из старейших предприятий региона.", "В Балашихе расположен крупнейший в Европе производственный комплекс Coca-Cola.", "Город активно застраивается новыми жилыми комплексами и парковыми зонами.", "", false),
      City("Щёлково", 30, "130 тыс.", "37 км²", "1925 г.", "🏭 Щёлково — текстильная столица региона, здесь работали крупнейшие мануфактуры XIX века.", "В городе находится Щёлковский историко-краеведческий музей с богатой коллекцией.", "Щёлковский район известен своими санаториями и домами отдыха на берегу Клязьмы.", "Здесь расположен аэродром Чкаловский — база военно-транспортной авиации России.", "В окрестностях города находится Медвежьи Озёра — популярное место отдыха москвичей.", "", false),
      City("Фрязино", 35, "60 тыс.", "9 км²", "1951 г.", "🔬 Фрязино — один из первых наукоградов России, центр радиоэлектроники и СВЧ-технологий.", "Здесь расположены ведущие НИИ в области электроники и космической связи.", "В городе находится единственный в России музей радиоэлектроники «Фрязино-наукоград».", "Фрязино — один из самых благоустроенных и компактных городов Подмосковья.", "В парке «Фрязино» проводятся ежегодные фестивали науки и техники.", "", false),
      City("Сергиев Посад", 75, "100 тыс.", "50 км²", "1345 г.", "🏛️ Сергиев Посад — духовная столица России, центр православного паломничества.", "Троице-Сергиева Лавра — крупнейший мужской монастырь страны, объект ЮНЕСКО.", "В городе находится знаменитая Сергиево-Посадская игрушка — народный промысел.", "Здесь работал известный художник Михаил Нестеров, создавший цикл картин о св. Сергии.", "В городе проходят ежегодные ярмарки народных промыслов и фестивали колокольного звона.", "Сергиевские пряники", false),
      City("Орехово-Зуево", 95, "118 тыс.", "47 км²", "1917 г.", "🧵 Орехово-Зуево — родина Морозовской текстильной мануфактуры, крупнейшей в России XIX века.", "В городе находится Саввино-Сторожевский монастырь, основанный учеником Сергия Радонежского.", "Здесь родился и жил знаменитый поэт Николай Заболоцкий.", "В Орехово-Зуеве расположен уникальный мост через Клязьму — памятник инженерной мысли.", "Город известен своими традициями футбола — здесь базируется клуб «Знамя Труда».", "", false),
      City("Владимир", 180, "350 тыс.", "308 км²", "990 г.", "🏰 Владимир — жемчужина Золотого кольца, древняя столица Северо-Восточной Руси.", "Золотые ворота, Успенский и Дмитриевский соборы — объекты Всемирного наследия ЮНЕСКО.", "В городе находится знаменитый Владимирский централ — тюрьма, известная по песне Михаила Круга.", "Здесь работали великие князья Андрей Боголюбский и Всеволод Большое Гнездо.", "Владимир славится своей вишнёвой настойкой и вишнёвыми садами.", "Владимирская вишня", false),
      City("Муром", 300, "110 тыс.", "44 км²", "862 г.", "🏰 Муром — родина былинного богатыря Ильи Муромца.", "Спасо-Преображенский монастырь — древнейший монастырь России, основанный в XI веке.", "В городе находится единственный в России памятник калачу.", "Муром — родина изобретателя телевидения Владимира Зворыкина.", "Каждое лето в Муроме проходит фестиваль «Муромское лето».", "Муромские калачи", false),
      City("Нижний Новгород", 400, "1,2 млн", "460 км²", "1221 г.", "🌅 Нижний Новгород — столица закатов, здесь находится самая длинная лестница в России.", "Нижегородский кремль — неприступная крепость.", "Город — родина изобретателя радио Александра Попова.", "Здесь находится знаменитая Нижегородская ярмарка.", "В городе расположен уникальный музей техники «ГАЗ».", "Нижегородский пряник", true),
      City("Кстово", 440, "66 тыс.", "18 км²", "1957 г.", "🛢️ Кстово — центр нефтепереработки.", "Озеро Святое — место паломничества.", "В окрестностях города расположен Щёлковский хутор.", "Кстово — город-спутник Нижнего Новгорода.", "Здесь находится уникальный храм.", "", false),
      City("Шумерля", 630, "30 тыс.", "13 км²", "1916 г.", "🚂 Шумерля — железнодорожный город.", "Шумерля знаменита своими валенками.", "В городе есть единственный в Чувашии железнодорожный техникум.", "Шумерлинский завод специализируется на оборудовании для ЖД.", "В окрестностях города находится заказник.", "", false),
      City("Чебоксары", 640, "497 тыс.", "233 км²", "1469 г.", "🌉 Чебоксары — жемчужина на Волге.", "46-метровая статуя Мать-покровительница.", "Чебоксарский залив — любимое место отдыха.", "Здесь находится один из крупнейших тракторных заводов.", "Чебоксары — родина космонавта Андрияна Николаева.", "Чебоксарский хмель", false),
      City("Казань", 800, "1,3 млн", "425 км²", "1005 г.", "🕌 Казань — третья столица России.", "Казанский Кремль — объект ЮНЕСКО.", "В городе находится самый большой в Европе цирк.", "Казань — родина Фёдора Шаляпина.", "Казанский университет — один из старейших в России.", "Эчпочмак, чак-чак", true),
      City("Набережные Челны", 1020, "545 тыс.", "171 км²", "1626 г.", "🚚 Набережные Челны — город грузовиков КАМАЗ.", "КАМАЗ — крупнейший в мире производитель.", "В городе работает музей истории КАМАЗа.", "Набережные Челны — один из самых молодых городов.", "В городе расположен парк «Прибрежный».", "", false),
      City("Пермь", 1380, "1,0 млн", "799 км²", "1723 г.", "🎭 Пермь — культурная столица Урала.", "Пермская деревянная скульптура — уникальное явление.", "В городе есть памятник букве «Ё».", "Пермь — родина изобретателя радио.", "Пермский период назван в честь города.", "Пермские пельмени", false),
      City("Екатеринбург", 1800, "1,5 млн", "1 111 км²", "1723 г.", "⛰️ Екатеринбург — столица Урала.", "Здесь находится памятник границе Европы и Азии.", "В городе крупнейший музей за Уралом.", "Екатеринбург — родина Бориса Ельцина.", "Единственный в мире памятник клавиатуре.", "Уральские пельмени", true),
      City("Тюмень", 2100, "830 тыс.", "698 км²", "1586 г.", "🛢️ Тюмень — нефтяная столица России.", "Самый длинный мост в России — Мост Влюблённых.", "Единственный в мире памятник собакам-поводырям.", "Тюменский драмтеатр — один из старейших.", "Город славится термальными источниками.", "", true),
      City("Ишим", 2420, "67 тыс.", "46 км²", "1687 г.", "📖 Ишим — родина автора «Конька-Горбунка».", "Единственный в мире памятник Коньку-Горбунку.", "Ишимский музей — один из лучших.", "Город стоит на Транссибирской магистрали.", "В Ишиме родился Михаил Пришвин.", "", false),
      City("Омск", 2700, "1,1 млн", "572 км²", "1716 г.", "🏰 Омск — врата Сибири.", "Омский драмтеатр — один из старейших.", "Крупнейший в Сибири технический университет.", "Знаменитая Омская ТЭЦ-5.", "Омск — родина актёра Михаила Ульянова.", "", true),
      City("Барабинск", 3050, "30 тыс.", "44 км²", "1893 г.", "🚂 Барабинск — крупный узел на Транссибе.", "Здесь был построен самолёт «Ан-2».", "Родина дважды Героя Советского Союза.", "Единственный памятник паровозу.", "Барабинская степь — заповедник.", "", false),
      City("Новосибирск", 3400, "1,6 млн", "502 км²", "1893 г.", "🎭 Новосибирск — культурная столица Сибири.", "Мост через Обь был первым в Сибири.", "Академгородок — мировой центр науки.", "Новосибирск стоит на реке Обь.", "Новосибирский зоопарк — один из лучших.", "", true),
      City("Томск", 3570, "576 тыс.", "294 км²", "1604 г.", "🎓 Томск — старейший университетский город.", "Более 100 памятников деревянного зодчества.", "Томск — центр атомной промышленности.", "Здесь родился Михаил Зощенко.", "Томские учёные создают нанотехнологии.", "", false),
      City("Кемерово", 3700, "557 тыс.", "282 км²", "1918 г.", "⛏️ Кемерово — столица Кузбасса.", "Мост через Томь — один из самых длинных.", "Кузбасский ботанический сад.", "Родина хоккеиста Сергея Бобровского.", "Угольный разрез «Кедровский».", "", false),
      City("Красноярск", 4100, "1,1 млн", "348 км²", "1628 г.", "🌉 Красноярск — город на Енисее.", "Вантовый мост — один из самых длинных.", "Красноярские Столбы — нацпарк.", "Многие знаменитости родом отсюда.", "Красноярская ГЭС — крупнейшая в мире.", "", true),
      City("Тайшет", 4510, "34 тыс.", "40 км²", "1897 г.", "🚂 Тайшет — начальная точка БАМа.", "Станция Тайшет — важный узел.", "Евгений Евтушенко упоминал Тайшет.", "Крупный лесопромышленный комплекс.", "Центр алюминиевой промышленности.", "", false),
      City("Иркутск", 5100, "617 тыс.", "277 км²", "1661 г.", "💎 Иркутск — ворота Байкала.", "Более 500 памятников архитектуры.", "Знаменский монастырь.", "Уникальный образец сибирского барокко.", "Иркутское водохранилище.", "Байкальский омуль", true),
      City("Улан-Удэ", 5600, "435 тыс.", "347 км²", "1666 г.", "🗿 Улан-Удэ — буддийская столица.", "Самый большой памятник Ленину.", "Город в долине рек Уды и Селенги.", "Крупнейший авиационный завод.", "Этнографический музей народов Забайкалья.", "Позы (буузы)", true),
      City("Чита", 6200, "350 тыс.", "538 км²", "1653 г.", "⛰️ Чита — столица Забайкалья.", "Церковь декабристов.", "Читинский дацан — старейший.", "Уникальный минеральный источник.", "Забайкальское зодчество.", "", true),
      City("Нерчинск", 6600, "15 тыс.", "24 км²", "1653 г.", "🏰 Нерчинск — один из первых острогов.", "Здесь был сослан протопоп Аввакум.", "Старейший краеведческий музей.", "Управление Нерчинской каторгой.", "Нерчинские рудники.", "", false),
      City("Свободный", 7680, "54 тыс.", "58 км²", "1912 г.", "🚀 Свободный — космодром «Восточный».", "Переименован из Алексеевска.", "Знаменит драмтеатром.", "Крупный сельхозрайон.", "Добыча золота и леса.", "", false),
      City("Белогорск", 7950, "65 тыс.", "39 км²", "1860 г.", "🛩️ Белогорск — центр штурмовой авиации.", "Музей авиации под открытым небом.", "Станция на Транссибе.", "Санатории и источники.", "Крупный сельхозцентр.", "", false),
      City("Хабаровск", 8500, "617 тыс.", "386 км²", "1858 г.", "🐅 Хабаровск — столица Дальнего Востока.", "Символ города — тигр.", "Амурский мост на Транссибе.", "Краеведческий музей.", "Центр деревянного зодчества.", "", true),
      City("Уссурийск", 9140, "173 тыс.", "173 км²", "1866 г.", "🌸 Уссурийск — город цветов.", "Заповедник «Кедровая Падь».", "Уссурийская тайга.", "Архитектура начала XX века.", "Центр виноградарства.", "", false),
      City("Владивосток", 9300, "605 тыс.", "331 км²", "1860 г.", "🌊 Владивосток — конечная точка Транссиба.", "Мост на Русский остров.", "Золотой мост и бухта Золотой Рог.", "Штаб Тихоокеанского флота.", "Крупнейший порт на Дальнем Востоке.", "Морепродукты, крабы", true),
    ];
  }
}

class City {
  final String name;
  final int distanceFromMoscow;
  final String population;
  final String area;
  final String founded;
  final String fact;
  final String funFact1;
  final String funFact2;
  final String funFact3;
  final String funFact4;
  final String cuisine;
  final bool isMajor;

  City(
      this.name,
      this.distanceFromMoscow,
      this.population,
      this.area,
      this.founded,
      this.fact,
      this.funFact1,
      this.funFact2,
      this.funFact3,
      this.funFact4,
      this.cuisine,
      this.isMajor,
      );
}

class DayStats {
  final DateTime date;
  final int steps;
  final int activeMinutes;

  DayStats({required this.date, required this.steps, required this.activeMinutes});
}

class _FullActivityScreen extends StatelessWidget {
  final List<String> feed;
  const _FullActivityScreen({required this.feed});

  @override
  Widget build(BuildContext context) {
    // Группируем записи по дням
    final Map<String, List<String>> groupedByDay = {};

    for (final entry in feed) {
      String dayKey = 'Ранее';
      if (entry.length >= 5 && entry.contains('.')) {
        dayKey = entry.substring(0, 5); // "05.06"
      }
      groupedByDay.putIfAbsent(dayKey, () => []).add(entry);
    }

    // Сортируем дни (сначала новые)
    final sortedDays = groupedByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('История активности',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF4CAF50)),
            onPressed: () {
              // Можно добавить фильтрацию в будущем
            },
          ),
        ],
      ),
      body: feed.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет записей',
                style: TextStyle(color: Colors.grey, fontSize: 18)),
            SizedBox(height: 8),
            Text('Начните ходить, чтобы увидеть историю',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sortedDays.length,
        itemBuilder: (_, dayIndex) {
          final day = sortedDays[dayIndex];
          final entries = groupedByDay[day]!;

          // Определяем, является ли день сегодняшним
          final now = DateTime.now();
          final todayStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}';
          final isToday = day == todayStr;

          // Считаем общее количество шагов за день
          int daySteps = 0;
          for (final entry in entries) {
            if (entry.contains('Шагов:')) {
              final stepsStr = entry.split('Шагов:').last.trim();
              final steps = int.tryParse(stepsStr) ?? 0;
              daySteps += steps;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок дня
              Container(
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFF4CAF50).withOpacity(0.15)
                      : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday
                      ? Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday
                            ? const Color(0xFF4CAF50).withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                      ),
                      child: Icon(
                        isToday ? Icons.today : Icons.date_range,
                        color: isToday ? const Color(0xFF4CAF50) : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isToday ? 'СЕГОДНЯ' : _formatFullDate(day),
                            style: TextStyle(
                              color: isToday ? const Color(0xFF4CAF50) : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${entries.length} записей${daySteps > 0 ? ' • $daySteps шагов' : ''}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (daySteps > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$daySteps шагов',
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Записи за день
              ...entries.map((entry) {
                final time = entry.length >= 11 ? entry.substring(6, 11) : '';
                final text = entry.length > 17 ? entry.substring(17) : entry;

                // Определяем тип записи для цвета
                Color iconColor = Colors.grey;
                IconData icon = Icons.circle;
                if (entry.contains('Начало')) {
                  iconColor = const Color(0xFF4CAF50);
                  icon = Icons.play_arrow;
                } else if (entry.contains('Конец')) {
                  iconColor = const Color(0xFFFF6B6B);
                  icon = Icons.stop;
                } else if (entry.contains('Достигли')) {
                  iconColor = const Color(0xFFFF9800);
                  icon = Icons.emoji_events;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            icon,
                            color: iconColor,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _formatFullDate(String dayMonth) {
    // Преобразует "05.06" в "5 июня"
    final parts = dayMonth.split('.');
    if (parts.length != 2) return dayMonth;

    final day = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;

    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];

    if (month > 0 && month < 13) {
      return '$day ${months[month]}';
    }
    return dayMonth;
  }
}