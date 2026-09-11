// chat_screen.dart - Timeline style chat UI
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/notification_service.dart';

// 🔥 Модель цветовой схемы чата
class ChatColorScheme {
  final Color myBorderColor;
  final Color myTextColor;
  final Color otherBorderColor;
  final Color otherTextColor;
  final Color backgroundColor;
  final String name;

  const ChatColorScheme({
    required this.myBorderColor,
    required this.myTextColor,
    required this.otherBorderColor,
    required this.otherTextColor,
    required this.backgroundColor,
    required this.name,
  });
}

// 🔥 Предустановленные цветовые схемы
const List<ChatColorScheme> _colorSchemes = [
  ChatColorScheme(
    name: 'Неон',
    myBorderColor: Color(0xFF39BDF8),
    myTextColor: Color(0xFF52C7FF),
    otherBorderColor: Color(0xFFD7D0C4),
    otherTextColor: Color(0xFFE9E4D9),
    backgroundColor: Color(0xFF090A0C),
  ),
  ChatColorScheme(
    name: 'Океан',
    myBorderColor: Color(0xFF42C7FF),
    myTextColor: Color(0xFF62CEFF),
    otherBorderColor: Color(0xFF8DAFBD),
    otherTextColor: Color(0xFFDDE9ED),
    backgroundColor: Color(0xFF071116),
  ),
  ChatColorScheme(
    name: 'Лес',
    myBorderColor: Color(0xFF62D69A),
    myTextColor: Color(0xFF6FE3A5),
    otherBorderColor: Color(0xFFA8BFAF),
    otherTextColor: Color(0xFFE0E8E2),
    backgroundColor: Color(0xFF08110C),
  ),
  ChatColorScheme(
    name: 'Закат',
    myBorderColor: Color(0xFFFF8B72),
    myTextColor: Color(0xFFFFA08C),
    otherBorderColor: Color(0xFFD6B19F),
    otherTextColor: Color(0xFFE8D9D2),
    backgroundColor: Color(0xFF120A09),
  ),
  ChatColorScheme(
    name: 'Фиолет',
    myBorderColor: Color(0xFFB493FF),
    myTextColor: Color(0xFFC0A5FF),
    otherBorderColor: Color(0xFFB6AACB),
    otherTextColor: Color(0xFFE3DDF0),
    backgroundColor: Color(0xFF0E0A15),
  ),
  ChatColorScheme(
    name: 'Мята',
    myBorderColor: Color(0xFF55D8C0),
    myTextColor: Color(0xFF65E4CC),
    otherBorderColor: Color(0xFF9FC8C0),
    otherTextColor: Color(0xFFDDEDEA),
    backgroundColor: Color(0xFF07110F),
  ),
  ChatColorScheme(
    name: 'Янтарь',
    myBorderColor: Color(0xFFFFC857),
    myTextColor: Color(0xFFFFD36F),
    otherBorderColor: Color(0xFFD1BE94),
    otherTextColor: Color(0xFFE9E1CF),
    backgroundColor: Color(0xFF110D07),
  ),
  ChatColorScheme(
    name: 'Рубин',
    myBorderColor: Color(0xFFFF6683),
    myTextColor: Color(0xFFFF8199),
    otherBorderColor: Color(0xFFCBA4AC),
    otherTextColor: Color(0xFFE8DADD),
    backgroundColor: Color(0xFF12080C),
  ),
  ChatColorScheme(
    name: 'Графит',
    myBorderColor: Color(0xFFB7BEC8),
    myTextColor: Color(0xFFD5DAE1),
    otherBorderColor: Color(0xFF7C838C),
    otherTextColor: Color(0xFFC9CDD2),
    backgroundColor: Color(0xFF0B0D10),
  ),
  ChatColorScheme(
    name: 'Лайм',
    myBorderColor: Color(0xFFB9E769),
    myTextColor: Color(0xFFC8F47D),
    otherBorderColor: Color(0xFFB1BE9C),
    otherTextColor: Color(0xFFE3E9D9),
    backgroundColor: Color(0xFF0B1007),
  ),
  // Более светлые варианты
  ChatColorScheme(
    name: 'Лёд',
    myBorderColor: Color(0xFF3AA7FF),
    myTextColor: Color(0xFF0877D1),
    otherBorderColor: Color(0xFF9AA9B8),
    otherTextColor: Color(0xFF24313D),
    backgroundColor: Color(0xFFF1F6FA),
  ),
  ChatColorScheme(
    name: 'Облако',
    myBorderColor: Color(0xFF6E7CFF),
    myTextColor: Color(0xFF4C56C8),
    otherBorderColor: Color(0xFFACB4C0),
    otherTextColor: Color(0xFF333944),
    backgroundColor: Color(0xFFF5F6FA),
  ),
  ChatColorScheme(
    name: 'Сливки',
    myBorderColor: Color(0xFFB47B2C),
    myTextColor: Color(0xFF8A5C15),
    otherBorderColor: Color(0xFFC4B69D),
    otherTextColor: Color(0xFF40392F),
    backgroundColor: Color(0xFFFAF6ED),
  ),
  ChatColorScheme(
    name: 'Роса',
    myBorderColor: Color(0xFF249D91),
    myTextColor: Color(0xFF147A70),
    otherBorderColor: Color(0xFFA8BAB6),
    otherTextColor: Color(0xFF31403D),
    backgroundColor: Color(0xFFF0F8F6),
  ),
  ChatColorScheme(
    name: 'Индиго Ночь',
    myBorderColor: Color(0xFF627DFF),
    myTextColor: Color(0xFF7790FF),
    otherBorderColor: Color(0xFF7F8AA8),
    otherTextColor: Color(0xFFD9DEEA),
    backgroundColor: Color(0xFF0B0F1A),
  ),
  // Ещё пять контрастных тёмных наборов
  ChatColorScheme(
    name: 'Сапфир',
    myBorderColor: Color(0xFF4C8DFF),
    myTextColor: Color(0xFF63A1FF),
    otherBorderColor: Color(0xFF8292AA),
    otherTextColor: Color(0xFFDCE3ED),
    backgroundColor: Color(0xFF090E17),
  ),
  ChatColorScheme(
    name: 'Магма',
    myBorderColor: Color(0xFFFF6848),
    myTextColor: Color(0xFFFF8064),
    otherBorderColor: Color(0xFFB79A92),
    otherTextColor: Color(0xFFE7DCD8),
    backgroundColor: Color(0xFF130907),
  ),
  ChatColorScheme(
    name: 'Бирюза',
    myBorderColor: Color(0xFF2FD3D3),
    myTextColor: Color(0xFF55E1DF),
    otherBorderColor: Color(0xFF8FAFB2),
    otherTextColor: Color(0xFFDCE8E9),
    backgroundColor: Color(0xFF071111),
  ),
  ChatColorScheme(
    name: 'Аметист',
    myBorderColor: Color(0xFF9B70FF),
    myTextColor: Color(0xFFB08BFF),
    otherBorderColor: Color(0xFF9F94B7),
    otherTextColor: Color(0xFFE5DFEC),
    backgroundColor: Color(0xFF100A17),
  ),
  ChatColorScheme(
    name: 'Моно',
    myBorderColor: Color(0xFFF1F3F5),
    myTextColor: Color(0xFFFFFFFF),
    otherBorderColor: Color(0xFF7A7E84),
    otherTextColor: Color(0xFFD7D9DC),
    backgroundColor: Color(0xFF0A0B0D),
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

  int _selectedColorSchemeIndex = 0;
  late ChatColorScheme _currentColorScheme;

  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const String uploadApiUrl = 'https://functions.yandexcloud.net/d4e3c2me21eou683ic6d';
  static const String _cacheKey = 'chat_messages_cache';

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

    final savedSchemeIndex = prefs.getInt('chat_color_scheme_${widget.chatId}') ?? 0;
    _selectedColorSchemeIndex = savedSchemeIndex < 0
        ? 0
        : (savedSchemeIndex >= _colorSchemes.length ? _colorSchemes.length - 1 : savedSchemeIndex);
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
    await prefs.setInt('chat_color_scheme_${widget.chatId}', index);
  }

  void _sendPushNotification(String text, {String? imageUrl}) {
    final displayText = imageUrl != null && imageUrl.isNotEmpty
        ? '📷 Фото'
        : (text.isNotEmpty ? text : 'Новое сообщение');

    NotificationService.sendNotification(
      targetUserId: widget.otherUserId,
      type: 'new_message',
      data: {
        'chat_id': widget.chatId,
        'sender_name': _currentUserName ?? 'Пользователь',
        'text': displayText,
        'image_url': imageUrl ?? '',
        'other_user_id': _currentUserId ?? '',
        'other_name': _currentUserName ?? 'Собеседник',
        'other_avatar': _currentUserAvatar ?? '',
      },
    );
  }

  void _showColorSchemeDialog() {
    var pendingIndex = _selectedColorSchemeIndex;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final scheme = _colorSchemes[pendingIndex];
            final panelColor = Color.lerp(scheme.backgroundColor, Colors.white, 0.025)!;
            final subtle = scheme.otherTextColor.withOpacity(0.48);

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(
                  top: BorderSide(color: scheme.myBorderColor.withOpacity(0.28)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 36,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.otherTextColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: scheme.myBorderColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.myBorderColor.withOpacity(0.28)),
                            ),
                            child: Icon(Icons.auto_awesome_rounded, color: scheme.myBorderColor, size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Оформление чата',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                    color: scheme.otherTextColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Линии, сообщения и акцент',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 9,
                                    letterSpacing: 0.25,
                                    color: subtle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: _buildSchemePreview(scheme),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'СТИЛИ',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: subtle,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.25,
                        ),
                        itemCount: _colorSchemes.length,
                        itemBuilder: (context, index) {
                          final item = _colorSchemes[index];
                          final selected = pendingIndex == index;
                          return GestureDetector(
                            onTap: () => setDialogState(() => pendingIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selected ? item.myBorderColor.withOpacity(0.09) : Colors.white.withOpacity(0.018),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected ? item.myBorderColor.withOpacity(0.75) : item.otherTextColor.withOpacity(0.08),
                                  width: selected ? 1.2 : 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: item.backgroundColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: item.otherTextColor.withOpacity(0.12)),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: 6,
                                          right: 6,
                                          top: 7,
                                          child: Container(height: 1.3, color: item.otherBorderColor.withOpacity(0.55)),
                                        ),
                                        Positioned(
                                          left: 6,
                                          right: 6,
                                          bottom: 7,
                                          child: Container(height: 1.3, color: item.myBorderColor.withOpacity(0.65)),
                                        ),
                                        Center(
                                          child: Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(shape: BoxShape.circle, color: item.myBorderColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        color: selected ? item.myBorderColor : item.otherTextColor.withOpacity(0.78),
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Icon(Icons.check_circle_rounded, size: 16, color: item.myBorderColor),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: Colors.white.withOpacity(0.025),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                'Отмена',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: scheme.otherTextColor.withOpacity(0.65),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedColorSchemeIndex = pendingIndex;
                                  _currentColorScheme = _colorSchemes[pendingIndex];
                                });
                                _saveColorScheme(pendingIndex);
                                Navigator.pop(ctx);
                              },
                              style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: scheme.myBorderColor.withOpacity(0.13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: scheme.myBorderColor.withOpacity(0.42)),
                                ),
                              ),
                              child: Text(
                                'Применить',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.myBorderColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSchemePreview(ChatColorScheme scheme) {
    return Container(
      height: 136,
      decoration: BoxDecoration(
        color: scheme.backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.otherTextColor.withOpacity(0.10)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 39,
            top: 10,
            bottom: 10,
            child: Container(width: 1, color: scheme.otherBorderColor.withOpacity(0.28)),
          ),
          Positioned(
            left: 18,
            top: 23,
            child: Container(width: 21, height: 1, color: scheme.otherBorderColor.withOpacity(0.28)),
          ),
          Positioned(
            left: 39,
            top: 20,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.otherBorderColor),
            ),
          ),
          Positioned(
            left: 50,
            top: 34,
            right: 16,
            child: Text(
              'Hello Neo',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: scheme.otherTextColor),
            ),
          ),
          Positioned(
            left: 39,
            top: 76,
            child: Container(width: 45, height: 1, color: scheme.myBorderColor.withOpacity(0.28)),
          ),
          Positioned(
            left: 39,
            top: 73,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.myBorderColor),
            ),
          ),
          Positioned(
            left: 92,
            top: 66,
            right: 14,
            child: Text(
              'Who is this?',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: scheme.myTextColor),
            ),
          ),
          Positioned(
            left: 50,
            bottom: 17,
            right: 16,
            child: Text(
              'subtle separators / grouped messages',
              style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: scheme.otherTextColor.withOpacity(0.42)),
            ),
          ),
        ],
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
              (server['image_url'] == pendingImage && pendingImage.isNotEmpty));
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
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
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
        _sendPushNotification(text.isNotEmpty ? text : '', imageUrl: imageUrl);
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

        if (!isEditing) {
          _sendPushNotification(text);
        }

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
            SnackBar(
              content: Text(data['errorMessage'] ?? 'Ошибка'),
              backgroundColor: Colors.red,
            ),
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
          title: const Text('Редактировать фото'),
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
                    placeholder: (_, __) => Container(
                      height: 150,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 150,
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.broken_image, size: 40)),
                    ),
                  )
                      : Container(
                    height: 150,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              if (newImageFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: () => setDialogState(() {
                      newImageFile = null;
                      newImageUrl = null;
                    }),
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
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editImageMessage(
      String messageId,
      String text,
      File? newImageFile,
      String? currentImageUrl,
      ) async {
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
            SnackBar(
              content: Text(data['errorMessage'] ?? 'Ошибка редактирования'),
              backgroundColor: Colors.red,
            ),
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
        return SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.2,
            color: _mutedText,
          ),
        );
      case 'sent':
        return Icon(Icons.check_rounded, size: 12, color: _mutedText);
      case 'read':
        return Icon(Icons.done_all_rounded, size: 12, color: _accentBlue);
      case 'failed':
        return const Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFFF6B6B));
      default:
        return Icon(Icons.done_all_rounded, size: 12, color: _accentBlue);
    }
  }

  Widget _buildAvatar(String? url, String name, {double radius = 16, Color? bgColor, Color? textColor}) {
    final fallbackAccent = _currentColorScheme.myBorderColor;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor ?? Colors.white.withOpacity(0.06),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: bgColor ?? Colors.white.withOpacity(0.06),
              child: Center(
                child: Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: radius * 0.85,
                    color: textColor ?? fallbackAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: bgColor ?? fallbackAccent.withOpacity(0.08),
              child: Center(
                child: Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: radius * 0.85,
                    color: textColor ?? fallbackAccent,
                    fontWeight: FontWeight.w700,
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
      backgroundColor: bgColor ?? fallbackAccent.withOpacity(0.08),
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: radius * 0.85,
          color: textColor ?? fallbackAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = _chatBackground;
    final foreground = _primaryText;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: bg,
          textTheme: Theme.of(context).textTheme.apply(
            fontFamily: 'monospace',
            bodyColor: foreground,
            displayColor: foreground,
          ),
        ),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: bg,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: _buildTimelineAppBar(),
          ),
          body: Stack(
            children: [
              if (_initialLoading)
                _buildLoadingSkeleton()
              else if (_loadError != null && _messages.isEmpty)
                _buildErrorState()
              else
                _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildInputField(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _chatBackground => _currentColorScheme.backgroundColor;

  Color get _primaryText => _currentColorScheme.otherTextColor;
  Color get _mutedText => _currentColorScheme.otherTextColor.withOpacity(0.50);
  Color get _timelineColor => _currentColorScheme.otherBorderColor;
  Color get _accentBlue => _currentColorScheme.myBorderColor;
  Color get _myMessageColor => _currentColorScheme.myTextColor;
  Color get _panelColor => Color.lerp(_chatBackground, Colors.white, 0.035)!;

  Widget _buildTimelineAppBar() {
    final panelFill = Color.lerp(_chatBackground, Colors.white, 0.06)!.withOpacity(0.56);
    return Container(
      decoration: BoxDecoration(
        color: panelFill,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(
          bottom: BorderSide(color: _primaryText.withOpacity(0.018), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 8, 7),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: _mutedText, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _currentColorScheme.myBorderColor.withOpacity(0.55)),
                ),
                child: _buildAvatar(
                  widget.otherAvatar,
                  widget.otherName,
                  radius: 17,
                  bgColor: _currentColorScheme.otherBorderColor.withOpacity(0.08),
                  textColor: _accentBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.15,
                        color: _primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _currentColorScheme.myBorderColor),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$_totalMessages · диалог',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            letterSpacing: 0.2,
                            color: _mutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showColorSchemeDialog,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(Icons.tune_rounded, color: _mutedText, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 88, 12, 126),
      itemCount: 8,
      itemBuilder: (context, index) {
        final isMine = index.isOdd;
        return _buildSkeletonTimelineRow(index, isMine);
      },
    );
  }

  Widget _buildSkeletonTimelineRow(int index, bool isMine) {
    final width = 105.0 + ((index * 31) % 125);
    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _timelineColor.withOpacity(0.10),
                    _timelineColor.withOpacity(0.28),
                    _timelineColor.withOpacity(0.48),
                    _timelineColor.withOpacity(0.48),
                    _timelineColor.withOpacity(0.28),
                    _timelineColor.withOpacity(0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.035, 0.10, 0.18, 0.82, 0.90, 0.965, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 15.6 - 11,
            top: 18,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _timelineColor.withOpacity(0.34), width: 1.2),
              ),
            ),
          ),
          Positioned(
            left: isMine ? 58 : 60,
            right: isMine ? 10 : null,
            top: 30,
            child: Container(
              width: width,
              height: 10,
              decoration: BoxDecoration(
                color: _primaryText.withOpacity(0.045),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 34, color: _mutedText),
            const SizedBox(height: 14),
            Text(
              _loadError ?? 'Ошибка соединения',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _primaryText,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Проверьте подключение',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: _mutedText,
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () {
                if (!mounted) return;
                setState(() {
                  _initialLoading = true;
                  _loadError = null;
                });
                _loadMessages();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _accentBlue.withOpacity(0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: _accentBlue, size: 15),
                    const SizedBox(width: 7),
                    Text(
                      'ПОВТОРИТЬ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: _accentBlue,
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _EmptyTimelinePainter(
                  lineColor: _timelineColor.withOpacity(0.35),
                  accentColor: _accentBlue.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет сообщений',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _primaryText,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Напишите первое сообщение',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: _mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<List<Map<String, dynamic>>> _buildMessageGroups() {
    final groups = <List<Map<String, dynamic>>>[];
    for (final message in _messages) {
      if (groups.isEmpty) {
        groups.add([message]);
        continue;
      }
      final previous = groups.last.last;
      final previousSender = (previous['sender_id'] ?? '').toString();
      final currentSender = (message['sender_id'] ?? '').toString();
      if (previousSender == currentSender) {
        groups.last.add(message);
      } else {
        groups.add([message]);
      }
    }
    return groups;
  }

  Widget _buildMessagesList() {
    final groups = _buildMessageGroups();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 88, 10, 126),
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        final isMine = group.first['sender_id'] == _currentUserId;
        return _buildMessageGroup(
          group: group,
          groupIndex: groupIndex,
          isMine: isMine,
        );
      },
    );
  }

  Widget _buildMessageGroup({
    required List<Map<String, dynamic>> group,
    required int groupIndex,
    required bool isMine,
  }) {
    final first = group.first;
    final senderName = (first['sender_name'] ?? '').toString();
    final beamColor = isMine ? _accentBlue : _timelineColor;

    return Container(
      margin: EdgeInsets.only(
        top: groupIndex == 0 ? 2 : 15,
        bottom: 4,
      ),
      child: Stack(
        children: [
          // Тонкая вертикальная timeline остаётся общей для диалога.
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _timelineColor.withOpacity(0.10),
                    _timelineColor.withOpacity(0.28),
                    _timelineColor.withOpacity(0.48),
                    _timelineColor.withOpacity(0.48),
                    _timelineColor.withOpacity(0.28),
                    _timelineColor.withOpacity(0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.035, 0.10, 0.18, 0.82, 0.90, 0.965, 1.0],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isMine && senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 54, right: 12, bottom: 3),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.45,
                        color: _mutedText,
                      ),
                    ),
                  ),
                ...List.generate(group.length, (index) {
                  final message = group[index];
                  final isLast = index == group.length - 1;
                  final isFirst = index == 0;
                  return _buildGroupedMessageItem(
                    message,
                    isMine: isMine,
                    isFirstInGroup: isFirst,
                    isLastInGroup: isLast,
                    beamColor: beamColor,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedMessageItem(
      Map<String, dynamic> msg, {
        required bool isMine,
        required bool isFirstInGroup,
        required bool isLastInGroup,
        required Color beamColor,
      }) {
    final text = (msg['text'] ?? '').toString();
    final imageUrl = (msg['image_url'] ?? '').toString();
    final time = (msg['created_at'] ?? '').toString();
    final isEdited = msg['is_edited'] == true;
    final status = msg['status']?.toString() ?? 'read';
    final replyToData = msg['reply_to_message'] as Map<String, dynamic>?;
    final messageColor = status == 'failed'
        ? const Color(0xFFFF6B6B)
        : (isMine ? _myMessageColor : _primaryText);

    // Контент имеет естественную ширину до указанного максимума.
    // Благодаря этому верхний луч действительно повторяет ширину сообщения.
    final maxMessageWidth = MediaQuery.of(context).size.width * 0.78;

    final dotSize = isFirstInGroup ? 18.0 : 13.0;
    final dotInnerSize = isFirstInGroup ? 6.0 : 3.8;

    return GestureDetector(
      onLongPress: status == 'failed' ? null : () => _showMessageOptions(msg, isMine),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(
          left: 56,
          right: 12,
          top: isFirstInGroup ? 2 : 1,
          bottom: isLastInGroup ? 9 : 2,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Все точки — и мои, и собеседника — стоят строго на одной вертикали.
            Positioned(
              left: -56.0 + 14.0 + 1.6 - (dotSize / 2),
              top: 8,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: _chatBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: beamColor.withOpacity(isFirstInGroup ? 0.92 : 0.76),
                    width: isFirstInGroup ? 1.8 : 1.45,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: dotInnerSize,
                    height: dotInnerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: beamColor.withOpacity(isFirstInGroup ? 1.0 : 0.92),
                    ),
                  ),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Align(
                    alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxMessageWidth),
                      child: IntrinsicWidth(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Column(
                            crossAxisAlignment: isMine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              // НЕ разделитель между сообщениями, а отдельный тонкий луч
                              // над каждым сообщением. Края постепенно исчезают.
                              SizedBox(
                                height: 2,
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        beamColor.withOpacity(0.08),
                                        beamColor.withOpacity(0.22),
                                        beamColor.withOpacity(0.34),
                                        beamColor.withOpacity(0.22),
                                        beamColor.withOpacity(0.08),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.08, 0.22, 0.50, 0.78, 0.92, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),

                              if (replyToData != null)
                                _buildTimelineReplyPreview(replyToData, messageColor),

                              if (imageUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: GestureDetector(
                                    onTap: () => _showFullImage(imageUrl),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.56,
                                          maxHeight: MediaQuery.of(context).size.width * 0.56 * 1.15,
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          width: MediaQuery.of(context).size.width * 0.56,
                                          placeholder: (_, __) => Container(
                                            width: MediaQuery.of(context).size.width * 0.56,
                                            height: MediaQuery.of(context).size.width * 0.56 * 0.62,
                                            color: _primaryText.withOpacity(0.035),
                                            child: Center(
                                              child: SizedBox(
                                                width: 17,
                                                height: 17,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 1.3,
                                                  color: messageColor.withOpacity(0.72),
                                                ),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) => Container(
                                            width: MediaQuery.of(context).size.width * 0.56,
                                            height: MediaQuery.of(context).size.width * 0.56 * 0.52,
                                            color: _primaryText.withOpacity(0.035),
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              size: 28,
                                              color: _mutedText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              if (text.isNotEmpty)
                                Text(
                                  text,
                                  textAlign: isMine ? TextAlign.right : TextAlign.left,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.08,
                                    height: 1.30,
                                    color: messageColor,
                                  ),
                                ),

                              if (isLastInGroup) ...[
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTime(time),
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 8,
                                        letterSpacing: 0.2,
                                        color: _mutedText,
                                      ),
                                    ),
                                    if (isEdited) ...[
                                      const SizedBox(width: 5),
                                      Text(
                                        'изм.',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 7.5,
                                          color: _mutedText,
                                        ),
                                      ),
                                    ],
                                    if (isMine) ...[
                                      const SizedBox(width: 5),
                                      _buildTimelineStatusIcon(status),
                                    ],
                                  ],
                                ),
                              ],

                              if (status == 'failed')
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: GestureDetector(
                                    onTap: () => _retryMessage(msg),
                                    child: const Text(
                                      'НЕ ДОСТАВЛЕНО  ↻',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                        color: Color(0xFFFF6B6B),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineReplyPreview(Map<String, dynamic> reply, Color color) {
    final replyText = (reply['text'] ?? '').toString();
    final replySender = (reply['sender_name'] ?? '').toString();
    final replyImage = (reply['image_url'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 8, top: 3, bottom: 3),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color.withOpacity(0.58), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replySender.isEmpty ? 'ОТВЕТ' : 'ОТВЕТ · $replySender',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.25,
              color: color.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 2),
          if (replyImage.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined, size: 9, color: _mutedText),
                const SizedBox(width: 4),
                Text(
                  replyText.isEmpty ? 'Фото' : replyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: _mutedText),
                ),
              ],
            )
          else
            Text(
              replyText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8.5,
                height: 1.2,
                color: _mutedText,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineStatusIcon(String status) {
    switch (status) {
      case 'sending':
        return SizedBox(
          width: 9,
          height: 9,
          child: CircularProgressIndicator(strokeWidth: 1, color: _mutedText),
        );
      case 'sent':
        return Icon(Icons.check_rounded, size: 10, color: _mutedText);
      case 'read':
        return Icon(Icons.done_all_rounded, size: 10, color: _accentBlue);
      case 'failed':
        return const Icon(Icons.error_outline_rounded, size: 10, color: Color(0xFFFF6B6B));
      default:
        return Icon(Icons.done_all_rounded, size: 10, color: _accentBlue);
    }
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
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              panEnabled: true,
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
                      Icon(Icons.broken_image, size: 50, color: Colors.white54),
                      SizedBox(height: 8),
                      Text(
                        'Ошибка загрузки',
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
                      if (message['image_url'] != null && message['image_url'].toString().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: message['image_url'],
                            height: 32,
                            width: 32,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
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
                              isMine ? 'Вы' : widget.otherName,
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

  // Нижняя панель снова плавающая, полупрозрачная и сильно скруглённая.
  // Прозрачность применяется только к панели и полю ввода, не к тексту сообщений.
  Widget _buildInputField() {
    final hasContext = _replyToMessageData != null || _editingMessageId != null;
    final panelFill = Color.lerp(_chatBackground, Colors.white, 0.06)!.withOpacity(0.56);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: panelFill,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _primaryText.withOpacity(0.018)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasContext) _buildInputContextLine(),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickAndSendImage,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: Center(
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              color: _mutedText,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 1),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 42),
                          child: TextField(
                            controller: _textController,
                            onSubmitted: (_) => _handleSendMessage(),
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 4,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.05,
                              color: _primaryText,
                            ),
                            cursorColor: _accentBlue,
                            decoration: InputDecoration(
                              hintText: 'Сообщение...',
                              hintStyle: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: _mutedText,
                              ),
                              filled: true,
                              fillColor: _primaryText.withOpacity(0.035),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: _primaryText.withOpacity(0.045)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: _primaryText.withOpacity(0.045)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: _accentBlue.withOpacity(0.40), width: 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      GestureDetector(
                        onTap: _sending ? null : _handleSendMessage,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: _sending
                                ? SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: _accentBlue,
                              ),
                            )
                                : Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _accentBlue.withOpacity(0.11),
                                shape: BoxShape.circle,
                                border: Border.all(color: _accentBlue.withOpacity(0.32)),
                              ),
                              child: Icon(
                                _editingMessageId != null ? Icons.check_rounded : Icons.arrow_upward_rounded,
                                color: _accentBlue,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputContextLine() {
    final isReply = _replyToMessageData != null;
    final accent = isReply ? _accentBlue : _timelineColor;
    final title = isReply
        ? 'ОТВЕТ · ${_replyToMessageData!['sender_name'] ?? ''}'
        : 'РЕДАКТИРОВАНИЕ';
    final preview = isReply ? (_replyToMessageData!['text'] ?? '').toString() : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(42, 0, 39, 7),
      child: Row(
        children: [
          Container(width: 1, height: 24, color: accent.withOpacity(0.65)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                    color: accent,
                  ),
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8.5,
                      color: _mutedText,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: isReply ? _cancelReply : _cancelEdit,
            child: Icon(Icons.close_rounded, size: 15, color: _mutedText),
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
      if (dt.year == now.year) {
        return DateFormat('dd MMM, HH:mm', 'ru').format(dt);
      }
      return DateFormat('dd.MM.yy, HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _EmptyTimelinePainter extends CustomPainter {
  final Color lineColor;
  final Color accentColor;

  _EmptyTimelinePainter({
    required this.lineColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(centerX, 4),
      Offset(centerX, size.height - 4),
      linePaint,
    );

    final beamPaint = Paint()
      ..color = accentColor.withOpacity(0.45)
      ..strokeWidth = 1;

    final topY = size.height * 0.33;
    final bottomY = size.height * 0.66;

    canvas.drawLine(Offset(8, topY), Offset(centerX, topY), beamPaint);
    canvas.drawLine(Offset(centerX, bottomY), Offset(size.width - 8, bottomY), beamPaint);

    final topDot = Paint()..color = accentColor;
    canvas.drawCircle(Offset(centerX, topY), 4, topDot);

    final bottomDot = Paint()..color = lineColor;
    canvas.drawCircle(Offset(centerX, bottomY), 3, bottomDot);
  }

  @override
  bool shouldRepaint(covariant _EmptyTimelinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor;
  }
}