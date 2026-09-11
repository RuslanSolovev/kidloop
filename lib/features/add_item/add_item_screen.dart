// add_item_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../../core/item_model.dart';
import '../../core/items_provider.dart';
import '../../core/sv_calculator.dart';

// ==================== iOS DESIGN SYSTEM ====================

class _IOS {
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color darkBg = Color(0xFF000000);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);

  static const Color blue = Color(0xFF007AFF);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color purple = Color(0xFFAF52DE);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color indigo = Color(0xFF5856D6);
  static const Color pink = Color(0xFFFF2D55);
  static const Color red = Color(0xFFFF3B30);
  static const Color gray = Color(0xFF8E8E93);

  static Color separator(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color textPrimary(bool isDark) => isDark ? Colors.white : Colors.black;
  static Color textSecondary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.6)
      : const Color(0xFF3C3C43).withOpacity(0.6);
  static Color textTertiary(bool isDark) => isDark
      ? Colors.white.withOpacity(0.3)
      : const Color(0xFF3C3C43).withOpacity(0.3);

  static Color inputFill(bool isDark) =>
      isDark ? darkCardElevated : const Color(0xFFF2F2F7);
}

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen>
    with SingleTickerProviderStateMixin {
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

  bool _isDarkMode = false;
  bool _themeLoaded = false;

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

  @override
  void initState() {
    super.initState();

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadingAnimation = CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadTheme();
    _updateSv();

    _svAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _svScaleAnimation = Tween(begin: 0.99, end: 1.01).animate(
      CurvedAnimation(parent: _svAnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    if (!mounted) return;

    setState(() {
      _isDarkMode = isDark;
      _themeLoaded = true;
    });
    _loadingController.forward();
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

  void _updateSv() {
    setState(() {
      currentSv = SvCalculator.calculate(
        category: selectedCategory,
        condition: selectedCondition,
      );
    });
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Максимум 5 фото'),
          backgroundColor: _IOS.orange,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedImages.add(File(picked.path));
      });
    }
  }

  void _removeImage(int index) {
    HapticFeedback.mediumImpact();
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

        final response = await http
            .post(
          Uri.parse(
              'https://functions.yandexcloud.net/d4e3c2me21eou683ic6d'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "action": "upload",
            "file_name":
            "photo_${DateTime.now().millisecondsSinceEpoch}.jpg",
            "file_data": base64,
          }),
        )
            .timeout(const Duration(seconds: 15));

        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          urls.add(data['file_url']);
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }

    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadedImageUrls = urls;
      });
    }
    return urls;
  }

  void saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Добавьте хотя бы одно фото'),
          backgroundColor: _IOS.orange,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _IOS.card(_isDarkMode),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: _IOS.blue,
                strokeWidth: 2.5,
              ),
              SizedBox(height: 14),
              Text(
                'Загружаем фото…',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );

    final imageUrls = await _uploadImages();

    if (mounted) Navigator.pop(context);

    if (imageUrls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ошибка загрузки фото'),
            backgroundColor: _IOS.red,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
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
      imagePath:
      imageUrls.isNotEmpty ? imageUrls.first : 'assets/images/bear.jpg',
      imagePaths: imageUrls,
      location: selectedLocation,
      category: selectedCategory,
      condition: selectedCondition,
      isMine: true,
      status: 'available',
    );

    await context.read<ItemsProvider>().addItem(item);

    if (mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Объявление опубликовано 🎉'),
          backgroundColor: _IOS.green,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return _buildLoadingScreen();
    }

    final isDark = _isDarkMode;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _loadingAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - _loadingAnimation.value)),
            child: child,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: _IOS.bg(isDark),
        appBar: _buildAppBar(isDark),
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImagePicker(isDark),
                      const SizedBox(height: 24),

                      // Title
                      _buildSectionTitle('Название', isDark),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: titleController,
                        hint: 'Например: Детский самокат Micro',
                        isDark: isDark,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Введите название'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Description
                      _buildSectionTitle('Описание', isDark),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: descriptionController,
                        hint: 'Размер, цвет, возраст…',
                        isDark: isDark,
                        maxLines: 4,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Введите описание'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // Category
                      _buildSectionTitle('Категория', isDark),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = selectedCategory == cat;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => selectedCategory = cat);
                                _updateSv();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _IOS.blue
                                      : _IOS.card(isDark),
                                  borderRadius: BorderRadius.circular(19),
                                  border: Border.all(
                                    color: isSelected
                                        ? _IOS.blue
                                        : _IOS.separator(isDark),
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    letterSpacing: -0.2,
                                    color: isSelected
                                        ? Colors.white
                                        : _IOS.textPrimary(isDark),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Condition
                      _buildSectionTitle('Состояние', isDark),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: conditions.map((cond) {
                          final isSelected = selectedCondition == cond;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => selectedCondition = cond);
                              _updateSv();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _IOS.green
                                    : _IOS.card(isDark),
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: isSelected
                                      ? _IOS.green
                                      : _IOS.separator(isDark),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    cond,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      letterSpacing: -0.2,
                                      color: isSelected
                                          ? Colors.white
                                          : _IOS.textPrimary(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Location
                      _buildSectionTitle('Город', isDark),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: _IOS.inputFill(isDark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _IOS.separator(isDark)),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: selectedLocation,
                          dropdownColor: _IOS.card(isDark),
                          style: TextStyle(
                            color: _IOS.textPrimary(isDark),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _IOS.textSecondary(isDark),
                          ),
                          items: locations
                              .map((loc) => DropdownMenuItem(
                            value: loc,
                            child: Text(
                              loc,
                              style: TextStyle(
                                color: _IOS.textPrimary(isDark),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              HapticFeedback.selectionClick();
                              setState(() => selectedLocation = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 28),

                      // SV preview
                      AnimatedBuilder(
                        animation: _svAnimationController,
                        builder: (context, child) => Transform.scale(
                          scale: _svScaleAnimation.value,
                          child: child,
                        ),
                        child: _buildSvCard(isDark),
                      ),
                      const SizedBox(height: 28),

                      // Submit
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: saveItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _IOS.blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Опубликовать',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING SCREEN
  // ============================================================

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: _IOS.bg(_isDarkMode),
      body: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _IOS.blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: _IOS.blue,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Загрузка…',
                style: TextStyle(
                  color: _IOS.textSecondary(_isDarkMode),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: _IOS.bg(isDark).withOpacity(0.85),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              color: _IOS.textPrimary(isDark),
              size: 22,
            ),
          ),
        ),
      ),
      title: Text(
        'Новое объявление',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: _IOS.textPrimary(isDark),
        ),
      ),
      centerTitle: true,
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: _IOS.textTertiary(isDark),
        ),
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: _IOS.textPrimary(isDark),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: _IOS.textTertiary(isDark),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: _IOS.inputFill(isDark),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _IOS.separator(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _IOS.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _IOS.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _IOS.red, width: 2),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE PICKER
  // ============================================================

  Widget _buildImagePicker(bool isDark) {
    final hasImages = _selectedImages.isNotEmpty;

    return Column(
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 220,
            decoration: BoxDecoration(
              color: _IOS.inputFill(isDark),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasImages ? Colors.transparent : _IOS.separator(isDark),
                width: 1,
              ),
              image: hasImages
                  ? DecorationImage(
                image: FileImage(_selectedImages.first),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: hasImages
                ? Stack(
              children: [
                // Затемнение для кнопок
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                ),

                // Загрузка
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Загрузка…',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Главное фото badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'ГЛАВНОЕ ФОТО',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),

                // Add more button
                if (!_isUploading)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: _IOS.blue,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _IOS.blue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 28,
                    color: _IOS.blue,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Добавить фото',
                  style: TextStyle(
                    color: _IOS.textPrimary(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'До 5 фотографий',
                  style: TextStyle(
                    color: _IOS.textSecondary(isDark),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Thumbnails
        if (_selectedImages.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: 8,
                    left: index == 0 ? 0 : 0,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImages[index],
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _IOS.blue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
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

  // ============================================================
  // SV CARD
  // ============================================================

  Widget _buildSvCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _IOS.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _IOS.separator(isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _IOS.orange.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _IOS.orange,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Оценка стоимости',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: _IOS.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$currentSv',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1,
                        color: _IOS.orange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'SV',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: _IOS.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}