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

class _ForumsTabState extends State<ForumsTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _forums = [];
  bool _loading = true;
  String? _currentUserId;
  String? _currentUserName;
  Timer? _refreshTimer;
  int _retryCount = 0;
  String? _loadError;

  static const String forumApiUrl =
      'https://functions.yandexcloud.net/d4en6mi363fq4o5js5ee';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadForums());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _currentUserName = prefs.getString('user_name') ?? 'Пользователь';
    await _loadForums();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadForums() async {
    try {
      final response = await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list-forums"}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() {
          _forums = (data['forums'] as List).cast<Map<String, dynamic>>();
          _retryCount = 0;
          _loadError = null;
        });
      } else {
        _retryLoad();
      }
    } catch (e) {
      _retryLoad();
    }
  }

  void _retryLoad() {
    _retryCount++;
    if (_retryCount <= 5 && mounted) {
      if (_retryCount >= 3) {
        setState(() => _loadError = 'Проблемы с загрузкой. Пробуем снова...');
      }
      Future.delayed(const Duration(seconds: 2), _loadForums);
    } else if (_retryCount > 5 && mounted) {
      setState(() =>
      _loadError = 'Не удалось загрузить форум. Потяните чтобы обновить.');
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
                decoration: const InputDecoration(labelText: 'Тема')),
            const SizedBox(height: 8),
            TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Создать')),
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
      ).timeout(const Duration(seconds: 10));
      _retryCount = 0;
      _loadForums();
    } catch (e) {}
  }

  void _deleteForum(String forumId) async {
    try {
      await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "delete-forum",
          "forum_id": forumId,
          "user_id": _currentUserId
        }),
      ).timeout(const Duration(seconds: 10));
      _loadForums();
    } catch (e) {}
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      if (dt.day == now.day) return DateFormat('HH:mm').format(dt);
      return DateFormat('dd.MM.yy').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_forums.isEmpty && _loadError != null) {
      return _buildErrorView();
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'create_forum',
        onPressed: _createForum,
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add),
      ),
      body: _forums.isEmpty
          ? _buildEmptyView()
          : RefreshIndicator(
        onRefresh: () async {
          _retryCount = 0;
          _loadError = null;
          await _loadForums();
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _forums.length,
          itemBuilder: (context, index) {
            final f = _forums[index];
            return _ForumCard(
              forum: f,
              currentUserId: _currentUserId!,
              onDelete: _deleteForum,
              formatTime: _formatTime,
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _retryCount = 0;
            _loadError = null;
          });
          _loadForums();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_loadError!, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 8),
            Text('Нажмите чтобы повторить',
                style: TextStyle(color: colorScheme.primary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Нет обсуждений',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Создайте первое обсуждение!',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ForumCard extends StatelessWidget {
  final Map<String, dynamic> forum;
  final String currentUserId;
  final Function(String) onDelete;
  final String Function(String?) formatTime;

  const _ForumCard({
    required this.forum,
    required this.currentUserId,
    required this.onDelete,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final forumId = forum['forum_id'] ?? '';
    final title = forum['title'] ?? '';
    final desc = forum['description'] ?? '';
    final creatorName = forum['creator_name'] ?? '';
    final participantCount = forum['participant_count'] ?? 0;
    final lastMsg = forum['last_message'] ?? '';
    final lastTime = forum['last_time'];
    final isCreator = forum['creator_id'] == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ForumScreen(
                  forumId: forumId,
                  forumTitle: title,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.tertiaryContainer,
                  child: Text('$participantCount',
                      style: TextStyle(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        '$creatorName${desc.isNotEmpty ? " • $desc" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6)),
                      ),
                      if (lastMsg.isNotEmpty)
                        Text(lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.5))),
                    ],
                  ),
                ),
                if (lastTime != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(formatTime(lastTime),
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.5))),
                  ),
                if (isCreator)
                  PopupMenuButton(
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        child: const Text('Удалить',
                            style: TextStyle(color: Colors.red)),
                        onTap: () => onDelete(forumId),
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
}