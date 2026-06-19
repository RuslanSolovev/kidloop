// item_model.dart
import 'package:latlong2/latlong.dart';

class Item {
  final String itemId;
  final String ownerId;
  final String title;
  final String description;
  final int sv;
  final String imagePath;
  final List<String> imagePaths;
  final String location;
  final String category;
  final String condition;
  final bool isMine;
  final String status;

  final double? latitude;
  final double? longitude;

  double? _dynamicLatitude;
  double? _dynamicLongitude;

  Item({
    required this.itemId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.sv,
    required this.imagePath,
    this.imagePaths = const [],
    required this.location,
    required this.category,
    required this.condition,
    this.isMine = false,
    this.status = 'available',
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates {
    if (latitude != null && latitude != 0.0 && longitude != null && longitude != 0.0) {
      return true;
    }
    if (_dynamicLatitude != null && _dynamicLongitude != null) {
      return true;
    }
    return false;
  }

  double? get effectiveLatitude {
    if (latitude != null && latitude != 0.0) return latitude;
    return _dynamicLatitude;
  }

  double? get effectiveLongitude {
    if (longitude != null && longitude != 0.0) return longitude;
    return _dynamicLongitude;
  }

  void setCoordinates(double lat, double lon) {
    _dynamicLatitude = lat;
    _dynamicLongitude = lon;
  }

  LatLng? get coordinates {
    final lat = effectiveLatitude;
    final lon = effectiveLongitude;
    if (lat != null && lon != null) {
      return LatLng(lat, lon);
    }
    return null;
  }

  Item copyWith({
    String? itemId,
    String? ownerId,
    String? title,
    String? description,
    int? sv,
    String? imagePath,
    List<String>? imagePaths,
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
      imagePaths: imagePaths ?? this.imagePaths,
      location: location ?? this.location,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      isMine: isMine ?? this.isMine,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    final images = json['image_paths'];
    List<String> paths = [];
    if (images is List) {
      paths = images.cast<String>();
    } else if (json['image_path'] != null && json['image_path'].toString().isNotEmpty) {
      paths = [json['image_path'].toString()];
    }
    if (paths.isEmpty) {
      paths = ['assets/images/bear.jpg'];
    }

    return Item(
      itemId: json['item_id']?.toString() ?? '',
      ownerId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sv: (json['sv'] ?? 0) is int ? json['sv'] : int.tryParse(json['sv'].toString()) ?? 0,
      imagePath: paths.isNotEmpty ? paths.first : 'assets/images/bear.jpg',
      imagePaths: paths,
      location: json['location']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
      isMine: json['isMine'] == true || json['isMine'] == 'true' || json['isMine'] == 1,
      status: json['status']?.toString() ?? 'available',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'user_id': ownerId,
      'title': title,
      'description': description,
      'sv': sv,
      'image_path': imagePath,
      'image_paths': imagePaths,
      'location': location,
      'category': category,
      'condition': condition,
      'isMine': isMine,
      'status': status,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  @override
  String toString() {
    return 'Item($itemId: $title, location: $location, coords: $coordinates, images: ${imagePaths.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Item && other.itemId == itemId;
  }

  @override
  int get hashCode => itemId.hashCode;
}