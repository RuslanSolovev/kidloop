// features/dashboard/dashboard_screen.dart
import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../../core/items_provider.dart';
import '../../core/level_calculator.dart';
import '../../core/trades_provider.dart';
import '../../core/item_model.dart';
import '../../core/bundle_provider.dart';
import '../../core/bundle_model.dart';
import '../../navigation/main_navigation_screen.dart';
import '../bundles/bundle_details_screen.dart';
import '../item_details/item_details_screen.dart';
import '../profile/profile_screen.dart';
import '../add_item/add_item_screen.dart';
import '../bundles/create_bundle_screen.dart';
import '../feed/presentation/trade_offers_screen.dart';
import '../games/games_screen.dart';
import '../games/memory_game/memory_game_screen.dart';
import '../games/chess/chess_game_screen.dart';
import '../pedometer/pedometer_screen.dart';
import '../messenger/messenger_screen.dart';
import '../map/map_screen.dart';
import 'manage_banners_screen.dart';
import 'banner_detail_screen.dart';

mixin SingleTapMixin {
  bool _isProcessing = false;
  Future<void> safeTap(Future<void> Function() action) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      await action();
    } finally {
      _isProcessing = false;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  ThemeProvider() {
    _loadTheme();
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    notifyListeners();
  }
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, SingleTapMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _userName = 'Друг';
  String? _avatarUrl;
  String? _currentUserId;
  int _todaySteps = 0;
  int _level = 1;
  String _dailyTip = '';
  List<Item> _latestItems = [];
  List<Bundle> _latestBundles = [];
  List<BannerAd> _banners = [];
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  final PageController _pageController = PageController();

  final List<String> _tips = [
    'Меняйся игрушками — спасай планету! 🌍',
    'Каждая ненужная вещь может стать сокровищем для другого 👶',
    'Сделай 10 000 шагов сегодня и получи бонус! 👟',
    'Обмен вещами экономит до 30 кг CO₂ в год 🌱',
    'Проверь раздел «Обмены» — возможно, тебя ждёт выгодная сделка 🤝',
    'Добавь свои старые игрушки — освободи место и заработай SV 🧸',
  ];

  static const String _bannerApiUrl =
      'https://functions.yandexcloud.net/d4e9bd6bmvqmife91gf4';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();
    _loadInitialData();
    _loadBanners();
    _startBannerAutoScroll();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _loadTodaySteps();
    try {
      final itemsProvider = context.read<ItemsProvider>();
      if (itemsProvider.items.isEmpty) await itemsProvider.loadItems();
      final bundleProvider = context.read<BundleProvider>();
      if (bundleProvider.allBundles.isEmpty) {
        await bundleProvider.loadAllBundles();
      }
    } catch (e) {
      debugPrint("Ошибка загрузки: $e");
    }
    _dailyTip = (_tips..shuffle()).first;
    _loadLatestItems();
  }

  Future<void> _loadBanners() async {
    try {
      final response = await http.post(
        Uri.parse(_bannerApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-banners"}),
      ).timeout(const Duration(seconds: 5));
      if (mounted) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          setState(() {
            _banners = (data['banners'] as List).map((b) => BannerAd(
              id: b['banner_id'] ?? '',
              imageUrl: b['image_url'] ?? '',
              title: b['title'] ?? '',
              subtitle: b['subtitle'] ?? '',
              description: b['description'] ?? '',
              overlayText: b['overlay_text'] ?? '',
              link: b['link'] ?? '',
            )).toList();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _banners = [
            BannerAd(
              id: 'default', imageUrl: '',
              title: '🔄 Обменивайся вещами!',
              subtitle: 'Найди нужное и отдай ненужное',
              description: 'KidLoop — платформа для обмена детскими вещами.',
              overlayText: 'KIDLOOP',
            ),
          ];
        });
      }
    }
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_banners.isNotEmpty && mounted) {
        final nextIndex = (_currentBannerIndex + 1) % _banners.length;
        _pageController.animateToPage(
          nextIndex, duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
        setState(() => _currentBannerIndex = nextIndex);
      }
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    final jsonString = prefs.getString('user_profile');
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userName = map['name']?.toString() ?? 'Друг';
            _avatarUrl = map['avatarUrl']?.toString();
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _userName = prefs.getString('user_name') ?? 'Друг');
        }
      }
    } else {
      if (mounted) {
        setState(() => _userName = prefs.getString('user_name') ?? 'Друг');
      }
    }
  }

  Future<void> _loadTodaySteps() async {
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('today_steps') ?? 0;
    final total = prefs.getInt('total_steps') ?? 0;
    final itemsCount = context.read<ItemsProvider>().items.length;
    final trades = context.read<TradesProvider>().offers;
    final completedTrades =
        trades.where((t) => t.status == 'completed').length;
    final sentOffers =
        trades.where((t) => t.fromUserId == _currentUserId).length;
    final level = LevelCalculator.calculateLevel(
      totalSteps: total, itemsCount: itemsCount,
      completedTrades: completedTrades, sentOffers: sentOffers,
    );
    if (mounted) setState(() { _todaySteps = steps; _level = level; });
  }

  void _loadLatestItems() {
    try {
      final items = context.read<ItemsProvider>().items;
      final bundles = context.read<BundleProvider>().allBundles;
      final List<dynamic> allItems = [...items, ...bundles];
      allItems.sort((a, b) {
        DateTime? dateA;
        DateTime? dateB;
        if (a is Item) dateA = DateTime.tryParse(a.createdAt ?? '');
        else if (a is Bundle) dateA = DateTime.tryParse(a.createdAt ?? '');
        if (b is Item) dateB = DateTime.tryParse(b.createdAt ?? '');
        else if (b is Bundle) dateB = DateTime.tryParse(b.createdAt ?? '');
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
      if (mounted) {
        setState(() {
          final top10 = allItems.take(10).toList();
          _latestItems = top10.whereType<Item>().toList();
          _latestBundles = top10.whereType<Bundle>().toList();
        });
      }
    } catch (e) {
      debugPrint("Ошибка загрузки: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);
    final backgroundColor =
    isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA);
    return Theme(
      data: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        useMaterial3: true, colorSchemeSeed: Colors.orange,
        scaffoldBackgroundColor: backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnimation, child: _buildWelcomeHeader(isDark),
              )),
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildTopActions(isDark, textColor),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildOpenAppButton(isDark),
                ),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              if (_banners.isNotEmpty)
                SliverToBoxAdapter(child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildBannerCarousel(isDark),
                )),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildLatestItemsCarousel(isDark, textColor),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildQuickActions(isDark, textColor),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildStepTracker(isDark),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnimation, child: _buildChatsBlock(isDark),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnimation, child: _buildGamesBlock(isDark),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildDailyTip(isDark, textColor),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 1. ПРИВЕТСТВИЕ ====================
  Widget _buildWelcomeHeader(bool isDark) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/vverh.jpeg'), fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.7)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.6), width: 2),
                ),
                child: CircleAvatar(
                  radius: 28, backgroundColor: Colors.white24,
                  backgroundImage: _avatarUrl != null
                      ? CachedNetworkImageProvider(_avatarUrl!) : null,
                  child: _avatarUrl == null
                      ? Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold,
                        fontSize: 22),
                  ) : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Привет, $_userName!',
                      style: const TextStyle(fontSize: 24,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('Уровень $_level',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
              )),
              if (_currentUserId == '68a878d2-0c31-46f9-917a-898ff9403311')
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.campaign_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => safeTap(() async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                          const ManageBannersScreen()));
                    }),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('До уровня ${_level + 1}',
                    style: TextStyle(color: Colors.white.withOpacity(0.9),
                        fontSize: 11, fontWeight: FontWeight.w600)),
                Text('${_todaySteps % 50000} / 50000 шагов',
                    style: TextStyle(color: Colors.white.withOpacity(0.9),
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ((_todaySteps % 50000) / 50000).clamp(0.0, 1.0),
                  minHeight: 6, backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ==================== 2. ПРОФИЛЬ И ТЕМА ====================
  Widget _buildTopActions(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          InkWell(
            onTap: () => safeTap(() async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()));
              await _loadUserData();
            }),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFFF8A3D), Color(0xFFFF6B00)]),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Профиль', style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<ThemeProvider>().toggleTheme(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut, width: 64, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                color: isDark ? const Color(0xFF2A2D35) : Colors.grey.shade200,
              ),
              child: Stack(children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 30, height: 30, margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF3A86FF), const Color(0xFF007AFF)]
                            : [Colors.orange, Colors.orange.shade700],
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                        key: ValueKey(isDark), color: Colors.white, size: 16,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ==================== 3. КНОПКА ОТКРЫТЬ ЛЕНТУ ====================
  Widget _buildOpenAppButton(bool isDark) {
    return GestureDetector(
      onTap: () => safeTap(_openMainApp),
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
              image: AssetImage('assets/images/veshi.jpeg'), fit: BoxFit.cover),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3),
              blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: [Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6)],
            ),
          ),
          child: Center(child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange]),
                  boxShadow: [BoxShadow(color: Colors.deepOrange,
                      blurRadius: 15, spreadRadius: 5)],
                ),
                child: const Icon(Icons.explore_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Открыть полную ленту', style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w800, color: Colors.white)),
                    SizedBox(height: 4),
                    Text('Все объявления в одном месте',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ]),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 28),
            ],
          )),
        ),
      ),
    );
  }

  // ==================== 4. БАННЕРЫ ====================
  Widget _buildBannerCarousel(bool isDark) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SizedBox(height: 160, child: PageView.builder(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentBannerIndex = i),
        itemCount: _banners.length,
        itemBuilder: (ctx, i) {
          final b = _banners[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => safeTap(() async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                        BannerDetailScreen(banner: b)));
              }),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.15),
                      blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(fit: StackFit.expand, children: [
                    if (b.imageUrl.isNotEmpty)
                      CachedNetworkImage(imageUrl: b.imageUrl, fit: BoxFit.cover)
                    else
                      Container(decoration: const BoxDecoration(gradient:
                      LinearGradient(colors: [Colors.orange, Colors.deepOrange]))),
                    Container(decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.6)]))),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: b.overlayText.isNotEmpty
                            ? MainAxisAlignment.center : MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (b.overlayText.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(b.overlayText, style: const TextStyle(
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(b.title, style: const TextStyle(color: Colors.white,
                              fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(b.subtitle, style: TextStyle(
                              color: Colors.white.withOpacity(0.85), fontSize: 13)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      )),
      if (_banners.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children:
          List.generate(_banners.length, (i) => GestureDetector(
            onTap: () => _pageController.animateToPage(i,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == _currentBannerIndex ? 24 : 8, height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                  color: i == _currentBannerIndex
                      ? Colors.orange : Colors.grey.shade400),
            ),
          ))),
        ),
    ]);
  }

  // ==================== 5. НОВЫЕ ОБЪЯВЛЕНИЯ ====================
  Widget _buildLatestItemsCarousel(bool isDark, Color textColor) {
    if (_latestItems.isEmpty && _latestBundles.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isDark
            ? [const Color(0xFF1A1D24).withOpacity(0.95),
          const Color(0xFF2A2D35).withOpacity(0.9),
          const Color(0xFF1A1D24).withOpacity(0.95)]
            : [Colors.orange.shade50.withOpacity(0.8),
          Colors.orange.shade100.withOpacity(0.5),
          Colors.orange.shade50.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(24),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('🔥 Новые объявления', style: TextStyle(color: textColor,
                fontSize: 18, fontWeight: FontWeight.w800)),
            TextButton(
              onPressed: () => safeTap(_openMainApp),
              child: Text('Все', style: TextStyle(color:
              isDark ? const Color(0xFF3A86FF) : Colors.orange,
                  fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 170, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _latestItems.length + _latestBundles.length,
          itemBuilder: (ctx, i) {
            if (i < _latestBundles.length) {
              return _buildLatestBundleCard(_latestBundles[i]);
            } else {
              return _buildLatestItemCard(
                  _latestItems[i - _latestBundles.length]);
            }
          },
        )),
      ]),
    );
  }

  // 🔥 КАРТОЧКА ОДИНОЧНОЙ ВЕЩИ (SV вместо "Обмен")
  Widget _buildLatestItemCard(Item item) {
    return GestureDetector(
      onTap: () => safeTap(() async {
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(item: item)));
      }),
      child: Container(
        width: 150, margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
              blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(fit: StackFit.expand, children: [
            if (item.imagePaths.isNotEmpty)
              CachedNetworkImage(imageUrl: item.imagePaths.first,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.shade300),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey.shade300))
            else Container(color: Colors.grey.shade300),
            Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(0.3), Colors.transparent]))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // 🔥 SV вместо "Обмен"
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${item.sv} SV', style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // 🔥 КАРТОЧКА НАБОРА — СЕТКА 3×3, БЕЗ НАДПИСИ "НАБОР"
  Widget _buildLatestBundleCard(Bundle bundle) {
    return GestureDetector(
      onTap: () => safeTap(() async {
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => BundleDetailsScreen(bundle: bundle)));
      }),
      child: Container(
        width: 150, margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.withOpacity(0.4), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2),
              blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(fit: StackFit.expand, children: [
            // Фон
            Container(decoration: BoxDecoration(gradient: LinearGradient(
                colors: [const Color(0xFF7B1FA2).withOpacity(0.8),
                  const Color(0xFF512DA8).withOpacity(0.9)]))),
            // 🔥 СЕТКА 3×3 превью предметов
            if (bundle.items.isNotEmpty)
              _buildItemGrid(bundle.items),
            // Затемнение снизу
            Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(0.2), Colors.transparent]))),
            // Название и SV снизу
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bundle.title, style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${bundle.items.length} пред. • ${bundle.totalSv} SV',
                      style: TextStyle(color: Colors.white.withOpacity(0.8),
                          fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // 🔥 СЕТКА 3×3 ДЛЯ ПРЕДМЕТОВ НАБОРА
  Widget _buildItemGrid(List<BundleItem> items) {
    final showItems = items.take(6).toList(); // максимум 6 в сетке
    final remaining = items.length - 6;

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(children: [
        // Первый ряд
        Expanded(child: Row(children: [
          _gridCell(showItems, 0),
          _gridCell(showItems, 1),
          _gridCell(showItems, 2),
        ])),
        // Второй ряд
        Expanded(child: Row(children: [
          _gridCell(showItems, 3),
          _gridCell(showItems, 4),
          _gridCell(showItems, 5),
        ])),
        // Если больше 6 — "+N"
        if (remaining > 0)
          Container(
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text('+$remaining ещё',
                style: const TextStyle(color: Colors.white,
                    fontSize: 9, fontWeight: FontWeight.bold))),
          ),
      ]),
    );
  }

  // 🔥 ОДНА ЯЧЕЙКА СЕТКИ
  Widget _gridCell(List<BundleItem> items, int index) {
    if (index >= items.length) {
      return const Expanded(child: SizedBox.shrink());
    }
    final item = items[index];
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: item.imagePath.isNotEmpty && item.imagePath.startsWith('http')
              ? CachedNetworkImage(imageUrl: item.imagePath, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _gridCellPlaceholder(item))
              : _gridCellPlaceholder(item),
        ),
      ),
    );
  }

  Widget _gridCellPlaceholder(BundleItem item) {
    return Container(
      color: Colors.white.withOpacity(0.15),
      child: Center(child: Text('${item.sv}',
          style: const TextStyle(color: Colors.white70,
              fontSize: 9, fontWeight: FontWeight.bold))),
    );
  }

  // ==================== 6. БЫСТРЫЕ ДЕЙСТВИЯ ====================
  Widget _buildQuickActions(bool isDark, Color textColor) {
    final actions = [
      {'label': 'Лента', 'image': 'assets/images/lenta.jpeg', 'route': 'main'},
      {'label': 'Добавить', 'image': 'assets/images/dobavit.jpeg', 'route': 'add'},
      {'label': 'Обмены', 'image': 'assets/images/obmen.jpeg', 'route': 'trades'},
      {'label': 'Карта', 'image': 'assets/images/karti.jpeg', 'route': 'map'},
      {'label': 'Шахматы', 'image': 'assets/images/shahmati.jpeg', 'route': 'chess'},
      {'label': 'Запомни число', 'image': 'assets/images/cifri.jpeg', 'route': 'memory'},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: isDark
          ? [const Color(0xFF0F1115).withOpacity(0.95),
        const Color(0xFF1A1D24).withOpacity(0.9),
        const Color(0xFF0F1115).withOpacity(0.95)]
          : [Colors.blue.shade50, Colors.purple.shade50, Colors.blue.shade50]),
          borderRadius: BorderRadius.circular(24)),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('⚡ Быстрые действия', style: TextStyle(color: textColor,
              fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 100, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (ctx, i) {
            final a = actions[i];
            return GestureDetector(
              onTap: () => safeTap(() async {
                await _handleAction(a['route'] as String);
              }),
              child: Container(
                width: 90,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.asset(a['image'] as String, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey.shade300)),
                    Container(decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.75)]))),
                    Center(child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(a['label'] as String, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    )),
                  ]),
                ),
              ),
            );
          },
        )),
      ]),
    );
  }

  Future<void> _handleAction(String route) async {
    switch (route) {
      case 'main': await _openMainApp(); break;
      case 'add': _showAddOptions(context); break;
      case 'trades':
        try { await context.read<TradesProvider>().loadOffers(); }
        catch (_) {}
        if (mounted) Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TradeOffersScreen()));
        break;
      case 'map': Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MapScreen())); break;
      case 'chess': Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ChessGameScreen())); break;
      case 'memory': Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MemoryGameScreen())); break;
    }
  }

  void _showAddOptions(BuildContext parentContext) {
    final isDark = Theme.of(parentContext).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    showModalBottomSheet(
      context: parentContext, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Что хотите добавить?', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          Text('Выберите тип объявления',
              style: TextStyle(fontSize: 14, color: subTextColor)),
          const SizedBox(height: 28),
          // Вещь
          GestureDetector(onTap: () {
            Navigator.pop(ctx);
            Navigator.push(parentContext, MaterialPageRoute(
                builder: (_) => const AddItemScreen())).then((_) {
              parentContext.read<ItemsProvider>().loadItems();
            });
          }, child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.withOpacity(0.08),
                Colors.deepOrange.withOpacity(0.04)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.2), width: 1.5),
            ),
            child: Row(children: [
              Container(width: 56, height: 56,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                      borderRadius: BorderRadius.all(Radius.circular(16))),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Одна вещь', style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 4),
                Text('Добавьте одно объявление',
                    style: TextStyle(fontSize: 13, color: subTextColor)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Colors.orange, size: 28),
            ]),
          )),
          const SizedBox(height: 16),
          // Набор
          GestureDetector(onTap: () {
            Navigator.pop(ctx);
            Navigator.push(parentContext, MaterialPageRoute(
                builder: (_) => const CreateBundleScreen())).then((_) {
              parentContext.read<ItemsProvider>().loadItems();
              parentContext.read<BundleProvider>().loadAllBundles();
              parentContext.read<BundleProvider>().loadMyBundles();
            });
          }, child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.purple.withOpacity(0.08),
                Colors.blue.withOpacity(0.04)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple.withOpacity(0.2), width: 1.5),
            ),
            child: Row(children: [
              Container(width: 56, height: 56,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFF512DA8)]),
                      borderRadius: BorderRadius.all(Radius.circular(16))),
                  child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Набор вещей (Сет)', style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 4),
                Text('Объедините несколько вещей',
                    style: TextStyle(fontSize: 13, color: subTextColor)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Colors.purple, size: 28),
            ]),
          )),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 50, child: OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(foregroundColor: subTextColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text('Отмена', style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w600)),
          )),
        ]),
      ),
    );
  }

  Future<void> _openMainApp() async {
    try {
      await Future.wait([
        context.read<ItemsProvider>().loadItems(),
        context.read<TradesProvider>().loadOffers(),
        context.read<BundleProvider>().loadAllBundles(),
      ]);
    } catch (_) {}
    if (mounted) {
      await Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionsBuilder: (_, animation, __, child) {
          const begin = Offset(1.0, 0.0); const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeInOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ));
      await _loadInitialData();
    }
  }

  // ==================== 7. ШАГОМЕР ====================
  Widget _buildStepTracker(bool isDark) {
    final progress = (_todaySteps / 10000).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => safeTap(() async {
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const PedometerScreen()));
      }),
      child: Container(
        height: 110, margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: isDark
                ? [const Color(0xFF1A1D24), const Color(0xFF252830)]
                : [Colors.white, const Color(0xFFF8F9FA)])),
        child: ClipRRect(borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            Positioned.fill(child: Image.asset('assets/images/begom.jpeg',
                fit: BoxFit.cover, colorBlendMode: BlendMode.overlay,
                color: Colors.black.withOpacity(0.4))),
            Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              SizedBox(width: 64, height: 64, child: Stack(
                  alignment: Alignment.center, children: [
                CircularProgressIndicator(value: progress, strokeWidth: 5,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? const Color(0xFF3A86FF) : Colors.orange)),
                Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3))),
                    child: const Icon(Icons.directions_walk_rounded,
                        size: 26, color: Colors.white)),
              ])),
              const SizedBox(width: 16),
              Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$_todaySteps шагов', style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.white, fontSize: 20)),
                const SizedBox(height: 4),
                Text('Цель: 10 000 шагов • Уровень $_level',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
              ])),
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 22)),
            ])),
          ]),
        ),
      ),
    );
  }

  // ==================== 8. ЧАТЫ ====================
  Widget _buildChatsBlock(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => safeTap(() async {
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => const MessengerScreen()));
        }),
        child: Container(
          height: 100,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
              image: const DecorationImage(image: AssetImage('assets/images/chati.jpeg'),
                  fit: BoxFit.cover)),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(colors: [Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.5)])),
            child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
              Container(padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.chat_bubble_rounded, size: 28, color: Colors.white)),
              const SizedBox(width: 16),
              const Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💬 Чаты', style: TextStyle(fontWeight: FontWeight.w800,
                    color: Colors.white, fontSize: 18)),
                SizedBox(height: 4),
                Text('Общайся с другими пользователями',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ])),
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20)),
            ])),
          ),
        ),
      ),
    );
  }

  // ==================== 9. ИГРЫ ====================
  Widget _buildGamesBlock(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => safeTap(() async {
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => const GamesScreen()));
        }),
        child: Container(
          height: 100,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
              image: const DecorationImage(image: AssetImage('assets/images/igri.jpeg'),
                  fit: BoxFit.cover)),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(colors: [Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.5)])),
            child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
              Container(padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.games_rounded, size: 28, color: Colors.white)),
              const SizedBox(width: 16),
              const Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🎮 Игры', style: TextStyle(fontWeight: FontWeight.w800,
                    color: Colors.white, fontSize: 18)),
                SizedBox(height: 4),
                Text('Играй и зарабатывай бонусы',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ])),
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20)),
            ])),
          ),
        ),
      ),
    );
  }

  // ==================== 10. СОВЕТ ДНЯ ====================
  Widget _buildDailyTip(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: LinearGradient(colors: isDark
            ? [const Color(0xFF1A1D24), const Color(0xFF252830)]
            : [Colors.white, const Color(0xFFF8F9FA)]),
            borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.lightbulb_rounded, size: 22, color: Colors.teal)),
          const SizedBox(width: 14),
          Expanded(child: Text(_dailyTip, style: TextStyle(color: textColor,
              fontSize: 13, fontWeight: FontWeight.w600, height: 1.4))),
        ]),
      ),
    );
  }
}

class BannerAd {
  final String id; final String imageUrl; final String title;
  final String subtitle; final String description;
  final String overlayText; final String link;
  BannerAd({required this.id, required this.imageUrl, required this.title,
    required this.subtitle, this.description = '', this.overlayText = '', this.link = ''});
}