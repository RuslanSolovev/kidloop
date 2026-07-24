import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../core/items_provider.dart';
import '../../../core/item_model.dart';
import '../../../core/trades_provider.dart';
import '../../../core/trade_offer.dart';
import '../../../core/bundle_provider.dart';
import '../../../core/bundle_model.dart';

class SelectItemToTradeScreen extends StatefulWidget {
  final Item wantedItem;
  final Bundle? wantedBundle; // 🔥 Добавлено для обмена набор-на-набор

  const SelectItemToTradeScreen({
    super.key,
    required this.wantedItem,
    this.wantedBundle,
  });

  @override
  State<SelectItemToTradeScreen> createState() =>
      _SelectItemToTradeScreenState();
}

class _SelectItemToTradeScreenState extends State<SelectItemToTradeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BundleProvider>().loadMyBundles();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor =>
      _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _surfaceColor =>
      _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _backgroundColor =>
      _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

  // 🔥 Удобные геттеры
  bool get _isWantedBundle => widget.wantedBundle != null;
  String get _wantedTitle =>
      _isWantedBundle ? '📦 ${widget.wantedBundle!.title}' : widget.wantedItem.title;
  int get _wantedSv =>
      _isWantedBundle ? widget.wantedBundle!.totalSv : widget.wantedItem.sv;
  String get _wantedOwnerId =>
      _isWantedBundle ? widget.wantedBundle!.userId : widget.wantedItem.ownerId;
  String get _wantedItemId =>
      _isWantedBundle ? '' : widget.wantedItem.itemId;
  String get _wantedBundleId =>
      _isWantedBundle ? widget.wantedBundle!.bundleId : '';
  String get _wantedItemsJson =>
      _isWantedBundle ? jsonEncode(widget.wantedBundle!.items.map((e) => e.toJson()).toList()) : '';

  Future<int> _getBalance(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4e4du0dtej5k7md0cc5'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-balance", "user_id": userId}),
      ).timeout(const Duration(seconds: 5));
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return data['balance'] ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  // ==================== ОДИНОЧНЫЙ ОБМЕН (Вещь/Набор → Одиночная вещь) ====================
  Future<void> _sendSingleOffer(Item myItem) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('user_id') ?? '';
      final diff = _wantedSv - myItem.sv;

      debugPrint('=== SEND SINGLE OFFER ===');
      debugPrint('Item: ${myItem.title}');
      debugPrint('Diff: $diff');

      if (!_isWantedBundle && (widget.wantedItem.status == 'reserved' ||
          widget.wantedItem.status == 'swapped')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Эта вещь уже участвует в активной сделке'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (diff > 0) {
        final balance = await _getBalance(currentUserId);
        if (balance < diff) {
          if (mounted) _showInsufficientBalanceDialog(diff, balance);
          return;
        }
      }

      final confirm = await _showConfirmDialog(
        myItem.title,
        myItem.sv,
        _wantedTitle,
        _wantedSv,
        diff,
      );

      if (confirm != true) return;

      final offer = TradeOffer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fromUserId: currentUserId,
        toUserId: _wantedOwnerId,
        fromItemId: myItem.itemId,
        toItemId: _wantedItemId,
        fromItemTitle: myItem.title,
        toItemTitle: _wantedTitle,
        svDifference: diff,
        toBundleId: _isWantedBundle ? _wantedBundleId : null,
        toBundleItems: _isWantedBundle ? widget.wantedBundle!.items : null,
        toItemsJson: _isWantedBundle ? _wantedItemsJson : null,
      );

      await _executeOffer(offer);
    } catch (e, stack) {
      debugPrint('ERROR in _sendSingleOffer: $e');
      debugPrint('Stack: $stack');
    }
  }

  // ==================== BUNDLE ОБМЕН (Набор → Одиночная вещь / Набор → Набор) ====================
  Future<void> _sendBundleOffer(Bundle myBundle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('user_id') ?? '';
      final diff = _wantedSv - myBundle.totalSv;

      debugPrint('=== SEND BUNDLE OFFER ===');
      debugPrint('Bundle: ${myBundle.title}');
      debugPrint('Bundle ID: ${myBundle.bundleId}');
      debugPrint('Wanted is bundle: $_isWantedBundle');
      debugPrint('Diff: $diff');

      if (diff > 0) {
        final balance = await _getBalance(currentUserId);
        if (balance < diff) {
          if (mounted) _showInsufficientBalanceDialog(diff, balance);
          return;
        }
      }

      final confirm = await _showConfirmDialog(
        '📦 ${myBundle.title}',
        myBundle.totalSv,
        _wantedTitle,
        _wantedSv,
        diff,
      );

      if (confirm != true) return;

      final itemsJson = jsonEncode(myBundle.items.map((e) => e.toJson()).toList());

      final offer = TradeOffer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fromUserId: currentUserId,
        toUserId: _wantedOwnerId,
        fromItemId: '',
        toItemId: _wantedItemId,
        fromItemTitle: '📦 ${myBundle.title}',
        toItemTitle: _wantedTitle,
        svDifference: diff,
        fromBundleId: myBundle.bundleId,
        fromBundleItems: myBundle.items,
        fromItemsJson: itemsJson,
        // 🔥 Для обмена набор-на-набор
        toBundleId: _isWantedBundle ? _wantedBundleId : null,
        toBundleItems: _isWantedBundle ? widget.wantedBundle!.items : null,
        toItemsJson: _isWantedBundle ? _wantedItemsJson : null,
      );

      debugPrint('Offer created, calling _executeOffer...');
      await _executeOffer(offer);
    } catch (e, stack) {
      debugPrint('ERROR in _sendBundleOffer: $e');
      debugPrint('Stack: $stack');
    }
  }

  // ==================== ВЫПОЛНЕНИЕ ОБМЕНА ====================
  Future<void> _executeOffer(TradeOffer offer) async {
    try {
      debugPrint('=== EXECUTE OFFER ===');
      debugPrint('fromUserId: ${offer.fromUserId}');
      debugPrint('toUserId: ${offer.toUserId}');
      debugPrint('fromItemId: "${offer.fromItemId}"');
      debugPrint('toItemId: ${offer.toItemId}');
      debugPrint('fromBundleId: ${offer.fromBundleId}');
      debugPrint('toBundleId: ${offer.toBundleId}');

      final result = await context.read<TradesProvider>().createOffer(offer);
      debugPrint('Result: $result');

      if (mounted) {
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
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.green.shade700,
            ),
          );
        } else {
          final error = result['error'] ?? '';
          String errorMessage = 'Не удалось отправить предложение.';
          if (error == 'insufficient_balance') {
            errorMessage = 'Недостаточно SV для отправки предложения.';
          } else if (error == 'item_reserved') {
            errorMessage = 'Эта вещь уже участвует в активной сделке.';
          } else if (error == 'bundle_item_reserved') {
            errorMessage = 'Одна из вещей в наборе уже участвует в сделке.';
          }
          _showErrorDialog(error, errorMessage);
        }
      }
    } catch (e, stack) {
      debugPrint('ERROR in _executeOffer: $e');
      debugPrint('Stack: $stack');
    }
  }

  void _showErrorDialog(String error, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          error == 'item_reserved' || error == 'bundle_item_reserved'
              ? Icons.block
              : Icons.error_outline,
          color: Colors.orange,
          size: 48,
        ),
        title: Text('Ошибка', style: TextStyle(color: _textColor)),
        content: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _subTextColor)),
        actions: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ДИАЛОГИ ====================
  void _showInsufficientBalanceDialog(int diff, int balance) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text('⚠️ Недостаточно SV', style: TextStyle(color: _textColor)),
          ],
        ),
        content: Text(
          'Для этого обмена нужно $diff SV.\nУ тебя на балансе: $balance SV.',
          style: TextStyle(height: 1.5, color: _subTextColor),
        ),
        actions: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Понятно',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(
      String fromTitle,
      int fromSv,
      String toTitle,
      int toSv,
      int diff,
      ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text('Подтверждение обмена',
                style: TextStyle(color: _textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _offerItemTile(
              icon: Icons.card_giftcard,
              label: 'Ты получишь',
              title: toTitle,
              sv: toSv,
              color: Colors.green,
            ),
            const Divider(height: 24),
            _offerItemTile(
              icon: Icons.upload_file,
              label: 'Ты отдаёшь',
              title: fromTitle,
              sv: fromSv,
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
            label: Text('Отмена', style: TextStyle(color: _subTextColor)),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('Отправить',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ВИДЖЕТЫ ====================
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
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: _isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: _textColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$sv SV',
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
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
        style: TextStyle(
            fontWeight: FontWeight.bold, color: color, fontSize: 16),
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final myItems = context
        .watch<ItemsProvider>()
        .items
        .where((e) => e.isMine && e.status != 'in_bundle')
        .toList();
    final myBundles = context.watch<BundleProvider>().myBundles;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Выбери, что предложить',
            style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: _subTextColor,
          indicatorColor: Colors.orange,
          tabs: [
            Tab(text: 'Мои вещи (${myItems.length})'),
            Tab(text: 'Мои наборы (${myBundles.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Карточка желаемого (вещь или набор)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.15),
                  Colors.deepOrange.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'wanted_${_wantedItemId}${_wantedBundleId}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: Colors.orange.withOpacity(0.1),
                      child: Icon(
                        _isWantedBundle ? Icons.inventory_2 : Icons.card_giftcard,
                        color: Colors.orange,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ты хочешь получить',
                          style:
                          TextStyle(fontSize: 13, color: Colors.orange)),
                      const SizedBox(height: 4),
                      Text(_wantedTitle,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _textColor)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$_wantedSv SV',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Вкладки
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildItemsTab(myItems),
                _buildBundlesTab(myBundles),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab(List<Item> myItems) {
    if (myItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_outlined,
                    size: 64,
                    color: _isDarkMode
                        ? Colors.grey.shade500
                        : Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Text(
                'У тебя нет своих вещей.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, color: _subTextColor, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: myItems.length,
      itemBuilder: (context, index) {
        final item = myItems[index];
        final diff = _wantedSv - item.sv;
        final isReserved =
            item.status == 'reserved' || item.status == 'swapped';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isReserved
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isReserved ? null : () => _sendSingleOffer(item),
            child: Opacity(
              opacity: isReserved ? 0.5 : 1.0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.imagePaths.isNotEmpty
                            ? item.imagePaths.first
                            : item.imagePath,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: _textColor)),
                          const SizedBox(height: 4),
                          Text('${item.sv} SV',
                              style: TextStyle(
                                  color: _subTextColor,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: diff > 0
                              ? [Colors.orange.shade400, Colors.red.shade400]
                              : diff < 0
                              ? [
                            Colors.green.shade400,
                            Colors.teal.shade400
                          ]
                              : [
                            Colors.grey.shade400,
                            Colors.grey.shade500
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
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
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBundlesTab(List<Bundle> myBundles) {
    if (myBundles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_outlined,
                    size: 64,
                    color: _isDarkMode
                        ? Colors.grey.shade500
                        : Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Text(
                'У тебя нет наборов.\nСоздай набор из нескольких вещей!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, color: _subTextColor, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: myBundles.length,
      itemBuilder: (context, index) {
        final bundle = myBundles[index];
        final diff = _wantedSv - bundle.totalSv;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _sendBundleOffer(bundle),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2,
                                color: Colors.orange, size: 14),
                            SizedBox(width: 4),
                            Text('НАБОР',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: diff > 0
                                ? [Colors.orange.shade400, Colors.red.shade400]
                                : diff < 0
                                ? [
                              Colors.green.shade400,
                              Colors.teal.shade400
                            ]
                                : [
                              Colors.grey.shade400,
                              Colors.grey.shade500
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
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
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(bundle.title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: _textColor)),
                  const SizedBox(height: 4),
                  Text(
                    '${bundle.items.length} предметов • ${bundle.totalSv} SV',
                    style: TextStyle(color: _subTextColor, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: bundle.items.length,
                      itemBuilder: (ctx, i) {
                        final item = bundle.items[i];
                        return Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${item.sv}',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}