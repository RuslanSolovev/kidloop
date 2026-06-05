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
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
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
      body: offers.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              size: 80,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Пока нет предложений обмена',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Здесь будут появляться предложения обмена',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      )
          : CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text('Предложения обмена'),
            centerTitle: false,
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final offer = offers[index];
                  return _buildOfferCard(offer, provider, theme);
                },
                childCount: offers.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(TradeOffer offer, TradesProvider provider, ThemeData theme) {
    final isTo = _isToUser(offer);
    final statusColor = _getStatusColor(offer.status, theme);
    final canTap = offer.status != 'pending' && offer.status != 'rejected';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: statusColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        color: theme.colorScheme.surfaceContainerLow,
        child: InkWell(
          onTap: canTap
              ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TradeDiscussionScreen(offer: offer),
              ),
            );
          }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Статус и тип
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(offer.status), size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(offer.status),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (canTap)
                      Icon(Icons.chevron_right, color: theme.colorScheme.outlineVariant),
                  ],
                ),
                const SizedBox(height: 16),

                // Предметы обмена
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Предлагают',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            offer.fromItemTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Взамен на',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            offer.toItemTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Доплата
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: offer.svDifference != 0
                        ? Colors.amber.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        offer.svDifference != 0 ? Icons.savings : Icons.balance,
                        size: 16,
                        color: offer.svDifference != 0 ? Colors.amber.shade700 : Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        offer.svDifference > 0
                            ? 'Доплата: +${offer.svDifference} SV'
                            : offer.svDifference < 0
                            ? 'Доплата: ${offer.svDifference} SV'
                            : 'Равный обмен',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: offer.svDifference != 0
                              ? Colors.amber.shade700
                              : Colors.green.shade700,
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
                            side: BorderSide(color: Colors.red.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Отклонить'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _acceptOffer(offer),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Принять'),
                        ),
                      ),
                    ],
                  ),
                ],

                // Индикатор для отклонённых
                if (offer.status == 'rejected')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.block, size: 16, color: Colors.red.shade300),
                        const SizedBox(width: 6),
                        Text(
                          'Предложение отклонено',
                          style: TextStyle(color: Colors.red.shade300, fontSize: 13),
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

  void _showRejectDialog(TradeOffer offer, TradesProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Отклонить предложение?'),
        content: const Text('Вы уверены, что хотите отклонить это предложение обмена?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
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

  Color _getStatusColor(String status, ThemeData theme) {
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