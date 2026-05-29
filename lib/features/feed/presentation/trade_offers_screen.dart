import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../core/trades_provider.dart';
import '../../../core/trade_offer.dart';
import 'trade_discussion_screen.dart';

class TradeOffersScreen extends StatefulWidget {
  const TradeOffersScreen({super.key});

  @override
  State<TradeOffersScreen> createState() => _TradeOffersScreenState();
}

class _TradeOffersScreenState extends State<TradeOffersScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _currentUserId = prefs.getString('user_id'));
  }

  Future<void> _acceptOffer(TradeOffer offer) async {
    final result = await context.read<TradesProvider>().updateStatus(offer.id, 'accepted');
    if (result['ok'] != true) {
      final error = result['error'] ?? '';
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ошибка'),
            content: Text(error == 'insufficient_balance'
                ? 'У вас недостаточно SV для принятия.'
                : 'Не удалось принять предложение.'),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'completed': return Colors.green;
      case 'rejected': return Colors.red;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'accepted': return 'Принято';
      case 'shipped': return 'В процессе';
      case 'completed': return 'Завершено';
      case 'rejected': return 'Отклонено';
      case 'cancelled': return 'Отменено';
      default: return 'Ожидает';
    }
  }

  bool _isToUser(TradeOffer offer) => offer.toUserId == _currentUserId;

  @override
  Widget build(BuildContext context) {
    final offers = context.watch<TradesProvider>().offers;
    final provider = context.read<TradesProvider>();

    return Scaffold(

      body: offers.isEmpty
          ? const Center(child: Text('Пока нет предложений обмена'))
          : ListView.builder(
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          final isTo = _isToUser(offer);

          return Card(
            margin: const EdgeInsets.all(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (offer.status != 'pending' && offer.status != 'rejected') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TradeDiscussionScreen(offer: offer)),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Предлагают: ${offer.fromItemTitle}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        if (offer.status != 'pending' && offer.status != 'rejected')
                          const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Взамен на: ${offer.toItemTitle}'),
                    const SizedBox(height: 8),
                    if (offer.svDifference > 0)
                      Text('Доплата отправителю: +${offer.svDifference} SV',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                    else if (offer.svDifference < 0)
                      Text('Доплата получателю: +${offer.svDifference.abs()} SV',
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                    else
                      const Text('Равный обмен', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _statusColor(offer.status), borderRadius: BorderRadius.circular(20)),
                      child: Text(_statusText(offer.status),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    if (offer.status == 'pending' && isTo)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => provider.updateStatus(offer.id, 'rejected'),
                                child: const Text('Отклонить'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _acceptOffer(offer),
                                child: const Text('Принять'),
                              ),
                            ),
                          ],
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
}