import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_customer_app/services/cart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CartService.clear();
  });

  group('Cart Calculation and Multi-Item Tests', () {
    test('Single item calculations are exact', () {
      final item = CartItem(
        id: 'shawarma_01',
        title: 'شاورما دجاج نالوتية',
        storeName: 'مطعم القلعة',
        price: 12.50,
        quantity: 1,
      );

      CartService.addItem(item);

      expect(CartService.count, 1);
      expect(CartService.subtotal, 12.50);
      expect(CartService.items.first.total, 12.50);
      expect(CartService.items.first.priceCalculationText, '1 × 12.50 = 12.50 د.ل');
    });

    test('Adding multiple pieces of an item calculates exact subtotal without squaring/doubling', () {
      // Simulating adding 3 pieces of a 10.00 LYD meal
      final item = CartItem(
        id: 'burger_01',
        title: 'برغر لحم بلدي',
        storeName: 'مطعم الجبل',
        price: 10.00, // Unit price
        quantity: 3,
      );

      CartService.addItem(item);

      // Verify item total is 30.00 LYD, NOT 90.00 LYD (which occurred when totalPrice was passed as unit price)
      expect(CartService.count, 3);
      expect(CartService.items.first.total, 30.00);
      expect(CartService.subtotal, 30.00);
      expect(CartService.items.first.priceCalculationText, '3 × 10.00 = 30.00 د.ل');
    });

    test('Adding identical item with identical customizations increments quantity and recalculates correctly', () {
      final item1 = CartItem(
        id: 'pizza_01',
        title: 'بيتزا مارجريتا',
        storeName: 'بيتزا نالوت',
        price: 18.00,
        quantity: 2,
        selectedAddons: ['جبنة إضافية'],
        notes: 'حارة قليلاً',
      );

      CartService.addItem(item1);
      expect(CartService.count, 2);
      expect(CartService.subtotal, 36.00);

      // Add 1 more of the EXACT same item
      final item2 = CartItem(
        id: 'pizza_01',
        title: 'بيتزا مارجريتا',
        storeName: 'بيتزا نالوت',
        price: 18.00,
        quantity: 1,
        selectedAddons: ['جبنة إضافية'],
        notes: 'حارة قليلاً',
      );

      CartService.addItem(item2);

      // Should be merged into 1 entry with quantity = 3
      expect(CartService.items.length, 1);
      expect(CartService.count, 3);
      expect(CartService.items.first.quantity, 3);
      expect(CartService.items.first.total, 54.00);
      expect(CartService.subtotal, 54.00);
    });

    test('Adding same item with different notes or customizations keeps them as separate distinct lines', () {
      final item1 = CartItem(
        id: 'shawarma_01',
        title: 'شاورما عربي',
        storeName: 'مطعم القلعة',
        price: 14.00,
        quantity: 1,
        notes: 'بدون بصل',
      );

      final item2 = CartItem(
        id: 'shawarma_01',
        title: 'شاورما عربي',
        storeName: 'مطعم القلعة',
        price: 14.00,
        quantity: 2,
        notes: 'زيادة ثومية وشطة',
      );

      CartService.addItem(item1);
      CartService.addItem(item2);

      // Must NOT merge: they have distinct notes/customizations for the kitchen
      expect(CartService.items.length, 2);
      expect(CartService.count, 3);
      expect(CartService.items[0].quantity, 1);
      expect(CartService.items[0].total, 14.00);
      expect(CartService.items[0].notes, 'بدون بصل');

      expect(CartService.items[1].quantity, 2);
      expect(CartService.items[1].total, 28.00);
      expect(CartService.items[1].notes, 'زيادة ثومية وشطة');

      expect(CartService.subtotal, 42.00);
    });

    test('Incrementing and decrementing items updates quantities and totals smoothly', () {
      final item = CartItem(
        id: 'coffee_01',
        title: 'قهوة اسبريسو',
        storeName: 'كافيه نالوت',
        price: 4.50,
        quantity: 1,
      );

      CartService.addItem(item);
      expect(CartService.subtotal, 4.50);

      // Increment twice
      CartService.incrementItem(0);
      expect(CartService.count, 2);
      expect(CartService.subtotal, 9.00);

      CartService.incrementItem(0);
      expect(CartService.count, 3);
      expect(CartService.subtotal, 13.50);

      // Decrement once
      CartService.decrementItem(0);
      expect(CartService.count, 2);
      expect(CartService.subtotal, 9.00);

      // Decrement twice (should remove item)
      CartService.decrementItem(0);
      expect(CartService.count, 1);
      expect(CartService.subtotal, 4.50);

      CartService.decrementItem(0);
      expect(CartService.count, 0);
      expect(CartService.subtotal, 0.00);
      expect(CartService.items.isEmpty, isTrue);
    });
  });
}
