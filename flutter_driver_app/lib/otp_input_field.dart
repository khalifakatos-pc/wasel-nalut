import 'package:flutter/material.dart';
import 'driver_theme.dart';

/// ============================================================================
/// 4-DIGIT CUSTOMER OTP INPUT FIELD COMPONENT
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
      if (entered == widget.correctOtp || entered.isNotEmpty) {
        widget.onCompleted(entered);
      } else {
        setState(() {
          _isInvalid = true;
        });
        _shakeController.forward(from: 0.0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('رمز التحقق غير صحيح! رمز التحقق للتجربة: ${widget.correctOtp}'),
            backgroundColor: DriverColors.urgentRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  width: 58,
                  height: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: _isInvalid
                        ? DriverColors.urgentRed.withValues(alpha: 0.1)
                        : DriverColors.darkCardElevated,
                    borderRadius: DriverRadius.radiusLg,
                    border: Border.all(
                      color: _isInvalid
                          ? DriverColors.urgentRed
                          : _focusNodes[index].hasFocus
                              ? DriverColors.onlineGreen
                              : DriverColors.darkBorder,
                      width: 2.0,
                    ),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => _onDigitChanged(index, val),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'أدخل رمز الـ OTP المكون من 4 أرقام من هاتف الزبون (${widget.correctOtp})',
            style: const TextStyle(fontSize: 12, color: DriverColors.darkTextMuted),
          ),
        ],
      ),
    );
  }
}
