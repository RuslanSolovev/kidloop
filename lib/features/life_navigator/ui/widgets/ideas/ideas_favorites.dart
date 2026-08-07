// features/life_navigator/ui/widgets/ideas/ideas_favorites.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../providers/life_provider.dart';
import '../../../models/life_models.dart';
import 'ideas_common.dart';
import 'ideas_details.dart';

// ============================================================
// ИЗБРАННОЕ (с кликом по задаче)
// ============================================================

class FavoritesSheet extends StatelessWidget {
  final bool isDark;
  final List<LifeIdea> favorites;
  final LifeProvider provider;
  final VoidCallback onClose;

  const FavoritesSheet({
    super.key,
    required this.isDark,
    required this.favorites,
    required this.provider,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF0F1115)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Text(
                'Избранное',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1D24),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${favorites.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (favorites.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 48,
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Нет избранных задач',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: favorites.length,
                itemBuilder: (_, index) {
                  final idea = favorites[index];
                  final images = idea.images;
                  return GestureDetector(
                    onTap: () => _showDetails(context, idea),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withOpacity(isDark ? 0.06 : 0.02),
                            isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.red.withOpacity(isDark ? 0.1 : 0.04),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  idea.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (idea.description.isNotEmpty)
                                  Text(
                                    idea.description,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (images.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: images.take(3).map((imageUrl) => Container(
                                      width: 20,
                                      height: 20,
                                      margin: const EdgeInsets.only(right: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        image: DecorationImage(
                                          image: getImageProvider(imageUrl),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IceScoreBadge(score: idea.iceScore),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              provider.updateIdea(idea.copyWith(isFavorite: false));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: Colors.red,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              child: Text(
                'Закрыть',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, LifeIdea idea) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => IdeaDetailsSheet(
        isDark: isDark,
        idea: idea,
        provider: provider,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }
}