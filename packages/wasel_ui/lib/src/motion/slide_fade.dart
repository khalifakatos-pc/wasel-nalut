import 'package:flutter/material.dart';
import 'wasel_motion.dart';

/// ============================================================================
/// WASEL SLIDE FADE (انتقال الظهور التدريجي المتدرج)
/// ============================================================================
/// Fluid staggered entry transition with customizable delay and offset.
/// Automatically renders immediately if [WaselMotion.isAnimationDisabled] is true.
/// ============================================================================
class WaselSlideFade extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  const WaselSlideFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = WaselMotion.standard,
    this.offset = const Offset(0.0, 0.12),
    this.curve = WaselMotion.easeOutCubic,
  });

  @override
  State<WaselSlideFade> createState() => _WaselSlideFadeState();
}

class _WaselSlideFadeState extends State<WaselSlideFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (WaselMotion.isAnimationDisabled(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: child,
          ),
        );
      },
      child: RepaintBoundary(child: widget.child),
    );
  }
}
