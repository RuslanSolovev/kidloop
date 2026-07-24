import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/bundle_provider.dart';
import '../../core/items_provider.dart';
import '../../core/item_model.dart';
import '../../core/sv_calculator.dart';

class CreateBundleScreen extends StatefulWidget {
  const CreateBundleScreen({super.key});

  @override
  State<CreateBundleScreen> createState() => _CreateBundleScreenState();
}

class _CreateBundleScreenState extends State<CreateBundleScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String selectedCondition = 'Хороший';
  String selectedLocation = 'Рига';
  List<Item> selectedItems = [];
  List<String> selectedCategories = [];
  bool _isUploading = false;
  int totalSv = 0;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF0A0A1A) : const Color(0xFFFFF8F0);
  Color get _cardBorderColor => _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;

  final allCategories = SvCalculator.categoryBase.keys.toList()..sort();
  final conditions = ['Новый', 'Отличный', 'Хороший', 'Обычный'];
  final locations = ['Москва', 'Санкт-Петербург', 'Рига', 'Юрмала'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemsProvider>().loadItems();
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _updateTotalSv() {
    int sum = 0;
    for (final item in selectedItems) sum += item.sv;
    setState(() => totalSv = sum);
  }

  void _toggleItem(Item item) {
    setState(() {
      if (selectedItems.contains(item)) {
        selectedItems.remove(item);
        final remainingCategories = selectedItems.map((e) => e.category).toSet();
        selectedCategories.removeWhere((c) => !remainingCategories.contains(c));
      } else {
        if (selectedItems.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Максимум 5 предметов в наборе'), backgroundColor: Colors.orange),
          );
          return;
        }
        selectedItems.add(item);
      }
      _updateTotalSv();
    });
  }

  void _toggleCategory(String category) {
    setState(() {
      if (selectedCategories.contains(category)) {
        selectedCategories.remove(category);
      } else {
        selectedCategories.add(category);
      }
    });
  }

  Future<List<String>> _getCollageImages() async {
    final List<String> urls = [];
    for (final item in selectedItems.take(4)) {
      if (item.imagePaths.isNotEmpty) {
        urls.add(item.imagePaths.first);
      }
    }
    return urls;
  }

  Future<void> _createBundle() async {
    if (!_formKey.currentState!.validate()) return;

    final availableItems = selectedItems
        .where((item) => item.status == 'available')
        .toList();

    if (availableItems.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Нужно минимум 2 доступных предмета. Выбрано: ${selectedItems.length}, доступно: ${availableItems.length}.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (selectedCategories.isEmpty) {
      final autoCategories = availableItems
          .map((e) => e.category)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      selectedCategories.addAll(autoCategories);
    }
    if (selectedCategories.isEmpty) {
      selectedCategories.add('Игрушки');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(16)),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Создаём набор...', style: TextStyle(fontSize: 14)),
          ]),
        ),
      ),
    );

    final imageUrls = await _getCollageImages();
    if (mounted) Navigator.pop(context);

    if (imageUrls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет фото для набора'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    final result = await context.read<BundleProvider>().createBundle(
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      itemIds: availableItems.map((e) => e.itemId).toList(),
      imagePaths: imageUrls,
      location: selectedLocation,
      categories: selectedCategories,
      condition: selectedCondition,
    );

    if (mounted) Navigator.pop(context);

    if (mounted) {
      if (result['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Набор создан! 🎉'), backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${result['error'] ?? 'Неизвестная ошибка'}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myItems = context.watch<ItemsProvider>().items.where((e) => e.isMine).toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Создать набор', style: TextStyle(fontWeight: FontWeight.bold, color: _textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: _textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('📦 Выберите предметы (минимум 2 доступных)'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: myItems.isEmpty
                          ? Center(child: Text('У вас нет вещей', style: TextStyle(color: _subTextColor)))
                          : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: myItems.length,
                        itemBuilder: (context, index) {
                          final item = myItems[index];
                          final isSelected = selectedItems.contains(item);
                          final isInBundle = item.status == 'in_bundle';
                          final isReserved = item.status == 'reserved' || item.status == 'swapped';
                          final isBlocked = isInBundle || isReserved;

                          // 🔥 Цвет и иконка зависят от статуса
                          final Color blockColor = isInBundle ? Colors.purple : Colors.orange;
                          final IconData blockIcon = isInBundle ? Icons.inventory_2 : Icons.lock;
                          final String blockText = isInBundle ? 'В наборе' : 'В сделке';

                          return GestureDetector(
                            onTap: isBlocked ? null : () => _toggleItem(item),
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: isBlocked ? blockColor.withOpacity(0.06) : _surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.orange
                                      : isBlocked
                                      ? blockColor.withOpacity(0.35)
                                      : _cardBorderColor,
                                  width: isSelected ? 2.5 : (isBlocked ? 1.5 : 1),
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Иконка
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                      child: const Icon(Icons.check, color: Colors.white, size: 18),
                                    )
                                  else if (isBlocked)
                                    Icon(blockIcon, color: blockColor, size: 24)
                                  else
                                    const Icon(Icons.add_circle_outline, color: Colors.grey, size: 24),

                                  const SizedBox(height: 8),

                                  // Название
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      item.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isBlocked ? blockColor : _textColor,
                                        decoration: isBlocked ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  // Статус или SV
                                  if (isBlocked)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: blockColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        blockText,
                                        style: TextStyle(color: blockColor, fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${item.sv} SV',
                                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (selectedItems.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                        child: Row(children: [
                          const Icon(Icons.inventory_2, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text('Выбрано: ${selectedItems.length} предмета(ов)', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]), borderRadius: BorderRadius.all(Radius.circular(12))), child: Text('$totalSv SV', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _sectionTitle('🏷️ Категории (можно несколько)'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allCategories.map((cat) {
                        final isSelected = selectedCategories.contains(cat);
                        return GestureDetector(
                          onTap: () => _toggleCategory(cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.orange : _surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? Colors.orange : _cardBorderColor, width: 1.5),
                            ),
                            child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : _textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('📝 Название'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: titleController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                      style: TextStyle(color: _textColor),
                      decoration: InputDecoration(hintText: 'Например: Набор LEGO и кукол', filled: true, fillColor: _surfaceColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('📄 Описание'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descriptionController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите описание' : null,
                      maxLines: 3,
                      style: TextStyle(color: _textColor),
                      decoration: InputDecoration(hintText: 'Опишите набор...', filled: true, fillColor: _surfaceColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('⭐ Состояние'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorderColor)),
                      child: DropdownButtonFormField<String>(
                        value: selectedCondition,
                        dropdownColor: _surfaceColor,
                        style: TextStyle(color: _textColor),
                        decoration: const InputDecoration(border: InputBorder.none),
                        items: conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => selectedCondition = v!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('📍 Город'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorderColor)),
                      child: DropdownButtonFormField<String>(
                        value: selectedLocation,
                        dropdownColor: _surfaceColor,
                        style: TextStyle(color: _textColor),
                        decoration: const InputDecoration(border: InputBorder.none),
                        items: locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                        onChanged: (v) => setState(() => selectedLocation = v!),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _createBundle,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: Colors.orange.withOpacity(0.5)),
                        child: Text(_isUploading ? 'Создание...' : 'Создать набор', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor)),
    ]);
  }
}