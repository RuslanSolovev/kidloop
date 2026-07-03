// chat_screen.dart - С ОТПРАВКОЙ ФОТО, ПРАВИЛЬНЫМ ПОРЯДКОМ И НАСТРОЙКАМИ ЦВЕТОВ
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

// 🔥 Модель цветовой схемы чата
class ChatColorScheme {
  final Color myBgColor;
  final Color myTextColor;
  final Color otherBgColor;
  final Color otherTextColor;
  final Color backgroundColor;
  final String name;

  const ChatColorScheme({
    required this.myBgColor,
    required this.myTextColor,
    required this.otherBgColor,
    required this.otherTextColor,
    required this.backgroundColor,
    required this.name,
  });
}

// 🔥 Предустановленные цветовые схемы (10 вариантов)
const List<ChatColorScheme> _colorSchemes = [
  ChatColorScheme(
    name: 'Стандарт',
    myBgColor: Color(0xFFFF9800),
    myTextColor: Colors.white,
    otherBgColor: Colors.white,
    otherTextColor: Colors.black87,
    backgroundColor: Color(0xFFFFF8F0),
  ),
  ChatColorScheme(
    name: 'Океан',
    myBgColor: Color(0xFF2196F3),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFE3F2FD),
    otherTextColor: Color(0xFF1565C0),
    backgroundColor: Color(0xFFF0F8FF),
  ),
  ChatColorScheme(
    name: 'Лес',
    myBgColor: Color(0xFF4CAF50),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFE8F5E9),
    otherTextColor: Color(0xFF2E7D32),
    backgroundColor: Color(0xFFF1F8E9),
  ),
  ChatColorScheme(
    name: 'Закат',
    myBgColor: Color(0xFFE91E63),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFFCE4EC),
    otherTextColor: Color(0xFF880E4F),
    backgroundColor: Color(0xFFFFF5F5),
  ),
  ChatColorScheme(
    name: 'Фиолет',
    myBgColor: Color(0xFF9C27B0),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFF3E5F5),
    otherTextColor: Color(0xFF6A1B9A),
    backgroundColor: Color(0xFFFDF8FF),
  ),
  ChatColorScheme(
    name: 'Темный',
    myBgColor: Color(0xFF37474F),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFECEFF1),
    otherTextColor: Color(0xFF263238),
    backgroundColor: Color(0xFFECEFF1),
  ),
  ChatColorScheme(
    name: 'Мятный',
    myBgColor: Color(0xFF00897B),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFE0F2F1),
    otherTextColor: Color(0xFF004D40),
    backgroundColor: Color(0xFFF0FFFE),
  ),
  ChatColorScheme(
    name: 'Карамель',
    myBgColor: Color(0xFFFF6F00),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFFFF3E0),
    otherTextColor: Color(0xFFE65100),
    backgroundColor: Color(0xFFFFFBF5),
  ),
  ChatColorScheme(
    name: 'Лаванда',
    myBgColor: Color(0xFF7B1FA2),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFF5F0FF),
    otherTextColor: Color(0xFF4A148C),
    backgroundColor: Color(0xFFFAF8FF),
  ),
  ChatColorScheme(
    name: 'Ночь',
    myBgColor: Color(0xFF455A64),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFF2C3E50),
    otherTextColor: Color(0xFFECF0F1),
    backgroundColor: Color(0xFF1A1A2E),
  ),
];

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

  // 🔥 Настройки цветов
  int _selectedColorSchemeIndex = 0;
  late ChatColorScheme _currentColorScheme;

  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const String uploadApiUrl = 'https://functions.yandexcloud.net/d4e3c2me21eou683ic6d';
  static const String _cacheKey = 'chat_messages_cache';

  // 🔥 Поддержка темной темы
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentColorScheme = _colorSchemes[0];
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

    // 🔥 Загружаем сохраненную цветовую схему
    _selectedColorSchemeIndex = prefs.getInt('chat_color_scheme_${widget.chatId}') ?? 0;
    _currentColorScheme = _colorSchemes[_selectedColorSchemeIndex];

    await _loadCachedMessages();
    await _loadMessages();

    if (mounted) {
      setState(() => _initialLoading = false);
      _scrollToBottom();
    }
  }

  // 🔥 Сохранение цветовой схемы
  Future<void> _saveColorScheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chat_color_scheme_${widget.chatId}', index);
  }

  // 🔥 Диалог выбора цветовой схемы
  void _showColorSchemeDialog() {
    final isDark = _isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Оформление чата',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // 🔥 Предпросмотр с фоном
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _colorSchemes[_selectedColorSchemeIndex].backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.visibility_rounded, size: 14, color: isDark ? Colors.white54 : Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Предпросмотр',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Мое сообщение
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _colorSchemes[_selectedColorSchemeIndex].myBgColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                          child: Text(
                            'Ваше сообщение',
                            style: TextStyle(
                              color: _colorSchemes[_selectedColorSchemeIndex].myTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Чужое сообщение
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _colorSchemes[_selectedColorSchemeIndex].otherBgColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Сообщение собеседника',
                            style: TextStyle(
                              color: _colorSchemes[_selectedColorSchemeIndex].otherTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 🔥 Сетка с выбором цветов (3 колонки)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _colorSchemes.length,
                  itemBuilder: (context, index) {
                    final scheme = _colorSchemes[index];
                    final isSelected = _selectedColorSchemeIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => _selectedColorSchemeIndex = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.orange : Colors.grey.withOpacity(0.3),
                            width: isSelected ? 2.5 : 1,
                          ),
                          color: isSelected
                              ? (isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.withOpacity(0.05))
                              : Colors.transparent,
                          boxShadow: isSelected
                              ? [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 8)]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Три цвета: свои, чужие, фон
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: scheme.myBgColor,
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: scheme.otherBgColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: scheme.backgroundColor,
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              scheme.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? Colors.orange
                                    : (isDark ? Colors.white70 : Colors.grey.shade700),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.orange.withOpacity(0.2),
                                ),
                                child: const Icon(Icons.check, color: Colors.orange, size: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // 🔥 Подсказка
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: isDark ? Colors.white54 : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Цвета: своё сообщение | чужое | фон',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _currentColorScheme = _colorSchemes[_selectedColorSchemeIndex];
                  });
                  _saveColorScheme(_selectedColorSchemeIndex);
                  Navigator.pop(ctx);
                },
                child: const Text('Применить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
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

        final pendingMessages = _messages.where((m) {
          final id = m['message_id'].toString();
          return id.startsWith('temp_') || _pendingIds.contains(id);
        }).toList();

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

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

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

    if (text == null || !mounted) return;

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
      _showEditImageDialog(message);
    } else {
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

  Future<void> _editImageMessage(String messageId, String text, File? newImageFile, String? currentImageUrl) async {
    if (!mounted) return;

    setState(() => _sending = true);

    String? finalImageUrl = currentImageUrl;

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
    final isDark = _isDarkMode;

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
        actions: [
          // 🔥 Кнопка настроек цветов
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.palette_rounded, color: Colors.orange, size: 20),
            ),
            onPressed: _showColorSchemeDialog,
            tooltip: 'Оформление чата',
          ),
        ],
      ),
      body: Container(
        // 🔥 Используем цвет фона из выбранной схемы
        color: _currentColorScheme.backgroundColor,
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
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: _currentColorScheme.myBgColor.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          const Text('Нет сообщений', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Напишите первое сообщение!', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
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

        // 🔥 Используем выбранную цветовую схему
        final myBg = _currentColorScheme.myBgColor;
        final myText = _currentColorScheme.myTextColor;
        final otherBg = _currentColorScheme.otherBgColor;
        final otherText = _currentColorScheme.otherTextColor;
        final bgColor = isMine ? myBg : otherBg;
        final textColor = isMine ? myText : otherText;

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
                      gradient: status == 'failed'
                          ? LinearGradient(colors: [Colors.red.shade100, Colors.red.shade200])
                          : null,
                      color: status == 'failed' ? null : bgColor,
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
                                    _buildAvatar(senderAvatar, senderName, radius: 15, bgColor: otherBg.withOpacity(0.5), textColor: otherText),
                                    const SizedBox(width: 8),
                                    Text(senderName.isNotEmpty ? senderName : 'Пользователь',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: otherText)),
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
                                    left: BorderSide(color: textColor.withOpacity(0.6), width: 3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(Icons.reply_rounded, size: 14, color: textColor.withOpacity(0.7)),
                                      const SizedBox(width: 4),
                                      Text(replyToData['sender_name'] ?? '',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.8))),
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
                                        style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.7), fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),

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
                              Text(text, style: TextStyle(fontSize: 16, color: textColor)),
                            const SizedBox(height: 4),

                            Align(
                              alignment: Alignment.bottomRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_formatTime(time),
                                      style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7))),
                                  if (isEdited) ...[
                                    const SizedBox(width: 4),
                                    Text('изм.', style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6))),
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