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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        _hasMore) {
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
        setState(() =>
        _pendingRequests = (data['requests'] as List).cast<Map<String, dynamic>>());
      }
    } catch (e) {}
  }

  bool _isFriend(String userId) => _friends.any((f) => f['user_id'] == userId);

  Future<void> _sendFriendRequest(String friendId) async {
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {"action": "send-friend-request", "user_id": _currentUserId, "friend_id": friendId}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Заявка отправлена')));
      }
    } catch (e) {}
  }

  Future<void> _removeFriend(String friendId) async {
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {"action": "remove-friend", "user_id": _currentUserId, "friend_id": friendId}),
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
        body: jsonEncode(
            {"action": "accept-friend", "user_id": _currentUserId, "friend_id": friendId}),
      );
      _loadFriends();
      _loadPendingRequests();
      if (mounted) setState(() {});
    } catch (e) {}
  }

  void _openChat(String otherUserId, String otherName, String otherAvatar) async {
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
              otherAvatar: otherAvatar,
            ),
          ),
        );
      }
    } catch (e) {}
  }

  void _openProfile(String userId) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)));
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
    final colorScheme = Theme.of(context).colorScheme;

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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          if (_pendingRequests.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Заявки в друзья (${_pendingRequests.length})',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontSize: 16),
                ),
              ),
            ),
          if (_pendingRequests.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _UserCard(
                  user: _pendingRequests[i],
                  isPending: true,
                  onAccept: _acceptRequest,
                  onOpenProfile: _openProfile,
                  onOpenChat: (id, name, avatar) => _openChat(id, name, avatar),
                ),
                childCount: _pendingRequests.length,
              ),
            ),
          if (_friends.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Друзья (${_friends.length})',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontSize: 16)),
              ),
            ),
          if (_friends.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _UserCard(
                  user: _friends[i],
                  isFriend: true,
                  onRemoveFriend: _removeFriend,
                  onOpenProfile: _openProfile,
                  onOpenChat: (id, name, avatar) => _openChat(id, name, avatar),
                ),
                childCount: _friends.length,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Все пользователи',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onSurface)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _UserCard(
                user: _users[i],
                isFriend: _isFriend(_users[i]['user_id'] ?? ''),
                onSendRequest: _sendFriendRequest,
                onOpenProfile: _openProfile,
                onOpenChat: (id, name, avatar) => _openChat(id, name, avatar),
              ),
              childCount: _users.length,
            ),
          ),
          if (_hasMore)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isFriend;
  final bool isPending;
  final Function(String)? onAccept;
  final Function(String)? onRemoveFriend;
  final Function(String)? onSendRequest;
  final Function(String) onOpenProfile;
  final Function(String, String, String) onOpenChat;

  const _UserCard({
    required this.user,
    this.isFriend = false,
    this.isPending = false,
    this.onAccept,
    this.onRemoveFriend,
    this.onSendRequest,
    required this.onOpenProfile,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = user['user_id'] ?? '';
    final name = user['name'] ?? 'Пользователь';
    final avatarUrl = user['avatar_url'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onOpenProfile(userId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  backgroundColor: avatarUrl.isEmpty
                      ? colorScheme.primaryContainer
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(name[0].toUpperCase(),
                      style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                if (isPending)
                  ElevatedButton.icon(
                    onPressed: () => onAccept?.call(userId),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Принять'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else if (isFriend)
                  PopupMenuButton(
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                          child: const Text('Написать'),
                          onTap: () => onOpenChat(userId, name, avatarUrl)),
                      PopupMenuItem(
                          child: const Text('Профиль'),
                          onTap: () => onOpenProfile(userId)),
                      PopupMenuItem(
                          child: const Text('Удалить из друзей',
                              style: TextStyle(color: Colors.red)),
                          onTap: () => onRemoveFriend?.call(userId)),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: () => onSendRequest?.call(userId),
                    child: const Text('Добавить'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}