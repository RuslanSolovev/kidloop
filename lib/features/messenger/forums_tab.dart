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

  static const String forumApiUrl = 'https://functions.yandexcloud.net/d4en6mi363fq4o5js5ee';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadForums());
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
    print("🟢 ForumsTab: userId=$_currentUserId, userName=$_currentUserName");
    await _loadForums();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadForums() async {
    try {
      print("🔄 ForumsTab: loading forums...");
      final response = await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list-forums"}),
      ).timeout(const Duration(seconds: 10));

      print("📦 ForumsTab: status=${response.statusCode}, body=${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");
      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() {
          _forums = (data['forums'] as List).cast<Map<String, dynamic>>();
          _retryCount = 0;
          _loadError = null;
        });
        print("✅ ForumsTab: loaded ${_forums.length} forums");
      } else {
        print("⚠️ ForumsTab: server returned ok=false or null data");
        _retryLoad();
      }
    } catch (e) {
      print("🔴 ForumsTab error: $e");
      _retryLoad();
    }
  }

  void _retryLoad() {
    _retryCount++;
    print("🔄 ForumsTab: retry $_retryCount/5");
    if (_retryCount <= 5 && mounted) {
      if (_retryCount >= 3) {
        setState(() => _loadError = 'Проблемы с загрузкой. Пробуем снова...');
      }
      Future.delayed(const Duration(seconds: 2), _loadForums);
    } else if (_retryCount > 5 && mounted) {
      setState(() => _loadError = 'Не удалось загрузить форум. Потяните чтобы обновить.');
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
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Тема')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Описание'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      print("🟢 ForumsTab: creating forum...");
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
    } catch (e) {
      print("🔴 ForumsTab: create forum error: $e");
    }
  }

  void _deleteForum(String forumId) async {
    try {
      print("🟢 ForumsTab: deleting forum $forumId");
      await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "delete-forum", "forum_id": forumId, "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 10));
      _loadForums();
    } catch (e) {
      print("🔴 ForumsTab: delete forum error: $e");
    }
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

    if (_loading) return const Center(child: CircularProgressIndicator(color: Colors.orange));

    if (_forums.isEmpty && _loadError != null) {
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_loadError!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Нажмите чтобы повторить', style: TextStyle(color: Colors.orange, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'create_forum',
        onPressed: _createForum,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
      body: _forums.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет обсуждений', style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 4),
            Text('Создайте первое обсуждение!', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          print("🔄 ForumsTab: pull to refresh");
          _retryCount = 0;
          _loadError = null;
          await _loadForums();
        },
        child: ListView.builder(
          itemCount: _forums.length,
          itemBuilder: (context, index) {
            final f = _forums[index];
            final forumId = f['forum_id'] ?? '';
            final title = f['title'] ?? '';
            final desc = f['description'] ?? '';
            final creatorName = f['creator_name'] ?? '';
            final participantCount = f['participant_count'] ?? 0;
            final lastMsg = f['last_message'] ?? '';
            final lastTime = f['last_time'];
            final isCreator = f['creator_id'] == _currentUserId;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Text('${participantCount}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$creatorName${desc.isNotEmpty ? " • $desc" : ""}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (lastMsg.isNotEmpty)
                      Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lastTime != null)
                      Text(_formatTime(lastTime),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
              ),
            );
          },
        ),
      ),
    );
  }
}