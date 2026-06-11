import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Добавлено для SystemNavigator.pop()
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // <-- Добавлено: Храним время последнего нажатия кнопки "Назад"
  DateTime? _lastBackPressTime;

  final screens = const [
    HomeScreen(),
    MessengerScreen(),
    MapScreen(),
    TradeOffersScreen(),
    PedometerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadThemePreference();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });

    _globalTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _refreshData();
      }
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
    setState(() {
      _isDarkMode = isDark;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newThemeMode = !_isDarkMode;
    setState(() {
      _isDarkMode = newThemeMode;
    });
    await prefs.setBool('is_dark_mode', newThemeMode);
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        context.read<ItemsProvider>().loadItems().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print("⚠️ Таймаут загрузки ItemsProvider");
            return;
          },
        ),
        context.read<TradesProvider>().loadOffers().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print("⚠️ Таймаут загрузки TradesProvider");
            return;
          },
        ),
      ]);
    } catch (e) {
      print("❌ Ошибка загрузки данных: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      await Future.wait([
        context.read<ItemsProvider>().loadItems(),
        context.read<TradesProvider>().loadOffers(),
      ]);
      await _loadAvatar();
    } catch (e) {
      print("❌ Ошибка обновления: $e");
    }
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('user_profile');
      if (jsonString != null && jsonString.isNotEmpty) {
        final map = jsonDecode(jsonString);
        final url = map['avatarUrl'] ?? '';
        if (mounted) {
          setState(() => _avatarUrl = url.isNotEmpty ? url : null);
        }
      }
    } catch (e) {
      print("❌ Ошибка загрузки аватара: $e");
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

  // 🔥 НОВЫЙ МЕТОД: Обертка для перехвата кнопки "Назад"
  Widget _wrapInPopScope(Widget child) {
    return Builder(
      builder: (context) {
        return PopScope(
          canPop: false, // Запрещаем стандартное закрытие экрана
          onPopInvoked: (didPop) {
            if (didPop) return; // Если экран всё-таки закрылся, ничего не делаем

            final now = DateTime.now();
            const twoSeconds = Duration(seconds: 2);

            // Если нажали впервые или прошло больше 2 секунд с прошлого нажатия
            if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) >= twoSeconds) {
              _lastBackPressTime = now; // Запоминаем время нажатия

              // Показываем снекбар (Builder нужен именно для корректного context)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Нажмите ещё раз, чтобы выйти'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              // Если нажали второй раз в течение 2 секунд — закрываем приложение
              SystemNavigator.pop();
            }
          },
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Тема приложения
    final brightness = _isDarkMode ? Brightness.dark : Brightness.light;
    final backgroundColor = _isDarkMode ? const Color(0xFF0A0A1A) : Colors.white;
    final cardColor = _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black87;

    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: brightness,
          useMaterial3: true,
          colorSchemeSeed: Colors.orange,
        ),
        // 🔥 Оборачиваем Scaffold в PopScope
        home: _wrapInPopScope(Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                radius: 20,
                child: const Icon(Icons.person, color: Colors.orange, size: 22),
              ),
            ),
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🔄', style: TextStyle(fontSize: 22)),
                SizedBox(width: 6),
                Text(
                  'KidLoop',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              _buildThemeToggle(),
            ],
          ),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                SizedBox(height: 16),
                Text(
                  "Загрузка...",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
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
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: textColor,
        ),
        cardTheme: CardTheme(
          color: cardColor,
          elevation: 4,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: cardColor,
          selectedItemColor: Colors.orange,
          unselectedItemColor: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
        ),
      ),
      // 🔥 Оборачиваем Scaffold в PopScope
      home: _wrapInPopScope(Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.all(6),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) => _loadAvatar());
              },
              child: Hero(
                tag: 'profile_avatar',
                child: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  radius: 20,
                  backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? NetworkImage(_avatarUrl!)
                      : null,
                  child: _avatarUrl == null || _avatarUrl!.isEmpty
                      ? const Icon(Icons.person, color: Colors.orange, size: 22)
                      : null,
                ),
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔄', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Text(
                'KidLoop',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 1.2,
                  color: textColor,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            _buildThemeToggle(),
          ],
        ),
        body: IndexedStack(
          index: currentIndex,
          children: screens,
        ),
        floatingActionButton: currentIndex == 0
            ? FloatingActionButton(
          onPressed: onAddPressed,
          backgroundColor: Colors.orange,
          child: const Icon(Icons.add),
        )
            : null,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            setState(() => currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.orange,
          unselectedItemColor: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.holiday_village_outlined), label: 'Главная'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Чаты'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Карта'),
            BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Обмены'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: 'Шагомер'),
          ],
        ),
      )),
    );
  }

  // 🔥 Креативный переключатель темы
  Widget _buildThemeToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: _toggleTheme,
        child: Container(
          width: 60,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: _isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey.shade200,
            border: Border.all(
              color: Colors.orange.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Анимированный переключатель
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: _isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isDarkMode
                          ? [const Color(0xFFE94560), const Color(0xFFFF6B6B)]
                          : [Colors.orange, Colors.orange.shade700],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                      key: ValueKey(_isDarkMode),
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
    );
  }
}