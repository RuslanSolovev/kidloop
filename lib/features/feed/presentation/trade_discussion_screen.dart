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
      print("LOAD ITEM DETAILS ERROR: $e");
    }
  }

  bool get _isFromUser => widget.offer.fromUserId == _currentUserId;
  bool get _isToUser => widget.offer.toUserId == _currentUserId;

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
      appBar: AppBar(
        title: Text(_isFromUser ? 'Обмен с получателем' : 'Обмен с отправителем'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📦 ОБМЕН
            const Text('📦 ОБМЕН', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ItemCard(
                    label: _isFromUser ? 'Твоя вещь' : 'Вещь отправителя',
                    isMine: _isFromUser,
                    title: offer.fromItemTitle,
                    sv: _fromSv,
                    imageUrl: _fromImageUrl,
                    description: _isFromUser ? _toDescription : _fromDescription,
                    condition: _isFromUser ? _toCondition : _fromCondition,
                    category: _isFromUser ? _toCategory : _fromCategory,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 30),
                  child: Icon(Icons.swap_horiz, color: Colors.orange, size: 32),
                ),
                Expanded(
                  child: _ItemCard(
                    label: _isFromUser ? 'Вещь получателя' : 'Твоя вещь',
                    isMine: !_isFromUser,
                    title: offer.toItemTitle,
                    sv: _toSv,
                    imageUrl: _toImageUrl,
                    description: _isFromUser ? _fromDescription : _toDescription,
                    condition: _isFromUser ? _fromCondition : _toCondition,
                    category: _isFromUser ? _fromCategory : _toCategory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 💰 Доплата
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: offer.svDifference != 0
                      ? [Colors.amber.shade300, Colors.amber.shade500]
                      : [Colors.green.shade300, Colors.green.shade500],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: offer.svDifference > 0
                  ? Text('💰 Доплата отправителю: +${offer.svDifference} SV',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                  : offer.svDifference < 0
                  ? Text('💰 Доплата получателю: +${offer.svDifference.abs()} SV',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                  : const Text('🤝 Равный обмен',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),

            // 📋 ДЕТАЛИ СДЕЛКИ
            _sectionHeader('📋 ДЕТАЛИ СДЕЛКИ'),
            const SizedBox(height: 12),
            _statusBadge(offer.status),
            const SizedBox(height: 16),

            _detailCard(offer),

            const SizedBox(height: 16),

            // Активные действия
            if (isActive) ...[
              const Text('Способ передачи:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              _deliveryOption(provider, offer, 'meetup', '🤝 Личная встреча'),
              const SizedBox(height: 4),
              _deliveryOption(provider, offer, 'delivery', '📦 Доставка'),
              const SizedBox(height: 12),

              _choiceIndicator('Отправитель', offer.fromDeliveryMethod),
              _choiceIndicator('Получатель', offer.toDeliveryMethod),

              if (offer.fromDeliveryMethod.isNotEmpty && offer.toDeliveryMethod.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: methodsMatch ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: methodsMatch
                        ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Способы совпадают!',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16))
                    ])
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Способы не совпадают',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))
                    ]),
                  ),
                ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Отменить сделку', style: TextStyle(color: Colors.red)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Отмена сделки'),
                          content: const Text('Сделка будет отменена, SV вернутся владельцу. Продолжить?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
                            ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true), child: const Text('Да, отменить')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await provider.cancelOffer(offer.id);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _sectionHeader('✅ ПОДТВЕРЖДЕНИЕ'),
              const SizedBox(height: 12),

              if (methodsMatch) ...[
                _confirmationProgress(offer),
                const SizedBox(height: 16),

                if (_isFromUser && !offer.fromConfirmed)
                  _confirmButton('📤 Я передал вещь', Colors.green, () async {
                    await provider.confirmStep(offer.id, 'shipped');
                  }),

                if (_isToUser && offer.fromConfirmed && !offer.toConfirmed)
                  _confirmButton('📥 Я получил вещь', Colors.blue, () async {
                    await provider.confirmStep(offer.id, 'received');
                  }),

                if (offer.fromConfirmed && !offer.toConfirmed)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('⏳ Ожидание подтверждения получения',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),

                if (offer.fromConfirmed && offer.toConfirmed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.green, Colors.teal]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.celebration, color: Colors.white, size: 48),
                        SizedBox(height: 8),
                        Text('🎉 Обмен завершён!',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('⏳ Выберите одинаковый способ передачи\nдля подтверждения обмена',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ),
            ],

            // Плашка "Сделка отменена"
            if (offer.status == 'cancelled')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 32),
                    SizedBox(width: 12),
                    Text('❌ Сделка отменена',
                        style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            if (offer.status == 'completed' && !methodsMatch)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.green, Colors.teal]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.celebration, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text('🎉 Обмен завершён!',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            if (offer.status == 'rejected')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 32),
                    SizedBox(width: 12),
                    Text('❌ Предложение отклонено',
                        style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            // 🏆 ИТОГИ СДЕЛКИ (после завершения)
            if (offer.status == 'completed') ...[
              const SizedBox(height: 24),
              _sectionHeader('🏆 ИТОГИ СДЕЛКИ'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFE0F2F1)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 40),
                    const SizedBox(height: 8),
                    const Text('Обмен успешно завершён!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    const Divider(height: 24),
                    _resultRow(
                      icon: Icons.person,
                      label: _isFromUser ? 'Ты получил' : 'Отправитель получил',
                      value: _isFromUser ? offer.toItemTitle : offer.fromItemTitle,
                    ),
                    _resultRow(
                      icon: Icons.person_outline,
                      label: _isFromUser ? 'Ты отдал' : 'Получатель отдал',
                      value: _isFromUser ? offer.fromItemTitle : offer.toItemTitle,
                    ),
                    const Divider(),
                    if (offer.svDifference > 0)
                      _resultRow(
                        icon: Icons.stars,
                        label: _isFromUser ? 'Ты получил SV' : 'Отправитель получил SV',
                        value: '+${offer.svDifference} SV',
                        color: Colors.green,
                      )
                    else if (offer.svDifference < 0)
                      _resultRow(
                        icon: Icons.stars,
                        label: _isFromUser ? 'Ты заплатил SV' : 'Получатель получил SV',
                        value: '${offer.svDifference} SV',
                        color: Colors.red,
                      )
                    else
                      _resultRow(
                        icon: Icons.stars,
                        label: 'SV',
                        value: 'Равный обмен',
                      ),
                    if (offer.deliveryMethod.isNotEmpty)
                      _resultRow(
                        icon: Icons.local_shipping,
                        label: 'Способ передачи',
                        value: _methodName(offer.deliveryMethod),
                      ),
                    _resultRow(
                      icon: Icons.calendar_today,
                      label: 'Дата завершения',
                      value: _formatDate(DateTime.now()),
                    ),
                  ],
                ),
              ),
            ],

            // 💔 ИТОГИ ОТМЕНЫ
            if (offer.status == 'cancelled') ...[
              const SizedBox(height: 24),
              _sectionHeader('💔 ИТОГИ ОТМЕНЫ'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFEF9A9A), width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.restore, color: Colors.orange, size: 40),
                    const SizedBox(height: 8),
                    const Text('Сделка отменена',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 8),
                    Text(
                      offer.svDifference > 0
                          ? '${offer.svDifference} SV возвращены отправителю'
                          : offer.svDifference < 0
                          ? '${offer.svDifference.abs()} SV возвращены получателю'
                          : 'SV не списывались',
                      style: TextStyle(color: Color(0xFF616161)),
                    ),
                    const SizedBox(height: 4),
                    const Text('Вещи остались у владельцев',
                        style: TextStyle(color: Color(0xFF616161))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 💬 ОБСУЖДЕНИЕ
            _sectionHeader('💬 ОБСУЖДЕНИЕ'),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: ChatWidget(offerId: offer.id),
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
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? Colors.black)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  Widget _detailCard(TradeOffer offer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('📝 Сделка №', offer.id.substring(0, 8)),
          const Divider(),
          _detailRow('📤 Отправитель', offer.fromItemTitle),
          _detailRow('📥 Получатель', offer.toItemTitle),
          const Divider(),
          _detailRow('💎 SV отправителя', '$_fromSv'),
          _detailRow('💎 SV получателя', '$_toSv'),
          if (offer.svDifference != 0)
            _detailRow('💰 Доплата', '${offer.svDifference.abs()} SV'),
          if (offer.deliveryMethod.isNotEmpty)
            _detailRow('🚚 Способ', _methodName(offer.deliveryMethod)),
          _detailRow('📅 Статус', _statusText(offer.status)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(_statusText(status), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted': return Icons.check_circle_outline;
      case 'shipped': return Icons.local_shipping;
      case 'completed': return Icons.verified;
      case 'rejected': return Icons.cancel;
      case 'cancelled': return Icons.cancel;
      default: return Icons.hourglass_empty;
    }
  }

  Widget _confirmationProgress(TradeOffer offer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          _stepDot('1. Передача', offer.fromConfirmed),
          Expanded(child: Container(height: 3, color: offer.fromConfirmed ? Colors.green : Colors.grey.shade300)),
          _stepDot('2. Получение', offer.toConfirmed),
          Expanded(child: Container(height: 3, color: offer.toConfirmed ? Colors.green : Colors.grey.shade300)),
          _stepDot('3. Завершено', offer.fromConfirmed && offer.toConfirmed),
        ],
      ),
    );
  }

  Widget _stepDot(String label, bool done) {
    return Column(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done ? Colors.green : Colors.grey.shade300),
          child: done ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: done ? Colors.green : Colors.grey)),
      ],
    );
  }

  Widget _confirmButton(String label, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check, color: Colors.white),
          label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 4,
          ),
        ),
      ),
    );
  }

  Widget _choiceIndicator(String who, String method) {
    final chosen = method.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(chosen ? Icons.check_circle : Icons.radio_button_unchecked,
              color: chosen ? Colors.orange : Colors.grey, size: 18),
          const SizedBox(width: 6),
          Text('$who: ${chosen ? _methodName(method) : "не выбрано"}',
              style: TextStyle(color: chosen ? Colors.black : Colors.grey)),
        ],
      ),
    );
  }

  Widget _deliveryOption(TradesProvider provider, TradeOffer offer, String method, String label) {
    final isSelected = (_isFromUser && offer.fromDeliveryMethod == method) ||
        (!_isFromUser && offer.toDeliveryMethod == method);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isSelected ? null : () async {
          await provider.updateDeliveryMethod(offer.id, method);
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? Colors.orange.shade50 : null,
          side: BorderSide(color: isSelected ? Colors.orange : Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.orange),
          ],
        ),
      ),
    );
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

  String _methodName(String method) {
    switch (method) {
      case 'meetup': return 'Личная встреча';
      case 'delivery': return 'Доставка';
      default: return method;
    }
  }
}

class _ItemCard extends StatelessWidget {
  final String label;
  final bool isMine;
  final String title;
  final int sv;
  final String? imageUrl;
  final String description;
  final String condition;
  final String category;

  const _ItemCard({
    required this.label,
    required this.isMine,
    required this.title,
    required this.sv,
    this.imageUrl,
    this.description = '',
    this.condition = '',
    this.category = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMine ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMine ? Colors.orange : Colors.blue, width: 2),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null && imageUrl!.isNotEmpty && imageUrl!.startsWith('http')
                ? Image.network(imageUrl!, height: 80, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(height: 80, color: Colors.grey.shade200, child: const Icon(Icons.toys, size: 40)))
                : Container(height: 80, color: Colors.grey.shade200, child: const Icon(Icons.toys, size: 40)),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (description.isNotEmpty)
            Text(description, style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (condition.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: condition == 'Новый' ? Colors.green.shade100 :
                condition == 'Отличный' ? Colors.teal.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(condition, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                  color: condition == 'Новый' ? Colors.green.shade700 : Colors.grey.shade700)),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: isMine ? Colors.orange : Colors.blue, borderRadius: BorderRadius.circular(10)),
            child: Text('$sv SV', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}