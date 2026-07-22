// features/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/image_gallery_widget.dart';
import '../item_details/item_details_screen.dart';
import '../../core/items_provider.dart';
import '../../core/item_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _showMyItems = false;
  String? _loadError;
  int _retryCount = 0;
  bool _isRefreshing = false;

  // Scroll контроллер для отслеживания позиции
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _loadItems();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await context.read<ItemsProvider>().loadItems().timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _retryCount = 0;
          _loadError = null;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
      _retryLoad();
    }
  }

  void _retryLoad() {
    _retryCount++;
    if (_retryCount <= 5 && mounted) {
      if (_retryCount >= 2) {
        setState(() => _loadError = 'Проблемы с загрузкой. Пробуем снова...');
      }
      Future.delayed(const Duration(seconds: 2), _loadItems);
    } else if (_retryCount > 5 && mounted) {
      setState(() => _loadError = 'Не удалось загрузить вещи. Проверьте интернет и потяните, чтобы обновить.');
    }
  }

  Future<void> _onRefresh() async {
    _retryCount = 0;
    _loadError = null;
    await _loadItems();
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : const Color(0xFF1A1D24);
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1D24) : Colors.white;
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    final allItems = provider.items;
    final items = _showMyItems ? allItems.where((e) => e.isMine).toList() : allItems;

    final allCount = allItems.length;
    final myCount = allItems.where((e) => e.isMine).length;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // СЛИВЕР С ФИЛЬТРАМИ (скрывается при прокрутке)
          SliverAppBar(
            pinned: false, // Не прикреплен к верху
            floating: true, // Показывается при прокрутке вверх
            snap: false, // Не "прилипает"
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 0, // Убираем стандартную высоту AppBar
            flexibleSpace: FlexibleSpaceBar(
              background: _buildFilterBar(allCount, myCount),
            ),
            expandedHeight: 80, // Высота фильтров
            collapsedHeight: 0,
            automaticallyImplyLeading: false,
          ),

          // ОСНОВНОЙ КОНТЕНТ
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildBody(provider, items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(int allCount, int myCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          _buildFilterButton(
            isActive: !_showMyItems,
            icon: Icons.public_rounded,
            label: 'Все',
            count: allCount,
            onTap: () => setState(() => _showMyItems = false),
          ),
          const SizedBox(width: 4),
          _buildFilterButton(
            isActive: _showMyItems,
            icon: Icons.inventory_2_rounded,
            label: 'Мои',
            count: myCount,
            onTap: () => setState(() => _showMyItems = true),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required bool isActive,
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? (_isDarkMode ? const Color(0xFF2A2D35) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.orange : _subTextColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? _textColor : _subTextColor,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.orange.withOpacity(0.15) : (_isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.orange : _subTextColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ItemsProvider provider, List<Item> items) {
    // Состояние ошибки
    if (_loadError != null && items.isEmpty && !provider.isLoading && !_isRefreshing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.1),
              ),
              child: Icon(Icons.wifi_off_rounded, size: 48, color: Colors.orange.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: _subTextColor, fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() { _retryCount = 0; _loadError = null; });
                _loadItems();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: Colors.orange.withOpacity(0.3),
              ),
              child: const Text('Обновить', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      );
    }

    // Состояние загрузки
    if ((provider.isLoading || _isRefreshing) && items.isEmpty && _loadError == null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text('Загрузка вещей...', style: TextStyle(color: _subTextColor, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    // Пустое состояние
    if (items.isEmpty && _loadError == null && !provider.isLoading) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.orange.withOpacity(0.1), Colors.deepOrange.withOpacity(0.05)]),
                ),
                child: Icon(_showMyItems ? Icons.inventory_2_outlined : Icons.search_off_rounded, size: 64, color: Colors.orange.withOpacity(0.6)),
              ),
              const SizedBox(height: 24),
              Text(
                _showMyItems ? 'У тебя пока нет вещей' : 'Пока нет вещей',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Нажми + чтобы добавить первое объявление!',
                textAlign: TextAlign.center,
                style: TextStyle(color: _subTextColor, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Список с RefreshIndicator
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.orange,
      backgroundColor: _surfaceColor,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(), // Отключаем скролл, т.к. используем CustomScrollView
        shrinkWrap: true,
        itemCount: items.length,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildItemCard(context, item);
        },
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Item item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ItemDetailsScreen(item: item),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: Hero(
        tag: 'item_${item.title}_${item.hashCode}',
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  children: [
                    ImageGalleryWidget(
                      imageUrls: item.imagePaths,
                      height: 220,
                      borderRadius: 24,
                      showIndicators: true,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [_surfaceColor.withOpacity(0.8), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textColor, height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: TextStyle(color: _subTextColor, fontSize: 14, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (item.category.isNotEmpty) _buildTag(item.category, Colors.blue),
                        if (item.category.isNotEmpty && item.condition.isNotEmpty) const SizedBox(width: 8),
                        if (item.condition.isNotEmpty) _buildTag(item.condition, Colors.green),
                        const Spacer(),
                        _buildSvBadge(item.sv),
                      ],
                    ),
                    if (item.location.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: Colors.blue.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location,
                              style: TextStyle(color: Colors.blue.shade400, fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSvBadge(int sv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8A3D), Color(0xFFFF6B00)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '$sv SV',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}