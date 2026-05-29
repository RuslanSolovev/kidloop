import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';

class PedometerScreen extends StatefulWidget {
  const PedometerScreen({super.key});

  @override
  State<PedometerScreen> createState() => _PedometerScreenState();
}

class _PedometerScreenState extends State<PedometerScreen> with SingleTickerProviderStateMixin {
  int _totalSteps = 0;
  int _todaySteps = 0;
  bool _isWalking = false;
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  late AnimationController _pulseController;
  bool _showJourney = false;

  final double _stepLength = 0.75;
  final int _totalDistance = 9300;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _loadData();
    _initPedometer();
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _todaySteps = prefs.getInt('today_steps') ?? 0;
      _totalSteps = prefs.getInt('total_steps') ?? 0;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('today_steps', _todaySteps);
    await prefs.setInt('total_steps', _totalSteps);
  }

  void _initPedometer() {
    try {
      _stepSubscription = Pedometer.stepCountStream.listen((event) {
        if (mounted) {
          setState(() {
            _todaySteps = event.steps;
            _totalSteps++;
          });
          _saveData();
        }
      });
      _statusSubscription = Pedometer.pedestrianStatusStream.listen((event) {
        if (mounted) setState(() => _isWalking = event.status == 'walking');
      });
    } catch (e) {
      print("Pedometer error: $e");
    }
  }

  double get _walkedKm => (_totalSteps * _stepLength) / 1000.0;
  double get _progress => (_walkedKm / _totalDistance).clamp(0.0, 1.0);

  City get _currentCity {
    return _cities.lastWhere((c) => c.distanceFromMoscow <= _walkedKm, orElse: () => _cities.first);
  }

  City? get _nextCity {
    final index = _cities.indexOf(_currentCity);
    return index < _cities.length - 1 ? _cities[index + 1] : null;
  }

  final List<City> _cities = _getCities();

  @override
  Widget build(BuildContext context) {
    if (_showJourney) return _buildJourneyView();
    return _buildPedometerView();
  }

  Widget _buildPedometerView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showJourney = true),
            icon: const Icon(Icons.map, color: Color(0xFFFF6B6B)),
            label: const Text('Путешествие', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) {
                final pulse = _pulseController.value;
                return Container(
                  width: 120 + (pulse * 20),
                  height: 120 + (pulse * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isWalking ? const Color(0xFFFF6B6B).withOpacity(0.15 + pulse * 0.1) : const Color(0xFF2D2D44),
                    border: Border.all(color: _isWalking ? const Color(0xFFFF6B6B) : const Color(0xFF8888AA), width: 3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_todaySteps', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: _isWalking ? const Color(0xFFFF6B6B) : Colors.white)),
                      const Text('шагов сегодня', style: TextStyle(color: Color(0xFF8888AA), fontSize: 14)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            _statCard('👣 Всего шагов', '$_totalSteps'),
            const SizedBox(height: 12),
            _statCard('📏 Пройдено км', _walkedKm.toStringAsFixed(1)),
            const SizedBox(height: 12),
            _statCard('🎯 До Владивостока', '${(_totalDistance - _walkedKm).toStringAsFixed(0)} км'),
            const SizedBox(height: 30),
            Text(_isWalking ? '🟢 Вы идёте!' : '⚪ Ожидание шагов...', style: TextStyle(color: _isWalking ? const Color(0xFFFF6B6B) : const Color(0xFF8888AA), fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyView() {
    final nextCity = _nextCity;
    final progressToNext = nextCity != null ? ((_walkedKm - _currentCity.distanceFromMoscow) / (nextCity.distanceFromMoscow - _currentCity.distanceFromMoscow)).clamp(0.0, 1.0) : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFFFF6B6B)), onPressed: () => setState(() => _showJourney = false)),
        title: const Text('Путь к Владивостоку', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProgressCard(),
          const SizedBox(height: 16),
          _buildCityCard(_currentCity, isCurrent: true),
          if (nextCity != null) ...[
            const SizedBox(height: 12),
            _buildNextCityCard(nextCity, progressToNext),
          ],
          const SizedBox(height: 16),
          _buildTimeline(),
          const SizedBox(height: 24),
          const Text('«Дорога в тысячу миль начинается с одного шага» — Лао-Цзы', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8888AA), fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Text('${(_progress * 100).toStringAsFixed(3)}%', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFFF6B6B))),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: _progress, minHeight: 10, backgroundColor: const Color(0xFF2D2D44), color: const Color(0xFFFF6B6B))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _miniStat('👣', '$_totalSteps шагов'),
            _miniStat('📏', '${_walkedKm.toStringAsFixed(1)} км'),
            _miniStat('🎯', '${(_totalDistance - _walkedKm).toStringAsFixed(0)} км'),
          ]),
        ],
      ),
    );
  }

  Widget _buildCityCard(City city, {bool isCurrent = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isCurrent ? const Color(0xFF16213E) : const Color(0xFF0F0F1A), borderRadius: BorderRadius.circular(24), border: isCurrent ? Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)) : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFF6B6B).withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.location_on, color: Color(0xFFFF6B6B), size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isCurrent ? '📍 ТЕКУЩАЯ ОСТАНОВКА' : city.name, style: TextStyle(color: isCurrent ? const Color(0xFFFF6B6B) : Colors.white, fontSize: isCurrent ? 11 : 20, fontWeight: isCurrent ? FontWeight.normal : FontWeight.bold)),
            if (isCurrent) Text(city.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text('${city.distanceFromMoscow} км от Москвы', style: TextStyle(color: isCurrent ? const Color(0xFFFF6B6B) : const Color(0xFF8888AA), fontSize: 13)),
          ])),
        ]),
        const SizedBox(height: 12),
        _factRow(city.fact),
        _factRow(city.funFact1),
        _factRow(city.funFact2),
        if (city.cuisine.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('🍽️ ${city.cuisine}', style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13))),
      ]),
    );
  }

  Widget _buildNextCityCard(City city, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF0F0F1A), borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('🎯 СЛЕДУЮЩАЯ', style: TextStyle(color: Color(0xFF8888AA), fontSize: 11)), const Spacer(), Text('${(progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8),
        Text(city.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text('${city.distanceFromMoscow} км от Москвы', style: const TextStyle(color: Color(0xFF8888AA), fontSize: 13)),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: const Color(0xFF2D2D44), color: const Color(0xFFFF6B6B))),
      ]),
    );
  }

  Widget _buildTimeline() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12),
        child: Text('🗺️ МАРШРУТ • ${_cities.length} ГОРОДОВ',
            style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, letterSpacing: 2)),
      ),
      ..._cities.map((city) {
        final isReached = city.distanceFromMoscow <= _walkedKm;
        final isLast = _cities.last == city;
        return InkWell(
          onTap: () => _showCityInfo(city),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 40, child: Column(children: [
              Container(
                  width: city.isMajor ? 24 : 16,
                  height: city.isMajor ? 24 : 16,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isReached ? const Color(0xFFFF6B6B) : const Color(0xFF2D2D44)),
                  child: isReached && city.isMajor
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null),
              if (!isLast)
                Container(
                    width: 2,
                    height: 40,
                    color: isReached
                        ? const Color(0xFFFF6B6B).withOpacity(0.5)
                        : const Color(0xFF2D2D44)),
            ])),
            Expanded(
                child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isReached
                            ? const Color(0xFFFF6B6B).withOpacity(0.12)
                            : const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(city.name,
                          style: TextStyle(
                              color: isReached ? const Color(0xFFFF6B6B) : Colors.white,
                              fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
                              fontSize: city.isMajor ? 15 : 13)),
                      Text('${city.distanceFromMoscow} км',
                          style: const TextStyle(color: Color(0xFF8888AA), fontSize: 11)),
                    ]))),
          ]),
        );
      }),
    ]);
  }

  void _showCityInfo(City city) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A1A),
        title: Row(children: [Text(city.name, style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)), const SizedBox(width: 8), Text('(${city.distanceFromMoscow} км)', style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 14))]),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _infoSection('📊 ОСНОВНАЯ ИНФОРМАЦИЯ', ['👥 Население: ${city.population}', '🗺️ Площадь: ${city.area}', '📅 Основан: ${city.founded}']),
            _infoSection('📜 ИСТОРИЯ', [city.fact]),
            _infoSection('✨ ИНТЕРЕСНЫЕ ФАКТЫ', [city.funFact1, city.funFact2, city.funFact3, city.funFact4]),
            if (city.cuisine.isNotEmpty) _infoSection('🍽️ КУХНЯ', [city.cuisine]),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть', style: TextStyle(color: Color(0xFFFF6B6B))))],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _infoSection(String title, List<String> lines) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11)),
        const SizedBox(height: 8),
        ...lines.map((l) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)))),
      ]),
    );
  }

  Widget _statCard(String title, String value) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Color(0xFF8888AA), fontSize: 15)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]));
  }

  Widget _miniStat(String emoji, String value) {
    return Column(children: [Text(emoji, style: const TextStyle(fontSize: 18)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.white, fontSize: 12))]);
  }

  Widget _factRow(String text) {
    return Padding(padding: const EdgeInsets.only(top: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('✨ ', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)), Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)))]));
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

  City(this.name, this.distanceFromMoscow, this.population, this.area, this.founded, this.fact, this.funFact1, this.funFact2, this.funFact3, this.funFact4, this.cuisine, this.isMajor);
}