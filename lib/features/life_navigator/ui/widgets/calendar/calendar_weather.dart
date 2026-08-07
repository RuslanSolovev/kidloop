// features/life_navigator/ui/widgets/calendar/calendar_weather.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class CalendarWeather extends StatefulWidget {
  final bool isDark;
  final bool transparent; // НОВЫЙ ПАРАМЕТР для прозрачного фона
  final bool compact; // НОВЫЙ ПАРАМЕТР для крупного текста

  const CalendarWeather({
    super.key,
    required this.isDark,
    this.transparent = false,
    this.compact = false,
  });

  @override
  State<CalendarWeather> createState() => _CalendarWeatherState();
}

class _CalendarWeatherState extends State<CalendarWeather> with SingleTickerProviderStateMixin {
  String _weatherEmoji = '🌤️';
  String _temperature = '--°';
  String _feelsLike = '';
  String _city = 'Определение...';
  String _description = '';
  int _humidity = 0;
  int _windSpeed = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  // 🔥 Города РФ по координатам
  static final Map<String, String> _cities = {
    '55.96_38.05': 'Фрязино',
    '55.75_37.62': 'Москва',
    '59.93_30.33': 'СПб',
    '55.04_82.93': 'Новосибирск',
    '56.83_60.60': 'Екатеринбург',
    '55.79_49.12': 'Казань',
    '45.03_38.97': 'Краснодар',
    '43.58_39.72': 'Сочи',
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    _loadWeather();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; _city = 'Определение...'; });
    await _fetchRealWeather();
  }

  // ==================== Open-Meteo API (БЕСПЛАТНО, БЕЗ КЛЮЧА) ====================

  Future<void> _fetchRealWeather() async {
    try {
      // 🔥 1. Разрешения геолокации
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) { _setError('Нет доступа к гео'); return; }
      }
      if (permission == LocationPermission.deniedForever) { _setError('Гео отключена'); return; }

      // 🔥 2. Получаем позицию
      Position? position = await Geolocator.getLastKnownPosition();
      try {
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low).timeout(const Duration(seconds: 3));
      } catch (_) {}

      if (position == null) { _setError('Нет GPS'); return; }

      // 🔥 3. Город по координатам
      final cityName = _getCity(position.latitude, position.longitude);

      // 🔥 4. Запрос к Open-Meteo (бесплатно, без ключа!)
      final url = 'https://api.open-meteo.com/v1/forecast?'
          'latitude=${position.latitude}&longitude=${position.longitude}'
          '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code'
          '&timezone=auto&forecast_days=1';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];

        final temp = (current['temperature_2m'] as num).round();
        final humidity = current['relative_humidity_2m'] as int;
        final windSpeed = (current['wind_speed_10m'] as num).round();
        final weatherCode = current['weather_code'] as int;

        if (!mounted) return;
        setState(() {
          _temperature = '$temp°';
          _feelsLike = 'Ощущается: $temp°';
          _description = _weatherDescription(weatherCode);
          _weatherEmoji = _weatherEmojiFromCode(weatherCode);
          _humidity = humidity;
          _windSpeed = windSpeed;
          _city = cityName;
          _isLoading = false;
        });
      } else {
        _setError('Ошибка сервера');
      }
    } catch (e) {
      _setError('Нет интернета');
    }
  }

  // ==================== ГОРОД ПО КООРДИНАТАМ ====================

  String _getCity(double lat, double lon) {
    final key = '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
    if (_cities.containsKey(key)) return _cities[key]!;

    String closest = '';
    double minDist = double.infinity;
    for (final entry in _cities.entries) {
      final parts = entry.key.split('_');
      final d = (lat - double.parse(parts[0])) * (lat - double.parse(parts[0])) +
          (lon - double.parse(parts[1])) * (lon - double.parse(parts[1]));
      if (d < minDist) { minDist = d; closest = entry.value; }
    }
    return closest.isNotEmpty ? closest : '—';
  }

  // ==================== КОДЫ ПОГОДЫ Open-Meteo → ЭМОДЗИ ====================

  String _weatherEmojiFromCode(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '🌤️';
    if (code <= 48) return '🌫️';
    if (code <= 57) return '🌧️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '🌨️';
    if (code <= 82) return '🌧️';
    if (code <= 86) return '🌨️';
    if (code <= 99) return '⛈️';
    return '🌤️';
  }

  String _weatherDescription(int code) {
    if (code == 0) return 'Ясно';
    if (code <= 3) return 'Переменная облачность';
    if (code <= 48) return 'Туман';
    if (code <= 57) return 'Морось';
    if (code <= 67) return 'Дождь';
    if (code <= 77) return 'Снег';
    if (code <= 82) return 'Ливень';
    if (code <= 86) return 'Снегопад';
    if (code <= 99) return 'Гроза';
    return '—';
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() { _hasError = true; _errorMessage = msg; _isLoading = false; });
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); _showDetails(context); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.zero,
        decoration: widget.transparent
            ? null
            : BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hasError ? Colors.red.withOpacity(0.3) : (widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)),
        ),
        child: _isLoading ? _buildLoading() : _hasError ? _buildError() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() => const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
    SizedBox(width: 8),
    Text('Загрузка...', style: TextStyle(fontSize: 11)),
  ]);

  Widget _buildError() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off_rounded, size: 16, color: Colors.red),
    const SizedBox(width: 6),
    Expanded(child: Text(_errorMessage, style: const TextStyle(fontSize: 11, color: Colors.red))),
    GestureDetector(onTap: _loadWeather, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.refresh_rounded, size: 16, color: Colors.blue))),
  ]);

  Widget _buildContent() {
    // КРУПНЫЙ режим (когда transparent = true)
    if (widget.transparent && !widget.compact) {
      return Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, c) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Text(_weatherEmoji, style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_temperature, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: Colors.blue.shade200),
                          const SizedBox(width: 3),
                          Text(_city, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(_description, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    Text('$_humidity% 💧', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(width: 8),
                    Text('$_windSpeed м/с 💨', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadWeather,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.refresh_rounded, size: 18, color: Colors.white70),
            ),
          ),
        ],
      );
    }

    // Обычный компактный режим
    return Row(children: [
      AnimatedBuilder(animation: _pulseAnimation, builder: (_, c) => Transform.scale(scale: _pulseAnimation.value, child: Text(_weatherEmoji, style: const TextStyle(fontSize: 22)))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_temperature, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : Colors.black87)),
        Text(_description, style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on_rounded, size: 9, color: Colors.blue.shade400), const SizedBox(width: 2), Text(_city, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : Colors.grey.shade600))]),
        Text('$_humidity% 💧  $_windSpeed м/с 💨', style: TextStyle(fontSize: 8, color: widget.isDark ? Colors.white38 : Colors.grey.shade500)),
      ]),
      GestureDetector(onTap: _loadWeather, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.refresh_rounded, size: 14, color: Colors.grey))),
    ]);
  }

  void _showDetails(BuildContext ctx) => showModalBottomSheet(
    context: ctx, backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text(_weatherEmoji, style: const TextStyle(fontSize: 56)),
        Text(_temperature, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: widget.isDark ? Colors.white : Colors.black87)),
        Text(_description, style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.white70 : Colors.grey.shade700)),
        Text(_feelsLike, style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
        const SizedBox(height: 16),
        Row(children: [
          _tile('💧', 'Влажность', '$_humidity%'),
          const SizedBox(width: 8),
          _tile('💨', 'Ветер', '$_windSpeed м/с'),
          const SizedBox(width: 8),
          _tile('📍', 'Город', _city),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(_); _loadWeather(); }, icon: const Icon(Icons.refresh_rounded, size: 14), label: const Text('Обновить'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(_), child: const Text('Закрыть'))),
        ]),
      ]),
    ),
  );

  Widget _tile(String e, String l, String v) => Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(e, style: const TextStyle(fontSize: 18)), const SizedBox(height: 2), Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black87)), Text(l, style: TextStyle(fontSize: 9, color: widget.isDark ? Colors.white38 : Colors.grey.shade500))])));
}