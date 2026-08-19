// features/fitness/ui/screens/workout_execution_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';
import '../widgets/timer_widget.dart';

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

class _WorkoutExecutionScreenState
    extends State<WorkoutExecutionScreen> {
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

  // 🔥 Настроение и фото
  int? _moodEnergy;
  int? _moodSleep;
  int? _moodMotivation;
  String? _moodNotes;
  String? _workoutPhotoPath;
  final ImagePicker _imagePicker = ImagePicker();

  // 🔒 ЗАЩИТА ОТ ДУБЛИРОВАНИЯ ЗАПИСЕЙ В ЖУРНАЛЕ
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

  // ==================== НАСТРОЙКА ====================

  Widget _buildSetupScreen(bool isDark, FitnessProvider provider) {
    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: AppBar(
        backgroundColor:
        isDark ? const Color(0xFF1A1D24) : Colors.white,
        elevation: 0,
        title: const Text('Настройка тренировки',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_config.length > 1)
            Row(
              children: [
                Text('Круговая',
                    style: TextStyle(
                        fontSize: 10,
                        color: _isCircuitMode
                            ? const Color(0xFFFF6B35)
                            : Colors.grey)),
                Switch(
                  value: _isCircuitMode,
                  onChanged: (v) =>
                      setState(() => _isCircuitMode = v),
                  activeColor: const Color(0xFFFF6B35),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _config.length,
              itemBuilder: (context, index) {
                final config = _config[index];
                final exData = provider.exercises.firstWhere(
                      (e) => e.id == config.exercise.exerciseId,
                  orElse: () => Exercise(id: '', name: '???'),
                );
                return _buildExerciseSetupCard(
                    isDark, index, config, exData);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildStartButton(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(bool isDark) {
    final List<String> missingWeights = [];
    for (final config in _config) {
      final exData = context
          .read<FitnessProvider>()
          .exercises
          .firstWhere(
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
      children: [
        if (!canStart) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Установите вес для упражнений:',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                ...missingWeights.map((name) => Padding(
                  padding: const EdgeInsets.only(
                      left: 26, bottom: 2),
                  child: Text('• $name',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white70
                              : Colors.grey.shade700)),
                )),
              ],
            ),
          ),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canStart
                ? () async {
              await _showPreWorkoutDialog();
              if (mounted) {
                setState(
                        () => _phase = WorkoutPhase.active);
              }
            }
                : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Установите вес для всех силовых упражнений'),
                  backgroundColor: Colors.red,
                  behavior:
                  SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_isCircuitMode
                ? 'Начать круговую ($_totalCircuits кругов)'
                : 'Начать тренировку'),
            style: ElevatedButton.styleFrom(
              backgroundColor: canStart
                  ? const Color(0xFFFF6B35)
                  : Colors.grey,
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16)),
              textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== ДИАЛОГ НАСТРОЕНИЯ И ФОТО ====================

  Future<void> _showPreWorkoutDialog() async {
    var energy = 5.0;
    var sleep = 5.0;
    var motivation = 5.0;
    final notesController = TextEditingController();
    File? selectedPhoto;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          backgroundColor: widget.isDark
              ? const Color(0xFF1A1D24)
              : Colors.white,
          title: Row(
            children: [
              const Text('Перед тренировкой',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Icon(Icons.mood_rounded, color: Colors.orange.shade400),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Как настроение?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white70
                            : Colors.grey.shade700)),
                const SizedBox(height: 16),
                _buildMoodSliderRow('⚡', 'Энергия', energy,
                        (v) => setDialogState(() => energy = v)),
                _buildMoodSliderRow('😴', 'Сон', sleep,
                        (v) => setDialogState(() => sleep = v)),
                _buildMoodSliderRow('🎯', 'Мотивация', motivation,
                        (v) => setDialogState(() => motivation = v)),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Заметки о самочувствии...',
                    hintStyle: TextStyle(
                        color: widget.isDark
                            ? Colors.white38
                            : Colors.grey.shade400,
                        fontSize: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
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
                      setDialogState(
                              () => selectedPhoto = File(image.path));
                    }
                  },
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: selectedPhoto != null
                        ? ClipRRect(
                      borderRadius:
                      BorderRadius.circular(12),
                      child: Image.file(selectedPhoto!,
                          fit: BoxFit.cover),
                    )
                        : Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded,
                            color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text('Добавить фото тренировки',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Пропустить',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _moodEnergy = energy.toInt();
                _moodSleep = sleep.toInt();
                _moodMotivation = motivation.toInt();
                _moodNotes = notesController.text.isNotEmpty
                    ? notesController.text
                    : null;
                _workoutPhotoPath = selectedPhoto?.path;
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Начать'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodSliderRow(String emoji, String label, double value,
      Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        SizedBox(
          width: 60,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            label: value.toInt().toString(),
            activeColor: const Color(0xFFFF6B35),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 30,
          child: Text('${value.toInt()}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildExerciseSetupCard(
      bool isDark,
      int index,
      ConfiguredExercise config,
      Exercise exData,
      ) {
    final isTimeBased =
    _isTimeBased(exData.exerciseType);
    return Card(
      color: isDark
          ? const Color(0xFF1A1D24)
          : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: exData.muscleGroups.isNotEmpty
                ? exData.muscleGroups.first.color
                .withOpacity(0.2)
                : const Color(0xFFFF6B35)
                .withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(exData.exerciseType.emoji,
                style: const TextStyle(fontSize: 18)),
          ),
        ),
        title: Text(exData.name,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Colors.white
                    : Colors.black87)),
        subtitle: Text(
          '${config.sets.length} подходов${isTimeBased ? " • время" : ""}',
          style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? Colors.white38
                  : Colors.grey.shade500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 0, 16, 16),
            child: Column(
              children: [
                ...config.sets.asMap().entries.map((
                    entry,
                    ) {
                  return _buildSetRow(
                    isDark,
                    index,
                    entry.key,
                    entry.value,
                    isTimeBased,
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      final newIndex =
                          config.sets.length;
                      config.sets.add(SetConfig(
                          reps: 10,
                          weight: 0,
                          duration: 60,
                          intensity: 5));
                      _weightControllers[
                      '${index}_$newIndex'] =
                          TextEditingController();
                      _repsControllers[
                      '${index}_$newIndex'] =
                          TextEditingController(
                              text: '10');
                    });
                  },
                  icon: const Icon(Icons.add,
                      size: 16),
                  label: const Text(
                      'Добавить подход',
                      style:
                      TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                      foregroundColor:
                      const Color(0xFFFF6B35)),
                ),
              ],
            ),
          ),
        ],
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
    final weightController =
    _weightControllers['${exIndex}_$setIndex'];
    final repsController =
    _repsControllers['${exIndex}_$setIndex'];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1115)
            : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: set.isWarmup
            ? Border.all(
            color:
            Colors.orange.withOpacity(0.5))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Подход ${setIndex + 1}',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white54
                          : Colors.grey.shade600)),
              if (set.isWarmup) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.orange
                          .withOpacity(0.2),
                      borderRadius:
                      BorderRadius.circular(4)),
                  child: const Text('разм.',
                      style: TextStyle(
                          fontSize: 7,
                          color: Colors.orange)),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    set.isWarmup = !set.isWarmup;
                  });
                },
                child: Icon(Icons.whatshot,
                    size: 16,
                    color: set.isWarmup
                        ? Colors.orange
                        : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isTimeBased) ...[
            Row(
              children: [
                const Text('⏱️',
                    style:
                    TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: set.duration.toDouble(),
                    min: 15,
                    max: 300,
                    divisions: 19,
                    onChanged: (v) => setState(() =>
                    set.duration = v.toInt()),
                  ),
                ),
                Text(
                    _formatSeconds(
                        set.duration),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight:
                        FontWeight.w700)),
              ],
            ),
            Row(
              children: [
                const Text('💪',
                    style:
                    TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value:
                    set.intensity.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (v) => setState(() =>
                    set.intensity =
                        v.toInt()),
                  ),
                ),
                Text('${set.intensity}/10',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight:
                        FontWeight.w700)),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: repsController,
                    keyboardType:
                    TextInputType.number,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Повторений',
                      labelStyle:
                      const TextStyle(
                          fontSize: 9,
                          color: Colors.grey),
                      border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(8)),
                      contentPadding:
                      const EdgeInsets
                          .symmetric(
                          horizontal: 12,
                          vertical: 10),
                      isDense: false,
                    ),
                    onChanged: (v) =>
                        setState(() =>
                        set.reps =
                            int.tryParse(
                                v) ??
                                0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: weightController,
                    keyboardType:
                    TextInputType.numberWithOptions(
                        decimal: true),
                    style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Вес (кг)',
                      labelStyle:
                      const TextStyle(
                          fontSize: 9,
                          color: Colors.grey),
                      border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(8)),
                      contentPadding:
                      const EdgeInsets
                          .symmetric(
                          horizontal: 12,
                          vertical: 10),
                      isDense: false,
                      suffixText: 'кг',
                      suffixStyle:
                      TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors
                              .white38
                              : Colors
                              .grey
                              .shade500),
                    ),
                    onChanged: (v) =>
                        setState(() =>
                        set.weight =
                            double.tryParse(
                                v) ??
                                0),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==================== АКТИВНАЯ ТРЕНИРОВКА ====================

  Widget _buildActiveScreen(
      bool isDark, FitnessProvider provider) {
    final currentConfig = _getCurrentConfig();

    // 🔒 ИСПРАВЛЕНО: Убрали вызов _finishWorkout() из build-метода!
    // Раньше здесь было: if (currentConfig == null) { _finishWorkout(); ... }
    // Это вызывало дублирование при каждом rebuild.
    if (currentConfig == null) {
      // Если тренировка завершена, просто показываем экран завершения
      // БЕЗ вызова _finishWorkout() (он уже был вызван один раз в _moveToNext или _skipSet/_skipExercise)
      return _buildCompletedScreen(isDark);
    }

    final exData = provider.exercises.firstWhere(
          (e) => e.id == currentConfig.exercise.exerciseId,
      orElse: () =>
          Exercise(id: '', name: '???'),
    );
    final isTimeBased =
    _isTimeBased(exData.exerciseType);
    final set = currentConfig.sets[_currentSetIndex];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0D14)
          : const Color(0xFFF2F5F9),
      appBar: AppBar(
        backgroundColor:
        isDark ? const Color(0xFF1A1D24) : Colors.white,
        elevation: 0,
        title: Text(exData.name,
            style: TextStyle(
                color: isDark
                    ? Colors.white
                    : Colors.black87,
                fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.skip_next,
                  color: Colors.orange),
              onPressed: _skipExercise),
          IconButton(
              icon: Icon(Icons.close,
                  color: Colors.red.shade300),
              onPressed: () =>
                  _showExitDialog(context, isDark)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _totalCompletedSets() /
                  _getTotalSets().clamp(1, 999),
              backgroundColor: isDark
                  ? Colors.white10
                  : Colors.grey.shade200,
              valueColor:
              const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF6B35)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (exData.muscleGroups.isNotEmpty
                        ? exData.muscleGroups.first
                        .color
                        : const Color(0xFFFF6B35))
                        .withOpacity(0.3),
                    (exData.muscleGroups.isNotEmpty
                        ? exData.muscleGroups.first
                        .color
                        : const Color(0xFFFF6B35))
                        .withOpacity(0.05),
                  ],
                ),
                borderRadius:
                BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(exData.exerciseType.emoji,
                      style: const TextStyle(
                          fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(exData.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : Colors.black87)),
                  const SizedBox(height: 12),
                  Text(
                    'Подход ${_currentSetIndex + 1} из ${currentConfig.sets.length}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF6B35)),
                  ),
                  if (isTimeBased)
                    Text(
                        '⏱️ ${_formatSeconds(set.duration)} • Интенсивность ${set.intensity}/10',
                        style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey
                                .shade700))
                  else
                    Text(
                        '🏋️ ${set.reps} повт. × ${set.weight.toStringAsFixed(1)} кг',
                        style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey
                                .shade700)),
                  if (set.isWarmup)
                    Container(
                      margin: const EdgeInsets.only(
                          top: 8),
                      padding: const EdgeInsets
                          .symmetric(
                          horizontal: 8,
                          vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.orange
                              .withOpacity(0.2),
                          borderRadius:
                          BorderRadius.circular(
                              6)),
                      child: const Text(
                          'РАЗМИНОЧНЫЙ',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight:
                              FontWeight
                                  .w700)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showSetCompletionDialog(
                        isDark, isTimeBased),
                icon: const Icon(Icons.check_rounded,
                    size: 28),
                label: const Text('ПОДХОД ВЫПОЛНЕН',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                          16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _skipSet,
                icon: const Icon(Icons.skip_next,
                    size: 18),
                label: const Text(
                    'Пропустить подход'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding:
                  const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                          14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ДИАЛОГ ПОДТВЕРЖДЕНИЯ ПОДХОДА ====================

  Future<void> _showSetCompletionDialog(
      bool isDark, bool isTimeBased) async {
    final config = _getCurrentConfig();
    if (config == null) return;
    final set = config.sets[_currentSetIndex];

    final actualRepsController =
    TextEditingController(text: set.reps.toString());
    final actualWeightController = TextEditingController(
        text: set.weight.toStringAsFixed(1));

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
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1D24)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white38
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Подход выполнен?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B35).withOpacity(0.15),
                      const Color(0xFFFF6B35).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    if (!isTimeBased) ...[
                      _buildPlanChip(
                          '🏋️',
                          '${set.reps} повт.',
                          isDark),
                      const SizedBox(width: 12),
                      _buildPlanChip(
                          '⚖️',
                          '${set.weight.toStringAsFixed(1)} кг',
                          isDark),
                    ] else ...[
                      _buildPlanChip(
                          '⏱️',
                          _formatSeconds(set.duration),
                          isDark),
                      const SizedBox(width: 12),
                      _buildPlanChip(
                          '💪',
                          '${set.intensity}/10',
                          isDark),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!isTimeBased) ...[
                Text(
                  'Фактический результат',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white70
                        : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActualField(
                        controller: actualRepsController,
                        label: 'Повторения',
                        suffix: 'раз',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActualField(
                        controller: actualWeightController,
                        label: 'Вес',
                        suffix: 'кг',
                        isDark: isDark,
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
                      color: Colors.blueGrey,
                      onTap: () => Navigator.pop(ctx, 'repeat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.skip_next_rounded,
                      label: 'Пропустить',
                      color: Colors.orange,
                      onTap: () => Navigator.pop(ctx, 'skip'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pop(ctx, 'done'),
                  icon: const Icon(Icons.check_rounded,
                      size: 24),
                  label: const Text(
                    'ВЫПОЛНЕНО',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == 'done') {
      final actualReps =
          int.tryParse(actualRepsController.text) ??
              set.reps;
      final actualWeight =
          double.tryParse(actualWeightController.text) ??
              set.weight;

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
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$emoji $text',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildActualField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      keyboardType:
      TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white38 : Colors.grey.shade500,
        ),
        filled: true,
        fillColor: isDark
            ? const Color(0xFF0F1115)
            : const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        side: BorderSide(color: color.withOpacity(0.5)),
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
      if (_currentSetIndex <
          config.sets.length - 1) {
        _currentSetIndex++;
        _phase = WorkoutPhase.rest;
      } else {
        _currentSetIndex = 0;
        _currentExIndex++;
        if (_getCurrentConfig() == null) {
          // 🔒 Тренировка завершена - вызываем _finishWorkout ОДИН РАЗ
          // Защита от повторного вызова внутри _finishWorkout через флаг _isFinishing
          _finishWorkout();
        } else {
          _phase = WorkoutPhase.rest;
        }
      }
    });
  }

  // ==================== ЭКРАН ОТДЫХА ====================

  Widget _buildRestScreen(
      bool isDark, FitnessProvider provider) {
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
      backgroundColor:
      isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: TimerWidget(
                isDark: isDark,
                restSeconds: _restSeconds,
                onTimerComplete: () =>
                    setState(() => _phase = WorkoutPhase.active),
                onSkip: () =>
                    setState(() => _phase = WorkoutPhase.active),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1D24)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          labelColor: Colors.white,
                          unselectedLabelColor: isDark
                              ? Colors.white38
                              : Colors.grey.shade500,
                          indicator: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                          indicatorSize:
                          TabBarIndicatorSize.tab,
                          labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          padding:
                          const EdgeInsets.all(3),
                          tabs: const [
                            Tab(text: 'Сводка'),
                            Tab(text: 'Осталось'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            SingleChildScrollView(
                              padding:
                              const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  _buildSummaryHeader(
                                      isDark,
                                      'Общий прогресс'),
                                  const SizedBox(height: 12),
                                  _buildProgressStat(
                                      isDark,
                                      Icons
                                          .check_circle_rounded,
                                      'Выполнено подходов',
                                      '${_totalCompletedSets()}',
                                      Colors.green),
                                  _buildProgressStat(
                                      isDark,
                                      Icons
                                          .fitness_center_rounded,
                                      'Упражнений пройдено',
                                      '${_completedData.keys.length} / ${_config.length}',
                                      const Color(
                                          0xFFFF6B35)),
                                  _buildProgressStat(
                                      isDark,
                                      Icons
                                          .monitor_weight_rounded,
                                      'Общий тоннаж',
                                      '${_calculateTotalVolume().toStringAsFixed(0)} кг',
                                      Colors.blue),
                                  const SizedBox(height: 16),
                                  Divider(
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.grey
                                        .shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  if (nextExData != null) ...[
                                    _buildSummaryHeader(
                                        isDark,
                                        '⏭️ Следующее'),
                                    const SizedBox(
                                        height: 12),
                                    _buildNextExerciseCard(
                                        isDark,
                                        nextExData,
                                        nextConfig!),
                                  ],
                                ],
                              ),
                            ),
                            SingleChildScrollView(
                              padding:
                              const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  _buildSummaryHeader(
                                      isDark,
                                      'Оставшиеся упражнения'),
                                  const SizedBox(height: 12),
                                  if (remainingInfo.isEmpty)
                                    Text(
                                      'Вы выполнили все упражнения!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                        FontWeight.w600,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey
                                            .shade600,
                                      ),
                                    )
                                  else
                                    ...remainingInfo.map(
                                            (info) {
                                          final ex = info[
                                          'exercise']
                                          as Exercise;
                                          final sets = info[
                                          'sets']
                                          as List<
                                              SetConfig>;
                                          return _buildRemainingExerciseCard(
                                              isDark,
                                              ex,
                                              sets);
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
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildProgressStat(
      bool isDark,
      IconData icon,
      String label,
      String value,
      Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
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
      ConfiguredExercise config) {
    final isTimeBased = _isTimeBased(exData.exerciseType);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (exData.muscleGroups.isNotEmpty
                ? exData.muscleGroups.first.color
                : const Color(0xFFFF6B35))
                .withOpacity(0.2),
            (exData.muscleGroups.isNotEmpty
                ? exData.muscleGroups.first.color
                : const Color(0xFFFF6B35))
                .withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (exData.muscleGroups.isNotEmpty
              ? exData.muscleGroups.first.color
              : const Color(0xFFFF6B35))
              .withOpacity(0.3),
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
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (exData.muscleGroups.isNotEmpty)
                      Text(
                        exData.muscleGroups
                            .map((m) => m.displayName)
                            .join(' • '),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors.white38
                              : Colors.grey.shade500,
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
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isTimeBased
                      ? _formatSeconds(s.duration)
                      : '${s.weight.toStringAsFixed(0)}кг×${s.reps}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
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
      bool isDark, Exercise ex, List<SetConfig> sets) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sets.length} подхода(ов)',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: isDark ? Colors.white24 : Colors.grey.shade400),
        ],
      ),
    );
  }

  // ==================== ЗАВЕРШЕНИЕ ====================

  Widget _buildCompletedScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0D14)
          : const Color(0xFFF2F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration:
              const Duration(milliseconds: 800),
              builder: (context, value, child) =>
                  Transform.scale(
                    scale: value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [
                              Color(0xFF4CAF50),
                              Color(0xFF2E7D32)
                            ]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(
                                  0xFF4CAF50)
                                  .withOpacity(0.4),
                              blurRadius: 30)
                        ],
                      ),
                      child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 64),
                    ),
                  ),
            ),
            const SizedBox(height: 32),
            Text('Тренировка завершена!',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.white
                        : Colors.black87)),
            if (_savedLogId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'ID: $_savedLogId',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _buildDetailedCompletionStats(isDark),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pop(context),
                icon:
                const Icon(Icons.home_rounded),
                label: const Text('Вернуться'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(
                      vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                          16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedCompletionStats(
      bool isDark) {
    final provider =
    context.read<FitnessProvider>();
    final Map<String, List<CompletedSetData>>
    grouped = {};

    for (final config in _config) {
      final exData =
      provider.exercises.firstWhere(
            (e) =>
        e.id == config.exercise.exerciseId,
        orElse: () =>
            Exercise(id: '', name: '???'),
      );
      final list = _completedData[
      config.exercise.exerciseId] ??
          [];
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1D24)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFFFF6B35)
                    .withOpacity(0.1),
                const Color(0xFFFF6B35)
                    .withOpacity(0.05),
              ]),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('🏋️',
                    '$totalExercises', 'упражнений'),
                _buildSummaryItem(
                    '💪', '$totalSets', 'подходов'),
                _buildSummaryItem(
                    '⏱️', '$duration', 'минут'),
                _buildSummaryItem(
                    '📊',
                    '${totalVolume.toStringAsFixed(0)}',
                    'кг'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Подробности тренировки',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white
                      : Colors.black87)),
          const SizedBox(height: 12),
          ...grouped.entries.map((entry) {
            final sets = entry.value
                .where((s) => !s.isWarmup)
                .toList();
            final warmupSets = entry.value
                .where((s) => s.isWarmup)
                .toList();

            if (sets.isEmpty &&
                warmupSets.isEmpty)
              return const SizedBox.shrink();

            final maxWeight = sets.isNotEmpty
                ? sets
                .map((s) => s.weight)
                .reduce((a, b) =>
            a > b ? a : b)
                : 0.0;
            final volume = sets.fold(
                0.0,
                    (sum, s) =>
                sum + s.weight * s.reps);

            return Container(
              margin:
              const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade50,
                borderRadius:
                BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.key,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : Colors
                                    .black87)),
                      ),
                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                            horizontal: 8,
                            vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(
                              0xFFFF6B35)
                              .withOpacity(0.1),
                          borderRadius:
                          BorderRadius.circular(
                              8),
                        ),
                        child: Text(
                            '${sets.length} подходов',
                            style: TextStyle(
                                fontSize: 10,
                                color: const Color(
                                    0xFFFF6B35),
                                fontWeight:
                                FontWeight
                                    .w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (sets.isNotEmpty) ...[
                    Text('Рабочие подходы:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                            FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey
                                .shade700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                      sets.map((s) {
                        return Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                              horizontal: 8,
                              vertical: 4),
                          decoration:
                          BoxDecoration(
                            color: isDark
                                ? Colors.white
                                .withOpacity(
                                0.1)
                                : Colors.white,
                            borderRadius:
                            BorderRadius
                                .circular(6),
                          ),
                          child: Text(
                            '${s.weight.toStringAsFixed(0)}кг×${s.reps}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                FontWeight
                                    .w600,
                                color: isDark
                                    ? Colors
                                    .white
                                    : Colors
                                    .black87),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (warmupSets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Разминка: ${warmupSets.map((s) => "${s.weight.toStringAsFixed(0)}кг×${s.reps}").join(", ")}',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange
                              .withOpacity(0.8)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Divider(
                      color: isDark
                          ? Colors.white24
                          : Colors.grey
                          .shade300,
                      height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      Text('Макс. вес:',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey
                                  .shade600)),
                      Text(
                          '${maxWeight.toStringAsFixed(0)} кг',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : Colors
                                  .black87)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      Text('Тоннаж:',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey
                                  .shade600)),
                      Text(
                          '${volume.toStringAsFixed(0)} кг',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.w700,
                              color: Color(
                                  0xFFFF6B35))),
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

  Widget _buildSummaryItem(
      String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji,
            style:
            const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500)),
      ],
    );
  }

  double _calculateTotalVolume() {
    double total = 0;
    for (final config in _config) {
      final sets = _completedData[
      config.exercise.exerciseId] ??
          [];
      for (final s in sets) {
        if (!s.isWarmup)
          total += s.weight * s.reps;
      }
    }
    return total;
  }

  ConfiguredExercise? _getCurrentConfig() {
    if (_currentExIndex >= _config.length) return null;
    return _config[_currentExIndex];
  }

  // 🔒 ИСПРАВЛЕНО: Пропуск подхода + проверка завершения тренировки
  void _skipSet() {
    HapticFeedback.lightImpact();
    final config = _getCurrentConfig();
    if (config == null) return;
    setState(() {
      if (_currentSetIndex <
          config.sets.length - 1) {
        _currentSetIndex++;
      } else {
        _currentSetIndex = 0;
        _currentExIndex++;
      }
    });
    // 🔒 Проверка завершения тренировки после пропуска
    if (_getCurrentConfig() == null) {
      _finishWorkout();
    }
  }

  // 🔒 ИСПРАВЛЕНО: Пропуск упражнения + проверка завершения тренировки
  void _skipExercise() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentExIndex++;
      _currentSetIndex = 0;
    });
    // 🔒 Проверка завершения тренировки после пропуска упражнения
    if (_getCurrentConfig() == null) {
      _finishWorkout();
    }
  }

  int _totalCompletedSets() {
    int total = 0;
    for (final list in _completedData.values) {
      total += list
          .where((s) => !s.isWarmup)
          .length;
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

  // 🔒 ИСПРАВЛЕНО: Добавлена защита от повторного вызова!
  Future<void> _finishWorkout() async {
    // 🔒 Защита 1: Если уже в процессе завершения - выходим
    if (_isFinishing) {
      debugPrint('⚠️ _finishWorkout уже выполняется, пропускаем повторный вызов');
      return;
    }

    // 🔒 Защита 2: Если тренировка уже завершена - выходим
    if (_phase == WorkoutPhase.completed) {
      debugPrint('⚠️ Тренировка уже завершена, пропускаем');
      return;
    }

    // 🔒 Защита 3: Если уже есть сохранённый лог - выходим
    if (_savedLogId != null) {
      debugPrint('⚠️ Лог уже сохранён ($_savedLogId), пропускаем');
      return;
    }

    // Если данных нет - просто показываем экран завершения
    if (_completedData.isEmpty) {
      if (mounted) {
        setState(() => _phase = WorkoutPhase.completed);
      }
      return;
    }

    // 🔒 Блокируем повторные вызовы
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

      // 🔒 СОХРАНЯЕМ ТОЛЬКО ОДИН РАЗ
      await provider.saveWorkoutLogDirect(log);
      _savedLogId = logId;  // 🔒 Запоминаем ID сохранённого лога
      debugPrint('✅ Тренировка сохранена (ОДИН РАЗ): $logId, упражнений: ${exercisesLog.length}');

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

  Future<bool> _showExitDialog(
      BuildContext context, bool isDark) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Прервать тренировку?'),
        content: const Text(
            'Прогресс не будет сохранён'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false),
              child: const Text('Продолжить')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, true),
              child: const Text('Прервать',
                  style: TextStyle(
                      color: Colors.red))),
        ],
      ),
    );
    if (result == true) Navigator.pop(context);
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
  ConfiguredExercise(
      {required this.exercise, required this.sets});
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