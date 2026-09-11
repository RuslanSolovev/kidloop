// forum_screen.dart - СТИЛЬНЫЙ ФОРУМ (как чат: контрастный верх с скруглением, парящее поле)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

// 🔥 Модель цветовой схемы форума
class ForumColorScheme {
  final Color myBorderColor;
  final Color myTextColor;
  final Color otherBorderColor;
  final Color otherTextColor;
  final Color backgroundColor;
  final String name;

  const ForumColorScheme({
    required this.myBorderColor,
    required this.myTextColor,
    required this.otherBorderColor,
    required this.otherTextColor,
    required this.backgroundColor,
    required this.name,
  });
}

// 🔥 Предустановленные цветовые схемы
const List<ForumColorScheme> _colorSchemes = [
  ForumColorScheme(
    name: 'Стандарт',
    myBorderColor: Color(0xFFFF6B35),
    myTextColor: Color(0xFF1A1D24),
    otherBorderColor: Color(0xFF2D7FF9),
    otherTextColor: Color(0xFF1A1D24),
    backgroundColor: Color(0xFFF5F7FA),
  ),
  ForumColorScheme(
    name: 'Океан',
    myBorderColor: Color(0xFF2D7FF9),
    myTextColor: Color(0xFF1A3A6B),
    otherBorderColor: Color(0xFF7FB3D9),
    otherTextColor: Color(0xFF1A3A6B),
    backgroundColor: Color(0xFFF0F7FF),
  ),
  ForumColorScheme(
    name: 'Лес',
    myBorderColor: Color(0xFF2E9A4C),
    myTextColor: Color(0xFF1A4A2A),
    otherBorderColor: Color(0xFF66BB6A),
    otherTextColor: Color(0xFF1A4A2A),
    backgroundColor: Color(0xFFF0FAF2),
  ),
  ForumColorScheme(
    name: 'Закат',
    myBorderColor: Color(0xFFE8456B),
    myTextColor: Color(0xFF7A1A3A),
    otherBorderColor: Color(0xFFF06292),
    otherTextColor: Color(0xFF7A1A3A),
    backgroundColor: Color(0xFFFFF5F7),
  ),
  ForumColorScheme(
    name: 'Фиолет',
    myBorderColor: Color(0xFF8B3DF0),
    myTextColor: Color(0xFF4A1A7A),
    otherBorderColor: Color(0xFFB39DDB),
    otherTextColor: Color(0xFF4A1A7A),
    backgroundColor: Color(0xFFF8F5FF),
  ),
  ForumColorScheme(
    name: 'Мятный',
    myBorderColor: Color(0xFF00A88A),
    myTextColor: Color(0xFF004A3A),
    otherBorderColor: Color(0xFF4DB6AC),
    otherTextColor: Color(0xFF004A3A),
    backgroundColor: Color(0xFFF0FFFC),
  ),
  ForumColorScheme(
    name: 'Карамель',
    myBorderColor: Color(0xFFFF8F00),
    myTextColor: Color(0xFF6A3A00),
    otherBorderColor: Color(0xFFFFB74D),
    otherTextColor: Color(0xFF6A3A00),
    backgroundColor: Color(0xFFFFFBF5),
  ),
  ForumColorScheme(
    name: 'Лаванда',
    myBorderColor: Color(0xFF6A1AB0),
    myTextColor: Color(0xFF3A0A6A),
    otherBorderColor: Color(0xFFCE93D8),
    otherTextColor: Color(0xFF3A0A6A),
    backgroundColor: Color(0xFFFAF5FF),
  ),
  ForumColorScheme(
    name: 'Ночь',
    myBorderColor: Color(0xFF6A7A8A),
    myTextColor: Color(0xFFE8F0F8),
    otherBorderColor: Color(0xFF4A5A6A),
    otherTextColor: Color(0xFFE8F0F8),
    backgroundColor: Color(0xFF1A1A2E),
  ),
  ForumColorScheme(
    name: 'Вишня',
    myBorderColor: Color(0xFFD42A5A),
    myTextColor: Color(0xFF6A1A2A),
    otherBorderColor: Color(0xFFEF5350),
    otherTextColor: Color(0xFF6A1A2A),
    backgroundColor: Color(0xFFFFF5F8),
  ),
];

class ForumScreen extends StatefulWidget {
  final String forumId;
  final String forumTitle;

  const ForumScreen({super.key, required this.forumId, required this.forumTitle});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> with WidgetsBindingObserver {
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
  final Set<String> _pendingIds = {};

  int _selectedColorSchemeIndex = 0;
  late ForumColorScheme _currentColorScheme;

  static const String forumApiUrl = 'https://functions.yandexcloud.net/d4en6mi363fq4o5js5ee';
  static const String _cacheKey = 'forum_messages_cache';

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
    _currentUserName = prefs.getString('user_name') ?? 'Пользователь';
    _currentUserAvatar = prefs.getString('avatar_url') ?? '';

    _selectedColorSchemeIndex = prefs.getInt('forum_color_scheme_${widget.forumId}') ?? 0;
    _currentColorScheme = _colorSchemes[_selectedColorSchemeIndex];

    await _loadCachedMessages();
    await _loadMessages();

    if (mounted) {
      setState(() => _initialLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _saveColorScheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('forum_color_scheme_${widget.forumId}', index);
  }

  void _showColorSchemeDialog() {
    final isDark = _isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.palette_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Оформление форума',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Выберите стиль',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _colorSchemes[_selectedColorSchemeIndex].backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 130),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _colorSchemes[_selectedColorSchemeIndex].otherBorderColor,
                              width: 2,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Привет!',
                            style: TextStyle(
                              color: _colorSchemes[_selectedColorSchemeIndex].otherTextColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 130),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _colorSchemes[_selectedColorSchemeIndex].myBorderColor,
                              width: 2,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                          child: Text(
                            'Привет! 😊',
                            style: TextStyle(
                              color: _colorSchemes[_selectedColorSchemeIndex].myTextColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: _colorSchemes.length,
                    itemBuilder: (context, index) {
                      final scheme = _colorSchemes[index];
                      final isSelected = _selectedColorSchemeIndex == index;
                      return GestureDetector(
                        onTap: () => setDialogState(() => _selectedColorSchemeIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF6B35)
                                  : isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.shade200,
                              width: isSelected ? 2.5 : 1,
                            ),
                            color: isSelected
                                ? const Color(0xFFFF6B35).withOpacity(0.08)
                                : Colors.transparent,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: scheme.myBorderColor,
                                          borderRadius: const BorderRadius.horizontal(
                                            left: Radius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: scheme.otherBorderColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: scheme.backgroundColor,
                                          borderRadius: const BorderRadius.horizontal(
                                            right: Radius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                scheme.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFFFF6B35)
                                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isSelected)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFF6B35),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Отмена',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _currentColorScheme = _colorSchemes[_selectedColorSchemeIndex];
                            });
                            _saveColorScheme(_selectedColorSchemeIndex);
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Применить',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$_cacheKey${widget.forumId}');
      if (cached != null && mounted) {
        final data = jsonDecode(cached) as List;
        setState(() {
          _messages = data.cast<Map<String, dynamic>>();
          _initialLoading = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _cacheMessages() async {
    try {
      final toCache = _messages
          .where((m) => !m['message_id'].toString().startsWith('temp_'))
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cacheKey${widget.forumId}', jsonEncode(toCache));
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    if (widget.forumId.isEmpty || !mounted) return;

    try {
      final response = await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-forum-messages", "forum_id": widget.forumId}),
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
          return !serverMessages.any((server) =>
          server['text'] == pendingText && server['sender_id'] == _currentUserId);
        }).toList();

        setState(() {
          _messages = [...filteredPending, ...serverMessages];
          _initialLoading = false;
          _loadError = null;
        });

        await _cacheMessages();
      }
    } catch (_) {
      if (!mounted) return;
      if (_messages.isEmpty) {
        setState(() {
          _initialLoading = false;
          _loadError = 'Ошибка соединения';
        });
      }
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
      'forum_id': widget.forumId,
      'sender_id': _currentUserId,
      'sender_name': _currentUserName ?? 'Пользователь',
      'sender_avatar': _currentUserAvatar ?? '',
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
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
    });

    _textController.clear();
    _scrollToBottom();

    try {
      final body = <String, dynamic>{
        "action": isEditing ? "edit-forum-message" : "send-forum-message",
        "forum_id": widget.forumId,
        "sender_id": _currentUserId,
        "sender_name": _currentUserName,
        "text": text,
      };
      if (isEditing) body["message_id"] = editingIdSnapshot;
      if (replyIdSnapshot != null) body["reply_to"] = replyIdSnapshot;

      final response = await http.post(
        Uri.parse(forumApiUrl),
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
            SnackBar(content: Text(data['errorMessage'] ?? 'Ошибка'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      _pendingIds.remove(tempId);
      setState(() {
        final idx = _messages.indexWhere((m) => m['message_id'] == tempId);
        if (idx != -1) _messages[idx]['status'] = 'failed';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Ошибка сети'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        );
      }
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

    setState(() => _messages.removeWhere((m) => m['message_id'] == messageId));
    await _cacheMessages();

    try {
      final response = await http.post(
        Uri.parse(forumApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "delete-forum-message", "message_id": messageId, "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (data['ok'] != true) {
        setState(() => _messages.add(deletedMsg));
        await _cacheMessages();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.add(deletedMsg));
    }
  }

  void _retryMessage(Map<String, dynamic> msg) {
    setState(() => _messages.removeWhere((m) => m['message_id'] == msg['message_id']));
    _textController.text = msg['text'] ?? '';
    FocusScope.of(context).requestFocus();
  }

  void _startEditMessage(Map<String, dynamic> message) {
    if (!mounted) return;
    _textController.text = message['text'] ?? '';
    setState(() {
      _editingMessageId = message['message_id'];
      _replyToMessageId = null;
      _replyToMessageData = null;
    });
    FocusScope.of(context).requestFocus();
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
          0,
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
        return const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey));
      case 'sent':
        return Icon(Icons.check, size: 14, color: Colors.grey);
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
            placeholder: (_, __) => Container(
              color: bgColor ?? Colors.grey.shade200,
              child: Center(
                child: Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: TextStyle(
                    fontSize: radius * 0.85,
                    color: textColor ?? const Color(0xFFFF6B35),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: bgColor ?? const Color(0xFFFF6B35).withOpacity(0.1),
              child: Center(
                child: Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: TextStyle(
                    fontSize: radius * 0.85,
                    color: textColor ?? const Color(0xFFFF6B35),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor ?? const Color(0xFFFF6B35).withOpacity(0.1),
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.85,
          color: textColor ?? const Color(0xFFFF6B35),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;

    return Scaffold(
      backgroundColor: _currentColorScheme.backgroundColor,
      // ========== КОНТРАСТНЫЙ ВЕРХ КАК В ЧАТЕ ==========
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: _currentColorScheme.myBorderColor.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(44),
            ),
            boxShadow: [
              BoxShadow(
                color: _currentColorScheme.myBorderColor.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, top: 6, bottom: 6),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Avatar (иконка форума)
                  _buildAvatar(
                    null,
                    widget.forumTitle,
                    radius: 18,
                    bgColor: Colors.white.withOpacity(0.2),
                    textColor: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  // Title & count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.forumTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${_messages.length} сообщений',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Palette button
                  Transform.translate(
                    offset: const Offset(-4, -4),
                    child: GestureDetector(
                      onTap: _showColorSchemeDialog,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.25),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.palette_rounded,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Основной контент — список сообщений (или состояния загрузки/ошибки/пусто)
          if (_initialLoading)
            const Center(child: CircularProgressIndicator(color: Colors.orange))
          else if (_loadError != null && _messages.isEmpty)
            _buildErrorState()
          else
            _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),

          // Парящее поле ввода
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInputField(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final isDark = _isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, size: 48, color: subTextColor),
        const SizedBox(height: 16),
        Text(_loadError!, style: TextStyle(fontSize: 16, color: textColor)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            setState(() {
              _initialLoading = true;
              _loadError = null;
            });
            _loadMessages();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Повторить',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptyState() {
    final isDark = _isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : _currentColorScheme.myBorderColor.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.forum_rounded,
            size: 44,
            color: _currentColorScheme.myBorderColor.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 16),
        Text('Нет сообщений', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 6),
        Text('Начните обсуждение первым!', style: TextStyle(fontSize: 14, color: subTextColor)),
      ]),
    );
  }

  // Список сообщений с отступом снизу для поля ввода
  Widget _buildMessagesList() {
    final isDark = _isDarkMode;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.only(
        top: 6,
        bottom: 100, // отступ, чтобы последние сообщения не перекрывались полем
        left: 10,
        right: 10,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[_messages.length - 1 - index];
        final isMine = msg['sender_id'] == _currentUserId;
        final senderName = msg['sender_name'] ?? '';
        final senderAvatar = msg['sender_avatar'] ?? '';
        final text = msg['text'] ?? '';
        final time = msg['created_at'] ?? '';
        final isEdited = msg['is_edited'] == true;
        final status = msg['status']?.toString() ?? 'read';
        final replyToData = msg['reply_to_message'] as Map<String, dynamic>?;

        final borderColor = isMine ? const Color(0xFFFF6B35) : _currentColorScheme.otherBorderColor;
        final textColor = isMine ? _currentColorScheme.myTextColor : _currentColorScheme.otherTextColor;

        return GestureDetector(
          onLongPress: status == 'failed' ? null : () => _showMessageOptions(msg, isMine),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: status == 'failed' ? Colors.red : borderColor,
                        width: status == 'failed' ? 2 : 2.5,
                      ),
                      borderRadius: BorderRadius.circular(20).copyWith(
                        topRight: isMine ? const Radius.circular(4) : null,
                        topLeft: !isMine ? const Radius.circular(4) : null,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMine)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: borderColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildAvatar(
                                    senderAvatar,
                                    senderName,
                                    radius: 14,
                                    bgColor: borderColor.withOpacity(0.2),
                                    textColor: textColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    senderName.isNotEmpty ? senderName : 'Пользователь',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (replyToData != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border(
                                left: BorderSide(
                                  color: textColor.withOpacity(0.5),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.reply_rounded,
                                      size: 12,
                                      color: textColor.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      replyToData['sender_name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: textColor.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  replyToData['text'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor.withOpacity(0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (text.isNotEmpty)
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 15,
                              color: textColor,
                              height: 1.3,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(time),
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withOpacity(0.5),
                              ),
                            ),
                            if (isEdited) ...[
                              const SizedBox(width: 3),
                              Text(
                                'изм.',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: textColor.withOpacity(0.4),
                                ),
                              ),
                            ],
                            if (isMine) ...[
                              const SizedBox(width: 4),
                              _buildStatusIcon(status, isMine),
                            ],
                          ],
                        ),
                        if (status == 'failed')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Text(
                                  'Не доставлено',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade400,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _retryMessage(msg),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.refresh_rounded, size: 12, color: Colors.red.shade400),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Повторить',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.red.shade400,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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

  void _showMessageOptions(Map<String, dynamic> message, bool isMine) {
    if (!mounted) return;

    final isDark = _isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.message_rounded,
                          color: Color(0xFFFF6B35),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMine ? 'Вы' : (message['sender_name'] ?? 'Пользователь'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              message['text'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                  height: 1,
                ),
                _buildOptionTile(
                  icon: Icons.reply_rounded,
                  title: 'Ответить',
                  color: const Color(0xFFFF6B35),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setReplyToMessage(message);
                  },
                  isDark: isDark,
                ),
                if (isMine) ...[
                  _buildOptionTile(
                    icon: Icons.edit_rounded,
                    title: 'Редактировать',
                    color: const Color(0xFF2D7FF9),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startEditMessage(message);
                    },
                    isDark: isDark,
                  ),
                  _buildOptionTile(
                    icon: Icons.delete_rounded,
                    title: 'Удалить',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showDeleteConfirmation(message['message_id']);
                    },
                    isDark: isDark,
                  ),
                ],
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Закрыть',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? Colors.white38 : Colors.grey.shade400,
        size: 18,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  void _showDeleteConfirmation(String messageId) {
    if (!mounted) return;

    final isDark = _isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Удалить?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          'Это действие нельзя отменить',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) _deleteMessage(messageId);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Удалить',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ ПАРЯЩЕЕ ПОЛЕ ВВОДА (БЕЗ ФОНА) ============
  Widget _buildInputField() {
    final isDark = _isDarkMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Индикаторы ответа/редактирования (прозрачные)
        if (_replyToMessageData != null || _editingMessageId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: Colors.transparent,
            child: _replyToMessageData != null
                ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.reply_rounded, color: Color(0xFFFF6B35), size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ответ ${_replyToMessageData!['sender_name'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                      Text(
                        _replyToMessageData!['text'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _cancelReply,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            )
                : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7FF9).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.edit_rounded, color: Color(0xFF2D7FF9), size: 14),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Редактирование',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D7FF9),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _cancelEdit,
                  child: Text(
                    'Отмена',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Строка ввода: только поле и кнопка (без лишней иконки)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Овальное поле ввода
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _textController,
                      onSubmitted: (_) => _handleSendMessage(),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 1,
                      style: const TextStyle(color: Colors.black87, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Сообщение...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Кнопка отправки
                GestureDetector(
                  onTap: _sending ? null : _handleSendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _sending
                          ? null
                          : const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
                      ),
                      color: _sending ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200) : null,
                      shape: BoxShape.circle,
                      boxShadow: _sending
                          ? null
                          : [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _sending
                        ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    )
                        : Icon(
                      _editingMessageId != null ? Icons.check_rounded : Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
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
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) return DateFormat('HH:mm').format(dt);
      if (dt.year == now.year) return DateFormat('dd MMM, HH:mm', 'ru').format(dt);
      return DateFormat('dd.MM.yy, HH:mm').format(dt);
    } catch (_) { return ''; }
  }
}
