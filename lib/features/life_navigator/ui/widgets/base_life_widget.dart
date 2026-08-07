// features/life_navigator/ui/widgets/base_life_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/life_provider.dart';

/// Базовый класс для всех виджетов с поддержкой компактного и полноэкранного режимов
abstract class BaseLifeWidget extends StatefulWidget {
  final bool isDark;
  final bool isCompact; // true - компактный режим, false - полноэкранный

  const BaseLifeWidget({
    super.key,
    required this.isDark,
    this.isCompact = true,
  });

  @override
  State<BaseLifeWidget> createState();
}

/// Миксин для единообразного поведения виджетов
/// ВНИМАНИЕ: Используйте этот миксин ТОЛЬКО с StatefulWidget, который уже имеет TickerProvider
/// Обычно это достигается добавлением with SingleTickerProviderStateMixin
mixin LifeWidgetMixin<T extends BaseLifeWidget> on State<T> {
  /// Открыть виджет в полноэкранном режиме
  void openFullScreen() {
    HapticFeedback.mediumImpact();

    // Получаем провайдер из текущего контекста
    final provider = context.read<LifeProvider>();

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: _FullScreenWrapper(
            child: widget,
            isDark: widget.isDark,
          ),
        ),
      ),
    );
  }

  /// Показать меню действий
  void showWidgetMenu(BuildContext context, List<Widget> actions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ...actions,
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Обёртка для полноэкранного режима
class _FullScreenWrapper extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _FullScreenWrapper({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Полный экран',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
              // Можно добавить дополнительные действия
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}