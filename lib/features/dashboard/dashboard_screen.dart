// features/dashboard/dashboard_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bundle_model.dart';
import '../../core/bundle_provider.dart';
import '../../core/item_model.dart';
import '../../core/items_provider.dart';
import '../../core/level_calculator.dart';
import '../../core/trades_provider.dart';
import '../../navigation/main_navigation_screen.dart';

import '../add_item/add_item_screen.dart';
import '../bundles/bundle_details_screen.dart';
import '../bundles/create_bundle_screen.dart';
import '../feed/presentation/trade_offers_screen.dart';
import '../games/chess/chess_game_screen.dart';
import '../games/games_screen.dart';
import '../games/memory_game/memory_game_screen.dart';
import '../item_details/item_details_screen.dart';
import '../life_navigator/ui/widgets/calendar/calendar_weather.dart';
import '../map/map_screen.dart';
import '../messenger/messenger_screen.dart';
import '../pedometer/pedometer_screen.dart';
import '../profile/profile_screen.dart';

import 'banner_detail_screen.dart';
import 'manage_banners_screen.dart';
import 'parallax_panel.dart';
import 'widgets/pulse_card.dart';

// ============================================================
// MIXINS
// ============================================================

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

// ============================================================
// THEME PROVIDER
// ============================================================

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

// ============================================================
// DESIGN TOKENS
// ============================================================

class AppTokens {
  static const Color accent = Color(0xFFFF6B00);
  static const Color accentDark = Color(0xFFE85D00);
  static const Color violet = Color(0xFF6C5CE7);
  static const Color blue = Color(0xFF4F7CFF);
  static const Color green = Color(0xFF00A884);
  static const Color ink = Color(0xFF121216);
  static const Color white = Color(0xFFFFFFFF);

  static const Color darkBg = Color(0xFF0F0F10);
  static const Color darkSurface = Color(0xFF171719);
  static const Color darkCard = Color(0xFF1D1D20);
  static const Color darkBorder = Color(0xFF2A2A2E);

  static const Color lightBg = Color(0xFFF7F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8E8E4);

  static const Color textDark = Color(0xFF171717);
  static const Color textSecondary = Color(0xFF777777);

  static const double radiusSm = 14;
  static const double radiusMd = 20;
  static const double radiusLg = 28;

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}

// ============================================================
// BANNER MODEL
// ============================================================

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
      id: json['banner_id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      overlayText: json['overlay_text']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      backgroundColor: json['background_color']?.toString() ?? '#FF6B00',
      gradientStart: json['gradient_start']?.toString() ?? '#FF8A3D',
      gradientEnd: json['gradient_end']?.toString() ?? '#FF6B00',
      priority: json['priority'] is int
          ? json['priority'] as int
          : int.tryParse(json['priority']?.toString() ?? '') ?? 0,
    );
  }
}

// ============================================================
// RECOMMENDATIONS
// ============================================================

class RecommendationEngine {
  final List<String> _viewHistory = [];
  final Map<String, double> _itemScores = {};

  void addView(String itemId) {
    _viewHistory.add(itemId);
    if (_viewHistory.length > 100) _viewHistory.removeAt(0);
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

// ============================================================
// DASHBOARD
// ============================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, SingleTapMixin, HapticFeedbackMixin {
  // ==========================================================
  // ADMIN / API
  // ==========================================================

  static const String _adminUserId = '68a878d2-0c31-46f9-917a-898ff9403311';
  static const String _bannerApiUrl =
      'https://functions.yandexcloud.net/d4e9bd6bmvqmife91gf4';
  static const String _statsApiUrl =
      'https://functions.yandexcloud.net/d4ejmhrgofllrks14a7s';

  // ==========================================================
  // ANIMATION
  // ==========================================================

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _levelProgressController;
  late Animation<double> _levelProgressAnimation;

  // ==========================================================
  // PARALLAX
  // ==========================================================

  late PageController _parallaxPageController;
  double _currentPage = 1.0;
  bool _isPanModeActive = false;

  // ==========================================================
  // REORDER
  // ==========================================================

  bool _isReorderMode = false;
  int? _draggedIndex;
  // 9 контейнеров: 0..7 старые + 8 — PulseCard
  List<int> _containerOrder = [0, 8, 1, 2, 3, 4, 5, 6, 7];
  final ScrollController _scrollController = ScrollController();

  // ==========================================================
  // DATA
  // ==========================================================

  String _userName = 'Друг';
  String? _avatarUrl;
  String? _currentUserId;
  int _todaySteps = 0;
  int _level = 1;
  int _levelProgress = 0;
  int _maxLevelProgress = 50000;
  String _dailyTip = '';

  // ---- Факты дня (ровно 5 штук из сети) ----
  List<String> _todayFacts = [];
  bool _isLoadingFacts = false;
  bool _isFactsExpanded = false;

  // ---- Глобальная статистика KidLoop ----
  Map<String, dynamic>? _globalStats;
  bool _statsLoading = true;

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

  // ==========================================================
  // PANEL
  // ==========================================================

  bool _isPanelOpen = false;
  final Duration _panelAnimationDuration = const Duration(milliseconds: 300);
  late AnimationController _panelController;
  late Animation<double> _panelAnimation;

  // ==========================================================
  // TIPS
  // ==========================================================

  final List<String> _tips = [
    'Меняйся игрушками — спасай планету! 🌍',
    'Каждая ненужная вещь может стать сокровищем для другого 👶',
    'Сделай 10 000 шагов сегодня и получи бонус! 👟',
    'Обмен вещами экономит ресурсы и деньги 🌱',
    'Проверь раздел «Обмены» — возможно, тебя ждёт выгодная сделка 🤝',
    'Добавь свои старые игрушки и освободи место дома 🧸',
    'Каждый обмен — маленький шаг к большой экологии 🌿',
    'Твои старые вещи могут сделать кого-то счастливым 🎁',
    'KidLoop — место, где вещи получают вторую жизнь 💚',
    'Новые объявления появляются каждый день 🔄',
  ];

  /// Является ли текущий пользователь админом.
  bool get _isAdmin => _currentUserId == _adminUserId;

  // ==========================================================
  // LIFECYCLE
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _levelProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _levelProgressAnimation = const AlwaysStoppedAnimation(0.0);

    _panelController = AnimationController(
      vsync: this,
      duration: _panelAnimationDuration,
      value: 0,
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    );

    _parallaxPageController = PageController(initialPage: 1)
      ..addListener(() {
        if (!mounted) return;
        final page = _parallaxPageController.page ?? 1.0;
        if ((page - _currentPage).abs() < 0.01) return;
        setState(() {
          _currentPage = page;
        });
      });

    _fadeController.forward();

    _loadInitialData();
    _loadBanners();
    _startBannerAutoScroll();
    _loadCounters();
    _loadContainerOrder();
    _loadFactsWithFallback();
    _loadGlobalStats();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _levelProgressController.dispose();
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    _parallaxPageController.dispose();
    _scrollController.dispose();
    _panelController.dispose();
    _isLoadingFacts = false;
    super.dispose();
  }

  // ==========================================================
  // GLOBAL STATS
  // ==========================================================

  Future<void> _loadGlobalStats() async {
    try {
      final response = await http.post(
        Uri.parse(_statsApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'get-global-stats'}),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        setState(() {
          _globalStats = data['stats'];
          _statsLoading = false;
        });
      } else {
        setState(() => _statsLoading = false);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки статистики: $e');
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  // ==========================================================
  // FACTS LOADING (без таймаутов, без локальных заглушек)
  // ==========================================================

  Future<void> _loadFactsWithFallback() async {
    if (_isLoadingFacts) return;
    if (!mounted) return;

    setState(() {
      _isLoadingFacts = true;
      _todayFacts = [];
    });

    final pool = <String>[];
    final seen = <String>{};

    try {
      final batches = await Future.wait([
        _loadOnThisDayList('events'),
        _loadOnThisDayList('births'),
        _loadOnThisDayList('holidays'),
        _loadOnThisDayList('deaths'),
      ]);

      for (final batch in batches) {
        for (final f in batch) {
          if (seen.add(f)) pool.add(f);
        }
      }
      debugPrint('Факты: короткие категории → ${pool.length}');

      if (pool.length < 5) {
        final featured = await _loadWikipediaFeatured();
        if (featured != null) {
          final f = _shortenFact(featured);
          if (seen.add(f)) pool.add(f);
        }
        debugPrint('Факты: +featured → ${pool.length}');
      }

      int attempts = 0;
      while (pool.length < 5 && attempts < 15) {
        attempts++;
        try {
          final random = await _loadWikipediaRandom();
          if (random != null) {
            final f = _shortenFact(random);
            if (seen.add(f)) pool.add(f);
          }
        } catch (e) {
          debugPrint('Факты: random #$attempts упал: $e');
        }
      }
      debugPrint('Факты: после random → ${pool.length} (попыток: $attempts)');

      pool.shuffle();

      if (mounted) {
        setState(() {
          _todayFacts = pool.take(5).toList();
          _isLoadingFacts = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки фактов: $e');
      if (mounted) {
        setState(() {
          _todayFacts = pool.take(5).toList();
          _isLoadingFacts = false;
        });
      }
    }
  }

  Future<List<String>> _loadOnThisDayList(String category) async {
    try {
      final now = DateTime.now();
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');

      final url =
          'https://api.wikimedia.org/feed/v1/wikipedia/ru/onthisday/all/$m/$d';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
          'KidLoopApp/1.0 (https://kidloop.app; contact@kidloop.app)',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('onthisday[$category] HTTP ${response.statusCode}');
        return const [];
      }

      final data = jsonDecode(response.body);
      final list = data[category];
      if (list is! List) return const [];

      final result = <String>[];
      for (final item in list) {
        final text = _cleanHtml(
          item['text']?.toString() ??
              item['title']?.toString() ??
              item['description']?.toString() ??
              '',
        );
        if (text.isNotEmpty) result.add(text);
      }
      return result;
    } catch (e) {
      debugPrint('onthisday[$category] error: $e');
      return const [];
    }
  }

  Future<String?> _loadWikipediaFeatured() async {
    try {
      final now = DateTime.now();
      final y = now.year;
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');

      final response = await http.get(
        Uri.parse(
          'https://api.wikimedia.org/feed/v1/wikipedia/ru/featured/$y/$m/$d',
        ),
        headers: {
          'User-Agent':
          'KidLoopApp/1.0 (https://kidloop.app; contact@kidloop.app)',
        },
      );

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final extract = data['tfa']?['extract']?.toString();
      if (extract == null || extract.isEmpty) return null;
      return _cleanHtml(extract);
    } catch (e) {
      debugPrint('Wikipedia featured error: $e');
      return null;
    }
  }

  Future<String?> _loadWikipediaRandom() async {
    try {
      final response = await http.get(
        Uri.parse('https://ru.wikipedia.org/api/rest_v1/page/random/summary'),
        headers: {
          'User-Agent':
          'KidLoopApp/1.0 (https://kidloop.app; contact@kidloop.app)',
        },
      );

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final extract = data['extract']?.toString();
      if (extract == null || extract.isEmpty) return null;
      return _cleanHtml(extract);
    } catch (e) {
      debugPrint('Wikipedia random error: $e');
      return null;
    }
  }

  String _cleanHtml(String html) {
    String clean = html.replaceAll(RegExp(r'<[^>]*>'), '');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    clean = clean.replaceAll(RegExp(r'\[\d+\]'), '');
    clean = clean.replaceAll(RegExp(r'&[a-z]+;'), ' ');
    return clean.trim();
  }

  String _shortenFact(String text, {int maxLen = 180}) {
    final t = text.trim();
    if (t.length <= maxLen) return t;

    final cut = t.substring(0, maxLen);
    final lastDot = cut.lastIndexOf(RegExp(r'[.!?]'));
    if (lastDot > maxLen * 0.5) {
      return cut.substring(0, lastDot + 1).trimRight();
    }
    return '${cut.trimRight()}…';
  }

  void _toggleFactsExpanded() {
    setState(() => _isFactsExpanded = !_isFactsExpanded);
  }

  // ==========================================================
  // PANEL
  // ==========================================================

  void _openPanel() {
    if (_isPanelOpen) return;
    setState(() => _isPanelOpen = true);
    _panelController.forward();
  }

  void _closePanel() {
    if (!_isPanelOpen) return;
    setState(() => _isPanelOpen = false);
    _panelController.reverse();
  }

  void _togglePanel() {
    _isPanelOpen ? _closePanel() : _openPanel();
  }

  // ==========================================================
  // DATA LOADING
  // ==========================================================

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _loadCounters();

    try {
      final itemsProvider = context.read<ItemsProvider>();
      if (itemsProvider.items.isEmpty) await itemsProvider.loadItems();

      final bundleProvider = context.read<BundleProvider>();
      if (bundleProvider.allBundles.isEmpty) {
        await bundleProvider.loadAllBundles();
      }
    } catch (e) {
      debugPrint('Ошибка загрузки: $e');
    }

    await _loadTodaySteps();

    if (!mounted) return;
    final tips = List<String>.from(_tips)..shuffle();
    setState(() {
      _dailyTip = tips.first;
    });

    _loadLatestItems();
    _generateRecommendations();
  }

  Future<void> _loadContainerOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('container_order');
    // 9 контейнеров теперь
    if (saved == null || saved.length != 9) return;

    final parsed = saved.map(int.tryParse).toList();
    if (!parsed.every((value) => value != null && value >= 0 && value <= 8)) {
      return;
    }

    final order = parsed.cast<int>();
    if (order.toSet().length != 9) return;

    if (!mounted) return;
    setState(() {
      _containerOrder = order;
    });
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
      if (!mounted) return;
      setState(() {
        _pendingTradesCount = tradesProvider.offers
            .where((t) => t.status == 'pending' || t.status == 'waiting')
            .length;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки обменов: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _unreadMessagesCount = prefs.getInt('unread_messages') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');

    final jsonString = prefs.getString('user_profile');
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _userName = map['name']?.toString() ?? 'Друг';
          _avatarUrl = map['avatarUrl']?.toString();
          _isOnline = map['isOnline'] ?? true;
          _statusMessage = map['status']?.toString() ?? 'Сегодня активен';
        });
        return;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Друг';
    });
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
    const maxProgress = 50000;

    if (!mounted) return;
    setState(() {
      _todaySteps = steps;
      _level = level;
      _levelProgress = progress;
      _maxLevelProgress = maxProgress;
    });

    _levelProgressAnimation = Tween<double>(
      begin: 0,
      end: (progress / maxProgress).clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _levelProgressController,
      curve: Curves.easeOutCubic,
    ));

    _levelProgressController.forward(from: 0);
  }

  Future<void> _loadBanners() async {
    try {
      final response = await http.post(
        Uri.parse(_bannerApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'get-banners'}),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);
      if (data['ok'] != true) return;

      final raw = data['banners'];
      if (raw is! List) return;

      final banners = raw
          .map((b) => BannerAd.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));

      setState(() {
        _banners = banners;
        if (_currentBannerIndex >= _banners.length) _currentBannerIndex = 0;
      });

      _startBannerAutoScroll();
    } catch (e) {
      debugPrint('Ошибка загрузки баннеров: $e');
      if (!mounted) return;
      setState(() {
        _banners = [
          BannerAd(
            id: 'default',
            imageUrl: '',
            title: 'Обменивайся вещами',
            subtitle: 'Найди нужное и отдай ненужное',
            description: 'KidLoop — платформа для обмена детскими вещами.',
            overlayText: 'KIDLOOP',
            gradientStart: '#FF6B00',
            gradientEnd: '#FF8A3D',
          ),
        ];
      });
      _startBannerAutoScroll();
    }
  }

  void _loadLatestItems() {
    try {
      final items = context.read<ItemsProvider>().items;
      final bundles = context.read<BundleProvider>().allBundles;
      final allItems = <dynamic>[...items, ...bundles];

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

      if (!mounted) return;
      final top = allItems.take(10).toList();
      setState(() {
        _latestItems = top.whereType<Item>().toList();
        _latestBundles = top.whereType<Bundle>().toList();
      });
    } catch (e) {
      debugPrint('Ошибка загрузки последних объявлений: $e');
    }
  }

  void _generateRecommendations() {
    final items = context.read<ItemsProvider>().items;
    final bundles = context.read<BundleProvider>().allBundles;
    final recommendations = _recommendationEngine.getRecommendations(
      [...items, ...bundles],
      6,
    );
    if (!mounted) return;
    setState(() {
      _recommendedItems = recommendations;
    });
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    if (_banners.length <= 1) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !_bannerPageController.hasClients ||
          _banners.length <= 1) {
        return;
      }
      final next = (_currentBannerIndex + 1) % _banners.length;
      _bannerPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  // ==========================================================
  // MODES
  // ==========================================================

  void _handleTwoFingerTap() {
    setState(() {
      _isPanModeActive = !_isPanModeActive;
    });

    if (_isPanModeActive) {
      mediumHaptic();
      ScaffoldMessenger.of(context).showSnackBar(
        _modernSnackBar('Панорамирование включено', AppTokens.accent),
      );
    } else {
      heavyHaptic();
      ScaffoldMessenger.of(context).showSnackBar(
        _modernSnackBar('Позиция зафиксирована', Colors.green),
      );
    }
  }

  void _toggleReorderMode() {
    setState(() {
      _isReorderMode = !_isReorderMode;
      if (!_isReorderMode) _draggedIndex = null;
    });

    if (_isReorderMode) {
      heavyHaptic();
      ScaffoldMessenger.of(context).showSnackBar(
        _modernSnackBar('Зажмите блок и перетащите', Colors.black87),
      );
    } else {
      selectionHaptic();
      _saveContainerOrder();
      ScaffoldMessenger.of(context).showSnackBar(
        _modernSnackBar('Порядок сохранён', Colors.green),
      );
    }
  }

  SnackBar _modernSnackBar(String text, Color color) {
    return SnackBar(
      content: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      duration: const Duration(seconds: 2),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  // ==========================================================
  // REFRESH
  // ==========================================================

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    lightHaptic();

    try {
      await Future.wait([
        _loadUserData(),
        _loadCounters(),
        _loadTodaySteps(),
        context.read<ItemsProvider>().loadItems(),
        context.read<BundleProvider>().loadAllBundles(),
        context.read<TradesProvider>().loadOffers(),
      ]);

      _loadLatestItems();
      _generateRecommendations();
      _loadGlobalStats();

      final tips = List<String>.from(_tips)..shuffle();
      if (mounted) setState(() => _dailyTip = tips.first);

      await _loadFactsWithFallback();
    } catch (e) {
      debugPrint('Ошибка обновления: $e');
    }

    if (!mounted) return;
    setState(() => _isRefreshing = false);
    selectionHaptic();
  }

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  Future<void> _openMainApp() async {
    lightHaptic();
    try {
      await Future.wait([
        context.read<ItemsProvider>().loadItems(),
        context.read<TradesProvider>().loadOffers(),
        context.read<BundleProvider>().loadAllBundles(),
      ]);
    } catch (_) {}

    if (!mounted) return;
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final tween =
          Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );

    if (mounted) await _loadInitialData();
  }

  Future<void> _openProfile() async {
    lightHaptic();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (mounted) await _loadUserData();
  }

  Future<void> _openManageBanners() async {
    lightHaptic();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageBannersScreen()),
    );
    if (mounted) await _loadBanners();
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
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TradeOffersScreen()),
        );
        break;
      case 'map':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
        break;
      case 'chess':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChessGameScreen()),
        );
        break;
      case 'memory':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MemoryGameScreen()),
        );
        break;
      case 'games':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GamesScreen()),
        );
        break;
      case 'messenger':
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('unread_messages', 0);
        if (!mounted) return;
        setState(() => _unreadMessagesCount = 0);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessengerScreen()),
        );
        break;
      case 'pedometer':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PedometerScreen()),
        );
        break;
      case 'stats':
        await _openStats();
        break;
    }
  }

  /// Открыть статистику KidLoop.
  Future<void> _openStats() async {
    lightHaptic();
    await _loadGlobalStats();
    if (!mounted) return;
    _showStatsDialog();
  }

  // ==========================================================
  // ADD OPTIONS
  // ==========================================================

  void _showAddOptions(BuildContext parentContext) {
    lightHaptic();

    final isDark = Theme.of(parentContext).brightness == Brightness.dark;
    final background = isDark ? AppTokens.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : AppTokens.textDark;
    final secondary = isDark ? Colors.white54 : AppTokens.textSecondary;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Добавить',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Что хотите разместить?',
                  style: TextStyle(
                    color: secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _buildAddOption(
                onTap: () {
                  heavyHaptic();
                  Navigator.pop(ctx);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(builder: (_) => const AddItemScreen()),
                  ).then((_) async {
                    await parentContext.read<ItemsProvider>().loadItems();
                    _loadLatestItems();
                    _generateRecommendations();
                  });
                },
                icon: Icons.add_rounded,
                title: 'Одна вещь',
                subtitle: 'Создать объявление',
                color: AppTokens.accent,
                textColor: textColor,
              ),
              const SizedBox(height: 12),
              _buildAddOption(
                onTap: () {
                  heavyHaptic();
                  Navigator.pop(ctx);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                        builder: (_) => const CreateBundleScreen()),
                  ).then((_) async {
                    await parentContext.read<ItemsProvider>().loadItems();
                    await parentContext
                        .read<BundleProvider>()
                        .loadAllBundles();
                    await parentContext.read<BundleProvider>().loadMyBundles();
                    _loadLatestItems();
                    _generateRecommendations();
                  });
                },
                icon: Icons.inventory_2_outlined,
                title: 'Набор вещей',
                subtitle: 'Объединить несколько вещей',
                color: const Color(0xFF6C5CE7),
                textColor: textColor,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () {
                    selectionHaptic();
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Отмена',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddOption({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color textColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withOpacity(0.52),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return Theme(
      data: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: AppTokens.accent,
        scaffoldBackgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
        body: SafeArea(
          child: Stack(
            children: [
              _buildBackground(isDark),
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
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: _buildPageIndicator(isDark),
              ),
              _buildSlideOutPanel(isDark),
              if (_isReorderMode)
                Positioned(
                  top: 56,
                  left: 20,
                  right: 20,
                  child: _modeIndicator(
                    'Режим редактирования',
                    Colors.black87,
                    Icons.drag_indicator_rounded,
                  ),
                ),
              if (_isPanModeActive && !_isReorderMode)
                Positioned(
                  top: 56,
                  left: 20,
                  right: 20,
                  child: _modeIndicator(
                    'Свайпни, чтобы переместиться',
                    AppTokens.accent,
                    Icons.open_with_rounded,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BACKGROUND
  // ==========================================================

  Widget _buildBackground(bool isDark) {
    return ColoredBox(
      color: isDark ? AppTokens.darkBg : AppTokens.lightBg,
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTokens.accent.withOpacity(isDark ? 0.055 : 0.045),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTokens.accent.withOpacity(isDark ? 0.035 : 0.025),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MODE INDICATOR
  // ==========================================================

  Widget _modeIndicator(String text, Color color, IconData icon) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // SLIDE PANEL
  // ==========================================================

  Widget _buildSlideOutPanel(bool isDark) {
    const double handleWidth = 24;
    const double contentWidth = 110;
    const double rightOpen = 10;
    const double rightClosed = rightOpen - contentWidth;

    return AnimatedBuilder(
      animation: _panelAnimation,
      builder: (context, child) {
        final t = _panelAnimation.value;
        final right = rightClosed + (rightOpen - rightClosed) * t;

        return Positioned(
          right: right,
          top: MediaQuery.of(context).size.height / 2 - 68,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePanel,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -100) {
                _openPanel();
              } else if (velocity > 100) {
                _closePanel();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTokens.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                  isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                ),
                boxShadow: AppTokens.softShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: handleWidth,
                    height: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 3,
                          height: _isPanelOpen ? 16 : 22,
                          decoration: BoxDecoration(
                            color: AppTokens.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 3,
                          height: _isPanelOpen ? 22 : 16,
                          decoration: BoxDecoration(
                            color: AppTokens.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: contentWidth,
                    child: Opacity(
                      opacity: t,
                      child: Row(
                        children: [
                          const SizedBox(width: 6),
                          _buildPanelButton(
                            icon: _isReorderMode
                                ? Icons.check_rounded
                                : Icons.drag_indicator_rounded,
                            color: AppTokens.accent,
                            onTap: _toggleReorderMode,
                          ),
                          const SizedBox(width: 8),
                          _buildPanelButton(
                            icon: _isPanModeActive
                                ? Icons.lock_rounded
                                : Icons.open_with_rounded,
                            color: _isPanModeActive
                                ? Colors.green
                                : Colors.black54,
                            onTap: _handleTwoFingerTap,
                          ),
                          const SizedBox(width: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanelButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }

  // ==========================================================
  // PAGE INDICATOR
  // ==========================================================

  Widget _buildPageIndicator(bool isDark) {
    return IgnorePointer(
      ignoring: !_isPanModeActive,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final active = _currentPage.round() == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 28 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: active
                  ? AppTokens.accent
                  : (isDark ? Colors.white24 : Colors.black12),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }),
      ),
    );
  }

  // ==========================================================
  // MAIN DASHBOARD
  // ==========================================================

  Widget _buildMainDashboard(bool isDark) {
    final List<Widget Function()> builders = [
      // 0 — HEADER
          () => _buildDraggableContainer(
        index: 0,
        isDark: isDark,
        child: _buildHeaderBlock(isDark),
      ),
      // 1 — FEED + ACTIONS
          () => _buildDraggableContainer(
        index: 1,
        isDark: isDark,
        child: _buildFeedAndActionsBlock(isDark),
      ),
      // 2 — PEDOMETER
          () => _buildDraggableContainer(
        index: 2,
        isDark: isDark,
        child: _buildPedometerBlock(isDark),
      ),
      // 3 — BANNER
          () => _buildDraggableContainer(
        index: 3,
        isDark: isDark,
        child: _buildBannerCarousel(isDark),
      ),
      // 4 — CHATS + GAMES
          () => _buildDraggableContainer(
        index: 4,
        isDark: isDark,
        child: _buildChatsGamesBlock(isDark),
      ),
      // 5 — RECOMMENDATIONS
          () => _buildDraggableContainer(
        index: 5,
        isDark: isDark,
        child: _buildRecommendationsCarousel(isDark),
      ),
      // 6 — NEW ITEMS
          () => _buildDraggableContainer(
        index: 6,
        isDark: isDark,
        child: _buildNewItemsCarousel(isDark),
      ),
      // 7 — CREATIVE
          () => _buildDraggableContainer(
        index: 7,
        isDark: isDark,
        child: _buildCreativeBlock(isDark),
      ),
      // 8 — PULSE CARD (питание + фитнес + статистика + совет)
          () => _buildDraggableContainer(
        index: 8,
        isDark: isDark,
        child: PulseCard(isDark: isDark),
      ),
    ];

    final order = _containerOrder
        .where((i) => i >= 0 && i < builders.length)
        .toList();

    final slivers = <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];

    for (int i = 0; i < order.length; i++) {
      slivers.add(
        SliverToBoxAdapter(
          key: ValueKey('dashboard_container_${order[i]}'),
          child: builders[order[i]](),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 18)));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTokens.accent,
      backgroundColor: isDark ? AppTokens.darkCard : Colors.white,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: slivers,
      ),
    );
  }

  // ==========================================================
  // DRAGGABLE
  // ==========================================================

  Widget _buildDraggableContainer({
    required int index,
    required bool isDark,
    required Widget child,
  }) {
    if (!_isReorderMode) {
      return FadeTransition(
        key: ValueKey('fade_$index'),
        opacity: _fadeAnimation,
        child: child,
      );
    }

    final dragging = _draggedIndex == index;

    return LongPressDraggable<int>(
      data: index,
      delay: const Duration(milliseconds: 280),
      onDragStarted: () {
        mediumHaptic();
        setState(() => _draggedIndex = index);
      },
      onDragUpdate: (details) {
        _handleDragScroll(details.globalPosition);
      },
      onDragEnd: (_) {
        if (!mounted) return;
        setState(() => _draggedIndex = null);
      },
      feedback: Material(
        color: Colors.transparent,
        elevation: 10,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: MediaQuery.of(context).size.width - 32,
          decoration: BoxDecoration(
            color: isDark ? AppTokens.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTokens.accent, width: 2),
          ),
          child: child,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) {
          _reorderOnDrop(details.data, index);
          _saveContainerOrder();
          selectionHaptic();
        },
        builder: (context, candidateData, rejectedData) {
          final target = candidateData.isNotEmpty;
          return Stack(
            children: [
              child,
              if (target && !dragging)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: AppTokens.accent.withOpacity(0.08),
                        border: Border.all(
                          color: AppTokens.accent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.drag_indicator_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _reorderOnDrop(int dragged, int target) {
    if (dragged == target) return;
    final from = _containerOrder.indexOf(dragged);
    final to = _containerOrder.indexOf(target);
    if (from == -1 || to == -1) return;

    setState(() {
      final item = _containerOrder.removeAt(from);
      final destination = to > from ? to - 1 : to;
      _containerOrder.insert(destination, item);
    });
    heavyHaptic();
  }

  void _handleDragScroll(Offset globalPosition) {
    if (!_scrollController.hasClients) return;
    final render = context.findRenderObject();
    if (render is! RenderBox) return;

    final local = render.globalToLocal(globalPosition);
    final height = render.size.height;
    final top = height * 0.16;
    final bottom = height * 0.84;

    double speed = 0;
    if (local.dy < top) {
      speed = -((top - local.dy) / top) * 22;
    } else if (local.dy > bottom) {
      speed = ((local.dy - bottom) / (height - bottom)) * 22;
    }

    if (speed != 0) {
      final offset = (_scrollController.offset + speed).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(offset);
    }
  }

  // ==========================================================
  // BLOCK 0: HEADER
  // ==========================================================

  Widget _buildHeaderBlock(bool isDark) {
    final displayName = _userName.trim().isEmpty ? 'Друг' : _userName.trim();
    final itemsCount = context.watch<ItemsProvider>().items.length;

    final now = DateTime.now();
    final weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'мая',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    final weekday = weekdays[now.weekday - 1];
    final day = now.day;
    final month = months[now.month - 1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => safeTap(_openProfile),
                behavior: HitTestBehavior.opaque,
                child: _buildProfileAvatar(isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Добро пожаловать',
                      style: TextStyle(
                        color:
                        isDark ? Colors.white38 : AppTokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTokens.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isAdmin) ...[
                _buildCircleAction(
                  isDark: isDark,
                  icon: Icons.campaign_rounded,
                  color: AppTokens.violet,
                  onTap: () => safeTap(_openManageBanners),
                ),
                const SizedBox(width: 8),
              ],
              _buildCircleAction(
                isDark: isDark,
                icon: isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: AppTokens.accent,
                onTap: () {
                  lightHaptic();
                  context.read<ThemeProvider>().toggleTheme();
                },
              ),
              const SizedBox(width: 8),
              _buildCircleAction(
                isDark: isDark,
                icon: Icons.chat_bubble_outline_rounded,
                color: AppTokens.blue,
                onTap: () => safeTap(() => _handleAction('messenger')),
                badge: _unreadMessagesCount > 0 ? _unreadMessagesCount : null,
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTokens.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? AppTokens.darkBorder
                            : const Color(0xFFEDECE7),
                      ),
                      boxShadow: isDark ? const [] : AppTokens.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const Text(
                          'Статистика',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.accent,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMiniStatCompact(
                                icon: Icons.star_rounded,
                                value: '$_level',
                                label: 'ур.',
                                color: AppTokens.accent,
                                isDark: isDark,
                              ),
                            ),
                            Expanded(
                              child: _buildMiniStatCompact(
                                icon: Icons.inventory_2_outlined,
                                value: _formatNumber(itemsCount),
                                label: 'вещей',
                                color: AppTokens.violet,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMiniStatCompact(
                                icon: Icons.swap_horiz_rounded,
                                value: '$_pendingTradesCount',
                                label: 'обм.',
                                color: AppTokens.green,
                                isDark: isDark,
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => safeTap(() async {
                                  lightHaptic();
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const PedometerScreen(),
                                    ),
                                  );
                                  if (mounted) await _loadTodaySteps();
                                }),
                                child: _buildMiniStatCompact(
                                  icon: Icons.directions_walk_rounded,
                                  value: _formatNumber(_todaySteps),
                                  label: 'шаг.',
                                  color: AppTokens.blue,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isDark ? const [] : AppTokens.softShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const Image(
                            image: AssetImage('assets/images/pogoda.jpeg'),
                            fit: BoxFit.cover,
                          ),
                          Container(
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
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: CalendarWeather(
                                isDark: true,
                                transparent: true,
                                compact: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ============================================================
          // Date + Facts container
          // ============================================================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppTokens.darkCard, AppTokens.darkSurface]
                    : [Colors.white, const Color(0xFFF8F8F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color:
                isDark ? AppTokens.darkBorder : const Color(0xFFEDECE7),
              ),
              boxShadow: isDark ? const [] : AppTokens.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTokens.accent, AppTokens.accentDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              month.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: isDark
                                    ? Colors.white60
                                    : AppTokens.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$weekday, $day $month',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppTokens.textDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '💡',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _todayFacts.isEmpty
                                      ? 'Факты дня'
                                      : '${_todayFacts.length} ${_pluralFacts(_todayFacts.length)}',
                                  style: const TextStyle(
                                    color: AppTokens.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => safeTap(_loadFactsWithFallback),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTokens.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: AppTokens.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.05),
                ),
                const SizedBox(height: 12),
                _buildFactsList(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // FACTS LIST (UI)
  // ==========================================================

  Widget _buildFactsList(bool isDark) {
    if (_isLoadingFacts && _todayFacts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTokens.accent,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Загружаем факты…',
              style: TextStyle(
                fontSize: 13,
                color: AppTokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_todayFacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 16,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Не удалось загрузить факты. Проверьте интернет.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : AppTokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => safeTap(_loadFactsWithFallback),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Повторить',
                style: TextStyle(
                  color: AppTokens.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final visible =
    _isFactsExpanded ? _todayFacts : [_todayFacts.first];

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      alignment: Alignment.topCenter,
      curve: Curves.easeOutCubic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < visible.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == visible.length - 1 ? 6 : 10,
              ),
              child: _buildFactRow(
                index: i,
                text: visible[i],
                isDark: isDark,
                expanded: _isFactsExpanded,
              ),
            ),
          if (_todayFacts.length > 1)
            GestureDetector(
              onTap: () {
                selectionHaptic();
                _toggleFactsExpanded();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isFactsExpanded
                          ? 'Свернуть'
                          : 'Показать все (${_todayFacts.length})',
                      style: const TextStyle(
                        color: AppTokens.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isFactsExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppTokens.accent,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFactRow({
    required int index,
    required String text,
    required bool isDark,
    required bool expanded,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTokens.accent.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: AppTokens.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: expanded ? null : 3,
            overflow:
            expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppTokens.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  String _pluralFacts(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'факт';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'факта';
    }
    return 'фактов';
  }

  // ==========================================================
  // MINI STAT
  // ==========================================================

  Widget _buildMiniStatCompact({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 13),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : AppTokens.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileAvatar(bool isDark) {
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;
    return Stack(
      children: [
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTokens.accent,
          ),
          child: CircleAvatar(
            backgroundColor: isDark ? AppTokens.darkCard : Colors.white,
            backgroundImage: hasAvatar
                ? CachedNetworkImageProvider(_avatarUrl!)
                : null,
            child: !hasAvatar
                ? Text(
              _userName.isNotEmpty
                  ? _userName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: isDark ? Colors.white : AppTokens.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            )
                : null,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _isOnline ? const Color(0xFF35C759) : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppTokens.darkBg : AppTokens.lightBg,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleAction({
    required bool isDark,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white10 : AppTokens.lightBorder,
              ),
              boxShadow: isDark
                  ? const []
                  : const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          if (badge != null && badge > 0)
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                constraints:
                const BoxConstraints(minWidth: 17, minHeight: 17),
                padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTokens.accent,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: isDark ? AppTokens.darkBg : Colors.white,
                    width: 2,
                  ),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // BLOCK 1: Feed + Actions
  // ==========================================================

  Widget _buildFeedAndActionsBlock(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTokens.accent.withOpacity(0.6),
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => safeTap(_openMainApp),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/veshi.jpeg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.2),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Icon(
                            Icons.view_stream_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Открыть ленту обменов',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Смотри, выбирай, обменивайся',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                color: isDark ? AppTokens.darkCard : Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionIcon(
                      icon: Icons.add_rounded,
                      label: 'Добавить',
                      color: AppTokens.accent,
                      onTap: () => _handleAction('add'),
                      isDark: isDark,
                    ),
                    _buildActionIcon(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Обмены',
                      color: AppTokens.green,
                      onTap: () => _handleAction('trades'),
                      isDark: isDark,
                    ),
                    _buildActionIcon(
                      icon: Icons.location_on_outlined,
                      label: 'Карта',
                      color: const Color(0xFF5C6BC0),
                      onTap: () => _handleAction('map'),
                      isDark: isDark,
                    ),
                    _buildActionIcon(
                      icon: Icons.insights_rounded,
                      label: 'KidLoop',
                      color: AppTokens.violet,
                      onTap: _openStats,
                      isDark: isDark,
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

  Widget _buildActionIcon({
    required IconData icon,
    required String label,
    required Color color,
    required Future<void> Function() onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => safeTap(onTap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppTokens.textDark,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BLOCK 2: Pedometer
  // ==========================================================

  Widget _buildPedometerBlock(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => safeTap(() async {
          lightHaptic();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PedometerScreen()),
          );
          if (mounted) await _loadTodaySteps();
        }),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            image: const DecorationImage(
              image: AssetImage('assets/images/begom.jpeg'),
              fit: BoxFit.cover,
            ),
            boxShadow: isDark ? const [] : AppTokens.softShadow,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.2),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_walk_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Сегодня пройдено',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_formatNumber(_todaySteps)} шагов',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTokens.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Подробнее',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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

  // ==========================================================
  // BLOCK 4: Chats + Games
  // ==========================================================

  Widget _buildChatsGamesBlock(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: GestureDetector(
                onTap: () => safeTap(() => _handleAction('messenger')),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/chati.jpeg'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: isDark ? const [] : AppTokens.softShadow,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Чаты',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: GestureDetector(
                onTap: () => safeTap(() => _handleAction('games')),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/igri.jpeg'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: isDark ? const [] : AppTokens.softShadow,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.games_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Игры',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BLOCK 5: Recommendations
  // ==========================================================

  Widget _buildRecommendationsCarousel(bool isDark) {
    if (_recommendedItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSectionHeader(
            'Для вас',
            'Подобрали специально для вас',
            isDark,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: _buildCarousel(
            items: _recommendedItems,
            isDark: isDark,
            onItemTap: (item) async {
              lightHaptic();
              if (item is Item) {
                _recommendationEngine.addView(item.itemId);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItemDetailsScreen(item: item),
                  ),
                );
              } else if (item is Bundle) {
                _recommendationEngine.addView(item.bundleId);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BundleDetailsScreen(bundle: item),
                  ),
                );
              }
            },
            itemBuilder: (context, item) {
              if (item is Item) {
                return _buildCarouselItemCard(item, isDark, true);
              } else if (item is Bundle) {
                return _buildCarouselBundleCard(item, isDark);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // BLOCK 6: New items
  // ==========================================================

  Widget _buildNewItemsCarousel(bool isDark) {
    if (_latestItems.isEmpty && _latestBundles.isEmpty) {
      return const SizedBox.shrink();
    }

    final mixed = <dynamic>[..._latestBundles, ..._latestItems];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSectionHeader('Новое', 'Свежие объявления', isDark),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: _buildCarousel(
            items: mixed,
            isDark: isDark,
            onItemTap: (item) async {
              lightHaptic();
              if (item is Item) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItemDetailsScreen(item: item),
                  ),
                );
              } else if (item is Bundle) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BundleDetailsScreen(bundle: item),
                  ),
                );
              }
            },
            itemBuilder: (context, item) {
              if (item is Item) {
                return _buildCarouselItemCard(item, isDark, false);
              } else if (item is Bundle) {
                return _buildCarouselBundleCard(item, isDark);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // CAROUSEL HELPERS
  // ==========================================================

  Widget _buildCarousel({
    required List<dynamic> items,
    required bool isDark,
    required Function(dynamic) onItemTap,
    required Widget Function(BuildContext, dynamic) itemBuilder,
  }) {
    final PageController controller =
    PageController(viewportFraction: 0.65, initialPage: 0);

    return PageView.builder(
      controller: controller,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            double value = 1.0;
            if (controller.position.hasContentDimensions) {
              final double page = controller.page ?? 0;
              final double distance = (index - page).abs();
              value = 1.0 - (distance * 0.15).clamp(0.0, 0.15);
              final blur = (distance * 3.0).clamp(0.0, 3.0);
              final opacity = 1.0 - (distance * 0.4).clamp(0.0, 0.4);

              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: opacity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter:
                      ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: GestureDetector(
                        onTap: () => onItemTap(item),
                        child: itemBuilder(context, item),
                      ),
                    ),
                  ),
                ),
              );
            } else {
              return GestureDetector(
                onTap: () => onItemTap(item),
                child: itemBuilder(context, item),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildCarouselItemCard(Item item, bool isDark, bool recommended) {
    final image = item.imagePaths.isNotEmpty ? item.imagePaths.first : '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark ? const [] : AppTokens.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: image.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark
                          ? Colors.white10
                          : const Color(0xFFEDEDEB),
                    ),
                    errorWidget: (_, __, ___) =>
                        _imagePlaceholder(isDark),
                  )
                      : _imagePlaceholder(isDark),
                ),
                if (recommended)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Для вас',
                        style: TextStyle(
                          color: AppTokens.accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTokens.textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.sv} SV',
                  style: const TextStyle(
                    color: AppTokens.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselBundleCard(Bundle bundle, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark ? const [] : AppTokens.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: isDark
                        ? const Color(0xFF2A2231)
                        : const Color(0xFFF1EAF5),
                    child: bundle.items.isNotEmpty
                        ? _buildBundleGrid(bundle.items)
                        : Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: isDark
                            ? Colors.white54
                            : AppTokens.violet,
                        size: 38,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Набор',
                      style: TextStyle(
                        color: Color(0xFF6C5CE7),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bundle.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTokens.textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bundle.items.length} пред. • ${bundle.totalSv} SV',
                  style: const TextStyle(
                    color: Color(0xFF6C5CE7),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BLOCK 7: Creative block
  // ==========================================================

  Widget _buildCreativeBlock(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTokens.accent.withOpacity(0.08),
              AppTokens.violet.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTokens.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: AppTokens.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Эко-вклад',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTokens.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Вы спасли ${(_level * 3) + 5} кг CO₂ благодаря обменам',
                    style: TextStyle(
                      color:
                      isDark ? Colors.white60 : AppTokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTokens.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+${_level * 5}',
                style: const TextStyle(
                  color: AppTokens.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // COMMON HELPERS
  // ==========================================================

  Widget _imagePlaceholder(bool isDark) {
    return Container(
      color: isDark ? Colors.white10 : const Color(0xFFEDEDEB),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.black26, size: 28),
      ),
    );
  }

  Widget _buildBundleGrid(List<BundleItem> items) {
    final visible = items.take(6).toList();
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: visible.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemBuilder: (context, index) {
          final item = visible[index];
          if (item.imagePath.startsWith('http')) {
            return CachedNetworkImage(
              imageUrl: item.imagePath,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: Colors.white24),
            );
          }
          return Container(
            color: Colors.white24,
            child: Center(
              child: Text(
                '${item.sv}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : AppTokens.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white38 : AppTokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int value) {
    if (value >= 1000) {
      final result = value / 1000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}k';
    }
    return '$value';
  }

  // ==========================================================
  // BANNER CAROUSEL
  // ==========================================================

  Color _parseColor(String value) {
    try {
      final hex = value.replaceFirst('#', '').trim();
      return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {
      return AppTokens.accent;
    }
  }

  Widget _buildBannerCarousel(bool isDark) {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSectionHeader(
            'Актуальное',
            'Что происходит в KidLoop',
            isDark,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _bannerPageController,
            itemCount: _banners.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _currentBannerIndex = index);
            },
            itemBuilder: (context, index) {
              final banner = _banners[index];
              final start = _parseColor(banner.gradientStart);
              final end = _parseColor(banner.gradientEnd);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => safeTap(() async {
                    lightHaptic();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BannerDetailScreen(banner: banner),
                      ),
                    );
                  }),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
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
                                  colors: [start, end],
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [start, end],
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [start, end],
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.02),
                                  Colors.black.withOpacity(0.72),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (banner.overlayText.isNotEmpty)
                                Text(
                                  banner.overlayText,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              if (banner.overlayText.isNotEmpty)
                                const SizedBox(height: 6),
                              Text(
                                banner.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                banner.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
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
              children: List.generate(_banners.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: index == _currentBannerIndex ? 24 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _currentBannerIndex
                        ? AppTokens.accent
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // ==========================================================
  // STATS DIALOG (красивая статистика KidLoop)
  // ==========================================================

  void _showStatsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Если данных нет — показываем спиннер и подгружаем
    if (_statsLoading || _globalStats == null) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppTokens.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: AppTokens.accent,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Загружаем статистику…',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTokens.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      _loadGlobalStats().then((_) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        if (_globalStats != null) {
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) _showStatsDialog();
          });
        }
      });
      return;
    }

    final stats = _globalStats!;
    final completed = (stats['completedTrades'] ?? 0) as num;
    final cancelled = (stats['cancelledTrades'] ?? 0) as num;
    final totalTrades = (stats['totalTrades'] ?? 0) as num;
    final totalSV = (stats['totalSV'] ?? 0) as num;
    final totalUsers = (stats['totalUsers'] ?? 0) as num;
    final totalItems = (stats['totalItems'] ?? 0) as num;

    final successRate = totalTrades > 0
        ? (completed / totalTrades * 100).round()
        : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTokens.darkBg : AppTokens.lightBg,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  // Handle
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
                        // ─── Заголовок с градиентом ───
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8A3D), Color(0xFFE85D00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTokens.accent.withOpacity(0.35),
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
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                              // Success rate большой
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
                                        color:
                                        Colors.white.withOpacity(0.85),
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
                                  value: totalTrades > 0
                                      ? completed / totalTrades
                                      : 0,
                                  minHeight: 8,
                                  backgroundColor:
                                  Colors.white.withOpacity(0.2),
                                  valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        _buildStatsSectionTitle('Обзор', isDark),
                        const SizedBox(height: 10),

                        // Сетка 2×2 главных чисел
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.check_circle_rounded,
                                value: _formatNumber(completed.toInt()),
                                label: 'Успешных',
                                color: AppTokens.green,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.cancel_rounded,
                                value: _formatNumber(cancelled.toInt()),
                                label: 'Отменено',
                                color: const Color(0xFFE53935),
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
                                value: _formatNumber(totalSV.toInt()),
                                label: 'SV в сделках',
                                color: const Color(0xFFFFB300),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.trending_up_rounded,
                                value: _formatNumber(totalTrades.toInt()),
                                label: 'Всего сделок',
                                color: const Color(0xFF00ACC1),
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
                                value: _formatNumber(totalUsers.toInt()),
                                label: 'Пользователей',
                                color: AppTokens.blue,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.inventory_2_rounded,
                                value: _formatNumber(totalItems.toInt()),
                                label: 'Вещей',
                                color: AppTokens.violet,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        // Причины отмен
                        if (stats['cancelReasons'] != null &&
                            (stats['cancelReasons'] as Map).isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildStatsSectionTitle('Причины отмен', isDark),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTokens.darkCard
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? AppTokens.darkBorder
                                    : AppTokens.lightBorder,
                              ),
                            ),
                            child: Column(
                              children: (stats['cancelReasons']
                              as Map<String, dynamic>)
                                  .entries
                                  .map((entry) {
                                final reason = entry.key;
                                final count =
                                (entry.value as num).toInt();
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
                                          borderRadius:
                                          BorderRadius.circular(11),
                                        ),
                                        child: Icon(icon,
                                            size: 18, color: color),
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
                                                color: isDark
                                                    ? Colors.white
                                                    : AppTokens.textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius:
                                              BorderRadius.circular(4),
                                              child:
                                              LinearProgressIndicator(
                                                value: cancelled > 0
                                                    ? count / cancelled
                                                    : 0,
                                                minHeight: 5,
                                                backgroundColor: isDark
                                                    ? Colors.white12
                                                    : Colors.black12,
                                                valueColor:
                                                AlwaysStoppedAnimation<
                                                    Color>(color),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.end,
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
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38,
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
                              foregroundColor: AppTokens.accent,
                              backgroundColor:
                              AppTokens.accent.withOpacity(0.10),
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
            );
          },
        );
      },
    );
  }

  Widget _buildStatsSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppTokens.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTokens.textDark,
            letterSpacing: -0.2,
          ),
        ),
      ],
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
        color: isDark ? AppTokens.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
        ),
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
              color: isDark ? Colors.white : AppTokens.textDark,
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
              color: isDark ? Colors.white54 : AppTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
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
        return const Color(0xFFE53935);
      case 'Скандальный пользователь':
        return const Color(0xFFFB8C00);
      case 'Товар не соответствует':
        return const Color(0xFFFFB300);
      case 'Передумал':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}