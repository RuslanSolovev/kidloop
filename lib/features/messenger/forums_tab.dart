import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'forum_screen.dart';

class ForumsTab extends StatefulWidget {
  final Color accentColor;

  const ForumsTab({
    super.key,
    required this.accentColor,
  });

  @override
  State<ForumsTab> createState() => _ForumsTabState();
}

class _ForumsTabState extends State<ForumsTab>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _forums = [];

  bool _loading = true;

  String? _currentUserId;
  String? _currentUserName;

  Timer? _refreshTimer;

  int _retryCount = 0;
  String? _loadError;

  static const String forumApiUrl =
      'https://functions.yandexcloud.net/d4en6mi363fq4o5js5ee';

  static const String _cacheKey = 'forums_cache';

  // --------------------------------------------------------------
  // Цвета
  // --------------------------------------------------------------

  Color get _accent => widget.accentColor;

  Color get _accentSoft =>
      Color.lerp(
        _accent,
        Colors.white,
        0.20,
      ) ??
          _accent;

  Color get _accentDeep =>
      Color.lerp(
        _accent,
        Colors.black,
        0.08,
      ) ??
          _accent;

  bool get _isDarkMode =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _backgroundColor =>
      _isDarkMode
          ? const Color(0xFF070A10)
          : const Color(0xFFF5F6F8);

  Color get _surfaceColor =>
      _isDarkMode
          ? const Color(0xFF10151D)
          : Colors.white;

  Color get _surfaceElevatedColor =>
      _isDarkMode
          ? const Color(0xFF141A23)
          : const Color(0xFFFFFFFF);

  Color get _softSurfaceColor =>
      _isDarkMode
          ? Colors.white.withOpacity(0.035)
          : Colors.black.withOpacity(0.025);

  Color get _cardBgColor =>
      _isDarkMode
          ? Colors.white.withOpacity(0.025)
          : const Color(0xFFF7F8FA);

  Color get _textColor =>
      _isDarkMode
          ? const Color(0xFFF8FAFC)
          : const Color(0xFF161A20);

  Color get _subTextColor =>
      _isDarkMode
          ? const Color(0xFF8A94A3)
          : const Color(0xFF7D8692);

  Color get _mutedColor =>
      _isDarkMode
          ? const Color(0xFF626C79)
          : const Color(0xFFA0A7B0);

  Color get _borderColor =>
      _isDarkMode
          ? Colors.white.withOpacity(0.055)
          : Colors.black.withOpacity(0.055);

  // --------------------------------------------------------------
  // Keep alive
  // --------------------------------------------------------------

  @override
  bool get wantKeepAlive => true;

  // --------------------------------------------------------------
  // Init / lifecycle
  // --------------------------------------------------------------

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
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed) {
      _loadForums();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) {
        if (mounted) {
          _loadForums();
        }
      },
    );
  }

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

      await _loadCachedForums();
      await _loadForums();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Forums init error: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadError =
        'Не удалось загрузить форумы';
      });
    }
  }

  // --------------------------------------------------------------
  // Cache
  // --------------------------------------------------------------

  Future<void> _loadCachedForums() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      final cached =
      prefs.getString(_cacheKey);

      if (cached == null ||
          cached.isEmpty ||
          !mounted ||
          _forums.isNotEmpty) {
        return;
      }

      final decoded =
      jsonDecode(cached);

      if (decoded is! List) {
        return;
      }

      final forums = decoded
          .whereType<Map>()
          .map(
            (forum) =>
        Map<String, dynamic>.from(
          forum,
        ),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        _forums = forums;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Forums cache read error: $e',
      );
    }
  }

  Future<void> _cacheForums() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      await prefs.setString(
        _cacheKey,
        jsonEncode(_forums),
      );
    } catch (e) {
      debugPrint(
        'Forums cache save error: $e',
      );
    }
  }

  // --------------------------------------------------------------
  // Загрузка форумов
  // --------------------------------------------------------------

  Future<void> _loadForums() async {
    try {
      final response = await http
          .post(
        Uri.parse(forumApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action': 'list-forums',
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

      if (decoded is Map &&
          decoded['ok'] == true &&
          decoded['forums'] is List) {
        final forums =
        (decoded['forums'] as List)
            .whereType<Map>()
            .map(
              (forum) =>
          Map<String, dynamic>.from(
            forum,
          ),
        )
            .toList();

        if (!mounted) return;

        setState(() {
          _forums = forums;
          _retryCount = 0;
          _loadError = null;
          _loading = false;
        });

        await _cacheForums();
      } else {
        _handleLoadError();
      }
    } catch (e) {
      debugPrint(
        'Forums load error: $e',
      );

      _handleLoadError();
    }
  }

  void _handleLoadError() {
    _retryCount++;

    if (_forums.isEmpty && mounted) {
      setState(() {
        _loading = false;

        if (_retryCount >= 3) {
          _loadError =
          'Не удалось загрузить форумы';
        }
      });
    }

    if (_retryCount <= 5 && mounted) {
      final delay =
      Duration(seconds: 2 * _retryCount);

      Future.delayed(
        delay,
            () {
          if (mounted) {
            _loadForums();
          }
        },
      );
    }
  }

  // --------------------------------------------------------------
  // Создание форума
  // --------------------------------------------------------------

  Future<void> _createForum() async {
    final titleCtrl =
    TextEditingController();

    final descCtrl =
    TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogDark =
            Theme.of(ctx).brightness ==
                Brightness.dark;

        final dialogSurface =
        dialogDark
            ? const Color(0xFF11161E)
            : Colors.white;

        final dialogText =
        dialogDark
            ? Colors.white
            : const Color(0xFF171B21);

        final dialogSecondary =
        dialogDark
            ? const Color(0xFF8993A1)
            : const Color(0xFF7E8794);

        return AlertDialog(
          backgroundColor:
          dialogSurface,
          surfaceTintColor:
          Colors.transparent,
          elevation: 18,
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(26),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                BoxDecoration(
                  color:
                  _accent.withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  Icons.forum_rounded,
                  color: _accent,
                  size: 21,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Text(
                  'Создать обсуждение',
                  style: TextStyle(
                    color:
                    dialogText,
                    fontSize: 19,
                    fontWeight:
                    FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(
                  color: dialogText,
                  fontSize: 14,
                ),
                cursorColor: _accent,
                decoration:
                InputDecoration(
                  labelText: 'Тема',
                  labelStyle:
                  TextStyle(
                    color:
                    dialogSecondary,
                  ),
                  floatingLabelStyle:
                  TextStyle(
                    color: _accent,
                  ),
                  filled: true,
                  fillColor:
                  dialogDark
                      ? Colors.white
                      .withOpacity(
                    0.035,
                  )
                      : Colors.black
                      .withOpacity(
                    0.025,
                  ),
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      15,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  enabledBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      15,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  focusedBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      15,
                    ),
                    borderSide:
                    BorderSide(
                      color: _accent
                          .withOpacity(
                        0.45,
                      ),
                      width: 1,
                    ),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(
                height: 11,
              ),
              TextField(
                controller: descCtrl,
                style: TextStyle(
                  color: dialogText,
                  fontSize: 14,
                ),
                cursorColor: _accent,
                maxLines: 3,
                decoration:
                InputDecoration(
                  labelText: 'Описание',
                  labelStyle:
                  TextStyle(
                    color:
                    dialogSecondary,
                  ),
                  floatingLabelStyle:
                  TextStyle(
                    color: _accent,
                  ),
                  filled: true,
                  fillColor:
                  dialogDark
                      ? Colors.white
                      .withOpacity(
                    0.035,
                  )
                      : Colors.black
                      .withOpacity(
                    0.025,
                  ),
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      15,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  enabledBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      15,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  focusedBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      15,
                    ),
                    borderSide:
                    BorderSide(
                      color: _accent
                          .withOpacity(
                        0.45,
                      ),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
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
                  Navigator.of(ctx)
                      .pop(false),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color:
                  dialogSecondary,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
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
                  13,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    _accent
                        .withOpacity(
                      0.18,
                    ),
                    blurRadius: 10,
                    offset:
                    const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: () =>
                    Navigator.of(ctx)
                        .pop(true),
                child: const Text(
                  'Создать',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) {
      titleCtrl.dispose();
      descCtrl.dispose();
      return;
    }

    try {
      final response = await http
          .post(
        Uri.parse(forumApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action': 'create-forum',
          'creator_id': _currentUserId,
          'creator_name': _currentUserName,
          'title':
          titleCtrl.text.trim(),
          'description':
          descCtrl.text.trim(),
        }),
      )
          .timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      _retryCount = 0;

      await _loadForums();

      if (!mounted) return;

      _showSnackBar(
        'Обсуждение создано',
        icon:
        Icons.check_circle_outline_rounded,
      );
    } catch (e) {
      debugPrint(
        'Create forum error: $e',
      );

      if (!mounted) return;

      _showSnackBar(
        'Не удалось создать обсуждение',
        isError: true,
      );
    } finally {
      titleCtrl.dispose();
      descCtrl.dispose();
    }
  }

  // --------------------------------------------------------------
  // Удаление форума
  // --------------------------------------------------------------

  Future<void> _deleteForum(
      String forumId,
      ) async {
    final confirm =
    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogDark =
            Theme.of(ctx).brightness ==
                Brightness.dark;

        final dialogSurface =
        dialogDark
            ? const Color(0xFF11161E)
            : Colors.white;

        final dialogText =
        dialogDark
            ? Colors.white
            : const Color(0xFF171B21);

        final dialogSecondary =
        dialogDark
            ? const Color(0xFF8993A1)
            : const Color(0xFF7E8794);

        return AlertDialog(
          backgroundColor:
          dialogSurface,
          surfaceTintColor:
          Colors.transparent,
          elevation: 18,
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(26),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                BoxDecoration(
                  color: Colors.redAccent
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child: const Icon(
                  Icons
                      .delete_outline_rounded,
                  color:
                  Colors.redAccent,
                  size: 21,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Text(
                  'Удалить обсуждение?',
                  style: TextStyle(
                    color:
                    dialogText,
                    fontSize: 18,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Это действие нельзя отменить.',
            style: TextStyle(
              color:
              dialogSecondary,
              fontSize: 14,
              height: 1.4,
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
                  Navigator.of(ctx)
                      .pop(false),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color:
                  dialogSecondary,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx)
                      .pop(true),
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

    if (confirm != true ||
        !mounted) {
      return;
    }

    try {
      final response = await http
          .post(
        Uri.parse(forumApiUrl),
        headers: const {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode({
          'action':
          'delete-forum',
          'forum_id': forumId,
          'user_id': _currentUserId,
        }),
      )
          .timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      await _loadForums();

      if (!mounted) return;

      _showSnackBar(
        'Обсуждение удалено',
        icon:
        Icons.delete_outline_rounded,
      );
    } catch (e) {
      debugPrint(
        'Delete forum error: $e',
      );

      if (!mounted) return;

      _showSnackBar(
        'Не удалось удалить обсуждение',
        isError: true,
      );
    }
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
              const SizedBox(
                width: 10,
              ),
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
  // Build
  // --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading &&
        _forums.isEmpty) {
      return _buildLoadingSkeleton();
    }

    if (_forums.isEmpty &&
        _loadError != null) {
      return _buildErrorState();
    }

    return Scaffold(
      backgroundColor:
      _backgroundColor,
      floatingActionButton:
      _buildFloatingActionButton(),
      body:
      _forums.isEmpty
          ? _buildEmptyState()
          : _buildForumsList(),
    );
  }

  // --------------------------------------------------------------
  // Верхняя панель
  // --------------------------------------------------------------

  Widget _buildHeader() {
    final total =
        _forums.length;

    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Обсуждения',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 27,
                    fontWeight:
                    FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  total == 0
                      ? 'Общайтесь и делитесь мыслями'
                      : '$total ${_forumWord(total)}',
                  style: TextStyle(
                    color:
                    _subTextColor,
                    fontSize: 12.5,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration:
            BoxDecoration(
              color:
              _accent.withOpacity(
                0.08,
              ),
              shape: BoxShape.circle,
              border:
              Border.all(
                color:
                _accent.withOpacity(
                  0.10,
                ),
                width: 0.7,
              ),
            ),
            child: Icon(
              Icons.forum_outlined,
              color: _accent,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  String _forumWord(int count) {
    final mod10 =
        count % 10;

    final mod100 =
        count % 100;

    if (mod10 == 1 &&
        mod100 != 11) {
      return 'обсуждение';
    }

    if (mod10 >= 2 &&
        mod10 <= 4 &&
        (mod100 < 10 ||
            mod100 >= 20)) {
      return 'обсуждения';
    }

    return 'обсуждений';
  }

  // --------------------------------------------------------------
  // Список
  // --------------------------------------------------------------

  Widget _buildForumsList() {
    return RefreshIndicator(
      color: _accent,
      backgroundColor:
      _surfaceColor,
      displacement: 30,
      onRefresh: () async {
        _retryCount = 0;
        _loadError = null;

        await _loadForums();
      },
      child: AnimatedSwitcher(
        duration:
        const Duration(
          milliseconds: 260,
        ),
        child: ListView.builder(
          key:
          ValueKey(
            _forums.length,
          ),
          physics:
          const BouncingScrollPhysics(
            parent:
            AlwaysScrollableScrollPhysics(),
          ),
          padding:
          const EdgeInsets.only(
            top: 2,
            bottom: 115,
          ),
          itemCount:
          _forums.length + 1,
          itemBuilder:
              (context, index) {
            if (index == 0) {
              return _buildHeader();
            }

            final forum =
            _forums[index - 1];

            return _buildForumCard(
              forum,
              index - 1,
            );
          },
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // FAB
  // --------------------------------------------------------------

  Widget _buildFloatingActionButton() {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 72,
      ),
      child: AnimatedContainer(
        duration:
        const Duration(
          milliseconds: 220,
        ),
        decoration:
        BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:
              _accent.withOpacity(
                _isDarkMode
                    ? 0.26
                    : 0.18,
              ),
              blurRadius: 18,
              spreadRadius: 1,
              offset:
              const Offset(
                0,
                7,
              ),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag:
          'create_forum',
          onPressed:
          _createForum,
          backgroundColor:
          _accent,
          foregroundColor:
          Colors.white,
          elevation: 0,
          shape:
          const CircleBorder(),
          child: const Icon(
            Icons.add_rounded,
            size: 29,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Loading
  // --------------------------------------------------------------

  Widget _buildLoadingSkeleton() {
    return ColoredBox(
      color:
      _backgroundColor,
      child: ListView.builder(
        physics:
        const NeverScrollableScrollPhysics(),
        padding:
        const EdgeInsets.only(
          top: 14,
          bottom: 30,
        ),
        itemCount: 5,
        itemBuilder:
            (context, index) {
          return _buildSkeletonCard(
            index,
          );
        },
      ),
    );
  }

  Widget _buildSkeletonCard(
      int index,
      ) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        14,
        0,
        14,
        9,
      ),
      child: Container(
        height: 148,
        decoration:
        BoxDecoration(
          color: _surfaceColor,
          borderRadius:
          BorderRadius.circular(
            21,
          ),
          border:
          Border.all(
            color: _borderColor,
            width: 0.7,
          ),
        ),
        padding:
        const EdgeInsets.all(
          15,
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildSkeletonBox(
                  width: 46,
                  height: 46,
                  radius: 15,
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
                      _buildSkeletonBox(
                        width: 160,
                        height: 14,
                        radius: 7,
                      ),
                      const SizedBox(
                        height: 9,
                      ),
                      _buildSkeletonBox(
                        width: 210,
                        height: 10,
                        radius: 5,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 18,
            ),
            _buildSkeletonBox(
              width: double.infinity,
              height: 11,
              radius: 6,
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                _buildSkeletonBox(
                  width: 75,
                  height: 9,
                  radius: 5,
                ),
                const SizedBox(
                  width: 10,
                ),
                _buildSkeletonBox(
                  width: 55,
                  height: 9,
                  radius: 5,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    required double radius,
  }) {
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
      builder:
          (context, value, child) {
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
                0.035,
              )
                  : Colors.black
                  .withOpacity(
                0.035,
              ),
              borderRadius:
              BorderRadius.circular(
                radius,
              ),
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------
  // Error
  // --------------------------------------------------------------

  Widget _buildErrorState() {
    return ColoredBox(
      color:
      _backgroundColor,
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
              Container(
                width: 82,
                height: 82,
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  color:
                  _accent.withOpacity(
                    0.09,
                  ),
                  border:
                  Border.all(
                    color:
                    _accent.withOpacity(
                      0.08,
                    ),
                  ),
                ),
                child: Icon(
                  Icons
                      .cloud_off_rounded,
                  color: _accent,
                  size: 34,
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
                style: TextStyle(
                  color:
                  _textColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                'Проверьте соединение и попробуйте ещё раз.',
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  color:
                  _subTextColor,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                    _retryCount = 0;
                  });

                  _loadForums();
                },
                icon: const Icon(
                  Icons
                      .refresh_rounded,
                  size: 19,
                ),
                label: const Text(
                  'Повторить',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
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
                    BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // Empty
  // --------------------------------------------------------------

  Widget _buildEmptyState() {
    return ColoredBox(
      color:
      _backgroundColor,
      child: Stack(
        children: [
          ListView(
            physics:
            const BouncingScrollPhysics(
              parent:
              AlwaysScrollableScrollPhysics(),
            ),
            padding:
            const EdgeInsets.only(
              bottom: 140,
            ),
            children: [
              _buildHeader(),
              const SizedBox(
                height: 90,
              ),
              Padding(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 30,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
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
                        color: _accent,
                        size: 38,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    Text(
                      'Нет обсуждений',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        color:
                        _textColor,
                        fontSize: 22,
                        fontWeight:
                        FontWeight.w800,
                        letterSpacing:
                        -0.4,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      'Создайте первое обсуждение и начните общение.',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        color:
                        _subTextColor,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    DecoratedBox(
                      decoration:
                      BoxDecoration(
                        color: _accent
                            .withOpacity(
                          0.08,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: Padding(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        child: Row(
                          mainAxisSize:
                          MainAxisSize.min,
                          children: [
                            Icon(
                              Icons
                                  .add_circle_outline_rounded,
                              color:
                              _accent,
                              size: 18,
                            ),
                            const SizedBox(
                              width: 7,
                            ),
                            Text(
                              'Нажмите +, чтобы создать тему',
                              style:
                              TextStyle(
                                color:
                                _accent,
                                fontSize:
                                12.5,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 22,
            child:
            _buildFloatingActionButton(),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // Forum card
  // --------------------------------------------------------------

  Widget _buildForumCard(
      Map<String, dynamic> forum,
      int index,
      ) {
    final forumId =
        forum['forum_id']
            ?.toString() ??
            '';

    final title =
        forum['title']
            ?.toString() ??
            '';

    final desc =
        forum['description']
            ?.toString() ??
            '';

    final creatorName =
        forum['creator_name']
            ?.toString() ??
            '';

    final participantValue =
    forum['participant_count'];

    final participantCount =
    participantValue is num
        ? participantValue.toInt()
        : int.tryParse(
      participantValue
          ?.toString() ??
          '',
    ) ??
        0;

    final lastMsg =
        forum['last_message']
            ?.toString() ??
            '';

    final lastTime =
    forum['last_time'];

    final isCreator =
        forum['creator_id']
            ?.toString() ==
            _currentUserId;

    return TweenAnimationBuilder<
        double>(
      tween: Tween(
        begin: 0,
        end: 1,
      ),
      duration: Duration(
        milliseconds:
        260 + (index.clamp(0, 5) * 55),
      ),
      curve:
      Curves.easeOutCubic,
      builder:
          (context, value, child) {
        return Transform.translate(
          offset: Offset(
            0,
            18 * (1 - value),
          ),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding:
        const EdgeInsets.fromLTRB(
          14,
          4,
          14,
          7,
        ),
        child: Material(
          color: _surfaceColor,
          borderRadius:
          BorderRadius.circular(
            22,
          ),
          child: InkWell(
            onTap:
            forumId.isEmpty
                ? null
                : () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration:
                  const Duration(
                    milliseconds:
                    320,
                  ),
                  reverseTransitionDuration:
                  const Duration(
                    milliseconds:
                    250,
                  ),
                  pageBuilder:
                      (
                      context,
                      animation,
                      secondaryAnimation,
                      ) =>
                      ForumScreen(
                        forumId:
                        forumId,
                        forumTitle:
                        title,
                      ),
                  transitionsBuilder:
                      (
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
                      end:
                      Offset.zero,
                    ).chain(
                      CurveTween(
                        curve:
                        Curves
                            .easeOutCubic,
                      ),
                    );

                    final fade =
                    CurvedAnimation(
                      parent:
                      animation,
                      curve:
                      Curves.easeOut,
                    );

                    return SlideTransition(
                      position:
                      animation
                          .drive(
                        slide,
                      ),
                      child:
                      FadeTransition(
                        opacity:
                        fade,
                        child:
                        child,
                      ),
                    );
                  },
                ),
              );
            },
            borderRadius:
            BorderRadius.circular(
              22,
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
              const EdgeInsets.all(
                15,
              ),
              decoration:
              BoxDecoration(
                borderRadius:
                BorderRadius.circular(
                  22,
                ),
                border:
                Border.all(
                  color: _borderColor,
                  width: 0.7,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black
                        .withOpacity(
                      _isDarkMode
                          ? 0.12
                          : 0.025,
                    ),
                    blurRadius: 12,
                    offset:
                    const Offset(
                      0,
                      4,
                    ),
                    spreadRadius: -3,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      _buildForumIcon(),
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
                              title.isEmpty
                                  ? 'Без названия'
                                  : title,
                              maxLines: 2,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              TextStyle(
                                color:
                                _textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing:
                                -0.25,
                              ),
                            ),
                            if (creatorName
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                _buildCreatorLine(
                                  creatorName,
                                  desc,
                                ),
                                maxLines: 2,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style:
                                TextStyle(
                                  color:
                                  _subTextColor,
                                  fontSize:
                                  12.5,
                                  height:
                                  1.3,
                                  fontWeight:
                                  FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isCreator)
                        _buildForumMenu(
                          forumId,
                        ),
                    ],
                  ),

                  if (desc.isNotEmpty) ...[
                    const SizedBox(
                      height: 13,
                    ),
                    Container(
                      width:
                      double.infinity,
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        _cardBgColor,
                        borderRadius:
                        BorderRadius.circular(
                          13,
                        ),
                      ),
                      child: Text(
                        desc,
                        maxLines: 2,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style: TextStyle(
                          color:
                          _subTextColor,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],

                  if (lastMsg.isNotEmpty) ...[
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      padding:
                      const EdgeInsets
                          .fromLTRB(
                        12,
                        10,
                        12,
                        10,
                      ),
                      decoration:
                      BoxDecoration(
                        color: _accent
                            .withOpacity(
                          0.035,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          13,
                        ),
                        border:
                        Border.all(
                          color: _accent
                              .withOpacity(
                            0.055,
                          ),
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration:
                            BoxDecoration(
                              color:
                              _accent,
                              shape:
                              BoxShape.circle,
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              lastMsg,
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              TextStyle(
                                color:
                                _subTextColor,
                                fontSize:
                                12.5,
                                height:
                                1.2,
                              ),
                            ),
                          ),
                          if (lastTime !=
                              null) ...[
                            const SizedBox(
                              width: 8,
                            ),
                            Text(
                              _formatTime(
                                lastTime,
                              ),
                              style:
                              TextStyle(
                                color:
                                _mutedColor,
                                fontSize:
                                10.5,
                                fontWeight:
                                FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 11,
                  ),

                  Row(
                    children: [
                      _buildMetaItem(
                        icon:
                        Icons.people_outline_rounded,
                        value:
                        '$participantCount',
                      ),
                      const SizedBox(
                        width: 15,
                      ),
                      _buildMetaItem(
                        icon:
                        Icons
                            .chat_bubble_outline_rounded,
                        value:
                        'Обсуждение',
                      ),
                      const Spacer(),
                      Icon(
                        Icons
                            .chevron_right_rounded,
                        size: 19,
                        color:
                        _mutedColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForumIcon() {
    return Container(
      width: 46,
      height: 46,
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
            _accentDeep,
          ],
        ),
        borderRadius:
        BorderRadius.circular(
          15,
        ),
        boxShadow: [
          BoxShadow(
            color:
            _accent.withOpacity(
              0.16,
            ),
            blurRadius: 12,
            offset:
            const Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child: const Icon(
        Icons.forum_rounded,
        color: Colors.white,
        size: 21,
      ),
    );
  }

  String _buildCreatorLine(
      String creatorName,
      String desc,
      ) {
    if (desc.isEmpty) {
      return creatorName;
    }

    return creatorName;
  }

  Widget _buildForumMenu(
      String forumId,
      ) {
    return PopupMenuButton<void>(
      tooltip: 'Действия',
      color: _surfaceElevatedColor,
      elevation: 10,
      padding:
      EdgeInsets.zero,
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
          15,
        ),
      ),
      icon: Icon(
        Icons
            .more_horiz_rounded,
        color:
        _subTextColor,
        size: 21,
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem<void>(
          height: 48,
          onTap: () =>
              _deleteForum(
                forumId,
              ),
          child: const Row(
            children: [
              Icon(
                Icons
                    .delete_outline_rounded,
                color:
                Colors.redAccent,
                size: 19,
              ),
              SizedBox(
                width: 9,
              ),
              Text(
                'Удалить',
                style: TextStyle(
                  color:
                  Colors.redAccent,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String value,
  }) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Icon(
          icon,
          color:
          _mutedColor,
          size: 15,
        ),
        const SizedBox(
          width: 5,
        ),
        Text(
          value,
          style:
          TextStyle(
            color:
            _mutedColor,
            fontSize:
            11.5,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------
  // Time
  // --------------------------------------------------------------

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
}