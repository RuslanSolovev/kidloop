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
  String _searchQuery = '';
  String? _currentUserId;
  int _offset = 0;
  bool _hasMore = true;
  int _retryCount = 0;
  final ScrollController _scrollController = ScrollController();

  static const String userApiUrl = 'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';
  static const String personalChatApiUrl = 'https://functions.yandexcloud.net/d4es79s8locoa8ul3pe3';

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
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && _hasMore) {
      _loadUsers();
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    await Future.wait([_loadUsers(), _loadFriends(), _loadPendingRequests()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadUsers() async {
    try {
      final response = await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "search",
          "query": _searchQuery,
          "user_id": _currentUserId,
          "offset": _offset,
          "limit": 20,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        final newUsers = (data['users'] as List).cast<Map<String, dynamic>>();
        setState(() {
          if (_offset == 0) _users = newUsers;
          else _users.addAll(newUsers);
          _hasMore = newUsers.length >= 20;
          _offset += newUsers.length;
          _retryCount = 0;
        });
      } else {
        _retryLoadUsers();
      }
    } catch (e) {
      _retryLoadUsers();
    }
  }

  void _retryLoadUsers() {
    _retryCount++;
    if (_retryCount <= 3 && mounted) {
      Future.delayed(const Duration(seconds: 2), _loadUsers);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заявка отправлена')));
      }
    } catch (e) {}
  }

  Future<void> _removeFriend(String friendId) async {
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "remove-friend", "user_id": _currentUserId, "friend_id": friendId}),
      );
      _loadFriends();
      if (mounted) setState(() {});
    } catch (e) {}
  }

  Future<void> _acceptRequest(String friendId) async {
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "accept-friend", "user_id": _currentUserId, "friend_id": friendId}),
      );
      _loadFriends();
      _loadPendingRequests();
      if (mounted) setState(() {});
    } catch (e) {}
  }

  void _openChat(String otherUserId, String otherName) async {
    try {
      final response = await http.post(
        Uri.parse(personalChatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "get-or-create-chat",
          "user1_id": _currentUserId,
          "user2_id": otherUserId,
        }),
      ).timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: data['chat_id'] ?? '',
              otherUserId: otherUserId,
              otherName: otherName,
            ),
          ),
        );
      }
    } catch (e) {}
  }

  void _openProfile(String userId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)));
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _offset = 0;
      _users = [];
      _hasMore = true;
      _retryCount = 0;
    });
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () async {
        _offset = 0;
        _users = [];
        _hasMore = true;
        _retryCount = 0;
        await _init();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Поиск пользователей...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),

          if (_pendingRequests.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('Заявки в друзья (${_pendingRequests.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ),
            ),
          if (_pendingRequests.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _userTile(_pendingRequests[i], isPending: true),
                childCount: _pendingRequests.length,
              ),
            ),

          if (_friends.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('Друзья (${_friends.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            ),
          if (_friends.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _userTile(_friends[i], isFriend: true),
                childCount: _friends.length,
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text('Все пользователи', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _userTile(_users[i]),
              childCount: _users.length,
            ),
          ),

          if (_hasMore)
            const SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )),
            ),
        ],
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user, {bool isFriend = false, bool isPending = false}) {
    final userId = user['user_id'] ?? '';
    final name = user['name'] ?? '';
    final avatarUrl = user['avatar_url'] ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
        child: avatarUrl.isEmpty ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase()) : null,
      ),
      title: Text(name.isNotEmpty ? name : 'Пользователь'),
      onTap: () => _openProfile(userId),
      trailing: isPending
          ? TextButton(onPressed: () => _acceptRequest(userId), child: const Text('Принять'))
          : isFriend
          ? PopupMenuButton(
        itemBuilder: (ctx) => [
          PopupMenuItem(child: const Text('Написать'), onTap: () => _openChat(userId, name)),
          PopupMenuItem(child: const Text('Профиль'), onTap: () => _openProfile(userId)),
          PopupMenuItem(child: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () => _removeFriend(userId)),
        ],
      )
          : _isFriend(userId)
          ? null
          : ElevatedButton(onPressed: () => _sendFriendRequest(userId), child: const Text('Добавить')),
    );
  }
}