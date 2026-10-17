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

  static const DriverStats initial = DriverStats(
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

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'options': options,
    'unitPriceLyd': unitPriceLyd,
    'isVerified': isVerified,
  };

  factory DeliveryItem.fromJson(Map<String, dynamic> json) => DeliveryItem(
    name: json['name']?.toString() ?? '',
    quantity: (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1,
    options: json['options']?.toString() ?? '',
    unitPriceLyd: (json['unitPriceLyd'] is num) ? (json['unitPriceLyd'] as num).toDouble() : 0.0,
    isVerified: json['isVerified'] == true,
  );
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
  final double driverPayoutLyd;
  final String? handoverCode;
  final List<DeliveryItem> items;
  DeliveryStep currentStep;
  String orderStatus;

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
    required this.driverPayoutLyd,
    required this.items,
    this.currentStep = DeliveryStep.navigatingToStore,
    this.orderStatus = 'preparing',
    this.handoverCode,
  });

  static String generateHandoverCode(String orderIdOrNumber) {
    final digits = orderIdOrNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return digits.substring(digits.length - 4);
    }
    final hash = (orderIdOrNumber.hashCode.abs() % 9000 + 1000).toString();
    return hash;
  }

  bool get isAllItemsVerified => items.every((i) => i.isVerified);
  bool get isCod => paymentType == PaymentType.cashOnDelivery;

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'orderNumber': orderNumber,
    'storeName': storeName,
    'storePhone': storePhone,
    'storeAddress': storeAddress,
    'storeLatitude': storeLatitude,
    'storeLongitude': storeLongitude,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerAddress': customerAddress,
    'customerNotes': customerNotes,
    'customerLatitude': customerLatitude,
    'customerLongitude': customerLongitude,
    'paymentType': paymentType.name,
    'codAmountLyd': codAmountLyd,
    'driverPayoutLyd': driverPayoutLyd,
    'handoverCode': handoverCode ?? generateHandoverCode(orderNumber.isNotEmpty ? orderNumber : orderId),
    'items': items.map((i) => i.toJson()).toList(),
    'currentStep': currentStep.name,
    'orderStatus': orderStatus,
  };

  factory ActiveDeliveryOrder.fromJson(Map<String, dynamic> json) {
    PaymentType pType = PaymentType.cashOnDelivery;
    final pName = json['paymentType']?.toString();
    if (pName != null) {
      for (final val in PaymentType.values) {
        if (val.name == pName) {
          pType = val;
          break;
        }
      }
    }

    DeliveryStep step = DeliveryStep.navigatingToStore;
    final sName = json['currentStep']?.toString();
    if (sName != null) {
      for (final val in DeliveryStep.values) {
        if (val.name == sName) {
          step = val;
          break;
        }
      }
    }

    List<DeliveryItem> itemList = [];
    if (json['items'] is List) {
      itemList = (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((i) => DeliveryItem.fromJson(i))
          .toList();
    }
    if (itemList.isEmpty) {
      itemList = [
        DeliveryItem(
          name: 'طلب نالوت',
          quantity: 1,
          options: 'نشط',
          unitPriceLyd: (json['codAmountLyd'] is num) ? (json['codAmountLyd'] as num).toDouble() : 0.0,
        ),
      ];
    }

    final rawHandover = json['handoverCode']?.toString() ?? json['handover_code']?.toString() ?? json['pickup_code']?.toString();
    final handover = (rawHandover != null && rawHandover.isNotEmpty)
        ? rawHandover
        : generateHandoverCode(json['orderNumber']?.toString() ?? json['orderId']?.toString() ?? '1000');

    return ActiveDeliveryOrder(
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '#W-100',
      storeName: json['storeName']?.toString() ?? 'متجر نالوت',
      storePhone: json['storePhone']?.toString() ?? '091-2233445',
      storeAddress: json['storeAddress']?.toString() ?? 'نالوت - المركز',
      storeLatitude: (json['storeLatitude'] is num) ? (json['storeLatitude'] as num).toDouble() : 31.8680,
      storeLongitude: (json['storeLongitude'] is num) ? (json['storeLongitude'] as num).toDouble() : 10.9850,
      customerName: json['customerName']?.toString() ?? 'زبون نالوت',
      customerPhone: json['customerPhone']?.toString() ?? '091-7788990',
      customerAddress: json['customerAddress']?.toString() ?? 'نالوت',
      customerNotes: json['customerNotes']?.toString() ?? '',
      customerLatitude: (json['customerLatitude'] is num) ? (json['customerLatitude'] as num).toDouble() : 31.8620,
      customerLongitude: (json['customerLongitude'] is num) ? (json['customerLongitude'] as num).toDouble() : 10.9780,
      paymentType: pType,
      codAmountLyd: (json['codAmountLyd'] is num) ? (json['codAmountLyd'] as num).toDouble() : 0.0,
      driverPayoutLyd: (json['driverPayoutLyd'] is num) ? (json['driverPayoutLyd'] as num).toDouble() : 0.0,
      handoverCode: handover,
      items: itemList,
      currentStep: step,
      orderStatus: json['orderStatus']?.toString() ?? 'preparing',
    );
  }
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

