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

  static const String chatApiUrl =
      'https://functions.yandexcloud.net/d4es79s8locoa8ul3pe3';

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
    await _loadChats();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChats() async {
    if (_currentUserId == null) return;
    try {
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list-chats", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() {
          _chats = (data['chats'] as List).cast<Map<String, dynamic>>();
          _retryCount = 0;
          _loadError = null;
        });
      } else {
        _retryLoad();
      }
    } catch (e) {
      _retryLoad();
    }
  }

  void _retryLoad() {
    _retryCount++;
    if (_retryCount <= 5 && mounted) {
      if (_retryCount >= 3) {
        setState(() => _loadError = 'Проблемы с загрузкой. Пробуем снова...');
      }
      Future.delayed(const Duration(seconds: 2), _loadChats);
    } else if (_retryCount > 5 && mounted) {
      setState(() => _loadError = 'Не удалось загрузить чаты. Потяните чтобы обновить.');
    }
  }

  void _openChat(Map<String, dynamic> chat) {
    final chatId = chat['chat_id'] ?? '';
    final otherUserId = chat['other_user_id'] ?? '';
    final otherName = chat['other_name'] ?? 'Пользователь';
    final otherAvatar = chat['other_avatar'] ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: otherUserId,
          otherName: otherName,
          otherAvatar: otherAvatar,
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
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chats.isEmpty && _loadError != null) {
      return _buildErrorView();
    }

    if (_chats.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: () async {
        _retryCount = 0;
        _loadError = null;
        await _loadChats();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return _ChatCard(
            chat: chat,
            currentUserId: _currentUserId!,
            onTap: () => _openChat(chat),
            formatTime: _formatTime,
          );
        },
      ),
    );
  }

  Widget _buildErrorView() {
    final colorScheme = Theme.of(context).colorScheme;
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_loadError!, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 8),
            Text('Нажмите чтобы повторить',
                style: TextStyle(color: colorScheme.primary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Нет чатов',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Добавьте друзей, чтобы начать общение',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// --- Карточка чата ---
class _ChatCard extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String currentUserId;
  final VoidCallback onTap;
  final String Function(String?) formatTime;

  const _ChatCard({
    required this.chat,
    required this.currentUserId,
    required this.onTap,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = chat['other_name'] ?? 'Пользователь';
    final avatar = chat['other_avatar'] ?? '';
    final lastMsg = chat['last_message'] ?? '';
    final lastTime = chat['last_time'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'avatar_${chat['other_user_id']}',
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: avatar.isNotEmpty
                        ? CachedNetworkImageProvider(avatar)
                        : null,
                    backgroundColor: avatar.isEmpty
                        ? colorScheme.primaryContainer
                        : null,
                    child: avatar.isEmpty
                        ? Text(name[0].toUpperCase(),
                        style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        lastMsg.isNotEmpty ? lastMsg : 'Нет сообщений',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (lastTime != null)
                  Text(formatTime(lastTime),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}