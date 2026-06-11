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

  // Старые поля (оставляем для обратной совместимости)
  bool fromConfirmed;
  bool toConfirmed;

  // Новые поля для 4-шагового подтверждения
  bool fromShipped;   // Отправитель передал свою вещь
  bool toReceived;    // Получатель получил вещь отправителя
  bool toShipped;     // Получатель передал свою вещь
  bool fromReceived;  // Отправитель получил вещь получателя

  String fromDeliveryMethod;
  String toDeliveryMethod;

  // Причина отмены
  String cancelReason;

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
  });
}