import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_customer_app/services/cart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CartService.clear();
  });

  group('CartService Persistence Tests (002-app-lifecycle-persistence)', () {
    test('CartItem serializes and deserializes correctly', () {
      final item = CartItem(
        id: 'prod_nalut_pizza_01',
        title: 'بيتزا جبلية مخصوصة',
        storeName: 'مطعم رانشيلو نالوت',
        price: 28.5,
        quantity: 2,
        selectedAddons: ['جبنة موزاريلا إضافية', 'زيتون جبلي'],
        image: 'https://images.unsplash.com/photo-pizza',
        notes: 'بدون شطة',
        spiceLevel: 'بارد',
        exclusions: ['بصل'],
      );

      final json = item.toJson();
      expect(json['id'], 'prod_nalut_pizza_01');
      expect(json['title'], 'بيتزا جبلية مخصوصة');
      expect(json['price'], 28.5);
      expect(json['quantity'], 2);
      expect(json['selectedAddons'], contains('زيتون جبلي'));

      final restored = CartItem.fromJson(json);
      expect(restored.id, 'prod_nalut_pizza_01');
      expect(restored.total, 57.0);
      expect(restored.exclusions, contains('بصل'));
    });

    test('CartService persists items to local storage and reloads upon reboot simulation', () async {
      final item1 = CartItem(
        id: 'item_1',
        title: 'وجبة قلاية نالوتية',
        storeName: 'قصر نالوت',
        price: 25.0,
        quantity: 1,
      );

      final item2 = CartItem(
        id: 'item_2',
        title: 'عصير ليمون بالنعناع',
        storeName: 'قصر نالوت',
        price: 5.0,
        quantity: 2,
      );

      CartService.addItem(item1);
      CartService.addItem(item2);
      expect(CartService.count, 3);
      expect(CartService.subtotal, 35.0);

      // Verify that data was written to mock SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedString = prefs.getString('wasel_customer_cart_v1');
      expect(storedString, isNotNull);
      expect(storedString, contains('وجبة قلاية نالوتية'));

      // Simulate app restart / RAM purge
      CartService.items.clear();
      expect(CartService.count, 0);

      // Reload from storage
      await CartService.loadFromStorage();
      expect(CartService.count, 3);
      expect(CartService.subtotal, 35.0);
      expect(CartService.storeName, 'قصر نالوت');
    });
  });
}
