import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/notification_service.dart';
import '../profile/public_profile_screen.dart';
import 'chat_screen.dart';

class UsersTab extends StatefulWidget {
  final Color accentColor;

  const UsersTab({
    super.key,
    required this.accentColor,
  });

  @override
  State<UsersTab> createState() =>
      _UsersTabState();
}

class _UsersTabState extends State<UsersTab>
    with AutomaticKeepAliveClientMixin {
  static const String _userApiUrl =
      'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';

  static const String _chatApiUrl =
      'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';

  static const int _pageSize = 15;

  final Set<String> _outgoingRequestIds =
  <String>{};

  int _searchGeneration = 0;

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

  final TextEditingController
  _searchController =
  TextEditingController();

  final ScrollController
  _scrollController =
  ScrollController();

  Timer? _searchDebounce;

  @override
  bool get wantKeepAlive => true;

  // --------------------------------------------------------------
  // Цвет
  // --------------------------------------------------------------

  Color get _accent =>
      widget.accentColor;

  Color get _accentSoft =>
      Color.lerp(
        _accent,
        Colors.white,
        0.22,
      ) ??
          _accent;

  // --------------------------------------------------------------
  // Жизненный цикл
  // --------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _onScroll,
    );

    _init();
  }

  @override
  void didUpdateWidget(
      covariant UsersTab oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.accentColor.value !=
        widget.accentColor.value) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // --------------------------------------------------------------
  // Цветовые помощники
  // --------------------------------------------------------------

  bool get _isDarkMode =>
      Theme.of(context).brightness ==
          Brightness.dark;

  Color get _backgroundColor =>
      _isDarkMode
          ? const Color(0xFF070A10)
          : const Color(0xFFF4F6F8);

  Color get _surfaceColor =>
      _isDarkMode
          ? const Color(0xFF10151D)
          : Colors.white;

  Color get _softSurfaceColor =>
      _isDarkMode
          ? Colors.white.withOpacity(0.045)
          : Colors.black.withOpacity(0.028);

  Color get _primaryText =>
      _isDarkMode
          ? Colors.white
          : const Color(0xFF15191F);

  Color get _secondaryText =>
      _isDarkMode
          ? const Color(0xFF8993A1)
          : const Color(0xFF7E8794);

  Color get _lineColor =>
      _isDarkMode
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.055);

  // --------------------------------------------------------------
  // Инициализация
  // --------------------------------------------------------------

  Future<void> _init() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      _currentUserId =
          prefs.getString('user_id');

      _currentUserName =
          prefs.getString('user_name') ??
              'Пользователь';

      await Future.wait([
        _loadFriends(),
        _loadPendingRequests(),
        _loadUsers(),
      ]);

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  // --------------------------------------------------------------
  // Скролл
  // --------------------------------------------------------------

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position =
        _scrollController.position;

    if (position.pixels >=
        position.maxScrollExtent - 220) {
      _loadMoreUsers();
    }
  }

  // --------------------------------------------------------------
  // Загрузка пользователей
  // --------------------------------------------------------------

  Future<void> _loadUsers({
    bool reset = true,
  }) async {
    if (_currentUserId == null ||
        _currentUserId!.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      return;
    }

    final requestGeneration =
    ++_searchGeneration;

    if (reset) {
      _offset = 0;
      _hasMore = true;
    }

    try {
      final response = await http
          .post(
        Uri.parse(_userApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action': 'list',
          'query': _searchQuery,
          'user_id': _currentUserId,
          'offset': _offset,
          'limit': _pageSize,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      final decoded =
      jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['ok'] != true) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }

        return;
      }

      final rawUsers =
      decoded['users'];

      if (rawUsers is! List) {
        if (mounted) {
          setState(() {
            _loading = false;
            _hasMore = false;
          });
        }

        return;
      }

      final newUsers = rawUsers
          .whereType<Map>()
          .map(
            (user) =>
        Map<String, dynamic>.from(
          user,
        ),
      )
          .toList();

      if (!mounted ||
          requestGeneration !=
              _searchGeneration) {
        return;
      }

      setState(() {
        if (reset) {
          _users = newUsers;
        } else {
          _users.addAll(newUsers);
        }

        _hasMore =
            newUsers.length >= _pageSize;

        _offset += newUsers.length;

        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_loadingMore ||
        !_hasMore ||
        _searchQuery.isNotEmpty ||
        _loading) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    await _loadUsers(
      reset: false,
    );

    if (!mounted) return;

    setState(() {
      _loadingMore = false;
    });
  }

  // --------------------------------------------------------------
  // Друзья
  // --------------------------------------------------------------

  Future<void> _loadFriends() async {
    if (_currentUserId == null) return;

    try {
      final response = await http
          .post(
        Uri.parse(_userApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action': 'friends',
          'user_id': _currentUserId,
        }),
      )
          .timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return;
      }

      final decoded =
      jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['ok'] != true ||
          decoded['friends'] is! List) {
        return;
      }

      final friends =
      (decoded['friends'] as List)
          .whereType<Map>()
          .map(
            (friend) =>
        Map<String, dynamic>.from(
          friend,
        ),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        _friends = friends;
      });
    } catch (_) {}
  }

  // --------------------------------------------------------------
  // Входящие заявки
  // --------------------------------------------------------------

  Future<void> _loadPendingRequests() async {
    if (_currentUserId == null) return;

    try {
      final response = await http
          .post(
        Uri.parse(_userApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action': 'pending-requests',
          'user_id': _currentUserId,
        }),
      )
          .timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return;
      }

      final decoded =
      jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['ok'] != true ||
          decoded['requests'] is! List) {
        return;
      }

      final requests =
      (decoded['requests'] as List)
          .whereType<Map>()
          .map(
            (request) =>
        Map<String, dynamic>.from(
          request,
        ),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        _pendingRequests = requests;
      });
    } catch (_) {}
  }

  // --------------------------------------------------------------
  // Действия
  // --------------------------------------------------------------

  bool _isFriend(String userId) {
    return _friends.any(
          (friend) =>
      friend['user_id']?.toString() ==
          userId,
    );
  }

  Future<void> _sendFriendRequest(
      String friendId,
      ) async {
    if (_currentUserId == null) return;

    try {
      final response = await http
          .post(
        Uri.parse(_userApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action':
          'send-friend-request',
          'user_id': _currentUserId,
          'friend_id': friendId,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception();
      }

      try {
        await NotificationService
            .sendNotification(
          targetUserId: friendId,
          type: 'friend_request',
          data: {
            'user_id': _currentUserId,
            'user_name':
            _currentUserName ??
                'Пользователь',
          },
        );
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _outgoingRequestIds
            .add(friendId);
      });

      _showSnackBar(
        'Заявка отправлена',
        icon:
        Icons.person_add_alt_1_rounded,
      );
    } catch (_) {
      if (!mounted) return;

      _showSnackBar(
        'Не удалось отправить заявку',
        isError: true,
      );
    }
  }

  Future<void> _removeFriend(
      String friendId,
      ) async {
    final confirmed =
    await _showRemoveFriendDialog();

    if (!confirmed ||
        _currentUserId == null) {
      return;
    }

    try {
      final response = await http
          .post(
        Uri.parse(_userApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action': 'remove-friend',
          'user_id': _currentUserId,
          'friend_id': friendId,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception();
      }

      if (!mounted) return;

      setState(() {
        _friends.removeWhere(
              (friend) =>
          friend['user_id']
              ?.toString() ==
              friendId,
        );
      });

      _showSnackBar(
        'Пользователь удалён из друзей',
      );
    } catch (_) {
      if (!mounted) return;

      _showSnackBar(
        'Не удалось удалить пользователя',
        isError: true,
      );
    }
  }

  Future<bool>
  _showRemoveFriendDialog() async {
    final result =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dark =
            Theme.of(dialogContext)
                .brightness ==
                Brightness.dark;

        final background =
        dark
            ? const Color(0xFF11151D)
            : Colors.white;

        final text =
        dark
            ? Colors.white
            : const Color(0xFF15191F);

        final secondary =
        dark
            ? const Color(0xFF8993A1)
            : const Color(0xFF7E8794);

        return AlertDialog(
          backgroundColor:
          background,
          surfaceTintColor:
          Colors.transparent,
          elevation: 18,
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(26),
          ),
          title: Text(
            'Удалить из друзей?',
            style: TextStyle(
              color: text,
              fontSize: 19,
              fontWeight:
              FontWeight.w700,
            ),
          ),
          content: Text(
            'Пользователь будет удалён из списка друзей.',
            style: TextStyle(
              color: secondary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          actionsPadding:
          const EdgeInsets.fromLTRB(
            18,
            0,
            18,
            16,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(
                    dialogContext,
                  ).pop(false),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color: secondary,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: () =>
                  Navigator.of(
                    dialogContext,
                  ).pop(true),
              style:
              TextButton.styleFrom(
                foregroundColor:
                Colors.redAccent,
              ),
              child: const Text(
                'Удалить',
                style: TextStyle(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _acceptRequest(
      String friendId,
      ) async {
    if (_currentUserId == null) return;

    try {
      final response = await http
          .post(
        Uri.parse(_userApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action':
          'accept-friend',
          'user_id': _currentUserId,
          'friend_id': friendId,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception();
      }

      try {
        await NotificationService
            .sendNotification(
          targetUserId: friendId,
          type: 'friend_accepted',
          data: {
            'user_id': _currentUserId,
            'user_name':
            _currentUserName ??
                'Пользователь',
          },
        );
      } catch (_) {}

      if (!mounted) return;

      final acceptedRequest =
      _pendingRequests
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (request) =>
        request['user_id']
            ?.toString() ==
            friendId,
        orElse: () =>
        <String, dynamic>{},
      );

      setState(() {
        _pendingRequests.removeWhere(
              (request) =>
          request['user_id']
              ?.toString() ==
              friendId,
        );

        _outgoingRequestIds
            .remove(friendId);

        if (acceptedRequest.isNotEmpty &&
            !_friends.any(
                  (friend) =>
              friend['user_id']
                  ?.toString() ==
                  friendId,
            )) {
          _friends.add(
            Map<String, dynamic>.from(
              acceptedRequest,
            ),
          );
        }

        for (final user in _users) {
          if (user['user_id']
              ?.toString() ==
              friendId) {
            user['is_friend'] = true;
          }
        }
      });

      _showSnackBar(
        'Теперь вы друзья',
        icon:
        Icons.people_alt_rounded,
      );
    } catch (_) {
      if (!mounted) return;

      _showSnackBar(
        'Не удалось принять заявку',
        isError: true,
      );
    }
  }

  // --------------------------------------------------------------
  // Чат
  // --------------------------------------------------------------

  Future<void> _openChat(
      String otherUserId,
      String otherName,
      String otherAvatar,
      ) async {
    if (_currentUserId == null) return;

    try {
      final response = await http
          .post(
        Uri.parse(_chatApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action':
          'get-or-create-chat',
          'user1_id':
          _currentUserId,
          'user2_id':
          otherUserId,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception();
      }

      final decoded =
      jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['ok'] != true ||
          decoded['chat_id'] == null) {
        if (!mounted) return;

        _showSnackBar(
          decoded is Map
              ? decoded['errorMessage']
              ?.toString() ??
              'Не удалось создать чат'
              : 'Не удалось создать чат',
          isError: true,
        );

        return;
      }

      final chatId =
      decoded['chat_id'].toString();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId:
            otherUserId,
            otherName:
            otherName,
            otherAvatar:
            otherAvatar,
          ),
        ),
      );

      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;

      _showSnackBar(
        'Ошибка соединения',
        isError: true,
      );
    }
  }

  // --------------------------------------------------------------
  // Профиль
  // --------------------------------------------------------------

  void _openProfile(
      String userId,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PublicProfileScreen(
              userId: userId,
            ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Поиск
  // --------------------------------------------------------------

  void _onSearchChanged(
      String query,
      ) {
    _searchDebounce?.cancel();

    _searchDebounce =
        Timer(
          const Duration(
            milliseconds: 450,
          ),
              () {
            if (!mounted) return;

            final normalized =
            _searchController.text
                .trim();

            if (normalized ==
                _searchQuery) {
              return;
            }

            setState(() {
              _searchQuery = normalized;
            });

            _loadUsers();
          },
        );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();

    _searchController.clear();

    if (!mounted) return;

    setState(() {
      _searchQuery = '';
    });

    _loadUsers();
  }

  // --------------------------------------------------------------
  // Обновление
  // --------------------------------------------------------------

  Future<void> _refresh() async {
    if (!mounted) return;

    await Future.wait([
      _loadFriends(),
      _loadPendingRequests(),
      _loadUsers(),
    ]);
  }

  // --------------------------------------------------------------
  // SnackBar
  // --------------------------------------------------------------

  void _showSnackBar(
      String message, {
        bool isError = false,
        IconData? icon,
      }) {
    if (!mounted) return;

    final messenger =
    ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                icon ??
                    (isError
                        ? Icons
                        .error_outline_rounded
                        : Icons
                        .check_circle_outline_rounded),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style:
                  const TextStyle(
                    color: Colors.white,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor:
          isError
              ? const Color(
            0xFFD94B4B,
          )
              : const Color(
            0xFF202731,
          ),
          behavior:
          SnackBarBehavior.floating,
          margin:
          const EdgeInsets.fromLTRB(
            14,
            0,
            14,
            18,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              17,
            ),
          ),
          elevation: 8,
        ),
      );
  }

  // --------------------------------------------------------------
  // Построение UI
  // --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ColoredBox(
      color: _backgroundColor,
      child:
      _loading
          ? _buildLoading()
          : RefreshIndicator(
        color: _accent,
        backgroundColor:
        _surfaceColor,
        displacement: 25,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller:
          _scrollController,
          physics:
          const BouncingScrollPhysics(
            parent:
            AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: false,
              snap: false,
              automaticallyImplyLeading:
              false,
              leading:
              const SizedBox.shrink(),
              expandedHeight: 92,
              backgroundColor:
              Colors.transparent,
              elevation: 0,
              flexibleSpace:
              FlexibleSpaceBar(
                background:
                _buildAppBarBackground(),
                title:
                _buildAppBarTitle(),
                titlePadding:
                const EdgeInsets
                    .fromLTRB(
                  16,
                  4,
                  16,
                  8,
                ),
                centerTitle: false,
              ),
            ),

            SliverToBoxAdapter(
              child:
              _buildSearchField(),
            ),

            if (_searchQuery.isEmpty &&
                _pendingRequests
                    .isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Заявки',
                count:
                _pendingRequests
                    .length,
                icon: Icons
                    .person_add_alt_1_rounded,
                color: _accent,
              ),
              _buildUsersList(
                _pendingRequests,
                isPending: true,
              ),
            ],

            if (_searchQuery.isEmpty &&
                _friends.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Друзья',
                count:
                _friends.length,
                icon: Icons
                    .people_alt_rounded,
                color:
                const Color(
                  0xFF32C98B,
                ),
              ),
              _buildUsersList(
                _friends,
                isFriend: true,
              ),
            ],

            _buildSectionHeader(
              title:
              _searchQuery
                  .isNotEmpty
                  ? 'Результаты'
                  : 'Пользователи',
              count:
              _users.length,
              icon:
              _searchQuery
                  .isNotEmpty
                  ? Icons
                  .search_rounded
                  : Icons
                  .explore_rounded,
              color:
              _searchQuery
                  .isNotEmpty
                  ? _accent
                  : const Color(
                0xFF5E8FFF,
              ),
            ),

            if (_users.isEmpty)
              SliverToBoxAdapter(
                child:
                _buildEmptyUsers(),
              )
            else
              _buildUsersList(
                _users,
                hasMore:
                _hasMore &&
                    _searchQuery
                        .isEmpty,
              ),

            SliverToBoxAdapter(
              child: SizedBox(
                height:
                MediaQuery.of(
                  context,
                )
                    .padding
                    .bottom +
                    45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // AppBar
  // --------------------------------------------------------------

  Widget _buildAppBarBackground() {
    return ClipRRect(
      borderRadius:
      const BorderRadius.only(
        bottomLeft:
        Radius.circular(28),
        bottomRight:
        Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
        ),
        child: Container(
          decoration: BoxDecoration(
            color:
            _surfaceColor.withOpacity(
              0.76,
            ),
            border: Border(
              bottom: BorderSide(
                color:
                _primaryText
                    .withOpacity(
                  0.018,
                ),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Text(
            'Люди',
            style: TextStyle(
              color: _primaryText,
              fontSize: 28,
              fontWeight:
              FontWeight.w800,
              letterSpacing: -0.8,
              decoration:
              TextDecoration.none,
            ),
          ),
          const Spacer(),
          if (_friends.isNotEmpty)
            Container(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 11,
                vertical: 8,
              ),
              decoration:
              BoxDecoration(
                color:
                _softSurfaceColor,
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color: _lineColor,
                  width: 0.7,
                ),
              ),
              child: Row(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .people_alt_rounded,
                    size: 16,
                    color: _accent,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    '${_friends.length}',
                    style: TextStyle(
                      color:
                      _primaryText,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w700,
                      decoration:
                      TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // Поиск
  // --------------------------------------------------------------

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8,
      ),
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 220,
        ),
        curve: Curves.easeOutCubic,
        height: 46,
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF0F141C)
              : Colors.white,
          borderRadius: BorderRadius.circular(
            16,
          ),
          boxShadow: [
            if (!_isDarkMode)
              BoxShadow(
                color: Colors.black.withOpacity(
                  0.035,
                ),
                blurRadius: 20,
                offset: const Offset(
                  0,
                  7,
                ),
                spreadRadius: -7,
              ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: TextStyle(
            color: _primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: _accent,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Поиск',
            hintStyle: TextStyle(
              color: _secondaryText.withOpacity(
                0.82,
              ),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: AnimatedContainer(
              duration: const Duration(
                milliseconds: 220,
              ),
              width: 50,
              child: Center(
                child: Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: _accent,
                ),
              ),
            ),
            suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
              onPressed:
              _clearSearch,
              splashRadius: 18,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color:
                _secondaryText,
              ),
            )
                : null,
            filled: true,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            disabledBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding:
            const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 11,
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Заголовок секции
  // --------------------------------------------------------------

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding:
        const EdgeInsets.fromLTRB(
          16,
          23,
          16,
          11,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration:
              BoxDecoration(
                color:
                color.withOpacity(
                  0.10,
                ),
                borderRadius:
                BorderRadius.circular(
                  15,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 17,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Text(
              title,
              style: TextStyle(
                color: _primaryText,
                fontSize: 17,
                fontWeight:
                FontWeight.w700,
                letterSpacing: -0.3,
                decoration:
                TextDecoration.none,
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Container(
              constraints:
              const BoxConstraints(
                minWidth: 22,
              ),
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 7,
                vertical: 4,
              ),
              decoration:
              BoxDecoration(
                color:
                color.withOpacity(
                  0.10,
                ),
                borderRadius:
                BorderRadius.circular(
                  9,
                ),
              ),
              alignment:
              Alignment.center,
              child: Text(
                count > 99
                    ? '99+'
                    : '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight:
                  FontWeight.w800,
                  decoration:
                  TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Список пользователей
  // --------------------------------------------------------------

  Widget _buildUsersList(
      List<Map<String, dynamic>> users, {
        bool isFriend = false,
        bool isPending = false,
        bool hasMore = false,
      }) {
    return SliverPadding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      sliver: SliverList(
        delegate:
        SliverChildBuilderDelegate(
              (context, index) {
            if (hasMore &&
                index == users.length) {
              return _buildLoadMore();
            }

            if (index >=
                users.length) {
              return null;
            }

            return _buildUserTile(
              users[index],
              isFriend: isFriend,
              isPending: isPending,
            );
          },
          childCount:
          users.length +
              (hasMore ? 1 : 0),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Загрузка ещё
  // --------------------------------------------------------------

  Widget _buildLoadMore() {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 18,
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration:
          const Duration(
            milliseconds: 180,
          ),
          child:
          _loadingMore
              ? SizedBox(
            key:
            const ValueKey(
              'loading',
            ),
            width: 24,
            height: 24,
            child:
            CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _accent,
            ),
          )
              : TextButton.icon(
            key:
            const ValueKey(
              'button',
            ),
            onPressed:
            _loadMoreUsers,
            icon: Icon(
              Icons
                  .expand_more_rounded,
              color:
              _accent,
              size: 20,
            ),
            label: Text(
              'Показать ещё',
              style:
              TextStyle(
                color:
                _accent,
                fontSize:
                13,
                fontWeight:
                FontWeight.w700,
                decoration:
                TextDecoration
                    .none,
              ),
            ),
            style:
            TextButton
                .styleFrom(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              backgroundColor:
              _accent
                  .withOpacity(
                0.07,
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius
                    .circular(
                  14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Карточка пользователя
  // --------------------------------------------------------------

  Widget _buildUserTile(
      Map<String, dynamic> user, {
        bool isFriend = false,
        bool isPending = false,
      }) {
    final userId =
        user['user_id']
            ?.toString() ??
            '';

    final name =
        user['name']
            ?.toString()
            .trim() ??
            '';

    final avatarUrl =
        user['avatar_url']
            ?.toString()
            .trim() ??
            '';

    final city =
        user['city']
            ?.toString()
            .trim() ??
            '';

    final displayName =
    name.isEmpty
        ? 'Пользователь'
        : name;

    final isOnline =
        user['is_online'] == true;

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 8,
      ),
      child: Material(
        color: _surfaceColor,
        borderRadius:
        BorderRadius.circular(21),
        child: InkWell(
          onTap:
          userId.isEmpty
              ? null
              : () =>
              _openProfile(
                userId,
              ),
          borderRadius:
          BorderRadius.circular(
            21,
          ),
          splashColor:
          _accent.withOpacity(
            0.045,
          ),
          highlightColor:
          _accent.withOpacity(
            0.02,
          ),
          child: Container(
            padding:
            const EdgeInsets.fromLTRB(
              11,
              11,
              11,
              11,
            ),
            decoration:
            BoxDecoration(
              borderRadius:
              BorderRadius.circular(
                21,
              ),
              border:
              Border.all(
                color: _lineColor,
                width: 0.7,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                  Colors.black
                      .withOpacity(
                    0.02,
                  ),
                  blurRadius: 6,
                  offset:
                  const Offset(
                    0,
                    2,
                  ),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    _buildAvatar(
                      name:
                      displayName,
                      avatarUrl:
                      avatarUrl,
                      isPending:
                      isPending,
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration:
                          BoxDecoration(
                            color: Colors
                                .greenAccent,
                            shape:
                            BoxShape.circle,
                            border:
                            Border.all(
                              color:
                              _surfaceColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                  _buildUserInfo(
                    name:
                    displayName,
                    city: city,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                _buildUserAction(
                  userId: userId,
                  name: displayName,
                  avatarUrl:
                  avatarUrl,
                  isFriend: isFriend,
                  isPending:
                  isPending,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Аватар
  // --------------------------------------------------------------

  Widget _buildAvatar({
    required String name,
    required String avatarUrl,
    required bool isPending,
  }) {
    final firstLetter =
    name.trim().isNotEmpty
        ? name
        .trim()[0]
        .toUpperCase()
        : '?';

    return Container(
      width: 56,
      height: 56,
      padding:
      const EdgeInsets.all(2),
      decoration:
      BoxDecoration(
        shape: BoxShape.circle,
        gradient:
        LinearGradient(
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
          colors: [
            _accentSoft,
            _accent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
            _accent.withOpacity(
              isPending
                  ? 0.18
                  : 0.10,
            ),
            blurRadius: 12,
            offset:
            const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child:
        avatarUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl:
          avatarUrl,
          fit:
          BoxFit.cover,
          fadeInDuration:
          const Duration(
            milliseconds:
            180,
          ),
          placeholder:
              (
              context,
              url,
              ) =>
              _avatarFallback(
                firstLetter,
              ),
          errorWidget:
              (
              context,
              url,
              error,
              ) =>
              _avatarFallback(
                firstLetter,
              ),
        )
            : _avatarFallback(
          firstLetter,
        ),
      ),
    );
  }

  Widget _avatarFallback(
      String firstLetter,
      ) {
    return Container(
      decoration:
      BoxDecoration(
        color:
        _isDarkMode
            ? const Color(
          0xFF181E27,
        )
            : const Color(
          0xFFF0F2F5,
        ),
      ),
      alignment:
      Alignment.center,
      child: Text(
        firstLetter,
        style: TextStyle(
          color: _accent,
          fontSize: 19,
          fontWeight:
          FontWeight.w800,
          decoration:
          TextDecoration.none,
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Информация пользователя
  // --------------------------------------------------------------

  Widget _buildUserInfo({
    required String name,
    required String city,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
          style: TextStyle(
            color: _primaryText,
            fontSize: 15.5,
            fontWeight:
            FontWeight.w700,
            letterSpacing: -0.2,
            decoration:
            TextDecoration.none,
          ),
        ),
        if (city.isNotEmpty) ...[
          const SizedBox(
            height: 5,
          ),
          Row(
            children: [
              Icon(
                Icons
                    .location_on_rounded,
                color: _secondaryText,
                size: 14,
              ),
              const SizedBox(
                width: 4,
              ),
              Expanded(
                child: Text(
                  city,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                    _secondaryText,
                    fontSize: 12.5,
                    fontWeight:
                    FontWeight.w500,
                    decoration:
                    TextDecoration
                        .none,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(
            height: 5,
          ),
          Text(
            'Пользователь',
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              color:
              _secondaryText,
              fontSize: 12.5,
              fontWeight:
              FontWeight.w500,
              decoration:
              TextDecoration.none,
            ),
          ),
        ],
      ],
    );
  }

  // --------------------------------------------------------------
  // Кнопки действий
  // --------------------------------------------------------------

  Widget _buildUserAction({
    required String userId,
    required String name,
    required String avatarUrl,
    required bool isFriend,
    required bool isPending,
  }) {
    if (isPending) {
      return _buildPrimaryButton(
        label: 'Принять',
        icon: Icons.check_rounded,
        onTap: () =>
            _acceptRequest(
              userId,
            ),
      );
    }

    if (_outgoingRequestIds
        .contains(userId)) {
      return _buildIconButton(
        icon: Icons.schedule_rounded,
        color: _secondaryText,
        onTap: () {},
      );
    }

    if (isFriend) {
      return Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          _buildIconButton(
            icon: Icons
                .chat_bubble_rounded,
            color: _accent,
            onTap: () =>
                _openChat(
                  userId,
                  name,
                  avatarUrl,
                ),
          ),
          const SizedBox(
            width: 7,
          ),
          _buildIconButton(
            icon:
            Icons.more_horiz_rounded,
            color:
            _secondaryText,
            onTap: () =>
                _showFriendOptions(
                  userId,
                  name,
                  avatarUrl,
                ),
          ),
        ],
      );
    }

    return _buildIconButton(
      icon:
      Icons.person_add_alt_1_rounded,
      color: _accent,
      onTap: () =>
          _sendFriendRequest(
            userId,
          ),
    );
  }

  // --------------------------------------------------------------
  // Основная кнопка
  // --------------------------------------------------------------

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(14),
        child: Ink(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 9,
          ),
          decoration:
          BoxDecoration(
            gradient:
            LinearGradient(
              begin:
              Alignment.topLeft,
              end:
              Alignment.bottomRight,
              colors: [
                _accentSoft,
                _accent,
              ],
            ),
            borderRadius:
            BorderRadius.circular(
              14,
            ),
            boxShadow: [
              BoxShadow(
                color:
                _accent.withOpacity(
                  0.16,
                ),
                blurRadius: 10,
                offset:
                const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(
                width: 5,
              ),
              Text(
                label,
                style:
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight:
                  FontWeight.w700,
                  decoration:
                  TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Маленькая кнопка
  // --------------------------------------------------------------

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(14),
        child: Ink(
          width: 40,
          height: 40,
          decoration:
          BoxDecoration(
            color:
            color.withOpacity(
              0.075,
            ),
            borderRadius:
            BorderRadius.circular(
              14,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Пустой список
  // --------------------------------------------------------------

  Widget _buildEmptyUsers() {
    final searching =
        _searchQuery.isNotEmpty;

    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        30,
      ),
      child: Container(
        width: double.infinity,
        padding:
        const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 30,
        ),
        decoration:
        BoxDecoration(
          color: _surfaceColor,
          borderRadius:
          BorderRadius.circular(
            22,
          ),
          border:
          Border.all(
            color: _lineColor,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration:
              BoxDecoration(
                color:
                _accent.withOpacity(
                  0.09,
                ),
                shape:
                BoxShape.circle,
              ),
              child: Icon(
                searching
                    ? Icons
                    .search_off_rounded
                    : Icons
                    .people_outline_rounded,
                color: _accent,
                size: 29,
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            Text(
              searching
                  ? 'Ничего не найдено'
                  : 'Пользователей пока нет',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: _primaryText,
                fontSize: 16,
                fontWeight:
                FontWeight.w700,
                decoration:
                TextDecoration.none,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              searching
                  ? 'Попробуй изменить запрос'
                  : 'Здесь появятся новые пользователи',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                _secondaryText,
                fontSize: 13,
                height: 1.35,
                decoration:
                TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Загрузка
  // --------------------------------------------------------------

  Widget _buildLoading() {
    return ColoredBox(
      color: _backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration:
              BoxDecoration(
                gradient:
                LinearGradient(
                  begin:
                  Alignment.topLeft,
                  end:
                  Alignment.bottomRight,
                  colors: [
                    _accentSoft,
                    _accent,
                  ],
                ),
                borderRadius:
                BorderRadius.circular(
                  19,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    _accent
                        .withOpacity(
                      0.22,
                    ),
                    blurRadius: 20,
                    offset:
                    const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
            const SizedBox(
              height: 17,
            ),
            Text(
              'Загружаем пользователей',
              style: TextStyle(
                color: _primaryText,
                fontSize: 15,
                fontWeight:
                FontWeight.w600,
                decoration:
                TextDecoration.none,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            SizedBox(
              width: 90,
              height: 3,
              child: ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  5,
                ),
                child:
                LinearProgressIndicator(
                  backgroundColor:
                  _accent.withOpacity(
                    0.08,
                  ),
                  valueColor:
                  AlwaysStoppedAnimation<
                      Color>(
                    _accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Нижнее меню друга
  // --------------------------------------------------------------

  void _showFriendOptions(
      String userId,
      String name,
      String avatarUrl,
      ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
      Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        final dark =
            Theme.of(
              sheetContext,
            ).brightness ==
                Brightness.dark;

        final surface =
        dark
            ? const Color(
          0xFF11151D,
        )
            : Colors.white;

        final text =
        dark
            ? Colors.white
            : const Color(
          0xFF15191F,
        );

        final secondary =
        dark
            ? const Color(
          0xFF8993A1,
        )
            : const Color(
          0xFF7E8794,
        );

        return SafeArea(
          top: false,
          child: Container(
            margin:
            const EdgeInsets
                .fromLTRB(
              10,
              0,
              10,
              10,
            ),
            padding:
            const EdgeInsets
                .fromLTRB(
              18,
              11,
              18,
              18,
            ),
            decoration:
            BoxDecoration(
              color: surface,
              borderRadius:
              BorderRadius.circular(
                27,
              ),
              border:
              Border.all(
                color:
                dark
                    ? Colors
                    .white
                    .withOpacity(
                  0.06,
                )
                    : Colors
                    .black
                    .withOpacity(
                  0.05,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                  Colors.black
                      .withOpacity(
                    0.18,
                  ),
                  blurRadius: 30,
                  offset:
                  const Offset(
                    0,
                    -5,
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration:
                  BoxDecoration(
                    color:
                    secondary
                        .withOpacity(
                      0.35,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      5,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                Row(
                  children: [
                    _buildSmallSheetAvatar(
                      name,
                      avatarUrl,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            TextStyle(
                              color: text,
                              fontSize: 16,
                              fontWeight:
                              FontWeight
                                  .w700,
                              decoration:
                              TextDecoration
                                  .none,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            'Ваш друг',
                            style:
                            TextStyle(
                              color:
                              secondary,
                              fontSize: 12,
                              decoration:
                              TextDecoration
                                  .none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 17,
                ),
                _sheetAction(
                  context: sheetContext,
                  icon: Icons
                      .chat_bubble_rounded,
                  title: 'Написать',
                  color: _accent,
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    _openChat(
                      userId,
                      name,
                      avatarUrl,
                    );
                  },
                ),
                _sheetAction(
                  context: sheetContext,
                  icon:
                  Icons.person_rounded,
                  title:
                  'Открыть профиль',
                  color: secondary,
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    _openProfile(
                      userId,
                    );
                  },
                ),
                const SizedBox(
                  height: 4,
                ),
                Divider(
                  color:
                  dark
                      ? Colors
                      .white
                      .withOpacity(
                    0.06,
                  )
                      : Colors
                      .black
                      .withOpacity(
                    0.06,
                  ),
                  height: 1,
                ),
                const SizedBox(
                  height: 4,
                ),
                _sheetAction(
                  context: sheetContext,
                  icon: Icons
                      .person_remove_rounded,
                  title:
                  'Удалить из друзей',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    _removeFriend(
                      userId,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------
  // Маленький аватар
  // --------------------------------------------------------------

  Widget _buildSmallSheetAvatar(
      String name,
      String avatarUrl,
      ) {
    final letter =
    name.trim().isNotEmpty
        ? name
        .trim()[0]
        .toUpperCase()
        : '?';

    return Container(
      width: 48,
      height: 48,
      padding:
      const EdgeInsets.all(2),
      decoration:
      BoxDecoration(
        shape: BoxShape.circle,
        gradient:
        LinearGradient(
          colors: [
            _accentSoft,
            _accent,
          ],
        ),
      ),
      child: ClipOval(
        child:
        avatarUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl:
          avatarUrl,
          fit:
          BoxFit.cover,
          errorWidget:
              (
              context,
              url,
              error,
              ) =>
              _smallAvatarFallback(
                letter,
              ),
        )
            : _smallAvatarFallback(
          letter,
        ),
      ),
    );
  }

  Widget _smallAvatarFallback(
      String letter,
      ) {
    return Container(
      color:
      _isDarkMode
          ? const Color(0xFF181E27)
          : const Color(0xFFF0F2F5),
      alignment:
      Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: _accent,
          fontSize: 17,
          fontWeight:
          FontWeight.w800,
          decoration:
          TextDecoration.none,
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Bottom sheet action
  // --------------------------------------------------------------

  Widget _sheetAction({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(16),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            vertical: 7,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                BoxDecoration(
                  color:
                  color.withOpacity(
                    0.09,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color:
                    color ==
                        Colors
                            .redAccent
                        ? Colors
                        .redAccent
                        : _primaryText,
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w600,
                    decoration:
                    TextDecoration.none,
                  ),
                ),
              ),
              Icon(
                Icons
                    .chevron_right_rounded,
                color:
                _secondaryText
                    .withOpacity(
                  0.65,
                ),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}