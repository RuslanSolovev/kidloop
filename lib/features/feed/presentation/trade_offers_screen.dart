// features/feed/presentation/trade_offers_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/trades_provider.dart';
import '../../../core/trade_offer.dart';
import 'trade_discussion_screen.dart';
import '../../../services/notification_service.dart';

class TradeOffersScreen extends StatefulWidget {
  const TradeOffersScreen({super.key});

  @override
  State<TradeOffersScreen> createState() => _TradeOffersScreenState();
}

class _TradeOffersScreenState extends State<TradeOffersScreen> {
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('user_id');
        _currentUserName = prefs.getString('user_name') ?? 'Пользователь';
      });
    }
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;

  Future<void> _acceptOffer(TradeOffer offer) async {
    final result = await context.read<TradesProvider>().updateStatus(offer.id, 'accepted');
    if (result['ok'] != true) {
      final error = result['error'] ?? '';
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
            title: Text('Ошибка', style: TextStyle(color: _textColor)),
            content: Text(
              error == 'insufficient_balance'
                  ? 'У вас недостаточно SV для принятия.'
                  : 'Не удалось принять предложение.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _subTextColor),
            ),
            actions: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      NotificationService.sendNotification(
        targetUserId: offer.fromUserId,
        type: 'trade_accepted',
        data: {
          'trade_id': offer.id,
          'item_title': offer.toItemTitle,
          'user_name': _currentUserName ?? 'Пользователь',
        },
      );

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
    final offers = context.watch<TradesProvider>().offers;
    final provider = context.read<TradesProvider>();

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: offers.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: () => context.read<TradesProvider>().loadOffers(),
        color: Colors.orange,
        backgroundColor: _surfaceColor,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Стильный заголовок
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            // Список предложений
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final offer = offers[index];
                    return _buildOfferCard(offer, provider);
                  },
                  childCount: offers.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с иконкой
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Обмены',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Управляйте предложениями обмена',
                      style: TextStyle(
                        fontSize: 13,
                        color: _subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Счетчик предложений
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Text(
                  '${context.watch<TradesProvider>().offers.length}',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.withOpacity(0.08), Colors.deepOrange.withOpacity(0.04)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 64,
              color: Colors.orange.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Нет предложений',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь будут появляться предложения\nобмена от других пользователей',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _subTextColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.withOpacity(0.1), Colors.deepOrange.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  'Создайте объявление, чтобы получать обмены',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(TradeOffer offer, TradesProvider provider) {
    final isTo = _isToUser(offer);
    final statusColor = _getStatusColor(offer.status);
    final canTap = offer.status == 'accepted' || offer.status == 'shipped' || offer.status == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: canTap
            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => TradeDiscussionScreen(offer: offer)))
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: canTap ? statusColor.withOpacity(0.2) : _cardBorderColor,
              width: canTap ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDarkMode ? 0.15 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Статус
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(offer.status),
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(offer.status),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Кто инициатор
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTo ? Colors.blue.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isTo ? '📩 Вам' : '📤 Вы',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isTo ? Colors.blue.shade600 : Colors.orange.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Карточка обмена
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Левая часть - что предлагают
                    Expanded(
                      child: _buildItemPreview(
                        title: isTo ? offer.fromItemTitle : offer.toItemTitle,
                        label: isTo ? 'Предлагают' : 'Вы предлагаете',
                        color: Colors.orange,
                      ),
                    ),
                    // Центральная иконка обмена
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    // Правая часть - что хотят получить
                    Expanded(
                      child: _buildItemPreview(
                        title: isTo ? offer.toItemTitle : offer.fromItemTitle,
                        label: isTo ? 'Взамен' : 'На что меняете',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // SV информация
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: offer.svDifference != 0
                          ? [Colors.amber.withOpacity(0.08), Colors.orange.withOpacity(0.04)]
                          : [Colors.green.withOpacity(0.08), Colors.teal.withOpacity(0.04)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: offer.svDifference != 0
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        offer.svDifference > 0
                            ? Icons.add_circle_outline
                            : offer.svDifference < 0
                            ? Icons.remove_circle_outline
                            : Icons.check_circle_outline,
                        size: 16,
                        color: offer.svDifference != 0 ? Colors.amber.shade700 : Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        offer.svDifference > 0
                            ? 'Доплата +${offer.svDifference} SV'
                            : offer.svDifference < 0
                            ? 'Доплата ${offer.svDifference} SV'
                            : 'Равный обмен',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: offer.svDifference != 0 ? Colors.amber.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Кнопки действий
                if (offer.status == 'pending' && isTo) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showRejectDialog(offer, provider),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.red.withOpacity(0.02),
                          ),
                          child: const Text(
                            'Отклонить',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00C853), Color(0xFF00BFA5)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00C853).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _acceptOffer(offer),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Принять',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (offer.status == 'pending' && !isTo) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          'Ожидание ответа...',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (offer.status == 'rejected') ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.block, size: 16, color: Colors.red),
                        const SizedBox(width: 6),
                        Text(
                          'Предложение отклонено',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (offer.status == 'completed') ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.withOpacity(0.08), Colors.teal.withOpacity(0.04)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.celebration, size: 18, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Обмен завершён! 🎉',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemPreview({
    required String title,
    required String label,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            height: 1.3,
            color: _textColor,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showRejectDialog(TradeOffer offer, TradesProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Отклонить предложение?', style: TextStyle(color: _textColor)),
        content: Text(
          'Вы уверены, что хотите отклонить это предложение обмена?',
          style: TextStyle(color: _subTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(color: _isDarkMode ? Colors.grey : Colors.grey.shade600),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.red, Colors.redAccent]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.updateStatus(offer.id, 'rejected').then((_) {
                  NotificationService.sendNotification(
                    targetUserId: offer.fromUserId,
                    type: 'trade_declined',
                    data: {
                      'trade_id': offer.id,
                      'item_title': offer.toItemTitle,
                      'user_name': _currentUserName ?? 'Пользователь',
                    },
                  );
                });
              },
              child: const Text(
                'Отклонить',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Принято';
      case 'shipped':
        return 'В пути';
      case 'completed':
        return 'Завершено';
      case 'rejected':
        return 'Отклонено';
      case 'cancelled':
        return 'Отменено';
      default:
        return 'Ожидает';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'shipped':
        return Icons.local_shipping;
      case 'completed':
        return Icons.celebration;
      case 'rejected':
        return Icons.block;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }
}