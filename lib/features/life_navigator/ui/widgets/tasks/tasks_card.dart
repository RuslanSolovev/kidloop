// features/life_navigator/ui/widgets/tasks/tasks_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/life_models.dart';
import '../../../providers/life_provider.dart';
import 'tasks_constants.dart';
import 'tasks_details.dart';
import 'tasks_edit_dialog.dart';

class TasksCard extends StatefulWidget {
  final LifeTask task;
  final bool isDark;
  final LifeProvider provider;
  final int depth;
  final bool isExpanded;
  final VoidCallback? onExpandToggle;
  final Function(String) onStatusChanged;
  final VoidCallback? onTaskUpdated;
  final bool isLastChild;

  const TasksCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.provider,
    this.depth = 0,
    this.isExpanded = false,
    this.onExpandToggle,
    required this.onStatusChanged,
    this.onTaskUpdated,
    this.isLastChild = false,
  });

  @override
  State<TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends State<TasksCard>
    with SingleTickerProviderStateMixin {
  late bool _localExpanded;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _localExpanded = widget.isExpanded;
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _expandController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));
    if (_localExpanded) _expandController.value = 1.0;
  }

  @override
  void didUpdateWidget(TasksCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) {
      _localExpanded = widget.isExpanded;
      if (_localExpanded) _expandController.forward();
      else _expandController.reverse();
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.task.statusColor;
    final priorityColor = widget.task.priorityColor;
    final isOverdue = widget.task.deadline != null &&
        widget.task.deadline!.isBefore(DateTime.now()) &&
        widget.task.status != 'done' &&
        widget.task.status != 'postponed';
    final subtasks = widget.provider.tasks.where((t) => t.parentId == widget.task.id).toList();
    final hasSubtasks = subtasks.isNotEmpty;
    final completedSubtasks = subtasks.where((t) => t.status == 'done').length;
    final totalSubtasks = subtasks.length;
    final connectorColor = _getLevelAccent(widget.depth);
    final progressValue = totalSubtasks > 0 ? completedSubtasks / totalSubtasks : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.depth > 0) _buildConnector(connectorColor),
        Expanded(child: GestureDetector(
          onTap: () => _showDetails(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(
              left: 0,
              right: 0,
              bottom: hasSubtasks && _localExpanded ? 2 : 6,
              top: widget.depth > 0 ? 2 : 0,
            ),
            decoration: BoxDecoration(
              gradient: _getLevelGradient(widget.depth),
              borderRadius: BorderRadius.circular(widget.depth == 0 ? 14 : 12),
              boxShadow: [
                BoxShadow(
                  color: _localExpanded && hasSubtasks
                      ? statusColor.withOpacity(widget.isDark ? 0.25 : 0.12)
                      : statusColor.withOpacity(widget.isDark ? 0.12 : 0.06),
                  blurRadius: _localExpanded && hasSubtasks ? 16 : widget.depth == 0 ? 10 : 6,
                  offset: Offset(0, _localExpanded && hasSubtasks ? 6 : widget.depth == 0 ? 4 : 2),
                  spreadRadius: _localExpanded && hasSubtasks ? 2 : 0,
                ),
              ],
              border: Border.all(
                color: isOverdue
                    ? Colors.red.withOpacity(0.5)
                    : _localExpanded && hasSubtasks
                    ? statusColor.withOpacity(0.3)
                    : widget.depth == 0
                    ? statusColor.withOpacity(0.15)
                    : connectorColor.withOpacity(0.12),
                width: _localExpanded && hasSubtasks ? 2.0 : widget.depth == 0 ? 1.5 : 1.0,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _buildStatusHeader(context, statusColor, priorityColor),
              Padding(padding: const EdgeInsets.fromLTRB(14, 12, 10, 12), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTitle(context),
                  if (widget.task.description.isNotEmpty) ...[const SizedBox(height: 8), _buildDescription()],
                  if (widget.task.images != null && widget.task.images!.isNotEmpty) ...[const SizedBox(height: 10), _buildImagePreviews()],
                  if (widget.task.tags.isNotEmpty || widget.task.deadline != null || widget.task.hasReminder == true) ...[const SizedBox(height: 10), _buildMetadata(isOverdue)],
                  if (hasSubtasks) ...[const SizedBox(height: 8), _buildExpandButton(completedSubtasks, totalSubtasks, progressValue)],
                ],
              )),
            ]),
          ),
        )),
      ])),
      if (hasSubtasks) SizeTransition(
        sizeFactor: _expandAnimation,
        axisAlignment: -1.0,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildSubtasksContainer(context, subtasks, connectorColor),
          ),
        ),
      ),
    ]);
  }

  LinearGradient _getLevelGradient(int level) {
    if (widget.isDark) {
      switch (level) {
        case 0: return const LinearGradient(colors: [Color(0xFF1A1D2E), Color(0xFF161928)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        case 1: return const LinearGradient(colors: [Color(0xFF2D1A2A), Color(0xFF261524)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        case 2: return const LinearGradient(colors: [Color(0xFF1A2535), Color(0xFF16202E)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        default: return const LinearGradient(colors: [Color(0xFF252535), Color(0xFF202030)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      }
    } else {
      switch (level) {
        case 0: return const LinearGradient(colors: [Colors.white, Color(0xFFFBFBFC)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        case 1: return const LinearGradient(colors: [Color(0xFFFFF5F5), Color(0xFFFDEBEB)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        case 2: return const LinearGradient(colors: [Color(0xFFF5F8FF), Color(0xFFEBF0FF)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        default: return const LinearGradient(colors: [Color(0xFFF8F8FA), Color(0xFFF2F2F5)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      }
    }
  }

  Widget _buildConnector(Color color) {
    return SizedBox(width: 20, child: CustomPaint(
      painter: _ConnectorPainter(
        color: color,
        isLast: widget.isLastChild,
        hasChildren: widget.task.subtaskIds?.isNotEmpty == true,
        progress: _localExpanded ? _expandAnimation.value : 0.0,
      ),
    ));
  }

  Widget _buildStatusHeader(BuildContext context, Color statusColor, Color priorityColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [statusColor.withOpacity(0.15), statusColor.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(top: Radius.circular(widget.depth == 0 ? 14 : 12)),
        border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.12), width: 1)),
      ),
      child: Row(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 300), width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 6, spreadRadius: 1.5)])),
        const SizedBox(width: 10),
        GestureDetector(onTap: () => _showStatusSelector(context), child: Row(children: [Text(widget.task.statusDisplay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.3)), const SizedBox(width: 3), Icon(Icons.arrow_drop_down_rounded, color: statusColor, size: 18)])),
        const Spacer(),
        if (widget.depth > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _getLevelAccent(widget.depth).withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: _getLevelAccent(widget.depth).withOpacity(0.25), width: 1)), child: Text('Ур.${widget.depth}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _getLevelAccent(widget.depth)))),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(gradient: LinearGradient(colors: [priorityColor.withOpacity(0.15), priorityColor.withOpacity(0.05)]), borderRadius: BorderRadius.circular(8), border: Border.all(color: priorityColor.withOpacity(0.2), width: 1)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(widget.task.priorityEmoji, style: const TextStyle(fontSize: 12)), const SizedBox(width: 5), Text(widget.task.priorityDisplay, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: priorityColor))])),
      ]),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.depth > 0) ...[
        AnimatedContainer(duration: const Duration(milliseconds: 300), width: 24, height: 24, margin: const EdgeInsets.only(top: 1), decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_getLevelAccent(widget.depth).withOpacity(0.25), _getLevelAccent(widget.depth).withOpacity(0.08)]), border: Border.all(color: _getLevelAccent(widget.depth).withOpacity(0.4), width: 2), boxShadow: [BoxShadow(color: _getLevelAccent(widget.depth).withOpacity(0.2), blurRadius: 4, spreadRadius: 0.5)]), child: Center(child: Text('${_getSubtaskNumber()}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _getLevelAccent(widget.depth))))),
        const SizedBox(width: 10),
      ],
      Expanded(child: Text(widget.task.title, style: TextStyle(fontSize: widget.depth == 0 ? 16 : 14, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : const Color(0xFF1A1D24), height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis)),
      GestureDetector(onTap: () => _showEditDialog(context), child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1)), child: Icon(Icons.edit_rounded, size: 15, color: Colors.blue.shade400))),
    ]);
  }

  Widget _buildDescription() {
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))), child: Text(widget.task.description, style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white.withOpacity(0.65) : Colors.grey.shade600, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis));
  }

  Widget _buildImagePreviews() {
    return SizedBox(height: 64, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: widget.task.images!.length.clamp(0, 5), itemBuilder: (ctx, index) => Container(width: 64, height: 64, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: _getImageProvider(widget.task.images![index]), fit: BoxFit.cover), border: Border.all(color: Colors.white.withOpacity(0.3), width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3))]))));
  }

  Widget _buildMetadata(bool isOverdue) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (widget.task.tags.isNotEmpty) ...widget.task.tags.map((tag) { final c = LifeTask.getTagColor(tag); return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withOpacity(0.25), width: 1)), child: Text('#$tag', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c))); }),
      if (widget.task.deadline != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isOverdue ? Colors.red.withOpacity(0.12) : (widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.08)), borderRadius: BorderRadius.circular(8), border: Border.all(color: isOverdue ? Colors.red.withOpacity(0.35) : (widget.isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.18)), width: 1)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.calendar_today_rounded, size: 12, color: isOverdue ? Colors.red.shade400 : (widget.isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)), const SizedBox(width: 5), Text('${widget.task.deadline!.day}.${widget.task.deadline!.month}.${widget.task.deadline!.year}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOverdue ? Colors.red.shade400 : (widget.isDark ? Colors.white.withOpacity(0.7) : Colors.grey.shade700)))])),
      if (widget.task.hasReminder == true && widget.task.reminderTime != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple.withOpacity(0.25), width: 1)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.alarm_rounded, size: 12, color: Colors.purple.withOpacity(0.8)), const SizedBox(width: 5), Text('${widget.task.reminderTime!.hour.toString().padLeft(2, '0')}:${widget.task.reminderTime!.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple.withOpacity(0.8)))])),
    ]);
  }

  Widget _buildExpandButton(int completed, int total, double progress) {
    return GestureDetector(onTap: () { setState(() => _localExpanded = !_localExpanded); if (_localExpanded) _expandController.forward(); else _expandController.reverse(); widget.onExpandToggle?.call(); }, child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: BoxDecoration(gradient: LinearGradient(colors: [(widget.isDark ? Colors.white : Colors.black).withOpacity(0.04), (widget.isDark ? Colors.white : Colors.black).withOpacity(0.02)]), borderRadius: BorderRadius.circular(10), border: Border.all(color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.06), width: 1)), child: Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedRotation(turns: _localExpanded ? 0.25 : 0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, child: Icon(Icons.chevron_right_rounded, size: 18, color: widget.isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600)),
      const SizedBox(width: 8),
      Text(_localExpanded ? 'Скрыть' : 'Подзадачи', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade700)),
      const SizedBox(width: 10),
      Container(width: 60, height: 4, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.1)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: progress, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade300]))))),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: completed == total && total > 0 ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('$completed/$total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: completed == total && total > 0 ? Colors.green.shade600 : Colors.orange.shade600))),
    ])));
  }

  Widget _buildSubtasksContainer(BuildContext context, List<LifeTask> subtasks, Color connectorColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(left: 8, right: 0, bottom: 6),
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [connectorColor.withOpacity(widget.isDark ? 0.08 : 0.05), connectorColor.withOpacity(widget.isDark ? 0.03 : 0.01)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: connectorColor.withOpacity(0.15), width: 1.5),
        boxShadow: [BoxShadow(color: connectorColor.withOpacity(widget.isDark ? 0.08 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: subtasks.asMap().entries.map((entry) {
        final subtask = entry.value;
        final isLast = entry.key == subtasks.length - 1;
        final subSubtasks = widget.provider.tasks.where((t) => t.parentId == subtask.id).toList();
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (entry.key * 60)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 10 * (1 - value)), child: child)),
          child: TasksCard(key: ValueKey(subtask.id), task: subtask, isDark: widget.isDark, provider: widget.provider, depth: widget.depth + 1, isExpanded: false, onExpandToggle: subSubtasks.isNotEmpty ? () {} : null, onStatusChanged: (s) { widget.provider.updateTask(subtask.copyWith(status: s)); widget.onTaskUpdated?.call(); }, onTaskUpdated: widget.onTaskUpdated, isLastChild: isLast),
        );
      }).toList()),
    );
  }

  Color _getLevelAccent(int level) { switch (level) { case 1: return const Color(0xFFE85D5D); case 2: return const Color(0xFF5D7EE8); default: return Colors.grey; } }

  int _getSubtaskNumber() { if (widget.depth <= 0) return 0; final s = widget.provider.tasks.where((t) => t.parentId == widget.task.parentId).toList(); final i = s.indexWhere((t) => t.id == widget.task.id); return i >= 0 ? i + 1 : 0; }

  void _showStatusSelector(BuildContext context) {
    final st = [{'id':'formulated','label':'Сформулирована','emoji':'📝','color':const Color(0xFF4A9EFF)},{'id':'in_progress','label':'В процессе','emoji':'⚡','color':const Color(0xFFFF6B35)},{'id':'done','label':'Готова','emoji':'✅','color':const Color(0xFF00C853)},{'id':'postponed','label':'Отложена','emoji':'⏰','color':const Color(0xFF7C4DFF)}];
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: widget.isDark?[const Color(0xFF1E2233),const Color(0xFF151824)]:[Colors.white,const Color(0xFFF8F9FA)],begin:Alignment.topCenter,end:Alignment.bottomCenter),borderRadius:const BorderRadius.vertical(top:Radius.circular(24))), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width:40,height:4,decoration:BoxDecoration(color:widget.isDark?Colors.white.withOpacity(0.2):Colors.grey.shade300,borderRadius:BorderRadius.circular(2))), const SizedBox(height:20), Text('Изменить статус',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:widget.isDark?Colors.white:const Color(0xFF1A1D24))), const SizedBox(height:16), ...st.map((s){final sel=widget.task.status==s['id'];final c=s['color'] as Color;return GestureDetector(onTap:(){Navigator.pop(ctx);widget.onStatusChanged(s['id'] as String);widget.onTaskUpdated?.call();},child:Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),decoration:BoxDecoration(gradient:sel?LinearGradient(colors:[c.withOpacity(0.15),c.withOpacity(0.05)]):null,color:sel?null:(widget.isDark?Colors.white.withOpacity(0.03):Colors.grey.shade50),borderRadius:BorderRadius.circular(14),border:Border.all(color:sel?c.withOpacity(0.4):Colors.transparent,width:1.5)),child:Row(children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:c.withOpacity(0.1),borderRadius:BorderRadius.circular(10)),child:Text(s['emoji'] as String,style:const TextStyle(fontSize:20))),const SizedBox(width:14),Expanded(child:Text(s['label'] as String,style:TextStyle(fontSize:15,fontWeight:sel?FontWeight.w700:FontWeight.w500,color:sel?c:(widget.isDark?Colors.white:Colors.black87)))),if(sel)Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:c,shape:BoxShape.circle),child:const Icon(Icons.check_rounded,color:Colors.white,size:16))])));}).toList(), const SizedBox(height:12), SizedBox(width:double.infinity,child:OutlinedButton(onPressed:()=>Navigator.pop(ctx),child:Text('Отмена',style:TextStyle(color:widget.isDark?Colors.white60:Colors.grey.shade600))))])));
  }

  void _showEditDialog(BuildContext context) { showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (ctx) => TasksEditDialog(isDark: widget.isDark, task: widget.task, provider: widget.provider, onClose: () => Navigator.pop(ctx), onTaskUpdated: widget.onTaskUpdated)); }
  void _showDetails(BuildContext context) { showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (ctx) => TasksDetailsSheet(isDark: widget.isDark, task: widget.task, provider: widget.provider, onClose: () => Navigator.pop(ctx), onStatusChanged: widget.onStatusChanged, onTaskUpdated: widget.onTaskUpdated)); }

  ImageProvider _getImageProvider(String path) => path.startsWith('http') ? NetworkImage(path) : FileImage(File(path));
}

class _ConnectorPainter extends CustomPainter {
  final Color color; final bool isLast; final bool hasChildren; final double progress;
  _ConnectorPainter({required this.color, required this.isLast, required this.hasChildren, this.progress = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color=color.withOpacity(0.2+(progress*0.15))..strokeWidth=2.0+(progress*0.5)..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    final cx=size.width/2, my=size.height/2, ey=isLast?my:size.height;
    if(!isLast||hasChildren) canvas.drawLine(Offset(cx,0),Offset(cx,ey),p); else canvas.drawLine(Offset(cx,0),Offset(cx,my),p);
    canvas.drawLine(Offset(cx,my),Offset(size.width,my),p);
    canvas.drawCircle(Offset(cx,my),3.0+(progress*1.5),Paint()..color=color.withOpacity(0.4+(progress*0.3))..style=PaintingStyle.fill);
    canvas.drawCircle(Offset(cx,my),5.0+(progress*2.0),Paint()..color=color.withOpacity(0.2+(progress*0.15))..style=PaintingStyle.stroke..strokeWidth=1.5+(progress*0.5));
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter o) => o.progress!=progress||o.isLast!=isLast||o.hasChildren!=hasChildren;
}