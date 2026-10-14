import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// ============================================================================
/// DEDICATED ORDER RATING & CELEBRATION SCREEN (شاشة تقييم الطلب المستقلة)
/// ============================================================================
/// Full-screen celebration of completed delivery with separate, detailed
/// rating sections for the Restaurant/Kitchen and the Captain/Driver.
/// Awards +20 Wasel Loyalty Points upon honest submission.
/// ============================================================================
class OrderRatingScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String storeName;
  final String storeId;
  final String? driverId;
  final String? driverName;

  const OrderRatingScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.storeName,
    required this.storeId,
    this.driverId,
    this.driverName,
  });

  @override
  State<OrderRatingScreen> createState() => _OrderRatingScreenState();
}

class _OrderRatingScreenState extends State<OrderRatingScreen> {
  double _foodRating = 5.0;
  double _driverRating = 5.0;
  final Set<String> _selectedFoodTags = {};
  final Set<String> _selectedDriverTags = {};
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _foodTags = [
    'طعام ساخن وطازج ♨️',
    'تغليف محكم ونظيف 📦',
    'لحم بلدي وطني فاخر 🥩',
    'زيت زيتون نالوت الأصلي 🫒',
    'كمية مشبعة ووافية 🍽️',
    'طعم أصيل ومميز ⭐',
  ];

  final List<String> _driverTags = [
    'سرعة استثنائية في الوصول ⚡',
    'لباقة وحسن معاملة 🤝',
    'التزام دقيق بالموقع 📍',
    'سيارة نظيفة ومجهزة 🚗',
    'تواصل مسبق ومحترف 📞',
    'تسليم الأمانة بحرص 🛡️',
  ];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _getRatingFeedback(double rating) {
    if (rating >= 5.0) return 'ممتاز ونخب أول 🌟';
    if (rating >= 4.0) return 'جيد جداً ومرضي للغاية 👍';
    if (rating >= 3.0) return 'جيد ومقبول 👌';
    if (rating >= 2.0) return 'أقل من المتوقع ⚠️';
    return 'غير مرضي ويحتاج معالجة ❌';
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    // Combine tags and custom note into detailed comment
    final List<String> feedbackParts = [];
    if (_selectedFoodTags.isNotEmpty) {
      feedbackParts.add('ملاحظات الطعام: ${_selectedFoodTags.join('، ')}');
    }
    if (_selectedDriverTags.isNotEmpty) {
      feedbackParts.add('ملاحظات الكابتن: ${_selectedDriverTags.join('، ')}');
    }
    if (_commentCtrl.text.trim().isNotEmpty) {
      feedbackParts.add('كلمة حق: ${_commentCtrl.text.trim()}');
    }
    final combinedComment = feedbackParts.join(' | ');

    try {
      await ApiService.submitOrderReview(
        orderId: widget.orderId,
        storeId: widget.storeId,
        driverId: widget.driverId,
        foodScore: _foodRating,
        deliveryScore: _driverRating,
        comment: combinedComment,
      );

      // Award 20 loyalty points for honest review
      await ApiService.addLoyaltyPoints(20);
    } catch (_) {}

    if (mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: WaselColors.success,
          duration: const Duration(seconds: 4),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✨ شكراً لتقييمك المنصف! أُضيفت 20 نقطة ولاء لمحفظتك 🎁',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );

      // Return to home or pop
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'تقييم الطلب #${widget.orderNumber}',
            style: WaselTypography.cairo(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          children: [
            // 1. CELEBRATION HERO BANNER
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: WaselRadius.radiusXl,
                border: Border.all(
                  color: isDark ? colorScheme.outlineVariant : const Color(0xFFFDE68A),
                ),
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: WaselColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      boxShadow: WaselShadows.glowAmber,
                    ),
                    child: const Center(
                      child: Text('🍽️', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'صحتين وعافية على قلبك!',
                    style: WaselTypography.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تم تسليم وجبتك بنجاح. رأيك الصادق أمانة يُسهم في ترقية مطاعم وكباتن نالوت، ويكافئك بـ 20 نقطة ولاء 🎁',
                    textAlign: TextAlign.center,
                    style: WaselTypography.cairo(
                      fontSize: 12.5,
                      color: isDark ? colorScheme.onSurfaceVariant : const Color(0xFFB45309),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: WaselRadius.radiusFull,
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_rounded, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          widget.storeName,
                          style: WaselTypography.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. RESTAURANT / KITCHEN RATING CARD
            _buildRatingCard(
              title: 'تقييم مطعم ومطبخ (${widget.storeName})',
              subtitle: 'جودة الطهي، النكهة، والتغليف الساخن',
              icon: Icons.restaurant_rounded,
              accentColor: WaselColors.primary,
              rating: _foodRating,
              onRatingChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _foodRating = val);
              },
              tags: _foodTags,
              selectedTags: _selectedFoodTags,
              onTagToggled: (tag) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (_selectedFoodTags.contains(tag)) {
                    _selectedFoodTags.remove(tag);
                  } else {
                    _selectedFoodTags.add(tag);
                  }
                });
              },
            ),

            const SizedBox(height: 20),

            // 3. CAPTAIN / DELIVERY RATING CARD
            _buildRatingCard(
              title: 'تقييم كابتن التوصيل (${widget.driverName ?? "كابتن واصل"})',
              subtitle: 'السرعة، اللباقة، وحسن المعاملة والأمانة',
              icon: Icons.two_wheeler_rounded,
              accentColor: const Color(0xFF0284C7),
              rating: _driverRating,
              onRatingChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _driverRating = val);
              },
              tags: _driverTags,
              selectedTags: _selectedDriverTags,
              onTagToggled: (tag) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (_selectedDriverTags.contains(tag)) {
                    _selectedDriverTags.remove(tag);
                  } else {
                    _selectedDriverTags.add(tag);
                  }
                });
              },
            ),

            const SizedBox(height: 20),

            // 4. HONEST COMMENT & FEEDBACK CARD
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: WaselRadius.radiusXl,
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: colorScheme.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'كلمة حق وملاحظات إضافية (اختياري)',
                        style: WaselTypography.cairo(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ملاحظاتك تصل لإدارة واصل وإدارة المتجر مباشرة لتحسين الجودة الدائمة.',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'اكتب انطباعك أو أي اقتراح يطور خدمات التوصيل في نالوت...',
                      hintStyle: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: WaselRadius.radiusMd,
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: WaselRadius.radiusMd,
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // BOTTOM ACTION BAR
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'تخطي لاحقاً',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 50,
                      child: WaselBouncyButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        backgroundColor: WaselColors.primary,
                        borderRadius: WaselRadius.radiusLg,
                        child: _isSubmitting
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'إرسال التقييم (+20 نقطة 🎁)',
                                    style: WaselTypography.cairo(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required double rating,
    required ValueChanged<double> onRatingChanged,
    required List<String> tags,
    required Set<String> selectedTags,
    required ValueChanged<String> onTagToggled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: WaselRadius.radiusXl,
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: WaselTypography.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive 5 Stars Row
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1.0;
                final isFilled = starValue <= rating;
                return WaselBouncyPressable(
                  onTap: () => onRatingChanged(starValue),
                  pressedScale: 0.85,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFFFB800),
                      size: 38,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _getRatingFeedback(rating),
              style: WaselTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD97706),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Quick Tag Pills
          Text(
            'اختر ما ينطبق على تجربتك:',
            style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              final isSelected = selectedTags.contains(tag);
              return WaselBouncyPressable(
                onTap: () => onTagToggled(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: WaselRadius.radiusFull,
                    border: Border.all(
                      color: isSelected ? accentColor : colorScheme.outlineVariant,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? accentColor : colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
