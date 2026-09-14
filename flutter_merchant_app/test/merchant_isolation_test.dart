import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_merchant_app/merchant_models.dart';
import 'package:wasel_merchant_app/merchant_login_screen.dart';
import 'package:wasel_merchant_app/services/merchant_supabase_service.dart';
import 'package:wasel_merchant_app/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Wasel Merchant App — Multi-Tenant Isolation & Workflows Suite', () {
    // -------------------------------------------------------------------------
    // 1. Authentication & Store Isolation
    // -------------------------------------------------------------------------
    test('1.1: Valid merchant credentials authenticate and isolate to Ranchello Restaurant', () async {
      final user = await MerchantSupabaseService.authenticateMerchant('0919570011', '1234');
      expect(user, isNotNull);
      expect(user!.storeId, equals('store_nalut_ranchello'));
      expect(user.name, contains('رانشيلو'));
      expect(MerchantSupabaseService.currentStoreId, equals('store_nalut_ranchello'));
    });

    test('1.2: Valid merchant credentials authenticate and isolate to Rixos Shopping Market', () async {
      final user = await MerchantSupabaseService.authenticateMerchant('0910000002', '1234');
      expect(user, isNotNull);
      expect(user!.storeId, equals('store_nalut_rixos'));
      expect(user.name, contains('ريكسوس'));
      expect(MerchantSupabaseService.currentStoreId, equals('store_nalut_rixos'));
    });

    test('1.3: Incorrect PIN rejects authentication', () async {
      final user = await MerchantSupabaseService.authenticateMerchant('0919570011', '0000');
      expect(user, isNull);
    });

    test('1.4: Dynamic Libyan mobile login with default PIN succeeds', () async {
      final user = await MerchantSupabaseService.authenticateMerchant('0912345678', '1234');
      expect(user, isNotNull);
      expect(user!.phone, equals('0912345678'));
    });

    // -------------------------------------------------------------------------
    // 2. Receipts & Financial Settlements Workflow (الواصلات)
    // -------------------------------------------------------------------------
    test('2.1: Store receipts calculate net merchant earnings and order breakdown correctly', () async {
      final receipts = await MerchantSupabaseService.fetchStoreReceipts('store_nalut_ranchello');
      expect(receipts, isNotEmpty);

      final r = receipts.first;
      expect(r.receiptNumber, startsWith('RCP-NAL'));
      expect(r.subtotalLyd, greaterThan(0));
      expect(r.netMerchantLyd, lessThanOrEqualTo(r.subtotalLyd));
      expect(r.items, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 3. Inventory & Stock-Taking Workflow (الجرد)
    // -------------------------------------------------------------------------
    test('3.1: CatalogProduct detects low stock threshold correctly', () {
      final normalItem = CatalogProduct(
        id: 'item_1',
        nameAr: 'شاورما دبل',
        category: 'سندوتشات',
        priceLyd: 18.00,
        inStock: true,
        stockQuantity: 20,
        minStockAlert: 5,
        descAr: 'شاورما طازجة',
      );
      expect(normalItem.isLowStock, isFalse);

      final lowStockItem = CatalogProduct(
        id: 'item_2',
        nameAr: 'كباب صحن',
        category: 'مشويات',
        priceLyd: 24.00,
        inStock: true,
        stockQuantity: 3,
        minStockAlert: 5,
        descAr: 'كباب لحم وطني',
      );
      expect(lowStockItem.isLowStock, isTrue);
    });

    test('3.2: Updating inventory quantity synchronizes stock status', () async {
      final result = await MerchantSupabaseService.updateInventoryStock('prod_ranchello_box_big', 0);
      expect(result, isTrue);
    });

    // -------------------------------------------------------------------------
    // 4. UI Widget Handshake: Login Screen & 1-Click Fill
    // -------------------------------------------------------------------------
    testWidgets('4.1: MerchantLoginScreen displays inputs and 1-click store shortcuts', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      MerchantUser? loggedUser;
      PartnerStore? loggedStore;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MerchantLoginScreen(
            onLoginSuccess: (user, store) {
              loggedUser = user;
              loggedStore = store;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and form inputs
      expect(find.text('شريك واصل | نالوت'), findsOneWidget);
      expect(find.text('تسجيل الدخول للمتجر'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Phone & PIN

      // Verify quick shortcuts exist
      final ranchelloChip = find.text('مطعم رانشيلو 🌯');
      expect(ranchelloChip, findsOneWidget);

      // Tap 1-click shortcut for Ranchello
      await tester.tap(ranchelloChip);
      await tester.pumpAndSettle();

      // Tap login button
      final loginBtn = find.text('دخول المتجر والمطبخ');
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Verify session logged in
      expect(loggedUser, isNotNull);
      expect(loggedUser!.storeId, equals('store_nalut_ranchello'));
      expect(loggedStore, isNotNull);
      expect(loggedStore!.name, contains('رانشيلو'));
    });

    testWidgets('4.2: WaselMerchantApp launches with AuthGate', (WidgetTester tester) async {
      await tester.pumpWidget(const WaselMerchantApp());
      await tester.pumpAndSettle();

      expect(find.byType(MerchantAuthGate), findsOneWidget);
      // Since no session saved yet, it shows login screen
      expect(find.byType(MerchantLoginScreen), findsOneWidget);
    });
  });
}
