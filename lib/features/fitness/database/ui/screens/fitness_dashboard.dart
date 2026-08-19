import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../nutrition/providers/nutrition_provider.dart';
import '../../../../nutrition/ui/screens/fuel_dashboard_screen.dart';
import '../../../models/fitness_models.dart';
import '../../../models/enums.dart';
import '../../../providers/fitness_provider.dart';
import 'exercise_library_screen.dart';
import 'program_builder_screen.dart';
import 'program_view_screen.dart';
import 'workout_execution_screen.dart';
import 'workout_log_screen.dart';
import 'progress_screen.dart';
import 'photo_comparison_screen.dart';
import 'wellbeing_screen.dart';
import 'active_program_screen.dart';
import 'completed_programs_screen.dart';
import 'fitness_targets_screen.dart';

class Achievement {
  final String emoji;
  final String title;
  final String description;
  final String category;
  final Color color;
  final bool isUnlocked;
  final double progress;
  final String requirement;

  Achievement(this.emoji, this.title, this.description, this.category,
      this.color, this.isUnlocked, this.progress, this.requirement);
}

class FitnessDashboard extends StatefulWidget {
  final bool isDark;
  const FitnessDashboard({super.key, this.isDark = false});

  @override
  State<FitnessDashboard> createState() => _FitnessDashboardState();
}

class _FitnessDashboardState extends State<FitnessDashboard>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;

  NutritionProvider? _nutritionProvider;
  Future<NutritionProvider>? _nutritionFuture;

  String _avatarEmoji = '💪';
  String _profileName = 'Атлет';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _avatarEmoji = prefs.getString('avatar_emoji') ?? '💪';
        _profileName = prefs.getString('profile_name') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<NutritionProvider> _getNutritionProvider() {
    _nutritionFuture ??= _initNutritionProvider();
    return _nutritionFuture!;
  }

  Future<NutritionProvider> _initNutritionProvider() async {
    if (_nutritionProvider != null) return _nutritionProvider!;
    debugPrint('🥗 Создание NutritionProvider...');
    _nutritionProvider = NutritionProvider();
    await _nutritionProvider!.init();
    return _nutritionProvider!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final stats = provider.getStats();
    final profile = provider.profile;
    final activeSession = provider.activeSession;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeroHeader(isDark, provider, profile, stats)),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (activeSession != null) ...[
            SliverToBoxAdapter(child: _buildActiveProgramBanner(isDark, provider, activeSession)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
          SliverToBoxAdapter(child: _buildWeekTracker(isDark, provider)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildAchievementsStrip(isDark, provider)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildTargetsPreview(isDark, provider)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Быстрый доступ')),
          SliverToBoxAdapter(child: _buildQuickActionsGrid(isDark, provider, stats)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Питание', onTap: () async {
            final nutritionProvider = await _getNutritionProvider();
            if (!mounted) return;
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: nutritionProvider,
                child: const FuelDashboardScreen(isDark: true),
              ),
            ));
          })),
          SliverToBoxAdapter(child: _buildFuelPreview(isDark)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Ваши программы',
              onTap: () => _showProgramsList(context, isDark, provider))),
          SliverToBoxAdapter(child: _buildProgramsRow(isDark, provider)), // 🔥 ИЗМЕНЕНО
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Ваш прогресс', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) =>
                ChangeNotifierProvider.value(value: provider, child: ProgressScreen(isDark: isDark))));
          })),
          SliverToBoxAdapter(child: _buildProgressCards(isDark, stats)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (provider.templates.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Готовые шаблоны')),
            SliverToBoxAdapter(child: _buildTemplatesGrid(isDark, provider)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
          SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Ещё')),
          SliverToBoxAdapter(child: _buildExtraGrid(isDark, provider)),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  // ==================== 🎯 HERO HEADER ====================

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Доброе утро';
    if (h >= 12 && h < 17) return 'Добрый день';
    if (h >= 17 && h < 23) return 'Добрый вечер';
    return 'Доброй ночи';
  }

  String _getGreetingEmoji() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return '☀️';
    if (h >= 12 && h < 17) return '🌤️';
    if (h >= 17 && h < 23) return '🌙';
    return '🌙';
  }

  String _getTodayDate() {
    final now = DateTime.now();
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  Widget _buildHeroHeader(bool isDark, FitnessProvider provider, UserFitnessProfile? profile, Map<String, dynamic> stats) {
    final now = DateTime.now();
    final last7 = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final weekVolume = last7.fold<double>(0, (s, d) =>
    s + provider.getLogsForDate(d).fold<double>(0, (sum, l) => sum + (l.totalVolume ?? 0)));
    final weekWorkouts = last7.fold<int>(0, (s, d) =>
    s + provider.getLogsForDate(d).where((l) => l.status == WorkoutDayStatus.completed).length);

    final displayName = _profileName.isNotEmpty
        ? _profileName
        : (profile?.name ?? 'Атлет');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1D24), const Color(0xFF0F1115), const Color(0xFF151A26)]
              : [const Color(0xFFFF6B35), const Color(0xFFFF3D00)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (ctx, child) {
                      return Container(
                        padding: EdgeInsets.all(2 + _pulseController.value * 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF6B35).withOpacity(0.5 - _pulseController.value * 0.3),
                            width: 2,
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      onTap: () => _showEditProfileDialog(context, provider),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFFFF6B35), const Color(0xFFFF3D00)]
                                : [Colors.white.withOpacity(0.35), Colors.white.withOpacity(0.15)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: Center(
                          child: Text(_avatarEmoji, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _showEditProfileDialog(context, provider),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                        ),
                        child: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFFFF6B35)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()}, $displayName! ${_getGreetingEmoji()}',
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTodayDate(),
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (profile?.currentWeight != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${profile!.currentWeight!.toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                      Text('кг', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(flex: 3, child: _buildHeroNutritionCard(isDark)),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildHeroWeeklyCard(isDark, weekWorkouts, weekVolume)),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 🎯 HERO NUTRITION CARD ====================

  Widget _buildHeroNutritionCard(bool isDark) {
    return FutureBuilder<NutritionProvider>(
      future: _getNutritionProvider(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.defaultGoals == null) {
          return Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isDark ? 0.05 : 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
          );
        }
        final provider = snap.data!;
        final today = DateTime.now();
        final summary = provider.getSummaryForDate(today);
        final goals = provider.getGoalsForDate(today);
        final calPct = summary.percentOf(goals);
        final waterPct = summary.waterPercentOf(goals);

        final pPct = goals.protein > 0 ? (summary.protein / goals.protein).clamp(0.0, 1.0) : 0.0;
        final fPct = goals.fat > 0 ? (summary.fat / goals.fat).clamp(0.0, 1.0) : 0.0;
        final cPct = goals.carbs > 0 ? (summary.carbs / goals.carbs).clamp(0.0, 1.0) : 0.0;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              ChangeNotifierProvider.value(value: provider, child: const FuelDashboardScreen(isDark: true)))),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF00D4FF).withOpacity(isDark ? 0.15 : 0.2),
                const Color(0xFF00FF9D).withOpacity(isDark ? 0.05 : 0.1),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFF00D4FF), size: 12),
                    const SizedBox(width: 4),
                    const Text('ПИТАНИЕ', style: TextStyle(color: Color(0xFF00D4FF), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const Spacer(),
                    Text('${summary.calories.round()}/${goals.calories.round()}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                  ],
                ),
                const SizedBox(height: 4),
                _buildMiniProgressBar(calPct, const Color(0xFF00D4FF)),
                const SizedBox(height: 6),
                _buildMiniMacroRow('Б', summary.protein, goals.protein, pPct, const Color(0xFF00FF9D)),
                const SizedBox(height: 3),
                _buildMiniMacroRow('Ж', summary.fat, goals.fat, fPct, const Color(0xFFFF2D55)),
                const SizedBox(height: 3),
                _buildMiniMacroRow('У', summary.carbs, goals.carbs, cPct, const Color(0xFFFFD60A)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.water_drop_rounded, color: Color(0xFF4A9BFF), size: 10),
                    const SizedBox(width: 3),
                    Expanded(child: _buildMiniProgressBar(waterPct, const Color(0xFF4A9BFF))),
                    const SizedBox(width: 4),
                    Text('${summary.waterMl}',
                        style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniMacroRow(String label, double current, double goal, double pct, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 10,
          child: Text(label,
              style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ),
        const SizedBox(width: 3),
        Expanded(child: _buildMiniProgressBar(pct, color)),
        const SizedBox(width: 4),
        Text('${current.round()}/${goal.round()}',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 7, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildMiniProgressBar(double pct, Color color) {
    return Stack(
      children: [
        Container(height: 3, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
        FractionallySizedBox(
          widthFactor: pct.clamp(0.0, 1.0),
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        ),
      ],
    );
  }

  Widget _buildHeroWeeklyCard(bool isDark, int weekWorkouts, double weekVolume) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isDark ? 0.05 : 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: Color(0xFFFF6B35), size: 14),
              const SizedBox(width: 4),
              const Text('НЕДЕЛЯ', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 6),
          Text('$weekWorkouts трен.',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text('${_formatVolume(weekVolume)} кг',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  // ==================== 🔒 ДИАЛОГ РЕДАКТИРОВАНИЯ ПРОФИЛЯ ====================

  void _showEditProfileDialog(BuildContext context, FitnessProvider provider) {
    final nameController = TextEditingController(text: _profileName.isNotEmpty ? _profileName : (provider.profile?.name ?? ''));
    final emojis = ['💪', '🏋️', '🏃', '🧘', '🚴', '🤸', '🥊', '🔥', '⚡', '🦁', '🐺', '🦅', '👑', '🎯'];
    String selectedEmoji = _avatarEmoji;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Редактировать профиль',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                        color: widget.isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 20),
                Text('Имя',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87,
                      fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Введите имя',
                    filled: true,
                    fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Аватар',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: emojis.map((e) => GestureDetector(
                    onTap: () => setState(() => selectedEmoji = e),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: selectedEmoji == e
                            ? const Color(0xFFFF6B35).withOpacity(0.2)
                            : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selectedEmoji == e ? const Color(0xFFFF6B35) : Colors.transparent,
                            width: 2),
                      ),
                      child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newName = nameController.text.trim();
                      final prefs = await SharedPreferences.getInstance();

                      await prefs.setString('avatar_emoji', selectedEmoji);

                      if (newName.isNotEmpty) {
                        await prefs.setString('profile_name', newName);
                      }

                      if (mounted) {
                        setState(() {
                          _avatarEmoji = selectedEmoji;
                          if (newName.isNotEmpty) _profileName = newName;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(newName.isNotEmpty
                              ? '✅ Профиль обновлён: $newName'
                              : '✅ Аватар обновлён'),
                          backgroundColor: const Color(0xFF4CAF50),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Сохранить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 🎯 ТРЕКЕР НЕДЕЛИ ====================

  Widget _buildWeekTracker(bool isDark, FitnessProvider provider) {
    final now = DateTime.now();
    final last7 = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    const dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final volumes = last7.map((d) => provider.getLogsForDate(d)
        .fold<double>(0, (s, l) => s + (l.totalVolume ?? 0))).toList();
    final maxVol = volumes.fold<double>(0, (a, b) => a > b ? a : b);
    final weekWorkouts = last7.fold<int>(0, (s, d) =>
    s + provider.getLogsForDate(d).where((l) => l.status == WorkoutDayStatus.completed).length);
    final weekVolume = volumes.fold<double>(0, (a, b) => a + b);
    final activeDays = last7.where((d) =>
        provider.getLogsForDate(d).any((l) => l.status == WorkoutDayStatus.completed)).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4A9BFF), Color(0xFF00C7BE)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Последние 7 дней', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                      Text('Нажми на день для деталей', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      ChangeNotifierProvider.value(value: provider, child: WorkoutLogScreen(isDark: isDark)))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF4A9BFF).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Всё →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4A9BFF))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 92,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final date = last7[i];
                  final isToday = _isSameDay(date, now);
                  final logs = provider.getLogsForDate(date);
                  final completed = logs.where((l) => l.status == WorkoutDayStatus.completed).length;
                  final skipped = logs.where((l) => l.status == WorkoutDayStatus.skipped).length;
                  final hasWorkout = logs.isNotEmpty;
                  final barH = maxVol > 0 ? (volumes[i] / maxVol) : 0.0;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showDayDetails(context, date, logs, isDark, provider);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          children: [
                            Text(dayNames[date.weekday - 1],
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                    color: isToday ? const Color(0xFFFF6B35) : (isDark ? Colors.white38 : Colors.grey.shade500))),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: 8,
                                      height: 8 + barH * 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: hasWorkout
                                              ? [const Color(0xFFFF6B35), const Color(0xFFFF6B35).withOpacity(0.3)]
                                              : [Colors.grey.withOpacity(0.2), Colors.grey.withOpacity(0.1)],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: _getDayColor(isDark, hasWorkout, completed, skipped),
                                        shape: BoxShape.circle,
                                        border: isToday ? Border.all(color: const Color(0xFFFF6B35), width: 2) : null,
                                        boxShadow: hasWorkout
                                            ? [BoxShadow(color: _getDayColor(isDark, hasWorkout, completed, skipped).withOpacity(0.5), blurRadius: 8)]
                                            : null,
                                      ),
                                      child: Center(child: _getDayIcon(hasWorkout, completed, skipped, small: true)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${date.day}',
                                style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                                    color: isToday ? const Color(0xFFFF6B35) : (isDark ? Colors.white : Colors.black87))),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWeekStat('✅', '$weekWorkouts', 'тренировок', const Color(0xFF4CAF50), isDark),
                  Container(width: 1, height: 30, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                  _buildWeekStat('🏋️', _formatVolume(weekVolume), 'кг тоннаж', const Color(0xFFFF6B35), isDark),
                  Container(width: 1, height: 30, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                  _buildWeekStat('⚡', '$activeDays/7', 'активных', const Color(0xFF4A9BFF), isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekStat(String emoji, String value, String label, Color color, bool isDark) {
    return Column(
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
        ]),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.grey.shade500)),
      ],
    );
  }

  Color _getDayColor(bool isDark, bool hasWorkout, int completed, int skipped) {
    if (!hasWorkout) return isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;
    if (completed > 0) return const Color(0xFF4CAF50);
    if (skipped > 0) return const Color(0xFFF44336);
    return isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;
  }

  Widget _getDayIcon(bool hasWorkout, int completed, int skipped, {bool small = false}) {
    final size = small ? 14.0 : 24.0;
    if (!hasWorkout) return Icon(Icons.remove_rounded, size: size, color: Colors.grey.shade400);
    if (completed > 0) return Icon(Icons.check_rounded, size: size, color: Colors.white);
    if (skipped > 0) return Icon(Icons.close_rounded, size: size, color: Colors.white);
    return Icon(Icons.remove_rounded, size: size, color: Colors.grey);
  }

  // ==================== 🎯 ЛЕНТА ДОСТИЖЕНИЙ ====================

  List<Achievement> _getAchievements(FitnessProvider provider) {
    final stats = provider.getStats();
    final streak = ((stats['currentStreak'] ?? 0) as num).toInt();
    final total = ((stats['totalWorkouts'] ?? 0) as num).toInt();
    final volume = ((stats['totalVolume'] ?? 0) as num).toDouble();
    final week = ((stats['workoutsThisWeek'] ?? 0) as num).toInt();
    final exercisesInBase = ((stats['totalExercises'] ?? 0) as num).toInt();
    final completedSessionsCount = provider.completedSessions.length;
    final activeTargets = provider.activeTargets.length;
    final photosCount = provider.photos.length;
    final programsCount = provider.programs.length;
    final todayWellbeing = provider.getTodayWellbeing();
    final hasActiveTargets = activeTargets > 0;

    double calcProgress(num current, num goal) {
      if (goal <= 0) return 0.0;
      return (current / goal).clamp(0.0, 1.0).toDouble();
    }

    final trainingAchievements = [
      Achievement('👟', 'Первый шаг', 'Проведи свою первую тренировку и начни путь к цели',
          '🏃 Тренировки', const Color(0xFF4CAF50), total >= 1, calcProgress(total, 1), '1 тренировка'),
      Achievement('💪', 'Десятка', 'Проведи 10 полноценных тренировок',
          '🏃 Тренировки', const Color(0xFF00C7BE), total >= 10, calcProgress(total, 10), '10 тренировок'),
      Achievement('🎖️', 'Полтинник', 'Пройди отметку в 50 тренировок — серьёзный рубеж!',
          '🏃 Тренировки', const Color(0xFF00BCD4), total >= 50, calcProgress(total, 50), '50 тренировок'),
      Achievement('💎', 'Сотня', '100 тренировок! Ты настоящий фанат своего дела',
          '🏃 Тренировки', const Color(0xFF2196F3), total >= 100, calcProgress(total, 100), '100 тренировок'),
      Achievement('🌟', 'Легенда', 'Легендарные 500 тренировок — ты икона',
          '🏃 Тренировки', const Color(0xFF9C27B0), total >= 500, calcProgress(total, 500), '500 тренировок'),
      Achievement('⚡', 'Неделя в ударе', 'Проведи 3 или больше тренировок за одну неделю',
          '🏃 Тренировки', const Color(0xFF4A9BFF), week >= 3, calcProgress(week, 3), '3 тренировки/нед'),
      Achievement('🗓️', 'Режим недели', 'Тренируйся 5 дней в неделю — максимальный темп',
          '🏃 Тренировки', const Color(0xFF3F51B5), week >= 5, calcProgress(week, 5), '5 тренировок/нед'),
    ];

    final streakAchievements = [
      Achievement('🔥', 'Серия 3', 'Тренируйся 3 дня подряд без пропусков',
          '🔥 Серии', const Color(0xFFFF6B35), streak >= 3, calcProgress(streak, 3), '3 дня подряд'),
      Achievement('🔥', 'Неделя силы', 'Поддерживай серию 7 дней подряд',
          '🔥 Серии', const Color(0xFFFF5722), streak >= 7, calcProgress(streak, 7), '7 дней подряд'),
      Achievement('🔥', 'Две недели воли', '14 дней без единого пропуска — мощно!',
          '🔥 Серии', const Color(0xFFE64A19), streak >= 14, calcProgress(streak, 14), '14 дней подряд'),
      Achievement('🔥', 'Месяц дисциплины', 'Целый месяц тренировок без пропусков — ты машина!',
          '🔥 Серии', const Color(0xFFD84315), streak >= 30, calcProgress(streak, 30), '30 дней подряд'),
    ];

    final volumeAchievements = [
      Achievement('🏋️', 'Тонна', 'Подними суммарно 10 000 кг за всё время',
          '🏋️ Объёмы', const Color(0xFFE91E63), volume >= 10000, calcProgress(volume, 10000), '10 000 кг'),
      Achievement('🏋️', 'Десять тонн', '100 000 кг — ты уже поднимаешь грузовики',
          '🏋️ Объёмы', const Color(0xFFC2185B), volume >= 100000, calcProgress(volume, 100000), '100 000 кг'),
      Achievement('🏋️', 'Стальная тонна', 'Полмиллиона килограмм — ты настоящий Атлант!',
          '🏋️ Объёмы', const Color(0xFF880E4F), volume >= 500000, calcProgress(volume, 500000), '500 000 кг'),
    ];

    final programAchievements = [
      Achievement('🏆', 'Финишер', 'Успешно заверши свою первую программу',
          '🎯 Цели и программы', const Color(0xFFFFCC00), completedSessionsCount > 0,
          completedSessionsCount > 0 ? 1.0 : 0.0, '1 программа'),
      Achievement('🏆', 'Серийный финишер', 'Заверши 3 программы — ты коллекционер побед',
          '🎯 Цели и программы', const Color(0xFFFFA000), completedSessionsCount >= 3,
          calcProgress(completedSessionsCount, 3), '3 программы'),
      Achievement('🎯', 'Целеустремлённость', 'Поставь фитнес-цель и работай над ней',
          '🎯 Цели и программы', const Color(0xFF9C27B0), hasActiveTargets,
          hasActiveTargets ? 1.0 : 0.0, 'Активные цели'),
      Achievement('🎯', 'Мульти-цель', 'Работай сразу над 3 целями одновременно',
          '🎯 Цели и программы', const Color(0xFF7B1FA2), activeTargets >= 3,
          calcProgress(activeTargets, 3), '3 активные цели'),
      Achievement('🎓', 'Архитектор', 'Создай 5 собственных программ тренировок',
          '🎯 Цели и программы', const Color(0xFF673AB7), programsCount >= 5,
          calcProgress(programsCount, 5), '5 программ'),
    ];

    final otherAchievements = [
      Achievement('📸', 'Первое фото', 'Сделай первое фото для отслеживания прогресса',
          '✨ Прогресс', const Color(0xFFFF9500), photosCount > 0,
          photosCount > 0 ? 1.0 : 0.0, '1 фото'),
      Achievement('📸', 'Хроникёр', 'Собери коллекцию из 5 фото-отчётов',
          '✨ Прогресс', const Color(0xFFFF5722), photosCount >= 5,
          calcProgress(photosCount, 5), '5 фото'),
      Achievement('🧠', 'Осознанность', 'Запиши своё самочувствие хотя бы раз',
          '✨ Прогресс', const Color(0xFF34C759), todayWellbeing != null,
          todayWellbeing != null ? 1.0 : 0.0, '1 запись'),
      Achievement('🧠', 'Гуру самочувствия', 'Отслеживай своё состояние регулярно',
          '✨ Прогресс', const Color(0xFF2E7D32), todayWellbeing != null,
          todayWellbeing != null ? 1.0 : 0.0, '10+ записей'),
      Achievement('📚', 'Знаток базы', 'Изучи 50+ упражнений в библиотеке',
          '✨ Прогресс', const Color(0xFF795548), exercisesInBase >= 50,
          calcProgress(exercisesInBase, 50), '50 упражнений'),
    ];

    final all = [
      ...trainingAchievements,
      ...streakAchievements,
      ...volumeAchievements,
      ...programAchievements,
      ...otherAchievements,
    ];

    all.sort((a, b) => (b.isUnlocked ? 1 : 0).compareTo(a.isUnlocked ? 1 : 0));
    return all;
  }

  Widget _buildAchievementsStrip(bool isDark, FitnessProvider provider) {
    final achievements = _getAchievements(provider);
    achievements.sort((a, b) => (b.isUnlocked ? 1 : 0).compareTo(a.isUnlocked ? 1 : 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(isDark, 'Достижения'),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: achievements.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final a = achievements[i];
              return GestureDetector(
                onTap: () => _showAchievementDetails(context, a, isDark),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: a.isUnlocked
                        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [a.color.withOpacity(0.25), a.color.withOpacity(0.08)])
                        : null,
                    color: a.isUnlocked ? null : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: a.isUnlocked ? a.color.withOpacity(0.4) : Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(a.emoji, style: const TextStyle(fontSize: 22)),
                          const Spacer(),
                          if (!a.isUnlocked) const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(a.title,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                              color: a.isUnlocked ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (!a.isUnlocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: LinearProgressIndicator(
                            value: a.progress,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(a.color),
                            minHeight: 2,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAchievementDetails(BuildContext context, Achievement a, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: a.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(a.category,
                  style: TextStyle(color: a.color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 16),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [a.color.withOpacity(0.3), a.color.withOpacity(0.1)]),
                shape: BoxShape.circle,
                border: Border.all(color: a.color.withOpacity(0.5), width: 2),
              ),
              child: Center(child: Text(a.emoji, style: const TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 16),
            Text(a.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(a.description, style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Требование', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                      Text(a.requirement, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(height: 8, decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        widthFactor: a.progress,
                        child: Container(decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [a.color, a.color.withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(4))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.isUnlocked ? '✅ Получено!' : '${(a.progress * 100).toInt()}% выполнено',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        color: a.isUnlocked ? const Color(0xFF4CAF50) : a.color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!a.isUnlocked && a.progress > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: a.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: a.color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, color: a.color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_getMotivationPhrase(a.progress),
                          style: TextStyle(fontSize: 11, color: a.color, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getMotivationPhrase(double progress) {
    if (progress < 0.25) return 'Начало положено — не останавливайся! 💪';
    if (progress < 0.50) return 'Отличный темп — четверть пути пройдена!';
    if (progress < 0.75) return 'Ты на полпути — скоро финиш! 🔥';
    if (progress < 1.0) return 'Почти у цели — последний рывок! 🚀';
    return 'Ты легенда! 🏆';
  }

  // ==================== 🎯 ПРЕВЬЮ ПИТАНИЯ ====================

  Widget _buildFuelPreview(bool isDark) {
    return FutureBuilder<NutritionProvider>(
      future: _getNutritionProvider(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
        }
        return ChangeNotifierProvider.value(
          value: snap.data!,
          child: Consumer<NutritionProvider>(builder: (ctx, provider, _) {
            if (provider.defaultGoals == null) {
              return const SizedBox(height: 160,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF), strokeWidth: 2)));
            }
            final today = DateTime.now();
            final summary = provider.getSummaryForDate(today);
            final goals = provider.getGoalsForDate(today);
            final percent = summary.percentOf(goals);
            final waterPct = summary.waterPercentOf(goals);

            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  ChangeNotifierProvider.value(value: provider, child: const FuelDashboardScreen(isDark: true)))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF141A2E), Color(0xFF1A2140)]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF9D)]),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.5), blurRadius: 10)],
                            ),
                            child: const Icon(Icons.bolt_rounded, color: Color(0xFF0A0E1A), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text('⚡ ТОПЛИВО', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'monospace')),
                          const Spacer(),
                          Text('${summary.entriesCount} приёмов', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF00D4FF).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Text('ОТКРЫТЬ →', style: TextStyle(color: Color(0xFF00D4FF), fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 88, height: 88,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 88, height: 88,
                                  child: CircularProgressIndicator(
                                    value: percent.clamp(0, 1),
                                    strokeWidth: 9,
                                    backgroundColor: Colors.white.withOpacity(0.08),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${summary.calories.round()}',
                                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace', height: 1)),
                                    const Text('ккал', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFuelMacro('Б', summary.protein, goals.protein, const Color(0xFF00FF9D)),
                                const SizedBox(height: 6),
                                _buildFuelMacro('Ж', summary.fat, goals.fat, const Color(0xFFFF2D55)),
                                const SizedBox(height: 6),
                                _buildFuelMacro('У', summary.carbs, goals.carbs, const Color(0xFFFFD60A)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.water_drop_rounded, color: Color(0xFF00D4FF), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(height: 5, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(3))),
                                FractionallySizedBox(
                                  widthFactor: waterPct.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF9D)]),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${summary.waterMl}/${goals.waterMl} мл',
                              style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildFuelMacro(String label, double current, double goal, Color color) {
    final percent = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label: ${current.round()} / ${goal.round()} г',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 3),
        Stack(
          children: [
            Container(height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(2))),
            FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== 🎯 ЦЕЛИ ====================

  Widget _buildTargetsPreview(bool isDark, FitnessProvider provider) {
    final active = provider.activeTargets;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [const Color(0xFFFF6B35).withOpacity(0.15), const Color(0xFFFF3D00).withOpacity(0.05)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.2)),
          boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Мои цели', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                      Text('${active.length} ${active.length == 1 ? "активная цель" : "активных целей"}',
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      ChangeNotifierProvider.value(value: provider, child: FitnessTargetsScreen(isDark: isDark)))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Все →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFF6B35))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (active.isEmpty)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                    ChangeNotifierProvider.value(value: provider, child: FitnessTargetsScreen(isDark: isDark)))),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Поставить цель', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                            Text('Например: пожать 100 кг или подтянуться 10 раз',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...active.take(2).map((t) => _buildMiniTargetCard(isDark, t)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTargetCard(bool isDark, FitnessTarget target) {
    final progress = target.progressPercent;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
          ChangeNotifierProvider.value(value: context.read<FitnessProvider>(), child: FitnessTargetsScreen(isDark: isDark)))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: target.accentColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [target.accentColor, target.accentColor.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: target.accentColor.withOpacity(0.3), blurRadius: 6)],
              ),
              child: Center(child: Text(target.type.emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(target.accentColor),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: target.accentColor)),
                Text('${target.formattedCurrent}/${target.formattedTarget}',
                    style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIVE PROGRAM BANNER ====================

  Widget _buildActiveProgramBanner(bool isDark, FitnessProvider provider, ProgramSession session) {
    final program = provider.programs.firstWhere(
          (p) => p.id == session.programId,
      orElse: () => WorkoutProgram(id: '', name: 'Неизвестная'),
    );
    final progress = session.progressPercent;
    final completedDays = session.daySessions.where((d) => d.status == DaySessionStatus.completed).length;
    final totalDays = session.daySessions.length;
    final currentDayIndex = session.currentDayIndex;
    final currentDay = currentDayIndex < program.days.length ? program.days[currentDayIndex] : null;
    final isRestDay = currentDay?.isRestDay ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            ChangeNotifierProvider.value(value: provider, child: ActiveProgramScreen(program: program, isDark: isDark)))),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFFF3D00), Color(0xFFE91E63)]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('🔥', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 4),
                      Text('АКТИВНАЯ ПРОГРАММА', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ]),
                  ),
                  const Spacer(),
                  if (session.streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                      child: Text('⚡ ${session.streak} ${_getDaysWord(session.streak)}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(program.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(
                isRestDay ? 'Сегодня: день отдыха 😴' : 'День ${currentDayIndex + 1} из $totalDays • ${currentDay?.exercises.length ?? 0} упражнений',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$completedDays / $totalDays дней', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isRestDay ? Icons.arrow_forward_rounded : Icons.play_arrow_rounded, color: const Color(0xFFFF6B35), size: 24),
                    const SizedBox(width: 8),
                    Text(isRestDay ? 'ПЕРЕЙТИ К ПРОГРАММЕ' : 'ПРОДОЛЖИТЬ ТРЕНИРОВКУ',
                        style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SECTION HEADER ====================

  Widget _buildSectionHeader(bool isDark, String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('Все →', style: TextStyle(fontSize: 11, color: Color(0xFFFF6B35), fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== 🎯 БЫСТРЫЙ ДОСТУП ====================

  Widget _buildQuickActionsGrid(bool isDark, FitnessProvider provider, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
        children: [
          _buildQuickActionCard(isDark, icon: Icons.play_arrow_rounded, title: 'Быстрый старт', subtitle: 'Свободная тренировка',
              gradient: const [Color(0xFFFF6B35), Color(0xFFFF3D00)], onTap: () => _quickStartWorkout(context, isDark, provider)),
          _buildQuickActionCard(isDark, icon: Icons.fitness_center_rounded, title: 'Упражнения', subtitle: '${stats['totalExercises']} в базе',
              gradient: const [Color(0xFF00C7BE), Color(0xFF009688)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ExerciseLibraryScreen(isDark: isDark))))),
          _buildQuickActionCard(isDark, icon: Icons.book_rounded, title: 'Журнал', subtitle: '${stats['totalWorkouts']} записей',
              gradient: const [Color(0xFF4A9BFF), Color(0xFF2962FF)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: WorkoutLogScreen(isDark: isDark))))),
          _buildQuickActionCard(isDark, icon: Icons.mood_rounded, title: 'Самочувствие', subtitle: 'Записать день',
              gradient: const [Color(0xFF34C759), Color(0xFF28A745)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: WellbeingScreen(isDark: isDark))))),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(bool isDark, {required IconData icon, required String title, required String subtitle, required List<Color> gradient, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 22)),
            const Spacer(),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ==================== 🔥 НОВОЕ: КАРТОЧКА ПРОГРАММЫ (УЛУЧШЕННАЯ) ====================

  /// Компактная карточка для горизонтального списка
  Widget _buildProgramCardCompact(bool isDark, WorkoutProgram program, bool isActive, FitnessProvider provider) {
    final stats = _getProgramStats(program);
    final textColor = isActive ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final subColor = isActive ? Colors.white70 : (isDark ? Colors.white54 : Colors.grey.shade600);

    // 🔥 ФОН для неактивной программы — используем accentColor с прозрачностью (как в билдере)
    final bgColor = isActive
        ? program.accentColor
        : program.accentColor.withOpacity(0.12);

    // 🔥 Обводка для неактивной программы — цвет акцента
    final borderColor = isActive
        ? Colors.white.withOpacity(0.3)
        : program.accentColor.withOpacity(0.3);

    return GestureDetector(
      onTap: () {
        if (isActive) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ActiveProgramScreen(program: program, isDark: isDark))));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramViewScreen(program: program, isDark: isDark))));
        }
      },
      onLongPress: () { HapticFeedback.mediumImpact(); _showProgramOptions(context, isDark, program, provider); },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isActive ? 2 : 1.5,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: program.accentColor.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6))]
              : [BoxShadow(color: program.accentColor.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.2)
                        : program.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(program.emoji, style: const TextStyle(fontSize: 20)),
                ),
                const Spacer(),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(6)),
                    child: const Text('АКТИВНАЯ', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  )
                else
                  Row(
                    children: [
                      _buildProgramTag(isDark, _difficultyEmoji(program.difficulty), isActive, program.accentColor),
                      const SizedBox(width: 4),
                      _buildProgramTag(isDark, _goalEmoji(program.goal), isActive, program.accentColor),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(program.name,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('⏱️ ${program.sessionDurationMinutes} мин • ${program.days.length} дней',
                style: TextStyle(fontSize: 11, color: subColor)),
            if (program.description != null && program.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(program.description!,
                    style: TextStyle(fontSize: 10, color: subColor.withOpacity(0.8)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            const Spacer(),
            if (isActive && provider.activeSession != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: provider.activeSession!.progressPercent,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('${(provider.activeSession!.progressPercent * 100).toInt()}%', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (provider.activeSession!.streak > 0)
                    Text('🔥${provider.activeSession!.streak}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  _buildProgramChip('${stats['completed']}', const Color(0xFF4CAF50), isActive),
                  const SizedBox(width: 4),
                  _buildProgramChip('${stats['pending']}', const Color(0xFFFFC107), isActive),
                  const SizedBox(width: 4),
                  Text('${program.days.length} дн.', style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Полная карточка для списка в bottom sheet
  Widget _buildProgramCardFull(bool isDark, WorkoutProgram program, bool isActive, FitnessProvider provider) {
    final textColor = isActive ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final subColor = isActive ? Colors.white70 : (isDark ? Colors.white54 : Colors.grey.shade600);

    // 🔥 ФОН для неактивной программы — используем accentColor с прозрачностью
    final bgColor = isActive
        ? program.accentColor
        : program.accentColor.withOpacity(0.12);

    // 🔥 Обводка для неактивной программы — цвет акцента
    final borderColor = isActive
        ? program.accentColor
        : program.accentColor.withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isActive ? 2 : 1.5),
        boxShadow: isActive
            ? [BoxShadow(color: program.accentColor.withOpacity(0.3), blurRadius: 12)]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.2)
                : program.accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(program.emoji, style: const TextStyle(fontSize: 24)),
        ),
        title: Text(program.name,
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${program.type.displayName} • ${program.days.length} дней • ⏱️${program.sessionDurationMinutes} мин',
                    style: TextStyle(fontSize: 11, color: subColor)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.2)
                        : program.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_difficultyEmoji(program.difficulty),
                      style: TextStyle(fontSize: 10, color: isActive ? Colors.white : program.accentColor)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.2)
                        : program.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_goalEmoji(program.goal),
                      style: TextStyle(fontSize: 10, color: isActive ? Colors.white : program.accentColor)),
                ),
              ],
            ),
            if (program.description != null && program.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(program.description!,
                    style: TextStyle(fontSize: 11, color: subColor.withOpacity(0.8)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            if (isActive && provider.activeSession != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: provider.activeSession!.progressPercent,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFF6B35)),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text('${(provider.activeSession!.progressPercent * 100).toInt()}% • День ${provider.activeSession!.currentDayIndex + 1} • 🔥${provider.activeSession!.streak}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFFFF6B35), fontWeight: FontWeight.w700)),
            ],
          ],
        ),
        trailing: isActive
            ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8)
            ),
            child: const Text('АКТИВНАЯ', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900)))
            : Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: program.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)
          ),
          child: Icon(Icons.chevron_right_rounded, color: program.accentColor, size: 20),
        ),
        onTap: () {
          if (isActive) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ActiveProgramScreen(program: program, isDark: isDark))));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramViewScreen(program: program, isDark: isDark))));
          }
        },
        onLongPress: () => _showProgramOptions(context, isDark, program, provider),
      ),
    );
  }

// 🔥 Обновленный метод _buildProgramTag с цветом
  Widget _buildProgramTag(bool isDark, String text, bool isActive, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withOpacity(0.2)
            : accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: isActive ? Colors.white : accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Вспомогательные методы для отображения полей программы

  String _difficultyEmoji(String difficulty) {
    switch (difficulty) {
      case 'easy': return '🟢';
      case 'hardcore': return '🔴';
      default: return '🟡';
    }
  }

  String _goalEmoji(String goal) {
    switch (goal) {
      case 'lose': return '🔥';
      case 'gain': return '💪';
      case 'strength': return '🏋️';
      default: return '🎯';
    }
  }

  // ==================== ПРОГРАММЫ (ГОРИЗОНТАЛЬНЫЙ СПИСОК) ====================

  Widget _buildProgramsRow(bool isDark, FitnessProvider provider) {
    if (provider.programs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark)))),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isDark ? [const Color(0xFF1A1D24), const Color(0xFF0F1115)] : [Colors.white, const Color(0xFFF5F7FA)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Создать программу', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text('Создайте свою первую программу тренировок', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 210, // 🔥 Увеличил высоту, чтобы поместилось больше информации
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: provider.programs.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == provider.programs.length) {
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark)))),
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.add_rounded, color: Color(0xFFFF6B35), size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text('Создать', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }
          final program = provider.programs[index];
          final isActive = provider.activeSession?.programId == program.id;
          return _buildProgramCardCompact(isDark, program, isActive, provider);
        },
      ),
    );
  }

  // ==================== ПРОГРАММЫ (СПИСОК В BOTTOM SHEET) ====================

  void _showProgramsList(BuildContext context, bool isDark, FitnessProvider provider) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Мои программы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark))));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: provider.programs.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.fitness_center_rounded, size: 60, color: isDark ? Colors.white12 : Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Нет программ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.grey.shade500)),
              ]))
                  : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: provider.programs.length,
                itemBuilder: (context, index) {
                  final program = provider.programs[index];
                  final isActive = provider.activeSession?.programId == program.id;
                  return _buildProgramCardFull(isDark, program, isActive, provider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ОПЦИИ ПРОГРАММЫ ====================

  void _showProgramOptions(BuildContext context, bool isDark, WorkoutProgram program, FitnessProvider provider) {
    final isActive = provider.activeSession?.programId == program.id;
    final hasActiveSession = provider.activeSession != null;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1D24) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(program.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87))),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]), borderRadius: BorderRadius.circular(8)),
                    child: const Text('🔥 АКТИВНАЯ', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (!isActive && !hasActiveSession)
              _buildMenuItem(icon: Icons.play_arrow_rounded, iconGradient: const [Color(0xFFFF6B35), Color(0xFFFF3D00)],
                  title: 'Начать прохождение', subtitle: 'Режим последовательного выполнения',
                  onTap: () { Navigator.pop(ctx); _showStartProgramDialog(context, isDark, program, provider); }),
            if (isActive)
              _buildMenuItem(icon: Icons.play_circle_filled, iconColor: const Color(0xFF4CAF50), iconBgColor: const Color(0xFF4CAF50).withOpacity(0.15),
                  title: 'Продолжить прохождение', subtitle: 'День ${provider.activeSession!.currentDayIndex + 1}',
                  onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ActiveProgramScreen(program: program, isDark: isDark)))); }),
            if (isActive)
              _buildMenuItem(icon: Icons.pause_circle_outline, iconColor: Colors.orange, iconBgColor: Colors.orange.withOpacity(0.15),
                  title: 'Приостановить', onTap: () async { Navigator.pop(ctx); await provider.pauseProgramSession(); }),
            if (isActive)
              _buildMenuItem(icon: Icons.flag_outlined, iconColor: Colors.red.shade400, iconBgColor: Colors.red.withOpacity(0.1),
                  title: 'Бросить программу', titleColor: Colors.red, subtitle: 'Отказаться от прохождения', subtitleColor: Colors.red,
                  onTap: () { Navigator.pop(ctx); _confirmAbandonProgram(context, isDark, program, provider); }),
            _buildMenuItem(icon: Icons.edit_rounded, iconColor: const Color(0xFFFF6B35), iconBgColor: const Color(0xFFFF6B35).withOpacity(0.15),
                title: 'Редактировать',
                onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(existingProgram: program, isDark: isDark)))); }),
            _buildMenuItem(icon: Icons.delete_rounded, iconColor: Colors.red.shade400, iconBgColor: Colors.red.withOpacity(0.1),
                title: 'Удалить', titleColor: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (isActive) await provider.abandonProgramSession(provider.activeSession!.id);
                  await provider.deleteProgram(program.id);
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, List<Color>? iconGradient, Color? iconColor, Color? iconBgColor, required String title, Color? titleColor, String? subtitle, Color? subtitleColor, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconBgColor, gradient: iconGradient != null ? LinearGradient(colors: iconGradient) : null, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconGradient != null ? Colors.white : iconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor ?? Colors.grey)) : null,
      onTap: onTap,
    );
  }

  // ==================== СТАРТ ПРОГРАММЫ ====================

  void _showStartProgramDialog(BuildContext context, bool isDark, WorkoutProgram program, FitnessProvider provider) {
    ProgramDifficulty selectedDifficulty = ProgramDifficulty.standard;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]), borderRadius: BorderRadius.circular(10)),
                child: const Text('🚀', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Начать "${program.name}"', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 17))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${program.days.length} дней • Выберите режим прохождения:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600)),
              const SizedBox(height: 16),
              _buildDifficultyOption(isDark, emoji: '🟢', title: 'Гибкий', description: 'Можно пропускать дни без штрафов', isSelected: selectedDifficulty == ProgramDifficulty.flexible, onTap: () => setState(() => selectedDifficulty = ProgramDifficulty.flexible)),
              const SizedBox(height: 8),
              _buildDifficultyOption(isDark, emoji: '🟡', title: 'Стандартный', description: 'Пропуск сбрасывает серию', isSelected: selectedDifficulty == ProgramDifficulty.standard, onTap: () => setState(() => selectedDifficulty = ProgramDifficulty.standard)),
              const SizedBox(height: 8),
              _buildDifficultyOption(isDark, emoji: '🔴', title: 'Хардкор', description: 'Пропуск сбрасывает всю неделю', isSelected: selectedDifficulty == ProgramDifficulty.hardcore, onTap: () => setState(() => selectedDifficulty = ProgramDifficulty.hardcore)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await provider.startProgramSession(program.id, difficulty: selectedDifficulty);
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ActiveProgramScreen(program: program, isDark: isDark))));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  }
                }
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Начать!'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(bool isDark, {required String emoji, required String title, required String description, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF6B35).withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(14),
            border: isSelected ? Border.all(color: const Color(0xFFFF6B35), width: 2) : Border.all(color: Colors.transparent)),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                  Text(description, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFFFF6B35), size: 22),
          ],
        ),
      ),
    );
  }

  // ==================== БРОСИТЬ ПРОГРАММУ ====================

  void _confirmAbandonProgram(BuildContext context, bool isDark, WorkoutProgram program, FitnessProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Бросить программу?'),
          ],
        ),
        content: Text('Весь прогресс по "${program.name}" будет потерян. Вы уверены?', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.abandonProgramSession(provider.activeSession!.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Программа "${program.name}" остановлена'), backgroundColor: Colors.orange));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Бросить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== БЫСТРАЯ ТРЕНИРОВКА ====================

  void _quickStartWorkout(BuildContext context, bool isDark, FitnessProvider provider) {
    final quickDay = WorkoutDay(id: 'quick_${DateTime.now().millisecondsSinceEpoch}', programId: 'quick', dayNumber: 1, exercises: []);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1D24) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Быстрая тренировка', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Выберите упражнения для тренировки', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade500)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: provider.exercises.length,
                  itemBuilder: (context, index) {
                    final ex = provider.exercises[index];
                    final isAdded = quickDay.exercises.any((we) => we.exerciseId == ex.id);
                    return ListTile(
                      leading: CircleAvatar(
                          backgroundColor: ex.muscleGroups.isNotEmpty ? ex.muscleGroups.first.color.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                          child: Text(ex.exerciseType.emoji)),
                      title: Text(ex.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: isAdded
                          ? IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => setSheetState(() => quickDay.exercises.removeWhere((we) => we.exerciseId == ex.id)))
                          : IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFFF6B35)),
                          onPressed: () {
                            setSheetState(() {
                              quickDay.exercises.add(WorkoutExercise(id: 'quick_ex_${quickDay.exercises.length}', exerciseId: ex.id, order: quickDay.exercises.length, sets: [ExerciseSet(setNumber: 1, reps: 10, weight: 0)]));
                            });
                          }),
                    );
                  },
                ),
              ),
              if (quickDay.exercises.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: WorkoutExecutionScreen(day: quickDay, isDark: isDark))));
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('Начать (${quickDay.exercises.length} упр.)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ПРОГРЕСС ====================

  Widget _buildProgressCards(bool isDark, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildProgressCard(
              isDark,
              '🔥',
              '${stats['currentStreak'] ?? 0}',
              'дней стрик',
              const [Color(0xFFFF6B35), Color(0xFFFF3D00)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<FitnessProvider>(),
                    child: ProgressScreen(isDark: isDark),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProgressCard(
              isDark,
              '🏋️',
              '${stats['totalWorkouts'] ?? 0}',
              'тренировок',
              const [Color(0xFF4A9BFF), Color(0xFF2962FF)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<FitnessProvider>(),
                    child: WorkoutLogScreen(isDark: isDark),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProgressCard(
              isDark,
              '📊',
              '${stats['workoutsThisWeek'] ?? 0}',
              'за неделю',
              const [Color(0xFF00C7BE), Color(0xFF009688)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<FitnessProvider>(),
                    child: ProgressScreen(isDark: isDark),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
      bool isDark,
      String emoji,
      String value,
      String label,
      List<Color> gradient, {
        VoidCallback? onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ШАБЛОНЫ ====================

  Widget _buildTemplatesGrid(bool isDark, FitnessProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3),
        itemCount: provider.templates.length,
        itemBuilder: (context, index) {
          final t = provider.templates[index];
          return GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final program = await provider.createProgramFromTemplate(t.id);
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramViewScreen(program: program, isDark: isDark))));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                      ),
                      const Spacer(),
                      Icon(Icons.download_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey.shade400),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(t.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Expanded(child: Text(t.description, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== ЕЩЁ ====================

  Widget _buildExtraGrid(bool isDark, FitnessProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
        children: [
          _buildExtraCardWidget(isDark, icon: Icons.flag_rounded, title: 'Мои цели', subtitle: '${provider.activeTargets.length} активных',
              gradient: const [Color(0xFFFF6B35), Color(0xFFFF3D00)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: FitnessTargetsScreen(isDark: isDark))))),
          _buildExtraCardWidget(isDark, icon: Icons.photo_camera_rounded, title: 'Фотоотчёты', subtitle: '${provider.photos.length} фото',
              gradient: const [Color(0xFFFF9500), Color(0xFFFF5722)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: PhotoComparisonScreen(isDark: isDark))))),
          _buildWellbeingCardWidget(isDark, provider),
          _buildExtraCardWidget(isDark, icon: Icons.history_rounded, title: 'История программ',
              subtitle: '${provider.sessions.where((s) => s.status != ProgramSessionStatus.active).length} завершено',
              gradient: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: CompletedProgramsScreen(isDark: isDark))))),
          _buildExtraCardWidget(isDark, icon: Icons.trending_up_rounded, title: 'Детальный прогресс', subtitle: 'По упражнениям',
              gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgressScreen(isDark: isDark))))),
        ],
      ),
    );
  }

  Widget _buildExtraCardWidget(bool isDark, {required IconData icon, required String title, required String subtitle, required List<Color> gradient, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const Spacer(),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildWellbeingCardWidget(bool isDark, FitnessProvider provider) {
    final todayWellbeing = provider.getTodayWellbeing();
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: WellbeingScreen(isDark: isDark))));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF34C759), Color(0xFF28A745)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: const Color(0xFF34C759).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Icon(Icons.mood_rounded, color: Colors.white, size: 22),
            ),
            const Spacer(),
            Text('Самочувствие', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            if (todayWellbeing != null)
              Row(
                children: [
                  _buildMiniStat('⚡', '${todayWellbeing.energyLevel}'),
                  const SizedBox(width: 6),
                  _buildMiniStat('😴', '${todayWellbeing.sleepQuality}'),
                  const SizedBox(width: 6),
                  _buildMiniStat('🎯', '${todayWellbeing.motivationLevel}'),
                ],
              )
            else
              Text('Записать', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF34C759))),
      ],
    );
  }

  // ==================== ДИАЛОГ ДЕТАЛЕЙ ДНЯ ====================

  void _showDayDetails(BuildContext context, DateTime date, List<WorkoutLog> logs, bool isDark, FitnessProvider provider) {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('На ${_formatFullDate(date)} не было тренировок'),
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ));
      return;
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatFullDate(date), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                      Text('${logs.length} ${_getWorkoutsWord(logs.length)}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true, itemCount: logs.length,
                itemBuilder: (context, index) => _buildDayLogCard(isDark, logs[index], provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayLogCard(bool isDark, WorkoutLog log, FitnessProvider provider) {
    final isCompleted = log.status == WorkoutDayStatus.completed;
    final isSkipped = log.status == WorkoutDayStatus.skipped;
    final totalVolume = log.totalVolume ?? 0;
    final avgRpe = log.avgRpe;
    final duration = log.duration;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCompleted ? const Color(0xFF4CAF50).withOpacity(0.3) : isSkipped ? const Color(0xFFF44336).withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFF4CAF50).withOpacity(0.2) : isSkipped ? const Color(0xFFF44336).withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: Center(child: Icon(isCompleted ? Icons.check_rounded : isSkipped ? Icons.close_rounded : Icons.schedule_rounded,
                    color: isCompleted ? const Color(0xFF4CAF50) : isSkipped ? const Color(0xFFF44336) : Colors.grey, size: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isCompleted ? 'Тренировка выполнена' : isSkipped ? 'Пропущена' : 'Не завершена',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                    if (log.programId != null)
                      Text('День ${log.dayNumber ?? "?"} • ${log.exercisesLog.length} упр.', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFF4CAF50).withOpacity(0.15) : isSkipped ? const Color(0xFFF44336).withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(isCompleted ? '✅' : isSkipped ? '❌' : '⏳', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.2) : Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLogStat('🏋️', '${totalVolume.toStringAsFixed(0)}', 'кг', const Color(0xFFFF6B35), isDark),
                  Container(width: 1, height: 24, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                  _buildLogStat('💪', '${log.exercisesLog.length}', 'упр.', const Color(0xFF4A9BFF), isDark),
                  Container(width: 1, height: 24, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                  _buildLogStat('⏱️', duration != null ? '${duration.inMinutes}' : '—', 'мин', const Color(0xFF00C7BE), isDark),
                  if (avgRpe != null) ...[
                    Container(width: 1, height: 24, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                    _buildLogStat('📊', avgRpe.toStringAsFixed(1), 'RPE', const Color(0xFFFFCC00), isDark),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogStat(String emoji, String value, String label, Color color, bool isDark) {
    return Column(
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        ]),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.grey.shade500)),
      ],
    );
  }

  // ==================== HELPERS ====================

  bool _isSameDay(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  String _formatVolume(double volume) => volume >= 1000 ? '${(volume / 1000).toStringAsFixed(1)}k' : volume.toStringAsFixed(0);

  String _formatFullDate(DateTime date) {
    const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    const weekdays = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
    return '${weekdays[date.weekday % 7]}, ${date.day} ${months[date.month - 1]}';
  }

  String _getWorkoutsWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'тренировка';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'тренировки';
    return 'тренировок';
  }

  String _getDaysWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'день';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'дня';
    return 'дней';
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ДЛЯ СТАТИСТИКИ ПРОГРАММ ====================

  Map<String, int> _getProgramStats(WorkoutProgram program) {
    int completed = 0, pending = 0, skipped = 0;
    for (final day in program.days) {
      switch (day.status) {
        case WorkoutDayStatus.completed: completed++; break;
        case WorkoutDayStatus.pending: pending++; break;
        case WorkoutDayStatus.skipped: skipped++; break;
        default: break;
      }
    }
    return {'completed': completed, 'pending': pending, 'skipped': skipped};
  }

  Widget _buildProgramChip(String text, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: isActive ? Colors.white.withOpacity(0.25) : color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isActive ? Colors.white : color)),
    );
  }
}