// forum_screen.dart - КАК ЧАТ (мгновенный UI + галочки + НАСТРОЙКИ ЦВЕТОВ)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

// 🔥 Модель цветовой схемы форума
class ForumColorScheme {
  final Color myBgColor;
  final Color myTextColor;
  final Color otherBgColor;
  final Color otherTextColor;
  final Color backgroundColor;
  final String name;

  const ForumColorScheme({
    required this.myBgColor,
    required this.myTextColor,
    required this.otherBgColor,
    required this.otherTextColor,
    required this.backgroundColor,
    required this.name,
  });
}

// 🔥 Предустановленные цветовые схемы
const List<ForumColorScheme> _colorSchemes = [
  ForumColorScheme(
    name: 'Стандарт',
    myBgColor: Color(0xFFFF9800),
    myTextColor: Colors.white,
    otherBgColor: Colors.white,
    otherTextColor: Colors.black87,
    backgroundColor: Color(0xFFFFF8F0),
  ),
  ForumColorScheme(
    name: 'Океан',
    myBgColor: Color(0xFF2196F3),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFE3F2FD),
    otherTextColor: Color(0xFF1565C0),
    backgroundColor: Color(0xFFF0F8FF),
  ),
  ForumColorScheme(
    name: 'Лес',
    myBgColor: Color(0xFF4CAF50),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFE8F5E9),
    otherTextColor: Color(0xFF2E7D32),
    backgroundColor: Color(0xFFF1F8E9),
  ),
  ForumColorScheme(
    name: 'Закат',
    myBgColor: Color(0xFFE91E63),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFFCE4EC),
    otherTextColor: Color(0xFF880E4F),
    backgroundColor: Color(0xFFFFF5F5),
  ),
  ForumColorScheme(
    name: 'Фиолет',
    myBgColor: Color(0xFF9C27B0),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFF3E5F5),
    otherTextColor: Color(0xFF6A1B9A),
    backgroundColor: Color(0xFFFDF8FF),
  ),
  ForumColorScheme(
    name: 'Темный',
    myBgColor: Color(0xFF37474F),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFF1A1A2E),
    otherTextColor: Color(0xFFECEFF1),
    backgroundColor: Color(0xFF0A0A1A),
  ),
  ForumColorScheme(
    name: 'Мятный',
    myBgColor: Color(0xFF00897B),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFE0F2F1),
    otherTextColor: Color(0xFF004D40),
    backgroundColor: Color(0xFFF0FFFE),
  ),
  ForumColorScheme(
    name: 'Карамель',
    myBgColor: Color(0xFFFF6F00),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFFFF3E0),
    otherTextColor: Color(0xFFE65100),
    backgroundColor: Color(0xFFFFFBF5),
  ),
  ForumColorScheme(
    name: 'Лаванда',
    myBgColor: Color(0xFF7B1FA2),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFFF5F0FF),
    otherTextColor: Color(0xFF4A148C),
    backgroundColor: Color(0xFFFAF8FF),
  ),
  ForumColorScheme(
    name: 'Ночь',
    myBgColor: Color(0xFF455A64),
    myTextColor: Colors.white,
    otherBgColor: Color(0xFF2C3E50),
    otherTextColor: Color(0xFFECF0F1),
    backgroundColor: Color(0xFF1A1A2E),
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

  // 🔥 Настройки цветов
  int _selectedColorSchemeIndex = 0;
  late ForumColorScheme _currentColorScheme;

  static const String forumApiUrl = 'https://functions.yandexcloud.net/d4en6mi363fq4o5js5ee';
  static const String _cacheKey = 'forum_messages_cache';

  // 🔥 Используем Theme напрямую
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;
  Color get _inputFillColor => _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100;
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;

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

    // 🔥 Загружаем сохраненную цветовую схему
    _selectedColorSchemeIndex = prefs.getInt('forum_color_scheme_${widget.forumId}') ?? 0;
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
    await prefs.setInt('forum_color_scheme_${widget.forumId}', index);
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
                'Оформление форума',
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
                          Text('Предпросмотр', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 12)),
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
                          child: Text('Ваше сообщение',
                              style: TextStyle(color: _colorSchemes[_selectedColorSchemeIndex].myTextColor, fontSize: 14)),
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
                          child: Text('Сообщение участника',
                              style: TextStyle(color: _colorSchemes[_selectedColorSchemeIndex].otherTextColor, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 🔥 Сетка с выбором цветов
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
                      onTap: () => setDialogState(() => _selectedColorSchemeIndex = index),
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
                            Row(
                              children: [
                                Expanded(child: Container(height: 24, decoration: BoxDecoration(color: scheme.myBgColor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(8))))),
                                const SizedBox(width: 2),
                                Expanded(child: Container(height: 24, decoration: BoxDecoration(color: scheme.otherBgColor))),
                                const SizedBox(width: 2),
                                Expanded(child: Container(height: 24, decoration: BoxDecoration(color: scheme.backgroundColor, borderRadius: const BorderRadius.horizontal(right: Radius.circular(8))))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(scheme.name, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.orange : (isDark ? Colors.white70 : Colors.grey.shade700)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (isSelected) ...[
                              const SizedBox(height: 4),
                              Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withOpacity(0.2)), child: const Icon(Icons.check, color: Colors.orange, size: 14)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 16, color: isDark ? Colors.white54 : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Цвета: своё сообщение | чужое | фон', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600))),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey))),
            Container(
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]), borderRadius: BorderRadius.circular(12)),
              child: TextButton(
                onPressed: () {
                  setState(() => _currentColorScheme = _colorSchemes[_selectedColorSchemeIndex]);
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
        return const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70));
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

  Widget _buildAvatar(String? url, String name, {double radius = 16}) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: CachedNetworkImage(imageUrl: url, width: radius * 2, height: radius * 2, fit: BoxFit.cover,
            placeholder: (_, __) => _buildInitial(name, radius),
            errorWidget: (_, __, ___) => _buildInitial(name, radius),
          ),
        ),
      );
    }
    return _buildInitial(name, radius);
  }

  Widget _buildInitial(String name, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.orange.shade100,
      child: Text((name.isNotEmpty ? name[0] : '?').toUpperCase(),
          style: TextStyle(fontSize: radius * 0.85, color: Colors.orange, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;

    return Scaffold(
      backgroundColor: _currentColorScheme.backgroundColor, // 🔥 Фон из схемы
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorderColor),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: _textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.forumTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor)),
            Text('${_messages.length} сообщений', style: TextStyle(fontSize: 11, color: _subTextColor)),
          ],
        ),
        centerTitle: true,
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
            tooltip: 'Оформление форума',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_initialLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.orange)))
          else if (_loadError != null && _messages.isEmpty)
            Expanded(child: _buildErrorState())
          else
            Expanded(child: _messages.isEmpty ? _buildEmptyState() : _buildMessagesList()),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, size: 48, color: _subTextColor),
        const SizedBox(height: 16),
        Text(_loadError!, style: TextStyle(fontSize: 16, color: _textColor)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () { setState(() { _initialLoading = true; _loadError = null; }); _loadMessages(); },
          icon: const Icon(Icons.refresh), label: const Text('Повторить'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.forum_rounded, size: 48, color: _currentColorScheme.myBgColor.withOpacity(0.4)),
        const SizedBox(height: 16),
        Text('Нет сообщений', style: TextStyle(fontSize: 18, color: _textColor)),
        const SizedBox(height: 8),
        Text('Начните обсуждение первым!', style: TextStyle(color: _subTextColor)),
      ]),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController, reverse: true, padding: const EdgeInsets.only(bottom: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[_messages.length - 1 - index];
        final isMine = msg['sender_id'] == _currentUserId;
        final senderName = msg['sender_name'] ?? '';
        final senderAvatar = msg['sender_avatar'] ?? '';
        final text = msg['text'] ?? '';
        final time = msg['created_at'] ?? '';
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
                      border: isMine ? null : Border.all(color: _cardBorderColor),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDarkMode ? 0.15 : 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Stack(children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (!isMine)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              _buildAvatar(senderAvatar, senderName, radius: 15),
                              const SizedBox(width: 8),
                              Text(senderName.isNotEmpty ? senderName : 'Пользователь',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: otherText)),
                            ]),
                          ),
                        if (replyToData != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isMine ? Colors.white : Colors.black).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border(left: BorderSide(color: textColor.withOpacity(0.6), width: 3)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Icon(Icons.reply_rounded, size: 14, color: textColor.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Text(replyToData['sender_name'] ?? '',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.8))),
                              ]),
                              const SizedBox(height: 4),
                              Text(replyToData['text'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.7), fontStyle: FontStyle.italic)),
                            ]),
                          ),
                        Text(text, style: TextStyle(fontSize: 16, color: textColor)),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(_formatTime(time), style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7))),
                            if (isMine) ...[const SizedBox(width: 4), _buildStatusIcon(status, isMine)],
                          ]),
                        ),
                      ]),
                      if (status == 'failed')
                        Positioned(
                          right: 0, top: 0,
                          child: GestureDetector(
                            onTap: () => _retryMessage(msg),
                            child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.refresh, size: 16, color: Colors.white)),
                          ),
                        ),
                    ]),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(Icons.reply_rounded, color: Colors.orange), title: Text('Ответить', style: TextStyle(color: _textColor)), onTap: () { Navigator.pop(ctx); _setReplyToMessage(message); }),
            if (isMine) ...[
              ListTile(leading: const Icon(Icons.edit_rounded, color: Colors.orange), title: Text('Редактировать', style: TextStyle(color: _textColor)), onTap: () { Navigator.pop(ctx); _startEditMessage(message); }),
              ListTile(leading: const Icon(Icons.delete_rounded, color: Colors.red), title: const Text('Удалить', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); _showDeleteConfirmation(message['message_id']); }),
            ],
          ]),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String messageId) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить сообщение?', style: TextStyle(color: _textColor)),
        content: Text('Это действие нельзя отменить', style: TextStyle(color: _subTextColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: _subTextColor))),
          Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]), borderRadius: BorderRadius.all(Radius.circular(12))),
            child: TextButton(onPressed: () { Navigator.pop(ctx); if (mounted) _deleteMessage(messageId); }, child: const Text('Удалить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_replyToMessageData != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), border: Border(bottom: BorderSide(color: Colors.orange.withOpacity(0.2)))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.reply_rounded, color: Colors.orange, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ответ на сообщение ${_replyToMessageData!['sender_name'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange)),
              Text(_replyToMessageData!['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: _subTextColor)),
            ])),
            IconButton(icon: Icon(Icons.close_rounded, size: 20, color: _subTextColor), onPressed: _cancelReply),
          ]),
        ),
      if (_editingMessageId != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), border: Border(bottom: BorderSide(color: Colors.orange.withOpacity(0.2)))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_rounded, color: Colors.orange, size: 18)),
            const SizedBox(width: 10),
            const Text('Редактирование', style: TextStyle(fontSize: 13, color: Colors.orange)),
            const Spacer(),
            TextButton(onPressed: _cancelEdit, child: Text('Отмена', style: TextStyle(color: Colors.orange))),
          ]),
        ),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _surfaceColor, border: Border(top: BorderSide(color: _cardBorderColor))),
        child: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _textController,
                style: TextStyle(color: _textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _editingMessageId != null ? 'Редактировать...' : 'Сообщение...',
                  hintStyle: TextStyle(color: _subTextColor, fontSize: 14),
                  filled: true, fillColor: _inputFillColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.orange, width: 2)),
                ),
                onSubmitted: (_) => _handleSendMessage(),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1, maxLines: 5,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _handleSendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]), boxShadow: [BoxShadow(color: Color(0x4DFF9800), blurRadius: 8, offset: Offset(0, 2))]),
                child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ),



    ]);
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