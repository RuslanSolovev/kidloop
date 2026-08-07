// features/dashboard/parallax_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/items_provider.dart';
import '../../core/bundle_provider.dart';
import '../../core/trades_provider.dart';
import '../profile/profile_screen.dart';
import '../life_navigator/ui/left_panel_life.dart';
import '../life_navigator/ui/right_panel_life.dart';
import '../life_navigator/providers/life_provider.dart';

// ==================== МИКСИНЫ ====================

mixin HapticFeedbackMixin {
  void lightHaptic() => HapticFeedback.lightImpact();
  void mediumHaptic() => HapticFeedback.mediumImpact();
  void heavyHaptic() => HapticFeedback.heavyImpact();
  void selectionHaptic() => HapticFeedback.selectionClick();
}

// ==================== ЛЕВАЯ ПАНЕЛЬ С ПАРОЛЕМ ====================

class LeftPanel extends StatefulWidget {
  const LeftPanel({super.key});

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  bool _isUnlocked = false;
  String _enteredPassword = '';
  final int _maxPasswordLength = 4;
  bool _showError = false;
  String _errorMessage = '';
  bool _isFirstTimeSetup = false;
  String? _storedPassword;

  @override
  void initState() {
    super.initState();
    _loadPassword();
  }

  Future<void> _loadPassword() async {
    final prefs = await SharedPreferences.getInstance();
    _storedPassword = prefs.getString('life_navigator_password');
    if (_storedPassword == null || _storedPassword!.isEmpty) {
      setState(() {
        _isFirstTimeSetup = true;
      });
    }
  }

  Future<void> _savePassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('life_navigator_password', password);
    setState(() {
      _storedPassword = password;
      _isFirstTimeSetup = false;
    });
  }

  void _onDigitPressed(String digit) {
    setState(() {
      if (_enteredPassword.length < _maxPasswordLength) {
        _enteredPassword += digit;
        _showError = false;
        if (_enteredPassword.length == _maxPasswordLength) {
          _checkPassword();
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (_enteredPassword.isNotEmpty) {
        _enteredPassword = _enteredPassword.substring(0, _enteredPassword.length - 1);
        _showError = false;
      }
    });
  }

  void _onClearPressed() {
    setState(() {
      _enteredPassword = '';
      _showError = false;
    });
  }

  void _checkPassword() {
    if (_isFirstTimeSetup) {
      if (_enteredPassword.length == _maxPasswordLength) {
        _savePassword(_enteredPassword);
        setState(() {
          _isUnlocked = true;
          _enteredPassword = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚇 Пароль установлен!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    if (_enteredPassword == _storedPassword) {
      setState(() {
        _isUnlocked = true;
        _enteredPassword = '';
        _showError = false;
      });
      HapticFeedback.lightImpact();
    } else {
      setState(() {
        _showError = true;
        _errorMessage = '❌ Неверный пароль';
        _enteredPassword = '';
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _lockNavigator() {
    setState(() {
      _isUnlocked = false;
      _enteredPassword = '';
      _showError = false;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isUnlocked) {
      return _buildLockScreen(isDark);
    }

    return ChangeNotifierProvider(
      create: (_) => LifeProvider(),
      child: LeftPanelLife(onLockTap: _lockNavigator),
    );
  }

  Widget _buildLockScreen(bool isDark) {
    final isSetup = _isFirstTimeSetup;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F1115), const Color(0xFF1A1D24)]
              : [const Color(0xFFF5F7FA), const Color(0xFFFFFFFF)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                    border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                  ),
                  child: Icon(
                    isSetup ? Icons.lock_outline_rounded : Icons.lock_rounded,
                    size: 40,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  isSetup ? '🚇 Установите PIN-код' : '🚇 Введите PIN-код',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D24)),
                ),
                const SizedBox(height: 6),
                Text(
                  isSetup ? 'Придумайте 4 цифры для доступа' : 'Введите код для доступа к метро жизни',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_maxPasswordLength, (index) {
                    final isFilled = index < _enteredPassword.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? (isDark ? Colors.white : const Color(0xFF1A1D24)) : Colors.transparent,
                        border: Border.all(
                          color: isFilled ? (isDark ? Colors.white : const Color(0xFF1A1D24)) : (isDark ? Colors.white24 : Colors.grey.shade300),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showError ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(_errorMessage, style: TextStyle(color: Colors.red.shade400, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 24),

                _buildKeyboard(isDark),

                const SizedBox(height: 20),

                SizedBox(
                  height: 36,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: (!isSetup && _enteredPassword.isNotEmpty) ? 1.0 : 0.0,
                    child: TextButton(
                      onPressed: _onClearPressed,
                      child: Text('Сбросить', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== КЛАВИАТУРА ====================

  Widget _buildKeyboard(bool isDark) {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3'], isDark),
        const SizedBox(height: 10),
        _buildKeyRow(['4', '5', '6'], isDark),
        const SizedBox(height: 10),
        _buildKeyRow(['7', '8', '9'], isDark),
        const SizedBox(height: 10),
        _buildKeyRow(['del', '0', ''], isDark),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key == 'del') {
          return _buildActionKey(Icons.backspace_rounded, _onDeletePressed, isDark);
        } else if (key.isEmpty) {
          return const SizedBox(width: 64, height: 56);
        } else {
          return _buildDigitKey(key, isDark);
        }
      }).toList(),
    );
  }

  Widget _buildDigitKey(String digit, bool isDark) {
    return GestureDetector(
      onTap: () => _onDigitPressed(digit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 60, height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
        ),
        child: Center(
          child: Text(digit, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1D24))),
        ),
      ),
    );
  }

  Widget _buildActionKey(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: Icon(icon, size: 22, color: isDark ? Colors.white54 : Colors.grey.shade600)),
      ),
    );
  }
}

// ==================== ПРАВАЯ ПАНЕЛЬ ====================

class RightPanel extends StatelessWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const RightPanelLife();
  }
}