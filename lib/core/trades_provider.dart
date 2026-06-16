import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'trade_offer.dart';

class TradesProvider extends ChangeNotifier {
  final List<TradeOffer> _offers = [];
  bool _isLoading = false;

  List<TradeOffer> get offers => List.unmodifiable(_offers);
  bool get isLoading => _isLoading;

  static const String apiUrl = 'https://functions.yandexcloud.net/d4e77rr4t3hlvjo7n77b';

  // 🔥 Очистка при выходе
  void clearOffers() {
    _offers.clear();
    notifyListeners();
  }

  Future<void> loadOffers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      if (userId.isEmpty) {
        return;
      }

      _isLoading = true;
      notifyListeners();

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list", "user_id": userId}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final newOffers = <TradeOffer>[];
        for (final o in data['offers']) {
          newOffers.add(TradeOffer(
            id: o['id'] ?? '',
            fromUserId: o['from_user_id'] ?? '',
            toUserId: o['to_user_id'] ?? '',
            fromItemId: o['from_item_id'] ?? '',
            toItemId: o['to_item_id'] ?? '',
            fromItemTitle: o['from_item_title'] ?? '',
            toItemTitle: o['to_item_title'] ?? '',
            svDifference: o['sv_difference'] ?? 0,
            status: o['status'] ?? 'pending',
            deliveryMethod: o['delivery_method'] ?? '',
            fromConfirmed: o['from_confirmed'] ?? false,
            toConfirmed: o['to_confirmed'] ?? false,
            fromShipped: o['from_shipped'] ?? false,
            toReceived: o['to_received'] ?? false,
            toShipped: o['to_shipped'] ?? false,
            fromReceived: o['from_received'] ?? false,
            fromDeliveryMethod: o['from_delivery_method'] ?? '',
            toDeliveryMethod: o['to_delivery_method'] ?? '',
            cancelReason: o['cancel_reason'] ?? '',
            whoCancelled: o['who_cancelled'] ?? '',
          ));
        }
        _offers.clear();
        _offers.addAll(newOffers);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading offers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createOffer(TradeOffer offer) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "create",
          "from_user_id": offer.fromUserId,
          "to_user_id": offer.toUserId,
          "from_item_id": offer.fromItemId,
          "to_item_id": offer.toItemId,
          "from_item_title": offer.fromItemTitle,
          "to_item_title": offer.toItemTitle,
          "sv_difference": offer.svDifference,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final newOffer = TradeOffer(
          id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          fromUserId: offer.fromUserId,
          toUserId: offer.toUserId,
          fromItemId: offer.fromItemId,
          toItemId: offer.toItemId,
          fromItemTitle: offer.fromItemTitle,
          toItemTitle: offer.toItemTitle,
          svDifference: offer.svDifference,
        );
        _offers.insert(0, newOffer);
        notifyListeners();
        return {"ok": true};
      } else {
        return {"ok": false, "error": data['error'] ?? 'unknown'};
      }
    } catch (e) {
      return {"ok": false, "error": e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateStatus(String offerId, String status) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "update-status", "offer_id": offerId, "status": status}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        await loadOffers();
        return {"ok": true};
      } else {
        return {"ok": false, "error": data['error'] ?? 'unknown'};
      }
    } catch (e) {
      return {"ok": false, "error": e.toString()};
    }
  }

  Future<void> updateDeliveryMethod(String offerId, String method) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "update-delivery",
          "offer_id": offerId,
          "user_id": userId,
          "delivery_method": method,
        }),
      ).timeout(const Duration(seconds: 8));

      await loadOffers();
    } catch (e) {
      print('Error updating delivery: $e');
    }
  }

  Future<void> confirmStep(String offerId, String step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "confirm",
          "offer_id": offerId,
          "user_id": userId,
          "step": step,
        }),
      ).timeout(const Duration(seconds: 8));

      await loadOffers();
    } catch (e) {
      print('Error confirming step: $e');
    }
  }

  Future<Map<String, dynamic>> cancelOffer(String offerId, {String reason = ''}) async {
    final index = _offers.indexWhere((o) => o.id == offerId);
    if (index != -1) {
      _offers[index].status = 'cancelled';
      _offers[index].cancelReason = reason;
      notifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "cancel",
          "offer_id": offerId,
          "cancel_reason": reason,
          "user_id": userId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        await loadOffers();
        return {"ok": true};
      } else {
        if (index != -1) {
          _offers[index].status = 'accepted';
          _offers[index].cancelReason = '';
          notifyListeners();
        }
        return {"ok": false, "error": data['error'] ?? 'unknown'};
      }
    } catch (e) {
      if (index != -1) {
        _offers[index].status = 'accepted';
        _offers[index].cancelReason = '';
        notifyListeners();
      }
      return {"ok": false, "error": e.toString()};
    }
  }
}