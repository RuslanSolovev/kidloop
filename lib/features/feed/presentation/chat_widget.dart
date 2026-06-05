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
  final GlobalKey _messageListKey = GlobalKey();
  String? _currentUserId;
  String? _currentUserName;
  Timer? _pollTimer;
  String? _replyToId;
  String? _replyToText;
  String? _replyToName;
  String? _editingId;
  bool _isLoading = true;

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
          setState(() {
            _messages.clear();
            _messages.addAll(msgs);
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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

    _textController.clear();
    _cancelReply();
    _cancelEdit();

    await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(msg));
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
    FocusScope.of(context).requestFocus();
  }

  void _startEdit(ChatMessage msg) {
    setState(() {
      _editingId = msg.messageId;
      _textController.text = msg.text;
      _replyToId = null;
      _replyToText = null;
      _replyToName = null;
    });
    FocusScope.of(context).requestFocus();
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
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Color _getAvatarColor(String id) {
    final colors = [
      Colors.deepPurple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.green,
      Colors.red,
      Colors.blue,
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMine = (String senderId) => senderId == _currentUserId;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Заголовок чата
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Обсуждение',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isLoading) ...[
                  const Spacer(),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Список сообщений
          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            )
                : _messages.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Начните обсуждение',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              key: _messageListKey,
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[_messages.length - 1 - index];
                final mine = isMine(msg.senderId);
                final showAvatar = index == _messages.length - 1 ||
                    _messages[_messages.length - 1 - index - 1].senderId != msg.senderId;

                return Padding(
                  padding: EdgeInsets.only(
                    top: showAvatar && index != _messages.length - 1 ? 8 : 2,
                    bottom: 2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!mine && showAvatar) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _getAvatarColor(msg.senderId),
                          child: Text(
                            _getInitials(msg.senderName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (!mine) ...[
                        const SizedBox(width: 40),
                      ],
                      Flexible(
                        child: GestureDetector(
                          onLongPress: () => _showMessageMenu(context, msg, mine),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: mine
                                  ? LinearGradient(
                                colors: [
                                  theme.colorScheme.primaryContainer,
                                  theme.colorScheme.primaryContainer.withOpacity(0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                                  : null,
                              color: mine ? null : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(mine ? 18 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine && showAvatar)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      msg.senderName,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: _getAvatarColor(msg.senderId),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (msg.replyToId.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? Colors.white.withOpacity(0.3)
                                          : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border(
                                        left: BorderSide(
                                          color: mine
                                              ? Colors.white.withOpacity(0.8)
                                              : theme.colorScheme.primary,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.replyToName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: mine ? Colors.white70 : theme.colorScheme.primary,
                                          ),
                                        ),
                                        Text(
                                          msg.replyToText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: mine ? Colors.white60 : Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: mine
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurface,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatTime(msg.createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: mine
                                            ? theme.colorScheme.onPrimaryContainer.withOpacity(0.6)
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                    if (mine) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all,
                                        size: 14,
                                        color: theme.colorScheme.onPrimaryContainer.withOpacity(0.6),
                                      ),
                                    ],
                                    if (msg.isEdited) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        'изм.',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: mine
                                              ? theme.colorScheme.onPrimaryContainer.withOpacity(0.6)
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (mine && showAvatar) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _getAvatarColor(msg.senderId),
                          child: Text(
                            _getInitials(msg.senderName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Полоса ответа
          if (_replyToId != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                border: Border(
                  top: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ответ $_replyToName',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          _replyToText ?? '',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: theme.colorScheme.primary),
                    onPressed: _cancelReply,
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

          // Полоса редактирования
          if (_editingId != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                border: Border(
                  top: BorderSide(color: Colors.amber.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Редактирование сообщения',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelEdit,
                    child: Text('Отмена', style: TextStyle(color: Colors.amber.shade700)),
                  ),
                ],
              ),
            ),

          // Поле ввода
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    onSubmitted: (_) => _handleSend(),
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: _editingId != null ? 'Редактировать...' : 'Напишите сообщение...',
                      hintStyle: TextStyle(color: theme.colorScheme.outlineVariant),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _editingId != null ? Icons.check : Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _handleSend,
                    splashRadius: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSend() {
    if (_editingId != null) {
      final text = _textController.text.trim();
      if (text.isNotEmpty) {
        _editMessage(_editingId!, text);
      }
    } else {
      _sendMessage();
    }
  }

  void _showMessageMenu(BuildContext context, ChatMessage msg, bool mine) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (mine) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit, color: theme.colorScheme.primary, size: 20),
                  ),
                  title: const Text('Редактировать'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startEdit(msg);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  ),
                  title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmDialog(msg.messageId);
                  },
                ),
              ],
              if (!mine)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.reply, color: theme.colorScheme.tertiary, size: 20),
                  ),
                  title: const Text('Ответить'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startReply(msg);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить сообщение?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage(messageId);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDate = DateTime(dt.year, dt.month, dt.day);

      if (msgDate == today) {
        return DateFormat('HH:mm').format(dt);
      } else if (msgDate == today.subtract(const Duration(days: 1))) {
        return 'Вчера ${DateFormat('HH:mm').format(dt)}';
      } else {
        return DateFormat('dd.MM HH:mm').format(dt);
      }
    } catch (_) {
      return '';
    }
  }
}