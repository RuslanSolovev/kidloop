import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'users_tab.dart';
import 'chats_tab.dart';
import 'forums_tab.dart';

class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key});

  @override
  State<MessengerScreen> createState() =>
      _MessengerScreenState();
}

class _MessengerScreenState
    extends State<MessengerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _currentIndex = 0;

  Color _accentColor =
  const Color(0xFFFF7548);

  static const String _accentKey =
      'messenger_accent_color';

  static const List<_AccentOption>
  _accentOptions = [
    _AccentOption(
      name: 'Оранжевый',
      color: Color(0xFFFF7548),
    ),
    _AccentOption(
      name: 'Фиолетовый',
      color: Color(0xFF8B5CF6),
    ),
    _AccentOption(
      name: 'Синий',
      color: Color(0xFF4B8DFF),
    ),
    _AccentOption(
      name: 'Бирюзовый',
      color: Color(0xFF16B8A6),
    ),
    _AccentOption(
      name: 'Розовый',
      color: Color(0xFFF45B97),
    ),
    _AccentOption(
      name: 'Красный',
      color: Color(0xFFFF5B61),
    ),
    _AccentOption(
      name: 'Лайм',
      color: Color(0xFF84CC16),
    ),
    _AccentOption(
      name: 'Изумрудный',
      color: Color(0xFF10B981),
    ),
    _AccentOption(
      name: 'Голубой',
      color: Color(0xFF06B6D4),
    ),
    _AccentOption(
      name: 'Индиго',
      color: Color(0xFF6366F1),
    ),
    _AccentOption(
      name: 'Малиновый',
      color: Color(0xFFE11D72),
    ),
    _AccentOption(
      name: 'Золотой',
      color: Color(0xFFF59E0B),
    ),
    _AccentOption(
      name: 'Жёлтый',
      color: Color(0xFFFACC15),
    ),
    _AccentOption(
      name: 'Мятный',
      color: Color(0xFF2DD4BF),
    ),
    _AccentOption(
      name: 'Бирюзовый тёмный',
      color: Color(0xFF0F766E),
    ),
    _AccentOption(
      name: 'Синий тёмный',
      color: Color(0xFF1D4ED8),
    ),
    _AccentOption(
      name: 'Фиолетовый тёмный',
      color: Color(0xFF6D28D9),
    ),
    _AccentOption(
      name: 'Графит',
      color: Color(0xFF4B5563),
    ),
    _AccentOption(
      name: 'Белый',
      color: Color(0xFFF8FAFC),
      isLight: true,
    ),
    _AccentOption(
      name: 'Чёрный',
      color: Color(0xFF111827),
    ),
  ];

  bool get _isDarkMode =>
      Theme.of(context).brightness ==
          Brightness.dark;

  Color get _backgroundColor =>
      _isDarkMode
          ? const Color(0xFF070A10)
          : const Color(0xFFF5F6F8);

  Color get _barColor =>
      _isDarkMode
          ? const Color(0xED0B1017)
          : const Color(0xF7F8F9FB);

  Color get _textColor =>
      _isDarkMode
          ? Colors.white
          : const Color(0xFF171B21);

  Color get _secondaryColor =>
      _isDarkMode
          ? const Color(0xFF7E8896)
          : const Color(0xFF858D98);

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: 0,
    );

    _tabController.addListener(
      _handleTabChanged,
    );

    _loadAccentColor();
  }

  Future<void> _loadAccentColor() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      final value =
      prefs.getInt(_accentKey);

      if (value == null || !mounted) {
        return;
      }

      setState(() {
        _accentColor = Color(value);
      });
    } catch (e) {
      debugPrint(
        'Accent load error: $e',
      );
    }
  }

  Future<void> _saveAccentColor(
      Color color,
      ) async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      await prefs.setInt(
        _accentKey,
        color.value,
      );
    } catch (e) {
      debugPrint(
        'Accent save error: $e',
      );
    }
  }

  void _handleTabChanged() {
    final newIndex =
        _tabController.index;

    if (_currentIndex == newIndex) {
      return;
    }

    setState(() {
      _currentIndex = newIndex;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(
      _handleTabChanged,
    );

    _tabController.dispose();

    super.dispose();
  }

  void _showColorPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
      Colors.transparent,
      barrierColor:
      Colors.black.withOpacity(
        _isDarkMode ? 0.60 : 0.24,
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _ColorPickerSheet(
          currentColor:
          _accentColor,
          options:
          _accentOptions,
          isDarkMode:
          _isDarkMode,
          onSelected: (color) {
            Navigator.of(
              sheetContext,
            ).pop();

            _changeAccentColor(
              color,
            );
          },
        );
      },
    );
  }

  void _changeAccentColor(
      Color color,
      ) {
    if (color.value ==
        _accentColor.value) {
      return;
    }

    setState(() {
      _accentColor = color;
    });

    _saveAccentColor(color);
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 240,
      ),
      curve:
      Curves.easeOutCubic,
      color:
      _backgroundColor,
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: TabBarView(
              controller:
              _tabController,
              physics:
              const BouncingScrollPhysics(),
              children: [
                ChatsTab(
                  accentColor:
                  _accentColor,
                ),
                ForumsTab(
                  accentColor:
                  _accentColor,
                ),
                UsersTab(
                  accentColor:
                  _accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 240,
      ),
      curve:
      Curves.easeOutCubic,
      decoration:
      BoxDecoration(
        color: _barColor,
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              _isDarkMode
                  ? 0.15
                  : 0.018,
            ),
            blurRadius: 18,
            offset:
            const Offset(0, 7),
            spreadRadius: -8,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
          const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            9,
          ),
          child: Row(
            children: [
              Expanded(
                child:
                _buildNavigation(),
              ),
              const SizedBox(
                width: 8,
              ),
              _buildMoreButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 220,
      ),
      curve:
      Curves.easeOutCubic,
      height: 56,
      decoration:
      BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(
          0.035,
        )
            : Colors.black.withOpacity(
          0.022,
        ),
        borderRadius:
        BorderRadius.circular(
          19,
        ),
      ),
      child: TabBar(
        controller:
        _tabController,
        padding:
        const EdgeInsets.all(4),
        labelPadding:
        EdgeInsets.zero,
        indicatorPadding:
        EdgeInsets.zero,
        indicatorSize:
        TabBarIndicatorSize.tab,
        dividerColor:
        Colors.transparent,
        indicator:
        _buildIndicator(),
        labelColor:
        Colors.white,
        unselectedLabelColor:
        _secondaryColor,
        overlayColor:
        WidgetStateProperty.all(
          Colors.transparent,
        ),
        splashFactory:
        NoSplash.splashFactory,
        tabs: const [
          _MessengerTab(
            icon: Icons
                .chat_bubble_outline_rounded,
            label: 'Чаты',
            tabIndex: 0,
          ),
          _MessengerTab(
            icon:
            Icons.forum_outlined,
            label: 'Форум',
            tabIndex: 1,
          ),
          _MessengerTab(
            icon:
            Icons.people_outline_rounded,
            label: 'Люди',
            tabIndex: 2,
          ),
        ],
      ),
    );
  }

  Decoration _buildIndicator() {
    return BoxDecoration(
      gradient:
      LinearGradient(
        begin:
        Alignment.topLeft,
        end:
        Alignment.bottomRight,
        colors: [
          Color.lerp(
            _accentColor,
            Colors.white,
            0.08,
          ) ??
              _accentColor,
          Color.lerp(
            _accentColor,
            Colors.black,
            0.06,
          ) ??
              _accentColor,
        ],
      ),
      borderRadius:
      BorderRadius.circular(
        15,
      ),
      boxShadow: [
        BoxShadow(
          color:
          _accentColor.withOpacity(
            0.20,
          ),
          blurRadius: 15,
          offset:
          const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildMoreButton() {
    return Material(
      color:
      Colors.transparent,
      child: InkWell(
        onTap:
        _showColorPicker,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        splashColor:
        _accentColor.withOpacity(
          0.08,
        ),
        highlightColor:
        Colors.transparent,
        child:
        AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 220,
          ),
          width: 48,
          height: 56,
          decoration:
          BoxDecoration(
            color: _isDarkMode
                ? Colors.white.withOpacity(
              0.035,
            )
                : Colors.black.withOpacity(
              0.022,
            ),
            borderRadius:
            BorderRadius.circular(
              18,
            ),
          ),
          child: Center(
            child: Icon(
              Icons
                  .more_horiz_rounded,
              color:
              _secondaryColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessengerTab
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final int tabIndex;

  const _MessengerTab({
    required this.icon,
    required this.label,
    required this.tabIndex,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final controller =
    DefaultTabController.maybeOf(
      context,
    );

    return AnimatedBuilder(
      animation:
      controller ??
          kAlwaysCompleteAnimation,
      builder: (
          context,
          child,
          ) {
        final index =
            controller?.index ??
                0;

        final selected =
            index == tabIndex;

        return Center(
          child:
          AnimatedContainer(
            duration:
            const Duration(
              milliseconds: 180,
            ),
            curve:
            Curves.easeOutCubic,
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment
                  .center,
              mainAxisSize:
              MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale:
                  selected
                      ? 1.0
                      : 0.94,
                  duration:
                  const Duration(
                    milliseconds: 180,
                  ),
                  child: Icon(
                    icon,
                    size: selected
                        ? 21
                        : 20,
                  ),
                ),
                AnimatedSize(
                  duration:
                  const Duration(
                    milliseconds:
                    180,
                  ),
                  curve:
                  Curves.easeOutCubic,
                  child: selected
                      ? Row(
                    children: [
                      const SizedBox(
                        width: 7,
                      ),
                      Text(
                        label,
                        style:
                        const TextStyle(
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w700,
                          letterSpacing:
                          -0.1,
                        ),
                      ),
                    ],
                  )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccentOption {
  final String name;
  final Color color;
  final bool isLight;

  const _AccentOption({
    required this.name,
    required this.color,
    this.isLight = false,
  });
}

class _ColorPickerSheet
    extends StatelessWidget {
  final Color currentColor;
  final List<_AccentOption>
  options;
  final bool isDarkMode;
  final ValueChanged<Color>
  onSelected;

  const _ColorPickerSheet({
    required this.currentColor,
    required this.options,
    required this.isDarkMode,
    required this.onSelected,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final background =
    isDarkMode
        ? const Color(
      0xFF10151D,
    )
        : Colors.white;

    final secondary =
    isDarkMode
        ? const Color(
      0xFF8892A0,
    )
        : const Color(
      0xFF7F8792,
    );

    final handleColor =
    secondary.withOpacity(
      0.30,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [
        0.62,
        0.92,
      ],
      builder:
          (
          sheetContext,
          scrollController,
          ) {
        return Container(
          decoration:
          BoxDecoration(
            color: background,
            borderRadius:
            const BorderRadius
                .vertical(
              top: Radius.circular(
                30,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(
                  isDarkMode
                      ? 0.35
                      : 0.12,
                ),
                blurRadius: 35,
                offset:
                const Offset(
                  0,
                  -8,
                ),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(
                height: 10,
              ),
              Container(
                width: 40,
                height: 4,
                decoration:
                BoxDecoration(
                  color:
                  handleColor,
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  20,
                  17,
                  20,
                  8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            'Цвет интерфейса',
                            style:
                            TextStyle(
                              color:
                              isDarkMode
                                  ? Colors.white
                                  : const Color(
                                0xFF171B21,
                              ),
                              fontSize: 21,
                              fontWeight:
                              FontWeight.w800,
                              letterSpacing:
                              -0.4,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            'Один цвет для чатов, форума и людей',
                            style:
                            TextStyle(
                              color:
                              secondary,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildCurrentColorPreview(),
                  ],
                ),
              ),
              Expanded(
                child:
                GridView.builder(
                  controller:
                  scrollController,
                  padding:
                  const EdgeInsets
                      .fromLTRB(
                    18,
                    10,
                    18,
                    24,
                  ),
                  itemCount:
                  options.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.98,
                  ),
                  itemBuilder:
                      (context, index) {
                    final option =
                    options[index];

                    final selected =
                        option.color.value ==
                            currentColor.value;

                    return _ColorOptionTile(
                      option:
                      option,
                      selected:
                      selected,
                      isDarkMode:
                      isDarkMode,
                      onTap: () =>
                          onSelected(
                            option.color,
                          ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentColorPreview() {
    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 180,
      ),
      width: 42,
      height: 42,
      decoration:
      BoxDecoration(
        color: currentColor,
        shape:
        BoxShape.circle,
        border: Border.all(
          color:
          isDarkMode
              ? Colors.white
              .withOpacity(
            0.12,
          )
              : Colors.black
              .withOpacity(
            0.08,
          ),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
            currentColor.withOpacity(
              0.25,
            ),
            blurRadius: 12,
          ),
        ],
      ),
      child: Icon(
        Icons
            .palette_rounded,
        color:
        _iconColorForAccent(
          currentColor,
        ),
        size: 19,
      ),
    );
  }

  Color _iconColorForAccent(
      Color color,
      ) {
    final brightness =
    ThemeData.estimateBrightnessForColor(
      color,
    );

    return brightness ==
        Brightness.dark
        ? Colors.white
        : const Color(0xFF20242A);
  }
}

class _ColorOptionTile
    extends StatelessWidget {
  final _AccentOption option;
  final bool selected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _ColorOptionTile({
    required this.option,
    required this.selected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final textColor =
    isDarkMode
        ? Colors.white
        : const Color(
      0xFF20242A,
    );

    final tileBackground =
    option.color.withOpacity(
      isDarkMode
          ? 0.095
          : 0.065,
    );

    return Material(
      color:
      Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        splashColor:
        option.color.withOpacity(
          0.10,
        ),
        highlightColor:
        option.color.withOpacity(
          0.045,
        ),
        child: AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 180,
          ),
          curve:
          Curves.easeOutCubic,
          decoration:
          BoxDecoration(
            color:
            tileBackground,
            borderRadius:
            BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color:
              selected
                  ? option.color
                  .withOpacity(
                0.65,
              )
                  : (isDarkMode
                  ? Colors.white
                  .withOpacity(
                0.045,
              )
                  : Colors.black
                  .withOpacity(
                0.035,
              )),
              width:
              selected ? 1.2 : 0.7,
            ),
            boxShadow:
            selected
                ? [
              BoxShadow(
                color: option
                    .color
                    .withOpacity(
                  0.16,
                ),
                blurRadius: 14,
                offset:
                const Offset(
                  0,
                  5,
                ),
              ),
            ]
                : null,
          ),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment
                .center,
            children: [
              AnimatedContainer(
                duration:
                const Duration(
                  milliseconds: 180,
                ),
                width:
                selected ? 46 : 42,
                height:
                selected ? 46 : 42,
                decoration:
                BoxDecoration(
                  color:
                  option.color,
                  shape:
                  BoxShape.circle,
                  border:
                  option.isLight
                      ? Border.all(
                    color: isDarkMode
                        ? Colors
                        .white
                        .withOpacity(
                      0.18,
                    )
                        : Colors
                        .black
                        .withOpacity(
                      0.10,
                    ),
                    width: 1,
                  )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: option
                          .color
                          .withOpacity(
                        selected
                            ? 0.30
                            : 0.14,
                      ),
                      blurRadius:
                      selected
                          ? 15
                          : 8,
                    ),
                  ],
                ),
                child:
                AnimatedSwitcher(
                  duration:
                  const Duration(
                    milliseconds:
                    150,
                  ),
                  child:
                  selected
                      ? Icon(
                    Icons
                        .check_rounded,
                    key:
                    const ValueKey(
                      'selected',
                    ),
                    color:
                    _checkColor(
                      option,
                    ),
                    size:
                    23,
                  )
                      : const SizedBox(
                    key:
                    ValueKey(
                      'empty',
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Padding(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 5,
                ),
                child: Text(
                  option.name,
                  maxLines: 1,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11.2,
                    fontWeight:
                    selected
                        ? FontWeight
                        .w700
                        : FontWeight
                        .w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _checkColor(
      _AccentOption option,
      ) {
    final brightness =
    ThemeData.estimateBrightnessForColor(
      option.color,
    );

    return brightness ==
        Brightness.dark
        ? Colors.white
        : const Color(
      0xFF20242A,
    );
  }
}