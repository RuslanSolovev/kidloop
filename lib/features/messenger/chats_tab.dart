import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_screen.dart';

class ChatsTab extends StatefulWidget {
  final Color accentColor;

  const ChatsTab({
    super.key,
    required this.accentColor,
  });

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _chats = [];

  bool _loading = true;
  String? _currentUserId;

  Timer? _refreshTimer;

  int _retryCount = 0;
  String? _loadError;

  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  static const String chatApiUrl =
      'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';

  static const String _cacheKey = 'chats_cache';

  bool get _isDarkMode =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _accent => widget.accentColor;

  Color get _backgroundColor {
    return _isDarkMode
        ? const Color(0xFF070A10)
        : const Color(0xFFF5F6F8);
  }

  Color get _textColor {
    return _isDarkMode
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF161A20);
  }

  Color get _secondaryTextColor {
    return _isDarkMode
        ? const Color(0xFF858F9D)
        : const Color(0xFF858D98);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _searchController.addListener(_onSearchChanged);

    _init();
    _startRefreshTimer();
  }

  void _onSearchChanged() {
    if (!mounted) return;

    final query =
    _searchController.text.trim().toLowerCase();

    if (query == _searchQuery) {
      return;
    }

    setState(() {
      _searchQuery = query;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _refreshTimer?.cancel();

    _searchController.removeListener(
      _onSearchChanged,
    );

    _searchController.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed) {
      _loadChats();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
          (_) {
        if (mounted) {
          _loadChats();
        }
      },
    );
  }

  Future<void> _init() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      _currentUserId =
          prefs.getString('user_id');

      if (_currentUserId == null ||
          _currentUserId!.trim().isEmpty) {
        _currentUserId =
            prefs.getString(
              'current_user_id',
            );
      }

      if (_currentUserId == null ||
          _currentUserId!.trim().isEmpty) {
        _currentUserId =
            prefs.getString('uid');
      }

      await _loadCachedChats();
      await _loadChats();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Chats init error: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadError =
        'Не удалось загрузить чаты';
      });
    }
  }

  Future<void> _loadCachedChats() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      final cached =
      prefs.getString(_cacheKey);

      if (cached == null ||
          cached.isEmpty ||
          !mounted ||
          _chats.isNotEmpty) {
        return;
      }

      final decoded = jsonDecode(cached);

      if (decoded is List) {
        final chats = decoded
            .where(
              (item) => item is Map,
        )
            .map(
              (item) =>
          Map<String, dynamic>.from(
            item as Map,
          ),
        )
            .toList();

        if (!mounted) return;

        setState(() {
          _chats = chats;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Chats cache read error: $e',
      );
    }
  }

  Future<void> _cacheChats() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      await prefs.setString(
        _cacheKey,
        jsonEncode(_chats),
      );
    } catch (e) {
      debugPrint(
        'Chats cache save error: $e',
      );
    }
  }

  Future<void> _loadChats() async {
    if (_currentUserId == null ||
        _currentUserId!.isEmpty) {
      return;
    }

    try {
      final response = await http
          .post(
        Uri.parse(chatApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
        },
        body: jsonEncode({
          'action': 'list-chats',
          'user_id': _currentUserId,
        }),
      )
          .timeout(
        const Duration(seconds: 8),
      );

      if (!mounted) return;

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      final decoded =
      jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception(
          'Invalid server response',
        );
      }

      final data =
      Map<String, dynamic>.from(
        decoded,
      );

      if (data['ok'] == true &&
          data['chats'] is List) {
        final chats =
        (data['chats'] as List)
            .where(
              (item) => item is Map,
        )
            .map(
              (item) =>
          Map<String, dynamic>.from(
            item as Map,
          ),
        )
            .toList();

        if (!mounted) return;

        setState(() {
          _chats = chats;
          _retryCount = 0;
          _loadError = null;
          _loading = false;
        });

        await _cacheChats();
      } else {
        _handleLoadError();
      }
    } catch (e) {
      debugPrint(
        'Chats load error: $e',
      );

      _handleLoadError();
    }
  }

  void _handleLoadError() {
    _retryCount++;

    if (_chats.isEmpty && mounted) {
      setState(() {
        _loading = false;

        if (_retryCount >= 3) {
          _loadError =
          'Не удалось загрузить чаты';
        }
      });
    }

    if (_retryCount <= 5) {
      Future.delayed(
        Duration(
          seconds: 2 * _retryCount,
        ),
            () {
          if (mounted) {
            _loadChats();
          }
        },
      );
    }
  }

  String _formatLastMessage(
      Map<String, dynamic> chat,
      ) {
    final lastMsg =
        chat['last_message']
            ?.toString() ??
            '';

    final lastSenderName =
        chat['last_sender_name']
            ?.toString() ??
            '';

    final isMe =
        (chat['last_sender_id']
            ?.toString() ??
            '') ==
            _currentUserId;

    if (lastMsg.trim().isEmpty) {
      return 'Нет сообщений';
    }

    final sender = isMe
        ? 'Вы'
        : (lastSenderName.isNotEmpty
        ? lastSenderName
        : 'Пользователь');

    return '$sender: $lastMsg';
  }

  String _getChatName(
      Map<String, dynamic> chat,
      ) {
    final name =
        chat['other_name']
            ?.toString()
            .trim() ??
            '';

    return name.isEmpty
        ? 'Пользователь'
        : name;
  }

  String _getChatAvatar(
      Map<String, dynamic> chat,
      ) {
    final value =
    chat['other_avatar'];

    if (value == null) {
      return '';
    }

    final avatar =
    value.toString().trim();

    if (avatar.isEmpty ||
        avatar.toLowerCase() ==
            'null' ||
        avatar.toLowerCase() ==
            'none') {
      return '';
    }

    return avatar;
  }

  int _getUnreadCount(
      Map<String, dynamic> chat,
      ) {
    final value =
    chat['unread_count'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  bool _matchesSearch(
      Map<String, dynamic> chat,
      ) {
    if (_searchQuery.isEmpty) {
      return true;
    }

    final name =
    _getChatName(
      chat,
    ).toLowerCase();

    final message =
    _formatLastMessage(
      chat,
    ).toLowerCase();

    return name.contains(
      _searchQuery,
    ) ||
        message.contains(
          _searchQuery,
        );
  }

  List<Map<String, dynamic>>
  get _visibleChats {
    final result =
    _chats
        .where(_matchesSearch)
        .toList();

    result.sort((a, b) {
      final aUnread =
      _getUnreadCount(a);

      final bUnread =
      _getUnreadCount(b);

      if (aUnread > 0 &&
          bUnread == 0) {
        return -1;
      }

      if (aUnread == 0 &&
          bUnread > 0) {
        return 1;
      }

      final aTime =
      DateTime.tryParse(
        a['last_time']
            ?.toString() ??
            '',
      );

      final bTime =
      DateTime.tryParse(
        b['last_time']
            ?.toString() ??
            '',
      );

      if (aTime == null &&
          bTime == null) {
        return 0;
      }

      if (aTime == null) {
        return 1;
      }

      if (bTime == null) {
        return -1;
      }

      return bTime.compareTo(
        aTime,
      );
    });

    return result;
  }

  void _openChat(
      Map<String, dynamic> chat,
      ) {
    final chatId =
        chat['chat_id']
            ?.toString() ??
            '';

    final otherUserId =
        chat['other_user_id']
            ?.toString() ??
            '';

    if (chatId.isEmpty ||
        otherUserId.isEmpty) {
      debugPrint(
        'Cannot open chat: '
            'chatId=$chatId '
            'otherUserId=$otherUserId',
      );
      return;
    }

    final otherName =
    _getChatName(chat);

    final otherAvatar =
    _getChatAvatar(chat);

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration:
        const Duration(
          milliseconds: 360,
        ),
        reverseTransitionDuration:
        const Duration(
          milliseconds: 260,
        ),
        pageBuilder: (
            context,
            animation,
            secondaryAnimation,
            ) {
          return ChatScreen(
            chatId: chatId,
            otherUserId:
            otherUserId,
            otherName:
            otherName,
            otherAvatar:
            otherAvatar.isEmpty
                ? null
                : otherAvatar,
          );
        },
        transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
            ) {
          final slide =
          Tween<Offset>(
            begin:
            const Offset(
              0.08,
              0,
            ),
            end: Offset.zero,
          ).chain(
            CurveTween(
              curve:
              Curves.easeOutCubic,
            ),
          );

          final fade =
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          return SlideTransition(
            position:
            animation.drive(slide),
            child: FadeTransition(
              opacity: fade,
              child: child,
            ),
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        _loadChats();
      }
    });
  }

  String _formatTime(
      dynamic iso,
      ) {
    if (iso == null ||
        iso.toString().isEmpty) {
      return '';
    }

    try {
      final dt =
      DateTime.parse(
        iso.toString(),
      ).toLocal();

      final now =
      DateTime.now();

      if (dt.day == now.day &&
          dt.month == now.month &&
          dt.year == now.year) {
        return DateFormat(
          'HH:mm',
        ).format(dt);
      }

      if (dt.year == now.year) {
        return DateFormat(
          'dd MMM',
          'ru',
        ).format(dt);
      }

      return DateFormat(
        'dd.MM.yy',
      ).format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    super.build(context);

    if (_loading &&
        _chats.isEmpty) {
      return _buildLoadingState();
    }

    if (_chats.isEmpty &&
        _loadError != null) {
      return _buildErrorState();
    }

    if (_chats.isEmpty) {
      return _buildEmptyState();
    }

    final chats =
        _visibleChats;

    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 220,
      ),
      color: _backgroundColor,
      child: Stack(
        children: [
          _buildBackgroundDecor(),
          RefreshIndicator(
            color: _accent,
            backgroundColor:
            _isDarkMode
                ? const Color(
              0xFF11161E,
            )
                : Colors.white,
            strokeWidth: 2.1,
            onRefresh: () async {
              _retryCount = 0;
              _loadError = null;

              await _loadChats();
            },
            child: CustomScrollView(
              physics:
              const BouncingScrollPhysics(
                parent:
                AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child:
                  _buildHeader(),
                ),
                if (_searchQuery
                    .isNotEmpty &&
                    chats.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody:
                    false,
                    child:
                    _buildNoSearchResults(),
                  )
                else
                  SliverPadding(
                    padding:
                    const EdgeInsets
                        .fromLTRB(
                      14,
                      5,
                      14,
                      110,
                    ),
                    sliver: SliverList(
                      delegate:
                      SliverChildBuilderDelegate(
                            (context, index) {
                          final chat =
                          chats[index];

                          return Column(
                            children: [
                              _buildChatTile(
                                chat,
                                index,
                              ),
                              if (index <
                                  chats.length -
                                      1)
                                _buildChatSeparator(),
                            ],
                          );
                        },
                        childCount:
                        chats.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    if (!_isDarkMode) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -130,
            right: -110,
            child: Container(
              width: 280,
              height: 280,
              decoration:
              BoxDecoration(
                shape:
                BoxShape.circle,
                gradient:
                RadialGradient(
                  colors: [
                    _accent
                        .withOpacity(
                      0.075,
                    ),
                    _accent
                        .withOpacity(
                      0,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -140,
            child: Container(
              width: 300,
              height: 300,
              decoration:
              BoxDecoration(
                shape:
                BoxShape.circle,
                gradient:
                RadialGradient(
                  colors: [
                    const Color(
                      0xFF3F8CFF,
                    ).withOpacity(
                      0.04,
                    ),
                    const Color(
                      0xFF3F8CFF,
                    ).withOpacity(
                      0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final total =
        _chats.length;

    final unread =
    _chats.fold<int>(
      0,
          (sum, chat) =>
      sum +
          _getUnreadCount(chat),
    );

    return Padding(
      padding:
      const EdgeInsets
          .fromLTRB(
        16,
        14,
        16,
        9,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                _buildSearchField(),
              ),
              const SizedBox(
                width: 10,
              ),
              AnimatedContainer(
                duration:
                const Duration(
                  milliseconds: 220,
                ),
                width: 44,
                height: 44,
                decoration:
                BoxDecoration(
                  color: _accent
                      .withOpacity(
                    _isDarkMode
                        ? 0.075
                        : 0.055,
                  ),
                  shape:
                  BoxShape.circle,
                ),
                child:
                Center(
                  child: Icon(
                    unread > 0
                        ? Icons
                        .mark_chat_unread_outlined
                        : Icons
                        .chat_bubble_outline_rounded,
                    size: 20,
                    color:
                    unread > 0
                        ? _accent
                        : _secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          if (unread > 0) ...[
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                AnimatedContainer(
                  duration:
                  const Duration(
                    milliseconds:
                    220,
                  ),
                  width: 7,
                  height: 7,
                  decoration:
                  BoxDecoration(
                    color: _accent,
                    shape:
                    BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accent
                            .withOpacity(
                          0.35,
                        ),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  '$unread непрочитанных',
                  style: TextStyle(
                    color:
                    _secondaryTextColor,
                    fontSize: 12.5,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ],
            ),
          ] else if (total > 0) ...[
            const SizedBox(
              height: 10,
            ),
            Align(
              alignment:
              Alignment.centerLeft,
              child: Text(
                '$total ${_chatWord(total)}',
                style: TextStyle(
                  color: _secondaryTextColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _chatWord(
      int count,
      ) {
    final mod10 =
        count % 10;

    final mod100 =
        count % 100;

    if (mod10 == 1 &&
        mod100 != 11) {
      return 'чат';
    }

    if (mod10 >= 2 &&
        mod10 <= 4 &&
        (mod100 < 10 ||
            mod100 >= 20)) {
      return 'чата';
    }

    return 'чатов';
  }

  Widget _buildSearchField() {
    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 220,
      ),
      height: 46,
      decoration:
      BoxDecoration(
        color: _isDarkMode
            ? const Color(
          0xFF0F141C,
        )
            : Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        boxShadow: [
          if (!_isDarkMode)
            BoxShadow(
              color: Colors.black
                  .withOpacity(
                0.035,
              ),
              blurRadius: 20,
              offset:
              const Offset(
                0,
                7,
              ),
              spreadRadius: -7,
            ),
        ],
      ),
      child: TextField(
        controller:
        _searchController,
        style: TextStyle(
          color: _textColor,
          fontSize: 14,
          fontWeight:
          FontWeight.w500,
        ),
        cursorColor: _accent,
        textInputAction:
        TextInputAction.search,
        decoration:
        InputDecoration(
          hintText: 'Поиск',
          hintStyle:
          TextStyle(
            color:
            _secondaryTextColor
                .withOpacity(
              0.82,
            ),
            fontSize: 14,
            fontWeight:
            FontWeight.w400,
          ),
          prefixIcon:
          AnimatedContainer(
            duration:
            const Duration(
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
          _searchQuery
              .isNotEmpty
              ? IconButton(
            onPressed:
            _searchController
                .clear,
            splashRadius: 18,
            icon: Icon(
              Icons
                  .close_rounded,
              size: 18,
              color:
              _secondaryTextColor,
            ),
          )
              : null,
          filled: true,
          fillColor:
          Colors.transparent,
          border:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            borderSide:
            BorderSide.none,
          ),
          enabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            borderSide:
            BorderSide.none,
          ),
          focusedBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            borderSide:
            BorderSide.none,
          ),
          disabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            borderSide:
            BorderSide.none,
          ),
          contentPadding:
          const EdgeInsets
              .symmetric(
            horizontal: 8,
            vertical: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(
      Map<String, dynamic> chat,
      int index,
      ) {
    final name =
    _getChatName(chat);

    final avatar =
    _getChatAvatar(chat);

    final unreadCount =
    _getUnreadCount(chat);

    final lastMsg =
    _formatLastMessage(chat);

    final lastTime =
    chat['last_time'];

    final isMe =
        (chat['last_sender_id']
            ?.toString() ??
            '') ==
            _currentUserId;

    final isUnread =
        unreadCount > 0;

    return _ChatTile(
      key: ValueKey(
        chat['chat_id'] ??
            '${name}_$index',
      ),
      name: name,
      avatar: avatar,
      unreadCount:
      unreadCount,
      lastMessage:
      lastMsg,
      lastTime:
      _formatTime(lastTime),
      isMe: isMe,
      isUnread:
      isUnread,
      textColor:
      _textColor,
      secondaryColor:
      _secondaryTextColor,
      accentColor:
      _accent,
      isDarkMode:
      _isDarkMode,
      onTap: () =>
          _openChat(chat),
    );
  }

  Widget _buildChatSeparator() {
    return SizedBox(
      height: 5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: Container(
              height: 2.2,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    _accent.withOpacity(
                      _isDarkMode ? 0.035 : 0.045,
                    ),
                    _accent.withOpacity(
                      _isDarkMode ? 0.14 : 0.16,
                    ),
                    _accent.withOpacity(
                      _isDarkMode ? 0.035 : 0.045,
                    ),
                    Colors.transparent,
                  ],
                  stops: const [
                    0.0,
                    0.25,
                    0.5,
                    0.75,
                    1.0,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(
                      _isDarkMode ? 0.10 : 0.07,
                    ),
                    blurRadius: 5,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: _backgroundColor,
      child: ListView.builder(
        physics:
        const NeverScrollableScrollPhysics(),
        padding:
        const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          20,
        ),
        itemCount: 7,
        itemBuilder:
            (context, index) {
          return Padding(
            padding:
            const EdgeInsets.only(
              bottom: 9,
            ),
            child:
            _buildSkeletonTile(),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonTile() {
    return Container(
      height: 78,
      decoration:
      BoxDecoration(
        color:
        _isDarkMode
            ? Colors.white
            .withOpacity(
          0.025,
        )
            : Colors.black
            .withOpacity(
          0.018,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 4,
          ),
          _buildSkeletonCircle(),
          const SizedBox(
            width: 13,
          ),
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets
                  .symmetric(
                vertical: 15,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                mainAxisAlignment:
                MainAxisAlignment
                    .center,
                children: [
                  _buildSkeletonLine(
                    width: 125,
                    height: 10,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  _buildSkeletonLine(
                    width: 195,
                    height: 8,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCircle() {
    return TweenAnimationBuilder<
        double>(
      tween: Tween(
        begin: 0.45,
        end: 1.0,
      ),
      duration:
      const Duration(
        milliseconds: 850,
      ),
      curve:
      Curves.easeInOut,
      builder: (
          context,
          value,
          child,
          ) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 56,
            height: 56,
            decoration:
            BoxDecoration(
              shape:
              BoxShape.circle,
              color:
              _isDarkMode
                  ? Colors.white
                  .withOpacity(
                0.025,
              )
                  : Colors.black
                  .withOpacity(
                0.018,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLine({
    required double width,
    required double height,
  }) {
    return TweenAnimationBuilder<
        double>(
      tween: Tween(
        begin: 0.45,
        end: 1.0,
      ),
      duration:
      const Duration(
        milliseconds: 800,
      ),
      curve:
      Curves.easeInOut,
      builder: (
          context,
          value,
          child,
          ) {
        return Opacity(
          opacity: value,
          child: Container(
            width: width,
            height: height,
            decoration:
            BoxDecoration(
              color:
              _isDarkMode
                  ? Colors.white
                  .withOpacity(
                0.025,
              )
                  : Colors.black
                  .withOpacity(
                0.018,
              ),
              borderRadius:
              BorderRadius.circular(
                height,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: _backgroundColor,
      child: Center(
        child: Padding(
          padding:
          const EdgeInsets
              .symmetric(
            horizontal: 32,
          ),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment
                .center,
            children: [
              AnimatedContainer(
                duration:
                const Duration(
                  milliseconds: 240,
                ),
                width: 82,
                height: 82,
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  color: _accent
                      .withOpacity(
                    0.09,
                  ),
                ),
                child: Icon(
                  Icons
                      .forum_outlined,
                  size: 34,
                  color: _accent,
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              Text(
                'Пока пусто',
                style:
                TextStyle(
                  color:
                  _textColor,
                  fontSize: 23,
                  fontWeight:
                  FontWeight.w800,
                  letterSpacing:
                  -0.5,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                'Начните общение — здесь появятся ваши чаты.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  _secondaryTextColor,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: _backgroundColor,
      child: Center(
        child: Padding(
          padding:
          const EdgeInsets
              .symmetric(
            horizontal: 28,
          ),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment
                .center,
            children: [
              AnimatedContainer(
                duration:
                const Duration(
                  milliseconds: 240,
                ),
                width: 76,
                height: 76,
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  color: _accent
                      .withOpacity(
                    0.09,
                  ),
                ),
                child: Icon(
                  Icons
                      .wifi_off_rounded,
                  size: 32,
                  color: _accent,
                ),
              ),
              const SizedBox(
                height: 22,
              ),
              Text(
                _loadError ??
                    'Ошибка загрузки',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  _textColor,
                  fontSize: 19,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                'Проверьте подключение и попробуйте ещё раз.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  _secondaryTextColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _loading =
                    true;
                    _loadError =
                    null;
                    _retryCount =
                    0;
                  });

                  _loadChats();
                },
                style:
                FilledButton.styleFrom(
                  backgroundColor:
                  _accent,
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      16,
                    ),
                  ),
                ),
                icon:
                const Icon(
                  Icons
                      .refresh_rounded,
                  size: 19,
                ),
                label:
                const Text(
                  'Повторить',
                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,
          children: [
            Icon(
              Icons
                  .search_off_rounded,
              size: 40,
              color:
              _secondaryTextColor,
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              'Ничего не найдено',
              style:
              TextStyle(
                color:
                _textColor,
                fontSize: 18,
                fontWeight:
                FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 7,
            ),
            Text(
              'Попробуйте изменить запрос.',
              style:
              TextStyle(
                color:
                _secondaryTextColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatefulWidget {
  final String name;
  final String avatar;
  final int unreadCount;
  final String lastMessage;
  final String lastTime;
  final bool isMe;
  final bool isUnread;

  final Color textColor;
  final Color secondaryColor;
  final Color accentColor;

  final bool isDarkMode;

  final VoidCallback onTap;

  const _ChatTile({
    super.key,
    required this.name,
    required this.avatar,
    required this.unreadCount,
    required this.lastMessage,
    required this.lastTime,
    required this.isMe,
    required this.isUnread,
    required this.textColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  State<_ChatTile> createState() =>
      _ChatTileState();
}

class _ChatTileState
    extends State<_ChatTile> {
  bool _pressed = false;

  @override
  Widget build(
      BuildContext context,
      ) {
    return AnimatedScale(
      scale:
      _pressed ? 0.985 : 1.0,
      duration:
      const Duration(
        milliseconds: 110,
      ),
      child: Material(
        color:
        Colors.transparent,
        child: InkWell(
          onTap:
          widget.onTap,
          onTapDown: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _pressed = true;
            });
          },
          onTapCancel: () {
            if (!mounted) {
              return;
            }

            setState(() {
              _pressed = false;
            });
          },
          onTapUp: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _pressed = false;
            });
          },
          borderRadius:
          BorderRadius.circular(
            18,
          ),
          splashColor:
          widget.accentColor
              .withOpacity(
            0.045,
          ),
          highlightColor:
          Colors.transparent,
          child: Padding(
            padding:
            const EdgeInsets
                .fromLTRB(
              2,
              10,
              2,
              10,
            ),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(
                  width: 13,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.name,
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              TextStyle(
                                color:
                                widget.textColor,
                                fontSize:
                                16,
                                fontWeight:
                                widget.isUnread
                                    ? FontWeight
                                    .w700
                                    : FontWeight
                                    .w600,
                                letterSpacing:
                                -0.2,
                              ),
                            ),
                          ),
                          if (widget
                              .lastTime
                              .isNotEmpty) ...[
                            const SizedBox(
                              width: 8,
                            ),
                            Text(
                              widget.lastTime,
                              style:
                              TextStyle(
                                color: widget
                                    .isUnread
                                    ? widget
                                    .accentColor
                                    : widget
                                    .secondaryColor,
                                fontSize:
                                11,
                                fontWeight:
                                widget.isUnread
                                    ? FontWeight
                                    .w700
                                    : FontWeight
                                    .w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Row(
                        children: [
                          if (widget
                              .isMe) ...[
                            Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal:
                                6,
                                vertical:
                                3,
                              ),
                              decoration:
                              BoxDecoration(
                                color: widget
                                    .accentColor
                                    .withOpacity(
                                  0.075,
                                ),
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  7,
                                ),
                              ),
                              child:
                              Text(
                                'ВЫ',
                                style:
                                TextStyle(
                                  color:
                                  widget.accentColor,
                                  fontSize:
                                  8,
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                  letterSpacing:
                                  0.35,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 7,
                            ),
                          ],
                          Expanded(
                            child: Text(
                              widget
                                  .lastMessage,
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              TextStyle(
                                color: widget
                                    .isUnread
                                    ? widget
                                    .textColor
                                    .withOpacity(
                                  0.70,
                                )
                                    : widget
                                    .secondaryColor,
                                fontSize:
                                13,
                                fontWeight:
                                widget.isUnread
                                    ? FontWeight
                                    .w500
                                    : FontWeight
                                    .w400,
                                height:
                                1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                _buildUnreadIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 180,
      ),
      width: 56,
      height: 56,
      decoration:
      BoxDecoration(
        shape:
        BoxShape.circle,
        boxShadow: [
          if (widget.isUnread)
            BoxShadow(
              color: widget
                  .accentColor
                  .withOpacity(
                0.15,
              ),
              blurRadius: 16,
            ),
        ],
      ),
      child: ClipOval(
        child:
        _buildAvatarImage(),
      ),
    );
  }

  Widget _buildAvatarImage() {
    final avatar =
    widget.avatar.trim();

    if (avatar.isEmpty) {
      return _buildAvatarFallback();
    }

    return CachedNetworkImage(
      imageUrl: avatar,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      fadeInDuration:
      const Duration(
        milliseconds: 180,
      ),
      fadeOutDuration:
      const Duration(
        milliseconds: 100,
      ),
      placeholder: (
          context,
          url,
          ) {
        return _buildAvatarFallback();
      },
      errorWidget: (
          context,
          url,
          error,
          ) {
        debugPrint(
          'Avatar load error: '
              '$url\n$error',
        );

        return _buildAvatarFallback();
      },
    );
  }

  Widget _buildAvatarFallback() {
    final cleaned =
    widget.name.trim();

    String letter = '?';

    if (cleaned.isNotEmpty) {
      letter =
          cleaned.characters
              .first
              .toUpperCase();
    }

    return Container(
      color: widget.isDarkMode
          ? const Color(
        0xFF161D27,
      )
          : const Color(
        0xFFF0F2F5,
      ),
      alignment:
      Alignment.center,
      child: Text(
        letter,
        style:
        TextStyle(
          color:
          widget.accentColor,
          fontSize: 19,
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildUnreadIndicator() {
    if (!widget.isUnread) {
      return const SizedBox(
        width: 5,
        height: 5,
      );
    }

    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 180,
      ),
      constraints:
      const BoxConstraints(
        minWidth: 22,
        minHeight: 22,
      ),
      padding:
      const EdgeInsets
          .symmetric(
        horizontal: 6,
      ),
      decoration:
      BoxDecoration(
        color:
        widget.accentColor,
        borderRadius:
        BorderRadius.circular(
          11,
        ),
        boxShadow: [
          BoxShadow(
            color: widget
                .accentColor
                .withOpacity(
              0.20,
            ),
            blurRadius: 10,
          ),
        ],
      ),
      alignment:
      Alignment.center,
      child: Text(
        widget.unreadCount > 99
            ? '99+'
            : widget.unreadCount
            .toString(),
        style:
        const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }
}
