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

  static const List<PartnerStore> nalutStores = [
    PartnerStore(
      id: 'store_nalut_ranchello',
      name: 'مطعم ومقهى رانشيلو',
      nameEn: 'Ranchello Restaurant & Cafe',
      type: 'restaurant',
      district: 'شارع أفريقيا، نالوت',
      phone: '0919570011',
      mode: PartnerAppMode.kitchen,
      icon: Icons.lunch_dining_rounded,
    ),
    PartnerStore(
      id: 'store_nalut_akakus',
      name: 'بيتزا أكاكوس',
      nameEn: 'Pizza Akakus',
      type: 'pizza',
      district: 'شارع تونس، نالوت',
      phone: '0910000000',
      mode: PartnerAppMode.kitchen,
      icon: Icons.local_pizza_rounded,
    ),
    PartnerStore(
      id: 'store_nalut_rixos',
      name: 'ريكسوس للتسوق (ماركت)',
      nameEn: 'Rixos Shopping Market',
      type: 'grocery',
      district: 'المدخل الرئيسي - نالوت',
      phone: '0910000000',
      mode: PartnerAppMode.retail,
      icon: Icons.shopping_cart_rounded,
    ),
    PartnerStore(
      id: 'store_nalut_alhanaa',
      name: 'صيدلية الهناء',
      nameEn: 'Al-Hanaa Pharmacy',
      type: 'pharmacy',
      district: 'مقابل جزيرة مصرف الجمهورية، نالوت',
      phone: '0910000000',
      mode: PartnerAppMode.retail,
      icon: Icons.medication_rounded,
    ),
  ];
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
  final String descAr;
  final IconData icon;

  CatalogProduct({
    required this.id,
    required this.nameAr,
    required this.category,
    required this.priceLyd,
    this.inStock = true,
    required this.descAr,
    this.icon = Icons.restaurant_rounded,
  });
}

class MerchantMockData {
  static StoreStatus currentStoreStatus = StoreStatus.open;

  static List<CatalogProduct> getSampleCatalog() {
    return [
      CatalogProduct(
        id: 'prod_ranchello_happiness_cheese',
        nameAr: 'بوكس السعادة بالجبنة',
        category: 'البوكسات والعائلي',
        priceLyd: 31.00,
        inStock: true,
        descAr: 'بوكس السعادة المميز مغطى بجبنة شيدر وموزاريلا ذائبة ومقرمشات',
        icon: Icons.takeout_dining_rounded,
      ),
      CatalogProduct(
        id: 'prod_ranchello_box_big',
        nameAr: 'بوكس كبير',
        category: 'البوكسات والعائلي',
        priceLyd: 140.00,
        inStock: true,
        descAr: 'بوكس رانشيلو الحجم الكبير المناسب للعزائم والجمعات العائلية',
        icon: Icons.inventory_2_rounded,
      ),
      CatalogProduct(
        id: 'prod_ranchello_meal_chicken_full',
        nameAr: 'وجبة دجاجة كاملة',
        category: 'الوجبات الرئيسية',
        priceLyd: 45.00,
        inStock: true,
        descAr: 'دجاجة كاملة مشوية على الفحم مع الأرز والبطاطا والسلطة',
        icon: Icons.dinner_dining_rounded,
      ),
      CatalogProduct(
        id: 'prod_ranchello_meal_shish_tawook',
        nameAr: 'وجبة شيش طاووق',
        category: 'الوجبات الرئيسية',
        priceLyd: 22.00,
        inStock: true,
        descAr: 'أسياخ شيش طاووق صدور دجاج متبلة مع بطاطا وثومية وخبز صاج',
        icon: Icons.kebab_dining_rounded,
      ),
      CatalogProduct(
        id: 'prod_ranchello_scallop_fatira_big',
        nameAr: 'سكالوب فطيرة كبير',
        category: 'السندوتشات والفطائر',
        priceLyd: 23.00,
        inStock: true,
        descAr: 'سكالوب دجاج مقرمش في خبز الفطيرة الليبية الطازجة بالحجم الكبير',
        icon: Icons.lunch_dining_rounded,
      ),
      CatalogProduct(
        id: 'prod_ranchello_shawarma_double',
        nameAr: 'شاورما دبل',
        category: 'السندوتشات والفطائر',
        priceLyd: 18.00,
        inStock: true,
        descAr: 'سندوتش شاورما بحجم مضاعف وإضافات غنية',
        icon: Icons.lunch_dining_rounded,
      ),
      CatalogProduct(
        id: 'prod_ranchello_plate_kebab',
        nameAr: 'كباب صحن',
        category: 'الصحون والمقبلات',
        priceLyd: 18.00,
        inStock: true,
        descAr: 'صحن كباب لحم مشوي على الفحم مع الطماطم والفلفل المشوي والخبز',
        icon: Icons.outdoor_grill_rounded,
      ),
      CatalogProduct(
        id: 'prod_ranchello_lentil_soup',
        nameAr: 'شوربة عدس',
        category: 'الصحون والمقبلات',
        priceLyd: 5.00,
        inStock: true,
        descAr: 'شوربة عدس دافئة ومغذية مع الخبز المحمص والليمون',
        icon: Icons.soup_kitchen_rounded,
      ),
    ];
  }

  static List<KdsOrder> getSampleOrders() {
    return [
      KdsOrder(
        id: 'ord_101',
        orderNumber: '#WSL-90412',
        customerName: 'محمد سالم الورفلي',
        customerPhone: '+218 91 123 4567',
        deliveryAddress: 'حي الشهداء، شارع النور، نالوت',
        customerNotes: 'ثومية إضافية وخبز ساخن',
        status: KdsTicketStatus.newOrder,
        timePlaced: DateTime.now().subtract(const Duration(minutes: 2)),
        prepTimeMinutes: 15,
        totalAmountLyd: 53.00,
        paymentMethod: 'كاش عند الاستلام (COD)',
        items: [
          KdsOrderItem(name: 'بوكس السعادة بالجبنة', quantity: 1, priceLyd: 31.00, notes: 'جبنة زيادة'),
          KdsOrderItem(name: 'وجبة شيش طاووق', quantity: 1, priceLyd: 22.00, notes: 'ثومية زيادة'),
        ],
      ),
      KdsOrder(
        id: 'ord_102',
        orderNumber: '#WSL-90415',
        customerName: 'أحمد بن عثمان النالوتي',
        customerPhone: '+218 92 876 5432',
        deliveryAddress: 'شارع أفريقيا، قرب رانشيلو، نالوت',
        customerNotes: 'يرجى تحمير البطاطا جيداً',
        status: KdsTicketStatus.newOrder,
        timePlaced: DateTime.now().subtract(const Duration(minutes: 1)),
        prepTimeMinutes: 20,
        totalAmountLyd: 59.00,
        paymentMethod: 'سداد (Sadad Pay)',
        items: [
          KdsOrderItem(name: 'سكالوب فطيرة كبير', quantity: 1, priceLyd: 23.00),
          KdsOrderItem(name: 'شاورما دبل', quantity: 2, priceLyd: 18.00, notes: 'بدون شطة'),
        ],
      ),
      KdsOrder(
        id: 'ord_103',
        orderNumber: '#WSL-90398',
        customerName: 'طارق العكرمي',
        customerPhone: '+218 94 333 2211',
        deliveryAddress: 'طريق وازن، نالوت',
        customerNotes: 'كباب مستوي جيداً على الفحم',
        status: KdsTicketStatus.preparing,
        timePlaced: DateTime.now().subtract(const Duration(minutes: 8)),
        prepTimeMinutes: 15,
        totalAmountLyd: 41.00,
        paymentMethod: 'محفظة واصل',
        items: [
          KdsOrderItem(name: 'كباب صحن', quantity: 2, priceLyd: 18.00),
          KdsOrderItem(name: 'شوربة عدس', quantity: 1, priceLyd: 5.00),
        ],
      ),
      KdsOrder(
        id: 'ord_104',
        orderNumber: '#WSL-90388',
        customerName: 'إبراهيم الجبالي',
        customerPhone: '+218 91 444 5566',
        deliveryAddress: 'منطقة القلعة، نالوت',
        customerNotes: 'الكابتن ينتظر بالباب للاستلام',
        status: KdsTicketStatus.readyForPickup,
        timePlaced: DateTime.now().subtract(const Duration(minutes: 18)),
        prepTimeMinutes: 15,
        totalAmountLyd: 45.00,
        paymentMethod: 'كاش عند الاستلام (COD)',
        courierName: 'كابتن وسيم النالوتي',
        courierVehicle: 'كيا سيراتو (نالوت 4-11204)',
        courierPhone: '+218 91 777 8899',
        items: [
          KdsOrderItem(name: 'وجبة دجاجة كاملة', quantity: 1, priceLyd: 45.00),
        ],
      ),
    ];
  }

  static List<KdsOrder> getSampleRetailOrders() {
    return [
      KdsOrder(
        id: 'ord_rixos_201',
        orderNumber: '#WSL-88021',
        customerName: 'د. مسعود قاسم',
        customerPhone: '+218 91 665 4411',
        deliveryAddress: 'حي المستشفى، بجوار عيادة نالوت المركزية',
        customerNotes: 'يرجى التأكد من تاريخ الصلاحية للحليب والتونة',
        status: KdsTicketStatus.preparing,
        timePlaced: DateTime.now().subtract(const Duration(minutes: 6)),
        prepTimeMinutes: 20,
        totalAmountLyd: 64.50,
        paymentMethod: 'سداد (Sadad Pay)',
        courierName: 'كابتن وسيم النالوتي',
        courierVehicle: 'تويوتا بريفيا (نالوت)',
        courierPhone: '091-7778899',
        items: [
          KdsOrderItem(name: 'حليب البقرة الحلوب كامل الدسم 1 لتر', quantity: 3, priceLyd: 4.50, isCollected: true),
          KdsOrderItem(name: 'زيت زيتون نالوتي بكر عصرة أولى 1 لتر', quantity: 1, priceLyd: 22.00, isCollected: true),
          KdsOrderItem(name: 'مياه نالوت المعدنية الطبيعية شد 6 قارورات', quantity: 2, priceLyd: 4.00, isCollected: true),
          KdsOrderItem(name: 'تونة الطاهي قطع فاخرة بزيت دوار الشمس', quantity: 4, priceLyd: 3.50, isCollected: false),
          KdsOrderItem(name: 'خبز توست أبيض بريوش طازج', quantity: 2, priceLyd: 3.50, isCollected: false),
        ],
      ),
      KdsOrder(
        id: 'ord_rixos_202',
        orderNumber: '#WSL-88026',
        customerName: 'فاطمة التائب',
        customerPhone: '+218 92 332 1199',
        deliveryAddress: 'حي الشهداء، نالوت',
        customerNotes: 'الاتصال عند الوصول للباب',
        status: KdsTicketStatus.newOrder,
        timePlaced: DateTime.now().subtract(const Duration(minutes: 2)),
        prepTimeMinutes: 15,
        totalAmountLyd: 41.00,
        paymentMethod: 'كاش عند الاستلام (COD)',
        items: [
          KdsOrderItem(name: 'أرز بسمتي الشعلان عنبر 5 كجم', quantity: 1, priceLyd: 24.00),
          KdsOrderItem(name: 'مكرونة سباغيتي إيطالية 500 جم', quantity: 3, priceLyd: 3.00),
          KdsOrderItem(name: 'صلصة طماطم الليبية معجون مركز 400 جم', quantity: 2, priceLyd: 4.00),
        ],
      ),
      KdsOrder(
        id: 'ord_alhanaa_301',
        orderNumber: '#WSL-88030',
        customerName: 'أ. سالم يوسف',
        customerPhone: '+218 94 888 2233',
        deliveryAddress: 'شارع تونس، قرب مدرسة نالوت الثانوية',
        customerNotes: 'مستعجل يرجى تسليمه سريعاً',
        status: KdsTicketStatus.readyForPickup,
        timePlaced: DateTime.now().subtract(const Duration(minutes: 14)),
        prepTimeMinutes: 10,
        totalAmountLyd: 38.00,
        paymentMethod: 'محفظة واصل',
        courierName: 'كابتن طارق النالوتي',
        courierVehicle: 'هيونداي فيرنا',
        courierPhone: '091-5554433',
        items: [
          KdsOrderItem(name: 'بانادول إكسترا أحمر أقراص 500 ملغ (24 قرص)', quantity: 2, priceLyd: 8.50, isCollected: true),
          KdsOrderItem(name: 'فيتامين سي فوار 1000 ملغ بطعم البرتقال', quantity: 1, priceLyd: 11.00, isCollected: true),
          KdsOrderItem(name: 'محلول تعقيم وغسيل عدسات 360 مل', quantity: 1, priceLyd: 10.00, isCollected: true),
        ],
      ),
    ];
  }

}
