import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';
import '../widgets/muscle_map_widget.dart';

// ==================== ОСНОВНОЙ ВИДЖЕТ ====================

class ProgramBuilderScreen extends StatefulWidget {
  final WorkoutProgram? existingProgram;
  final bool isDark;
  const ProgramBuilderScreen({super.key, this.existingProgram, this.isDark = false});
  @override
  State<ProgramBuilderScreen> createState() => _ProgramBuilderScreenState();
}

class _ProgramBuilderScreenState extends State<ProgramBuilderScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _stepController;
  late Animation<double> _stepAnimation;

  // Данные программы
  ProgramType _programType = ProgramType.weekly;
  List<WorkoutDay> _days = [];
  int _editingDayIndex = 0;

  // Поля шага 0
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '60');
  String _selectedEmoji = '💪';
  Color _accentColor = const Color(0xFFFF6B35);
  String _difficulty = 'medium';
  String _goal = 'general';

  bool _showManekin = false;

  // Контроллеры для подходов
  final Map<String, TextEditingController> _repsControllers = {};
  final Map<String, TextEditingController> _weightControllers = {};

  final List<String> _steps = ['Основы', 'Дни', 'Подходы', 'Готово'];

  @override
  void initState() {
    super.initState();
    _stepController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _stepAnimation = CurvedAnimation(parent: _stepController, curve: Curves.easeOutCubic);
    _stepController.forward();

    if (widget.existingProgram != null) {
      _loadExistingProgram();
    } else {
      _initDays(_programType);
    }
    _initControllers();
  }

  void _loadExistingProgram() {
    final p = widget.existingProgram!;
    _programType = p.type;
    _days = p.days.map((d) => WorkoutDay(
      id: d.id, programId: d.programId, dayNumber: d.dayNumber,
      isRestDay: d.isRestDay, notes: d.notes,
      exercises: d.exercises.map((e) => WorkoutExercise(
        id: e.id, exerciseId: e.exerciseId, order: e.order,
        sets: e.sets.map((s) => ExerciseSet(
          setNumber: s.setNumber, reps: s.reps, weight: s.weight,
          isWarmup: s.isWarmup, status: s.status,
        )).toList(),
        groupType: e.groupType, restBetweenSeconds: e.restBetweenSeconds,
      )).toList(),
    )).toList();
    _nameController.text = p.name;
    _descriptionController.text = p.description ?? '';
    _durationController.text = (p.sessionDurationMinutes ?? 60).toString();
    _selectedEmoji = p.emoji ?? '💪';
    _accentColor = p.accentColor;
    _difficulty = p.difficulty ?? 'medium';
    _goal = p.goal ?? 'general';
  }

  @override
  void dispose() {
    _stepController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _initControllers() {
    _disposeControllers();
    for (int d = 0; d < _days.length; d++) {
      for (int e = 0; e < _days[d].exercises.length; e++) {
        for (int s = 0; s < _days[d].exercises[e].sets.length; s++) {
          final key = '${d}_${e}_$s';
          final set = _days[d].exercises[e].sets[s];
          _repsControllers[key] = TextEditingController(text: set.reps > 0 ? '${set.reps}' : '');
          _weightControllers[key] = TextEditingController(text: set.weight > 0 ? set.weight.toStringAsFixed(1) : '');
        }
      }
    }
  }

  void _disposeControllers() {
    for (final c in _repsControllers.values) c.dispose();
    for (final c in _weightControllers.values) c.dispose();
    _repsControllers.clear();
    _weightControllers.clear();
  }

  void _initDays(ProgramType type) {
    int count;
    switch (type) {
      case ProgramType.daily: count = 1; break;
      case ProgramType.weekly: count = 7; break;
      case ProgramType.monthly: count = 30; break;
      default: count = 7;
    }
    _days = List.generate(count, (i) => WorkoutDay(
      id: 'temp_${i}_${DateTime.now().millisecondsSinceEpoch}',
      programId: 'new', dayNumber: i + 1,
      isRestDay: (type == ProgramType.weekly && (i == 5 || i == 6)),
      exercises: [],
    ));
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: return _nameController.text.trim().isNotEmpty;
      case 1: return _days.any((d) => !d.isRestDay && d.exercises.isNotEmpty);
      case 2: return true;
      case 3: return true;
      default: return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: _buildAppBar(isDark),
      body: FadeTransition(
        opacity: _stepAnimation,
        child: _buildStepContent(isDark),
      ),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 6),
          ..._steps.asMap().entries.map((entry) {
            final i = entry.key;
            final label = entry.value;
            final isActive = i == _currentStep;
            final isPast = i < _currentStep;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // увеличен отступ
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFF6B35) : isPast ? const Color(0xFF4CAF50) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13, // увеличено с 11 до 13
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive || isPast ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _buildBottomNavButtons(isDark),
      ),
      toolbarHeight: 52,
    );
  }

  Widget _buildBottomNavButtons(bool isDark) {
    final canProceed = _canProceed();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            _buildNavButtonCompact(
              label: '← Назад',
              color: Colors.grey,
              onTap: () {
                HapticFeedback.lightImpact();
                _stepController.forward(from: 0.0);
                setState(() => _currentStep--);
              },
              isDark: isDark,
            )
          else
            const SizedBox(width: 80),
          if (_currentStep < 3)
            _buildNavButtonCompact(
              label: _currentStep == 2 ? 'Пропустить →' : 'Далее →',
              color: canProceed ? const Color(0xFFFF6B35) : Colors.grey,
              onTap: canProceed
                  ? () {
                HapticFeedback.lightImpact();
                _stepController.forward(from: 0.0);
                setState(() => _currentStep++);
              }
                  : null,
              isDark: isDark,
            )
          else
            _buildNavButtonCompact(
              label: '💾 Сохранить',
              color: const Color(0xFF4CAF50),
              onTap: _saveProgram,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildNavButtonCompact({
    required String label,
    required Color color,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: onTap != null ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // ==================== СОДЕРЖИМОЕ ШАГОВ ====================

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 0: return _buildStep0_Basics(isDark);
      case 1: return _buildStep1_Days(isDark);
      case 2: return _buildStep2_Sets(isDark);
      case 3: return _buildStep3_Summary(isDark);
      default: return const SizedBox.shrink();
    }
  }

  // ==================== ШАГ 0: ОСНОВЫ ====================

  Widget _buildStep0_Basics(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(isDark, 'Название программы *'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _nameController,
            hint: 'Например: "Силовая 3 дня"',
            isDark: isDark,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          _buildSectionLabel(isDark, 'Тип программы'),
          const SizedBox(height: 6),
          _buildTypeSelector(isDark),
          const SizedBox(height: 16),

          _buildSectionLabel(isDark, 'Иконка'),
          const SizedBox(height: 6),
          _buildEmojiSelector(isDark),
          const SizedBox(height: 16),

          _buildSectionLabel(isDark, 'Цвет'),
          const SizedBox(height: 6),
          _buildColorSelector(isDark),
          const SizedBox(height: 16),

          _buildSectionLabel(isDark, 'Сложность'),
          const SizedBox(height: 6),
          _buildDifficultySelector(isDark),
          const SizedBox(height: 16),

          _buildSectionLabel(isDark, 'Цель'),
          const SizedBox(height: 6),
          _buildGoalSelector(isDark),
          const SizedBox(height: 16),

          _buildSectionLabel(isDark, 'Длительность сессии (мин)'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _durationController,
            hint: '60',
            isDark: isDark,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          _buildSectionLabel(isDark, 'Описание'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _descriptionController,
            hint: 'Опишите программу...',
            isDark: isDark,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType ?? TextInputType.text,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade400),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(bool isDark, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  // ----- ТИП ПРОГРАММЫ (уменьшен) -----

  Widget _buildTypeSelector(bool isDark) {
    final types = [
      {'type': ProgramType.daily, 'emoji': '☀️', 'label': '1 день'},
      {'type': ProgramType.weekly, 'emoji': '📅', 'label': 'Неделя'},
      {'type': ProgramType.monthly, 'emoji': '🗓️', 'label': 'Месяц'},
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
      ),
      child: Row(
        children: types.map((t) {
          final type = t['type'] as ProgramType;
          final isSelected = _programType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _programType = type;
                  _initDays(type);
                  _editingDayIndex = 0;
                  _initControllers();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t['emoji'] as String, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      t['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ----- ИКОНКА (уменьшена) -----

  Widget _buildEmojiSelector(bool isDark) {
    final emojis = ['💪', '🏋️', '🔥', '🏃', '🧘', '🚴', '🥊', '⚡', '🏆', '💎', '🎯', '⚔️', '🛡️', '🌀', '🌟', '🌊', '🌋', '🪐', '🚀', '💥'];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: emojis.map((e) => GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedEmoji = e); },
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _selectedEmoji == e ? const Color(0xFFFF6B35).withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _selectedEmoji == e ? const Color(0xFFFF6B35) : Colors.transparent, width: 2),
          ),
          child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
        ),
      )).toList(),
    );
  }

  // ----- ЦВЕТ (уменьшен) -----

  Widget _buildColorSelector(bool isDark) {
    final colors = [
      const Color(0xFFFF6B35), const Color(0xFF4CAF50), const Color(0xFF2196F3),
      const Color(0xFF9C27B0), const Color(0xFFFF9500), const Color(0xFFE91E63),
      const Color(0xFF00C7BE), const Color(0xFF795548), const Color(0xFF3F51B5),
      const Color(0xFF607D8B), const Color(0xFFFDD835), const Color(0xFFFF5722),
      const Color(0xFF673AB7), const Color(0xFF009688), const Color(0xFFFF9800),
    ];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: colors.map((c) => GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); setState(() => _accentColor = c); },
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accentColor == c ? Colors.white : Colors.transparent, width: 2),
            boxShadow: _accentColor == c ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6)] : null,
          ),
        ),
      )).toList(),
    );
  }

  // ----- СЛОЖНОСТЬ (уменьшена) -----

  Widget _buildDifficultySelector(bool isDark) {
    final difficulties = [
      {'value': 'easy', 'emoji': '🟢', 'label': 'Лёгкая'},
      {'value': 'medium', 'emoji': '🟡', 'label': 'Средняя'},
      {'value': 'hardcore', 'emoji': '🔴', 'label': 'Хардкор'},
    ];
    return Row(
      children: difficulties.map((d) {
        final isSelected = _difficulty == d['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _difficulty = d['value'] as String); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF6B35).withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? const Color(0xFFFF6B35) : Colors.transparent, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(d['emoji'] as String, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    d['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFFFF6B35) : (isDark ? Colors.white70 : Colors.grey.shade700),
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

  // ----- ЦЕЛЬ (уменьшена) -----

  Widget _buildGoalSelector(bool isDark) {
    final goals = [
      {'value': 'lose', 'emoji': '🔥', 'label': 'Похудение'},
      {'value': 'gain', 'emoji': '💪', 'label': 'Набор массы'},
      {'value': 'strength', 'emoji': '🏋️', 'label': 'Сила'},
      {'value': 'general', 'emoji': '🎯', 'label': 'Общая форма'},
    ];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: goals.map((g) {
        final isSelected = _goal == g['value'];
        return GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _goal = g['value'] as String); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF6B35).withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? const Color(0xFFFF6B35) : Colors.transparent, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(g['emoji'] as String, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  g['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFFFF6B35) : (isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== ШАГ 1: ДНИ ====================

  Widget _buildStep1_Days(bool isDark) {
    final provider = context.watch<FitnessProvider>();
    final day = _days[_editingDayIndex];

    return Column(
      children: [
        _buildDaysRow(isDark),
        const SizedBox(height: 4),
        _buildDayControlBar(isDark, day),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                if (!day.isRestDay) _buildAddExerciseButton(isDark),
                _buildManekinToggle(isDark),
                if (_showManekin) _buildManekinSection(isDark, day),
                if (!day.isRestDay && day.exercises.isNotEmpty) _buildExercisesList(isDark, day, provider),
                if (day.isRestDay) _buildRestDayMessage(isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 1. Новая кнопка "Добавить упражнения" всегда видна
  Widget _buildAddExerciseButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GestureDetector(
        onTap: () => _showExerciseList(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_rounded, color: Color(0xFFFF6B35), size: 22)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Добавить упражнения', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF6B35), size: 22),
          ]),
        ),
      ),
    );
  }

  Widget _buildRestDayMessage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Icon(Icons.bedtime_rounded, size: 60, color: isDark ? Colors.white24 : Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('День отдыха', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('Восстановление — часть тренировки', style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.grey.shade500)),
      ]),
    );
  }

  // 🔥 1. Кнопка показа/скрытия манекена
  Widget _buildManekinToggle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _showManekin = !_showManekin);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: _showManekin ? const Color(0xFFFF6B35).withOpacity(0.12) : const Color(0xFF4A9BFF).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _showManekin ? const Color(0xFFFF6B35).withOpacity(0.3) : const Color(0xFF4A9BFF).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showManekin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: _showManekin ? const Color(0xFFFF6B35) : const Color(0xFF4A9BFF),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _showManekin ? 'Скрыть манекен' : 'Показать манекен',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _showManekin ? const Color(0xFFFF6B35) : const Color(0xFF4A9BFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- ДНИ (ряд с днями) - УВЕЛИЧЕН -----

  Widget _buildDaysRow(bool isDark) {
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final total = _days.where((d) => !d.isRestDay).length;
    final filled = _days.where((d) => !d.isRestDay && d.exercises.isNotEmpty).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Text('Прогресс', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(width: 6),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
              value: total > 0 ? filled / total : 0.0,
              minHeight: 2,
              backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
            ))),
            const SizedBox(width: 6),
            Text('$filled/$total', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFFF6B35))),
          ]),
        ),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            itemBuilder: (context, index) {
              final day = _days[index];
              final isSelected = index == _editingDayIndex;
              final hasExercises = day.exercises.isNotEmpty;
              final label = _programType == ProgramType.weekly ? dayNames[index % 7] : 'Д${index + 1}';
              return GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setState(() => _editingDayIndex = index); },
                child: Container(
                  width: 54,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]) : null,
                    color: isSelected ? null : (isDark ? const Color(0xFF1A1D24) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: !isSelected ? Border.all(color: hasExercises ? const Color(0xFF4CAF50).withOpacity(0.5) : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)) : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (day.isRestDay)
                      Icon(Icons.bedtime_rounded,
                        size: 16,
                        color: isSelected ? Colors.white70 : Colors.grey,
                      )
                    else
                      Text('${day.exercises.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: hasExercises ? (isSelected ? Colors.white : const Color(0xFF4CAF50)) : (isDark ? Colors.white24 : Colors.grey.shade400),
                        ),
                      ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ----- УПРАВЛЕНИЕ ДНЕМ (УВЕЛИЧЕНО) -----

  Widget _buildDayControlBar(bool isDark, WorkoutDay day) {
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final dayLabel = _programType == ProgramType.weekly ? " • ${dayNames[_editingDayIndex % 7]}" : "";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Text('День ${day.dayNumber}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
        ),
        Text(dayLabel,
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey.shade500),
        ),
        if (!day.isRestDay && day.exercises.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('${day.exercises.length} упр.', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50)))),
        ],
        const Spacer(),
        Text('Отдых', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
        Transform.scale(scale: 0.7, child: Switch(
          value: day.isRestDay,
          onChanged: (v) { HapticFeedback.lightImpact(); setState(() { _days[_editingDayIndex] = day.copyWith(isRestDay: v); }); },
          activeColor: const Color(0xFFFF6B35),
        )),
        if (!day.isRestDay) ...[
          const SizedBox(width: 4),
          _buildSmallIconButton(Icons.search_rounded, () => _showExerciseSearch(context), const Color(0xFF4A9BFF), isDark, size: 18),
          const SizedBox(width: 4),
          _buildSmallIconButton(Icons.list_alt_rounded, () => _showExerciseList(context), const Color(0xFFFF6B35), isDark, size: 18),
        ],
      ]),
    );
  }

  Widget _buildSmallIconButton(IconData icon, VoidCallback onTap, Color color, bool isDark, {double size = 14}) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }

  // ----- МАНЕКЕН (УВЕЛИЧЕН) -----

  Widget _buildManekinSection(bool isDark, WorkoutDay day) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFF4A9BFF).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.touch_app_rounded, color: Color(0xFF4A9BFF), size: 14),
            const SizedBox(width: 6),
            Text('Тап по мышце → подбор', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600)),
          ]),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 320, // увеличено с 240 до 320
          child: InteractiveMuscleMap(
            onMuscleSelected: (muscle) => _showFilteredExercises(context, muscle),
          ),
        ),
      ]),
    );
  }

  // ----- СПИСОК УПРАЖНЕНИЙ (УВЕЛИЧЕН) -----

  Widget _buildExercisesList(bool isDark, WorkoutDay day, FitnessProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Упражнения', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(width: 6),
          Text('${day.exercises.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF4CAF50))),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 100,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final exercises = List<WorkoutExercise>.from(day.exercises);
                final item = exercises.removeAt(oldIndex);
                exercises.insert(newIndex, item);
                for (int i = 0; i < exercises.length; i++) exercises[i] = exercises[i].copyWith(order: i);
                _days[_editingDayIndex] = day.copyWith(exercises: exercises);
                _initControllers();
              });
            },
            itemCount: day.exercises.length,
            itemBuilder: (context, index) {
              final we = day.exercises[index];
              final exData = provider.exercises.firstWhere((e) => e.id == we.exerciseId, orElse: () => Exercise(id: '', name: '???'));
              final muscleColor = exData.muscleGroups.isNotEmpty ? exData.muscleGroups.first.color : Colors.grey;
              return Container(
                key: ValueKey(we.id),
                width: 100,
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: muscleColor.withOpacity(0.4), width: 2),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: muscleColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                        child: Text(exData.exerciseType.emoji, style: const TextStyle(fontSize: 12))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () { HapticFeedback.mediumImpact(); _removeExerciseFromDay(exData); },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Expanded(child: Text(exData.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.2))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text('${we.sets.length} подх.', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFFF6B35)))),
                ]),
              );
            },
          ),
        ),
        const SizedBox(height: 2),
        Center(child: Text('← зажмите для перестановки →', style: TextStyle(fontSize: 8, color: isDark ? Colors.white24 : Colors.grey.shade500, fontStyle: FontStyle.italic))),
      ]),
    );
  }

  // ----- ДЕЙСТВИЯ С УПРАЖНЕНИЯМИ -----

  void _showExerciseSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExerciseSearchSheet(
        isDark: widget.isDark,
        onAdd: _addExerciseToDay,
        onRemove: _removeExerciseFromDay,
        addedIds: _days[_editingDayIndex].exercises.map((e) => e.exerciseId).toList(),
      ),
    );
  }

  void _showExerciseList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExerciseListSheet(
        isDark: widget.isDark,
        onAdd: _addExerciseToDay,
        onRemove: _removeExerciseFromDay,
        addedIds: _days[_editingDayIndex].exercises.map((e) => e.exerciseId).toList(),
      ),
    );
  }

  void _showFilteredExercises(BuildContext context, MuscleGroup muscle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExerciseListSheet(
        isDark: widget.isDark,
        onAdd: _addExerciseToDay,
        onRemove: _removeExerciseFromDay,
        addedIds: _days[_editingDayIndex].exercises.map((e) => e.exerciseId).toList(),
        filterMuscle: muscle,
      ),
    );
  }

  void _addExerciseToDay(Exercise exercise) {
    setState(() {
      final day = _days[_editingDayIndex];
      if (day.exercises.any((e) => e.exerciseId == exercise.id)) return;
      _days[_editingDayIndex] = day.copyWith(exercises: [
        ...day.exercises,
        WorkoutExercise(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          exerciseId: exercise.id,
          order: day.exercises.length,
          sets: [ExerciseSet(setNumber: 1, reps: 10, weight: 0)],
        )
      ]);
      _initControllers();
    });
  }

  void _removeExerciseFromDay(Exercise exercise) {
    setState(() {
      final day = _days[_editingDayIndex];
      _days[_editingDayIndex] = day.copyWith(
          exercises: day.exercises.where((e) => e.exerciseId != exercise.id).toList()
      );
      _initControllers();
    });
  }

  // ==================== ШАГ 2: ПОДХОДЫ ====================

  Widget _buildStep2_Sets(bool isDark) {
    final provider = context.watch<FitnessProvider>();
    final day = _days[_editingDayIndex];

    return Column(
      children: [
        _buildDaysRow(isDark),
        if (day.isRestDay || day.exercises.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(day.isRestDay ? Icons.bedtime_rounded : Icons.warning_amber_rounded, size: 50, color: day.isRestDay ? Colors.grey : Colors.orange),
                  const SizedBox(height: 12),
                  Text(
                    day.isRestDay ? 'День отдыха' : 'Нет упражнений',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                  if (!day.isRestDay) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        _stepController.forward(from: 0.0);
                        setState(() => _currentStep = 1);
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Вернуться и добавить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              physics: const BouncingScrollPhysics(),
              itemCount: day.exercises.length,
              itemBuilder: (context, exIndex) {
                final we = day.exercises[exIndex];
                final exData = provider.exercises.firstWhere(
                      (e) => e.id == we.exerciseId,
                  orElse: () => Exercise(id: '', name: '???'),
                );
                return _buildExerciseConfigCard(isDark, exIndex, we, exData);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildExerciseConfigCard(bool isDark, int exIndex, WorkoutExercise we, Exercise exData) {
    final isTimeBased = exData.exerciseType == ExerciseType.cardio ||
        exData.exerciseType == ExerciseType.yoga ||
        exData.exerciseType == ExerciseType.other;
    final muscleColor = exData.muscleGroups.isNotEmpty ? exData.muscleGroups.first.color : const Color(0xFFFF6B35);
    final configuredCount = we.sets.where((s) => _hasSetConfigured(s)).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          leading: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: muscleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(exData.exerciseType.emoji, style: const TextStyle(fontSize: 14))),
          ),
          title: Text(exData.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              Text('${we.sets.length} подх.', style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : Colors.grey.shade600)),
              const SizedBox(width: 4),
              Text(configuredCount == we.sets.length ? '✓ готово' : '$configuredCount/${we.sets.length}',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: configuredCount == we.sets.length ? const Color(0xFF4CAF50) : Colors.orange)),
              if (isTimeBased) ...[const SizedBox(width: 4), const Text('⏱️', style: TextStyle(fontSize: 9))],
            ]),
          ),
          children: [
            ...we.sets.asMap().entries.map((setEntry) {
              final setIndex = setEntry.key;
              final set = setEntry.value;
              return _buildSetConfigRow(isDark, exIndex, setIndex, set, isTimeBased);
            }),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    final day = _days[_editingDayIndex];
                    final exercises = List<WorkoutExercise>.from(day.exercises);
                    final sets = List<ExerciseSet>.from(exercises[exIndex].sets);
                    sets.add(ExerciseSet(setNumber: sets.length + 1, reps: isTimeBased ? 60 : 10, weight: isTimeBased ? 5 : 0));
                    exercises[exIndex] = exercises[exIndex].copyWith(sets: sets);
                    _days[_editingDayIndex] = day.copyWith(exercises: exercises);
                    _initControllers();
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 12),
                label: const Text('Подход', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B35)),
              )),
              if (we.sets.length > 1)
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      final day = _days[_editingDayIndex];
                      final exercises = List<WorkoutExercise>.from(day.exercises);
                      final sets = List<ExerciseSet>.generate(we.sets.length, (i) => ExerciseSet(
                        setNumber: i + 1,
                        reps: we.sets.first.reps,
                        weight: we.sets.first.weight,
                        isWarmup: i == 0 && we.sets.first.isWarmup,
                      ));
                      exercises[exIndex] = exercises[exIndex].copyWith(sets: sets);
                      _days[_editingDayIndex] = day.copyWith(exercises: exercises);
                      _initControllers();
                    });
                  },
                  icon: const Icon(Icons.copy_rounded, size: 10),
                  label: const Text('Копировать', style: TextStyle(fontSize: 9)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF4A9BFF)),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSetConfigRow(bool isDark, int exIndex, int setIndex, ExerciseSet set, bool isTimeBased) {
    final day = _days[_editingDayIndex];
    final we = day.exercises[exIndex];
    final key = '${_editingDayIndex}_${exIndex}_$setIndex';
    final repsController = _repsControllers[key];
    final weightController = _weightControllers[key];

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: set.isWarmup ? Border.all(color: Colors.orange.withOpacity(0.4)) :
        _hasSetConfigured(set) ? Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)) : null,
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: set.isWarmup ? Colors.orange.withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('П${setIndex + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: set.isWarmup ? Colors.orange : (isDark ? Colors.white70 : Colors.grey.shade700))),
          ),
          if (set.isWarmup) ...[const SizedBox(width: 3), const Text('🔥', style: TextStyle(fontSize: 8))],
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                final d = _days[_editingDayIndex];
                final exs = List<WorkoutExercise>.from(d.exercises);
                final sets = List<ExerciseSet>.from(exs[exIndex].sets);
                sets[setIndex] = ExerciseSet(
                  setNumber: set.setNumber,
                  reps: set.reps,
                  weight: set.weight,
                  isWarmup: !set.isWarmup,
                  status: set.status,
                );
                exs[exIndex] = exs[exIndex].copyWith(sets: sets);
                _days[_editingDayIndex] = d.copyWith(exercises: exs);
              });
            },
            child: Icon(Icons.whatshot_rounded, size: 12, color: set.isWarmup ? Colors.orange : Colors.grey),
          ),
          if (we.sets.length > 1) ...[
            const SizedBox(width: 3),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  final d = _days[_editingDayIndex];
                  final exs = List<WorkoutExercise>.from(d.exercises);
                  final sets = List<ExerciseSet>.from(exs[exIndex].sets);
                  sets.removeAt(setIndex);
                  for (int i = 0; i < sets.length; i++) {
                    sets[i] = ExerciseSet(
                      setNumber: i + 1,
                      reps: sets[i].reps,
                      weight: sets[i].weight,
                      isWarmup: sets[i].isWarmup,
                      status: sets[i].status,
                    );
                  }
                  exs[exIndex] = exs[exIndex].copyWith(sets: sets);
                  _days[_editingDayIndex] = d.copyWith(exercises: exs);
                  _initControllers();
                });
              },
              child: const Icon(Icons.close_rounded, size: 10, color: Colors.red),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        if (isTimeBased)
          _buildTimeBasedRow(isDark, exIndex, setIndex, set)
        else ...[
          _buildCompactStepper(
            isDark: isDark,
            label: 'Повт.',
            value: set.reps,
            min: 1, max: 100, step: 1,
            controller: repsController,
            onChanged: (v) {
              _updateSet(exIndex, setIndex, reps: v.toInt());
              if (repsController != null) repsController.text = v > 0 ? '${v.toInt()}' : '';
            },
          ),
          const SizedBox(height: 4),
          _buildCompactStepper(
            isDark: isDark,
            label: 'Вес',
            value: set.weight,
            min: 0, max: 500, step: 2.5,
            isDouble: true,
            controller: weightController,
            onChanged: (v) {
              _updateSet(exIndex, setIndex, weight: v.toDouble());
              if (weightController != null) weightController.text = v > 0 ? v.toDouble().toStringAsFixed(1) : '';
            },
          ),
        ],
      ]),
    );
  }

  Widget _buildCompactStepper({
    required bool isDark,
    required String label,
    required num value,
    required num min,
    required num max,
    required num step,
    required TextEditingController? controller,
    required Function(num) onChanged,
    bool isDouble = false,
  }) {
    return Row(children: [
      SizedBox(width: 50, child: Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.grey.shade700))),
      _buildCompactButton(Icons.remove_rounded, value > min ? () {
        HapticFeedback.selectionClick();
        final nv = (value - step).clamp(min, max);
        onChanged(nv);
        if (controller != null) {
          controller.text = isDouble ? nv.toDouble().toStringAsFixed(1) : '${nv.toInt()}';
        }
      } : null, Colors.grey, isDark),
      const SizedBox(width: 3),
      Expanded(child: SizedBox(
        height: 28,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: isDouble ? value.toDouble().toStringAsFixed(1) : '${value.toInt()}',
            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w800),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
            isDense: true,
          ),
          onChanged: (v) {
            if (v.isEmpty) {
              onChanged(0);
              return;
            }
            final parsed = isDouble ? double.tryParse(v) : int.tryParse(v);
            if (parsed != null) {
              final clamped = parsed.clamp(min, max);
              onChanged(clamped);
              if (controller != null) {
                final formatted = isDouble ? clamped.toDouble().toStringAsFixed(1) : '${clamped.toInt()}';
                if (controller.text != formatted) {
                  controller.text = formatted;
                  controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                }
              }
            }
          },
        ),
      )),
      const SizedBox(width: 3),
      _buildCompactButton(Icons.add_rounded, value < max ? () {
        HapticFeedback.selectionClick();
        final nv = (value + step).clamp(min, max);
        onChanged(nv);
        if (controller != null) {
          controller.text = isDouble ? nv.toDouble().toStringAsFixed(1) : '${nv.toInt()}';
        }
      } : null, const Color(0xFFFF6B35), isDark),
    ]);
  }

  Widget _buildCompactButton(IconData icon, VoidCallback? onTap, Color color, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: onTap != null ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
        ),
        child: Icon(icon, color: onTap != null ? color : Colors.grey, size: 13),
      ),
    );
  }

  // ----- УВЕЛИЧЕННЫЙ СЛАЙДЕР (бегунок) -----

  Widget _buildTimeBasedRow(bool isDark, int exIndex, int setIndex, ExerciseSet set) {
    return Column(children: [
      Row(children: [
        const Text('⏱️', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Expanded(child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            activeTrackColor: const Color(0xFF4A9BFF),
            inactiveTrackColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            thumbColor: const Color(0xFF4A9BFF),
          ),
          child: Slider(
            value: _getDuration(set).toDouble(),
            min: 15, max: 600, divisions: 39,
            onChanged: (v) => _updateSet(exIndex, setIndex, duration: v.toInt()),
          ),
        )),
        Text(_formatSeconds(_getDuration(set)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4A9BFF))),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        const Text('💪', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Expanded(child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            activeTrackColor: const Color(0xFFFF6B35),
            inactiveTrackColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            thumbColor: const Color(0xFFFF6B35),
          ),
          child: Slider(
            value: _getIntensity(set).toDouble(),
            min: 1, max: 10, divisions: 9,
            onChanged: (v) => _updateSet(exIndex, setIndex, intensity: v.toInt()),
          ),
        )),
        Text('${_getIntensity(set)}/10', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFF6B35))),
      ]),
    ]);
  }

  void _updateSet(int exIndex, int setIndex, {int? reps, double? weight, int? duration, int? intensity}) {
    setState(() {
      final day = _days[_editingDayIndex];
      final exercises = List<WorkoutExercise>.from(day.exercises);
      final sets = List<ExerciseSet>.from(exercises[exIndex].sets);
      final old = sets[setIndex];
      sets[setIndex] = duration != null
          ? ExerciseSet(
        setNumber: old.setNumber,
        reps: duration,
        weight: (intensity ?? _getIntensity(old)).toDouble(),
        isWarmup: old.isWarmup,
        status: old.status,
      )
          : ExerciseSet(
        setNumber: old.setNumber,
        reps: reps ?? old.reps,
        weight: weight ?? old.weight,
        isWarmup: old.isWarmup,
        status: old.status,
      );
      exercises[exIndex] = exercises[exIndex].copyWith(sets: sets);
      _days[_editingDayIndex] = day.copyWith(exercises: exercises);
    });
  }

  int _getDuration(ExerciseSet set) => set.reps > 0 ? set.reps : 60;
  int _getIntensity(ExerciseSet set) => set.weight > 0 ? set.weight.toInt() : 5;
  bool _hasSetConfigured(ExerciseSet s) => s.reps > 0 || s.weight > 0;
  String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}м ${s}с' : '${s}с';
  }

  // ==================== ШАГ 3: ИТОГ ====================

  Widget _buildStep3_Summary(bool isDark) {
    final totalExercises = _days.fold<int>(0, (sum, d) => sum + (d.isRestDay ? 0 : d.exercises.length));
    final trainingDays = _days.where((d) => !d.isRestDay).length;
    final restDays = _days.length - trainingDays;
    final totalSets = _days.fold<int>(0, (sum, d) => sum + (d.isRestDay ? 0 : d.exercises.fold<int>(0, (s, e) => s + e.sets.length)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accentColor.withOpacity(0.15), _accentColor.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accentColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_accentColor, _accentColor.withOpacity(0.7)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_selectedEmoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isEmpty ? 'Без названия' : _nameController.text,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                        ),
                        Text(
                          _programType.displayName,
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600),
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            _buildInfoChip(_difficulty == 'easy' ? '🟢 Лёгкая' : _difficulty == 'medium' ? '🟡 Средняя' : '🔴 Хардкор', isDark),
                            _buildInfoChip(_goal == 'lose' ? '🔥 Похудение' : _goal == 'gain' ? '💪 Масса' : _goal == 'strength' ? '🏋️ Сила' : '🎯 ОФП', isDark),
                            _buildInfoChip('⏱️ ${_durationController.text} мин', isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('📅', '${_days.length}', 'дней'),
                    _buildSummaryItem('💪', '$totalExercises', 'упражнений'),
                    _buildSummaryItem('🔄', '$totalSets', 'подходов'),
                    _buildSummaryItem('😴', '$restDays', 'отдыха'),
                  ],
                ),
                if (_descriptionController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _descriptionController.text,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionLabel(isDark, 'Дни'),
          const SizedBox(height: 6),
          ..._days.map((day) => _buildDaySummaryRow(isDark, day)),

          if (_days.any((d) => !d.isRestDay && d.exercises.isEmpty)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Есть дни без упражнений. Проверьте перед сохранением.',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white54 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String emoji, String value, String label) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
    ]);
  }

  Widget _buildDaySummaryRow(bool isDark, WorkoutDay day) {
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final label = _programType == ProgramType.weekly ? dayNames[(day.dayNumber - 1) % 7] : 'День ${day.dayNumber}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: day.isRestDay ? Colors.grey.withOpacity(0.2) : const Color(0xFF4CAF50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            day.isRestDay ? Icons.bedtime_rounded : Icons.fitness_center_rounded,
            size: 16,
            color: day.isRestDay ? Colors.grey : const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
              Text(
                day.isRestDay ? 'День отдыха' : '${day.exercises.length} упражнений',
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ],
          ),
        ),
        if (!day.isRestDay)
          Text(
            '${day.exercises.fold<int>(0, (sum, e) => sum + e.sets.length)} подходов',
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500),
          ),
      ]),
    );
  }

  // ==================== СОХРАНЕНИЕ ====================

  Future<void> _saveProgram() async {
    HapticFeedback.mediumImpact();

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название программы'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final activeDays = _days.where((d) => !d.isRestDay).toList();
    if (activeDays.isNotEmpty && activeDays.every((d) => d.exercises.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одно упражнение'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final provider = context.read<FitnessProvider>();
    final daysData = _days.map((d) => {
      'dayNumber': d.dayNumber,
      'isRestDay': d.isRestDay,
      'notes': d.notes,
      'exercises': d.exercises.map((e) => WorkoutExercise(
        id: 'ex_${DateTime.now().microsecondsSinceEpoch}_${e.order}',
        exerciseId: e.exerciseId,
        order: e.order,
        sets: e.sets.map((s) => ExerciseSet(
          setNumber: s.setNumber,
          reps: s.reps,
          weight: s.weight,
          isWarmup: s.isWarmup,
          status: SetStatus.pending,
        )).toList(),
        groupType: e.groupType,
        restBetweenSeconds: e.restBetweenSeconds,
        notes: e.notes,
      )).toList(),
    }).toList();

    try {
      if (widget.existingProgram != null) {
        await provider.updateProgram(widget.existingProgram!.copyWith(
          name: name,
          type: _programType,
          days: _days,
          description: _descriptionController.text,
          emoji: _selectedEmoji,
          accentColorValue: _accentColor.value,
          difficulty: _difficulty,
          goal: _goal,
          sessionDurationMinutes: int.tryParse(_durationController.text) ?? 60,
        ));
      } else {
        await provider.addFullProgram(
          name: name,
          type: _programType,
          daysData: daysData,
          description: _descriptionController.text,
          emoji: _selectedEmoji,
          accentColorValue: _accentColor.value,
          difficulty: _difficulty,
          goal: _goal,
          sessionDurationMinutes: int.tryParse(_durationController.text) ?? 60,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('Программа "$name" сохранена'),
            ]),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

// ==================== ШТОРКА ПОИСКА ====================

class _ExerciseSearchSheet extends StatefulWidget {
  final bool isDark;
  final Function(Exercise) onAdd;
  final Function(Exercise) onRemove;
  final List<String> addedIds;
  const _ExerciseSearchSheet({required this.isDark, required this.onAdd, required this.onRemove, required this.addedIds});
  @override State<_ExerciseSearchSheet> createState() => _ExerciseSearchSheetState();
}

class _ExerciseSearchSheetState extends State<_ExerciseSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late Set<String> _addedIdsSet;

  @override
  void initState() {
    super.initState();
    _addedIdsSet = widget.addedIds.toSet();
  }

  @override
  void didUpdateWidget(covariant _ExerciseSearchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.addedIds.length != widget.addedIds.length ||
        oldWidget.addedIds.toSet() != widget.addedIds.toSet()) {
      _addedIdsSet = widget.addedIds.toSet();
    }
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final provider = context.watch<FitnessProvider>();
    final exercises = _query.isEmpty ? provider.exercises : provider.searchExercises(_query);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Поиск...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isNotEmpty ? IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () { _searchController.clear(); setState(() => _query = ''); },
            ) : null,
            filled: true,
            fillColor: widget.isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: ListView.builder(
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final ex = exercises[index];
            final isAdded = _addedIdsSet.contains(ex.id);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: (ex.muscleGroups.isNotEmpty ? ex.muscleGroups.first.color : Colors.grey).withOpacity(0.2),
                child: Text(ex.exerciseType.emoji),
              ),
              title: Text(ex.name, style: const TextStyle(fontSize: 13)),
              trailing: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (isAdded) {
                    _addedIdsSet.remove(ex.id);
                    widget.onRemove(ex);
                  } else {
                    _addedIdsSet.add(ex.id);
                    widget.onAdd(ex);
                  }
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAdded ? Colors.green.withOpacity(0.15) : const Color(0xFFFF6B35).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isAdded ? Icons.check_circle_rounded : Icons.add_rounded,
                    color: isAdded ? Colors.green : const Color(0xFFFF6B35),
                    size: 18,
                  ),
                ),
              ),
            );
          },
        )),
      ]),
    );
  }
}

// ==================== ШТОРКА СПИСКА ====================

class _ExerciseListSheet extends StatefulWidget {
  final bool isDark;
  final Function(Exercise) onAdd;
  final Function(Exercise) onRemove;
  final List<String> addedIds;
  final MuscleGroup? filterMuscle;
  const _ExerciseListSheet({
    required this.isDark,
    required this.onAdd,
    required this.onRemove,
    required this.addedIds,
    this.filterMuscle,
  });
  @override State<_ExerciseListSheet> createState() => _ExerciseListSheetState();
}

class _ExerciseListSheetState extends State<_ExerciseListSheet> {
  MuscleGroup? _selectedGroup;
  late Set<String> _addedIdsSet;

  @override void initState() {
    super.initState();
    _selectedGroup = widget.filterMuscle;
    _addedIdsSet = widget.addedIds.toSet();
  }

  @override
  void didUpdateWidget(covariant _ExerciseListSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.addedIds.length != widget.addedIds.length ||
        oldWidget.addedIds.toSet() != widget.addedIds.toSet()) {
      _addedIdsSet = widget.addedIds.toSet();
    }
  }

  @override Widget build(BuildContext context) {
    final provider = context.watch<FitnessProvider>();
    var exercises = provider.exercises.toList();
    if (_selectedGroup != null) {
      exercises = exercises.where((e) => e.muscleGroups.contains(_selectedGroup)).toList();
    }
    final groups = MuscleGroup.values.where((g) => g != MuscleGroup.fullBody).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        const Text('Библиотека упражнений', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final group = isAll ? null : groups[index - 1];
              final isSelected = (isAll && _selectedGroup == null) || (!isAll && _selectedGroup == group);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedGroup = group);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFF6B35) : (widget.isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(isAll ? '🌐' : group!.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      isAll ? 'Все' : group!.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final ex = exercises[index];
            final isAdded = _addedIdsSet.contains(ex.id);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: (ex.muscleGroups.isNotEmpty ? ex.muscleGroups.first.color : Colors.grey).withOpacity(0.2),
                child: Text(ex.exerciseType.emoji),
              ),
              title: Text(ex.name, style: const TextStyle(fontSize: 13)),
              trailing: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (isAdded) {
                    _addedIdsSet.remove(ex.id);
                    widget.onRemove(ex);
                  } else {
                    _addedIdsSet.add(ex.id);
                    widget.onAdd(ex);
                  }
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAdded ? Colors.green.withOpacity(0.15) : const Color(0xFFFF6B35).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isAdded ? Icons.check_circle_rounded : Icons.add_rounded,
                    color: isAdded ? Colors.green : const Color(0xFFFF6B35),
                    size: 18,
                  ),
                ),
              ),
            );
          },
        )),
      ]),
    );
  }
}