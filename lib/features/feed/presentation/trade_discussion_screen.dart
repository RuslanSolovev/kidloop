import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/trades_provider.dart';
import '../../../core/trade_offer.dart';
import 'chat_widget.dart';

class TradeDiscussionScreen extends StatefulWidget {
  final TradeOffer offer;

  const TradeDiscussionScreen({super.key, required this.offer});

  @override
  State<TradeDiscussionScreen> createState() => _TradeDiscussionScreenState();
}

class _TradeDiscussionScreenState extends State<TradeDiscussionScreen> {
  String? _currentUserId;
  String? _fromImageUrl;
  String? _toImageUrl;
  int _fromSv = 0;
  int _toSv = 0;
  String _fromDescription = '';
  String _toDescription = '';
  String _fromCondition = '';
  String _toCondition = '';
  String _fromCategory = '';
  String _toCategory = '';
  bool _isLoadingDetails = true;

  static final Map<String, String> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadItemDetails();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _currentUserId = prefs.getString('user_id'));
  }

  Future<void> _loadItemDetails() async {
    try {
      final cacheKey = '${widget.offer.fromItemId}_${widget.offer.toItemId}';
      if (_imageCache.containsKey('${cacheKey}_from')) {
        setState(() {
          _fromImageUrl = _imageCache['${cacheKey}_from'];
          _toImageUrl = _imageCache['${cacheKey}_to'];
          _isLoadingDetails = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4ei9an1aushareidmjc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      );
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        for (final item in data['items']) {
          if (item['item_id'] == widget.offer.fromItemId) {
            final url = item['image_path'] ?? '';
            setState(() {
              _fromImageUrl = url;
              _fromSv = item['sv'] ?? 0;
              _fromDescription = item['description'] ?? '';
              _fromCondition = item['condition'] ?? '';
              _fromCategory = item['category'] ?? '';
            });
            _imageCache['${cacheKey}_from'] = url;
          }
          if (item['item_id'] == widget.offer.toItemId) {
            final url = item['image_path'] ?? '';
            setState(() {
              _toImageUrl = url;
              _toSv = item['sv'] ?? 0;
              _toDescription = item['description'] ?? '';
              _toCondition = item['condition'] ?? '';
              _toCategory = item['category'] ?? '';
            });
            _imageCache['${cacheKey}_to'] = url;
          }
        }
      }
    } catch (e) {
      debugPrint("LOAD ITEM DETAILS ERROR: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  bool get _isFromUser => widget.offer.fromUserId == _currentUserId;
  bool get _isToUser => widget.offer.toUserId == _currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offers = context.watch<TradesProvider>().offers;
    final offer = offers.firstWhere((o) => o.id == widget.offer.id, orElse: () => widget.offer);
    final provider = context.read<TradesProvider>();

    final methodsMatch = offer.fromDeliveryMethod.isNotEmpty &&
        offer.toDeliveryMethod.isNotEmpty &&
        offer.fromDeliveryMethod == offer.toDeliveryMethod;

    final isActive = offer.status != 'cancelled' && offer.status != 'completed' && offer.status != 'rejected';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(_isFromUser ? 'Обмен с получателем' : 'Обмен с отправителем'),
            pinned: true,
            snap: false,
            floating: false,
          ),
          SliverToBoxAdapter(
            child: _isLoadingDetails
                ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
                : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Статус
                  _buildStatusBanner(offer, theme),
                  const SizedBox(height: 20),

                  // Обмен
                  _buildSectionHeader('📦 ОБМЕН', theme),
                  const SizedBox(height: 12),
                  _buildExchangeCards(offer, theme),
                  const SizedBox(height: 12),

                  // Доплата
                  _buildSVDifferenceCard(offer, theme),
                  const SizedBox(height: 24),

                  // Детали сделки
                  _buildSectionHeader('📋 ДЕТАЛИ СДЕЛКИ', theme),
                  const SizedBox(height: 12),
                  _buildDetailCard(offer, theme),
                  const SizedBox(height: 20),

                  // Способ передачи (только для активных)
                  if (isActive) ...[
                    _buildSectionHeader('🚚 СПОСОБ ПЕРЕДАЧИ', theme),
                    const SizedBox(height: 12),
                    _buildDeliveryMethods(offer, provider, theme),
                    const SizedBox(height: 8),
                    _buildDeliveryChoices(offer, theme),

                    if (offer.fromDeliveryMethod.isNotEmpty && offer.toDeliveryMethod.isNotEmpty)
                      _buildMatchIndicator(methodsMatch, theme),

                    const SizedBox(height: 20),

                    // Подтверждение
                    if (methodsMatch) ...[
                      _buildSectionHeader('✅ ПОДТВЕРЖДЕНИЕ', theme),
                      const SizedBox(height: 12),
                      _buildConfirmationProgress(offer, theme),
                      const SizedBox(height: 16),
                      _buildConfirmButtons(offer, provider, theme),
                    ] else if (offer.fromDeliveryMethod.isNotEmpty && offer.toDeliveryMethod.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.sync_problem, size: 40, color: theme.colorScheme.error),
                            const SizedBox(height: 8),
                            Text(
                              'Выберите одинаковый способ передачи\nдля подтверждения обмена',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Кнопка отмены
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCancelDialog(offer, provider),
                        icon: Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
                        label: Text(
                          'Отменить сделку',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Результаты сделки
                  if (offer.status == 'completed') ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('🏆 ИТОГИ СДЕЛКИ', theme),
                    const SizedBox(height: 12),
                    _buildCompletedResultCard(offer, theme),
                  ],

                  if (offer.status == 'cancelled') ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('💔 ИТОГИ ОТМЕНЫ', theme),
                    const SizedBox(height: 12),
                    _buildCancelledResultCard(offer, theme),
                  ],

                  const SizedBox(height: 24),

                  // Чат
                  _buildSectionHeader('💬 ОБСУЖДЕНИЕ', theme),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 400,
                    child: ChatWidget(offerId: offer.id),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(TradeOffer offer, ThemeData theme) {
    final statusColor = _getStatusColor(offer.status, theme);
    final statusIcon = _getStatusIcon(offer.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.15),
            statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(offer.status),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (offer.status == 'accepted')
                  Text(
                    'Выберите способ передачи',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor.withOpacity(0.7),
                    ),
                  ),
                if (offer.status == 'shipped')
                  Text(
                    'Ожидается получение',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeCards(TradeOffer offer, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildItemCard(
            label: _isFromUser ? 'Твоя вещь' : 'Вещь отправителя',
            isHighlighted: _isFromUser,
            title: offer.fromItemTitle,
            sv: _fromSv,
            imageUrl: _fromImageUrl,
            theme: theme,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 30),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
        ),
        Expanded(
          child: _buildItemCard(
            label: _isFromUser ? 'Вещь получателя' : 'Твоя вещь',
            isHighlighted: !_isFromUser,
            title: offer.toItemTitle,
            sv: _toSv,
            imageUrl: _toImageUrl,
            theme: theme,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard({
    required String label,
    required bool isHighlighted,
    required String title,
    required int sv,
    String? imageUrl,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHighlighted
              ? [
            theme.colorScheme.primaryContainer.withOpacity(0.5),
            theme.colorScheme.primaryContainer.withOpacity(0.2),
          ]
              : [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')
                ? Image.network(
              imageUrl,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.toys, size: 40, color: theme.colorScheme.outlineVariant),
              ),
            )
                : Container(
              height: 100,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.toys, size: 40, color: theme.colorScheme.outlineVariant),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$sv SV',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSVDifferenceCard(TradeOffer offer, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: offer.svDifference != 0
              ? [Colors.amber.shade200, Colors.orange.shade300]
              : [Colors.green.shade200, Colors.teal.shade300],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (offer.svDifference != 0 ? Colors.orange : Colors.green).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            offer.svDifference != 0 ? Icons.savings : Icons.balance,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              offer.svDifference > 0
                  ? 'Доплата отправителю: +${offer.svDifference} SV'
                  : offer.svDifference < 0
                  ? 'Доплата получателю: +${offer.svDifference.abs()} SV'
                  : 'Равный обмен',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(TradeOffer offer, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _detailRow('Сделка №', offer.id.substring(0, 8), theme),
            const Divider(height: 24),
            _detailRow('Отправитель', offer.fromItemTitle, theme),
            const SizedBox(height: 8),
            _detailRow('Получатель', offer.toItemTitle, theme),
            const Divider(height: 24),
            _detailRow('SV отправителя', '$_fromSv', theme),
            const SizedBox(height: 8),
            _detailRow('SV получателя', '$_toSv', theme),
            if (offer.svDifference != 0) ...[
              const SizedBox(height: 8),
              _detailRow(
                'Доплата',
                '${offer.svDifference.abs()} SV',
                theme,
                highlight: true,
              ),
            ],
            if (offer.deliveryMethod.isNotEmpty) ...[
              const Divider(height: 24),
              _detailRow('Способ передачи', _methodName(offer.deliveryMethod), theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme, {bool highlight = false}) {
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: highlight
              ? BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          )
              : null,
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.amber.shade800 : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryMethods(TradeOffer offer, TradesProvider provider, ThemeData theme) {
    final currentMethod = _isFromUser ? offer.fromDeliveryMethod : offer.toDeliveryMethod;

    return Row(
      children: [
        Expanded(
          child: _deliveryOptionCard(
            icon: Icons.people_rounded,
            label: 'Личная встреча',
            value: 'meetup',
            isSelected: currentMethod == 'meetup',
            theme: theme,
            onTap: currentMethod == 'meetup'
                ? null
                : () => provider.updateDeliveryMethod(offer.id, 'meetup'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _deliveryOptionCard(
            icon: Icons.local_shipping_rounded,
            label: 'Доставка',
            value: 'delivery',
            isSelected: currentMethod == 'delivery',
            theme: theme,
            onTap: currentMethod == 'delivery'
                ? null
                : () => provider.updateDeliveryMethod(offer.id, 'delivery'),
          ),
        ),
      ],
    );
  }

  Widget _deliveryOptionCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isSelected,
    required ThemeData theme,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryChoices(TradeOffer offer, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: _choiceChip(
              'Отправитель',
              offer.fromDeliveryMethod,
              theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _choiceChip(
              'Получатель',
              offer.toDeliveryMethod,
              theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceChip(String who, String method, ThemeData theme) {
    final chosen = method.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chosen
            ? theme.colorScheme.tertiaryContainer.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            chosen ? Icons.check_circle : Icons.hourglass_empty,
            size: 16,
            color: chosen ? Colors.green : theme.colorScheme.outlineVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$who: ${chosen ? _methodName(method) : "ждём..."}',
              style: TextStyle(
                fontSize: 12,
                color: chosen ? theme.colorScheme.onSurface : theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchIndicator(bool methodsMatch, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: methodsMatch
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: methodsMatch ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              methodsMatch ? Icons.check_circle : Icons.warning_rounded,
              color: methodsMatch ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              methodsMatch ? 'Способы совпадают!' : 'Способы не совпадают',
              style: TextStyle(
                color: methodsMatch ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationProgress(TradeOffer offer, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                _stepDot('Передача', offer.fromConfirmed, theme),
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: offer.fromConfirmed ? Colors.green : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _stepDot('Получение', offer.toConfirmed, theme),
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: offer.toConfirmed ? Colors.green : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _stepDot('Готово', offer.fromConfirmed && offer.toConfirmed, theme),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stepLabel('1. Передача', offer.fromConfirmed),
                _stepLabel('2. Получение', offer.toConfirmed),
                _stepLabel('3. Завершено', offer.fromConfirmed && offer.toConfirmed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepDot(String label, bool done, ThemeData theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? Colors.green : theme.colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: done ? Colors.green : theme.colorScheme.outlineVariant,
          width: 2,
        ),
        boxShadow: done
            ? [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: done
          ? const Icon(Icons.check, color: Colors.white, size: 20)
          : Center(
        child: Text(
          label[0],
          style: TextStyle(color: theme.colorScheme.outlineVariant, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _stepLabel(String text, bool active) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: active ? Colors.green : Colors.grey,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildConfirmButtons(TradeOffer offer, TradesProvider provider, ThemeData theme) {
    return Column(
      children: [
        if (_isFromUser && !offer.fromConfirmed)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => provider.confirmStep(offer.id, 'shipped'),
              icon: const Icon(Icons.local_shipping, color: Colors.white),
              label: const Text(
                'Я передал вещь',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

        if (_isToUser && offer.fromConfirmed && !offer.toConfirmed) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => provider.confirmStep(offer.id, 'received'),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text(
                'Я получил вещь',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],

        if (offer.fromConfirmed && !offer.toConfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_bottom, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ожидание подтверждения получения',
                  style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

        if (offer.fromConfirmed && offer.toConfirmed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.teal],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(Icons.celebration, color: Colors.white, size: 48),
                SizedBox(height: 8),
                Text(
                  '🎉 Обмен завершён!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCompletedResultCard(TradeOffer offer, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.verified, color: Colors.green.shade700, size: 48),
            const SizedBox(height: 12),
            Text(
              'Обмен успешно завершён!',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 32),
            _resultRow(
              icon: Icons.person,
              label: _isFromUser ? 'Ты получил' : 'Отправитель получил',
              value: _isFromUser ? offer.toItemTitle : offer.fromItemTitle,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _resultRow(
              icon: Icons.person_outline,
              label: _isFromUser ? 'Ты отдал' : 'Получатель отдал',
              value: _isFromUser ? offer.fromItemTitle : offer.toItemTitle,
              theme: theme,
            ),
            const Divider(height: 24),
            if (offer.svDifference > 0)
              _resultRow(
                icon: Icons.auto_awesome,
                label: _isFromUser ? 'Ты получил SV' : 'Отправитель получил SV',
                value: '+${offer.svDifference} SV',
                theme: theme,
                highlight: true,
              )
            else if (offer.svDifference < 0)
              _resultRow(
                icon: Icons.auto_awesome,
                label: _isFromUser ? 'Ты заплатил SV' : 'Получатель получил SV',
                value: '${offer.svDifference} SV',
                theme: theme,
                highlight: true,
              )
            else
              _resultRow(
                icon: Icons.balance,
                label: 'SV',
                value: 'Равный обмен',
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledResultCard(TradeOffer offer, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.red.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.restore, color: Colors.orange.shade700, size: 48),
            const SizedBox(height: 12),
            Text(
              'Сделка отменена',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              offer.svDifference > 0
                  ? '${offer.svDifference} SV возвращены отправителю'
                  : offer.svDifference < 0
                  ? '${offer.svDifference.abs()} SV возвращены получателю'
                  : 'SV не списывались',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Вещи остались у владельцев',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: highlight ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: highlight ? Colors.amber.shade700 : Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.amber.shade800 : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(TradeOffer offer, TradesProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 48),
        title: const Text('Отмена сделки'),
        content: const Text(
          'Сделка будет отменена, SV вернутся владельцу. Продолжить?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.cancelOffer(offer.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Да, отменить'),
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

  String _methodName(String method) {
    switch (method) {
      case 'meetup': return 'Личная встреча';
      case 'delivery': return 'Доставка';
      default: return method;
    }
  }
}