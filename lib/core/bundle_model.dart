import 'dart:convert';

class Bundle {
  final String bundleId;
  final String userId;
  final String title;
  final String description;
  final int totalSv;
  final List<String> imagePaths;
  final String location;
  final List<String> categories;  // 🔥 Было String category, стало List<String>
  final String condition;
  final String status;
  final List<BundleItem> items;
  final String? createdAt;
  bool isMine;

  Bundle({
    required this.bundleId,
    required this.userId,
    required this.title,
    required this.description,
    required this.totalSv,
    required this.imagePaths,
    required this.location,
    required this.categories,
    required this.condition,
    this.status = 'available',
    this.items = const [],
    this.createdAt,
    this.isMine = false,
  });

  // 🔥 Удобный геттер для фильтрации
  String get primaryCategory => categories.isNotEmpty ? categories.first : '';

  bool hasCategory(String category) => categories.contains(category);

  factory Bundle.fromJson(Map<String, dynamic> json) {
    final itemsList = <BundleItem>[];
    if (json['items'] is List) {
      for (final item in json['items']) {
        itemsList.add(BundleItem.fromJson(item));
      }
    } else if (json['items'] is String) {
      try {
        final parsed = List<dynamic>.from(const JsonDecoder().convert(json['items']));
        for (final item in parsed) {
          itemsList.add(BundleItem.fromJson(item));
        }
      } catch (_) {}
    }

    // 🔥 Парсим categories — ИСПРАВЛЕНО
    final List<String> categoriesList = [];
    if (json['categories'] is List) {
      for (final cat in json['categories']) {
        if (cat is String) {
          categoriesList.add(cat);
        } else {
          categoriesList.add(cat.toString());
        }
      }
    } else if (json['categories'] is String) {
      try {
        final parsed = List<dynamic>.from(const JsonDecoder().convert(json['categories']));
        for (final cat in parsed) {
          categoriesList.add(cat.toString());
        }
      } catch (_) {
        if (json['categories'].toString().isNotEmpty && json['categories'] != 'null') {
          categoriesList.add(json['categories'].toString());
        }
      }
    } else if (json['category'] != null && json['category'].toString().isNotEmpty) {
      categoriesList.add(json['category'].toString());
    }

    final imagePathsRaw = json['image_paths'];
    List<String> imagePaths = [];
    if (imagePathsRaw is List) {
      for (final img in imagePathsRaw) {
        imagePaths.add(img.toString());
      }
    } else if (imagePathsRaw is String) {
      try {
        final parsed = List<dynamic>.from(const JsonDecoder().convert(imagePathsRaw));
        for (final img in parsed) {
          imagePaths.add(img.toString());
        }
      } catch (_) {
        if (imagePathsRaw.isNotEmpty) imagePaths = [imagePathsRaw.toString()];
      }
    }

    return Bundle(
      bundleId: json['bundle_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      totalSv: (json['total_sv'] ?? 0) is int
          ? json['total_sv']
          : int.tryParse(json['total_sv'].toString()) ?? 0,
      imagePaths: imagePaths,
      location: json['location']?.toString() ?? '',
      categories: categoriesList,
      condition: json['condition']?.toString() ?? '',
      status: json['status']?.toString() ?? 'available',
      items: itemsList,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bundle_id': bundleId,
      'user_id': userId,
      'title': title,
      'description': description,
      'total_sv': totalSv,
      'image_paths': imagePaths,
      'location': location,
      'categories': categories,
      'condition': condition,
      'status': status,
      'items': items.map((e) => e.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bundle && other.bundleId == bundleId;
  }

  @override
  int get hashCode => bundleId.hashCode;
}

class BundleItem {
  final String itemId;
  final String title;
  final int sv;
  final String imagePath;
  final String category;
  final String condition;

  BundleItem({
    required this.itemId,
    required this.title,
    required this.sv,
    this.imagePath = '',
    this.category = '',
    this.condition = '',
  });

  factory BundleItem.fromJson(Map<String, dynamic> json) {
    return BundleItem(
      itemId: json['item_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      sv: (json['sv'] ?? 0) is int
          ? json['sv']
          : int.tryParse(json['sv'].toString()) ?? 0,
      imagePath: json['image_path']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'title': title,
      'sv': sv,
      'image_path': imagePath,
      'category': category,
      'condition': condition,
    };
  }
}