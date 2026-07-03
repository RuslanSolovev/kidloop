// add_item_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../../core/item_model.dart';
import '../../core/items_provider.dart';
import '../../core/sv_calculator.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> with SingleTickerProviderStateMixin {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  String selectedCategory = 'Игрушки';
  String selectedCondition = 'Хороший';
  String selectedLocation = 'Рига';

  int currentSv = 50;
  List<File> _selectedImages = [];
  List<String> _uploadedImageUrls = [];
  bool _isUploading = false;
  final _formKey = GlobalKey<FormState>();

  late AnimationController _svAnimationController;
  late Animation<double> _svScaleAnimation;
  late Animation<double> _svGlowAnimation;

  // 🔥 Состояние загрузки темы
  bool _isDarkMode = false;
  bool _themeLoaded = false;

  // 🔥 Анимация для загрузки
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final categories = [
    'Игрушки', 'LEGO', 'Самокат', 'Книги', 'Одежда',
    'Коляска', 'Мебель', 'Техника', 'Развивашки', 'Спорт',
    'Творчество', 'Пазлы', 'Конструктор', 'Куклы', 'Машинки',
    'Настолки', 'Велосипед', 'Электроника', 'Детская посуда', 'Постель',
    'Обувь', 'Школьное', 'Музыкальное', 'Игровая приставка', 'Надувное',
  ];
  final conditions = ['Новый', 'Отличный', 'Хороший', 'Обычный'];

  final locations = [
    'Москва', 'Санкт-Петербург', 'Щёлково', 'Фрязино', 'Новосибирск',
    'Екатеринбург', 'Казань', 'Нижний Новгород', 'Челябинск', 'Самара',
    'Омск', 'Ростов-на-Дону', 'Уфа', 'Красноярск', 'Воронеж',
    'Пермь', 'Волгоград', 'Краснодар', 'Саратов', 'Тюмень',
    'Тольятти', 'Ижевск', 'Барнаул', 'Иркутск', 'Хабаровск',
    'Ярославль', 'Владивосток', 'Махачкала', 'Томск', 'Оренбург',
    'Кемерово', 'Новокузнецк', 'Рига', 'Юрмала', 'Даугавпилс',
    'Лиепая', 'Вентспилс', 'Елгава', 'Резекне', 'Таллин',
  ];

  // 🔥 Геттеры цветов
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFFFF8F0);
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;
  Color get _inputFillColor => _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white;

  @override
  void initState() {
    super.initState();

    // 🔥 Инициализация анимации загрузки (увеличено до 1 секунды)
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Было 500, стало 1000
    );
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeOutCubic),
    );

    // 🔥 Анимация пульсации для прогресс-бара
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadTheme();
    updateSv();

    _svAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _svScaleAnimation = Tween(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _svAnimationController, curve: Curves.easeInOut),
    );
    _svGlowAnimation = Tween(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _svAnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadTheme() async {
    // 🔥 Увеличена задержка до 1 секунды для плавного показа прогресс-бара
    await Future.delayed(const Duration(milliseconds: 1000)); // Было 100, стало 1000

    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;

    if (mounted) {
      setState(() {
        _isDarkMode = isDark;
        _themeLoaded = true;
      });

      // 🔥 Запускаем анимацию появления
      _loadingController.forward();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    _svAnimationController.dispose();
    _loadingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void updateSv() {
    setState(() {
      currentSv = SvCalculator.calculate(category: selectedCategory, condition: selectedCondition);
    });
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 5 фото'), backgroundColor: Colors.orange),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _selectedImages.add(File(picked.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];

    setState(() => _isUploading = true);
    final urls = <String>[];

    try {
      for (final image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);

        final response = await http.post(
          Uri.parse('https://functions.yandexcloud.net/d4e3c2me21eou683ic6d'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "action": "upload",
            "file_name": "photo_${DateTime.now().millisecondsSinceEpoch}.jpg",
            "file_data": base64,
          }),
        ).timeout(const Duration(seconds: 15));

        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          urls.add(data['file_url']);
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }

    setState(() {
      _isUploading = false;
      _uploadedImageUrls = urls;
    });
    return urls;
  }

  void saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно фото'), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
    );

    final imageUrls = await _uploadImages();

    if (mounted) Navigator.pop(context);

    if (imageUrls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки фото'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'unknown';

    final item = Item(
      itemId: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: userId,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      sv: currentSv,
      imagePath: imageUrls.isNotEmpty ? imageUrls.first : 'assets/images/bear.jpg',
      imagePaths: imageUrls,
      location: selectedLocation,
      category: selectedCategory,
      condition: selectedCondition,
      isMine: true,
      status: 'available',
    );

    await context.read<ItemsProvider>().addItem(item);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Объявление опубликовано! 🎉'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Показываем прогресс-бар пока тема не загружена
    if (!_themeLoaded) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Загрузка...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Подготовка формы',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 🔥 Основной контент с анимацией появления
    final isDark = _isDarkMode;
    final textColor = _textColor;
    final subTextColor = _subTextColor;
    final surfaceColor = _surfaceColor;
    final backgroundColor = _backgroundColor;
    final cardBorderColor = _cardBorderColor;
    final inputFillColor = _inputFillColor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _loadingAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _loadingAnimation.value)),
            child: child,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text('Новое объявление', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorderColor),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.1), blurRadius: 8)],
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF0A0A1A), const Color(0xFF1A1A2E), const Color(0xFF151932)]
                  : [const Color(0xFFFFF8F0), const Color(0xFFFFF0E0), Colors.white],
            ),
          ),
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildModernImagePicker(isDark, subTextColor, surfaceColor, cardBorderColor),
                        const SizedBox(height: 28),

                        _buildSectionTitle('Название', Icons.edit_rounded, textColor),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: titleController,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                          style: TextStyle(fontSize: 16, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Например: Детский самокат Micro',
                            hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                            filled: true,
                            fillColor: inputFillColor,
                            contentPadding: const EdgeInsets.all(16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cardBorderColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.orange, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildSectionTitle('Описание', Icons.description_rounded, textColor),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: descriptionController,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите описание' : null,
                          maxLines: 3,
                          style: TextStyle(fontSize: 16, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Опишите вещь: размер, цвет, возраст...',
                            hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                            filled: true,
                            fillColor: inputFillColor,
                            contentPadding: const EdgeInsets.all(16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cardBorderColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.orange, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionTitle('Категория', Icons.category_rounded, textColor),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = selectedCategory == cat;
                              return GestureDetector(
                                onTap: () { setState(() => selectedCategory = cat); updateSv(); },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.orange : surfaceColor,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: isSelected ? Colors.orange : cardBorderColor, width: 1.5),
                                    boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
                                  ),
                                  child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionTitle('Состояние', Icons.verified_rounded, textColor),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: conditions.map((cond) {
                            final isSelected = selectedCondition == cond;
                            return GestureDetector(
                              onTap: () { setState(() => selectedCondition = cond); updateSv(); },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.green.shade50 : surfaceColor,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: isSelected ? Colors.green : cardBorderColor, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected) ...[
                                      const Icon(Icons.check_circle, size: 18, color: Colors.green),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(cond, style: TextStyle(color: isSelected ? Colors.green.shade700 : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionTitle('Город', Icons.location_on_rounded, textColor),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorderColor),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: selectedLocation,
                            dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                            style: TextStyle(color: textColor, fontSize: 15),
                            decoration: const InputDecoration(border: InputBorder.none),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.orange),
                            items: locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc, style: TextStyle(color: textColor, fontSize: 15)))).toList(),
                            onChanged: (val) { if (val != null) setState(() => selectedLocation = val); },
                          ),
                        ),
                        const SizedBox(height: 32),

                        AnimatedBuilder(
                          animation: _svAnimationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _svScaleAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(_svGlowAnimation.value), blurRadius: 24, offset: const Offset(0, 8))],
                                ),
                                child: Column(
                                  children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                                      const SizedBox(width: 8),
                                      Text('Оценка стоимости', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w500)),
                                    ]),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                                      child: Text('$currentSv SV', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        SizedBox(
                          height: 58,
                          child: ElevatedButton(
                            onPressed: saveItem,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 8,
                              shadowColor: Colors.orange.withOpacity(0.5),
                            ),
                            child: const Text('Опубликовать объявление', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: Colors.orange),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
      ],
    );
  }

  Widget _buildModernImagePicker(bool isDark, Color subTextColor, Color surfaceColor, Color cardBorderColor) {
    return Column(
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 220,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _selectedImages.isNotEmpty ? Colors.orange : cardBorderColor,
                width: 2,
              ),
              boxShadow: _selectedImages.isNotEmpty
                  ? [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))]
                  : null,
              image: _selectedImages.isNotEmpty
                  ? DecorationImage(image: FileImage(_selectedImages.first), fit: BoxFit.cover)
                  : null,
            ),
            child: _selectedImages.isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Colors.orange.shade100, Colors.orange.shade200]),
                  ),
                  child: const Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.orange),
                ),
                const SizedBox(height: 16),
                Text('Нажмите, чтобы добавить фото', style: TextStyle(color: subTextColor, fontSize: 15)),
                const SizedBox(height: 6),
                Text('Можно добавить до 5 фото', style: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, fontSize: 13)),
              ],
            )
                : Stack(
              children: [
                if (_isUploading)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                      child: const Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text('Загрузка...', style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                  ),
                if (!_isUploading)
                  Positioned(
                    bottom: 12, right: 12,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.2), blurRadius: 8)]),
                        child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.orange, size: 22),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_selectedImages.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImages[index],
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          bottom: 2, left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Главное', style: TextStyle(color: Colors.white, fontSize: 8)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}