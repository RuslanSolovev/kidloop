// image_gallery_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageGalleryWidget extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final double borderRadius;
  final bool showIndicators;

  const ImageGalleryWidget({
    super.key,
    required this.imageUrls,
    this.height = 200,
    this.borderRadius = 20,
    this.showIndicators = true,
  });

  @override
  State<ImageGalleryWidget> createState() => _ImageGalleryWidgetState();
}

class _ImageGalleryWidgetState extends State<ImageGalleryWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  final Map<int, Widget> _pageCache = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _preloadPages();
  }

  void _preloadPages() {
    final urls = widget.imageUrls.isEmpty ? ['assets/images/bear.jpg'] : widget.imageUrls;
    for (int i = 0; i < urls.length && i <= 2; i++) {
      _pageCache[i] = _buildImagePage(urls[i]);
    }
  }

  Widget _buildImagePage(String url) {
    // 🔥 Если это локальный ассет
    if (!url.startsWith('http')) {
      return Container(
        width: double.infinity,
        height: widget.height,
        color: Colors.grey.shade100,
        child: Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade100,
            child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
          ),
        ),
      );
    }

    // 🔥 Сетевое изображение
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: widget.height,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
        ),
      ),
      // 🔥 Используем imageBuilder для правильного отображения
      imageBuilder: (context, imageProvider) {
        return Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls.isEmpty
        ? ['assets/images/bear.jpg']
        : widget.imageUrls;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: widget.borderRadius > 0
                ? BorderRadius.vertical(top: Radius.circular(widget.borderRadius))
                : BorderRadius.zero,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                _cachePage(page - 1, urls);
                _cachePage(page, urls);
                _cachePage(page + 1, urls);
              },
              itemCount: urls.length,
              itemBuilder: (context, index) {
                if (_pageCache.containsKey(index)) {
                  return _pageCache[index]!;
                }
                final page = _buildImagePage(urls[index]);
                _pageCache[index] = page;
                return page;
              },
            ),
          ),
          // Индикаторы
          if (widget.showIndicators && urls.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  urls.length,
                      (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentPage == index ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          // Стрелки
          if (urls.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_currentPage > 0) {
                      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    }
                  },
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_currentPage < urls.length - 1) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    }
                  },
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _cachePage(int index, List<String> urls) {
    if (index < 0 || index >= urls.length) return;
    if (_pageCache.containsKey(index)) return;
    _pageCache[index] = _buildImagePage(urls[index]);
  }
}