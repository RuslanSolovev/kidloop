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

  final categories = [
    'LEGO',
    'Игрушки',
    'Самокат',
    'Книги',
    'Одежда',
  ];

  @override
  void initState() {
    super.initState();

    final profile = context.read<ProfileProvider>().profile;

    nameController = TextEditingController(text: profile.name);
    cityController = TextEditingController(text: profile.city);
    bioController = TextEditingController(text: profile.bio);
    ageController = TextEditingController(text: profile.age.toString());
    telegramController = TextEditingController(text: profile.telegram);
    selectedCategory = profile.favoriteCategory;
    _avatarUrl = profile.avatarUrl;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Аватар с кнопкой изменения
            GestureDetector(
              onTap: _pickAvatar,
              child: Hero(
                tag: 'profile_avatar',
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: colorScheme.surfaceVariant,
                  backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                  child: _avatarUrl.isEmpty
                      ? Icon(Icons.camera_alt, size: 48, color: colorScheme.primary)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Нажмите, чтобы изменить фото',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            // Поля ввода с современными InputDecoration
            _buildTextField(
              controller: nameController,
              label: 'Имя',
              icon: Icons.person,
              theme: theme,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: cityController,
              label: 'Город',
              icon: Icons.location_on,
              theme: theme,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: bioController,
              label: 'О себе',
              icon: Icons.info_outline,
              maxLines: 3,
              theme: theme,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: ageController,
              label: 'Возраст',
              icon: Icons.cake,
              keyboardType: TextInputType.number,
              theme: theme,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: telegramController,
              label: 'Telegram',
              icon: Icons.telegram,
              theme: theme,
            ),
            const SizedBox(height: 16),

            // Выбор категории в виде чипсов
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Любимая категория', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: categories.map((cat) => ChoiceChip(
                label: Text(cat),
                selected: selectedCategory == cat,
                onSelected: (val) {
                  setState(() => selectedCategory = cat);
                },
                selectedColor: colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: selectedCategory == cat ? colorScheme.onPrimaryContainer : null,
                ),
              )).toList(),
            ),

            const SizedBox(height: 32),

            // Кнопка сохранения с градиентом
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: isSaving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Сохранить',
                          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный метод для стилизации полей ввода
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );
  }
}