import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/items_provider.dart';
import '../../core/profile_provider.dart';
import '../../core/trades_provider.dart';

import '../profile/edit_profile_screen.dart';
import '../../screens/auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _svBalance = 0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4e4du0dtej5k7md0cc5'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-balance", "user_id": userId}),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        if (mounted) {
          setState(() {
            _svBalance = data['balance'] ?? 100;
            _loadingBalance = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingBalance = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта'),
        content: const Text('Ты уверен, что хочешь выйти?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Выйти', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_profile');
      await prefs.remove('user_name');

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  int _calculateLevel(int items, int trades) {
    final score = items * 2 + trades * 3;
    if (score < 5) return 1;
    if (score < 10) return 2;
    if (score < 20) return 3;
    if (score < 35) return 4;
    if (score < 55) return 5;
    if (score < 80) return 6;
    if (score < 110) return 7;
    if (score < 150) return 8;
    if (score < 200) return 9;
    return 10;
  }

  double _profileCompletion({
    required String name,
    required String city,
    required String bio,
    required String telegram,
    required int age,
    required int items,
    required int trades,
    required String avatarUrl,
  }) {
    double progress = 0;
    if (name.isNotEmpty) progress += 0.12;
    if (city.isNotEmpty) progress += 0.12;
    if (bio.isNotEmpty) progress += 0.12;
    if (telegram.isNotEmpty) progress += 0.12;
    if (age > 0) progress += 0.1;
    if (items > 0) progress += 0.12;
    if (trades > 0) progress += 0.12;
    if (avatarUrl.isNotEmpty) progress += 0.18;
    return progress;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final items = context.watch<ItemsProvider>().items;
    final trades = context.watch<TradesProvider>().offers;

    final myItems = items.where((e) => e.isMine).length;
    final completedTrades = trades.where((e) => e.status == 'completed').length;

    final level = _calculateLevel(myItems, completedTrades);

    final completion = _profileCompletion(
      name: profile.name,
      city: profile.city,
      bio: profile.bio,
      telegram: profile.telegram,
      age: profile.age,
      items: myItems,
      trades: completedTrades,
      avatarUrl: profile.avatarUrl,
    );

    final successRate = trades.isEmpty ? 0 : (completedTrades / trades.length * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти из аккаунта',
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade700],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: profile.avatarUrl.isNotEmpty ? NetworkImage(profile.avatarUrl) : null,
                    child: profile.avatarUrl.isEmpty
                        ? const Icon(Icons.person, size: 55, color: Colors.blue)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(profile.name,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text(profile.city, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // SV BALANCE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _loadingBalance
                        ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text('$_svBalance SV',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                    child: Text('LEVEL $level',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 18),
                  LinearProgressIndicator(value: completion, minHeight: 10, borderRadius: BorderRadius.circular(10)),
                  const SizedBox(height: 8),
                  Text('Заполненность профиля ${(completion * 100).round()}%',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // EDIT BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Редактировать профиль', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                },
              ),
            ),

            const SizedBox(height: 12),

            // LOGOUT BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Colors.red),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Выйти из аккаунта', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _logout,
              ),
            ),

            const SizedBox(height: 24),

            // INFO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.05))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Информация', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _infoRow(Icons.cake, 'Возраст', '${profile.age}'),
                  _infoRow(Icons.category, 'Любимая категория', profile.favoriteCategory),
                  _infoRow(Icons.telegram, 'Telegram', profile.telegram.isEmpty ? 'Не указан' : profile.telegram),
                  const SizedBox(height: 16),
                  const Text('О себе', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(profile.bio.isEmpty ? 'Нет описания' : profile.bio),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // STATS
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Мои вещи', value: '$myItems', icon: Icons.inventory)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Обмены', value: '${trades.length}', icon: Icons.swap_horiz)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Успешно', value: '$completedTrades', icon: Icons.check_circle)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Рейтинг', value: '$successRate%', icon: Icons.star)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text('$title: $value')),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.05))],
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: Colors.blue),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title),
        ],
      ),
    );
  }
}