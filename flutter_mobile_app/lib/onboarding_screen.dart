import 'package:flutter/material.dart';
import 'design_system.dart';
import 'login_screen.dart';
import 'main.dart';
import 'services/api_service.dart';

/// Onboarding screen with 3 welcome slides introducing Wasel Super-App in Nalut.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: Icons.restaurant_menu_rounded,
      iconColor: AppColors.waselPrimary,
      title: 'واصل وجبات 🍔',
      subtitle: 'أشهى وجبات مطاعم نالوت ومشويات الجبل\nتوصلك ساخنة وسريعة مع تتبع مباشر',
      gradientColors: [
        const Color(0xFFFF6B6B),
        AppColors.waselPrimary,
      ],
    ),
    _OnboardingSlide(
      icon: Icons.bolt_rounded,
      iconColor: AppColors.jetPrimary,
      title: 'واصل فوري ⚡ 15 دقيقة',
      subtitle: 'بقالة وتموينات نالوت اليومية\nخضروات، لحوم، ومياه توصلك في ربع ساعة',
      gradientColors: [
        const Color(0xFF34D399),
        AppColors.jetPrimary,
      ],
    ),
    _OnboardingSlide(
      icon: Icons.shopping_bag_rounded,
      iconColor: AppColors.waselPurple,
      title: 'سوق واصل ومنتجات الجبل 🛍️',
      subtitle: 'تسوق الإلكترونيات، الأزياء،\nوزيت زيتون نالوت الجبلي الأصلي وعسل السدر',
      gradientColors: [
        const Color(0xFFA78BFA),
        AppColors.waselPurple,
      ],
    ),
  ];

  Future<void> _enterMainApp() async {
    await ApiService.setGuestMode(true);
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigationShell(
            onToggleTheme: () {},
            isDark: false,
          ),
        ),
      );
    }
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Action Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  WaselBouncyPressable(
                    onTap: _enterMainApp,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'دخول مباشر (تخطي)',
                        style: WaselTypography.cairo(
                          color: isDark
                              ? WaselColors.textSecondaryDark
                              : WaselColors.textSecondaryLight,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  WaselBouncyPressable(
                    onTap: _goToLogin,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'تسجيل الدخول',
                        style: WaselTypography.cairo(
                          color: colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page content with multi-plane parallax
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double pageOffset = 0.0;
                      if (_pageController.position.haveDimensions) {
                        pageOffset = (_pageController.page ?? _currentPage.toDouble()) - index;
                      }
                      final bool disableAnim = WaselMotion.isAnimationDisabled(context);
                      final iconOffset = disableAnim ? Offset.zero : Offset(pageOffset * -40.0, 0.0);
                      final textOffset = disableAnim ? Offset.zero : Offset(pageOffset * -18.0, 0.0);
                      final opacity = disableAnim ? 1.0 : (1.0 - (pageOffset.abs() * 0.5)).clamp(0.0, 1.0);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon circle with parallax offset
                            Transform.translate(
                              offset: iconOffset,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: slide.gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: slide.iconColor.withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  slide.icon,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 48),

                            // Title & Subtitle with secondary parallax offset
                            Transform.translate(
                              offset: textOffset,
                              child: Opacity(
                                opacity: opacity,
                                child: Column(
                                  children: [
                                    Text(
                                      slide.title,
                                      textAlign: TextAlign.center,
                                      style: WaselTypography.cairo(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? WaselColors.textPrimaryDark
                                            : WaselColors.textPrimaryLight,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      slide.subtitle,
                                      textAlign: TextAlign.center,
                                      style: WaselTypography.cairo(
                                        fontSize: 16,
                                        color: isDark
                                            ? WaselColors.textSecondaryDark
                                            : WaselColors.textSecondaryLight,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Dots indicator + bouncy action button
            Padding(
              padding: const EdgeInsets.only(bottom: 32, left: 28, right: 28),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: WaselMotion.standard,
                        curve: WaselMotion.signature,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? colorScheme.primary
                              : (isDark ? WaselColors.borderDark : WaselColors.borderLight),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Primary Bouncy Button (ابدأ تجربة واصل)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: WaselBouncyButton(
                      backgroundColor: colorScheme.primary,
                      borderRadius: WaselRadius.radiusLg,
                      onPressed: () {
                        if (_currentPage == _slides.length - 1) {
                          _enterMainApp();
                        } else {
                          _pageController.nextPage(
                            duration: WaselMotion.standard,
                            curve: WaselMotion.signature,
                          );
                        }
                      },
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'ابدأ تجربة واصل 🚀'
                            : 'التالي',
                        style: WaselTypography.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
  }
}

class _OnboardingSlide {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;

  _OnboardingSlide({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
  });
}
