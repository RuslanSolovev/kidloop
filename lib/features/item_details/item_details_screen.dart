// features/item_details/item_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/item_model.dart';
import '../../../core/items_provider.dart';
import '../my_items/select_item_to_trade_screen.dart';
import '../profile/public_profile_screen.dart';
import '../../widgets/image_gallery_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== iOS DESIGN SYSTEM ====================

class _IOS {
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color darkBg = Color(0xFF000000);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);

  static const Color blue = Color(0xFF007AFF);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color purple = Color(0xFFAF52DE);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color indigo = Color(0xFF5856D6);
  static const Color pink = Color(0xFFFF2D55);
  static const Color red = Color(0xFFFF3B30);
  static const Color gray = Color(0xFF8E8E93);

  static Color separator(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color textPrimary(bool isDark) => isDark ? Colors.white : Colors.black;
  static Color textSecondary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.6)
      : const Color(0xFF3C3C43).withOpacity(0.6);
  static Color textTertiary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.3)
      : const Color(0xFF3C3C43).withOpacity(0.3);
}

class ItemDetailsScreen extends StatefulWidget {
  final Item item;

  const ItemDetailsScreen({super.key, required this.item});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  Map<String, dynamic>? _ownerData;
  bool _loadingOwner = true;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    if (widget.item.isMine) {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _ownerData = {
            'name': prefs.getString('user_name') ?? 'Вы',
            'avatar_url': prefs.getString('avatar_url') ?? '',
          };
          _loadingOwner = false;
        });
      }
      return;
    }

    try {
      final provider = context.read<ItemsProvider>();
      final ownerData = await provider.getUserProfile(widget.item.ownerId);
      if (mounted) {
        setState(() {
          _ownerData = ownerData;
          _loadingOwner = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingOwner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = _isDarkMode;

    return Scaffold(
      backgroundColor: _IOS.bg(isDark),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ==========================================================
          // HERO GALLERY
          // ==========================================================
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            stretch: true,
            backgroundColor: _IOS.bg(isDark).withOpacity(0.85),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: 60,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Hero(
                tag: 'item_image_${item.itemId}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageGalleryWidget(
                      imageUrls: item.imagePaths,
                      height: 340,
                      borderRadius: 0,
                      showIndicators: true,
                    ),

                    // Bottom gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _IOS.bg(isDark),
                              _IOS.bg(isDark).withOpacity(0.6),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ==========================================================
          // CONTENT
          // ==========================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- Title + SV ----------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: _IOS.textPrimary(isDark),
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildSvBadge(item.sv),
                    ],
                  ),

                  // ---------- Description ----------
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 15,
                        color: _IOS.textSecondary(isDark),
                        height: 1.45,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ---------- Tags ----------
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (item.category.isNotEmpty)
                        _buildTag(
                          item.category,
                          _IOS.blue,
                          icon: Icons.category_rounded,
                        ),
                      if (item.condition.isNotEmpty)
                        _buildTag(
                          item.condition,
                          _IOS.green,
                          icon: Icons.verified_rounded,
                        ),
                      if (item.location.isNotEmpty)
                        _buildTag(
                          item.location,
                          _IOS.orange,
                          icon: Icons.location_on_rounded,
                        ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ---------- Owner card ----------
                  _buildOwnerCard(),

                  // ---------- Trade button ----------
                  if (!item.isMine) ...[
                    const SizedBox(height: 20),
                    _buildTradeButton(item),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SV BADGE
  // ============================================================

  Widget _buildSvBadge(int sv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _IOS.orange.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: _IOS.orange,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            '$sv',
            style: const TextStyle(
              color: _IOS.orange,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            'SV',
            style: TextStyle(
              color: _IOS.orange,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAG
  // ============================================================

  Widget _buildTag(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: -0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OWNER CARD
  // ============================================================

  Widget _buildOwnerCard() {
    final isDark = _isDarkMode;

    if (_loadingOwner) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _IOS.card(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _IOS.separator(isDark)),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _IOS.blue,
            ),
          ),
        ),
      );
    }

    final name = _ownerData?['name'] ??
        (widget.item.isMine ? 'Вы' : 'Пользователь');
    final avatarUrl = _ownerData?['avatar_url'] ?? '';
    final isMine = widget.item.isMine;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _IOS.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _IOS.separator(isDark)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _IOS.blue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Center(
                child: Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: const TextStyle(
                    color: _IOS.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: const TextStyle(
                    color: _IOS.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            )
                : Center(
              child: Text(
                (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                style: const TextStyle(
                  color: _IOS.blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMine ? 'Это ваша вещь' : 'Владелец',
                  style: TextStyle(
                    color: _IOS.textTertiary(isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.3,
                    color: _IOS.textPrimary(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Profile button
          if (!isMine)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicProfileScreen(
                      userId: widget.item.ownerId,
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _IOS.blue.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_rounded,
                        color: _IOS.blue, size: 15),
                    SizedBox(width: 5),
                    Text(
                      'Профиль',
                      style: TextStyle(
                        color: _IOS.blue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // TRADE BUTTON
  // ============================================================

  Widget _buildTradeButton(Item item) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SelectItemToTradeScreen(wantedItem: item),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _IOS.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Предложить обмен',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}