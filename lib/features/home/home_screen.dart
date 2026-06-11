import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    final allItems = provider.items;
    final items = _showMyItems ? allItems.where((e) => e.isMine).toList() : allItems;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Все вещи'), icon: Icon(Icons.public)),
                ButtonSegment(value: true, label: Text('Мои вещи'), icon: Icon(Icons.inventory)),
              ],
              selected: {_showMyItems},
              onSelectionChanged: (selected) => setState(() => _showMyItems = selected.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) ? Colors.orange : Colors.grey.shade200;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) ? Colors.white : Colors.black;
                }),
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody(provider, items)),
      ],
    );
  }

  Widget _buildBody(ItemsProvider provider, List<Item> items) {
    if (_loadError != null && items.isEmpty && !provider.isLoading && !_isRefreshing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() { _retryCount = 0; _loadError = null; });
                _loadItems();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if ((provider.isLoading || _isRefreshing) && items.isEmpty && _loadError == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Загрузка вещей...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (items.isEmpty && _loadError == null && !provider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _showMyItems ? 'У тебя пока нет вещей.\nНажми + чтобы добавить!' : 'Пока нет вещей.\nНажми + чтобы добавить',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.orange,
      backgroundColor: Colors.white,
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ИЗОБРАЖЕНИЕ
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.imagePath,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 300),
                      fadeOutDuration: const Duration(milliseconds: 300),
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      imageBuilder: (context, imageProvider) {
                        return Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                    // Бейдж статуса
                    if (item.status != 'available')
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: item.status == 'reserved' ? Colors.orange : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.status == 'reserved' ? 'ЗАБРОНИРОВАНО' : 'ОБМЕНЯНО',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Текстовая часть
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Описание
                  Text(
                    item.description,
                    style: TextStyle(color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // 🔥 Теги: категория + состояние + SV
                  Row(
                    children: [
                      _buildTag(item.category, Colors.orange),
                      const SizedBox(width: 8),
                      _buildTag(item.condition, Colors.green),
                      const Spacer(),
                      _buildSvBadge(item.sv),
                    ],
                  ),
                  // 🔥 ГОРОД - отдельной строкой ниже
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
        color: color.withOpacity(0.1),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$sv SV',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}