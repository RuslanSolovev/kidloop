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

  static const String forumApiUrl =
      'https://functions.yandexcloud.net/d4en6mi363fq4o5js5ee';

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
    await _loadMessages();
    _scrollToBottom();
  }

  Future<void> _loadMessages() async {
    if (widget.forumId.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {"action": "get-forum-messages", "forum_id": widget.forumId}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() {
          _messages = (data['messages'] as List).cast<Map<String, dynamic>>();
          _retryCount = 0;
          _loadingMessages = false;
          _loadError = null;
        });
      } else {
        if (_messages.isEmpty) setState(() => _loadingMessages = false);
        _retryLoad();
      }
    } catch (e) {
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
    if (_retryCount <= 5 && mounted) {
      Future.delayed(const Duration(seconds: 2), _loadMessages);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    try {
      await http.post(
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
      _textController.clear();
      await _loadMessages();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Не удалось отправить. Попробуйте ещё раз.')),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _messages.isNotEmpty) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forumTitle),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [colorScheme.surface, colorScheme.surfaceVariant]
                : [const Color(0xFFF9F9F9), const Color(0xFFE8E8E8)],
          ),
        ),
        child: Column(
          children: [
            if (_loadingMessages && _messages.isEmpty)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
              ),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off, size: 64, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text(_loadError!,
                            style: TextStyle(color: colorScheme.error)),
                        const SizedBox(height: 8),
                        Text('Нажмите чтобы повторить',
                            style: TextStyle(
                                color: colorScheme.primary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_loadingMessages || _messages.isNotEmpty)
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                    child: Text('Нет сообщений. Напишите первым!',
                        style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[_messages.length - 1 - index];
                    final isMine = msg['sender_id'] == _currentUserId;
                    return _ForumMessageBubble(
                      isMine: isMine,
                      senderName: msg['sender_name'] ?? '',
                      text: msg['text'] ?? '',
                      time: _formatTime(msg['created_at'] ?? ''),
                    );
                  },
                ),
              ),
            _MessageInputBar(
              controller: _textController,
              sending: _sending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

// Виджет пузыря форума (аналогичен личному чату)
class _ForumMessageBubble extends StatelessWidget {
  final bool isMine;
  final String senderName;
  final String text;
  final String time;

  const _ForumMessageBubble({
    required this.isMine,
    required this.senderName,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alignment = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final gradientColors = isMine
        ? [colorScheme.tertiary, colorScheme.tertiaryContainer]
        : [colorScheme.surfaceVariant, colorScheme.surfaceVariant];
    final textColor = isMine
        ? colorScheme.onTertiary
        : colorScheme.onSurfaceVariant;
    final shadowColor = isMine
        ? colorScheme.tertiary.withOpacity(0.3)
        : Colors.black12;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
            isMine ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
            isMine ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            if (!isMine && senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(senderName,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.tertiary)),
              ),
            Text(text, style: TextStyle(fontSize: 16, color: textColor)),
            const SizedBox(height: 4),
            Text(time,
                style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

// Поле ввода — то же самое, что и в личном чате, вынесено для переиспользования
// (можно вынести в отдельный файл, здесь оставим дубликат)
class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _MessageInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        top: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 5,
              minLines: 1,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Сообщение...',
                filled: true,
                fillColor: colorScheme.surfaceVariant,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedScale(
            scale: sending ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.primary,
              child: IconButton(
                icon: sending
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: sending ? null : onSend,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}