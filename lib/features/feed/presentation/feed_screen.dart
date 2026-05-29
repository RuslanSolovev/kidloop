import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../item_details/item_details_screen.dart';
import '../../../core/items_provider.dart';
import '../../../core/item_model.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(title: const Text('KidLoop')),
      body: provider.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(
          child: Text('Пока нет вещей.\nНажми + чтобы добавить', textAlign: TextAlign.center))
          : ListView.builder(
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
                        : Image.asset(item.imagePath,
                        height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(item.description, style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                              child: Text(item.category,
                                  style: const TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.green, borderRadius: BorderRadius.circular(20)),
                              child: Text(item.condition,
                                  style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 18),
                                const SizedBox(width: 4),
                                Text(item.location),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.blue, borderRadius: BorderRadius.circular(20)),
                              child: Text('${item.sv} SV',
                                  style: const TextStyle(color: Colors.white)),
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