import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../item_details/item_details_screen.dart';
import '../../../core/items_provider.dart';
import '../../../core/item_model.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  void initState() {
    super.initState();
    // Загружаем при первом открытии
    Future.delayed(const Duration(milliseconds: 100), () {
      context.read<ItemsProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    final items = provider.items;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KidLoop', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              // TODO: Фильтры
            },
          ),
        ],
      ),
      body: provider.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.toys_outlined,
                size: 60,
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Пока нет вещей',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите + чтобы добавить',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () => provider.loadItems(),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _ItemCard(item: item);
          },
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ItemDetailsScreen(item: item),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Изображение
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: item.imagePath,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 300),
                          placeholder: (_, __) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.toys, size: 64, color: theme.colorScheme.outlineVariant),
                          ),
                        ),
                      ),
                    ),
                    // SV бейдж
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade400, Colors.deepOrange],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${item.sv} SV',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Категория
                    if (item.category.isNotEmpty)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Контент
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.condition.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getConditionColor(item.condition).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getConditionColor(item.condition).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                item.condition,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getConditionColor(item.condition),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 18, color: Colors.blue.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location.isNotEmpty ? item.location : 'Не указано',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Подробнее',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'Новый':
        return Colors.green;
      case 'Отличный':
        return Colors.teal;
      case 'Хороший':
        return Colors.blue;
      case 'Обычный':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}