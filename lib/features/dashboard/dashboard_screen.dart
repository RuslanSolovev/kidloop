// features/dashboard/dashboard_screen.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'parallax_panel.dart';
import '../life_navigator/ui/widgets/calendar/calendar_weather.dart';

// ==================== MIXINS ====================

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

mixin HapticFeedbackMixin {
  void lightHaptic() => HapticFeedback.lightImpact();
  void mediumHaptic() => HapticFeedback.mediumImpact();
  void heavyHaptic() => HapticFeedback.heavyImpact();
  void selectionHaptic() => HapticFeedback.selectionClick();
}

// ==================== THEME PROVIDER ====================

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

// ==================== BANNER AD MODEL ====================

class BannerAd {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String description;
  final String overlayText;
  final String link;
  final String backgroundColor;
  final String gradientStart;
  final String gradientEnd;
  final int priority;

  BannerAd({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.description = '',
    this.overlayText = '',
    this.link = '',
    this.backgroundColor = '#FF6B00',
    this.gradientStart = '#FF8A3D',
    this.gradientEnd = '#FF6B00',
    this.priority = 0,
  });

  factory BannerAd.fromJson(Map<String, dynamic> json) {
    return BannerAd(
      id: json['banner_id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      description: json['description'] ?? '',
      overlayText: json['overlay_text'] ?? '',
      link: json['link'] ?? '',
      backgroundColor: json['background_color'] ?? '#FF6B00',
      gradientStart: json['gradient_start'] ?? '#FF8A3D',
      gradientEnd: json['gradient_end'] ?? '#FF6B00',
      priority: json['priority'] ?? 0,
    );
  }
}

// ==================== RECOMMENDATION ENGINE ====================

class RecommendationEngine {
  final List<String> _viewHistory = [];
  final Map<String, double> _itemScores = {};

  void addView(String itemId) {
    _viewHistory.add(itemId);
    if (_viewHistory.length > 100) {
      _viewHistory.removeAt(0);
    }
    _itemScores[itemId] = (_itemScores[itemId] ?? 0) + 0.5;
  }

  List<dynamic> getRecommendations(List<dynamic> items, int count) {
    final scored = items.map((item) {
      double score = 0;
      if (item is Item) {
        score = _itemScores[item.itemId] ?? 0;
        score += (item.sv / 100) * 0.3;
      } else if (item is Bundle) {
        score = _itemScores[item.bundleId] ?? 0;
        score += (item.totalSv / 100) * 0.3;
      }
      return MapEntry(item, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(count).map((e) => e.key).toList();
  }

  void clearHistory() {
    _viewHistory.clear();
    _itemScores.clear();
  }
}

// ==================== DASHBOARD SCREEN ====================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, SingleTapMixin, HapticFeedbackMixin {

  // ==================== CONTROLLERS & ANIMATIONS ====================

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _levelProgressController;
  late Animation<double> _levelProgressAnimation;

  // ==================== ПАРАЛЛАКС КОНТРОЛЛЕР ====================
  late PageController _parallaxPageController;
  double _currentPage = 0.0;
  bool _isPanModeActive = false;

  // ==================== DRAG & DROP СОСТОЯНИЕ ====================
  bool _isReorderMode = false;
  int? _draggedIndex;
  List<int> _containerOrder = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  final ScrollController _scrollController = ScrollController();

  final List<String> _containerNames = [
    'Приветствие',
    'Действия',
    'Открыть ленту',
    'Баннеры',
    'Рекомендации',
    'Новые объявления',
    'Быстрые действия',
    'Шагомер',
    'Чаты',
    'Игры'
  ];

  // ==================== STATE ====================

  String _userName = 'Друг';
  String? _avatarUrl;
  String? _currentUserId;
  int _todaySteps = 0;
  int _level = 1;
  int _levelProgress = 0;
  int _maxLevelProgress = 50000;
  String _dailyTip = '';
  List<Item> _latestItems = [];
  List<Bundle> _latestBundles = [];
  List<BannerAd> _banners = [];
  List<dynamic> _recommendedItems = [];
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  final PageController _bannerPageController = PageController();
  final RecommendationEngine _recommendationEngine = RecommendationEngine();
  bool _isRefreshing = false;
  int _unreadMessagesCount = 0;
  int _pendingTradesCount = 0;
  bool _isOnline = true;
  String _statusMessage = 'Сегодня активен';

  // ==================== CONSTANTS ====================

  final List<String> _tips = [
    'Меняйся игрушками — спасай планету! 🌍',
    'Каждая ненужная вещь может стать сокровищем для другого 👶',
    'Сделай 10 000 шагов сегодня и получи бонус! 👟',
    'Обмен вещами экономит до 30 кг CO₂ в год 🌱',
    'Проверь раздел «Обмены» — возможно, тебя ждёт выгодная сделка 🤝',
    'Добавь свои старые игрушки — освободи место и заработай SV 🧸',
    'Каждый обмен — это маленький шаг к большой экологии 🌿',
    'Твои старые игрушки могут сделать кого-то счастливым 🎁',
    'KidLoop — это сообщество заботливых родителей 💚',
    'Новые объявления появляются каждый день! 🔄',
  ];

  static const String _bannerApiUrl =
      'https://functions.yandexcloud.net/d4e9bd6bmvqmife91gf4';

  // ==================== LIFECYCLE ====================

  @override
  void initState() {
    super.initState();

    _parallaxPageController = PageController(
      viewportFraction: 1.0,
      initialPage: 1,
    )..addListener(() {
      setState(() {
        _currentPage = _parallaxPageController.page ?? 1.0;
      });
    });

    _initAnimations();
    _loadInitialData();
    _loadBanners();
    _startBannerAutoScroll();
    _loadCounters();
    _loadContainerOrder();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _levelProgressController.dispose();
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    _parallaxPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== ANIMATIONS INIT ====================

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _levelProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _levelProgressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _levelProgressController, curve: Curves.easeOutCubic),
    );
  }

  // ==================== DATA LOADING ====================

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _loadTodaySteps();
    await _loadCounters();
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
    _generateRecommendations();
  }

  Future<void> _loadContainerOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('container_order');
    if (savedOrder != null && savedOrder.length == 10) {
      setState(() {
        _containerOrder = savedOrder.map((e) => int.parse(e)).toList();
      });
    }
  }

  Future<void> _saveContainerOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'container_order',
      _containerOrder.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _loadCounters() async {
    try {
      final tradesProvider = context.read<TradesProvider>();
      await tradesProvider.loadOffers();
      if (mounted) {
        setState(() {
          _pendingTradesCount = tradesProvider.offers
              .where((t) => t.status == 'pending' || t.status == 'waiting')
              .length;
        });
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    _unreadMessagesCount = prefs.getInt('unread_messages') ?? 0;
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
            _isOnline = map['isOnline'] ?? true;
            _statusMessage = map['status'] ?? 'Сегодня активен';
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
      totalSteps: total,
      itemsCount: itemsCount,
      completedTrades: completedTrades,
      sentOffers: sentOffers,
    );

    final progress = total % 50000;
    final maxProgress = 50000;

    if (mounted) {
      setState(() {
        _todaySteps = steps;
        _level = level;
        _levelProgress = progress;
        _maxLevelProgress = maxProgress;
      });

      _levelProgressAnimation = Tween<double>(
        begin: 0.0,
        end: (progress / maxProgress).clamp(0.0, 1.0),
      ).animate(
        CurvedAnimation(
          parent: _levelProgressController,
          curve: Curves.easeOutCubic,
        ),
      );
      _levelProgressController.forward(from: 0.0);
    }
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
                .map((b) => BannerAd.fromJson(b))
                .toList()
              ..sort((a, b) => b.priority.compareTo(a.priority));
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _banners = [
            BannerAd(
              id: 'default',
              imageUrl: '',
              title: '🔄 Обменивайся вещами!',
              subtitle: 'Найди нужное и отдай ненужное',
              description: 'KidLoop — платформа для обмена детскими вещами.',
              overlayText: 'KIDLOOP',
              gradientStart: '#FF6B00',
              gradientEnd: '#FF8A3D',
            ),
          ];
        });
      }
    }
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

  void _generateRecommendations() {
    final items = context.read<ItemsProvider>().items;
    final bundles = context.read<BundleProvider>().allBundles;
    final allItems = [...items, ...bundles];
    _recommendedItems = _recommendationEngine.getRecommendations(allItems, 6);
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    if (_banners.isEmpty) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_banners.isNotEmpty && mounted) {
        final nextIndex = (_currentBannerIndex + 1) % _banners.length;
        _bannerPageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
        setState(() => _currentBannerIndex = nextIndex);
      }
    });
  }

  // ==================== РЕЖИМ ПЕРЕМЕЩЕНИЯ ====================

  void _handleTwoFingerTap() {
    if (_isPanModeActive) {
      _isPanModeActive = false;
      heavyHaptic();
      _playClickSound();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Позиция зафиксирована'),
          duration: Duration(milliseconds: 500),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _isPanModeActive = true;
      mediumHaptic();
      _playClickSound();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('👆 Перемещайте экран пальцем'),
          duration: Duration(milliseconds: 800),
          backgroundColor: Colors.blue,
        ),
      );
    }
    setState(() {});
  }

  void _toggleReorderMode() {
    setState(() {
      _isReorderMode = !_isReorderMode;
      if (!_isReorderMode) {
        _draggedIndex = null;
        _saveContainerOrder();
      }
    });

    if (_isReorderMode) {
      heavyHaptic();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.drag_indicator, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Зажмите и перетащите, скролл работает',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      selectionHaptic();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Порядок сохранён', style: TextStyle(fontSize: 14)),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _playClickSound() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  // ==================== REFRESH ====================

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    lightHaptic();

    await Future.wait([
      _loadUserData(),
      _loadTodaySteps(),
      _loadCounters(),
      context.read<ItemsProvider>().loadItems(),
      context.read<BundleProvider>().loadAllBundles(),
      context.read<TradesProvider>().loadOffers(),
    ]);

    _loadLatestItems();
    _generateRecommendations();
    _dailyTip = (_tips..shuffle()).first;

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _isRefreshing = false);
      selectionHaptic();
    }
  }

  // ==================== NAVIGATION ====================

  Future<void> _openMainApp() async {
    lightHaptic();
    try {
      await Future.wait([
        context.read<ItemsProvider>().loadItems(),
        context.read<TradesProvider>().loadOffers(),
        context.read<BundleProvider>().loadAllBundles(),
      ]);
    } catch (_) {}

    if (mounted) {
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionsBuilder: (_, animation, __, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: Curves.easeInOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      await _loadInitialData();
    }
  }

  Future<void> _handleAction(String route) async {
    lightHaptic();
    switch (route) {
      case 'main':
        await _openMainApp();
        break;
      case 'add':
        _showAddOptions(context);
        break;
      case 'trades':
        try {
          await context.read<TradesProvider>().loadOffers();
        } catch (_) {}
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TradeOffersScreen()),
          );
        }
        break;
      case 'map':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
        break;
      case 'chess':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChessGameScreen()),
        );
        break;
      case 'memory':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MemoryGameScreen()),
        );
        break;
      case 'games':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GamesScreen()),
        );
        break;
      case 'messenger':
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('unread_messages', 0);
        setState(() => _unreadMessagesCount = 0);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessengerScreen()),
        );
        break;
      case 'pedometer':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PedometerScreen()),
        );
        break;
    }
  }

  void _showAddOptions(BuildContext parentContext) {
    lightHaptic();
    final isDark = Theme.of(parentContext).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Что хотите добавить?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Выберите тип объявления',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 28),

            GestureDetector(
              onTap: () {
                heavyHaptic();
                Navigator.pop(ctx);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(builder: (_) => const AddItemScreen()),
                ).then((_) {
                  parentContext.read<ItemsProvider>().loadItems();
                  _loadLatestItems();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.08),
                      Colors.deepOrange.withOpacity(0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Одна вещь',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Добавьте одно объявление',
                            style: TextStyle(
                              fontSize: 13,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            GestureDetector(
              onTap: () {
                heavyHaptic();
                Navigator.pop(ctx);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(builder: (_) => const CreateBundleScreen()),
                ).then((_) {
                  parentContext.read<ItemsProvider>().loadItems();
                  parentContext.read<BundleProvider>().loadAllBundles();
                  parentContext.read<BundleProvider>().loadMyBundles();
                  _loadLatestItems();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.withOpacity(0.08),
                      Colors.blue.withOpacity(0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Набор вещей (Сет)',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Объедините несколько вещей',
                            style: TextStyle(
                              fontSize: 13,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.purple,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  selectionHaptic();
                  Navigator.pop(ctx);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: subTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Отмена',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,  // ← ТЁМНЫЕ иконки (для светлого фона)
        statusBarBrightness: Brightness.light,      // ← СВЕТЛЫЙ статус-бар
      ),
    );

    final backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
        const Color(0xFF0F1115),
        const Color(0xFF1A1D24),
        const Color(0xFF0F1115),
      ]
          : [
        const Color(0xFFF5F7FA),
        const Color(0xFFFFFFFF),
        const Color(0xFFF5F7FA),
      ],
    );

    return Theme(
      data: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: backgroundGradient,
          ),
          child: Stack(
            children: [
              // ========== ПАРАЛЛАКС PAGE VIEW ==========
              PageView(
                controller: _parallaxPageController,
                physics: _isPanModeActive
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                children: [
                  const LeftPanel(),
                  _buildMainDashboard(isDark),
                  const RightPanel(),
                ],
              ),

              // ========== ИНДИКАТОР СТРАНИЦ ==========
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: _buildPageIndicator(isDark),
              ),

              // ========== КНОПКИ УПРАВЛЕНИЯ ==========
              Positioned(
                bottom: 80,
                right: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Кнопка перетаскивания контейнеров
                    AnimatedScale(
                      scale: _isReorderMode ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: FloatingActionButton(
                        heroTag: 'reorder',
                        onPressed: _toggleReorderMode,
                        backgroundColor: _isReorderMode ? Colors.purple : Colors.blue,
                        mini: true,
                        elevation: 6,
                        shape: const CircleBorder(),
                        child: Icon(
                          _isReorderMode ? Icons.check_rounded : Icons.reorder_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Кнопка режима панорамирования
                    AnimatedScale(
                      scale: _pulseAnimation.value,
                      duration: const Duration(milliseconds: 300),
                      child: FloatingActionButton(
                        heroTag: 'pan',
                        onPressed: _handleTwoFingerTap,
                        backgroundColor: _isPanModeActive ? Colors.red : Colors.orange,
                        elevation: 8,
                        shape: const CircleBorder(),
                        child: Icon(
                          _isPanModeActive ? Icons.lock_rounded : Icons.open_with_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ========== ИНДИКАТОР РЕЖИМА ПЕРЕТАСКИВАНИЯ ==========
              if (_isReorderMode)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Зажмите и перетащите контейнер',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ========== ИНДИКАТОР РЕЖИМА ПАНОРАМИРОВАНИЯ ==========
              if (_isPanModeActive && !_isReorderMode)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drag_handle_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Режим перемещения активен',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ИНДИКАТОР СТРАНИЦ ====================

  Widget _buildPageIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = _currentPage.round() == index;
        return GestureDetector(
          onTap: () {
            if (_isPanModeActive) {
              _parallaxPageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 32 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? Colors.orange
                  : (isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade400),
            ),
          ),
        );
      }),
    );
  }

  // ==================== ОСНОВНОЙ DASHBOARD ====================

  Widget _buildMainDashboard(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);

    // Создаем список виджетов в соответствии с порядком
    final List<Widget Function()> containerBuilders = [
      // 0 - Приветствие с погодой
          () => _buildDraggableContainer(
        index: 0,
        isDark: isDark,
        child: _buildWelcomeHeaderWithWeather(isDark),
      ),
      // 1 - Действия
          () => _buildDraggableContainer(
        index: 1,
        isDark: isDark,
        child: _buildTopActions(isDark, textColor),
      ),
      // 2 - Открыть ленту
          () => _buildDraggableContainer(
        index: 2,
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildOpenAppButton(isDark),
        ),
      ),
      // 3 - Баннеры
          () {
        if (_banners.isEmpty) return const SizedBox.shrink();
        return _buildDraggableContainer(
          index: 3,
          isDark: isDark,
          child: _buildBannerCarousel(isDark),
        );
      },
      // 4 - Рекомендации
          () {
        if (_recommendedItems.isEmpty) return const SizedBox.shrink();
        return _buildDraggableContainer(
          index: 4,
          isDark: isDark,
          child: _buildRecommendations(isDark, textColor),
        );
      },
      // 5 - Новые объявления
          () => _buildDraggableContainer(
        index: 5,
        isDark: isDark,
        child: _buildLatestItemsCarousel(isDark, textColor),
      ),
      // 6 - Быстрые действия
          () => _buildDraggableContainer(
        index: 6,
        isDark: isDark,
        child: _buildQuickActions(isDark, textColor),
      ),
      // 7 - Шагомер
          () => _buildDraggableContainer(
        index: 7,
        isDark: isDark,
        child: _buildStepTracker(isDark),
      ),
      // 8 - Чаты
          () => _buildDraggableContainer(
        index: 8,
        isDark: isDark,
        child: _buildChatsBlock(isDark),
      ),
      // 9 - Игры
          () => _buildDraggableContainer(
        index: 9,
        isDark: isDark,
        child: _buildGamesBlock(isDark),
      ),
    ];

    // Строим список слайверов в соответствии с порядком
    List<Widget> slivers = [];
    for (int i = 0; i < _containerOrder.length; i++) {
      final containerIndex = _containerOrder[i];
      final widget = containerBuilders[containerIndex]();
      slivers.add(SliverToBoxAdapter(child: widget));

      // Добавляем отступы между контейнерами
      if (i < _containerOrder.length - 1) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
      }
    }

    // Добавляем совет дня в конец
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: _buildDailyTip(isDark, textColor),
        ),
      ),
    );
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 40)));

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.orange,
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        child: CustomScrollView(
          controller: _scrollController,
          physics: _isReorderMode
              ? const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          )
              : const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: slivers,
        ),
      ),
    );
  }

  // ==================== DRAGGABLE CONTAINER WRAPPER ====================

  Widget _buildDraggableContainer({
    required int index,
    required bool isDark,
    required Widget child,
  }) {
    if (!_isReorderMode) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: child,
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: LongPressDraggable<int>(
        data: index,
        delay: Duration(milliseconds: 300),
        onDragStarted: () {
          mediumHaptic();
          setState(() {
            _draggedIndex = index;
          });
        },
        onDragUpdate: (details) {
          // НОВОЕ: Автоматический скролл при перетаскивании
          _handleDragScroll(details.globalPosition);
        },
        onDragEnd: (details) {
          setState(() {
            _draggedIndex = null;
          });
          _saveContainerOrder();
        },
        onDraggableCanceled: (velocity, offset) {
          setState(() {
            _draggedIndex = null;
          });
        },
        feedback: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(20),
          shadowColor: Colors.purple.withOpacity(0.5),
          child: Container(
            width: MediaQuery.of(context).size.width - 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.purple.withOpacity(0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Opacity(
              opacity: 0.85,
              child: child,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.purple.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: child,
          ),
        ),
        child: DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            return details.data != index;
          },
          onAcceptWithDetails: (details) {
            heavyHaptic();
            final fromIndex = details.data;
            final toIndex = _containerOrder.indexOf(index);
            final fromOrderIndex = _containerOrder.indexOf(fromIndex);

            setState(() {
              final item = _containerOrder.removeAt(fromOrderIndex);
              _containerOrder.insert(toIndex, item);
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ "${_containerNames[fromIndex]}" перемещён',
                  style: TextStyle(fontSize: 13),
                ),
                duration: Duration(milliseconds: 800),
                backgroundColor: Colors.purple.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(
                vertical: isHovering ? 8.0 : 0.0,
                horizontal: isHovering ? 4.0 : 0.0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: isHovering
                    ? Border.all(
                  color: Colors.purple.withOpacity(0.8),
                  width: 2.5,
                )
                    : _draggedIndex == index
                    ? Border.all(
                  color: Colors.purple.withOpacity(0.5),
                  width: 2,
                )
                    : null,
                boxShadow: isHovering
                    ? [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ]
                    : null,
              ),
              child: Stack(
                children: [
                  child,
                  if (_isReorderMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

// НОВЫЙ МЕТОД: Автоматический скролл при перетаскивании
  void _handleDragScroll(Offset globalPosition) {
    if (!_isReorderMode || !_scrollController.hasClients) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(globalPosition);
    final double screenHeight = renderBox.size.height;

    // Зоны активации скролла (верхние и нижние 15% экрана)
    final double topZone = screenHeight * 0.15;
    final double bottomZone = screenHeight * 0.85;

    double scrollSpeed = 0;

    if (localPosition.dy < topZone) {
      // Ближе к верху - скроллим вверх
      scrollSpeed = -((topZone - localPosition.dy) / topZone) * 15;
    } else if (localPosition.dy > bottomZone) {
      // Ближе к низу - скроллим вниз
      scrollSpeed = ((localPosition.dy - bottomZone) / (screenHeight - bottomZone)) * 15;
    }

    if (scrollSpeed != 0) {
      final newOffset = _scrollController.offset + scrollSpeed;
      _scrollController.jumpTo(
        newOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  // ==================== WELCOME HEADER С ПОГОДОЙ ====================

  Widget _buildWelcomeHeaderWithWeather(bool isDark) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/vverh.jpeg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black54,
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isOnline
                              ? [Colors.green.shade400, Colors.green.shade700]
                              : [Colors.grey.shade400, Colors.grey.shade600],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
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
                            fontSize: 24,
                          ),
                        )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnline ? Colors.green.shade400 : Colors.grey,
                          border: Border.all(
                            color: Colors.black.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Привет, $_userName!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Уровень $_level',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.red,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _statusMessage,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_currentUserId == '68a878d2-0c31-46f9-917a-898ff9403311')
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => safeTap(() async {
                        lightHaptic();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageBannersScreen(),
                          ),
                        );
                        await _loadBanners();
                      }),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'До уровня ${_level + 1}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_levelProgress} / $_maxLevelProgress',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: _levelProgressAnimation,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _levelProgressAnimation.value.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange.shade400,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ========== ВСТРОЕННЫЙ БЛОК ПОГОДЫ ==========
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: AssetImage('assets/images/pogoda.jpeg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: const CalendarWeather(
                  isDark: true,
                  transparent: true,  // ← ВКЛЮЧАЕМ прозрачный режим
                  compact: false,      // ← КРУПНЫЙ текст
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TOP ACTIONS ====================

  Widget _buildTopActions(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => safeTap(() async {
                lightHaptic();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                await _loadUserData();
              }),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF8A3D), Color(0xFFFF6B00)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
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
              onTap: () {
                lightHaptic();
                context.read<ThemeProvider>().toggleTheme();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 64,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  color: isDark
                      ? const Color(0xFF2A2D35)
                      : Colors.grey.shade200,
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: isDark
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.all(3),
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
                            isDark
                                ? Icons.nightlight_round
                                : Icons.wb_sunny_rounded,
                            key: ValueKey(isDark),
                            color: Colors.white,
                            size: 16,
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
      ),
    );
  }

  // ==================== OPEN APP BUTTON ====================

  Widget _buildOpenAppButton(bool isDark) {
    return GestureDetector(
      onTap: () => safeTap(_openMainApp),
      child: Container(
        height: 230,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage('assets/images/veshi.jpeg'),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange,
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Открыть полную ленту',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Все объявления в одном месте',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BANNER CAROUSEL ====================

  Widget _buildBannerCarousel(bool isDark) {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _bannerPageController,
            onPageChanged: (i) {
              setState(() => _currentBannerIndex = i);
              selectionHaptic();
            },
            itemCount: _banners.length,
            itemBuilder: (ctx, i) {
              final b = _banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => safeTap(() async {
                    lightHaptic();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BannerDetailScreen(banner: b),
                      ),
                    );
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (b.imageUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: b.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(int.parse('0xFF${b.gradientStart.replaceFirst('#', '')}')),
                                      Color(int.parse('0xFF${b.gradientEnd.replaceFirst('#', '')}')),
                                    ],
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(int.parse('0xFF${b.gradientStart.replaceFirst('#', '')}')),
                                      Color(int.parse('0xFF${b.gradientEnd.replaceFirst('#', '')}')),
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
                                    Color(int.parse('0xFF${b.gradientStart.replaceFirst('#', '')}')),
                                    Color(int.parse('0xFF${b.gradientEnd.replaceFirst('#', '')}')),
                                  ],
                                ),
                              ),
                            ),

                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: b.overlayText.isNotEmpty
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (b.overlayText.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      b.overlayText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Text(
                                  b.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  b.subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
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
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _banners.length,
                    (i) => GestureDetector(
                  onTap: () {
                    selectionHaptic();
                    _bannerPageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i == _currentBannerIndex ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _currentBannerIndex
                          ? Colors.orange
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==================== RECOMMENDATIONS ====================

  Widget _buildRecommendations(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
            const Color(0xFF1A1D24).withOpacity(0.95),
            const Color(0xFF2A2D35).withOpacity(0.9),
            const Color(0xFF1A1D24).withOpacity(0.95),
          ]
              : [
            Colors.teal.shade50.withOpacity(0.8),
            Colors.teal.shade100.withOpacity(0.5),
            Colors.teal.shade50.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🎯 Для вас',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: () => safeTap(_openMainApp),
                  child: Text(
                    'Все',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF3A86FF) : Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _recommendedItems.length,
              itemBuilder: (ctx, i) {
                final item = _recommendedItems[i];
                if (item is Bundle) {
                  return _buildRecommendBundleCard(item);
                } else if (item is Item) {
                  return _buildRecommendItemCard(item);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendItemCard(Item item) {
    return GestureDetector(
      onTap: () => safeTap(() async {
        lightHaptic();
        _recommendationEngine.addView(item.itemId);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(item: item),
          ),
        );
      }),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.imagePaths.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.imagePaths.first,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.shade300),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey.shade300),
                )
              else
                Container(color: Colors.grey.shade300),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Рек.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.sv} SV',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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

  Widget _buildRecommendBundleCard(Bundle bundle) {
    return GestureDetector(
      onTap: () => safeTap(() async {
        lightHaptic();
        _recommendationEngine.addView(bundle.bundleId);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BundleDetailsScreen(bundle: bundle),
          ),
        );
      }),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B1FA2).withOpacity(0.8),
                      const Color(0xFF512DA8).withOpacity(0.9),
                    ],
                  ),
                ),
              ),
              if (bundle.items.isNotEmpty) _buildItemGrid(bundle.items),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Набор',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bundle.items.length} пред. • ${bundle.totalSv} SV',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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

  // ==================== LATEST ITEMS ====================

  Widget _buildLatestItemsCarousel(bool isDark, Color textColor) {
    if (_latestItems.isEmpty && _latestBundles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
            const Color(0xFF1A1D24).withOpacity(0.95),
            const Color(0xFF2A2D35).withOpacity(0.9),
            const Color(0xFF1A1D24).withOpacity(0.95),
          ]
              : [
            Colors.orange.shade50.withOpacity(0.8),
            Colors.orange.shade100.withOpacity(0.5),
            Colors.orange.shade50.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🔥 Новые объявления',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: () => safeTap(_openMainApp),
                  child: Text(
                    'Все',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF3A86FF) : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _latestItems.length + _latestBundles.length,
              itemBuilder: (ctx, i) {
                if (i < _latestBundles.length) {
                  return _buildLatestBundleCard(_latestBundles[i]);
                } else {
                  return _buildLatestItemCard(_latestItems[i - _latestBundles.length]);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestItemCard(Item item) {
    return GestureDetector(
      onTap: () => safeTap(() async {
        lightHaptic();
        _recommendationEngine.addView(item.itemId);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(item: item),
          ),
        );
      }),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.imagePaths.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.imagePaths.first,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.shade300),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey.shade300),
                )
              else
                Container(color: Colors.grey.shade300),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.sv} SV',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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

  Widget _buildLatestBundleCard(Bundle bundle) {
    return GestureDetector(
      onTap: () => safeTap(() async {
        lightHaptic();
        _recommendationEngine.addView(bundle.bundleId);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BundleDetailsScreen(bundle: bundle),
          ),
        );
      }),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B1FA2).withOpacity(0.8),
                      const Color(0xFF512DA8).withOpacity(0.9),
                    ],
                  ),
                ),
              ),
              if (bundle.items.isNotEmpty) _buildItemGrid(bundle.items),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bundle.items.length} пред. • ${bundle.totalSv} SV',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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

  // ==================== ITEM GRID ====================

  Widget _buildItemGrid(List<BundleItem> items) {
    final showItems = items.take(6).toList();
    final remaining = items.length - 6;

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _gridCell(showItems, 0),
                _gridCell(showItems, 1),
                _gridCell(showItems, 2),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _gridCell(showItems, 3),
                _gridCell(showItems, 4),
                _gridCell(showItems, 5),
              ],
            ),
          ),
          if (remaining > 0)
            Container(
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '+$remaining ещё',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

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
              ? CachedNetworkImage(
            imageUrl: item.imagePath,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _gridCellPlaceholder(item),
          )
              : _gridCellPlaceholder(item),
        ),
      ),
    );
  }

  Widget _gridCellPlaceholder(BundleItem item) {
    return Container(
      color: Colors.white.withOpacity(0.15),
      child: Center(
        child: Text(
          '${item.sv}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==================== QUICK ACTIONS ====================

  Widget _buildQuickActions(bool isDark, Color textColor) {
    final actions = [
      {'label': 'Лента', 'image': 'assets/images/lenta.jpeg', 'route': 'main'},
      {'label': 'Добавить', 'image': 'assets/images/dobavit.jpeg', 'route': 'add'},
      {'label': 'Обмены', 'image': 'assets/images/obmen.jpeg', 'route': 'trades'},
      {'label': 'Карта', 'image': 'assets/images/karti.jpeg', 'route': 'map'},
      {'label': 'Шахматы', 'image': 'assets/images/shahmati.jpeg', 'route': 'chess'},
      {'label': 'Запомни', 'image': 'assets/images/cifri.jpeg', 'route': 'memory'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
            const Color(0xFF0F1115).withOpacity(0.95),
            const Color(0xFF1A1D24).withOpacity(0.9),
            const Color(0xFF0F1115).withOpacity(0.95),
          ]
              : [
            Colors.blue.shade50,
            Colors.purple.shade50,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '⚡ Быстрые действия',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.separated(
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
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            a['image'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.75),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                a['label'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  // ==================== STEP TRACKER ====================

  Widget _buildStepTracker(bool isDark) {
    final progress = (_todaySteps / 10000).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => safeTap(() async {
        lightHaptic();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PedometerScreen()),
        );
        await _loadTodaySteps();
      }),
      child: Container(
        height: 110,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A1D24), const Color(0xFF252830)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/begom.jpeg',
                  fit: BoxFit.cover,
                  colorBlendMode: BlendMode.overlay,
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _levelProgressAnimation,
                            builder: (context, child) {
                              return CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 5,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark ? const Color(0xFF3A86FF) : Colors.orange,
                                ),
                              );
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_walk_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_todaySteps шагов',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Цель: 10 000 шагов • Уровень $_level',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 22,
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

  // ==================== CHATS BLOCK ====================

  Widget _buildChatsBlock(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => safeTap(() async {
          lightHaptic();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('unread_messages', 0);
          setState(() => _unreadMessagesCount = 0);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MessengerScreen()),
          );
        }),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: const DecorationImage(
              image: AssetImage('assets/images/chati.jpeg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        const Icon(
                          Icons.chat_bubble_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                        if (_unreadMessagesCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                _unreadMessagesCount > 9 ? '9+' : '$_unreadMessagesCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💬 Чаты',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Общайся с другими пользователями',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== GAMES BLOCK ====================

  Widget _buildGamesBlock(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => safeTap(() async {
          lightHaptic();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GamesScreen()),
          );
        }),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: const DecorationImage(
              image: AssetImage('assets/images/igri.jpeg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.games_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎮 Игры',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Играй и зарабатывай бонусы',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== DAILY TIP ====================

  Widget _buildDailyTip(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A1D24), const Color(0xFF252830)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.teal.shade400,
                    Colors.teal.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.lightbulb_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _dailyTip,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}