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
    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать профиль')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Аватар
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                child: _avatarUrl.isEmpty
                    ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text('Нажми, чтобы изменить фото',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: cityController,
              decoration: const InputDecoration(
                labelText: 'Город',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'О себе',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Возраст',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: telegramController,
              decoration: const InputDecoration(
                labelText: 'Telegram',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedCategory = value);
              },
              decoration: const InputDecoration(
                labelText: 'Любимая категория',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Сохранить', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}