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
    final collapsed = _scrollController.hasClients && _scrollController.offset > 60;
    if (collapsed != _isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = collapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<LifeProvider>();
    // 🔥 Фитнес-провайдер для баннера
    final fitness = context.watch<FitnessProvider>();
    // Исключаем фитнес из сетки — теперь он сверху отдельным баннером
    final widgets = provider.widgets.where((w) => w.type != 'fitness').toList();
    final stats = provider.getStats();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: _isHeaderCollapsed
                        ? const SizedBox(height: 12)
                        : Column(
                      children: [
                        _buildHeader(isDark, stats, provider),
                        const SizedBox(height: 8),
                        _buildQuickStats(isDark, stats),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                // 🔥 НОВОЕ: Фитнес-баннер во всю ширину сверху
                SliverToBoxAdapter(
                  child: _buildFitnessHero(isDark, fitness),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (widgets.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState(isDark))
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
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
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            // Кнопка добавления
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: _buildAddButton(isDark, provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 🔥 ФИТНЕС-БАННЕР (HERO) ====================

  Widget _buildFitnessHero(bool isDark, FitnessProvider fitness) {
    final stats = fitness.getStats();
    final activeSession = fitness.activeSession;
    final activeProgram = activeSession != null
        ? fitness.programs
        .where((p) => p.id == activeSession.programId)
        .toList()
        .firstOrNull
        : null;

    return GestureDetector(
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
        height: 220,
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🖼️ Фоновое изображение зала (с фолбэком)
              Image.asset(
                'assets/images/kachalka.jpeg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
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
                        size: 72,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  );
                },
              ),
              // Затемнение для читаемости текста
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.92),
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.15),
                    ],
                  ),
                ),
              ),
              // Неоновая полоса сверху (в стиле зала)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF00E5FF),
                        Color(0xFFFF2E9A),
                        Color(0xFFFF6B35),
                        Color(0xFFB4FF39),
                      ],
                    ),
                  ),
                ),
              ),
              // Контент
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Верхняя строка: GYM + стрик
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B35).withOpacity(0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fitness_center_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'GYM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if ((stats['currentStreak'] ?? 0) > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  '${stats['currentStreak']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Неоновая сила начинается здесь ⚡',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Активная программа или статистика
                    if (activeSession != null && activeProgram != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '🎯 ${activeProgram.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(activeSession.progressPercent * 100).toInt()}%',
                            style: const TextStyle(
                              color: Color(0xFFFF6B35),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: activeSession.progressPercent,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF6B35),
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Статистика (стеклянные чипы)
                    Row(
                      children: [
                        _buildHeroStatChip(
                          '💪',
                          '${stats['workoutsThisWeek'] ?? 0}',
                          'на неделе',
                        ),
                        const SizedBox(width: 8),
                        _buildHeroStatChip(
                          '🏋️',
                          '${stats['totalWorkouts'] ?? 0}',
                          'всего',
                        ),
                        const SizedBox(width: 8),
                        _buildHeroStatChip(
                          '⚡',
                          _formatVolume(stats['totalVolume'] ?? 0.0),
                          'тоннаж',
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatChip(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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

  // ==================== ЗАГОЛОВОК ====================

  Widget _buildHeader(
      bool isDark,
      Map<String, dynamic> stats,
      LifeProvider provider,
      ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1D24).withOpacity(0.8)
            : Colors.white.withOpacity(0.7),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3F3D9E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Life Dashboard',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1D24),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '${stats['totalEvents'] ?? 0} событий • ${stats['totalTasks'] ?? 0} задач',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onLockTap ?? () {},
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    provider.init();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(bool isDark, Map<String, dynamic> stats) {
    final items = [
      ['📋', '${stats['totalTasks'] ?? 0}', 'задач'],
      ['💡', '${stats['totalIdeas'] ?? 0}', 'идей'],
      ['💪', '${stats['totalHabits'] ?? 0}', 'привычек'],
      ['📅', '${stats['totalEvents'] ?? 0}', 'событий'],
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: items.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1D24).withOpacity(0.6)
                  : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
              ),
            ),
            child: Row(
              children: [
                Text(item[0], style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item[1],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      item[2],
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.widgets_rounded,
            size: 56,
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Нет виджетов',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Нажмите + чтобы добавить',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== КНОПКА ДОБАВЛЕНИЯ ====================

  Widget _buildAddButton(bool isDark, LifeProvider provider) {
    return GestureDetector(
      onTap: () => _showAddWidgetDialog(context, isDark, provider),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3F3D9E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  // ==================== КАРТОЧКА ВИДЖЕТА ====================

  Widget _buildWidgetCard(
      LifeWidget widget,
      bool isDark,
      LifeProvider provider,
      int index,
      ) {
    final config = _getWidgetConfig(widget.type);

    return GestureDetector(
      onTap: () => _openFullscreenWidget(
        context,
        widget.type,
        isDark,
        provider,
      ),
      child: Container(
        key: Key(widget.id),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              config.color.withOpacity(0.15),
              config.color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: config.color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Декоративные элементы
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Основное содержимое
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Иконка
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [config.color, config.color.withOpacity(0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: config.color.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        config.icon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Название
                  Text(
                    config.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1D24),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Количество
                  Text(
                    config.count.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: config.color,
                    ),
                  ),
                  const Spacer(),
                  // Подпись
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: config.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          config.subtitle,
                          style: TextStyle(
                            fontSize: 8,
                            color: config.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.04),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Drag-ручка
            Positioned(
              top: 8,
              left: 8,
              child: ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            // Кнопка удаления
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _confirmRemoveWidget(context, widget, provider);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== КОНФИГУРАЦИЯ ВИДЖЕТОВ ====================

  _WidgetConfig _getWidgetConfig(String type) {
    switch (type) {
      case 'calendar':
        return _WidgetConfig(
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFF4A9BFF),
          label: 'Календарь',
          subtitle: 'События',
          count: 12,
        );
      case 'tasks':
        return _WidgetConfig(
          icon: Icons.checklist_rounded,
          color: const Color(0xFF34C759),
          label: 'Задачи',
          subtitle: 'To-do',
          count: 8,
        );
      case 'habits':
        return _WidgetConfig(
          icon: Icons.fitness_center_rounded,
          color: const Color(0xFFFF9500),
          label: 'Привычки',
          subtitle: 'Ритуалы',
          count: 5,
        );
      case 'notes':
        return _WidgetConfig(
          icon: Icons.note_rounded,
          color: const Color(0xFFFFCC00),
          label: 'Заметки',
          subtitle: 'Записи',
          count: 15,
        );
      case 'ideas':
        return _WidgetConfig(
          icon: Icons.lightbulb_rounded,
          color: const Color(0xFFAF52DE),
          label: 'Идеи',
          subtitle: 'Вдохновение',
          count: 7,
        );
      case 'stats':
        return _WidgetConfig(
          icon: Icons.analytics_rounded,
          color: const Color(0xFF00C7BE),
          label: 'Статистика',
          subtitle: 'Аналитика',
          count: 3,
        );
      case 'inbox':
        return _WidgetConfig(
          icon: Icons.inbox_rounded,
          color: const Color(0xFF8E8E93),
          label: 'Входящие',
          subtitle: 'Новые',
          count: 4,
        );
      default:
        return _WidgetConfig(
          icon: Icons.widgets_rounded,
          color: Colors.grey,
          label: type,
          subtitle: 'Виджет',
          count: 0,
        );
    }
  }

  // ==================== ДИАЛОГИ ====================

  void _confirmRemoveWidget(
      BuildContext context,
      LifeWidget widget,
      LifeProvider provider,
      ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить виджет?'),
        content: Text('Виджет "${_getWidgetConfig(widget.type).label}" будет удалён'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.removeWidget(widget.id);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ==================== ОТКРЫТИЕ ПОЛНОЭКРАННОГО ВИДЖЕТА ====================

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
          color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
          child: const Center(
            child: Text('Входящие в разработке'),
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
            backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
            body: screen,
          ),
        ),
      ),
    );
  }

  // ==================== ДИАЛОГ ДОБАВЛЕНИЯ ====================

  void _showAddWidgetDialog(
      BuildContext context,
      bool isDark,
      LifeProvider provider,
      ) {
    final widgetTypes = [
      _WidgetType('calendar', Icons.calendar_month_rounded, 'Календарь', 'События и встречи', const Color(0xFF4A9BFF)),
      _WidgetType('tasks', Icons.checklist_rounded, 'Задачи', 'To-do лист', const Color(0xFF34C759)),
      _WidgetType('habits', Icons.fitness_center_rounded, 'Привычки', 'Ежедневные ритуалы', const Color(0xFFFF9500)),
      _WidgetType('notes', Icons.note_rounded, 'Заметки', 'Быстрые записи', const Color(0xFFFFCC00)),
      _WidgetType('ideas', Icons.lightbulb_rounded, 'Идеи', 'Мозговой штурм', const Color(0xFFAF52DE)),
      _WidgetType('stats', Icons.analytics_rounded, 'Статистика', 'Аналитика', const Color(0xFF00C7BE)),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
              'Добавить виджет',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Выберите тип виджета',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
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
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: wt.color.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: wt.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(wt.icon, color: wt.color, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          wt.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          wt.subtitle,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ),
          ],
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
  final int count;

  const _WidgetConfig({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.count,
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