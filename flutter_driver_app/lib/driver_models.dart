import 'package:flutter/material.dart';

/// ============================================================================
/// CAPTAIN WASEL (كابتن واصل) DATA MODELS & NALUT MOCK DATA
/// ============================================================================

enum DriverOnlineStatus {
  offline,
  onlineIdle,
  busyDelivery,
}

enum DeliveryStep {
  navigatingToStore,
  orderPickupChecklist,
  navigatingToCustomer,
  completeDeliveryOtp,
  deliveryFinished,
}

enum PaymentType {
  cashOnDelivery,
  prepaidSadad,
  prepaidTadawul,
  prepaidWallet,
  prepaidJumhouria,
  prepaidNab,
  prepaidLypay,
  prepaidOnepay,
}

enum TransactionType {
  tripEarnings,
  tipReceived,
  surgeBonus,
  codCollected,
  platformSettlement,
  payoutWithdrawalSadad,
  payoutWithdrawalTadawul,
}

/// Vehicle Information
class VehicleInfo {
  final String type;
  final String plateNumber;
  final String model;
  final IconData icon;

  const VehicleInfo({
    required this.type,
    required this.plateNumber,
    required this.model,
    required this.icon,
  });
}

/// Driver Daily Earnings & Performance Stats
class DriverStats {
  final double netEarningsTodayLyd;
  final double netEarningsYesterdayLyd;
  final int completedTripsToday;
  final double cashInHandCodLyd;
  final double maxCodLimitLyd;
  final double rating;
  final int totalReviews;
  final double acceptanceRate;
  final double onTimeRate;
  final int onlineDurationSeconds;

  const DriverStats({
    required this.netEarningsTodayLyd,
    required this.netEarningsYesterdayLyd,
    required this.completedTripsToday,
    required this.cashInHandCodLyd,
    this.maxCodLimitLyd = 500.0,
    required this.rating,
    required this.totalReviews,
    required this.acceptanceRate,
    required this.onTimeRate,
    required this.onlineDurationSeconds,
  });

  double get codUsageRatio => (cashInHandCodLyd / maxCodLimitLyd).clamp(0.0, 1.0);
  bool get isCodLimitApproaching => cashInHandCodLyd >= (maxCodLimitLyd * 0.75);
  bool get isCodLimitExceeded => cashInHandCodLyd >= maxCodLimitLyd;
}

/// Delivery Zone Heat Map Info
class DeliveryZoneHeat {
  final String id;
  final String name;
  final String city;
  final double surgeMultiplier;
  final String demandLevel;
  final String estimatedWaitTime;
  final double bonusLyd;
  final bool isHotspot;

  const DeliveryZoneHeat({
    required this.id,
    required this.name,
    required this.city,
    required this.surgeMultiplier,
    required this.demandLevel,
    required this.estimatedWaitTime,
    required this.bonusLyd,
    required this.isHotspot,
  });
}

/// Delivery Item
class DeliveryItem {
  final String name;
  final int quantity;
  final String options;
  final double unitPriceLyd;
  bool isVerified;

  DeliveryItem({
    required this.name,
    required this.quantity,
    required this.options,
    required this.unitPriceLyd,
    this.isVerified = false,
  });
}

/// Incoming Radar Order Offer
class RadarOrder {
  final String orderId;
  final String orderNumber;
  final String storeName;
  final String storeCategory;
  final String storeAddress;
  final double storeDistanceKm;
  final int storeEtaMinutes;
  final String customerAddress;
  final String customerArea;
  final double tripDistanceKm;
  final int tripEtaMinutes;
  final double basePayoutLyd;
  final double surgeBonusLyd;
  final double tipLyd;
  final PaymentType paymentType;
  final double codCollectAmountLyd;
  final int countdownSeconds;
  final List<DeliveryItem> items;
  final String status;
  final String? prepStatusBadge;

  const RadarOrder({
    required this.orderId,
    required this.orderNumber,
    required this.storeName,
    required this.storeCategory,
    required this.storeAddress,
    required this.storeDistanceKm,
    required this.storeEtaMinutes,
    required this.customerAddress,
    required this.customerArea,
    required this.tripDistanceKm,
    required this.tripEtaMinutes,
    required this.basePayoutLyd,
    required this.surgeBonusLyd,
    required this.tipLyd,
    required this.paymentType,
    required this.codCollectAmountLyd,
    this.countdownSeconds = 15,
    required this.items,
    this.status = 'ready_for_pickup',
    this.prepStatusBadge,
  });

  double get totalDriverPayoutLyd => basePayoutLyd + surgeBonusLyd + tipLyd;
  bool get isCashOnDelivery => paymentType == PaymentType.cashOnDelivery;
}

/// Ongoing Active Delivery
class ActiveDeliveryOrder {
  final String orderId;
  final String orderNumber;
  final String storeName;
  final String storePhone;
  final String storeAddress;
  final double storeLatitude;
  final double storeLongitude;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String customerNotes;
  final double customerLatitude;
  final double customerLongitude;
  final PaymentType paymentType;
  final double codAmountLyd;
  final String customerOtpPin;
  final double driverPayoutLyd;
  final List<DeliveryItem> items;
  DeliveryStep currentStep;

  ActiveDeliveryOrder({
    required this.orderId,
    required this.orderNumber,
    required this.storeName,
    required this.storePhone,
    required this.storeAddress,
    required this.storeLatitude,
    required this.storeLongitude,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerNotes,
    required this.customerLatitude,
    required this.customerLongitude,
    required this.paymentType,
    required this.codAmountLyd,
    required this.customerOtpPin,
    required this.driverPayoutLyd,
    required this.items,
    this.currentStep = DeliveryStep.navigatingToStore,
  });

  bool get isAllItemsVerified => items.every((i) => i.isVerified);
  bool get isCod => paymentType == PaymentType.cashOnDelivery;
}

/// Ledger Transaction
class LedgerTransaction {
  final String id;
  final String title;
  final String description;
  final double amountLyd;
  final bool isCredit;
  final TransactionType type;
  final DateTime timestamp;
  final String? orderReference;
  final String referenceId;
  final String status;

  const LedgerTransaction({
    required this.id,
    required this.title,
    required this.description,
    required this.amountLyd,
    required this.isCredit,
    required this.type,
    required this.timestamp,
    this.orderReference,
    required this.referenceId,
    this.status = 'completed',
  });
}

/// Mock Dataset for Captain Wasel in Nalut
class DriverMockData {
  static const VehicleInfo driverVehicle = VehicleInfo(
    type: 'سيارة (Car)',
    plateNumber: 'نالوت 4-11204',
    model: 'كيا سيراتو (Kia Cerato)',
    icon: Icons.directions_car_rounded,
  );

  static const DriverStats initialStats = DriverStats(
    netEarningsTodayLyd: 0.0,
    netEarningsYesterdayLyd: 0.0,
    completedTripsToday: 0,
    cashInHandCodLyd: 0.0,
    maxCodLimitLyd: 500.0,
    rating: 5.0,
    totalReviews: 0,
    acceptanceRate: 1.0,
    onTimeRate: 1.0,
    onlineDurationSeconds: 0,
  );

  static const List<DeliveryZoneHeat> libyanZones = [
    DeliveryZoneHeat(
      id: 'zone_shuhada',
      name: 'حي الشهداء وقصر نالوت',
      city: 'نالوت',
      surgeMultiplier: 1.6,
      demandLevel: 'مرتفع جداً 🔥',
      estimatedWaitTime: '< 1 دقيقة',
      bonusLyd: 4.50,
      isHotspot: true,
    ),
    DeliveryZoneHeat(
      id: 'zone_center',
      name: 'وسط نالوت وطريق وازن',
      city: 'نالوت',
      surgeMultiplier: 1.4,
      demandLevel: 'طلب عالي',
      estimatedWaitTime: '2-3 دقائق',
      bonusLyd: 3.00,
      isHotspot: true,
    ),
    DeliveryZoneHeat(
      id: 'zone_qalaa',
      name: 'منطقة القلعة وتالات',
      city: 'نالوت',
      surgeMultiplier: 1.2,
      demandLevel: 'متوسط',
      estimatedWaitTime: '4-5 دقائق',
      bonusLyd: 2.00,
      isHotspot: false,
    ),
  ];

  static RadarOrder getSampleIncomingOrder() {
    return RadarOrder(
      orderId: 'ord_ly_90412',
      orderNumber: '#WSL-90412',
      storeName: 'مطعم قصر نالوت للمشويات',
      storeCategory: 'طعام ومأكولات ليبية (واصل طعام)',
      storeAddress: 'نالوت - بالقرب من القصر الأثري',
      storeDistanceKm: 1.2,
      storeEtaMinutes: 4,
      customerAddress: 'حي الشهداء، شارع النور، نالوت',
      customerArea: 'منطقة نالوت المركزية',
      tripDistanceKm: 2.8,
      tripEtaMinutes: 8,
      basePayoutLyd: 10.00,
      surgeBonusLyd: 3.50,
      tipLyd: 1.00,
      paymentType: PaymentType.cashOnDelivery,
      codCollectAmountLyd: 48.00,
      countdownSeconds: 15,
      items: [
        DeliveryItem(
          name: 'صحن مشويات مشكل قصر نالوت',
          quantity: 1,
          options: 'خبز تنور إضافي، سلطة مشوية جبلية',
          unitPriceLyd: 28.00,
        ),
        DeliveryItem(
          name: 'بيتزا القلعة سوبريم حجم كبير',
          quantity: 1,
          options: 'جبنة موزاريلا إضافية',
          unitPriceLyd: 20.00,
        ),
      ],
    );
  }

  static ActiveDeliveryOrder getSampleActiveDelivery() {
    final sample = getSampleIncomingOrder();
    return ActiveDeliveryOrder(
      orderId: sample.orderId,
      orderNumber: sample.orderNumber,
      storeName: sample.storeName,
      storePhone: '+218 91 234 5678',
      storeAddress: sample.storeAddress,
      storeLatitude: 31.8686,
      storeLongitude: 10.9818,
      customerName: 'محمد سالم الورفلي',
      customerPhone: '+218 92 876 5432',
      customerAddress: sample.customerAddress,
      customerNotes: 'منزل بباب أزرق بجانب المسجد. يرجى الاتصال عند الوصول.',
      customerLatitude: 31.8740,
      customerLongitude: 10.9790,
      paymentType: sample.paymentType,
      codAmountLyd: sample.codCollectAmountLyd,
      customerOtpPin: '8492',
      driverPayoutLyd: sample.totalDriverPayoutLyd,
      items: sample.items,
      currentStep: DeliveryStep.navigatingToStore,
    );
  }

  static List<LedgerTransaction> getSampleTransactions() {
    return [
      LedgerTransaction(
        id: 'tx_01',
        title: 'عائد توصيل طلب #WSL-90412',
        description: 'مشوار أساسي (10.00) + مكافأة ذروة (3.50) + إكرامية (1.00)',
        amountLyd: 14.50,
        isCredit: true,
        type: TransactionType.tripEarnings,
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        orderReference: '#WSL-90412',
        referenceId: 'REF-8921-NAL',
      ),
      LedgerTransaction(
        id: 'tx_02',
        title: 'كاش محصل من الزبون (COD)',
        description: 'تحصيل كاش للطلب #WSL-90412 (مطعم قصر نالوت)',
        amountLyd: 48.00,
        isCredit: false,
        type: TransactionType.codCollected,
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        orderReference: '#WSL-90412',
        referenceId: 'COD-90412-LY',
      ),
      LedgerTransaction(
        id: 'tx_03',
        title: 'عائد توصيل طلب #WSL-90388',
        description: 'مشوار أسواق نالوت المركزية (واصل فوري)',
        amountLyd: 12.00,
        isCredit: true,
        type: TransactionType.tripEarnings,
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 40)),
        orderReference: '#WSL-90388',
        referenceId: 'REF-8874-NAL',
      ),
      LedgerTransaction(
        id: 'tx_04',
        title: 'تسوية كاش المنصة (تمت بنجاح)',
        description: 'تسوية كاش COD عبر خدمة سداد الإلكترونية (Sadad Pay)',
        amountLyd: 150.00,
        isCredit: true,
        type: TransactionType.platformSettlement,
        timestamp: DateTime.now().subtract(const Duration(hours: 3, minutes: 10)),
        referenceId: 'SADAD-TX-984102',
        status: 'settled',
      ),
      LedgerTransaction(
        id: 'tx_05',
        title: 'سحب أرباح أسبوعية',
        description: 'تحويل مباشر إلى بطاقة تداول المصرفية (تنتهي بـ **4819)',
        amountLyd: 250.00,
        isCredit: false,
        type: TransactionType.payoutWithdrawalTadawul,
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        referenceId: 'TDW-PAY-77192',
      ),
    ];
  }
}
