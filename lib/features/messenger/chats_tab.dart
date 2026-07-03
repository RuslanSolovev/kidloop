// chats_tab.dart
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

class _ChatsTabState extends State<ChatsTab> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  bool _initialLoad = true;
  String? _currentUserId;
  Timer? _refreshTimer;
  int _retryCount = 0;
  String? _loadError;

  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const String _cacheKey = 'chats_cache';

  @override
  bool get wantKeepAlive => true;

  // 🔥 Используем Theme напрямую
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadChats();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadChats());
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');

    await _loadCachedChats();
    await _loadChats();

    if (mounted) {
      setState(() {
        _loading = false;
        _initialLoad = false;
      });
    }
  }

  Future<void> _loadCachedChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as List;
        if (mounted && _chats.isEmpty) {
          setState(() {
            _chats = data.cast<Map<String, dynamic>>();
            _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _cacheChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_chats));
    } catch (_) {}
  }

  Future<void> _loadChats() async {
    if (_currentUserId == null) return;

    try {
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list-chats", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() {
          _chats = (data['chats'] as List).cast<Map<String, dynamic>>();
          _retryCount = 0;
          _loadError = null;
          _loading = false;
        });
        await _cacheChats();
      } else {
        _handleLoadError();
      }
    } catch (_) {
      _handleLoadError();
    }
  }

  void _handleLoadError() {
    _retryCount++;
    if (_chats.isEmpty && mounted) {
      setState(() {
        _loading = false;
        if (_retryCount >= 3) {
          _loadError = 'Не удалось загрузить чаты';
        }
      });
    }

    if (_retryCount <= 5 && mounted) {
      final delay = Duration(seconds: 2 * _retryCount);
      Future.delayed(delay, () {
        if (mounted) _loadChats();
      });
    }
  }

  // 🔥 Получаем текст последнего сообщения с автором
  String _formatLastMessage(Map<String, dynamic> chat) {
    final lastMsg = chat['last_message'] ?? '';
    final lastSenderName = chat['last_sender_name'] ?? '';
    final isMe = (chat['last_sender_id'] ?? '') == _currentUserId;

    if (lastMsg.toString().isEmpty) return 'Нет сообщений';

    final sender = isMe ? 'Вы' : (lastSenderName.isNotEmpty ? lastSenderName : 'Пользователь');
    return '$sender: $lastMsg';
  }

  void _openChat(Map<String, dynamic> chat) {
    final chatId = chat['chat_id'] ?? '';
    final otherUserId = chat['other_user_id'] ?? '';
    final otherName = chat['other_name'] ?? 'Пользователь';
    final otherAvatar = chat['other_avatar'] ?? '';

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
          chatId: chatId,
          otherUserId: otherUserId,
          otherName: otherName,
          otherAvatar: otherAvatar,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading && _chats.isEmpty) {
      return _buildLoadingSkeleton();
    }

    if (_chats.isEmpty && _loadError != null) {
      return _buildErrorState();
    }

    if (_chats.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: Colors.orange,
      backgroundColor: _surfaceColor,
      onRefresh: () async {
        _retryCount = 0;
        _loadError = null;
        await _loadChats();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: ListView.builder(
          key: ValueKey(_chats.length),
          padding: const EdgeInsets.only(top: 8),
          itemCount: _chats.length,
          itemBuilder: (context, index) {
            return _buildChatTile(_chats[index], index);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, decoration: BoxDecoration(color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200, borderRadius: BorderRadius.circular(8))),
                    const SizedBox(height: 4),
                    Container(height: 12, decoration: BoxDecoration(color: _isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100, borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withValues(alpha: 0.1)),
            child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.orange),
          ),
          const SizedBox(height: 16),
          Text(_loadError!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textColor)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() { _loading = true; _loadError = null; _retryCount = 0; });
              _loadChats();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withValues(alpha: 0.1)),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.orange),
          ),
          const SizedBox(height: 16),
          Text('Нет чатов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _textColor)),
          const SizedBox(height: 8),
          Text('Добавьте друзей, чтобы начать общение', style: TextStyle(color: _subTextColor)),
        ],
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat, int index) {
    final name = chat['other_name'] ?? 'Пользователь';
    final avatar = chat['other_avatar'] ?? '';
    final lastTime = chat['last_time'];
    final unreadCount = chat['unread_count'] ?? 0;

    // 🔥 Форматируем последнее сообщение с автором
    final lastMsg = _formatLastMessage(chat);
    final isMe = (chat['last_sender_id'] ?? '') == _currentUserId;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: unreadCount > 0 ? Colors.orange.withValues(alpha: 0.3) : _cardBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDarkMode ? 0.1 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openChat(chat),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 🔥 Аватар с индикатором непрочитанных
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.orange.shade100,
                        backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                        child: avatar.isEmpty
                            ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 20))
                            : null,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // 🔥 Имя и последнее сообщение
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // 🔥 Индикатор "Вы:" если это моё сообщение
                          if (isMe && lastMsg.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Вы', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              lastMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unreadCount > 0 ? _textColor.withValues(alpha: 0.8) : _subTextColor,
                                fontSize: 13,
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 🔥 Время
                Text(
                  _formatTime(lastTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: unreadCount > 0 ? Colors.orange : _subTextColor,
                    fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(dynamic iso) {
    if (iso == null || iso.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(iso.toString());
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) return DateFormat('HH:mm').format(dt);
      if (dt.year == now.year) return DateFormat('dd MMM', 'ru').format(dt);
      return DateFormat('dd.MM.yy').format(dt);
    } catch (_) {
      return '';
    }
  }
}