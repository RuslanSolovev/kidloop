import 'package:latlong2/latlong.dart';

class Item {
  final String itemId;
  final String ownerId;
  final String title;
  final String description;
  final int sv;
  final String imagePath;
  final String location;
  final String category;
  final String condition;
  final bool isMine;
  final String status;

  // Координаты (могут приходить с сервера или null)
  final double? latitude;
  final double? longitude;

  // Внутренние изменяемые поля для геокодирования
  double? _dynamicLatitude;
  double? _dynamicLongitude;

  Item({
    required this.itemId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.sv,
    required this.imagePath,
    required this.location,
    required this.category,
    required this.condition,
    this.isMine = false,
    this.status = 'available',
    this.latitude,
    this.longitude,
  });

  /// Есть ли координаты (либо из БД, либо после геокодирования)
  bool get hasCoordinates {
    // Проверяем статические координаты
    if (latitude != null && latitude != 0.0 && longitude != null && longitude != 0.0) {
      return true;
    }
    // Проверяем динамические координаты (после геокодирования)
    if (_dynamicLatitude != null && _dynamicLongitude != null) {
      return true;
    }
    return false;
  }

  /// Эффективная широта (приоритет: статическая, затем динамическая)
  double? get effectiveLatitude {
    if (latitude != null && latitude != 0.0) return latitude;
    return _dynamicLatitude;
  }

  /// Эффективная долгота (приоритет: статическая, затем динамическая)
  double? get effectiveLongitude {
    if (longitude != null && longitude != 0.0) return longitude;
    return _dynamicLongitude;
  }

  /// Установить координаты после геокодирования
  void setCoordinates(double lat, double lon) {
    _dynamicLatitude = lat;
    _dynamicLongitude = lon;
  }

  /// Получить координаты как LatLng (если есть)
  LatLng? get coordinates {
    final lat = effectiveLatitude;
    final lon = effectiveLongitude;
    if (lat != null && lon != null) {
      return LatLng(lat, lon);
    }
    return null;
  }

  /// Создание копии с измененными полями (для иммутабельности)
  Item copyWith({
    String? itemId,
    String? ownerId,
    String? title,
    String? description,
    int? sv,
    String? imagePath,
    String? location,
    String? category,
    String? condition,
    bool? isMine,
    String? status,
    double? latitude,
    double? longitude,
  }) {
    return Item(
      itemId: itemId ?? this.itemId,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      sv: sv ?? this.sv,
      imagePath: imagePath ?? this.imagePath,
      location: location ?? this.location,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      isMine: isMine ?? this.isMine,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Создать из JSON
  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      itemId: json['item_id']?.toString() ?? '',
      ownerId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sv: (json['sv'] ?? 0) is int ? json['sv'] : int.tryParse(json['sv'].toString()) ?? 0,
      imagePath: json['image_path']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
      isMine: json['isMine'] == true || json['isMine'] == 'true' || json['isMine'] == 1,
      status: json['status']?.toString() ?? 'available',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }

  /// Преобразовать в JSON
  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'user_id': ownerId,
      'title': title,
      'description': description,
      'sv': sv,
      'image_path': imagePath,
      'location': location,
      'category': category,
      'condition': condition,
      'isMine': isMine,
      'status': status,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Для отладки
  @override
  String toString() {
    return 'Item($itemId: $title, location: $location, coords: $coordinates)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Item && other.itemId == itemId;
  }

  @override
  int get hashCode => itemId.hashCode;
}