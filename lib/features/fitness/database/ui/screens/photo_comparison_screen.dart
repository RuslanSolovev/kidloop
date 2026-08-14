import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/fitness_provider.dart';

class PhotoComparisonScreen extends StatefulWidget {
  final bool isDark;

  const PhotoComparisonScreen({super.key, this.isDark = false});

  @override
  State<PhotoComparisonScreen> createState() => _PhotoComparisonScreenState();
}

class _PhotoComparisonScreenState extends State<PhotoComparisonScreen> {
  int? _selectedPhotoIndex1;
  int? _selectedPhotoIndex2;
  bool _isCompareMode = false;
  bool _isSliderMode = false;
  double _sliderPosition = 0.5;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final provider = context.watch<FitnessProvider>();
    final photos = provider.photos;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F5F9),
      appBar: _buildAppBar(isDark, _isCompareMode, photos),
      body: _isCompareMode
          ? _buildCompareView(isDark, photos)
          : _buildGalleryView(isDark, photos, provider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPhotoDialog(context, isDark, provider),
        backgroundColor: const Color(0xFFFF6B35),
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text('Добавить фото', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, bool isCompareMode, List<FitnessPhoto> photos) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      elevation: 0,
      title: Text(
        isCompareMode ? 'Сравнение' : 'Фотоотчёты',
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w800, fontSize: 17),
      ),
      actions: [
        if (isCompareMode) ...[
          IconButton(
            icon: Icon(
              _isSliderMode ? Icons.compare_arrows_rounded : Icons.swipe_rounded,
              color: const Color(0xFFFF6B35),
            ),
            tooltip: _isSliderMode ? 'Рядом' : 'Слайдер',
            onPressed: () => setState(() => _isSliderMode = !_isSliderMode),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            onPressed: () {
              setState(() {
                _isCompareMode = false;
                _selectedPhotoIndex1 = null;
                _selectedPhotoIndex2 = null;
              });
            },
          ),
        ] else if (photos.length >= 2) ...[
          TextButton.icon(
            onPressed: () => setState(() => _isCompareMode = true),
            icon: const Icon(Icons.compare_rounded, size: 16),
            label: const Text('Сравнить', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B35)),
          ),
        ],
      ],
    );
  }

  // ==================== ГАЛЕРЕЯ ====================

  Widget _buildGalleryView(bool isDark, List<FitnessPhoto> photos, FitnessProvider provider) {
    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_rounded, size: 80, color: isDark ? Colors.white12 : Colors.grey.shade300),
            const SizedBox(height: 20),
            Text('Нет фотографий', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Добавьте фото, чтобы отслеживать\nвизуальный прогресс', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isDark ? Colors.white24 : Colors.grey.shade400)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddPhotoDialog(context, isDark, provider),
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Добавить первое фото'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_isCompareMode)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.info_rounded, color: Color(0xFFFF6B35), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedPhotoIndex1 == null
                        ? 'Выберите первое фото'
                        : _selectedPhotoIndex2 == null
                        ? 'Выберите второе фото для сравнения'
                        : 'Нажмите "Сравнить" для просмотра',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B35)),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              final isSelected = _selectedPhotoIndex1 == index || _selectedPhotoIndex2 == index;
              final selectionNumber = _selectedPhotoIndex1 == index ? 1 : _selectedPhotoIndex2 == index ? 2 : null;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_isCompareMode) {
                    setState(() {
                      if (_selectedPhotoIndex1 == null) {
                        _selectedPhotoIndex1 = index;
                      } else if (_selectedPhotoIndex2 == null && _selectedPhotoIndex1 != index) {
                        _selectedPhotoIndex2 = index;
                      } else {
                        _selectedPhotoIndex1 = index;
                        _selectedPhotoIndex2 = null;
                      }
                    });
                  } else {
                    _showPhotoDetail(context, isDark, photo, provider);
                  }
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _showPhotoOptions(context, isDark, photo, provider);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(color: const Color(0xFFFF6B35), width: 3)
                        : Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                    boxShadow: isSelected
                        ? [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.3), blurRadius: 12, spreadRadius: 1)]
                        : [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 8)],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(isSelected ? 13 : 16),
                        child: _buildPhotoImage(photo, isDark),
                      ),
                      if (selectionNumber != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                            ),
                            child: Center(child: Text('$selectionNumber', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent]),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${photo.date.day}.${photo.date.month}.${photo.date.year}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                              if (photo.measurementsCount > 0)
                                Text('${photo.measurementsCount} измер.', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                      if (photo.label != null && photo.label!.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
                            child: Text(photo.label!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
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

  Widget _buildPhotoImage(FitnessPhoto photo, bool isDark) {
    final file = File(photo.imageUrl);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return Container(
      color: isDark ? const Color(0xFF1A1D24) : Colors.grey.shade200,
      child: Center(child: Icon(Icons.image_rounded, size: 48, color: isDark ? Colors.white12 : Colors.grey.shade400)),
    );
  }

  // ==================== РЕЖИМ СРАВНЕНИЯ ====================

  Widget _buildCompareView(bool isDark, List<FitnessPhoto> photos) {
    if (_selectedPhotoIndex1 == null || _selectedPhotoIndex2 == null) {
      // Если выбрано только одно — показываем галерею с подсказкой
      return _buildGalleryView(isDark, photos, context.read<FitnessProvider>());
    }

    final photo1 = photos[_selectedPhotoIndex1!];
    final photo2 = photos[_selectedPhotoIndex2!];

    final sorted = [photo1, photo2]..sort((a, b) => a.date.compareTo(b.date));
    final beforePhoto = sorted[0];
    final afterPhoto = sorted[1];

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildPhotoInfoChip('До', beforePhoto),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _getDaysBetween(beforePhoto.date, afterPhoto.date),
                    style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const Spacer(),
                _buildPhotoInfoChip('После', afterPhoto),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: _isSliderMode
                ? _buildSliderCompare(isDark, beforePhoto, afterPhoto)
                : _buildSideBySideCompare(isDark, beforePhoto, afterPhoto),
          ),
          const SizedBox(height: 16),
          _buildMeasurementsComparison(isDark, beforePhoto, afterPhoto),
        ],
      ),
    );
  }

  Widget _buildPhotoInfoChip(String label, FitnessPhoto photo) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFF6B35))),
        const SizedBox(height: 2),
        Text('${photo.date.day}.${photo.date.month}.${photo.date.year}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        if (photo.weight != null) Text('${photo.weight!.toStringAsFixed(1)} кг', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSideBySideCompare(bool isDark, FitnessPhoto before, FitnessPhoto after) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildCompareImage(isDark, before, 'До')),
          Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 2, color: isDark ? Colors.white24 : Colors.grey.shade300),
          Expanded(child: _buildCompareImage(isDark, after, 'После')),
        ],
      ),
    );
  }

  // 🔥 ИСПРАВЛЕННЫЙ СЛАЙДЕР СРАВНЕНИЯ
  Widget _buildSliderCompare(bool isDark, FitnessPhoto before, FitnessPhoto after) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanUpdate: (details) {
              final newX = details.localPosition.dx;
              final width = constraints.maxWidth;
              setState(() {
                _sliderPosition = (newX / width).clamp(0.0, 1.0);
              });
            },
            onTapDown: (details) {
              final newX = details.localPosition.dx;
              final width = constraints.maxWidth;
              setState(() {
                _sliderPosition = (newX / width).clamp(0.0, 1.0);
              });
            },
            child: Stack(
              children: [
                // Фото "После" (фон)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: _buildCompareImage(isDark, after, 'После'),
                  ),
                ),
                // Фото "До" (обрезанное)
                ClipRect(
                  clipper: _HalfClipper(_sliderPosition),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: _buildCompareImage(isDark, before, 'До'),
                    ),
                  ),
                ),
                // Вертикальная линия
                Positioned(
                  left: constraints.maxWidth * _sliderPosition - 2,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                    ),
                  ),
                ),
                // Ручка слайдера
                Positioned(
                  left: constraints.maxWidth * _sliderPosition - 24,
                  top: constraints.maxHeight / 2 - 24,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                        Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompareImage(bool isDark, FitnessPhoto photo, String label) {
    final file = File(photo.imageUrl);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (file.existsSync())
            Image.file(file, fit: BoxFit.cover)
          else
            Center(child: Icon(Icons.image_rounded, size: 64, color: isDark ? Colors.white12 : Colors.grey.shade400)),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 СРАВНЕНИЕ ИЗМЕРЕНИЙ ТЕЛА
  Widget _buildMeasurementsComparison(bool isDark, FitnessPhoto before, FitnessPhoto after) {
    final measurements = <_MeasurementItem>[
      _MeasurementItem('Вес', 'кг', before.weight, after.weight, isWeight: true),
      _MeasurementItem('Грудь', 'см', before.chest, after.chest),
      _MeasurementItem('Талия', 'см', before.waist, after.waist, smallerIsBetter: true),
      _MeasurementItem('Бёдра', 'см', before.hips, after.hips),
      _MeasurementItem('Бицепс', 'см', before.biceps, after.biceps),
      _MeasurementItem('Бедро', 'см', before.thigh, after.thigh),
      _MeasurementItem('Икра', 'см', before.calf, after.calf),
      _MeasurementItem('Шея', 'см', before.neck, after.neck),
      _MeasurementItem('Предплечье', 'см', before.forearm, after.forearm),
    ];

    // Оставляем только те, где есть оба значения
    final comparableItems = measurements.where((m) => m.before != null && m.after != null).toList();
    // И те, где есть хотя бы одно
    final partialItems = measurements.where((m) => (m.before != null || m.after != null) && !(m.before != null && m.after != null)).toList();

    if (comparableItems.isEmpty && partialItems.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline_rounded, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Нет данных для сравнения', style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('Добавьте измерения к фото', style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.grey.shade400)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten_rounded, color: const Color(0xFFFF6B35), size: 18),
              const SizedBox(width: 8),
              Text('Измерения тела', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          // Заголовок таблицы
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Параметр', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600))),
                Expanded(child: Text('До', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600))),
                Expanded(child: Text('После', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600))),
                Expanded(child: Text('Δ', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...comparableItems.map((item) => _buildMeasurementRow(isDark, item)),
          if (partialItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Частичные данные:', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            ...partialItems.map((item) => _buildMeasurementRow(isDark, item)),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasurementRow(bool isDark, _MeasurementItem item) {
    final hasBoth = item.before != null && item.after != null;
    final diff = hasBoth ? item.after! - item.before! : 0.0;

    Color diffColor;
    IconData? diffIcon;
    if (!hasBoth) {
      diffColor = Colors.grey;
    } else if (diff.abs() < 0.05) {
      diffColor = Colors.grey;
    } else {
      // Для веса и талии — уменьшение хорошо
      // Для бицепса, груди — увеличение хорошо
      final isPositive = item.smallerIsBetter ? diff < 0 : diff > 0;
      diffColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
      diffIcon = diff > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(item.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(child: Text(item.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
              ],
            ),
          ),
          Expanded(
            child: Text(
              item.before != null ? '${item.before!.toStringAsFixed(1)}' : '—',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              item.after != null ? '${item.after!.toStringAsFixed(1)}' : '—',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (diffIcon != null) Icon(diffIcon, size: 12, color: diffColor),
                Text(
                  hasBoth ? '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}' : '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: diffColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ДИАЛОГИ ====================

  void _showPhotoDetail(BuildContext context, bool isDark, FitnessPhoto photo, FitnessProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1D24) : Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 300,
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF0F1115) : Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: File(photo.imageUrl).existsSync()
                        ? Image.file(File(photo.imageUrl), fit: BoxFit.cover)
                        : Center(child: Icon(Icons.image_rounded, size: 80, color: Colors.grey.shade500)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('${photo.date.day}.${photo.date.month}.${photo.date.year}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                if (photo.label != null) Text(photo.label!, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600)),
                if (photo.notes != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(photo.notes!, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade500))),
                if (photo.measurementsCount > 0) ...[
                  const SizedBox(height: 16),
                  _buildMeasurementsPreview(isDark, photo),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditPhotoDialog(context, isDark, photo, provider);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Изменить'),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDeletePhoto(context, isDark, photo, provider);
                      },
                      icon: Icon(Icons.delete_rounded, size: 16, color: Colors.red.shade400),
                      label: const Text('Удалить', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementsPreview(bool isDark, FitnessPhoto photo) {
    final measurements = <MapEntry<String, String>>[];
    if (photo.weight != null) measurements.add(MapEntry('⚖️ Вес', '${photo.weight!.toStringAsFixed(1)} кг'));
    if (photo.chest != null) measurements.add(MapEntry('📏 Грудь', '${photo.chest!.toStringAsFixed(1)} см'));
    if (photo.waist != null) measurements.add(MapEntry('📏 Талия', '${photo.waist!.toStringAsFixed(1)} см'));
    if (photo.hips != null) measurements.add(MapEntry('📏 Бёдра', '${photo.hips!.toStringAsFixed(1)} см'));
    if (photo.biceps != null) measurements.add(MapEntry('💪 Бицепс', '${photo.biceps!.toStringAsFixed(1)} см'));
    if (photo.thigh != null) measurements.add(MapEntry('🦵 Бедро', '${photo.thigh!.toStringAsFixed(1)} см'));
    if (photo.calf != null) measurements.add(MapEntry('🦵 Икра', '${photo.calf!.toStringAsFixed(1)} см'));
    if (photo.neck != null) measurements.add(MapEntry('📏 Шея', '${photo.neck!.toStringAsFixed(1)} см'));
    if (photo.forearm != null) measurements.add(MapEntry('💪 Предплечье', '${photo.forearm!.toStringAsFixed(1)} см'));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: measurements.map((m) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
            ),
            child: Text(m.key + ': ' + m.value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          );
        }).toList(),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, bool isDark, FitnessPhoto photo, FitnessProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1D24) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFFFF6B35)),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditPhotoDialog(context, isDark, photo, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.compare_rounded, color: Color(0xFF4A9BFF)),
              title: const Text('Сравнить с другим'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _isCompareMode = true;
                  _selectedPhotoIndex1 = provider.photos.indexOf(photo);
                  _selectedPhotoIndex2 = null;
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: Colors.red.shade400),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeletePhoto(context, isDark, photo, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 ОБНОВЛЁННЫЙ ДИАЛОГ ДОБАВЛЕНИЯ С КАМЕРОЙ И ОБХВАТАМИ
  void _showAddPhotoDialog(BuildContext context, bool isDark, FitnessProvider provider) {
    final labelController = TextEditingController();
    final weightController = TextEditingController();
    final notesController = TextEditingController();
    final chestController = TextEditingController();
    final waistController = TextEditingController();
    final hipsController = TextEditingController();
    final bicepsController = TextEditingController();
    final thighController = TextEditingController();
    final calfController = TextEditingController();
    final neckController = TextEditingController();
    final forearmController = TextEditingController();
    File? selectedImage;
    bool showMeasurements = false;

    Future<void> pickImage(ImageSource source) async {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image != null && context.mounted) {
        (context as Element).markNeedsBuild();
        setState(() {});
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
          title: Text('Добавить фото', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showImageSourceDialog(ctx, isDark, (source) async {
                    final XFile? image = await _picker.pickImage(source: source, imageQuality: 85);
                    if (image != null) {
                      setDialogState(() => selectedImage = File(image.path));
                    }
                  }),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
                    ),
                    child: selectedImage != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(selectedImage!, fit: BoxFit.cover))
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_rounded, color: Color(0xFFFF6B35), size: 48),
                        const SizedBox(height: 8),
                        Text('Нажмите для выбора фото', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('Камера или галерея', style: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade500, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(labelText: 'Подпись (например "До")', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(labelText: 'Вес (кг)', prefixIcon: const Icon(Icons.monitor_weight_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                // Переключатель обхватов
                InkWell(
                  onTap: () => setDialogState(() => showMeasurements = !showMeasurements),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: showMeasurements ? const Color(0xFFFF6B35).withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: showMeasurements ? const Color(0xFFFF6B35).withOpacity(0.5) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.straighten_rounded, color: showMeasurements ? const Color(0xFFFF6B35) : Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Добавить обхваты тела', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                        Icon(showMeasurements ? Icons.expand_less : Icons.expand_more, color: isDark ? Colors.white54 : Colors.grey),
                      ],
                    ),
                  ),
                ),
                if (showMeasurements) ...[
                  const SizedBox(height: 12),
                  _buildMeasurementField('Грудь (см)', chestController, isDark, Icons.favorite_outline),
                  const SizedBox(height: 8),
                  _buildMeasurementField('Талия (см)', waistController, isDark, Icons.hourglass_empty),
                  const SizedBox(height: 8),
                  _buildMeasurementField('Бёдра (см)', hipsController, isDark, Icons.water_drop_outlined),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildMeasurementField('Бицепс', bicepsController, isDark, Icons.fitness_center)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMeasurementField('Предплечье', forearmController, isDark, Icons.fitness_center)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildMeasurementField('Бедро', thighController, isDark, Icons.airline_seat_legroom_extra)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMeasurementField('Икра', calfController, isDark, Icons.airline_seat_legroom_extra)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMeasurementField('Шея (см)', neckController, isDark, Icons.panorama_fish_eye),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(labelText: 'Заметки', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                if (selectedImage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите фото')));
                  return;
                }
                await provider.addPhoto(
                  imageUrl: selectedImage!.path,
                  label: labelController.text.isNotEmpty ? labelController.text : null,
                  weight: double.tryParse(weightController.text),
                  notes: notesController.text.isNotEmpty ? notesController.text : null,
                  chest: double.tryParse(chestController.text),
                  waist: double.tryParse(waistController.text),
                  hips: double.tryParse(hipsController.text),
                  biceps: double.tryParse(bicepsController.text),
                  thigh: double.tryParse(thighController.text),
                  calf: double.tryParse(calfController.text),
                  neck: double.tryParse(neckController.text),
                  forearm: double.tryParse(forearmController.text),
                );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Добавить', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementField(String label, TextEditingController controller, bool isDark, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        labelStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context, bool isDark, Function(ImageSource) onPick) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        title: const Text('Выберите источник'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF6B35)),
              ),
              title: const Text('Камера'),
              subtitle: const Text('Сделать новое фото', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                onPick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF4A9BFF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF4A9BFF)),
              ),
              title: const Text('Галерея'),
              subtitle: const Text('Выбрать из сохранённых', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                onPick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPhotoDialog(BuildContext context, bool isDark, FitnessPhoto photo, FitnessProvider provider) {
    final labelController = TextEditingController(text: photo.label);
    final weightController = TextEditingController(text: photo.weight?.toString() ?? '');
    final notesController = TextEditingController(text: photo.notes);
    final chestController = TextEditingController(text: photo.chest?.toString() ?? '');
    final waistController = TextEditingController(text: photo.waist?.toString() ?? '');
    final hipsController = TextEditingController(text: photo.hips?.toString() ?? '');
    final bicepsController = TextEditingController(text: photo.biceps?.toString() ?? '');
    final thighController = TextEditingController(text: photo.thigh?.toString() ?? '');
    final calfController = TextEditingController(text: photo.calf?.toString() ?? '');
    final neckController = TextEditingController(text: photo.neck?.toString() ?? '');
    final forearmController = TextEditingController(text: photo.forearm?.toString() ?? '');
    bool showMeasurements = photo.measurementsCount > 1 || photo.chest != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
          title: Text('Редактировать', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: labelController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Подпись', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextField(controller: weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Вес (кг)', prefixIcon: const Icon(Icons.monitor_weight_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setDialogState(() => showMeasurements = !showMeasurements),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: showMeasurements ? const Color(0xFFFF6B35).withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: showMeasurements ? const Color(0xFFFF6B35).withOpacity(0.5) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.straighten_rounded, color: showMeasurements ? const Color(0xFFFF6B35) : Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Обхваты тела', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                        Icon(showMeasurements ? Icons.expand_less : Icons.expand_more, color: isDark ? Colors.white54 : Colors.grey),
                      ],
                    ),
                  ),
                ),
                if (showMeasurements) ...[
                  const SizedBox(height: 12),
                  _buildMeasurementField('Грудь (см)', chestController, isDark, Icons.favorite_outline),
                  const SizedBox(height: 8),
                  _buildMeasurementField('Талия (см)', waistController, isDark, Icons.hourglass_empty),
                  const SizedBox(height: 8),
                  _buildMeasurementField('Бёдра (см)', hipsController, isDark, Icons.water_drop_outlined),
                  const SizedBox(height: 8),
                  Row(children: [Expanded(child: _buildMeasurementField('Бицепс', bicepsController, isDark, Icons.fitness_center)), const SizedBox(width: 8), Expanded(child: _buildMeasurementField('Предплечье', forearmController, isDark, Icons.fitness_center))]),
                  const SizedBox(height: 8),
                  Row(children: [Expanded(child: _buildMeasurementField('Бедро', thighController, isDark, Icons.airline_seat_legroom_extra)), const SizedBox(width: 8), Expanded(child: _buildMeasurementField('Икра', calfController, isDark, Icons.airline_seat_legroom_extra))]),
                  const SizedBox(height: 8),
                  _buildMeasurementField('Шея (см)', neckController, isDark, Icons.panorama_fish_eye),
                ],
                const SizedBox(height: 12),
                TextField(controller: notesController, maxLines: 2, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Заметки', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                final updated = photo.copyWith(
                  label: labelController.text.isNotEmpty ? labelController.text : null,
                  weight: double.tryParse(weightController.text),
                  notes: notesController.text.isNotEmpty ? notesController.text : null,
                  chest: double.tryParse(chestController.text),
                  waist: double.tryParse(waistController.text),
                  hips: double.tryParse(hipsController.text),
                  biceps: double.tryParse(bicepsController.text),
                  thigh: double.tryParse(thighController.text),
                  calf: double.tryParse(calfController.text),
                  neck: double.tryParse(neckController.text),
                  forearm: double.tryParse(forearmController.text),
                  clearChest: chestController.text.isEmpty,
                  clearWaist: waistController.text.isEmpty,
                  clearHips: hipsController.text.isEmpty,
                  clearBiceps: bicepsController.text.isEmpty,
                  clearThigh: thighController.text.isEmpty,
                  clearCalf: calfController.text.isEmpty,
                  clearNeck: neckController.text.isEmpty,
                  clearForearm: forearmController.text.isEmpty,
                );
                await provider.updatePhoto(updated);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePhoto(BuildContext context, bool isDark, FitnessPhoto photo, FitnessProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить фото?'),
        content: const Text('Фото будет удалено безвозвратно'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              await provider.deletePhoto(photo.id);
              // Удаляем файл с диска
              try {
                final file = File(photo.imageUrl);
                if (file.existsSync()) await file.delete();
              } catch (_) {}
              Navigator.pop(ctx);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getDaysBetween(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    if (days < 30) return '$days дн.';
    if (days < 365) return '${(days / 30).round()} мес.';
    return '${(days / 365).toStringAsFixed(1)} г.';
  }
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ КЛАССЫ ====================

class _MeasurementItem {
  final String name;
  final String unit;
  final double? before;
  final double? after;
  final bool isWeight;
  final bool smallerIsBetter;

  String get icon {
    if (isWeight) return '⚖️';
    if (name == 'Грудь') return '👕';
    if (name == 'Талия') return '⏳';
    if (name == 'Бёдра') return '👖';
    if (name == 'Бицепс') return '💪';
    if (name == 'Бедро') return '🦵';
    if (name == 'Икра') return '🦵';
    if (name == 'Шея') return '👔';
    if (name == 'Предплечье') return '💪';
    return '📏';
  }

  _MeasurementItem(this.name, this.unit, this.before, this.after, {this.isWeight = false, this.smallerIsBetter = false});
}

class _HalfClipper extends CustomClipper<Rect> {
  final double position;
  _HalfClipper(this.position);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width * position, size.height);

  @override
  bool shouldReclip(_HalfClipper oldClipper) => oldClipper.position != position;
}