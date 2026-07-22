// features/users/users_tab.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../profile/public_profile_screen.dart';
import 'chat_screen.dart';
import '../../services/notification_service.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _searchQuery = '';
  String? _currentUserId;
  String? _currentUserName;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  static const String userApiUrl = 'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';
  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const int _pageSize = 15;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _currentUserName = prefs.getString('user_name') ?? 'Пользователь';
    await Future.wait([_loadFriends(), _loadPendingRequests(), _loadUsers()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadUsers({bool reset = true}) async {
    if (reset) { _offset = 0; _hasMore = true; if (mounted) setState(() { _users.clear(); _loading = true; }); }
    try {
      final response = await http.post(Uri.parse(userApiUrl), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list", "query": _searchQuery, "user_id": _currentUserId, "offset": _offset, "limit": _pageSize}),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        final newUsers = (data['users'] as List).cast<Map<String, dynamic>>();
        setState(() {
          if (reset) { _users = newUsers; } else { _users.addAll(newUsers); }
          _hasMore = newUsers.length >= _pageSize; _offset += newUsers.length; _loading = false;
        });
      } else if (mounted) { setState(() => _loading = false); }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadMoreUsers() async {
    if (_loadingMore || !_hasMore || _searchQuery.isNotEmpty) return;
    _loadingMore = true;
    await _loadUsers(reset: false);
    _loadingMore = false;
  }

  Future<void> _loadFriends() async {
    try {
      final response = await http.post(Uri.parse(userApiUrl), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "friends", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) setState(() => _friends = (data['friends'] as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _loadPendingRequests() async {
    try {
      final response = await http.post(Uri.parse(userApiUrl), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "pending-requests", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) setState(() => _pendingRequests = (data['requests'] as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  bool _isFriend(String userId) => _friends.any((f) => f['user_id'] == userId);

  Future<void> _sendFriendRequest(String friendId) async {
    try {
      await http.post(Uri.parse(userApiUrl), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "send-friend-request", "user_id": _currentUserId, "friend_id": friendId}),
      );
      NotificationService.sendNotification(targetUserId: friendId, type: 'friend_request', data: {'user_id': _currentUserId, 'user_name': _currentUserName ?? 'Пользователь'});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Заявка отправлена! 🎉'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось отправить заявку'), backgroundColor: Colors.red));
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final isDark = _isDarkMode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Удалить из друзей?', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1C1C1E), fontWeight: FontWeight.bold)),
        content: Text('Вы уверены?', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF8E8E93))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: TextStyle(color: isDark ? const Color(0xFF8E8E93) : Colors.grey.shade600))),
          Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.red, Colors.deepOrange]), borderRadius: BorderRadius.circular(14)), child: TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await http.post(Uri.parse(userApiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"action": "remove-friend", "user_id": _currentUserId, "friend_id": friendId}));
      await _loadFriends();
    } catch (_) {}
  }

  Future<void> _acceptRequest(String friendId) async {
    try {
      await http.post(Uri.parse(userApiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"action": "accept-friend", "user_id": _currentUserId, "friend_id": friendId}));
      NotificationService.sendNotification(targetUserId: friendId, type: 'friend_accepted', data: {'user_id': _currentUserId, 'user_name': _currentUserName ?? 'Пользователь'});
      await Future.wait([_loadFriends(), _loadPendingRequests()]);
    } catch (_) {}
  }

  Future<void> _openChat(String otherUserId, String otherName, String otherAvatar) async {
    try {
      final response = await http.post(Uri.parse(chatApiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"action": "get-or-create-chat", "user1_id": _currentUserId, "user2_id": otherUserId})).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (data['ok'] == true && data['chat_id'] != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: data['chat_id'], otherUserId: otherUserId, otherName: otherName, otherAvatar: otherAvatar)));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['errorMessage'] ?? 'Не удалось создать чат'), backgroundColor: Colors.red));
      }
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка соединения'), backgroundColor: Colors.red)); }
  }

  void _openProfile(String userId) => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)));

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = query.trim());
      _loadUsers(reset: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() { _searchQuery = ''; _users.clear(); });
    _loadUsers(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final backgroundColor = _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF5F5F7);
    final surfaceColor = _isDarkMode ? const Color(0xFF1C1C2E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1C1C1E);
    final subTextColor = _isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);

    return Container(
      color: backgroundColor,
      child: _loading
          ? _buildLoadingIndicator(subTextColor)
          : RefreshIndicator(
        color: const Color(0xFFFF6B35), backgroundColor: surfaceColor,
        onRefresh: () async { setState(() { _loading = true; _users.clear(); }); await Future.wait([_loadFriends(), _loadPendingRequests(), _loadUsers()]); },
        child: CustomScrollView(
          controller: _scrollController, physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSearchBar(surfaceColor, textColor, subTextColor),
            if (_searchQuery.isEmpty && _pendingRequests.isNotEmpty) ...[
              _sectionHeader('Заявки в друзья', _pendingRequests.length, const Color(0xFFFF6B35), textColor),
              _buildUsersList(_pendingRequests, isPending: true, textColor: textColor, subTextColor: subTextColor, surfaceColor: surfaceColor),
            ],
            if (_searchQuery.isEmpty && _friends.isNotEmpty) ...[
              _sectionHeader('Друзья', _friends.length, const Color(0xFF34C759), textColor),
              _buildUsersList(_friends, isFriend: true, textColor: textColor, subTextColor: subTextColor, surfaceColor: surfaceColor),
            ],
            _sectionHeader(_searchQuery.isNotEmpty ? 'Результаты' : 'Пользователи', _users.length, const Color(0xFF007AFF), textColor),
            _buildUsersList(_users, hasMore: _hasMore && _searchQuery.isEmpty, textColor: textColor, subTextColor: subTextColor, surfaceColor: surfaceColor),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(Color subTextColor) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]), boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]), child: const Icon(Icons.people_rounded, color: Colors.white, size: 28)),
      const SizedBox(height: 20),
      Text('Загружаем пользователей...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: subTextColor)),
      const SizedBox(height: 8),
      SizedBox(width: 120, height: 4, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0.2, end: 1.0), duration: const Duration(milliseconds: 1500), builder: (_, value, __) => LinearProgressIndicator(value: value, backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)), borderRadius: BorderRadius.circular(2)))),
    ]));
  }

  Widget _buildSearchBar(Color surfaceColor, Color textColor, Color subTextColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.06), blurRadius: 15, offset: const Offset(0, 4))]),
          child: TextField(
            controller: _searchController, style: TextStyle(color: textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Поиск по имени или городу...', hintStyle: TextStyle(color: subTextColor, fontSize: 14),
              prefixIcon: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.search_rounded, color: Colors.white, size: 20)),
              suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: subTextColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.close_rounded, color: subTextColor, size: 16)), onPressed: _clearSearch) : null,
              filled: true, fillColor: Colors.transparent, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: const Color(0xFFFF6B35).withOpacity(0.5), width: 2)),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color, Color textColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(children: [
          Container(width: 3, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: textColor, letterSpacing: -0.3)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text('$count', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }

  Widget _buildUsersList(List<Map<String, dynamic>> users, {bool isFriend = false, bool isPending = false, bool hasMore = false, required Color textColor, required Color subTextColor, required Color surfaceColor}) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (ctx, i) {
            if (hasMore && i == users.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: _loadingMore ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B35))) : OutlinedButton.icon(
                  onPressed: _loadMoreUsers, icon: const Icon(Icons.expand_more_rounded, size: 18), label: const Text('Показать ещё'),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF6B35), side: const BorderSide(color: Color(0xFFFF6B35), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                )),
              );
            }
            if (i >= users.length) return null;
            return _userTile(users[i], isFriend: isFriend, isPending: isPending, textColor: textColor, subTextColor: subTextColor, surfaceColor: surfaceColor);
          },
          childCount: users.length + (hasMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user, {bool isFriend = false, bool isPending = false, required Color textColor, required Color subTextColor, required Color surfaceColor}) {
    final userId = user['user_id'] ?? '';
    final name = user['name'] ?? '';
    final avatarUrl = user['avatar_url'] ?? '';
    final city = user['city'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDarkMode ? 0.12 : 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Material(
          color: Colors.transparent, borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20), onTap: () => _openProfile(userId),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]), boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]), padding: const EdgeInsets.all(2.5), child: CircleAvatar(radius: 28, backgroundColor: _isDarkMode ? const Color(0xFF2C2C3E) : Colors.white, backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null, child: avatarUrl.isEmpty ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold, fontSize: 22)) : null)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isNotEmpty ? name : 'Пользователь', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textColor, letterSpacing: -0.2)),
                  if (city.isNotEmpty) ...[const SizedBox(height: 4), Row(children: [Icon(Icons.location_on_rounded, size: 14, color: subTextColor), const SizedBox(width: 4), Text(city, style: TextStyle(color: subTextColor, fontSize: 13))])],
                ])),
                if (isPending) GestureDetector(onTap: () => _acceptRequest(userId), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]), child: const Text('Принять', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))))
                else if (isFriend) Row(mainAxisSize: MainAxisSize.min, children: [
                  _actionButton(Icons.chat_rounded, const Color(0xFFFF6B35), () => _openChat(userId, name, avatarUrl)),
                  const SizedBox(width: 8),
                  _actionButton(Icons.more_horiz, subTextColor, () => _showFriendOptions(userId, name, avatarUrl, textColor)),
                ])
                else GestureDetector(onTap: () => _sendFriendRequest(userId), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.08), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.person_add_rounded, color: Color(0xFFFF6B35), size: 22))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 22)));
  }

  void _showFriendOptions(String userId, String name, String avatarUrl, Color textColor) {
    final isDark = _isDarkMode;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C2E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 20),
          ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.chat_rounded, color: Color(0xFFFF6B35))), title: Text('Написать', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)), onTap: () { Navigator.pop(ctx); _openChat(userId, name, avatarUrl); }),
          ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_rounded, color: Color(0xFFFF6B35))), title: Text('Профиль', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)), onTap: () { Navigator.pop(ctx); _openProfile(userId); }),
          const Divider(height: 8),
          ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_remove_rounded, color: Colors.red)), title: const Text('Удалить из друзей', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)), onTap: () { Navigator.pop(ctx); _removeFriend(userId); }),
        ])),
      ),
    );
  }
}