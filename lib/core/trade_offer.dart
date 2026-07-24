import 'bundle_model.dart';

class TradeOffer {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String fromItemId;
  final String toItemId;
  final String fromItemTitle;
  final String toItemTitle;
  final int svDifference;
  String status;
  String deliveryMethod;
  String whoCancelled;

  bool fromConfirmed;
  bool toConfirmed;

  bool fromShipped;
  bool toReceived;
  bool toShipped;
  bool fromReceived;

  String fromDeliveryMethod;
  String toDeliveryMethod;
  String cancelReason;

  // 🔥 Новые поля для Bundle
  final String? fromBundleId;
  final String? toBundleId;
  final List<BundleItem>? fromBundleItems;
  final List<BundleItem>? toBundleItems;
  final String? fromItemsJson;
  final String? toItemsJson;

  TradeOffer({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.fromItemId,
    required this.toItemId,
    required this.fromItemTitle,
    required this.toItemTitle,
    required this.svDifference,
    this.status = 'pending',
    this.deliveryMethod = '',
    this.fromConfirmed = false,
    this.toConfirmed = false,
    this.fromShipped = false,
    this.toReceived = false,
    this.toShipped = false,
    this.fromReceived = false,
    this.fromDeliveryMethod = '',
    this.toDeliveryMethod = '',
    this.cancelReason = '',
    this.whoCancelled = '',
    this.fromBundleId,
    this.toBundleId,
    this.fromBundleItems,
    this.toBundleItems,
    this.fromItemsJson,
    this.toItemsJson,
  });

  bool get isFromBundle => fromBundleId != null && fromBundleId!.isNotEmpty;
  bool get isToBundle => toBundleId != null && toBundleId!.isNotEmpty;

  int get fromItemCount {
    if (isFromBundle && fromBundleItems != null) return fromBundleItems!.length;
    return fromItemId.isNotEmpty ? 1 : 0;
  }

  int get toItemCount {
    if (isToBundle && toBundleItems != null) return toBundleItems!.length;
    return toItemId.isNotEmpty ? 1 : 0;
  }
}