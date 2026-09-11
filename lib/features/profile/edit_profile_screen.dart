import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/profile_provider.dart';
import '../../core/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
  });

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  static const Color _accent = Color(0xFFFF6B00);
  static const Color _accent2 = Color(0xFFFF8A3D);
  static const Color _cyan = Color(0xFF42DFFF);
  static const Color _violet = Color(0xFF9A7CFF);
  static const Color _green = Color(0xFF40E0A0);

  late final TextEditingController nameController;
  late final TextEditingController cityController;
  late final TextEditingController bioController;
  late final TextEditingController ageController;
  late final TextEditingController telegramController;

  String selectedCategory = 'LEGO';
  String _avatarUrl = '';
  bool isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isDarkMode = false;

  final List<String> categories = [
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

  final List<String> locations = [
    'Москва',
    'Санкт-Петербург',
    'Щёлково',
    'Фрязино',
    'Новосибирск',
    'Екатеринбург',
    'Казань',
    'Нижний Новгород',
    'Челябинск',
    'Самара',
    'Омск',
    'Ростов-на-Дону',
    'Уфа',
    'Красноярск',
    'Воронеж',
    'Пермь',
    'Волгоград',
    'Краснодар',
    'Саратов',
    'Тюмень',
    'Тольятти',
    'Ижевск',
    'Барнаул',
    'Иркутск',
    'Хабаровск',
    'Ярославль',
    'Владивосток',
    'Махачкала',
    'Томск',
    'Оренбург',
    'Кемерово',
    'Новокузнецк',
    'Рига',
    'Юрмала',
    'Даугавпилс',
    'Лиепая',
    'Вентспилс',
    'Елгава',
    'Резекне',
    'Таллин',
  ];

  @override
  void initState() {
    super.initState();

    _loadThemeMode();

    final profile =
        context.read<ProfileProvider>().profile;

    nameController =
        TextEditingController(text: profile.name);

    cityController =
        TextEditingController(text: profile.city);

    bioController =
        TextEditingController(text: profile.bio);

    ageController = TextEditingController(
      text: profile.age > 0
          ? profile.age.toString()
          : '',
    );

    telegramController =
        TextEditingController(text: profile.telegram);

    selectedCategory =
    profile.favoriteCategory.isNotEmpty
        ? profile.favoriteCategory
        : 'LEGO';

    _avatarUrl = profile.avatarUrl;
  }

  Future<void> _loadThemeMode() async {
    final prefs =
    await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _isDarkMode =
          prefs.getBool('is_dark_mode') ?? false;
    });
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
    if (_isUploadingAvatar || isSaving) {
      return;
    }

    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );

      if (picked == null) {
        return;
      }

      setState(() {
        _isUploadingAvatar = true;
      });

      final bytes =
      await File(picked.path).readAsBytes();

      final encoded =
      base64Encode(bytes);

      final response = await http
          .post(
        Uri.parse(
          'https://functions.yandexcloud.net/d4e3c2me21eou683ic6d',
        ),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'upload',
          'file_data': encoded,
        }),
      )
          .timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Upload failed: ${response.statusCode}',
        );
      }

      final data = jsonDecode(
        response.body,
      );

      if (data is Map &&
          data['ok'] == true &&
          data['file_url'] != null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _avatarUrl =
              data['file_url'].toString();
          _isUploadingAvatar = false;
        });

        _showSnackBar(
          'Фото успешно загружено',
          accent: _green,
        );
      } else {
        throw Exception(
          'Сервер не вернул URL изображения',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });

        _showSnackBar(
          'Не удалось загрузить фото',
          accent: const Color(0xFFFF5D73),
        );
      }

      debugPrint(
        'AVATAR UPLOAD ERROR: $e',
      );
    }
  }

  Future<void> save() async {
    if (isSaving) {
      return;
    }

    final age =
        int.tryParse(
          ageController.text.trim(),
        ) ??
            0;

    final updated = UserProfile(
      name: nameController.text.trim(),
      city: cityController.text.trim(),
      bio: bioController.text.trim(),
      age: age,
      favoriteCategory: selectedCategory,
      telegram:
      telegramController.text.trim(),
      avatarUrl: _avatarUrl,
    );

    context
        .read<ProfileProvider>()
        .updateProfile(updated);

    setState(() {
      isSaving = true;
    });

    try {
      final prefs =
      await SharedPreferences.getInstance();

      final userId =
          prefs.getString('user_id') ??
              'unknown';

      final url = Uri.parse(
        'https://functions.yandexcloud.net/d4euctluka7dnot8sosh',
      );

      final response = await http
          .post(
        url,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'update',
          'user_id': userId,
          'name': updated.name,
          'city': updated.city,
          'bio': updated.bio,
          'telegram': updated.telegram,
          'age': updated.age,
          'avatar_url': _avatarUrl,
        }),
      )
          .timeout(
        const Duration(seconds: 15),
      );

      debugPrint(
        'PROFILE SAVE STATUS: '
            '${response.statusCode}',
      );

      debugPrint(
        'PROFILE SAVE BODY: '
            '${response.body}',
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        _showSnackBar(
          'Профиль сохранён в облаке',
          accent: _green,
        );
      } else {
        _showSnackBar(
          'Сохранено локально • сервер ${response.statusCode}',
          accent: _accent,
        );
      }
    } catch (e) {
      debugPrint(
        'PROFILE SYNC ERROR: $e',
      );

      if (mounted) {
        _showSnackBar(
          'Сохранено локально • нет сети',
          accent: _accent,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  void _showSnackBar(
      String message, {
        Color accent = _accent,
      }) {
    if (!mounted) {
      return;
    }

    final background = _isDarkMode
        ? const Color(0xFF12242C)
        : Colors.white;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: background,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                      accent.withOpacity(0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.white
                        : const Color(0xFF18252D),
                    fontSize: 12.5,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDarkMode
        ? const Color(0xFF071016)
        : const Color(0xFFF5F8FB);

    final surfaceColor = _isDarkMode
        ? const Color(0xFF0D1B22)
        : Colors.white;

    final surfaceColor2 = _isDarkMode
        ? const Color(0xFF12242C)
        : const Color(0xFFF0F4F7);

    final textColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF17242C);

    final subTextColor = _isDarkMode
        ? const Color(0xFF91A4AE)
        : const Color(0xFF6C7B84);

    final borderColor = _isDarkMode
        ? Colors.white.withOpacity(0.07)
        : const Color(0xFFDCE4E9);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(
        textColor: textColor,
        borderColor: borderColor,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics:
          const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            40,
          ),
          child: Column(
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 28),
              _buildSectionTitle(
                icon: Icons.person_rounded,
                title: 'Основное',
                subtitle:
                'Как тебя будут видеть другие',
                accent: _accent,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 12),
              _buildCard(
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: nameController,
                      label: 'Имя',
                      hint: 'Как тебя зовут?',
                      icon: Icons.person_rounded,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                      surfaceColor2:
                      surfaceColor2,
                    ),
                    _buildDivider(borderColor),
                    _buildCityField(
                      textColor: textColor,
                      subTextColor:
                      subTextColor,
                      borderColor: borderColor,
                      surfaceColor2:
                      surfaceColor2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _buildSectionTitle(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'О тебе',
                subtitle:
                'Добавь немного информации',
                accent: _cyan,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 12),
              _buildCard(
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: bioController,
                      label: 'О себе',
                      hint:
                      'Чем увлекаешься, что ищешь...',
                      icon:
                      Icons.notes_rounded,
                      maxLines: 4,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                      surfaceColor2:
                      surfaceColor2,
                    ),
                    _buildDivider(borderColor),
                    _buildTextField(
                      controller: ageController,
                      label: 'Возраст',
                      hint: 'Твой возраст',
                      icon:
                      Icons.cake_rounded,
                      keyboardType:
                      TextInputType.number,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                      surfaceColor2:
                      surfaceColor2,
                    ),
                    _buildDivider(borderColor),
                    _buildTextField(
                      controller:
                      telegramController,
                      label: 'Telegram',
                      hint: '@username',
                      icon: Icons.telegram,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                      surfaceColor2:
                      surfaceColor2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _buildSectionTitle(
                icon:
                Icons.auto_awesome_rounded,
                title: 'Интерес',
                subtitle:
                'Что тебе нравится обменивать',
                accent: _violet,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 12),
              _buildCategoryCard(
                surfaceColor: surfaceColor,
                surfaceColor2: surfaceColor2,
                borderColor: borderColor,
                textColor: textColor,
              ),
              const SizedBox(height: 30),
              _buildSaveButton(),
              const SizedBox(height: 10),
              Text(
                'Изменения сохраняются локально и в облаке',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required Color textColor,
    required Color borderColor,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 12,
      leading: Padding(
        padding:
        const EdgeInsets.only(left: 12),
        child: Container(
          margin:
          const EdgeInsets.symmetric(
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.045)
                : Colors.black.withOpacity(0.035),
            borderRadius:
            BorderRadius.circular(15),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: IconButton(
            onPressed: () =>
                Navigator.pop(context),
            tooltip: 'Назад',
            icon: Icon(
              Icons.arrow_back_rounded,
              color: textColor,
              size: 20,
            ),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Редактировать профиль',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
          Text(
            'Обнови информацию о себе',
            style: TextStyle(
              color: _isDarkMode
                  ? const Color(0xFF738993)
                  : const Color(0xFF87959D),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding:
          const EdgeInsets.only(right: 12),
          child: Container(
            margin:
            const EdgeInsets.symmetric(
              vertical: 8,
            ),
            decoration: BoxDecoration(
              gradient:
              const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _accent,
                  _accent2,
                ],
              ),
              borderRadius:
              BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color:
                  _accent.withOpacity(0.20),
                  blurRadius: 17,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: TextButton(
              onPressed:
              isSaving ? null : save,
              style: TextButton.styleFrom(
                foregroundColor:
                Colors.white,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(15),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                width: 19,
                height: 19,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : const Row(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Сохранить',
                    style:
                    TextStyle(
                      color:
                      Colors.white,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    final hasAvatar =
        _avatarUrl.isNotEmpty;

    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Hero(
            tag: 'profile_avatar',
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration:
                  BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                    const LinearGradient(
                      begin:
                      Alignment.topLeft,
                      end:
                      Alignment.bottomRight,
                      colors: [
                        _accent2,
                        _accent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent
                            .withOpacity(0.20),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 130,
                  height: 130,
                  decoration:
                  BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white
                          .withOpacity(0.95),
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor:
                    _isDarkMode
                        ? const Color(
                      0xFF182A32,
                    )
                        : const Color(
                      0xFFFFF0E7,
                    ),
                    backgroundImage:
                    hasAvatar
                        ? NetworkImage(
                      _avatarUrl,
                    )
                        : null,
                    child: hasAvatar
                        ? null
                        : const Icon(
                      Icons
                          .camera_alt_rounded,
                      color: _accent,
                      size: 47,
                    ),
                  ),
                ),
                if (_isUploadingAvatar)
                  Container(
                    width: 130,
                    height: 130,
                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,
                      color: Colors.black
                          .withOpacity(0.55),
                    ),
                    child:
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                Positioned(
                  right: 8,
                  bottom: 7,
                  child: Container(
                    width: 37,
                    height: 37,
                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,
                      gradient:
                      const LinearGradient(
                        colors: [
                          _accent,
                          _accent2,
                        ],
                      ),
                      border: Border.all(
                        color: _isDarkMode
                            ? const Color(
                          0xFF071016,
                        )
                            : Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent
                              .withOpacity(
                            0.28,
                          ),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 13),
        GestureDetector(
          onTap: _pickAvatar,
          child: Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: _accent.withOpacity(
                _isDarkMode ? 0.09 : 0.07,
              ),
              borderRadius:
              BorderRadius.circular(17),
              border: Border.all(
                color:
                _accent.withOpacity(0.19),
              ),
            ),
            child: Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_camera_rounded,
                  color: _accent,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Text(
                  _isUploadingAvatar
                      ? 'Загрузка...'
                      : 'Изменить фото',
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Нажми на фото, чтобы выбрать новое',
          style: TextStyle(
            color: _isDarkMode
                ? const Color(0xFF738993)
                : const Color(0xFF87959D),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withOpacity(
              _isDarkMode ? 0.10 : 0.08,
            ),
            borderRadius:
            BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: accent,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 10.5,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required Color surfaceColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius:
        BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              _isDarkMode ? 0.11 : 0.035,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController
    controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
    required Color surfaceColor2,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final inputType = keyboardType ??
        TextInputType.text;

    return TextField(
      controller: controller,
      keyboardType: inputType,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      textInputAction:
      maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: _accent,
      decoration:
      _inputDecoration(
        label: label,
        hint: hint,
        icon: icon,
        textColor: textColor,
        subTextColor: subTextColor,
        borderColor: borderColor,
        surfaceColor2: surfaceColor2,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
    required Color surfaceColor2,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior:
      FloatingLabelBehavior.auto,
      labelStyle: TextStyle(
        color: subTextColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle:
      const TextStyle(
        color: _accent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(
        color:
        subTextColor.withOpacity(0.45),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Padding(
        padding:
        const EdgeInsets.fromLTRB(
          10,
          10,
          7,
          10,
        ),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _accent.withOpacity(
              _isDarkMode ? 0.08 : 0.06,
            ),
            borderRadius:
            BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: _accent,
            size: 19,
          ),
        ),
      ),
      filled: true,
      fillColor: surfaceColor2,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(17),
        borderSide: BorderSide(
          color: borderColor,
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(17),
        borderSide: BorderSide(
          color: borderColor,
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(17),
        borderSide:
        const BorderSide(
          color: _accent,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _buildCityField({
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
    required Color surfaceColor2,
  }) {
    final currentCity =
    cityController.text.trim();

    final selectedValue =
    locations.contains(currentCity)
        ? currentCity
        : null;

    return DropdownButtonFormField<String>(
      value: selectedValue,
      dropdownColor:
      _isDarkMode
          ? const Color(0xFF12242C)
          : Colors.white,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _accent,
      ),
      decoration:
      _inputDecoration(
        label: 'Город',
        hint: 'Выбери город',
        icon: Icons.location_on_rounded,
        textColor: textColor,
        subTextColor: subTextColor,
        borderColor: borderColor,
        surfaceColor2: surfaceColor2,
      ),
      items: locations
          .map(
            (location) =>
            DropdownMenuItem<String>(
              value: location,
              child: Text(
                location,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
      )
          .toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          cityController.text = value;
        });
      },
    );
  }

  Widget _buildDivider(
      Color borderColor,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 13,
        horizontal: 4,
      ),
      child: Container(
        height: 1,
        color: borderColor,
      ),
    );
  }

  Widget _buildCategoryCard({
    required Color surfaceColor,
    required Color surfaceColor2,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius:
        BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              _isDarkMode ? 0.10 : 0.03,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: _violet.withOpacity(
                _isDarkMode ? 0.07 : 0.06,
              ),
              borderRadius:
              BorderRadius.circular(16),
              border: Border.all(
                color:
                _violet.withOpacity(0.12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _violet
                        .withOpacity(0.11),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: _violet,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        'Сейчас выбрано',
                        style: TextStyle(
                          color:
                          _isDarkMode
                              ? const Color(
                            0xFF8498A2,
                          )
                              : const Color(
                            0xFF71808A,
                          ),
                          fontSize: 9.5,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        selectedCategory,
                        style:
                        TextStyle(
                          color:
                          textColor,
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children:
            categories.map(
                  (category) {
                return _buildCategoryChip(
                  category: category,
                  selected:
                  selectedCategory ==
                      category,
                  surfaceColor2:
                  surfaceColor2,
                  textColor:
                  textColor,
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String category,
    required bool selected,
    required Color surfaceColor2,
    required Color textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(17),
        onTap: () {
          setState(() {
            selectedCategory =
                category;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 220,
          ),
          curve: Curves.easeOut,
          padding:
          const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
              begin:
              Alignment.topLeft,
              end:
              Alignment.bottomRight,
              colors: [
                _accent,
                _accent2,
              ],
            )
                : null,
            color: selected
                ? null
                : surfaceColor2,
            borderRadius:
            BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? _accent
                  : _isDarkMode
                  ? Colors.white
                  .withOpacity(0.055)
                  : const Color(
                0xFFDCE4E9,
              ),
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: _accent
                    .withOpacity(0.18),
                blurRadius: 12,
                offset:
                const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                category,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : textColor,
                  fontSize: 11.5,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient:
          const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              _accent,
              _accent2,
            ],
          ),
          borderRadius:
          BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: _accent
                  .withOpacity(0.22),
              blurRadius: 24,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed:
          isSaving ? null : save,
          style:
          ElevatedButton.styleFrom(
            backgroundColor:
            Colors.transparent,
            foregroundColor:
            Colors.white,
            shadowColor:
            Colors.transparent,
            disabledBackgroundColor:
            Colors.transparent,
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(19),
            ),
          ),
          child: isSaving
              ? const SizedBox(
            width: 22,
            height: 22,
            child:
            CircularProgressIndicator(
              strokeWidth: 2.3,
              color: Colors.white,
            ),
          )
              : const Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 21,
              ),
              SizedBox(width: 9),
              Text(
                'Сохранить изменения',
                style:
                TextStyle(
                  color:
                  Colors.white,
                  fontSize: 14,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}