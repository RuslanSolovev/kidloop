import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';
import 'fitness_target_details_screen.dart';

class FitnessTargetsScreen extends StatefulWidget {
  final bool isDark;
  const FitnessTargetsScreen({super.key, required this.isDark});

  @override
  State<FitnessTargetsScreen> createState() => _FitnessTargetsScreenState();
}

class _FitnessTargetsScreenState extends State<FitnessTargetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final active = provider.targets.where((t) => t.status == FitnessTargetStatus.active).toList();
    final completed = provider.targets.where((t) => t.status == FitnessTargetStatus.completed).toList();
    final other = provider.targets.where((t) =>
    t.status == FitnessTargetStatus.paused || t.status == FitnessTargetStatus.abandoned).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        title: const Text('Мои цели', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey.shade600,
          indicatorColor: const Color(0xFFFF6B35),
          tabs: [
            Tab(text: 'Активные (${active.length})'),
            Tab(text: 'Достигнуты (${completed.length})'),
            Tab(text: 'Архив (${other.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () => _showCreateTargetSheet(context, isDark, provider),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTargetsList(isDark, active, provider, emptyMessage: 'Нет активных целей'),
          _buildTargetsList(isDark, completed, provider, emptyMessage: 'Пока нет достигнутых целей'),
          _buildTargetsList(isDark, other, provider, emptyMessage: 'Архив пуст'),
        ],
      ),
    );
  }

  Widget _buildTargetsList(bool isDark, List<FitnessTarget> targets,
      FitnessProvider provider, {required String emptyMessage}) {
    if (targets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_rounded, size: 72,
                color: isDark ? Colors.white12 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Нажмите + чтобы создать цель',
                style: TextStyle(fontSize: 12,
                    color: isDark ? Colors.white24 : Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: targets.length,
      itemBuilder: (context, index) {
        return _buildTargetCard(isDark, targets[index], provider);
      },
    );
  }

  Widget _buildTargetCard(bool isDark, FitnessTarget target, FitnessProvider provider) {
    final progress = target.progressPercent;
    final isCompleted = target.status == FitnessTargetStatus.completed;
    final isPaused = target.status == FitnessTargetStatus.paused;

    return GestureDetector(
      // 🔥 Тап → экран деталей с графиком и прогнозом
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: FitnessTargetDetailsScreen(
              target: target,
              isDark: isDark,
            ),
          ),
        ),
      ),
      // Долгое нажатие → меню опций
      onLongPress: () => _showTargetOptions(context, target, provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCompleted
                ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                : isPaused
                ? [Colors.grey.shade700, Colors.grey.shade800]
                : [
              target.accentColor.withOpacity(0.15),
              target.accentColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF4CAF50).withOpacity(0.3)
                : target.accentColor.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: target.accentColor.withOpacity(isCompleted ? 0.4 : 0.2),
              blurRadius: 14,
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        target.accentColor,
                        target.accentColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: target.accentColor.withOpacity(0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(target.type.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (target.description.isNotEmpty)
                        Text(
                          target.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 22),
                  )
                else if (target.deadline != null)
                  _buildDeadlineChip(target),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  target.formattedCurrent,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: isCompleted ? Colors.white : target.accentColor,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    target.unit,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? Colors.white.withOpacity(0.9)
                          : (isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'из ${target.formattedTarget}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(isCompleted ? 0.25 : 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? Colors.white : target.accentColor,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toInt()}% выполнено',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  'осталось ${target.formattedRemaining} ${target.unit}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineChip(FitnessTarget target) {
    final days = target.daysUntilDeadline ?? 0;
    final isOverdue = target.isOverdue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.withOpacity(0.15)
            : const Color(0xFFFFCC00).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue
              ? Colors.red.withOpacity(0.3)
              : const Color(0xFFFFCC00).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue ? Icons.warning_rounded : Icons.schedule_rounded,
            size: 12,
            color: isOverdue ? Colors.red : const Color(0xFFFFCC00),
          ),
          const SizedBox(width: 4),
          Text(
            isOverdue ? 'Просрочено' : '$days дн.',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isOverdue ? Colors.red : const Color(0xFFFFCC00),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== СОЗДАНИЕ ЦЕЛИ ====================

  void _showCreateTargetSheet(BuildContext context, bool isDark, FitnessProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: _TargetBuilderSheet(isDark: isDark, provider: provider),
        ),
      ),
    );
  }

  // ==================== ОПЦИИ ЦЕЛИ ====================

  void _showTargetOptions(BuildContext context, FitnessTarget target, FitnessProvider provider) {
    final isDark = widget.isDark;
    final isActive = target.status == FitnessTargetStatus.active;
    final isPaused = target.status == FitnessTargetStatus.paused;
    final isCompleted = target.status == FitnessTargetStatus.completed;

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
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      target.accentColor,
                      target.accentColor.withOpacity(0.7),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(target.type.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(target.name,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87)),
                      Text('${target.formattedCurrent} / ${target.formattedTarget} ${target.unit}',
                          style: TextStyle(fontSize: 12, color: target.accentColor, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 🔥 Главный пункт — открыть детальный экран
            _buildMenuItem(
              icon: Icons.analytics_rounded,
              iconColor: target.accentColor,
              title: 'Открыть детали и прогноз',
              subtitle: 'График, история, прогноз достижения',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: FitnessTargetDetailsScreen(target: target, isDark: isDark),
                  ),
                ));
              },
            ),
            if (isActive)
              _buildMenuItem(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFF4CAF50),
                title: 'Отметить как достигнутую',
                onTap: () {
                  Navigator.pop(ctx);
                  provider.completeTarget(target.id);
                },
              ),
            if (isActive)
              _buildMenuItem(
                icon: Icons.pause_circle_outline_rounded,
                iconColor: Colors.orange,
                title: 'Приостановить',
                onTap: () {
                  Navigator.pop(ctx);
                  provider.pauseTarget(target.id);
                },
              ),
            if (isPaused)
              _buildMenuItem(
                icon: Icons.play_circle_outline_rounded,
                iconColor: const Color(0xFF4CAF50),
                title: 'Возобновить',
                onTap: () {
                  Navigator.pop(ctx);
                  provider.resumeTarget(target.id);
                },
              ),
            if (!isCompleted)
              _buildMenuItem(
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.red.shade400,
                title: 'Удалить',
                titleColor: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Удалить цель?'),
                      content: Text('"${target.name}" будет удалена'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) provider.deleteTarget(target.id);
                },
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
      subtitle: subtitle != null
          ? Text(subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
          : null,
      onTap: onTap,
    );
  }
}

// ==================== ЛИСТ КОНСТРУКТОРА ЦЕЛИ ====================

class _TargetBuilderSheet extends StatefulWidget {
  final bool isDark;
  final FitnessProvider provider;
  const _TargetBuilderSheet({required this.isDark, required this.provider});

  @override
  State<_TargetBuilderSheet> createState() => _TargetBuilderSheetState();
}

class _TargetBuilderSheetState extends State<_TargetBuilderSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _valueController = TextEditingController();
  final _repsController = TextEditingController(text: '10');

  FitnessTargetType _type = FitnessTargetType.strengthMax;
  Exercise? _selectedExercise;
  DateTime? _deadline;
  Color _selectedColor = const Color(0xFFFF6B35);
  String? _measurement;

  static const _colors = [
    Color(0xFFFF6B35), Color(0xFF4CAF50), Color(0xFF4A9BFF),
    Color(0xFFE91E63), Color(0xFF9C27B0), Color(0xFFFFCC00),
    Color(0xFF00C7BE), Color(0xFF795548), Color(0xFF3F51B5),
    Color(0xFFFF5722),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _valueController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = widget.provider;
    final templates = provider.getTargetTemplates();
    final showRepsField = _type == FitnessTargetType.strengthReps;
    final showExercisePicker = _type == FitnessTargetType.strengthMax ||
        _type == FitnessTargetType.strengthReps ||
        _type == FitnessTargetType.bodyweightReps;
    final showMeasurementPicker = _type == FitnessTargetType.bodyMeasurement;

    return Column(
      children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Создать цель', style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // ШАБЛОНЫ
              Text('🎯 Популярные цели',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.grey.shade700)),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final t = templates[i];
                    return _buildTemplateChip(t);
                  },
                ),
              ),
              const SizedBox(height: 20),
              // ТИП
              Text('Тип цели', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.grey.shade700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: FitnessTargetType.values.map((type) {
                  final isSelected = type == _type;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _type = type;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _selectedColor.withOpacity(0.15)
                            : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: _selectedColor, width: 2)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(type.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(type.displayName,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // НАЗВАНИЕ
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Название цели',
                  hintText: 'Например: Жим 100 кг',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F1115) : Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 12),
              // ОПИСАНИЕ
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Описание (опционально)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F1115) : Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 12),
              // УПРАЖНЕНИЕ (если нужно)
              if (showExercisePicker) ...[
                GestureDetector(
                  onTap: () => _pickExercise(context),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1115) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _selectedColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(_selectedExercise?.exerciseType.emoji ?? '🏋️',
                                style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_selectedExercise?.name ?? 'Выбрать упражнение',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black87)),
                              if (_selectedExercise != null)
                                Text(
                                  _selectedExercise!.muscleGroups.map((m) => m.displayName).join(' • '),
                                  style: TextStyle(fontSize: 10,
                                      color: isDark ? Colors.white38 : Colors.grey.shade500),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // ОБХВАТ (если bodyMeasurement)
              if (showMeasurementPicker) ...[
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    ('chest', 'Грудь'), ('waist', 'Талия'), ('hips', 'Бёдра'),
                    ('biceps', 'Бицепс'), ('thigh', 'Бедро'), ('calf', 'Икра'),
                    ('neck', 'Шея'), ('forearm', 'Предплечье'),
                  ].map((m) {
                    final isSelected = _measurement == m.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _measurement = m.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _selectedColor.withOpacity(0.15) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected ? Border.all(color: _selectedColor, width: 2) : null,
                        ),
                        child: Text(m.$2,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              // ЦЕЛЕВОЕ ЗНАЧЕНИЕ
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Целевое значение',
                        suffixText: _type.defaultUnit,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F1115) : Colors.grey.shade100,
                      ),
                    ),
                  ),
                  if (showRepsField) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Повторений',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F1115) : Colors.grey.shade100,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // ДЕДЛАЙН
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (date != null) setState(() => _deadline = date);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F1115) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(_deadline != null
                                ? '${_deadline!.day}.${_deadline!.month}.${_deadline!.year}'
                                : 'Дедлайн (опционально)',
                                style: TextStyle(fontSize: 13,
                                    color: isDark ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_deadline != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _deadline = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // ЦВЕТ
              Text('Акцентный цвет', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.grey.shade700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _colors.map((c) {
                  final isSelected = c.value == _selectedColor.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(color: c.withOpacity(0.4), blurRadius: 8),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // СОЗДАТЬ
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _createTarget(provider),
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('СОЗДАТЬ ЦЕЛЬ',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateChip(FitnessTarget t) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _nameController.text = t.name;
        _descController.text = t.description;
        _valueController.text = t.targetValue.toString();
        setState(() {
          _type = t.type;
          _selectedColor = t.accentColor;
          if (t.exerciseId != null) {
            try {
              _selectedExercise = widget.provider.exercises.firstWhere((e) => e.id == t.exerciseId);
            } catch (_) {}
          }
          if (t.extra.containsKey('measurement')) {
            _measurement = t.extra['measurement'] as String?;
          }
          if (t.extra.containsKey('reps')) {
            _repsController.text = (t.extra['reps'] as int).toString();
          }
        });
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [t.accentColor.withOpacity(0.2), t.accentColor.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.accentColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.type.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(t.name,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${t.formattedTarget} ${t.unit}',
                style: TextStyle(fontSize: 11, color: t.accentColor, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  void _pickExercise(BuildContext context) async {
    final result = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _ExercisePickerSheet(
          isDark: widget.isDark,
          exercises: widget.provider.exercises,
          filterType: _type == FitnessTargetType.bodyweightReps ? ExerciseType.bodyweight : null,
        ),
      ),
    );
    if (result != null) setState(() => _selectedExercise = result);
  }

  void _createTarget(FitnessProvider provider) {
    final name = _nameController.text.trim();
    final value = double.tryParse(_valueController.text) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название цели'), backgroundColor: Colors.red),
      );
      return;
    }
    if (value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите целевое значение'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_type == FitnessTargetType.bodyMeasurement && _measurement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите обхват'), backgroundColor: Colors.red),
      );
      return;
    }

    final extra = <String, dynamic>{};
    if (_type == FitnessTargetType.strengthReps) {
      extra['reps'] = int.tryParse(_repsController.text) ?? 10;
    }
    if (_measurement != null) {
      extra['measurement'] = _measurement;
    }

    // Стартовое значение
    double startValue = 0;
    if (_type == FitnessTargetType.bodyWeight) {
      startValue = provider.profile?.currentWeight ?? 0;
    }

    final target = FitnessTarget(
      id: const Uuid().v4(),
      name: name,
      description: _descController.text.trim(),
      type: _type,
      exerciseId: _selectedExercise?.id,
      targetValue: value,
      startValue: startValue,
      currentValue: startValue,
      unit: _type.defaultUnit,
      deadline: _deadline,
      accentColor: _selectedColor,
      extra: extra,
    );

    provider.addTarget(target);
    Navigator.pop(context);
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.white),
            const SizedBox(width: 8),
            Text('Цель "$name" создана!'),
          ],
        ),
        backgroundColor: _selectedColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ==================== ВЫБОР УПРАЖНЕНИЯ ====================

class _ExercisePickerSheet extends StatefulWidget {
  final bool isDark;
  final List<Exercise> exercises;
  final ExerciseType? filterType;
  const _ExercisePickerSheet({required this.isDark, required this.exercises, this.filterType});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises.where((e) {
      if (widget.filterType != null && e.exerciseType != widget.filterType) return false;
      if (_query.isNotEmpty && !e.name.toLowerCase().contains(_query.toLowerCase())) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Поиск упражнения...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: widget.isDark ? const Color(0xFF0F1115) : Colors.grey.shade100,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final ex = filtered[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: ex.muscleGroups.isNotEmpty
                      ? ex.muscleGroups.first.color.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  child: Text(ex.exerciseType.emoji),
                ),
                title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(ex.muscleGroups.map((m) => m.displayName).join(' • '),
                    style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(context, ex),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==================== EXTENSION ====================

extension on FitnessTarget {
  String get formattedRemaining {
    final rem = remaining;
    if (rem == rem.roundToDouble()) return rem.toStringAsFixed(0);
    return rem.toStringAsFixed(1);
  }
}