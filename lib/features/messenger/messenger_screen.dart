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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: [
              Tab(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _tabController.index == 0
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, size: 24),
                ),
                text: 'Чаты',
              ),
              Tab(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _tabController.index == 1
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.forum_rounded, size: 24),
                ),
                text: 'Форум',
              ),
              Tab(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _tabController.index == 2
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_rounded, size: 24),
                ),
                text: 'Пользователи',
              ),
            ],
            onTap: (index) {
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ChatsTab(),
              ForumsTab(),
              UsersTab(),
            ],
          ),
        ),
      ],
    );
  }
}