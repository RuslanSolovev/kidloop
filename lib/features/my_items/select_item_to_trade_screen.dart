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

    // Проверяем баланс, если нужна доплата
    if (diff > 0) {
      final balance = await _getBalance(currentUserId);
      if (balance < diff) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('⚠️ Недостаточно SV'),
              content: Text(
                  'Для этого обмена нужно $diff SV.\nУ тебя на балансе: $balance SV.\n\nДобавь больше вещей или выбери другую.'),
              actions: [
                ElevatedButton(
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

    // Показываем подтверждение
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение обмена'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _itemRow('Ты получишь:', wantedItem.title, wantedItem.sv),
            const Divider(),
            _itemRow('Ты отдаёшь:', myItem.title, myItem.sv),
            const Divider(),
            if (diff > 0)
              Text('💰 Ты доплатишь $diff SV',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            else if (diff < 0)
              Text('💰 Тебе доплатят ${diff.abs()} SV',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            else
              const Text('🤝 Равный обмен', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить')),
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
          const SnackBar(content: Text('Предложение отправлено!')),
        );
      } else {
        final error = result['error'] ?? '';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
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

  Widget _itemRow(String label, String title, int sv) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
          Text('$sv SV'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myItems = context.watch<ItemsProvider>().items.where((e) => e.isMine).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Выбери свою вещь для обмена')),
      body: myItems.isEmpty
          ? const Center(
          child: Text('У тебя нет своих вещей.\nСначала добавь что-нибудь!', textAlign: TextAlign.center))
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: wantedItem.imagePath.startsWith('http')
                      ? Image.network(wantedItem.imagePath, width: 50, height: 50, fit: BoxFit.cover)
                      : Image.asset(wantedItem.imagePath, width: 50, height: 50, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ты хочешь получить:', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                      Text(wantedItem.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${wantedItem.sv} SV', style: TextStyle(color: Colors.blue.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Выбери свою вещь для обмена:', style: TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: myItems.length,
              itemBuilder: (context, index) {
                final item = myItems[index];
                final diff = wantedItem.sv - item.sv;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: item.imagePath.startsWith('http')
                        ? Image.network(item.imagePath, width: 60, height: 60, fit: BoxFit.cover)
                        : Image.asset(item.imagePath, width: 60, height: 60, fit: BoxFit.cover),
                    title: Text(item.title),
                    subtitle: Text('${item.sv} SV'),
                    trailing: diff != 0
                        ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: diff > 0 ? Colors.red.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        diff > 0 ? 'Доплатишь $diff SV' : 'Получишь ${diff.abs()} SV',
                        style: TextStyle(
                          color: diff > 0 ? Colors.red.shade700 : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                        : const Text('Равный обмен', style: TextStyle(color: Colors.grey)),
                    onTap: () => _sendOffer(context, item),
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