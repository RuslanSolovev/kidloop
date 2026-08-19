// features/fitness/ui/screens/wellbeing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/fitness_provider.dart';

class WellbeingScreen extends StatefulWidget {
  final bool isDark;

  const WellbeingScreen({
    super.key,
    this.isDark = false,
  });

  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen>
    with SingleTickerProviderStateMixin {
  int _energy = 7;
  int _sleep = 7;
  int _motivation = 7;
  String? _notes;
  List<String> _painAreas = [];
  bool _isSubmitting = false;
  bool _showStats = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _statsController;
  late Animation<double> _statsAnimation;

  final List<String> _moodEmojis = ['😫', '😩', '😐', '🙂', '😊', '😁', '🤩', '🔥', '💪', '🚀'];
  final List<String> _moodLabels = [
    'Ужасно', 'Плохо', 'Средне', 'Нормально', 'Хорошо',
    'Отлично', 'Замечательно', 'Супер', 'Великолепно', 'Невероятно'
  ];

  final List<Color> _moodColors = [
    Color(0xFFEF5350), Color(0xFFFF7043), Color(0xFFFFA726),
    Color(0xFFFFD54F), Color(0xFFAED581), Color(0xFF66BB6A),
    Color(0xFF26A69A), Color(0xFF42A5F5), Color(0xFF7E57C2),
    Color(0xFFAB47BC),
  ];

  final List<String> _motivationQuotes = [
    '🌟 Каждый день — это новый шанс стать лучше',
    '💪 Ты сильнее, чем думаешь',
    '🔥 Продолжай в том же духе!',
    '🏆 Маленькие шаги ведут к большим результатам',
    '⭐ Ты делаешь великое дело — заботишься о себе',
    '🌈 После дождя всегда выходит солнце',
    '🚀 Твой потенциал безграничен',
    '💚 Слушай своё тело — оно знает, что ему нужно',
    '🎯 Сегодня ты стал сильнее, чем вчера',
    '🌟 Ты — главный герой своей истории',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _statsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _statsAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _statsController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final todayWellbeing = provider.getTodayWellbeing();
    final notes = provider.wellbeingNotes;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: _buildAppBar(isDark, provider),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreeting(isDark, todayWellbeing),
                const SizedBox(height: 16),
                if (notes.isNotEmpty) _buildStatsToggle(isDark, provider),
                if (todayWellbeing != null) ...[
                  const SizedBox(height: 16),
                  _buildTodayCard(isDark, todayWellbeing),
                ],
                const SizedBox(height: 16),
                _buildFormCard(isDark, provider),
                const SizedBox(height: 20),
                if (notes.isNotEmpty) ...[
                  _buildHistoryHeader(isDark, notes),
                  const SizedBox(height: 12),
                  ...notes.take(10).map((note) =>
                      _buildHistoryCard(isDark, note, provider)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== APP BAR ====================

  AppBar _buildAppBar(bool isDark, FitnessProvider provider) {
    final stats = provider.getWellbeingStats();
    final avgMood = stats['avgEnergy'] ?? 0;

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF34C759), Color(0xFF28A745)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Самочувствие',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          if (provider.wellbeingNotes.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getColorForValue(avgMood.toInt()),
                    _getColorForValue(avgMood.toInt()).withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getEmojiForValue(avgMood.toInt()),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    avgMood.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.info_outline_rounded,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
          onPressed: () => _showInfoDialog(context, isDark),
        ),
      ],
    );
  }

  // ==================== GREETING ====================

  Widget _buildGreeting(bool isDark, WellbeingNote? todayWellbeing) {
    final timeOfDay = DateTime.now().hour;
    String greeting;
    String emoji;

    if (timeOfDay < 6) {
      greeting = 'Доброй ночи';
      emoji = '🌙';
    } else if (timeOfDay < 12) {
      greeting = 'Доброе утро';
      emoji = '🌅';
    } else if (timeOfDay < 18) {
      greeting = 'Добрый день';
      emoji = '☀️';
    } else {
      greeting = 'Добрый вечер';
      emoji = '🌆';
    }

    final hasRecord = todayWellbeing != null;
    final randomQuote = _motivationQuotes[DateTime.now().day % _motivationQuotes.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF34C759).withOpacity(0.12),
            const Color(0xFF34C759).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF34C759).withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  hasRecord
                      ? '✅ Сегодня уже записано'
                      : randomQuote,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasRecord ? FontWeight.w600 : FontWeight.w400,
                    color: hasRecord
                        ? const Color(0xFF34C759)
                        : (isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasRecord)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF34C759), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Записано',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34C759),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==================== STATS TOGGLE ====================

  Widget _buildStatsToggle(bool isDark, FitnessProvider provider) {
    final stats = provider.getWellbeingStats();
    final total = stats['total']?.toInt() ?? 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _showStats = !_showStats;
          if (_showStats) {
            _statsController.forward(from: 0);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.analytics_rounded,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Статистика за всё время',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ),
            Text(
              '$total записей',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              turns: _showStats ? 0.5 : 0,
              child: Icon(
                Icons.expand_more_rounded,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TODAY CARD ====================

  Widget _buildTodayCard(bool isDark, WellbeingNote note) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF34C759).withOpacity(0.15),
            const Color(0xFF34C759).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF34C759).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.today_rounded,
                  color: Color(0xFF34C759),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Сегодняшнее состояние',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDate(note.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMoodStat(
                '⚡',
                'Энергия',
                note.energyLevel,
                isDark,
              ),
              _buildMoodStat(
                '😴',
                'Сон',
                note.sleepQuality,
                isDark,
              ),
              _buildMoodStat(
                '🎯',
                'Мотивация',
                note.motivationLevel,
                isDark,
              ),
            ],
          ),
          if (note.painAreas.isNotEmpty && !note.painAreas.contains('Нет болей')) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.healing_rounded,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Боли: ${note.painAreas.join(" • ")}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (note.notes != null && note.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('💭 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      '"${note.notes!}"',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodStat(String emoji, String label, int value, bool isDark) {
    final color = _getColorForValue(value);
    final moodEmoji = _moodEmojis[value - 1];
    final moodLabel = _moodLabels[value - 1];

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.25),
                color.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              moodEmoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              '/10',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          moodLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.grey.shade500,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white24 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  // ==================== FORM CARD ====================

  Widget _buildFormCard(bool isDark, FitnessProvider provider) {
    final hasTodayRecord = provider.getTodayWellbeing() != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34C759), Color(0xFF28A745)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                hasTodayRecord ? 'Обновить состояние' : 'Записать самочувствие',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Энергия
          _buildAnimatedSlider(
            isDark,
            'Энергия',
            Icons.flash_on_rounded,
            _energy.toDouble(),
                (v) {
              setState(() {
                _energy = v.toInt();
              });
            },
          ),

          // Сон
          _buildAnimatedSlider(
            isDark,
            'Сон',
            Icons.bed_rounded,
            _sleep.toDouble(),
                (v) {
              setState(() {
                _sleep = v.toInt();
              });
            },
          ),

          // Мотивация
          _buildAnimatedSlider(
            isDark,
            'Мотивация',
            Icons.rocket_launch_rounded,
            _motivation.toDouble(),
                (v) {
              setState(() {
                _motivation = v.toInt();
              });
            },
          ),

          const SizedBox(height: 16),

          // Болевые точки
          _buildPainSelector(isDark),

          const SizedBox(height: 16),

          // Заметки
          _buildNotesField(isDark),

          const SizedBox(height: 20),

          // Кнопка сохранения
          _buildSubmitButton(isDark, provider, hasTodayRecord),
        ],
      ),
    );
  }

  // ==================== ANIMATED SLIDER ====================

  Widget _buildAnimatedSlider(
      bool isDark,
      String label,
      IconData icon,
      double value,
      Function(double) onChanged,
      ) {
    final intValue = value.toInt();
    final emoji = _moodEmojis[intValue - 1];
    final color = _getColorForValue(intValue);
    final moodLabel = _moodLabels[intValue - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(intValue),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.15),
                      color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$intValue/10',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: color,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          moodLabel,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: color.withOpacity(0.7),
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
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 12,
              pressedElevation: 8,
            ),
            thumbColor: color,
            activeTrackColor: color,
            inactiveTrackColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            overlayColor: color.withOpacity(0.2),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 24,
            ),
            valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
            valueIndicatorColor: color,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          child: Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: onChanged,
            label: '$intValue',
          ),
        ),
      ],
    );
  }

  Color _getColorForValue(int value) {
    if (value <= 3) return const Color(0xFFEF5350);
    if (value <= 5) return const Color(0xFFFFA726);
    if (value <= 7) return const Color(0xFFFFD54F);
    return const Color(0xFF66BB6A);
  }

  String _getEmojiForValue(int value) {
    return _moodEmojis[value.clamp(1, 10) - 1];
  }

  // ==================== PAIN SELECTOR ====================

  Widget _buildPainSelector(bool isDark) {
    final painOptions = [
      'Спина',
      'Плечи',
      'Колени',
      'Шея',
      'Голова',
      'Ноги',
      'Руки',
      'Нет болей',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.healing_rounded,
                  color: Colors.orange, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Болевые точки',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            if (_painAreas.isNotEmpty) ...[
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _painAreas.clear());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Очистить все',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: painOptions.map((area) {
            final isSelected = _painAreas.contains(area);
            final isNoPain = area == 'Нет болей';

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  if (isSelected) {
                    _painAreas.remove(area);
                  } else {
                    if (isNoPain) {
                      _painAreas.clear();
                      _painAreas.add(area);
                    } else {
                      _painAreas.remove('Нет болей');
                      _painAreas.add(area);
                    }
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? isNoPain
                      ? Colors.green.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15)
                      : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? isNoPain
                        ? Colors.green
                        : Colors.orange
                        : Colors.transparent,
                    width: isSelected ? 1.5 : 0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Icon(
                        isNoPain ? Icons.check_circle_rounded : Icons.warning_rounded,
                        color: isNoPain ? Colors.green : Colors.orange,
                        size: 14,
                      ),
                    if (isSelected) const SizedBox(width: 4),
                    Text(
                      area,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? isNoPain
                            ? Colors.green
                            : Colors.orange
                            : (isDark
                            ? Colors.white54
                            : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==================== NOTES FIELD ====================

  Widget _buildNotesField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.note_rounded,
                  color: Colors.grey, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Заметки',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          maxLines: 3,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Как вы себя чувствуете? Расскажите подробнее...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey.shade400,
              fontSize: 13,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F1115)
                : const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          onChanged: (v) => _notes = v.isEmpty ? null : v,
        ),
      ],
    );
  }

  // ==================== SUBMIT BUTTON ====================

  Widget _buildSubmitButton(
      bool isDark, FitnessProvider provider, bool hasTodayRecord) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: ElevatedButton.icon(
          onPressed: _isSubmitting
              ? null
              : () async {
            if (!hasTodayRecord) {
              if (_energy == 0 || _sleep == 0 || _motivation == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Пожалуйста, оцените все показатели'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
            }

            setState(() => _isSubmitting = true);

            try {
              await provider.addWellbeingNote(
                energyLevel: _energy,
                sleepQuality: _sleep,
                motivationLevel: _motivation,
                painAreas: _painAreas,
                notes: _notes,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        hasTodayRecord
                            ? 'Самочувствие обновлено! 🌟'
                            : 'Самочувствие записано! 🌟',
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF34C759),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );

              setState(() {
                _notes = null;
                _painAreas = [];
                _energy = 7;
                _sleep = 7;
                _motivation = 7;
              });
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка: ${e.toString()}'),
                  backgroundColor: Colors.red.shade400,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } finally {
              setState(() => _isSubmitting = false);
            }
          },
          icon: _isSubmitting
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Icon(
            hasTodayRecord ? Icons.refresh_rounded : Icons.save_rounded,
            size: 22,
          ),
          label: Text(
            _isSubmitting
                ? 'Сохранение...'
                : (hasTodayRecord ? 'Обновить' : 'Сохранить'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF34C759),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: _isSubmitting ? 0 : 4,
          ),
        ),
      ),
    );
  }

  // ==================== HISTORY HEADER ====================

  Widget _buildHistoryHeader(bool isDark, List<WellbeingNote> notes) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.history_rounded,
            size: 18,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'История',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${notes.length} записей',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== УЛУЧШЕННАЯ КАРТОЧКА ИСТОРИИ С ЦИФРАМИ ====================

  Widget _buildHistoryCard(bool isDark, WellbeingNote note,
      FitnessProvider provider) {
    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await provider.deleteWellbeingNote(note.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запись удалена'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.delete_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Дата
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatDate(note.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Энергия
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getColorForValue(note.energyLevel).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _moodEmojis[note.energyLevel - 1],
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${note.energyLevel}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _getColorForValue(note.energyLevel),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Сон
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getColorForValue(note.sleepQuality).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _moodEmojis[note.sleepQuality - 1],
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${note.sleepQuality}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _getColorForValue(note.sleepQuality),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Мотивация
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getColorForValue(note.motivationLevel).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _moodEmojis[note.motivationLevel - 1],
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${note.motivationLevel}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _getColorForValue(note.motivationLevel),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Боли
            if (note.painAreas.isNotEmpty && !note.painAreas.contains('Нет болей')) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: note.painAreas.map((area) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '🔴 $area',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Заметки
            if (note.notes != null && note.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('💭', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      note.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Дополнительная информация — среднее значение за день
            if (note.energyLevel > 0 && note.sleepQuality > 0 && note.motivationLevel > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.analytics_rounded,
                      size: 12,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Среднее: ${((note.energyLevel + note.sleepQuality + note.motivationLevel) / 3).toStringAsFixed(1)}/10',
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== INFO DIALOG ====================

  void _showInfoDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.info_rounded, color: Color(0xFF34C759)),
            const SizedBox(width: 10),
            const Text('О самочувствии',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('⚡ Энергия', 'Уровень бодрости и активности'),
            const SizedBox(height: 8),
            _buildInfoRow('😴 Сон', 'Качество и продолжительность сна'),
            const SizedBox(height: 8),
            _buildInfoRow('🎯 Мотивация', 'Желание тренироваться и развиваться'),
            const SizedBox(height: 8),
            _buildInfoRow('🔴 Боли', 'Отметьте зоны дискомфорта'),
            const SizedBox(height: 8),
            _buildInfoRow('💭 Заметки', 'Детали и наблюдения'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_rounded, color: Color(0xFF34C759), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Записывайте самочувствие ежедневно, чтобы отслеживать свой прогресс и вовремя замечать изменения',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF34C759),
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Expanded(
          child: Text(description,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ],
    );
  }

  // ==================== HELPERS ====================

  String _formatDate(DateTime date) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    final now = DateTime.now();
    final isToday = date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;

    if (isToday) return 'Сегодня';

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year;

    if (isYesterday) return 'Вчера';

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ==================== РАСШИРЕНИЕ ДЛЯ PROVIDER ====================

extension WellbeingStats on FitnessProvider {
  Map<String, double> getWellbeingStats() {
    if (wellbeingNotes.isEmpty) {
      return {
        'avgEnergy': 0,
        'avgSleep': 0,
        'avgMotivation': 0,
        'total': 0,
      };
    }

    final total = wellbeingNotes.length.toDouble();
    final avgEnergy = wellbeingNotes.map((n) => n.energyLevel).reduce((a, b) => a + b) / total;
    final avgSleep = wellbeingNotes.map((n) => n.sleepQuality).reduce((a, b) => a + b) / total;
    final avgMotivation = wellbeingNotes.map((n) => n.motivationLevel).reduce((a, b) => a + b) / total;

    return {
      'avgEnergy': double.parse(avgEnergy.toStringAsFixed(1)),
      'avgSleep': double.parse(avgSleep.toStringAsFixed(1)),
      'avgMotivation': double.parse(avgMotivation.toStringAsFixed(1)),
      'total': total,
    };
  }
}