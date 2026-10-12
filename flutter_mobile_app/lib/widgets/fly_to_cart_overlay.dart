import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wasel_ui/wasel_ui.dart';

/// Signature animated fly-to-cart particle/arc feedback on dish addition.
/// Respects accessibility motion disable guards.
class FlyToCartOverlay {
  static void run({
    required BuildContext context,
    required Offset startOffset,
    required GlobalKey targetKey,
    IconData icon = Icons.lunch_dining_rounded,
    VoidCallback? onComplete,
  }) {
    if (WaselMotion.isAnimationDisabled(context)) {
      HapticFeedback.selectionClick();
      onComplete?.call();
      return;
    }

    final overlayState = Overlay.of(context);
    final targetBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) {
      onComplete?.call();
      return;
    }

    final targetOffset = targetBox.localToGlobal(
      Offset(targetBox.size.width / 2, targetBox.size.height / 2),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyParticle(
        start: startOffset,
        target: targetOffset,
        icon: icon,
        onFinished: () {
          entry.remove();
          HapticFeedback.lightImpact();
          onComplete?.call();
        },
      ),
    );

    overlayState.insert(entry);
  }
}

class _FlyParticle extends StatefulWidget {
  final Offset start;
  final Offset target;
  final IconData icon;
  final VoidCallback onFinished;

  const _FlyParticle({
    required this.start,
    required this.target,
    required this.icon,
    required this.onFinished,
  });

  @override
  State<_FlyParticle> createState() => _FlyParticleState();
}

class _FlyParticleState extends State<_FlyParticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: WaselMotion.slow, // 450ms
    )..forward().then((_) {
        if (mounted) widget.onFinished();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Parabolic arc interpolation:
        // x moves linearly; y arcs upward by arcHeight before descending
        final x = lerpDouble(widget.start.dx, widget.target.dx, t)!;
        const arcHeight = 70.0;
        final y = lerpDouble(widget.start.dy, widget.target.dy, t)! -
            (4 * arcHeight * t * (1 - t));

        // Scale pop: starts at 0.6, expands to 1.15 at t=0.25, shrinks to 0.4 at landing
        double scale;
        if (t < 0.25) {
          scale = lerpDouble(0.6, 1.15, t / 0.25)!;
        } else {
          scale = lerpDouble(1.15, 0.4, (t - 0.25) / 0.75)!;
        }

        final opacity =
            t > 0.85 ? lerpDouble(1.0, 0.0, (t - 0.85) / 0.15)! : 1.0;

        return Positioned(
          left: x - 18,
          top: y - 18,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: WaselColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: WaselShadows.glowAmber,
                ),
                child: Center(
                  child: Icon(widget.icon, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
