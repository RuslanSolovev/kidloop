// features/dashboard/manage_banners_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BannerAd {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String overlayText;
  final String link;
  final String description;
  final bool isActive;
  final DateTime createdAt;

  BannerAd({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.overlayText = '',
    this.link = '',
    this.description = '',
    this.isActive = true,
    required this.createdAt,
  });
}

class ManageBannersScreen extends StatefulWidget {
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  List<BannerAd> _banners = [];
  bool _loading = true;
  String? _currentUserId;

  static const String _apiUrl =
      'https://functions.yandexcloud.net/d4e9bd6bmvqmife91gf4';
  static const String _uploadApiUrl =
      'https://functions.yandexcloud.net/d4e3c2me21eou683ic6d';

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-all-banners"}),
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          setState(() {
            _banners = (data['banners'] as List)
                .map((b) => BannerAd(
              id: b['banner_id'] ?? '',
              imageUrl: b['image_url'] ?? '',
              title: b['title'] ?? '',
              subtitle: b['subtitle'] ?? '',
              overlayText: b['overlay_text'] ?? '',
              link: b['link'] ?? '',
              description: b['description'] ?? '',
              isActive:
              b['is_active'] == true || b['is_active'] == 'true',
              createdAt: DateTime.tryParse(b['created_at'] ?? '') ??
                  DateTime.now(),
            ))
                .toList();
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Стильный полноэкранный редактор баннера
  Future<void> _createOrEditBanner({BannerAd? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final overlayCtrl =
    TextEditingController(text: existing?.overlayText ?? '');
    final linkCtrl = TextEditingController(text: existing?.link ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String? imageUrl = existing?.imageUrl;
    File? imageFile;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _BannerEditorScreen(
          imageUrl: imageUrl,
          imageFile: imageFile,
          titleCtrl: titleCtrl,
          subtitleCtrl: subtitleCtrl,
          overlayCtrl: overlayCtrl,
          linkCtrl: linkCtrl,
          descCtrl: descCtrl,
          isEditing: existing != null,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _loading = true);

    try {
      String? finalImageUrl = result['imageUrl'] as String?;

      // Загружаем изображение если выбрано новое
      if (result['imageFile'] != null) {
        final file = result['imageFile'] as File;
        final bytes = await file.readAsBytes();
        final base64 = base64Encode(bytes);

        final uploadResponse = await http.post(
          Uri.parse(_uploadApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "action": "upload",
            "file_name":
            "banner_${DateTime.now().millisecondsSinceEpoch}.jpg",
            "file_data": base64,
          }),
        ).timeout(const Duration(seconds: 15));

        final uploadData = jsonDecode(uploadResponse.body);
        if (uploadData['ok'] == true) {
          finalImageUrl = uploadData['file_url'];
        }
      }

      final action = existing != null ? 'update-banner' : 'create-banner';
      final body = <String, dynamic>{
        "action": action,
        "title": result['title'],
        "subtitle": result['subtitle'],
        "overlay_text": result['overlay'],
        "link": result['link'],
        "description": result['description'],
        "image_url": finalImageUrl ?? '',
        "user_id": _currentUserId,
      };
      if (existing != null) body["banner_id"] = existing.id;

      await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 8));

      await _loadBanners();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ошибка сохранения'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteBanner(String bannerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить баннер?'),
        content: const Text('Это действие нельзя отменить'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await http.post(
      Uri.parse(_apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "action": "delete-banner",
        "banner_id": bannerId,
        "user_id": _currentUserId
      }),
    );

    _loadBanners();
  }

  Future<void> _toggleActive(BannerAd banner) async {
    await http.post(
      Uri.parse(_apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "action": "toggle-banner",
        "banner_id": banner.id,
        "is_active": !banner.isActive,
        "user_id": _currentUserId,
      }),
    );
    _loadBanners();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final backgroundColor =
    isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text('📢 Баннеры',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _createOrEditBanner(),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Новый баннер',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: Colors.orange))
          : _banners.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.1),
              ),
              child: Icon(Icons.campaign_rounded,
                  size: 48, color: Colors.orange.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text('Нет баннеров',
                style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 16)),
            const SizedBox(height: 8),
            Text('Нажмите кнопку ниже, чтобы создать первый баннер',
                style: TextStyle(
                    color: textColor.withOpacity(0.3),
                    fontSize: 12)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: _banners.length,
        itemBuilder: (context, index) {
          final banner = _banners[index];
          return _buildBannerCard(banner, isDark, textColor, surfaceColor);
        },
      ),
    );
  }

  Widget _buildBannerCard(
      BannerAd banner, bool isDark, Color textColor, Color surfaceColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Изображение с наложением статуса
            if (banner.imageUrl.isNotEmpty)
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  // Статус активен/неактивен
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: banner.isActive
                            ? Colors.green.withOpacity(0.8)
                            : Colors.grey.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        banner.isActive ? 'Активен' : 'Скрыт',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor),
                  ),
                  if (banner.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                  if (banner.link.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.link_rounded,
                            size: 14, color: Colors.blue.shade300),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            banner.link,
                            style: TextStyle(
                                color: Colors.blue.shade300, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(banner.createdAt),
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 10),
                        ),
                      ),
                      // Переключатель
                      GestureDetector(
                        onTap: () => _toggleActive(banner),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: banner.isActive
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: banner.isActive
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            banner.isActive ? 'Выкл' : 'Вкл',
                            style: TextStyle(
                              color: banner.isActive
                                  ? Colors.green
                                  : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Кнопка редактировать
                      GestureDetector(
                        onTap: () => _createOrEditBanner(existing: banner),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              size: 16, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Кнопка удалить
                      GestureDetector(
                        onTap: () => _deleteBanner(banner.id),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_rounded,
                              size: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

// Стильный полноэкранный редактор
class _BannerEditorScreen extends StatefulWidget {
  final String? imageUrl;
  final File? imageFile;
  final TextEditingController titleCtrl;
  final TextEditingController subtitleCtrl;
  final TextEditingController overlayCtrl;
  final TextEditingController linkCtrl;
  final TextEditingController descCtrl;
  final bool isEditing;

  const _BannerEditorScreen({
    this.imageUrl,
    this.imageFile,
    required this.titleCtrl,
    required this.subtitleCtrl,
    required this.overlayCtrl,
    required this.linkCtrl,
    required this.descCtrl,
    required this.isEditing,
  });

  @override
  State<_BannerEditorScreen> createState() => _BannerEditorScreenState();
}

class _BannerEditorScreenState extends State<_BannerEditorScreen> {
  File? _imageFile;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.imageFile;
    _imageUrl = widget.imageUrl;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _imageUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final backgroundColor =
    isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.close_rounded, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          widget.isEditing ? 'Редактировать баннер' : 'Новый баннер',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'title': widget.titleCtrl.text.trim(),
                'subtitle': widget.subtitleCtrl.text.trim(),
                'overlay': widget.overlayCtrl.text.trim(),
                'link': widget.linkCtrl.text.trim(),
                'description': widget.descCtrl.text.trim(),
                'imageFile': _imageFile,
                'imageUrl': _imageUrl,
              });
            },
            child: Text(
              'Сохранить',
              style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Превью баннера
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Фон
                    if (_imageFile != null)
                      Image.file(_imageFile!, fit: BoxFit.cover)
                    else if (_imageUrl != null && _imageUrl!.isNotEmpty)
                      CachedNetworkImage(
                          imageUrl: _imageUrl!, fit: BoxFit.cover)
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade300,
                              Colors.deepOrange.shade400
                            ],
                          ),
                        ),
                      ),
                    // Затемнение
                    Container(color: Colors.black.withOpacity(0.35)),
                    // Текст предпросмотра
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment:
                        widget.overlayCtrl.text.isNotEmpty
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.overlayCtrl.text.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.overlayCtrl.text,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            widget.titleCtrl.text.isNotEmpty
                                ? widget.titleCtrl.text
                                : 'Заголовок',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitleCtrl.text.isNotEmpty
                                ? widget.subtitleCtrl.text
                                : 'Подзаголовок',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Кнопка смены фото
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Поля ввода
            _buildTextField(
              controller: widget.titleCtrl,
              label: 'Заголовок',
              hint: 'Например: Большая распродажа!',
              textColor: textColor,
              surfaceColor: surfaceColor,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: widget.subtitleCtrl,
              label: 'Подзаголовок',
              hint: 'Краткое описание акции',
              textColor: textColor,
              surfaceColor: surfaceColor,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: widget.overlayCtrl,
              label: 'Бейдж (над заголовком)',
              hint: 'Например: АКЦИЯ',
              textColor: textColor,
              surfaceColor: surfaceColor,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: widget.linkCtrl,
              label: 'Ссылка для перехода',
              hint: 'https://example.com',
              textColor: textColor,
              surfaceColor: surfaceColor,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: widget.descCtrl,
              label: 'Описание (для экрана подробностей)',
              hint: 'Полное описание баннера...',
              textColor: textColor,
              surfaceColor: surfaceColor,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color textColor,
    required Color surfaceColor,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
              TextStyle(color: Colors.grey.shade400, fontSize: 13),
              contentPadding: const EdgeInsets.all(14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}