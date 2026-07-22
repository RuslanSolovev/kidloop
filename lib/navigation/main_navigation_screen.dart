// navigation/main_navigation_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/feed/presentation/trade_offers_screen.dart';
import '../features/add_item/add_item_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../core/items_provider.dart';
import '../core/trades_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with SingleTickerProviderStateMixin {
  int currentIndex = 0;
  Timer? _globalTimer;
  bool _isLoading = true;
  Map<String, dynamic>? _globalStats;
  bool _statsLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final screens = const [HomeScreen(), MapScreen(), TradeOffersScreen()];
  final navItems = const [
    {'icon': Icons.holiday_village_rounded, 'activeIcon': Icons.holiday_village, 'label': 'Главная'},
    {'icon': Icons.map_outlined, 'activeIcon': Icons.map, 'label': 'Карта'},
    {'icon': Icons.swap_horiz_rounded, 'activeIcon': Icons.swap_horiz, 'label': 'Обмены'},
  ];

  static const String statsApiUrl = 'https://functions.yandexcloud.net/d4ejmhrgofllrks14a7s';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
    _globalTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshData();
    });
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    _fadeController.dispose();
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
      debugPrint("Ошибка загрузки данных: $e");
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
      debugPrint("Ошибка обновления: $e");
    }
  }

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
      debugPrint('Ошибка загрузки статистики: $e');
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  void onAddPressed() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AddItemScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      ),
    ).then((_) {
      context.read<ItemsProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final backgroundColor = isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text("Загрузка KidLoop...", style: TextStyle(color: textColor.withOpacity(0.6), fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: backgroundColor,
        extendBody: true,
        appBar: _buildAppBar(textColor, isDark),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: IndexedStack(index: currentIndex, children: screens),
        ),
        floatingActionButton: currentIndex == 0
            ? Padding(
          padding: const EdgeInsets.only(bottom: 90),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: FloatingActionButton(
              onPressed: onAddPressed,
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              child: const Icon(Icons.add_rounded, size: 32),
            ),
          ),
        )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _buildCreativeNavBar(isDark),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color textColor, bool isDark) {
    final hasStats = _globalStats != null && !_statsLoading;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: hasStats
          ? _buildStatsCounter(textColor, isDark)
          : _statsLoading
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
          const SizedBox(width: 8),
          Text('Загрузка...', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      )
          : Text('KidLoop', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 0.5, color: textColor)),
      centerTitle: true,
    );
  }

  Widget _buildStatsCounter(Color textColor, bool isDark) {
    final stats = _globalStats!;
    final completed = stats['completedTrades'] ?? 0;
    final totalSV = stats['totalSV'] ?? 0;

    return GestureDetector(
      onTap: () => _showStatsDialog(isDark),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(isDark ? 0.15 : 0.1),
                  Colors.orange.withOpacity(isDark ? 0.15 : 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Text('$completed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textColor)),
                    const SizedBox(width: 4),
                    Text('сделок', style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6), fontWeight: FontWeight.w500)),
                  ],
                ),
                Container(width: 1, height: 20, color: textColor.withOpacity(0.15), margin: const EdgeInsets.symmetric(horizontal: 12)),
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.amber.shade600),
                    const SizedBox(width: 6),
                    Text('$totalSV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textColor)),
                    const SizedBox(width: 4),
                    Text('SV', style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6), fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textColor.withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatsDialog(bool isDark) {
    if (_globalStats == null) return;
    final stats = _globalStats!;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
            boxShadow: [
              BoxShadow(color: Colors.orange.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF8A3D), Color(0xFFFF6B00)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text('Статистика KidLoop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildStatItem(icon: Icons.check_circle_rounded, value: '${stats['completedTrades'] ?? 0}', label: 'Успешных', color: Colors.green, isDark: isDark),
                    const SizedBox(width: 12),
                    _buildStatItem(icon: Icons.cancel_rounded, value: '${stats['cancelledTrades'] ?? 0}', label: 'Отменено', color: Colors.red, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatItem(icon: Icons.auto_awesome_rounded, value: '${stats['totalSV'] ?? 0}', label: 'SV в сделках', color: Colors.amber, isDark: isDark),
                    const SizedBox(width: 12),
                    _buildStatItem(icon: Icons.people_rounded, value: '${stats['totalUsers'] ?? 0}', label: 'Пользователей', color: Colors.blue, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatItem(icon: Icons.inventory_2_rounded, value: '${stats['totalItems'] ?? 0}', label: 'Вещей', color: Colors.purple, isDark: isDark),
                    const SizedBox(width: 12),
                    _buildStatItem(icon: Icons.trending_up_rounded, value: '${stats['totalTrades'] ?? 0}', label: 'Всего сделок', color: Colors.teal, isDark: isDark),
                  ],
                ),
                if ((stats['totalTrades'] ?? 0) > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green.withOpacity(0.1), Colors.teal.withOpacity(0.05)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Успешность сделок', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                            Text('${((stats['completedTrades'] ?? 0) / (stats['totalTrades'] ?? 1) * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
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
                            Text('Причины отмен', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
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
                                  decoration: BoxDecoration(color: reasonColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(reasonIcon, size: 16, color: reasonColor),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(entry.key, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: reasonColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text('${entry.value}', style: TextStyle(fontWeight: FontWeight.w700, color: reasonColor, fontSize: 13)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required String value, required String label, required Color color, required bool isDark}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
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
      default: return Icons.info_outline_rounded;
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

  Widget _buildCreativeNavBar(bool isDark) {
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, -8)),
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final isSelected = currentIndex == index;
              final item = navItems[index];

              return GestureDetector(
                onTap: () => setState(() => currentIndex = index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  width: isSelected ? 56 : 44,
                  height: isSelected ? 56 : 44,
                  decoration: BoxDecoration(
                    gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFF8A3D), Color(0xFFFF6B00)]) : null,
                    shape: BoxShape.circle,
                    boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] : null,
                  ),
                  child: Icon(
                    isSelected ? item['activeIcon'] as IconData : item['icon'] as IconData,
                    color: isSelected ? Colors.white : (isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade500),
                    size: isSelected ? 26 : 24,
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