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
    } catch (e) {}
  }

  Future<void> _cacheForums() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_forums));
    } catch (e) {}
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
    } catch (e) {
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
        title: const Text('Создать обсуждение'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Тема'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать обсуждение')),
        );
      }
    }
  }

  void _deleteForum(String forumId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить обсуждение?'),
        content: const Text('Это действие нельзя отменить'),
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
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "delete-forum", "forum_id": forumId, "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      _loadForums();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить обсуждение')),
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'create_forum',
        onPressed: _createForum,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add_rounded),
      ),
      body: _forums.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: () async {
          _retryCount = 0;
          _loadError = null;
          await _loadForums();
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: ListView.builder(
            key: ValueKey(_forums.length),
            padding: const EdgeInsets.only(top: 8, bottom: 80),
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
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
            ),
            title: Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            subtitle: Container(
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
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
              color: Colors.orange.withOpacity(0.1),
            ),
            child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.orange),
          ),
          const SizedBox(height: 16),
          Text(_loadError!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
              color: Colors.orange.withOpacity(0.1),
            ),
            child: const Icon(Icons.forum_rounded, size: 48, color: Colors.orange),
          ),
          const SizedBox(height: 16),
          const Text(
            'Нет обсуждений',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте первое обсуждение!',
            style: TextStyle(color: Colors.grey),
          ),
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
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.forum_rounded, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$creatorName${desc.isNotEmpty ? " • ${desc.length > 50 ? '${desc.substring(0, 50)}...' : desc}" : ""}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (isCreator)
                      PopupMenuButton(
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
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
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ),
                        if (lastTime != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(lastTime),
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people_rounded, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      '$participantCount участников',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
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