import 'package:flutter/material.dart';
import '../../models/nutrition_models.dart';
import '../../providers/nutrition_provider.dart';

class AddFoodScreen extends StatefulWidget {
  final bool isDark;
  final DateTime date;
  final MealType? initialMeal;
  final FoodProduct? preselectedProduct;
  final NutritionProvider nutritionProvider; // ✅ Явный параметр (не через context)

  const AddFoodScreen({
    super.key,
    required this.isDark,
    required this.date,
    required this.nutritionProvider,
    this.initialMeal,
    this.preselectedProduct,
  });

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  static const bgDark = Color(0xFF0A0E1A);
  static const surface = Color(0xFF141A2E);
  static const cyan = Color(0xFF00D4FF);
  static const green = Color(0xFF00FF9D);

  final _searchController = TextEditingController();
  final _gramsController = TextEditingController(text: '100');
  String _query = '';
  String? _selectedCategory;
  FoodProduct? _selectedProduct;
  MealType _selectedMeal = MealType.suggestForNow();

  @override
  void initState() {
    super.initState();
    if (widget.initialMeal != null) _selectedMeal = widget.initialMeal!;
    if (widget.preselectedProduct != null) {
      _selectedProduct = widget.preselectedProduct;
      _query = widget.preselectedProduct!.name;
      _searchController.text = widget.preselectedProduct!.name;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Берём provider из widget, НЕ из context
    final provider = widget.nutritionProvider;

    // ✅ Базовый список: ВСЕ продукты при пустом query, иначе поиск
    final baseList = _query.isEmpty
        ? provider.products
        : provider.searchProducts(_query);

    // Фильтр по категории
    final filtered = _selectedCategory == null
        ? baseList
        : baseList.where((p) => p.category == _selectedCategory).toList();

    // Быстрые секции показываем только когда нет поиска и категории
    final showQuickSections = _query.isEmpty && _selectedCategory == null;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Добавить продукт',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              autofocus: widget.preselectedProduct == null,
              onChanged: (v) => setState(() {
                _query = v;
                _selectedProduct = null;
              }),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Поиск продукта...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: cyan),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _selectedProduct = null;
                    });
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

          // Категории
          if (_query.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryChip('Все', null),
                    ...{'meat', 'fish', 'dairy', 'grains', 'vegetables',
                      'fruits', 'nuts', 'legumes', 'drinks'}
                        .map((c) => _buildCategoryChip(_categoryName(c), c)),
                  ],
                ),
              ),
            ),

          // Выбор приёма
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: MealType.values
                  .map((m) => ChoiceChip(
                label: Text('${m.emoji} ${m.displayName}',
                    style: const TextStyle(fontSize: 11)),
                selected: _selectedMeal == m,
                selectedColor: cyan.withOpacity(0.3),
                backgroundColor: surface,
                labelStyle: TextStyle(
                  color: _selectedMeal == m
                      ? Colors.white
                      : Colors.white54,
                ),
                onSelected: (_) => setState(() => _selectedMeal = m),
              ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ Список продуктов (ЕДИНСТВЕННОЕ место ввода граммов — внутри карточки)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // 🔥 Быстрые секции (только при пустом поиске и без категории)
                if (showQuickSections) ..._buildQuickSections(provider),

                // Основной список
                if (filtered.isEmpty)
                  _buildEmptySearch()
                else
                  ...filtered.map((p) => _buildProductRow(provider, p)),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== БЫСТРЫЕ СЕКЦИИ ====================

  List<Widget> _buildQuickSections(NutritionProvider provider) {
    final recent = provider.getRecentProducts(limit: 8);
    final favorites = provider.favoriteProducts.take(8).toList();
    final sections = <Widget>[];

    if (recent.isNotEmpty) {
      sections.add(_buildSectionHeader('⚡ Недавние'));
      sections.add(_buildHorizontalList(provider, recent));
      sections.add(const SizedBox(height: 16));
    }

    if (favorites.isNotEmpty) {
      sections.add(_buildSectionHeader('⭐ Избранное'));
      sections.add(_buildHorizontalList(provider, favorites));
      sections.add(const SizedBox(height: 16));
    }

    if (sections.isNotEmpty) {
      sections.add(_buildSectionHeader('📦 Все продукты'));
      sections.add(const SizedBox(height: 8));
    }

    return sections;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHorizontalList(NutritionProvider provider, List<FoodProduct> items) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final p = items[i];
          return InkWell(
            onTap: () {
              setState(() {
                _selectedProduct = p;
                _query = p.name;
                _searchController.text = p.name;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 120,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.categoryEmoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    p.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    '${p.calories.round()} ккал',
                    style: TextStyle(
                      color: cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Ничего не найдено',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Попробуй другой запрос',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ==================== КАТЕГОРИИ ====================

  Widget _buildCategoryChip(String label, String? category) {
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
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? cyan : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _categoryName(String c) {
    const names = {
      'meat': '🥩 Мясо',
      'fish': '🐟 Рыба',
      'dairy': '🥛 Молочка',
      'grains': '🌾 Крупы',
      'vegetables': '🥬 Овощи',
      'fruits': '🍎 Фрукты',
      'nuts': '🥜 Орехи',
      'legumes': '🫘 Бобовые',
      'drinks': '☕ Напитки',
    };
    return names[c] ?? c;
  }

  // ==================== СТРОКА ПРОДУКТА (ЕДИНСТВЕННЫЙ ВВОД ГРАММОВ) ====================

  Widget _buildProductRow(NutritionProvider provider, FoodProduct p) {
    final isSelected = _selectedProduct?.id == p.id;
    final grams = double.tryParse(_gramsController.text) ?? 100;
    final macros = p.forGrams(grams);

    return InkWell(
      onTap: () {
        setState(() {
          // Повторный тап по выбранному — сворачивает панель
          if (isSelected) {
            _selectedProduct = null;
          } else {
            _selectedProduct = p;
            _gramsController.text = '100';
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? cyan.withOpacity(0.15) : surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cyan : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.categoryEmoji,
                      style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        p.categoryName,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.keyboard_arrow_up_rounded, color: cyan)
                else
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white24),
                IconButton(
                  icon: Icon(
                    p.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: p.isFavorite ? Colors.amber : Colors.white24,
                  ),
                  onPressed: () => provider.toggleFavorite(p.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMacroBadge('🔥', '${p.calories.round()}', 'ккал', cyan),
                _buildMacroBadge('Б', p.protein.toStringAsFixed(1), 'г', green),
                _buildMacroBadge('Ж', p.fat.toStringAsFixed(1), 'г',
                    const Color(0xFFFF2D55)),
                _buildMacroBadge('У', p.carbs.toStringAsFixed(1), 'г',
                    const Color(0xFFFFD60A)),
              ],
            ),
            // ✅ ЕДИНСТВЕННАЯ панель ввода граммов (с готовыми кнопками)
            if (isSelected) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _gramsController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '100',
                        suffixText: 'г',
                        suffixStyle: TextStyle(color: Colors.white54, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroBadge('🔥', '${macros.calories.round()}', 'ккал', cyan),
                        _buildMacroBadge('Б', '${macros.protein.toStringAsFixed(1)}', 'г', green),
                        _buildMacroBadge('Ж', '${macros.fat.toStringAsFixed(1)}', 'г',
                            const Color(0xFFFF2D55)),
                        _buildMacroBadge('У', '${macros.carbs.toStringAsFixed(1)}', 'г',
                            const Color(0xFFFFD60A)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [50, 100, 150, 200, 250]
                          .map((g) => InkWell(
                        onTap: () =>
                            setState(() => _gramsController.text = '$g'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border:
                            Border.all(color: cyan.withOpacity(0.4)),
                          ),
                          child: Text(
                            '$g г',
                            style: const TextStyle(
                              color: cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final grams = double.tryParse(_gramsController.text);
                          if (grams == null || grams <= 0) return;
                          await provider.addEntry(
                            product: p,
                            grams: grams,
                            mealType: _selectedMeal,
                            date: widget.date,
                          );
                          if (mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          'Добавить ${_gramsController.text} г',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyan,
                          foregroundColor: bgDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBadge(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value$unit',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}