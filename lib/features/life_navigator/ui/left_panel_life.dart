// features/life_navigator/ui/left_panel_life.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/life_models.dart';
import '../providers/life_provider.dart';
import 'widgets/calendar/calendar_widget.dart';
import 'widgets/tasks/tasks_widget.dart';
import 'widgets/habits/habits_widget.dart';
import 'widgets/notes/notes_widget.dart';
import 'widgets/ideas/ideas_widget.dart';
import 'widgets/stats/stats_widget.dart';
import '../../fitness/fitness_entry.dart';
import '../../fitness/providers/fitness_provider.dart';

// ==================== iOS-STYLE DESIGN SYSTEM ====================

class _IOS {
  // Фон
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color darkBg = Color(0xFF000000);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);

  // Акценты (iOS system colors)
  static const Color blue = Color(0xFF007AFF);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color purple = Color(0xFFAF52DE);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color indigo = Color(0xFF5856D6);
  static const Color pink = Color(0xFFFF2D55);
  static const Color red = Color(0xFFFF3B30);

  // Разделители
  static Color lightSep = Colors.black.withOpacity(0.06);
  static Color darkSep = Colors.white.withOpacity(0.08);

  static Color separator(bool isDark) => isDark ? darkSep : lightSep;
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color textPrimary(bool isDark) =>
      isDark ? Colors.white : Colors.black;
  static Color textSecondary(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF3C3C43).withOpacity(0.6);
  static Color textTertiary(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.3) : const Color(0xFF3C3C43).withOpacity(0.3);
}

// ==================== СОВРЕМЕННАЯ СЕТКА 2×N ====================

class LeftPanelLife extends StatefulWidget {
  final VoidCallback? onLockTap;
  const LeftPanelLife({super.key, this.onLockTap});

  @override
  State<LeftPanelLife> createState() => _LeftPanelLifeState();
}

class _LeftPanelLifeState extends State<LeftPanelLife>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderCollapsed = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LifeProvider>().init();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final collapsed =
        _scrollController.hasClients && _scrollController.offset > 60;
    if (collapsed != _isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = collapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<LifeProvider>();
    final fitness = context.watch<FitnessProvider>();
    final widgets =
    provider.widgets.where((w) => w.type != 'fitness').toList();
    final stats = provider.getStats();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _IOS.bg(isDark),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: provider.isLoading
            ? const Center(
          child: CircularProgressIndicator(color: _IOS.blue),
        )
            : Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ===== Header =====
                SliverToBoxAdapter(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _isHeaderCollapsed
                        ? const SizedBox(height: 0)
                        : _buildHeader(isDark, stats, provider),
                  ),
                ),

                // ===== Quick stats chips =====
                SliverToBoxAdapter(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _isHeaderCollapsed
                        ? const SizedBox(height: 0)
                        : _buildQuickStats(isDark, stats),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ===== Fitness hero =====
                SliverToBoxAdapter(
                  child: _buildFitnessHero(isDark, fitness),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ===== Section title =====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Виджеты',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: _IOS.textPrimary(isDark),
                          ),
                        ),
                        const Spacer(),
                        if (widgets.isNotEmpty)
                          Text(
                            '${widgets.length}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _IOS.textTertiary(isDark),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ===== Widget grid =====
                if (widgets.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState(isDark))
                else
                  SliverPadding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.88,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final widget = widgets[index];
                          return _buildWidgetCard(
                            widget,
                            isDark,
                            provider,
                            index,
                          );
                        },
                        childCount: widgets.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),

            // ===== Add FAB =====
            Positioned(
              bottom: 24,
              right: 20,
              child: _buildAddButton(isDark, provider),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER — iOS Large Title style
  // ============================================================

  Widget _buildHeader(
      bool isDark,
      Map<String, dynamic> stats,
      LifeProvider provider,
      ) {
    final now = DateTime.now();
    final weekdays = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];
    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final dateLine =
        '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя строка: дата + кнопки
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateLine.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: _IOS.textTertiary(isDark),
                    ),
                  ),
                ),
                _buildIconButton(
                  isDark: isDark,
                  icon: Icons.lock_outline_rounded,
                  onTap: widget.onLockTap ?? () {},
                ),
                const SizedBox(width: 8),
                _buildIconButton(
                  isDark: isDark,
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    provider.init();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Large Title
            Text(
              'Life Dashboard',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.9,
                height: 1.05,
                color: _IOS.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle
            Text(
              '${stats['totalEvents'] ?? 0} событий • ${stats['totalTasks'] ?? 0} задач • ${stats['totalHabits'] ?? 0} привычек',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: _IOS.textSecondary(isDark),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: _IOS.textSecondary(isDark),
        ),
      ),
    );
  }

  // ============================================================
  // QUICK STATS — iOS pill chips
  // ============================================================

  Widget _buildQuickStats(bool isDark, Map<String, dynamic> stats) {
    final items = <List<String>>[
      ['📋', '${stats['totalTasks'] ?? 0}', 'Задачи'],
      ['💡', '${stats['totalIdeas'] ?? 0}', 'Идеи'],
      ['💪', '${stats['totalHabits'] ?? 0}', 'Привычки'],
      ['📅', '${stats['totalEvents'] ?? 0}', 'События'],
    ];

    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _IOS.card(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _IOS.separator(isDark)),
            ),
            child: Row(
              children: [
                Text(item[0], style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item[1],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        letterSpacing: -0.2,
                        color: _IOS.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item[2],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1,
                        color: _IOS.textTertiary(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // FITNESS HERO — featured card
  // ============================================================

  Widget _buildFitnessHero(bool isDark, FitnessProvider fitness) {
    final stats = fitness.getStats();
    final activeSession = fitness.activeSession;
    final activeProgram = activeSession != null
        ? fitness.programs
        .where((p) => p.id == activeSession.programId)
        .toList()
        .firstOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _openFullscreenWidget(
            context,
            'fitness',
            isDark,
            context.read<LifeProvider>(),
          );
        },
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Фон
                Image.asset(
                  'assets/images/kachalka.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1A1D24),
                            Color(0xFF0F1115),
                            Color(0xFF2A1508),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.fitness_center_rounded,
                          size: 64,
                          color: _IOS.orange,
                        ),
                      ),
                    );
                  },
                ),

                // Затемнение
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),

                // Контент
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Верхняя строка
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              'FITNESS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if ((stats['currentStreak'] ?? 0) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${stats['currentStreak']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const Spacer(),

                      // Заголовок
                      const Text(
                        'Качалка',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Неоновая сила начинается здесь ⚡',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Стат-чипы
                      Row(
                        children: [
                          _buildHeroChip(
                            icon: Icons.local_fire_department_rounded,
                            value: '${stats['workoutsThisWeek'] ?? 0}',
                            label: 'на неделе',
                          ),
                          const SizedBox(width: 8),
                          _buildHeroChip(
                            icon: Icons.fitness_center_rounded,
                            value: '${stats['totalWorkouts'] ?? 0}',
                            label: 'всего',
                          ),
                          const Spacer(),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),

                      // Прогресс активной программы
                      if (activeSession != null && activeProgram != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activeProgram.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(activeSession.progressPercent * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: activeSession.progressPercent,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}k';
    }
    return volume.toStringAsFixed(0);
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: _IOS.card(isDark),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _IOS.separator(isDark)),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _IOS.blue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.widgets_rounded,
                size: 28,
                color: _IOS.blue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет виджетов',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: _IOS.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Нажмите + чтобы добавить',
              style: TextStyle(
                fontSize: 14,
                color: _IOS.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ADD BUTTON — iOS FAB
  // ============================================================

  Widget _buildAddButton(bool isDark, LifeProvider provider) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showAddWidgetDialog(context, isDark, provider);
      },
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_IOS.blue, Color(0xFF0051D5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _IOS.blue.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  // ============================================================
  // WIDGET CARD — iOS style
  // ============================================================

  Widget _buildWidgetCard(
      LifeWidget widget,
      bool isDark,
      LifeProvider provider,
      int index,
      ) {
    final config = _getWidgetConfig(widget.type);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openFullscreenWidget(
          context,
          widget.type,
          isDark,
          provider,
        );
      },
      child: Container(
        key: Key(widget.id),
        decoration: BoxDecoration(
          color: _IOS.card(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _IOS.separator(isDark)),
        ),
        child: Stack(
          children: [
            // Основное содержимое
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Иконка в квадрате
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: config.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        config.icon,
                        color: config.color,
                        size: 22,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Название
                  Text(
                    config.label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      height: 1.1,
                      color: _IOS.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Подпись + chevron
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          config.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _IOS.textSecondary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: _IOS.textTertiary(isDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Меню (drag + delete) — появляется поверх в верхнем правом
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  // Удаление
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _confirmRemoveWidget(context, widget, provider);
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: _IOS.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Drag handle (визуальный)
            Positioned(
              top: 12,
              right: 44,
              child: ReorderableDragStartListener(
                index: index,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 14,
                    color: _IOS.textTertiary(isDark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WIDGET CONFIG
  // ============================================================

  _WidgetConfig _getWidgetConfig(String type) {
    switch (type) {
      case 'calendar':
        return const _WidgetConfig(
          icon: Icons.calendar_month_rounded,
          color: _IOS.blue,
          label: 'Календарь',
          subtitle: 'События и встречи',
        );
      case 'tasks':
        return const _WidgetConfig(
          icon: Icons.checklist_rounded,
          color: _IOS.green,
          label: 'Задачи',
          subtitle: 'To-do список',
        );
      case 'habits':
        return const _WidgetConfig(
          icon: Icons.fitness_center_rounded,
          color: _IOS.orange,
          label: 'Привычки',
          subtitle: 'Ежедневные ритуалы',
        );
      case 'notes':
        return const _WidgetConfig(
          icon: Icons.note_rounded,
          color: _IOS.yellow,
          label: 'Заметки',
          subtitle: 'Быстрые записи',
        );
      case 'ideas':
        return const _WidgetConfig(
          icon: Icons.lightbulb_rounded,
          color: _IOS.purple,
          label: 'Идеи',
          subtitle: 'Мозговой штурм',
        );
      case 'stats':
        return const _WidgetConfig(
          icon: Icons.analytics_rounded,
          color: _IOS.teal,
          label: 'Статистика',
          subtitle: 'Аналитика',
        );
      case 'inbox':
        return const _WidgetConfig(
          icon: Icons.inbox_rounded,
          color: Color(0xFF8E8E93),
          label: 'Входящие',
          subtitle: 'Новые',
        );
      default:
        return _WidgetConfig(
          icon: Icons.widgets_rounded,
          color: const Color(0xFF8E8E93),
          label: type,
          subtitle: 'Виджет',
        );
    }
  }

  // ============================================================
  // DIALOGS
  // ============================================================

  void _confirmRemoveWidget(
      BuildContext context,
      LifeWidget widget,
      LifeProvider provider,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 60),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
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
                      'Удалить виджет?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _IOS.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '«${_getWidgetConfig(widget.type).label}» будет удалён',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _IOS.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 0.5, color: _IOS.separator(isDark)),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: Text(
                          'Отмена',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            color: _IOS.blue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 0.5,
                    height: 50,
                    color: _IOS.separator(isDark),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        provider.removeWidget(widget.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: const Text(
                          'Удалить',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _IOS.red,
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
  }

  // ============================================================
  // OPEN FULLSCREEN
  // ============================================================

  void _openFullscreenWidget(
      BuildContext context,
      String type,
      bool isDark,
      LifeProvider provider,
      ) {
    Widget screen;
    switch (type) {
      case 'calendar':
        screen = CalendarWidget(isDark: isDark, isCompact: false);
        break;
      case 'tasks':
        screen = TasksWidget(isDark: isDark, isCompact: false);
        break;
      case 'habits':
        screen = HabitsWidget(isDark: isDark, isCompact: false);
        break;
      case 'notes':
        screen = NotesWidget(isDark: isDark, isCompact: false);
        break;
      case 'ideas':
        screen = IdeasWidget(isDark: isDark, isCompact: false);
        break;
      case 'stats':
        screen = StatsWidget(isDark: isDark, isCompact: false);
        break;
      case 'inbox':
        screen = Container(
          color: _IOS.bg(isDark),
          child: Center(
            child: Text(
              'Входящие в разработке',
              style: TextStyle(color: _IOS.textSecondary(isDark)),
            ),
          ),
        );
        break;
      case 'fitness':
        screen = FitnessEntry(isDark: isDark);
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: Scaffold(
            backgroundColor: _IOS.bg(isDark),
            body: screen,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADD WIDGET DIALOG — iOS sheet
  // ============================================================

  void _showAddWidgetDialog(
      BuildContext context,
      bool isDark,
      LifeProvider provider,
      ) {
    final widgetTypes = [
      _WidgetType('calendar', Icons.calendar_month_rounded, 'Календарь',
          'События', _IOS.blue),
      _WidgetType(
          'tasks', Icons.checklist_rounded, 'Задачи', 'To-do', _IOS.green),
      _WidgetType('habits', Icons.fitness_center_rounded, 'Привычки',
          'Ритуалы', _IOS.orange),
      _WidgetType(
          'notes', Icons.note_rounded, 'Заметки', 'Записи', _IOS.yellow),
      _WidgetType('ideas', Icons.lightbulb_rounded, 'Идеи', 'Мысли',
          _IOS.purple),
      _WidgetType(
          'stats', Icons.analytics_rounded, 'Статистика', 'Данные', _IOS.teal),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? _IOS.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Добавить виджет',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: _IOS.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Выберите тип виджета',
                style: TextStyle(
                  fontSize: 14,
                  color: _IOS.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 20),

              // Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.5,
                ),
                itemCount: widgetTypes.length,
                itemBuilder: (_, i) {
                  final wt = widgetTypes[i];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(ctx);
                      provider.addWidget(wt.type);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: wt.color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: wt.color.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(wt.icon, color: wt.color, size: 22),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            wt.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: _IOS.textPrimary(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            wt.subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: _IOS.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Cancel
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Отмена',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _IOS.textPrimary(isDark),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ КЛАССЫ ====================

class _WidgetConfig {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;

  const _WidgetConfig({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
  });
}

class _WidgetType {
  final String type, label, subtitle;
  final IconData icon;
  final Color color;
  const _WidgetType(
      this.type,
      this.icon,
      this.label,
      this.subtitle,
      this.color,
      );
}