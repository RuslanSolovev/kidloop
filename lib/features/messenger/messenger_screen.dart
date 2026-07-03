// messenger_screen.dart
import 'package:flutter/material.dart';
import 'users_tab.dart';
import 'chats_tab.dart';
import 'forums_tab.dart';

class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _switchAnimationController;
  late Animation<double> _switchAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _previousIndex && !_tabController.indexIsChanging) {
        setState(() {
          _previousIndex = _tabController.index;
        });
        _switchAnimationController.forward(from: 0);
      }
    });

    _switchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _switchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _switchAnimationController, curve: Curves.easeOutCubic),
    );
    _switchAnimationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _switchAnimationController.dispose();
    super.dispose();
  }

  // 🔥 Поддержка темы
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      children: [
        // 🔥 Верхняя панель (без заголовка)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF1A1A2E), const Color(0xFF151932)]
                  : [Colors.white, const Color(0xFFF8F9FA)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(isDark ? 0.1 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: subTextColor,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: [
                    _buildTab(icon: Icons.chat_bubble_rounded, label: 'Чаты', index: 0, subTextColor: subTextColor),
                    _buildTab(icon: Icons.forum_rounded, label: 'Форум', index: 1, subTextColor: subTextColor),
                    _buildTab(icon: Icons.people_rounded, label: 'Люди', index: 2, subTextColor: subTextColor),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 🔥 Контент с анимацией переключения
        Expanded(
          child: AnimatedBuilder(
            animation: _switchAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _switchAnimation.value,
                child: Transform.scale(
                  scale: 0.97 + (0.03 * _switchAnimation.value),
                  child: child,
                ),
              );
            },
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: const [
                ChatsTab(),
                ForumsTab(),
                UsersTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 Вкладка с иконкой (текст показывается сразу)
  Widget _buildTab({
    required IconData icon,
    required String label,
    required int index,
    required Color subTextColor,
  }) {
    final isSelected = _tabController.index == index;

    return Tab(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.white : subTextColor,
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}