import 'package:flutter/material.dart';
import 'design_system.dart';
import 'services/api_service.dart';

class FairRatingDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String storeName;
  final String storeId;
  final String? driverId;

  const FairRatingDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.storeName,
    required this.storeId,
    this.driverId,
  });

  @override
  State<FairRatingDialog> createState() => _FairRatingDialogState();
}

class _FairRatingDialogState extends State<FairRatingDialog> {
  double _foodRating = 5.0;
  double _driverRating = 5.0;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await ApiService.submitOrderReview(
      orderId: widget.orderId,
      storeId: widget.storeId,
      driverId: widget.driverId,
      foodScore: _foodRating,
      deliveryScore: _driverRating,
      comment: _commentCtrl.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ شكراً لتقييمك الصادق والمنصف! أُضيفت 20 نقطة ولاء لمحفظتك 🎁'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildStarRow({
    required double rating,
    required ValueChanged<double> onRatingChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        final isFilled = starValue <= rating;
        return IconButton(
          icon: Icon(
            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: const Color(0xFFFFB800),
            size: 32,
          ),
          onPressed: () => onRatingChanged(starValue),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.waselPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rate_review_outlined, color: AppColors.waselPrimary, size: 28),
              ),
              const SizedBox(height: 12),
              const Text(
                'التقييم المنصف للطلب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.lightTextPrimary),
              ),
              Text(
                'طلب ${widget.orderNumber} - ${widget.storeName}',
                style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 16),

              // 1. Food Rating
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.restaurant, size: 18, color: AppColors.waselPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'طعام ومطبخ (${widget.storeName})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.lightTextPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'جودة الطعام، الطهي، والتغليف الساخن',
                      style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                    ),
                    _buildStarRow(
                      rating: _foodRating,
                      onRatingChanged: (val) => setState(() => _foodRating = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Captain Rating
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.two_wheeler, size: 18, color: Color(0xFF0284C7)),
                        SizedBox(width: 6),
                        Text(
                          'كابتن التوصيل',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.lightTextPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'سرعة التوصيل، اللباقة، وحسن المعاملة',
                      style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                    ),
                    _buildStarRow(
                      rating: _driverRating,
                      onRatingChanged: (val) => setState(() => _driverRating = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Comment Field
              TextField(
                controller: _commentCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'اكتب كلمة حق أو ملاحظة لتطوير الخدمة (اختياري)...',
                  hintStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('لاحقاً', style: TextStyle(color: AppColors.lightTextSecondary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.waselPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'إرسال التقييم بأمانة ✔️',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
