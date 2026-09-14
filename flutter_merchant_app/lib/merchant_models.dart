import 'package:flutter/material.dart';

/// ============================================================================
/// WASEL MERCHANT & KITCHEN DATA MODELS & NALUT MOCK DATA
/// ============================================================================

enum KdsTicketStatus {
  newOrder,
  preparing,
  readyForPickup,
  completed,
  cancelled,
}

enum StoreStatus {
  open,
  rushHour,
  closed,
}

enum PartnerAppMode {
  kitchen, // للمطاعم والكافيهات ومحلات البيتزا والشاورما (شاشة المطبخ KDS)
  retail,  // للسوبرماركت والبقالة والمواد الغذائية والصيدليات (تجميع الأصناف Pick & Pack)
}

class PartnerStore {
  final String id;
  final String name;
  final String nameEn;
  final String type; // restaurant, pizza, grocery, pharmacy
  final String district;
  final String phone;
  final PartnerAppMode mode;
  final IconData icon;

  const PartnerStore({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.type,
    required this.district,
    required this.phone,
    required this.mode,
    required this.icon,
  });

  factory PartnerStore.fromMap(Map<String, dynamic> map) {
    final type = map['category']?.toString().toLowerCase() ??
        map['type']?.toString().toLowerCase() ??
        'restaurant';
    final isRetail = type == 'grocery' ||
        type == 'supermarket' ||
        type == 'pharmacy' ||
        map['app_mode'] == 'retail';
    IconData icon;
    if (type.contains('pizza')) {
      icon = Icons.local_pizza_rounded;
    } else if (type.contains('burger') ||
        type.contains('restaurant') ||
        type.contains('food') ||
        type.contains('cafe')) {
      icon = Icons.lunch_dining_rounded;
    } else if (type.contains('pharmacy') || type.contains('health')) {
      icon = Icons.medication_rounded;
    } else {
      icon = isRetail ? Icons.shopping_cart_rounded : Icons.storefront_rounded;
    }
    return PartnerStore(
      id: map['id']?.toString() ?? 'store_dynamic',
      name: map['name_ar']?.toString() ?? map['name']?.toString() ?? 'متجر نالوت',
      nameEn: map['name_en']?.toString() ?? map['nameEn']?.toString() ?? '',
      type: type,
      district: map['district']?.toString() ?? map['address']?.toString() ?? 'نالوت',
      phone: map['phone']?.toString() ?? '',
      mode: isRetail ? PartnerAppMode.retail : PartnerAppMode.kitchen,
      icon: icon,
    );
  }

  static const defaultStore = PartnerStore(
    id: 'store_default',
    name: 'متجر واصل',
    nameEn: 'Wasel Store',
    type: 'restaurant',
    district: 'نالوت',
    phone: '',
    mode: PartnerAppMode.kitchen,
    icon: Icons.storefront_rounded,
  );

  static const List<PartnerStore> nalutStores = [];
}

class MerchantUser {
  final String id;
  final String phone;
  final String name;
  final String storeId;
  final String role; // owner, chef, cashier, inventory_manager

  const MerchantUser({
    required this.id,
    required this.phone,
    required this.name,
    required this.storeId,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'storeId': storeId,
        'role': role,
      };

  factory MerchantUser.fromJson(Map<String, dynamic> json) => MerchantUser(
        id: json['id'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String,
        storeId: json['storeId'] as String,
        role: json['role'] as String? ?? 'chef',
      );
}

class MerchantReceipt {
  final String id;
  final String receiptNumber;
  final String orderNumber;
  final String storeId;
  final DateTime issuedAt;
  final double subtotalLyd;
  final double deliveryFeeLyd;
  final double platformCommissionLyd;
  final double netMerchantLyd;
  final String paymentMethod; // Cash, Sadad, Tadawul, Wallet
  final String paymentStatus; // paid, collected, pending
  final String customerName;
  final String? customerPhone;
  final String? courierName;
  final List<KdsOrderItem> items;

  const MerchantReceipt({
    required this.id,
    required this.receiptNumber,
    required this.orderNumber,
    required this.storeId,
    required this.issuedAt,
    required this.subtotalLyd,
    required this.deliveryFeeLyd,
    required this.platformCommissionLyd,
    required this.netMerchantLyd,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.customerName,
    this.customerPhone,
    this.courierName,
    required this.items,
  });
}

class KdsOrderItem {
  final String name;
  final int quantity;
  final double priceLyd;
  final String? notes;
  bool isCollected;
  bool isOutOfStock;
  String? substituteNote;

  KdsOrderItem({
    required this.name,
    required this.quantity,
    required this.priceLyd,
    this.notes,
    this.isCollected = false,
    this.isOutOfStock = false,
    this.substituteNote,
  });

  double get totalLyd => priceLyd * quantity;
}

class KdsOrder {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String? customerNotes;
  KdsTicketStatus status;
  final DateTime timePlaced;
  int prepTimeMinutes;
  final List<KdsOrderItem> items;
  final double totalAmountLyd;
  final String paymentMethod; // COD, Sadad, Tadawul, Wallet
  final String? courierName;
  final String? courierVehicle;
  final String? courierPhone;

  KdsOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.customerNotes,
    required this.status,
    required this.timePlaced,
    this.prepTimeMinutes = 15,
    required this.items,
    required this.totalAmountLyd,
    required this.paymentMethod,
    this.courierName,
    this.courierVehicle,
    this.courierPhone,
  });

  int get elapsedMinutes => DateTime.now().difference(timePlaced).inMinutes;
  bool get isUrgent => status == KdsTicketStatus.newOrder && elapsedMinutes >= 4;

  int get collectedItemsCount => items.where((i) => i.isCollected).length;
  bool get allItemsCollected => items.isNotEmpty && items.every((i) => i.isCollected || i.isOutOfStock);
}

class CatalogProduct {
  final String id;
  final String nameAr;
  final String category;
  double priceLyd;
  bool inStock;
  int stockQuantity;
  int minStockAlert;
  final String descAr;
  final IconData icon;

  CatalogProduct({
    required this.id,
    required this.nameAr,
    required this.category,
    required this.priceLyd,
    this.inStock = true,
    this.stockQuantity = 25,
    this.minStockAlert = 5,
    required this.descAr,
    this.icon = Icons.restaurant_rounded,
  });

  bool get isLowStock => inStock && stockQuantity <= minStockAlert;
}

class MerchantMockData {
  static StoreStatus currentStoreStatus = StoreStatus.open;

  static List<CatalogProduct> getSampleCatalog() => [];

  static List<KdsOrder> getSampleOrders() => [];

  static List<KdsOrder> getSampleRetailOrders() => [];

  static const List<Map<String, String>> registeredMerchants = [];

  static List<MerchantReceipt> getSampleReceipts(String storeId) => [];
}
