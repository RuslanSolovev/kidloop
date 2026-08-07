// features/life_navigator/ui/widgets/tasks/tasks_add_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';
import 'tasks_constants.dart';

class TasksAddDialog extends StatefulWidget {
  final bool isDark;
  final LifeProvider provider;
  final LifeTask? parentTask;
  const TasksAddDialog({super.key, required this.isDark, required this.provider, this.parentTask});
  @override
  State<TasksAddDialog> createState() => _TasksAddDialogState();
}

class _TasksAddDialogState extends State<TasksAddDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  String _priority = 'medium';
  DateTime? _deadline;
  TimeOfDay? _time;
  bool _hasReminder = false;
  List<String> _tags = [];
  List<String> _images = [];
  bool _isLoading = false;
  final int _maxImages = 5;
  List<_SubtaskNode> _subtaskNodes = [];

  @override
  void dispose() {
    _titleController.dispose(); _descriptionController.dispose(); _tagController.dispose();
    for (final node in _subtaskNodes) node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canHaveSubtasks = widget.parentTask == null;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: widget.isDark ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)] : [Colors.white, const Color(0xFFF8F9FA)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildHandle(), const SizedBox(height: 16),
          _buildHeader(widget.parentTask != null), const SizedBox(height: 16),
          _buildTitleField(), const SizedBox(height: 12),
          _buildDescriptionField(), const SizedBox(height: 12),
          _buildPrioritySelector(), const SizedBox(height: 12),
          _buildDeadlineField(), const SizedBox(height: 12),
          _buildReminderSection(), const SizedBox(height: 12),
          _buildTags(), const SizedBox(height: 12),
          _buildPhotos(_images, (img) => setState(() => _images = img)), const SizedBox(height: 12),
          if (canHaveSubtasks) _buildSubtasksSection(), const SizedBox(height: 16),
          _buildButtons(),
        ]),
      ),
    );
  }

  Widget _buildHandle() => Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))));

  Widget _buildHeader(bool isSubtask) => Row(children: [
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]), borderRadius: BorderRadius.circular(12)), child: Icon(isSubtask ? Icons.subdirectory_arrow_right_rounded : Icons.task_rounded, color: Colors.white, size: 20)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isSubtask ? 'Новая подзадача' : 'Новая задача', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black87)),
      if (isSubtask) Text('Для: ${widget.parentTask!.title}', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)
      else Text('Заполните все поля', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)),
    ])),
  ]);

  Widget _buildTitleField() => TextField(controller: _titleController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Название *', labelStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));

  Widget _buildDescriptionField() => TextField(controller: _descriptionController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87), maxLines: 3, decoration: InputDecoration(labelText: 'Описание', labelStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));

  Widget _buildPrioritySelector() => DropdownButtonFormField<String>(value: _priority, dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13), decoration: InputDecoration(labelText: 'Приоритет', labelStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), items: TasksConstants.priorities.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text('${p['emoji']} ${p['label']}'))).toList(), onChanged: (v) => setState(() => _priority = v!));

  Widget _buildDeadlineField() => GestureDetector(
    onTap: () async { final date = await showDatePicker(context: context, initialDate: _deadline ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030)); if (date != null) setState(() => _deadline = date); },
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: _deadline != null ? const Color(0xFFFF6B35).withOpacity(0.3) : Colors.transparent, width: 1.5)), child: Row(children: [Icon(Icons.calendar_today_rounded, color: const Color(0xFFFF6B35).withOpacity(0.6), size: 18), const SizedBox(width: 10), Text(_deadline != null ? '${_deadline!.day}.${_deadline!.month}.${_deadline!.year}' : 'Дедлайн', style: TextStyle(fontSize: 14, color: _deadline != null ? (widget.isDark ? Colors.white : Colors.black87) : (widget.isDark ? Colors.white54 : Colors.grey.shade500)))])),
  );

  Widget _buildReminderSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text('Напомнить', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white70 : Colors.grey.shade700)), subtitle: Text(_hasReminder ? 'Напоминание включено' : 'Без напоминания', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500)), value: _hasReminder, activeColor: const Color(0xFFFF6B35), onChanged: (v) => setState(() => _hasReminder = v)),
    if (_hasReminder) ...[const SizedBox(height: 8),
      GestureDetector(onTap: () async { final time = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0)); if (time != null) setState(() => _time = time); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: _time != null ? Colors.purple.withOpacity(0.3) : Colors.transparent, width: 1.5)), child: Row(children: [Icon(Icons.access_time_rounded, color: Colors.purple.withOpacity(0.6), size: 18), const SizedBox(width: 10), Text(_time != null ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}' : 'Время напоминания', style: TextStyle(fontSize: 14, color: _time != null ? (widget.isDark ? Colors.white : Colors.black87) : (widget.isDark ? Colors.white54 : Colors.grey.shade500)))]))),
    ],
  ]);

  Widget _buildTags() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: TextField(controller: _tagController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13), decoration: InputDecoration(hintText: 'Добавить тег...', hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade400, fontSize: 12), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), onSubmitted: _addTag)),
      const SizedBox(width: 8),
      GestureDetector(onTap: () => _addTag(_tagController.text), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.add_rounded, color: const Color(0xFFFF6B35), size: 18))),
    ]),
    if (_tags.isNotEmpty) ...[const SizedBox(height: 6), Wrap(spacing: 4, runSpacing: 4, children: _tags.map((tag) => Chip(label: Text('#$tag', style: const TextStyle(fontSize: 11)), deleteIcon: Icon(Icons.close_rounded, size: 14), onDeleted: () => setState(() => _tags.remove(tag)), backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 4))).toList())],
  ]);

  Widget _buildPhotos(List<String> images, Function(List<String>) onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Фото (до $_maxImages)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)), const SizedBox(height: 6),
    SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: images.length + (images.length < _maxImages ? 1 : 0), itemBuilder: (ctx, index) {
      if (index == images.length) return GestureDetector(onTap: () => _addImage(images, onChanged), child: Container(width: 80, height: 80, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300, width: 2)), child: Icon(Icons.add_photo_alternate_outlined, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade400, size: 28)));
      return Stack(children: [
        Container(width: 80, height: 80, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: _getImageProvider(images[index]), fit: BoxFit.cover))),
        Positioned(top: 2, right: 8, child: GestureDetector(onTap: () { final newImages = List<String>.from(images)..removeAt(index); onChanged(newImages); }, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 12)))),
      ]);
    })),
  ]);

  Widget _buildSubtasksSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Text('Подзадачи', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)), const Spacer(), GestureDetector(onTap: () => setState(() => _subtaskNodes.add(_SubtaskNode())), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 14, color: const Color(0xFFFF6B35)), const SizedBox(width: 4), Text('Добавить', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B35)))])))]),
    if (_subtaskNodes.isEmpty) ...[const SizedBox(height: 4), Text('Нет подзадач', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade400))]
    else ...[const SizedBox(height: 8), ..._subtaskNodes.asMap().entries.map((e) => _buildSubtaskNode(e.value, e.key))],
  ]);

  Widget _buildSubtaskNode(_SubtaskNode node, int index) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.red.withOpacity(0.15))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [const Color(0xFFFF6B35).withOpacity(0.3), const Color(0xFFFF6B35).withOpacity(0.1)])), child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : const Color(0xFFFF6B35))))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: node.titleController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Название подзадачи', hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade400, fontSize: 13), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
      IconButton(icon: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade300), onPressed: () { setState(() { node.dispose(); _subtaskNodes.remove(node); }); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
    ]),
    const SizedBox(height: 8),
    TextField(controller: node.descriptionController, style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.black54, fontSize: 12), maxLines: 2, decoration: InputDecoration(hintText: 'Описание', hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade400, fontSize: 11), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true)),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(value: node.priority, dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 12), decoration: InputDecoration(labelText: 'Приоритет', labelStyle: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), isDense: true), items: TasksConstants.priorities.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text('${p['emoji']} ${p['label']}', style: const TextStyle(fontSize: 11)))).toList(), onChanged: (v) => setState(() => node.priority = v!)),
    const SizedBox(height: 8),
    GestureDetector(onTap: () async { final date = await showDatePicker(context: context, initialDate: node.deadline ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030)); if (date != null) setState(() => node.deadline = date); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: node.deadline != null ? const Color(0xFFFF6B35).withOpacity(0.3) : Colors.transparent)), child: Row(children: [Icon(Icons.calendar_today_rounded, size: 14, color: const Color(0xFFFF6B35).withOpacity(0.6)), const SizedBox(width: 6), Text(node.deadline != null ? '${node.deadline!.day}.${node.deadline!.month}.${node.deadline!.year}' : 'Дедлайн', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.grey.shade500))]))),
    const SizedBox(height: 8),
    Row(children: [Text('Напомнить', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade600)), Switch(value: node.hasReminder, onChanged: (v) => setState(() => node.hasReminder = v), activeColor: const Color(0xFFFF6B35), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), if (node.hasReminder) ...[const Spacer(), GestureDetector(onTap: () async { final time = await showTimePicker(context: context, initialTime: node.time ?? const TimeOfDay(hour: 9, minute: 0)); if (time != null) setState(() => node.time = time); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.access_time_rounded, size: 12, color: Colors.purple), const SizedBox(width: 4), Text(node.time != null ? '${node.time!.hour.toString().padLeft(2, '0')}:${node.time!.minute.toString().padLeft(2, '0')}' : 'Время', style: TextStyle(fontSize: 10, color: Colors.purple))])))]]),
    const SizedBox(height: 8),
    _buildPhotos(node.images, (img) => setState(() => node.images = img)),
    const SizedBox(height: 8),
    _buildSubSubtasksSection(node),
  ]));

  Widget _buildSubSubtasksSection(_SubtaskNode parentNode) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Text('Подподзадачи', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white.withOpacity(0.38) : Colors.grey.shade500)), const Spacer(), GestureDetector(onTap: () => setState(() => parentNode.children.add(_SubtaskNode())), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 12, color: const Color(0xFFFF6B35)), const SizedBox(width: 2), Text('Добавить', style: TextStyle(fontSize: 10, color: const Color(0xFFFF6B35), fontWeight: FontWeight.w600))])))]),
    if (parentNode.children.isNotEmpty) ...[const SizedBox(height: 6), ...parentNode.children.asMap().entries.map((e) => _buildSubSubtaskNode(e.value, e.key, parentNode))],
  ]);

  Widget _buildSubSubtaskNode(_SubtaskNode node, int index, _SubtaskNode parent) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.15))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.2)), child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.blue.shade300)))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: node.titleController, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13), decoration: InputDecoration(hintText: 'Название подподзадачи', hintStyle: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
      IconButton(icon: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade300), onPressed: () { setState(() { node.dispose(); parent.children.remove(node); }); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
    ]),
    const SizedBox(height: 6),
    TextField(controller: node.descriptionController, style: TextStyle(color: widget.isDark ? Colors.white60 : Colors.black54, fontSize: 11), maxLines: 1, decoration: InputDecoration(hintText: 'Описание', hintStyle: TextStyle(color: widget.isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade400, fontSize: 10), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), isDense: true)),
    const SizedBox(height: 6),
    Row(children: [
      Expanded(child: DropdownButtonFormField<String>(value: node.priority, dropdownColor: widget.isDark ? const Color(0xFF2A2D35) : Colors.white, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 10), decoration: InputDecoration(filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), isDense: true), items: TasksConstants.priorities.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text('${p['emoji']} ${p['label']}', style: const TextStyle(fontSize: 10)))).toList(), onChanged: (v) => setState(() => node.priority = v!))),
      const SizedBox(width: 4),
      Expanded(child: GestureDetector(onTap: () async { final date = await showDatePicker(context: context, initialDate: node.deadline ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030)); if (date != null) setState(() => node.deadline = date); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: Row(children: [Icon(Icons.calendar_today_rounded, size: 10, color: const Color(0xFFFF6B35).withOpacity(0.6)), const SizedBox(width: 2), Text(node.deadline != null ? '${node.deadline!.day}.${node.deadline!.month}' : 'Дедлайн', style: TextStyle(fontSize: 9, color: widget.isDark ? Colors.white54 : Colors.grey.shade500))])))),
    ]),
    const SizedBox(height: 4),
    Row(children: [Text('Напомнить', style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade500)), Switch(value: node.hasReminder, onChanged: (v) => setState(() => node.hasReminder = v), activeColor: const Color(0xFFFF6B35), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), if (node.hasReminder) ...[const Spacer(), GestureDetector(onTap: () async { final time = await showTimePicker(context: context, initialTime: node.time ?? const TimeOfDay(hour: 9, minute: 0)); if (time != null) setState(() => node.time = time); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(node.time != null ? '${node.time!.hour.toString().padLeft(2, '0')}:${node.time!.minute.toString().padLeft(2, '0')}' : 'Время', style: TextStyle(fontSize: 9, color: Colors.purple))))]]),
    const SizedBox(height: 6),
    _buildPhotos(node.images, (img) => setState(() => node.images = img)),
  ]));

  Widget _buildButtons() => Row(children: [
    Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Создать', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)))),
    const SizedBox(width: 10),
    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: widget.isDark ? Colors.white.withOpacity(0.24) : Colors.grey.shade300)), child: Text('Отмена', style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 14)))),
  ]);

  void _save() {
    if (_titleController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите название задачи'), backgroundColor: Colors.red)); return; }
    setState(() => _isLoading = true);
    final subtaskData = _collectSubtaskData(_subtaskNodes);
    widget.provider.addTask(title: _titleController.text.trim(), description: _descriptionController.text.trim(), priority: _priority, status: 'formulated', deadline: _deadline, tags: _tags, parentId: widget.parentTask?.id, images: _images.isNotEmpty ? _images : null, hasReminder: _hasReminder, reminderMinutes: 15, reminderTime: _time).then((mainTask) async {
      await _createSubtasks(mainTask.id, subtaskData);
      if (mounted) { setState(() => _isLoading = false); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(subtaskData.isEmpty ? '✅ Задача "${_titleController.text.trim()}" создана' : '✅ Задача создана с ${_countSubtasks(subtaskData)} подзадачами'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
    }).catchError((e) { if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)); } });
  }

  List<_SubtaskData> _collectSubtaskData(List<_SubtaskNode> nodes) {
    final result = <_SubtaskData>[];
    for (final node in nodes) {
      if (node.titleController.text.trim().isNotEmpty) {
        result.add(_SubtaskData(title: node.titleController.text.trim(), description: node.descriptionController.text.trim(), priority: node.priority, deadline: node.deadline, hasReminder: node.hasReminder, reminderTime: node.time, images: node.images, children: _collectSubtaskData(node.children)));
      }
    }
    return result;
  }

  Future<void> _createSubtasks(String parentId, List<_SubtaskData> subtasks) async {
    for (final data in subtasks) {
      final newSubtask = await widget.provider.addTask(title: data.title, description: data.description, priority: data.priority, status: 'formulated', deadline: data.deadline, parentId: parentId, hasReminder: data.hasReminder, reminderTime: data.reminderTime, images: data.images.isNotEmpty ? data.images : null);
      if (data.children.isNotEmpty) await _createSubtasks(newSubtask.id, data.children);
    }
  }

  int _countSubtasks(List<_SubtaskData> subtasks) { int c = subtasks.length; for (final d in subtasks) c += _countSubtasks(d.children); return c; }

  ImageProvider _getImageProvider(String path) => path.startsWith('http') ? NetworkImage(path) : FileImage(File(path));

  void _addTag(String tag) { final t = tag.trim().toLowerCase(); if (t.isNotEmpty && !_tags.contains(t)) { setState(() { _tags.add(t); _tagController.clear(); }); } }

  Future<void> _addImage(List<String> images, Function(List<String>) onChanged) async {
    try {
      final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
      if (image != null && images.length < _maxImages) { final newImages = List<String>.from(images)..add(image.path); onChanged(newImages); }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)); }
  }
}

class _SubtaskNode {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  String priority;
  DateTime? deadline;
  TimeOfDay? time;
  bool hasReminder;
  List<String> images;
  final List<_SubtaskNode> children;

  _SubtaskNode({this.priority = 'medium', this.deadline, this.time, this.hasReminder = false})
      : titleController = TextEditingController(), descriptionController = TextEditingController(), images = [], children = [];

  void dispose() { titleController.dispose(); descriptionController.dispose(); for (final child in children) child.dispose(); }
}

class _SubtaskData {
  final String title, description, priority;
  final DateTime? deadline;
  final bool hasReminder;
  final TimeOfDay? reminderTime;
  final List<String> images;
  final List<_SubtaskData> children;

  _SubtaskData({required this.title, required this.description, required this.priority, this.deadline, this.hasReminder = false, this.reminderTime, this.images = const [], this.children = const []});
}