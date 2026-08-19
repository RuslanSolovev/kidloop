import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/nutrition_models.dart';
import '../../providers/nutrition_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isDark;
  final NutritionProvider? provider;

  const ProfileSetupScreen({
    super.key,
    this.isDark = true,
    this.provider,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const bgDark = Color(0xFF0A0E1A);
  static const surface = Color(0xFF141A2E);
  static const surfaceLight = Color(0xFF1A2140);
  static const cyan = Color(0xFF00D4FF);
  static const green = Color(0xFF00FF9D);
  static const pink = Color(0xFFFF2D55);
  static const yellow = Color(0xFFFFD60A);
  static const orange = Color(0xFFFF9500);

  // Контроллеры
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _targetDaysController = TextEditingController();
  final _stepsController = TextEditingController();
  final _workoutsController = TextEditingController();
  final _bodyFatController = TextEditingController();

  // Выбранные значения
  Gender _gender = Gender.male;
  ActivityLevel _activityLevel = ActivityLevel.moderate;
  GoalType _goalType = GoalType.maintain;
  GoalPace _goalPace = GoalPace.moderate;

  int _currentStep = 0;
  bool _isLoading = true;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    _targetDaysController.dispose();
    _stepsController.dispose();
    _workoutsController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  NutritionProvider get _provider {
    if (widget.provider != null) {
      return widget.provider!;
    }
    try {
      return Provider.of<NutritionProvider>(context, listen: false);
    } catch (e) {
      debugPrint('⚠️ Ошибка получения провайдера: $e');
      throw Exception('NutritionProvider не найден. Передайте провайдер в ProfileSetupScreen');
    }
  }

  void _loadProfile() {
    try {
      final provider = _provider;
      final profile = provider.userProfile;
      if (profile != null) {
        _gender = profile.gender;
        _ageController.text = profile.age.toString();
        _weightController.text = profile.weight.toString();
        _heightController.text = profile.height.toString();
        _activityLevel = profile.activityLevel;
        _goalType = profile.goalType;
        _goalPace = profile.goalPace;
        if (profile.targetWeight != null) {
          _targetWeightController.text = profile.targetWeight!.toString();
        }
        if (profile.targetDays != null) {
          _targetDaysController.text = profile.targetDays!.toString();
        }
        _stepsController.text = profile.stepsPerDay.toString();
        _workoutsController.text = profile.workoutsPerWeek.toString();
        if (profile.bodyFatPercentage > 0) {
          _bodyFatController.text = profile.bodyFatPercentage.toString();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка загрузки профиля: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgDark,
        body: const Center(
          child: CircularProgressIndicator(
            color: cyan,
          ),
        ),
      );
    }

    final provider = widget.provider != null
        ? widget.provider!
        : context.watch<NutritionProvider>();
    final profile = provider.userProfile;

    // Если профиль сохранён и мы не в режиме редактирования, показываем результаты
    if (profile != null && _showResults) {
      return _buildResultsScreen(provider, profile);
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('НАСТРОЙКА ПРОФИЛЯ',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        actions: [
          if (profile != null)
            TextButton(
              onPressed: () {
                _showRecommendations(provider);
              },
              child: const Text('Рекомендации',
                  style: TextStyle(color: cyan, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepHeader(),
                  const SizedBox(height: 16),
                  _buildStepContent(provider),
                  const SizedBox(height: 24),
                  _buildNavigationButtons(provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen(NutritionProvider provider, UserProfile profile) {
    final prediction = profile.goalPrediction;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('ВАШ ПРОФИЛЬ',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [green.withOpacity(0.2), cyan.withOpacity(0.2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ПРОФИЛЬ СОЗДАН!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'На основе твоих данных мы подготовили персональные рекомендации',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Основная информация
              const Text(
                '📊 ОСНОВНЫЕ ПОКАЗАТЕЛИ',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _resultStat('BMR', '${profile.bmr.round()} ккал', cyan),
                        _resultStat('TDEE', '${profile.tdee.round()} ккал', yellow),
                        _resultStat('ИМТ', profile.bmi.toStringAsFixed(1), green),
                      ],
                    ),
                    const Divider(color: Colors.white10),
                    Row(
                      children: [
                        _resultStat('Цель', _goalTypeDisplay(profile.goalType), yellow),
                        _resultStat('Темп', _goalPaceDisplay(profile.goalPace), green),
                        _resultStat('Активность', _activityDisplay(profile.activityLevel), cyan),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Рекомендации по КБЖУ
              const Text(
                '🍽️ ЕЖЕДНЕВНЫЕ РЕКОМЕНДАЦИИ',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _resultMacro('🔥', '${profile.targetCalories.round()}', 'ккал', cyan),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _resultMacro('🥩', '${profile.recommendedProtein.round()}', 'г белка', green)),
                        Expanded(child: _resultMacro('🧈', '${profile.recommendedFat.round()}', 'г жиров', pink)),
                        Expanded(child: _resultMacro('🍞', '${profile.recommendedCarbs.round()}', 'г углеводов', yellow)),
                        Expanded(child: _resultMacro('💧', '${profile.recommendedWater}', 'мл воды', cyan)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Прогноз
              if (prediction['canPredict'] == true) ...[
                const Text(
                  '📈 ПРОГНОЗ ДОСТИЖЕНИЯ ЦЕЛИ',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [yellow.withOpacity(0.1), orange.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: yellow.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        prediction['isLose'] ? '📉' : '📈',
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${prediction['days']} дней',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${prediction['absDiff'].toStringAsFixed(1)} кг ${prediction['isLose'] ? 'сбросить' : 'набрать'} при текущем темпе',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Кнопка "Понятно"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showResults = false);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 24),
                  label: const Text(
                    'ПОНЯТНО, ПРИСТУПИМ!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cyan,
                    foregroundColor: bgDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultMacro(String emoji, String value, String label, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==================== ШАГИ ====================

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? cyan : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepHeader() {
    final titles = [
      '👤 ОСНОВНЫЕ ДАННЫЕ',
      '🎯 ТВОИ ЦЕЛИ',
      '🏃 ОБРАЗ ЖИЗНИ',
    ];
    final subtitles = [
      'Расскажи о себе для точного расчёта',
      'Что ты хочешь изменить?',
      'Учём активность для лучших рекомендаций',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titles[_currentStep],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitles[_currentStep],
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(NutritionProvider provider) {
    switch (_currentStep) {
      case 0:
        return _buildPersonalDataStep(provider);
      case 1:
        return _buildGoalsStep(provider);
      case 2:
        return _buildLifestyleStep(provider);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==================== ШАГ 1: ЛИЧНЫЕ ДАННЫЕ ====================

  Widget _buildPersonalDataStep(NutritionProvider provider) {
    return Column(
      children: [
        _buildSectionTitle('Пол'),
        Row(
          children: [
            Expanded(
              child: _buildGenderCard(Gender.male, 'Мужской', '♂️'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderCard(Gender.female, 'Женский', '♀️'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Возраст'),
        _buildInputField('Лет', _ageController, Icons.cake),
        const SizedBox(height: 16),
        _buildSectionTitle('Вес'),
        _buildInputField('кг', _weightController, Icons.monitor_weight),
        const SizedBox(height: 16),
        _buildSectionTitle('Рост'),
        _buildInputField('см', _heightController, Icons.straighten),
        const SizedBox(height: 16),
        _buildSectionTitle('Процент жира (опционально)'),
        _buildInputField('%', _bodyFatController, Icons.percent),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white38, size: 14),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Можно оставить пустым — будет рассчитан приблизительно',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderCard(Gender gender, String label, String emoji) {
    final isSelected = _gender == gender;
    return InkWell(
      onTap: () => setState(() => _gender = gender),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? cyan.withOpacity(0.15) : surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? cyan : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? cyan : Colors.white70,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ШАГ 2: ЦЕЛИ ====================

  Widget _buildGoalsStep(NutritionProvider provider) {
    return Column(
      children: [
        _buildSectionTitle('Что ты хочешь?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GoalType.values.map((goal) => _buildGoalChip(goal)).toList(),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Темп достижения'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GoalPace.values.map((pace) => _buildPaceChip(pace)).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Целевой вес (опционально)'),
                  _buildInputField('кг', _targetWeightController, Icons.monitor_weight),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('За дней (опционально)'),
                  _buildInputField('дней', _targetDaysController, Icons.timer),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_weightController.text.isNotEmpty && _heightController.text.isNotEmpty)
          _buildQuickPreview(provider),
      ],
    );
  }

  Widget _buildGoalChip(GoalType goal) {
    final labels = {
      GoalType.maintain: '⚖️ Поддержание',
      GoalType.lose: '🔥 Похудение',
      GoalType.gain: '💪 Набор веса',
      GoalType.muscleGain: '🏋️ Набор мышц',
      GoalType.recomposition: '🔄 Ре-композиция',
    };
    final isSelected = _goalType == goal;
    return InkWell(
      onTap: () => setState(() => _goalType = goal),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cyan.withOpacity(0.15) : surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? cyan : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          labels[goal]!,
          style: TextStyle(
            color: isSelected ? cyan : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPaceChip(GoalPace pace) {
    final labels = {
      GoalPace.slow: '🐢 Медленно',
      GoalPace.moderate: '⚡ Умеренно',
      GoalPace.fast: '🚀 Быстро',
    };
    final colors = {
      GoalPace.slow: green,
      GoalPace.moderate: yellow,
      GoalPace.fast: pink,
    };
    final isSelected = _goalPace == pace;
    return InkWell(
      onTap: () => setState(() => _goalPace = pace),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors[pace]!.withOpacity(0.15) : surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors[pace]! : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          labels[pace]!,
          style: TextStyle(
            color: isSelected ? colors[pace] : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ==================== ШАГ 3: ОБРАЗ ЖИЗНИ ====================

  Widget _buildLifestyleStep(NutritionProvider provider) {
    return Column(
      children: [
        _buildSectionTitle('Уровень активности'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ActivityLevel.values.map((level) => _buildActivityChip(level)).toList(),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Среднее количество шагов в день'),
        _buildInputField('шагов', _stepsController, Icons.directions_walk),
        const SizedBox(height: 16),
        _buildSectionTitle('Тренировок в неделю'),
        _buildInputField('раз', _workoutsController, Icons.fitness_center),
        const SizedBox(height: 24),
        _buildProfileSummary(provider),
      ],
    );
  }

  Widget _buildActivityChip(ActivityLevel level) {
    final labels = {
      ActivityLevel.sedentary: '🪑 Сидячий',
      ActivityLevel.light: '🚶 Лёгкий',
      ActivityLevel.moderate: '🏃 Умеренный',
      ActivityLevel.active: '💪 Активный',
      ActivityLevel.veryActive: '🔥 Очень активный',
      ActivityLevel.professional: '🏆 Профи',
    };
    final isSelected = _activityLevel == level;
    return InkWell(
      onTap: () => setState(() => _activityLevel = level),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cyan.withOpacity(0.15) : surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? cyan : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          labels[level]!,
          style: TextStyle(
            color: isSelected ? cyan : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ==================== ПРОФИЛЬ СВОДКА ====================

  Widget _buildQuickPreview(NutritionProvider provider) {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final height = double.tryParse(_heightController.text) ?? 0;

    if (weight == 0 || height == 0) return const SizedBox.shrink();

    final tempProfile = UserProfile(
      id: 'temp',
      gender: _gender,
      age: int.tryParse(_ageController.text) ?? 30,
      weight: weight,
      height: height,
      activityLevel: _activityLevel,
      goalType: _goalType,
      goalPace: _goalPace,
      targetWeight: double.tryParse(_targetWeightController.text),
      targetDays: int.tryParse(_targetDaysController.text),
      stepsPerDay: int.tryParse(_stepsController.text) ?? 5000,
      workoutsPerWeek: int.tryParse(_workoutsController.text) ?? 0,
      bodyFatPercentage: double.tryParse(_bodyFatController.text) ?? 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surface, surfaceLight],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 ПРЕДВАРИТЕЛЬНЫЙ РАСЧЁТ',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _previewStat('BMR', '${tempProfile.bmr.round()} ккал', cyan),
              _previewStat('TDEE', '${tempProfile.tdee.round()} ккал', yellow),
              _previewStat('ИМТ', tempProfile.bmi.toStringAsFixed(1), green),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Целевая калорийность: ${tempProfile.targetCalories.round()} ккал',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (tempProfile.goalType != GoalType.maintain)
            Text(
              '${_goalTypeDisplay(tempProfile.goalType)}: ${(tempProfile.targetCalories - tempProfile.tdee).round()} ккал/день',
              style: TextStyle(
                color: tempProfile.targetCalories > tempProfile.tdee ? green : pink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (tempProfile.bmiCategory != 'Норма')
            Text(
              '⚠️ ${tempProfile.bmiCategory}',
              style: const TextStyle(
                color: yellow,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummary(NutritionProvider provider) {
    final profile = provider.userProfile;
    if (profile == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surface, surfaceLight],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✅ ТЕКУЩИЙ ПРОФИЛЬ',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _profileStat('Пол', profile.gender == Gender.male ? 'Мужской' : 'Женский', cyan),
              _profileStat('Возраст', '${profile.age} лет', cyan),
              _profileStat('Вес', '${profile.weight} кг', cyan),
              _profileStat('Рост', '${profile.height} см', cyan),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _profileStat('Цель', _goalTypeDisplay(profile.goalType), yellow),
              _profileStat('Темп', _goalPaceDisplay(profile.goalPace), yellow),
              _profileStat('Активность', _activityDisplay(profile.activityLevel), yellow),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _profileStat('BMR', '${profile.bmr.round()} ккал', green),
              _profileStat('TDEE', '${profile.tdee.round()} ккал', green),
              _profileStat('Цель', '${profile.targetCalories.round()} ккал', green),
              _profileStat('ИМТ', profile.bmi.toStringAsFixed(1), green),
            ],
          ),
          const Divider(color: Colors.white10),
          Row(
            children: [
              _profileStat('🥩 Белок', '${profile.recommendedProtein.round()} г', green),
              _profileStat('🧈 Жиры', '${profile.recommendedFat.round()} г', pink),
              _profileStat('🍞 Углеводы', '${profile.recommendedCarbs.round()} г', yellow),
              _profileStat('💧 Вода', '${profile.recommendedWater} мл', cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== НАВИГАЦИЯ ====================

  Widget _buildNavigationButtons(NutritionProvider provider) {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('НАЗАД'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                await _saveProfile(provider);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cyan,
              foregroundColor: bgDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _currentStep < 2 ? 'ДАЛЕЕ' : 'СОХРАНИТЬ',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== ХЕЛПЕРЫ ====================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInputField(String suffix, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(icon, color: cyan, size: 20),
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cyan.withOpacity(0.5)),
        ),
      ),
    );
  }

  String _goalTypeDisplay(GoalType type) {
    switch (type) {
      case GoalType.maintain: return 'Поддержание';
      case GoalType.lose: return 'Похудение';
      case GoalType.gain: return 'Набор веса';
      case GoalType.muscleGain: return 'Набор мышц';
      case GoalType.recomposition: return 'Ре-композиция';
    }
  }

  String _goalPaceDisplay(GoalPace pace) {
    switch (pace) {
      case GoalPace.slow: return 'Медленно';
      case GoalPace.moderate: return 'Умеренно';
      case GoalPace.fast: return 'Быстро';
    }
  }

  String _activityDisplay(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary: return 'Сидячий';
      case ActivityLevel.light: return 'Лёгкий';
      case ActivityLevel.moderate: return 'Умеренный';
      case ActivityLevel.active: return 'Активный';
      case ActivityLevel.veryActive: return 'Очень активный';
      case ActivityLevel.professional: return 'Профи';
    }
  }

  Future<void> _saveProfile(NutritionProvider provider) async {
    final age = int.tryParse(_ageController.text);
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);

    if (age == null || weight == null || height == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполни все обязательные поля!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final profile = UserProfile(
      id: provider.userProfile?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      gender: _gender,
      age: age,
      weight: weight,
      height: height,
      activityLevel: _activityLevel,
      goalType: _goalType,
      goalPace: _goalPace,
      targetWeight: double.tryParse(_targetWeightController.text),
      targetDays: int.tryParse(_targetDaysController.text),
      stepsPerDay: int.tryParse(_stepsController.text) ?? 5000,
      workoutsPerWeek: int.tryParse(_workoutsController.text) ?? 0,
      bodyFatPercentage: double.tryParse(_bodyFatController.text) ?? 0,
    );

    await provider.saveUserProfile(profile);

    // Показываем экран с результатами
    setState(() {
      _showResults = true;
    });
  }

  // ==================== УМНЫЕ РЕКОМЕНДАЦИИ (УЛУЧШЕННЫЕ) ====================

  void _showRecommendations(NutritionProvider provider) {
    final profile = provider.userProfile;
    if (profile == null) return;

    final prediction = profile.goalPrediction;
    final weekSummary = provider.getLast7DaysSummaries();

    // Расчёт дополнительных рекомендаций
    final List<Map<String, dynamic>> extraRecommendations = [];

    // 1. Рекомендация по ИМТ
    if (profile.bmiCategory != 'Норма') {
      extraRecommendations.add({
        'emoji': '⚖️',
        'title': 'Индекс массы тела',
        'message': 'Ваш ИМТ: ${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})',
        'color': yellow,
      });
    }

    // 2. Рекомендация по распределению БЖУ
    final proteinPercent = (profile.recommendedProtein * 4 / profile.targetCalories * 100).round();
    final fatPercent = (profile.recommendedFat * 9 / profile.targetCalories * 100).round();
    final carbsPercent = (profile.recommendedCarbs * 4 / profile.targetCalories * 100).round();

    extraRecommendations.add({
      'emoji': '📊',
      'title': 'Распределение БЖУ',
      'message': 'Белки $proteinPercent% • Жиры $fatPercent% • Углеводы $carbsPercent%',
      'color': cyan,
    });

    // 3. Рекомендация по воде
    if (profile.recommendedWater > 2000) {
      extraRecommendations.add({
        'emoji': '💧',
        'title': 'Обрати внимание на воду',
        'message': 'Рекомендуется ${profile.recommendedWater} мл воды в день',
        'color': cyan,
      });
    }

    // 4. Рекомендация по активности
    final activityLabels = {
      ActivityLevel.sedentary: 'Рекомендуем добавить ежедневные прогулки',
      ActivityLevel.light: 'Хороший старт! Попробуй добавить 2-3 тренировки в неделю',
      ActivityLevel.moderate: 'Отличный уровень активности!',
      ActivityLevel.active: 'Ты молодец! Не забывай про восстановление',
      ActivityLevel.veryActive: 'Интенсивный режим! Уделяй внимание питанию',
      ActivityLevel.professional: 'Профессиональный уровень!',
    };
    extraRecommendations.add({
      'emoji': '🏃',
      'title': 'Уровень активности',
      'message': activityLabels[profile.activityLevel] ?? 'Продолжай в том же духе!',
      'color': green,
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🧠 УМНЫЕ РЕКОМЕНДАЦИИ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'На основе твоих данных и статистики',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      // Основные рекомендации
                      _recommendationCard(
                        '🎯 ЦЕЛЕВАЯ КАЛОРИЙНОСТЬ',
                        '${profile.targetCalories.round()} ккал/день',
                        cyan,
                        'База: ${profile.tdee.round()} ккал (TDEE)',
                      ),
                      const SizedBox(height: 8),
                      _recommendationCard(
                        '🥩 БЕЛКИ',
                        '${profile.recommendedProtein.round()} г',
                        green,
                        '${(profile.recommendedProtein / profile.weight).toStringAsFixed(1)} г/кг веса',
                      ),
                      const SizedBox(height: 8),
                      _recommendationCard(
                        '🧈 ЖИРЫ',
                        '${profile.recommendedFat.round()} г',
                        pink,
                        '${(profile.recommendedFat / profile.targetCalories * 100).round()}% от калорий',
                      ),
                      const SizedBox(height: 8),
                      _recommendationCard(
                        '🍞 УГЛЕВОДЫ',
                        '${profile.recommendedCarbs.round()} г',
                        yellow,
                        '${(profile.recommendedCarbs / profile.targetCalories * 100).round()}% от калорий',
                      ),
                      const SizedBox(height: 8),
                      _recommendationCard(
                        '💧 ВОДА',
                        '${profile.recommendedWater} мл/день',
                        cyan,
                        '${(profile.recommendedWater / profile.weight).round()} мл/кг веса',
                      ),

                      // Дополнительные рекомендации
                      if (extraRecommendations.isNotEmpty) ...[
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        ...extraRecommendations.map((rec) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (rec['color'] as Color).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (rec['color'] as Color).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(rec['emoji'], style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rec['title'],
                                      style: TextStyle(
                                        color: rec['color'] as Color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      rec['message'],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],

                      // Прогноз
                      if (prediction['canPredict'] == true) ...[
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: yellow.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: yellow.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                prediction['isLose'] ? '📉' : '📈',
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Прогноз: ${prediction['days']} дней',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${prediction['absDiff'].toStringAsFixed(1)} кг ${prediction['isLose'] ? 'сбросить' : 'набрать'}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Недельная статистика
                      if (weekSummary.isNotEmpty) ...[
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        const Text(
                          '📊 НЕДЕЛЬНАЯ СТАТИСТИКА',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...weekSummary.take(7).map((data) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.03),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${(DateTime.now().subtract(Duration(days: 7 - weekSummary.indexOf(data) - 1))).weekday == 1 ? "Пн" : (DateTime.now().subtract(Duration(days: 7 - weekSummary.indexOf(data) - 1))).weekday == 2 ? "Вт" : (DateTime.now().subtract(Duration(days: 7 - weekSummary.indexOf(data) - 1))).weekday == 3 ? "Ср" : (DateTime.now().subtract(Duration(days: 7 - weekSummary.indexOf(data) - 1))).weekday == 4 ? "Чт" : (DateTime.now().subtract(Duration(days: 7 - weekSummary.indexOf(data) - 1))).weekday == 5 ? "Пт" : (DateTime.now().subtract(Duration(days: 7 - weekSummary.indexOf(data) - 1))).weekday == 6 ? "Сб" : "Вс"}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${data.calories.round()} ккал',
                                  style: TextStyle(
                                    color: data.calories > 0 ? Colors.white : Colors.white38,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                'Б:${data.protein.round()}',
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ж:${data.fat.round()}',
                                style: const TextStyle(
                                  color: pink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'У:${data.carbs.round()}',
                                style: const TextStyle(
                                  color: yellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],

                      const SizedBox(height: 20),
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

  Widget _recommendationCard(String label, String value, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}