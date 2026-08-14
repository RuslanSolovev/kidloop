import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kidloop/features/fitness/models/enums.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/fitness_provider.dart';
import 'workout_execution_screen.dart';
import 'program_summary_screen.dart';
import 'program_builder_screen.dart';

class ActiveProgramScreen extends StatefulWidget {
  final WorkoutProgram program;
  final bool isDark;

  const ActiveProgramScreen({
    super.key,
    required this.program,
    required this.isDark,
  });

  @override
  State<ActiveProgramScreen> createState() => _ActiveProgramScreenState();
}

class _ActiveProgramScreenState extends State<ActiveProgramScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressAnimController;
  Animation<double>? _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
        parent: _progressAnimController,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkIfCompleted();
      _animateProgress();
    });
  }

  void _animateProgress() {
    if (!mounted) return;

    final provider = context.read<FitnessProvider>();

    // 🔥 Ищем сессию для ЭТОЙ программы (не только active)
    final session = provider.sessions.where((s) =>
    s.programId == widget.program.id &&
        (s.status == ProgramSessionStatus.active ||
            s.status == ProgramSessionStatus.completed ||
            s.status == ProgramSessionStatus.paused)
    ).firstOrNull;

    if (session != null) {
      _progressAnimation = Tween<double>(
        begin: 0,
        end: session.progressPercent,
      ).animate(CurvedAnimation(
        parent: _progressAnimController,
        curve: Curves.easeOutCubic,
      ));

      _progressAnimController.reset();
      _progressAnimController.forward();

      if (mounted) setState(() {});
    }
  }

  void _checkIfCompleted() {
    if (!mounted) return;
    final provider = context.read<FitnessProvider>();

    // 🔥 ИСПРАВЛЕНО: ищем сессию для этой программы, не только active
    final session = provider.sessions.where((s) =>
    s.programId == widget.program.id
    ).firstOrNull;

    if (session != null && session.status == ProgramSessionStatus.completed) {
      debugPrint('🏆 Обнаружена завершённая программа, показываем сводку');
      _showCompletionScreen(session);
    }
  }

  @override
  void dispose() {
    _progressAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();

    // 🔥 ИСПРАВЛЕНО: ищем сессию для ЭТОЙ программы (любого статуса)
    final session = provider.sessions.where((s) =>
    s.programId == widget.program.id &&
        (s.status == ProgramSessionStatus.active ||
            s.status == ProgramSessionStatus.completed ||
            s.status == ProgramSessionStatus.paused)
    ).firstOrNull;

    // Если сессия совсем пропала (брошена/удалена) — выходим
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🔥 ИСПРАВЛЕНО: если программа завершена — сразу показываем сводку
    if (session.status == ProgramSessionStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCompletionScreen(session);
      });
    }

    final program = widget.program;
    final currentDayIndex = session.currentDayIndex;
    final currentDay = currentDayIndex < program.days.length
        ? program.days[currentDayIndex]
        : null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark, program, session),
          SliverToBoxAdapter(child: _buildHeroProgress(isDark, session, program)),
          SliverToBoxAdapter(child: _buildStatsRow(isDark, session)),
          if (session.status == ProgramSessionStatus.paused)
            SliverToBoxAdapter(child: _buildPausedBanner(isDark)),
          if (currentDay != null && session.status == ProgramSessionStatus.active)
            SliverToBoxAdapter(child: _buildCurrentDaySection(isDark, currentDay, session, provider)),
          SliverToBoxAdapter(child: _buildDayMapSection(isDark, session, program)),
          SliverToBoxAdapter(child: _buildActionButtons(isDark, session, provider)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ==================== APP BAR ====================

  Widget _buildSliverAppBar(bool isDark, WorkoutProgram program, ProgramSession session) {
    return SliverAppBar.large(
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      title: Text(program.name, style: const TextStyle(fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: Color(0xFFFF6B35)),
          onPressed: () => _showEditDialog(context, program),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black87),
          onSelected: (value) => _handleMenuAction(value, session, program),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'pause',
              child: Row(
                children: [
                  Icon(session.status == ProgramSessionStatus.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_circle_outline,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Text(session.status == ProgramSessionStatus.paused
                      ? 'Возобновить'
                      : 'Приостановить'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, color: Color(0xFFFF6B35), size: 20),
                  SizedBox(width: 12),
                  Text('Редактировать программу'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'abandon',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 12),
                  const Text('Бросить программу', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== HERO ПРОГРЕСС ====================

  Widget _buildHeroProgress(bool isDark, ProgramSession session, WorkoutProgram program) {
    final completedCount = session.daySessions.where((d) => d.status == DaySessionStatus.completed).length;
    final totalCount = session.daySessions.length;
    final daysRemaining = totalCount - completedCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B35), Color(0xFFFF3D00), Color(0xFFE91E63)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.status == ProgramSessionStatus.completed
                      ? '🏆 ЗАВЕРШЕНО'
                      : '🔥 В ПРОЦЕССЕ',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
              const Spacer(),
              if (session.streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚡ ${session.streak} ${_getDaysWord(session.streak)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'День ${session.currentDayIndex + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, height: 1),
                    ),
                    Text(
                      'из $totalCount',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _progressAnimController,
                builder: (ctx, child) {
                  final progressValue = _progressAnimation?.value ?? 0;
                  return Text(
                    '${(progressValue * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _progressAnimController,
              builder: (ctx, child) {
                final progressValue = _progressAnimation?.value ?? 0;
                return LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 12,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeroStat('✅ Выполнено', '$completedCount', Colors.white),
              _buildHeroStat('⏳ Осталось', '$daysRemaining', Colors.white.withOpacity(0.9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.85), fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ==================== СТАТИСТИКА ====================

  Widget _buildStatsRow(bool isDark, ProgramSession session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox(
              isDark,
              emoji: '🏋️',
              label: 'Тоннаж',
              value: '${(session.totalVolumeCompleted / 1000).toStringAsFixed(1)}k',
              unit: 'кг',
              color: const Color(0xFF4A9BFF),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatBox(
              isDark,
              emoji: '📊',
              label: 'Ср. RPE',
              value: session.averageRpe > 0 ? session.averageRpe.toStringAsFixed(1) : '—',
              unit: '',
              color: const Color(0xFF00C7BE),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatBox(
              isDark,
              emoji: '🏆',
              label: 'Рекорд',
              value: '${session.longestStreak}',
              unit: 'дн.',
              color: const Color(0xFFFFCC00),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatBox(
              isDark,
              emoji: '📅',
              label: 'Дней',
              value: '${session.durationDays}',
              unit: '',
              color: const Color(0xFFE91E63),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(bool isDark, {
    required String emoji,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(unit, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                ),
            ],
          ),
          Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==================== ПРИОСТАНОВЛЕНО ====================

  Widget _buildPausedBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.pause_circle_filled, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Программа на паузе', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                Text('Нажмите "Возобновить" чтобы продолжить', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.read<FitnessProvider>().resumeProgramSession(context.read<FitnessProvider>().activeSession!.id),
            style: TextButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Возобновить'),
          ),
        ],
      ),
    );
  }

  // ==================== ТЕКУЩИЙ ДЕНЬ ====================

  Widget _buildCurrentDaySection(bool isDark, WorkoutDay day, ProgramSession session, FitnessProvider provider) {
    final isRestDay = day.isRestDay;

    if (isRestDay) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF9E9E9E).withOpacity(0.15), const Color(0xFF616161).withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.bedtime_rounded, size: 40, color: isDark ? Colors.white54 : Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Сегодня день отдыха',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Восстановление — важная часть прогресса 😴',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await provider.skipCurrentDay(reason: 'День отдыха');
                  if (mounted) {
                    _animateProgress();
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Перейти к следующему дню', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.15),
            const Color(0xFF2196F3).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2196F3)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'День ${session.currentDayIndex + 1}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                    ),
                    Text(
                      '${day.exercises.length} упражнений • ${_getEstimatedTime(day)}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'План на сегодня:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                ...day.exercises.take(3).toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ex = entry.value;
                  final exData = provider.exercises.firstWhere(
                        (e) => e.id == ex.exerciseId,
                    orElse: () => Exercise(id: '', name: '???'),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFF6B35))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(exData.exerciseType.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            exData.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${ex.sets.length}×',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
                if (day.exercises.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${day.exercises.length - 3} ещё...',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _startTodayWorkout(context, day),
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: const Text('НАЧАТЬ ТРЕНИРОВКУ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: const Color(0xFF4CAF50).withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEstimatedTime(WorkoutDay day) {
    int totalSets = 0;
    for (final ex in day.exercises) {
      totalSets += ex.sets.length;
    }
    final minutes = totalSets * 3;
    if (minutes < 60) return '~$minutes мин';
    return '~${(minutes / 60).toStringAsFixed(1)} ч';
  }

  // ==================== КАРТА ДНЕЙ ====================

  Widget _buildDayMapSection(bool isDark, ProgramSession session, WorkoutProgram program) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_rounded, color: const Color(0xFFFF6B35), size: 22),
              const SizedBox(width: 8),
              Text(
                'Карта программы',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
              const Spacer(),
              Text(
                '${session.daySessions.where((d) => d.status == DaySessionStatus.completed).length}/${program.days.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFFF6B35)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem(isDark, '✅', 'Выполнено', const Color(0xFF4CAF50)),
              _buildLegendItem(isDark, '🔥', 'Текущий', const Color(0xFFFF6B35)),
              _buildLegendItem(isDark, '❌', 'Пропущен', const Color(0xFFF44336)),
              _buildLegendItem(isDark, '🔒', 'Закрыто', Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...program.days.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final daySession = index < session.daySessions.length
                ? session.daySessions[index]
                : null;
            return _buildDayTile(isDark, day, daySession, index, session.currentDayIndex);
          }),
        ],
      ),
    );
  }

  Widget _buildLegendItem(bool isDark, String emoji, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildDayTile(bool isDark, WorkoutDay day, DaySession? daySession, int index, int currentIndex) {
    Color bgColor;
    String emoji;
    Color iconColor;
    String statusText;
    bool isCurrent = index == currentIndex && daySession?.status == DaySessionStatus.current;

    if (daySession == null) {
      bgColor = Colors.grey.withOpacity(0.1);
      emoji = '🔒';
      iconColor = Colors.grey;
      statusText = 'Заблокировано';
    } else {
      switch (daySession.status) {
        case DaySessionStatus.completed:
          bgColor = const Color(0xFF4CAF50).withOpacity(0.1);
          emoji = '✅';
          iconColor = const Color(0xFF4CAF50);
          statusText = daySession.volumeDone != null
              ? '${daySession.volumeDone!.toStringAsFixed(0)} кг'
              : 'Выполнено';
          break;
        case DaySessionStatus.current:
          bgColor = const Color(0xFFFF6B35).withOpacity(0.15);
          emoji = '🔥';
          iconColor = const Color(0xFFFF6B35);
          statusText = 'Текущий';
          break;
        case DaySessionStatus.skipped:
          bgColor = const Color(0xFFF44336).withOpacity(0.1);
          emoji = '❌';
          iconColor = const Color(0xFFF44336);
          statusText = 'Пропущен';
          break;
        case DaySessionStatus.locked:
        case DaySessionStatus.pending:
          bgColor = isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100;
          emoji = '🔒';
          iconColor = Colors.grey;
          statusText = 'Ожидает';
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: isCurrent
            ? Border.all(color: const Color(0xFFFF6B35), width: 2)
            : Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
        boxShadow: isCurrent
            ? [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.2), blurRadius: 10)]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'День ${index + 1}${day.isRestDay ? " 😴" : ""}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day.isRestDay
                      ? 'День отдыха'
                      : '${day.exercises.length} упражнений',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusText,
                style: TextStyle(fontSize: 11, color: iconColor, fontWeight: FontWeight.w700),
              ),
              if (daySession?.completedAt != null)
                Text(
                  _formatDate(daySession!.completedAt!),
                  style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.grey.shade400),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }

  // ==================== КНОПКИ ДЕЙСТВИЙ ====================

  Widget _buildActionButtons(bool isDark, ProgramSession session, FitnessProvider provider) {
    if (session.status != ProgramSessionStatus.active) return const SizedBox();

    final currentDay = session.currentDayIndex < widget.program.days.length
        ? widget.program.days[session.currentDayIndex]
        : null;

    if (currentDay == null || currentDay.isRestDay) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _confirmSkipDay(context, session),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Пропустить день', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : Colors.grey.shade700,
                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ДИАЛОГИ ====================

  void _startTodayWorkout(BuildContext context, WorkoutDay day) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<FitnessProvider>(),
          child: WorkoutExecutionScreen(day: day, isDark: widget.isDark),
        ),
      ),
    ).then((_) {
      if (mounted) {
        _checkIfCompleted();
        _animateProgress();
      }
    });
  }

  void _confirmSkipDay(BuildContext context, ProgramSession session) {
    final reasonController = TextEditingController();
    final isDark = widget.isDark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            const Text('Пропустить день?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Это сбросит вашу серию из ${session.streak} ${_getDaysWord(session.streak)}. Причина (необязательно):',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Почему пропускаете?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F1115) : Colors.grey.shade100,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<FitnessProvider>().skipCurrentDay(reason: reasonController.text);
              if (mounted) {
                _animateProgress();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Пропустить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WorkoutProgram program) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<FitnessProvider>(),
          child: ProgramBuilderScreen(existingProgram: program, isDark: widget.isDark),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, ProgramSession session, WorkoutProgram program) async {
    final provider = context.read<FitnessProvider>();

    switch (action) {
      case 'pause':
        if (session.status == ProgramSessionStatus.paused) {
          await provider.resumeProgramSession(session.id);
        } else {
          await provider.pauseProgramSession();
        }
        break;
      case 'edit':
        _showEditDialog(context, program);
        break;
      case 'abandon':
        _confirmAbandonProgram(context, session, program);
        break;
    }
  }

  void _confirmAbandonProgram(BuildContext context, ProgramSession session, WorkoutProgram program) {
    final isDark = widget.isDark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Бросить программу?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Весь прогресс будет остановлен:',
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            _buildAbandonStat('✅ Выполнено дней', '${session.totalWorkoutsCompleted}'),
            _buildAbandonStat('🏋️ Тоннаж', '${session.totalVolumeCompleted.toStringAsFixed(0)} кг'),
            _buildAbandonStat('🔥 Макс. серия', '${session.longestStreak} ${_getDaysWord(session.longestStreak)}'),
            const SizedBox(height: 8),
            Text(
              'Вы сможете начать программу заново позже.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<FitnessProvider>().abandonProgramSession(session.id);
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Бросить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAbandonStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _showCompletionScreen(ProgramSession session) {
    debugPrint('🎬 Переход на экран сводки: ${widget.program.name}');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<FitnessProvider>(),
          child: ProgramSummaryScreen(
            session: session,
            program: widget.program,
            isDark: widget.isDark,
          ),
        ),
      ),
    );
  }

  String _getDaysWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'день';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'дня';
    return 'дней';
  }
}