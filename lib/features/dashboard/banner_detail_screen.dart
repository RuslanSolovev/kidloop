// features/dashboard/banner_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_screen.dart';

class BannerDetailScreen extends StatelessWidget {
  final BannerAd banner;

  const BannerDetailScreen({super.key, required this.banner});

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Изображение
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: banner.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.image_rounded, size: 48, color: Colors.white54),
                      ),
                    ),
                  )
                      : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                            ),
                            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 48),
                          ),
                          const SizedBox(height: 16),
                          if (banner.overlayText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                              ),
                              child: Text(
                                banner.overlayText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Размытие снизу
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          backgroundColor.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Контент
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Бейдж
                  if (banner.overlayText.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        banner.overlayText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                  // Заголовок
                  Text(
                    banner.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Подзаголовок
                  if (banner.subtitle.isNotEmpty)
                    Text(
                      banner.subtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color: subTextColor,
                        height: 1.4,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Описание в карточке
                  if (banner.description.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        banner.description,
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor,
                          height: 1.7,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Кнопка действия
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (banner.link.isNotEmpty) {
                          _openLink(banner.link);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      icon: Icon(
                        banner.link.isNotEmpty ? Icons.open_in_new_rounded : Icons.arrow_back_rounded,
                        size: 22,
                      ),
                      label: Text(
                        banner.link.isNotEmpty ? 'Перейти' : 'Вернуться назад',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 4,
                        shadowColor: Colors.orange.withOpacity(0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}