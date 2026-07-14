// home_screen.dart
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

class _HomeScreenState extends State<HomeScreen> {
  bool _showMyItems = false;
  String? _loadError;
  int _retryCount = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _loadItems();
    });
  }

  Future<void> _loadItems() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await context.read<ItemsProvider>().loadItems().timeout(
        const Duration(seconds: 15),
      );
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
      setState(() => _loadError = 'Не удалось загрузить вещи. Проверьте интернет и потяните чтобы обновить.');
    }
  }

  Future<void> _onRefresh() async {
    _retryCount = 0;
    _loadError = null;
    await _loadItems();
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    final allItems = provider.items;
    final items = _showMyItems ? allItems.where((e) => e.isMine).toList() : allItems;

    // Считаем количество для каждого фильтра
    final allCount = allItems.length;
    final myCount = allItems.where((e) => e.isMine).length;

    return Column(
      children: [
        // Стильный минималистичный переключатель
        _buildFilterBar(allCount, myCount),
        Expanded(child: _buildBody(provider, items)),
      ],
    );
  }

  // Стильный минималистичный переключатель
  Widget _buildFilterBar(int allCount, int myCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Кнопка "Все вещи"
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showMyItems = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_showMyItems
                      ? (_isDarkMode ? const Color(0xFF2A2A3E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: !_showMyItems
                      ? [
                    BoxShadow(
                      color: _isDarkMode
                          ? Colors.black.withOpacity(0.2)
                          : Colors.black.withOpacity(0.05),
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
                      Icons.public_rounded,
                      size: 18,
                      color: !_showMyItems
                          ? Colors.orange
                          : (_isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey.shade500),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Все',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: !_showMyItems ? FontWeight.w600 : FontWeight.w400,
                        color: !_showMyItems
                            ? _textColor
                            : (_isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey.shade500),
                      ),
                    ),
                    if (allCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: !_showMyItems
                              ? Colors.orange.withOpacity(0.15)
                              : (_isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$allCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: !_showMyItems
                                ? Colors.orange
                                : (_isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Кнопка "Мои вещи"
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showMyItems = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _showMyItems
                      ? (_isDarkMode ? const Color(0xFF2A2A3E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: _showMyItems
                      ? [
                    BoxShadow(
                      color: _isDarkMode
                          ? Colors.black.withOpacity(0.2)
                          : Colors.black.withOpacity(0.05),
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
                      Icons.inventory_2_rounded,
                      size: 18,
                      color: _showMyItems
                          ? Colors.orange
                          : (_isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey.shade500),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Мои',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _showMyItems ? FontWeight.w600 : FontWeight.w400,
                        color: _showMyItems
                            ? _textColor
                            : (_isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey.shade500),
                      ),
                    ),
                    if (myCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _showMyItems
                              ? Colors.orange.withOpacity(0.15)
                              : (_isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$myCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _showMyItems
                                ? Colors.orange
                                : (_isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ItemsProvider provider, List<Item> items) {
    if (_loadError != null && items.isEmpty && !provider.isLoading && !_isRefreshing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: _subTextColor),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: _subTextColor, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() { _retryCount = 0; _loadError = null; });
                _loadItems();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if ((provider.isLoading || _isRefreshing) && items.isEmpty && _loadError == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 16),
            Text('Загрузка вещей...', style: TextStyle(color: _subTextColor)),
          ],
        ),
      );
    }

    if (items.isEmpty && _loadError == null && !provider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _showMyItems ? 'У тебя пока нет вещей.\nНажми + чтобы добавить!' : 'Пока нет вещей.\nНажми + чтобы добавить',
              textAlign: TextAlign.center,
              style: TextStyle(color: _subTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.orange,
      backgroundColor: _surfaceColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        padding: const EdgeInsets.only(bottom: 16),
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
          MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDarkMode ? 0.15 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: ImageGalleryWidget(
                imageUrls: item.imagePaths,
                height: 200,
                borderRadius: 20,
                showIndicators: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: TextStyle(color: _subTextColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTag(item.category, Colors.orange),
                      const SizedBox(width: 8),
                      _buildTag(item.condition, Colors.green),
                      const Spacer(),
                      _buildSvBadge(item.sv),
                    ],
                  ),
                  if (item.location.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.blue.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.location,
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
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
    );
  }

  Widget _buildTag(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSvBadge(int sv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40FF9800),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '$sv SV',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}