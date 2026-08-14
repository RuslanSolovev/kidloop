// features/fitness/ui/screens/fitness_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

class FitnessDashboard extends StatefulWidget {
  final bool isDark;

  const FitnessDashboard({super.key, this.isDark = false});

  @override
  State<FitnessDashboard> createState() => _FitnessDashboardState();
}

class _FitnessDashboardState extends State<FitnessDashboard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final stats = provider.getStats();
    final profile = provider.profile;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar(isDark, profile, stats)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildQuickActions(isDark, provider, stats)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Ваши программы', onTap: () => _showProgramsList(context, isDark, provider))),
            SliverToBoxAdapter(child: _buildProgramsRow(isDark, provider)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Готовые шаблоны')),
            SliverToBoxAdapter(child: _buildTemplatesGrid(isDark, provider)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Прогресс')),
            SliverToBoxAdapter(child: _buildProgressCards(isDark, stats)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSectionHeader(isDark, 'Ещё')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildListDelegate([
                  _buildExtraCard(
                    isDark,
                    icon: Icons.photo_camera_rounded,
                    title: 'Фотоотчёты',
                    subtitle: '${provider.photos.length} фото',
                    color: const Color(0xFFFF9500),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: PhotoComparisonScreen(isDark: isDark)))),
                  ),
                  _buildWellbeingCard(isDark, provider),
                  _buildExtraCard(
                    isDark,
                    icon: Icons.bolt_rounded,
                    title: 'Быстрый старт',
                    subtitle: 'Свободная тренировка',
                    color: const Color(0xFFE91E63),
                    onTap: () => _quickStartWorkout(context, isDark, provider),
                  ),
                  _buildExtraCard(
                    isDark,
                    icon: Icons.add_circle_rounded,
                    title: 'Создать',
                    subtitle: 'Новая программа',
                    color: const Color(0xFF4A9BFF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark)))),
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ==================== ВЕРХНЯЯ ПАНЕЛЬ ====================

  Widget _buildTopBar(bool isDark, UserFitnessProfile? profile, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                (profile?.name ?? 'А')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Привет, ${profile?.name ?? 'Атлет'}!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24)),
                ),
                const SizedBox(height: 2),
                Text(
                  '🔥 ${stats['currentStreak'] ?? 0} дней стрик • ${stats['workoutsThisWeek'] ?? 0} тренировок на неделе',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (profile?.currentWeight != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${profile!.currentWeight!.toStringAsFixed(1)} кг',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24)),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== БЫСТРЫЕ ДЕЙСТВИЯ ====================

  Widget _buildQuickActions(bool isDark, FitnessProvider provider, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              icon: Icons.play_arrow_rounded,
              title: 'Начать',
              subtitle: 'тренировку',
              color: const Color(0xFFFF6B35),
              onTap: () => _quickStartWorkout(context, isDark, provider),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              icon: Icons.fitness_center_rounded,
              title: 'Упражнения',
              subtitle: '${stats['totalExercises']} в базе',
              color: const Color(0xFF00C7BE),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ExerciseLibraryScreen(isDark: isDark)))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              icon: Icons.book_rounded,
              title: 'Журнал',
              subtitle: '${stats['totalWorkouts']} записей',
              color: const Color(0xFFFFCC00),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: WorkoutLogScreen(isDark: isDark)))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(bool isDark, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24))),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ==================== ЗАГОЛОВОК СЕКЦИИ ====================

  Widget _buildSectionHeader(bool isDark, String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24))),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Text('Все →', style: TextStyle(fontSize: 12, color: const Color(0xFFFF6B35), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  // ==================== ПРОГРАММЫ (ГОРИЗОНТАЛЬНО) ====================

  Widget _buildProgramsRow(bool isDark, FitnessProvider provider) {
    if (provider.programs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark))));
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D24) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3), style: BorderStyle.solid),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_rounded, color: Color(0xFFFF6B35), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Создать программу', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1A1D24))),
                      const SizedBox(height: 4),
                      Text('Нажмите, чтобы создать свою первую программу тренировок', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
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
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: provider.programs.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == provider.programs.length) {
            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(isDark: isDark))));
              },
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
                ),
                child: const Center(child: Icon(Icons.add_rounded, color: Colors.grey, size: 32)),
              ),
            );
          }

          final program = provider.programs[index];
          final stats = _getProgramStats(program);
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramViewScreen(program: program, isDark: isDark))));
            },
            onLongPress: () {
              _showProgramOptions(context, isDark, program, provider);
            },
            child: Container(
              width: 160,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFFFF6B35).withOpacity(0.2), const Color(0xFFFF6B35).withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fitness_center_rounded, color: Color(0xFFFF6B35), size: 20),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text(program.type.displayName, style: const TextStyle(fontSize: 8, color: Color(0xFFFF6B35), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(program.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1A1D24)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    children: [
                      _buildMiniChip('${stats['completed']}', const Color(0xFF4CAF50)),
                      const SizedBox(width: 6),
                      _buildMiniChip('${stats['pending']}', const Color(0xFFFFC107)),
                      const SizedBox(width: 6),
                      Text('${program.days.length} дн.', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

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

  // ==================== ШАБЛОНЫ ====================

  Widget _buildTemplatesGrid(bool isDark, FitnessProvider provider) {
    if (provider.templates.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
        ),
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
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.bolt_rounded, color: Color(0xFFFF6B35), size: 16),
                      ),
                      const Spacer(),
                      Icon(Icons.download_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade500),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(t.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1A1D24))),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(t.description, style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          );
        },
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
            child: _buildProgressCard(isDark, '🔥', '${stats['currentStreak'] ?? 0}', 'дней стрик', const Color(0xFFFF6B35), onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: context.read<FitnessProvider>(), child: ProgressScreen(isDark: isDark))));
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProgressCard(isDark, '🏋️', '${stats['totalWorkouts'] ?? 0}', 'тренировок', const Color(0xFF4A9BFF), onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: context.read<FitnessProvider>(), child: WorkoutLogScreen(isDark: isDark))));
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProgressCard(isDark, '📊', '${stats['workoutsThisWeek'] ?? 0}', 'за неделю', const Color(0xFF00C7BE), onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: context.read<FitnessProvider>(), child: ProgressScreen(isDark: isDark))));
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark, String emoji, String value, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1A1D24))),
            Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ==================== ДОПОЛНИТЕЛЬНЫЕ КАРТОЧКИ ====================

  Widget _buildExtraCard(bool isDark, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24))),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildWellbeingCard(bool isDark, FitnessProvider provider) {
    final todayWellbeing = provider.getTodayWellbeing();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // 🔥 Открываем новый экран самочувствия
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: WellbeingScreen(isDark: isDark),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF34C759), Color(0xFF28A745)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mood_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 14),
            Text('Самочувствие', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24))),
            const SizedBox(height: 8),
            if (todayWellbeing != null) ...[
              Row(
                children: [
                  _buildMiniStat('⚡', '${todayWellbeing.energyLevel}'),
                  const SizedBox(width: 8),
                  _buildMiniStat('😴', '${todayWellbeing.sleepQuality}'),
                  const SizedBox(width: 8),
                  _buildMiniStat('🎯', '${todayWellbeing.motivationLevel}'),
                ],
              ),
            ] else ...[
              Text('Не записано', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade500)),
            ],
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
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        Text('/10', style: TextStyle(fontSize: 7, color: Colors.grey.shade500)),
      ],
    );
  }

  // ==================== ДИАЛОГИ ====================

  void _showProgramsList(BuildContext context, bool isDark, FitnessProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Мои программы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded, color: Color(0xFFFF6B35), size: 28),
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
                  ? Center(child: Text('Нет программ\nСоздайте свою первую программу', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500)))
                  : ListView.builder(
                itemCount: provider.programs.length,
                itemBuilder: (context, index) {
                  final program = provider.programs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.fitness_center_rounded, color: Color(0xFFFF6B35))),
                      title: Text(program.name, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text('${program.type.displayName} • ${program.days.length} дней', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramViewScreen(program: program, isDark: isDark))));
                      },
                      onLongPress: () {
                        Navigator.pop(ctx);
                        _showProgramOptions(context, isDark, program, provider);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProgramOptions(BuildContext context, bool isDark, WorkoutProgram program, FitnessProvider provider) {
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(program.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFFFF6B35)),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: ProgramBuilderScreen(existingProgram: program, isDark: isDark))));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: Colors.red.shade400),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await provider.deleteProgram(program.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _quickStartWorkout(BuildContext context, bool isDark, FitnessProvider provider) {
    final quickDay = WorkoutDay(
      id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
      programId: 'quick',
      dayNumber: 1,
      exercises: [],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Быстрая тренировка', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text('Выберите упражнения', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade500)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.exercises.length,
                  itemBuilder: (context, index) {
                    final ex = provider.exercises[index];
                    final isAdded = quickDay.exercises.any((we) => we.exerciseId == ex.id);
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: ex.muscleGroups.isNotEmpty ? ex.muscleGroups.first.color.withOpacity(0.2) : Colors.grey, child: Text(ex.exerciseType.emoji)),
                      title: Text(ex.name, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                      trailing: isAdded
                          ? IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setSheetState(() => quickDay.exercises.removeWhere((we) => we.exerciseId == ex.id)))
                          : IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFFF6B35)), onPressed: () {
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
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: WorkoutExecutionScreen(day: quickDay, isDark: isDark))));
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('Начать (${quickDay.exercises.length} упр.)'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}