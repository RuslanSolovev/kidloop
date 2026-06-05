import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../core/items_provider.dart';
import '../../../core/item_model.dart';
import '../../../core/trades_provider.dart';
import '../../../core/trade_offer.dart';

class SelectItemToTradeScreen extends StatelessWidget {
  final Item wantedItem;

  const SelectItemToTradeScreen({super.key, required this.wantedItem});

  Future<int> _getBalance(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4e4du0dtej5k7md0cc5'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-balance", "user_id": userId}),
      );
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return data['balance'] ?? 0;
      }
    } catch (e) {
      print("GET BALANCE ERROR: $e");
    }
    return 0;
  }

  Future<void> _sendOffer(BuildContext context, Item myItem) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id') ?? '';
    final diff = wantedItem.sv - myItem.sv;

    if (diff > 0) {
      final balance = await _getBalance(currentUserId);
      if (balance < diff) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('⚠️ Недостаточно SV'),
                ],
              ),
              content: Text(
                'Для этого обмена нужно $diff SV.\nУ тебя на балансе: $balance SV.\n\nДобавь больше вещей или выбери другую.',
                style: const TextStyle(height: 1.5),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Понятно'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.deepPurple, size: 28),
            SizedBox(width: 8),
            Text('Подтверждение обмена'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _offerItemTile(
              icon: Icons.card_giftcard,
              label: 'Ты получишь',
              title: wantedItem.title,
              sv: wantedItem.sv,
              color: Colors.green,
            ),
            const Divider(height: 24),
            _offerItemTile(
              icon: Icons.upload_file,
              label: 'Ты отдаёшь',
              title: myItem.title,
              sv: myItem.sv,
              color: Colors.red,
            ),
            const Divider(height: 24),
            if (diff > 0)
              _svChip('Ты доплатишь $diff SV', Colors.red)
            else if (diff < 0)
              _svChip('Тебе доплатят ${diff.abs()} SV', Colors.green)
            else
              _svChip('Равный обмен', Colors.grey),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.close),
            label: const Text('Отмена'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send),
            label: const Text('Отправить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final offer = TradeOffer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: currentUserId,
      toUserId: wantedItem.ownerId,
      fromItemId: myItem.itemId,
      toItemId: wantedItem.itemId,
      fromItemTitle: myItem.title,
      toItemTitle: wantedItem.title,
      svDifference: diff,
    );

    final result = await context.read<TradesProvider>().createOffer(offer);

    if (context.mounted) {
      Navigator.pop(context);
      if (result['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Предложение отправлено!'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        final error = result['error'] ?? '';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Ошибка'),
            content: Text(error == 'insufficient_balance'
                ? 'Недостаточно SV для отправки предложения.'
                : 'Не удалось отправить предложение.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _offerItemTile({
    required IconData icon,
    required String label,
    required String title,
    required int sv,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$sv SV', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _svChip(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myItems = context.watch<ItemsProvider>().items.where((e) => e.isMine).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбери свою вещь'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: myItems.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'У тебя нет своих вещей.\nДобавь первую, чтобы начать обмен!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          // Карточка желаемой вещи
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade100,
                  Colors.blue.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'wanted_${wantedItem.itemId}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      wantedItem.imagePath,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/bear.jpg',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ты хочешь получить',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        wantedItem.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${wantedItem.sv} SV',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Выбери свою вещь для обмена',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: myItems.length,
              itemBuilder: (context, index) {
                final item = myItems[index];
                final diff = wantedItem.sv - item.sv;

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + index * 50),
                  curve: Curves.easeOut,
                  builder: (_, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0, // используем кастомные тени
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _sendOffer(context, item),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Изображение
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Hero(
                                tag: 'my_item_${item.itemId}',
                                child: Image.network(
                                  item.imagePath,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/bear.jpg',
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.monetization_on, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${item.sv} SV',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Разница SV
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: diff > 0
                                      ? [Colors.orange.shade400, Colors.red.shade400]
                                      : diff < 0
                                      ? [Colors.green.shade400, Colors.teal.shade400]
                                      : [Colors.grey.shade400, Colors.grey.shade500],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: (diff > 0
                                        ? Colors.red
                                        : diff < 0
                                        ? Colors.green
                                        : Colors.grey)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                diff > 0
                                    ? '-$diff SV'
                                    : diff < 0
                                    ? '+${diff.abs()} SV'
                                    : 'Равно',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}