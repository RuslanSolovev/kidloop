import 'package:flutter/material.dart';
import '../../../core/item_model.dart';

import '../my_items/select_item_to_trade_screen.dart';
import '../profile/public_profile_screen.dart';

class ItemDetailsScreen extends StatelessWidget {
  final Item item;

  const ItemDetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: item.imagePath.startsWith('http')
                  ? Image.network(
                item.imagePath,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/bear.jpg',
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  );
                },
              )
                  : Image.asset(
                item.imagePath,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 16),

            // Название
            Text(
              item.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Описание
            Text(
              item.description,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // SV баллы
            Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${item.sv} SV',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Категория и состояние
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(item.category, style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(item.condition, style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Локация
            Row(
              children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 4),
                Text(item.location),
              ],
            ),

            const SizedBox(height: 30),

            // Профиль владельца
            if (!item.isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person),
                    label: const Text('Профиль владельца'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(userId: item.ownerId),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Кнопка обмена
            if (!item.isMine)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SelectItemToTradeScreen(wantedItem: item),
                      ),
                    );
                  },
                  child: const Text('Предложить обмен'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}