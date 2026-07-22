// features/messenger/chats_tab.dart
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
  String? _currentUserId;
  Timer? _refreshTimer;
  int _retryCount = 0;
  String? _loadError;

  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const String _cacheKey = 'chats_cache';

  @override
  bool get wantKeepAlive => true;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

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
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCachedChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && mounted && _chats.isEmpty) {
        setState(() => _chats = (jsonDecode(cached) as List).cast<Map<String, dynamic>>());
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
        Uri.parse(chatApiUrl), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list-chats", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() { _chats = (data['chats'] as List).cast<Map<String, dynamic>>(); _retryCount = 0; _loadError = null; _loading = false; });
        await _cacheChats();
      } else { _handleLoadError(); }
    } catch (_) { _handleLoadError(); }
  }

  void _handleLoadError() {
    _retryCount++;
    if (_chats.isEmpty && mounted) setState(() { _loading = false; if (_retryCount >= 3) _loadError = 'Не удалось загрузить чаты'; });
    if (_retryCount <= 5 && mounted) Future.delayed(Duration(seconds: 2 * _retryCount), () { if (mounted) _loadChats(); });
  }

  String _formatLastMessage(Map<String, dynamic> chat) {
    final lastMsg = chat['last_message'] ?? '';
    final lastSenderName = chat['last_sender_name'] ?? '';
    final isMe = (chat['last_sender_id'] ?? '') == _currentUserId;
    if (lastMsg.toString().isEmpty) return 'Нет сообщений';
    final sender = isMe ? 'Вы' : (lastSenderName.isNotEmpty ? lastSenderName : 'Пользователь');
    return '$sender: $lastMsg';
  }

  void _openChat(Map<String, dynamic> chat) {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
        chatId: chat['chat_id'] ?? '', otherUserId: chat['other_user_id'] ?? '',
        otherName: chat['other_name'] ?? 'Пользователь', otherAvatar: chat['other_avatar'] ?? '',
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)), child: child);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final backgroundColor = _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF5F5F7);
    final surfaceColor = _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1C1C1E);
    final subTextColor = _isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);

    if (_loading && _chats.isEmpty) return _buildLoadingSkeleton(backgroundColor, surfaceColor);
    if (_chats.isEmpty && _loadError != null) return _buildErrorState(backgroundColor, textColor, subTextColor);
    if (_chats.isEmpty) return _buildEmptyState(backgroundColor, textColor, subTextColor);

    return Container(
      color: backgroundColor,
      child: RefreshIndicator(
        color: const Color(0xFFFF6B35), backgroundColor: surfaceColor,
        onRefresh: () async { _retryCount = 0; _loadError = null; await _loadChats(); },
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: _chats.length,
          itemBuilder: (context, index) => _buildChatTile(_chats[index], index, surfaceColor, textColor, subTextColor),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(Color bg, Color surface) {
    return Container(
      color: bg,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]), boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]), child: const Icon(Icons.chat_rounded, color: Colors.white, size: 28)),
          const SizedBox(height: 20),
          Text('Загружаем чаты...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF8E8E93))),
          const SizedBox(height: 8),
          SizedBox(width: 120, height: 4, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0.2, end: 1.0), duration: const Duration(milliseconds: 1500), builder: (context, value, child) => LinearProgressIndicator(value: value, backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)), borderRadius: BorderRadius.circular(2)))),
        ]),
      ),
    );
  }

  Widget _buildErrorState(Color bg, Color text, Color sub) {
    return Container(
      color: bg,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFF6B35).withOpacity(0.1)), child: const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFFF6B35))),
          const SizedBox(height: 16), Text(_loadError!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: text)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () { setState(() { _loading = true; _loadError = null; _retryCount = 0; }); _loadChats(); },
            icon: const Icon(Icons.refresh_rounded), label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState(Color bg, Color text, Color sub) {
    return Container(
      color: bg,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFF6B35).withOpacity(0.08)), child: const Icon(Icons.chat_bubble_outline_rounded, size: 52, color: Color(0xFFFF6B35))),
          const SizedBox(height: 20), Text('Нет чатов', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: text, letterSpacing: -0.3)),
          const SizedBox(height: 8), Text('Найдите друзей и начните общение', style: TextStyle(fontSize: 15, color: sub)),
        ]),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat, int index, Color surface, Color text, Color sub) {
    final name = chat['other_name'] ?? 'Пользователь';
    final avatar = chat['other_avatar'] ?? '';
    final lastTime = chat['last_time'];
    final unreadCount = chat['unread_count'] ?? 0;
    final lastMsg = _formatLastMessage(chat);
    final isMe = (chat['last_sender_id'] ?? '') == _currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDarkMode ? 0.12 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openChat(chat),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                // Аватар
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]), boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                      padding: const EdgeInsets.all(2.5),
                      child: CircleAvatar(radius: 26, backgroundColor: _isDarkMode ? const Color(0xFF2C2C3E) : Colors.white, backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: avatar.isEmpty ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold, fontSize: 20)) : null),
                    ),
                    if (unreadCount > 0) Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: const Color(0xFFFF3B30), shape: BoxShape.circle, border: Border.all(color: surface, width: 2)), child: Text(unreadCount > 99 ? '99+' : unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
                  ],
                ),
                const SizedBox(width: 14),
                // Контент
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(name, style: TextStyle(fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600, fontSize: 16, color: text, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(_formatTime(lastTime), style: TextStyle(fontSize: 12, fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400, color: unreadCount > 0 ? const Color(0xFFFF6B35) : sub)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (isMe && lastMsg.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(5)), child: const Text('Вы', style: TextStyle(fontSize: 10, color: Color(0xFFFF6B35), fontWeight: FontWeight.w700))),
                      Expanded(child: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400, color: unreadCount > 0 ? text.withOpacity(0.7) : sub))),
                      if (unreadCount > 0) Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 8), decoration: const BoxDecoration(color: Color(0xFFFF6B35), shape: BoxShape.circle)),
                    ]),
                  ]),
                ),
              ]),
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
    } catch (_) { return ''; }
  }
}