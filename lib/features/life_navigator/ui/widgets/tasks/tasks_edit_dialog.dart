// features/life_navigator/ui/widgets/tasks/tasks_edit_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';
import 'tasks_constants.dart';

class TasksEditDialog extends StatefulWidget {
  final bool isDark;
  final LifeTask task;
  final LifeProvider provider;
  final VoidCallback onClose;
  final VoidCallback? onTaskUpdated;

  const TasksEditDialog({
    super.key,
    required this.isDark,
    required this.task,
    required this.provider,
    required this.onClose,
    this.onTaskUpdated,
  });

  @override
  State<TasksEditDialog> createState() => _TasksEditDialogState();
}

class _TasksEditDialogState extends State<TasksEditDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();

  String _priority = 'medium';
  DateTime? _deadline;
  TimeOfDay? _time;
  bool _hasReminder = false;
  int _reminderMinutes = 15;
  List<String> _tags = [];
  List<String> _images = [];
  bool _isLoading = false;
  final int _maxImages = 5;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.task.title;
    _descriptionController.text = widget.task.description;
    _priority = widget.task.priority;
    _deadline = widget.task.deadline;
    _time = widget.task.reminderTime;
    _hasReminder = widget.task.hasReminder ?? false;
    _reminderMinutes = widget.task.reminderMinutes ?? 15;
    _tags = List.from(widget.task.tags);
    _images = List.from(widget.task.images ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 16),
            _buildTitleField(),
            const SizedBox(height: 12),
            _buildDescriptionField(),
            const SizedBox(height: 12),
            _buildPrioritySelector(),
            const SizedBox(height: 12),
            _buildReminderSection(),
            const SizedBox(height: 12),
            _buildTags(),
            const SizedBox(height: 12),
            _buildPhotos(),
            const SizedBox(height: 16),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Редактировать задачу',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Измените данные задачи',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: 'Название *',
        labelStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descriptionController,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Описание',
        labelStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return DropdownButtonFormField<String>(
      value: _priority,
      dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Приоритет',
        labelStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: TasksConstants.priorities.map((p) {
        return DropdownMenuItem(
          value: p['id'] as String,
          child: Text('${p['emoji']} ${p['label']}'),
        );
      }).toList(),
      onChanged: (v) => setState(() => _priority = v!),
    );
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Напомнить',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white70 : Colors.grey.shade700),
          ),
          subtitle: Text(
            _hasReminder ? 'Напоминание включено' : 'Без напоминания',
            style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
          ),
          value: _hasReminder,
          activeColor: const Color(0xFFFF6B35),
          onChanged: (v) => setState(() => _hasReminder = v),
        ),
        if (_hasReminder) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _deadline = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _deadline != null ? const Color(0xFFFF6B35).withOpacity(0.3) : Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: const Color(0xFFFF6B35).withOpacity(0.6), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _deadline != null ? '${_deadline!.day}.${_deadline!.month}.${_deadline!.year}' : 'Дата',
                          style: TextStyle(color: _deadline != null ? (widget.isDark ? Colors.white : Colors.black87) : (widget.isDark ? Colors.white54 : Colors.grey.shade500), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time != null) setState(() => _time = time);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      border: Border.all(color: _time != null ? const Color(0xFFFF6B35).withOpacity(0.3) : Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: const Color(0xFFFF6B35).withOpacity(0.6), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _time != null ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}' : 'Время',
                          style: TextStyle(color: _time != null ? (widget.isDark ? Colors.white : Colors.black87) : (widget.isDark ? Colors.white54 : Colors.grey.shade500), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Добавить тег...',
                  hintStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 12),
                  filled: true,
                  fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addTag(_tagController.text),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.add_rounded, color: const Color(0xFFFF6B35), size: 18),
              ),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4, runSpacing: 4,
            children: _tags.map((tag) => Chip(
              label: Text('#$tag', style: const TextStyle(fontSize: 11)),
              deleteIcon: Icon(Icons.close_rounded, size: 14),
              onDeleted: () => setState(() => _tags.remove(tag)),
              backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Фото (до $_maxImages)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
            const Spacer(),
            if (_images.length < _maxImages)
              GestureDetector(
                onTap: _addImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: const Color(0xFFFF6B35)),
                      const SizedBox(width: 2),
                      Text('Добавить', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B35))),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 100, // увеличен размер
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            itemBuilder: (ctx, index) {
              return Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(image: _getImageProvider(_images[index]), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 2, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.removeAt(index)),
                      child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 12)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: _isLoading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onClose,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)),
            child: Text('Отмена', style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return NetworkImage(path);
    return FileImage(File(path));
  }

  void _addTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() { _tags.add(trimmed); _tagController.clear(); });
    }
  }

  Future<void> _addImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
      if (image != null && _images.length < _maxImages) {
        setState(() => _images.add(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка при выборе фото: $e'), backgroundColor: Colors.red));
    }
  }

  void _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите название задачи'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    final updatedTask = widget.task.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      priority: _priority,
      deadline: _deadline,
      tags: _tags,
      images: _images,
      hasReminder: _hasReminder,
      reminderMinutes: _reminderMinutes,
      reminderTime: _time,
    );
    try {
      await widget.provider.updateTask(updatedTask);
      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.onTaskUpdated != null) widget.onTaskUpdated!();
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Задача "${updatedTask.title}" обновлена'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    }
  }
}