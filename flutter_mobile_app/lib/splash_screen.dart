import 'dart:async';
import 'package:flutter/material.dart';
import 'design_system.dart';
import 'services/api_service.dart';

/// Animated splash screen with WASEL (واصل) branding centered on Nalut.
/// Auto-navigates based on authentication state after animation.
class SplashScreen extends StatefulWidget {
  final bool isLoggedIn;
  final Widget nextScreen;
  final Widget? homeScreen;

  const SplashScreen({
    super.key,
    required this.isLoggedIn,
    required this.nextScreen,
    this.homeScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _navigationTimer;
  Timer? _fallbackTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Primary timer: 1400ms (< 1.7s total elapsed)
    _navigationTimer = Timer(const Duration(milliseconds: 1400), _navigateToDestination);

    // Fallback timer: 2500ms safety net ensuring navigation never hangs
    _fallbackTimer = Timer(const Duration(milliseconds: 2500), _navigateToDestination);
  }

  void _navigateToDestination() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _navigationTimer?.cancel();
    _fallbackTimer?.cancel();

    final bool hasSession = widget.isLoggedIn || ApiService.hasActiveSession;
    final destination = (hasSession && widget.homeScreen != null)
        ? widget.homeScreen!
        : widget.nextScreen;

    try {
      final nav = Navigator.maybeOf(context);
      if (nav != null) {
        nav.pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => destination,
            transitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('SplashScreen PageRouteBuilder error: $e');
    }

    // Secondary fallback to standard MaterialPageRoute
    try {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e2) {
      debugPrint('SplashScreen fatal route fallback error: $e2');
    }
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasNavigated && (_navigationTimer == null || !_navigationTimer!.isActive)) {
      _navigationTimer = Timer(const Duration(milliseconds: 400), _navigateToDestination);
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToDestination,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF134E4A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 125,
                  height: 125,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.waselPrimary, AppColors.waselSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadius.radiusXxl,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.waselPrimary.withValues(alpha: 0.45),
                        blurRadius: 35,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'و',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // App Name
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Column(
                  children: [
                    Text(
                      'واصل | WASEL',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'سوبر آب التوصيل والتسوق الأول في نالوت والجبل 🏔️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Loading indicator
              FadeTransition(
                opacity: _fadeAnimation,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.waselPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tap anywhere hint for instantaneous access
              FadeTransition(
                opacity: _fadeAnimation,
                child: TextButton(
                  onPressed: _navigateToDestination,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('انقر هنا للمتابعة 👈'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
