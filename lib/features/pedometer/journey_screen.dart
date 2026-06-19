import 'package:flutter/material.dart';

class JourneyView extends StatefulWidget {
  final double walkedKm;
  final int totalSteps;
  final VoidCallback onBack;

  const JourneyView({
    super.key,
    required this.walkedKm,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  State<JourneyView> createState() => _JourneyViewState();
}

class _JourneyViewState extends State<JourneyView>
    with SingleTickerProviderStateMixin {
  static const double _totalDistance = 9300;
  late final List<City> _cities = _getCities();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  final Map<int, AnimationController> _itemAnimControllers = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    for (final controller in _itemAnimControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  City get _currentCity => _cities.lastWhere(
        (c) => c.distanceFromMoscow <= widget.walkedKm,
    orElse: () => _cities.first,
  );

  int get _reachedCitiesCount =>
      _cities.where((c) => c.distanceFromMoscow <= widget.walkedKm).length;

  int get _remainingCitiesCount => _cities.length - _reachedCitiesCount;

  double get _progressPercent =>
      (widget.walkedKm / _totalDistance).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final nextIndex = _cities.indexOf(_currentCity) + 1;
    final nextCity = nextIndex < _cities.length ? _cities[nextIndex] : null;
    final progressToNext = nextCity != null
        ? ((widget.walkedKm - _currentCity.distanceFromMoscow) /
        (nextCity.distanceFromMoscow - _currentCity.distanceFromMoscow))
        .clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroProgressCard(),
          const SizedBox(height: 20),
          _buildQuickStats(),
          const SizedBox(height: 20),
          _buildCityCard(_currentCity, isCurrent: true),
          if (nextCity != null) ...[
            const SizedBox(height: 12),
            _buildNextCityCard(nextCity, progressToNext),
          ],
          const SizedBox(height: 20),
          _buildTimelineHeader(),
          const SizedBox(height: 8),
          _journeyTimeline(),
          const SizedBox(height: 24),
          _buildQuote(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFFFF6B6B), size: 20),
          onPressed: widget.onBack,
        ),
      ),
      title: Column(
        children: [
          const Text('Транссибирское путешествие',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          Text('Москва → Владивосток',
              style: TextStyle(
                  color: const Color(0xFFFF6B6B).withOpacity(0.7),
                  fontSize: 11)),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeroProgressCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, child) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B6B).withOpacity(0.12),
                const Color(0xFF1A1A2E),
                const Color(0xFF0F0F1A),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: const Color(0xFFFF6B6B).withOpacity(0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.08),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(children: [
            Transform.scale(
              scale: _pulseAnimation.value,
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B),
                    const Color(0xFFFF8E8E).withOpacity(0.9),
                  ],
                ).createShader(bounds),
                child: Text(
                  '${(_progressPercent * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    letterSpacing: -2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('пути пройдено',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    letterSpacing: 1.5)),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: _progressPercent,
                minHeight: 14,
                backgroundColor: const Color(0xFF1E1E3A),
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFFF6B6B).withOpacity(0.9),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('👣', '${widget.totalSteps}', 'шагов'),
                Container(
                  width: 1,
                  height: 44,
                  color: Colors.white.withOpacity(0.08),
                ),
                _buildStatItem(
                    '📍', '${widget.walkedKm.toStringAsFixed(1)}', 'км'),
                Container(
                  width: 1,
                  height: 44,
                  color: Colors.white.withOpacity(0.08),
                ),
                _buildStatItem(
                    '🎯',
                    '${(_totalDistance - widget.walkedKm).toStringAsFixed(0)}',
                    'осталось'),
              ],
            ),
          ]),
        );
      },
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4CAF50).withOpacity(0.08),
                  const Color(0xFF1A1A2E).withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_city,
                      color: Color(0xFF4CAF50), size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_reachedCitiesCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    Text('посещено',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4A90E2).withOpacity(0.08),
                  const Color(0xFF1A1A2E).withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF4A90E2).withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.explore,
                      color: Color(0xFF4A90E2), size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_remainingCitiesCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    Text('впереди',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCityCard(City city, {bool isCurrent = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrent
              ? [
            const Color(0xFF16213E),
            const Color(0xFFFF6B6B).withOpacity(0.08),
          ]
              : [
            const Color(0xFF0F0F1A),
            const Color(0xFF1A1A2E).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: isCurrent
            ? Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.25))
            : Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: isCurrent
            ? [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ]
            : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCurrent
                    ? [
                  const Color(0xFFFF6B6B).withOpacity(0.2),
                  const Color(0xFFFF6B6B).withOpacity(0.05),
                ]
                    : [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isCurrent ? Icons.location_on_rounded : Icons.place_outlined,
              color: isCurrent ? const Color(0xFFFF6B6B) : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B6B).withOpacity(0.2),
                            const Color(0xFFFF8E8E).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('📍 ТЕКУЩАЯ ЛОКАЦИЯ',
                          style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                    ),
                  const SizedBox(height: 6),
                  Text(city.name,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: isCurrent ? 28 : 18,
                          fontWeight: FontWeight.bold)),
                  Text('${city.distanceFromMoscow} км от Москвы',
                      style: TextStyle(
                          color: isCurrent
                              ? const Color(0xFFFF6B6B).withOpacity(0.7)
                              : const Color(0xFF8888AA),
                          fontSize: 12)),
                ]),
          ),
          if (city.isMajor)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF9800).withOpacity(0.3),
                    const Color(0xFFFF9800).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.star_rounded,
                  color: Color(0xFFFF9800), size: 18),
            ),
        ]),
        const SizedBox(height: 20),
        _buildFactCard(city.fact, '📜 История'),
        const SizedBox(height: 10),
        _buildFactCard(city.funFact1, '💡 Факт'),
        const SizedBox(height: 10),
        _buildFactCard(city.funFact2, '✨ Интересно'),
        if (city.cuisine.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.03),
                  Colors.white.withOpacity(0.01),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                const Text('🍽️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Местная кухня: ${city.cuisine}',
                      style: const TextStyle(
                          color: Color(0xFFAAAAAA), fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildFactCard(String text, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B6B).withOpacity(0.2),
                  const Color(0xFFFF6B6B).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFFBBBBBB),
                    fontSize: 12,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildNextCityCard(City city, double progress) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.08),
            const Color(0xFF0F0F1A),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withOpacity(0.15),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B6B).withOpacity(0.2),
                  const Color(0xFFFF8E8E).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('🎯 СЛЕДУЮЩАЯ ОСТАНОВКА',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
          ),
          const Spacer(),
          Text('${(progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B).withOpacity(0.2),
                    const Color(0xFFFF6B6B).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.navigation,
                  color: Color(0xFFFF6B6B), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(city.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text('${city.distanceFromMoscow} км',
                      style: const TextStyle(
                          color: Color(0xFF8888AA), fontSize: 12)),
                ],
              ),
            ),
            if (city.isMajor)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star, color: Color(0xFFFF9800), size: 18),
              ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: const Color(0xFF1E1E3A),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
          ),
        ),
      ]),
    );
  }

  Widget _buildTimelineHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.timeline, color: Color(0xFFFF6B6B), size: 18),
          ),
          const SizedBox(width: 10),
          const Text('ПОЛНЫЙ МАРШРУТ',
              style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_cities.length} городов',
                style: const TextStyle(
                    color: Color(0xFF8888AA),
                    fontSize: 10,
                    letterSpacing: 0.5)),
          ),
          const Spacer(),
          Text(
            '$_reachedCitiesCount/${_cities.length}',
            style: TextStyle(
              color: const Color(0xFFFF6B6B).withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _journeyTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _cities.asMap().entries.map((entry) {
        final index = entry.key;
        final city = entry.value;
        final isReached = city.distanceFromMoscow <= widget.walkedKm;
        final isCurrent = city == _currentCity;

        return AnimatedContainer(
          duration: Duration(milliseconds: 400 + (index * 30)),
          curve: Curves.easeOutCubic,
          child: InkWell(
            onTap: () => _showCityInfo(city),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: isCurrent
                              ? 28
                              : (city.isMajor ? 20 : 14),
                          height: isCurrent
                              ? 28
                              : (city.isMajor ? 20 : 14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isReached
                                ? LinearGradient(
                              colors: [
                                const Color(0xFFFF6B6B),
                                const Color(0xFFFF8E8E)
                                    .withOpacity(0.7),
                              ],
                            )
                                : null,
                            color: isReached
                                ? null
                                : const Color(0xFF2D2D44),
                            border: isCurrent
                                ? Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 3)
                                : null,
                            boxShadow: isCurrent
                                ? [
                              BoxShadow(
                                color: const Color(0xFFFF6B6B)
                                    .withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ]
                                : isReached
                                ? [
                              BoxShadow(
                                color: const Color(0xFFFF6B6B)
                                    .withOpacity(0.2),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                                : [],
                          ),
                          child: isReached && city.isMajor && !isCurrent
                              ? const Icon(Icons.check,
                              color: Colors.white, size: 12)
                              : isCurrent
                              ? const Icon(Icons.location_on,
                              color: Colors.white, size: 14)
                              : null,
                        ),
                        if (index < _cities.length - 1)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 2,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isReached
                                    ? [
                                  const Color(0xFFFF6B6B)
                                      .withOpacity(0.5),
                                  const Color(0xFFFF6B6B)
                                      .withOpacity(0.1),
                                ]
                                    : [
                                  const Color(0xFF2D2D44),
                                  const Color(0xFF1A1A2E),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isReached
                              ? [
                            const Color(0xFFFF6B6B)
                                .withOpacity(0.08),
                            const Color(0xFF16213E)
                                .withOpacity(0.5),
                          ]
                              : [
                            const Color(0xFF16213E)
                                .withOpacity(0.5),
                            const Color(0xFF0F0F1A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: isCurrent
                            ? Border.all(
                            color: const Color(0xFFFF6B6B)
                                .withOpacity(0.3))
                            : Border.all(
                            color: Colors.white.withOpacity(0.03)),
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  city.name,
                                  style: TextStyle(
                                    color: isReached
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.white,
                                    fontSize:
                                    city.isMajor ? 14 : 12,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (city.isMajor) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${city.population} • ${city.founded}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${city.distanceFromMoscow} км',
                                style: TextStyle(
                                  color: isReached
                                      ? const Color(0xFFFF6B6B)
                                      .withOpacity(0.7)
                                      : const Color(0xFF8888AA),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  margin:
                                  const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFF6B6B)
                                            .withOpacity(0.3),
                                        const Color(0xFFFF8E8E)
                                            .withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius:
                                    BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ВЫ ЗДЕСЬ',
                                    style: TextStyle(
                                      color: Color(0xFFFF6B6B),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showCityInfo(City city) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0A0A1A),
                const Color(0xFF16213E).withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFFF6B6B).withOpacity(0.2),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B6B).withOpacity(0.2),
                            const Color(0xFFFF6B6B).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.location_city,
                          color: Color(0xFFFF6B6B), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(city.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          Text('${city.distanceFromMoscow} км от Москвы',
                              style: const TextStyle(
                                  color: Color(0xFFFF6B6B), fontSize: 12)),
                        ],
                      ),
                    ),
                    if (city.isMajor)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF9800).withOpacity(0.3),
                              const Color(0xFFFF9800).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: Color(0xFFFF9800), size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _infoSection('📊 ОСНОВНАЯ ИНФОРМАЦИЯ', [
                  '👥 Население: ${city.population}',
                  '🗺️ Площадь: ${city.area}',
                  '📅 Основан: ${city.founded}',
                ]),
                const SizedBox(height: 10),
                _infoSection('📜 ИСТОРИЧЕСКАЯ СПРАВКА', [city.fact]),
                const SizedBox(height: 10),
                _infoSection('✨ ИНТЕРЕСНЫЕ ФАКТЫ', [
                  city.funFact1,
                  city.funFact2,
                  city.funFact3,
                  city.funFact4,
                ]),
                if (city.cuisine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _infoSection('🍽️ МЕСТНАЯ КУХНЯ', [city.cuisine]),
                ],
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF6B6B).withOpacity(0.2),
                          const Color(0xFFFF8E8E).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                      ),
                      child: const Text('Закрыть',
                          style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoSection(String title, List<String> lines) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF16213E).withOpacity(0.8),
            const Color(0xFF0F0F1A).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          ...lines.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l,
                style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 13,
                    height: 1.5)),
          )),
        ],
      ),
    );
  }

  Widget _buildQuote() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.05),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.format_quote_rounded,
              color: Color(0xFFFF6B6B), size: 28),
          const SizedBox(height: 10),
          const Text(
            'Дорога в тысячу миль\nначинается с одного шага',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '— Лао-Цзы',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static List<City> _getCities() {
    return [
      City("Москва", 0, "12,7 млн", "2 561 км²", "1147 г.", "🏛️ Сердце России. Москва — политический, экономический и культурный центр страны.", "Кремль — самая большая средневековая крепость в Европе, её стены протянулись на 2,2 км.", "В Москве 17 действующих вокзалов и 5 аэропортов, а также самое большое метро в Европе.", "Красная площадь — главная площадь страны, здесь находятся Храм Василия Блаженного и Мавзолей.", "Московский Кремль — резиденция президента РФ и объект Всемирного наследия ЮНЕСКО.", "Блины, пельмени, борщ", true),
      City("Балашиха", 22, "520 тыс.", "97 км²", "1830 г.", "🏭 Балашиха — крупнейший город-спутник Москвы, важный промышленный центр.", "В городе находится знаменитая усадьба Пехра-Яковлевское — образец русского классицизма.", "Балашихинский литейно-механический завод — одно из старейших предприятий региона.", "В Балашихе расположен крупнейший в Европе производственный комплекс Coca-Cola.", "Город активно застраивается новыми жилыми комплексами и парковыми зонами.", "", false),
      City("Щёлково", 30, "130 тыс.", "37 км²", "1925 г.", "🏭 Щёлково — текстильная столица региона, здесь работали крупнейшие мануфактуры XIX века.", "В городе находится Щёлковский историко-краеведческий музей с богатой коллекцией.", "Щёлковский район известен своими санаториями и домами отдыха на берегу Клязьмы.", "Здесь расположен аэродром Чкаловский — база военно-транспортной авиации России.", "В окрестностях города находится Медвежьи Озёра — популярное место отдыха москвичей.", "", false),
      City("Фрязино", 35, "60 тыс.", "9 км²", "1951 г.", "🔬 Фрязино — один из первых наукоградов России, центр радиоэлектроники и СВЧ-технологий.", "Здесь расположены ведущие НИИ в области электроники и космической связи.", "В городе находится единственный в России музей радиоэлектроники «Фрязино-наукоград».", "Фрязино — один из самых благоустроенных и компактных городов Подмосковья.", "В парке «Фрязино» проводятся ежегодные фестивали науки и техники.", "", false),
      City("Сергиев Посад", 75, "100 тыс.", "50 км²", "1345 г.", "🏛️ Сергиев Посад — духовная столица России, центр православного паломничества.", "Троице-Сергиева Лавра — крупнейший мужской монастырь страны, объект ЮНЕСКО.", "В городе находится знаменитая Сергиево-Посадская игрушка — народный промысел.", "Здесь работал известный художник Михаил Нестеров, создавший цикл картин о св. Сергии.", "В городе проходят ежегодные ярмарки народных промыслов и фестивали колокольного звона.", "Сергиевские пряники", false),
      City("Орехово-Зуево", 95, "118 тыс.", "47 км²", "1917 г.", "🧵 Орехово-Зуево — родина Морозовской текстильной мануфактуры, крупнейшей в России XIX века.", "В городе находится Саввино-Сторожевский монастырь, основанный учеником Сергия Радонежского.", "Здесь родился и жил знаменитый поэт Николай Заболоцкий.", "В Орехово-Зуеве расположен уникальный мост через Клязьму — памятник инженерной мысли.", "Город известен своими традициями футбола — здесь базируется клуб «Знамя Труда».", "", false),
      City("Владимир", 180, "350 тыс.", "308 км²", "990 г.", "🏰 Владимир — жемчужина Золотого кольца, древняя столица Северо-Восточной Руси.", "Золотые ворота, Успенский и Дмитриевский соборы — объекты Всемирного наследия ЮНЕСКО.", "В городе находится знаменитый Владимирский централ — тюрьма, известная по песне Михаила Круга.", "Здесь работали великие князья Андрей Боголюбский и Всеволод Большое Гнездо.", "Владимир славится своей вишнёвой настойкой и вишнёвыми садами.", "Владимирская вишня", false),
      City("Муром", 300, "110 тыс.", "44 км²", "862 г.", "🏰 Муром — родина былинного богатыря Ильи Муромца.", "Спасо-Преображенский монастырь — древнейший монастырь России, основанный в XI веке.", "В городе находится единственный в России памятник калачу.", "Муром — родина изобретателя телевидения Владимира Зворыкина.", "Каждое лето в Муроме проходит фестиваль «Муромское лето».", "Муромские калачи", false),
      City("Нижний Новгород", 400, "1,2 млн", "460 км²", "1221 г.", "🌅 Нижний Новгород — столица закатов, здесь находится самая длинная лестница в России.", "Нижегородский кремль — неприступная крепость.", "Город — родина изобретателя радио Александра Попова.", "Здесь находится знаменитая Нижегородская ярмарка.", "В городе расположен уникальный музей техники «ГАЗ».", "Нижегородский пряник", true),
      City("Кстово", 440, "66 тыс.", "18 км²", "1957 г.", "🛢️ Кстово — центр нефтепереработки.", "Озеро Святое — место паломничества.", "В окрестностях города расположен Щёлковский хутор.", "Кстово — город-спутник Нижнего Новгорода.", "Здесь находится уникальный храм.", "", false),
      City("Шумерля", 630, "30 тыс.", "13 км²", "1916 г.", "🚂 Шумерля — железнодорожный город.", "Шумерля знаменита своими валенками.", "В городе есть единственный в Чувашии железнодорожный техникум.", "Шумерлинский завод специализируется на оборудовании для ЖД.", "В окрестностях города находится заказник.", "", false),
      City("Чебоксары", 640, "497 тыс.", "233 км²", "1469 г.", "🌉 Чебоксары — жемчужина на Волге.", "46-метровая статуя Мать-покровительница.", "Чебоксарский залив — любимое место отдыха.", "Здесь находится один из крупнейших тракторных заводов.", "Чебоксары — родина космонавта Андрияна Николаева.", "Чебоксарский хмель", false),
      City("Казань", 800, "1,3 млн", "425 км²", "1005 г.", "🕌 Казань — третья столица России.", "Казанский Кремль — объект ЮНЕСКО.", "В городе находится самый большой в Европе цирк.", "Казань — родина Фёдора Шаляпина.", "Казанский университет — один из старейших в России.", "Эчпочмак, чак-чак", true),
      City("Набережные Челны", 1020, "545 тыс.", "171 км²", "1626 г.", "🚚 Набережные Челны — город грузовиков КАМАЗ.", "КАМАЗ — крупнейший в мире производитель.", "В городе работает музей истории КАМАЗа.", "Набережные Челны — один из самых молодых городов.", "В городе расположен парк «Прибрежный».", "", false),
      City("Пермь", 1380, "1,0 млн", "799 км²", "1723 г.", "🎭 Пермь — культурная столица Урала.", "Пермская деревянная скульптура — уникальное явление.", "В городе есть памятник букве «Ё».", "Пермь — родина изобретателя радио.", "Пермский период назван в честь города.", "Пермские пельмени", false),
      City("Екатеринбург", 1800, "1,5 млн", "1 111 км²", "1723 г.", "⛰️ Екатеринбург — столица Урала.", "Здесь находится памятник границе Европы и Азии.", "В городе крупнейший музей за Уралом.", "Екатеринбург — родина Бориса Ельцина.", "Единственный в мире памятник клавиатуре.", "Уральские пельмени", true),
      City("Тюмень", 2100, "830 тыс.", "698 км²", "1586 г.", "🛢️ Тюмень — нефтяная столица России.", "Самый длинный мост в России — Мост Влюблённых.", "Единственный в мире памятник собакам-поводырям.", "Тюменский драмтеатр — один из старейших.", "Город славится термальными источниками.", "", true),
      City("Ишим", 2420, "67 тыс.", "46 км²", "1687 г.", "📖 Ишим — родина автора «Конька-Горбунка».", "Единственный в мире памятник Коньку-Горбунку.", "Ишимский музей — один из лучших.", "Город стоит на Транссибирской магистрали.", "В Ишиме родился Михаил Пришвин.", "", false),
      City("Омск", 2700, "1,1 млн", "572 км²", "1716 г.", "🏰 Омск — врата Сибири.", "Омский драмтеатр — один из старейших.", "Крупнейший в Сибири технический университет.", "Знаменитая Омская ТЭЦ-5.", "Омск — родина актёра Михаила Ульянова.", "", true),
      City("Барабинск", 3050, "30 тыс.", "44 км²", "1893 г.", "🚂 Барабинск — крупный узел на Транссибе.", "Здесь был построен самолёт «Ан-2».", "Родина дважды Героя Советского Союза.", "Единственный памятник паровозу.", "Барабинская степь — заповедник.", "", false),
      City("Новосибирск", 3400, "1,6 млн", "502 км²", "1893 г.", "🎭 Новосибирск — культурная столица Сибири.", "Мост через Обь был первым в Сибири.", "Академгородок — мировой центр науки.", "Новосибирск стоит на реке Обь.", "Новосибирский зоопарк — один из лучших.", "", true),
      City("Томск", 3570, "576 тыс.", "294 км²", "1604 г.", "🎓 Томск — старейший университетский город.", "Более 100 памятников деревянного зодчества.", "Томск — центр атомной промышленности.", "Здесь родился Михаил Зощенко.", "Томские учёные создают нанотехнологии.", "", false),
      City("Кемерово", 3700, "557 тыс.", "282 км²", "1918 г.", "⛏️ Кемерово — столица Кузбасса.", "Мост через Томь — один из самых длинных.", "Кузбасский ботанический сад.", "Родина хоккеиста Сергея Бобровского.", "Угольный разрез «Кедровский».", "", false),
      City("Красноярск", 4100, "1,1 млн", "348 км²", "1628 г.", "🌉 Красноярск — город на Енисее.", "Вантовый мост — один из самых длинных.", "Красноярские Столбы — нацпарк.", "Многие знаменитости родом отсюда.", "Красноярская ГЭС — крупнейшая в мире.", "", true),
      City("Тайшет", 4510, "34 тыс.", "40 км²", "1897 г.", "🚂 Тайшет — начальная точка БАМа.", "Станция Тайшет — важный узел.", "Евгений Евтушенко упоминал Тайшет.", "Крупный лесопромышленный комплекс.", "Центр алюминиевой промышленности.", "", false),
      City("Иркутск", 5100, "617 тыс.", "277 км²", "1661 г.", "💎 Иркутск — ворота Байкала.", "Более 500 памятников архитектуры.", "Знаменский монастырь.", "Уникальный образец сибирского барокко.", "Иркутское водохранилище.", "Байкальский омуль", true),
      City("Улан-Удэ", 5600, "435 тыс.", "347 км²", "1666 г.", "🗿 Улан-Удэ — буддийская столица.", "Самый большой памятник Ленину.", "Город в долине рек Уды и Селенги.", "Крупнейший авиационный завод.", "Этнографический музей народов Забайкалья.", "Позы (буузы)", true),
      City("Чита", 6200, "350 тыс.", "538 км²", "1653 г.", "⛰️ Чита — столица Забайкалья.", "Церковь декабристов.", "Читинский дацан — старейший.", "Уникальный минеральный источник.", "Забайкальское зодчество.", "", true),
      City("Нерчинск", 6600, "15 тыс.", "24 км²", "1653 г.", "🏰 Нерчинск — один из первых острогов.", "Здесь был сослан протопоп Аввакум.", "Старейший краеведческий музей.", "Управление Нерчинской каторгой.", "Нерчинские рудники.", "", false),
      City("Свободный", 7680, "54 тыс.", "58 км²", "1912 г.", "🚀 Свободный — космодром «Восточный».", "Переименован из Алексеевска.", "Знаменит драмтеатром.", "Крупный сельхозрайон.", "Добыча золота и леса.", "", false),
      City("Белогорск", 7950, "65 тыс.", "39 км²", "1860 г.", "🛩️ Белогорск — центр штурмовой авиации.", "Музей авиации под открытым небом.", "Станция на Транссибе.", "Санатории и источники.", "Крупный сельхозцентр.", "", false),
      City("Хабаровск", 8500, "617 тыс.", "386 км²", "1858 г.", "🐅 Хабаровск — столица Дальнего Востока.", "Символ города — тигр.", "Амурский мост на Транссибе.", "Краеведческий музей.", "Центр деревянного зодчества.", "", true),
      City("Уссурийск", 9140, "173 тыс.", "173 км²", "1866 г.", "🌸 Уссурийск — город цветов.", "Заповедник «Кедровая Падь».", "Уссурийская тайга.", "Архитектура начала XX века.", "Центр виноградарства.", "", false),
      City("Владивосток", 9300, "605 тыс.", "331 км²", "1860 г.", "🌊 Владивосток — конечная точка Транссиба.", "Мост на Русский остров.", "Золотой мост и бухта Золотой Рог.", "Штаб Тихоокеанского флота.", "Крупнейший порт на Дальнем Востоке.", "Морепродукты, крабы", true),
    ];
  }
}

class City {
  final String name;
  final int distanceFromMoscow;
  final String population;
  final String area;
  final String founded;
  final String fact;
  final String funFact1;
  final String funFact2;
  final String funFact3;
  final String funFact4;
  final String cuisine;
  final bool isMajor;

  City(
      this.name,
      this.distanceFromMoscow,
      this.population,
      this.area,
      this.founded,
      this.fact,
      this.funFact1,
      this.funFact2,
      this.funFact3,
      this.funFact4,
      this.cuisine,
      this.isMajor,
      );
}