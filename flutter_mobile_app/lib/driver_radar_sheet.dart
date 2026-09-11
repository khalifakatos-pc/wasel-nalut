import 'dart:async';
import 'package:flutter/material.dart';
import 'design_system.dart';

class DriverRadarSheet extends StatefulWidget {
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const DriverRadarSheet({super.key, this.onAccept, this.onDecline});

  @override
  State<DriverRadarSheet> createState() => _DriverRadarSheetState();
}

class _DriverRadarSheetState extends State<DriverRadarSheet> with SingleTickerProviderStateMixin {
  int _secondsLeft = 15;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        widget.onDecline?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.waselPrimary.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.waselPrimary.withValues(alpha: 0.3),
              blurRadius: 25,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. RADAR ICON WITH PULSE
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 80 + (_pulseController.value * 20),
                      height: 80 + (_pulseController.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.waselPrimary.withValues(alpha: 0.2 - (_pulseController.value * 0.15)),
                      ),
                    );
                  },
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.waselPrimary, Color(0xFFC22026)],
                    ),
                  ),
                  child: const Icon(Icons.motorcycle_rounded, color: Colors.white, size: 36),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. BADGE & RESTAURANT
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.waselPrimary.withValues(alpha: 0.15),
                borderRadius: AppRadius.radiusSm,
              ),
              child: const Text(
                'كابتن واصل • طلب فوري جديد ⚡',
                style: TextStyle(color: AppColors.waselPrimary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'مطعم قصر نالوت للمشويات',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'نالوت - قرب القصر الأثري إلى حي الشهداء (1.8 كم)',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // 3. EARNINGS & TIMER ROW
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: AppRadius.radiusLg,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const Column(
                    children: [
                      Text('عائد الكابتن', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      SizedBox(height: 2),
                      Text(
                        '14.50 د.ل',
                        style: TextStyle(color: AppColors.success, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 36, color: const Color(0xFF334155)),
                  Column(
                    children: [
                      const Text('الوقت المتبقي', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        '$_secondsLeft ثانية',
                        style: TextStyle(
                          color: _secondsLeft <= 5 ? AppColors.error : AppColors.warning,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.pop(context);
                      widget.onDecline?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                    ),
                    child: const Text('تخطي'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.pop(context);
                      widget.onAccept?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                      elevation: 4,
                    ),
                    child: const Text('قبول المهمة 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
