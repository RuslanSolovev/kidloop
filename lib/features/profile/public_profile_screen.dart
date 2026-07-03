import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../messenger/chat_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _profile;

  int _itemsCount = 0;
  int _friendsCount = 0;

  int _sentOffersCount = 0;
  int _sentAcceptedCount = 0;

  int _receivedOffersCount = 0;
  int _receivedAcceptedCount = 0;

  int _completedDealsCount = 0;
  int _acceptedDealsCount = 0;

  int _totalCancelledCount = 0;
  int _cancelledByUserCount = 0;
  int _cancelledByPartnerCount = 0;
  Map<String, int> _myCancelReasons = {};
  Map<String, int> _partnerCancelReasons = {};

  bool _loading = true;
  String? _currentUserId;
  bool _isFriend = false;
  bool _isPending = false;
  bool _isLoadingActions = false;

  // 🔥 Поддержка тёмной/светлой темы
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  static const String usersApiUrl = 'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';
  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const String itemsApiUrl = 'https://functions.yandexcloud.net/d4ei9an1aushareidmjc';
  static const String tradesApiUrl = 'https://functions.yandexcloud.net/d4e77rr4t3hlvjo7n77b';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    await Future.wait([
      _loadAll(),
      _checkFriendship(),
    ]);
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadStats(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkFriendship() async {
    if (_currentUserId == null || _currentUserId == widget.userId) return;

    try {
      final friendsRes = await http.post(
        Uri.parse(usersApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "friends", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 5));

      final friendsData = jsonDecode(friendsRes.body);
      if (friendsData['ok'] == true && mounted) {
        final friends = friendsData['friends'] as List? ?? [];
        final isFriend = friends.any((f) => f['user_id'] == widget.userId);

        bool isPending = false;
        if (!isFriend) {
          final pendingRes = await http.post(
            Uri.parse(usersApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"action": "pending-requests", "user_id": widget.userId}),
          ).timeout(const Duration(seconds: 3));

          final pendingData = jsonDecode(pendingRes.body);
          if (pendingData['ok'] == true) {
            final requests = pendingData['requests'] as List? ?? [];
            isPending = requests.any((r) => r['user_id'] == _currentUserId);
          }
        }

        setState(() {
          _isFriend = isFriend;
          _isPending = isPending;
        });
      }
    } catch (e) {
      print('Error checking friendship: $e');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await http.post(
        Uri.parse(usersApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "search",
          "query": "",
          "user_id": "",
          "offset": 0,
          "limit": 100,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final users = data['users'] as List?;
        if (users != null) {
          final match = users.firstWhere(
                (u) => u['user_id'] == widget.userId,
            orElse: () => null,
          );
          if (match != null && mounted) {
            setState(() => _profile = match);
          }
        }
      }

      if (_profile == null) {
        final listRes = await http.post(
          Uri.parse(usersApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "action": "list",
            "query": "",
            "user_id": "",
            "offset": 0,
            "limit": 100,
          }),
        ).timeout(const Duration(seconds: 8));

        final listData = jsonDecode(listRes.body);
        if (listData['ok'] == true) {
          final users = listData['users'] as List?;
          if (users != null) {
            final match = users.firstWhere(
                  (u) => u['user_id'] == widget.userId,
              orElse: () => null,
            );
            if (match != null && mounted) {
              setState(() => _profile = match);
            }
          }
        }
      }

      if (_profile != null) {
        final friendsRes = await http.post(
          Uri.parse(usersApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"action": "friends", "user_id": widget.userId}),
        ).timeout(const Duration(seconds: 5));

        final friendsData = jsonDecode(friendsRes.body);
        if (friendsData['ok'] == true && mounted) {
          final friends = friendsData['friends'] as List? ?? [];
          setState(() => _friendsCount = friends.length);
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final itemsRes = await http.post(
        Uri.parse(itemsApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      ).timeout(const Duration(seconds: 5));

      final itemsData = jsonDecode(itemsRes.body);
      if (itemsData['ok'] == true) {
        final items = itemsData['items'] as List;
        final userItems = items.where((i) => i['user_id'] == widget.userId).toList();
        if (mounted) setState(() => _itemsCount = userItems.length);
      }

      final offersRes = await http.post(
        Uri.parse(tradesApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list", "user_id": widget.userId}),
      ).timeout(const Duration(seconds: 8));

      final offersData = jsonDecode(offersRes.body);
      if (offersData['ok'] == true) {
        final offers = offersData['offers'] as List;
        final userId = widget.userId;

        final sentOffers = offers.where((o) => o['from_user_id'] == userId).toList();
        final sentAccepted = sentOffers.where((o) =>
        o['status'] == 'accepted' || o['status'] == 'shipped' ||
            o['status'] == 'completed' || o['status'] == 'cancelled'
        ).toList();
        final receivedOffers = offers.where((o) => o['to_user_id'] == userId).toList();
        final receivedAccepted = receivedOffers.where((o) =>
        o['status'] == 'accepted' || o['status'] == 'shipped' ||
            o['status'] == 'completed' || o['status'] == 'cancelled'
        ).toList();
        final completedDeals = offers.where((o) => o['status'] == 'completed').toList();
        final acceptedDeals = offers.where((o) =>
        o['status'] == 'accepted' || o['status'] == 'shipped' ||
            o['status'] == 'completed' || o['status'] == 'cancelled'
        ).toList();
        final cancelledDeals = offers.where((o) => o['status'] == 'cancelled').toList();

        int userCancelled = 0;
        int partnerCancelled = 0;
        final Map<String, int> myReasons = {};
        final Map<String, int> partnerReasons = {};

        for (final deal in cancelledDeals) {
          final whoCancelled = deal['who_cancelled']?.toString() ?? '';
          final reason = deal['cancel_reason']?.toString().trim() ?? '';

          if (whoCancelled == userId) {
            userCancelled++;
            if (reason.isNotEmpty) {
              myReasons[reason] = (myReasons[reason] ?? 0) + 1;
            }
          } else if (whoCancelled.isNotEmpty) {
            partnerCancelled++;
            if (reason.isNotEmpty) {
              partnerReasons[reason] = (partnerReasons[reason] ?? 0) + 1;
            }
          }
        }

        if (mounted) {
          setState(() {
            _sentOffersCount = sentOffers.length;
            _sentAcceptedCount = sentAccepted.length;
            _receivedOffersCount = receivedOffers.length;
            _receivedAcceptedCount = receivedAccepted.length;
            _completedDealsCount = completedDeals.length;
            _acceptedDealsCount = acceptedDeals.length;
            _totalCancelledCount = cancelledDeals.length;
            _cancelledByUserCount = userCancelled;
            _cancelledByPartnerCount = partnerCancelled;
            _myCancelReasons = myReasons;
            _partnerCancelReasons = partnerReasons;
          });
        }
      }
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  int _calculateRating() {
    if (_acceptedDealsCount == 0) return 0;
    return ((_completedDealsCount / _acceptedDealsCount) * 100).round();
  }

  int _sentSuccessRate() {
    if (_sentOffersCount == 0) return 0;
    return ((_sentAcceptedCount / _sentOffersCount) * 100).round();
  }

  int _receivedSuccessRate() {
    if (_receivedOffersCount == 0) return 0;
    return ((_receivedAcceptedCount / _receivedOffersCount) * 100).round();
  }

  Future<void> _sendFriendRequest() async {
    if (_currentUserId == null) return;
    setState(() => _isLoadingActions = true);

    try {
      await http.post(
        Uri.parse(usersApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "send-friend-request",
          "user_id": _currentUserId,
          "friend_id": widget.userId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _isPending = true;
          _isLoadingActions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Заявка в друзья отправлена! 🎉'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingActions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить заявку'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeFriend() async {
    final isDark = _isDarkMode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить из друзей?', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('Вы уверены, что хотите удалить этого пользователя из друзей?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoadingActions = true);

    try {
      await http.post(
        Uri.parse(usersApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "remove-friend",
          "user_id": _currentUserId,
          "friend_id": widget.userId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _isFriend = false;
          _isPending = false;
          _isLoadingActions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь удалён из друзей'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingActions = false);
    }
  }

  Future<void> _openChat() async {
    if (_currentUserId == null) return;

    try {
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "get-or-create-chat",
          "user1_id": _currentUserId,
          "user2_id": widget.userId,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && data['chat_id'] != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: data['chat_id'],
              otherUserId: widget.userId,
              otherName: _profile?['name'] ?? 'Пользователь',
              otherAvatar: _profile?['avatar_url'] ?? '',
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть чат'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка соединения'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🔥 Хелперы для цветов темы
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Профиль', style: TextStyle(color: _textColor)),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Профиль', style: TextStyle(color: _textColor)),
        ),
        body: Center(child: Text('Профиль не найден', style: TextStyle(color: _subTextColor))),
      );
    }

    final name = _profile!['name'] ?? 'Пользователь';
    final city = _profile!['city'] ?? '';
    final bio = _profile!['bio'] ?? '';
    final telegram = _profile!['telegram'] ?? '';
    final age = _profile!['age'] ?? 0;
    final avatarUrl = _profile!['avatar_url'] ?? '';
    final isSelf = _currentUserId == widget.userId;
    final rating = _calculateRating();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorderColor),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: _textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(name, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_isFriend && !isSelf)
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorderColor),
              ),
              child: IconButton(
                icon: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 20),
                tooltip: 'Удалить из друзей',
                onPressed: _removeFriend,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(name, city, avatarUrl, isSelf),
            const SizedBox(height: 20),
            _buildRatingCard(rating),
            const SizedBox(height: 20),
            _buildSectionTitle('📊 Статистика'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Вещей', value: '$_itemsCount', icon: Icons.inventory_rounded, color: Colors.blue, isDark: _isDarkMode)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(title: 'Друзей', value: '$_friendsCount', icon: Icons.people_rounded, color: Colors.indigo, isDark: _isDarkMode)),
              ],
            ),
            const SizedBox(height: 10),
            _buildTradeStatCard(
              title: 'Предложил обменов',
              total: _sentOffersCount,
              success: _sentAcceptedCount,
              rate: _sentSuccessRate(),
              icon: Icons.send_rounded,
              color: Colors.orange,
              successLabel: 'принято',
            ),
            const SizedBox(height: 10),
            _buildTradeStatCard(
              title: 'Предложили обменов',
              total: _receivedOffersCount,
              success: _receivedAcceptedCount,
              rate: _receivedSuccessRate(),
              icon: Icons.inbox_rounded,
              color: Colors.purple,
              successLabel: 'принято',
            ),
            const SizedBox(height: 10),
            _buildTradeStatCard(
              title: 'Успешных сделок',
              total: _completedDealsCount,
              success: _acceptedDealsCount,
              rate: _acceptedDealsCount > 0 ? ((_completedDealsCount / _acceptedDealsCount) * 100).round() : 0,
              icon: Icons.verified_rounded,
              color: Colors.green,
              successLabel: 'из $_acceptedDealsCount принятых',
            ),

            if (_totalCancelledCount > 0) ...[
              const SizedBox(height: 20),
              _buildSectionTitle('🚫 Отмены сделок'),
              const SizedBox(height: 12),
              _buildCancellationsCard(),
            ],

            const SizedBox(height: 24),
            _buildSectionTitle('ℹ️ Информация'),
            const SizedBox(height: 12),
            _buildInfoCard(age, telegram, bio),
          ],
        ),
      ),
    );
  }

  Widget _buildCancellationsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(_isDarkMode ? 0.15 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.cancel_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Отмены сделок', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _textColor)),
              Text('Всего $_totalCancelledCount', style: TextStyle(color: Colors.red.shade400, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ]),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: GestureDetector(
                onTap: _myCancelReasons.isNotEmpty ? () => _showReasonsDialog('Мои отмены', _myCancelReasons, Colors.orange) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(_isDarkMode ? 0.15 : 0.08),
                        Colors.orange.withOpacity(_isDarkMode ? 0.05 : 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.orange.withOpacity(_isDarkMode ? 0.1 : 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 6)],
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.orange, size: 24),
                    ),
                    const SizedBox(height: 10),
                    Text('$_cancelledByUserCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: Colors.orange)),
                    Text('Отменил сам', style: TextStyle(fontSize: 12, color: _subTextColor)),
                    if (_myCancelReasons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.visibility, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('Причины', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _partnerCancelReasons.isNotEmpty ? () => _showReasonsDialog('Отмены партнёров', _partnerCancelReasons, Colors.purple) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withOpacity(_isDarkMode ? 0.15 : 0.08),
                        Colors.purple.withOpacity(_isDarkMode ? 0.05 : 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.purple.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.purple.withOpacity(_isDarkMode ? 0.1 : 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 6)],
                      ),
                      child: const Icon(Icons.people_rounded, color: Colors.purple, size: 24),
                    ),
                    const SizedBox(height: 10),
                    Text('$_cancelledByPartnerCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: Colors.purple)),
                    Text('Отменил партнёр', style: TextStyle(fontSize: 12, color: _subTextColor)),
                    if (_partnerCancelReasons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.visibility, size: 14, color: Colors.purple),
                          const SizedBox(width: 4),
                          Text('Причины', style: TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _showReasonsDialog(String title, Map<String, int> reasons, Color accentColor) {
    final isDark = _isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: accentColor, size: 20),
                ),
                const SizedBox(width: 10),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentColor)),
              ],
            ),
            const Divider(height: 24),
            if (reasons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Нет данных о причинах отмен', style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600, fontSize: 14))),
              )
            else
              ...reasons.entries.map((entry) {
                final reasonIcon = _getCancelReasonIcon(entry.key);
                final reasonColor = _getCancelReasonColor(entry.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: reasonColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(reasonIcon, color: reasonColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry.key, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                          if (entry.value > 1)
                            Text('${entry.value} раза', style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 12)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: reasonColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text('${entry.value}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: reasonColor)),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Закрыть', style: TextStyle(color: Colors.orange)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCancelReasonIcon(String reason) {
    switch (reason) {
      case 'Подозрение на мошенника': return Icons.security_rounded;
      case 'Скандальный пользователь': return Icons.report_rounded;
      case 'Товар не соответствует': return Icons.broken_image_rounded;
      case 'Передумал': return Icons.psychology_rounded;
      default: return Icons.info_outline;
    }
  }

  Color _getCancelReasonColor(String reason) {
    switch (reason) {
      case 'Подозрение на мошенника': return Colors.red;
      case 'Скандальный пользователь': return Colors.orange;
      case 'Товар не соответствует': return Colors.amber.shade700;
      case 'Передумал': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Widget _buildProfileHeader(String name, String city, String avatarUrl, bool isSelf) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
            ),
            child: CircleAvatar(
              radius: 55,
              backgroundColor: Colors.white,
              backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 40))
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          if (city.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 18),
              const SizedBox(width: 4),
              Text(city, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            ]),
          ],
          if (_isFriend) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.people, color: Colors.white.withOpacity(0.8), size: 16),
              const SizedBox(width: 4),
              Text('У вас в друзьях', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
            ]),
          ],
          if (!isSelf) ...[
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Написать'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _isLoadingActions
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : ElevatedButton.icon(
                  onPressed: _isFriend ? _removeFriend : (_isPending ? null : _sendFriendRequest),
                  icon: Icon(
                    _isFriend ? Icons.person_remove_rounded : (_isPending ? Icons.access_time_rounded : Icons.person_add_rounded),
                    size: 18,
                  ),
                  label: Text(
                    _isFriend ? 'В друзьях' : (_isPending ? 'Заявка отправлена' : 'Добавить'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFriend
                        ? Colors.white.withOpacity(0.25)
                        : (_isPending ? Colors.white.withOpacity(0.15) : Colors.amber),
                    foregroundColor: _isFriend || _isPending ? Colors.white : Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingCard(int rating) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(_isDarkMode ? 0.15 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rating >= 80
                    ? [Colors.green.shade400, Colors.teal.shade400]
                    : rating >= 50
                    ? [Colors.amber.shade400, Colors.orange.shade400]
                    : [Colors.red.shade300, Colors.red.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (rating >= 80 ? Colors.green : rating >= 50 ? Colors.orange : Colors.red).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Рейтинг надёжности', style: TextStyle(color: _subTextColor, fontSize: 13)),
              const SizedBox(height: 2),
              Text('$rating%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: _textColor)),
            ]),
          ),
          SizedBox(
            width: 80,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                rating >= 80 ? 'Отлично' : rating >= 50 ? 'Хорошо' : 'Низкий',
                style: TextStyle(
                  color: rating >= 80 ? Colors.green : rating >= 50 ? Colors.orange : Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rating / 100,
                  minHeight: 8,
                  backgroundColor: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    rating >= 80 ? Colors.green : rating >= 50 ? Colors.orange : Colors.red,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 3, height: 20, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _textColor)),
      ],
    );
  }

  Widget _buildTradeStatCard({
    required String title,
    required int total,
    required int success,
    required int rate,
    required IconData icon,
    required Color color,
    required String successLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(_isDarkMode ? 0.15 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: _subTextColor, fontSize: 12)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: _textColor)),
                if (success > 0) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(successLabel, style: TextStyle(color: _subTextColor, fontSize: 12)),
                  ),
                ],
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(total > 0 ? '$rate%' : '-', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(int age, String telegram, String bio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(_isDarkMode ? 0.15 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (age > 0) _infoRow(Icons.cake_rounded, 'Возраст', '$age лет'),
        if (telegram.isNotEmpty) _infoRow(Icons.telegram, 'Telegram', telegram),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('О себе', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textColor)),
          const SizedBox(height: 6),
          Text(bio, style: TextStyle(color: _subTextColor, fontSize: 14, height: 1.4)),
        ],
        if (age == 0 && telegram.isEmpty && bio.isEmpty)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info_outline, size: 20, color: _subTextColor),
            const SizedBox(width: 8),
            Text('Пользователь пока не заполнил информацию', style: TextStyle(color: _subTextColor, fontSize: 14)),
          ]),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.orange, size: 18),
        ),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.orange)),
        Text(value, style: TextStyle(color: _textColor, fontSize: 14)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 12)),
      ]),
    );
  }
}