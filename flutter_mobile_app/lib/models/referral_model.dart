/// ============================================================================
/// WASEL REFERRAL & FREE DELIVERY VOUCHERS MODELS
/// ============================================================================
library;

enum ReferralFriendStatus {
  alreadyRegistered, // مسجل مسبقاً في واصل (لا يُحتسب كإحالة جديدة)
  verifiedNew,       // مستخدم جديد تم التحقق منه وتأكيد حسابه (محتسب ✅)
  completedFirstOrder, // أكمل أول طلب ناجح عبر التطبيق 🎉
}

class ReferralFriend {
  final String id;
  final String name;
  final String phone;
  final ReferralFriendStatus status;
  final DateTime date;

  ReferralFriend({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'status': status.index,
    'date': date.toIso8601String(),
  };

  factory ReferralFriend.fromJson(Map<String, dynamic> json) => ReferralFriend(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    status: ReferralFriendStatus.values[json['status'] ?? 0],
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
  );
}

class FreeDeliveryVoucher {
  final String id;
  final String code;
  final String title;
  final DateTime expiresAt;
  bool isUsed;
  final double discountLyd;

  FreeDeliveryVoucher({
    required this.id,
    required this.code,
    required this.title,
    required this.expiresAt,
    this.isUsed = false,
    this.discountLyd = 5.00, // تغطية كامل قيمة التوصيل
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isUsed && !isExpired;

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'title': title,
    'expiresAt': expiresAt.toIso8601String(),
    'isUsed': isUsed,
    'discountLyd': discountLyd,
  };

  factory FreeDeliveryVoucher.fromJson(Map<String, dynamic> json) => FreeDeliveryVoucher(
    id: json['id'] ?? '',
    code: json['code'] ?? '',
    title: json['title'] ?? 'توصيل مجاني 🛵',
    expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : DateTime.now().add(const Duration(days: 14)),
    isUsed: json['isUsed'] ?? false,
    discountLyd: (json['discountLyd'] is num) ? (json['discountLyd'] as num).toDouble() : 5.00,
  );
}
