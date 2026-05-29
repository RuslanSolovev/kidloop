import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemsProvider>().loadItems();
      context.read<TradesProvider>().loadOffers();
    });
    _globalTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        context.read<ItemsProvider>().loadItems();
        context.read<TradesProvider>().loadOffers();
        _loadAvatar();
      }
    });
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_profile');
    if (jsonString != null) {
      try {
        final map = jsonDecode(jsonString);
        final url = map['avatarUrl'] ?? '';
        if (mounted) {
          setState(() => _avatarUrl = url.isNotEmpty ? url : null);
        }
      } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Уведомления (пока заглушка)
            },
          ),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Чаты'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Карта'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Обмены'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: 'Шагомер'),
        ],
      ),
    );
  }
}