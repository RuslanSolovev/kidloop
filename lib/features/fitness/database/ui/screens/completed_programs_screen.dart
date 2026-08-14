import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/fitness_provider.dart';
import 'program_summary_screen.dart';

class CompletedProgramsScreen extends StatefulWidget {
  final bool isDark;

  const CompletedProgramsScreen({
    super.key,
    required this.isDark,
  });

  @override
  State<CompletedProgramsScreen> createState() => _CompletedProgramsScreenState();
}

class _CompletedProgramsScreenState extends State<CompletedProgramsScreen> {
  String _filter = 'all'; // all, completed, abandoned, paused

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();

    // Собираем все сессии кроме активных
    final allSessions = provider.sessions.where((s) =>
    s.status != ProgramSessionStatus.active
    ).toList();

    // Применяем фильтр
    final filteredSessions = allSessions.where((s) {
      switch (_filter) {
        case 'completed':
          return s.status == ProgramSessionStatus.completed;
        case 'abandoned':
          return s.status == ProgramSessionStatus.abandoned;
        case 'paused':
          return s.status == ProgramSessionStatus.paused;
        default:
          return true;
      }
    }).toList();

    // Сортируем по дате (новые сверху)
    filteredSessions.sort((a, b) => b.startDate.compareTo(a.startDate));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        elevation: 0,
        title: Text(
          'История программ',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Общая статистика
          _buildTotalStats(isDark, provider),

          // Фильтры
          _buildFilters(isDark),

          // Список программ
          Expanded(
            child: filteredSessions.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredSessions.length,
              itemBuilder: (context, index) {
                final session = filteredSessions[index];
                return _buildSessionCard(isDark, session, provider);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ОБЩАЯ СТАТИСТИКА ====================

  Widget _buildTotalStats(bool isDark, FitnessProvider provider) {
    final completedCount = provider.sessions.where((s) =>
    s.status == ProgramSessionStatus.completed
    ).length;

    final totalVolume = provider.sessions.fold<double>(
      0,
          (sum, s) => sum + s.totalVolumeCompleted,
    );

    final totalWorkouts = provider.sessions.fold<int>(
      0,
          (sum, s) => sum + s.totalWorkoutsCompleted,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Вся ваша история',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTotalStat('🏆', '$completedCount', 'программ'),
              _buildTotalStat('🏋️', '${(totalVolume / 1000).toStringAsFixed(1)}k', 'кг тоннаж'),
              _buildTotalStat('💪', '$totalWorkouts', 'тренировок'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalStat(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ФИЛЬТРЫ ====================

  Widget _buildFilters(bool isDark) {
    final filters = [
      {'id': 'all', 'label': 'Все', 'icon': Icons.list_rounded},
      {'id': 'completed', 'label': 'Завершённые', 'icon': Icons.check_circle_rounded},
      {'id': 'abandoned', 'label': 'Брошенные', 'icon': Icons.flag_rounded},
      {'id': 'paused', 'label': 'На паузе', 'icon': Icons.pause_circle_rounded},
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _filter == filter['id'];

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _filter = filter['id'] as String);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6B35)
                    : (isDark ? const Color(0xFF1A1D24) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF6B35)
                      : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== КАРТОЧКА СЕССИИ ====================

  Widget _buildSessionCard(bool isDark, ProgramSession session, FitnessProvider provider) {
    // Находим программу по ID
    WorkoutProgram? program;
    try {
      program = provider.programs.firstWhere((p) => p.id == session.programId);
    } catch (_) {
      program = null;
    }

    final programName = program?.name ?? 'Удалённая программа';
    final statusInfo = _getStatusInfo(session.status);
    final duration = session.endDate != null
        ? session.endDate!.difference(session.startDate).inDays
        : DateTime.now().difference(session.startDate).inDays;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (session.status == ProgramSessionStatus.completed && program != null) {
          // Открываем полную сводку
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: ProgramSummaryScreen(
                  session: session,
                  program: program!,
                  isDark: isDark,
                ),
              ),
            ),
          );
        } else {
          // Для незавершённых показываем детали в диалоге
          _showSessionDetails(context, session, program);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (statusInfo['color'] as Color).withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (statusInfo['color'] as Color).withOpacity(0.2),
                        (statusInfo['color'] as Color).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      statusInfo['emoji'] as String,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDate(session.startDate)} — ${session.endDate != null ? _formatDate(session.endDate!) : 'сейчас'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (statusInfo['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusInfo['label'] as String,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusInfo['color'] as Color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Прогресс-бар
            if (session.status == ProgramSessionStatus.completed) ...[
              Row(
                children: [
                  Icon(Icons.flag_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Выполнено: ${session.daySessions.where((d) => d.status == DaySessionStatus.completed).length} из ${session.daySessions.length} дней',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(session.progressPercent * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: session.progressPercent,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Статистика
            Row(
              children: [
                _buildSessionStat(
                  isDark,
                  Icons.calendar_month_rounded,
                  '$duration',
                  'дней',
                  const Color(0xFF4A9BFF),
                ),
                const SizedBox(width: 8),
                _buildSessionStat(
                  isDark,
                  Icons.fitness_center_rounded,
                  '${session.totalWorkoutsCompleted}',
                  'трен.',
                  const Color(0xFFFF6B35),
                ),
                const SizedBox(width: 8),
                _buildSessionStat(
                  isDark,
                  Icons.monitor_weight_rounded,
                  '${(session.totalVolumeCompleted / 1000).toStringAsFixed(1)}k',
                  'кг',
                  const Color(0xFF00C7BE),
                ),
                const SizedBox(width: 8),
                _buildSessionStat(
                  isDark,
                  Icons.local_fire_department_rounded,
                  '${session.longestStreak}',
                  'серия',
                  const Color(0xFFFFCC00),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStat(bool isDark, IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(ProgramSessionStatus status) {
    switch (status) {
      case ProgramSessionStatus.completed:
        return {
          'emoji': '🏆',
          'label': 'ЗАВЕРШЕНА',
          'color': const Color(0xFF4CAF50),
        };
      case ProgramSessionStatus.abandoned:
        return {
          'emoji': '🚫',
          'label': 'БРОШЕНА',
          'color': const Color(0xFFF44336),
        };
      case ProgramSessionStatus.paused:
        return {
          'emoji': '⏸️',
          'label': 'НА ПАУЗЕ',
          'color': Colors.orange,
        };
      default:
        return {
          'emoji': '🔥',
          'label': 'АКТИВНА',
          'color': const Color(0xFFFF6B35),
        };
    }
  }

  // ==================== ДЕТАЛИ СЕССИИ (для незавершённых) ====================

  void _showSessionDetails(BuildContext context, ProgramSession session, WorkoutProgram? program) {
    final isDark = widget.isDark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              program?.name ?? 'Удалённая программа',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Статус: ${_getStatusInfo(session.status)['label']}',
              style: TextStyle(
                fontSize: 13,
                color: _getStatusInfo(session.status)['color'] as Color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // Детальная статистика
            _buildDetailRow(isDark, '📅', 'Дата начала', _formatDate(session.startDate)),
            _buildDetailRow(isDark, '🏁', 'Дата конца', session.endDate != null ? _formatDate(session.endDate!) : '—'),
            _buildDetailRow(isDark, '⏱️', 'Длительность', '${session.durationDays} дней'),
            _buildDetailRow(isDark, '💪', 'Тренировок', '${session.totalWorkoutsCompleted}'),
            _buildDetailRow(isDark, '❌', 'Пропущено', '${session.totalWorkoutsSkipped}'),
            _buildDetailRow(isDark, '🏋️', 'Тоннаж', '${session.totalVolumeCompleted.toStringAsFixed(0)} кг'),
            _buildDetailRow(isDark, '📊', 'Средний RPE', session.averageRpe > 0 ? session.averageRpe.toStringAsFixed(1) : '—'),
            _buildDetailRow(isDark, '🔥', 'Макс. серия', '${session.longestStreak} дней'),

            const SizedBox(height: 20),

            // Кнопки действий
            if (session.status == ProgramSessionStatus.paused)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await context.read<FitnessProvider>().resumeProgramSession(session.id);
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Возобновить программу'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

            if (session.status == ProgramSessionStatus.abandoned)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Эта программа была брошена. Начните новую для продолжения тренировок.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(bool isDark, String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ПУСТОЕ СОСТОЯНИЕ ====================

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            'Пока нет истории',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Завершите свою первую программу, и она появится здесь со всеми подробностями',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white24 : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}