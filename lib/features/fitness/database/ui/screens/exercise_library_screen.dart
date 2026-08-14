// features/fitness/ui/screens/exercise_library_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/enums.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/fitness_provider.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final bool isDark;
  final bool isCompact;

  const ExerciseLibraryScreen({
    super.key,
    this.isDark = false,
    this.isCompact = false,
  });

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MuscleGroup? _selectedMuscle;
  ExerciseType? _selectedType;

  final List<Tab> _tabs = [
    const Tab(text: 'Все'),
    const Tab(text: 'Силовые'),
    const Tab(text: 'Кардио'),
    const Tab(text: 'Свой вес'),
    const Tab(text: 'Бокс'),
    const Tab(text: 'Йога'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0: _selectedType = null; break;
            case 1: _selectedType = ExerciseType.strength; break;
            case 2: _selectedType = ExerciseType.cardio; break;
            case 3: _selectedType = ExerciseType.bodyweight; break;
            case 4: _selectedType = ExerciseType.boxing; break;
            case 5: _selectedType = ExerciseType.yoga; break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final exercises = _getFilteredExercises(provider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
      appBar: _buildAppBar(isDark, provider),
      body: Column(
        children: [
          // Поиск
          _buildSearchBar(isDark),

          // Фильтр по мышцам
          _buildMuscleFilter(isDark),

          // Табы типов упражнений
          _buildTypeTabs(isDark),

          // Список упражнений
          Expanded(
            child: exercises.isEmpty
                ? _buildEmptyState(isDark)
                : _buildExerciseGrid(exercises, isDark, provider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExerciseDialog(context, isDark, provider),
        backgroundColor: const Color(0xFFFF6B35),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Создать',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, FitnessProvider provider) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      elevation: 0,
      title: Text(
        'Упражнения',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.filter_list_rounded,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
          onPressed: () => _showFilterSheet(context, isDark),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Поиск упражнений...',
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
          prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildMuscleFilter(bool isDark) {
    final muscles = MuscleGroup.values.where((m) =>
    m != MuscleGroup.cardio_vascular && m != MuscleGroup.flexibility).toList();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: muscles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final muscle = muscles[index];
          final isSelected = _selectedMuscle == muscle;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedMuscle = isSelected ? null : muscle;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? muscle.color
                    : (isDark ? const Color(0xFF1A1D24) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? muscle.color : muscle.color.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  muscle.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeTabs(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white38 : Colors.grey.shade500,
        indicator: BoxDecoration(
          color: const Color(0xFFFF6B35),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.all(3),
        tabs: _tabs,
      ),
    );
  }

  Widget _buildExerciseGrid(List<Exercise> exercises, bool isDark, FitnessProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return _buildExerciseCard(exercise, isDark, provider);
      },
    );
  }

  Widget _buildExerciseCard(Exercise exercise, bool isDark, FitnessProvider provider) {
    final lastProgress = provider.getLastProgress(exercise.id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider<FitnessProvider>.value(
              value: provider,
              child: ExerciseDetailScreen(
                exercise: exercise,
                isDark: isDark,
              ),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение упражнения
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      exercise.muscleGroups.isNotEmpty
                          ? exercise.muscleGroups.first.color.withOpacity(0.3)
                          : const Color(0xFFFF6B35).withOpacity(0.3),
                      exercise.muscleGroups.isNotEmpty
                          ? exercise.muscleGroups.first.color.withOpacity(0.05)
                          : const Color(0xFFFF6B35).withOpacity(0.05),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getExerciseIcon(exercise.exerciseType),
                        size: 48,
                        color: exercise.muscleGroups.isNotEmpty
                            ? exercise.muscleGroups.first.color
                            : const Color(0xFFFF6B35),
                      ),
                    ),
                    if (exercise.isCustom)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Ваше',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          exercise.exerciseType.emoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Информация
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (lastProgress != null)
                      Text(
                        'Лучший: ${lastProgress.bestWeight.toStringAsFixed(0)}кг × ${lastProgress.bestReps}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      )
                    else
                      Text(
                        'Нет данных',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const Spacer(),
                    // Группы мышц
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: exercise.muscleGroups.take(2).map((m) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: m.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            m.displayName,
                            style: TextStyle(
                              fontSize: 7,
                              color: m.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 64,
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Упражнения не найдены',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Попробуйте изменить фильтры или создайте своё',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  List<Exercise> _getFilteredExercises(FitnessProvider provider) {
    List<Exercise> result = List.from(provider.exercises);

    // Поиск
    if (_searchQuery.isNotEmpty) {
      result = provider.searchExercises(_searchQuery);
    }

    // Фильтр по мышце
    if (_selectedMuscle != null) {
      result = result.where((e) => e.muscleGroups.contains(_selectedMuscle)).toList();
    }

    // Фильтр по типу
    if (_selectedType != null) {
      result = result.where((e) => e.exerciseType == _selectedType).toList();
    }

    return result;
  }

  void _showFilterSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Фильтры',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // Фильтр по пользовательским
            SwitchListTile(
              title: Text(
                'Только мои упражнения',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700),
              ),
              value: false,
              onChanged: (value) {
                // Добавить фильтр isCustom
              },
              activeColor: const Color(0xFFFF6B35),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Применить',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExerciseDialog(BuildContext context, bool isDark, FitnessProvider provider) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final tipsController = TextEditingController();
    final mistakesController = TextEditingController();
    var selectedType = ExerciseType.strength;
    var selectedMuscles = <MuscleGroup>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
          title: Text(
            'Новое упражнение',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Название',
                    labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Описание',
                    labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Тип упражнения
                DropdownButtonFormField<ExerciseType>(
                  value: selectedType,
                  dropdownColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Тип',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ExerciseType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text('${type.emoji} ${type.displayName}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedType = value!);
                  },
                ),
                const SizedBox(height: 12),
                // Группы мышц
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MuscleGroup.values.where((m) =>
                  m != MuscleGroup.fullBody &&
                      m != MuscleGroup.cardio_vascular &&
                      m != MuscleGroup.flexibility).map((muscle) {
                    final isSelected = selectedMuscles.contains(muscle);
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          if (isSelected) {
                            selectedMuscles.remove(muscle);
                          } else {
                            selectedMuscles.add(muscle);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? muscle.color : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: muscle.color.withOpacity(0.5)),
                        ),
                        child: Text(
                          muscle.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : muscle.color,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tipsController,
                  maxLines: 2,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Советы по технике',
                    labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                await provider.addExercise(
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  muscleGroups: selectedMuscles,
                  exerciseType: selectedType,
                  techniqueTips: tipsController.text.trim().isNotEmpty ? tipsController.text.trim() : null,
                );

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Упражнение "${nameController.text.trim()}" создано'),
                    backgroundColor: const Color(0xFFFF6B35),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Создать', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getExerciseIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.strength: return Icons.fitness_center_rounded;
      case ExerciseType.cardio: return Icons.directions_run_rounded;
      case ExerciseType.bodyweight: return Icons.accessibility_new_rounded;
      case ExerciseType.boxing: return Icons.sports_mma_rounded;
      case ExerciseType.yoga: return Icons.self_improvement_rounded;
      case ExerciseType.other: return Icons.more_horiz_rounded;
    }
  }
}