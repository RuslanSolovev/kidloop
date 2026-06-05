import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _profile;
  int _itemsCount = 0;
  int _tradesCount = 0;
  int _completedTrades = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadStats(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4euctluka7dnot8sosh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get", "user_id": widget.userId}),
      );
      final data = jsonDecode(response.body);
      if (data['ok'] == true && data['profile'] != null) {
        setState(() => _profile = data['profile']);
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final itemsRes = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4ei9an1aushareidmjc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list", "user_id": widget.userId}),
      );
      final itemsData = jsonDecode(itemsRes.body);
      if (itemsData['ok'] == true) {
        setState(() => _itemsCount = (itemsData['items'] as List).length);
      }

      final offersRes = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4e77rr4t3hlvjo7n77b'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list", "user_id": widget.userId}),
      );
      final offersData = jsonDecode(offersRes.body);
      if (offersData['ok'] == true) {
        final offers = offersData['offers'] as List;
        setState(() {
          _tradesCount = offers.length;
          _completedTrades = offers.where((o) => o['status'] == 'completed').length;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Профиль')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Профиль')),
        body: const Center(child: Text('Профиль не найден')),
      );
    }

    final name = _profile!['name'] ?? 'Без имени';
    final city = _profile!['city'] ?? '';
    final bio = _profile!['bio'] ?? '';
    final telegram = _profile!['telegram'] ?? '';
    final age = _profile!['age'] ?? 0;
    final avatarUrl = _profile!['avatar_url'] ?? '';

    final successRate = _tradesCount > 0 ? (_completedTrades / _tradesCount * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Шапка профиля
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.6)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white,
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Icon(Icons.person, size: 60, color: colorScheme.primary)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 20),
                        const SizedBox(width: 4),
                        Text(city, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ],
                  if (telegram.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Здесь можно открыть ссылку на Telegram
                      },
                      icon: const Icon(Icons.telegram),
                      label: const Text('Написать'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Статистика
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Вещей', value: '$_itemsCount', icon: Icons.inventory, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Обменов', value: '$_tradesCount', icon: Icons.swap_horiz, color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Успешно', value: '$_completedTrades', icon: Icons.check_circle, color: Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Рейтинг', value: '$successRate%', icon: Icons.star, color: Colors.amber)),
              ],
            ),

            const SizedBox(height: 24),

            // Информация
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Информация', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  if (age > 0) _InfoTile(icon: Icons.cake, label: 'Возраст', value: '$age'),
                  if (telegram.isNotEmpty) _InfoTile(icon: Icons.telegram, label: 'Telegram', value: telegram),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('О себе', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(bio, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ],
                  if (age == 0 && telegram.isEmpty && bio.isEmpty)
                    const Text('Пользователь пока не заполнил информацию',
                        style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Информационная строка для публичного профиля
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Карточка статистики (аналогично личному профилю)
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }
}