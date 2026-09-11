// features/life_navigator/ui/widgets/calendar/calendar_weather.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:characters/characters.dart';

class CalendarWeather extends StatefulWidget {
  final bool isDark;
  final bool transparent;
  final bool compact;

  const CalendarWeather({
    super.key,
    required this.isDark,
    this.transparent = false,
    this.compact = false,
  });

  @override
  State<CalendarWeather> createState() => _CalendarWeatherState();
}

class _CalendarWeatherState extends State<CalendarWeather>
    with SingleTickerProviderStateMixin {
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

  // ==================== ГОРОДА РФ ====================

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

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    _loadWeather();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ==================== ЗАГРУЗКА ПОГОДЫ ====================

  Future<void> _loadWeather() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _city = 'Определение...';
    });

    await _fetchRealWeather();
  }

  Future<void> _fetchRealWeather() async {
    try {
      // Проверяем разрешение геолокации
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          _setError('Нет доступа к геолокации');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setError('Геолокация отключена');
        return;
      }

      // Сначала пытаемся получить последнюю известную позицию
      Position? position = await Geolocator.getLastKnownPosition();

      // Затем актуальную
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        ).timeout(
          const Duration(seconds: 4),
        );
      } catch (_) {
        // Если актуальную получить не удалось,
        // используем последнюю известную
      }

      if (position == null) {
        _setError('Нет GPS');
        return;
      }

      // Определяем город
      final cityName = _getCity(
        position.latitude,
        position.longitude,
      );

      // Open-Meteo
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
            'latitude=${position.latitude}&'
            'longitude=${position.longitude}&'
            'current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&'
            'timezone=auto&'
            'forecast_days=1',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 6),
      );

      if (response.statusCode != 200) {
        _setError('Ошибка сервера');
        return;
      }

      final data = jsonDecode(response.body);

      final current = data['current'];

      if (current == null) {
        _setError('Нет данных');
        return;
      }

      final temp = (current['temperature_2m'] as num).round();

      final humidity =
      (current['relative_humidity_2m'] as num).round();

      final windSpeed =
      (current['wind_speed_10m'] as num).round();

      final weatherCode =
      (current['weather_code'] as num).round();

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
        _hasError = false;
      });
    } catch (_) {
      _setError('Нет интернета');
    }
  }

  // ==================== ГОРОД ====================

  String _getCity(double lat, double lon) {
    final key =
        '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';

    if (_cities.containsKey(key)) {
      return _cities[key]!;
    }

    String closest = '';
    double minDist = double.infinity;

    for (final entry in _cities.entries) {
      final parts = entry.key.split('_');

      final cityLat = double.parse(parts[0]);
      final cityLon = double.parse(parts[1]);

      final distance =
          (lat - cityLat) * (lat - cityLat) +
              (lon - cityLon) * (lon - cityLon);

      if (distance < minDist) {
        minDist = distance;
        closest = entry.value;
      }
    }

    return closest.isNotEmpty ? closest : '—';
  }

  // ==================== ЭМОДЗИ ====================

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

  // ==================== ОПИСАНИЕ ====================

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

  // ==================== ОШИБКА ====================

  void _setError(String message) {
    if (!mounted) return;

    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isLoading = false;
    });
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _showDetails(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.zero,
        decoration: widget.transparent
            ? null
            : BoxDecoration(
          color: widget.isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hasError
                ? Colors.red.withOpacity(0.3)
                : widget.isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.shade200,
          ),
        ),
        child: _isLoading
            ? _buildLoading()
            : _hasError
            ? _buildError()
            : _buildContent(),
      ),
    );
  }

  // ==================== LOADING ====================

  Widget _buildLoading() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.isDark
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Загрузка...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ERROR ====================

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 17,
            color: Colors.red,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _errorMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _loadWeather,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.refresh_rounded,
                size: 17,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ОСНОВНОЙ КОНТЕНТ ====================

  Widget _buildContent() {
    /*
     * Структура:
     *
     *       ☀️  Москва
     *          +18°
     *      💧 65%  💨 3 м/с
     *           Ясно
     *
     * Никаких длинных горизонтальных Row,
     * которые могут вылезать за границы карточки.
     */

    if (widget.transparent && !widget.compact) {
      return _buildLargeWeather();
    }

    return _buildCompactWeather();
  }

  // ==================== БОЛЬШОЙ РЕЖИМ ====================

  Widget _buildLargeWeather() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Адаптивные размеры.
        final emojiSize = width < 110 ? 28.0 : 34.0;

        final temperatureSize = width < 110 ? 25.0 : 30.0;

        final citySize = width < 110 ? 12.0 : 14.0;

        final infoSize = width < 110 ? 9.0 : 10.5;

        final descriptionSize =
        width < 110 ? 11.0 : 13.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width < 110 ? 7 : 10,
            vertical: height < 120 ? 7 : 9,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // 1. СОЛНЦЕ + ГОРОД
              // ==========================================

              SizedBox(
                height: height < 120 ? 30 : 36,
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (_, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Text(
                        _weatherEmoji,
                        style: TextStyle(
                          fontSize: emojiSize,
                          height: 1,
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        _city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: citySize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),

                    // Маленькая кнопка обновления
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _loadWeather,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: width < 110 ? 13 : 15,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: height < 120 ? 1 : 3,
              ),

              // ==========================================
              // 2. ТЕМПЕРАТУРА
              // ==========================================

              Text(
                _temperature,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: temperatureSize,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                  letterSpacing: -0.8,
                ),
              ),

              SizedBox(
                height: height < 120 ? 5 : 7,
              ),

              // ==========================================
              // 3. ВЛАЖНОСТЬ + ВЕТЕР
              // ==========================================

              Row(
                children: [
                  Expanded(
                    child: _buildWeatherInfo(
                      icon: Icons.water_drop_rounded,
                      value: '$_humidity%',
                      fontSize: infoSize,
                    ),
                  ),

                  const SizedBox(width: 4),

                  Expanded(
                    child: _buildWeatherInfo(
                      icon: Icons.air_rounded,
                      value: '$_windSpeed м/с',
                      fontSize: infoSize,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // ==========================================
              // 4. ОПИСАНИЕ ПОГОДЫ
              // ==========================================

              Text(
                _description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: descriptionSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.92),
                  height: 1.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== ИНФОРМАЦИЯ ====================

  Widget _buildWeatherInfo({
    required IconData icon,
    required String value,
    required double fontSize,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: fontSize + 2,
          color: Colors.white.withOpacity(0.65),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.72),
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== КОМПАКТНЫЙ РЕЖИМ ====================

  Widget _buildCompactWeather() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final dim = w < h ? w : h; // квадрат → ориентир на меньшую сторону

        // Базовые размеры (адаптируются от размера квадрата)
        final emojiSize   = (dim * 0.22).clamp(16.0, 30.0);
        final tempSize    = (dim * 0.27).clamp(18.0, 34.0);
        final cityBase    = (dim * 0.13).clamp(11.0, 16.0);
        final infoSize    = (dim * 0.10).clamp(8.5, 12.0);
        final descSize    = (dim * 0.11).clamp(9.0, 13.0);

        final primaryColor = widget.isDark ? Colors.white : Colors.black87;
        final secondaryColor = widget.isDark
            ? Colors.white70
            : Colors.grey.shade700;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dim * 0.07,
            vertical: dim * 0.06,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ==========================================
              // 1. ЭМОДЗИ + ТЕМПЕРАТУРА
              // ==========================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, child) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    ),
                    child: Text(
                      _weatherEmoji,
                      style: TextStyle(fontSize: emojiSize, height: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _temperature,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: tempSize,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                          height: 1,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ==========================================
              // 2. ГОРОД — полная ширина, до 2 строк,
              //    адаптивный шрифт по длине названия
              // ==========================================
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _city,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _cityFontSize(_city, cityBase),
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                      height: 1.15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              // ==========================================
              // 3. ВЛАЖНОСТЬ + ВЕТЕР
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '💧 $_humidity%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: infoSize,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '💨 $_windSpeed м/с',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: infoSize,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              // ==========================================
              // 4. ОПИСАНИЕ
              // ==========================================
              Text(
                _description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: descSize,
                  fontWeight: FontWeight.w700,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== ПОДРОБНОСТИ ====================

  void _showDetails(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF1A1D24)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Полоска
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 20),

                // Иконка
                Text(
                  _weatherEmoji,
                  style: const TextStyle(
                    fontSize: 56,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 8),

                // Город
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 17,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Температура
                Text(
                  _temperature,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: widget.isDark
                        ? Colors.white
                        : Colors.black87,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 8),

                // Описание
                Text(
                  _description,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? Colors.white70
                        : Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 4),

                // Ощущается
                Text(
                  _feelsLike,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark
                        ? Colors.white54
                        : Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 18),

                // Показатели
                Row(
                  children: [
                    _tile(
                      '💧',
                      'Влажность',
                      '$_humidity%',
                    ),
                    const SizedBox(width: 8),
                    _tile(
                      '💨',
                      'Ветер',
                      '$_windSpeed м/с',
                    ),
                    const SizedBox(width: 8),
                    _tile(
                      '📍',
                      'Город',
                      _city,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(_);
                          _loadWeather();
                        },
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 16,
                        ),
                        label: const Text('Обновить'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(_);
                        },
                        child: const Text('Закрыть'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== TILE ====================

  Widget _tile(
      String emoji,
      String label,
      String value,
      ) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 70,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 18,
                height: 1,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.isDark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                color: widget.isDark
                    ? Colors.white38
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Понижает шрифт для длинных названий городов.
/// «Сочи» → базовый, «Новосибирск» → −8%, «Петропавловск-Камчатский» → −42%.
double _cityFontSize(String name, double base) {
  final len = name.characters.length;
  if (len <= 8)  return base;
  if (len <= 11) return base * 0.92;
  if (len <= 14) return base * 0.82;
  if (len <= 18) return base * 0.72;
  if (len <= 22) return base * 0.64;
  return base * 0.58;
}