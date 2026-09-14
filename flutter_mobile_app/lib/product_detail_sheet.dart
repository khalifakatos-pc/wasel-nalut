import 'package:flutter/material.dart';
import 'design_system.dart';
import 'widgets/motion_widgets.dart';

/// ============================================================================
/// WASEL SUPER-APP PRODUCT DETAIL & VARIANT MODAL SHEET
/// ============================================================================
/// A dual-mode BottomSheet supporting:
/// 1. FOOD MODE (Presto Eat & Jet): Radio size options, Multi-select add-ons,
///    Kitchen notes, dynamic modifier pricing.
/// 2. E-COMMERCE MODE (Mataa Marketplace): Color swatches, storage/size chips,
///    warranty specs, prime shipping guarantees.
/// ============================================================================

class ProductDetailSheet extends StatefulWidget {
  final String title;
  final double basePrice;
  final String category;
  final bool isFood;
  final Function(Map<String, dynamic> itemDetails)? onAddToCart;

  const ProductDetailSheet({
    super.key,
    required this.title,
    required this.basePrice,
    required this.category,
    this.isFood = true,
    this.onAddToCart,
  });

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  int _quantity = 1;
  final TextEditingController _notesController = TextEditingController();

  // --- FOOD STATE ---
  int _selectedSizeIndex = 0;
  final List<Map<String, dynamic>> _foodSizes = [
    {'name': 'حجم عادي (سنجل)', 'detail': 'وجبة قياسية مع خبز طازج وبطاطا', 'extra': 0.0},
    {'name': 'حجم مزدوج (دبل)', 'detail': 'شريحتان إضافيتان مع صلصة خاصة', 'extra': 5.0},
    {'name': 'حجم عائلي كبير (جامبو)', 'detail': 'وجبة كاملة تكفي شخصين مع مشروب وبطاطا', 'extra': 12.0},
  ];

  // --- SPICE & HARISSA STATE ---
  String _selectedSpiceLevel = 'هريسة عادية موزونة 🌶️🌶️';
  final List<Map<String, String>> _spiceOptions = [
    {'name': 'بدون هريسة ⚪ (بارد)'},
    {'name': 'هريسة خفيفة 🌶️'},
    {'name': 'هريسة عادية موزونة 🌶️🌶️'},
    {'name': 'زيادة هريسة (حارة هلبا) 🔥'},
  ];

  // --- EXCLUSIONS STATE ---
  final Set<String> _selectedExclusions = {};
  final List<String> _exclusionOptions = [
    'بدون كاتشب',
    'بدون مايونيز',
    'بدون بصل',
    'بدون طماطم',
    'بدون مخلل',
  ];

  final Map<String, bool> _selectedAddons = {
    'كثر البطاطا داخل السندوتش 🍟': true,
    'حمّر الخبزة هلبا (مقرمشة) 🥖': false,
    'صلصة ثومية ليبية حارة (+1.50 د.ل)': true,
    'شريحة جبنة شيدر مدخنة (+2.00 د.ل)': false,
    'بطاطا مقلية مقرمشة إضافية (+3.50 د.ل)': false,
    'دحي مقلي (بيضة) (+1.00 د.ل)': false,
  };

  final Map<String, double> _addonPrices = {
    'كثر البطاطا داخل السندوتش 🍟': 0.0,
    'حمّر الخبزة هلبا (مقرمشة) 🥖': 0.0,
    'صلصة ثومية ليبية حارة (+1.50 د.ل)': 1.50,
    'شريحة جبنة شيدر مدخنة (+2.00 د.ل)': 2.00,
    'بطاطا مقلية مقرمشة إضافية (+3.50 د.ل)': 3.50,
    'دحي مقلي (بيضة) (+1.00 د.ل)': 1.00,
  };

  // --- E-COMMERCE STATE ---
  int _selectedColorIndex = 0;
  final List<Map<String, dynamic>> _productColors = [
    {'name': 'Space Black', 'color': const Color(0xFF1E293B)},
    {'name': 'Titanium Blue', 'color': const Color(0xFF2563EB)},
    {'name': 'Natural Titanium', 'color': const Color(0xFF94A3B8)},
    {'name': 'Desert Gold', 'color': const Color(0xFFD97706)},
  ];

  int _selectedVariantIndex = 1; // Default 256GB
  final List<Map<String, dynamic>> _variants = [
    {'name': '128 GB', 'extra': 0.0},
    {'name': '256 GB', 'extra': 100.0},
    {'name': '512 GB', 'extra': 240.0},
    {'name': '1 TB', 'extra': 420.0},
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _calculatedUnitPrice {
    double price = widget.basePrice;

    if (widget.isFood) {
      // Add size extra
      price += (_foodSizes[_selectedSizeIndex]['extra'] as double);
      // Add addons
      _selectedAddons.forEach((key, isSelected) {
        if (isSelected) {
          price += (_addonPrices[key] ?? 0.0);
        }
      });
    } else {
      // Add variant extra
      price += (_variants[_selectedVariantIndex]['extra'] as double);
    }

    return price;
  }

  double get _totalPrice => _calculatedUnitPrice * _quantity;

  Color get _themeColor => widget.isFood ? AppColors.waselPrimary : AppColors.waselPurple;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: AppRadius.topXxl,
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        children: [
          // Drag Handle & Top Header
          _buildSheetHeader(isDark),

          // Scrollable Modifier Options
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 10),
              children: [
                // Product Hero Header (Image representation, tags, title, base price)
                _buildProductHeroCard(isDark),

                const SizedBox(height: 20),

                if (widget.isFood) ...[
                  // Food Size Selection (Required Single Choice)
                  _buildSizeSection(isDark),
                  const SizedBox(height: 20),

                  // 1. Spice & Harissa Level (Single Choice)
                  _buildSpiceLevelSection(isDark),
                  const SizedBox(height: 20),

                  // 2. Exclusions (بدون...) (Multi Choice)
                  _buildExclusionsSection(isDark),
                  const SizedBox(height: 20),

                  // Food Addons Selection (Multi Choice)
                  _buildAddonsSection(isDark),
                  const SizedBox(height: 20),

                  // Kitchen Special Instructions
                  _buildSpecialInstructions(isDark),
                ] else ...[
                  // E-Commerce Color Swatch Selector
                  _buildColorSelector(isDark),
                  const SizedBox(height: 20),

                  // E-Commerce Storage / Size Chips
                  _buildVariantChips(isDark),
                  const SizedBox(height: 20),

                  // E-Commerce Delivery & Warranty Assurance Perks
                  _buildAssurancePerks(isDark),
                ],

                const SizedBox(height: 30),
              ],
            ),
          ),

          // Sticky Bottom Checkout Bar
          _buildStickyCheckoutBar(isDark),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// SHEET HEADER (Drag Handle & Close Button)
  /// ---------------------------------------------------------------------------
  Widget _buildSheetHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _themeColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.radiusFull,
            ),
            child: Text(
              widget.category.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                color: _themeColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
              borderRadius: AppRadius.radiusFull,
            ),
          ),
          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// PRODUCT HERO CARD
  /// ---------------------------------------------------------------------------
  Widget _buildProductHeroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Hero Container
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: widget.isFood
                  ? AppColors.waselGradient
                  : AppColors.waselGradient,
              borderRadius: AppRadius.radiusLg,
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    widget.isFood ? Icons.lunch_dining_rounded : Icons.devices_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: AppRadius.radiusFull,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
                        const SizedBox(width: 3),
                        Text(
                          '4.9 (1.2k)',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Title & Base Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.basePrice.toStringAsFixed(2)} د.ل',
                style: AppTypography.headlineLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: _themeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Description & Badges
          Text(
            widget.isFood
                ? 'تحضير طازج على الطلب بأجود المكونات المحلية، مع الخضروات الطازجة والصلصات الخاصة المحضرة يومياً في نالوت.'
                : 'منتج أصلي ومضمون مع ضمان الوكيل المعتمد، يدعم الشحن السريع إلى كافة مناطق نالوت والجبل الغربي.',
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),

          // Food tags / specs
          Wrap(
            spacing: 8,
            children: widget.isFood
                ? [
                    _buildPillTag('🔥 طازج وصحي', isDark),
                    _buildPillTag('⏱ 15-25 دقيقة تحضير', isDark),
                    _buildPillTag('حلال 100%', isDark),
                  ]
                : [
                    _buildPillTag('⚡ توصيل فوري نالوت', isDark),
                    _buildPillTag('🛡 ضمان استبدال رسمي', isDark),
                    _buildPillTag('🔄 استرجاع مجاني خلال 7 أيام', isDark),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillTag(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: AppRadius.radiusSm,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// FOOD MODE: SIZE SELECTION (Custom Modern Radio Cards)
  /// ---------------------------------------------------------------------------
  Widget _buildSizeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'اختر الحجم',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.waselLight,
                borderRadius: AppRadius.radiusFull,
              ),
              child: Text(
                'إجباري',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.waselPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(_foodSizes.length, (index) {
          final size = _foodSizes[index];
          final isSelected = _selectedSizeIndex == index;
          final extraPrice = size['extra'] as double;

          return InkWell(
            onTap: () => setState(() => _selectedSizeIndex = index),
            borderRadius: AppRadius.radiusLg,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? _themeColor.withValues(alpha: isDark ? 0.15 : 0.06)
                    : (isDark ? AppColors.darkCard : Colors.white),
                borderRadius: AppRadius.radiusLg,
                border: Border.all(
                  color: isSelected ? _themeColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: isSelected ? 1.8 : 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _themeColor : (isDark ? AppColors.darkTextMuted : AppColors.lightBorder),
                        width: 2,
                      ),
                      color: isSelected ? _themeColor : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          size['name'],
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          size['detail'],
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  extraPrice > 0
                      ? Text(
                          '+${extraPrice.toStringAsFixed(2)} د.ل',
                          style: AppTypography.labelMedium.copyWith(
                            color: _themeColor,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : Text(
                          'مجاناً',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// FOOD MODE: SPICE & HARISSA LEVEL (Single Choice)
  /// ---------------------------------------------------------------------------
  Widget _buildSpiceLevelSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'مستوى الهريسة والشطة 🌶️',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'اختيار أساسي',
                style: TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _spiceOptions.map((opt) {
            final isSelected = _selectedSpiceLevel == opt['name'];
            return ChoiceChip(
              selected: isSelected,
              label: Text(
                opt['name']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              selectedColor: Colors.deepOrange,
              backgroundColor: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
              side: BorderSide(
                color: isSelected ? Colors.deepOrange : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedSpiceLevel = opt['name']!);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// FOOD MODE: EXCLUSIONS (بدون...) (Multi Choice)
  /// ---------------------------------------------------------------------------
  Widget _buildExclusionsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.do_not_disturb_on_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'استثناءات سريعة (بدون...) 🚫',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'انقر للاستبعاد ❌',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _exclusionOptions.map((item) {
            final isExcluded = _selectedExclusions.contains(item);
            return FilterChip(
              selected: isExcluded,
              avatar: isExcluded
                  ? const Icon(Icons.close_rounded, size: 16, color: Colors.white)
                  : null,
              label: Text(
                item,
                style: TextStyle(
                  color: isExcluded ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isExcluded ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              selectedColor: AppColors.error,
              backgroundColor: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
              side: BorderSide(
                color: isExcluded ? AppColors.error : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedExclusions.add(item);
                  } else {
                    _selectedExclusions.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// FOOD MODE: ADDONS SELECTION (Multi-Choice)
  /// ---------------------------------------------------------------------------
  Widget _buildAddonsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'إضافات ومقبلات إضافية',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            Text(
              'اختياري',
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._selectedAddons.keys.map((addon) {
          final isChecked = _selectedAddons[addon] ?? false;
          final price = _addonPrices[addon] ?? 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isChecked
                  ? _themeColor.withValues(alpha: isDark ? 0.12 : 0.05)
                  : (isDark ? AppColors.darkCard : Colors.white),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: isChecked ? _themeColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isChecked ? 1.5 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: isChecked,
                activeColor: _themeColor,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                onChanged: (val) {
                  setState(() {
                    _selectedAddons[addon] = val ?? false;
                  });
                },
                title: Text(
                  addon.split(' (').first,
                  style: AppTypography.titleSmall.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                secondary: Text(
                  '+${price.toStringAsFixed(2)} د.ل',
                  style: AppTypography.labelSmall.copyWith(
                    color: _themeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// FOOD MODE: SPECIAL INSTRUCTIONS
  /// ---------------------------------------------------------------------------
  Widget _buildSpecialInstructions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تعليمات خاصة للمطبخ',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 2,
          style: AppTypography.bodyMedium.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'مثال: بدون بصل، ثومية إضافية جانباً، تغليف ساخن...',
            hintStyle: AppTypography.bodySmall.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: AppRadius.radiusLg,
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// E-COMMERCE MODE: COLOR SWATCH SELECTOR
  /// ---------------------------------------------------------------------------
  Widget _buildColorSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'اختر اللون / المظهر',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            Text(
              _productColors[_selectedColorIndex]['name'],
              style: AppTypography.labelMedium.copyWith(
                color: _themeColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_productColors.length, (index) {
            final colorItem = _productColors[index];
            final isSelected = _selectedColorIndex == index;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _selectedColorIndex = index);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _themeColor : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorItem['color'] as Color,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.sm,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// E-COMMERCE MODE: VARIANT STORAGE CHIPS
  /// ---------------------------------------------------------------------------
  Widget _buildVariantChips(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سعة التخزين / المواصفات',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_variants.length, (index) {
            final variant = _variants[index];
            final isSelected = _selectedVariantIndex == index;
            final extraPrice = variant['extra'] as double;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _selectedVariantIndex = index);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _themeColor.withValues(alpha: isDark ? 0.2 : 0.08)
                      : (isDark ? AppColors.darkCard : Colors.white),
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(
                    color: isSelected ? _themeColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      variant['name'],
                      style: AppTypography.labelLarge.copyWith(
                        color: isSelected
                            ? _themeColor
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      extraPrice > 0 ? '+${extraPrice.toStringAsFixed(0)} د.ل' : 'مشمول',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// E-COMMERCE MODE: ASSURANCE & WARRANTY PERKS
  /// ---------------------------------------------------------------------------
  Widget _buildAssurancePerks(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
        borderRadius: AppRadius.radiusLg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                'ضمان أصالة المنتج 100% معتمد',
                style: AppTypography.labelMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'واصل إكسبريس: توصيل فوري موثوق',
                style: AppTypography.labelMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// STICKY BOTTOM CHECKOUT BAR
  /// ---------------------------------------------------------------------------
  Widget _buildStickyCheckoutBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        boxShadow: AppShadows.bottomBarShadow,
      ),
      child: Row(
        children: [
          // Quantity Stepper (- 1 +)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
              borderRadius: AppRadius.radiusFull,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildStepperButton(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    if (_quantity > 1) {
                      setState(() => _quantity--);
                    }
                  },
                  isDark: isDark,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$_quantity',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                _buildStepperButton(
                  icon: Icons.add_rounded,
                  onTap: () {
                    setState(() => _quantity++);
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isFood ? AppColors.waselPrimary : AppColors.waselPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  elevation: 2,
                ),
                onPressed: () {
                  final selectedAddonList = <String>[];
                  if (widget.isFood) {
                    // Include spice level
                    selectedAddonList.add(_selectedSpiceLevel);
                    // Include exclusions
                    for (var ex in _selectedExclusions) {
                      selectedAddonList.add(ex);
                    }
                    // Include selected addons
                    _selectedAddons.forEach((addon, selected) {
                      if (selected) {
                        selectedAddonList.add(addon);
                      }
                    });
                  }

                  final result = {
                    'title': widget.title,
                    'quantity': _quantity,
                    'unitPrice': _calculatedUnitPrice,
                    'totalPrice': _totalPrice,
                    'isFood': widget.isFood,
                    'spiceLevel': widget.isFood ? _selectedSpiceLevel : null,
                    'exclusions': widget.isFood ? _selectedExclusions.toList() : <String>[],
                    'selectedAddons': selectedAddonList,
                    'notes': _notesController.text.trim(),
                  };
                  widget.onAddToCart?.call(result);
                  Navigator.of(context).pop();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'إضافة للسلة • ${_totalPrice.toStringAsFixed(2)} د.ل',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return WaselBouncyPressable(
      behavior: HitTestBehavior.opaque,
      pressedScale: 0.88,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            shape: BoxShape.circle,
            boxShadow: AppShadows.sm,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
