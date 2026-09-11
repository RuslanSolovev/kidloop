import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/items_provider.dart';
import '../../core/level_calculator.dart';
import '../../core/profile_provider.dart';
import '../../core/trades_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../profile/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _accent = Color(0xFFFF6B00);
  static const Color _accent2 = Color(0xFFFF8A3D);
  static const Color _cyan = Color(0xFF42DFFF);
  static const Color _green = Color(0xFF40E0A0);
  static const Color _violet = Color(0xFF9A7CFF);
  static const Color _red = Color(0xFFFF5D73);
  static const Color _gold = Color(0xFFFFC857);

  int _svBalance = 0;
  bool _loadingBalance = true;
  String? _currentUserId;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();

    _loadThemeMode();
    _loadBalance();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfile();
    });
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('user_id');
    final darkMode = prefs.getBool('is_dark_mode') ?? false;

    if (!mounted) {
      return;
    }

    setState(() {
      _currentUserId = userId;
      _isDarkMode = darkMode;
    });
  }

  Future<void> _refreshProfile() async {
    try {
      final profileProvider = context.read<ProfileProvider>();

      await profileProvider.loadProfile();
      await _loadBalance();
    } catch (e) {
      debugPrint('Error refreshing profile: $e');
    }
  }

  Future<void> _loadBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      if (userId.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingBalance = false;
          });
        }
        return;
      }

      final response = await http
          .post(
        Uri.parse(
          'https://functions.yandexcloud.net/d4e4du0dtej5k7md0cc5',
        ),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'get-balance',
          'user_id': userId,
        }),
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        if (mounted) {
          setState(() {
            _loadingBalance = false;
          });
        }
        return;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map &&
          decoded['ok'] == true) {
        final balance = decoded['balance'];

        if (mounted) {
          setState(() {
            _svBalance = balance is num
                ? balance.round()
                : 100;
            _loadingBalance = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingBalance = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBalance = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogBackground = _isDarkMode
            ? const Color(0xFF111A21)
            : Colors.white;

        final dialogText = _isDarkMode
            ? Colors.white
            : const Color(0xFF17232B);

        final dialogMuted = _isDarkMode
            ? const Color(0xFF94A4AE)
            : const Color(0xFF6E7C84);

        return AlertDialog(
          backgroundColor: dialogBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            24,
            24,
            24,
            8,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            24,
            8,
            24,
            10,
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
                  color: _red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Выйти из аккаунта',
                  style: TextStyle(
                    color: dialogText,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Ты уверен, что хочешь выйти?',
            style: TextStyle(
              color: dialogMuted,
              fontSize: 14,
              height: 1.45,
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
                  color: dialogMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    _red,
                    Color(0xFFE83F5B),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                ),
                child: const Text(
                  'Выйти',
                  style: TextStyle(
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

    if (confirm != true) {
      return;
    }

    if (mounted) {
      context.read<ProfileProvider>().clearProfile();
      context.read<ItemsProvider>().clearItems();
      context.read<TradesProvider>().clearOffers();
    }

    final prefs = await SharedPreferences.getInstance();
    final savedDarkMode =
        prefs.getBool('is_dark_mode') ?? false;

    await prefs.clear();
    await prefs.setBool(
      'is_dark_mode',
      savedDarkMode,
    );

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  double _profileCompletion({
    required String name,
    required String city,
    required String bio,
    required String telegram,
    required int age,
    required int items,
    required int trades,
    required String avatarUrl,
  }) {
    double progress = 0;

    if (name.isNotEmpty) {
      progress += 0.12;
    }

    if (city.isNotEmpty) {
      progress += 0.12;
    }

    if (bio.isNotEmpty) {
      progress += 0.12;
    }

    if (telegram.isNotEmpty) {
      progress += 0.12;
    }

    if (age > 0) {
      progress += 0.10;
    }

    if (items > 0) {
      progress += 0.12;
    }

    if (trades > 0) {
      progress += 0.12;
    }

    if (avatarUrl.isNotEmpty) {
      progress += 0.18;
    }

    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider =
    context.watch<ProfileProvider>();
    final itemsProvider =
    context.watch<ItemsProvider>();
    final tradesProvider =
    context.watch<TradesProvider>();

    final profile = profileProvider.profile;
    final items = itemsProvider.items;
    final trades = tradesProvider.offers;

    final myItems =
        items.where((item) => item.isMine).length;

    final completedTrades = trades
        .where(
          (trade) => trade.status == 'completed',
    )
        .length;

    final sentOffers = trades
        .where(
          (trade) => trade.fromUserId == _currentUserId,
    )
        .length;

    final level = LevelCalculator.calculateLevel(
      totalSteps: 0,
      itemsCount: myItems,
      completedTrades: completedTrades,
      sentOffers: sentOffers,
    );

    final completion = _profileCompletion(
      name: profile.name,
      city: profile.city,
      bio: profile.bio,
      telegram: profile.telegram,
      age: profile.age,
      items: myItems,
      trades: completedTrades,
      avatarUrl: profile.avatarUrl,
    );

    final successRate = trades.isEmpty
        ? 0
        : (completedTrades /
        trades.length *
        100)
        .round();

    final backgroundColor = _isDarkMode
        ? const Color(0xFF071016)
        : const Color(0xFFF5F8FB);

    final surfaceColor = _isDarkMode
        ? const Color(0xFF0D1B22)
        : Colors.white;

    final surfaceColor2 = _isDarkMode
        ? const Color(0xFF12242C)
        : const Color(0xFFF0F4F7);

    final textColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF17242C);

    final subTextColor = _isDarkMode
        ? const Color(0xFF90A4AE)
        : const Color(0xFF6B7A83);

    final borderColor = _isDarkMode
        ? Colors.white.withOpacity(0.07)
        : const Color(0xFFDCE4E9);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(
        textColor: textColor,
        borderColor: borderColor,
      ),
      body: RefreshIndicator(
        color: _accent,
        backgroundColor: surfaceColor,
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            36,
          ),
          child: Column(
            children: [
              _buildHero(
                profile: profile,
                level: level,
                completion: completion,
                surfaceColor2: surfaceColor2,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 14),
              _buildActionButtons(),
              const SizedBox(height: 26),
              _buildSectionTitle(
                title: 'Профиль',
                subtitle: 'Твоя информация',
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                profile: profile,
                surfaceColor: surfaceColor,
                surfaceColor2: surfaceColor2,
                textColor: textColor,
                subTextColor: subTextColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 26),
              _buildSectionTitle(
                title: 'Статистика',
                subtitle: 'Твоя активность в KidLoop',
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 12),
              _buildStatisticsGrid(
                myItems: myItems,
                trades: trades.length,
                completedTrades: completedTrades,
                successRate: successRate,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 26),
              _buildLevelCard(
                level: level,
                myItems: myItems,
                completedTrades: completedTrades,
                sentOffers: sentOffers,
                surfaceColor: surfaceColor,
                surfaceColor2: surfaceColor2,
                textColor: textColor,
                subTextColor: subTextColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 20),
              _buildLogoutCard(
                borderColor: borderColor,
                textColor: textColor,
                surfaceColor: surfaceColor,
                subTextColor: subTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required Color textColor,
    required Color borderColor,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Профиль',
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          Text(
            'Твой KidLoop',
            style: TextStyle(
              color: _isDarkMode
                  ? const Color(0xFF738993)
                  : const Color(0xFF87959D),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(
            right: 14,
            top: 8,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.045)
                : Colors.black.withOpacity(0.035),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: IconButton(
            onPressed: _logout,
            tooltip: 'Выйти',
            icon: const Icon(
              Icons.logout_rounded,
              color: _red,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero({
    required dynamic profile,
    required int level,
    required double completion,
    required Color surfaceColor2,
    required Color textColor,
    required Color subTextColor,
  }) {
    final hasAvatar = profile.avatarUrl.isNotEmpty;
    final userName = profile.name.isNotEmpty
        ? profile.name
        : 'Пользователь';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        20,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF7A18),
            Color(0xFFFF5B00),
            Color(0xFFE94700),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.22),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -45,
            right: -35,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.055),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -45,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.055),
              ),
            ),
          ),
          Column(
            children: [
              Hero(
                tag: 'profile_avatar',
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.95),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: hasAvatar
                        ? NetworkImage(
                      profile.avatarUrl,
                    )
                        : null,
                    child: !hasAvatar
                        ? const Icon(
                      Icons.person_rounded,
                      color: _accent,
                      size: 58,
                    )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                userName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (profile.city.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.white.withOpacity(0.72),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile.city,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _buildSvBalance(),
              const SizedBox(height: 12),
              _buildLevelPill(level),
              const SizedBox(height: 18),
              _buildProfileProgress(
                completion: completion,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSvBalance() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
        ),
      ),
      child: _loadingBalance
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: Colors.white,
        ),
      )
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _gold,
              size: 16,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            '$_svBalance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'SV',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelPill(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.11),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.17),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: _gold,
            size: 17,
          ),
          const SizedBox(width: 7),
          Text(
            'УРОВЕНЬ $level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '• ${LevelCalculator.getLevelName(level)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileProgress({
    required double completion,
  }) {
    final percent = (completion * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Заполненность',
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                height: 9,
                width: double.infinity,
                color: Colors.white.withOpacity(0.14),
              ),
              FractionallySizedBox(
                widthFactor: completion,
                child: Container(
                  height: 9,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Color(0xFFFFE8DD),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.edit_rounded,
            label: 'Редактировать',
            gradient: const LinearGradient(
              colors: [
                _accent,
                _accent2,
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const EditProfileScreen(),
                ),
              ).then((_) {
                _refreshProfile();
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            icon: Icons.logout_rounded,
            label: 'Выйти',
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF5D73),
                Color(0xFFE9405A),
              ],
            ),
            onPressed: _logout,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: gradient is LinearGradient
                  ? gradient.colors.first.withOpacity(0.20)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _accent2,
                _accent,
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required dynamic profile,
    required Color surfaceColor,
    required Color surfaceColor2,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              _isDarkMode ? 0.12 : 0.035,
            ),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.cake_rounded,
            label: 'Возраст',
            value: profile.age > 0
                ? '${profile.age}'
                : 'Не указан',
            accent: _cyan,
            textColor: textColor,
            subTextColor: subTextColor,
            surfaceColor2: surfaceColor2,
          ),
          _buildInfoDivider(borderColor),
          _buildInfoTile(
            icon: Icons.category_rounded,
            label: 'Любимая категория',
            value: profile.favoriteCategory
                .toString()
                .isEmpty
                ? 'Не указана'
                : profile.favoriteCategory,
            accent: _violet,
            textColor: textColor,
            subTextColor: subTextColor,
            surfaceColor2: surfaceColor2,
          ),
          _buildInfoDivider(borderColor),
          _buildInfoTile(
            icon: Icons.telegram,
            label: 'Telegram',
            value: profile.telegram.isEmpty
                ? 'Не указан'
                : profile.telegram,
            accent: _cyan,
            textColor: textColor,
            subTextColor: subTextColor,
            surfaceColor2: surfaceColor2,
          ),
          const SizedBox(height: 16),
          _buildBioBlock(
            bio: profile.bio,
            textColor: textColor,
            subTextColor: subTextColor,
            surfaceColor2: surfaceColor2,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
    required Color surfaceColor2,
  }) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoDivider(Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
      ),
      child: Container(
        height: 1,
        width: double.infinity,
        color: borderColor,
      ),
    );
  }

  Widget _buildBioBlock({
    required String bio,
    required Color textColor,
    required Color subTextColor,
    required Color surfaceColor2,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surfaceColor2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.format_quote_rounded,
                  color: _accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'О себе',
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bio.isEmpty
                ? 'Добавь пару слов о себе, чтобы другим было проще познакомиться с тобой.'
                : bio,
            style: TextStyle(
              color: bio.isEmpty
                  ? subTextColor.withOpacity(0.72)
                  : subTextColor,
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid({
    required int myItems,
    required int trades,
    required int completedTrades,
    required int successRate,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Мои вещи',
                value: '$myItems',
                icon: Icons.inventory_2_rounded,
                accent: _cyan,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Обмены',
                value: '$trades',
                icon: Icons.swap_horizontal_circle_rounded,
                accent: _accent,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Успешно',
                value: '$completedTrades',
                icon: Icons.check_circle_rounded,
                accent: _green,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Рейтинг',
                value: '$successRate%',
                icon: Icons.star_rounded,
                accent: _gold,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
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
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        15,
        16,
        15,
        15,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withOpacity(0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(
              _isDarkMode ? 0.07 : 0.045,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 22,
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
                    color: _isDarkMode
                        ? Colors.white
                        : const Color(0xFF18252D),
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isDarkMode
                        ? const Color(0xFF8296A0)
                        : const Color(0xFF728089),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard({
    required int level,
    required int myItems,
    required int completedTrades,
    required int sentOffers,
    required Color surfaceColor,
    required Color surfaceColor2,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: _accent.withOpacity(0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.055),
            blurRadius: 25,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      _accent,
                      _accent2,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Твой уровень',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Уровень $level • ${LevelCalculator.getLevelName(level)}',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$level LVL',
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildGlowRay(
            color: _accent,
            widthFactor: 0.84,
          ),
          const SizedBox(height: 18),
          Text(
            'Активность',
            style: TextStyle(
              color: subTextColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _buildMiniProgress(
                  icon: Icons.inventory_2_rounded,
                  value: '$myItems',
                  label: 'вещей',
                  accent: _cyan,
                  surfaceColor2: surfaceColor2,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniProgress(
                  icon: Icons.swap_horiz_rounded,
                  value: '$completedTrades',
                  label: 'обменов',
                  accent: _green,
                  surfaceColor2: surfaceColor2,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniProgress(
                  icon: Icons.send_rounded,
                  value: '$sentOffers',
                  label: 'заявок',
                  accent: _violet,
                  surfaceColor2: surfaceColor2,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgress({
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
    required Color surfaceColor2,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: surfaceColor2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: accent,
            size: 17,
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: subTextColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutCard({
    required Color borderColor,
    required Color textColor,
    required Color surfaceColor,
    required Color subTextColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _logout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _red.withOpacity(0.14),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выйти из аккаунта',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Завершить текущую сессию',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: subTextColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlowRay({
    required Color color,
    double widthFactor = 0.82,
  }) {
    return SizedBox(
      height: 12,
      width: double.infinity,
      child: CustomPaint(
        painter: _GlowRayPainter(
          color: color,
          widthFactor: widthFactor,
          backgroundColor: _isDarkMode
              ? const Color(0x22354A55)
              : const Color(0x22394D57),
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

    final right = left + totalWidth;

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
      ..shader = gradient.createShader(rect)
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
      ..shader = gradient.createShader(rect)
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