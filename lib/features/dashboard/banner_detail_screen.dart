// features/dashboard/banner_detail_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_screen.dart';

class BannerDetailScreen extends StatelessWidget {
  final BannerAd banner;

  const BannerDetailScreen({super.key, required this.banner});

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Ошибка открытия ссылки: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final surfaceColor = isDark ? const Color(0xFF1A1D24) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Изображение с Hero-анимацией
            Stack(
              children: [
                Hero(
                  tag: 'banner_${banner.id}',
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      child: banner.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: banner.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade600]),
                          ),
                          child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade600]),
                          ),
                          child: const Center(child: Icon(Icons.image_rounded, size: 48, color: Colors.white54)),
                        ),
                      )
                          : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade600]),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15), border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
                                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 48),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Плавный градиентный переход к фону
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, backgroundColor.withOpacity(0.95)],
                      ),
                    ),
                  ),
                ),

                // Стеклянная кнопка "Назад"
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Контент
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Бейдж
                  if (banner.overlayText.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Text(
                        banner.overlayText,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                    ),

                  // Заголовок
                  Text(
                    banner.title,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor, height: 1.1, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 12),

                  // Подзаголовок
                  if (banner.subtitle.isNotEmpty)
                    Text(
                      banner.subtitle,
                      style: TextStyle(fontSize: 18, color: subTextColor, height: 1.4, fontWeight: FontWeight.w500),
                    ),

                  const SizedBox(height: 32),

                  // Описание в стильной карточке
                  if (banner.description.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 16, offset: const Offset(0, 8))],
                      ),
                      child: Text(
                        banner.description,
                        style: TextStyle(fontSize: 15, color: textColor, height: 1.7, letterSpacing: 0.2),
                      ),
                    ),

                  const SizedBox(height: 40),

                  // Кнопка действия (Перейти)
                  if (banner.link.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(colors: [Color(0xFFFF8A3D), Color(0xFFFF6B00)]),
                        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openLink(banner.link),
                          borderRadius: BorderRadius.circular(20),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Перейти по ссылке', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                                SizedBox(width: 8),
                                Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Кнопка "Назад" (текстовая, минималистичная)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: const Text('Вернуться назад', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}