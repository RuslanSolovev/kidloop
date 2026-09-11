// features/bundles/create_bundle_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/bundle_provider.dart';
import '../../core/items_provider.dart';
import '../../core/item_model.dart';
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
    HapticFeedback.selectionClick();
    setState(() {
      if (selectedItems.contains(item)) {
        selectedItems.remove(item);
        final remainingCategories =
        selectedItems.map((e) => e.category).toSet();
        selectedCategories.removeWhere((c) => !remainingCategories.contains(c));
      } else {
        if (selectedItems.length >= 5) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Максимум 5 предметов в наборе'),
              backgroundColor: _IOS.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
          return;
        }
        selectedItems.add(item);
      }
      _updateTotalSv();
    });
  }

  void _toggleCategory(String category) {
    HapticFeedback.selectionClick();
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

    final availableItems =
    selectedItems.where((item) => item.status == 'available').toList();

    if (availableItems.length < 2) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Нужно минимум 2 доступных предмета.\nВыбрано: ${selectedItems.length}, доступно: ${availableItems.length}',
            ),
            backgroundColor: _IOS.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildProgressDialog('Создаём набор…'),
    );

    final imageUrls = await _getCollageImages();
    if (mounted) Navigator.pop(context);

    if (imageUrls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Нет фото для набора'),
            backgroundColor: _IOS.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildProgressDialog('Публикуем…'),
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
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Набор создан 🎉'),
            backgroundColor: _IOS.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${result['error'] ?? 'Неизвестная'}'),
            backgroundColor: _IOS.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    }
  }

  Widget _buildProgressDialog(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _IOS.card(_isDarkMode),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: _IOS.blue,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _IOS.textPrimary(_isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;
    final myItems = context
        .watch<ItemsProvider>()
        .items
        .where((e) => e.isMine)
        .toList();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
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
                    // ---------- ITEMS ----------
                    _buildSectionTitle('Выберите предметы', isDark),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'Минимум 2 доступных, максимум 5',
                        style: TextStyle(
                          fontSize: 12,
                          color: _IOS.textTertiary(isDark),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 158,
                      child: myItems.isEmpty
                          ? _buildNoItems(isDark)
                          : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2),
                        itemCount: myItems.length,
                        itemBuilder: (context, index) {
                          return _buildItemTile(myItems[index], isDark);
                        },
                      ),
                    ),

                    if (selectedItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSelectionSummary(isDark),
                    ],

                    const SizedBox(height: 26),

                    // ---------- CATEGORIES ----------
                    _buildSectionTitle('Категории', isDark),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'Можно выбрать несколько',
                        style: TextStyle(
                          fontSize: 12,
                          color: _IOS.textTertiary(isDark),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allCategories.map((cat) {
                        final isSelected = selectedCategories.contains(cat);
                        return GestureDetector(
                          onTap: () => _toggleCategory(cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
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
                      }).toList(),
                    ),

                    const SizedBox(height: 26),

                    // ---------- TITLE ----------
                    _buildSectionTitle('Название', isDark),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: titleController,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Введите название'
                          : null,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _IOS.textPrimary(isDark),
                      ),
                      decoration: _inputDecoration(
                        hint: 'Например: Набор LEGO и кукол',
                        isDark: isDark,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---------- DESCRIPTION ----------
                    _buildSectionTitle('Описание', isDark),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descriptionController,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Введите описание'
                          : null,
                      maxLines: 4,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _IOS.textPrimary(isDark),
                      ),
                      decoration: _inputDecoration(
                        hint: 'Опишите набор…',
                        isDark: isDark,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---------- CONDITION ----------
                    _buildSectionTitle('Состояние', isDark),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: selectedCondition,
                      items: conditions,
                      isDark: isDark,
                      onChanged: (v) =>
                          setState(() => selectedCondition = v!),
                    ),

                    const SizedBox(height: 20),

                    // ---------- LOCATION ----------
                    _buildSectionTitle('Город', isDark),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: selectedLocation,
                      items: locations,
                      isDark: isDark,
                      onChanged: (v) =>
                          setState(() => selectedLocation = v!),
                    ),

                    const SizedBox(height: 32),

                    // ---------- SUBMIT ----------
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _createBundle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _IOS.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          _IOS.blue.withOpacity(0.4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _isUploading ? 'Создание…' : 'Создать набор',
                          style: const TextStyle(
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
        'Новый набор',
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
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required bool isDark,
  }) {
    return InputDecoration(
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
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _IOS.inputFill(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _IOS.separator(isDark)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: _IOS.card(isDark),
        style: TextStyle(
          color: _IOS.textPrimary(isDark),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _IOS.textSecondary(isDark),
        ),
        items: items
            .map((c) => DropdownMenuItem(
          value: c,
          child: Text(
            c,
            style: TextStyle(
              color: _IOS.textPrimary(isDark),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ))
            .toList(),
        onChanged: (v) {
          HapticFeedback.selectionClick();
          onChanged(v);
        },
      ),
    );
  }

  // ============================================================
  // NO ITEMS
  // ============================================================

  Widget _buildNoItems(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: _IOS.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _IOS.separator(isDark)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _IOS.blue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: _IOS.blue,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'У вас пока нет вещей',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _IOS.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ITEM TILE
  // ============================================================

  Widget _buildItemTile(Item item, bool isDark) {
    final isSelected = selectedItems.contains(item);
    final isInBundle = item.status == 'in_bundle';
    final isReserved =
        item.status == 'reserved' || item.status == 'swapped';
    final isBlocked = isInBundle || isReserved;

    final Color blockColor = isInBundle ? _IOS.purple : _IOS.orange;
    final IconData blockIcon =
    isInBundle ? Icons.inventory_2_rounded : Icons.lock_rounded;
    final String blockText = isInBundle ? 'В наборе' : 'В сделке';

    return GestureDetector(
      onTap: isBlocked ? null : () => _toggleItem(item),
      child: Container(
        width: 118,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: _IOS.card(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? _IOS.blue
                : isBlocked
                ? blockColor.withOpacity(0.35)
                : _IOS.separator(isDark),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon / check
              if (isSelected)
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: _IOS.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                )
              else if (isBlocked)
                Icon(blockIcon, color: blockColor, size: 24)
              else
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _IOS.blue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: _IOS.blue,
                    size: 18,
                  ),
                ),

              const SizedBox(height: 10),

              // Title
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: isBlocked
                      ? blockColor
                      : _IOS.textPrimary(isDark),
                  decoration:
                  isBlocked ? TextDecoration.lineThrough : null,
                ),
              ),

              const SizedBox(height: 6),

              // Status / SV
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isBlocked
                      ? blockColor.withOpacity(0.14)
                      : _IOS.orange.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isBlocked ? blockText : '${item.sv} SV',
                  style: TextStyle(
                    color: isBlocked ? blockColor : _IOS.orange,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: -0.1,
                    height: 1,
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
  // SELECTION SUMMARY
  // ============================================================

  Widget _buildSelectionSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _IOS.blue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _IOS.blue.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _IOS.blue.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: _IOS.blue,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Выбрано: ${selectedItems.length}',
              style: const TextStyle(
                color: _IOS.blue,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _IOS.orange.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$totalSv SV',
              style: const TextStyle(
                color: _IOS.orange,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: -0.2,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}