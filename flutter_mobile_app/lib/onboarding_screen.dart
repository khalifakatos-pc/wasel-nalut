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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Action Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _enterMainApp,
                      child: const Text(
                        'دخول مباشر (تخطي)',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: _goToLogin,
                      child: const Text(
                        'تسجيل الدخول',
                        style: TextStyle(color: AppColors.waselPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon circle with gradient
                          Container(
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
                          const SizedBox(height: 48),

                          // Title
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Subtitle
                          Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white60,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Dots indicator + action button
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
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? AppColors.waselPrimary
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Primary Button (ابدأ تجربة واصل)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage == _slides.length - 1) {
                            _enterMainApp();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.waselPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusLg,
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          _currentPage == _slides.length - 1
                              ? 'ابدأ تجربة واصل 🚀'
                              : 'التالي',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
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
