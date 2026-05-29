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
  bool fromConfirmed;
  bool toConfirmed;
  String fromDeliveryMethod;  // что выбрал отправитель
  String toDeliveryMethod;    // что выбрал получатель

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
    this.fromDeliveryMethod = '',
    this.toDeliveryMethod = '',
  });
}