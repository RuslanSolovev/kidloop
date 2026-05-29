import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ChatMessage {
  final String messageId;
  final String offerId;
  final String senderId;
  final String senderName;
  final String text;
  final String replyToId;
  final String replyToText;
  final String replyToName;
  final bool isEdited;
  final String createdAt;

  ChatMessage({
    required this.messageId,
    required this.offerId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.replyToId = '',
    this.replyToText = '',
    this.replyToName = '',
    this.isEdited = false,
    this.createdAt = '',
  });
}

class ChatWidget extends StatefulWidget {
  final String offerId;

  const ChatWidget({super.key, required this.offerId});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  String? _currentUserName;
  Timer? _pollTimer;
  String? _replyToId;
  String? _replyToText;
  String? _replyToName;
  String? _editingId;

  static const String apiUrl = 'https://functions.yandexcloud.net/d4empovmpsth9ljl5s56';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_id');
      _currentUserName = prefs.getString('user_name') ?? 'Пользователь';
    });
  }

  Future<void> _loadMessages() async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list", "offer_id": widget.offerId}),
      );
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final msgs = (data['messages'] as List).map((m) => ChatMessage(
          messageId: m['message_id'] ?? '',
          offerId: m['offer_id'] ?? '',
          senderId: m['sender_id'] ?? '',
          senderName: m['sender_name'] ?? '',
          text: m['text'] ?? '',
          replyToId: m['reply_to_id'] ?? '',
          replyToText: m['reply_to_text'] ?? '',
          replyToName: m['reply_to_name'] ?? '',
          isEdited: m['is_edited'] ?? false,
          createdAt: m['created_at'] ?? '',
        )).toList();

        if (mounted) {
          setState(() => _messages.clear());
          _messages.addAll(msgs);
          _scrollToBottom();
        }
      }
    } catch (e) {}
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final msg = {
      "action": "send",
      "offer_id": widget.offerId,
      "sender_id": _currentUserId,
      "sender_name": _currentUserName,
      "text": text,
    };

    if (_replyToId != null) {
      msg["reply_to_id"] = _replyToId!;
      msg["reply_to_text"] = _replyToText!;
      msg["reply_to_name"] = _replyToName!;
    }

    await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(msg));

    _textController.clear();
    _cancelReply();
    _cancelEdit();
    _loadMessages();
  }

  Future<void> _deleteMessage(String messageId) async {
    await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      "action": "delete", "message_id": messageId, "sender_id": _currentUserId,
    }));
    _loadMessages();
  }

  Future<void> _editMessage(String messageId, String newText) async {
    await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      "action": "edit", "message_id": messageId, "sender_id": _currentUserId, "text": newText,
    }));
    _loadMessages();
  }

  void _startReply(ChatMessage msg) {
    setState(() {
      _replyToId = msg.messageId;
      _replyToText = msg.text;
      _replyToName = msg.senderName;
      _editingId = null;
    });
  }

  void _startEdit(ChatMessage msg) {
    setState(() {
      _editingId = msg.messageId;
      _textController.text = msg.text;
      _replyToId = null;
      _replyToText = null;
      _replyToName = null;
    });
  }

  void _cancelReply() {
    setState(() { _replyToId = null; _replyToText = null; _replyToName = null; });
  }

  void _cancelEdit() {
    setState(() { _editingId = null; _textController.clear(); });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMine = (String senderId) => senderId == _currentUserId;

    return Column(
      children: [
        // Список сообщений
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[_messages.length - 1 - index];
              final mine = isMine(msg.senderId);

              return GestureDetector(
                onLongPress: () => _showMessageMenu(context, msg, mine),
                child: Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: mine ? Colors.orange.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!mine)
                          Text(msg.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                        // Цитата
                        if (msg.replyToId.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(6),
                              border: const Border(left: BorderSide(color: Colors.orange, width: 3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(msg.replyToName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(msg.replyToText, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        Text(msg.text, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_formatTime(msg.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            if (mine) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.check, size: 12, color: Colors.grey.shade600),
                            ],
                            if (msg.isEdited) ...[
                              const SizedBox(width: 4),
                              Text('изм.', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Полоса ответа/редактирования
        if (_replyToId != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                const Icon(Icons.reply, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ответ $_replyToName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(_replyToText ?? '', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _cancelReply),
              ],
            ),
          ),
        if (_editingId != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.edit, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Редактирование', style: TextStyle(fontSize: 12)),
                const Spacer(),
                TextButton(onPressed: _cancelEdit, child: const Text('Отмена')),
              ],
            ),
          ),

        // Поле ввода
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: _editingId != null ? 'Редактировать...' : 'Сообщение...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (_) {
                    if (_editingId != null) {
                      _editMessage(_editingId!, _textController.text.trim());
                    } else {
                      _sendMessage();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.orange,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () {
                    if (_editingId != null) {
                      _editMessage(_editingId!, _textController.text.trim());
                    } else {
                      _sendMessage();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMessageMenu(BuildContext context, ChatMessage msg, bool mine) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Редактировать'),
                onTap: () { Navigator.pop(ctx); _startEdit(msg); },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _deleteMessage(msg.messageId); },
              ),
            ],
            if (!mine)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Ответить'),
                onTap: () { Navigator.pop(ctx); _startReply(msg); },
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}