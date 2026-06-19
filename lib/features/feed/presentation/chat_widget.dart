import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

class ChatMessage {
  final String messageId;
  final String offerId;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final String imageUrl;
  final String replyToId;
  final String replyToText;
  final String replyToImageUrl;
  final String replyToName;
  final String replyToAvatar;
  final bool isEdited;
  final String createdAt;

  ChatMessage({
    required this.messageId,
    required this.offerId,
    required this.senderId,
    this.senderName = '',
    this.senderAvatar = '',
    required this.text,
    this.imageUrl = '',
    this.replyToId = '',
    this.replyToText = '',
    this.replyToImageUrl = '',
    this.replyToName = '',
    this.replyToAvatar = '',
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
  String? _currentUserAvatar;
  Timer? _pollTimer;
  String? _replyToId;
  String? _replyToText;
  String? _replyToImageUrl;
  String? _replyToName;
  String? _replyToAvatar;
  String? _editingId;
  bool _isLoading = true;
  bool _sending = false;

  static const String apiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const String uploadApiUrl = 'https://functions.yandexcloud.net/d4e3c2me21eou683ic6d';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
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
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('user_id');
        _currentUserName = prefs.getString('user_name') ?? 'Пользователь';
        _currentUserAvatar = prefs.getString('avatar_url') ?? '';
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-messages", "chat_id": widget.offerId}),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        final msgs = (data['messages'] as List? ?? []).map((m) => ChatMessage(
          messageId: m['message_id'] ?? '',
          offerId: widget.offerId,
          senderId: m['sender_id'] ?? '',
          senderName: m['sender_name'] ?? '',
          senderAvatar: m['sender_avatar'] ?? '',
          text: m['text'] ?? '',
          imageUrl: m['image_url'] ?? '',
          replyToId: m['reply_to_message']?['message_id'] ?? '',
          replyToText: m['reply_to_message']?['text'] ?? '',
          replyToImageUrl: m['reply_to_message']?['image_url'] ?? '',
          replyToName: m['reply_to_message']?['sender_name'] ?? '',
          replyToAvatar: m['reply_to_message']?['sender_avatar'] ?? '',
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

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _textController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    final body = <String, dynamic>{
      "action": "send-message",
      "chat_id": widget.offerId,
      "sender_id": _currentUserId,
      "text": text,
    };

    if (imageUrl != null) body["image_url"] = imageUrl;
    if (_replyToId != null) body["reply_to"] = _replyToId;

    _textController.clear();
    _cancelReply();
    _cancelEdit();

    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
      _loadMessages();
    } catch (e) {}
  }

  // 🔥 Отправка фото
  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _sending = true);

    try {
      final bytes = await File(picked.path).readAsBytes();
      final base64 = base64Encode(bytes);

      final uploadResponse = await http.post(
        Uri.parse(uploadApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "upload",
          "file_name": "chat_${DateTime.now().millisecondsSinceEpoch}.jpg",
          "file_data": base64,
        }),
      ).timeout(const Duration(seconds: 20));

      final uploadData = jsonDecode(uploadResponse.body);
      if (uploadData['ok'] == true) {
        final uploadedUrl = uploadData['file_url'];
        await _sendMessage(imageUrl: uploadedUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка загрузки фото'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки фото'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "delete-message",
          "message_id": messageId,
          "user_id": _currentUserId,
          "chat_id": widget.offerId,
        }),
      ).timeout(const Duration(seconds: 5));
      _loadMessages();
    } catch (e) {}
  }

  Future<void> _editMessage(String messageId, String newText) async {
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "edit-message",
          "message_id": messageId,
          "sender_id": _currentUserId,
          "text": newText,
          "chat_id": widget.offerId,
        }),
      ).timeout(const Duration(seconds: 5));
      _loadMessages();
    } catch (e) {}
  }

  void _startReply(ChatMessage msg) {
    setState(() {
      _replyToId = msg.messageId;
      _replyToText = msg.text;
      _replyToImageUrl = msg.imageUrl;
      _replyToName = msg.senderName;
      _replyToAvatar = msg.senderAvatar;
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
      _replyToImageUrl = null;
      _replyToName = null;
    });
    FocusScope.of(context).requestFocus();
  }

  void _cancelReply() {
    setState(() { _replyToId = null; _replyToText = null; _replyToImageUrl = null; _replyToName = null; });
  }

  void _cancelEdit() {
    setState(() { _editingId = null; _textController.clear(); });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _messages.isNotEmpty) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 🔥 Полноэкранный просмотр изображения
  void _showFullImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 60, color: Colors.white54),
                      SizedBox(height: 8),
                      Text(
                        'Не удалось загрузить изображение',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, String name, {double radius = 16}) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (_, __) => _buildInitial(name, radius),
            errorWidget: (_, __, ___) => _buildInitial(name, radius),
          ),
        ),
      );
    }
    return _buildInitial(name, radius);
  }

  Widget _buildInitial(String name, double radius) {
    final colors = [
      Colors.deepPurple, Colors.teal, Colors.orange, Colors.pink,
      Colors.indigo, Colors.green, Colors.red, Colors.blue,
    ];
    final color = colors[name.hashCode.abs() % colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: TextStyle(color: Colors.white, fontSize: radius * 0.85, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 🔥 Максимальная ширина изображения в чате (примерно 2/3 от ширины сообщения)
    final imageMaxWidth = MediaQuery.of(context).size.width * 0.45; // было 0.7, стало 0.45

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: [
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
                Text('Обсуждение', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                if (_isLoading) ...[
                  const Spacer(),
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
                ],
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : _messages.isEmpty
                ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 8),
                Text('Начните обсуждение', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outlineVariant)),
              ]),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final mine = msg.senderId == _currentUserId;
                final showAvatar = index == 0 ||
                    _messages[index - 1].senderId != msg.senderId;

                return Padding(
                  padding: EdgeInsets.only(top: showAvatar ? 8 : 2, bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!mine && showAvatar) ...[
                        _buildAvatar(msg.senderAvatar, msg.senderName, radius: 14),
                        const SizedBox(width: 8),
                      ] else if (!mine) ...[
                        const SizedBox(width: 36),
                      ],
                      Flexible(
                        child: GestureDetector(
                          onLongPress: () => _showMessageMenu(context, msg, mine),
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: mine
                                  ? LinearGradient(colors: [Colors.orange.shade300, Colors.deepOrange.shade300], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                  : null,
                              color: mine ? null : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mine ? 16 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 16),
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine && showAvatar)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(msg.senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ),
                                if (msg.replyToId.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: mine ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border(left: BorderSide(color: mine ? Colors.white : Colors.orange, width: 2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (msg.replyToImageUrl.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: CachedNetworkImage(
                                              imageUrl: msg.replyToImageUrl,
                                              height: 30, // 🔥 уменьшено
                                              width: 30,  // 🔥 уменьшено
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        if (msg.replyToText.isNotEmpty)
                                          Text(msg.replyToText, style: TextStyle(fontSize: 12, color: mine ? Colors.white70 : Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                // 🔥 Фото в сообщении (уменьшенный размер и прозрачный плейсхолдер)
                                if (msg.imageUrl.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => _showFullImage(msg.imageUrl),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: imageMaxWidth,
                                            maxHeight: imageMaxWidth * 1.2, // пропорции фото
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: msg.imageUrl,
                                            fit: BoxFit.cover,
                                            width: imageMaxWidth,
                                            placeholder: (_, __) => Container(
                                              width: imageMaxWidth,
                                              height: imageMaxWidth * 0.8,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Center(
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) => Container(
                                              width: imageMaxWidth,
                                              height: imageMaxWidth * 0.6,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.broken_image, size: 30, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (msg.text.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: msg.imageUrl.isNotEmpty ? 2 : 0),
                                    child: Text(msg.text, style: TextStyle(fontSize: 14, color: mine ? Colors.white : Colors.black87, height: 1.3)),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(_formatTime(msg.createdAt), style: TextStyle(fontSize: 10, color: mine ? Colors.white60 : Colors.grey.shade500)),
                                    if (mine) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.done_all, size: 12, color: mine ? Colors.white60 : Colors.grey),
                                    ],
                                    if (msg.isEdited) ...[
                                      const SizedBox(width: 4),
                                      Text('изм.', style: TextStyle(fontSize: 10, color: mine ? Colors.white60 : Colors.grey.shade500)),
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
                        _buildAvatar(_currentUserAvatar, _currentUserName ?? 'Вы', radius: 14),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), border: Border(top: BorderSide(color: Colors.orange.withOpacity(0.3)))),
              child: Row(children: [
                const Icon(Icons.reply, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ответ $_replyToName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange)),
                    if (_replyToText != null && _replyToText!.isNotEmpty) Text(_replyToText!, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (_replyToImageUrl != null && _replyToImageUrl!.isNotEmpty) const Text('📷 Фото', style: TextStyle(fontSize: 11)),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.close, size: 16), onPressed: _cancelReply, splashRadius: 16),
              ]),
            ),

          if (_editingId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), border: Border(top: BorderSide(color: Colors.blue.withOpacity(0.3)))),
              child: Row(children: [
                const Icon(Icons.edit, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Редактирование', style: TextStyle(fontSize: 11, color: Colors.blue))),
                TextButton(onPressed: _cancelEdit, child: const Text('Отмена', style: TextStyle(fontSize: 11))),
              ]),
            ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 🔥 Кнопка фото
                IconButton(
                  icon: const Icon(Icons.image_rounded, color: Colors.orange, size: 22),
                  onPressed: _pickAndSendImage,
                  padding: const EdgeInsets.only(bottom: 6),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _editingId != null ? 'Редактировать...' : 'Сообщение...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_editingId != null) {
                      _editMessage(_editingId!, _textController.text.trim());
                    } else {
                      _sendMessage();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange])),
                    child: Icon(_editingId != null ? Icons.check : Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageMenu(BuildContext context, ChatMessage msg, bool mine) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              if (!mine)
                ListTile(
                  leading: const Icon(Icons.reply, color: Colors.orange),
                  title: const Text('Ответить'),
                  onTap: () { Navigator.pop(ctx); _startReply(msg); },
                ),
              if (mine) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Редактировать'),
                  onTap: () { Navigator.pop(ctx); _startEdit(msg); },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(ctx); _showDeleteConfirmDialog(msg.messageId); },
                ),
              ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить сообщение?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); _deleteMessage(messageId); },
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
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return DateFormat('HH:mm').format(dt);
      }
      return DateFormat('dd.MM HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}