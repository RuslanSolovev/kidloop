// features/dashboard/dashboard_screen.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../../core/items_provider.dart';
import '../../core/trades_provider.dart';
import '../../core/item_model.dart';
import '../../navigation/main_navigation_screen.dart';
import '../item_details/item_details_screen.dart'; // Добавляем импорт
import '../profile/profile_screen.dart';
import '../add_item/add_item_screen.dart';
import '../feed/presentation/trade_offers_screen.dart';
import '../games/games_screen.dart';
import '../games/memory_game/memory_game_screen.dart';
import '../games/chess/chess_game_screen.dart';
import '../pedometer/pedometer_screen.dart';
import 'manage_banners_screen.dart';
import 'banner_detail_screen.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _userName = 'Друг';
  String? _avatarUrl;
  String? _currentUserId;
  int _todaySteps = 0;
  int _level = 1;
  String _dailyTip = '';
  List<Item> _latestItems = [];

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
      if (itemsProvider.items.isEmpty) {
        await itemsProvider.loadItems();
      }
    } catch (e) {
      print("Ошибка загрузки items: $e");
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
            _banners = (data['banners'] as List)
                .map((b) => BannerAd(
              id: b['banner_id'] ?? '',
              imageUrl: b['image_url'] ?? '',
              title: b['title'] ?? '',
              subtitle: b['subtitle'] ?? '',
              description: b['description'] ?? '',
              overlayText: b['overlay_text'] ?? '',
              link: b['link'] ?? '',
            ))
                .toList();
          });
        }
      }
    } catch (_) {
      setState(() {
        _banners = [
          BannerAd(
            id: 'default',
            imageUrl: '',
            title: '🔄 Обменивайся вещами!',
            subtitle: 'Найди нужное и отдай ненужное',
            description: 'KidLoop — это платформа для обмена детскими вещами.',
            overlayText: 'KIDLOOP',
          ),
        ];
      });
    }
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_banners.isNotEmpty && mounted) {
        final nextIndex = (_currentBannerIndex + 1) % _banners.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
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
    if (mounted) {
      setState(() {
        _todaySteps = steps;
        _level = (total / 50000).floor() + 1;
      });
    }
  }

  void _loadLatestItems() {
    try {
      final items = context.read<ItemsProvider>().items;
      if (mounted) {
        setState(() => _latestItems = items.take(10).toList());
      }
    } catch (e) {
      print("Ошибка загрузки последних items: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final backgroundColor =
    isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

    return Theme(
      data: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        scaffoldBackgroundColor: backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildWelcomeHeader(isDark),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildTopActions(isDark, textColor),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 10)),
              if (_banners.isNotEmpty)
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildBannerCarousel(isDark),
                  ),
                ),
              if (_banners.isNotEmpty)
                SliverToBoxAdapter(child: const SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildOpenAppButton(),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildLatestItemsCarousel(isDark, surfaceColor, textColor),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildQuickActions(isDark, textColor),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildStepTracker(isDark),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildGamesSection(isDark, textColor, subTextColor, surfaceColor),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildDailyTip(isDark, textColor),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  // Приветствие
  Widget _buildWelcomeHeader(bool isDark) {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/vverh.jpeg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.6),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: _avatarUrl != null
                      ? CachedNetworkImageProvider(_avatarUrl!)
                      : null,
                  child: _avatarUrl == null
                      ? Text(
                    _userName.isNotEmpty
                        ? _userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Привет, $_userName!',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Colors.orange, Colors.deepOrange]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Уровень $_level',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentUserId == '68a878d2-0c31-46f9-917a-898ff9403311')
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.campaign_rounded,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManageBannersScreen()),
                      ),
                      tooltip: 'Управление баннерами',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ((_todaySteps % 50000) / 50000).clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'До следующего уровня: ${50000 - (_todaySteps % 50000)} шагов',
              style:
              TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  // Панель с кнопкой профиля и переключателем темы
  Widget _buildTopActions(bool isDark, Color textColor) {
    final backgroundColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ).then((_) => _loadUserData());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Профиль',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<ThemeProvider>().toggleTheme(),
            child: Container(
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200,
                border: Border.all(
                  color: Colors.orange.withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 300),
                    alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFFE94560), const Color(0xFFFF6B6B)]
                              : [Colors.orange, Colors.orange.shade700],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isDark ? Icons.nightlight_round : Icons.wb_sunny,
                          key: ValueKey(isDark),
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Баннер
  Widget _buildBannerCarousel(bool isDark) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) =>
                setState(() => _currentBannerIndex = index),
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => BannerDetailScreen(banner: banner)),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (banner.imageUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: banner.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.shade400,
                                      Colors.deepOrange.shade400
                                    ],
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.shade400,
                                      Colors.deepOrange.shade400
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade400,
                                    Colors.deepOrange.shade400
                                  ],
                                ),
                              ),
                            ),
                          Container(color: Colors.black.withOpacity(0.3)),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment:
                              banner.overlayText.isNotEmpty
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (banner.overlayText.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      banner.overlayText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Text(
                                  banner.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  banner.subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (i) {
                return GestureDetector(
                  onTap: () => _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _currentBannerIndex ? 20 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _currentBannerIndex
                          ? Colors.orange
                          : (isDark
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey.shade400),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // Новые объявления
  Widget _buildLatestItemsCarousel(
      bool isDark, Color surfaceColor, Color textColor) {
    if (_latestItems.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '🔥 Новые объявления',
            style: TextStyle(
                color: textColor, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _latestItems.length,
            itemBuilder: (ctx, i) {
              final item = _latestItems[i];
              return GestureDetector(
                // 🔥 Теперь открывает детали именно этого объявления
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ItemDetailsScreen(item: item),
                    ),
                  );
                },
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: surfaceColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.15 : 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14)),
                          child: item.imagePaths.isNotEmpty
                              ? CachedNetworkImage(
                            imageUrl: item.imagePaths.first,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                              : Container(color: Colors.grey.shade200),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          item.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Быстрые действия - БЕЗ ИКОНОК, только текст на фоне
  Widget _buildQuickActions(bool isDark, Color textColor) {
    final actions = [
      {
        'label': 'Лента',
        'image': 'assets/images/lenta.jpeg',
        'route': 'main'
      },
      {
        'label': 'Добавить',
        'image': 'assets/images/dobavit.jpeg',
        'route': 'add'
      },
      {
        'label': 'Обмены',
        'image': 'assets/images/obmen.jpeg',
        'route': 'trades'
      },
      {
        'label': 'Игры',
        'image': 'assets/images/igri.jpeg',
        'route': 'games'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚡ Быстрые действия',
            style: TextStyle(
                color: textColor, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: actions.length,
            itemBuilder: (ctx, i) {
              final a = actions[i];
              return GestureDetector(
                onTap: () => _handleAction(a['route'] as String),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Фоновое изображение
                        Image.asset(
                          a['image'] as String,
                          fit: BoxFit.cover,
                        ),
                        // Затемнение для читаемости текста
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        // Только текст, без иконки
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                a['label'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleAction(String route) async {
    switch (route) {
      case 'main':
        _openMainApp();
        break;
      case 'add':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddItemScreen()));
        break;
      case 'trades':
        try {
          await context.read<TradesProvider>().loadOffers();
        } catch (e) {
          print("Ошибка загрузки обменов: $e");
        }
        if (mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TradeOffersScreen()));
        }
        break;
      case 'games':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GamesScreen()));
        break;
    }
  }

  void _openMainApp() async {
    try {
      await Future.wait([
        context.read<ItemsProvider>().loadItems(),
        context.read<TradesProvider>().loadOffers(),
      ]);
    } catch (e) {
      print("Ошибка загрузки: $e");
    }

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
      );
      await _loadInitialData();
    }
  }

  // Шагомер
  Widget _buildStepTracker(bool isDark) {
    final progress = (_todaySteps / 10000).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PedometerScreen()),
        ),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/begom.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),
                Container(color: Colors.black.withOpacity(0.4)),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 4,
                              color: Colors.white,
                              backgroundColor: Colors.white.withOpacity(0.3),
                            ),
                            Icon(Icons.directions_walk,
                                size: 22, color: Colors.white),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_todaySteps шагов сегодня',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Цель: 10 000 шагов',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chevron_right_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Игры
  Widget _buildGamesSection(bool isDark, Color textColor, Color subTextColor,
      Color surfaceColor) {
    final games = [
      {
        'label': 'Запомни число',
        'image': 'assets/images/cifri.jpeg',
        'screen': const MemoryGameScreen(),
      },
      {
        'label': 'Шахматы',
        'image': 'assets/images/shahmati.jpeg',
        'screen': const ChessGameScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 Развлечения',
            style: TextStyle(
                color: textColor, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: games.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final g = games[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => g['screen'] as Widget),
                  ),
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            g['image'] as String,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              g['label'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Совет дня
  Widget _buildDailyTip(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.teal.withOpacity(0.1),
              Colors.blue.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_rounded, size: 20, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _dailyTip,
                style: TextStyle(color: textColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Кнопка
  Widget _buildOpenAppButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _openMainApp,
        icon: const Icon(Icons.explore_rounded, size: 18),
        label: const Text(
          'Открыть полную ленту',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          shadowColor: Colors.orange.withOpacity(0.4),
        ),
      ),
    );
  }
}

class BannerAd {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String description;
  final String overlayText;
  final String link;

  BannerAd({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.description = '',
    this.overlayText = '',
    this.link = '',
  });
}