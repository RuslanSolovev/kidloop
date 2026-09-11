// features/home/home_screen.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/bundle_model.dart';
import '../../core/bundle_provider.dart';
import '../../core/item_model.dart';
import '../../core/items_provider.dart';
import '../../widgets/image_gallery_widget.dart';
import '../bundles/bundle_details_screen.dart';
import '../item_details/item_details_screen.dart';

// ============================================================
// KIDLOOP — IOS DESIGN SYSTEM
// ============================================================

class _IOS {
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color darkBg = Color(0xFF000000);

  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkElevated = Color(0xFF2C2C2E);

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

  static Color bg(bool isDark) {
    return isDark ? darkBg : lightBg;
  }

  static Color card(bool isDark) {
    return isDark ? darkCard : lightCard;
  }

  static Color elevated(bool isDark) {
    return isDark ? darkElevated : const Color(0xFFF8F8FA);
  }

  static Color primaryText(bool isDark) {
    return isDark ? Colors.white : const Color(0xFF111111);
  }

  static Color secondaryText(bool isDark) {
    return isDark
        ? Colors.white.withOpacity(0.62)
        : const Color(0xFF3C3C43).withOpacity(0.68);
  }

  static Color tertiaryText(bool isDark) {
    return isDark
        ? Colors.white.withOpacity(0.36)
        : const Color(0xFF3C3C43).withOpacity(0.42);
  }

  static Color separator(bool isDark) {
    return isDark
        ? Colors.white.withOpacity(0.085)
        : Colors.black.withOpacity(0.065);
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

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

  late final AnimationController _fadeController;

  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _fadeController.forward();

    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        _loadItems();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isDarkMode {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadItems() async {
    if (_isRefreshing) {
      return;
    }

    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      await Future.wait([
        context
            .read<ItemsProvider>()
            .loadItems()
            .timeout(const Duration(seconds: 15)),
        context
            .read<BundleProvider>()
            .loadAllBundles()
            .timeout(const Duration(seconds: 10)),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _retryCount = 0;
        _loadError = null;
        _isRefreshing = false;
      });

      if (!_fadeController.isCompleted) {
        _fadeController.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }

      _retryLoad();
    }
  }

  void _retryLoad() {
    _retryCount++;

    if (_retryCount <= 5 && mounted) {
      if (_retryCount >= 2) {
        setState(() {
          _loadError = 'Не удалось загрузить ленту.\nПробуем снова…';
        });
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _loadItems();
        }
      });
    } else if (_retryCount > 5 && mounted) {
      setState(() {
        _loadError =
        'Не удалось загрузить вещи.\nПроверьте интернет и потяните вниз, чтобы обновить.';
      });
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();

    _retryCount = 0;
    _loadError = null;

    await _loadItems();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final itemsProvider = context.watch<ItemsProvider>();
    final bundleProvider = context.watch<BundleProvider>();

    final allItems = itemsProvider.items;
    final allBundles = bundleProvider.allBundles;

    final itemCategories = allItems
        .map((item) => item.category)
        .where((category) => category.isNotEmpty)
        .toSet();

    final bundleCategories = allBundles
        .expand((bundle) => bundle.categories)
        .where((category) => category.isNotEmpty)
        .toSet();

    final availableCategories = {
      ...itemCategories,
      ...bundleCategories,
    }.toList()
      ..sort();

    if (_selectedCategory != null &&
        !availableCategories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }

    final List<dynamic> combinedItems = [];

    for (final item in allItems) {
      if (_showMyItems && !item.isMine) {
        continue;
      }

      if (_selectedCategory != null &&
          item.category != _selectedCategory) {
        continue;
      }

      combinedItems.add(item);
    }

    for (final bundle in allBundles) {
      if (_showMyItems && !bundle.isMine) {
        continue;
      }

      if (_selectedCategory != null &&
          !bundle.hasCategory(_selectedCategory!)) {
        continue;
      }

      combinedItems.add(bundle);
    }

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

      if (dateA == null && dateB == null) {
        return 0;
      }

      if (dateA == null) {
        return 1;
      }

      if (dateB == null) {
        return -1;
      }

      return dateB.compareTo(dateA);
    });

    return Scaffold(
      backgroundColor: _IOS.bg(_isDarkMode),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(
              availableCategories,
              allItems.length + allBundles.length,
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildBody(
                itemsProvider,
                bundleProvider,
                combinedItems,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
      List<String> categories,
      int totalCount,
      ) {
    final isDark = _isDarkMode;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // TOP TITLE
            // --------------------------------------------------

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: _IOS.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'KIDLOOP • MARKET',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.05,
                                color: _IOS.tertiaryText(isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Обмен',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.25,
                            height: 1,
                            color: _IOS.primaryText(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ------------------------------------------------
                  // TOTAL COUNTER
                  // ------------------------------------------------

                  if (totalCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _IOS.card(isDark),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: _IOS.separator(isDark),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 14,
                            color: _IOS.secondaryText(isDark),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$totalCount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _IOS.primaryText(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // SEGMENTED TAB
            // --------------------------------------------------

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSegmentedControl(isDark),
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // CATEGORY STRIP
            // --------------------------------------------------

            if (categories.isNotEmpty)
              _buildCategoryChips(categories),

            const SizedBox(height: 10),

            // --------------------------------------------------
            // SMALL SEPARATOR
            // --------------------------------------------------

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 1,
                color: _IOS.separator(isDark),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEGMENTED CONTROL
  // ============================================================

  Widget _buildSegmentedControl(bool isDark) {
    final items = context.watch<ItemsProvider>().items;
    final bundles = context.watch<BundleProvider>().allBundles;

    final allCount = items.length + bundles.length;

    final myCount = items.where((item) => item.isMine).length +
        bundles.where((bundle) => bundle.isMine).length;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.075)
            : Colors.black.withOpacity(0.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _IOS.separator(isDark),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegment(
              isActive: !_showMyItems,
              label: 'Все',
              count: allCount,
              icon: Icons.explore_rounded,
              onTap: () {
                if (_showMyItems) {
                  HapticFeedback.selectionClick();

                  setState(() {
                    _showMyItems = false;
                  });
                }
              },
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _buildSegment(
              isActive: _showMyItems,
              label: 'Мои',
              count: myCount,
              icon: Icons.person_rounded,
              onTap: () {
                if (!_showMyItems) {
                  HapticFeedback.selectionClick();

                  setState(() {
                    _showMyItems = true;
                  });
                }
              },
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required bool isActive,
    required String label,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isActive
              ? _IOS.card(isDark)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(
                isDark ? 0.32 : 0.08,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: isActive
                      ? _IOS.blue.withOpacity(
                    isDark ? 0.17 : 0.10,
                  )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: isActive
                      ? _IOS.blue
                      : _IOS.tertiaryText(isDark),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive
                      ? FontWeight.w700
                      : FontWeight.w500,
                  letterSpacing: -0.15,
                  color: isActive
                      ? _IOS.primaryText(isDark)
                      : _IOS.secondaryText(isDark),
                ),
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? _IOS.secondaryText(isDark)
                      : _IOS.tertiaryText(isDark),
                ),
                child: Text('$count'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY CHIPS
  // ============================================================

  Widget _buildCategoryChips(List<String> categories) {
    final isDark = _isDarkMode;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final isAll = index == 0;

          final label = isAll
              ? 'Все категории'
              : categories[index - 1];

          final isActive = isAll
              ? _selectedCategory == null
              : _selectedCategory == label;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();

              setState(() {
                _selectedCategory = isAll ? null : label;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? _IOS.blue
                    : _IOS.card(isDark),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: isActive
                      ? _IOS.blue
                      : _IOS.separator(isDark),
                  width: 0.7,
                ),
                boxShadow: isActive
                    ? [
                  BoxShadow(
                    color: _IOS.blue.withOpacity(0.18),
                    blurRadius: 9,
                    offset: const Offset(0, 3),
                  ),
                ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAll) ...[
                      Icon(
                        Icons.apps_rounded,
                        size: 14,
                        color: isActive
                            ? Colors.white
                            : _IOS.secondaryText(isDark),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : _IOS.primaryText(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(
      ItemsProvider itemsProvider,
      BundleProvider bundleProvider,
      List<dynamic> items,
      ) {
    final isLoading =
        itemsProvider.isLoading || bundleProvider.isLoading;

    if (_loadError != null &&
        items.isEmpty &&
        !isLoading &&
        !_isRefreshing) {
      return _buildErrorState();
    }

    if ((isLoading || _isRefreshing) &&
        items.isEmpty &&
        _loadError == null) {
      return _buildLoadingState();
    }

    if (items.isEmpty &&
        _loadError == null &&
        !isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _IOS.blue,
      backgroundColor: _IOS.card(_isDarkMode),
      displacement: 18,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: items.length,
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          110,
        ),
        itemBuilder: (context, index) {
          final item = items[index];

          final child = item is Item
              ? _buildItemCard(context, item)
              : item is Bundle
              ? _buildBundleCard(context, item)
              : const SizedBox.shrink();

          return _AnimatedListEntry(
            index: index,
            child: child,
          );
        },
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState() {
    final isDark = _isDarkMode;

    return SizedBox(
      height: MediaQuery.of(context).size.height - 260,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _IOS.blue.withOpacity(
                  isDark ? 0.12 : 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    color: _IOS.blue,
                    strokeWidth: 2.7,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Загружаем обмены',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _IOS.primaryText(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ищем что-то интересное рядом',
              style: TextStyle(
                fontSize: 13,
                color: _IOS.secondaryText(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    final isDark = _isDarkMode;

    final title = _showMyItems
        ? 'У тебя пока нет вещей'
        : _selectedCategory != null
        ? 'В этой категории пусто'
        : 'Пока здесь пусто';

    final subtitle = _showMyItems
        ? 'Добавь вещь, которой готов поделиться'
        : _selectedCategory != null
        ? 'Попробуй выбрать другую категорию'
        : 'Скоро здесь появятся новые предложения';

    return SizedBox(
      height: MediaQuery.of(context).size.height - 270,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _IOS.blue.withOpacity(
                        isDark ? 0.18 : 0.10,
                      ),
                      _IOS.purple.withOpacity(
                        isDark ? 0.13 : 0.07,
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _showMyItems
                      ? Icons.inventory_2_outlined
                      : Icons.swap_horizontal_circle_outlined,
                  size: 38,
                  color: _IOS.blue,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _IOS.primaryText(isDark),
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.55,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _IOS.secondaryText(isDark),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    final isDark = _isDarkMode;

    return SizedBox(
      height: MediaQuery.of(context).size.height - 270,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: _IOS.orange.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 37,
                  color: _IOS.orange,
                ),
              ),
              const SizedBox(height: 21),
              Text(
                'Не получилось загрузить',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _IOS.primaryText(isDark),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _loadError ??
                    'Проверьте интернет и попробуйте ещё раз.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _IOS.secondaryText(isDark),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();

                  setState(() {
                    _retryCount = 0;
                    _loadError = null;
                  });

                  _loadItems();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _IOS.blue,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _IOS.blue.withOpacity(0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Обновить',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ITEM CARD
  // ============================================================

  Widget _buildItemCard(
      BuildContext context,
      Item item,
      ) {
    final isDark = _isDarkMode;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) {
              return ItemDetailsScreen(item: item);
            },
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration:
            const Duration(milliseconds: 240),
          ),
        );
      },
      child: Hero(
        tag: 'item_${item.title}_${item.hashCode}',
        child: Container(
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: _IOS.card(isDark),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _IOS.separator(isDark),
              width: 0.65,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  isDark ? 0.20 : 0.045,
                ),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // IMAGE
              // ------------------------------------------------

              Stack(
                children: [
                  ImageGalleryWidget(
                    imageUrls: item.imagePaths,
                    height: 245,
                    borderRadius: 22,
                    showIndicators: true,
                  ),

                  // Mine badge
                  if (item.isMine)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _buildFloatingBadge(
                        icon: Icons.person_rounded,
                        text: 'МОЁ',
                        color: _IOS.blue,
                      ),
                    ),

                  // SV overlay
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildImageSvBadge(item.sv),
                  ),
                ],
              ),

              // ------------------------------------------------
              // CONTENT
              // ------------------------------------------------

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  15,
                  15,
                  15,
                  15,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.45,
                              height: 1.16,
                              color:
                              _IOS.primaryText(isDark),
                            ),
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        style: TextStyle(
                          color:
                          _IOS.secondaryText(isDark),
                          fontSize: 13.5,
                          height: 1.38,
                        ),
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 13),

                    // Tags
                    Row(
                      children: [
                        if (item.category.isNotEmpty)
                          Flexible(
                            child: _buildTag(
                              item.category,
                              _IOS.blue,
                            ),
                          ),
                        if (item.category.isNotEmpty &&
                            item.condition.isNotEmpty)
                          const SizedBox(width: 6),
                        if (item.condition.isNotEmpty)
                          Flexible(
                            child: _buildTag(
                              item.condition,
                              _IOS.green,
                            ),
                          ),
                      ],
                    ),

                    if (item.location.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color:
                            _IOS.tertiaryText(isDark),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location,
                              style: TextStyle(
                                color:
                                _IOS.tertiaryText(
                                  isDark,
                                ),
                                fontSize: 12.5,
                                fontWeight:
                                FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
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

  // ============================================================
  // BUNDLE CARD
  // ============================================================

  Widget _buildBundleCard(
      BuildContext context,
      Bundle bundle,
      ) {
    final isDark = _isDarkMode;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) {
              return BundleDetailsScreen(
                bundle: bundle,
              );
            },
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration:
            const Duration(milliseconds: 240),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: _IOS.card(isDark),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _IOS.separator(isDark),
            width: 0.65,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                isDark ? 0.20 : 0.045,
              ),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildBundleCollage(bundle),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                15,
                15,
                15,
                15,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          bundle.title,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.45,
                            height: 1.16,
                            color:
                            _IOS.primaryText(isDark),
                          ),
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildBundleSvBadge(
                        bundle.totalSv,
                      ),
                    ],
                  ),

                  if (bundle.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      bundle.description,
                      style: TextStyle(
                        color:
                        _IOS.secondaryText(isDark),
                        fontSize: 13.5,
                        height: 1.38,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 13),

                  Row(
                    children: [
                      if (bundle.categories.isNotEmpty)
                        Flexible(
                          child: _buildTag(
                            bundle.categories.first,
                            _IOS.purple,
                          ),
                        ),
                      if (bundle.categories.length > 1)
                        Padding(
                          padding:
                          const EdgeInsets.only(
                            left: 6,
                          ),
                          child: Text(
                            '+${bundle.categories.length - 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                              FontWeight.w700,
                              color:
                              _IOS.tertiaryText(
                                isDark,
                              ),
                            ),
                          ),
                        ),
                      if (bundle.condition.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: _buildTag(
                            bundle.condition,
                            _IOS.green,
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (bundle.location.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 15,
                          color:
                          _IOS.tertiaryText(isDark),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            bundle.location,
                            style: TextStyle(
                              color:
                              _IOS.tertiaryText(
                                isDark,
                              ),
                              fontSize: 12.5,
                              fontWeight:
                              FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
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
    );
  }

  // ============================================================
  // BUNDLE COLLAGE
  // ============================================================

  Widget _buildBundleCollage(
      Bundle bundle,
      ) {
    final items = bundle.items;

    return Stack(
      children: [
        _buildCollageGrid(items),

        Positioned(
          top: 12,
          left: 12,
          child: _buildFloatingBadge(
            icon: Icons.inventory_2_rounded,
            text: 'НАБОР',
            color: _IOS.purple,
          ),
        ),

        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.60),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  '${bundle.items.length} вещи',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollageGrid(
      List<BundleItem> items,
      ) {
    final isDark = _isDarkMode;

    return Container(
      height: 225,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.025)
            : Colors.black.withOpacity(0.025),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(22),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const height = 225.0;
            final count = items.length;

            if (count == 0) {
              return _buildCollageEmpty(
                isDark,
                width,
                height,
              );
            }

            if (count == 1) {
              return _buildCollageItem(
                items[0],
                width,
                height,
              );
            }

            if (count == 2) {
              return Row(
                children: [
                  Expanded(
                    child: _buildCollageItem(
                      items[0],
                      width / 2,
                      height,
                    ),
                  ),
                  _collageGap(isDark),
                  Expanded(
                    child: _buildCollageItem(
                      items[1],
                      width / 2,
                      height,
                    ),
                  ),
                ],
              );
            }

            if (count == 3) {
              return Column(
                children: [
                  Expanded(
                    child: _buildCollageItem(
                      items[0],
                      width,
                      height / 2,
                    ),
                  ),
                  _collageGap(isDark),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCollageItem(
                            items[1],
                            width / 2,
                            height / 2,
                          ),
                        ),
                        _collageGap(isDark),
                        Expanded(
                          child: _buildCollageItem(
                            items[2],
                            width / 2,
                            height / 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            if (count == 4) {
              return Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCollageItem(
                            items[0],
                            width / 2,
                            height / 2,
                          ),
                        ),
                        _collageGap(isDark),
                        Expanded(
                          child: _buildCollageItem(
                            items[1],
                            width / 2,
                            height / 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _collageGap(isDark),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCollageItem(
                            items[2],
                            width / 2,
                            height / 2,
                          ),
                        ),
                        _collageGap(isDark),
                        Expanded(
                          child: _buildCollageItem(
                            items[3],
                            width / 2,
                            height / 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final extra = count - 5;

            return Column(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildCollageItem(
                    items[0],
                    width,
                    height * 0.6,
                  ),
                ),
                _collageGap(isDark),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildCollageItem(
                          items[1],
                          width / 4,
                          height * 0.4,
                        ),
                      ),
                      _collageGap(isDark),
                      Expanded(
                        child: _buildCollageItem(
                          items[2],
                          width / 4,
                          height * 0.4,
                        ),
                      ),
                      _collageGap(isDark),
                      Expanded(
                        child: _buildCollageItem(
                          items[3],
                          width / 4,
                          height * 0.4,
                        ),
                      ),
                      _collageGap(isDark),
                      Expanded(
                        child: extra > 0
                            ? _buildMoreBadge(
                          extra + 1,
                          isDark,
                        )
                            : _buildCollageItem(
                          items[4],
                          width / 4,
                          height * 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _collageGap(bool isDark) {
    return Container(
      width: 2,
      height: 2,
      color: _IOS.bg(isDark),
    );
  }

  Widget _buildCollageEmpty(
      bool isDark,
      double width,
      double height,
      ) {
    return Container(
      color: isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.03),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 42,
          color: _IOS.tertiaryText(isDark),
        ),
      ),
    );
  }

  Widget _buildCollageItem(
      BundleItem item,
      double width,
      double height,
      ) {
    final isDark = _isDarkMode;

    if (item.imagePath.isNotEmpty &&
        item.imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: item.imagePath,
        fit: BoxFit.cover,
        width: width,
        height: height,
        placeholder: (_, __) {
          return Container(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.04),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                size: 22,
                color:
                _IOS.tertiaryText(isDark),
              ),
            ),
          );
        },
        errorWidget: (_, __, ___) {
          return _buildCollageFallback(
            item,
            isDark,
          );
        },
      );
    }

    return _buildCollageFallback(
      item,
      isDark,
    );
  }

  Widget _buildCollageFallback(
      BundleItem item,
      bool isDark,
      ) {
    return Container(
      color: isDark
          ? Colors.white.withOpacity(0.045)
          : Colors.black.withOpacity(0.035),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _IOS.purple.withOpacity(0.12),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _IOS.purple,
                  size: 17,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color:
                  _IOS.secondaryText(isDark),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreBadge(
      int count,
      bool isDark,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.66),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 19,
            ),
            const SizedBox(height: 1),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BADGES
  // ============================================================

  Widget _buildFloatingBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSvBadge(int sv) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Colors.white.withOpacity(0.13),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: _IOS.orange,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            '$sv',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'SV',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundleSvBadge(int sv) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _IOS.orange.withOpacity(
          _isDarkMode ? 0.15 : 0.10,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: _IOS.orange,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '$sv SV',
            style: const TextStyle(
              color: _IOS.orange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAG
  // ============================================================

  Widget _buildTag(
      String text,
      Color color,
      ) {
    final isDark = _isDarkMode;

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 155,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(
          isDark ? 0.14 : 0.09,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.05,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ============================================================
// CARD ENTRY ANIMATION
// ============================================================

class _AnimatedListEntry extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedListEntry({
    required this.index,
    required this.child,
  });

  @override
  State<_AnimatedListEntry> createState() =>
      _AnimatedListEntryState();
}

class _AnimatedListEntryState
    extends State<_AnimatedListEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _opacity;

  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 430),
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    Future.delayed(
      Duration(
        milliseconds:
        (widget.index * 45).clamp(0, 280),
      ),
          () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}