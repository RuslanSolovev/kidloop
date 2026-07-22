// features/feed/presentation/trade_discussion_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

import '../../../core/trades_provider.dart';
import '../../../core/trade_offer.dart';
import '../../../services/notification_service.dart';
import 'chat_widget.dart';

class TradeDiscussionScreen extends StatefulWidget {
  final TradeOffer offer;

  const TradeDiscussionScreen({super.key, required this.offer});

  @override
  State<TradeDiscussionScreen> createState() => _TradeDiscussionScreenState();
}

class _TradeDiscussionScreenState extends State<TradeDiscussionScreen> {
  String? _currentUserId;
  String? _currentUserName;
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
  String _fromOwnerName = '';
  String _toOwnerName = '';
  String _fromOwnerId = '';
  String _toOwnerId = '';
  bool _isLoadingDetails = true;

  static final Map<String, String> _imageCache = {};
  static final Map<String, String> _nameCache = {};
  Set<String> _pendingSteps = {};

  static const String itemsApiUrl = 'https://functions.yandexcloud.net/d4ei9an1aushareidmjc';
  static const String usersApiUrl = 'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadItemDetails();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_id');
      _currentUserName = prefs.getString('user_name') ?? 'Вы';
    });
  }

  Future<String> _getUserName(String userId) async {
    if (userId.isEmpty) return 'Пользователь';
    if (_nameCache.containsKey(userId)) return _nameCache[userId]!;

    try {
      final response = await http.post(
        Uri.parse(usersApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "list",
          "query": "",
          "user_id": "",
          "offset": 0,
          "limit": 100,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final users = data['users'] as List? ?? [];
        for (final user in users) {
          final uid = user['user_id']?.toString() ?? '';
          final name = user['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            _nameCache[uid] = name;
          }
        }
      }

      if (!_nameCache.containsKey(userId)) {
        final profileRes = await http.post(
          Uri.parse(usersApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"action": "get", "user_id": userId}),
        ).timeout(const Duration(seconds: 5));

        final profileData = jsonDecode(profileRes.body);
        if (profileData['ok'] == true && profileData['profile'] != null) {
          final name = profileData['profile']['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            _nameCache[userId] = name;
          }
        }
      }
    } catch (_) {}

    return _nameCache[userId] ?? 'Пользователь';
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

      final response = await http.post(
        Uri.parse(itemsApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list", "limit": 100}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        bool foundFrom = false;
        bool foundTo = false;

        for (final item in data['items']) {
          final itemId = item['item_id']?.toString() ?? '';
          final ownerId = item['user_id']?.toString() ?? '';

          if (itemId == widget.offer.fromItemId) {
            foundFrom = true;
            final img = (item['image_paths'] is List && (item['image_paths'] as List).isNotEmpty)
                ? (item['image_paths'] as List).first.toString()
                : (item['image_path']?.toString() ?? '');
            final sv = int.tryParse(item['sv']?.toString() ?? '0') ?? 0;
            _fromOwnerId = ownerId;
            final ownerName = await _getUserName(ownerId);
            if (mounted) {
              setState(() {
                _fromImageUrl = img;
                _fromSv = sv;
                _fromDescription = item['description']?.toString() ?? '';
                _fromCondition = item['condition']?.toString() ?? '';
                _fromCategory = item['category']?.toString() ?? '';
                _fromOwnerName = ownerName;
              });
            }
            _imageCache['${cacheKey}_from'] = img;
          }

          if (itemId == widget.offer.toItemId) {
            foundTo = true;
            final img = (item['image_paths'] is List && (item['image_paths'] as List).isNotEmpty)
                ? (item['image_paths'] as List).first.toString()
                : (item['image_path']?.toString() ?? '');
            final sv = int.tryParse(item['sv']?.toString() ?? '0') ?? 0;
            _toOwnerId = ownerId;
            final ownerName = await _getUserName(ownerId);
            if (mounted) {
              setState(() {
                _toImageUrl = img;
                _toSv = sv;
                _toDescription = item['description']?.toString() ?? '';
                _toCondition = item['condition']?.toString() ?? '';
                _toCategory = item['category']?.toString() ?? '';
                _toOwnerName = ownerName;
              });
            }
            _imageCache['${cacheKey}_to'] = img;
          }

          if (foundFrom && foundTo) break;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingDetails = false);
  }

  bool get _isFromUser => widget.offer.fromUserId == _currentUserId;
  bool get _isToUser => widget.offer.toUserId == _currentUserId;

  String get _fromDisplayName {
    if (_isFromUser) return 'Вы';
    if (_fromOwnerName.isNotEmpty) return _fromOwnerName;
    return 'Пользователь';
  }

  String get _toDisplayName {
    if (_isToUser) return 'Вы';
    if (_toOwnerName.isNotEmpty) return _toOwnerName;
    return 'Пользователь';
  }

  String get _payerName {
    if (widget.offer.svDifference == 0) return '';
    if (widget.offer.svDifference > 0) return _fromDisplayName;
    return _toDisplayName;
  }

  @override
  Widget build(BuildContext context) {
    final offers = context.watch<TradesProvider>().offers;
    final offer = offers.firstWhere((o) => o.id == widget.offer.id, orElse: () => widget.offer);
    final provider = context.read<TradesProvider>();

    final methodsMatch = offer.fromDeliveryMethod.isNotEmpty &&
        offer.toDeliveryMethod.isNotEmpty &&
        offer.fromDeliveryMethod == offer.toDeliveryMethod;

    final isActive = offer.status != 'cancelled' && offer.status != 'completed' && offer.status != 'rejected';

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8, top: 8),
          child: Container(
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorderColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: _isDarkMode ? 0.15 : 0.08), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: _textColor, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text('Детали обмена', style: TextStyle(color: _textColor, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
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
                _buildStatusBanner(offer),
                const SizedBox(height: 24),
                _buildExchangeCards(offer),
                const SizedBox(height: 20),
                _buildSVDifferenceCard(offer),
                const SizedBox(height: 24),
                _buildSectionTitle('📋 Детали сделки'),
                const SizedBox(height: 12),
                _buildDetailCard(offer),
                const SizedBox(height: 24),
                if (isActive) ...[
                  _buildSectionTitle('🚚 Способ передачи'),
                  const SizedBox(height: 12),
                  _buildDeliveryMethods(offer, provider),
                  const SizedBox(height: 12),
                  _buildDeliveryChoices(offer),
                  if (offer.fromDeliveryMethod.isNotEmpty && offer.toDeliveryMethod.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildMatchIndicator(methodsMatch),
                  ],
                  const SizedBox(height: 24),
                  if (methodsMatch) ...[
                    _buildSectionTitle('✅ Подтверждение обмена'),
                    const SizedBox(height: 12),
                    _buildConfirmationPanel(offer, provider),
                  ] else if (offer.fromDeliveryMethod.isNotEmpty && offer.toDeliveryMethod.isNotEmpty)
                    _buildMismatchWarning(),
                  const SizedBox(height: 20),
                  _buildCancelButton(offer, provider),
                ],
                if (offer.status == 'completed') ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('🏆 Итоги сделки'),
                  const SizedBox(height: 12),
                  _buildCompletedResultCard(offer),
                ],
                if (offer.status == 'cancelled') ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('💔 Итоги отмены'),
                  const SizedBox(height: 12),
                  _buildCancelledResultCard(offer),
                ],
                const SizedBox(height: 24),
                _buildSectionTitle('💬 Обсуждение'),
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
  Widget _buildStatusBanner(TradeOffer offer) {
    final statusColor = _getStatusColor(offer.status);
    final statusIcon = _getStatusIcon(offer.status);
    final statusText = _getStatusText(offer.status);
    final statusDescription = _getStatusDescription(offer.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [statusColor.withValues(alpha: 0.12), statusColor.withValues(alpha: 0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 2),
              Text(statusDescription, style: TextStyle(color: statusColor.withValues(alpha: 0.7), fontSize: 13)),
            ]),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // КАРТОЧКИ ОБМЕНА
  // ====================================================================
  Widget _buildExchangeCards(TradeOffer offer) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _buildItemCard(
        ownerName: _fromDisplayName,
        isHighlighted: _isFromUser,
        title: offer.fromItemTitle,
        sv: _fromSv,
        imageUrl: _fromImageUrl,
        category: _fromCategory,
        condition: _fromCondition,
      )),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 40),
        child: Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
            borderRadius: BorderRadius.all(Radius.circular(14)),
            boxShadow: [BoxShadow(color: Color(0x59FF9800), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 24),
        ),
      ),
      Expanded(child: _buildItemCard(
        ownerName: _toDisplayName,
        isHighlighted: _isToUser,
        title: offer.toItemTitle,
        sv: _toSv,
        imageUrl: _toImageUrl,
        category: _toCategory,
        condition: _toCondition,
      )),
    ]);
  }

  Widget _buildItemCard({
    required String ownerName,
    required bool isHighlighted,
    required String title,
    required int sv,
    String? imageUrl,
    String category = '',
    String condition = '',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isHighlighted
            ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))]
            : [BoxShadow(color: Colors.black.withValues(alpha: _isDarkMode ? 0.15 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        border: isHighlighted ? Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 2) : Border.all(color: _cardBorderColor),
      ),
      child: Column(children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(
            height: 130, width: double.infinity,
            child: imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')
                ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (_, __) => Container(color: _isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))), errorWidget: (_, __, ___) => Container(color: _isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100, child: Icon(Icons.toys, size: 40, color: Colors.grey.shade300)))
                : Container(color: _isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100, child: Icon(Icons.toys, size: 40, color: Colors.grey.shade300)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(ownerName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
            ),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            if (category.isNotEmpty || condition.isNotEmpty)
              Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.center, children: [
                if (category.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(category, style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600))),
                if (condition.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(condition, style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600))),
              ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]), borderRadius: BorderRadius.all(Radius.circular(14)), boxShadow: [BoxShadow(color: Color(0x4DFF9800), blurRadius: 6, offset: Offset(0, 2))]),
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
  Widget _buildSVDifferenceCard(TradeOffer offer) {
    final hasDifference = offer.svDifference != 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: hasDifference ? [Colors.amber.shade300, Colors.orange.shade400] : [Colors.green.shade300, Colors.teal.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: (hasDifference ? Colors.orange : Colors.green).withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
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
  Widget _buildSectionTitle(String title) {
    return Row(children: [
      Container(width: 4, height: 22, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 12),
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _textColor)),
    ]);
  }

  // ====================================================================
  // ДЕТАЛИ СДЕЛКИ
  // ====================================================================
  Widget _buildDetailCard(TradeOffer offer) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDarkMode ? 0.15 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('Сделка №${offer.id.substring(0, 8).toUpperCase()}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 20),
        _buildDetailSection('👥 Участники обмена', [
          _buildParticipantRow(_fromDisplayName, offer.fromItemTitle, _fromSv, isCurrentUser: _isFromUser),
          const SizedBox(height: 8),
          const Center(child: Icon(Icons.swap_vert_rounded, color: Colors.orange, size: 28)),
          const SizedBox(height: 8),
          _buildParticipantRow(_toDisplayName, offer.toItemTitle, _toSv, isCurrentUser: _isToUser),
        ]),
        const SizedBox(height: 16),
        _buildDetailSection('💰 Стоимость товаров', [
          _buildPriceRow(offer.fromItemTitle, _fromSv, _fromDisplayName),
          const SizedBox(height: 8),
          _buildPriceRow(offer.toItemTitle, _toSv, _toDisplayName),
        ]),
        if (offer.svDifference != 0) ...[
          const SizedBox(height: 16),
          _buildDetailSection('💳 Доплата', [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.amber.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.payment_rounded, color: Colors.amber, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text('Доплачивает: $_payerName — ${offer.svDifference.abs()} SV', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: _textColor))),
              ]),
            ),
          ]),
        ],
        if (offer.deliveryMethod.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDetailSection('🚚 Способ передачи', [
            _buildInfoRow(Icons.local_shipping_rounded, _methodName(offer.deliveryMethod)),
          ]),
        ],
      ]),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
      const SizedBox(height: 10),
      ...children,
    ]);
  }

  Widget _buildParticipantRow(String name, String itemTitle, int sv, {required bool isCurrentUser}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.orange.withValues(alpha: 0.08) : (_isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrentUser ? Colors.orange.withValues(alpha: 0.2) : _cardBorderColor),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isCurrentUser ? Colors.orange.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.person_rounded, color: isCurrentUser ? Colors.orange : _subTextColor, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textColor)),
          const SizedBox(height: 2),
          Text(itemTitle, style: TextStyle(fontSize: 12, color: _subTextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text('$sv SV', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13))),
      ]),
    );
  }

  Widget _buildPriceRow(String itemTitle, int sv, String ownerName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _isDarkMode ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorderColor)),
      child: Row(children: [
        Icon(Icons.auto_awesome, size: 18, color: Colors.orange.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(child: Text(itemTitle, style: TextStyle(fontSize: 13, color: _subTextColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text('($ownerName)', style: TextStyle(fontSize: 11, color: _subTextColor.withValues(alpha: 0.7))),
        const SizedBox(width: 8),
        Text('$sv SV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textColor)),
      ]),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _isDarkMode ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorderColor)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: Colors.orange)),
        const SizedBox(width: 10),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textColor)),
      ]),
    );
  }

  // ====================================================================
  // СПОСОБ ПЕРЕДАЧИ
  // ====================================================================
  Widget _buildDeliveryMethods(TradeOffer offer, TradesProvider provider) {
    final currentMethod = _isFromUser ? offer.fromDeliveryMethod : offer.toDeliveryMethod;
    return Row(children: [
      Expanded(child: _deliveryOptionCard(icon: Icons.people_rounded, title: 'Личная встреча', subtitle: 'Встретиться лично', value: 'meetup', isSelected: currentMethod == 'meetup', onTap: currentMethod == 'meetup' ? null : () => provider.updateDeliveryMethod(offer.id, 'meetup'))),
      const SizedBox(width: 12),
      Expanded(child: _deliveryOptionCard(icon: Icons.local_shipping_rounded, title: 'Доставка', subtitle: 'Отправить почтой', value: 'delivery', isSelected: currentMethod == 'delivery', onTap: currentMethod == 'delivery' ? null : () => provider.updateDeliveryMethod(offer.id, 'delivery'))),
    ]);
  }

  Widget _deliveryOptionCard({required IconData icon, required String title, required String subtitle, required String value, required bool isSelected, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withValues(alpha: 0.06) : _surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? Colors.orange : _cardBorderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withValues(alpha: _isDarkMode ? 0.1 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: isSelected ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 26, color: isSelected ? Colors.orange : Colors.grey.shade400)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isSelected ? Colors.orange : _textColor)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: isSelected ? Colors.orange.withValues(alpha: 0.7) : _subTextColor)),
          if (isSelected) ...[const SizedBox(height: 6), Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.check, color: Colors.white, size: 14))],
        ]),
      ),
    );
  }

  Widget _buildDeliveryChoices(TradeOffer offer) {
    return Row(children: [
      Expanded(child: _choiceChip(_fromDisplayName, offer.fromDeliveryMethod)),
      const SizedBox(width: 10),
      Expanded(child: _choiceChip(_toDisplayName, offer.toDeliveryMethod)),
    ]);
  }

  Widget _choiceChip(String who, String method) {
    final chosen = method.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: chosen ? Colors.green.withValues(alpha: 0.06) : _surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: chosen ? Colors.green.withValues(alpha: 0.3) : _cardBorderColor)),
      child: Row(children: [
        Icon(Icons.person_rounded, size: 18, color: chosen ? Colors.green : Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(child: Text(chosen ? '$who: ${_methodName(method)}' : '$who: ожидание...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: chosen ? _textColor : _subTextColor))),
        if (chosen) Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
      ]),
    );
  }

  Widget _buildMatchIndicator(bool methodsMatch) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: methodsMatch ? Colors.green.withValues(alpha: 0.06) : Colors.red.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: methodsMatch ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(methodsMatch ? Icons.check_circle : Icons.warning_rounded, color: methodsMatch ? Colors.green : Colors.red, size: 22),
        const SizedBox(width: 8),
        Text(methodsMatch ? 'Способы совпадают! Можно подтверждать' : 'Способы не совпадают', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: methodsMatch ? Colors.green.shade700 : Colors.red.shade700)),
      ]),
    );
  }

  Widget _buildMismatchWarning() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
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
  Widget _buildConfirmationPanel(TradeOffer offer, TradesProvider provider) {
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
      final isShipped = step.contains('shipped');
      final action = isShipped ? 'отправили' : 'получили';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(isShipped ? Icons.local_shipping : Icons.inbox_rounded, color: isShipped ? Colors.green : Colors.blue, size: 48),
          title: Text(isShipped ? 'Подтверждение отправки' : 'Подтверждение получения', style: TextStyle(color: _textColor)),
          content: Text('Вы точно $action вещь?', textAlign: TextAlign.center, style: TextStyle(color: _subTextColor)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
            Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]), borderRadius: BorderRadius.all(Radius.circular(12))),
              child: TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да, подтверждаю', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() => _pendingSteps.add(step));
        await provider.confirmStep(offer.id, step);
        setState(() => _pendingSteps.remove(step));

        // 🔥 Если все шаги выполнены — отправляем уведомление
        final updatedOffer = context.read<TradesProvider>().offers.firstWhere((o) => o.id == offer.id, orElse: () => offer);
        final fShipped = updatedOffer.fromShipped;
        final fReceived = updatedOffer.fromReceived;
        final tShipped = updatedOffer.toShipped;
        final tReceived = updatedOffer.toReceived;
        final allDoneNow = fShipped && fReceived && tShipped && tReceived;

        if (allDoneNow) {
          final opponentId = _isFromUser ? widget.offer.toUserId : widget.offer.fromUserId;
          NotificationService.sendNotification(
            targetUserId: opponentId,
            type: 'trade_completed',
            data: {
              'trade_id': widget.offer.id,
              'user_name': _currentUserName ?? 'Пользователь',
            },
          );
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorderColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDarkMode ? 0.1 : 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(allDone ? Icons.celebration : Icons.swap_horiz_rounded, color: allDone ? Colors.green : Colors.orange, size: 22),
          const SizedBox(width: 8),
          Text(allDone ? '🎉 Обмен завершён!' : 'Прогресс обмена', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: allDone ? Colors.green : _textColor)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: completed / 4, minHeight: 8, backgroundColor: _isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(allDone ? Colors.green : Colors.orange))),
        const SizedBox(height: 6),
        Text('$completed/4 шагов выполнено', style: TextStyle(color: _subTextColor, fontSize: 12)),
        const SizedBox(height: 20),
        _buildUserConfirmationBlock(label: _fromDisplayName, shipped: myShipped, received: myReceived, isMe: true,
          onTapShipped: _isFromUser ? (!fromShipped ? () => handleConfirm('from_shipped') : null) : (!toShipped ? () => handleConfirm('to_shipped') : null),
          onTapReceived: _isFromUser ? (!fromReceived ? () => handleConfirm('from_received') : null) : (!toReceived ? () => handleConfirm('to_received') : null),
        ),
        const SizedBox(height: 14),
        _buildUserConfirmationBlock(label: _isFromUser ? _toDisplayName : _fromDisplayName, shipped: partnerShipped, received: partnerReceived, isMe: false, onTapShipped: null, onTapReceived: null),
      ]),
    );
  }

  Widget _buildUserConfirmationBlock({required String label, required bool shipped, required bool received, required bool isMe, VoidCallback? onTapShipped, VoidCallback? onTapReceived}) {
    final allDone = shipped && received;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: allDone ? Colors.green.withValues(alpha: 0.06) : (isMe ? Colors.orange.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: allDone ? Colors.green.withValues(alpha: 0.3) : (isMe ? Colors.orange.withValues(alpha: 0.2) : _cardBorderColor), width: allDone ? 2 : 1),
      ),
      child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: allDone ? Colors.green.withValues(alpha: 0.1) : (isMe ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(8)),
              child: Icon(isMe ? Icons.person : Icons.people, color: allDone ? Colors.green : (isMe ? Colors.orange : Colors.grey), size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: allDone ? Colors.green.shade700 : _textColor))),
          if (allDone) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check, color: Colors.white, size: 14), SizedBox(width: 2), Text('Готово', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GestureDetector(onTap: onTapShipped, child: _buildStepBox(icon: Icons.local_shipping, label: 'Передал', isDone: shipped, isClickable: onTapShipped != null, color: Colors.green))),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(onTap: onTapReceived, child: _buildStepBox(icon: Icons.inbox_rounded, label: 'Получил', isDone: received, isClickable: onTapReceived != null, color: Colors.blue))),
        ]),
      ]),
    );
  }

  Widget _buildStepBox({required IconData icon, required String label, required bool isDone, required bool isClickable, required Color color}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDone ? color.withValues(alpha: 0.1) : (isClickable ? color.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDone ? color.withValues(alpha: 0.3) : (isClickable ? color.withValues(alpha: 0.4) : _cardBorderColor), width: isClickable ? 2 : 1),
        boxShadow: isClickable ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))] : null,
      ),
      child: Column(children: [
        if (isDone) Icon(Icons.check_circle, color: color, size: 24) else if (isClickable) Icon(icon, color: color, size: 24) else Icon(Icons.hourglass_empty, color: Colors.grey.shade400, size: 24),
        const SizedBox(height: 4),
        Text(isDone ? '✓ $label' : label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDone ? color : (isClickable ? color : _subTextColor))),
        if (isClickable && !isDone) ...[const SizedBox(height: 2), Text('Нажми', style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)))],
      ]),
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
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 48),
          title: Text('Отмена сделки', style: TextStyle(color: _textColor)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Укажите причину отмены:', style: TextStyle(fontSize: 14, color: _subTextColor)),
            const SizedBox(height: 16),
            _cancelReasonOption(title: 'Подозрение на мошенника', icon: Icons.security_rounded, isSelected: selectedReason == 'Подозрение на мошенника', onTap: () => setDialogState(() => selectedReason = 'Подозрение на мошенника')),
            const SizedBox(height: 8),
            _cancelReasonOption(title: 'Скандальный пользователь', icon: Icons.report_rounded, isSelected: selectedReason == 'Скандальный пользователь', onTap: () => setDialogState(() => selectedReason = 'Скандальный пользователь')),
            const SizedBox(height: 8),
            _cancelReasonOption(title: 'Товар не соответствует', icon: Icons.broken_image_rounded, isSelected: selectedReason == 'Товар не соответствует', onTap: () => setDialogState(() => selectedReason = 'Товар не соответствует')),
            const SizedBox(height: 8),
            _cancelReasonOption(title: 'Передумал', icon: Icons.psychology_rounded, isSelected: selectedReason == 'Передумал', onTap: () => setDialogState(() => selectedReason = 'Передумал')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: _subTextColor))),
            Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]), borderRadius: BorderRadius.all(Radius.circular(12))),
              child: TextButton(onPressed: selectedReason.isEmpty ? null : () {
                Navigator.pop(ctx);
                provider.cancelOffer(offer.id, reason: selectedReason).then((_) {
                  // 🔥 Отправляем уведомление второй стороне
                  final opponentId = _isFromUser ? widget.offer.toUserId : widget.offer.fromUserId;
                  NotificationService.sendNotification(
                    targetUserId: opponentId,
                    type: 'trade_declined',
                    data: {
                      'trade_id': widget.offer.id,
                      'user_name': _currentUserName ?? 'Пользователь',
                    },
                  );
                });
              }, child: const Text('Отменить сделку', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
        decoration: BoxDecoration(color: isSelected ? Colors.red.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? Colors.red : _cardBorderColor, width: isSelected ? 2 : 1)),
        child: Row(children: [
          Icon(icon, size: 20, color: isSelected ? Colors.red : Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: isSelected ? Colors.red.shade700 : _textColor))),
          if (isSelected) Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.check, color: Colors.white, size: 14)),
        ]),
      ),
    );
  }

  Widget _buildCancelButton(TradeOffer offer, TradesProvider provider) {
    return SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: () => _showCancelDialog(offer, provider),
      icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
      label: const Text('Отменить сделку', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 1.5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    ));
  }

  // ====================================================================
  // ИТОГИ СДЕЛКИ
  // ====================================================================
  Widget _buildCompletedResultCard(TradeOffer offer) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorderColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDarkMode ? 0.15 : 0.05), blurRadius: 12)]),
      child: Column(children: [
        const Icon(Icons.verified, color: Colors.green, size: 52),
        const SizedBox(height: 12),
        Text('Обмен успешно завершён! 🎉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
        const Divider(height: 28),
        _buildResultSection('📦 Кто что получил', [
          _buildResultRow(_fromDisplayName, 'получил(а)', offer.toItemTitle, _toSv, isCurrentUser: _isFromUser),
          const SizedBox(height: 8),
          _buildResultRow(_toDisplayName, 'получил(а)', offer.fromItemTitle, _fromSv, isCurrentUser: _isToUser),
        ]),
        if (offer.svDifference != 0) ...[
          const SizedBox(height: 16),
          _buildResultSection('💳 Доплата', [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.05)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Colors.amber, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text('Доплата ${offer.svDifference.abs()} SV от $_payerName выполнена', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _textColor))),
              ]),
            ),
          ]),
        ],
        if (offer.deliveryMethod.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildResultSection('🚚 Способ передачи', [_buildInfoRow(Icons.local_shipping_rounded, _methodName(offer.deliveryMethod))]),
        ],
      ]),
    );
  }

  Widget _buildCancelledResultCard(TradeOffer offer) {
    final reasonIcon = _getCancelReasonIcon(offer.cancelReason);
    final reasonColor = _getCancelReasonColor(offer.cancelReason);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorderColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDarkMode ? 0.15 : 0.05), blurRadius: 12)]),
      child: Column(children: [
        Icon(Icons.cancel_rounded, color: Colors.red.shade400, size: 52),
        const SizedBox(height: 12),
        const Text('Сделка отменена', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red)),
        const SizedBox(height: 4),
        Text('SV возвращены, вещи остались у владельцев', textAlign: TextAlign.center, style: TextStyle(color: _subTextColor, fontSize: 14)),
        if (offer.cancelReason.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: reasonColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: reasonColor.withValues(alpha: 0.2))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: reasonColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(reasonIcon, color: reasonColor, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Причина отмены', style: TextStyle(color: _subTextColor, fontSize: 11)),
                const SizedBox(height: 2),
                Text(offer.cancelReason, style: TextStyle(color: reasonColor, fontWeight: FontWeight.w600, fontSize: 14)),
              ])),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildResultSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
      const SizedBox(height: 10),
      ...children,
    ]);
  }

  Widget _buildResultRow(String name, String action, String itemTitle, int sv, {required bool isCurrentUser}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.orange.withValues(alpha: 0.08) : (_isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrentUser ? Colors.orange.withValues(alpha: 0.2) : _cardBorderColor),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isCurrentUser ? Colors.orange.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.person_rounded, color: isCurrentUser ? Colors.orange : _subTextColor, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(style: TextStyle(fontSize: 13, color: _textColor), children: [
            TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: ' $action '),
            TextSpan(text: itemTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(height: 2),
          Text('$sv SV', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
        ])),
      ]),
    );
  }

  // ====================================================================
  // ЧАТ
  // ====================================================================
  Widget _buildChatSection(TradeOffer offer) {
    return Container(
      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorderColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDarkMode ? 0.1 : 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
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

  String _methodName(String method) {
    switch (method) {
      case 'meetup': return 'Личная встреча';
      case 'delivery': return 'Доставка';
      default: return method;
    }
  }
}