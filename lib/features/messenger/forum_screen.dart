import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ForumScreen extends StatefulWidget {
  final String forumId;
  final String forumTitle;

  const ForumScreen({super.key, required this.forumId, required this.forumTitle});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;
  String? _currentUserName;
  Timer? _pollTimer;
  int _retryCount = 0;
  bool _sending = false;
  bool _loadingMessages = true;
  String? _loadError;

  static const String forumApiUrl = 'https://functions.yandexcloud.net/d4en6mi363fq4o5js5ee';

  @override
  void initState() {
    super.initState();
    _init();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _currentUserName = prefs.getString('user_name') ?? 'Пользователь';
    print("🟢 ForumScreen: userId=$_currentUserId, userName=$_currentUserName");
    await _loadMessages();
    _scrollToBottom();
  }

  Future<void> _loadMessages() async {
    if (widget.forumId.isEmpty) {
      print("🔴 ForumScreen: forumId is empty");
      return;
    }

    try {
      print("🔄 ForumScreen: loading messages for ${widget.forumId}...");
      final response = await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-forum-messages", "forum_id": widget.forumId}),
      ).timeout(const Duration(seconds: 10));

      print("📦 ForumScreen: status=${response.statusCode}, body=${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");
      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() {
          _messages = (data['messages'] as List).cast<Map<String, dynamic>>();
          _retryCount = 0;
          _loadingMessages = false;
          _loadError = null;
        });
        print("✅ ForumScreen: loaded ${_messages.length} messages");
      } else {
        if (_messages.isEmpty) {
          setState(() => _loadingMessages = false);
        }
        _retryLoad();
      }
    } catch (e) {
      print("🔴 ForumScreen error: $e");
      if (_messages.isEmpty) {
        setState(() {
          _loadingMessages = false;
          _loadError = 'Ошибка загрузки. Нажмите чтобы повторить.';
        });
      }
      _retryLoad();
    }
  }

  void _retryLoad() {
    _retryCount++;
    print("🔄 ForumScreen: retry $_retryCount/5");
    if (_retryCount <= 5 && mounted) {
      Future.delayed(const Duration(seconds: 2), _loadMessages);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      print("🟢 ForumScreen: sending message...");
      final response = await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "send-forum-message",
          "forum_id": widget.forumId,
          "sender_id": _currentUserId,
          "sender_name": _currentUserName,
          "text": text,
        }),
      ).timeout(const Duration(seconds: 10));

      print("📦 ForumScreen send: status=${response.statusCode}, body=${response.body}");
      _textController.clear();
      await _loadMessages();
      _scrollToBottom();
    } catch (e) {
      print("🔴 ForumScreen send error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить. Попробуйте ещё раз.')),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _messages.isNotEmpty) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.forumTitle)),
      body: Column(
        children: [
          // Индикатор загрузки
          if (_loadingMessages && _messages.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 16),
                    Text('Загрузка сообщений...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // Ошибка загрузки
          if (_loadError != null && _messages.isEmpty)
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _loadingMessages = true;
                      _loadError = null;
                      _retryCount = 0;
                    });
                    _loadMessages();
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
              ),
            ),

          // Список сообщений
          if (!_loadingMessages || _messages.isNotEmpty)
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('Нет сообщений. Напишите первым!'))
                  : ListView.builder(
                controller: _scrollController,
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[_messages.length - 1 - index];
                  final isMine = msg['sender_id'] == _currentUserId;
                  final senderName = msg['sender_name'] ?? '';
                  final text = msg['text'] ?? '';
                  final time = msg['created_at'] ?? '';

                  return Align(
                    alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isMine ? Colors.orange.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMine && senderName.isNotEmpty)
                            Text(senderName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text(text, style: const TextStyle(fontSize: 16)),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(_formatTime(time),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Поле ввода
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Сообщение...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: IconButton(
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }
}