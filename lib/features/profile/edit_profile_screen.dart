import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/profile_provider.dart';
import '../../core/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController cityController;
  late TextEditingController bioController;
  late TextEditingController ageController;
  late TextEditingController telegramController;

  String selectedCategory = 'LEGO';
  String _avatarUrl = '';
  bool isSaving = false;

  // 🔥 Загружаем настройку темы из SharedPreferences
  bool _isDarkMode = false;

  final categories = [
    'LEGO',
    'Игрушки',
    'Самокат',
    'Книги',
    'Одежда',
    'Коляска',
    'Мебель',
    'Техника',
    'Развивашки',
    'Спорт',
    'Творчество',
    'Пазлы',
    'Конструктор',
    'Куклы',
    'Машинки',
    'Настолки',
    'Велосипед',
    'Электроника',
    'Детская посуда',
    'Постель',
    'Обувь',
    'Школьное',
    'Музыкальное',
    'Игровая приставка',
    'Надувное',
  ];

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

    // 🔥 Загружаем тему при инициализации
    _loadThemeMode();

    final profile = context.read<ProfileProvider>().profile;

    nameController = TextEditingController(text: profile.name);
    cityController = TextEditingController(text: profile.city);
    bioController = TextEditingController(text: profile.bio);
    ageController = TextEditingController(text: profile.age.toString());
    telegramController = TextEditingController(text: profile.telegram);
    selectedCategory = profile.favoriteCategory;
    _avatarUrl = profile.avatarUrl;
  }

  // 🔥 Загружаем настройку темы
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    cityController.dispose();
    bioController.dispose();
    ageController.dispose();
    telegramController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (picked != null) {
      try {
        final bytes = await File(picked.path).readAsBytes();
        final base64 = base64Encode(bytes);

        final response = await http.post(
          Uri.parse('https://functions.yandexcloud.net/d4e3c2me21eou683ic6d'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"action": "upload", "file_data": base64}),
        );

        final data = jsonDecode(response.body);
        if (data['ok'] == true && mounted) {
          setState(() => _avatarUrl = data['file_url']);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Фото загружено')),
          );
        }
      } catch (e) {
        print("AVATAR UPLOAD ERROR: $e");
      }
    }
  }

  Future<void> save() async {
    final updated = UserProfile(
      name: nameController.text.trim(),
      city: cityController.text.trim(),
      bio: bioController.text.trim(),
      age: int.tryParse(ageController.text) ?? 0,
      favoriteCategory: selectedCategory,
      telegram: telegramController.text.trim(),
      avatarUrl: _avatarUrl,
    );

    context.read<ProfileProvider>().updateProfile(updated);

    setState(() => isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'unknown';

      final url = Uri.parse('https://functions.yandexcloud.net/d4euctluka7dnot8sosh');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "update",
          "user_id": userId,
          "name": updated.name,
          "city": updated.city,
          "bio": updated.bio,
          "telegram": updated.telegram,
          "age": updated.age,
          "avatar_url": _avatarUrl,
        }),
      );

      print("PROFILE SAVE STATUS: ${response.statusCode}");
      print("PROFILE SAVE BODY: ${response.body}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? 'Профиль сохранён в облаке'
                  : 'Сохранено локально (сервер: ${response.statusCode})',
            ),
          ),
        );
      }
    } catch (e) {
      print("PROFILE SYNC ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сохранено локально (нет сети)')),
        );
      }
    }

    setState(() => isSaving = false);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Адаптивные цвета (используем _isDarkMode из SharedPreferences)
    final backgroundColor = _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);
    final surfaceColor = _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;
    final fillColor = _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Редактировать профиль',
          style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: isSaving ? null : save,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Сохранить',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Аватар
            GestureDetector(
              onTap: _pickAvatar,
              child: Center(
                child: Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange.withOpacity(0.5), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 64,
                      backgroundColor: Colors.orange.shade100,
                      backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                      child: _avatarUrl.isEmpty
                          ? const Icon(Icons.camera_alt, size: 48, color: Colors.orange)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.withOpacity(0.15), Colors.deepOrange.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_rounded, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Изменить фото',
                      style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Секция "Основное"
            _buildSectionTitle('👤 Основное', textColor),
            const SizedBox(height: 16),

            // Имя
            _buildTextField(
              controller: nameController,
              label: 'Имя',
              icon: Icons.person_rounded,
              hint: 'Ваше имя',
              textColor: textColor,
              subTextColor: subTextColor,
              borderColor: borderColor,
              fillColor: fillColor,
              surfaceColor: surfaceColor,
            ),
            const SizedBox(height: 16),

            // Город
            _buildSectionTitle('📍 Город', textColor),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonFormField<String>(
                value: locations.contains(cityController.text) ? cityController.text : locations.first,
                dropdownColor: surfaceColor,
                style: TextStyle(color: textColor, fontSize: 15),
                decoration: const InputDecoration(border: InputBorder.none),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.orange),
                items: locations.map((loc) => DropdownMenuItem(
                  value: loc,
                  child: Text(loc, style: TextStyle(color: textColor)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) cityController.text = val;
                },
              ),
            ),
            const SizedBox(height: 24),

            // Секция "О себе"
            _buildSectionTitle('📝 О себе', textColor),
            const SizedBox(height: 16),

            _buildTextField(
              controller: bioController,
              label: 'Расскажите о себе',
              icon: Icons.info_outline_rounded,
              hint: 'Чем увлекаетесь, что ищете...',
              maxLines: 3,
              textColor: textColor,
              subTextColor: subTextColor,
              borderColor: borderColor,
              fillColor: fillColor,
              surfaceColor: surfaceColor,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: ageController,
              label: 'Возраст',
              icon: Icons.cake_rounded,
              hint: 'Ваш возраст',
              keyboardType: TextInputType.number,
              textColor: textColor,
              subTextColor: subTextColor,
              borderColor: borderColor,
              fillColor: fillColor,
              surfaceColor: surfaceColor,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: telegramController,
              label: 'Telegram',
              icon: Icons.telegram,
              hint: '@username',
              textColor: textColor,
              subTextColor: subTextColor,
              borderColor: borderColor,
              fillColor: fillColor,
              surfaceColor: surfaceColor,
            ),
            const SizedBox(height: 24),

            // Секция "Интересы"
            _buildSectionTitle('🎯 Любимая категория', textColor),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final isSelected = selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                          colors: [Colors.orange, Colors.deepOrange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        color: isSelected ? null : fillColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected ? Colors.orange : borderColor,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : textColor,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
    required Color fillColor,
    required Color surfaceColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.1 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: subTextColor, fontSize: 14),
          hintStyle: TextStyle(color: subTextColor.withOpacity(0.5), fontSize: 14),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.orange, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}