import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/notification_service.dart';
import '../messenger/chat_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  static const Color _accent = Color(0xFFFF6B00);
  static const Color _cyan = Color(0xFF42DFFF);
  static const Color _green = Color(0xFF40E0A0);
  static const Color _violet = Color(0xFF9A7CFF);
  static const Color _red = Color(0xFFFF5D73);
  static const Color _gold = Color(0xFFFFC857);

  static const String usersApiUrl =
      'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';

  static const String chatApiUrl =
      'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';

  static const String itemsApiUrl =
      'https://functions.yandexcloud.net/d4ei9an1aushareidmjc';

  static const String tradesApiUrl =
      'https://functions.yandexcloud.net/d4e77rr4t3hlvjo7n77b';

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
  bool _actionCompleted = false;

  bool get _isDarkMode =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _backgroundColor => _isDarkMode
      ? const Color(0xFF071016)
      : const Color(0xFFF5F8FB);

  Color get _surfaceColor => _isDarkMode
      ? const Color(0xFF0D1B22)
      : Colors.white;

  Color get _surfaceColor2 => _isDarkMode
      ? const Color(0xFF12242C)
      : const Color(0xFFF0F4F7);

  Color get _textColor => _isDarkMode
      ? Colors.white
      : const Color(0xFF17242C);

  Color get _subTextColor => _isDarkMode
      ? const Color(0xFF91A4AE)
      : const Color(0xFF6C7B84);

  Color get _borderColor => _isDarkMode
      ? Colors.white.withOpacity(0.07)
      : const Color(0xFFDCE4E9);

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

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _checkFriendship() async {
    if (_currentUserId == null ||
        _currentUserId == widget.userId) {
      return;
    }

    try {
      final friendsRes = await http
          .post(
        Uri.parse(usersApiUrl),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'friends',
          'user_id': _currentUserId,
        }),
      )
          .timeout(
        const Duration(seconds: 5),
      );

      final friendsData = jsonDecode(friendsRes.body);

      if (friendsData is! Map ||
          friendsData['ok'] != true) {
        return;
      }

      final friends = friendsData['friends'] as List? ?? [];

      final isFriend = friends.any(
            (friend) =>
        friend is Map &&
            friend['user_id'] == widget.userId,
      );

      bool isPending = false;

      if (!isFriend) {
        final pendingRes = await http
            .post(
          Uri.parse(usersApiUrl),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'action': 'pending-requests',
            'user_id': widget.userId,
          }),
        )
            .timeout(
          const Duration(seconds: 3),
        );

        final pendingData = jsonDecode(pendingRes.body);

        if (pendingData is Map &&
            pendingData['ok'] == true) {
          final requests =
              pendingData['requests'] as List? ?? [];

          isPending = requests.any(
                (request) =>
            request is Map &&
                request['user_id'] == _currentUserId,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isFriend = isFriend;
        _isPending = isPending;
      });
    } catch (e) {
      debugPrint(
        'Error checking friendship: $e',
      );
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await http
          .post(
        Uri.parse(usersApiUrl),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'search',
          'query': '',
          'user_id': '',
          'offset': 0,
          'limit': 100,
        }),
      )
          .timeout(
        const Duration(seconds: 8),
      );

      final data = jsonDecode(response.body);

      if (data is Map &&
          data['ok'] == true) {
        final users = data['users'] as List?;

        if (users != null) {
          Map<String, dynamic>? match;

          for (final user in users) {
            if (user is Map &&
                user['user_id'] == widget.userId) {
              match = Map<String, dynamic>.from(user);
              break;
            }
          }

          if (match != null) {
            _profile = match;
          }
        }
      }

      if (_profile == null) {
        final listRes = await http
            .post(
          Uri.parse(usersApiUrl),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'action': 'list',
            'query': '',
            'user_id': '',
            'offset': 0,
            'limit': 100,
          }),
        )
            .timeout(
          const Duration(seconds: 8),
        );

        final listData = jsonDecode(listRes.body);

        if (listData is Map &&
            listData['ok'] == true) {
          final users = listData['users'] as List?;

          if (users != null) {
            for (final user in users) {
              if (user is Map &&
                  user['user_id'] == widget.userId) {
                _profile =
                Map<String, dynamic>.from(user);
                break;
              }
            }
          }
        }
      }

      if (_profile != null) {
        final friendsRes = await http
            .post(
          Uri.parse(usersApiUrl),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'action': 'friends',
            'user_id': widget.userId,
          }),
        )
            .timeout(
          const Duration(seconds: 5),
        );

        final friendsData = jsonDecode(friendsRes.body);

        if (friendsData is Map &&
            friendsData['ok'] == true) {
          final friends =
              friendsData['friends'] as List? ?? [];

          if (mounted) {
            setState(() {
              _friendsCount = friends.length;
            });
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Error loading profile: $e',
      );
    }
  }

  Future<void> _loadStats() async {
    try {
      final itemsRes = await http
          .post(
        Uri.parse(itemsApiUrl),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'list',
        }),
      )
          .timeout(
        const Duration(seconds: 5),
      );

      final itemsData = jsonDecode(itemsRes.body);

      if (itemsData is Map &&
          itemsData['ok'] == true) {
        final items =
            itemsData['items'] as List? ?? [];

        final userItems = items.where(
              (item) =>
          item is Map &&
              item['user_id'] == widget.userId,
        );

        if (mounted) {
          setState(() {
            _itemsCount = userItems.length;
          });
        }
      }

      final offersRes = await http
          .post(
        Uri.parse(tradesApiUrl),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'list',
          'user_id': widget.userId,
        }),
      )
          .timeout(
        const Duration(seconds: 8),
      );

      final offersData = jsonDecode(offersRes.body);

      if (offersData is! Map ||
          offersData['ok'] != true) {
        return;
      }

      final offers =
          offersData['offers'] as List? ?? [];

      final userId = widget.userId;

      final sentOffers = offers.where(
            (offer) =>
        offer is Map &&
            offer['from_user_id'] == userId,
      ).toList();

      final sentAccepted = sentOffers.where(
            (offer) {
          final status = offer['status'];

          return status == 'accepted' ||
              status == 'shipped' ||
              status == 'completed' ||
              status == 'cancelled';
        },
      ).toList();

      final receivedOffers = offers.where(
            (offer) =>
        offer is Map &&
            offer['to_user_id'] == userId,
      ).toList();

      final receivedAccepted = receivedOffers.where(
            (offer) {
          final status = offer['status'];

          return status == 'accepted' ||
              status == 'shipped' ||
              status == 'completed' ||
              status == 'cancelled';
        },
      ).toList();

      final completedDeals = offers.where(
            (offer) =>
        offer is Map &&
            offer['status'] == 'completed',
      ).toList();

      final acceptedDeals = offers.where(
            (offer) {
          if (offer is! Map) {
            return false;
          }

          final status = offer['status'];

          return status == 'accepted' ||
              status == 'shipped' ||
              status == 'completed' ||
              status == 'cancelled';
        },
      ).toList();

      final cancelledDeals = offers.where(
            (offer) =>
        offer is Map &&
            offer['status'] == 'cancelled',
      ).toList();

      int userCancelled = 0;
      int partnerCancelled = 0;

      final Map<String, int> myReasons = {};
      final Map<String, int> partnerReasons = {};

      for (final deal in cancelledDeals) {
        if (deal is! Map) {
          continue;
        }

        final whoCancelled =
            deal['who_cancelled']?.toString() ?? '';

        final reason =
            deal['cancel_reason']?.toString().trim() ?? '';

        if (whoCancelled == userId) {
          userCancelled++;

          if (reason.isNotEmpty) {
            myReasons[reason] =
                (myReasons[reason] ?? 0) + 1;
          }
        } else if (whoCancelled.isNotEmpty) {
          partnerCancelled++;

          if (reason.isNotEmpty) {
            partnerReasons[reason] =
                (partnerReasons[reason] ?? 0) + 1;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _sentOffersCount = sentOffers.length;
        _sentAcceptedCount = sentAccepted.length;

        _receivedOffersCount = receivedOffers.length;
        _receivedAcceptedCount =
            receivedAccepted.length;

        _completedDealsCount = completedDeals.length;
        _acceptedDealsCount = acceptedDeals.length;

        _totalCancelledCount =
            cancelledDeals.length;

        _cancelledByUserCount = userCancelled;
        _cancelledByPartnerCount =
            partnerCancelled;

        _myCancelReasons = myReasons;
        _partnerCancelReasons = partnerReasons;
      });
    } catch (e) {
      debugPrint(
        'Error loading stats: $e',
      );
    }
  }

  int _calculateRating() {
    if (_acceptedDealsCount == 0) {
      return 0;
    }

    return ((_completedDealsCount /
        _acceptedDealsCount) *
        100)
        .round()
        .clamp(0, 100);
  }

  int _sentSuccessRate() {
    if (_sentOffersCount == 0) {
      return 0;
    }

    return ((_sentAcceptedCount /
        _sentOffersCount) *
        100)
        .round()
        .clamp(0, 100);
  }

  int _receivedSuccessRate() {
    if (_receivedOffersCount == 0) {
      return 0;
    }

    return ((_receivedAcceptedCount /
        _receivedOffersCount) *
        100)
        .round()
        .clamp(0, 100);
  }

  Future<void> _sendFriendRequest() async {
    if (_currentUserId == null ||
        _isLoadingActions) {
      return;
    }

    setState(() {
      _isLoadingActions = true;
    });

    try {
      final response = await http
          .post(
        Uri.parse(usersApiUrl),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'send-friend-request',
          'user_id': _currentUserId,
          'friend_id': widget.userId,
        }),
      )
          .timeout(
        const Duration(seconds: 5),
      );

      final responseData = jsonDecode(response.body);

      if (responseData is Map &&
          responseData['ok'] == false) {
        throw Exception(
          responseData['error'] ??
              'Friend request failed',
        );
      }

      final prefs =
      await SharedPreferences.getInstance();

      final userName =
          prefs.getString('user_name') ??
              'Пользователь';

      NotificationService.sendNotification(
        targetUserId: widget.userId,
        type: 'friend_request',
        data: {
          'user_id': _currentUserId,
          'user_name': userName,
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isPending = true;
        _isLoadingActions = false;
        _actionCompleted = true;
      });

      _showSnackBar(
        'Заявка в друзья отправлена',
        _green,
      );
    } catch (e) {
      debugPrint(
        'Error sending friend request: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingActions = false;
      });

      _showSnackBar(
        'Не удалось отправить заявку',
        _red,
      );
    }
  }

  Future<void> _removeFriend() async {
    final confirm = await _showConfirmDialog(
      title: 'Удалить из друзей?',
      message:
      'Пользователь исчезнет из твоего списка друзей.',
      accent: _red,
      confirmText: 'Удалить',
    );

    if (confirm != true) {
      return;
    }

    if (_isLoadingActions) {
      return;
    }

    setState(() {
      _isLoadingActions = true;
    });

    try {
      final response = await http
          .post(
        Uri.parse(usersApiUrl),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'remove-friend',
          'user_id': _currentUserId,
          'friend_id': widget.userId,
        }),
      )
          .timeout(
        const Duration(seconds: 5),
      );

      final responseData = jsonDecode(response.body);

      if (responseData is Map &&
          responseData['ok'] == false) {
        throw Exception(
          responseData['error'] ??
              'Remove friend failed',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isFriend = false;
        _isPending = false;
        _isLoadingActions = false;
        _actionCompleted = true;
      });

      _showSnackBar(
        'Пользователь удалён из друзей',
        _accent,
      );
    } catch (e) {
      debugPrint(
        'Error removing friend: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingActions = false;
      });

      _showSnackBar(
        'Не удалось удалить пользователя',
        _red,
      );
    }
  }

  Future<void> _openChat() async {
    if (_currentUserId == null ||
        _isLoadingActions) {
      return;
    }

    setState(() {
      _isLoadingActions = true;
    });

    try {
      final response = await http
          .post(
        Uri.parse(chatApiUrl),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'get-or-create-chat',
          'user1_id': _currentUserId,
          'user2_id': widget.userId,
        }),
      )
          .timeout(
        const Duration(seconds: 8),
      );

      final data = jsonDecode(response.body);

      if (data is Map &&
          data['ok'] == true &&
          data['chat_id'] != null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoadingActions = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: data['chat_id'].toString(),
              otherUserId: widget.userId,
              otherName:
              _profile?['name']?.toString() ??
                  'Пользователь',
              otherAvatar:
              _profile?['avatar_url']?.toString() ??
                  '',
            ),
          ),
        );
      } else {
        throw Exception(
          'Unable to create chat',
        );
      }
    } catch (e) {
      debugPrint(
        'Error opening chat: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingActions = false;
      });

      _showSnackBar(
        'Не удалось открыть чат',
        _red,
      );
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required Color accent,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: _borderColor,
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            24,
            23,
            24,
            8,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            24,
            8,
            24,
            8,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            18,
            0,
            18,
            18,
          ),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: _subTextColor,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'Отмена',
                style: TextStyle(
                  color: _subTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent,
                    accent.withOpacity(0.82),
                  ],
                ),
                borderRadius:
                BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                style: TextButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 11,
                  ),
                ),
                child: Text(
                  confirmText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(
      String message,
      Color accent,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _surfaceColor2,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildLoading();
    }

    if (_profile == null) {
      return _buildNotFound();
    }

    final name =
    _profile!['name']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? _profile!['name'].toString()
        : 'Пользователь';

    final city =
        _profile!['city']?.toString() ?? '';

    final bio =
        _profile!['bio']?.toString() ?? '';

    final telegram =
        _profile!['telegram']?.toString() ?? '';

    final age = _profile!['age'] is num
        ? (_profile!['age'] as num).round()
        : int.tryParse(
      _profile!['age']?.toString() ?? '',
    ) ??
        0;

    final avatarUrl =
        _profile!['avatar_url']?.toString() ?? '';

    final isSelf =
        _currentUserId == widget.userId;

    final rating = _calculateRating();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(
        name: name,
        isSelf: isSelf,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _accent,
          backgroundColor: _surfaceColor,
          onRefresh: _loadAll,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent:
              AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              38,
            ),
            child: Column(
              children: [
                _buildHero(
                  name: name,
                  city: city,
                  avatarUrl: avatarUrl,
                  isSelf: isSelf,
                ),
                const SizedBox(height: 14),
                _buildRatingCard(
                  rating: rating,
                ),
                const SizedBox(height: 26),
                _buildSectionTitle(
                  icon: Icons.insights_rounded,
                  title: 'Статистика',
                  subtitle:
                  'Активность пользователя',
                  accent: _cyan,
                ),
                const SizedBox(height: 12),
                _buildStatsGrid(),
                const SizedBox(height: 26),
                _buildSectionTitle(
                  icon:
                  Icons.swap_horizontal_circle_rounded,
                  title: 'Обмены',
                  subtitle:
                  'История активности',
                  accent: _accent,
                ),
                const SizedBox(height: 12),
                _buildTradeStatCard(
                  title: 'Предложил обменов',
                  total: _sentOffersCount,
                  success: _sentAcceptedCount,
                  rate: _sentSuccessRate(),
                  icon: Icons.send_rounded,
                  color: _accent,
                  successLabel: 'принято',
                ),
                const SizedBox(height: 10),
                _buildTradeStatCard(
                  title: 'Предложили обменов',
                  total: _receivedOffersCount,
                  success: _receivedAcceptedCount,
                  rate: _receivedSuccessRate(),
                  icon: Icons.inbox_rounded,
                  color: _violet,
                  successLabel: 'принято',
                ),
                const SizedBox(height: 10),
                _buildTradeStatCard(
                  title: 'Успешных сделок',
                  total: _completedDealsCount,
                  success: _acceptedDealsCount,
                  rate: _acceptedDealsCount == 0
                      ? 0
                      : ((_completedDealsCount /
                      _acceptedDealsCount) *
                      100)
                      .round(),
                  icon: Icons.verified_rounded,
                  color: _green,
                  successLabel:
                  'из $_acceptedDealsCount принятых',
                ),
                if (_totalCancelledCount > 0) ...[
                  const SizedBox(height: 26),
                  _buildSectionTitle(
                    icon: Icons.block_rounded,
                    title: 'Отмены',
                    subtitle:
                    'История отменённых сделок',
                    accent: _red,
                  ),
                  const SizedBox(height: 12),
                  _buildCancellationsCard(),
                ],
                const SizedBox(height: 26),
                _buildSectionTitle(
                  icon:
                  Icons.person_outline_rounded,
                  title: 'О пользователе',
                  subtitle:
                  'Основная информация',
                  accent: _violet,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  age: age,
                  telegram: telegram,
                  bio: bio,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _buildBackButton(),
      ),
      body: Center(
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(
            color: _accent,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _buildBackButton(),
        title: Text(
          'Профиль',
          style: TextStyle(
            color: _textColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: _surfaceColor2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_off_rounded,
                  color: _subTextColor,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Профиль не найден',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Пользователь мог удалить аккаунт или стать недоступным.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required String name,
    required bool isSelf,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: _buildBackButton(),
      title: Text(
        isSelf ? 'Мой профиль' : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _textColor,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      actions: [
        if (_actionCompleted)
          Padding(
            padding: const EdgeInsets.only(
              right: 14,
            ),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: _green,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.045)
              : Colors.black.withOpacity(0.035),
          borderRadius:
          BorderRadius.circular(14),
          border: Border.all(
            color: _borderColor,
          ),
        ),
        child: IconButton(
          onPressed: () =>
              Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: _textColor,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildHero({
    required String name,
    required String city,
    required String avatarUrl,
    required bool isSelf,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF7A18),
            Color(0xFFFF5B00),
            Color(0xFFE94700),
          ],
        ),
        borderRadius:
        BorderRadius.all(
          Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -55,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color:
                Colors.white.withOpacity(
                  0.055,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color:
                Colors.black.withOpacity(
                  0.055,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              Hero(
                tag:
                'public_profile_${widget.userId}',
                child: _buildAvatar(
                  name: name,
                  avatarUrl: avatarUrl,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (city.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color:
                      Colors.white.withOpacity(
                        0.74,
                      ),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: TextStyle(
                        color:
                        Colors.white.withOpacity(
                          0.74,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              if (_isFriend && !isSelf) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                    Colors.white.withOpacity(
                      0.10,
                    ),
                    borderRadius:
                    BorderRadius.circular(20),
                    border: Border.all(
                      color:
                      Colors.white.withOpacity(
                        0.16,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'У вас в друзьях',
                        style: TextStyle(
                          color:
                          Colors.white.withOpacity(
                            0.88,
                          ),
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!isSelf) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeroButton(
                        icon: Icons.chat_rounded,
                        label: 'Написать',
                        filled: true,
                        onPressed: _openChat,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _buildFriendButton(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String name,
    required String avatarUrl,
  }) {
    final firstLetter = name.trim().isEmpty
        ? '?'
        : name.trim()[0].toUpperCase();

    return Container(
      width: 126,
      height: 126,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.18),
            blurRadius: 26,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor:
        const Color(0xFFFFF2E9),
        backgroundImage: avatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(
          avatarUrl,
        )
            : null,
        child: avatarUrl.isEmpty
            ? Text(
          firstLetter,
          style: const TextStyle(
            color: _accent,
            fontSize: 44,
            fontWeight: FontWeight.w900,
          ),
        )
            : null,
      ),
    );
  }

  Widget _buildHeroButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 18,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled
              ? Colors.white
              : Colors.white.withOpacity(0.12),
          foregroundColor:
          filled ? _accent : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
            side: filled
                ? BorderSide.none
                : BorderSide(
              color:
              Colors.white.withOpacity(
                0.16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendButton() {
    if (_isLoadingActions) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color:
          Colors.white.withOpacity(0.10),
          borderRadius:
          BorderRadius.circular(16),
          border: Border.all(
            color:
            Colors.white.withOpacity(0.15),
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child:
            CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    final isFriend = _isFriend;
    final isPending = _isPending;

    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: isFriend
            ? _removeFriend
            : (isPending
            ? null
            : _sendFriendRequest),
        icon: Icon(
          isFriend
              ? Icons.person_remove_rounded
              : isPending
              ? Icons.schedule_rounded
              : Icons.person_add_alt_1_rounded,
          size: 18,
        ),
        label: Text(
          isFriend
              ? 'Удалить'
              : isPending
              ? 'Отправлено'
              : 'В друзья',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFriend
              ? Colors.white.withOpacity(0.13)
              : isPending
              ? Colors.white.withOpacity(0.09)
              : _gold,
          foregroundColor:
          isFriend || isPending
              ? Colors.white
              : const Color(0xFF332200),
          disabledForegroundColor:
          Colors.white.withOpacity(0.62),
          disabledBackgroundColor:
          Colors.white.withOpacity(0.09),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
            side: BorderSide(
              color: isFriend || isPending
                  ? Colors.white.withOpacity(0.14)
                  : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard({
    required int rating,
  }) {
    final ratingColor = rating >= 80
        ? _green
        : rating >= 50
        ? _gold
        : _red;

    final ratingText = rating >= 80
        ? 'Отличный'
        : rating >= 50
        ? 'Нормальный'
        : 'Низкий';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius:
        BorderRadius.circular(23),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              _isDarkMode ? 0.11 : 0.035,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 57,
            height: 57,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ratingColor,
                  ratingColor.withOpacity(0.72),
                ],
              ),
              borderRadius:
              BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color:
                  ratingColor.withOpacity(0.18),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Рейтинг надёжности',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 10.5,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$rating%',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 25,
                        fontWeight:
                        FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 3,
                      ),
                      child: Text(
                        ratingText,
                        style: TextStyle(
                          color: ratingColor,
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Text(
                  'Надёжность',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 9.5,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(20),
                  child:
                  LinearProgressIndicator(
                    value: rating / 100,
                    minHeight: 8,
                    backgroundColor:
                    _isDarkMode
                        ? Colors.white
                        .withOpacity(0.07)
                        : const Color(
                      0xFFE7EDF0,
                    ),
                    valueColor:
                    AlwaysStoppedAnimation<
                        Color>(
                      ratingColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          width: 41,
          height: 41,
          decoration: BoxDecoration(
            color: accent.withOpacity(
              _isDarkMode ? 0.09 : 0.07,
            ),
            borderRadius:
            BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: accent,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 10.5,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Вещей',
                value: '$_itemsCount',
                icon:
                Icons.inventory_2_rounded,
                accent: _cyan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Друзей',
                value: '$_friendsCount',
                icon:
                Icons.people_alt_rounded,
                accent: _violet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Завершено',
                value:
                '$_completedDealsCount',
                icon:
                Icons.check_circle_rounded,
                accent: _green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Всего отмен',
                value:
                '$_totalCancelledCount',
                icon:
                Icons.cancel_rounded,
                accent: _red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: accent.withOpacity(0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(
              _isDarkMode ? 0.055 : 0.035,
            ),
            blurRadius: 19,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color:
              accent.withOpacity(0.10),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 22,
                    fontWeight:
                    FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 10.5,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: color.withOpacity(0.13),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(
              _isDarkMode ? 0.045 : 0.025,
            ),
            blurRadius: 19,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color:
              color.withOpacity(0.10),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 10.5,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$total',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 22,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                    if (success > 0) ...[
                      const SizedBox(width: 7),
                      Padding(
                        padding:
                        const EdgeInsets.only(
                          bottom: 2,
                        ),
                        child: Text(
                          successLabel,
                          style: TextStyle(
                            color:
                            _subTextColor,
                            fontSize: 10,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 57,
            height: 57,
            decoration: BoxDecoration(
              color:
              color.withOpacity(0.07),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                color.withOpacity(0.12),
              ),
            ),
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text(
                  total > 0
                      ? '$rate%'
                      : '—',
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                Text(
                  'rate',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 7.5,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius:
        BorderRadius.circular(24),
        border: Border.all(
          color: _red.withOpacity(0.13),
        ),
        boxShadow: [
          BoxShadow(
            color: _red.withOpacity(
              _isDarkMode ? 0.045 : 0.025,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color:
                  _red.withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: _red,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Всего отмен',
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 10.5,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_totalCancelledCount',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 22,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          _buildGlowRay(
            color: _red,
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child:
                _buildCancellationMiniCard(
                  title: 'Сам',
                  value:
                  '$_cancelledByUserCount',
                  subtitle: 'отменил',
                  icon:
                  Icons.person_rounded,
                  accent: _accent,
                  reasons:
                  _myCancelReasons,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child:
                _buildCancellationMiniCard(
                  title: 'Партнёр',
                  value:
                  '$_cancelledByPartnerCount',
                  subtitle: 'отменил',
                  icon:
                  Icons.people_alt_rounded,
                  accent: _violet,
                  reasons:
                  _partnerCancelReasons,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationMiniCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Map<String, int> reasons,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(19),
        onTap: reasons.isEmpty
            ? null
            : () => _showReasonsDialog(
          title: '$title • причины',
          reasons: reasons,
          accentColor: accent,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceColor2,
            borderRadius:
            BorderRadius.circular(19),
            border: Border.all(
              color:
              accent.withOpacity(0.12),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color:
                  accent.withOpacity(0.09),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 17,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                value,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 21,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$title • $subtitle',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 9.5,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                    accent.withOpacity(0.08),
                    borderRadius:
                    BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Icon(
                        Icons
                            .visibility_rounded,
                        color: accent,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Причины',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showReasonsDialog({
    required String title,
    required Map<String, int> reasons,
    required Color accentColor,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius:
            const BorderRadius.vertical(
              top: Radius.circular(30),
            ),
            border: Border.all(
              color: _borderColor,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _borderColor,
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: accentColor
                            .withOpacity(0.10),
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Icon(
                        Icons
                            .warning_amber_rounded,
                        color: accentColor,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 18,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildGlowRay(
                  color: accentColor,
                ),
                const SizedBox(height: 17),
                if (reasons.isEmpty)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 20,
                    ),
                    child: Center(
                      child: Text(
                        'Нет данных о причинах отмен',
                        style: TextStyle(
                          color: _subTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ...reasons.entries.map(
                        (entry) => _buildReasonRow(
                      entry.key,
                      entry.value,
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(
                          sheetContext,
                        ),
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      _surfaceColor2,
                      foregroundColor:
                      _textColor,
                      elevation: 0,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Закрыть',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w800,
                      ),
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

  Widget _buildReasonRow(
      String reason,
      int count,
      ) {
    final icon =
    _getCancelReasonIcon(reason);

    final color =
    _getCancelReasonColor(reason);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceColor2,
          borderRadius:
          BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                color.withOpacity(0.10),
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                reason,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 12.5,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color:
                color.withOpacity(0.09),
                borderRadius:
                BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCancelReasonIcon(
      String reason,
      ) {
    switch (reason) {
      case 'Подозрение на мошенника':
        return Icons.security_rounded;
      case 'Скандальный пользователь':
        return Icons.report_rounded;
      case 'Товар не соответствует':
        return Icons.broken_image_rounded;
      case 'Передумал':
        return Icons.psychology_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getCancelReasonColor(
      String reason,
      ) {
    switch (reason) {
      case 'Подозрение на мошенника':
        return _red;
      case 'Скандальный пользователь':
        return _accent;
      case 'Товар не соответствует':
        return _gold;
      case 'Передумал':
        return _subTextColor;
      default:
        return _subTextColor;
    }
  }

  Widget _buildInfoCard({
    required int age,
    required String telegram,
    required String bio,
  }) {
    final isEmpty =
        age <= 0 &&
            telegram.isEmpty &&
            bio.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius:
        BorderRadius.circular(23),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              _isDarkMode ? 0.10 : 0.03,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isEmpty
          ? Padding(
        padding:
        const EdgeInsets.symmetric(
          vertical: 13,
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _surfaceColor2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons
                    .person_outline_rounded,
                color: _subTextColor,
                size: 23,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Информация не заполнена',
              style: TextStyle(
                color: _textColor,
                fontSize: 13,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          if (age > 0)
            _buildInfoRow(
              icon: Icons.cake_rounded,
              label: 'Возраст',
              value: '$age лет',
              accent: _cyan,
            ),
          if (telegram.isNotEmpty)
            _buildInfoRow(
              icon: Icons.telegram,
              label: 'Telegram',
              value: telegram,
              accent: _cyan,
            ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 7),
            _buildBio(bio),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 11,
      ),
      child: Row(
        children: [
          Container(
            width: 41,
            height: 41,
            decoration: BoxDecoration(
              color:
              accent.withOpacity(0.09),
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 9.5,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBio(
      String bio,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor2,
        borderRadius:
        BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color:
                  _violet.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.format_quote_rounded,
                  color: _violet,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'О себе',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 12.5,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            bio,
            style: TextStyle(
              color: _subTextColor,
              fontSize: 12.5,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowRay({
    required Color color,
    double widthFactor = 0.85,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 12,
      child: CustomPaint(
        painter: _GlowRayPainter(
          color: color,
          widthFactor: widthFactor,
          backgroundColor: _borderColor,
        ),
      ),
    );
  }
}

class _GlowRayPainter extends CustomPainter {
  final Color color;
  final double widthFactor;
  final Color backgroundColor;

  _GlowRayPainter({
    required this.color,
    required this.widthFactor,
    required this.backgroundColor,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final centerY = size.height / 2;

    final basePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      basePaint,
    );

    final totalWidth =
        size.width * widthFactor;

    final left =
        (size.width - totalWidth) / 2;

    final right =
        left + totalWidth;

    final rect = Rect.fromLTRB(
      left,
      0,
      right,
      size.height,
    );

    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        color.withOpacity(0),
        color.withOpacity(0.025),
        color.withOpacity(0.08),
        color.withOpacity(0.22),
        color.withOpacity(0.55),
        color,
        color.withOpacity(0.55),
        color.withOpacity(0.22),
        color.withOpacity(0.08),
        color.withOpacity(0.025),
        color.withOpacity(0),
      ],
      stops: const [
        0.0,
        0.10,
        0.20,
        0.34,
        0.45,
        0.50,
        0.55,
        0.66,
        0.80,
        0.90,
        1.0,
      ],
    );

    final glowPaint = Paint()
      ..shader =
      gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        6,
      );

    canvas.drawLine(
      Offset(left, centerY),
      Offset(right, centerY),
      glowPaint,
    );

    final corePaint = Paint()
      ..shader =
      gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(left, centerY),
      Offset(right, centerY),
      corePaint,
    );
  }

  @override
  bool shouldRepaint(
      covariant _GlowRayPainter oldDelegate,
      ) {
    return oldDelegate.color != color ||
        oldDelegate.widthFactor != widthFactor ||
        oldDelegate.backgroundColor !=
            backgroundColor;
  }
}