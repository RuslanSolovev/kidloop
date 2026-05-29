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

  Future<void> loadOffers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list", "user_id": userId}),
      ).timeout(const Duration(seconds: 5));
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
            fromDeliveryMethod: o['from_delivery_method'] ?? '',
            toDeliveryMethod: o['to_delivery_method'] ?? '',
          ));
        }
        _offers.clear();
        _offers.addAll(newOffers);
        notifyListeners();
      }
    } catch (e) {}
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
      );
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
      );
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
        body: jsonEncode({"action": "update-delivery", "offer_id": offerId, "user_id": userId, "delivery_method": method}),
      );
      await loadOffers();
    } catch (e) {}
  }

  Future<void> confirmStep(String offerId, String step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "confirm", "offer_id": offerId, "user_id": userId, "step": step}),
      );
      await loadOffers();
    } catch (e) {}
  }

  Future<Map<String, dynamic>> cancelOffer(String offerId) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "cancel", "offer_id": offerId}),
      );
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
}