import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import '../../core/item_model.dart';
import '../../core/items_provider.dart';
import '../../core/sv_calculator.dart';


class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  String selectedCategory = 'Игрушки';
  String selectedCondition = 'Хороший';
  String selectedLocation = 'Рига';

  int currentSv = 50;
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  final categories = [
    'Игрушки', 'LEGO', 'Самокат', 'Книги', 'Одежда',
    'Коляска', 'Мебель', 'Техника', 'Развивашки', 'Спорт',
    'Творчество', 'Пазлы', 'Конструктор', 'Куклы', 'Машинки',
  ];
  final conditions = ['Новый', 'Отличный', 'Хороший', 'Обычный'];

  final locations = [
    'Москва', 'Санкт-Петербург','Щёлково', 'Фрязино', 'Новосибирск', 'Екатеринбург', 'Казань',
    'Нижний Новгород', 'Челябинск', 'Самара', 'Омск', 'Ростов-на-Дону',
    'Уфа', 'Красноярск', 'Воронеж', 'Пермь', 'Волгоград',
    'Краснодар', 'Саратов', 'Тюмень', 'Тольятти', 'Ижевск',
    'Барнаул', 'Иркутск', 'Хабаровск', 'Ярославль', 'Владивосток',
    'Махачкала', 'Томск', 'Оренбург', 'Кемерово', 'Новокузнецк',
    'Рига', 'Юрмала', 'Даугавпилс',
  ];

  @override
  void initState() {
    super.initState();
    updateSv();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void updateSv() {
    currentSv = SvCalculator.calculate(
      category: selectedCategory,
      condition: selectedCondition,
    );
    setState(() {});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _uploadedImageUrl = null;
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    setState(() => _isUploading = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64 = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://functions.yandexcloud.net/d4e3c2me21eou683ic6d'),


        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "upload",
          "file_name": "photo.jpg",
          "file_data": base64,
        }),
      );

      print("UPLOAD RESPONSE: ${response.body}");

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        setState(() {
          _uploadedImageUrl = data['file_url'];
          _isUploading = false;
        });
        return data['file_url'];
      } else {
        print("UPLOAD ERROR: ${data['error']}");
        setState(() => _isUploading = false);
        return null;
      }
    } catch (e) {
      print("UPLOAD ERROR: $e");
      setState(() => _isUploading = false);
      return null;
    }
  }

  void saveItem() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) return;

    final imageUrl = await _uploadImage();

    final item = Item(
      itemId: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: 'me',
      title: title,
      description: description,
      sv: currentSv,
      imagePath: imageUrl ?? 'assets/images/bear.jpg',
      location: selectedLocation,
      category: selectedCategory,
      condition: selectedCondition,
      isMine: true,
    );

    await context.read<ItemsProvider>().addItem(item);

    // Переход обратно в ленту
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить вещь')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Фото
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  image: _selectedImage != null
                      ? DecorationImage(
                    image: FileImage(_selectedImage!),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: _selectedImage == null
                    ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Добавить фото', style: TextStyle(color: Colors.grey)),
                  ],
                )
                    : null,
              ),
            ),
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
            if (_uploadedImageUrl != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('✅ Фото загружено', style: TextStyle(color: Colors.green)),
              ),

            const SizedBox(height: 16),

            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (value) {
                if (value == null) return;
                selectedCategory = value;
                updateSv();
              },
              decoration: const InputDecoration(labelText: 'Категория'),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: selectedCondition,
              items: conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (value) {
                if (value == null) return;
                selectedCondition = value;
                updateSv();
              },
              decoration: const InputDecoration(labelText: 'Состояние'),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: selectedLocation,
              items: locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedLocation = value);
              },
              decoration: const InputDecoration(labelText: 'Город'),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Система оценила вещь в', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('$currentSv SV',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveItem,
                child: const Text('Опубликовать'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}