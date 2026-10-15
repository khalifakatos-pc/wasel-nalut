import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/referral_model.dart';
import 'api_service.dart';

/// ============================================================================
/// WASEL REFERRAL & VIRAL SHARING SERVICE (REAL PERSISTENT POSTGRESQL INTEGRATION)
/// ============================================================================

class ReferralService {
  static const String _backendBaseUrl = 'https://wasel-nalut.onrender.com/api/v1';

  /// Get current dynamic rules from Admin Cloud Configurations
  static Future<Map<String, dynamic>> getCampaignRules() async {
    final cfg = await ApiService.fetchSystemConfigurations();
    return {
      'enabled': cfg['referral_enabled'] ?? true,
      'target_count': cfg['referral_target_count'] ?? 3,
      'reward_type': cfg['referral_reward_type'] ?? 'free_delivery',
      'reward_lyd': (cfg['referral_reward_lyd'] as num?)?.toDouble() ?? 5.0,
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
    return '🚀 اطلب أشهى وجبات ومشتريات نالوت عبر تطبيق واصل!\n'
        'استخدم كود الإحالة الخاص بي: ($code)\n'
        'لتحصل على خصم على أول طلب عبر الرابط:\n'
        'https://wasel.ly/app?ref=$code';
  }

  /// Fetch user's invited friends list from persistent database
  static Future<List<ReferralFriend>> getInvitedFriends() async {
    final phone = ApiService.userPhone;
    final prefs = await SharedPreferences.getInstance();

    if (phone.isNotEmpty) {
      try {
        final res = await http.get(
          Uri.parse('$_backendBaseUrl/referrals/$phone'),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(res.body);
          if (body['success'] == true && body['invited_friends'] is List) {
            final List<dynamic> list = body['invited_friends'];
            final friends = list.map((item) {
              final m = Map<String, dynamic>.from(item);
              final isVerified = m['status'] == 'verified' || m['status'] == 'rewarded';
              return ReferralFriend(
                id: m['id'] ?? 'ref_${DateTime.now().millisecondsSinceEpoch}',
                name: m['referred_name'] ?? 'صديق واصل (${m['referred_phone'] ?? ""})',
                phone: m['referred_phone'] ?? '',
                status: isVerified ? ReferralFriendStatus.verifiedNew : ReferralFriendStatus.alreadyRegistered,
                date: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
              );
            }).toList();

            await _saveInvitedFriends(friends);
            return friends;
          }
        }
      } catch (_) {}
    }

    // Fallback to local cache
    final raw = prefs.getString('wasel_invited_friends');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((item) => ReferralFriend.fromJson(Map<String, dynamic>.from(item))).toList();
      } catch (_) {}
    }

    return [];
  }

  static Future<void> _saveInvitedFriends(List<ReferralFriend> friends) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(friends.map((f) => f.toJson()).toList());
    await prefs.setString('wasel_invited_friends', raw);
  }

  /// Check a phone number against real database and record referral
  static Future<Map<String, dynamic>> evaluateAndAddReferral({
    required String friendName,
    required String friendPhone,
  }) async {
    final cleanPhone = friendPhone.replaceAll(RegExp(r'\s+|-'), '');
    final referrerPhone = ApiService.userPhone.isNotEmpty ? ApiService.userPhone : '0910000000';
    final rules = await getCampaignRules();
    final int targetCount = rules['target_count'] ?? 3;

    try {
      final res = await http.post(
        Uri.parse('$_backendBaseUrl/referrals/invite'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'referrer_phone': referrerPhone,
          'friend_phone': cleanPhone,
          'friend_name': friendName,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        final ref = body['referral'] ?? {};
        final isAlreadyRegistered = ref['status'] == 'already_registered';
        final bool rewardGranted = body['reward_granted'] == true;

        final friends = await getInvitedFriends();
        final newFriend = ReferralFriend(
          id: ref['id'] ?? 'ref_${DateTime.now().millisecondsSinceEpoch}',
          name: friendName,
          phone: cleanPhone,
          status: isAlreadyRegistered ? ReferralFriendStatus.alreadyRegistered : ReferralFriendStatus.verifiedNew,
          date: DateTime.now(),
        );
        friends.insert(0, newFriend);
        await _saveInvitedFriends(friends);

        if (rewardGranted && body['voucher'] != null) {
          final vMap = body['voucher'];
          final newVoucher = FreeDeliveryVoucher(
            id: vMap['id'] ?? 'vouch_${DateTime.now().millisecondsSinceEpoch}',
            code: vMap['code'] ?? 'FREE-REF',
            title: vMap['title'] ?? 'توصيل مجاني 🛵 (هدية الإحالات)',
            expiresAt: DateTime.tryParse(vMap['expires_at'] ?? '') ?? DateTime.now().add(const Duration(days: 14)),
            discountLyd: (vMap['discount_amount_lyd'] as num?)?.toDouble() ?? 5.0,
          );
          await addVoucher(newVoucher);
        }

        final verifiedCount = _countVerified(friends);
        return {
          'success': !isAlreadyRegistered,
          'is_already_registered': isAlreadyRegistered,
          'message': isAlreadyRegistered
              ? '⚠️ الصديق ($friendName) مسجل مسبقاً في واصل!\nلم يُحتسب كإحالة جديدة وفقاً لسياسة المنصة.'
              : '🎉 رائع! تم تأكيد تسجيل الصديق ($friendName) كمستخدم جديد في واصل بنجاح!',
          'voucher_issued': rewardGranted,
          'new_progress': verifiedCount % targetCount,
          'target_count': targetCount,
        };
      }
    } catch (_) {}

    // Fallback: local record
    final friends = await getInvitedFriends();
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

    return {
      'success': true,
      'is_already_registered': false,
      'message': 'تم تسجيل دعوة ($friendName) بنجاح.',
      'voucher_issued': false,
      'new_progress': verifiedCount % targetCount,
      'target_count': targetCount,
    };
  }

  static int _countVerified(List<ReferralFriend> friends) {
    return friends.where((f) => f.status == ReferralFriendStatus.verifiedNew || f.status == ReferralFriendStatus.completedFirstOrder).length;
  }

  /// Get active free delivery vouchers from real database
  static Future<List<FreeDeliveryVoucher>> getActiveVouchers() async {
    final phone = ApiService.userPhone;
    final prefs = await SharedPreferences.getInstance();

    if (phone.isNotEmpty) {
      try {
        final res = await http.get(
          Uri.parse('$_backendBaseUrl/vouchers/user/$phone'),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(res.body);
          if (body['success'] == true && body['data'] is List) {
            final List<dynamic> list = body['data'];
            final vouchers = list.map((item) {
              final m = Map<String, dynamic>.from(item);
              return FreeDeliveryVoucher(
                id: m['id'] ?? 'v_${m['code']}',
                code: m['code'] ?? '',
                title: m['title'] ?? 'كوبون واصل',
                expiresAt: DateTime.tryParse(m['expires_at'] ?? '') ?? DateTime.now().add(const Duration(days: 7)),
                discountLyd: (m['discount_amount_lyd'] as num?)?.toDouble() ?? 5.0,
                isUsed: m['is_used'] == true,
              );
            }).where((v) => v.isValid).toList();

            await prefs.setString('wasel_user_vouchers', jsonEncode(vouchers.map((v) => v.toJson()).toList()));
            return vouchers;
          }
        }
      } catch (_) {}
    }

    // Local cached vouchers
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

    return [];
  }

  /// Add a new earned voucher
  static Future<void> addVoucher(FreeDeliveryVoucher voucher) async {
    final prefs = await SharedPreferences.getInstance();
    List<FreeDeliveryVoucher> vouchers = [];
    final raw = prefs.getString('wasel_user_vouchers');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        vouchers = list.map((item) => FreeDeliveryVoucher.fromJson(Map<String, dynamic>.from(item))).toList();
      } catch (_) {}
    }
    vouchers.insert(0, voucher);
    final updatedRaw = jsonEncode(vouchers.map((v) => v.toJson()).toList());
    await prefs.setString('wasel_user_vouchers', updatedRaw);
  }

  /// Redeem voucher on checkout
  static Future<bool> redeemVoucher(String voucherId, {String? orderId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('wasel_user_vouchers');
    String? codeToRedeem;

    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        final vouchers = list.map((item) => FreeDeliveryVoucher.fromJson(Map<String, dynamic>.from(item))).toList();
        for (final v in vouchers) {
          if (v.id == voucherId) {
            v.isUsed = true;
            codeToRedeem = v.code;
          }
        }
        await prefs.setString('wasel_user_vouchers', jsonEncode(vouchers.map((v) => v.toJson()).toList()));
      } catch (_) {}
    }

    if (codeToRedeem != null) {
      try {
        await http.post(
          Uri.parse('$_backendBaseUrl/vouchers/user/redeem'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': codeToRedeem,
            'order_id': orderId,
          }),
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    return true;
  }
}
