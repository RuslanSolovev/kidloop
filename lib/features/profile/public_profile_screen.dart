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
    setState(() => _loading = false);
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
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadStats() async {
    try {
      // Загружаем вещи пользователя
      final itemsRes = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4ei9an1aushareidmjc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list", "user_id": widget.userId}),
      );
      final itemsData = jsonDecode(itemsRes.body);
      if (itemsData['ok'] == true) {
        setState(() => _itemsCount = (itemsData['items'] as List).length);
      }

      // Загружаем обмены пользователя
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
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: Text(name)),
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
                    radius: 55,
                    backgroundColor: Colors.white,
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(Icons.person, size: 60, color: Colors.blue)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(name,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(city, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // STATS
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Вещей', value: '$_itemsCount', icon: Icons.inventory)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Обменов', value: '$_tradesCount', icon: Icons.swap_horiz)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Успешно', value: '$_completedTrades', icon: Icons.check_circle)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Рейтинг', value: '$successRate%', icon: Icons.star)),
              ],
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
                  if (age > 0) _infoRow(Icons.cake, 'Возраст', '$age'),
                  if (telegram.isNotEmpty) _infoRow(Icons.telegram, 'Telegram', telegram),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('О себе', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(bio, style: TextStyle(color: Colors.grey.shade700)),
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