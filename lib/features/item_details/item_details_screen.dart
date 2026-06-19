// item_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/item_model.dart';
import '../../../core/items_provider.dart';
import '../my_items/select_item_to_trade_screen.dart';
import '../profile/public_profile_screen.dart';
import '../../widgets/image_gallery_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemDetailsScreen extends StatefulWidget {
  final Item item;

  const ItemDetailsScreen({super.key, required this.item});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  Map<String, dynamic>? _ownerData;
  bool _loadingOwner = true;

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    if (widget.item.isMine) {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _ownerData = {
            'name': prefs.getString('user_name') ?? 'Вы',
            'avatar_url': prefs.getString('avatar_url') ?? '',
          };
          _loadingOwner = false;
        });
      }
      return;
    }

    try {
      final provider = context.read<ItemsProvider>();
      final ownerData = await provider.getUserProfile(widget.item.ownerId);
      if (mounted) {
        setState(() {
          _ownerData = ownerData;
          _loadingOwner = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingOwner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'item_image_${item.itemId}',
                child: ImageGalleryWidget(
                  imageUrls: item.imagePaths,
                  height: 300,
                  borderRadius: 0,
                  showIndicators: true,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Text(item.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                            const SizedBox(width: 4),
                            Text('${item.sv} SV', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(item.description, style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _buildBadge(icon: Icons.category, label: item.category, color: Colors.orange),
                      _buildBadge(icon: Icons.check_circle_outline, label: item.condition, color: Colors.green),
                      if (item.location.isNotEmpty)
                        _buildBadge(icon: Icons.location_on_outlined, label: item.location, color: Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildOwnerCard(),
                  if (!item.isMine) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SelectItemToTradeScreen(wantedItem: item)),
                          );
                        },
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Предложить обмен', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: Colors.orange.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard() {
    if (_loadingOwner) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))),
      );
    }

    final name = _ownerData?['name'] ?? (widget.item.isMine ? 'Вы' : 'Пользователь');
    final avatarUrl = _ownerData?['avatar_url'] ?? '';
    final isMine = widget.item.isMine;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMine ? Colors.orange.withOpacity(0.3) : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 22))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMine ? 'Это ваша вещь' : 'Владелец', style: TextStyle(color: isMine ? Colors.orange : Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          if (!isMine)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: widget.item.ownerId))),
              icon: const Icon(Icons.person, size: 18),
              label: const Text('Профиль'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}