// features/fitness/ui/screens/workout_execution_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';
import '../widgets/timer_widget.dart';

// ==================== POWER MODE TOKENS ====================

class _Power {
  static const Color heroBase = Color(0xFF050505);
  static const Color heroDeep = Color(0xFF120700);

  static const Color volt = Color(0xFFFF5500);
  static const Color voltBright = Color(0xFFFF7A1A);
  static const Color magma = Color(0xFFFF2D55);
  static const Color plasma = Color(0xFFFFCC00);
  static const Color ice = Color(0xFF00E5FF);
  static const Color lime = Color(0xFFB4FF39);
  static const Color green = Color(0xFF00C853);
  static const Color red = Color(0xFFFF3B30);

  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCard2 = Color(0xFF2C2C2E);
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);

  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color card2(bool isDark) => isDark ? darkCard2 : const Color(0xFFF9FAFB);
  static Color textPrimary(bool isDark) => isDark ? Colors.white : Colors.black;
  static Color textSecondary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.6)
      : const Color(0xFF3C3C43).withOpacity(0.6);
  static Color textTertiary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.3)
      : const Color(0xFF3C3C43).withOpacity(0.3);
  static Color separator(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

  static List<BoxShadow> softGlow(Color color, {double strength = 0.18}) => [
    BoxShadow(color: color.withOpacity(strength), blurRadius: 16),
  ];

  static List<BoxShadow> glow(Color color, {double strength = 0.4, double blur = 24}) => [
    BoxShadow(
      color: color.withOpacity(strength),
      blurRadius: blur,
      offset: const Offset(0, 6),
    ),
  ];
}

class WorkoutExecutionScreen extends StatefulWidget {
  final WorkoutDay day;
  final bool isDark;

  const WorkoutExecutionScreen({
    super.key,
    required this.day,
    this.isDark = false,
  });

  @override
  State<WorkoutExecutionScreen> createState() =>
      _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  WorkoutPhase _phase = WorkoutPhase.setup;
  late List<ConfiguredExercise> _config;
  int _currentExIndex = 0;
  int _currentSetIndex = 0;
  bool _isCircuitMode = false;
  int _totalCircuits = 1;
  final Map<String, List<CompletedSetData>> _completedData = {};
  DateTime? _startTime;
  int _restSeconds = 90;

  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _repsControllers = {};

  int? _moodEnergy;
  int? _moodSleep;
  int? _moodMotivation;
  String? _moodNotes;
  String? _workoutPhotoPath;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isFinishing = false;
  String? _savedLogId;

  @override
  void initState() {
    super.initState();
    _config = widget.day.exercises.map((ex) {
      return ConfiguredExercise(
        exercise: ex,
        sets: List.generate(
          ex.sets.length,
              (i) => SetConfig(
            reps: ex.sets[i].reps,
            weight: ex.sets[i].weight,
            duration: 60,
            intensity: 5,
            isWarmup: ex.sets[i].isWarmup,
          ),
        ),
      );
    }).toList();

    for (int i = 0; i < _config.length; i++) {
      for (int j = 0; j < _config[i].sets.length; j++) {
        final set = _config[i].sets[j];
        _weightControllers['${i}_$j'] = TextEditingController(
          text: set.weight > 0 ? set.weight.toStringAsFixed(1) : '',
        );
        _repsControllers['${i}_$j'] = TextEditingController(
          text: set.reps > 0 ? set.reps.toString() : '',
        );
      }
    }

    _startTime = DateTime.now();
  }

  @override
  void dispose() {
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    for (final controller in _repsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();

    switch (_phase) {
      case WorkoutPhase.setup:
        return _buildSetupScreen(isDark, provider);
      case WorkoutPhase.active:
        return _buildActiveScreen(isDark, provider);
      case WorkoutPhase.rest:
        return _buildRestScreen(isDark, provider);
      case WorkoutPhase.completed:
        return _buildCompletedScreen(isDark);
    }
  }

  // =====================================================================
  // SETUP SCREEN
  // =====================================================================

  Widget _buildSetupScreen(bool isDark, FitnessProvider provider) {
    return Scaffold(
      backgroundColor: _Power.bg(isDark),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: _Power.bg(isDark).withOpacity(0.85),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: 60,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: _Power.textPrimary(isDark),
                    size: 22,
                  ),
                ),
              ),
            ),
            title: Text(
              'Тренировка',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: _Power.textPrimary(isDark),
              ),
            ),
            centerTitle: true,
            actions: [
              if (_config.length > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      Text(
                        'КРУГ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: _isCircuitMode
                              ? _Power.volt
                              : _Power.textTertiary(isDark),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: _isCircuitMode,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _isCircuitMode = v);
                          },
                          activeColor: _Power.volt,
                          activeTrackColor: _Power.volt.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Large title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ПОДГОТОВКА',
                    style: TextStyle(
                      color: _Power.volt,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isCircuitMode ? 'Круговая' : 'Свободная',
                    style: TextStyle(
                      color: _Power.textPrimary(isDark),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_config.length} упражнений • настрой подходы',
                    style: TextStyle(
                      color: _Power.textSecondary(isDark),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Exercise cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final config = _config[index];
                  final exData = provider.exercises.firstWhere(
                        (e) => e.id == config.exercise.exerciseId,
                    orElse: () => Exercise(id: '', name: '???'),
                  );
                  return _buildExerciseSetupCard(
                    isDark,
                    index,
                    config,
                    exData,
                  );
                },
                childCount: _config.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomSheet: Container(
        color: _Power.bg(isDark),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: _buildStartButton(isDark),
      ),
    );
  }

  Widget _buildStartButton(bool isDark) {
    final List<String> missingWeights = [];
    for (final config in _config) {
      final exData = context.read<FitnessProvider>().exercises.firstWhere(
            (e) => e.id == config.exercise.exerciseId,
        orElse: () => Exercise(id: '', name: '???'),
      );
      if (_isTimeBased(exData.exerciseType)) continue;

      for (int i = 0; i < config.sets.length; i++) {
        if (config.sets[i].weight <= 0) {
          missingWeights.add(exData.name);
          break;
        }
      }
    }

    final canStart = missingWeights.isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!canStart) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _Power.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _Power.red.withOpacity(0.3),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: _Power.red, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'УКАЖИТЕ ВЕС ДЛЯ:',
                      style: TextStyle(
                        fontSize: 10,
                        color: _Power.red,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...missingWeights.map((name) => Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 2),
                  child: Text(
                    '• $name',
                    style: TextStyle(
                      fontSize: 11,
                      color: _Power.textSecondary(isDark),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: canStart
                ? () async {
              HapticFeedback.mediumImpact();
              await _showPreWorkoutDialog();
              if (mounted) {
                setState(() => _phase = WorkoutPhase.active);
              }
            }
                : () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Укажите вес для всех силовых'),
                  backgroundColor: _Power.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
              canStart ? _Power.volt : _Power.textTertiary(isDark),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              shadowColor: _Power.volt.withOpacity(0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 22),
                const SizedBox(width: 8),
                Text(
                  _isCircuitMode
                      ? 'НАЧАТЬ • $_totalCircuits КРУГ.'
                      : 'НАЧАТЬ ТРЕНИРОВКУ',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================================
  // PRE-WORKOUT DIALOG
  // =====================================================================

  Future<void> _showPreWorkoutDialog() async {
    var energy = 5.0;
    var sleep = 5.0;
    var motivation = 5.0;
    final notesController = TextEditingController();
    File? selectedPhoto;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: _Power.card(widget.isDark),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _Power.textTertiary(widget.isDark),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ПЕРЕД ТРЕНИРОВКОЙ',
                  style: TextStyle(
                    color: _Power.volt,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Как настроение?',
                  style: TextStyle(
                    color: _Power.textPrimary(widget.isDark),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 20),
                _buildMoodSliderRow(
                    '⚡', 'Энергия', energy, (v) => setSheetState(() => energy = v)),
                const SizedBox(height: 10),
                _buildMoodSliderRow(
                    '😴', 'Сон', sleep, (v) => setSheetState(() => sleep = v)),
                const SizedBox(height: 10),
                _buildMoodSliderRow('🎯', 'Мотивация', motivation,
                        (v) => setSheetState(() => motivation = v)),
                const SizedBox(height: 20),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(
                    color: _Power.textPrimary(widget.isDark),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Заметки о самочувствии…',
                    hintStyle: TextStyle(
                      color: _Power.textTertiary(widget.isDark),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: _Power.card2(widget.isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final XFile? image = await _imagePicker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      setSheetState(
                              () => selectedPhoto = File(image.path));
                    }
                  },
                  child: Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _Power.card2(widget.isDark),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _Power.separator(widget.isDark),
                        width: 0.5,
                      ),
                    ),
                    child: selectedPhoto != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        selectedPhoto!,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                            _Power.volt.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_a_photo_rounded,
                            color: _Power.volt,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добавить фото тренировки',
                          style: TextStyle(
                            fontSize: 12,
                            color: _Power.textSecondary(
                                widget.isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                            _Power.textSecondary(widget.isDark),
                            side: BorderSide(
                              color: _Power.separator(widget.isDark),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Пропустить',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _moodEnergy = energy.toInt();
                            _moodSleep = sleep.toInt();
                            _moodMotivation = motivation.toInt();
                            _moodNotes = notesController.text.isNotEmpty
                                ? notesController.text
                                : null;
                            _workoutPhotoPath = selectedPhoto?.path;
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _Power.volt,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            shadowColor:
                            _Power.volt.withOpacity(0.5),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'НАЧАТЬ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodSliderRow(
      String emoji,
      String label,
      double value,
      Function(double) onChanged,
      ) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _Power.textSecondary(widget.isDark),
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _Power.volt,
              inactiveTrackColor: _Power.volt.withOpacity(0.15),
              thumbColor: _Power.volt,
              overlayColor: _Power.volt.withOpacity(0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${value.toInt()}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _Power.textPrimary(widget.isDark),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================================
  // EXERCISE SETUP CARD
  // =====================================================================

  Widget _buildExerciseSetupCard(
      bool isDark,
      int index,
      ConfiguredExercise config,
      Exercise exData,
      ) {
    final isTimeBased = _isTimeBased(exData.exerciseType);
    final accentColor = exData.muscleGroups.isNotEmpty
        ? exData.muscleGroups.first.color
        : _Power.volt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Power.separator(isDark), width: 0.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          iconColor: _Power.volt,
          collapsedIconColor: _Power.textSecondary(isDark),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
              boxShadow: _Power.softGlow(accentColor, strength: 0.15),
            ),
            child: Center(
              child: Text(
                exData.exerciseType.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          title: Text(
            exData.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: _Power.textPrimary(isDark),
            ),
          ),
          subtitle: Text(
            '${config.sets.length} подходов${isTimeBased ? " • по времени" : ""}',
            style: TextStyle(
              fontSize: 11,
              color: _Power.textSecondary(isDark),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  ...config.sets.asMap().entries.map((entry) {
                    return _buildSetRow(
                      isDark,
                      index,
                      entry.key,
                      entry.value,
                      isTimeBased,
                    );
                  }),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        final newIndex = config.sets.length;
                        config.sets.add(SetConfig(
                          reps: 10,
                          weight: 0,
                          duration: 60,
                          intensity: 5,
                        ));
                        _weightControllers['${index}_$newIndex'] =
                            TextEditingController();
                        _repsControllers['${index}_$newIndex'] =
                            TextEditingController(text: '10');
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: _Power.volt.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 16, color: _Power.volt),
                          const SizedBox(width: 6),
                          const Text(
                            'ДОБАВИТЬ ПОДХОД',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: _Power.volt,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(
      bool isDark,
      int exIndex,
      int setIndex,
      SetConfig set,
      bool isTimeBased,
      ) {

    final weightController = _weightControllers['${exIndex}_$setIndex'] ??
        TextEditingController();
    final repsController = _repsControllers['${exIndex}_$setIndex'] ??
        TextEditingController();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Power.card2(isDark),
        borderRadius: BorderRadius.circular(14),
        border: set.isWarmup
            ? Border.all(
          color: _Power.volt.withOpacity(0.4),
          width: 0.8,
        )
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _Power.volt.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'ПОДХОД ${setIndex + 1}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: _Power.volt,
                  ),
                ),
              ),
              if (set.isWarmup) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _Power.volt.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'РАЗМ.',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: _Power.volt,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => set.isWarmup = !set.isWarmup);
                },
                child: Icon(
                  Icons.whatshot_rounded,
                  size: 18,
                  color: set.isWarmup
                      ? _Power.volt
                      : _Power.textTertiary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isTimeBased) ...[
            _buildTimeSlider(
              icon: '⏱️',
              value: set.duration.toDouble(),
              min: 15,
              max: 300,
              divisions: 19,
              label: _formatSeconds(set.duration),
              onChanged: (v) =>
                  setState(() => set.duration = v.toInt()),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildTimeSlider(
              icon: '💪',
              value: set.intensity.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '${set.intensity}/10',
              onChanged: (v) =>
                  setState(() => set.intensity = v.toInt()),
              isDark: isDark,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildSetupField(
                    controller: repsController,
                    label: 'Повторений',
                    suffix: 'раз',
                    isDark: isDark,
                    onChanged: (v) =>
                        setState(() => set.reps = int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSetupField(
                    controller: weightController,
                    label: 'Вес',
                    suffix: 'кг',
                    isDark: isDark,
                    isDecimal: true,
                    onChanged: (v) => setState(
                            () => set.weight = double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSlider({
    required String icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required Function(double) onChanged,
    required bool isDark,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _Power.volt,
              inactiveTrackColor: _Power.volt.withOpacity(0.15),
              thumbColor: _Power.volt,
              overlayColor: _Power.volt.withOpacity(0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _Power.textPrimary(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required bool isDark,
    bool isDecimal = false,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _Power.textPrimary(isDark),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: _Power.textTertiary(isDark),
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _Power.textTertiary(isDark),
        ),
        filled: true,
        fillColor: _Power.card(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  // =====================================================================
  // ACTIVE SCREEN
  // =====================================================================

  Widget _buildActiveScreen(bool isDark, FitnessProvider provider) {
    final currentConfig = _getCurrentConfig();

    if (currentConfig == null) {
      return _buildCompletedScreen(isDark);
    }

    final exData = provider.exercises.firstWhere(
          (e) => e.id == currentConfig.exercise.exerciseId,
      orElse: () => Exercise(id: '', name: '???'),
    );
    final isTimeBased = _isTimeBased(exData.exerciseType);
    final set = currentConfig.sets[_currentSetIndex];

    final accentColor = exData.muscleGroups.isNotEmpty
        ? exData.muscleGroups.first.color
        : _Power.volt;

    final progress = _totalCompletedSets() / _getTotalSets().clamp(1, 999);

    return Scaffold(
      backgroundColor: _Power.bg(isDark),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: _Power.bg(isDark).withOpacity(0.85),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            leadingWidth: 60,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
              child: GestureDetector(
                onTap: () => _showExitDialog(context, isDark),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _Power.red.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: _Power.red,
                    size: 20,
                  ),
                ),
              ),
            ),
            title: Text(
              exData.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: _Power.textPrimary(isDark),
              ),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _skipExercise();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _Power.volt.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.skip_next_rounded,
                      color: _Power.volt,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Progress bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: _Power.separator(isDark),
                  valueColor: const AlwaysStoppedAnimation(_Power.volt),
                ),
              ),
            ),
          ),

          // Big number
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ПОДХОД',
                    style: TextStyle(
                      color: _Power.volt,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${_currentSetIndex + 1}',
                        style: TextStyle(
                          color: _Power.textPrimary(isDark),
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -3,
                          height: 1,
                        ),
                      ),
                      Text(
                        ' / ${currentConfig.sets.length}',
                        style: TextStyle(
                          color: _Power.textTertiary(isDark),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Exercise card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withOpacity(0.18),
                      accentColor.withOpacity(0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: accentColor.withOpacity(0.3),
                    width: 0.8,
                  ),
                  boxShadow: _Power.softGlow(accentColor, strength: 0.12),
                ),
                child: Column(
                  children: [
                    Text(
                      exData.exerciseType.emoji,
                      style: const TextStyle(fontSize: 56),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      exData.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: _Power.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isTimeBased)
                      _buildMetricRow(
                        '⏱️',
                        _formatSeconds(set.duration),
                        '💪',
                        '${set.intensity}/10',
                        isDark,
                      )
                    else
                      _buildMetricRow(
                        '🏋️',
                        '${set.reps} повт.',
                        '⚖️',
                        '${set.weight.toStringAsFixed(1)} кг',
                        isDark,
                      ),
                    if (set.isWarmup) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _Power.volt,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow:
                          _Power.softGlow(_Power.volt, strength: 0.5),
                        ),
                        child: const Text(
                          'РАЗМИНОЧНЫЙ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomSheet: Container(
        color: _Power.bg(isDark),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () =>
                    _showSetCompletionDialog(isDark, isTimeBased),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Power.volt,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: _Power.volt.withOpacity(0.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'ПОДХОД ВЫПОЛНЕН',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _skipSet();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  'ПРОПУСТИТЬ ПОДХОД',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: _Power.textSecondary(isDark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
      String emoji1,
      String value1,
      String emoji2,
      String value2,
      bool isDark,
      ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji1, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  value1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: _Power.textPrimary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji2, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  value2,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: _Power.textPrimary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================================
  // SET COMPLETION DIALOG
  // =====================================================================

  Future<void> _showSetCompletionDialog(
      bool isDark, bool isTimeBased) async {
    final config = _getCurrentConfig();
    if (config == null) return;
    final set = config.sets[_currentSetIndex];

    final actualRepsController =
    TextEditingController(text: set.reps.toString());
    final actualWeightController =
    TextEditingController(text: set.weight.toStringAsFixed(1));

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: _Power.card(isDark),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _Power.textTertiary(isDark),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ПОДХОД ВЫПОЛНЕН?',
                  style: TextStyle(
                    color: _Power.volt,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Подтвердите результат',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                    color: _Power.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _Power.volt.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _Power.volt.withOpacity(0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isTimeBased) ...[
                        _buildPlanChip(
                            '🏋️', '${set.reps} повт.', isDark),
                        const SizedBox(width: 10),
                        _buildPlanChip(
                            '⚖️',
                            '${set.weight.toStringAsFixed(1)} кг',
                            isDark),
                      ] else ...[
                        _buildPlanChip(
                            '⏱️', _formatSeconds(set.duration), isDark),
                        const SizedBox(width: 10),
                        _buildPlanChip(
                            '💪', '${set.intensity}/10', isDark),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (!isTimeBased) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ФАКТИЧЕСКИЙ РЕЗУЛЬТАТ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                        color: _Power.textTertiary(isDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActualField(
                          controller: actualRepsController,
                          label: 'Повторения',
                          suffix: 'раз',
                          isDark: isDark,
                          isDecimal: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActualField(
                          controller: actualWeightController,
                          label: 'Вес',
                          suffix: 'кг',
                          isDark: isDark,
                          isDecimal: true,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.replay_rounded,
                        label: 'Повторить',
                        color: _Power.textSecondary(isDark),
                        onTap: () => Navigator.pop(ctx, 'repeat'),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.skip_next_rounded,
                        label: 'Пропустить',
                        color: _Power.volt,
                        onTap: () => Navigator.pop(ctx, 'skip'),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, 'done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Power.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: _Power.green.withOpacity(0.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'ВЫПОЛНЕНО',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == 'done') {
      final actualReps =
          int.tryParse(actualRepsController.text) ?? set.reps;
      final actualWeight =
          double.tryParse(actualWeightController.text) ?? set.weight;

      _saveCompletedSet(
        reps: actualReps,
        weight: actualWeight,
        duration: set.duration,
        intensity: set.intensity,
        isWarmup: set.isWarmup,
      );
      _moveToNext();
    } else if (result == 'skip') {
      _skipSet();
    }

    actualRepsController.dispose();
    actualWeightController.dispose();
  }

  Widget _buildPlanChip(String emoji, String text, bool isDark) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$emoji $text',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: _Power.textPrimary(isDark),
        ),
      ),
    );
  }

  Widget _buildActualField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required bool isDark,
    required bool isDecimal,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: _Power.textPrimary(isDark),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: _Power.textTertiary(isDark),
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _Power.textTertiary(isDark),
        ),
        filled: true,
        fillColor: _Power.card2(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCompletedSet({
    required int reps,
    required double weight,
    required int duration,
    required int intensity,
    required bool isWarmup,
  }) {
    final config = _getCurrentConfig();
    if (config == null) return;
    final key = config.exercise.exerciseId;
    _completedData.putIfAbsent(key, () => []);
    _completedData[key]!.add(CompletedSetData(
      exerciseIndex: _currentExIndex,
      setIndex: _currentSetIndex,
      reps: reps,
      weight: weight,
      duration: duration,
      intensity: intensity,
      rpe: 0,
      isWarmup: isWarmup,
    ));
  }

  void _moveToNext() {
    final config = _getCurrentConfig();
    if (config == null) return;
    setState(() {
      if (_currentSetIndex < config.sets.length - 1) {
        _currentSetIndex++;
        _phase = WorkoutPhase.rest;
      } else {
        _currentSetIndex = 0;
        _currentExIndex++;
        if (_getCurrentConfig() == null) {
          _finishWorkout();
        } else {
          _phase = WorkoutPhase.rest;
        }
      }
    });
  }

  // =====================================================================
  // REST SCREEN
  // =====================================================================

  Widget _buildRestScreen(bool isDark, FitnessProvider provider) {
    final nextConfig = _getCurrentConfig();
    final nextExData = nextConfig != null
        ? provider.exercises.firstWhere(
          (e) => e.id == nextConfig.exercise.exerciseId,
      orElse: () => Exercise(id: '', name: '???'),
    )
        : null;

    final List<Map<String, dynamic>> remainingInfo = [];
    for (int i = _currentExIndex; i < _config.length; i++) {
      final config = _config[i];
      final exData = provider.exercises.firstWhere(
            (e) => e.id == config.exercise.exerciseId,
        orElse: () => Exercise(id: '', name: '???'),
      );
      remainingInfo.add({
        'exercise': exData,
        'sets': config.sets,
      });
    }

    return Scaffold(
      backgroundColor: _Power.bg(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Timer area
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Glow background
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: _Power.glow(_Power.volt,
                              strength: 0.15, blur: 60),
                        ),
                      ),
                    ),
                  ),
                  TimerWidget(
                    isDark: isDark,
                    restSeconds: _restSeconds,
                    onTimerComplete: () =>
                        setState(() => _phase = WorkoutPhase.active),
                    onSkip: () =>
                        setState(() => _phase = WorkoutPhase.active),
                  ),
                ],
              ),
            ),

            // Stats panel
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: _Power.card(isDark),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _Power.separator(isDark),
                    width: 0.5,
                  ),
                ),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _Power.card2(isDark),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          labelColor: Colors.white,
                          unselectedLabelColor:
                          _Power.textSecondary(isDark),
                          indicator: BoxDecoration(
                            color: _Power.volt,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow:
                            _Power.softGlow(_Power.volt, strength: 0.3),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'СВОДКА'),
                            Tab(text: 'ОСТАЛОСЬ'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryHeader(
                                      isDark, 'ОБЩИЙ ПРОГРЕСС'),
                                  const SizedBox(height: 12),
                                  _buildProgressStat(
                                    isDark,
                                    Icons.check_circle_rounded,
                                    'Выполнено подходов',
                                    '${_totalCompletedSets()}',
                                    _Power.green,
                                  ),
                                  _buildProgressStat(
                                    isDark,
                                    Icons.fitness_center_rounded,
                                    'Упражнений пройдено',
                                    '${_completedData.keys.length} / ${_config.length}',
                                    _Power.volt,
                                  ),
                                  _buildProgressStat(
                                    isDark,
                                    Icons.monitor_weight_rounded,
                                    'Общий тоннаж',
                                    '${_calculateTotalVolume().toStringAsFixed(0)} кг',
                                    _Power.ice,
                                  ),
                                  if (nextExData != null) ...[
                                    const SizedBox(height: 16),
                                    _buildSummaryHeader(
                                        isDark, 'ДАЛЕЕ'),
                                    const SizedBox(height: 12),
                                    _buildNextExerciseCard(
                                        isDark, nextExData, nextConfig!),
                                  ],
                                ],
                              ),
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryHeader(
                                      isDark, 'ОСТАВШИЕСЯ'),
                                  const SizedBox(height: 12),
                                  if (remainingInfo.isEmpty)
                                    Text(
                                      'Все упражнения выполнены!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _Power.textSecondary(isDark),
                                      ),
                                    )
                                  else
                                    ...remainingInfo.map((info) {
                                      final ex =
                                      info['exercise'] as Exercise;
                                      final sets =
                                      info['sets'] as List<SetConfig>;
                                      return _buildRemainingExerciseCard(
                                          isDark, ex, sets);
                                    }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(bool isDark, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
        color: _Power.volt,
      ),
    );
  }

  Widget _buildProgressStat(
      bool isDark,
      IconData icon,
      String label,
      String value,
      Color color,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _Power.card2(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _Power.textSecondary(isDark),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextExerciseCard(
      bool isDark,
      Exercise exData,
      ConfiguredExercise config,
      ) {
    final isTimeBased = _isTimeBased(exData.exerciseType);
    final accentColor = exData.muscleGroups.isNotEmpty
        ? exData.muscleGroups.first.color
        : _Power.volt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.25),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                exData.exerciseType.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exData.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: _Power.textPrimary(isDark),
                      ),
                    ),
                    if (exData.muscleGroups.isNotEmpty)
                      Text(
                        exData.muscleGroups
                            .map((m) => m.displayName)
                            .join(' • '),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _Power.textTertiary(isDark),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: config.sets.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isTimeBased
                      ? _formatSeconds(s.duration)
                      : '${s.weight.toStringAsFixed(0)}кг×${s.reps}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _Power.textPrimary(isDark),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingExerciseCard(
      bool isDark,
      Exercise ex,
      List<SetConfig> sets,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Power.card2(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(ex.exerciseType.emoji,
              style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: _Power.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${sets.length} подходов',
                  style: TextStyle(
                    fontSize: 11,
                    color: _Power.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: _Power.textTertiary(isDark),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // COMPLETED SCREEN
  // =====================================================================

  Widget _buildCompletedScreen(bool isDark) {
    return Scaffold(
      backgroundColor: _Power.bg(isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
          child: Column(
            children: [
              // Big success icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_Power.green, Color(0xFF008B00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: _Power.glow(_Power.green,
                        strength: 0.45, blur: 40),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'ТРЕНИРОВКА ЗАВЕРШЕНА',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  color: _Power.volt,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Красава 💪',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  height: 1.05,
                  color: _Power.textPrimary(isDark),
                ),
              ),
              if (_savedLogId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'ID: $_savedLogId',
                    style: TextStyle(
                      fontSize: 10,
                      color: _Power.textTertiary(isDark),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              const SizedBox(height: 28),

              // Stats
              _buildDetailedCompletionStats(isDark),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Power.volt,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    shadowColor: _Power.volt.withOpacity(0.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'ВЕРНУТЬСЯ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
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
  }

  Widget _buildDetailedCompletionStats(bool isDark) {
    final provider = context.read<FitnessProvider>();
    final Map<String, List<CompletedSetData>> grouped = {};

    for (final config in _config) {
      final exData = provider.exercises.firstWhere(
            (e) => e.id == config.exercise.exerciseId,
        orElse: () => Exercise(id: '', name: '???'),
      );
      final list = _completedData[config.exercise.exerciseId] ?? [];
      if (list.isNotEmpty) {
        grouped[exData.name] = list;
      }
    }

    final totalExercises = grouped.length;
    final totalSets = _totalCompletedSets();
    final totalVolume = _calculateTotalVolume();
    final duration =
        DateTime.now().difference(_startTime!).inMinutes;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Power.card(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Power.separator(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _Power.volt.withOpacity(0.12),
                  _Power.volt.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildSummaryItem('🏋️', '$totalExercises', 'УПР'),
                _buildDivider(isDark),
                _buildSummaryItem('💪', '$totalSets', 'ПОДХ'),
                _buildDivider(isDark),
                _buildSummaryItem('⏱️', '$duration', 'МИН'),
                _buildDivider(isDark),
                _buildSummaryItem(
                  '📊',
                  '${totalVolume.toStringAsFixed(0)}',
                  'КГ',
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          Text(
            'ПОДРОБНОСТИ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
              color: _Power.volt,
            ),
          ),
          const SizedBox(height: 12),

          ...grouped.entries.map((entry) {
            final sets =
            entry.value.where((s) => !s.isWarmup).toList();
            final warmupSets =
            entry.value.where((s) => s.isWarmup).toList();

            if (sets.isEmpty && warmupSets.isEmpty) {
              return const SizedBox.shrink();
            }

            final maxWeight = sets.isNotEmpty
                ? sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b)
                : 0.0;
            final volume = sets.fold(
                0.0, (sum, s) => sum + s.weight * s.reps);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Power.card2(isDark),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: _Power.textPrimary(isDark),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _Power.volt.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${sets.length} ПОДХ',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: _Power.volt,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (sets.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sets.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '${s.weight.toStringAsFixed(0)}кг×${s.reps}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _Power.textPrimary(isDark),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (warmupSets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'РАЗМИНКА: ${warmupSets.map((s) => "${s.weight.toStringAsFixed(0)}кг×${s.reps}").join(", ")}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: _Power.volt.withOpacity(0.7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    height: 0.5,
                    color: _Power.separator(isDark),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCell(
                          'МАКС',
                          '${maxWeight.toStringAsFixed(0)} кг',
                          isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildStatCell(
                          'ТОННАЖ',
                          '${volume.toStringAsFixed(0)} кг',
                          isDark,
                          valueColor: _Power.volt,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 0.5,
      height: 32,
      color: _Power.separator(isDark),
    );
  }

  Widget _buildStatCell(
      String label,
      String value,
      bool isDark, {
        Color? valueColor,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: _Power.textTertiary(isDark),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: valueColor ?? _Power.textPrimary(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1,
              color: _Power.textPrimary(widget.isDark),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: _Power.textTertiary(widget.isDark),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalVolume() {
    double total = 0;
    for (final config in _config) {
      final sets = _completedData[config.exercise.exerciseId] ?? [];
      for (final s in sets) {
        if (!s.isWarmup) total += s.weight * s.reps;
      }
    }
    return total;
  }

  ConfiguredExercise? _getCurrentConfig() {
    if (_currentExIndex >= _config.length) return null;
    return _config[_currentExIndex];
  }

  void _skipSet() {
    HapticFeedback.lightImpact();
    final config = _getCurrentConfig();
    if (config == null) return;
    setState(() {
      if (_currentSetIndex < config.sets.length - 1) {
        _currentSetIndex++;
      } else {
        _currentSetIndex = 0;
        _currentExIndex++;
      }
    });
    if (_getCurrentConfig() == null) {
      _finishWorkout();
    }
  }

  void _skipExercise() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentExIndex++;
      _currentSetIndex = 0;
    });
    if (_getCurrentConfig() == null) {
      _finishWorkout();
    }
  }

  int _totalCompletedSets() {
    int total = 0;
    for (final list in _completedData.values) {
      total += list.where((s) => !s.isWarmup).length;
    }
    return total;
  }

  double _getTotalSets() {
    double total = 0;
    for (final c in _config) {
      total += c.sets.length;
    }
    return total;
  }

  Future<void> _finishWorkout() async {
    if (_isFinishing) {
      debugPrint('⚠️ _finishWorkout уже выполняется, пропускаем повторный вызов');
      return;
    }

    if (_phase == WorkoutPhase.completed) {
      debugPrint('⚠️ Тренировка уже завершена, пропускаем');
      return;
    }

    if (_savedLogId != null) {
      debugPrint('⚠️ Лог уже сохранён ($_savedLogId), пропускаем');
      return;
    }

    if (_completedData.isEmpty) {
      if (mounted) {
        setState(() => _phase = WorkoutPhase.completed);
      }
      return;
    }

    _isFinishing = true;

    try {
      final provider = context.read<FitnessProvider>();

      final List<WorkoutExercise> exercisesLog = [];
      for (final config in _config) {
        final exerciseId = config.exercise.exerciseId;
        final completedSets = _completedData[exerciseId] ?? [];
        final List<ExerciseSet> sets = [];

        for (int i = 0; i < config.sets.length; i++) {
          final planned = config.sets[i];
          final actual = completedSets.firstWhere(
                (cs) => cs.setIndex == i,
            orElse: () => CompletedSetData(
              exerciseIndex: 0,
              setIndex: i,
              reps: planned.reps,
              weight: planned.weight,
              duration: planned.duration,
              intensity: planned.intensity,
              rpe: 0,
              isWarmup: planned.isWarmup,
            ),
          );

          sets.add(ExerciseSet(
            setNumber: i + 1,
            reps: actual.reps,
            weight: actual.weight,
            rpe: actual.rpe,
            isWarmup: actual.isWarmup,
            status: completedSets.any((cs) => cs.setIndex == i)
                ? SetStatus.completed
                : SetStatus.skipped,
          ));
        }

        exercisesLog.add(WorkoutExercise(
          id: config.exercise.id,
          exerciseId: exerciseId,
          order: config.exercise.order,
          sets: sets,
          groupType: config.exercise.groupType,
          restBetweenSeconds: config.exercise.restBetweenSeconds,
        ));
      }

      final totalVolume = _calculateTotalVolume();
      final logId = DateTime.now().millisecondsSinceEpoch.toString();
      final log = WorkoutLog(
        id: logId,
        date: DateTime.now(),
        programId: widget.day.programId,
        dayNumber: widget.day.dayNumber,
        status: WorkoutDayStatus.completed,
        startTime: _startTime,
        endTime: DateTime.now(),
        exercisesLog: exercisesLog,
        totalRestTime: null,
        totalVolume: totalVolume,
        avgRpe: null,
        bodyWeight: null,
        moodEnergy: _moodEnergy,
        moodSleep: _moodSleep,
        moodMotivation: _moodMotivation,
        moodNotes: _moodNotes,
        workoutPhotoPath: _workoutPhotoPath,
      );

      await provider.saveWorkoutLogDirect(log);
      _savedLogId = logId;
      debugPrint(
          '✅ Тренировка сохранена (ОДИН РАЗ): $logId, упражнений: ${exercisesLog.length}');

      if (mounted) {
        setState(() => _phase = WorkoutPhase.completed);
      }
    } catch (e) {
      debugPrint('❌ Ошибка сохранения лога: $e');
      if (mounted) {
        setState(() => _phase = WorkoutPhase.completed);
      }
    }
  }

  Future<bool> _showExitDialog(BuildContext context, bool isDark) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 60),
        child: Container(
          decoration: BoxDecoration(
            color: _Power.card(isDark),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  children: [
                    Text(
                      'Прервать тренировку?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _Power.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Прогресс не будет сохранён',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _Power.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                  height: 0.5, color: _Power.separator(isDark)),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: Text(
                          'Продолжить',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            color: _Power.volt,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 0.5,
                    height: 50,
                    color: _Power.separator(isDark),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: const Text(
                          'Прервать',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _Power.red,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && mounted) Navigator.pop(context);
    return result ?? false;
  }

  bool _isTimeBased(ExerciseType type) {
    return type == ExerciseType.cardio ||
        type == ExerciseType.yoga ||
        type == ExerciseType.other;
  }

  String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}м ${s}с' : '${s}с';
  }
}

// ==================== МОДЕЛИ ====================

enum WorkoutPhase { setup, active, rest, completed }

class ConfiguredExercise {
  final WorkoutExercise exercise;
  final List<SetConfig> sets;
  ConfiguredExercise({required this.exercise, required this.sets});
}

class SetConfig {
  int reps;
  double weight;
  int duration;
  int intensity;
  bool isWarmup;
  SetConfig({
    this.reps = 10,
    this.weight = 0,
    this.duration = 60,
    this.intensity = 5,
    this.isWarmup = false,
  });
}

class CompletedSetData {
  final int exerciseIndex;
  final int setIndex;
  final int reps;
  final double weight;
  final int duration;
  final int intensity;
  final double rpe;
  final bool isWarmup;
  CompletedSetData({
    required this.exerciseIndex,
    required this.setIndex,
    required this.reps,
    required this.weight,
    required this.duration,
    required this.intensity,
    required this.rpe,
    required this.isWarmup,
  });
}