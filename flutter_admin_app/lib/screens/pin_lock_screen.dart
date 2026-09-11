import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import 'admin_main_screen.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  final String _correctPin = '7788';
  final String _backupPin = '9832';
  bool _isError = false;

  void _onKeyPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _isError = false;
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _isError = false;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _verifyPin() {
    if (_enteredPin == _correctPin || _enteredPin == _backupPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminMainScreen()),
      );
    } else {
      setState(() {
        _isError = true;
        _enteredPin = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ رمز PIN غير صحيح! الرمز الافتراضي للمدير: 7788', textAlign: TextAlign.center),
          backgroundColor: AdminColors.alertRed,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Crown icon and logo
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AdminColors.primaryGold, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AdminColors.primaryGold.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 44)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'غرفة عمليات واصل نالوت',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يرجى إدخال رمز الأمان للمدير (رمز المشرف: 7788)',
                  style: TextStyle(fontSize: 14, color: AdminColors.textSecondary),
                ),
                const SizedBox(height: 36),

                // PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? (_isError ? AdminColors.alertRed : AdminColors.primaryGold)
                            : Colors.transparent,
                        border: Border.all(
                          color: _isError ? AdminColors.alertRed : AdminColors.primaryGold,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                const Spacer(),

                // Number Pad
                Column(
                  children: [
                    _buildPadRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildPadRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildPadRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 75, height: 75), // Spacer
                        _buildPadButton('0'),
                        SizedBox(
                          width: 75,
                          height: 75,
                          child: IconButton(
                            icon: const Icon(Icons.backspace_outlined, color: AdminColors.textSecondary, size: 28),
                            onPressed: _onDelete,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Security Notice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AdminColors.divider),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, color: AdminColors.emeraldGreen, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'سحابة Supabase نشطة ومحمية 24/7',
                        style: TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildPadButton(d)).toList(),
    );
  }

  Widget _buildPadButton(String digit) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: AdminColors.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: AdminColors.divider),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AdminColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
