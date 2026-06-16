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
// КЭШ ГЕОКОДИРОВАНИЯ
// ============================================================================
class GeocodingCache {
  static final Map<String, LatLng?> _cache = {};
  static LatLng? get(String key) => _cache[key];
  static void set(String key, LatLng? value) => _cache[key] = value;
  static bool has(String key) => _cache.containsKey(key);
  static void clear() => _cache.clear();
}

// ============================================================================
// TOP-LEVEL ФУНКЦИИ ДЛЯ COMPUTE
// ============================================================================
List<Item> processItemsInBackground(List<dynamic> itemsJson) {
  final items = itemsJson.map((item) => Item(
    itemId: item['item_id'] ?? '', ownerId: item['user_id'] ?? '',
    title: item['title'] ?? '', description: item['description'] ?? '',
    sv: item['sv'] ?? 0, imagePath: item['image_path'] ?? '',
    location: item['location'] ?? '', category: item['category'] ?? '',
    condition: item['condition'] ?? '', status: item['status'] ?? '',
    latitude: (item['latitude'] ?? 0).toDouble(), longitude: (item['longitude'] ?? 0).toDouble(),
  )).toList();
  return items.where((i) => i.hasCoordinates || _getCityCoordsStatic(i.location) != null).toList();
}

List<MapMarker> processMarkersInBackground(List<dynamic> markersJson) {
  return markersJson.map((m) => MapMarker.fromJson(m)).toList();
}

LatLng? _getCityCoordsStatic(String location) {
  if (location.isEmpty) return null;
  final lower = location.toLowerCase().trim();
  final cleaned = lower.replaceAll(RegExp(r'[^\w\sа-яё-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final cityMap = {
    'москва': const LatLng(55.7558, 37.6173), 'moscow': const LatLng(55.7558, 37.6173),
    'санкт-петербург': const LatLng(59.9343, 30.3351), 'питер': const LatLng(59.9343, 30.3351), 'спб': const LatLng(59.9343, 30.3351),
    'новосибирск': const LatLng(55.0084, 82.9357), 'екатеринбург': const LatLng(56.8389, 60.6057),
    'казань': const LatLng(55.7961, 49.1064), 'нижний новгород': const LatLng(56.2965, 43.9361),
    'челябинск': const LatLng(55.1644, 61.4368), 'самара': const LatLng(53.1959, 50.1002),
    'щёлково': const LatLng(55.9205, 37.9917), 'щелково': const LatLng(55.9205, 37.9917),
    'фрязино': const LatLng(55.9606, 38.0412), 'омск': const LatLng(54.9893, 73.3682),
    'ростов-на-дону': const LatLng(47.2357, 39.7015), 'ростов': const LatLng(47.2357, 39.7015),
    'уфа': const LatLng(54.7388, 55.9721), 'красноярск': const LatLng(56.0106, 92.8525),
    'воронеж': const LatLng(51.6755, 39.2085), 'пермь': const LatLng(58.0105, 56.2502),
    'волгоград': const LatLng(48.7080, 44.5133), 'краснодар': const LatLng(45.0355, 38.9753),
    'саратов': const LatLng(51.5336, 46.0343), 'тюмень': const LatLng(57.1613, 65.5250),
    'тольятти': const LatLng(53.5303, 49.3461), 'ижевск': const LatLng(56.8498, 53.2045),
    'барнаул': const LatLng(53.3480, 83.7765), 'иркутск': const LatLng(52.2869, 104.3050),
    'хабаровск': const LatLng(48.4802, 135.0719), 'ярославль': const LatLng(57.6261, 39.8845),
    'владивосток': const LatLng(43.1155, 131.8855), 'махачкала': const LatLng(42.9849, 47.5047),
    'томск': const LatLng(56.4846, 84.9476), 'оренбург': const LatLng(51.7682, 55.0970),
    'кемерово': const LatLng(55.3549, 86.0873), 'новокузнецк': const LatLng(53.7557, 87.1099),
    'рига': const LatLng(56.9496, 24.1052), 'юрмала': const LatLng(56.9681, 23.7566),
    'даугавпилс': const LatLng(55.8751, 26.5320),
  };
  if (cityMap.containsKey(cleaned)) return cityMap[cleaned];
  for (final entry in cityMap.entries) { if (cleaned.contains(entry.key)) return entry.value; }
  if (cleaned.contains('нижн') && cleaned.contains('новгород')) return const LatLng(56.2965, 43.9361);
  if (cleaned.contains('санкт') && cleaned.contains('петербург')) return const LatLng(59.9343, 30.3351);
  if (cleaned.contains('ростов') && cleaned.contains('дон')) return const LatLng(47.2357, 39.7015);
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
  String _centerAddress = '';
  LatLng? _lastGeocodedCenter;
  Timer? _geocodeDebounce;
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
      if (!_isDisposed && mounted && !_isOffline && WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        _refreshDataSilently();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _refreshTimer?.cancel(); _debounceTimer?.cancel(); _geocodeDebounce?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isDisposed && mounted && !_isOffline) _refreshDataSilently();
  }

  void _initConnectivityCheck() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOffline = result == ConnectivityResult.none;
      if (isOffline != _isOffline && mounted) {
        setState(() => _isOffline = isOffline);
        if (!isOffline) { _refreshDataSilently(); if (_userLocation == null && _lastKnownPosition == null) _determinePosition(); }
      }
    });
  }

  Future<void> _initAsync() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none && mounted) setState(() { _isOffline = true; _locationStatus = 'Нет подключения к интернету'; });
    await _determinePosition();
    if (!_isDisposed && mounted && !_isOffline) { await Future.wait([_loadItems(), _loadCustomMarkers()]); if (mounted) setState(() => _loading = false); }
    else if (mounted) setState(() => _loading = false);
  }

  Future<void> _determinePosition() async {
    // Пробуем последнюю известную позицию
    try {
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && !_isDisposed && mounted) {
        final pos = LatLng(lastPosition.latitude, lastPosition.longitude);
        setState(() { _lastKnownPosition = pos; _locationStatus = 'Последнее местоположение'; });
        _safeMoveMap(pos, 13); _geocodeCenter(pos);
      }
    } catch (e) { debugPrint('Last position error: $e'); }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted && !_isDisposed) { setState(() => _locationStatus = 'Служба геолокации выключена'); _showLocationSettingsDialog(); }
      _setDefaultLocation(); return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        if (mounted && !_isDisposed) { setState(() => _locationStatus = 'Нет разрешения'); _showPermissionDeniedDialog(); }
        _setDefaultLocation(); return;
      }
    }

    // 🔥 Пытаемся получить позицию с большим таймаутом
    try {
      if (mounted && !_isDisposed) setState(() => _locationStatus = 'Ищем местоположение...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // 🔥 medium вместо high - быстрее
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 18));

      if (!_isDisposed && mounted && position != null) {
        final userLoc = LatLng(position.latitude, position.longitude);
        setState(() { _userLocation = userLoc; _locationStatus = 'Местоположение определено'; });
        _safeMoveMap(userLoc, 14); _geocodeCenter(userLoc);
        return; // 🔥 Успешно - выходим
      }
    } catch (e) {
      debugPrint('GPS error: $e');
    }

    // 🔥 Если не удалось получить текущую позицию, используем последнюю известную
    if (_lastKnownPosition != null && !_isDisposed && mounted) {
      setState(() { _userLocation = _lastKnownPosition; _locationStatus = 'Последнее местоположение'; });
      _safeMoveMap(_userLocation!, 12); _geocodeCenter(_userLocation!);
    } else {
      if (mounted && !_isDisposed) { setState(() => _locationStatus = 'Местоположение не найдено'); }
      _setDefaultLocation();
    }
  }

  void _onMapMoved(MapCamera camera) {
    final center = camera.center;
    if (_lastGeocodedCenter != null) {
      final distance = const Distance().as(LengthUnit.Meter, _lastGeocodedCenter!, center);
      if (distance < 300) return; // 🔥 Порог 300м
    }
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 600), () => _geocodeCenter(center));
  }

  Future<void> _geocodeCenter(LatLng point) async {
    if (_isDisposed) return;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(), 'lon': point.longitude.toString(),
        'format': 'json', 'accept-language': 'ru', 'zoom': '18', // 🔥 zoom 18 = улица
      });
      final response = await http.get(uri, headers: {'User-Agent': 'KidLoop/1.0'}).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted && !_isDisposed) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final road = address['road'] ?? address['pedestrian'] ?? address['footway'] ?? address['path'] ?? '';
          final house = address['house_number'] ?? '';
          final suburb = address['suburb'] ?? address['neighbourhood'] ?? '';
          final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
          final state = address['state'] ?? '';

          final parts = <String>[];
          // 🔥 Улица + дом
          if (road.isNotEmpty) {
            parts.add(house.isNotEmpty ? '$road, $house' : road);
          }
          // 🔥 Район
          if (suburb.isNotEmpty) parts.add(suburb);
          // 🔥 Город
          if (city.isNotEmpty) {
            parts.add(city);
          } else if (state.isNotEmpty) {
            parts.add(state);
          }

          final shortAddress = parts.join(', ');
          if (shortAddress.isNotEmpty) {
            setState(() { _centerAddress = shortAddress; _lastGeocodedCenter = point; });
          }
        }
      }
    } catch (e) { debugPrint('Geocode error: $e'); }
  }

  void _safeMoveMap(LatLng point, double zoom) {
    if (!mounted || _isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) { try { _mapController.move(point, zoom); } catch (e) {} }
    });
  }

  Future<void> _showLocationSettingsDialog() async {
    if (!mounted || _isDisposed) return;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: const Text('Геолокация выключена'),
      content: const Text('Включите службу геолокации в настройках устройства.'),
      actions: [
        TextButton(child: const Text('Пропустить'), onPressed: () => Navigator.pop(ctx)),
        ElevatedButton(child: const Text('Настройки'), onPressed: () { Navigator.pop(ctx); Geolocator.openLocationSettings(); }),
      ],
    ));
  }

  Future<void> _showPermissionDeniedDialog() async {
    if (!mounted || _isDisposed) return;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: const Text('Нет доступа'),
      content: const Text('Разрешите доступ к геолокации в настройках приложения.'),
      actions: [
        TextButton(child: const Text('Пропустить'), onPressed: () => Navigator.pop(ctx)),
        ElevatedButton(child: const Text('Настройки'), onPressed: () { Navigator.pop(ctx); Geolocator.openAppSettings(); }),
      ],
    ));
  }

  void _setDefaultLocation() {
    if (!_isDisposed && mounted) {
      final defaultLoc = _lastKnownPosition ?? const LatLng(55.7558, 37.6173);
      setState(() { _userLocation ??= defaultLoc; _centerAddress = 'Москва'; });
    }
  }

  void _showRetryDialog() {
    if (!mounted || _isDisposed) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Не удалось определить местоположение'),
      content: const Text('Проверьте GPS и подключение к интернету.'),
      actions: [
        TextButton(child: const Text('Закрыть'), onPressed: () => Navigator.pop(ctx)),
        ElevatedButton(child: const Text('Повторить'), onPressed: () { Navigator.pop(ctx); if (!_isDisposed && mounted) _determinePosition(); }),
      ],
    ));
  }

  Future<void> _refreshDataSilently() async {
    if (_isRefreshing || _isOffline) return;
    _isRefreshing = true;
    try { await Future.wait([_loadItems(), _loadCustomMarkers()]); if (mounted && !_isDisposed) setState(() {}); }
    catch (e) { debugPrint('Refresh error: $e'); } finally { _isRefreshing = false; }
  }

  Future<void> _loadItems() async {
    if (_isDisposed || _isOffline) return;
    try {
      final response = await http.post(Uri.parse(itemsApiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"action": "list"})).timeout(const Duration(seconds: 15));
      if (_isDisposed || response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final List<dynamic> itemsList = data['items'];
        final prefs = await SharedPreferences.getInstance();
        final currentUserId = prefs.getString('user_id') ?? '';
        final processedItems = itemsList.map((item) => Item(
          itemId: item['item_id'] ?? '', ownerId: item['user_id'] ?? '',
          title: item['title'] ?? '', description: item['description'] ?? '',
          sv: item['sv'] ?? 0, imagePath: item['image_path'] ?? '',
          location: item['location'] ?? '', category: item['category'] ?? '',
          condition: item['condition'] ?? '', status: item['status'] ?? '',
          isMine: item['user_id'] == currentUserId,
          latitude: (item['latitude'] ?? 0).toDouble(), longitude: (item['longitude'] ?? 0).toDouble(),
        )).where((i) => i.hasCoordinates || _getCityCoordsStatic(i.location) != null).toList();
        final itemsNeedGeocoding = processedItems.where((item) => !item.hasCoordinates && _getCityCoordsStatic(item.location) == null).toList();
        if (itemsNeedGeocoding.isNotEmpty) await _geocodeItems(itemsNeedGeocoding);
        if (!_isDisposed && mounted) setState(() => _items = processedItems);
      }
    } catch (e) { debugPrint('Load items error: $e'); }
  }

  Future<void> _geocodeItems(List<Item> items) async {
    for (final item in items) {
      if (GeocodingCache.has(item.location)) { final cached = GeocodingCache.get(item.location); if (cached != null) item.setCoordinates(cached.latitude, cached.longitude); continue; }
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {'q': item.location, 'format': 'json', 'limit': '1', 'countrycodes': 'ru,lv'});
        final response = await http.get(uri, headers: {'User-Agent': 'KidLoop/1.0', 'Accept-Language': 'ru'}).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final results = jsonDecode(response.body) as List;
          if (results.isNotEmpty) {
            final lat = double.parse(results[0]['lat']); final lon = double.parse(results[0]['lon']);
            GeocodingCache.set(item.location, LatLng(lat, lon)); item.setCoordinates(lat, lon);
          } else { GeocodingCache.set(item.location, null); }
        }
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) { GeocodingCache.set(item.location, null); }
    }
  }

  Future<void> _loadCustomMarkers() async {
    if (_isDisposed || _isOffline) return;
    try {
      final response = await http.post(Uri.parse(mapApiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"action": "list"})).timeout(const Duration(seconds: 15));
      if (_isDisposed || response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final List<dynamic> markersList = data['markers'];
        final processedMarkers = await compute(processMarkersInBackground, markersList);
        if (!_isDisposed && mounted) setState(() => _customMarkers = processedMarkers);
      }
    } catch (e) { debugPrint('Load markers error: $e'); }
  }

  LatLng? _getItemCoordinates(Item item) {
    if (item.hasCoordinates && item.coordinates != null) return item.coordinates;
    return _getCityCoordsStatic(item.location);
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Игрушки': return Colors.orange; case 'LEGO': return Colors.yellow.shade700;
      case 'Самокат': return Colors.green; case 'Книги': return Colors.blue;
      case 'Одежда': return Colors.purple; case 'Коляска': return Colors.teal;
      case 'Мебель': return Colors.brown; case 'Техника': return Colors.blueGrey;
      case 'Спорт': return Colors.red; case 'Развивашки': return Colors.pink;
      case 'Творчество': return Colors.deepOrange; case 'Пазлы': return Colors.indigo;
      case 'Конструктор': return Colors.amber; case 'Куклы': return Colors.pinkAccent.shade200;
      case 'Машинки': return Colors.lightBlue; default: return Colors.blue;
    }
  }

  Color _markerTypeColor(String type) {
    switch (type) { case 'announcement': return Colors.blue; case 'event': return Colors.orange; case 'meetup': return Colors.green; default: return Colors.grey; }
  }

  String _markerTypeEmoji(String type) {
    switch (type) { case 'announcement': return '📢'; case 'event': return '🎉'; case 'meetup': return '🤝'; default: return '📍'; }
  }

  List<Item> get _filteredItems {
    if (_selectedCategory == null || _selectedCategory == 'Все') return _items;
    return _items.where((i) => i.category == _selectedCategory).toList();
  }

  Widget _buildCircleImageWidget(String path, Color fallbackColor, double size) {
    if (path.startsWith('http')) {
      return ClipOval(child: Image.network(path, width: size, height: size, fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(width: size, height: size, decoration: BoxDecoration(color: fallbackColor.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.toys, color: fallbackColor, size: size * 0.5));
        },
        errorBuilder: (context, url, error) => Container(width: size, height: size, decoration: BoxDecoration(color: fallbackColor.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.broken_image, color: fallbackColor, size: size * 0.5)),
      ));
    }
    return Container(width: size, height: size, decoration: BoxDecoration(color: fallbackColor.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.toys, color: fallbackColor, size: size * 0.5));
  }

  List<Marker> _buildClusteredMarkers() {
    if (_isDisposed) return [];
    final markers = <Marker>[];
    final items = _filteredItems;
    final groups = <String, List<Item>>{};
    for (final item in items) {
      final coords = _getItemCoordinates(item);
      if (coords == null) continue;
      final key = '${coords.latitude.toStringAsFixed(3)}_${coords.longitude.toStringAsFixed(3)}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    for (final entry in groups.entries) {
      final groupItems = entry.value;
      final avgLat = groupItems.map((i) => _getItemCoordinates(i)!.latitude).reduce((a, b) => a + b) / groupItems.length;
      final avgLon = groupItems.map((i) => _getItemCoordinates(i)!.longitude).reduce((a, b) => a + b) / groupItems.length;
      final point = LatLng(avgLat, avgLon);
      if (groupItems.length > 1) {
        markers.add(Marker(point: point, width: 50, height: 50, child: GestureDetector(
          onTap: () => _showClusterDialog(groupItems),
          child: Container(decoration: BoxDecoration(color: Colors.red.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]), alignment: Alignment.center, child: Text('${groupItems.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
        )));
      } else {
        final item = groupItems.first;
        final color = _categoryColor(item.category);
        markers.add(Marker(point: point, width: 70, height: 90, rotate: true, child: GestureDetector(
          onTap: () { _debounceTimer?.cancel(); _debounceTimer = Timer(const Duration(milliseconds: 300), () { if (mounted) { _mapController.move(point, 15); setState(() => _selectedItem = item); } }); },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: item.isMine ? Border.all(color: Colors.orange, width: 3) : null, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: Stack(children: [
              _buildCircleImageWidget(item.imagePath, color, 50),
              if (item.isMine) Positioned(bottom: 0, right: 0, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.person, size: 10, color: Colors.white))),
            ])),
            const SizedBox(height: 2),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Text('${item.sv} SV', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
            CustomPaint(size: const Size(16, 8), painter: TrianglePainter(color: color)),
          ]),
        )));
      }
    }
    for (final marker in _customMarkers) {
      final color = _markerTypeColor(marker.type);
      markers.add(Marker(point: LatLng(marker.latitude, marker.longitude), width: 60, height: 80, rotate: true, child: GestureDetector(
        onTap: () => _showMarkerInfo(marker),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: Center(child: Text(_markerTypeEmoji(marker.type), style: const TextStyle(fontSize: 24)))),
          const SizedBox(height: 2),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Text(marker.type == 'announcement' ? 'Объявление' : (marker.type == 'event' ? 'Событие' : 'Встреча'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
          CustomPaint(size: const Size(16, 8), painter: TrianglePainter(color: color)),
        ]),
      )));
    }
    return markers;
  }

  void _showClusterDialog(List<Item> items) {
    if (_isDisposed) return;
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
      builder: (_, controller) => Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('Вещи рядом (${items.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        Expanded(child: ListView.builder(controller: controller, itemCount: items.length, itemBuilder: (_, i) {
          final item = items[i];
          return ListTile(leading: _buildCircleImageWidget(item.imagePath, _categoryColor(item.category), 40), title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${item.sv} SV • ${item.category}'), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item))); });
        })),
      ]),
    ));
  }

  void _showMarkerInfo(MapMarker marker) {
    if (_isDisposed) return;
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(_markerTypeEmoji(marker.type), style: const TextStyle(fontSize: 32)), const SizedBox(width: 12), Expanded(child: Text(marker.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))]),
        if (marker.description.isNotEmpty) ...[const SizedBox(height: 12), Text(marker.description, style: TextStyle(color: Colors.grey.shade700))],
        const SizedBox(height: 12), Text('Автор: ${marker.userName}', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16), SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))),
      ]),
    ));
  }

  void _showCreateMarkerDialog(LatLng point) async {
    if (_isDisposed || _isOffline) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет подключения к интернету'))); return; }
    final result = await showModalBottomSheet<Map<String, String>>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => _CreateMarkerSheet(point: point));
    if (result == null || !mounted || _isDisposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? ''; final userName = prefs.getString('user_name') ?? '';
      if (userId.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Необходимо войти в профиль'))); return; }
      final response = await http.post(Uri.parse(mapApiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"action": "create", "user_id": userId, "user_name": userName, "type": result['type'], "title": result['title'], "description": result['description'], "latitude": point.latitude, "longitude": point.longitude})).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) { await _loadCustomMarkers(); if (mounted && !_isDisposed) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Маркер создан! 🎉'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
      else throw Exception('Ошибка сервера');
    } catch (e) { if (mounted && !_isDisposed) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }
  }

  void _onCreateMarkerButtonPressed() { _showCreateMarkerDialog(_mapController.center); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_locationStatus)])));

    return Stack(children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _userLocation ?? _lastKnownPosition ?? const LatLng(55.7558, 37.6173),
          initialZoom: 10, minZoom: 4, maxZoom: 18,
          onLongPress: (tapPosition, point) => _showCreateMarkerDialog(point),
          onMapEvent: (event) { if (event is MapEventMove || event is MapEventFlingAnimation) _onMapMoved(event.camera); },
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.kid_loop', tileProvider: NetworkTileProvider(), errorImage: const AssetImage('assets/no_tile.png')),
          MarkerLayer(markers: [..._buildClusteredMarkers(), if (_userLocation != null) Marker(point: _userLocation!, width: 40, height: 40, child: Container(decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: Colors.blue, width: 3), boxShadow: const [BoxShadow(color: Colors.blue, blurRadius: 8)]), child: const Icon(Icons.my_location, color: Colors.blue, size: 24)))]),
        ],
      ),
      if (_isOffline) Positioned(top: 0, left: 0, right: 0, child: Container(color: Colors.orange.shade800, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), child: const Row(children: [Icon(Icons.wifi_off, color: Colors.white, size: 20), SizedBox(width: 8), Expanded(child: Text('Нет подключения к интернету', style: TextStyle(color: Colors.white, fontSize: 14)))]))),
      if (!_isOffline) Positioned(top: 0, left: 0, right: 0, child: GestureDetector(
        onTap: () { if (_userLocation != null) _mapController.move(_userLocation!, 15); else _determinePosition(); },
        child: Container(color: Colors.green.withOpacity(0.85), padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12), child: Row(children: [
          const Icon(Icons.location_on, color: Colors.white, size: 16), const SizedBox(width: 6),
          Expanded(child: Text(_centerAddress.isNotEmpty ? _centerAddress : _locationStatus, style: const TextStyle(color: Colors.white, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ])),
      )),
      Positioned(top: 46, left: 10, right: 10, child: Container(height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), itemCount: _categories.length, separatorBuilder: (_, __) => const SizedBox(width: 2), itemBuilder: (_, index) {
        final cat = _categories[index]; final isSelected = _selectedCategory == cat || (_selectedCategory == null && cat == 'Все');
        return FilterChip(label: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)), selected: isSelected, onSelected: (_) { if (!_isDisposed && mounted) setState(() => _selectedCategory = cat == 'Все' ? null : cat); }, backgroundColor: Colors.transparent, selectedColor: Colors.orange.shade100, checkmarkColor: Colors.orange, visualDensity: VisualDensity.compact, side: BorderSide(color: isSelected ? Colors.orange : Colors.grey.shade300));
      }))),
      // 🔥 Кнопки прижаты к правому краю
      Positioned(right: 8, bottom: 100, child: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(heroTag: 'add_marker_btn', onPressed: _onCreateMarkerButtonPressed, backgroundColor: Colors.orange, foregroundColor: Colors.white, tooltip: 'Создать маркер', elevation: 4, child: const Icon(Icons.add_location_alt, size: 20)),
        const SizedBox(height: 8),
        FloatingActionButton.small(heroTag: 'location_btn', onPressed: () { if (_userLocation != null) _mapController.move(_userLocation!, 15); else _determinePosition(); }, backgroundColor: Colors.white, foregroundColor: Colors.blue, tooltip: 'Моё местоположение', elevation: 4, child: const Icon(Icons.my_location, size: 20)),
      ])),
      if (_selectedItem != null) Positioned(bottom: 16, left: 16, right: 16, child: Material(borderRadius: BorderRadius.circular(16), elevation: 8, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () async {
        final item = _selectedItem!; setState(() => _selectedItem = null);
        final prefs = await SharedPreferences.getInstance(); final currentUserId = prefs.getString('user_id') ?? '';
        if (item.ownerId == currentUserId && item.ownerId.isNotEmpty) {
          if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), icon: const Icon(Icons.info_outline, color: Colors.orange, size: 48), title: const Text('Это ваша вещь'), content: const Text('Вы не можете предложить обмен самому себе.', textAlign: TextAlign.center), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')), FilledButton(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item))); }, style: FilledButton.styleFrom(backgroundColor: Colors.orange), child: const Text('Смотреть'))]));
        } else { if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item))); }
      }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(children: [
        _buildCircleImageWidget(_selectedItem!.imagePath, _categoryColor(_selectedItem!.category), 50), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(_selectedItem!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4), Text('${_selectedItem!.sv} SV • ${_selectedItem!.category}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          if (_selectedItem!.isMine) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Text('Это ваша вещь', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600))),
        ])), IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () { if (mounted && !_isDisposed) setState(() => _selectedItem = null); }),
      ]))))),
      if (_isRefreshing) const Positioned(top: 50, right: 60, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
    ]);
  }
}

// ============================================================================
// СОВРЕМЕННЫЙ BOTTOM SHEET ДЛЯ СОЗДАНИЯ МАРКЕРА
// ============================================================================
class _CreateMarkerSheet extends StatefulWidget {
  final LatLng point;
  const _CreateMarkerSheet({required this.point});
  @override
  State<_CreateMarkerSheet> createState() => _CreateMarkerSheetState();
}

class _CreateMarkerSheetState extends State<_CreateMarkerSheet> {
  String _selectedType = 'announcement';
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static const _types = [
    {'type': 'announcement', 'emoji': '📢', 'label': 'Объявление', 'desc': 'Расскажите о находке или событии', 'color': Colors.blue},
    {'type': 'event', 'emoji': '🎉', 'label': 'Событие', 'desc': 'Организуйте встречу или праздник', 'color': Colors.orange},
    {'type': 'meetup', 'emoji': '🤝', 'label': 'Встреча', 'desc': 'Предложите обменяться лично', 'color': Colors.green},
  ];

  @override
  void dispose() { _titleController.dispose(); _descController.dispose(); super.dispose(); }

  void _submit() { if (_formKey.currentState!.validate()) Navigator.pop(context, {'type': _selectedType, 'title': _titleController.text.trim(), 'description': _descController.text.trim()}); }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
      child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 20),
        const Text('Создать маркер', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('${widget.point.latitude.toStringAsFixed(4)}, ${widget.point.longitude.toStringAsFixed(4)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        const Text('Тип маркера', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 10),
        Row(children: _types.map((t) {
          final isSelected = _selectedType == t['type']; final color = t['color'] as Color;
          return Expanded(child: Padding(padding: EdgeInsets.only(right: t != _types.last ? 8 : 0), child: GestureDetector(
            onTap: () => setState(() => _selectedType = t['type'] as String),
            child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.08) : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: isSelected ? 2 : 1), boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))] : null),
                child: Column(children: [Text(t['emoji'] as String, style: const TextStyle(fontSize: 28)), const SizedBox(height: 6), Text(t['label'] as String, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isSelected ? color : Colors.black87)), const SizedBox(height: 2), Text(t['desc'] as String, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), textAlign: TextAlign.center, maxLines: 2), if (isSelected) ...[const SizedBox(height: 6), Icon(Icons.check_circle, color: color, size: 18)]])),
          )));
        }).toList()),
        const SizedBox(height: 20),
        TextFormField(controller: _titleController, validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null, autofocus: true, decoration: InputDecoration(labelText: 'Название', hintText: 'Краткое описание', prefixIcon: const Icon(Icons.edit_rounded), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.orange, width: 2)))),
        const SizedBox(height: 14),
        TextFormField(controller: _descController, maxLines: 3, decoration: InputDecoration(labelText: 'Описание (необязательно)', hintText: 'Подробности...', prefixIcon: const Icon(Icons.description_rounded), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.orange, width: 2)))),
        const SizedBox(height: 20),
        SizedBox(height: 54, child: ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4, shadowColor: Colors.orange.withOpacity(0.4)), child: const Text('Создать маркер', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}

// ============================================================================
class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = ui.Path(); path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(size.width / 2, size.height); path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => oldDelegate is TrianglePainter && oldDelegate.color != color;
}