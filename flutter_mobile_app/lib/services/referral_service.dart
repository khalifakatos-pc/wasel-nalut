import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/referral_model.dart';
import 'api_service.dart';

/// ============================================================================
/// WASEL REFERRAL & VIRAL SHARING SERVICE
/// ============================================================================

class ReferralService {
  // Existing registered phone numbers in Nalut (Simulating checking user base)
  static final Set<String> _existingUserPhones = {
    '0912345678',
    '0928765432',
    '0941122334',
    '0915554433',
    '0919570011',
    '0917778899',
    '+218912345678',
    '+218928765432',
  };

  /// Get current dynamic rules from Admin Cloud Configurations
  static Future<Map<String, dynamic>> getCampaignRules() async {
    final cfg = await ApiService.fetchSystemConfigurations();
    return {
      'enabled': cfg['referral_enabled'] ?? true,
      'target_count': cfg['referral_target_count'] ?? 3,
      'reward_type': cfg['referral_reward_type'] ?? 'free_delivery',
      'reward_lyd': cfg['referral_reward_lyd'] ?? 5.0,
      'validity_days': cfg['referral_validity_days'] ?? 14,
      'condition': cfg['referral_condition'] ?? 'on_signup_otp',
    };
  }

  /// Get personal referral code
  static Future<String> getReferralCode() async {
    return await ApiService.getUserReferralCode();
  }

  /// Generate WhatsApp / Share text
  static Future<String> getShareMessage() async {
    final code = await getReferralCode();
    return '🚀 اطلب أشهى وجبات ومشتريات نالوت من مطعم رانشيلو وريكسوس وأكاكوس عبر تطبيق واصل!\n'
        'استخدم كود الإحالة الخاص بي: ($code)\n'
        'لتحصل على خصم على أول طلب عبر الرابط:\n'
        'https://wasel.ly/app?ref=$code';
  }

  /// Fetch user's invited friends list
  static Future<List<ReferralFriend>> getInvitedFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('wasel_invited_friends');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((item) => ReferralFriend.fromJson(Map<String, dynamic>.from(item))).toList();
      } catch (_) {}
    }

    // Default sample friends to illustrate both scenarios (Already registered vs New)
    final initialFriends = [
      ReferralFriend(
        id: 'ref_1',
        name: 'أحمد سالم الورفلي',
        phone: '091-***1190',
        status: ReferralFriendStatus.verifiedNew,
        date: DateTime.now().subtract(const Duration(days: 2)),
      ),
      ReferralFriend(
        id: 'ref_2',
        name: 'طارق العكرمي',
        phone: '091-***5678',
        status: ReferralFriendStatus.alreadyRegistered, // مسجل مسبقاً
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    await _saveInvitedFriends(initialFriends);
    return initialFriends;
  }

  static Future<void> _saveInvitedFriends(List<ReferralFriend> friends) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(friends.map((f) => f.toJson()).toList());
    await prefs.setString('wasel_invited_friends', raw);
  }

  /// Check a phone number: Is it already registered in Wasel or a brand-new user?
  static Future<Map<String, dynamic>> evaluateAndAddReferral({
    required String friendName,
    required String friendPhone,
  }) async {
    final cleanPhone = friendPhone.replaceAll(RegExp(r'\s+|-'), '');
    final friends = await getInvitedFriends();
    final rules = await getCampaignRules();
    final int targetCount = rules['target_count'] ?? 3;

    // 1. Check if already registered
    final isAlreadyRegistered = _existingUserPhones.contains(cleanPhone);

    if (isAlreadyRegistered) {
      final friend = ReferralFriend(
        id: 'ref_${DateTime.now().millisecondsSinceEpoch}',
        name: friendName,
        phone: cleanPhone,
        status: ReferralFriendStatus.alreadyRegistered,
        date: DateTime.now(),
      );
      friends.insert(0, friend);
      await _saveInvitedFriends(friends);

      return {
        'success': false,
        'is_already_registered': true,
        'message': '⚠️ الصديق ($friendName) مسجل مسبقاً في تطبيق واصل!\nلذلك لم يُحتسب كإحالة جديدة وفقاً لسياسة المنصة.',
        'new_progress': _countVerified(friends) % targetCount,
        'target_count': targetCount,
      };
    }

    // 2. Brand new user!
    final friend = ReferralFriend(
      id: 'ref_${DateTime.now().millisecondsSinceEpoch}',
      name: friendName,
      phone: cleanPhone,
      status: ReferralFriendStatus.verifiedNew,
      date: DateTime.now(),
    );
    friends.insert(0, friend);
    await _saveInvitedFriends(friends);

    final verifiedCount = _countVerified(friends);
    bool voucherIssued = false;

    // Check if user hit the target count!
    if (verifiedCount >= targetCount && (verifiedCount % targetCount == 0)) {
      final validityDays = rules['validity_days'] ?? 14;
      final newVoucher = FreeDeliveryVoucher(
        id: 'vouch_${DateTime.now().millisecondsSinceEpoch}',
        code: 'FREE-REF-${DateTime.now().millisecondsSinceEpoch % 10000}',
        title: 'توصيل مجاني 🛵 (هدية دعوة $targetCount أصدقاء)',
        expiresAt: DateTime.now().add(Duration(days: validityDays)),
        discountLyd: 5.00,
      );
      await addVoucher(newVoucher);
      voucherIssued = true;
    }

    return {
      'success': true,
      'is_already_registered': false,
      'message': '🎉 رائع! تم تأكيد تسجيل الصديق ($friendName) كمستخدم جديد في واصل بنجاح!',
      'voucher_issued': voucherIssued,
      'new_progress': verifiedCount % targetCount,
      'target_count': targetCount,
    };
  }

  static int _countVerified(List<ReferralFriend> friends) {
    return friends.where((f) => f.status == ReferralFriendStatus.verifiedNew || f.status == ReferralFriendStatus.completedFirstOrder).length;
  }

  /// Get active free delivery vouchers
  static Future<List<FreeDeliveryVoucher>> getActiveVouchers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('wasel_user_vouchers');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list
            .map((item) => FreeDeliveryVoucher.fromJson(Map<String, dynamic>.from(item)))
            .where((v) => v.isValid)
            .toList();
      } catch (_) {}
    }

    // Default sample free delivery voucher for immediate testing
    final initialVoucher = FreeDeliveryVoucher(
      id: 'vouch_init_1',
      code: 'FREE-WAS-2041',
      title: 'كوبون توصيل مجاني 🛵 (هدية الإحالات)',
      expiresAt: DateTime.now().add(const Duration(days: 12)),
      discountLyd: 5.00,
    );
    try {
      await prefs.setString('wasel_user_vouchers', jsonEncode([initialVoucher.toJson()]));
    } catch (_) {}
    return [initialVoucher];
  }

  /// Add a new earned voucher
  static Future<void> addVoucher(FreeDeliveryVoucher voucher) async {
    final prefs = await SharedPreferences.getInstance();
    List<FreeDeliveryVoucher> vouchers = [];
    final raw = prefs.getString('wasel_user_vouchers');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        vouchers = list
            .map((item) => FreeDeliveryVoucher.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } catch (_) {}
    }
    vouchers.insert(0, voucher);
    final updatedRaw = jsonEncode(vouchers.map((v) => v.toJson()).toList());
    await prefs.setString('wasel_user_vouchers', updatedRaw);
  }

  /// Redeem voucher on checkout
  static Future<bool> redeemVoucher(String voucherId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('wasel_user_vouchers');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        final vouchers = list.map((item) => FreeDeliveryVoucher.fromJson(Map<String, dynamic>.from(item))).toList();
        for (final v in vouchers) {
          if (v.id == voucherId) {
            v.isUsed = true;
          }
        }
        await prefs.setString('wasel_user_vouchers', jsonEncode(vouchers.map((v) => v.toJson()).toList()));
      } catch (_) {}
    }
    return true;
  }
}
