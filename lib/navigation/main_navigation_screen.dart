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
import '../features/profile/profile_screen.dart';
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
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isDarkMode = false;

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
    _loadAvatar();
    _loadThemePreference();

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

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    if (mounted) setState(() => _isDarkMode = isDark);
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newThemeMode = !_isDarkMode;
    setState(() => _isDarkMode = newThemeMode);
    await prefs.setBool('is_dark_mode', newThemeMode);
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
      await _loadAvatar();
      _loadGlobalStats(); // без await, чтобы не блокировать
    } catch (e) {
      print("Ошибка обновления: $e");
    }
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('user_profile');
      if (jsonString != null && jsonString.isNotEmpty) {
        final map = jsonDecode(jsonString);
        final url = map['avatarUrl'] ?? '';
        if (mounted) setState(() => _avatarUrl = url.isNotEmpty ? url : null);
      }
    } catch (e) {
      print("Ошибка загрузки аватара: $e");
    }
  }

  // Загрузка глобальной статистики
  Future<void> _loadGlobalStats() async {
    try {
      print('🔄 Загружаем статистику...');
      final response = await http.post(
        Uri.parse(statsApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-global-stats"}),
      ).timeout(const Duration(seconds: 8));

      print('📡 Статус ответа: ${response.statusCode}');
      print('📡 Тело ответа: ${response.body}');

      final data = jsonDecode(response.body);
      print('📊 Данные: ok=${data['ok']}, stats=${data['stats'] != null ? "есть" : "нет"}');

      if (data['ok'] == true && mounted) {
        setState(() {
          _globalStats = data['stats'];
          _statsLoading = false;
        });
        print('✅ Статистика загружена: ${_globalStats!['completedTrades']} сделок');
      } else {
        print('❌ Ошибка в ответе: ${data['errorMessage']}');
        if (mounted) setState(() => _statsLoading = false);
      }
    } catch (e) {
      print('❌ Ошибка загрузки статистики: $e');
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
            const SnackBar(content: Text('Нажмите ещё раз, чтобы выйти'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
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
    final brightness = _isDarkMode ? Brightness.dark : Brightness.light;
    final backgroundColor = _isDarkMode ? const Color(0xFF0A0A1A) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black87;

    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: brightness, useMaterial3: true, colorSchemeSeed: Colors.orange),
        home: _wrapInPopScope(Scaffold(
          backgroundColor: backgroundColor,
          appBar: _buildAppBar(textColor, true),
          body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)),
            SizedBox(height: 16),
            Text("Загрузка...", style: TextStyle(color: Colors.grey)),
          ])),
        )),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: brightness,
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: textColor),
      ),
      home: _wrapInPopScope(Scaffold(
        backgroundColor: backgroundColor,
        extendBody: true,
        appBar: _buildAppBar(textColor, false),
        body: IndexedStack(index: currentIndex, children: screens),
        floatingActionButton: currentIndex == 0
            ? FloatingActionButton(
          onPressed: onAddPressed,
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 8,
          child: const Icon(Icons.add_rounded, size: 28),
        )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildCreativeNavBar(),
      )),
    );
  }

  // AppBar со счётчиком статистики
  PreferredSizeWidget _buildAppBar(Color textColor, bool isLoading) {
    // 🔥 Проверяем, есть ли загруженная статистика
    final hasStats = _globalStats != null && !_statsLoading;

    print('🔧 _buildAppBar: hasStats=$hasStats, statsLoading=$_statsLoading, stats=${_globalStats != null ? "есть" : "нет"}');

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(6),
        child: GestureDetector(
          onTap: isLoading ? null : () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _loadAvatar());
          },
          child: Hero(
            tag: 'profile_avatar',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 8)],
              ),
              child: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                radius: 18,
                backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null || _avatarUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.orange, size: 20)
                    : null,
              ),
            ),
          ),
        ),
      ),
      title: hasStats
          ? _buildStatsCounter(textColor)
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔄', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text('KidLoop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.2, color: textColor)),
        ],
      ),
      centerTitle: true,
      actions: [_buildThemeToggle()],
    );
  }

  // Виджет счётчика в AppBar
  Widget _buildStatsCounter(Color textColor) {
    final stats = _globalStats!;
    final completed = stats['completedTrades'] ?? 0;
    final totalSV = stats['totalSV'] ?? 0;

    print('🔢 Счётчик: completed=$completed, totalSV=$totalSV');

    return GestureDetector(
      onTap: () => _showStatsDialog(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Text(
              '$completed',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'сделок',
              style: TextStyle(
                fontSize: 12,
                color: textColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4, height: 4,
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.auto_awesome, size: 14, color: Colors.amber.shade600),
            const SizedBox(width: 4),
            Text(
              '$totalSV',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.amber.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  // Диалог с полной статистикой
  void _showStatsDialog() {
    if (_globalStats == null) return;
    final stats = _globalStats!;
    final isDark = _isDarkMode;

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

  String _formatStatsDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
      if (diff.inHours < 24) return '${diff.inHours} ч. назад';
      if (diff.inDays < 7) return '${diff.inDays} дн. назад';
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (_) {
      return '';
    }
  }

  // Нижняя навигационная панель
  Widget _buildCreativeNavBar() {
    final isDark = _isDarkMode;
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

  Widget _buildThemeToggle() {
    return GestureDetector(
      onTap: _toggleTheme,
      child: Container(
        width: 56,
        height: 30,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: _isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey.shade200,
          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.15), blurRadius: 8)],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              alignment: _isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isDarkMode
                        ? [const Color(0xFFE94560), const Color(0xFFFF6B6B)]
                        : [Colors.orange, Colors.orange.shade700],
                  ),
                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 6)],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                    key: ValueKey(_isDarkMode),
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}