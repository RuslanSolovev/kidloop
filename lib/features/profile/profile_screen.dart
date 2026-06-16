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
    // 🔥 Перезагружаем профиль при входе
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfile();
    });
  }

  Future<void> _refreshProfile() async {
    try {
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.loadProfile();
      await _loadBalance();
    } catch (e) {
      print('Error refreshing profile: $e');
    }
  }

  Future<void> _loadBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      if (userId.isEmpty) {
        if (mounted) setState(() => _loadingBalance = false);
        return;
      }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      // 🔥 Очищаем ВСЕ провайдеры
      if (mounted) {
        context.read<ProfileProvider>().clearProfile();
        context.read<ItemsProvider>().clearItems();
        context.read<TradesProvider>().clearOffers();
      }

      // 🔥 Очищаем SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти из аккаунта',
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                children: [
                  Hero(
                    tag: 'profile_avatar',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
                      ),
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white,
                        backgroundImage: profile.avatarUrl.isNotEmpty ? NetworkImage(profile.avatarUrl) : null,
                        child: profile.avatarUrl.isEmpty
                            ? Icon(Icons.person, size: 60, color: Colors.orange)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profile.name.isNotEmpty ? profile.name : 'Пользователь',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  if (profile.city.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 18),
                        const SizedBox(width: 4),
                        Text(profile.city, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: _loadingBalance
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.stars, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text('$_svBalance SV', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(20)),
                    child: Text('УРОВЕНЬ $level', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 20),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Заполненность профиля', style: TextStyle(color: Colors.white.withOpacity(0.9))),
                      Text('${(completion * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: completion, minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Кнопки
            Row(children: [
              Expanded(child: _ActionButton(icon: Icons.edit, label: 'Редактировать', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _refreshProfile()); }, gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade400]))),
              const SizedBox(width: 12),
              Expanded(child: _ActionButton(icon: Icons.logout, label: 'Выйти', onPressed: _logout, gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600]))),
            ]),

            const SizedBox(height: 24),

            // Информация
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Информация', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _InfoTile(icon: Icons.cake, label: 'Возраст', value: '${profile.age}'),
                _InfoTile(icon: Icons.category, label: 'Любимая категория', value: profile.favoriteCategory),
                _InfoTile(icon: Icons.telegram, label: 'Telegram', value: profile.telegram.isEmpty ? 'Не указан' : profile.telegram),
                const SizedBox(height: 16),
                Text('О себе', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(profile.bio.isEmpty ? 'Нет описания' : profile.bio, style: TextStyle(color: Colors.grey.shade600)),
              ]),
            ),

            const SizedBox(height: 24),

            // Статистика
            Row(children: [
              Expanded(child: _StatCard(title: 'Мои вещи', value: '$myItems', icon: Icons.inventory, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: 'Обмены', value: '${trades.length}', icon: Icons.swap_horiz, color: Colors.orange)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StatCard(title: 'Успешно', value: '$completedTrades', icon: Icons.check_circle, color: Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: 'Рейтинг', value: '$successRate%', icon: Icons.star, color: Colors.amber)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.orange, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: RichText(text: TextSpan(style: DefaultTextStyle.of(context).style, children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value),
        ]))),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))]),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 28, color: color)),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Gradient gradient;
  const _ActionButton({required this.icon, required this.label, required this.onPressed, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: gradient),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
        ),
      ),
    );
  }
}