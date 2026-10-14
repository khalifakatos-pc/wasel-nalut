import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wasel_ui/wasel_ui.dart';

/// ============================================================================
/// NO NETWORK MOUNTAIN CONNECTIVITY STATE (شاشة انقطاع التغطية الجبلية)
/// ============================================================================
/// Respectful, authentic Libyan empty state explaining mountain terrain signal drops
/// (Madar / Libyana cellular towers in Nafusa Mountains).
/// Features auto-retry countdown ring, manual retry action, and emergency direct voice dial.
/// ============================================================================
class NoNetworkScreen extends StatefulWidget {
  final Future<void> Function()? onRetry;
  final bool isFullScreen;

  const NoNetworkScreen({
    super.key,
    this.onRetry,
    this.isFullScreen = true,
  });

  @override
  State<NoNetworkScreen> createState() => _NoNetworkScreenState();
}

class _NoNetworkScreenState extends State<NoNetworkScreen> {
  static const int _retryIntervalSeconds = 12;
  int _secondsRemaining = _retryIntervalSeconds;
  Timer? _countdownTimer;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _startAutoRetryTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startAutoRetryTimer() {
    _secondsRemaining = _retryIntervalSeconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        _triggerRetry(isAuto: true);
      }
    });
  }

  Future<void> _triggerRetry({bool isAuto = false}) async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
    });

    if (!isAuto) {
      HapticFeedback.mediumImpact();
    }

    try {
      if (widget.onRetry != null) {
        await widget.onRetry!();
      } else {
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isRetrying = false;
      });
      _startAutoRetryTimer();
    }
  }

  Future<void> _callDirectSupport() async {
    final uri = Uri.parse('tel:0918207786');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Mountain & Antenna Visual Icon
            Stack(
              alignment: Alignment.center,
              children: [
                WaselPulseGlow(
                  glowColor: WaselColors.primary.withValues(alpha: 0.3),
                  minSpread: 4,
                  maxSpread: 18,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cell_tower_rounded,
                      size: 44,
                      color: WaselColors.primary,
                    ),
                    const SizedBox(height: 2),
                    Text('⛰️', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2. Clear & Respectful Mountain Headline
            Text(
              'يبدو أن التغطية ضعيفة في الجبل ⛰️📶',
              textAlign: TextAlign.center,
              style: WaselTypography.cairo(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 10),

            // 3. Explanation of Local Libyan Carriers (Madar / Libyana)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                'نواجه صعوبة في الوصول لأبراج المدار أو ليبيانا في منطقتك حالياً. لا تقلق، يقوم واصل بالبحث المستمر وإعادة المحاولة تلقائياً كل بضع ثوانٍ.',
                textAlign: TextAlign.center,
                style: WaselTypography.cairo(
                  fontSize: 12.5,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 4. Auto-Retry Countdown Ring
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: WaselRadius.radiusXl,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountdownRing(
                    progress: _secondsRemaining / _retryIntervalSeconds,
                    remainingSeconds: _secondsRemaining,
                    totalSeconds: _retryIntervalSeconds,
                    size: 38,
                    strokeWidth: 3.5,
                    color: WaselColors.primary,
                    showText: true,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعادة المحاولة التلقائية',
                        style: WaselTypography.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'جاري فحص الاتصال بالأبراج...',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 5. Manual Action Buttons
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                children: [
                  // Retry Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: WaselBouncyButton(
                      onPressed: _isRetrying ? null : () => _triggerRetry(isAuto: false),
                      backgroundColor: WaselColors.primary,
                      borderRadius: WaselRadius.radiusLg,
                      child: _isRetrying
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'إعادة المحاولة الآن 🔄',
                                  style: WaselTypography.cairo(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Direct Cellular Voice Call (Works without 4G mobile data!)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _callDirectSupport,
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                      label: Text(
                        'اتصال هاتفي مباشر بطوارئ نالوت (0918207786)',
                        style: WaselTypography.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(color: colorScheme.outlineVariant),
                        shape: RoundedRectangleBorder(borderRadius: WaselRadius.radiusLg),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isFullScreen) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(child: content),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: content,
    );
  }
}
