import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/image_gallery_widget.dart';
import '../item_details/item_details_screen.dart';
import '../../core/items_provider.dart';
import '../../core/item_model.dart';
import '../../core/bundle_provider.dart';
import '../../core/bundle_model.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../bundles/bundle_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _showMyItems = false;
  String? _loadError;
  int _retryCount = 0;
  bool _isRefreshing = false;
  String? _selectedCategory;

  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
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
      await Future.wait([
        context.read<ItemsProvider>().loadItems().timeout(const Duration(seconds: 15)),
        context.read<BundleProvider>().loadAllBundles().timeout(const Duration(seconds: 10)),
      ]);
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
        setState(
                () => _loadError = 'Проблемы с загрузкой. Пробуем снова...');
      }
      Future.delayed(const Duration(seconds: 2), _loadItems);
    } else if (_retryCount > 5 && mounted) {
      setState(() =>
      _loadError =
      'Не удалось загрузить вещи. Проверьте интернет и потяните, чтобы обновить.');
    }
  }

  Future<void> _onRefresh() async {
    _retryCount = 0;
    _loadError = null;
    await _loadItems();
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1A1D24);
  Color get _subTextColor =>
      _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _surfaceColor =>
      _isDarkMode ? const Color(0xFF1A1D24) : Colors.white;
  Color get _cardBorderColor => _isDarkMode
      ? Colors.white.withOpacity(0.06)
      : Colors.black.withOpacity(0.04);

  @override
  Widget build(BuildContext context) {
    final itemsProvider = context.watch<ItemsProvider>();
    final bundleProvider = context.watch<BundleProvider>();
    final allItems = itemsProvider.items;
    final allBundles = bundleProvider.allBundles;

    // 🔥 ОТЛАДКА
    debugPrint('=== HOME SCREEN BUILD ===');
    debugPrint('Items: ${allItems.length}');
    debugPrint('Bundles: ${allBundles.length}');
    for (final b in allBundles) {
      debugPrint('  Bundle: ${b.title} | categories: ${b.categories} | isMine: ${b.isMine}');
    }

    // Собираем все категории
    final itemCategories = allItems
        .map((e) => e.category)
        .where((c) => c.isNotEmpty)
        .toSet();
    final bundleCategories = allBundles
        .expand((e) => e.categories)
        .where((c) => c.isNotEmpty)
        .toSet();
    final availableCategories = {...itemCategories, ...bundleCategories}.toList()..sort();

    if (_selectedCategory != null &&
        !availableCategories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }

    // 🔥 Объединяем вещи и наборы
    final List<dynamic> combinedItems = [];

    // Добавляем одиночные вещи
    for (final item in allItems) {
      if (_showMyItems && !item.isMine) continue;
      if (_selectedCategory != null && item.category != _selectedCategory) continue;
      combinedItems.add(item);
    }

    // Добавляем наборы
    for (final bundle in allBundles) {
      if (_showMyItems && !bundle.isMine) continue;
      if (_selectedCategory != null && !bundle.hasCategory(_selectedCategory!)) continue;
      combinedItems.add(bundle);
    }

    debugPrint('Combined items: ${combinedItems.length}');

    // Сортировка: новые сверху
    combinedItems.sort((a, b) {
      DateTime? dateA;
      DateTime? dateB;

      if (a is Item) {
        dateA = DateTime.tryParse(a.createdAt ?? '');
      } else if (a is Bundle) {
        dateA = DateTime.tryParse(a.createdAt ?? '');
      }

      if (b is Item) {
        dateB = DateTime.tryParse(b.createdAt ?? '');
      } else if (b is Bundle) {
        dateB = DateTime.tryParse(b.createdAt ?? '');
      }

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: true,
            snap: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(availableCategories),
            ),
            expandedHeight: 110,
            collapsedHeight: 0,
            automaticallyImplyLeading: false,
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildBody(itemsProvider, bundleProvider, combinedItems),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<String> categories) {
    return Column(
      children: [
        _buildFilterBar(),
        if (categories.isNotEmpty) _buildCategoryChips(categories),
      ],
    );
  }

  Widget _buildFilterBar() {
    final allCount = context.watch<ItemsProvider>().items.length +
        context.watch<BundleProvider>().allBundles.length;
    final myCount = context
        .watch<ItemsProvider>()
        .items
        .where((e) => e.isMine)
        .length +
        context.watch<BundleProvider>().allBundles.where((b) => b.isMine).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.04)),
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
          const SizedBox(width: 3),
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
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive
                ? (_isDarkMode ? const Color(0xFF2A2D35) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
              BoxShadow(
                  color: Colors.black.withOpacity(
                      _isDarkMode ? 0.2 : 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isActive ? Colors.orange : _subTextColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? _textColor : _subTextColor,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.orange.withOpacity(0.15)
                        : (_isDarkMode
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
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

  Widget _buildCategoryChips(List<String> categories) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isActive = _selectedCategory == null;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = null),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.orange.withOpacity(0.2)
                      : _surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? Colors.orange : _cardBorderColor,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  'Все',
                  style: TextStyle(
                    color: isActive ? Colors.orange : _subTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          }
          final category = categories[index - 1];
          final isActive = _selectedCategory == category;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.orange.withOpacity(0.2)
                    : _surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? Colors.orange : _cardBorderColor,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isActive ? Colors.orange : _subTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ItemsProvider itemsProvider, BundleProvider bundleProvider, List<dynamic> items) {
    final isLoading = itemsProvider.isLoading || bundleProvider.isLoading;

    if (_loadError != null && items.isEmpty && !isLoading && !_isRefreshing) {
      return _buildErrorState();
    }

    if ((isLoading || _isRefreshing) && items.isEmpty && _loadError == null) {
      return _buildLoadingState();
    }

    if (items.isEmpty && _loadError == null && !isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.orange,
      backgroundColor: _surfaceColor,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: items.length,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is Item) {
            return _buildItemCard(context, item);
          } else if (item is Bundle) {
            return _buildBundleCard(context, item);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ==================== СОСТОЯНИЯ ====================
  Widget _buildErrorState() {
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
            child: Icon(Icons.wifi_off_rounded,
                size: 48, color: Colors.orange.withOpacity(0.6)),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(_loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _subTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _retryCount = 0;
                _loadError = null;
              });
              _loadItems();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Colors.orange.withOpacity(0.3),
            ),
            child: const Text('Обновить',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                  color: Colors.orange, strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text('Загрузка...',
                style: TextStyle(
                    color: _subTextColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                gradient: LinearGradient(colors: [
                  Colors.orange.withOpacity(0.1),
                  Colors.deepOrange.withOpacity(0.05)
                ]),
              ),
              child: Icon(
                  _showMyItems
                      ? Icons.inventory_2_outlined
                      : Icons.search_off_rounded,
                  size: 64,
                  color: Colors.orange.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            Text(
              _showMyItems ? 'У тебя пока нет вещей' : 'Пока нет вещей',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
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

  // ==================== КАРТОЧКА ВЕЩИ ====================
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
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    ImageGalleryWidget(
                      imageUrls: item.imagePaths,
                      height: 200,
                      borderRadius: 16,
                      showIndicators: true,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _surfaceColor.withOpacity(0.8),
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _textColor,
                            height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(item.description,
                        style: TextStyle(
                            color: _subTextColor,
                            fontSize: 13,
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (item.category.isNotEmpty)
                          _buildTag(item.category, Colors.blue),
                        if (item.category.isNotEmpty &&
                            item.condition.isNotEmpty)
                          const SizedBox(width: 6),
                        if (item.condition.isNotEmpty)
                          _buildTag(item.condition, Colors.green),
                        const Spacer(),
                        _buildSvBadge(item.sv),
                      ],
                    ),
                    if (item.location.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: Colors.blue.shade400),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(item.location,
                                style: TextStyle(
                                    color: Colors.blue.shade400,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
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

  // ==================== КАРТОЧКА НАБОРА С КОЛЛАЖЕМ ====================
  Widget _buildBundleCard(BuildContext context, Bundle bundle) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                BundleDetailsScreen(bundle: bundle),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.orange.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(_isDarkMode ? 0.15 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 КОЛЛАЖ — вместо ImageGalleryWidget
            _buildBundleCollage(bundle),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bundle.title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textColor,
                          height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(bundle.description,
                      style: TextStyle(
                          color: _subTextColor,
                          fontSize: 13,
                          height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (bundle.categories.isNotEmpty)
                        _buildTag(bundle.categories.first, Colors.blue),
                      if (bundle.categories.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '+${bundle.categories.length - 1}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _subTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (bundle.condition.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildTag(bundle.condition, Colors.green),
                      ],
                      const Spacer(),
                      _buildSvBadge(bundle.totalSv),
                    ],
                  ),
                  if (bundle.location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.blue.shade400),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(bundle.location,
                              style: TextStyle(
                                  color: Colors.blue.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
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
    );
  }

  // 🔥 КОЛЛАЖ из фото предметов набора
  // 🔥 КОЛЛАЖ из фото предметов набора — ВСЕГДА
  Widget _buildBundleCollage(Bundle bundle) {
    final items = bundle.items; // Все предметы

    return Stack(
      children: [
        _buildCollageGrid(items),
        // Бейдж "НАБОР"
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('НАБОР', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
        // Количество предметов
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${bundle.items.length} пред.',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 СЕТКА КОЛЛАЖА — поддерживает ЛЮБОЕ количество предметов
  Widget _buildCollageGrid(List<BundleItem> items) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.white.withOpacity(0.03) : Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = 200.0;
            final count = items.length;

            if (count == 0) {
              return const SizedBox.shrink();
            }

            // 1 предмет — на всю ширину
            if (count == 1) {
              return _buildCollageItem(items[0], width, height);
            }

            // 2 предмета — горизонтально 50/50
            if (count == 2) {
              return Row(
                children: [
                  Expanded(child: _buildCollageItem(items[0], width / 2, height)),
                  Expanded(child: _buildCollageItem(items[1], width / 2, height)),
                ],
              );
            }

            // 3 предмета — 1 большой сверху, 2 снизу
            if (count == 3) {
              return Column(
                children: [
                  Expanded(flex: 5, child: _buildCollageItem(items[0], width, height * 5 / 10)),
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        Expanded(child: _buildCollageItem(items[1], width / 2, height * 5 / 10)),
                        Expanded(child: _buildCollageItem(items[2], width / 2, height * 5 / 10)),
                      ],
                    ),
                  ),
                ],
              );
            }

            // 4 предмета — сетка 2×2
            if (count == 4) {
              return Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildCollageItem(items[0], width / 2, height / 2)),
                        Expanded(child: _buildCollageItem(items[1], width / 2, height / 2)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildCollageItem(items[2], width / 2, height / 2)),
                        Expanded(child: _buildCollageItem(items[3], width / 2, height / 2)),
                      ],
                    ),
                  ),
                ],
              );
            }

            // 5-6 предметов — 1 большой сверху, 4 маленьких снизу
            if (count == 5 || count == 6) {
              final bottomItems = items.sublist(1, count > 5 ? 5 : count); // максимум 4 снизу
              final remaining = count - 1 - bottomItems.length;

              return Column(
                children: [
                  Expanded(flex: 6, child: _buildCollageItem(items[0], width, height * 6 / 10)),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        for (int i = 0; i < 4; i++)
                          Expanded(
                            child: i < bottomItems.length
                                ? _buildCollageItem(bottomItems[i], width / 4, height * 4 / 10)
                                : _buildRemainingBadge(remaining + (4 - bottomItems.length), width / 4, height * 4 / 10),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // 7+ предметов — сетка с +N на последнем
            // Показываем первые 4 в сетке 2×2, остальные в бейдже
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildCollageItem(items[0], width / 2, height / 2)),
                          Expanded(child: _buildCollageItem(items[1], width / 2, height / 2)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildCollageItem(items[2], width / 2, height / 2)),
                          Expanded(child: _buildCollageItem(items[3], width / 2, height / 2)),
                        ],
                      ),
                    ),
                  ],
                ),
                // Полупрозрачный оверлей с +N
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.more_horiz, color: Colors.white, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            '+${count - 4}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'ещё',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 🔥 Бейдж с количеством оставшихся предметов
  Widget _buildRemainingBadge(int count, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.8),
        border: Border.all(color: _surfaceColor, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'ещё',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 ОДИН ЭЛЕМЕНТ КОЛЛАЖА (без параметров left/top)
  Widget _buildCollageItem(BundleItem item, double width, double height) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _surfaceColor, width: 1),
      ),
      child: ClipRRect(
        child: item.imagePath.isNotEmpty && item.imagePath.startsWith('http')
            ? CachedNetworkImage(
          imageUrl: item.imagePath,
          fit: BoxFit.cover,
          width: width,
          height: height,
          placeholder: (_, __) => Container(
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.image, color: Colors.grey)),
          ),
          errorWidget: (_, __, ___) => Container(
            color: Colors.grey.shade200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title, style: TextStyle(fontSize: 10, color: _subTextColor), textAlign: TextAlign.center, maxLines: 2),
                  const SizedBox(height: 2),
                  Text('${item.sv} SV', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        )
            : Container(
          color: Colors.grey.shade200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.title, style: TextStyle(fontSize: 10, color: _subTextColor), textAlign: TextAlign.center, maxLines: 2),
                const SizedBox(height: 2),
                Text('${item.sv} SV', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildSvBadge(int sv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFF8A3D), Color(0xFFFF6B00)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 12),
          const SizedBox(width: 3),
          Text('$sv SV',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}