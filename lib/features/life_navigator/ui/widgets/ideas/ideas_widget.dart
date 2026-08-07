// features/life_navigator/ui/widgets/ideas/ideas_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';
import '../base_life_widget.dart';
import 'ideas_fullscreen.dart';

// ============================================================
// ОСНОВНОЙ ВИДЖЕТ (ТОЧКА ВХОДА)
// ============================================================

class IdeasWidget extends BaseLifeWidget {
  const IdeasWidget({
    super.key,
    required super.isDark,
    super.isCompact = true,
  });

  @override
  State<IdeasWidget> createState() => _IdeasWidgetState();
}

class _IdeasWidgetState extends State<IdeasWidget> with LifeWidgetMixin<IdeasWidget> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeProvider>();
    final ideas = provider.ideas;

    return FullscreenIdeasView(
      isDark: widget.isDark,
      ideas: ideas,
      provider: provider,
      onClose: () => Navigator.pop(context),
    );
  }
}