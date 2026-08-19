import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/nutrition_models.dart';
import '../../providers/nutrition_provider.dart';
import 'add_food_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  final bool isDark;
  const FoodSearchScreen({super.key, this.isDark = true});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

enum FoodSortMode { name, caloriesAsc, caloriesDesc, proteinDesc }

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  static const bgDark = Color(0xFF0A0E1A);
  static const surface = Color(0xFF141A2E);
  static const cyan = Color(0xFF00D4FF);
  static const green = Color(0xFF00FF9D);
  static const pink = Color(0xFFFF2D55);
  static const yellow = Color(0xFFFFD60A);

  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedCategory;
  bool _favoritesOnly = false;
  FoodSortMode _sortMode = FoodSortMode.name;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NutritionProvider>();
    final products = _getFilteredProducts(provider);
    final categories = _getCategories(provider);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('База продуктов',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        actions: [
          // Сортировка
          PopupMenuButton<FoodSortMode>(
            icon: const Icon(Icons.sort_rounded, color: cyan),
            onSelected: (m) => setState(() => _sortMode = m),
            itemBuilder: (ctx) => [
              _sortItem(FoodSortMode.name, 'По алфавиту'),
              _sortItem(FoodSortMode.caloriesAsc, 'Калории ↑'),
              _sortItem(FoodSortMode.caloriesDesc, 'Калории ↓'),
              _sortItem(FoodSortMode.proteinDesc, 'Белок ↓'),
            ],
          ),
          // Своё блюдо
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: green),
            onPressed: () => _showCustomProductDialog(provider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Поиск: курица, овсянка, творог...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: cyan),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Категории + избранное
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryChip('Все', null),
                  _categoryChip('⭐ Избранное', '__fav__'),
                  ...categories.map((c) => _categoryChip(_catName(c), c)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Счётчик
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('${products.length} продуктов',
                    style: const TextStyle(
                      color: Colors.white38, fontSize: 11,
                      fontWeight: FontWeight.w700, fontFamily: 'monospace',
                    )),
                const Spacer(),
                if (_sortMode != FoodSortMode.name)
                  Text(_sortLabel(_sortMode),
                      style: TextStyle(
                        color: cyan, fontSize: 11, fontWeight: FontWeight.w700,
                      )),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Список
          Expanded(
            child: products.isEmpty
                ? _buildEmpty()
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: products.length,
              itemBuilder: (ctx, i) => _buildProductRow(provider, products[i]),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ЛОГИКА ====================

  List<FoodProduct> _getFilteredProducts(NutritionProvider provider) {
    // Явно приводим к List<FoodProduct> на случай, если searchProducts возвращает dynamic
    List<FoodProduct> list = _query.isEmpty
        ? List<FoodProduct>.from(provider.products)
        : List<FoodProduct>.from(provider.searchProducts(_query));

    if (_selectedCategory == '__fav__') {
      list = List<FoodProduct>.from(list.where((p) => p.isFavorite));
    } else if (_selectedCategory != null) {
      list = List<FoodProduct>.from(list.where((p) => p.category == _selectedCategory));
    }

    switch (_sortMode) {
      case FoodSortMode.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case FoodSortMode.caloriesAsc:
        list.sort((a, b) => a.calories.compareTo(b.calories));
        break;
      case FoodSortMode.caloriesDesc:
        list.sort((a, b) => b.calories.compareTo(a.calories));
        break;
      case FoodSortMode.proteinDesc:
        list.sort((a, b) => b.protein.compareTo(a.protein));
        break;
    }
    return list;
  }

  List<String> _getCategories(NutritionProvider provider) {
    // Явно типизируем map через <String> — это ключевой момент
    final Set<String> set = provider.products
        .map<String>((p) => p.category)  // ← Явно указываем тип результата map
        .toSet();                         // ← Без дженерик-параметра, тип наследуется
    final list = set.toList()..sort();
    return list;
  }

  String _catName(String c) {
    const names = {
      'meat': '🥩 Мясо', 'fish': '🐟 Рыба', 'dairy': '🥛 Молочка',
      'grains': '🌾 Крупы', 'vegetables': '🥬 Овощи', 'fruits': '🍎 Фрукты',
      'nuts': '🥜 Орехи', 'seeds': '🌱 Семена', 'legumes': '🫘 Бобовые',
      'oils': '🫒 Масла', 'sweets': '🍫 Сладости', 'drinks': '☕ Напитки',
      'bakery': '🥐 Выпечка', 'fastfood': '🍔 Фастфуд',
      'supplements': '💊 Добавки', 'sauces': '🧂 Соусы', 'other': '🍽️ Другое',
    };
    return names[c] ?? c;
  }

  String _sortLabel(FoodSortMode m) {
    switch (m) {
      case FoodSortMode.name: return 'А-Я';
      case FoodSortMode.caloriesAsc: return 'Калории ↑';
      case FoodSortMode.caloriesDesc: return 'Калории ↓';
      case FoodSortMode.proteinDesc: return 'Белок ↓';
    }
  }

  PopupMenuItem<FoodSortMode> _sortItem(FoodSortMode m, String label) {
    return PopupMenuItem(
      value: m,
      child: Row(
        children: [
          Icon(_sortMode == m ? Icons.check_circle : Icons.radio_button_unchecked,
              color: _sortMode == m ? cyan : Colors.grey, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  // ==================== UI ====================

  Widget _categoryChip(String label, String? category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = category),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? cyan.withOpacity(0.2) : surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? cyan : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: isSelected ? cyan : Colors.white70,
              fontSize: 12, fontWeight: FontWeight.w700,
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Ничего не найдено', style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 6),
          const Text('Попробуй другой запрос или категорию',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showCustomProductDialog(context.read<NutritionProvider>()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Создать свой продукт'),
            style: ElevatedButton.styleFrom(
              backgroundColor: green, foregroundColor: bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(NutritionProvider provider, FoodProduct p) {
    return InkWell(
      onTap: () => _showProductSheet(provider, p),
      onLongPress: () => provider.toggleFavorite(p.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(p.categoryEmoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(p.name, style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                        ), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (p.isFavorite)
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      if (p.isCustom)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('МОЁ', style: TextStyle(
                            color: green, fontSize: 9, fontWeight: FontWeight.w800,
                          )),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _badge('🔥', '${p.calories.round()}', cyan),
                      const SizedBox(width: 6),
                      _badge('Б', p.protein.toStringAsFixed(1), green),
                      const SizedBox(width: 6),
                      _badge('Ж', p.fat.toStringAsFixed(1), pink),
                      const SizedBox(width: 6),
                      _badge('У', p.carbs.toStringAsFixed(1), yellow),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label $value', style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace',
      )),
    );
  }

  // ==================== ДЕТАЛИ ПРОДУКТА ====================

  void _showProductSheet(NutritionProvider provider, FoodProduct p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(p.categoryEmoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900,
                      )),
                      Text('${_catName(p.category)} • на 100 г',
                          style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    p.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: p.isFavorite ? Colors.amber : Colors.white24,
                  ),
                  onPressed: () {
                    provider.toggleFavorite(p.id);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _macroCard('КАЛОРИИ', '${p.calories.round()}', 'ккал', cyan),
                const SizedBox(width: 8),
                _macroCard('БЕЛОК', p.protein.toStringAsFixed(1), 'г', green),
                const SizedBox(width: 8),
                _macroCard('ЖИРЫ', p.fat.toStringAsFixed(1), 'г', pink),
                const SizedBox(width: 8),
                _macroCard('УГЛЕВ.', p.carbs.toStringAsFixed(1), 'г', yellow),
              ],
            ),
            if (p.fiber > 0) ...[
              const SizedBox(height: 8),
              Text('🌾 Клетчатка: ${p.fiber.toStringAsFixed(1)} г',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddFoodScreen(
                        isDark: widget.isDark,
                        date: DateTime.now(),
                        preselectedProduct: p,
                        nutritionProvider: provider, // ✅ ЯВНО передаём
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('ДОБАВИТЬ В ДНЕВНИК',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cyan, foregroundColor: bgDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _macroCard(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              color: color, fontSize: 16,
              fontWeight: FontWeight.w900, fontFamily: 'monospace',
            )),
            Text('$label', style: TextStyle(
              color: color.withOpacity(0.7), fontSize: 8,
              fontWeight: FontWeight.w800, letterSpacing: 0.5,
            )),
          ],
        ),
      ),
    );
  }

  // ==================== СВОЙ ПРОДУКТ ====================

  void _showCustomProductDialog(NutritionProvider provider) {
    final nameC = TextEditingController();
    final calC = TextEditingController();
    final pC = TextEditingController();
    final fC = TextEditingController();
    final cC = TextEditingController();
    String category = 'other';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Свой продукт',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field('Название *', nameC),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: surface,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    labelStyle: TextStyle(color: Colors.white54),
                    filled: true, fillColor: Colors.transparent,
                    border: OutlineInputBorder(),
                  ),
                  items: <String>['meat','fish','dairy','grains','vegetables','fruits',
                    'nuts','legumes','sweets','drinks','other']
                      .map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(
                      value: c, child: Text(_catName(c))))
                      .toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 10),
                _field('Калории (ккал/100г) *', calC),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _field('Белки (г)', pC)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Жиры (г)', fC)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Углеводы (г)', cC)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameC.text.trim();
                final cal = double.tryParse(calC.text);
                if (name.isEmpty || cal == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Заполни название и калории'),
                    backgroundColor: pink,
                  ));
                  return;
                }
                Navigator.pop(ctx);
                await provider.addCustomProduct(
                  name: name,
                  calories: cal,
                  protein: double.tryParse(pC.text) ?? 0,
                  fat: double.tryParse(fC.text) ?? 0,
                  carbs: double.tryParse(cC.text) ?? 0,
                  category: category,
                );
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Продукт "$name" создан'),
                  backgroundColor: green,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: green, foregroundColor: bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Создать', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}