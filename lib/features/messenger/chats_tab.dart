import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  String? _currentUserId;
  Timer? _refreshTimer;
  int _retryCount = 0;
  String? _loadError;

  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4es79s8locoa8ul3pe3';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadChats());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    print("🟢 ChatsTab: userId=$_currentUserId");
    await _loadChats();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChats() async {
    if (_currentUserId == null) {
      print("🔴 ChatsTab: userId is null, skip loading");
      return;
    }

    try {
      print("🔄 ChatsTab: loading chats...");
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list-chats", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 10));

      print("📦 ChatsTab: status=${response.statusCode}, body=${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");
      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() {
          _chats = (data['chats'] as List).cast<Map<String, dynamic>>();
          _retryCount = 0;
          _loadError = null;
        });
        print("✅ ChatsTab: loaded ${_chats.length} chats");
      } else {
        print("⚠️ ChatsTab: server returned ok=false or null data");
        _retryLoad();
      }
    } catch (e) {
      print("🔴 ChatsTab error: $e");
      _retryLoad();
    }
  }

  void _retryLoad() {
    _retryCount++;
    print("🔄 ChatsTab: retry $_retryCount/5");
    if (_retryCount <= 5 && mounted) {
      if (_retryCount >= 3) {
        setState(() => _loadError = 'Проблемы с загрузкой. Пробуем снова...');
      }
      Future.delayed(const Duration(seconds: 2), _loadChats);
    } else if (_retryCount > 5 && mounted) {
      setState(() => _loadError = 'Не удалось загрузить чаты. Потяните чтобы обновить.');
    }
  }

  void _openChat(String chatId, String otherUserId, String otherName) {
    print("💬 ChatsTab: opening chat $chatId with $otherName");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: otherUserId,
          otherName: otherName,
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      if (dt.day == now.day) return DateFormat('HH:mm').format(dt);
      if (dt.year == now.year) return DateFormat('dd.MM').format(dt);
      return DateFormat('dd.MM.yy').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const Center(child: CircularProgressIndicator(color: Colors.orange));

    if (_chats.isEmpty && _loadError != null) {
      return Center(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _retryCount = 0;
              _loadError = null;
            });
            _loadChats();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_loadError!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Нажмите чтобы повторить', style: TextStyle(color: Colors.orange, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_chats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет чатов', style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 4),
            Text('Добавьте друзей, чтобы начать общение',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        print("🔄 ChatsTab: pull to refresh");
        _retryCount = 0;
        _loadError = null;
        await _loadChats();
      },
      child: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final name = chat['other_name'] ?? 'Пользователь';
          final avatar = chat['other_avatar'] ?? '';
          final lastMsg = chat['last_message'] ?? '';
          final lastTime = chat['last_time'];

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
              child: avatar.isEmpty
                  ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase())
                  : null,
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lastMsg.isNotEmpty ? lastMsg : 'Нет сообщений',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600)),
            trailing: Text(_formatTime(lastTime),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            onTap: () => _openChat(chat['chat_id'] ?? '', chat['other_user_id'] ?? '', name),
          );
        },
      ),
    );
  }
}