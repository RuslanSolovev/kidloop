import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/bundle_model.dart';
import '../../core/bundle_provider.dart';
import '../../core/items_provider.dart';
import '../../widgets/image_gallery_widget.dart';
import '../my_items/select_item_to_trade_screen.dart';
import '../profile/public_profile_screen.dart';
import '../../core/item_model.dart';

class BundleDetailsScreen extends StatefulWidget {
  final Bundle bundle;

  const BundleDetailsScreen({super.key, required this.bundle});

  @override
  State<BundleDetailsScreen> createState() => _BundleDetailsScreenState();
}

class _BundleDetailsScreenState extends State<BundleDetailsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _ownerData;
  bool _loadingOwner = true;
  String? _currentUserId;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor =>
      _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _backgroundColor =>
      _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);
  Color get _surfaceColor =>
      _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _cardBgColor => _isDarkMode
      ? Colors.white.withOpacity(0.05)
      : Colors.grey.shade50;
  Color get _cardBorderColor => _isDarkMode
      ? Colors.white.withOpacity(0.08)
      : Colors.grey.shade200;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();

    _loadOwnerData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');

    if (widget.bundle.userId == _currentUserId) {
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
      final ownerData = await provider.getUserProfile(widget.bundle.userId);
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
    final bundle = widget.bundle;
    final isMine = bundle.userId == _currentUserId;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Галерея изображений
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: _surfaceColor,
            foregroundColor: _textColor,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              if (isMine)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 22),
                      onPressed: () => _showDeleteDialog(),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'bundle_${bundle.bundleId}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageGalleryWidget(
                      imageUrls: bundle.imagePaths,
                      height: 350,
                      borderRadius: 0,
                      showIndicators: true,
                    ),
                    // Градиент снизу для плавного перехода
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _backgroundColor,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Бейдж НАБОР
                    Positioned(
                      top: 60,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'НАБОР',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Количество предметов
                    Positioned(
                      top: 60,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${bundle.items.length} предмета',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Контент
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок и SV
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              bundle.title,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // SV Бейдж
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8A3D), Color(0xFFFF6B00)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '${bundle.totalSv} SV',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Описание
                      if (bundle.description.isNotEmpty) ...[
                        Text(
                          bundle.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: _subTextColor,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 🔥 Теги — все категории + состояние + локация
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Все категории набора
                          ...bundle.categories.map((cat) => _buildInfoChip(
                            icon: Icons.category_rounded,
                            label: cat,
                            color: Colors.orange,
                          )),
                          _buildInfoChip(
                            icon: Icons.verified_rounded,
                            label: bundle.condition,
                            color: Colors.green,
                          ),
                          if (bundle.location.isNotEmpty)
                            _buildInfoChip(
                              icon: Icons.location_on_rounded,
                              label: bundle.location,
                              color: Colors.blue,
                            ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Карточка владельца
                      _buildOwnerCard(isMine),

                      const SizedBox(height: 28),

                      // Заголовок "Состав набора"
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '📦 Состав набора',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B1FA2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${bundle.items.length} предмета',
                              style: const TextStyle(
                                color: Color(0xFF7B1FA2),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Список предметов
                      ...List.generate(bundle.items.length, (index) {
                        final item = bundle.items[index];
                        return _buildItemInBundleCard(item, index);
                      }),

                      const SizedBox(height: 32),

                      // Сводка
                      _buildSummaryCard(bundle),

                      const SizedBox(height: 28),

                      // Кнопка "Предложить обмен"
                      if (!isMine) _buildTradeButton(bundle),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== КАРТОЧКА ВЛАДЕЛЬЦА ====================
  Widget _buildOwnerCard(bool isMine) {
    if (_loadingOwner) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorderColor),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF7B1FA2)),
          ),
        ),
      );
    }

    final name = _ownerData?['name'] ?? (isMine ? 'Вы' : 'Пользователь');
    final avatarUrl = _ownerData?['avatar_url'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMine
              ? const Color(0xFF7B1FA2).withOpacity(0.3)
              : _cardBorderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.purple.shade100,
            backgroundImage:
            avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
              (name.isNotEmpty ? name[0] : '?').toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF7B1FA2),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMine ? 'Это ваш набор' : 'Владелец набора',
                  style: TextStyle(
                    color: isMine ? const Color(0xFF7B1FA2) : _subTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textColor,
                  ),
                ),
              ],
            ),
          ),
          if (!isMine)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PublicProfileScreen(userId: widget.bundle.userId),
                  ),
                ),
                icon: const Icon(Icons.person, size: 18, color: Colors.white),
                label: const Text('Профиль',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== ЧИПС С ИНФОРМАЦИЕЙ ====================
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDarkMode ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(_isDarkMode ? 0.4 : 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== КАРТОЧКА ПРЕДМЕТА В НАБОРЕ ====================
  Widget _buildItemInBundleCard(BundleItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.1 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Номер предмета
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Информация о предмете
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (item.category.isNotEmpty)
                      _buildSmallTag(item.category, Colors.blue),
                    if (item.category.isNotEmpty && item.condition.isNotEmpty)
                      const SizedBox(width: 6),
                    if (item.condition.isNotEmpty)
                      _buildSmallTag(item.condition, Colors.green),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // SV предмета
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.15),
                  Colors.deepOrange.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Text(
              '${item.sv} SV',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ==================== СВОДКА ====================
  Widget _buildSummaryCard(Bundle bundle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B1FA2).withOpacity(0.08),
            const Color(0xFF512DA8).withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7B1FA2).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.summarize_rounded,
                  color: Color(0xFF7B1FA2), size: 22),
              SizedBox(width: 8),
              Text(
                'Сводка набора',
                style: TextStyle(
                  color: Color(0xFF7B1FA2),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            icon: Icons.inventory_2_outlined,
            label: 'Предметов в наборе',
            value: '${bundle.items.length} шт.',
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            icon: Icons.auto_awesome,
            label: 'Общая стоимость',
            value: '${bundle.totalSv} SV',
            valueColor: Colors.orange,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            icon: Icons.straighten,
            label: 'Средняя стоимость',
            value: '${(bundle.totalSv / bundle.items.length).round()} SV',
            valueColor: Colors.amber,
          ),
          // 🔥 Категории в сводке
          if (bundle.categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildSummaryRow(
              icon: Icons.category_rounded,
              label: 'Категории',
              value: bundle.categories.join(', '),
              valueColor: const Color(0xFF7B1FA2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.grey,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _subTextColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: _subTextColor, fontSize: 14),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==================== КНОПКА ОБМЕНА ====================
  Widget _buildTradeButton(Bundle bundle) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B1FA2).withOpacity(0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            // 🔥 Создаём временный Item для совместимости
            final tempItem = Item(
              itemId: bundle.bundleId,
              ownerId: bundle.userId,
              title: '📦 ${bundle.title}',
              description: bundle.description,
              sv: bundle.totalSv,
              imagePath: bundle.imagePaths.isNotEmpty
                  ? bundle.imagePaths.first
                  : '',
              imagePaths: bundle.imagePaths,
              location: bundle.location,
              category: bundle.primaryCategory,
              condition: bundle.condition,
              isMine: false,
              status: 'available',
            );

            // 🔥 ПЕРЕДАЁМ wantedBundle!
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SelectItemToTradeScreen(
                  wantedItem: tempItem,
                  wantedBundle: bundle,  // ← ВОТ ЭТО ГЛАВНОЕ
                ),
              ),
            );
          },
          icon: const Icon(Icons.swap_horiz_rounded,
              color: Colors.white, size: 22),
          label: const Text(
            'Предложить обмен',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== ДИАЛОГ УДАЛЕНИЯ ====================
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 8),
            Text('Удалить набор?', style: TextStyle(color: _textColor)),
          ],
        ),
        content: Text(
          'Это действие нельзя отменить. Все предметы останутся у вас, но сам набор будет удалён.',
          style: TextStyle(color: _subTextColor, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена',
                style: TextStyle(color: _subTextColor)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.red, Colors.redAccent]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context
                    .read<BundleProvider>()
                    .deleteBundle(widget.bundle.bundleId);
                Navigator.pop(context); // Возврат в ленту
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Набор удалён'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Удалить',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}