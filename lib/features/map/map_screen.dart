// features/map/map_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../item_details/item_details_screen.dart';
import '../../core/item_model.dart';

// ============================================================================
// МОДЕЛЬ МАРКЕРА
// ============================================================================
class MapMarker {
  final String markerId;
  final String userId;
  final String userName;
  final String type;
  final String title;
  final String description;
  final double latitude;
  final double longitude;

  MapMarker({
    required this.markerId,
    required this.userId,
    required this.userName,
    required this.type,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  factory MapMarker.fromJson(
      Map<String, dynamic> json,
      ) {
    return MapMarker(
      markerId: json['marker_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// ============================================================================
// КЭШ ГЕОКОДИРОВАНИЯ
// ============================================================================
class GeocodingCache {
  static final Map<String, LatLng?> _cache = <String, LatLng?>{};

  static LatLng? get(String key) => _cache[key];

  static void set(String key, LatLng? value) {
    _cache[key] = value;
  }

  static bool has(String key) => _cache.containsKey(key);

  static void clear() => _cache.clear();
}

// ============================================================================
// TOP-LEVEL ФУНКЦИИ ДЛЯ COMPUTE
// ============================================================================
List<Item> processItemsInBackground(
    List<dynamic> itemsJson,
    ) {
  final items = itemsJson
      .map(
        (item) => Item(
      itemId: item['item_id']?.toString() ?? '',
      ownerId: item['user_id']?.toString() ?? '',
      title: item['title']?.toString() ?? '',
      description: item['description']?.toString() ?? '',
      sv: int.tryParse(item['sv']?.toString() ?? '0') ?? 0,
      imagePath: item['image_path']?.toString() ?? '',
      location: item['location']?.toString() ?? '',
      category: item['category']?.toString() ?? '',
      condition: item['condition']?.toString() ?? '',
      status: item['status']?.toString() ?? '',
      latitude: _toDoubleStatic(item['latitude']),
      longitude: _toDoubleStatic(item['longitude']),
    ),
  )
      .toList();

  return items
      .where(
        (item) =>
    item.hasCoordinates ||
        _getCityCoordsStatic(item.location) != null,
  )
      .toList();
}

double _toDoubleStatic(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<MapMarker> processMarkersInBackground(
    List<dynamic> markersJson,
    ) {
  return markersJson
      .map(
        (marker) => MapMarker.fromJson(
      Map<String, dynamic>.from(marker as Map),
    ),
  )
      .toList();
}

LatLng? _getCityCoordsStatic(String location) {
  if (location.isEmpty) return null;

  final lower = location.toLowerCase().trim();

  final cleaned = lower
      .replaceAll(RegExp(r'[^\w\sа-яё-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  const cityMap = {
    'москва': LatLng(55.7558, 37.6173),
    'moscow': LatLng(55.7558, 37.6173),
    'санкт-петербург': LatLng(59.9343, 30.3351),
    'питер': LatLng(59.9343, 30.3351),
    'спб': LatLng(59.9343, 30.3351),
    'новосибирск': LatLng(55.0084, 82.9357),
    'екатеринбург': LatLng(56.8389, 60.6057),
    'казань': LatLng(55.7961, 49.1064),
    'нижний новгород': LatLng(56.2965, 43.9361),
    'челябинск': LatLng(55.1644, 61.4368),
    'самара': LatLng(53.1959, 50.1002),
    'щёлково': LatLng(55.9205, 37.9917),
    'щелково': LatLng(55.9205, 37.9917),
    'фрязино': LatLng(55.9606, 38.0412),
    'омск': LatLng(54.9893, 73.3682),
    'ростов-на-дону': LatLng(47.2357, 39.7015),
    'ростов': LatLng(47.2357, 39.7015),
    'уфа': LatLng(54.7388, 55.9721),
    'красноярск': LatLng(56.0106, 92.8525),
    'воронеж': LatLng(51.6755, 39.2085),
    'пермь': LatLng(58.0105, 56.2502),
    'волгоград': LatLng(48.7080, 44.5133),
    'краснодар': LatLng(45.0355, 38.9753),
    'саратов': LatLng(51.5336, 46.0343),
    'тюмень': LatLng(57.1613, 65.5250),
    'тольятти': LatLng(53.5303, 49.3461),
    'ижевск': LatLng(56.8498, 53.2045),
    'барнаул': LatLng(53.3480, 83.7765),
    'иркутск': LatLng(52.2869, 104.3050),
    'хабаровск': LatLng(48.4802, 135.0719),
    'ярославль': LatLng(57.6261, 39.8845),
    'владивосток': LatLng(43.1155, 131.8855),
    'махачкала': LatLng(42.9849, 47.5047),
    'томск': LatLng(56.4846, 84.9476),
    'оренбург': LatLng(51.7682, 55.0970),
    'кемерово': LatLng(55.3549, 86.0873),
    'новокузнецк': LatLng(53.7557, 87.1099),
    'рига': LatLng(56.9496, 24.1052),
    'юрмала': LatLng(56.9681, 23.7566),
    'даугавпилс': LatLng(55.8751, 26.5320),
  };

  if (cityMap.containsKey(cleaned)) {
    return cityMap[cleaned];
  }

  for (final entry in cityMap.entries) {
    if (cleaned.contains(entry.key)) {
      return entry.value;
    }
  }

  if (cleaned.contains('нижн') && cleaned.contains('новгород')) {
    return const LatLng(56.2965, 43.9361);
  }

  if (cleaned.contains('санкт') && cleaned.contains('петербург')) {
    return const LatLng(59.9343, 30.3351);
  }

  if (cleaned.contains('ростов') && cleaned.contains('дон')) {
    return const LatLng(47.2357, 39.7015);
  }

  return null;
}

// ============================================================================
// ЭКРАН КАРТЫ
// ============================================================================
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();

  List<Item> _items = [];
  List<MapMarker> _customMarkers = [];

  LatLng? _userLocation;
  LatLng? _lastKnownPosition;

  bool _loading = true;
  bool _isDisposed = false;
  bool _isRefreshing = false;
  bool _isOffline = false;

  String? _selectedCategory;
  Item? _selectedItem;

  String _locationStatus = 'Определение местоположения...';

  String _centerAddress = '';

  LatLng? _lastGeocodedCenter;

  Timer? _geocodeDebounce;
  Timer? _refreshTimer;
  Timer? _debounceTimer;

  StreamSubscription? _connectivitySubscription;

  bool _isDarkMode = false;

  static const List<String> _categories = [
    'Все',
    'Игрушки',
    'LEGO',
    'Самокат',
    'Книги',
    'Одежда',
    'Коляска',
    'Мебель',
    'Техника',
    'Спорт',
    'Развивашки',
    'Творчество',
    'Пазлы',
    'Конструктор',
    'Куклы',
    'Машинки',
  ];

  static const String mapApiUrl =
      'https://functions.yandexcloud.net/d4e2uh2tj0febumk6e7e';

  static const String itemsApiUrl =
      'https://functions.yandexcloud.net/d4ei9an1aushareidmjc';

  @override
  bool get wantKeepAlive => true;

  Color get _backgroundColor =>
      _isDarkMode ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

  Color get _surfaceColor =>
      _isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;

  Color get _secondarySurfaceColor =>
      _isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF8F8FA);

  Color get _textColor =>
      _isDarkMode ? Colors.white : const Color(0xFF111111);

  Color get _subTextColor =>
      _isDarkMode ? const Color(0xFF98989F) : const Color(0xFF6F6F76);

  Color get _tertiaryTextColor =>
      _isDarkMode ? const Color(0xFF636366) : const Color(0xFF8E8E93);

  Color get _borderColor => _isDarkMode
      ? Colors.white.withOpacity(0.07)
      : Colors.black.withOpacity(0.06);

  Color get _accentColor => Theme.of(context).colorScheme.primary;

  Color get _blueColor => const Color(0xFF0A84FF);

  Color get _greenColor => const Color(0xFF30D158);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initConnectivityCheck();
    _initAsync();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 45),
          (_) {
        if (_isDisposed ||
            !mounted ||
            _isOffline ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.paused) {
          return;
        }

        _refreshDataSilently();
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;

    _refreshTimer?.cancel();
    _debounceTimer?.cancel();
    _geocodeDebounce?.cancel();

    _connectivitySubscription?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    _mapController.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_isDisposed &&
        mounted &&
        !_isOffline) {
      _refreshDataSilently();
    }
  }

  void _initConnectivityCheck() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
          final offline = result == ConnectivityResult.none;

          if (offline != _isOffline && mounted) {
            setState(() {
              _isOffline = offline;
            });

            if (!offline) {
              _refreshDataSilently();

              if (_userLocation == null && _lastKnownPosition == null) {
                _determinePosition();
              }
            }
          }
        });
  }

  Future<void> _initAsync() async {
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      });
    }

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none && mounted) {
      setState(() {
        _isOffline = true;
        _locationStatus = 'Нет подключения к интернету';
      });
    }

    await _determinePosition();

    if (!_isDisposed && mounted && !_isOffline) {
      await Future.wait([
        _loadItems(),
        _loadCustomMarkers(),
      ]);

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } else if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _determinePosition() async {
    try {
      final lastPosition = await Geolocator.getLastKnownPosition();

      if (lastPosition != null && !_isDisposed && mounted) {
        final position = LatLng(
          lastPosition.latitude,
          lastPosition.longitude,
        );

        setState(() {
          _lastKnownPosition = position;
          _locationStatus = 'Последнее местоположение';
        });

        _safeMoveMap(position, 13);
        _geocodeCenter(position);
      }
    } catch (_) {}

    bool serviceEnabled;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      serviceEnabled = false;
    }

    if (!serviceEnabled) {
      if (mounted && !_isDisposed) {
        setState(() {
          _locationStatus = 'Служба геолокации выключена';
        });

        _showLocationSettingsDialog();
      }

      _setDefaultLocation();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        if (mounted && !_isDisposed) {
          setState(() {
            _locationStatus = 'Нет разрешения';
          });

          _showPermissionDeniedDialog();
        }

        _setDefaultLocation();
        return;
      }
    }

    try {
      if (mounted && !_isDisposed) {
        setState(() {
          _locationStatus = 'Ищем местоположение...';
        });
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 18));

      if (!_isDisposed && mounted) {
        final userLoc = LatLng(
          position.latitude,
          position.longitude,
        );

        setState(() {
          _userLocation = userLoc;
          _locationStatus = 'Местоположение определено';
        });

        _safeMoveMap(userLoc, 14);
        _geocodeCenter(userLoc);

        return;
      }
    } catch (_) {}

    if (_lastKnownPosition != null && !_isDisposed && mounted) {
      setState(() {
        _userLocation = _lastKnownPosition;
        _locationStatus = 'Последнее местоположение';
      });

      _safeMoveMap(_userLocation!, 12);
      _geocodeCenter(_userLocation!);
    } else {
      if (mounted && !_isDisposed) {
        setState(() {
          _locationStatus = 'Местоположение не найдено';
        });
      }

      _setDefaultLocation();
    }
  }

  void _onMapMoved(MapCamera camera) {
    final center = camera.center;

    if (_lastGeocodedCenter != null) {
      final distance = const Distance().as(
        LengthUnit.Meter,
        _lastGeocodedCenter!,
        center,
      );

      if (distance < 300) return;
    }

    _geocodeDebounce?.cancel();

    _geocodeDebounce = Timer(
      const Duration(milliseconds: 650),
          () => _geocodeCenter(center),
    );
  }

  Future<void> _geocodeCenter(LatLng point) async {
    if (_isDisposed) return;

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': point.latitude.toString(),
          'lon': point.longitude.toString(),
          'format': 'json',
          'accept-language': 'ru',
          'zoom': '18',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'KidLoop/1.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200 || !mounted || _isDisposed) {
        return;
      }

      final data = jsonDecode(response.body);

      final address = data['address'] as Map<String, dynamic>?;

      if (address == null) return;

      final road = address['road'] ??
          address['pedestrian'] ??
          address['footway'] ??
          address['path'] ??
          '';

      final house = address['house_number'] ?? '';

      final suburb =
          address['suburb'] ?? address['neighbourhood'] ?? '';

      final city =
          address['city'] ?? address['town'] ?? address['village'] ?? '';

      final state = address['state'] ?? '';

      final parts = <String>[];

      if (road.toString().isNotEmpty) {
        parts.add(house.toString().isNotEmpty
            ? '$road, $house'
            : road.toString());
      }

      if (suburb.toString().isNotEmpty) {
        parts.add(suburb.toString());
      }

      if (city.toString().isNotEmpty) {
        parts.add(city.toString());
      } else if (state.toString().isNotEmpty) {
        parts.add(state.toString());
      }

      final shortAddress = parts.join(', ');

      if (shortAddress.isNotEmpty) {
        setState(() {
          _centerAddress = shortAddress;
          _lastGeocodedCenter = point;
        });
      }
    } catch (_) {}
  }

  void _safeMoveMap(LatLng point, double zoom) {
    if (!mounted || _isDisposed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;

      try {
        _mapController.move(point, zoom);
      } catch (_) {}
    });
  }

  Future<void> _showLocationSettingsDialog() async {
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return _ModernDialog(
          isDarkMode: _isDarkMode,
          icon: Icons.location_off_outlined,
          color: _accentColor,
          title: 'Геолокация выключена',
          message:
          'Включите службу геолокации в настройках устройства, чтобы видеть вещи рядом.',
          secondaryText: 'Пропустить',
          primaryText: 'Настройки',
          onSecondary: () => Navigator.pop(ctx),
          onPrimary: () {
            Navigator.pop(ctx);
            Geolocator.openLocationSettings();
          },
        );
      },
    );
  }

  Future<void> _showPermissionDeniedDialog() async {
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return _ModernDialog(
          isDarkMode: _isDarkMode,
          icon: Icons.location_disabled_outlined,
          color: _accentColor,
          title: 'Нет доступа',
          message:
          'Разрешите приложению использовать геолокацию в настройках.',
          secondaryText: 'Пропустить',
          primaryText: 'Настройки',
          onSecondary: () => Navigator.pop(ctx),
          onPrimary: () {
            Navigator.pop(ctx);
            Geolocator.openAppSettings();
          },
        );
      },
    );
  }

  void _setDefaultLocation() {
    if (!_isDisposed && mounted) {
      final defaultLoc =
          _lastKnownPosition ?? const LatLng(55.7558, 37.6173);

      setState(() {
        _userLocation ??= defaultLoc;
        _centerAddress = 'Москва';
      });
    }
  }

  Future<void> _refreshDataSilently() async {
    if (_isRefreshing || _isOffline) return;

    _isRefreshing = true;

    try {
      await Future.wait([
        _loadItems(),
        _loadCustomMarkers(),
      ]);

      if (mounted && !_isDisposed) {
        setState(() {});
      }
    } catch (_) {
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadItems() async {
    if (_isDisposed || _isOffline) return;

    try {
      final response = await http.post(
        Uri.parse(itemsApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'list',
        }),
      ).timeout(const Duration(seconds: 15));

      if (_isDisposed || response.statusCode != 200) return;

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final itemsList = data['items'] as List? ?? [];

        final prefs = await SharedPreferences.getInstance();

        final currentUserId = prefs.getString('user_id') ?? '';

        final processedItems = itemsList
            .map(
              (item) => Item(
            itemId: item['item_id']?.toString() ?? '',
            ownerId: item['user_id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            description: item['description']?.toString() ?? '',
            sv: int.tryParse(item['sv']?.toString() ?? '0') ?? 0,
            imagePath: item['image_path']?.toString() ?? '',
            location: item['location']?.toString() ?? '',
            category: item['category']?.toString() ?? '',
            condition: item['condition']?.toString() ?? '',
            status: item['status']?.toString() ?? '',
            isMine:
            item['user_id']?.toString() == currentUserId,
            latitude: _toDoubleStatic(item['latitude']),
            longitude: _toDoubleStatic(item['longitude']),
          ),
        )
            .where(
              (item) =>
          item.hasCoordinates ||
              _getCityCoordsStatic(item.location) != null,
        )
            .toList();

        final itemsNeedGeocoding = processedItems
            .where(
              (item) =>
          !item.hasCoordinates &&
              _getCityCoordsStatic(item.location) == null,
        )
            .toList();

        if (itemsNeedGeocoding.isNotEmpty) {
          await _geocodeItems(itemsNeedGeocoding);
        }

        if (!_isDisposed && mounted) {
          setState(() {
            _items = processedItems;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _geocodeItems(List<Item> items) async {
    for (final item in items) {
      if (_isDisposed) return;

      if (GeocodingCache.has(item.location)) {
        final cached = GeocodingCache.get(item.location);

        if (cached != null) {
          item.setCoordinates(cached.latitude, cached.longitude);
        }

        continue;
      }

      try {
        final uri = Uri.https(
          'nominatim.openstreetmap.org',
          '/search',
          {
            'q': item.location,
            'format': 'json',
            'limit': '1',
            'countrycodes': 'ru,lv',
          },
        );

        final response = await http.get(
          uri,
          headers: {
            'User-Agent': 'KidLoop/1.0',
            'Accept-Language': 'ru',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final results = jsonDecode(response.body) as List;

          if (results.isNotEmpty) {
            final lat =
                double.tryParse(results[0]['lat'].toString()) ?? 0;

            final lon =
                double.tryParse(results[0]['lon'].toString()) ?? 0;

            final point = LatLng(lat, lon);

            GeocodingCache.set(item.location, point);

            item.setCoordinates(lat, lon);
          } else {
            GeocodingCache.set(item.location, null);
          }
        }

        await Future.delayed(const Duration(seconds: 1));
      } catch (_) {
        GeocodingCache.set(item.location, null);
      }
    }
  }

  Future<void> _loadCustomMarkers() async {
    if (_isDisposed || _isOffline) return;

    try {
      final response = await http.post(
        Uri.parse(mapApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'list',
        }),
      ).timeout(const Duration(seconds: 15));

      if (_isDisposed || response.statusCode != 200) return;

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final markersList = data['markers'] as List? ?? [];

        final processedMarkers = await compute(
          processMarkersInBackground,
          markersList,
        );

        if (!_isDisposed && mounted) {
          setState(() {
            _customMarkers = processedMarkers;
          });
        }
      }
    } catch (_) {}
  }

  LatLng? _getItemCoordinates(Item item) {
    if (item.hasCoordinates && item.coordinates != null) {
      return item.coordinates;
    }

    return _getCityCoordsStatic(item.location);
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Игрушки':
        return _accentColor;
      case 'LEGO':
        return const Color(0xFFFFCC00);
      case 'Самокат':
        return _greenColor;
      case 'Книги':
        return _blueColor;
      case 'Одежда':
        return const Color(0xFFBF5AF2);
      case 'Коляска':
        return const Color(0xFF64D2FF);
      case 'Мебель':
        return const Color(0xFFA2845E);
      case 'Техника':
        return const Color(0xFF8E8E93);
      case 'Спорт':
        return const Color(0xFFFF453A);
      case 'Развивашки':
        return const Color(0xFFFF375F);
      case 'Творчество':
        return const Color(0xFFFF9F0A);
      case 'Пазлы':
        return const Color(0xFF5856D6);
      case 'Конструктор':
        return const Color(0xFFFFCC00);
      case 'Куклы':
        return const Color(0xFFFF2D55);
      case 'Машинки':
        return const Color(0xFF64D2FF);
      default:
        return _blueColor;
    }
  }

  Color _markerTypeColor(String type) {
    switch (type) {
      case 'announcement':
        return _blueColor;
      case 'event':
        return _accentColor;
      case 'meetup':
        return _greenColor;
      default:
        return _tertiaryTextColor;
    }
  }

  String _markerTypeEmoji(String type) {
    switch (type) {
      case 'announcement':
        return '📢';
      case 'event':
        return '🎉';
      case 'meetup':
        return '🤝';
      default:
        return '📍';
    }
  }

  String _markerTypeLabel(String type) {
    switch (type) {
      case 'announcement':
        return 'Объявление';
      case 'event':
        return 'Событие';
      case 'meetup':
        return 'Встреча';
      default:
        return 'Метка';
    }
  }

  List<Item> get _filteredItems {
    if (_selectedCategory == null || _selectedCategory == 'Все') {
      return _items;
    }

    return _items
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  Widget _buildCircleImageWidget(
      String path,
      Color fallbackColor,
      double size,
      ) {
    if (path.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: fallbackColor.withOpacity(0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.toys_outlined,
                color: fallbackColor,
                size: size * 0.42,
              ),
            );
          },
          errorBuilder: (context, url, error) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: fallbackColor.withOpacity(0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.broken_image_outlined,
                color: fallbackColor,
                size: size * 0.42,
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor.withOpacity(0.13),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.toys_outlined,
        color: fallbackColor,
        size: size * 0.42,
      ),
    );
  }

  List<Marker> _buildClusteredMarkers() {
    if (_isDisposed) return [];

    final markers = <Marker>[];

    final items = _filteredItems;

    final groups = <String, List<Item>>{};

    for (final item in items) {
      final coords = _getItemCoordinates(item);

      if (coords == null) continue;

      final key =
          '${coords.latitude.toStringAsFixed(3)}_${coords.longitude.toStringAsFixed(3)}';

      groups.putIfAbsent(key, () => <Item>[]).add(item);
    }

    for (final entry in groups.entries) {
      final groupItems = entry.value;

      final avgLat = groupItems
          .map((item) => _getItemCoordinates(item)!.latitude)
          .reduce((a, b) => a + b) /
          groupItems.length;

      final avgLon = groupItems
          .map((item) => _getItemCoordinates(item)!.longitude)
          .reduce((a, b) => a + b) /
          groupItems.length;

      final point = LatLng(avgLat, avgLon);

      if (groupItems.length > 1) {
        markers.add(
          Marker(
            point: point,
            width: 58,
            height: 58,
            child: GestureDetector(
              onTap: () => _showClusterDialog(groupItems),
              child: _buildClusterMarker(groupItems.length),
            ),
          ),
        );
      } else {
        final item = groupItems.first;

        final color = _categoryColor(item.category);

        markers.add(
          Marker(
            point: point,
            width: 78,
            height: 94,
            child: GestureDetector(
              onTap: () {
                _debounceTimer?.cancel();

                _debounceTimer = Timer(
                  const Duration(milliseconds: 220),
                      () {
                    if (!mounted || _isDisposed) return;

                    _mapController.move(point, 15);

                    setState(() {
                      _selectedItem = item;
                    });
                  },
                );
              },
              child: _buildItemMarker(item, color),
            ),
          ),
        );
      }
    }

    for (final marker in _customMarkers) {
      final color = _markerTypeColor(marker.type);

      markers.add(
        Marker(
          point: LatLng(marker.latitude, marker.longitude),
          width: 76,
          height: 94,
          child: GestureDetector(
            onTap: () => _showMarkerInfo(marker),
            child: _buildCustomMarker(marker, color),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildClusterMarker(int count) {
    return Container(
      decoration: BoxDecoration(
        color: _accentColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'вещей',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemMarker(Item item, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: item.isMine ? _accentColor : Colors.white,
              width: item.isMine ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildCircleImageWidget(item.imagePath, color, 49),
              if (item.isMine)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            '${item.sv} SV',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(14, 7),
          painter: TrianglePainter(color: color),
        ),
      ],
    );
  }

  Widget _buildCustomMarker(MapMarker marker, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 47,
          height: 47,
          decoration: BoxDecoration(
            color: _surfaceColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.22),
                blurRadius: 11,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _markerTypeEmoji(marker.type),
            style: const TextStyle(fontSize: 23),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _markerTypeLabel(marker.type),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(14, 7),
          painter: TrianglePainter(color: color),
        ),
      ],
    );
  }

  void _showClusterDialog(List<Item> items) {
    if (_isDisposed) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ClusterSheet(
          items: items,
          isDarkMode: _isDarkMode,
          accentColor: _accentColor,
          onItemTap: (item) {
            Navigator.pop(ctx);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ItemDetailsScreen(item: item),
              ),
            );
          },
          imageBuilder: _buildCircleImageWidget,
          categoryColor: _categoryColor,
        );
      },
    );
  }

  void _showMarkerInfo(MapMarker marker) {
    if (_isDisposed) return;

    final color = _markerTypeColor(marker.type);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _MarkerInfoSheet(
          marker: marker,
          isDarkMode: _isDarkMode,
          color: color,
          typeLabel: _markerTypeLabel(marker.type),
          emoji: _markerTypeEmoji(marker.type),
          onClose: () => Navigator.pop(ctx),
        );
      },
    );
  }

  Future<void> _showCreateMarkerDialog(LatLng point) async {
    if (_isDisposed || _isOffline) {
      if (mounted) {
        _showSnackBar('Нет подключения к интернету', _accentColor);
      }

      return;
    }

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateMarkerSheet(
        point: point,
        isDarkMode: _isDarkMode,
        accentColor: _accentColor,
      ),
    );

    if (result == null || !mounted || _isDisposed) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getString('user_id') ?? '';

      final userName = prefs.getString('user_name') ?? '';

      if (userId.isEmpty) {
        if (mounted) {
          _showSnackBar('Необходимо войти в профиль', _accentColor);
        }

        return;
      }

      final response = await http.post(
        Uri.parse(mapApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'create',
          'user_id': userId,
          'user_name': userName,
          'type': result['type'],
          'title': result['title'],
          'description': result['description'],
          'latitude': point.latitude,
          'longitude': point.longitude,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _loadCustomMarkers();

        if (mounted && !_isDisposed) {
          _showSnackBar('Маркер создан', _greenColor);
        }
      } else {
        throw Exception('Ошибка сервера');
      }
    } catch (_) {
      if (mounted && !_isDisposed) {
        _showSnackBar('Ошибка при создании маркера', Colors.red);
      }
    }
  }

  void _onCreateMarkerButtonPressed() {
    _showCreateMarkerDialog(_mapController.center);
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15);
      _geocodeCenter(_userLocation!);
    } else {
      _determinePosition();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        backgroundColor: _surfaceColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: color.withOpacity(0.18),
          ),
        ),
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: color,
                size: 17,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _borderColor),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(_accentColor),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Загрузка карты',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _locationStatus,
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ??
                  _lastKnownPosition ??
                  const LatLng(55.7558, 37.6173),
              initialZoom: 10,
              minZoom: 4,
              maxZoom: 18,
              onLongPress: (tapPosition, point) =>
                  _showCreateMarkerDialog(point),
              onMapEvent: (event) {
                if (event is MapEventMove ||
                    event is MapEventFlingAnimation) {
                  _onMapMoved(event.camera);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.kid_loop',
                tileProvider: NetworkTileProvider(),
                errorImage: const AssetImage('assets/no_tile.png'),
              ),
              MarkerLayer(
                markers: [
                  ..._buildClusteredMarkers(),
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 44,
                      height: 44,
                      child: _buildUserLocationMarker(),
                    ),
                ],
              ),
            ],
          ),

          // ---------------------------------------------------------------
          // ВЕРХНЯЯ ПАНЕЛЬ
          // ---------------------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildLocationCard(),
                        ),
                        const SizedBox(width: 8),
                        _buildFloatingButton(
                          icon: Icons.my_location_rounded,
                          color: _blueColor,
                          onTap: _centerOnUser,
                        ),
                        const SizedBox(width: 8),
                        _buildFloatingButton(
                          icon: Icons.add_location_alt_outlined,
                          color: _accentColor,
                          onTap: _onCreateMarkerButtonPressed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    _buildCategoryBar(),
                  ],
                ),
              ),
            ),
          ),

          // ---------------------------------------------------------------
          // OFFLINE
          // ---------------------------------------------------------------
          if (_isOffline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: _buildOfflineBanner(),
                ),
              ),
            ),

          // ---------------------------------------------------------------
          // ОБНОВЛЕНИЕ
          // ---------------------------------------------------------------
          if (_isRefreshing)
            Positioned(
              top: 74,
              right: 68,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(7),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(_accentColor),
                ),
              ),
            ),

          // ---------------------------------------------------------------
          // SELECTED ITEM
          // ---------------------------------------------------------------
          if (_selectedItem != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: _buildSelectedItemCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return GestureDetector(
      onTap: _centerOnUser,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: 16,
            sigmaY: 16,
          ),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _surfaceColor.withOpacity(_isDarkMode ? 0.88 : 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(_isDarkMode ? 0.22 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _greenColor.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: _greenColor,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _centerAddress.isNotEmpty
                            ? _centerAddress
                            : 'Ваше местоположение',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Нажмите, чтобы вернуться',
                        style: TextStyle(
                          color: _tertiaryTextColor,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _tertiaryTextColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      height: 43,
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(_isDarkMode ? 0.90 : 0.94),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.16 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 5,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 3),
        itemBuilder: (context, index) {
          final category = _categories[index];

          final selected = (_selectedCategory == null &&
              category == 'Все') ||
              _selectedCategory == category;

          return GestureDetector(
            onTap: () {
              if (!_isDisposed && mounted) {
                setState(() {
                  _selectedCategory =
                  category == 'Все' ? null : category;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: selected ? _accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: selected ? Colors.white : _subTextColor,
                  fontSize: 10.5,
                  fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9F0A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9F0A).withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Нет подключения к интернету',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: _refreshDataSilently,
            child: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _surfaceColor.withOpacity(0.92),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDarkMode ? 0.18 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: color,
          size: 21,
        ),
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _blueColor.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: _blueColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: _blueColor.withOpacity(0.45),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedItemCard() {
    final item = _selectedItem!;

    final color = _categoryColor(item.category);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: () async {
          final selected = _selectedItem!;

          setState(() {
            _selectedItem = null;
          });

          final prefs = await SharedPreferences.getInstance();

          final currentUserId = prefs.getString('user_id') ?? '';

          if (selected.ownerId == currentUserId &&
              selected.ownerId.isNotEmpty) {
            if (!mounted) return;

            showDialog(
              context: context,
              builder: (ctx) {
                return _ModernDialog(
                  isDarkMode: _isDarkMode,
                  icon: Icons.info_outline_rounded,
                  color: _accentColor,
                  title: 'Это ваша вещь',
                  message: 'Предложить обмен самому себе нельзя.',
                  secondaryText: 'Закрыть',
                  primaryText: 'Открыть',
                  onSecondary: () => Navigator.pop(ctx),
                  onPrimary: () {
                    Navigator.pop(ctx);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ItemDetailsScreen(item: selected),
                      ),
                    );
                  },
                );
              },
            );
          } else {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemDetailsScreen(item: selected),
                ),
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color:
                Colors.black.withOpacity(_isDarkMode ? 0.22 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: _buildCircleImageWidget(
                  item.imagePath,
                  color,
                  54,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '${item.sv} SV',
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.category.isNotEmpty
                          ? item.category
                          : 'Вещь для обмена',
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 10.5,
                      ),
                    ),
                    if (item.isMine)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Ваша вещь',
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  if (!mounted || _isDisposed) return;

                  setState(() {
                    _selectedItem = null;
                  });
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: _tertiaryTextColor,
                  size: 19,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODERN DIALOG
// ============================================================================
class _ModernDialog extends StatelessWidget {
  final bool isDarkMode;
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String secondaryText;
  final String primaryText;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;

  const _ModernDialog({
    required this.isDarkMode,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.secondaryText,
    required this.primaryText,
    required this.onSecondary,
    required this.onPrimary,
  });

  Color get surfaceColor =>
      isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;

  Color get textColor =>
      isDarkMode ? Colors.white : const Color(0xFF111111);

  Color get subTextColor =>
      isDarkMode ? const Color(0xFF98989F) : const Color(0xFF6F6F76);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 13, 22, 0),
      actionsPadding: const EdgeInsets.fromLTRB(13, 8, 13, 13),
      title: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 27,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: subTextColor,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: onSecondary,
          child: Text(
            secondaryText,
            style: TextStyle(
              color: subTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: onPrimary,
          child: Text(
            primaryText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CLUSTER SHEET
// ============================================================================
class _ClusterSheet extends StatelessWidget {
  final List<Item> items;
  final bool isDarkMode;
  final Color accentColor;
  final void Function(Item item) onItemTap;
  final Widget Function(
      String path,
      Color fallbackColor,
      double size,
      ) imageBuilder;
  final Color Function(String category) categoryColor;

  const _ClusterSheet({
    required this.items,
    required this.isDarkMode,
    required this.accentColor,
    required this.onItemTap,
    required this.imageBuilder,
    required this.categoryColor,
  });

  Color get surfaceColor =>
      isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;

  Color get textColor =>
      isDarkMode ? Colors.white : const Color(0xFF111111);

  Color get subTextColor =>
      isDarkMode ? const Color(0xFF98989F) : const Color(0xFF6F6F76);

  Color get borderColor => isDarkMode
      ? Colors.white.withOpacity(0.07)
      : Colors.black.withOpacity(0.06);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: subTextColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: accentColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Рядом с вами',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${items.length} ${_itemWord(items.length)}',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    final color = categoryColor(item.category);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onItemTap(item),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFF8F8FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              imageBuilder(item.imagePath, color, 45),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.sv} SV${item.category.isNotEmpty ? ' · ${item.category}' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: subTextColor,
                                size: 19,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }

  String _itemWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'вещь';
    }

    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'вещи';
    }

    return 'вещей';
  }
}

// ============================================================================
// MARKER INFO SHEET
// ============================================================================
class _MarkerInfoSheet extends StatelessWidget {
  final MapMarker marker;
  final bool isDarkMode;
  final Color color;
  final String typeLabel;
  final String emoji;
  final VoidCallback onClose;

  const _MarkerInfoSheet({
    required this.marker,
    required this.isDarkMode,
    required this.color,
    required this.typeLabel,
    required this.emoji,
    required this.onClose,
  });

  Color get surfaceColor =>
      isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;

  Color get textColor =>
      isDarkMode ? Colors.white : const Color(0xFF111111);

  Color get subTextColor =>
      isDarkMode ? const Color(0xFF98989F) : const Color(0xFF6F6F76);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subTextColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          marker.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (marker.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  marker.description,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF8F8FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: subTextColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Автор: ${marker.userName.isNotEmpty ? marker.userName : 'Пользователь'}',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    backgroundColor: color.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    'Закрыть',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CREATE MARKER SHEET
// ============================================================================
class _CreateMarkerSheet extends StatefulWidget {
  final LatLng point;
  final bool isDarkMode;
  final Color accentColor;

  const _CreateMarkerSheet({
    required this.point,
    required this.isDarkMode,
    required this.accentColor,
  });

  @override
  State<_CreateMarkerSheet> createState() => _CreateMarkerSheetState();
}

class _CreateMarkerSheetState extends State<_CreateMarkerSheet> {
  String _selectedType = 'announcement';

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const List<Map<String, dynamic>> _types = [
    {
      'type': 'announcement',
      'emoji': '📢',
      'label': 'Объявление',
      'desc': 'Находка или информация',
      'color': Color(0xFF0A84FF),
    },
    {
      'type': 'event',
      'emoji': '🎉',
      'label': 'Событие',
      'desc': 'Праздник или мероприятие',
      'color': Color(0xFFFF9500),
    },
    {
      'type': 'meetup',
      'emoji': '🤝',
      'label': 'Встреча',
      'desc': 'Личный обмен',
      'color': Color(0xFF30D158),
    },
  ];

  Color get _textColor =>
      widget.isDarkMode ? Colors.white : const Color(0xFF111111);

  Color get _subTextColor =>
      widget.isDarkMode ? const Color(0xFF98989F) : const Color(0xFF6F6F76);

  Color get _surfaceColor =>
      widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;

  Color get _fillColor =>
      widget.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF8F8FA);

  Color get _borderColor => widget.isDarkMode
      ? Colors.white.withOpacity(0.07)
      : Colors.black.withOpacity(0.06);

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();

    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      {
        'type': _selectedType,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 18),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _subTextColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_location_alt_outlined,
                      color: widget.accentColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Новая точка',
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Добавьте информацию на карту',
                          style: TextStyle(
                            color: _subTextColor,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.my_location_outlined,
                      color: widget.accentColor,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${widget.point.latitude.toStringAsFixed(4)}, ${widget.point.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: _subTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Тип точки',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _types.map((type) {
                  final selected = _selectedType == type['type'];

                  final color = type['color'] as Color;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: type == _types.last ? 0 : 7,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedType = type['type'] as String;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            vertical: 11,
                            horizontal: 5,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.08)
                                : _fillColor,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: selected ? color : _borderColor,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                type['emoji'] as String,
                                style: const TextStyle(fontSize: 23),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                type['label'] as String,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                  selected ? color : _textColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (selected)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: color,
                                    size: 15,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 13,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите название';
                  }

                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: большой обмен игрушками',
                  labelStyle: TextStyle(
                    color: _subTextColor,
                    fontSize: 12,
                  ),
                  hintStyle: TextStyle(
                    color: _subTextColor.withOpacity(0.45),
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.edit_outlined,
                    color: widget.accentColor,
                    size: 19,
                  ),
                  filled: true,
                  fillColor: _fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: widget.accentColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: 'Описание',
                  hintText: 'Что важно знать другим пользователям',
                  labelStyle: TextStyle(
                    color: _subTextColor,
                    fontSize: 12,
                  ),
                  hintStyle: TextStyle(
                    color: _subTextColor.withOpacity(0.45),
                    fontSize: 12,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Icon(
                      Icons.notes_outlined,
                      color: widget.accentColor,
                      size: 19,
                    ),
                  ),
                  filled: true,
                  fillColor: _fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: widget.accentColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Добавить точку',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TRIANGLE
// ============================================================================
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is TrianglePainter && oldDelegate.color != color;
  }
}