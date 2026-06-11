// users_tab.dart - ПОИСК + ПАГИНАЦИЯ
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../profile/public_profile_screen.dart';
import 'chat_screen.dart';

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
  String? _loadError;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  static const String userApiUrl = 'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';
  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const int _pageSize = 15;

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

    await Future.wait([
      _loadFriends(),
      _loadPendingRequests(),
      _loadUsers(),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadUsers({bool reset = true}) async {
    if (reset) {
      _offset = 0;
      _hasMore = true;
      if (mounted) setState(() { _users = []; _loading = true; });
    }

    try {
      final response = await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "list",
          "query": _searchQuery,
          "user_id": _currentUserId,
          "offset": _offset,
          "limit": _pageSize,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        final newUsers = (data['users'] as List).cast<Map<String, dynamic>>();
        setState(() {
          if (reset) {
            _users = newUsers;
          } else {
            _users.addAll(newUsers);
          }
          _hasMore = newUsers.length >= _pageSize;
          _offset += newUsers.length;
          _loadError = null;
          _loading = false;
        });
      } else if (mounted) {
        setState(() { _loading = false; _hasMore = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_loadingMore || !_hasMore || _searchQuery.isNotEmpty) return;
    _loadingMore = true;
    await _loadUsers(reset: false);
    _loadingMore = false;
  }

  Future<void> _loadFriends() async {
    try {
      final response = await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "friends", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() => _friends = (data['friends'] as List).cast<Map<String, dynamic>>());
      }
    } catch (e) {}
  }

  Future<void> _loadPendingRequests() async {
    try {
      final response = await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "pending-requests", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() => _pendingRequests = (data['requests'] as List).cast<Map<String, dynamic>>());
      }
    } catch (e) {}
  }

  bool _isFriend(String userId) => _friends.any((f) => f['user_id'] == userId);

  Future<void> _sendFriendRequest(String friendId) async {
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "send-friend-request", "user_id": _currentUserId, "friend_id": friendId}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка отправлена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить заявку')),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить из друзей?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "remove-friend", "user_id": _currentUserId, "friend_id": friendId}),
      );
      await _loadFriends();
    } catch (e) {}
  }

  Future<void> _acceptRequest(String friendId) async {
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "accept-friend", "user_id": _currentUserId, "friend_id": friendId}),
      );
      await Future.wait([_loadFriends(), _loadPendingRequests()]);
    } catch (e) {}
  }

  Future<void> _openChat(String otherUserId, String otherName, String otherAvatar) async {
    try {
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "get-or-create-chat",
          "user1_id": _currentUserId,
          "user2_id": otherUserId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (data['ok'] == true && data['chat_id'] != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: data['chat_id'],
              otherUserId: otherUserId,
              otherName: otherName,
              otherAvatar: otherAvatar,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['errorMessage'] ?? 'Не удалось создать чат'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка соединения'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)),
    );
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = query.trim());
      _loadUsers(reset: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _users = [];
    });
    _loadUsers(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _loading = true; _users = []; });
        await Future.wait([_loadFriends(), _loadPendingRequests(), _loadUsers()]);
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 🔥 ПОИСК
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск пользователей...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: _clearSearch,
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),

          // 🔥 ЗАЯВКИ (только когда нет поиска)
          if (_searchQuery.isEmpty && _pendingRequests.isNotEmpty) ...[
            _sectionHeader('Заявки в друзья', Icons.person_add_rounded, Colors.orange, _pendingRequests.length),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _userTile(_pendingRequests[i], isPending: true),
                childCount: _pendingRequests.length,
              ),
            ),
          ],

          // 🔥 ДРУЗЬЯ (только когда нет поиска)
          if (_searchQuery.isEmpty && _friends.isNotEmpty) ...[
            _sectionHeader('Друзья', Icons.people_rounded, Colors.green, _friends.length),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _userTile(_friends[i], isFriend: true),
                childCount: _friends.length,
              ),
            ),
          ],

          // 🔥 ВСЕ ПОЛЬЗОВАТЕЛИ / РЕЗУЛЬТАТЫ ПОИСКА
          if (_searchQuery.isNotEmpty || _searchQuery.isEmpty) ...[
            _sectionHeader(
              _searchQuery.isNotEmpty ? 'Результаты поиска' : 'Все пользователи',
              Icons.person_rounded,
              _searchQuery.isNotEmpty ? Colors.blue : Colors.grey,
              _users.length,
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                  // Кнопка "Загрузить ещё"
                  if (i == _users.length && _hasMore && _searchQuery.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _loadingMore
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                          onPressed: _loadMoreUsers,
                          child: const Text('Загрузить ещё'),
                        ),
                      ),
                    );
                  }
                  if (i >= _users.length) return null;
                  return _userTile(_users[i]);
                },
                childCount: _users.length + (_hasMore && _searchQuery.isEmpty ? 1 : 0),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user, {bool isFriend = false, bool isPending = false}) {
    final userId = user['user_id'] ?? '';
    final name = user['name'] ?? '';
    final avatarUrl = user['avatar_url'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.orange.shade100,
          backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
          child: avatarUrl.isEmpty
              ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(),
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 20))
              : null,
        ),
        title: Text(name.isNotEmpty ? name : 'Пользователь', style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: () => _openProfile(userId),
        trailing: isPending
            ? FilledButton(
          onPressed: () => _acceptRequest(userId),
          style: FilledButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          child: const Text('Принять'),
        )
            : isFriend
            ? PopupMenuButton(
          itemBuilder: (ctx) => [
            PopupMenuItem(
              child: const Row(children: [Icon(Icons.chat_rounded, size: 20), SizedBox(width: 8), Text('Написать')]),
              onTap: () => _openChat(userId, name, avatarUrl),
            ),
            PopupMenuItem(
              child: const Row(children: [Icon(Icons.person_rounded, size: 20), SizedBox(width: 8), Text('Профиль')]),
              onTap: () => _openProfile(userId),
            ),
            PopupMenuItem(
              child: const Row(children: [Icon(Icons.person_remove_rounded, size: 20, color: Colors.red), SizedBox(width: 8), Text('Удалить', style: TextStyle(color: Colors.red))]),
              onTap: () => _removeFriend(userId),
            ),
          ],
        )
            : OutlinedButton(
          onPressed: () => _sendFriendRequest(userId),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          child: const Text('Добавить'),
        ),
      ),
    );
  }
}