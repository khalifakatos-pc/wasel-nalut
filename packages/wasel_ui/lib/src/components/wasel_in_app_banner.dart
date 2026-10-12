import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/wasel_colors.dart';
import '../theme/wasel_typography.dart';
import '../motion/wasel_motion.dart';
import '../motion/bouncy_pressable.dart';

/// ============================================================================
/// WASEL IN-APP HEADS-UP NOTIFICATION BANNER
/// Smooth top slide-in alert for foreground FCM / local events across all apps.
/// ============================================================================
class WaselInAppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;
  final Duration duration;

  const WaselInAppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.notifications_active_rounded,
    this.accentColor,
    this.onTap,
    required this.onDismiss,
    this.duration = const Duration(seconds: 4),
  });

  /// Displays the heads-up banner via Overlay
  static OverlayEntry? show(
    BuildContext context, {
    required String title,
    required String body,
    IconData icon = Icons.notifications_active_rounded,
    Color? accentColor,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return null;

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (ctx) => WaselInAppNotificationBanner(
        title: title,
        body: body,
        icon: icon,
        accentColor: accentColor,
        onTap: onTap,
        duration: duration,
        onDismiss: () {
          entry?.remove();
          entry = null;
        },
      ),
    );

    overlayState.insert(entry!);
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    return entry;
  }

  @override
  State<WaselInAppNotificationBanner> createState() => _WaselInAppNotificationBannerState();
}

class _WaselInAppNotificationBannerState extends State<WaselInAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: WaselMotion.standard,
      reverseDuration: WaselMotion.quick,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: WaselMotion.joy,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();

    _autoDismissTimer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _autoDismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accentColor ?? colorScheme.primary;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Dismissible(
            key: const Key('wasel_in_app_banner_dismiss'),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: WaselBouncyPressable(
                onTap: () {
                  _autoDismissTimer?.cancel();
                  widget.onDismiss();
                  widget.onTap?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Accent Icon Avatar
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.icon, color: accent, size: 22),
                        ),
                        const SizedBox(width: 12),

                        // Title & Body
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: WaselTypography.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? WaselColors.textPrimaryDark : WaselColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: WaselTypography.cairo(
                                  fontSize: 12,
                                  color: isDark ? WaselColors.textSecondaryDark : WaselColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Close button
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? WaselColors.textSecondaryDark : WaselColors.textSecondaryLight,
                          ),
                          onPressed: _dismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
