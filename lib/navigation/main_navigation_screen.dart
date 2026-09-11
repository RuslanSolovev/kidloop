// navigation/main_navigation_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/feed/presentation/trade_offers_screen.dart';
import '../features/add_item/add_item_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../core/items_provider.dart';
import '../core/trades_provider.dart';
import '../core/bundle_provider.dart';
import '../features/subscriptions/subscriptions_screen.dart';
import '../features/bundles/create_bundle_screen.dart';

// ==================== iOS DESIGN SYSTEM ====================

class _IOS {
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color darkBg = Color(0xFF000000);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);

  static const Color blue = Color(0xFF007AFF);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color purple = Color(0xFFAF52DE);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color indigo = Color(0xFF5856D6);
  static const Color pink = Color(0xFFFF2D55);
  static const Color red = Color(0xFFFF3B30);
  static const Color gray = Color(0xFF8E8E93);

  static Color separator(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color textPrimary(bool isDark) => isDark ? Colors.white : Colors.black;
  static Color textSecondary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.6)
      : const Color(0xFF3C3C43).withOpacity(0.6);
  static Color textTertiary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.3)
      : const Color(0xFF3C3C43).withOpacity(0.3);
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int currentIndex = 0;
  Timer? _globalTimer;
  bool _isLoading = true;
  Map<String, dynamic>? _globalStats;
  bool _statsLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final screens = const [HomeScreen(), MapScreen(), TradeOffersScreen()];

  final navItems = const [
    {
      'icon': Icons.holiday_village_outlined,
      'activeIcon': Icons.holiday_village_rounded,
      'label': 'Главная',
    },
    {
      'icon': Icons.map_outlined,
      'activeIcon': Icons.map_rounded,
      'label': 'Карта',
    },
    {
      'icon': Icons.swap_horiz_outlined,
      'activeIcon': Icons.swap_horiz_rounded,
      'label': 'Обмены',
    },
  ];

  static const String statsApiUrl =
      'https://functions.yandexcloud.net/d4ejmhrgofllrks14a7s';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
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
        context.read<ItemsProvider>().loadItems(),
        context.read<TradesProvider>().loadOffers(),
        context.read<BundleProvider>().loadAllBundles(),
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
        context.read<BundleProvider>().loadAllBundles(),
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
      );

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
    HapticFeedback.mediumImpact();
    _showAddOptions(context);
  }

  // ============================================================
  // ADD OPTIONS — iOS Action Sheet
  // ============================================================

  void _showAddOptions(BuildContext parentContext) {
    final isDark = Theme.of(parentContext).brightness == Brightness.dark;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? _IOS.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Что добавить?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: _IOS.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Выберите тип объявления',
                style: TextStyle(
                  fontSize: 14,
                  color: _IOS.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 20),

              _buildAddOption(
                isDark: isDark,
                icon: Icons.add_rounded,
                iconColor: _IOS.orange,
                title: 'Одна вещь',
                subtitle: 'Создать объявление',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(builder: (_) => const AddItemScreen()),
                  ).then((_) async {
                    parentContext.read<ItemsProvider>().loadItems();
                  });
                },
              ),
              const SizedBox(height: 10),
              _buildAddOption(
                isDark: isDark,
                icon: Icons.inventory_2_rounded,
                iconColor: _IOS.purple,
                title: 'Набор вещей',
                subtitle: 'Объединить несколько вещей',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                        builder: (_) => const CreateBundleScreen()),
                  ).then((_) async {
                    parentContext.read<ItemsProvider>().loadItems();
                    parentContext.read<BundleProvider>().loadAllBundles();
                    parentContext.read<BundleProvider>().loadMyBundles();
                  });
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Отмена',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _IOS.textPrimary(isDark),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _IOS.card(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _IOS.separator(isDark)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: _IOS.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: _IOS.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _IOS.textTertiary(isDark),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: _IOS.bg(isDark),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: _IOS.blue,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Загрузка KidLoop…",
                style: TextStyle(
                  color: _IOS.textSecondary(isDark),
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: _IOS.bg(isDark),
        extendBody: true,
        appBar: _buildAppBar(isDark),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: IndexedStack(index: currentIndex, children: screens),
        ),
        floatingActionButton: currentIndex == 0
            ? Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _IOS.blue.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: onAddPressed,
              backgroundColor: _IOS.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              child: const Icon(Icons.add_rounded, size: 28),
            ),
          ),
        )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _buildNavBar(isDark),
      ),
    );
  }

  // ============================================================
  // APP BAR — iOS style
  // ============================================================

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final hasStats = _globalStats != null && !_statsLoading;

    return AppBar(
      backgroundColor: _IOS.bg(isDark).withOpacity(0.85),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              color: _IOS.textPrimary(isDark),
              size: 22,
            ),
          ),
        ),
      ),
      title: hasStats
          ? _buildStatsCounter(isDark)
          : _statsLoading
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _IOS.blue.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Загрузка…',
            style: TextStyle(
              color: _IOS.textSecondary(isDark),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      )
          : Text(
        'KidLoop',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.5,
          color: _IOS.textPrimary(isDark),
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubscriptionsScreen(),
                ),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: _IOS.orange,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATS COUNTER — iOS pill
  // ============================================================

  Widget _buildStatsCounter(bool isDark) {
    final stats = _globalStats!;
    final completed = stats['completedTrades'] ?? 0;
    final totalSV = stats['totalSV'] ?? 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showStatsDialog(isDark);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _IOS.card(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _IOS.separator(isDark)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz_rounded,
                size: 15, color: _IOS.green),
            const SizedBox(width: 5),
            Text(
              '$completed',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1,
                color: _IOS.textPrimary(isDark),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'сделок',
              style: TextStyle(
                fontSize: 11,
                height: 1,
                color: _IOS.textSecondary(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              width: 0.5,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: _IOS.separator(isDark),
            ),
            const Icon(Icons.auto_awesome_rounded,
                size: 13, color: _IOS.orange),
            const SizedBox(width: 5),
            Text(
              '$totalSV',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1,
                color: _IOS.textPrimary(isDark),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'SV',
              style: TextStyle(
                fontSize: 11,
                height: 1,
                color: _IOS.textSecondary(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATS DIALOG — iOS bottom sheet
  // ============================================================

  void _showStatsDialog(bool isDark) {
    if (_globalStats == null) return;
    final stats = _globalStats!;
    final completed = (stats['completedTrades'] ?? 0) as num;
    final cancelled = (stats['cancelledTrades'] ?? 0) as num;
    final totalTrades = (stats['totalTrades'] ?? 0) as num;
    final totalSV = (stats['totalSV'] ?? 0) as num;
    final totalUsers = (stats['totalUsers'] ?? 0) as num;
    final totalItems = (stats['totalItems'] ?? 0) as num;
    final successRate =
    totalTrades > 0 ? (completed / totalTrades * 100).round() : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: _IOS.bg(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_IOS.orange, Color(0xFFE85D00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _IOS.orange.withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.insights_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Статистика KidLoop',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Живые данные платформы',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$successRate%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'успешность',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: totalTrades > 0 ? completed / totalTrades : 0,
                              minHeight: 8,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildStatsSectionTitle('Обзор', isDark),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.check_circle_rounded,
                            value: _formatNum(completed.toInt()),
                            label: 'Успешных',
                            color: _IOS.green,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.cancel_rounded,
                            value: _formatNum(cancelled.toInt()),
                            label: 'Отменено',
                            color: _IOS.red,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.auto_awesome_rounded,
                            value: _formatNum(totalSV.toInt()),
                            label: 'SV в сделках',
                            color: _IOS.yellow,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.trending_up_rounded,
                            value: _formatNum(totalTrades.toInt()),
                            label: 'Всего сделок',
                            color: _IOS.teal,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.people_alt_rounded,
                            value: _formatNum(totalUsers.toInt()),
                            label: 'Пользователей',
                            color: _IOS.blue,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.inventory_2_rounded,
                            value: _formatNum(totalItems.toInt()),
                            label: 'Вещей',
                            color: _IOS.purple,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    if (stats['cancelReasons'] != null &&
                        (stats['cancelReasons'] as Map).isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildStatsSectionTitle('Причины отмен', isDark),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _IOS.card(isDark),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _IOS.separator(isDark)),
                        ),
                        child: Column(
                          children: (stats['cancelReasons']
                          as Map<String, dynamic>)
                              .entries
                              .map((entry) {
                            final reason = entry.key;
                            final count = (entry.value as num).toInt();
                            final icon = _getReasonIcon(reason);
                            final color = _getReasonColor(reason);
                            final percent = cancelled > 0
                                ? (count / cancelled * 100).round()
                                : 0;

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: (stats['cancelReasons']
                                as Map<String, dynamic>)
                                    .entries
                                    .last
                                    .key ==
                                    reason
                                    ? 0
                                    : 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(icon, size: 18, color: color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          reason,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _IOS.textPrimary(isDark),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: cancelled > 0
                                                ? count / cancelled
                                                : 0,
                                            minHeight: 5,
                                            backgroundColor: isDark
                                                ? Colors.white12
                                                : Colors.black12,
                                            valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                color),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: color,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$percent%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color:
                                          _IOS.textTertiary(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: _IOS.blue,
                          backgroundColor: _IOS.blue.withOpacity(0.10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Закрыть',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: _IOS.textTertiary(isDark),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _IOS.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _IOS.separator(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _IOS.textPrimary(isDark),
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _IOS.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNum(int value) {
    if (value >= 1000) {
      final r = value / 1000;
      return '${r.toStringAsFixed(r.truncateToDouble() == r ? 0 : 1)}k';
    }
    return '$value';
  }

  IconData _getReasonIcon(String reason) {
    switch (reason) {
      case 'Подозрение на мошенника':
        return Icons.security_rounded;
      case 'Скандальный пользователь':
        return Icons.report_rounded;
      case 'Товар не соответствует':
        return Icons.broken_image_rounded;
      case 'Передумал':
        return Icons.psychology_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getReasonColor(String reason) {
    switch (reason) {
      case 'Подозрение на мошенника':
        return _IOS.red;
      case 'Скандальный пользователь':
        return _IOS.orange;
      case 'Товар не соответствует':
        return _IOS.yellow;
      case 'Передумал':
        return Colors.blueGrey;
      default:
        return _IOS.gray;
    }
  }

  // ============================================================
  // BOTTOM NAV — iOS tab bar style
  // ============================================================

  Widget _buildNavBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      height: 68,
      decoration: BoxDecoration(
        color: isDark
            ? _IOS.darkCardElevated.withOpacity(0.85)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _IOS.separator(isDark), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final isSelected = currentIndex == index;
                final item = navItems[index];

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => currentIndex = index);
                      if (index == 0) {
                        context.read<BundleProvider>().loadAllBundles();
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: isSelected ? 42 : 36,
                            height: isSelected ? 28 : 24,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _IOS.blue.withOpacity(0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isSelected
                                  ? item['activeIcon'] as IconData
                                  : item['icon'] as IconData,
                              color: isSelected
                                  ? _IOS.blue
                                  : _IOS.textSecondary(isDark),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                              letterSpacing: -0.1,
                              color: isSelected
                                  ? _IOS.blue
                                  : _IOS.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}