import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/items_provider.dart';
import '../../core/item_model.dart';
import '../../navigation/main_navigation_screen.dart';
import '../add_item/add_item_screen.dart';
import '../feed/presentation/trade_offers_screen.dart';
import '../messenger/messenger_screen.dart';
import '../pedometer/pedometer_screen.dart';
import '../games/games_screen.dart';
import '../games/chess/chess_game_screen.dart';

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
  int _todaySteps = 0;
  int _level = 1;
  String _dailyTip = '';
  List<Item> _latestItems = [];

  final List<String> _tips = [
    'Меняйся игрушками — спасай планету! 🌍',
    'Каждая ненужная вещь может стать сокровищем для другого 👶',
    'Сделай 10 000 шагов сегодня и получи бонус! 👟',
    'Обмен вещами экономит до 30 кг CO₂ в год 🌱',
    'Проверь раздел «Обмены» — возможно, тебя ждёт выгодная сделка 🤝',
    'Добавь свои старые игрушки — освободи место и заработай SV 🧸',
    'Участвуй в викторинах и получай призы! 🎁',
  ];

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
    _loadUserData();
    _loadTodaySteps();
    _dailyTip = (_tips..shuffle()).first;
    _loadLatestItems();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_profile');
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        setState(() {
          _userName = map['name']?.toString() ?? 'Друг';
          _avatarUrl = map['avatarUrl']?.toString();
        });
      } catch (e) {
        setState(() => _userName = prefs.getString('user_name') ?? 'Друг');
      }
    } else {
      setState(() => _userName = prefs.getString('user_name') ?? 'Друг');
    }
  }

  Future<void> _loadTodaySteps() async {
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('today_steps') ?? 0;
    final total = prefs.getInt('total_steps') ?? 0;
    setState(() {
      _todaySteps = steps;
      _level = (total / 50000).floor() + 1;
    });
  }

  void _loadLatestItems() {
    final items = context.read<ItemsProvider>().items;
    setState(() {
      _latestItems = items.take(10).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final backgroundColor =
    isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildWelcomeHeader(
                      isDark, textColor, subTextColor, surfaceColor),
                ),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildLatestItemsCarousel(
                    isDark, surfaceColor, textColor),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildQuickActions(
                    isDark, textColor, subTextColor, surfaceColor),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildStepTracker(
                    isDark, textColor, subTextColor, surfaceColor),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildGamesSection(
                    isDark, textColor, subTextColor, surfaceColor),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildDailyTip(isDark, textColor, subTextColor),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildOpenAppButton(isDark),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(bool isDark, Color textColor, Color subTextColor,
      Color surfaceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.orange.shade100,
              backgroundImage: _avatarUrl != null
                  ? CachedNetworkImageProvider(_avatarUrl!)
                  : null,
              child: _avatarUrl == null
                  ? Text(
                  _userName.isNotEmpty
                      ? _userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 24))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('С возвращением, $_userName!',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Colors.orange, Colors.deepOrange]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Уровень $_level',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: ((_todaySteps % 50000) / 50000).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor:
          isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
        const SizedBox(height: 4),
        Text('До следующего уровня: ${50000 - (_todaySteps % 50000)} шагов',
            style: TextStyle(color: subTextColor, fontSize: 11)),
      ],
    );
  }

  Widget _buildLatestItemsCarousel(
      bool isDark, Color surfaceColor, Color textColor) {
    if (_latestItems.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('🔥 Новые объявления',
              style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _latestItems.length,
            itemBuilder: (ctx, i) {
              final item = _latestItems[i];
              return GestureDetector(
                onTap: () => _openMainApp(),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: surfaceColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.15 : 0.06),
                        blurRadius: 8,
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
                              top: Radius.circular(16)),
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
                        padding: const EdgeInsets.all(8.0),
                        child: Text(item.title,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
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

  Widget _buildQuickActions(bool isDark, Color textColor, Color subTextColor,
      Color surfaceColor) {
    final actions = [
      {
        'icon': Icons.list_alt_rounded,
        'label': 'Лента вещей',
        'color': Colors.orange,
        'route': 'main'
      },
      {
        'icon': Icons.add_circle_outline_rounded,
        'label': 'Добавить вещь',
        'color': Colors.green,
        'route': 'add'
      },
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'label': 'Чаты',
        'color': Colors.blue,
        'route': 'chats'
      },
      {
        'icon': Icons.swap_horiz_rounded,
        'label': 'Мои обмены',
        'color': Colors.purple,
        'route': 'trades'
      },
      {
        'icon': Icons.directions_walk_rounded,
        'label': 'Шагомер',
        'color': Colors.amber,
        'route': 'pedometer'
      },
      {
        'icon': Icons.games_rounded,
        'label': 'Игры',
        'color': Colors.teal,
        'route': 'games'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⚡ Быстрые действия',
              style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: actions.length,
            itemBuilder: (ctx, i) {
              final a = actions[i];
              return GestureDetector(
                onTap: () => _handleAction(a['route'] as String),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              (a['color'] as Color).withOpacity(0.3),
                              (a['color'] as Color).withOpacity(0.1)
                            ],
                          ),
                        ),
                        child: Icon(a['icon'] as IconData,
                            size: 28, color: a['color'] as Color),
                      ),
                      const SizedBox(height: 8),
                      Text(a['label'] as String,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleAction(String route) {
    switch (route) {
      case 'main':
        _openMainApp();
        break;
      case 'add':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddItemScreen()));
        break;
      case 'chats':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MessengerScreen()));
        break;
      case 'trades':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TradeOffersScreen()));
        break;
      case 'pedometer':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PedometerScreen()));
        break;
      case 'games':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GamesScreen()));
        break;
    }
  }

  void _openMainApp() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const MainNavigationScreen()));
  }

  Widget _buildStepTracker(bool isDark, Color textColor, Color subTextColor,
      Color surfaceColor) {
    final progress = (_todaySteps / 10000).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.withOpacity(0.1),
              Colors.deepOrange.withOpacity(0.1)
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      color: Colors.orange,
                      backgroundColor: Colors.grey.shade300),
                  Icon(Icons.directions_walk, size: 28, color: Colors.orange),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_todaySteps шагов сегодня',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text('Цель: 10 000 шагов',
                    style: TextStyle(color: subTextColor, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Обновлённая секция игр
  Widget _buildGamesSection(bool isDark, Color textColor, Color subTextColor,
      Color surfaceColor) {
    final games = [
      {
        'icon': Icons.memory_rounded,
        'label': 'Запомни число',
        'color': Colors.orange,
        'screen': const GamesScreen(),
      },
      {
        'icon': Icons.sports_esports_rounded,
        'label': 'Шахматы',
        'color': Colors.purple,
        'screen': const ChessGameScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎯 Развлечения',
              style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: games.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                final g = games[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => g['screen'] as Widget),
                  ),
                  child: Container(
                    width: 130,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(g['icon'] as IconData,
                            size: 30, color: g['color'] as Color),
                        const SizedBox(height: 8),
                        Text(g['label'] as String,
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
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

  Widget _buildDailyTip(bool isDark, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.teal.withOpacity(0.1),
              Colors.blue.withOpacity(0.1)
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.teal.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_rounded, size: 24, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child:
              Text(_dailyTip, style: TextStyle(color: textColor, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenAppButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _openMainApp,
          icon: const Icon(Icons.explore_rounded, size: 22),
          label: const Text('Открыть полную ленту',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            elevation: 4,
            shadowColor: Colors.orange.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}