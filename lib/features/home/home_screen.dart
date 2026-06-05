import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <-- импорт

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
    // Небольшая задержка перед первой загрузкой
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _loadItems();
      }
    });
  }

  Future<void> _loadItems() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      print("🔄 HomeScreen: loading items...");
      await context.read<ItemsProvider>().loadItems().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("Таймаут загрузки");
        },
      );
      if (mounted) {
        setState(() {
          _retryCount = 0;
          _loadError = null;
          _isRefreshing = false;
        });
      }
      print("✅ HomeScreen: items loaded successfully");
    } catch (e) {
      print("🔴 HomeScreen: load error: $e");
      setState(() {
        _isRefreshing = false;
      });
      _retryLoad();
    }
  }

  void _retryLoad() {
    _retryCount++;
    print("🔄 HomeScreen: retry $_retryCount/5");
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
    print("🔄 HomeScreen: pull to refresh");
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
        // Сегмент-контрол
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
              onSelectionChanged: (selected) {
                setState(() => _showMyItems = selected.first);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.orange;
                  }
                  return Colors.grey.shade200;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.black;
                }),
              ),
            ),
          ),
        ),

        // Список вещей
        Expanded(
          child: _buildBody(provider, items),
        ),
      ],
    );
  }

  Widget _buildBody(ItemsProvider provider, List<Item> items) {
    // Ошибка загрузки
    if (_loadError != null && items.isEmpty && !provider.isLoading && !_isRefreshing) {
      return Center(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _retryCount = 0;
              _loadError = null;
            });
            _loadItems();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Повторить',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Загрузка (только если нет ошибки)
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

    // Пусто
    if (items.isEmpty && _loadError == null && !provider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _showMyItems
                  ? 'У тебя пока нет вещей.\nНажми + чтобы добавить!'
                  : 'Пока нет вещей.\nНажми + чтобы добавить',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: переход на экран добавления
              },
              icon: const Icon(Icons.add),
              label: const Text('Добавить вещь'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Список вещей
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
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemDetailsScreen(item: item),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Изображение
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Stack(
                      children: [
                        // Используем CachedNetworkImage для кэширования
                        item.imagePath.startsWith('http')
                            ? CachedNetworkImage(
                          imageUrl: item.imagePath,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              Container(
                                height: 200,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 50, color: Colors.grey),
                                ),
                              ),
                        )
                            : Image.asset(
                          item.imagePath,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 200,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.image_not_supported,
                                      size: 50, color: Colors.grey),
                                ),
                              ),
                        ),
                        // Бейдж статуса
                        if (item.status != 'available')
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: item.status == 'reserved'
                                    ? Colors.orange
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.status == 'reserved'
                                    ? 'ЗАБРОНИРОВАНО'
                                    : 'ОБМЕНЯНО',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Текстовая часть
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.description,
                          style: TextStyle(color: Colors.grey.shade700),
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
                      ],
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

  // Вспомогательные виджеты для тегов
  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSvBadge(int sv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$sv SV',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}