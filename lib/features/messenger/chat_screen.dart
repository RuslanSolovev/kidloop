// chat_screen.dart - С ОТПРАВКОЙ ФОТО И ПРАВИЛЬНЫМ ПОРЯДКОМ
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';


class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherName;
  final String? otherAvatar;

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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserAvatar;
  bool _sending = false;
  bool _initialLoading = true;
  String? _loadError;
  String? _replyToMessageId;
  Map<String, dynamic>? _replyToMessageData;
  String? _editingMessageId;
  int _totalMessages = 0;
  final Set<String> _pendingIds = {};

  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const String uploadApiUrl = 'https://functions.yandexcloud.net/d4e3c2me21eou683ic6d';
  static const String _cacheKey = 'chat_messages_cache';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadMessages();
    }
  }

  Future<void> _init() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _currentUserName = prefs.getString('user_name') ?? 'Вы';
    _currentUserAvatar = prefs.getString('avatar_url') ?? '';

    await _loadCachedMessages();
    await _loadMessages();

    if (mounted) {
      setState(() => _initialLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _loadCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$_cacheKey${widget.chatId}');
      if (cached != null && mounted) {
        final data = jsonDecode(cached) as List;
        setState(() {
          _messages = data.cast<Map<String, dynamic>>();
          _totalMessages = _messages.length;
          _initialLoading = false;
        });
      }
    } catch (e) {
      debugPrint('CACHE Error: $e');
    }
  }

  Future<void> _cacheMessages() async {
    try {
      final toCache = _messages
          .where((m) => !m['message_id'].toString().startsWith('temp_'))
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cacheKey${widget.chatId}', jsonEncode(toCache));
    } catch (e) {
      debugPrint('CACHE Error: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (widget.chatId.isEmpty || !mounted) return;

    try {
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-messages", "chat_id": widget.chatId}),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final serverMessages = (data['messages'] as List).cast<Map<String, dynamic>>();

        // Сохраняем pending сообщения
        final pendingMessages = _messages.where((m) {
          final id = m['message_id'].toString();
          return id.startsWith('temp_') || _pendingIds.contains(id);
        }).toList();

        // Убираем дубликаты
        final filteredPending = pendingMessages.where((pending) {
          final pendingText = pending['text'] ?? '';
          final pendingImage = pending['image_url'] ?? '';
          return !serverMessages.any((server) =>
          (server['text'] == pendingText && server['sender_id'] == _currentUserId) ||
              (server['image_url'] == pendingImage && pendingImage.isNotEmpty)
          );
        }).toList();

        setState(() {
          _messages = [...serverMessages, ...filteredPending];
          _totalMessages = _messages.length;
          _initialLoading = false;
          _loadError = null;
        });

        await _cacheMessages();
      }
    } catch (e) {
      debugPrint('LOAD Error: $e');
      if (!mounted) return;
      if (_messages.isEmpty) {
        setState(() {
          _initialLoading = false;
          _loadError = 'Ошибка соединения';
        });
      }
    }
  }

  // 🔥 ОТПРАВКА ФОТО С ТЕКСТОМ
  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    // 🔥 Показываем диалог для ввода текста к фото
    final textController = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Добавить подпись'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(picked.path),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Подпись к фото (необязательно)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );

    if (text == null || !mounted) return; // Отмена

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
        final imageUrl = uploadData['file_url'];
        await _sendImageMessage(imageUrl, text: text.isNotEmpty ? text : null);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка загрузки фото'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Image upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки фото'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendImageMessage(String imageUrl, {String? text}) async {
    if (!mounted) return;

    final replyIdSnapshot = _replyToMessageId;
    final replyDataSnapshot = _replyToMessageData != null
        ? Map<String, dynamic>.from(_replyToMessageData!)
        : null;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    _pendingIds.add(tempId);

    final optimisticMsg = <String, dynamic>{
      'message_id': tempId,
      'sender_id': _currentUserId,
      'text': text ?? '',
      'image_url': imageUrl,
      'sender_name': _currentUserName ?? 'Вы',
      'sender_avatar': _currentUserAvatar ?? '',
      'created_at': DateTime.now().toIso8601String(),
      'status': 'sending',
      if (replyIdSnapshot != null) 'reply_to': replyIdSnapshot,
      if (replyIdSnapshot != null && replyDataSnapshot != null)
        'reply_to_message': {
          'message_id': replyDataSnapshot['message_id'],
          'text': replyDataSnapshot['text'] ?? '',
          'image_url': replyDataSnapshot['image_url'] ?? '',
          'sender_name': replyDataSnapshot['sender_name'] ?? '',
          'sender_avatar': replyDataSnapshot['sender_avatar'] ?? '',
        },
    };

    setState(() {
      _messages.add(optimisticMsg);
      _replyToMessageId = null;
      _replyToMessageData = null;
      _totalMessages = _messages.length;
    });

    _scrollToBottom();

    try {
      final body = <String, dynamic>{
        "action": "send-message",
        "chat_id": widget.chatId,
        "sender_id": _currentUserId,
        "text": text ?? '',
        "image_url": imageUrl,
      };
      if (replyIdSnapshot != null) body["reply_to"] = replyIdSnapshot;

      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final newId = data['message_id'] ?? tempId;
        _pendingIds.remove(tempId);
        _pendingIds.add(newId);

        setState(() {
          final idx = _messages.indexWhere((m) => m['message_id'] == tempId);
          if (idx != -1) {
            _messages[idx]['message_id'] = newId;
            _messages[idx]['status'] = 'sent';
          }
        });

        await _loadMessages();
        _pendingIds.remove(newId);
        await _cacheMessages();
      } else {
        _pendingIds.remove(tempId);
        setState(() {
          final idx = _messages.indexWhere((m) => m['message_id'] == tempId);
          if (idx != -1) _messages[idx]['status'] = 'failed';
        });
      }
    } catch (e) {
      debugPrint('Send image error: $e');
      if (!mounted) return;
      _pendingIds.remove(tempId);
      setState(() {
        final idx = _messages.indexWhere((m) => m['message_id'] == tempId);
        if (idx != -1) _messages[idx]['status'] = 'failed';
      });
    }
  }

  // 🔥 ОТПРАВКА ТЕКСТОВОГО СООБЩЕНИЯ
  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending || !mounted) return;

    setState(() => _sending = true);

    final isEditing = _editingMessageId != null;
    final editingIdSnapshot = _editingMessageId;
    final replyIdSnapshot = _replyToMessageId;
    final replyDataSnapshot = _replyToMessageData != null
        ? Map<String, dynamic>.from(_replyToMessageData!)
        : null;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    _pendingIds.add(tempId);

    final optimisticMsg = <String, dynamic>{
      'message_id': tempId,
      'sender_id': _currentUserId,
      'text': text,
      'sender_name': _currentUserName ?? 'Вы',
      'sender_avatar': _currentUserAvatar ?? '',
      'created_at': DateTime.now().toIso8601String(),
      'is_edited': isEditing,
      'status': 'sending',
      if (replyIdSnapshot != null) 'reply_to': replyIdSnapshot,
      if (replyIdSnapshot != null && replyDataSnapshot != null)
        'reply_to_message': {
          'message_id': replyDataSnapshot['message_id'],
          'text': replyDataSnapshot['text'] ?? '',
          'sender_name': replyDataSnapshot['sender_name'] ?? '',
          'sender_avatar': replyDataSnapshot['sender_avatar'] ?? '',
        },
    };

    if (isEditing) {
      _messages.removeWhere((m) => m['message_id'] == editingIdSnapshot);
    }

    // 🔥 Добавляем в КОНЕЦ списка
    setState(() {
      _messages.add(optimisticMsg);
      _editingMessageId = null;
      _replyToMessageId = null;
      _replyToMessageData = null;
      _totalMessages = _messages.length;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      Map<String, dynamic> body;

      if (isEditing) {
        body = {
          "action": "edit-message",
          "chat_id": widget.chatId,
          "sender_id": _currentUserId,
          "text": text,
          "message_id": editingIdSnapshot,
        };
      } else {
        body = {
          "action": "send-message",
          "chat_id": widget.chatId,
          "sender_id": _currentUserId,
          "text": text,
        };
        if (replyIdSnapshot != null) body["reply_to"] = replyIdSnapshot;
      }

      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final newId = data['message_id'] ?? tempId;
        _pendingIds.remove(tempId);
        _pendingIds.add(newId);

        setState(() {
          final idx = _messages.indexWhere((m) => m['message_id'] == tempId);
          if (idx != -1) {
            _messages[idx]['message_id'] = newId;
            _messages[idx]['status'] = 'sent';
          }
        });

        await _loadMessages();
        _pendingIds.remove(newId);
        await _cacheMessages();
      } else {
        _pendingIds.remove(tempId);
        setState(() {
          final idx = _messages.indexWhere((m) => m['message_id'] == tempId);
          if (idx != -1) _messages[idx]['status'] = 'failed';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['errorMessage'] ?? 'Ошибка'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('SEND Error: $e');
      if (!mounted) return;
      _pendingIds.remove(tempId);
      setState(() {
        final idx = _messages.indexWhere((m) => m['message_id'] == tempId);
        if (idx != -1) _messages[idx]['status'] = 'failed';
      });
    }

    if (mounted) setState(() => _sending = false);
  }

  Future<void> _deleteMessage(String messageId) async {
    if (!mounted) return;

    final deletedMsg = _messages.firstWhere(
          (m) => m['message_id'] == messageId,
      orElse: () => <String, dynamic>{},
    );

    if (deletedMsg.isEmpty) return;

    setState(() {
      _messages.removeWhere((m) => m['message_id'] == messageId);
      _totalMessages = _messages.length;
    });

    try {
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "delete-message",
          "chat_id": widget.chatId,
          "message_id": messageId,
          "user_id": _currentUserId,
        }),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (data['ok'] != true) {
        setState(() {
          _messages.add(deletedMsg);
          _totalMessages = _messages.length;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(deletedMsg);
        _totalMessages = _messages.length;
      });
    }
  }

  void _retryMessage(Map<String, dynamic> msg) {
    setState(() {
      _messages.removeWhere((m) => m['message_id'] == msg['message_id']);
      _totalMessages = _messages.length;
    });
    _textController.text = msg['text'] ?? '';
    FocusScope.of(context).requestFocus();
  }

  void _startEditMessage(Map<String, dynamic> message) {
    if (!mounted) return;

    final hasImage = message['image_url'] != null && message['image_url'].toString().isNotEmpty;

    if (hasImage) {
      // 🔥 Для сообщений с фото показываем диалог
      _showEditImageDialog(message);
    } else {
      // Обычное редактирование текста
      _textController.text = message['text'] ?? '';
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
      setState(() {
        _editingMessageId = message['message_id'];
        _replyToMessageId = null;
        _replyToMessageData = null;
      });
      FocusScope.of(context).requestFocus();
    }
  }

// 🔥 Диалог редактирования фото
  void _showEditImageDialog(Map<String, dynamic> message) {
    final textController = TextEditingController(text: message['text'] ?? '');
    String? newImageUrl = message['image_url'];
    File? newImageFile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Редактировать фото и текст сообщения'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Текущее или новое фото
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (picked != null) {
                    setDialogState(() => newImageFile = File(picked.path));
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: newImageFile != null
                      ? Image.file(newImageFile!, height: 150, width: double.infinity, fit: BoxFit.cover)
                      : newImageUrl != null && newImageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: newImageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 150, color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator())),
                    errorWidget: (_, __, ___) => Container(height: 150, color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image, size: 40))),
                  )
                      : Container(height: 150, color: Colors.grey.shade200, child: const Center(child: Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey))),
                ),
              ),
              if (newImageFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: () => setDialogState(() { newImageFile = null; newImageUrl = null; }),
                    child: const Text('Удалить фото'),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Подпись к фото',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _editImageMessage(
                  message['message_id'],
                  textController.text.trim(),
                  newImageFile,
                  newImageUrl,
                );
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

// 🔥 Сохранение отредактированного фото-сообщения
  Future<void> _editImageMessage(String messageId, String text, File? newImageFile, String? currentImageUrl) async {
    if (!mounted) return;

    setState(() => _sending = true);

    String? finalImageUrl = currentImageUrl;

    // Если выбрали новое фото - загружаем его
    if (newImageFile != null) {
      try {
        final bytes = await newImageFile.readAsBytes();
        final base64 = base64Encode(bytes);

        final uploadResponse = await http.post(
          Uri.parse(uploadApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "action": "upload",
            "file_name": "chat_edit_${DateTime.now().millisecondsSinceEpoch}.jpg",
            "file_data": base64,
          }),
        ).timeout(const Duration(seconds: 20));

        final uploadData = jsonDecode(uploadResponse.body);
        if (uploadData['ok'] == true) {
          finalImageUrl = uploadData['file_url'];
        }
      } catch (e) {
        debugPrint('Edit image upload error: $e');
      }
    }

    // Отправляем изменения
    try {
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "edit-message",
          "chat_id": widget.chatId,
          "sender_id": _currentUserId,
          "message_id": messageId,
          "text": text,
          "image_url": finalImageUrl ?? '',
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        await _loadMessages();
        await _cacheMessages();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['errorMessage'] ?? 'Ошибка редактирования'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка сети'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  void _cancelEdit() {
    if (!mounted) return;
    setState(() => _editingMessageId = null);
    _textController.clear();
  }

  void _setReplyToMessage(Map<String, dynamic> message) {
    if (!mounted) return;
    setState(() {
      _replyToMessageId = message['message_id'];
      _replyToMessageData = message;
      _editingMessageId = null;
    });
    _textController.clear();
    FocusScope.of(context).requestFocus();
  }

  void _cancelReply() {
    if (!mounted) return;
    setState(() {
      _replyToMessageId = null;
      _replyToMessageData = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients && _messages.isNotEmpty) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildStatusIcon(String status, bool isMine) {
    if (!isMine) return const SizedBox.shrink();

    switch (status) {
      case 'sending':
        return const SizedBox(
          width: 12, height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70),
        );
      case 'sent':
        return Icon(Icons.check, size: 14, color: Colors.white.withOpacity(0.6));
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF64B5F6));
      case 'failed':
        return const Icon(Icons.error_outline, size: 14, color: Colors.red);
      default:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF64B5F6));
    }
  }

  Widget _buildAvatar(String? url, String name, {double radius = 16, Color? bgColor, Color? textColor}) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor ?? Colors.grey.shade200,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: bgColor ?? Colors.grey.shade200,
              child: Center(
                child: Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: TextStyle(fontSize: radius * 0.85, color: textColor ?? Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: bgColor ?? Colors.orange.shade100,
              child: Center(
                child: Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: TextStyle(fontSize: radius * 0.85, color: textColor ?? Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor ?? Colors.orange.shade100,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: TextStyle(fontSize: radius * 0.85, color: textColor ?? Colors.orange, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _buildAvatar(widget.otherAvatar, widget.otherName, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('$_totalMessages сообщений', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.orange.withOpacity(0.02),
        child: Column(
          children: [
            if (_initialLoading)
              Expanded(child: _buildLoadingSkeleton())
            else if (_loadError != null && _messages.isEmpty)
              Expanded(child: _buildErrorState())
            else
              Expanded(
                child: _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),
              ),
            _buildInputField(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            mainAxisAlignment: index % 2 == 0 ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const CircleAvatar(radius: 16, backgroundColor: Color(0xFFE0E0E0)),
                        const SizedBox(width: 8),
                        Container(width: 60, height: 12, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(6))),
                      ]),
                      const SizedBox(height: 8),
                      Container(width: 200, height: 16, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(8))),
                    ],
                  ),
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
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(_loadError!, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (!mounted) return;
              setState(() { _initialLoading = true; _loadError = null; });
              _loadMessages();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
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
          const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Нет сообщений', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Напишите первое сообщение!', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    // 🔥 Максимальный размер изображения в чате (примерно 2/3 от ширины сообщения)
    final imageMaxWidth = MediaQuery.of(context).size.width * 0.45;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMine = msg['sender_id'] == _currentUserId;
        final senderName = msg['sender_name'] ?? '';
        final senderAvatar = msg['sender_avatar'] ?? '';
        final text = msg['text'] ?? '';
        final imageUrl = msg['image_url'] ?? '';
        final time = msg['created_at'] ?? '';
        final isEdited = msg['is_edited'] == true;
        final status = msg['status']?.toString() ?? 'read';
        final replyToData = msg['reply_to_message'] as Map<String, dynamic>?;

        return GestureDetector(
          onLongPress: status == 'failed' ? null : () => _showMessageOptions(msg, isMine),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
            child: Row(
              mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: status == 'failed'
                            ? [Colors.red.shade100, Colors.red.shade200]
                            : isMine
                            ? [Colors.orange.shade400, Colors.orange.shade600]
                            : [Colors.white, Colors.grey.shade50],
                      ),
                      borderRadius: BorderRadius.circular(20).copyWith(
                        topRight: isMine ? const Radius.circular(4) : null,
                        topLeft: !isMine ? const Radius.circular(4) : null,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMine)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    _buildAvatar(senderAvatar, senderName, radius: 15, bgColor: Colors.orange.shade100, textColor: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(senderName.isNotEmpty ? senderName : 'Пользователь',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ],
                                ),
                              ),

                            if (replyToData != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isMine ? Colors.white : Colors.black).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border(
                                    left: BorderSide(color: (isMine ? Colors.white : Colors.orange).withOpacity(0.6), width: 3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(Icons.reply_rounded, size: 14, color: (isMine ? Colors.white : Colors.orange).withOpacity(0.7)),
                                      const SizedBox(width: 4),
                                      Text(replyToData['sender_name'] ?? '',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (isMine ? Colors.white : Colors.orange).withOpacity(0.8))),
                                    ]),
                                    const SizedBox(height: 4),
                                    if (replyToData['image_url'] != null && replyToData['image_url'].toString().isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: replyToData['image_url'],
                                          height: 60,
                                          width: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    Text(replyToData['text'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, color: (isMine ? Colors.white : Colors.black87).withOpacity(0.7), fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),

                            // 🔥 Фото в сообщении (уменьшенный размер и без рамок у плейсхолдера)
                            if (imageUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: GestureDetector(
                                  onTap: () => _showFullImage(imageUrl),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: imageMaxWidth,
                                        maxHeight: imageMaxWidth * 1.2,
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        width: imageMaxWidth,
                                        placeholder: (_, __) => Container(
                                          // 🔥 Точно такой же размер как у фото
                                          width: imageMaxWidth,
                                          height: imageMaxWidth * 0.8,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          width: imageMaxWidth,
                                          height: imageMaxWidth * 0.6,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.broken_image,
                                              size: 30,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            if (text.isNotEmpty)
                              Text(text, style: TextStyle(fontSize: 16, color: isMine ? Colors.white : Colors.black87)),
                            const SizedBox(height: 4),

                            Align(
                              alignment: Alignment.bottomRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_formatTime(time),
                                      style: TextStyle(fontSize: 11, color: isMine ? Colors.white.withOpacity(0.7) : Colors.grey.shade500)),
                                  if (isEdited) ...[
                                    const SizedBox(width: 4),
                                    Text('изм.', style: TextStyle(fontSize: 10, color: isMine ? Colors.white.withOpacity(0.6) : Colors.grey.shade400)),
                                  ],
                                  if (isMine) ...[
                                    const SizedBox(width: 4),
                                    _buildStatusIcon(status, isMine),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (status == 'failed')
                          Positioned(
                            right: 0, top: 0,
                            child: GestureDetector(
                              onTap: () => _retryMessage(msg),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.refresh, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  void _showMessageOptions(Map<String, dynamic> message, bool isMine) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.reply_rounded, color: Colors.orange.shade700),
                title: const Text('Ответить'),
                onTap: () { Navigator.pop(ctx); _setReplyToMessage(message); },
              ),
              if (isMine) ...[
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: Colors.blue.shade700),
                  title: const Text('Редактировать'),
                  onTap: () { Navigator.pop(ctx); _startEditMessage(message); },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.red),
                  title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(ctx); _showDeleteConfirmation(message['message_id']); },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String messageId) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Это действие нельзя отменить'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); if (mounted) _deleteMessage(messageId); },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyToMessageData != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.orange.withOpacity(0.08),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.reply_rounded, color: Colors.orange, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ответ на сообщение ${_replyToMessageData!['sender_name'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange)),
                  Text(_replyToMessageData!['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ])),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey), onPressed: _cancelReply),
              ],
            ),
          ),
        if (_editingMessageId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.blue.withOpacity(0.08),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_rounded, color: Colors.blue, size: 18)),
                const SizedBox(width: 10),
                const Text('Редактирование', style: TextStyle(fontSize: 13, color: Colors.blue)),
                const Spacer(),
                TextButton(onPressed: _cancelEdit, child: const Text('Отмена')),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(top: BorderSide(color: Colors.grey.shade200))),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 🔥 Кнопка фото
                IconButton(
                  icon: const Icon(Icons.image_rounded, color: Colors.orange),
                  onPressed: _pickAndSendImage,
                  padding: const EdgeInsets.only(bottom: 8),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: _editingMessageId != null ? 'Редактировать...' : 'Сообщение...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                      : Icon(_editingMessageId != null ? Icons.check_rounded : Icons.send_rounded, color: Colors.orange, size: 24),
                  onPressed: _sending ? null : _handleSendMessage,
                  padding: const EdgeInsets.only(bottom: 8),
                ),
              ],
            ),
          ),
        ),
      ],
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
      if (dt.year == now.year) {
        return DateFormat('dd MMM, HH:mm', 'ru').format(dt);
      }
      return DateFormat('dd.MM.yy, HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}