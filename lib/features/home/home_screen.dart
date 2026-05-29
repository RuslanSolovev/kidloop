import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItems();
    });
  }

  Future<void> _loadItems() async {
    try {
      print("🔄 HomeScreen: loading items...");
      await context.read<ItemsProvider>().loadItems();
      if (mounted) {
        setState(() {
          _retryCount = 0;
          _loadError = null;
        });
      }
      print("✅ HomeScreen: items loaded successfully");
    } catch (e) {
      print("🔴 HomeScreen: load error: $e");
      _retryLoad();
    }
  }

  void _retryLoad() {
    _retryCount++;
    print("🔄 HomeScreen: retry $_retryCount/5");
    if (_retryCount <= 5 && mounted) {
      if (_retryCount >= 3) {
        setState(() => _loadError = 'Проблемы с загрузкой. Пробуем снова...');
      }
      Future.delayed(const Duration(seconds: 2), _loadItems);
    } else if (_retryCount > 5 && mounted) {
      setState(() => _loadError = 'Не удалось загрузить вещи. Потяните чтобы обновить.');
    }
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
    if (_loadError != null && items.isEmpty && !provider.isLoading) {
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
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_loadError!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Нажмите чтобы повторить', style: TextStyle(color: Colors.orange, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // Загрузка
    if (provider.isLoading && items.isEmpty) {
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
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _showMyItems ? 'У тебя пока нет вещей.\nНажми + чтобы добавить!' : 'Пока нет вещей.\nНажми + чтобы добавить',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Список вещей
    return RefreshIndicator(
      onRefresh: () async {
        print("🔄 HomeScreen: pull to refresh");
        _retryCount = 0;
        _loadError = null;
        await _loadItems();
      },
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item)),
              );
            },
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: item.imagePath.startsWith('http')
                        ? Image.network(
                      item.imagePath,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset('assets/images/bear.jpg',
                            height: 200, width: double.infinity, fit: BoxFit.cover);
                      },
                    )
                        : Image.asset(item.imagePath, height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(item.description, style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                              child: Text(item.category, style: const TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                              child: Text(item.condition, style: const TextStyle(color: Colors.white)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
                              child: Text('${item.sv} SV', style: const TextStyle(color: Colors.white)),
                            ),
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
}