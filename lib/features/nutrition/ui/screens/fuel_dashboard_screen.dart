import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/nutrition_models.dart';
import '../../providers/nutrition_provider.dart';
import 'add_food_screen.dart';
import 'profile_setup_screen.dart';
import 'dart:math' as math;

class FuelDashboardScreen extends StatefulWidget {
  final bool isDark;
  const FuelDashboardScreen({super.key, this.isDark = true});

  @override
  State<FuelDashboardScreen> createState() => _FuelDashboardScreenState();
}

class _FuelDashboardScreenState extends State<FuelDashboardScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _showTemplatesGrid = false;
  String _templatesSearchQuery = '';
  TemplatesSortMode _templatesSortMode = TemplatesSortMode.name;

  static const bgDark = Color(0xFF0A0E1A);
  static const surface = Color(0xFF141A2E);
  static const surfaceLight = Color(0xFF1A2140);
  static const cardBg = Color(0xFF1E2745);
  static const cyan = Color(0xFF00D4FF);
  static const green = Color(0xFF00FF9D);
  static const pink = Color(0xFFFF2D55);
  static const yellow = Color(0xFFFFD60A);
  static const orange = Color(0xFFFF9500);
  static const purple = Color(0xFF9B59B6);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NutritionProvider>();
    final summary = provider.getSummaryForDate(_selectedDate);
    final goals = provider.getGoalsForDate(_selectedDate);
    final entries = provider.getEntriesForDate(_selectedDate);
    final recommendations = provider.getRecommendations(_selectedDate);
    final meals = _groupEntriesByMeal(entries);
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final hasProfile = provider.userProfile != null;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isToday, hasProfile),
            SliverToBoxAdapter(child: _buildDateSelector(provider)),
            SliverToBoxAdapter(child: _buildUnifiedStats(summary, goals, hasProfile)),
            SliverToBoxAdapter(child: _buildMacrosCards(summary, goals)),
            SliverToBoxAdapter(child: _buildWaterTracker(provider, goals)),
            if (recommendations.isNotEmpty)
              SliverToBoxAdapter(child: _buildRecommendations(recommendations)),
            SliverToBoxAdapter(child: _buildMealsSection(provider, meals, summary)),
            SliverToBoxAdapter(
              child: _buildTemplatesSection(provider),
            ),
            SliverToBoxAdapter(child: _buildRecentQuickAdd(provider)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cyan,
        foregroundColor: bgDark,
        onPressed: () => _openAddFood(context, provider),
        icon: const Icon(Icons.add_rounded, size: 28),
        label: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      ),
    );
  }

  Map<MealType, List<FoodDiaryEntry>> _groupEntriesByMeal(List<FoodDiaryEntry> entries) {
    final map = <MealType, List<FoodDiaryEntry>>{};
    for (final meal in MealType.values) {
      map[meal] = entries.where((e) => e.mealType == meal).toList();
    }
    return map;
  }

  // ==================== APP BAR ====================

  Widget _buildAppBar(bool isToday, bool hasProfile) {
    return SliverAppBar(
      backgroundColor: bgDark,
      floating: true,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [cyan, green]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: cyan.withOpacity(0.4), blurRadius: 12)],
            ),
            child: const Icon(Icons.bolt_rounded, color: bgDark, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Питание',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
        ],
      ),
      actions: [
        IconButton(
          icon: Stack(
            children: [
              Icon(
                hasProfile ? Icons.person_rounded : Icons.person_outline_rounded,
                color: hasProfile ? green : Colors.white,
              ),
              if (!hasProfile)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => _openProfileSetup(context),
          tooltip: hasProfile ? 'Профиль' : 'Настроить профиль',
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
          onPressed: () => _showGoalsEditor(context),
        ),
      ],
    );
  }

  // ==================== DATE SELECTOR ====================

  Widget _buildDateSelector(NutritionProvider provider) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _buildNavButton(
            icon: Icons.chevron_left,
            onPressed: () => setState(() =>
            _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [surface, surfaceLight],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cyan.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: cyan.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: cyan, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      _formatDateFull(_selectedDate).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: green.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'СЕЙЧАС',
                          style: TextStyle(
                            color: green,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _buildNavButton(
            icon: Icons.chevron_right,
            onPressed: isToday ? null : () => setState(() =>
            _selectedDate = _selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: surface,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: IconButton(
        icon: Icon(icon, color: onPressed != null ? Colors.white : Colors.white24),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: 24,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
    );
  }

  // ==================== ОБЪЕДИНЁННЫЙ БЛОК СТАТИСТИКИ + FUEL GAUGE ====================

  Widget _buildUnifiedStats(DailyNutritionSummary s, NutritionGoals g, bool hasProfile) {
    final percent = s.percentOf(g);
    final remaining = (g.calories - s.calories).round();
    final isOver = s.calories > g.calories;
    final color = isOver ? pink : (percent >= 0.9 ? green : cyan);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [surface, surfaceLight],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'КАЛОРИИ',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${s.calories.round()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/ ${g.calories.round()}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${(percent * 100).round()}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            isOver ? 'ПЕРЕБОР' : 'ВЫПОЛНЕНО',
                            style: TextStyle(
                              color: color.withOpacity(0.7),
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isOver ? pink : green).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isOver ? pink : green).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOver ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                            color: isOver ? pink : green,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOver ? '+${-remaining}' : '$remaining',
                            style: TextStyle(
                              color: isOver ? pink : green,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.5), color],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statItem('🥩 Белки', '${s.protein.round()} г', green),
                _statItem('🧈 Жиры', '${s.fat.round()} г', pink),
                _statItem('🍞 Углеводы', '${s.carbs.round()} г', yellow),
                _statItem('💧 Вода', '${s.waterMl} мл', cyan),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CustomPaint(
                    painter: _SmallFuelGaugePainter(
                      percent: percent,
                      color: color,
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                    child: Center(
                      child: Text(
                        '${s.calories.round()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FUEL GAUGE',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOver
                            ? '🔥 Перебор ${(percent * 100).round()}%'
                            : '✅ ${(percent * 100).round()}% от цели',
                        style: TextStyle(
                          color: isOver ? pink : green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Записей: ${s.entriesCount}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (hasProfile)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: green.withOpacity(0.2)),
                              ),
                              child: const Text(
                                '🎯 ПРОФИЛЬ',
                                style: TextStyle(
                                  color: green,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
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
      ),
    );
  }

  // ==================== MACROS CARDS ====================

  Widget _buildMacrosCards(DailyNutritionSummary s, NutritionGoals g) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildMacroCard(
              label: 'БЕЛКИ',
              current: s.protein,
              goal: g.protein,
              color: green,
              emoji: '🥩',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMacroCard(
              label: 'ЖИРЫ',
              current: s.fat,
              goal: g.fat,
              color: pink,
              emoji: '🧈',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMacroCard(
              label: 'УГЛЕВ.',
              current: s.carbs,
              goal: g.carbs,
              color: yellow,
              emoji: '🍞',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard({
    required String label,
    required double current,
    required double goal,
    required Color color,
    required String emoji,
  }) {
    final percent = goal > 0 ? (current / goal).clamp(0.0, 1.5) : 0.0;
    final isOver = current > goal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              Text(
                '${(percent * 100).round()}%',
                style: TextStyle(
                  color: isOver ? pink : color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 4,
            child: Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isOver ? pink : color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${current.round()}',
            style: TextStyle(
              color: isOver ? pink : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '/ ${goal.round()} г',
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

  // ==================== WATER TRACKER ====================

  Widget _buildWaterTracker(NutritionProvider provider, NutritionGoals goals) {
    final currentMl = provider.getWaterForDate(_selectedDate);
    final percent = (currentMl / goals.waterMl).clamp(0.0, 1.5);
    final presets = [200, 250, 330, 500];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [surface, surfaceLight],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cyan.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💧', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                const Text(
                  'ВОДА',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: cyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cyan.withOpacity(0.2)),
                  ),
                  child: Text(
                    '$currentMl / ${goals.waterMl} мл',
                    style: const TextStyle(
                      color: cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [cyan, green]),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [BoxShadow(color: cyan.withOpacity(0.3), blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: presets.map((ml) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () async => await provider.addWater(ml, date: _selectedDate),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: cyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cyan.withOpacity(0.2)),
                      ),
                      child: Text(
                        '+$ml',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== RECOMMENDATIONS ====================

  Widget _buildRecommendations(List<NutritionRecommendation> recs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              const Text(
                'СОВЕТЫ ПО ПИТАНИЮ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recs.take(3).map((r) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [surface, surfaceLight],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: r.color.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: r.color.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: r.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: r.color.withOpacity(0.2)),
                  ),
                  child: Text(r.emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: TextStyle(
                          color: r.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ==================== MEALS SECTION ====================

  Widget _buildMealsSection(
      NutritionProvider provider,
      Map<MealType, List<FoodDiaryEntry>> meals,
      DailyNutritionSummary summary,
      ) {
    final mealTypes = MealType.values;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(
                'ПРИЁМЫ ПИЩИ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cyan.withOpacity(0.2)),
                ),
                child: Text(
                  '${summary.entriesCount} записей',
                  style: const TextStyle(
                    color: cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...mealTypes.map((meal) => _buildMealCard(
            provider,
            meal,
            meals[meal] ?? [],
          )),
        ],
      ),
    );
  }

  Widget _buildMealCard(
      NutritionProvider provider,
      MealType meal,
      List<FoodDiaryEntry> entries,
      ) {
    final kcal = entries.fold(0.0, (s, e) => s + e.calories);
    final protein = entries.fold(0.0, (s, e) => s + e.protein);
    final fat = entries.fold(0.0, (s, e) => s + e.fat);
    final carbs = entries.fold(0.0, (s, e) => s + e.carbs);
    final isEmpty = entries.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(meal.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                meal.displayName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (!isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cyan.withOpacity(0.15)),
                  ),
                  child: Text(
                    '${kcal.round()} ккал',
                    style: const TextStyle(
                      color: cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (!isEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _microBadge('Б', protein.toStringAsFixed(1), green),
                const SizedBox(width: 6),
                _microBadge('Ж', fat.toStringAsFixed(1), pink),
                const SizedBox(width: 6),
                _microBadge('У', carbs.toStringAsFixed(1), yellow),
                const Spacer(),
                Text(
                  '${entries.length} продукта',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...entries.map((e) => _buildEntryRow(provider, e)),
          ],
          Padding(
            padding: EdgeInsets.only(top: isEmpty ? 12 : 8),
            child: InkWell(
              onTap: () => _openAddFood(context, provider, meal: meal),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: cyan.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      color: cyan,
                      size: isEmpty ? 20 : 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEmpty ? 'Добавить продукты' : 'Добавить ещё',
                      style: TextStyle(
                        color: cyan,
                        fontSize: isEmpty ? 13 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _microBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEntryRow(NutritionProvider provider, FoodDiaryEntry e) {
    return Dismissible(
      key: Key(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: pink.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: pink, size: 20),
      ),
      onDismissed: (_) => provider.removeEntry(e.id),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Text(
                _findProduct(provider, e.productId)?.categoryEmoji ?? '🍽️',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                e.productName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            // БЖУ справа от названия (перед калориями)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${e.grams.round()}г',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Б:${e.protein.round()}',
                    style: TextStyle(
                      color: green,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: pink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ж:${e.fat.round()}',
                    style: TextStyle(
                      color: pink,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: yellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'У:${e.carbs.round()}',
                    style: TextStyle(
                      color: yellow,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              '${e.calories.round()}',
              style: const TextStyle(
                color: cyan,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  FoodProduct? _findProduct(NutritionProvider provider, String id) {
    try {
      return provider.products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ==================== TEMPLATES SECTION ====================

  Widget _buildTemplatesSection(NutritionProvider provider) {
    final templates = provider.templates;
    if (templates.isEmpty) return const SizedBox.shrink();

    var filteredTemplates = List<MealTemplate>.from(templates);
    if (_templatesSearchQuery.isNotEmpty) {
      final query = _templatesSearchQuery.toLowerCase();
      filteredTemplates = filteredTemplates
          .where((t) => t.name.toLowerCase().contains(query))
          .toList();
    }

    switch (_templatesSortMode) {
      case TemplatesSortMode.name:
        filteredTemplates.sort((a, b) => a.name.compareTo(b.name));
        break;
      case TemplatesSortMode.caloriesDesc:
        filteredTemplates.sort((a, b) {
          final aCal = _getTemplateCalories(provider, a);
          final bCal = _getTemplateCalories(provider, b);
          return bCal.compareTo(aCal);
        });
        break;
      case TemplatesSortMode.caloriesAsc:
        filteredTemplates.sort((a, b) {
          final aCal = _getTemplateCalories(provider, a);
          final bCal = _getTemplateCalories(provider, b);
          return aCal.compareTo(bCal);
        });
        break;
      case TemplatesSortMode.proteinDesc:
        filteredTemplates.sort((a, b) {
          final aProtein = _getTemplateProtein(provider, a);
          final bProtein = _getTemplateProtein(provider, b);
          return bProtein.compareTo(aProtein);
        });
        break;
      case TemplatesSortMode.fatDesc:
        filteredTemplates.sort((a, b) {
          final aFat = _getTemplateFat(provider, a);
          final bFat = _getTemplateFat(provider, b);
          return bFat.compareTo(aFat);
        });
        break;
      case TemplatesSortMode.carbsDesc:
        filteredTemplates.sort((a, b) {
          final aCarbs = _getTemplateCarbs(provider, a);
          final bCarbs = _getTemplateCarbs(provider, b);
          return bCarbs.compareTo(aCarbs);
        });
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cyan.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🍱', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                const Text(
                  'ГОТОВЫЕ БЛЮДА',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${filteredTemplates.length}',
                    style: const TextStyle(
                      color: cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Современный поиск
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cyan.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: cyan.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        Icon(
                          Icons.search_rounded,
                          color: cyan.withOpacity(0.6),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (value) => setState(() => _templatesSearchQuery = value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Поиск готовых блюд...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (_templatesSearchQuery.isNotEmpty)
                          InkWell(
                            onTap: () => setState(() => _templatesSearchQuery = ''),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withOpacity(0.4),
                                size: 18,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Кнопка сортировки
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cyan.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: cyan.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: PopupMenuButton<TemplatesSortMode>(
                    offset: const Offset(0, 48),
                    position: PopupMenuPosition.under,
                    child: Row(
                      children: [
                        Icon(
                          _getSortIcon(),
                          color: cyan,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getSortLabel(),
                          style: TextStyle(
                            color: cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: cyan,
                          size: 20,
                        ),
                      ],
                    ),
                    onSelected: (mode) => setState(() => _templatesSortMode = mode),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: TemplatesSortMode.name,
                        child: Row(
                          children: [Text('📝 По названию')],
                        ),
                      ),
                      const PopupMenuItem(
                        value: TemplatesSortMode.caloriesDesc,
                        child: Row(
                          children: [Text('🔥 Калории ↓')],
                        ),
                      ),
                      const PopupMenuItem(
                        value: TemplatesSortMode.caloriesAsc,
                        child: Row(
                          children: [Text('🔥 Калории ↑')],
                        ),
                      ),
                      const PopupMenuItem(
                        value: TemplatesSortMode.proteinDesc,
                        child: Row(
                          children: [Text('🥩 Белок ↓')],
                        ),
                      ),
                      const PopupMenuItem(
                        value: TemplatesSortMode.fatDesc,
                        child: Row(
                          children: [Text('🧈 Жиры ↓')],
                        ),
                      ),
                      const PopupMenuItem(
                        value: TemplatesSortMode.carbsDesc,
                        child: Row(
                          children: [Text('🍞 Углеводы ↓')],
                        ),
                      ),
                    ],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Переключение режима отображения
            Row(
              children: [
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      _buildToggleButton(
                        icon: Icons.view_list_rounded,
                        isActive: !_showTemplatesGrid,
                        onTap: () => setState(() => _showTemplatesGrid = false),
                      ),
                      _buildToggleButton(
                        icon: Icons.grid_view_rounded,
                        isActive: _showTemplatesGrid,
                        onTap: () => setState(() => _showTemplatesGrid = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Список блюд
            if (filteredTemplates.isEmpty)
              _buildEmptyTemplates()
            else if (_showTemplatesGrid)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                ),
                itemCount: filteredTemplates.length,
                itemBuilder: (ctx, i) => _buildTemplateCard(provider, filteredTemplates[i]),
              )
            else
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredTemplates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) => _buildTemplateChip(provider, filteredTemplates[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? cyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: isActive ? cyan : Colors.white38,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildEmptyTemplates() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          const Text(
            'Ничего не найдено',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ДЛЯ ТЕМПЛЕЙТОВ ====================

  double _getTemplateCalories(NutritionProvider provider, MealTemplate t) {
    return t.items.fold(0.0, (sum, item) {
      final product = _findProduct(provider, item.productId);
      if (product != null) {
        return sum + product.forGrams(item.grams).calories;
      }
      return sum;
    });
  }

  double _getTemplateProtein(NutritionProvider provider, MealTemplate t) {
    return t.items.fold(0.0, (sum, item) {
      final product = _findProduct(provider, item.productId);
      if (product != null) {
        return sum + product.forGrams(item.grams).protein;
      }
      return sum;
    });
  }

  double _getTemplateFat(NutritionProvider provider, MealTemplate t) {
    return t.items.fold(0.0, (sum, item) {
      final product = _findProduct(provider, item.productId);
      if (product != null) {
        return sum + product.forGrams(item.grams).fat;
      }
      return sum;
    });
  }

  double _getTemplateCarbs(NutritionProvider provider, MealTemplate t) {
    return t.items.fold(0.0, (sum, item) {
      final product = _findProduct(provider, item.productId);
      if (product != null) {
        return sum + product.forGrams(item.grams).carbs;
      }
      return sum;
    });
  }

  IconData _getSortIcon() {
    switch (_templatesSortMode) {
      case TemplatesSortMode.name:
        return Icons.sort_by_alpha;
      case TemplatesSortMode.caloriesDesc:
        return Icons.arrow_downward;
      case TemplatesSortMode.caloriesAsc:
        return Icons.arrow_upward;
      case TemplatesSortMode.proteinDesc:
        return Icons.fitness_center;
      case TemplatesSortMode.fatDesc:
        return Icons.egg;
      case TemplatesSortMode.carbsDesc:
        return Icons.grain;
    }
  }

  String _getSortLabel() {
    switch (_templatesSortMode) {
      case TemplatesSortMode.name:
        return 'А-Я';
      case TemplatesSortMode.caloriesDesc:
        return '🔥↑';
      case TemplatesSortMode.caloriesAsc:
        return '🔥↓';
      case TemplatesSortMode.proteinDesc:
        return '🥩↑';
      case TemplatesSortMode.fatDesc:
        return '🧈↑';
      case TemplatesSortMode.carbsDesc:
        return '🍞↑';
    }
  }

  // ==================== ОСТАЛЬНЫЕ МЕТОДЫ ДЛЯ ТЕМПЛЕЙТОВ ====================

  Widget _buildTemplateChip(NutritionProvider provider, MealTemplate t) {
    final totalCal = _getTemplateCalories(provider, t);

    return InkWell(
      onTap: () => _showTemplateDetails(provider, t),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cyan.withOpacity(0.1), green.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cyan.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Text('🍱', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${t.items.length} ингр. • ${totalCal.round()} ккал',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(NutritionProvider provider, MealTemplate t) {
    final totalCal = _getTemplateCalories(provider, t);
    final totalProtein = _getTemplateProtein(provider, t);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surface, surfaceLight],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cyan.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: cyan.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showTemplateDetails(provider, t),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('🍱', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _templateMiniStat('🔥', '${totalCal.round()}', 'ккал', cyan),
                  const SizedBox(width: 6),
                  _templateMiniStat('🥩', totalProtein.toStringAsFixed(0), 'г', green),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${t.items.length}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
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
  }

  Widget _templateMiniStat(String emoji, String value, String label, Color color) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 7,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==================== TEMPLATE DETAILS ====================

  void _showTemplateDetails(NutritionProvider provider, MealTemplate t) {
    final totalCal = _getTemplateCalories(provider, t);
    final totalProtein = _getTemplateProtein(provider, t);
    final totalFat = _getTemplateFat(provider, t);
    final totalCarbs = _getTemplateCarbs(provider, t);

    MealType selectedMeal = MealType.suggestForNow();

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (_, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('🍱', style: TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${t.items.length} ингредиентов',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        _templateMacro('🔥', '${totalCal.round()}', 'ккал', cyan),
                        _templateMacro('🥩', totalProtein.toStringAsFixed(1), 'г', green),
                        _templateMacro('🧈', totalFat.toStringAsFixed(1), 'г', pink),
                        _templateMacro('🍞', totalCarbs.toStringAsFixed(1), 'г', yellow),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ИНГРЕДИЕНТЫ',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...t.items.map((item) {
                    final product = _findProduct(provider, item.productId);
                    final macros = product != null
                        ? product.forGrams(item.grams)
                        : (calories: 0.0, protein: 0.0, fat: 0.0, carbs: 0.0);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            product?.categoryEmoji ?? '🍽️',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${item.grams.round()} г',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${macros.calories.round()}',
                            style: TextStyle(
                              color: cyan,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text(
                    'ДОБАВИТЬ КАК:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: MealType.values.map((m) => ChoiceChip(
                      label: Text(
                        '${m.emoji} ${m.displayName}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: selectedMeal == m,
                      selectedColor: cyan.withOpacity(0.3),
                      backgroundColor: Colors.transparent,
                      labelStyle: TextStyle(
                        color: selectedMeal == m ? Colors.white : Colors.white54,
                      ),
                      onSelected: (_) => setState(() => selectedMeal = m),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await provider.addTemplateAsMeal(
                          t,
                          selectedMeal,
                          date: _selectedDate,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${t.name} добавлен!'),
                            backgroundColor: green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 22),
                      label: const Text(
                        'ДОБАВИТЬ В ДНЕВНИК',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cyan,
                        foregroundColor: bgDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _templateMacro(String emoji, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            unit,
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

  // ==================== QUICK ADD ====================

  Widget _buildRecentQuickAdd(NutritionProvider provider) {
    final recent = provider.getRecentProducts(limit: 5);

    if (recent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              const Text(
                'БЫСТРЫЙ ВВОД',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) => _buildQuickChip(provider, recent[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(NutritionProvider provider, FoodProduct p) {
    return InkWell(
      onTap: () => _openAddFood(context, provider, preselected: p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cyan.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(p.categoryEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${p.calories.round()} ккал',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPERS ====================

  void _openAddFood(
      BuildContext context,
      NutritionProvider provider, {
        MealType? meal,
        FoodProduct? preselected,
      }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodScreen(
          isDark: widget.isDark,
          date: _selectedDate,
          initialMeal: meal,
          preselectedProduct: preselected,
          nutritionProvider: provider,
        ),
      ),
    );
  }

  void _openProfileSetup(BuildContext context) {
    final provider = context.read<NutritionProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(
          isDark: widget.isDark,
          provider: provider,
        ),
      ),
    );
  }

  void _showGoalsEditor(BuildContext context) {
    final provider = context.read<NutritionProvider>();
    final goals = provider.getGoalsForDate(_selectedDate);
    final calC = TextEditingController(text: goals.calories.toStringAsFixed(0));
    final pC = TextEditingController(text: goals.protein.toStringAsFixed(0));
    final fC = TextEditingController(text: goals.fat.toStringAsFixed(0));
    final cC = TextEditingController(text: goals.carbs.toStringAsFixed(0));
    final wC = TextEditingController(text: goals.waterMl.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            const Text(
              'ЦЕЛИ НА ДЕНЬ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGoalsField('🔥 Калории (ккал)', calC),
              const SizedBox(height: 8),
              _buildGoalsField('🥩 Белки (г)', pC),
              const SizedBox(height: 8),
              _buildGoalsField('🧈 Жиры (г)', fC),
              const SizedBox(height: 8),
              _buildGoalsField('🍞 Углеводы (г)', cC),
              const SizedBox(height: 8),
              _buildGoalsField('💧 Вода (мл)', wC),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newGoals = NutritionGoals(
                id: goals.id,
                date: goals.date,
                calories: double.tryParse(calC.text) ?? goals.calories,
                protein: double.tryParse(pC.text) ?? goals.protein,
                fat: double.tryParse(fC.text) ?? goals.fat,
                carbs: double.tryParse(cC.text) ?? goals.carbs,
                waterMl: int.tryParse(wC.text) ?? goals.waterMl,
              );
              Navigator.pop(ctx);
              await provider.updateGoals(newGoals);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Цели обновлены! 🎯'),
                  backgroundColor: green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cyan,
              foregroundColor: bgDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsField(String label, TextEditingController c) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
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

  String _formatDateFull(DateTime d) {
    const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}

// ==================== ENUM ДЛЯ СОРТИРОВКИ ====================

enum TemplatesSortMode {
  name,
  caloriesDesc,
  caloriesAsc,
  proteinDesc,
  fatDesc,
  carbsDesc,
}

// ==================== CUSTOM PAINTERS ====================

class _FuelGaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color backgroundColor;

  _FuelGaugePainter({required this.percent, required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    final progressPaint = Paint()
      ..shader = SweepGradient(colors: [color.withOpacity(0.3), color])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweep = math.pi * 1.5 * percent.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -math.pi * 0.75,
      sweep,
      false,
      progressPaint,
    );

    if (percent > 0 && percent < 1) {
      final angle = -math.pi * 0.75 + sweep;
      final dotCenter = Offset(
        center.dx + (radius - 6) * math.cos(angle),
        center.dy + (radius - 6) * math.sin(angle),
      );
      canvas.drawCircle(dotCenter, 4, Paint()..color = color);
      canvas.drawCircle(
        dotCenter,
        10,
        Paint()
          ..color = color.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FuelGaugePainter old) => old.percent != percent;
}

class _SmallFuelGaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color backgroundColor;

  _SmallFuelGaugePainter({required this.percent, required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweep = math.pi * 1.5 * percent.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi * 0.75,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SmallFuelGaugePainter old) => old.percent != percent;
}