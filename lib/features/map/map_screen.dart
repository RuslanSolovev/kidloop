import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:ui' as ui;

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

  factory MapMarker.fromJson(Map<String, dynamic> json) {
    return MapMarker(
      markerId: json['marker_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }
}

// ============================================================================
// МОДЕЛЬ ДЛЯ ГЕОКОДИРОВАНИЯ
// ============================================================================
class GeocodingCache {
  static final Map<String, LatLng?> _cache = {};

  static LatLng? get(String key) => _cache[key];
  static void set(String key, LatLng? value) => _cache[key] = value;
  static bool has(String key) => _cache.containsKey(key);
  static void clear() => _cache.clear();
}

// ============================================================================
// TOP-LEVEL ФУНКЦИИ ДЛЯ COMPUTE (вне класса!)
// ============================================================================
List<Item> processItemsInBackground(List<dynamic> itemsJson) {
  final items = itemsJson.map((item) => Item(
    itemId: item['item_id'] ?? '',
    ownerId: item['user_id'] ?? '',
    title: item['title'] ?? '',
    description: item['description'] ?? '',
    sv: item['sv'] ?? 0,
    imagePath: item['image_path'] ?? '',
    location: item['location'] ?? '',
    category: item['category'] ?? '',
    condition: item['condition'] ?? '',
    status: item['status'] ?? '',
    latitude: (item['latitude'] ?? 0).toDouble(),
    longitude: (item['longitude'] ?? 0).toDouble(),
  )).toList();

  return items.where((i) => i.hasCoordinates || _getCityCoordsStatic(i.location) != null).toList();
}

List<MapMarker> processMarkersInBackground(List<dynamic> markersJson) {
  return markersJson.map((m) => MapMarker.fromJson(m)).toList();
}

LatLng? _getCityCoordsStatic(String location) {
  if (location.isEmpty) return null;
  final lower = location.toLowerCase().trim();

  // Удаляем лишние символы
  final cleaned = lower.replaceAll(RegExp(r'[^\w\sа-яё-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  // Словарь с координатами
  final cityMap = {
    'москва': const LatLng(55.7558, 37.6173),
    'moscow': const LatLng(55.7558, 37.6173),
    'санкт-петербург': const LatLng(59.9343, 30.3351),
    'питер': const LatLng(59.9343, 30.3351),
    'спб': const LatLng(59.9343, 30.3351),
    'новосибирск': const LatLng(55.0084, 82.9357),
    'екатеринбург': const LatLng(56.8389, 60.6057),
    'казань': const LatLng(55.7961, 49.1064),
    'нижний новгород': const LatLng(56.2965, 43.9361),
    'челябинск': const LatLng(55.1644, 61.4368),
    'самара': const LatLng(53.1959, 50.1002),
    'щёлково': const LatLng(55.9205, 37.9917),
    'щелково': const LatLng(55.9205, 37.9917),
    'фрязино': const LatLng(55.9606, 38.0412),
    'омск': const LatLng(54.9893, 73.3682),
    'ростов-на-дону': const LatLng(47.2357, 39.7015),
    'ростов': const LatLng(47.2357, 39.7015),
    'уфа': const LatLng(54.7388, 55.9721),
    'красноярск': const LatLng(56.0106, 92.8525),
    'воронеж': const LatLng(51.6755, 39.2085),
    'пермь': const LatLng(58.0105, 56.2502),
    'волгоград': const LatLng(48.7080, 44.5133),
    'краснодар': const LatLng(45.0355, 38.9753),
    'саратов': const LatLng(51.5336, 46.0343),
    'тюмень': const LatLng(57.1613, 65.5250),
    'тольятти': const LatLng(53.5303, 49.3461),
    'ижевск': const LatLng(56.8498, 53.2045),
    'барнаул': const LatLng(53.3480, 83.7765),
    'иркутск': const LatLng(52.2869, 104.3050),
    'хабаровск': const LatLng(48.4802, 135.0719),
    'ярославль': const LatLng(57.6261, 39.8845),
    'владивосток': const LatLng(43.1155, 131.8855),
    'махачкала': const LatLng(42.9849, 47.5047),
    'томск': const LatLng(56.4846, 84.9476),
    'оренбург': const LatLng(51.7682, 55.0970),
    'кемерово': const LatLng(55.3549, 86.0873),
    'новокузнецк': const LatLng(53.7557, 87.1099),
    'рига': const LatLng(56.9496, 24.1052),
    'юрмала': const LatLng(56.9681, 23.7566),
    'даугавпилс': const LatLng(55.8751, 26.5320),
  };

  // Прямое совпадение
  if (cityMap.containsKey(cleaned)) {
    return cityMap[cleaned];
  }

  // Поиск по подстроке
  for (final entry in cityMap.entries) {
    if (cleaned.contains(entry.key)) {
      return entry.value;
    }
  }

  // Расширенный поиск для составных названий
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

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
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

  Timer? _refreshTimer;
  Timer? _debounceTimer;
  StreamSubscription? _connectivitySubscription;

  static const List<String> _categories = [
    'Все', 'Игрушки', 'LEGO', 'Самокат', 'Книги', 'Одежда',
    'Коляска', 'Мебель', 'Техника', 'Спорт', 'Развивашки',
    'Творчество', 'Пазлы', 'Конструктор', 'Куклы', 'Машинки',
  ];

  static const String mapApiUrl = 'https://functions.yandexcloud.net/d4e2uh2tj0febumk6e7e';
  static const String itemsApiUrl = 'https://functions.yandexcloud.net/d4ei9an1aushareidmjc';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivityCheck();
    _initAsync();

    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!_isDisposed && mounted && !_isOffline &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        _refreshDataSilently();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _refreshTimer?.cancel();
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isDisposed && mounted && !_isOffline) {
      _refreshDataSilently();
    }
  }

  void _initConnectivityCheck() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOffline = result == ConnectivityResult.none;
      if (isOffline != _isOffline) {
        if (mounted) {
          setState(() {
            _isOffline = isOffline;
          });
          if (!isOffline) {
            _refreshDataSilently();
            if (_userLocation == null && _lastKnownPosition == null) {
              _determinePosition();
            }
          }
        }
      }
    });
  }

  Future<void> _initAsync() async {
    // Проверяем офлайн
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _locationStatus = 'Нет подключения к интернету';
        });
      }
    }

    await _determinePosition();

    if (!_isDisposed && mounted && !_isOffline) {
      await Future.wait([
        _loadItems(),
        _loadCustomMarkers(),
      ]);

      if (mounted) {
        setState(() => _loading = false);
      }
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _determinePosition() async {
    // 1. Пробуем сразу получить последнюю известную позицию (мгновенно)
    try {
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && !_isDisposed && mounted) {
        setState(() {
          _lastKnownPosition = LatLng(lastPosition.latitude, lastPosition.longitude);
          _locationStatus = 'Последнее местоположение загружено';
        });
        // Безопасно двигаем карту
        _safeMoveMap(_lastKnownPosition!, 13);
      }
    } catch (e) {
      debugPrint('Не удалось получить последнюю позицию: $e');
    }

    // 2. Проверяем, включена ли служба геолокации
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted && !_isDisposed) {
        setState(() => _locationStatus = 'Служба геолокации выключена');
        _showLocationSettingsDialog();
      }
      _setDefaultLocation();
      return;
    }

    // 3. Проверяем разрешения
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        if (mounted && !_isDisposed) {
          setState(() => _locationStatus = 'Нет разрешения на геолокацию');
          _showPermissionDeniedDialog();
        }
        _setDefaultLocation();
        return;
      }
    }

    // 4. Пытаемся получить текущую позицию
    try {
      if (mounted && !_isDisposed) {
        setState(() => _locationStatus = 'Ищем точное местоположение...');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(const Duration(seconds: 12));

      if (!_isDisposed && mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _locationStatus = 'Местоположение определено';
        });
        _safeMoveMap(_userLocation!, 14);
      }
    } catch (e) {
      debugPrint('❌ Геолокация ошибка: $e');
      // 5. Если текущая позиция не получена, используем последнюю известную
      if (_lastKnownPosition != null && !_isDisposed && mounted) {
        setState(() {
          _userLocation = _lastKnownPosition;
          _locationStatus = 'Использовано последнее местоположение';
        });
        _safeMoveMap(_userLocation!, 12);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось определить точное местоположение. Показано последнее известное.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // 6. Вообще ничего нет – показываем диалог без ожидания и ставим дефолт
        if (mounted && !_isDisposed) {
          setState(() => _locationStatus = 'Местоположение не найдено');
          _showRetryDialog();
        }
        _setDefaultLocation();
      }
    }
  }

  /// Безопасное перемещение карты (с проверкой инициализации контроллера)
  void _safeMoveMap(LatLng point, double zoom) {
    if (!mounted || _isDisposed) return;

    try {
      // Проверяем, что контроллер карты инициализирован
      // Пытаемся выполнить move с задержкой, чтобы дать карте время на инициализацию
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          try {
            _mapController.move(point, zoom);
          } catch (e) {
            debugPrint('Ошибка перемещения карты: $e');
            // Если не удалось, пробуем ещё раз с задержкой
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && !_isDisposed) {
                try {
                  _mapController.move(point, zoom);
                } catch (e) {
                  debugPrint('Повторная ошибка перемещения карты: $e');
                }
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Критическая ошибка safeMoveMap: $e');
    }
  }

  Future<void> _showLocationSettingsDialog() async {
    if (!mounted || _isDisposed) return;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Геолокация выключена'),
        content: const Text(
          'Для отображения вашего местоположения на карте необходимо включить службу геолокации в настройках устройства.',
        ),
        actions: [
          TextButton(
            child: const Text('Пропустить'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text('Открыть настройки'),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showPermissionDeniedDialog() async {
    if (!mounted || _isDisposed) return;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Разрешение не предоставлено'),
        content: const Text(
          'Для использования карты необходимо разрешить доступ к геолокации в настройках приложения.',
        ),
        actions: [
          TextButton(
            child: const Text('Пропустить'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text('Открыть настройки'),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  void _setDefaultLocation() {
    if (!_isDisposed && mounted) {
      final defaultLoc = _lastKnownPosition ?? const LatLng(55.7558, 37.6173);
      setState(() {
        _userLocation ??= defaultLoc;
      });
    }
  }

  void _showRetryDialog() {
    if (!mounted || _isDisposed) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Не удалось определить местоположение'),
        content: const Text('Проверьте, что GPS включён и устройство находится на открытом воздухе.'),
        actions: [
          TextButton(
            child: const Text('Закрыть'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text('Повторить'),
            onPressed: () {
              Navigator.pop(ctx);
              // Повторный вызов (не рекурсия внутри того же экземпляра)
              if (!_isDisposed && mounted) {
                _determinePosition();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _refreshDataSilently() async {
    if (_isRefreshing || _isOffline) return;
    _isRefreshing = true;

    try {
      final previousItemIds = _items.map((e) => e.itemId).toList();
      final previousMarkerIds = _customMarkers.map((e) => e.markerId).toList();

      await Future.wait([
        _loadItems(),
        _loadCustomMarkers(),
      ]);

      // Проверяем, изменились ли данные
      final currentItemIds = _items.map((e) => e.itemId).toList();
      final currentMarkerIds = _customMarkers.map((e) => e.markerId).toList();

      if (mounted && !_isDisposed) {
        if (!listEquals(previousItemIds, currentItemIds) ||
            !listEquals(previousMarkerIds, currentMarkerIds)) {
          setState(() {}); // Обновляем только если есть изменения
        }
      }
    } catch (e) {
      debugPrint('Ошибка фонового обновления: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadItems() async {
    if (_isDisposed || _isOffline) return;
    try {
      final response = await http.post(
        Uri.parse(itemsApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      ).timeout(const Duration(seconds: 15));

      if (_isDisposed || response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final List<dynamic> itemsList = data['items'];
        final processedItems = await compute(processItemsInBackground, itemsList);

        // Геокодируем те вещи, у которых нет координат и город не распознан
        final itemsNeedGeocoding = processedItems
            .where((item) => !item.hasCoordinates && _getCityCoordsStatic(item.location) == null)
            .toList();

        if (itemsNeedGeocoding.isNotEmpty) {
          await _geocodeItems(itemsNeedGeocoding);
        }

        if (!_isDisposed && mounted) {
          setState(() => _items = processedItems);
        }
      }
    } catch (e) {
      debugPrint('Ошибка загрузки вещей: $e');
    }
  }

  Future<void> _geocodeItems(List<Item> items) async {
    for (final item in items) {
      if (GeocodingCache.has(item.location)) {
        final cached = GeocodingCache.get(item.location);
        if (cached != null) {
          item.setCoordinates(cached.latitude, cached.longitude);
        }
        continue;
      }

      try {
        // Используем Nominatim (бесплатный, но с ограничениями)
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
            final lat = double.parse(results[0]['lat']);
            final lon = double.parse(results[0]['lon']);
            final coords = LatLng(lat, lon);
            GeocodingCache.set(item.location, coords);
            item.setCoordinates(lat, lon);
          } else {
            GeocodingCache.set(item.location, null);
          }
        }

        // Задержка для соблюдения лимитов Nominatim (1 запрос в секунду)
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('Ошибка геокодирования "${item.location}": $e');
        GeocodingCache.set(item.location, null);
      }
    }
  }

  Future<void> _loadCustomMarkers() async {
    if (_isDisposed || _isOffline) return;
    try {
      final response = await http.post(
        Uri.parse(mapApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      ).timeout(const Duration(seconds: 15));

      if (_isDisposed || response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final List<dynamic> markersList = data['markers'];
        final processedMarkers = await compute(processMarkersInBackground, markersList);

        if (!_isDisposed && mounted) {
          setState(() => _customMarkers = processedMarkers);
        }
      }
    } catch (e) {
      debugPrint('Ошибка загрузки маркеров: $e');
    }
  }

// Найти в классе _MapScreenState и заменить метод _getItemCoordinates
  LatLng? _getItemCoordinates(Item item) {
    // 1. Сначала проверяем, есть ли у item прямые координаты (из БД)
    if (item.hasCoordinates && item.coordinates != null) {
      return item.coordinates;
    }

    // 2. Если прямых координат нет, ищем по названию города
    return _getCityCoordsStatic(item.location);
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Игрушки': return Colors.orange;
      case 'LEGO': return Colors.yellow.shade700;
      case 'Самокат': return Colors.green;
      case 'Книги': return Colors.blue;
      case 'Одежда': return Colors.purple;
      case 'Коляска': return Colors.teal;
      case 'Мебель': return Colors.brown;
      case 'Техника': return Colors.blueGrey;
      case 'Спорт': return Colors.red;
      case 'Развивашки': return Colors.pink;
      case 'Творчество': return Colors.deepOrange;
      case 'Пазлы': return Colors.indigo;
      case 'Конструктор': return Colors.amber;
      case 'Куклы': return Colors.pinkAccent.shade200;
      case 'Машинки': return Colors.lightBlue;
      default: return Colors.blue;
    }
  }

  Color _markerTypeColor(String type) {
    switch (type) {
      case 'announcement': return Colors.blue;
      case 'event': return Colors.orange;
      case 'meetup': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _markerTypeEmoji(String type) {
    switch (type) {
      case 'announcement': return '📢';
      case 'event': return '🎉';
      case 'meetup': return '🤝';
      default: return '📍';
    }
  }

  List<Item> get _filteredItems {
    if (_selectedCategory == null || _selectedCategory == 'Все') return _items;
    return _items.where((i) => i.category == _selectedCategory).toList();
  }

  // Круглая иконка для изображения
  Widget _buildCircleImageWidget(String path, Color fallbackColor, double size) {
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
                color: fallbackColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.toys, color: fallbackColor, size: size * 0.5),
            );
          },
          errorBuilder: (context, url, error) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fallbackColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.broken_image, color: fallbackColor, size: size * 0.5),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.toys, color: fallbackColor, size: size * 0.5),
    );
  }

  List<Marker> _buildClusteredMarkers() {
    if (_isDisposed) return [];
    final markers = <Marker>[];
    final items = _filteredItems;

    // Группируем вещи по координатам
    final groups = <String, List<Item>>{};
    for (final item in items) {
      final coords = _getItemCoordinates(item);
      if (coords == null) continue;
      final key = '${coords.latitude.toStringAsFixed(3)}_${coords.longitude.toStringAsFixed(3)}';
      groups.putIfAbsent(key, () => []).add(item);
    }

    for (final entry in groups.entries) {
      final groupItems = entry.value;
      final avgLat = groupItems
          .map((i) => _getItemCoordinates(i)!.latitude)
          .reduce((a, b) => a + b) / groupItems.length;
      final avgLon = groupItems
          .map((i) => _getItemCoordinates(i)!.longitude)
          .reduce((a, b) => a + b) / groupItems.length;
      final point = LatLng(avgLat, avgLon);

      if (groupItems.length > 1) {
        // Кластер
        markers.add(Marker(
          point: point,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _showClusterDialog(groupItems),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              alignment: Alignment.center,
              child: Text(
                '${groupItems.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ));
      } else {
        final item = groupItems.first;
        final color = _categoryColor(item.category);

        markers.add(Marker(
          point: point,
          width: 70,
          height: 90,
          rotate: true,
          child: GestureDetector(
            onTap: () {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  _mapController.move(point, 15);
                  setState(() => _selectedItem = item);
                }
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: _buildCircleImageWidget(item.imagePath, color, 50),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${item.sv} SV',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CustomPaint(
                  size: const Size(16, 8),
                  painter: TrianglePainter(color: color),
                ),
              ],
            ),
          ),
        ));
      }
    }

    // Добавляем пользовательские маркеры
    for (final marker in _customMarkers) {
      final color = _markerTypeColor(marker.type);
      markers.add(Marker(
        point: LatLng(marker.latitude, marker.longitude),
        width: 60,
        height: 80,
        rotate: true,
        child: GestureDetector(
          onTap: () => _showMarkerInfo(marker),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Center(
                  child: Text(
                    _markerTypeEmoji(marker.type),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  marker.type == 'announcement'
                      ? 'Объявление'
                      : (marker.type == 'event' ? 'Событие' : 'Встреча'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(16, 8),
                painter: TrianglePainter(color: color),
              ),
            ],
          ),
        ),
      ));
    }

    return markers;
  }

  void _showClusterDialog(List<Item> items) {
    if (_isDisposed) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Вещи рядом (${items.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return ListTile(
                    leading: _buildCircleImageWidget(
                      item.imagePath,
                      _categoryColor(item.category),
                      40,
                    ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${item.sv} SV • ${item.category}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemDetailsScreen(item: item),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarkerInfo(MapMarker marker) {
    if (_isDisposed) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_markerTypeEmoji(marker.type), style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    marker.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (marker.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                marker.description,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 12),
            Text('Автор: ${marker.userName}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateMarkerDialog(LatLng point) async {
    if (_isDisposed || _isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет подключения к интернету')),
        );
      }
      return;
    }

    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Тип маркера'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('📢', style: TextStyle(fontSize: 28)),
              title: const Text('Объявление'),
              onTap: () => Navigator.pop(ctx, 'announcement'),
            ),
            ListTile(
              leading: const Text('🎉', style: TextStyle(fontSize: 28)),
              title: const Text('Событие'),
              onTap: () => Navigator.pop(ctx, 'event'),
            ),
            ListTile(
              leading: const Text('🤝', style: TextStyle(fontSize: 28)),
              title: const Text('Встреча'),
              onTap: () => Navigator.pop(ctx, 'meetup'),
            ),
          ],
        ),
      ),
    );

    if (type == null || !mounted || _isDisposed) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Создать ${_markerTypeEmoji(type)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Введите название')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted || _isDisposed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final userName = prefs.getString('user_name') ?? '';

      if (userId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Необходимо войти в профиль')),
          );
        }
        return;
      }

      final response = await http.post(
        Uri.parse(mapApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "create",
          "user_id": userId,
          "user_name": userName,
          "type": type,
          "title": titleCtrl.text.trim(),
          "description": descCtrl.text.trim(),
          "latitude": point.latitude,
          "longitude": point.longitude,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _loadCustomMarkers();
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Маркер создан!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Ошибка сервера');
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onCreateMarkerButtonPressed() {
    final center = _mapController.center;
    _showCreateMarkerDialog(center);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_locationStatus),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Карта
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? _lastKnownPosition ?? const LatLng(55.7558, 37.6173),
            initialZoom: 10,
            minZoom: 4,
            maxZoom: 18,
            onLongPress: (tapPosition, point) {
              _showCreateMarkerDialog(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.kid_loop',
              // Кэширование тайлов
              tileProvider: NetworkTileProvider(),
              // Резервный провайдер
              errorImage: const AssetImage('assets/no_tile.png'),
            ),
            MarkerLayer(
              markers: [
                ..._buildClusteredMarkers(),
                // Маркер местоположения пользователя
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.blue, blurRadius: 8),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Офлайн-сообщение
        if (_isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Нет подключения к интернету',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Статус геолокации
        if (!_isOffline)
          Positioned(
            top: _isOffline ? 45 : 0,
            left: 0,
            right: 0,
            child: Container(
              color: _userLocation != null
                  ? Colors.green.withOpacity(0.9)
                  : Colors.orange.withOpacity(0.9),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Text(
                _locationStatus,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Фильтр категорий
        Positioned(
          top: 50,
          left: 10,
          right: 10,
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat ||
                    (_selectedCategory == null && cat == 'Все');
                return FilterChip(
                  label: Text(
                    cat,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    if (!_isDisposed && mounted) {
                      setState(() => _selectedCategory = cat == 'Все' ? null : cat);
                    }
                  },
                  backgroundColor: Colors.transparent,
                  selectedColor: Colors.orange.shade100,
                  checkmarkColor: Colors.orange,
                  side: BorderSide(
                    color: isSelected ? Colors.orange : Colors.grey.shade300,
                  ),
                );
              },
            ),
          ),
        ),

        // Кнопки управления
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'add_marker_btn',
                onPressed: _onCreateMarkerButtonPressed,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                tooltip: 'Создать маркер',
                child: const Icon(Icons.add_location_alt),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.small(
                heroTag: 'location_btn',
                onPressed: () {
                  if (_userLocation != null) {
                    _mapController.move(_userLocation!, 15);
                  } else {
                    _determinePosition();
                  }
                },
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                tooltip: 'Моё местоположение',
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.small(
                heroTag: 'refresh_btn',
                onPressed: _isOffline ? null : () => _refreshDataSilently(),
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                tooltip: 'Обновить',
                child: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),

        // Карточка выбранной вещи
        if (_selectedItem != null)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(16),
              elevation: 8,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final item = _selectedItem!;
                  setState(() => _selectedItem = null);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ItemDetailsScreen(item: item),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildCircleImageWidget(
                        _selectedItem!.imagePath,
                        _categoryColor(_selectedItem!.category),
                        50,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedItem!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedItem!.sv} SV • ${_selectedItem!.category}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          if (mounted && !_isDisposed) {
                            setState(() => _selectedItem = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Индикатор загрузки при обновлении
        if (_isRefreshing)
          const Positioned(
            top: 10,
            right: 60,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is TrianglePainter && oldDelegate.color != color;
}