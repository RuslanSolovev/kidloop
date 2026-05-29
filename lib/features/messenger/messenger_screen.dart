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
        TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: '👥', icon: Text('Пользователи', style: TextStyle(fontSize: 11))),
            Tab(text: '💬', icon: Text('Чаты', style: TextStyle(fontSize: 11))),
            Tab(text: '📢', icon: Text('Форум', style: TextStyle(fontSize: 11))),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              UsersTab(),
              ChatsTab(),
              ForumsTab(),
            ],
          ),
        ),
      ],
    );
  }
}