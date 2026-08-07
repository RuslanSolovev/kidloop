// features/life_navigator/ui/widgets/ideas/ideas_add_edit.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';
import 'ideas_common.dart';

// ============================================================
// ДИАЛОГ ДОБАВЛЕНИЯ
// ============================================================

class AddIdeaSheet extends StatefulWidget {
  final bool isDark;
  final LifeProvider provider;
  final VoidCallback onClose;

  const AddIdeaSheet({
    super.key,
    required this.isDark,
    required this.provider,
    required this.onClose,
  });

  @override
  State<AddIdeaSheet> createState() => _AddIdeaSheetState();
}

class _AddIdeaSheetState extends State<AddIdeaSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'business';
  int _impact = 5;
  int _confidence = 5;
  int _ease = 5;
  int _priority = 5;
  int _rating = 3;
  bool _isLoading = false;
  final List<String> _images = [];
  final int _maxImages = 5;

  final categories = const [
    {'id': 'business', 'label': 'Бизнес', 'emoji': '💼', 'color': Color(0xFF4A9EFF)},
    {'id': 'creative', 'label': 'Творчество', 'emoji': '🎨', 'color': Color(0xFFFF6B9D)},
    {'id': 'tech', 'label': 'Технологии', 'emoji': '💻', 'color': Color(0xFF00BCD4)},
    {'id': 'home', 'label': 'Дом', 'emoji': '🏠', 'color': Color(0xFFFFA726)},
    {'id': 'health', 'label': 'Здоровье', 'emoji': '❤️', 'color': Color(0xFFFF1744)},
    {'id': 'education', 'label': 'Образование', 'emoji': '📚', 'color': Color(0xFF7C4DFF)},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iceScore = (_impact + _confidence + _ease) / 3;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Новая задача',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                        ),
                      ),
                      Text(
                        'Запишите свою задачу',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'Название',
                labelStyle: TextStyle(
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Описание',
                labelStyle: TextStyle(
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Категория',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: categories.map((cat) {
                final isSelected = _category == cat['id'];
                final color = cat['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat['id'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                        colors: [
                          color.withOpacity(0.15),
                          color.withOpacity(0.05),
                        ],
                      )
                          : null,
                      color: isSelected
                          ? null
                          : (widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat['emoji'] as String,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cat['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? color : (widget.isDark ? Colors.white70 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Фото (до 5 штук)
            Text(
              'Фото (до $_maxImages)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length + (_images.length < _maxImages ? 1 : 0),
                itemBuilder: (ctx, index) {
                  if (index == _images.length) {
                    return GestureDetector(
                      onTap: _addImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
                          size: 32,
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: getImageProvider(_images[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Рейтинг:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(5, (index) {
                  final star = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 28,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'Приоритет:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ),
                Expanded(
                  child: SliderRow(
                    label: '',
                    value: _priority,
                    onChanged: (v) => setState(() => _priority = v),
                    color: _getPriorityColor(_priority),
                    isDark: widget.isDark,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$_priority',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _getPriorityColor(_priority),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                    widget.isDark ? Colors.white.withOpacity(0.01) : Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '📊 ICE (Срочность, Трудность, Интерес)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getIceColor(iceScore).withOpacity(0.15),
                              _getIceColor(iceScore).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getIceColor(iceScore).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          iceScore.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _getIceColor(iceScore),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderRow(
                    label: 'Срочность',
                    value: _impact,
                    onChanged: (v) => setState(() => _impact = v),
                    color: _getIceColor(_impact.toDouble()),
                    isDark: widget.isDark,
                  ),
                  SliderRow(
                    label: 'Трудность',
                    value: _confidence,
                    onChanged: (v) => setState(() => _confidence = v),
                    color: _getIceColor(_confidence.toDouble()),
                    isDark: widget.isDark,
                  ),
                  SliderRow(
                    label: 'Интерес',
                    value: _ease,
                    onChanged: (v) => setState(() => _ease = v),
                    color: _getIceColor(_ease.toDouble()),
                    isDark: widget.isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addIdea,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Добавить задачу',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClose,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'Отмена',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                        fontSize: 15,
                      ),
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

  void _addImage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Добавить фото',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ImageSourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Галерея',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromGallery();
                  },
                  isDark: widget.isDark,
                ),
                ImageSourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Камера',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromCamera();
                  },
                  isDark: widget.isDark,
                ),
                ImageSourceButton(
                  icon: Icons.link_rounded,
                  label: 'URL',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(ctx);
                    _addImageByUrl();
                  },
                  isDark: widget.isDark,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (_images.length < _maxImages) {
            _images.add(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выборе фото: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (_images.length < _maxImages) {
            _images.add(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при съемке фото: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addImageByUrl() {
    final TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Введите URL фото'),
        content: TextField(
          controller: urlController,
          decoration: InputDecoration(
            hintText: 'https://example.com/photo.jpg',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          ),
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  if (_images.length < _maxImages) {
                    _images.add(url);
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Добавить', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Color _getIceColor(double score) {
    if (score >= 7) return const Color(0xFF00C853);
    if (score >= 4) return const Color(0xFFFF6B35);
    return const Color(0xFFFF1744);
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 8) return Colors.red;
    if (priority >= 5) return Colors.orange;
    return Colors.blue;
  }

  void _addIdea() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название задачи'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    widget.provider
        .addIdea(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category,
      rating: _rating,
      priority: _priority,
      impact: _impact,
      confidence: _confidence,
      ease: _ease,
      images: _images,
    )
        .then((_) {
      setState(() => _isLoading = false);
      widget.onClose();
    })
        .catchError((e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }
}

// ============================================================
// ДИАЛОГ РЕДАКТИРОВАНИЯ
// ============================================================

class EditIdeaSheet extends StatefulWidget {
  final bool isDark;
  final LifeIdea idea;
  final LifeProvider provider;
  final VoidCallback onClose;

  const EditIdeaSheet({
    super.key,
    required this.isDark,
    required this.idea,
    required this.provider,
    required this.onClose,
  });

  @override
  State<EditIdeaSheet> createState() => _EditIdeaSheetState();
}

class _EditIdeaSheetState extends State<EditIdeaSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _category;
  late int _impact;
  late int _confidence;
  late int _ease;
  late int _priority;
  late int _rating;
  late List<String> _images;
  final int _maxImages = 5;
  bool _isLoading = false;

  final categories = const [
    {'id': 'business', 'label': 'Бизнес', 'emoji': '💼', 'color': Color(0xFF4A9EFF)},
    {'id': 'creative', 'label': 'Творчество', 'emoji': '🎨', 'color': Color(0xFFFF6B9D)},
    {'id': 'tech', 'label': 'Технологии', 'emoji': '💻', 'color': Color(0xFF00BCD4)},
    {'id': 'home', 'label': 'Дом', 'emoji': '🏠', 'color': Color(0xFFFFA726)},
    {'id': 'health', 'label': 'Здоровье', 'emoji': '❤️', 'color': Color(0xFFFF1744)},
    {'id': 'education', 'label': 'Образование', 'emoji': '📚', 'color': Color(0xFF7C4DFF)},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.idea.title);
    _descController = TextEditingController(text: widget.idea.description);
    _category = widget.idea.category;
    _impact = widget.idea.impact;
    _confidence = widget.idea.confidence;
    _ease = widget.idea.ease;
    _priority = widget.idea.priority;
    _rating = widget.idea.rating;
    _images = List.from(widget.idea.images);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iceScore = (_impact + _confidence + _ease) / 3;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Редактировать задачу',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white : const Color(0xFF1A1D24),
                        ),
                      ),
                      Text(
                        'Измените данные задачи',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'Название',
                labelStyle: TextStyle(
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Описание',
                labelStyle: TextStyle(
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Категория',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: categories.map((cat) {
                final isSelected = _category == cat['id'];
                final color = cat['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat['id'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                        colors: [
                          color.withOpacity(0.15),
                          color.withOpacity(0.05),
                        ],
                      )
                          : null,
                      color: isSelected
                          ? null
                          : (widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat['emoji'] as String,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cat['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? color : (widget.isDark ? Colors.white70 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Фото (до 5 штук)
            Text(
              'Фото (до $_maxImages)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length + (_images.length < _maxImages ? 1 : 0),
                itemBuilder: (ctx, index) {
                  if (index == _images.length) {
                    return GestureDetector(
                      onTap: _addImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
                          size: 32,
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: getImageProvider(_images[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Рейтинг:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(5, (index) {
                  final star = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 28,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'Приоритет:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ),
                Expanded(
                  child: SliderRow(
                    label: '',
                    value: _priority,
                    onChanged: (v) => setState(() => _priority = v),
                    color: _getPriorityColor(_priority),
                    isDark: widget.isDark,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$_priority',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _getPriorityColor(_priority),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                    widget.isDark ? Colors.white.withOpacity(0.01) : Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '📊 ICE (Срочность, Трудность, Интерес)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getIceColor(iceScore).withOpacity(0.15),
                              _getIceColor(iceScore).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getIceColor(iceScore).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          iceScore.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _getIceColor(iceScore),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderRow(
                    label: 'Срочность',
                    value: _impact,
                    onChanged: (v) => setState(() => _impact = v),
                    color: _getIceColor(_impact.toDouble()),
                    isDark: widget.isDark,
                  ),
                  SliderRow(
                    label: 'Трудность',
                    value: _confidence,
                    onChanged: (v) => setState(() => _confidence = v),
                    color: _getIceColor(_confidence.toDouble()),
                    isDark: widget.isDark,
                  ),
                  SliderRow(
                    label: 'Интерес',
                    value: _ease,
                    onChanged: (v) => setState(() => _ease = v),
                    color: _getIceColor(_ease.toDouble()),
                    isDark: widget.isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateIdea,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Сохранить',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClose,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'Отмена',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                        fontSize: 15,
                      ),
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

  void _addImage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Добавить фото',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ImageSourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Галерея',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromGallery();
                  },
                  isDark: widget.isDark,
                ),
                ImageSourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Камера',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromCamera();
                  },
                  isDark: widget.isDark,
                ),
                ImageSourceButton(
                  icon: Icons.link_rounded,
                  label: 'URL',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(ctx);
                    _addImageByUrl();
                  },
                  isDark: widget.isDark,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (_images.length < _maxImages) {
            _images.add(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выборе фото: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (_images.length < _maxImages) {
            _images.add(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при съемке фото: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addImageByUrl() {
    final TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Введите URL фото'),
        content: TextField(
          controller: urlController,
          decoration: InputDecoration(
            hintText: 'https://example.com/photo.jpg',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          ),
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  if (_images.length < _maxImages) {
                    _images.add(url);
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Добавить', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Color _getIceColor(double score) {
    if (score >= 7) return const Color(0xFF00C853);
    if (score >= 4) return const Color(0xFFFF6B35);
    return const Color(0xFFFF1744);
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 8) return Colors.red;
    if (priority >= 5) return Colors.orange;
    return Colors.blue;
  }

  void _updateIdea() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название задачи'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final updated = widget.idea.copyWith(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category,
      impact: _impact,
      confidence: _confidence,
      ease: _ease,
      priority: _priority,
      rating: _rating,
      images: _images,
    );

    widget.provider
        .updateIdea(updated)
        .then((_) {
      setState(() => _isLoading = false);
      widget.onClose();
    })
        .catchError((e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }
}