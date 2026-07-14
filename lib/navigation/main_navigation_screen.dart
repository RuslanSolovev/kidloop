import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../features/home/home_screen.dart';
import '../features/messenger/messenger_screen.dart';
import '../features/map/map_screen.dart';
import '../features/feed/presentation/trade_offers_screen.dart';
import '../features/pedometer/pedometer_screen.dart';
import '../features/add_item/add_item_screen.dart';
import '../features/dashboard/dashboard_screen.dart'; // Импортируем ThemeProvider
import '../core/items_provider.dart';
import '../core/trades_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;
  Timer? _globalTimer;
  bool _isLoading = true;

  DateTime? _lastBackPressTime;

  // Статистика приложения
  Map<String, dynamic>? _globalStats;
  bool _statsLoading = true;

  final screens = const [
    HomeScreen(),
    MessengerScreen(),
    MapScreen(),
    TradeOffersScreen(),
    PedometerScreen(),
  ];

  final navItems = const [
    {'icon': Icons.holiday_village_rounded, 'activeIcon': Icons.holiday_village, 'label': 'Главная'},
    {'icon': Icons.chat_bubble_outline_rounded, 'activeIcon': Icons.chat_bubble_rounded, 'label': 'Чаты'},
    {'icon': Icons.map_outlined, 'activeIcon': Icons.map, 'label': 'Карта'},
    {'icon': Icons.swap_horiz_rounded, 'activeIcon': Icons.swap_horiz, 'label': 'Обмены'},
    {'icon': Icons.directions_walk_outlined, 'activeIcon': Icons.directions_walk, 'label': 'Шагомер'},
  ];

  static const String statsApiUrl = 'https://functions.yandexcloud.net/d4ejmhrgofllrks14a7s';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });

    _globalTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshData();
    });
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        context.read<ItemsProvider>().loadItems().timeout(const Duration(seconds: 10)),
        context.read<TradesProvider>().loadOffers().timeout(const Duration(seconds: 10)),
        _loadGlobalStats(),
      ]);
    } catch (e) {
      print("Ошибка загрузки данных: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    try {
      await Future.wait([
        context.read<ItemsProvider>().loadItems(),
        context.read<TradesProvider>().loadOffers(),
      ]);
      _loadGlobalStats();
    } catch (e) {
      print("Ошибка обновления: $e");
    }
  }

  // Загрузка глобальной статистики
  Future<void> _loadGlobalStats() async {
    try {
      final response = await http.post(
        Uri.parse(statsApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-global-stats"}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (data['ok'] == true && mounted) {
        setState(() {
          _globalStats = data['stats'];
          _statsLoading = false;
        });
      } else {
        if (mounted) setState(() => _statsLoading = false);
      }
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  void onAddPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    ).then((_) {
      context.read<ItemsProvider>().loadItems();
    });
  }

  Widget _wrapInPopScope(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) >= const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Нажмите ещё раз, чтобы выйти'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Получаем тему из провайдера
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final backgroundColor = isDark ? const Color(0xFF0A0A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return _wrapInPopScope(Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(textColor),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)),
              SizedBox(height: 16),
              Text("Загрузка...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ));
    }

    return _wrapInPopScope(Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      appBar: _buildAppBar(textColor),
      body: IndexedStack(index: currentIndex, children: screens),
      floatingActionButton: currentIndex == 0
          ? Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x66FF9800),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: onAddPressed,
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              child: const Icon(Icons.add_rounded, size: 28),
            ),
          ),
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildCreativeNavBar(isDark),
    ));
  }

  // В _buildAppBar добавляем leading с кнопкой назад
  PreferredSizeWidget _buildAppBar(Color textColor) {
    final hasStats = _globalStats != null && !_statsLoading;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: textColor),
        onPressed: () => Navigator.pop(context),
      ),
      title: hasStats
          ? _buildStatsCounter(textColor)
          : _statsLoading
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Загрузка статистики...',
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      )
          : Text(
        'KidLoop',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          letterSpacing: 1.2,
          color: textColor,
        ),
      ),
      centerTitle: true,
    );
  }

  // Виджет счётчика в AppBar на всю ширину
  Widget _buildStatsCounter(Color textColor) {
    final stats = _globalStats!;
    final completed = stats['completedTrades'] ?? 0;
    final totalSV = stats['totalSV'] ?? 0;

    return GestureDetector(
      onTap: () => _showStatsDialog(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withOpacity(0.15),
              Colors.orange.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Сделки
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz_rounded, size: 20, color: Colors.green.shade600),
                const SizedBox(width: 6),
                Text(
                  '$completed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'сделок',
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            // Разделитель
            Container(
              width: 1,
              height: 20,
              color: textColor.withOpacity(0.2),
            ),
            // SV
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Colors.amber.shade600),
                const SizedBox(width: 6),
                Text(
                  '$totalSV',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'SV',
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            // Стрелка вниз
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  // Диалог с полной статистикой
  void _showStatsDialog() {
    if (_globalStats == null) return;
    final stats = _globalStats!;
    final isDark = context.read<ThemeProvider>().isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade300, Colors.deepOrange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Статистика KidLoop',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Первый ряд
                Row(
                  children: [
                    _buildStatItem(
                      icon: Icons.check_circle_rounded,
                      value: '${stats['completedTrades'] ?? 0}',
                      label: 'Успешных сделок',
                      color: Colors.green,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildStatItem(
                      icon: Icons.cancel_rounded,
                      value: '${stats['cancelledTrades'] ?? 0}',
                      label: 'Отменено',
                      color: Colors.red,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Второй ряд
                Row(
                  children: [
                    _buildStatItem(
                      icon: Icons.auto_awesome,
                      value: '${stats['totalSV'] ?? 0}',
                      label: 'SV в сделках',
                      color: Colors.amber,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildStatItem(
                      icon: Icons.people_rounded,
                      value: '${stats['totalUsers'] ?? 0}',
                      label: 'Пользователей',
                      color: Colors.blue,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Третий ряд
                Row(
                  children: [
                    _buildStatItem(
                      icon: Icons.inventory_2_rounded,
                      value: '${stats['totalItems'] ?? 0}',
                      label: 'Вещей',
                      color: Colors.purple,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildStatItem(
                      icon: Icons.trending_up_rounded,
                      value: '${stats['totalTrades'] ?? 0}',
                      label: 'Всего сделок',
                      color: Colors.teal,
                      isDark: isDark,
                    ),
                  ],
                ),

                // Процент успешных сделок
                if ((stats['totalTrades'] ?? 0) > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.1),
                          Colors.teal.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Успешность сделок',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            Text(
                              '${((stats['completedTrades'] ?? 0) / (stats['totalTrades'] ?? 1) * 100).round()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (stats['completedTrades'] ?? 0) / (stats['totalTrades'] ?? 1),
                            minHeight: 8,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Причины отмен
                if (stats['cancelReasons'] != null && (stats['cancelReasons'] as Map).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red.shade400),
                            const SizedBox(width: 8),
                            Text(
                              'Причины отмен',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...(stats['cancelReasons'] as Map<String, dynamic>).entries.map((entry) {
                          final reasonIcon = _getReasonIcon(entry.key);
                          final reasonColor = _getReasonColor(entry.key);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: reasonColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(reasonIcon, size: 16, color: reasonColor),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: reasonColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${entry.value}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: reasonColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getReasonIcon(String reason) {
    switch (reason) {
      case 'Подозрение на мошенника': return Icons.security_rounded;
      case 'Скандальный пользователь': return Icons.report_rounded;
      case 'Товар не соответствует': return Icons.broken_image_rounded;
      case 'Передумал': return Icons.psychology_rounded;
      default: return Icons.info_outline;
    }
  }

  Color _getReasonColor(String reason) {
    switch (reason) {
      case 'Подозрение на мошенника': return Colors.red;
      case 'Скандальный пользователь': return Colors.orange;
      case 'Товар не соответствует': return Colors.amber.shade700;
      case 'Передумал': return Colors.grey;
      default: return Colors.grey;
    }
  }

  // Нижняя навигационная панель
  Widget _buildCreativeNavBar(bool isDark) {
    final bgColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.05);

    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final isSelected = currentIndex == index;
              final item = navItems[index];

              return GestureDetector(
                onTap: () => setState(() => currentIndex = index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  width: isSelected ? 52 : 40,
                  height: isSelected ? 52 : 40,
                  margin: EdgeInsets.only(top: isSelected ? 0 : 5),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                      colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      )
                    ]
                        : null,
                  ),
                  child: Icon(
                    isSelected ? item['activeIcon'] as IconData : item['icon'] as IconData,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade500),
                    size: isSelected ? 24 : 22,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}