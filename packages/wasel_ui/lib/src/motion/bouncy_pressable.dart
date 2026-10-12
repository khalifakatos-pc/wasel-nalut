import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/wasel_spacing.dart';
import 'wasel_motion.dart';

/// ============================================================================
/// WASEL BOUNCY PRESSABLE (تفاعل الضغط الفيزيائي المرتد)
/// ============================================================================
/// Provides tactile physical feedback on tap: scales down to [pressedScale] (default 0.96)
/// on pointer down, and springs back with overshoot elasticity upon release.
/// Includes automatic [WaselMotion.isAnimationDisabled] bypass for accessibility.
/// ============================================================================
class WaselBouncyPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final bool enableHaptic;
  final HitTestBehavior behavior;
  final bool enabled;

  const WaselBouncyPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = WaselMotion.pressScaleButton,
    this.pressDuration = WaselMotion.quick,
    this.releaseDuration = const Duration(milliseconds: 250),
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
    this.enabled = true,
  });

  @override
  State<WaselBouncyPressable> createState() => _WaselBouncyPressableState();
}

class _WaselBouncyPressableState extends State<WaselBouncyPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;
  DateTime? _pressStartTime;

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
        curve: WaselMotion.easeOutCubic,
        reverseCurve: WaselMotion.joy,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.enabled || (widget.onTap == null && widget.onLongPress == null)) {
      return;
    }
    _isPressed = true;
    _pressStartTime = DateTime.now();
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
    if (!WaselMotion.isAnimationDisabled(context)) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isPressed) return;
    _isPressed = false;
    if (WaselMotion.isAnimationDisabled(context)) {
      _controller.reset();
      return;
    }
    final elapsed = DateTime.now()
        .difference(_pressStartTime ?? DateTime.now())
        .inMilliseconds;
    if (elapsed < 80) {
      Future.delayed(Duration(milliseconds: 80 - elapsed), () {
        if (mounted && !_isPressed) {
          _controller.reverse();
        }
      });
    } else {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    _isPressed = false;
    if (!WaselMotion.isAnimationDisabled(context)) {
      _controller.reverse();
    } else {
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || (widget.onTap == null && widget.onLongPress == null)) {
      return widget.child;
    }

    if (WaselMotion.isAnimationDisabled(context)) {
      return GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
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

/// Convenience styled bouncy button wrapper for quick button composition.
class WaselBouncyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? shadows;
  final double pressedScale;
  final bool enabled;

  const WaselBouncyButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.borderRadius,
    this.border,
    this.shadows,
    this.pressedScale = WaselMotion.pressScaleButton,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? WaselRadius.radiusMd;
    final colorScheme = Theme.of(context).colorScheme;

    return WaselBouncyPressable(
      onTap: enabled ? onPressed : null,
      pressedScale: pressedScale,
      enabled: enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? colorScheme.primary,
          borderRadius: effectiveRadius,
          border: border,
          boxShadow: shadows,
        ),
        child: Padding(
          padding: padding,
          child: Center(
            widthFactor: 1.0,
            child: child,
          ),
        ),
      ),
    );
  }
}
