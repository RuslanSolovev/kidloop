import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../item_details/item_details_screen.dart';
import '../../core/item_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Item> _items = [];
  List<MapMarker> _customMarkers = [];
  LatLng? _userLocation;
  bool _loading = true;
  Timer? _refreshTimer;
  String? _selectedCategory;
  Item? _selectedItem;

  static const String mapApiUrl = 'https://functions.yandexcloud.net/d4e2uh2tj0febumk6e7e';

  final List<String> _categories = [
    'Все', 'Игрушки', 'LEGO', 'Самокат', 'Книги', 'Одежда',
    'Коляска', 'Мебель', 'Техника', 'Спорт', 'Развивашки',
    'Творчество', 'Пазлы', 'Конструктор', 'Куклы', 'Машинки',
  ];

  @override
  void initState() {
    super.initState();
    _init();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadItems();
      _loadCustomMarkers();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _getLocation();
    await Future.wait([_loadItems(), _loadCustomMarkers()]);
    setState(() => _loading = false);
  }

  Future<void> _getLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {}
  }

  Future<void> _loadItems() async {
    try {
      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4ei9an1aushareidmjc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      );
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final items = (data['items'] as List).map((item) => Item(
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
        )).toList();

        final mapped = items.where((i) => _getCityCoords(i.location) != null).toList();
        if (mounted) setState(() => _items = mapped);
      }
    } catch (e) {}
  }

  Future<void> _loadCustomMarkers() async {
    try {
      final response = await http.post(
        Uri.parse(mapApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "list"}),
      );
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        final markers = (data['markers'] as List).map((m) => MapMarker(
          markerId: m['marker_id'] ?? '',
          userId: m['user_id'] ?? '',
          userName: m['user_name'] ?? '',
          type: m['type'] ?? '',
          title: m['title'] ?? '',
          description: m['description'] ?? '',
          latitude: m['latitude'] ?? 0,
          longitude: m['longitude'] ?? 0,
        )).toList();
        if (mounted) setState(() => _customMarkers = markers);
      }
    } catch (e) {}
  }

  LatLng? _getCityCoords(String location) {
    final lower = location.toLowerCase();

    if (lower.contains('москва') || lower.contains('moscow')) return LatLng(55.7558, 37.6173);
    if (lower.contains('санкт-петербург') || lower.contains('питер') || lower.contains('спб')) return LatLng(59.9343, 30.3351);
    if (lower.contains('новосибирск')) return LatLng(55.0084, 82.9357);
    if (lower.contains('екатеринбург')) return LatLng(56.8389, 60.6057);
    if (lower.contains('казань')) return LatLng(55.7961, 49.1064);
    if (lower.contains('нижний новгород')) return LatLng(56.2965, 43.9361);
    if (lower.contains('челябинск')) return LatLng(55.1644, 61.4368);
    if (lower.contains('самара')) return LatLng(53.1959, 50.1002);
    if (lower.contains('щёлково') || lower.contains('щелково')) return LatLng(55.9205, 37.9917);
    if (lower.contains('фрязино')) return LatLng(55.9606, 38.0412);
    if (lower.contains('омск')) return LatLng(54.9893, 73.3682);
    if (lower.contains('ростов-на-дону') || lower.contains('ростов')) return LatLng(47.2357, 39.7015);
    if (lower.contains('уфа')) return LatLng(54.7388, 55.9721);
    if (lower.contains('красноярск')) return LatLng(56.0106, 92.8525);
    if (lower.contains('воронеж')) return LatLng(51.6755, 39.2085);
    if (lower.contains('пермь')) return LatLng(58.0105, 56.2502);
    if (lower.contains('волгоград')) return LatLng(48.7080, 44.5133);
    if (lower.contains('краснодар')) return LatLng(45.0355, 38.9753);
    if (lower.contains('саратов')) return LatLng(51.5336, 46.0343);
    if (lower.contains('тюмень')) return LatLng(57.1613, 65.5250);
    if (lower.contains('тольятти')) return LatLng(53.5303, 49.3461);
    if (lower.contains('ижевск')) return LatLng(56.8498, 53.2045);
    if (lower.contains('барнаул')) return LatLng(53.3480, 83.7765);
    if (lower.contains('иркутск')) return LatLng(52.2869, 104.3050);
    if (lower.contains('хабаровск')) return LatLng(48.4802, 135.0719);
    if (lower.contains('ярославль')) return LatLng(57.6261, 39.8845);
    if (lower.contains('владивосток')) return LatLng(43.1155, 131.8855);
    if (lower.contains('махачкала')) return LatLng(42.9849, 47.5047);
    if (lower.contains('томск')) return LatLng(56.4846, 84.9476);
    if (lower.contains('оренбург')) return LatLng(51.7682, 55.0970);
    if (lower.contains('кемерово')) return LatLng(55.3549, 86.0873);
    if (lower.contains('новокузнецк')) return LatLng(53.7557, 87.1099);
    if (lower.contains('рига')) return LatLng(56.9496, 24.1052);
    if (lower.contains('юрмала')) return LatLng(56.9681, 23.7566);
    if (lower.contains('даугавпилс')) return LatLng(55.8751, 26.5320);

    return null;
  }

  void _goToUserLocation() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14);
    }
  }

  void _goToItem(Item item) {
    final coords = _getCityCoords(item.location);
    if (coords != null) {
      _mapController.move(coords, 15);
      setState(() => _selectedItem = item);
    }
  }

  List<Item> get _filteredItems {
    if (_selectedCategory == null || _selectedCategory == 'Все') return _items;
    return _items.where((i) => i.category == _selectedCategory).toList();
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

  Widget _placeholderIcon(Color color) {
    return Container(
      width: 60,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.toys, color: color, size: 28),
    );
  }

  List<Marker> _buildClusteredMarkers() {
    final markers = <Marker>[];
    final items = _filteredItems;
    if (items.isEmpty && _customMarkers.isEmpty) return markers;

    // Маркеры вещей
    final groups = <String, List<Item>>{};
    for (final item in items) {
      final coords = _getCityCoords(item.location);
      if (coords == null) continue;
      final key = '${(coords.latitude * 100).round()}_${(coords.longitude * 100).round()}';
      groups.putIfAbsent(key, () => []).add(item);
    }

    for (final entry in groups.entries) {
      final groupItems = entry.value;
      final avgLat = groupItems.map((i) => _getCityCoords(i.location)!.latitude).reduce((a, b) => a + b) / groupItems.length;
      final avgLon = groupItems.map((i) => _getCityCoords(i.location)!.longitude).reduce((a, b) => a + b) / groupItems.length;

      if (groupItems.length > 1) {
        markers.add(Marker(
          point: LatLng(avgLat, avgLon),
          width: 55,
          height: 55,
          child: GestureDetector(
            onTap: () => _showClusterDialog(groupItems),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              alignment: Alignment.center,
              child: Text('${groupItems.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ));
      } else {
        final item = groupItems.first;
        final color = _categoryColor(item.category);

        markers.add(Marker(
          point: LatLng(avgLat, avgLon),
          width: 130,
          height: 100,
          child: GestureDetector(
            onTap: () => _goToItem(item),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 2.5),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.imagePath.startsWith('http')
                            ? Image.network(item.imagePath, width: 60, height: 50, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderIcon(color))
                            : _placeholderIcon(color),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                        child: Text(item.category,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 2),
                      Text('${item.sv} SV',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: color, size: 28),
              ],
            ),
          ),
        ));
      }
    }

    // Маркеры объявлений
    for (final marker in _customMarkers) {
      final color = _markerTypeColor(marker.type);
      markers.add(Marker(
        point: LatLng(marker.latitude, marker.longitude),
        width: 110,
        height: 80,
        child: GestureDetector(
          onTap: () => _showMarkerInfo(marker),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Column(
                  children: [
                    Text(_markerTypeEmoji(marker.type), style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(marker.title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, color: color, size: 20),
            ],
          ),
        ),
      ));
    }

    return markers;
  }

  void _showClusterDialog(List<Item> items) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Вещи в этом месте', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...items.map((item) => ListTile(
            leading: item.imagePath.startsWith('http')
                ? Image.network(item.imagePath, width: 40, height: 40, fit: BoxFit.cover)
                : const Icon(Icons.toys),
            title: Text(item.title),
            subtitle: Text('${item.sv} SV'),
            trailing: Text(item.category),
            onTap: () {
              Navigator.pop(ctx);
              _goToItem(item);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item)));
            },
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showMarkerInfo(MapMarker marker) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                Expanded(child: Text(marker.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              ],
            ),
            if (marker.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(marker.description, style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(marker.userName, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateMarkerDialog(LatLng point) async {
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

    if (type == null || !mounted) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Создать ${_markerTypeEmoji(type)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Название')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Описание'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final userName = prefs.getString('user_name') ?? '';

      await http.post(
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
      );

      _loadCustomMarkers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Маркер создан!')));
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? LatLng(55.7558, 37.6173),
            initialZoom: 10,
            minZoom: 4,
            maxZoom: 18,
            onLongPress: (point, latlng) {
              _showCreateMarkerDialog(latlng);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.kid_loop',
            ),
            MarkerLayer(
              markers: [
                ..._buildClusteredMarkers(),
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.my_location, color: Colors.green, size: 18),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Фильтр категорий
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat, style: const TextStyle(fontSize: 12)),
                  selected: _selectedCategory == cat || (_selectedCategory == null && cat == 'Все'),
                  onSelected: (_) {
                    setState(() => _selectedCategory = cat == 'Все' ? null : cat);
                  },
                  backgroundColor: Colors.white,
                  selectedColor: Colors.orange.shade100,
                  checkmarkColor: Colors.orange,
                ),
              )).toList(),
            ),
          ),
        ),

        // Кнопки
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'add_marker_btn',
                mini: true,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Зажмите карту, чтобы создать маркер')),
                  );
                },
                backgroundColor: Colors.orange,
                child: const Icon(Icons.add_location),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'location_btn',
                mini: true,
                onPressed: _goToUserLocation,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.blue),
              ),
            ],
          ),
        ),

        // Инфо о выбранной вещи
        if (_selectedItem != null)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(16),
              elevation: 6,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final item = _selectedItem!;
                  setState(() => _selectedItem = null);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item)));
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _selectedItem!.imagePath.startsWith('http')
                            ? Image.network(_selectedItem!.imagePath, width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.toys, size: 40),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selectedItem!.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${_selectedItem!.sv} SV • ${_selectedItem!.category}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _selectedItem = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

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
}