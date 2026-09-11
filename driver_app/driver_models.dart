import 'package:flutter/material.dart';

/// ============================================================================
/// WASEL CAPTAIN / DRIVER DATA MODELS & BUSINESS DOMAINS
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
  final String type; // Motorcycle, Car, Van, Bicycle
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
  final String city; // Tripoli, Benghazi, Misrata
  final double surgeMultiplier;
  final String demandLevel; // 'Extreme', 'High', 'Moderate', 'Normal'
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
    this.isHotspot = false,
  });
}

/// Order Item in Pickup Checklist
class DeliveryItem {
  final String name;
  final int quantity;
  final String? options;
  final double unitPriceLyd;
  bool isChecked;

  DeliveryItem({
    required this.name,
    required this.quantity,
    this.options,
    required this.unitPriceLyd,
    this.isChecked = false,
  });
}

/// High-Urgency Incoming Radar Order
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
  final List<DeliveryItem> items;
  final int countdownSeconds;

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
    this.surgeBonusLyd = 0.0,
    this.tipLyd = 0.0,
    required this.paymentType,
    this.codCollectAmountLyd = 0.0,
    required this.items,
    this.countdownSeconds = 15,
  });

  double get totalDriverPayoutLyd => basePayoutLyd + surgeBonusLyd + tipLyd;
}

/// Active Delivery State Model
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
  final String customerOtpPin; // 4 digits
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
}

/// Wallet / COD Ledger Transaction
class LedgerTransaction {
  final String id;
  final String title;
  final String description;
  final double amountLyd;
  final bool isCredit; // true: income/credit, false: debit/liability/settlement
  final TransactionType type;
  final DateTime timestamp;
  final String? orderReference;
  final String referenceId;
  final String status; // 'completed', 'pending', 'settled'

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

/// Mock Dataset Provider for Wasel Libya Fleet
class DriverMockData {
  static const VehicleInfo defaultVehicle = VehicleInfo(
    type: 'Motorcycle (Scooter)',
    plateNumber: '5-29418 🇱🇾',
    model: 'Honda PCX 160 (Black)',
    icon: Icons.two_wheeler_rounded,
  );

  static const DriverStats initialStats = DriverStats(
    netEarningsTodayLyd: 148.50,
    netEarningsYesterdayLyd: 125.00,
    completedTripsToday: 12,
    cashInHandCodLyd: 215.00,
    maxCodLimitLyd: 500.0,
    rating: 4.97,
    totalReviews: 624,
    acceptanceRate: 0.96,
    onTimeRate: 0.98,
    onlineDurationSeconds: 14200, // ~3h 56m
  );

  static const List<DeliveryZoneHeat> libyanZones = [
    DeliveryZoneHeat(
      id: 'zone_andalus',
      name: 'Hai Al-Andalus & Gargarish',
      city: 'Tripoli',
      surgeMultiplier: 1.6,
      demandLevel: 'Extreme',
      estimatedWaitTime: '< 1 min',
      bonusLyd: 5.50,
      isHotspot: true,
    ),
    DeliveryZoneHeat(
      id: 'zone_center',
      name: 'Tripoli Downtown & Ras Hassan',
      city: 'Tripoli',
      surgeMultiplier: 1.4,
      demandLevel: 'High',
      estimatedWaitTime: '2-3 mins',
      bonusLyd: 3.50,
      isHotspot: true,
    ),
    DeliveryZoneHeat(
      id: 'zone_souq',
      name: 'Souq Al-Jumaa & Tajoura Road',
      city: 'Tripoli',
      surgeMultiplier: 1.2,
      demandLevel: 'Moderate',
      estimatedWaitTime: '4-5 mins',
      bonusLyd: 2.00,
      isHotspot: false,
    ),
    DeliveryZoneHeat(
      id: 'zone_berka',
      name: 'Al-Berka & Dubai Street',
      city: 'Benghazi',
      surgeMultiplier: 1.5,
      demandLevel: 'High',
      estimatedWaitTime: '1-2 mins',
      bonusLyd: 4.00,
      isHotspot: true,
    ),
  ];

  static RadarOrder getSampleIncomingOrder() {
    return RadarOrder(
      orderId: 'ord_ly_90412',
      orderNumber: '#PR-90412',
      storeName: 'Smash Gourmet Burger & Grill',
      storeCategory: 'Food & Dining (Wasel Food)',
      storeAddress: 'Gargarish Main Rd, Near Tripoli Tower',
      storeDistanceKm: 1.2,
      storeEtaMinutes: 4,
      customerAddress: 'Hai Al-Andalus, St 14, Villa 8B',
      customerArea: 'Tripoli Coastal District',
      tripDistanceKm: 3.8,
      tripEtaMinutes: 11,
      basePayoutLyd: 12.00,
      surgeBonusLyd: 4.50,
      tipLyd: 2.00,
      paymentType: PaymentType.cashOnDelivery,
      codCollectAmountLyd: 55.00,
      countdownSeconds: 15,
      items: [
        DeliveryItem(
          name: 'Double Truffle Smash Burger',
          quantity: 2,
          options: 'Extra melted cheddar, pickles on side',
          unitPriceLyd: 19.50,
        ),
        DeliveryItem(
          name: 'Crispy Cajun Loaded Fries',
          quantity: 1,
          options: 'Large, spicy jalapeno dip',
          unitPriceLyd: 8.50,
        ),
        DeliveryItem(
          name: 'Fresh Mint Lemonade (500ml)',
          quantity: 2,
          options: 'Less ice, extra mint',
          unitPriceLyd: 3.75,
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
      storeLatitude: 32.8752,
      storeLongitude: 13.1554,
      customerName: 'Ahmed Al-Warfali',
      customerPhone: '+218 92 876 5432',
      customerAddress: sample.customerAddress,
      customerNotes: 'Villa with blue gate. Please ring bell twice.',
      customerLatitude: 32.8890,
      customerLongitude: 13.1290,
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
        title: 'Delivery Payout #PR-90412',
        description: 'Trip earnings (12.00) + Surge (4.50) + Tip (2.00)',
        amountLyd: 18.50,
        isCredit: true,
        type: TransactionType.tripEarnings,
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        orderReference: '#PR-90412',
        referenceId: 'REF-8921-TRP',
      ),
      LedgerTransaction(
        id: 'tx_02',
        title: 'Cash Collected (COD)',
        description: 'Customer cash received for Order #PR-90412',
        amountLyd: 55.00,
        isCredit: false,
        type: TransactionType.codCollected,
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        orderReference: '#PR-90412',
        referenceId: 'COD-90412-LY',
      ),
      LedgerTransaction(
        id: 'tx_03',
        title: 'Delivery Payout #PR-90388',
        description: 'Trip earnings (10.00) + Surge (3.00)',
        amountLyd: 13.00,
        isCredit: true,
        type: TransactionType.tripEarnings,
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 40)),
        orderReference: '#PR-90388',
        referenceId: 'REF-8874-TRP',
      ),
      LedgerTransaction(
        id: 'tx_04',
        title: 'COD Platform Deposit (Settled)',
        description: 'Settled via Sadad Mobile Payment Gateway',
        amountLyd: 150.00,
        isCredit: true,
        type: TransactionType.platformSettlement,
        timestamp: DateTime.now().subtract(const Duration(hours: 3, minutes: 10)),
        referenceId: 'SADAD-TX-984102',
        status: 'settled',
      ),
      LedgerTransaction(
        id: 'tx_05',
        title: 'Weekly Payout Withdrawal',
        description: 'Transferred to Tadawul Card (Ending in **4819)',
        amountLyd: 250.00,
        isCredit: false,
        type: TransactionType.payoutWithdrawalTadawul,
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        referenceId: 'TDW-PAY-77192',
      ),
    ];
  }
}
