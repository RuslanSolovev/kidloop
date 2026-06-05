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

class _AddItemScreenState extends State<AddItemScreen>
    with SingleTickerProviderStateMixin {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  String selectedCategory = 'Игрушки';
  String selectedCondition = 'Хороший';
  String selectedLocation = 'Рига';

  int currentSv = 50;
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final categories = [
    'Игрушки', 'LEGO', 'Самокат', 'Книги', 'Одежда',
    'Коляска', 'Мебель', 'Техника', 'Развивашки', 'Спорт',
    'Творчество', 'Пазлы', 'Конструктор', 'Куклы', 'Машинки',
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
  ];

  @override
  void initState() {
    super.initState();
    updateSv();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void updateSv() {
    setState(() {
      currentSv = SvCalculator.calculate(
        category: selectedCategory,
        condition: selectedCondition,
      );
    });
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

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        setState(() {
          _uploadedImageUrl = data['file_url'];
          _isUploading = false;
        });
        return data['file_url'];
      } else {
        setState(() => _isUploading = false);
        return null;
      }
    } catch (e) {
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

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 80,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Новое объявление',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Блок фото
                  _buildImagePicker(),
                  const SizedBox(height: 24),

                  // Название
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Название',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Описание
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Описание',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Категория (чипсы)
                  Text('Категория', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = selectedCategory == cat;
                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedCategory = cat);
                            updateSv();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.orange.shade100
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.orange : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.orange.shade900 : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Состояние (чипсы)
                  Text('Состояние', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: conditions.map((cond) {
                      final isSelected = selectedCondition == cond;
                      return ChoiceChip(
                        label: Text(cond),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() => selectedCondition = cond);
                          updateSv();
                        },
                        selectedColor: Colors.green.shade100,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.green.shade900 : Colors.black87,
                          fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? Colors.green : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Город
                  DropdownButtonFormField<String>(
                    value: selectedLocation,
                    decoration: InputDecoration(
                      labelText: 'Город',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: locations
                        .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedLocation = val);
                    },
                  ),
                  const SizedBox(height: 28),

                  // Блок SV
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade300, Colors.deepOrange.shade300],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Система оценила вещь в',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.auto_awesome, color: Colors.amber),
                              const SizedBox(width: 8),
                              Text(
                                '$currentSv SV',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Кнопка публикации
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: Colors.orange.withOpacity(0.5),
                      ),
                      child: const Text(
                        'Опубликовать',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _selectedImage != null ? Colors.orange : Colors.grey.shade300,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          image: _selectedImage != null
              ? DecorationImage(
            image: FileImage(_selectedImage!),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: _selectedImage == null
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.1),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined,
                  size: 48, color: Colors.orange),
            ),
            const SizedBox(height: 12),
            const Text('Добавить фото',
                style: TextStyle(color: Colors.orange, fontSize: 16)),
            if (_isUploading) ...[
              const SizedBox(height: 12),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(color: Colors.orange),
              ),
            ],
          ],
        )
            : Stack(
          children: [
            if (_uploadedImageUrl != null)
              const Positioned(
                right: 8,
                top: 8,
                child: Icon(Icons.check_circle, color: Colors.green, size: 32),
              ),
            if (_isUploading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}