import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_admin_app/screens/orders_tab.dart';
import 'package:wasel_admin_app/services/admin_supabase_service.dart';
import 'package:wasel_admin_app/theme/admin_theme.dart';

void main() {
  group('M2 Admin Orders Control & UI Enhancement Suite', () {
    test('AdminSupabaseService has all required order control endpoints defined', () {
      expect(AdminSupabaseService.backendHeaders, containsPair('Content-Type', 'application/json'));
      // Verify methods are callable functions
      expect(AdminSupabaseService.updateOrderStatus, isA<Function>());
      expect(AdminSupabaseService.cancelOrder, isA<Function>());
      expect(AdminSupabaseService.reassignOrder, isA<Function>());
      expect(AdminSupabaseService.deleteOrder, isA<Function>());
      expect(AdminSupabaseService.purgeOrders, isA<Function>());
    });

    testWidgets('OrdersTab renders AppBar purge action and all 7 filter chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.darkTheme,
          home: const OrdersTab(),
        ),
      );

      // Verify AppBar Title
      expect(find.text('رادار الطلبات الحية في نالوت'), findsOneWidget);

      // Verify F10: AppBar Purge Action button
      expect(find.text('تصفير كافة الطلبات'), findsOneWidget);
      expect(find.text('🧹'), findsOneWidget);

      // Verify F11: All 7 Filter Chips
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('طلب جديد'), findsOneWidget);
      expect(find.text('قيد التجهيز'), findsOneWidget);
      expect(find.text('جاهز للاستلام 📦'), findsOneWidget);
      expect(find.text('في الطريق'), findsOneWidget);
      expect(find.text('تم التسليم'), findsOneWidget);
      expect(find.text('ملغي ❌'), findsOneWidget);
    });

    testWidgets('Tapping Purge Orders button opens PIN confirmation dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.darkTheme,
          home: const OrdersTab(),
        ),
      );

      // Tap the Purge Orders AppBar button
      await tester.tap(find.text('تصفير كافة الطلبات'));
      await tester.pumpAndSettle();

      // Verify Purge Dialog opens with safety notice
      expect(find.text('تصفير كافة الطلبات 🧹'), findsOneWidget);
      expect(find.textContaining('تنبيه إداري صارم'), findsOneWidget);
      expect(find.textContaining('المتاجر المعتمدة، قوائم المنتجات والتصنيفات'), findsOneWidget);
      expect(find.text('أدخل رمز الأمان الإداري (PIN):'), findsOneWidget);
      expect(find.text('تأكيد التصفير 🧹'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('تأكيد التصفير 🧹'), findsNothing);
    });
  });
}
