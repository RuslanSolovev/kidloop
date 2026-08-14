// features/fitness/ui/screens/wellbeing_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/fitness_provider.dart';

class WellbeingScreen extends StatefulWidget {
  final bool isDark;

  const WellbeingScreen({
    super.key,
    this.isDark = false,
  });

  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen> {
  int _energy = 5;
  int _sleep = 5;
  int _motivation = 5;
  String? _notes;
  List<String> _painAreas = [];

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final todayWellbeing = provider.getTodayWellbeing();
    final notes = provider.wellbeingNotes;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: AppBar(
        backgroundColor:
        isDark ? const Color(0xFF1A1D24) : Colors.white,
        elevation: 0,
        title: Text(
          'Самочувствие',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Сегодняшнее состояние
            if (todayWellbeing != null) ...[
              _buildTodayCard(isDark, todayWellbeing),
              const SizedBox(height: 20),
            ],

            // Форма для записи
            _buildFormCard(isDark, provider),

            const SizedBox(height: 20),

            // История
            if (notes.isNotEmpty) ...[
              Text(
                'История',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              ...notes.take(10).map((note) => _buildHistoryCard(isDark, note)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(bool isDark, WellbeingNote note) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF34C759).withOpacity(0.15),
            const Color(0xFF34C759).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF34C759).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mood_rounded,
                  color: Color(0xFF34C759), size: 28),
              const SizedBox(width: 10),
              Text(
                'Сегодня',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMoodStat('⚡', 'Энергия', note.energyLevel),
              _buildMoodStat('😴', 'Сон', note.sleepQuality),
              _buildMoodStat('🎯', 'Мотивация', note.motivationLevel),
            ],
          ),
          if (note.painAreas.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Боли: ${note.painAreas.join(", ")}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.withOpacity(0.8),
              ),
            ),
          ],
          if (note.notes != null && note.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note.notes!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodStat(String emoji, String label, int value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 6),
        Text(
          '$value/10',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFormCard(bool isDark, FitnessProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Записать самочувствие',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            isDark,
            '⚡ Энергия',
            _energy.toDouble(),
                (v) => setState(() => _energy = v.toInt()),
          ),
          _buildSlider(
            isDark,
            '😴 Сон',
            _sleep.toDouble(),
                (v) => setState(() => _sleep = v.toInt()),
          ),
          _buildSlider(
            isDark,
            '🎯 Мотивация',
            _motivation.toDouble(),
                (v) => setState(() => _motivation = v.toInt()),
          ),
          const SizedBox(height: 16),
          Text(
            'Где болит?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Спина',
              'Плечи',
              'Колени',
              'Шея',
              'Голова',
              'Нет болей',
            ].map((area) {
              final isSelected = _painAreas.contains(area);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _painAreas.remove(area);
                    } else {
                      if (area == 'Нет болей') {
                        _painAreas.clear();
                      } else {
                        _painAreas.remove('Нет болей');
                      }
                      _painAreas.add(area);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.orange.withOpacity(0.2)
                        : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.orange
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    area,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.orange
                          : (isDark
                          ? Colors.white54
                          : Colors.grey.shade600),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            maxLines: 2,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Заметки...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF0F1115)
                  : const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => _notes = v,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await provider.addWellbeingNote(
                  energyLevel: _energy,
                  sleepQuality: _sleep,
                  motivationLevel: _motivation,
                  painAreas: _painAreas,
                  notes: _notes,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Самочувствие записано'),
                    backgroundColor: Color(0xFF34C759),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                setState(() {
                  _notes = null;
                  _painAreas = [];
                });
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Сохранить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(bool isDark, String label, double value,
      Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(
              '${value.toInt()}/10',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 1,
          max: 10,
          divisions: 9,
          onChanged: onChanged,
          activeColor: const Color(0xFF34C759),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(bool isDark, WellbeingNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${note.date.day}.${note.date.month}.${note.date.year}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '⚡${note.energyLevel} 😴${note.sleepQuality} 🎯${note.motivationLevel}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          if (note.painAreas.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Боли: ${note.painAreas.join(", ")}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange.withOpacity(0.8),
              ),
            ),
          ],
          if (note.notes != null && note.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note.notes!,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}