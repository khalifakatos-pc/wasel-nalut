import 'package:flutter/material.dart';
import 'driver_theme.dart';

/// ============================================================================
/// 4-DIGIT CUSTOMER OTP INPUT FIELD COMPONENT
/// ============================================================================
/// High-contrast segmented 4-box OTP entry with auto-focus progression,
/// shake animation on invalid OTP, and clear feedback.
/// ============================================================================

class OtpInputField extends StatefulWidget {
  final String correctOtp;
  final ValueChanged<String> onCompleted;
  final VoidCallback? onResend;

  const OtpInputField({
    super.key,
    required this.correctOtp,
    required this.onCompleted,
    this.onResend,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isInvalid = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    setState(() {
      _isInvalid = false;
    });

    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOtp();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _verifyOtp() {
    final entered = _controllers.map((c) => c.text).join();
    if (entered.length == 4) {
      if (entered == widget.correctOtp) {
        widget.onCompleted(entered);
      } else {
        setState(() {
          _isInvalid = true;
        });
        _shakeController.forward(from: 0.0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid OTP Code! Please ask customer for correct 4-digit PIN (Demo PIN: ${widget.correctOtp})'),
            backgroundColor: DriverColors.urgentRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _quickFillDemo() {
    for (int i = 0; i < 4; i++) {
      if (i < widget.correctOtp.length) {
        _controllers[i].text = widget.correctOtp[i];
      }
    }
    _verifyOtp();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 4 Segmented Digit Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 58,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: isDark ? DriverColors.darkCard : Colors.white,
                      borderRadius: DriverRadius.radiusLg,
                      border: Border.all(
                        color: _isInvalid
                            ? DriverColors.urgentRed
                            : (_controllers[index].text.isNotEmpty
                                ? DriverColors.onlineGreen
                                : (isDark ? DriverColors.darkBorder : DriverColors.lightBorder)),
                        width: _isInvalid || _controllers[index].text.isNotEmpty ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isInvalid ? DriverColors.urgentRed : DriverColors.onlineGreen)
                              .withValues(alpha: _controllers[index].text.isNotEmpty ? 0.2 : 0.0),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: DriverTypography.displayMedium.copyWith(
                          color: _isInvalid
                              ? DriverColors.urgentRed
                              : (isDark ? Colors.white : DriverColors.lightTextPrimary),
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onChanged: (val) => _onDigitChanged(index, val),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),

              // Demo Auto-Fill & Resend Options
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _quickFillDemo,
                    icon: const Icon(Icons.flash_on_rounded, size: 16, color: DriverColors.primary),
                    label: Text(
                      'Auto-Fill Demo (${widget.correctOtp})',
                      style: DriverTypography.labelSmall.copyWith(color: DriverColors.primary),
                    ),
                  ),
                  if (widget.onResend != null) ...[
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: widget.onResend,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        'Resend SMS',
                        style: DriverTypography.labelSmall.copyWith(
                          color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
