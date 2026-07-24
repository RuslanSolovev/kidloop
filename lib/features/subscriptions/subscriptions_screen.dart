import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/subscriptions_provider.dart';
import '../../core/sv_calculator.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<SubscriptionsProvider>().loadSubscriptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionsProvider>();
    final categories = SvCalculator.categoryBase.keys.toList()..sort();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Подписки на категории'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount:
        categories.length + (provider.subscriptions.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0 && provider.subscriptions.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await provider.unsubscribeAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Вы отписались от всех категорий')),
                    );
                  }
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Отписаться от всего'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            );
          }
          final catIndex =
          provider.subscriptions.isNotEmpty ? index - 1 : index;
          if (catIndex < categories.length) {
            final category = categories[catIndex];
            final isSubscribed = provider.isSubscribed(category);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                title: Text(
                  category,
                  style: TextStyle(
                    fontWeight:
                    isSubscribed ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: isSubscribed
                    ? const Text('Вы будете получать уведомления',
                    style: TextStyle(fontSize: 12))
                    : null,
                value: isSubscribed,
                onChanged: (val) {
                  if (val) {
                    provider.subscribeToCategory(category);
                  } else {
                    provider.unsubscribeFromCategory(category);
                  }
                },
                activeColor: Colors.orange,
                secondary: Icon(
                  isSubscribed
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: isSubscribed ? Colors.orange : Colors.grey,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}