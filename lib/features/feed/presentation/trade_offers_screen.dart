import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    if (mounted) {
      setState(() => _currentUserId = prefs.getString('user_id'));
    }
  }

  Future<void> _acceptOffer(TradeOffer offer) async {
    final result = await context.read<TradesProvider>().updateStatus(offer.id, 'accepted');
    if (result['ok'] != true) {
      final error = result['error'] ?? '';
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
            title: const Text('Ошибка'),
            content: Text(
              error == 'insufficient_balance'
                  ? 'У вас недостаточно SV для принятия.'
                  : 'Не удалось принять предложение.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Предложение принято! 🎉'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  bool _isToUser(TradeOffer offer) => offer.toUserId == _currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offers = context.watch<TradesProvider>().offers;
    final provider = context.read<TradesProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Предложения обмена', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: offers.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.swap_horiz_rounded, size: 56, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            const Text('Пока нет предложений обмена', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 8),
            const Text('Здесь будут появляться предложения\nобмена от других пользователей', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () => context.read<TradesProvider>().loadOffers(),
        color: Colors.orange,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            return _buildOfferCard(offer, provider, theme);
          },
        ),
      ),
    );
  }

  Widget _buildOfferCard(TradeOffer offer, TradesProvider provider, ThemeData theme) {
    final isTo = _isToUser(offer);
    final statusColor = _getStatusColor(offer.status);
    final canTap = offer.status == 'accepted' || offer.status == 'shipped' || offer.status == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: canTap
            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => TradeDiscussionScreen(offer: offer)))
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4)),
            ],
            border: canTap ? Border.all(color: statusColor.withOpacity(0.3), width: 1.5) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Статус
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(offer.status),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (canTap)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.orange, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Предметы обмена
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                            child: Text(isTo ? 'Предлагают' : 'Вы предлагаете', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue.shade600)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isTo ? offer.fromItemTitle : offer.toItemTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.orange.shade300, Colors.deepOrange.shade300]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                            child: Text(isTo ? 'Взамен на' : 'На что меняете', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade600)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isTo ? offer.toItemTitle : offer.fromItemTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Доплата
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: offer.svDifference != 0
                          ? [Colors.amber.withOpacity(0.1), Colors.orange.withOpacity(0.05)]
                          : [Colors.green.withOpacity(0.1), Colors.teal.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: offer.svDifference != 0 ? Colors.amber.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        offer.svDifference != 0 ? Icons.savings : Icons.balance,
                        size: 18,
                        color: offer.svDifference != 0 ? Colors.amber.shade700 : Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        offer.svDifference > 0
                            ? 'Доплата: +${offer.svDifference} SV'
                            : offer.svDifference < 0
                            ? 'Доплата: ${offer.svDifference} SV'
                            : 'Равный обмен',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: offer.svDifference != 0 ? Colors.amber.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Кнопки для pending
                if (offer.status == 'pending' && isTo) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showRejectDialog(offer, provider),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: Colors.red.withOpacity(0.03),
                          ),
                          child: const Text('Отклонить', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptOffer(offer),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                            shadowColor: Colors.green.withOpacity(0.4),
                          ),
                          child: const Text('Принять', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],

                // Ожидание для отправителя
                if (offer.status == 'pending' && !isTo)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                          SizedBox(width: 6),
                          Text('Ожидание ответа...', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                // Отклонено
                if (offer.status == 'rejected')
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block, size: 16, color: Colors.red),
                          SizedBox(width: 6),
                          Text('Предложение отклонено', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                // Завершено
                if (offer.status == 'completed')
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.green.withOpacity(0.08), Colors.teal.withOpacity(0.04)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.celebration, size: 18, color: Colors.green),
                          SizedBox(width: 6),
                          Text('Обмен завершён! 🎉', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(TradeOffer offer, TradesProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Отклонить предложение?'),
        content: const Text('Вы уверены, что хотите отклонить это предложение обмена?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.updateStatus(offer.id, 'rejected');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted': return Icons.check_circle_outline;
      case 'shipped': return Icons.local_shipping;
      case 'completed': return Icons.verified;
      case 'rejected': return Icons.cancel;
      case 'cancelled': return Icons.cancel;
      default: return Icons.hourglass_empty;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted': return 'Принято';
      case 'shipped': return 'В процессе';
      case 'completed': return 'Завершено';
      case 'rejected': return 'Отклонено';
      case 'cancelled': return 'Отменено';
      default: return 'Ожидает';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'completed': return Colors.green;
      case 'rejected': return Colors.red;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }
}