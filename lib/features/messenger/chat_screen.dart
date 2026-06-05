import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; // если нужно показывать аватар

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherName;
  final String? otherAvatar; // для Hero-анимации

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherName,
    this.otherAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;
  Timer? _pollTimer;
  int _retryCount = 0;
  bool _sending = false;
  bool _loadingMessages = true;
  String? _loadError;

  static const String chatApiUrl =
      'https://functions.yandexcloud.net/d4es79s8locoa8ul3pe3';

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
    await _loadMessages();
    _scrollToBottom();
  }

  Future<void> _loadMessages() async {
    if (widget.chatId.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-messages", "chat_id": widget.chatId}),
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
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "send-message",
          "chat_id": widget.chatId,
          "sender_id": _currentUserId,
          "text": text,
        }),
      ).timeout(const Duration(seconds: 10));
      _textController.clear();
      await _loadMessages();
      _scrollToBottom();
    } catch (e) {
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
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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

  // ----- UI Helpers -----
  Widget _buildLoadingShimmer() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        final isLeft = index % 2 == 0;
        return Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: _ShimmerBubble(isLeft: isLeft),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.otherAvatar != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Hero(
                  tag: 'avatar_${widget.otherUserId}',
                  child: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(widget.otherAvatar!),
                    radius: 18,
                  ),
                ),
              ),
            Text(widget.otherName),
          ],
        ),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [colorScheme.surface, colorScheme.surfaceVariant]
                : [const Color(0xFFF5F5F5), const Color(0xFFE0E0E0)],
          ),
        ),
        child: Column(
          children: [
            // Загрузка скелетонов
            if (_loadingMessages && _messages.isEmpty)
              Expanded(child: _buildLoadingShimmer()),

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

            // Список сообщений
            if (!_loadingMessages || _messages.isNotEmpty)
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                    child: Text('Нет сообщений. Напишите первым!',
                        style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[_messages.length - 1 - index];
                    final isMine = msg['sender_id'] == _currentUserId;
                    return _MessageBubble(
                      isMine: isMine,
                      senderName: msg['sender_name'] ?? '',
                      text: msg['text'] ?? '',
                      time: _formatTime(msg['created_at'] ?? ''),
                    );
                  },
                ),
              ),

            // Поле ввода
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

// --- Вспомогательные виджеты (приватные) ---

class _MessageBubble extends StatelessWidget {
  final bool isMine;
  final String senderName;
  final String text;
  final String time;

  const _MessageBubble({
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
        ? [colorScheme.primary, colorScheme.primaryContainer]
        : [colorScheme.surfaceVariant, colorScheme.surfaceVariant];
    final textColor = isMine ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final shadowColor = isMine
        ? colorScheme.primary.withOpacity(0.3)
        : Colors.black26;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
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
            bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
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
                        color: colorScheme.primary)),
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

// Простой скелетон для имитации загрузки сообщений
class _ShimmerBubble extends StatefulWidget {
  final bool isLeft;
  const _ShimmerBubble({required this.isLeft});

  @override
  State<_ShimmerBubble> createState() => _ShimmerBubbleState();
}

class _ShimmerBubbleState extends State<_ShimmerBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final color = colorScheme.surfaceVariant.withOpacity(_animation.value);
        final alignment =
        widget.isLeft ? Alignment.centerLeft : Alignment.centerRight;
        final width = 100.0 + (_animation.value * 40);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Align(
            alignment: alignment,
            child: Container(
              width: width,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}