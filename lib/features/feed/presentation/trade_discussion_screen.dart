import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
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

  Set<String> _pendingSteps = {};

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
        if (mounted) {
          setState(() {
            _fromImageUrl = _imageCache['${cacheKey}_from'];
            _toImageUrl = _imageCache['${cacheKey}_to'];
            _isLoadingDetails = false;
          });
        }
        return;
      }

      print('🔍 Loading items: from=${widget.offer.fromItemId}, to=${widget.offer.toItemId}');

      // 🔥 Загружаем ВСЕ items (без фильтра по статусу)
      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4ei9an1aushareidmjc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "list",
          "limit": 100, // 🔥 Большой лимит
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final data = jsonDecode(response.body);
      print('📦 Items count: ${data['items']?.length}');

      if (data['ok'] == true) {
        bool foundFrom = false;
        bool foundTo = false;

        for (final item in data['items']) {
          final itemId = item['item_id']?.toString() ?? '';

          if (itemId == widget.offer.fromItemId) {
            foundFrom = true;
            final img = item['image_path']?.toString() ?? '';
            final sv = int.tryParse(item['sv']?.toString() ?? '0') ?? 0;
            print('✅ FROM FOUND: sv=$sv img=$img');
            if (mounted) {
              setState(() {
                _fromImageUrl = img;
                _fromSv = sv;
                _fromDescription = item['description']?.toString() ?? '';
                _fromCondition = item['condition']?.toString() ?? '';
                _fromCategory = item['category']?.toString() ?? '';
              });
            }
            _imageCache['${cacheKey}_from'] = img;
          }

          if (itemId == widget.offer.toItemId) {
            foundTo = true;
            final img = item['image_path']?.toString() ?? '';
            final sv = int.tryParse(item['sv']?.toString() ?? '0') ?? 0;
            print('✅ TO FOUND: sv=$sv img=$img');
            if (mounted) {
              setState(() {
                _toImageUrl = img;
                _toSv = sv;
                _toDescription = item['description']?.toString() ?? '';
                _toCondition = item['condition']?.toString() ?? '';
                _toCategory = item['category']?.toString() ?? '';
              });
            }
            _imageCache['${cacheKey}_to'] = img;
          }

          if (foundFrom && foundTo) break;
        }

        if (!foundFrom) print('❌ FROM ITEM NOT FOUND in list!');
        if (!foundTo) print('❌ TO ITEM NOT FOUND in list!');
      }
    } catch (e) {
      print("❌ ERROR: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }


  // 🔥 Запасной метод загрузки одного фото по item_id
  Future<String> _loadSingleItemImage(String itemId) async {
    try {
      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4ei9an1aushareidmjc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        for (final item in data['items']) {
          if (item['item_id'] == itemId) {
            // Парсим image_paths
            if (item['image_paths'] is List && (item['image_paths'] as List).isNotEmpty) {
              return (item['image_paths'] as List).first.toString();
            } else if (item['image_path'] != null && item['image_path'].toString().isNotEmpty) {
              return item['image_path'].toString();
            }
            // Если ничего не нашли - возвращаем пустую строку
            return '';
          }
        }
      }
    } catch (e) {
      debugPrint("Load single item error for $itemId: $e");
    }
    return '';
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8, top: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text('Детали обмена', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _isLoadingDetails
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatusBanner(offer, theme),
                const SizedBox(height: 24),
                _buildExchangeCards(offer, theme),
                const SizedBox(height: 20),
                _buildSVDifferenceCard(offer, theme),
                const SizedBox(height: 24),
                _buildSectionTitle('📋 Детали сделки', theme),
                const SizedBox(height: 12),
                _buildDetailCard(offer, theme),
                const SizedBox(height: 24),

                if (isActive) ...[
                  _buildSectionTitle('🚚 Способ передачи', theme),
                  const SizedBox(height: 12),
                  _buildDeliveryMethods(offer, provider, theme),
                  const SizedBox(height: 12),
                  _buildDeliveryChoices(offer, theme),
                  if (offer.fromDeliveryMethod.isNotEmpty && offer.toDeliveryMethod.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildMatchIndicator(methodsMatch, theme),
                  ],
                  const SizedBox(height: 24),

                  if (methodsMatch) ...[
                    _buildSectionTitle('✅ Подтверждение обмена', theme),
                    const SizedBox(height: 12),
                    _buildConfirmationPanel(offer, provider, theme),
                  ] else if (offer.fromDeliveryMethod.isNotEmpty && offer.toDeliveryMethod.isNotEmpty)
                    _buildMismatchWarning(theme),

                  const SizedBox(height: 20),
                  _buildCancelButton(offer, provider, theme),
                ],

                if (offer.status == 'completed') ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('🏆 Итоги сделки', theme),
                  const SizedBox(height: 12),
                  _buildCompletedResultCard(offer, theme),
                ],

                if (offer.status == 'cancelled') ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('💔 Итоги отмены', theme),
                  const SizedBox(height: 12),
                  _buildCancelledResultCard(offer, theme),
                ],

                const SizedBox(height: 24),
                _buildSectionTitle('💬 Обсуждение', theme),
                const SizedBox(height: 12),
                _buildChatSection(offer),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // СТАТУС БАННЕР
  // ====================================================================
  Widget _buildStatusBanner(TradeOffer offer, ThemeData theme) {
    final statusColor = _getStatusColor(offer.status, theme);
    final statusIcon = _getStatusIcon(offer.status);
    final statusText = _getStatusText(offer.status);
    final statusDescription = _getStatusDescription(offer.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [statusColor.withOpacity(0.12), statusColor.withOpacity(0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: statusColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 2),
              Text(statusDescription, style: TextStyle(color: statusColor.withOpacity(0.7), fontSize: 13)),
            ]),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // КАРТОЧКИ ОБМЕНА
  // ====================================================================
  Widget _buildExchangeCards(TradeOffer offer, ThemeData theme) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _buildItemCard(label: _isFromUser ? 'Твоя вещь' : 'Вещь партнёра', isHighlighted: _isFromUser, title: offer.fromItemTitle, sv: _fromSv, imageUrl: _fromImageUrl, category: _fromCategory, condition: _fromCondition, theme: theme)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 40),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade400]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
          child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 24),
        ),
      ),
      Expanded(child: _buildItemCard(label: _isFromUser ? 'Вещь партнёра' : 'Твоя вещь', isHighlighted: !_isFromUser, title: offer.toItemTitle, sv: _toSv, imageUrl: _toImageUrl, category: _toCategory, condition: _toCondition, theme: theme)),
    ]);
  }

  Widget _buildItemCard({required String label, required bool isHighlighted, required String title, required int sv, String? imageUrl, String category = '', String condition = '', required ThemeData theme}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isHighlighted ? [BoxShadow(color: Colors.orange.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))] : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        border: isHighlighted ? Border.all(color: Colors.orange.withOpacity(0.4), width: 2) : null,
      ),
      child: Column(children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(
            height: 130, width: double.infinity,
            child: imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')
                ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 300), placeholder: (_, __) => Container(color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))), errorWidget: (_, __, ___) => Container(color: Colors.grey.shade100, child: Icon(Icons.toys, size: 40, color: Colors.grey.shade300)))
                : Container(color: Colors.grey.shade100, child: Icon(Icons.toys, size: 40, color: Colors.grey.shade300)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.3), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            if (category.isNotEmpty || condition.isNotEmpty)
              Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.center, children: [
                if (category.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(category, style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600))),
                if (condition.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(condition, style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600))),
              ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade400]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.auto_awesome, color: Colors.white, size: 12), const SizedBox(width: 4), Text('$sv SV', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
            ),
          ]),
        ),
      ]),
    );
  }

  // ====================================================================
  // КАРТОЧКА ДОПЛАТЫ
  // ====================================================================
  Widget _buildSVDifferenceCard(TradeOffer offer, ThemeData theme) {
    final hasDifference = offer.svDifference != 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: hasDifference ? [Colors.amber.shade300, Colors.orange.shade400] : [Colors.green.shade300, Colors.teal.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: (hasDifference ? Colors.orange : Colors.green).withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(hasDifference ? Icons.savings : Icons.balance, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Flexible(child: Text(hasDifference ? 'Доплата: ${offer.svDifference > 0 ? '+' : ''}${offer.svDifference} SV' : 'Равный обмен', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))),
      ]),
    );
  }

  // ====================================================================
  // ЗАГОЛОВОК СЕКЦИИ
  // ====================================================================
  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Row(children: [
      Container(width: 4, height: 22, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 12),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
    ]);
  }

  // ====================================================================
  // ДЕТАЛИ СДЕЛКИ
  // ====================================================================
  Widget _buildDetailCard(TradeOffer offer, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        _detailRow('Сделка №', '#${offer.id.substring(0, 8).toUpperCase()}', theme),
        const Divider(height: 20),
        _detailRowWithIcon(Icons.send_rounded, 'Отправитель', offer.fromItemTitle, theme),
        const SizedBox(height: 8),
        _detailRowWithIcon(Icons.inbox_rounded, 'Получатель', offer.toItemTitle, theme),
        const Divider(height: 20),
        _detailRowWithIcon(Icons.auto_awesome, 'SV отправителя', '$_fromSv SV', theme, highlight: true),
        const SizedBox(height: 6),
        _detailRowWithIcon(Icons.auto_awesome, 'SV получателя', '$_toSv SV', theme, highlight: true),
        if (offer.svDifference != 0) ...[
          const SizedBox(height: 6),
          _detailRowWithIcon(Icons.savings, 'Доплата', '${offer.svDifference.abs()} SV', theme, highlight: true),
        ],
        if (offer.deliveryMethod.isNotEmpty) ...[
          const Divider(height: 20),
          _detailRowWithIcon(Icons.local_shipping, 'Способ передачи', _methodName(offer.deliveryMethod), theme),
        ],
      ]),
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme, {bool highlight = false}) {
    return Row(children: [
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      const Spacer(),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: highlight ? BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)) : null, child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: highlight ? Colors.amber.shade800 : Colors.black87))),
    ]);
  }

  Widget _detailRowWithIcon(IconData icon, String label, String value, ThemeData theme, {bool highlight = false}) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: highlight ? Colors.amber.shade600 : Colors.grey.shade500)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      const Spacer(),
      Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: highlight ? Colors.amber.shade800 : Colors.black87)),
    ]);
  }

  // ====================================================================
  // СПОСОБ ПЕРЕДАЧИ
  // ====================================================================
  Widget _buildDeliveryMethods(TradeOffer offer, TradesProvider provider, ThemeData theme) {
    final currentMethod = _isFromUser ? offer.fromDeliveryMethod : offer.toDeliveryMethod;
    return Row(children: [
      Expanded(child: _deliveryOptionCard(icon: Icons.people_rounded, title: 'Личная встреча', subtitle: 'Встретиться лично', value: 'meetup', isSelected: currentMethod == 'meetup', theme: theme, onTap: currentMethod == 'meetup' ? null : () => provider.updateDeliveryMethod(offer.id, 'meetup'))),
      const SizedBox(width: 12),
      Expanded(child: _deliveryOptionCard(icon: Icons.local_shipping_rounded, title: 'Доставка', subtitle: 'Отправить почтой', value: 'delivery', isSelected: currentMethod == 'delivery', theme: theme, onTap: currentMethod == 'delivery' ? null : () => provider.updateDeliveryMethod(offer.id, 'delivery'))),
    ]);
  }

  Widget _deliveryOptionCard({required IconData icon, required String title, required String subtitle, required String value, required bool isSelected, required ThemeData theme, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isSelected ? Colors.orange.withOpacity(0.06) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade200, width: isSelected ? 2 : 1), boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 26, color: isSelected ? Colors.orange : Colors.grey.shade400)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isSelected ? Colors.orange : Colors.black87)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: isSelected ? Colors.orange.withOpacity(0.7) : Colors.grey.shade500)),
          if (isSelected) ...[const SizedBox(height: 6), Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.check, color: Colors.white, size: 14))],
        ]),
      ),
    );
  }

  Widget _buildDeliveryChoices(TradeOffer offer, ThemeData theme) {
    return Row(children: [
      Expanded(child: _choiceChip('Вы', offer.fromDeliveryMethod, Icons.person_rounded, theme)),
      const SizedBox(width: 10),
      Expanded(child: _choiceChip('Партнёр', offer.toDeliveryMethod, Icons.people_rounded, theme)),
    ]);
  }

  Widget _choiceChip(String who, String method, IconData icon, ThemeData theme) {
    final chosen = method.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: chosen ? Colors.green.withOpacity(0.06) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: chosen ? Colors.green.withOpacity(0.3) : Colors.grey.shade200)),
      child: Row(children: [
        Icon(icon, size: 18, color: chosen ? Colors.green : Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(child: Text(chosen ? '$who: ${_methodName(method)}' : '$who: ожидание...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: chosen ? Colors.black87 : Colors.grey.shade500))),
        if (chosen) Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
      ]),
    );
  }

  Widget _buildMatchIndicator(bool methodsMatch, ThemeData theme) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: methodsMatch ? Colors.green.withOpacity(0.06) : Colors.red.withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: methodsMatch ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(methodsMatch ? Icons.check_circle : Icons.warning_rounded, color: methodsMatch ? Colors.green : Colors.red, size: 22),
        const SizedBox(width: 8),
        Text(methodsMatch ? 'Способы совпадают! Можно подтверждать' : 'Способы не совпадают', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: methodsMatch ? Colors.green.shade700 : Colors.red.shade700)),
      ]),
    );
  }

  Widget _buildMismatchWarning(ThemeData theme) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.06), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.amber.withOpacity(0.3))),
      child: Column(children: [
        Icon(Icons.sync_problem, size: 40, color: Colors.amber.shade600),
        const SizedBox(height: 8),
        Text('Выберите одинаковый способ передачи\nдля подтверждения обмена', textAlign: TextAlign.center, style: TextStyle(color: Colors.amber.shade800, fontSize: 14)),
      ]),
    );
  }

  // ====================================================================
  // ПАНЕЛЬ ПОДТВЕРЖДЕНИЯ
  // ====================================================================
  Widget _buildConfirmationPanel(TradeOffer offer, TradesProvider provider, ThemeData theme) {
    final fromShipped = offer.fromShipped || _pendingSteps.contains('from_shipped');
    final fromReceived = offer.fromReceived || _pendingSteps.contains('from_received');
    final toShipped = offer.toShipped || _pendingSteps.contains('to_shipped');
    final toReceived = offer.toReceived || _pendingSteps.contains('to_received');

    final myShipped = _isFromUser ? fromShipped : toShipped;
    final myReceived = _isFromUser ? fromReceived : toReceived;
    final partnerShipped = _isFromUser ? toShipped : fromShipped;
    final partnerReceived = _isFromUser ? toReceived : fromReceived;

    final myDone = myShipped && myReceived;
    final partnerDone = partnerShipped && partnerReceived;
    final allDone = myDone && partnerDone;
    final completed = [fromShipped, fromReceived, toShipped, toReceived].where((v) => v).length;

    Future<void> handleConfirm(String step) async {
      // 🔥 Подтверждение с диалогом
      final isShipped = step.contains('shipped');
      final action = isShipped ? 'отправили' : 'получили';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(
            isShipped ? Icons.local_shipping : Icons.inbox_rounded,
            color: isShipped ? Colors.green : Colors.blue,
            size: 48,
          ),
          title: Text(isShipped ? 'Подтверждение отправки' : 'Подтверждение получения'),
          content: Text('Вы точно $action вещь?', textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Нет'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: isShipped ? Colors.green : Colors.blue,
              ),
              child: const Text('Да, подтверждаю'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() => _pendingSteps.add(step));
        await provider.confirmStep(offer.id, step);
        setState(() => _pendingSteps.remove(step));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(allDone ? Icons.celebration : Icons.swap_horiz_rounded, color: allDone ? Colors.green : Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text(allDone ? '🎉 Обмен завершён!' : 'Прогресс обмена', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: allDone ? Colors.green : Colors.black87)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: completed / 4, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(allDone ? Colors.green : Colors.orange)),
          ),
          const SizedBox(height: 6),
          Text('$completed/4 шагов выполнено', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 20),

          _buildUserConfirmationBlock(
            label: 'Я',
            shipped: myShipped,
            received: myReceived,
            isMe: true,
            onTapShipped: _isFromUser
                ? (!fromShipped ? () => handleConfirm('from_shipped') : null)
                : (!toShipped ? () => handleConfirm('to_shipped') : null),
            onTapReceived: _isFromUser
                ? (!fromReceived ? () => handleConfirm('from_received') : null)
                : (!toReceived ? () => handleConfirm('to_received') : null),
            theme: theme,
          ),
          const SizedBox(height: 14),
          _buildUserConfirmationBlock(
            label: 'Партнёр',
            shipped: partnerShipped,
            received: partnerReceived,
            isMe: false,
            onTapShipped: null,
            onTapReceived: null,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildUserConfirmationBlock({
    required String label,
    required bool shipped,
    required bool received,
    required bool isMe,
    VoidCallback? onTapShipped,
    VoidCallback? onTapReceived,
    required ThemeData theme,
  }) {
    final allDone = shipped && received;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: allDone ? Colors.green.withOpacity(0.06) : (isMe ? Colors.orange.withOpacity(0.04) : Colors.grey.withOpacity(0.04)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone ? Colors.green.withOpacity(0.3) : (isMe ? Colors.orange.withOpacity(0.2) : Colors.grey.shade300),
          width: allDone ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: allDone ? Colors.green.withOpacity(0.1) : (isMe ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isMe ? Icons.person : Icons.people,
                  color: allDone ? Colors.green : (isMe ? Colors.orange : Colors.grey),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: allDone ? Colors.green.shade700 : Colors.black87),
                ),
              ),
              if (allDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Colors.white, size: 14),
                      SizedBox(width: 2),
                      Text('Готово', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTapShipped,
                  child: _buildStepBox(
                    icon: Icons.local_shipping,
                    label: 'Передал',
                    isDone: shipped,
                    isClickable: onTapShipped != null,
                    color: Colors.green,
                    theme: theme,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onTapReceived,
                  child: _buildStepBox(
                    icon: Icons.inbox_rounded,
                    label: 'Получил',
                    isDone: received,
                    isClickable: onTapReceived != null,
                    color: Colors.blue,
                    theme: theme,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepBox({
    required IconData icon,
    required String label,
    required bool isDone,
    required bool isClickable,
    required Color color,
    required ThemeData theme,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDone ? color.withOpacity(0.1) : (isClickable ? color.withOpacity(0.05) : Colors.grey.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? color.withOpacity(0.3) : (isClickable ? color.withOpacity(0.4) : Colors.grey.shade300),
          width: isClickable ? 2 : 1,
        ),
        boxShadow: isClickable
            ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        children: [
          if (isDone)
            Icon(Icons.check_circle, color: color, size: 24)
          else if (isClickable)
            Icon(icon, color: color, size: 24)
          else
            Icon(Icons.hourglass_empty, color: Colors.grey.shade400, size: 24),
          const SizedBox(height: 4),
          Text(
            isDone ? '✓ $label' : label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDone ? color : (isClickable ? color : Colors.grey.shade500),
            ),
          ),
          if (isClickable && !isDone) ...[            const SizedBox(height: 2),
            Text(
              'Нажми',
              style: TextStyle(fontSize: 9, color: color.withOpacity(0.7)),
            ),
          ],
        ],
      ),
    );
  }

  // ====================================================================
  // ОТМЕНА СДЕЛКИ
  // ====================================================================
  void _showCancelDialog(TradeOffer offer, TradesProvider provider) {
    String selectedReason = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 48),
          title: const Text('Отмена сделки'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Укажите причину отмены:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              _cancelReasonOption(
                title: 'Подозрение на мошенника',
                icon: Icons.security_rounded,
                isSelected: selectedReason == 'Подозрение на мошенника',
                onTap: () => setDialogState(() => selectedReason = 'Подозрение на мошенника'),
              ),
              const SizedBox(height: 8),
              _cancelReasonOption(
                title: 'Скандальный пользователь',
                icon: Icons.report_rounded,
                isSelected: selectedReason == 'Скандальный пользователь',
                onTap: () => setDialogState(() => selectedReason = 'Скандальный пользователь'),
              ),
              const SizedBox(height: 8),
              _cancelReasonOption(
                title: 'Товар не соответствует',
                icon: Icons.broken_image_rounded,
                isSelected: selectedReason == 'Товар не соответствует',
                onTap: () => setDialogState(() => selectedReason = 'Товар не соответствует'),
              ),
              const SizedBox(height: 8),
              _cancelReasonOption(
                title: 'Передумал',
                icon: Icons.psychology_rounded,
                isSelected: selectedReason == 'Передумал',
                onTap: () => setDialogState(() => selectedReason = 'Передумал'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: selectedReason.isEmpty ? null : () { Navigator.pop(ctx); provider.cancelOffer(offer.id, reason: selectedReason); },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Отменить сделку'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cancelReasonOption({required String title, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: isSelected ? Colors.red : Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: isSelected ? Colors.red.shade700 : Colors.black87))),
          if (isSelected) Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.check, color: Colors.white, size: 14)),
        ]),
      ),
    );
  }

  Widget _buildCancelButton(TradeOffer offer, TradesProvider provider, ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showCancelDialog(offer, provider),
        icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
        label: const Text('Отменить сделку', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 1.5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  // ====================================================================
  // РЕЗУЛЬТАТЫ
  // ====================================================================
  Widget _buildCompletedResultCard(TradeOffer offer, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
      child: Column(children: [
        Icon(Icons.verified, color: Colors.green.shade600, size: 52),
        const SizedBox(height: 12),
        const Text('Обмен успешно завершён!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
        const Divider(height: 28),
        _resultRow(Icons.person, _isFromUser ? 'Ты получил' : 'Партнёр получил', _isFromUser ? offer.toItemTitle : offer.fromItemTitle, theme),
        const SizedBox(height: 10),
        _resultRow(Icons.person_outline, _isFromUser ? 'Ты отдал' : 'Партнёр отдал', _isFromUser ? offer.fromItemTitle : offer.toItemTitle, theme),
        if (offer.svDifference != 0) ...[const Divider(height: 20), _resultRow(Icons.auto_awesome, 'Доплата', '${offer.svDifference.abs()} SV', theme, highlight: true)],
      ]),
    );
  }

  Widget _buildCancelledResultCard(TradeOffer offer, ThemeData theme) {
    final reasonIcon = _getCancelReasonIcon(offer.cancelReason);
    final reasonColor = _getCancelReasonColor(offer.cancelReason);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
      child: Column(children: [
        Icon(Icons.cancel_rounded, color: Colors.red.shade400, size: 52),
        const SizedBox(height: 12),
        const Text('Сделка отменена', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red)),
        const SizedBox(height: 4),
        Text('SV возвращены, вещи остались у владельцев', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        if (offer.cancelReason.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: reasonColor.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: reasonColor.withOpacity(0.2))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: reasonColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(reasonIcon, color: reasonColor, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Причина отмены', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                const SizedBox(height: 2),
                Text(offer.cancelReason, style: TextStyle(color: reasonColor, fontWeight: FontWeight.w600, fontSize: 14)),
              ])),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _resultRow(IconData icon, String label, String value, ThemeData theme, {bool highlight = false}) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: highlight ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: highlight ? Colors.amber.shade700 : Colors.grey.shade500)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      const Spacer(),
      Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: highlight ? Colors.amber.shade800 : Colors.black87)),
    ]);
  }

  // ====================================================================
  // ЧАТ
  // ====================================================================
  Widget _buildChatSection(TradeOffer offer) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(height: 420, child: ChatWidget(offerId: offer.id))),
    );
  }

  // ====================================================================
  // ХЕЛПЕРЫ
  // ====================================================================
  IconData _getCancelReasonIcon(String reason) {
    switch (reason) {
      case 'Подозрение на мошенника': return Icons.security_rounded;
      case 'Скандальный пользователь': return Icons.report_rounded;
      case 'Товар не соответствует': return Icons.broken_image_rounded;
      case 'Передумал': return Icons.psychology_rounded;
      default: return Icons.info_outline;
    }
  }

  Color _getCancelReasonColor(String reason) {
    switch (reason) {
      case 'Подозрение на мошенника': return Colors.red;
      case 'Скандальный пользователь': return Colors.orange;
      case 'Товар не соответствует': return Colors.amber.shade700;
      case 'Передумал': return Colors.grey;
      default: return Colors.grey;
    }
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

  String _getStatusDescription(String status) {
    switch (status) {
      case 'accepted': return 'Выберите способ передачи';
      case 'shipped': return 'Ожидается получение';
      case 'completed': return 'Обмен успешно завершён';
      case 'rejected': return 'Предложение отклонено';
      case 'cancelled': return 'Сделка отменена';
      default: return 'Ожидание ответа';
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