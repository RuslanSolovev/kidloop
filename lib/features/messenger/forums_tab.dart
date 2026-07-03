// forums_tab.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'forum_screen.dart';

class ForumsTab extends StatefulWidget {
  const ForumsTab({super.key});

  @override
  State<ForumsTab> createState() => _ForumsTabState();
}

class _ForumsTabState extends State<ForumsTab> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _forums = [];
  bool _loading = true;
  String? _currentUserId;
  String? _currentUserName;
  Timer? _refreshTimer;
  int _retryCount = 0;
  String? _loadError;

  static const String forumApiUrl = 'https://functions.yandexcloud.net/d4en6mi363fq4o5js5ee';
  static const String _cacheKey = 'forums_cache';

  @override
  bool get wantKeepAlive => true;

  // 🔥 Используем Theme напрямую — автоматически обновляется при смене темы
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200;
  Color get _cardBgColor => _isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50;

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
      _loadForums();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadForums());
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _currentUserName = prefs.getString('user_name') ?? 'Пользователь';

    await _loadCachedForums();
    await _loadForums();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCachedForums() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as List;
        if (mounted && _forums.isEmpty) {
          setState(() {
            _forums = data.cast<Map<String, dynamic>>();
            _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _cacheForums() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_forums));
    } catch (_) {}
  }

  Future<void> _loadForums() async {
    try {
      final response = await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list-forums"}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() {
          _forums = (data['forums'] as List).cast<Map<String, dynamic>>();
          _retryCount = 0;
          _loadError = null;
          _loading = false;
        });
        await _cacheForums();
      } else {
        _handleLoadError();
      }
    } catch (_) {
      _handleLoadError();
    }
  }

  void _handleLoadError() {
    _retryCount++;
    if (_forums.isEmpty && mounted) {
      setState(() {
        _loading = false;
        if (_retryCount >= 3) {
          _loadError = 'Не удалось загрузить форумы';
        }
      });
    }

    if (_retryCount <= 5 && mounted) {
      final delay = Duration(seconds: 2 * _retryCount);
      Future.delayed(delay, () {
        if (mounted) _loadForums();
      });
    }
  }

  void _createForum() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Создать обсуждение', style: TextStyle(color: _textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                labelText: 'Тема',
                labelStyle: TextStyle(color: _subTextColor),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                labelText: 'Описание',
                labelStyle: TextStyle(color: _subTextColor),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: _subTextColor)),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Создать', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "create-forum",
          "creator_id": _currentUserId,
          "creator_name": _currentUserName,
          "title": titleCtrl.text.trim(),
          "description": descCtrl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      _retryCount = 0;
      _loadForums();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось создать обсуждение'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _deleteForum(String forumId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить обсуждение?', style: TextStyle(color: _textColor)),
        content: Text('Это действие нельзя отменить', style: TextStyle(color: _subTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: _subTextColor)),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "delete-forum", "forum_id": forumId, "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      _loadForums();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось удалить обсуждение'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading && _forums.isEmpty) {
      return _buildLoadingSkeleton();
    }

    if (_forums.isEmpty && _loadError != null) {
      return _buildErrorState();
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70), // 🔥 Отступ от нижней навигации
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x66FF9800),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'create_forum',
            onPressed: _createForum,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ),
      body: _forums.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        color: Colors.orange,
        backgroundColor: _surfaceColor,
        onRefresh: () async {
          _retryCount = 0;
          _loadError = null;
          await _loadForums();
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: ListView.builder(
            key: ValueKey(_forums.length),
            padding: const EdgeInsets.only(top: 8, bottom: 100), // 🔥 Увеличенный отступ снизу
            itemCount: _forums.length,
            itemBuilder: (context, index) {
              return _buildForumCard(_forums[index], index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 12,
                          width: 150,
                          decoration: BoxDecoration(
                            color: _isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.orange),
          ),
          const SizedBox(height: 16),
          Text(_loadError!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textColor)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _loading = true;
                _loadError = null;
                _retryCount = 0;
              });
              _loadForums();
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.forum_rounded, size: 48, color: Colors.orange),
          ),
          const SizedBox(height: 16),
          Text('Нет обсуждений', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _textColor)),
          const SizedBox(height: 8),
          Text('Создайте первое обсуждение!', style: TextStyle(color: _subTextColor)),
        ],
      ),
    );
  }

  Widget _buildForumCard(Map<String, dynamic> forum, int index) {
    final forumId = forum['forum_id'] ?? '';
    final title = forum['title'] ?? '';
    final desc = forum['description'] ?? '';
    final creatorName = forum['creator_name'] ?? '';
    final participantCount = forum['participant_count'] ?? 0;
    final lastMsg = forum['last_message'] ?? '';
    final lastTime = forum['last_time'];
    final isCreator = forum['creator_id'] == _currentUserId;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorderColor),
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
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => ForumScreen(
                  forumId: forumId,
                  forumTitle: title,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  );
                },
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.forum_rounded, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$creatorName${desc.isNotEmpty ? " • ${desc.length > 50 ? '${desc.substring(0, 50)}...' : desc}" : ""}',
                            style: TextStyle(color: _subTextColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (isCreator)
                      PopupMenuButton(
                        color: _surfaceColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text('Удалить', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                            onTap: () => _deleteForum(forumId),
                          ),
                        ],
                      ),
                  ],
                ),
                if (lastMsg.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _cardBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _subTextColor, fontSize: 13),
                          ),
                        ),
                        if (lastTime != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(lastTime),
                            style: TextStyle(color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people_rounded, size: 16, color: _subTextColor),
                    const SizedBox(width: 4),
                    Text(
                      '$participantCount участников',
                      style: TextStyle(color: _subTextColor, fontSize: 12),
                    ),
                  ],
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

      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return DateFormat('HH:mm').format(dt);
      } else if (dt.year == now.year) {
        return DateFormat('dd MMM', 'ru').format(dt);
      } else {
        return DateFormat('dd.MM.yy').format(dt);
      }
    } catch (_) {
      return '';
    }
  }
}