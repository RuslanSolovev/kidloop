// users_tab.dart - ПОИСК + ПАГИНАЦИЯ
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../profile/public_profile_screen.dart';
import 'chat_screen.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _searchQuery = '';
  String? _currentUserId;
  String? _loadError;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  // 🔥 Анимация прогресс-бара
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rotationController;
  final List<_Particle> _particles = [];
  Timer? _particleTimer;

  static const String userApiUrl = 'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';
  static const String chatApiUrl = 'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';
  static const int _pageSize = 15;

  // 🔥 Поддержка тёмной/светлой темы
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Инициализация анимаций прогресс-бара
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Создаем частицы для анимации
    _generateParticles();
    _particleTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateParticles();
    });

    _init();
    _scrollController.addListener(_onScroll);
  }

  void _generateParticles() {
    final random = Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 4 + 2,
        speed: random.nextDouble() * 0.02 + 0.01,
        angle: random.nextDouble() * 2 * pi,
        color: [
          Colors.orange,
          Colors.deepOrange,
          Colors.amber,
          Colors.red.shade300,
        ][random.nextInt(4)],
        opacity: random.nextDouble() * 0.6 + 0.2,
      ));
    }
  }

  void _updateParticles() {
    for (var particle in _particles) {
      particle.x += cos(particle.angle) * particle.speed;
      particle.y += sin(particle.angle) * particle.speed;

      if (particle.x < -0.1 || particle.x > 1.1 || particle.y < -0.1 || particle.y > 1.1) {
        particle.x = 0.5;
        particle.y = 0.5;
        particle.angle = Random().nextDouble() * 2 * pi;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _particleTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');

    await Future.wait([
      _loadFriends(),
      _loadPendingRequests(),
      _loadUsers(),
    ]);

    if (mounted) {
      setState(() => _loading = false);
      // Останавливаем анимации после загрузки
      _progressController.stop();
      _pulseController.stop();
      _rotationController.stop();
      _particleTimer?.cancel();
    }
  }

  Future<void> _loadUsers({bool reset = true}) async {
    if (reset) {
      _offset = 0;
      _hasMore = true;
      if (mounted) setState(() { _users = []; _loading = true; });
    }

    try {
      final response = await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "list",
          "query": _searchQuery,
          "user_id": _currentUserId,
          "offset": _offset,
          "limit": _pageSize,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        final newUsers = (data['users'] as List).cast<Map<String, dynamic>>();
        setState(() {
          if (reset) {
            _users = newUsers;
          } else {
            _users.addAll(newUsers);
          }
          _hasMore = newUsers.length >= _pageSize;
          _offset += newUsers.length;
          _loadError = null;
          _loading = false;
        });
      } else if (mounted) {
        setState(() { _loading = false; _hasMore = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_loadingMore || !_hasMore || _searchQuery.isNotEmpty) return;
    _loadingMore = true;
    await _loadUsers(reset: false);
    _loadingMore = false;
  }

  Future<void> _loadFriends() async {
    try {
      final response = await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "friends", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() => _friends = (data['friends'] as List).cast<Map<String, dynamic>>());
      }
    } catch (e) {}
  }

  Future<void> _loadPendingRequests() async {
    try {
      final response = await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "pending-requests", "user_id": _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && mounted) {
        setState(() => _pendingRequests = (data['requests'] as List).cast<Map<String, dynamic>>());
      }
    } catch (e) {}
  }

  bool _isFriend(String userId) => _friends.any((f) => f['user_id'] == userId);

  Future<void> _sendFriendRequest(String friendId) async {
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "send-friend-request", "user_id": _currentUserId, "friend_id": friendId}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Заявка отправлена! 🎉'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить заявку'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final isDark = _isDarkMode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить из друзей?', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('Вы уверены, что хотите удалить этого пользователя из друзей?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "remove-friend", "user_id": _currentUserId, "friend_id": friendId}),
      );
      await _loadFriends();
    } catch (e) {}
  }

  Future<void> _acceptRequest(String friendId) async {
    try {
      await http.post(
        Uri.parse(userApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "accept-friend", "user_id": _currentUserId, "friend_id": friendId}),
      );
      await Future.wait([_loadFriends(), _loadPendingRequests()]);
    } catch (e) {}
  }

  Future<void> _openChat(String otherUserId, String otherName, String otherAvatar) async {
    try {
      final response = await http.post(
        Uri.parse(chatApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "get-or-create-chat",
          "user1_id": _currentUserId,
          "user2_id": otherUserId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (data['ok'] == true && data['chat_id'] != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: data['chat_id'],
              otherUserId: otherUserId,
              otherName: otherName,
              otherAvatar: otherAvatar,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['errorMessage'] ?? 'Не удалось создать чат'),
            backgroundColor: Colors.red,
          ),
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

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)),
    );
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = query.trim());
      _loadUsers(reset: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _users = [];
    });
    _loadUsers(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 🔥 Адаптивные цвета
    final backgroundColor = _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);
    final surfaceColor = _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final fillColor = _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100;
    final borderColor = _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;

    return Container(
      color: backgroundColor,
      child: _loading
          ? _buildCustomProgressBar(textColor, surfaceColor)
          : RefreshIndicator(
        color: Colors.orange,
        backgroundColor: surfaceColor,
        onRefresh: () async {
          setState(() { _loading = true; _users = []; });
          await Future.wait([_loadFriends(), _loadPendingRequests(), _loadUsers()]);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 🔥 ПОИСК
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(_isDarkMode ? 0.15 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Поиск пользователей...',
                      hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.orange),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: subTextColor),
                        onPressed: _clearSearch,
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.orange, width: 2),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
            ),

            // 🔥 ЗАЯВКИ (только когда нет поиска)
            if (_searchQuery.isEmpty && _pendingRequests.isNotEmpty) ...[
              _sectionHeader('Заявки в друзья', Icons.person_add_rounded, Colors.orange, _pendingRequests.length, textColor),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _userTile(_pendingRequests[i], isPending: true, textColor: textColor, subTextColor: subTextColor, surfaceColor: surfaceColor),
                  childCount: _pendingRequests.length,
                ),
              ),
            ],

            // 🔥 ДРУЗЬЯ (только когда нет поиска)
            if (_searchQuery.isEmpty && _friends.isNotEmpty) ...[
              _sectionHeader('Друзья', Icons.people_rounded, Colors.green, _friends.length, textColor),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _userTile(_friends[i], isFriend: true, textColor: textColor, subTextColor: subTextColor, surfaceColor: surfaceColor),
                  childCount: _friends.length,
                ),
              ),
            ],

            // 🔥 ВСЕ ПОЛЬЗОВАТЕЛИ / РЕЗУЛЬТАТЫ ПОИСКА
            if (_searchQuery.isNotEmpty || _searchQuery.isEmpty) ...[
              _sectionHeader(
                _searchQuery.isNotEmpty ? 'Результаты поиска' : 'Все пользователи',
                Icons.person_rounded,
                _searchQuery.isNotEmpty ? Colors.blue : Colors.grey,
                _users.length,
                textColor,
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                    // Кнопка "Загрузить ещё"
                    if (i == _users.length && _hasMore && _searchQuery.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator(color: Colors.orange)
                              : OutlinedButton(
                            onPressed: _loadMoreUsers,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Загрузить ещё', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      );
                    }
                    if (i >= _users.length) return null;
                    return _userTile(_users[i], textColor: textColor, subTextColor: subTextColor, surfaceColor: surfaceColor);
                  },
                  childCount: _users.length + (_hasMore && _searchQuery.isEmpty ? 1 : 0),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 🔥 НЕОБЫЧНЫЙ ПРОГРЕСС-БАР
  Widget _buildCustomProgressBar(Color textColor, Color surfaceColor) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_progressAnimation, _pulseAnimation, _rotationController]),
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticleProgressPainter(
              progress: _progressAnimation.value,
              pulse: _pulseAnimation.value,
              rotation: _rotationController.value * 2 * pi,
              particles: _particles,
              isDark: _isDarkMode,
            ),
            child: Container(
              width: 200,
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Анимированный текст загрузки
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: [
                                Colors.orange,
                                Colors.amber,
                                Colors.orange,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'ЗАГРУЗКА',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Процент загрузки
                  Text(
                    '${(_progressAnimation.value * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.orange.shade300,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color, int count, Color textColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.08)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user, {
    bool isFriend = false,
    bool isPending = false,
    required Color textColor,
    required Color subTextColor,
    required Color surfaceColor,
  }) {
    final userId = user['user_id'] ?? '';
    final name = user['name'] ?? '';
    final avatarUrl = user['avatar_url'] ?? '';
    final city = user['city'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.1 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(),
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 20))
                : null,
          ),
        ),
        title: Text(
          name.isNotEmpty ? name : 'Пользователь',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
        ),
        subtitle: city.isNotEmpty
            ? Row(
          children: [
            Icon(Icons.location_on, size: 14, color: subTextColor),
            const SizedBox(width: 4),
            Text(city, style: TextStyle(color: subTextColor, fontSize: 12)),
          ],
        )
            : null,
        onTap: () => _openProfile(userId),
        trailing: isPending
            ? Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: TextButton(
            onPressed: () => _acceptRequest(userId),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              foregroundColor: Colors.white,
            ),
            child: const Text('Принять', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        )
            : isFriend
            ? PopupMenuButton(
          color: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              child: Row(children: [
                Icon(Icons.chat_rounded, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Написать', style: TextStyle(color: textColor)),
              ]),
              onTap: () => _openChat(userId, name, avatarUrl),
            ),
            PopupMenuItem(
              child: Row(children: [
                Icon(Icons.person_rounded, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Профиль', style: TextStyle(color: textColor)),
              ]),
              onTap: () => _openProfile(userId),
            ),
            PopupMenuItem(
              child: Row(children: [
                const Icon(Icons.person_remove_rounded, size: 20, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Удалить', style: TextStyle(color: Colors.red)),
              ]),
              onTap: () => _removeFriend(userId),
            ),
          ],
        )
            : Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextButton(
            onPressed: () => _sendFriendRequest(userId),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              foregroundColor: Colors.orange,
            ),
            child: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

// 🔥 Класс частицы для анимации
class _Particle {
  double x, y, size, speed, angle, opacity;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.angle,
    required this.color,
    required this.opacity,
  });
}

// 🔥 Продвинутый рисовальщик прогресс-бара с частицами
class _ParticleProgressPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final double rotation;
  final List<_Particle> particles;
  final bool isDark;

  _ParticleProgressPainter({
    required this.progress,
    required this.pulse,
    required this.rotation,
    required this.particles,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    // Рисуем фон
    final bgPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, bgPaint);

    // Рисуем прогресс с градиентом
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.orange.withOpacity(0.8),
          Colors.deepOrange,
          Colors.amber,
          Colors.orange.withOpacity(0.8),
        ],
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final progressAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      progressAngle,
      false,
      progressPaint,
    );

    // Рисуем светящийся ореол
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.orange.withOpacity(0.3 * pulse),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 1.5, glowPaint);

    // Рисуем частицы
    for (var particle in particles) {
      final particlePaint = Paint()
        ..color = particle.color.withOpacity(particle.opacity * pulse)
        ..style = PaintingStyle.fill;

      final particleOffset = Offset(
        center.dx + (particle.x - 0.5) * size.width * 1.2,
        center.dy + (particle.y - 0.5) * size.height * 1.2,
      );

      // Проверяем, находится ли частица в пределах прогресса
      final particleAngle = atan2(
        particleOffset.dy - center.dy,
        particleOffset.dx - center.dx,
      );

      final normalizedAngle = (particleAngle + pi / 2 + 2 * pi) % (2 * pi);

      if (normalizedAngle <= progressAngle &&
          (particleOffset - center).distance <= radius * 1.2) {
        canvas.drawCircle(particleOffset, particle.size * pulse, particlePaint);
      }
    }

    // Рисуем точки на окружности
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi + rotation;
      final dotProgress = (i / 12);

      if (dotProgress <= progress) {
        final dotCenter = Offset(
          center.dx + radius * cos(angle - pi / 2),
          center.dy + radius * sin(angle - pi / 2),
        );

        final dotPaint = Paint()
          ..color = Colors.orange.withOpacity(0.8 * pulse)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(dotCenter, 3 * pulse, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.rotation != rotation;
  }
}