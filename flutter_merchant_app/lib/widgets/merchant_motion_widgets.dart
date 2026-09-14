import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../merchant_theme.dart';

/// ============================================================================
/// WASEL MERCHANT & KITCHEN - MOTION & MICRO-INTERACTION WIDGETS
/// ============================================================================
/// 60/120 FPS high-performance motion widgets for kitchen display systems.
/// ============================================================================

/// 1. WaselBouncyPressable (Merchant KDS Edition)
class WaselBouncyPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final bool enableHaptic;

  const WaselBouncyPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = AppMotion.pressScaleButton,
    this.pressDuration = AppMotion.fast,
    this.releaseDuration = const Duration(milliseconds: 250),
    this.enableHaptic = true,
  });

  @override
  State<WaselBouncyPressable> createState() => _WaselBouncyPressableState();
}

class _WaselBouncyPressableState extends State<WaselBouncyPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppMotion.easeOutCubic,
        reverseCurve: AppMotion.springSnappy,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _isPressed = true;
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// 2. WaselPulseGlow (Merchant Alert Pulse for Incoming Kitchen Orders)
class WaselPulseGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double minBlur;
  final double maxBlur;
  final double minSpread;
  final double maxSpread;
  final Duration duration;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final bool isPulsing;

  const WaselPulseGlow({
    super.key,
    required this.child,
    this.glowColor = MerchantColors.newOrderAmber,
    this.minBlur = 6.0,
    this.maxBlur = 20.0,
    this.minSpread = 1.0,
    this.maxSpread = 5.0,
    this.duration = AppMotion.relaxed,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.isPulsing = true,
  });

  @override
  State<WaselPulseGlow> createState() => _WaselPulseGlowState();
}

class _WaselPulseGlowState extends State<WaselPulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.pulseCurve,
    );

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WaselPulseGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPulsing) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final progress = _glowAnimation.value;
        final currentBlur = widget.minBlur + (widget.maxBlur - widget.minBlur) * progress;
        final currentSpread = widget.minSpread + (widget.maxSpread - widget.minSpread) * progress;
        final currentAlpha = 0.20 + (0.35 * progress);

        return RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.circle ? null : (widget.borderRadius ?? MerchantRadius.md),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: currentAlpha),
                  blurRadius: currentBlur,
                  spreadRadius: currentSpread,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 3. WaselNumberOdometer (Merchant Daily Sales Counter)
class WaselNumberOdometer extends StatelessWidget {
  final double value;
  final int decimalPlaces;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  const WaselNumberOdometer({
    super.key,
    required this.value,
    this.decimalPlaces = 2,
    this.prefix = '',
    this.suffix = ' د.ل',
    this.style,
    this.duration = AppMotion.slow,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: AppMotion.easeOutCubic,
      builder: (context, animatedValue, child) {
        final formattedNumber = animatedValue.toStringAsFixed(decimalPlaces);
        return Text(
          '$prefix$formattedNumber$suffix',
          style: style,
        );
      },
    );
  }
}
