import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_merchant_app/merchant_models.dart';
import 'package:wasel_merchant_app/merchant_login_screen.dart';
import 'package:wasel_merchant_app/merchant_inventory_screen.dart';
import 'package:wasel_merchant_app/services/merchant_supabase_service.dart';
import 'package:wasel_merchant_app/main.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _MerchantTestHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Wasel Merchant App — Multi-Tenant Isolation & Workflows Suite', () {
    // -------------------------------------------------------------------------
    // 1. Authentication & Store Isolation
    // -------------------------------------------------------------------------
    test('1.1: Authentic merchant credentials authenticate and isolate to Ranchello Restaurant', () async {
      final user = await MerchantSupabaseService.authenticateMerchant('0919570011', '4821');
      expect(user, isNotNull);
      expect(user!.storeId, equals('store_nalut_ranchello'));
      expect(user.name, contains('رانشيلو'));
      expect(MerchantSupabaseService.currentStoreId, equals('store_nalut_ranchello'));
    });

    test('1.2: Authentic merchant credentials authenticate and isolate to Rixos Shopping Market', () async {
      final user = await MerchantSupabaseService.authenticateMerchant('0910000002', '8540');
      expect(user, isNotNull);
      expect(user!.storeId, equals('store_nalut_rixos'));
      expect(user.name, contains('ريكسوس'));
      expect(MerchantSupabaseService.currentStoreId, equals('store_nalut_rixos'));
    });

    test('1.3: Incorrect PIN rejects authentication', () async {
      final user = await MerchantSupabaseService.authenticateMerchant('0919570011', '0000');
      expect(user, isNull);
    });

    test('1.4: Purged backdoor PIN 1234 is strictly rejected on merchant login', () async {
      final user = await MerchantSupabaseService.authenticateMerchant('0919570011', '1234');
      expect(user, isNull);
    });

    test('1.5: International Libyan mobile number (+218) authenticates with valid merchant PIN', () async {
      final user = await MerchantSupabaseService.authenticateMerchant('+218-91-9570011', '4821');
      expect(user, isNotNull);
      expect(user!.storeId, equals('store_nalut_ranchello'));
    });

    // -------------------------------------------------------------------------
    // 2. Receipts & Financial Settlements Workflow (الواصلات)
    // -------------------------------------------------------------------------
    test('2.1: Store receipts calculate net merchant earnings and order breakdown correctly', () async {
      final receipts = await MerchantSupabaseService.fetchStoreReceipts('store_nalut_ranchello');
      expect(receipts, isNotEmpty);

      final r = receipts.first;
      expect(r.receiptNumber, startsWith('REC-'));
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

    test('3.2: Updating inventory quantity synchronizes stock status when server succeeds', () async {
      final result = await MerchantSupabaseService.updateInventoryStock('prod_ranchello_plate_kebab', 0);
      expect(result, isTrue);
    });

    test('3.3: Failed cloud stock update returns false and does not swallow error', () async {
      final result = await MerchantSupabaseService.updateInventoryStock('fail_network_err', 0);
      expect(result, isFalse);
    });

    // -------------------------------------------------------------------------
    // 4. UI Widget Handshake: Login Screen & Stock Error Propagation
    // -------------------------------------------------------------------------
    testWidgets('4.1: MerchantLoginScreen authenticates via genuine phone and PIN inputs', (WidgetTester tester) async {
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

      // Enter genuine phone number and valid PIN
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '0919570011');
      await tester.enterText(textFields.last, '4821');
      await tester.pumpAndSettle();

      // Tap login button
      final loginBtn = find.text('دخول المتجر والمطبخ');
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Verify authenticated session
      expect(loggedUser, isNotNull);
      expect(loggedUser!.storeId, equals('store_nalut_ranchello'));
      expect(loggedStore, isNotNull);
      expect(loggedStore!.name, contains('رانشيلو'));
    });

    testWidgets('4.2: MerchantLoginScreen rejects invalid PIN and displays error banner', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantLoginScreen(
            onLoginSuccess: (_, __) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '0919570011');
      await tester.enterText(textFields.last, '0000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('دخول المتجر والمطبخ'));
      await tester.pumpAndSettle();

      expect(find.text('رقم الهاتف أو رمز PIN غير صحيح. يرجى التأكد وإعادة المحاولة.'), findsOneWidget);
    });

    testWidgets('4.3: MerchantInventoryScreen rolls back stock switch and displays error SnackBar on failed update', (WidgetTester tester) async {
      final product = CatalogProduct(
        id: 'prod_test_01',
        nameAr: 'شاورما لحم',
        category: 'سندوتشات',
        priceLyd: 14.0,
        inStock: true,
        stockQuantity: 15,
        descAr: 'شاورما لحم طازجة',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MerchantInventoryScreen(
              catalog: [product],
              store: PartnerStore.nalutStores.first,
              onProductUpdated: (p) async {
                // Simulate server failure
                return false;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state is inStock == true
      expect(product.inStock, isTrue);

      // Find switch widget and tap
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify state was rolled back to true
      expect(product.inStock, isTrue);

      // Verify error SnackBar was shown
      expect(find.text('❌ تعذر تحديث المخزون على الخادم - يرجى التحقق من الاتصال'), findsOneWidget);
    });

    testWidgets('4.4: WaselMerchantApp launches with AuthGate', (WidgetTester tester) async {
      await tester.pumpWidget(const WaselMerchantApp());
      await tester.pumpAndSettle();

      expect(find.byType(MerchantAuthGate), findsOneWidget);
      expect(find.byType(MerchantLoginScreen), findsOneWidget);
    });
  });
}

// ============================================================================
// ZERO-LATENCY HERMETIC HTTP OVERRIDES FOR MERCHANT APP TESTS
// ============================================================================
class _MerchantTestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MerchantMockHttpClient();
  }
}

class _MerchantMockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout = const Duration(milliseconds: 50);
  @override
  Duration idleTimeout = const Duration(seconds: 1);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addAuthentication(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MerchantMockHttpClientRequest(method, url);
  }

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) =>
      openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> get(String host, int port, String path) => open('GET', host, port, path);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => open('POST', host, port, path);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) => open('PUT', host, port, path);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => open('DELETE', host, port, path);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => open('PATCH', host, port, path);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) => open('HEAD', host, port, path);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {}
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {}
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}
  @override
  set findProxy(String Function(Uri url)? f) {}
  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) {}
  @override
  set keyLog(Function(String line)? callback) {}
}

class _MerchantMockHttpClientRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  final List<int> _bodyBytes = [];

  @override
  final HttpHeaders headers = _MerchantMockHttpHeaders();

  _MerchantMockHttpClientRequest(this.method, this.uri);

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = -1;
  @override
  Encoding encoding = utf8;
  @override
  bool bufferOutput = true;

  @override
  void add(List<int> data) => _bodyBytes.addAll(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bodyBytes.addAll(chunk);
    }
  }
  @override
  void write(Object? obj) {
    if (obj != null) _bodyBytes.addAll(utf8.encode(obj.toString()));
  }
  @override
  void writeAll(Iterable objects, [String separator = '']) {
    for (final obj in objects) {
      write(obj);
      write(separator);
    }
  }
  @override
  void writeCharCode(int charCode) => _bodyBytes.add(charCode);
  @override
  void writeln([Object? obj = '']) {
    write(obj);
    write('\n');
  }
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  Future<void> flush() async {}

  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];
  @override
  Future<HttpClientResponse> get done => close();

  @override
  Future<HttpClientResponse> close() async {
    final bodyString = utf8.decode(_bodyBytes, allowMalformed: true);
    return _dispatchResponse(method, uri, bodyString);
  }

  HttpClientResponse _dispatchResponse(String method, Uri uri, String body) {
    final path = uri.path;

    // 1. Merchant Login Handler
    if (path.contains('/auth/merchant-login')) {
      Map<String, dynamic> reqBody = {};
      try {
        reqBody = jsonDecode(body);
      } catch (_) {}
      final storeId = (reqBody['store_id'] ?? '').toString();
      final pin = (reqBody['pin'] ?? '').toString();

      final cleanDigits = storeId.replaceAll(RegExp(r'[^0-9]'), '');
      final isRanchello = pin == '4821' && (cleanDigits.endsWith('919570011') || cleanDigits.endsWith('912345002') || storeId == 'store_nalut_ranchello');
      final isRixos = pin == '8540' && (cleanDigits.endsWith('910000002') || cleanDigits.endsWith('912345004') || storeId == 'store_nalut_rixos');

      if (isRanchello) {
        return _MerchantMockHttpClientResponse(
          200,
          jsonEncode({
            'success': true,
            'data': {
              'token': 'jwt_mock_ranchello',
              'store': {
                'id': 'store_nalut_ranchello',
                'name': 'مطعم ومقهى رانشيلو',
                'name_ar': 'مطعم ومقهى رانشيلو',
                'phone': '0919570011',
                'type': 'restaurant',
                'district': 'وسط نالوت',
                'app_mode': 'kitchen',
                'is_open': true,
              },
            },
          }),
        );
      } else if (isRixos) {
        return _MerchantMockHttpClientResponse(
          200,
          jsonEncode({
            'success': true,
            'data': {
              'token': 'jwt_mock_rixos',
              'store': {
                'id': 'store_nalut_rixos',
                'name': 'ريكسوس للتسوق',
                'name_ar': 'ريكسوس للتسوق',
                'phone': '0910000002',
                'type': 'grocery',
                'district': 'المدخل الرئيسي - نالوت',
                'app_mode': 'retail',
                'is_open': true,
              },
            },
          }),
        );
      } else {
        return _MerchantMockHttpClientResponse(
          401,
          jsonEncode({'success': false, 'error': 'رقم الهاتف أو رمز PIN غير صحيح.'}),
        );
      }
    }

    // 2. Orders & Receipts
    if (path.contains('/orders')) {
      final sampleOrders = [
        {
          'id': 'ord_mock_1',
          'order_number': '#W-1044',
          'store_id': 'store_nalut_ranchello',
          'created_at': DateTime.now().toIso8601String(),
          'total_amount_lyd': 50.0,
          'subtotal_lyd': 45.0,
          'delivery_fee_lyd': 5.0,
          'payment_method': 'cash_on_delivery',
          'payment_status': 'collected',
          'customer_name': 'طارق عسكر',
          'items': [
            {
              'name_ar': 'صحن كباب مشوي',
              'quantity': 2,
              'price': 22.5,
            }
          ],
        }
      ];
      return _MerchantMockHttpClientResponse(200, jsonEncode(sampleOrders));
    }

    // 3. Products Patch (Stock update)
    if (path.contains('/products')) {
      if (path.contains('fail_network_err') || uri.toString().contains('fail_network_err')) {
        return _MerchantMockHttpClientResponse(500, jsonEncode({'success': false, 'error': 'Server error'}));
      }
      return _MerchantMockHttpClientResponse(200, jsonEncode({'success': true}));
    }

    return _MerchantMockHttpClientResponse(200, jsonEncode({'success': true}));
  }
}

class _MerchantMockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final String _responseBody;

  _MerchantMockHttpClientResponse(this.statusCode, this._responseBody);

  @override
  int get contentLength => utf8.encode(_responseBody).length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  HttpHeaders get headers => _MerchantMockHttpHeaders();
  @override
  bool get isRedirect => false;
  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Error';
  @override
  List<RedirectInfo> get redirects => [];
  @override
  List<Cookie> get cookies => [];
  @override
  X509Certificate? get certificate => null;
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  bool get persistentConnection => true;
  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) => throw UnimplementedError();
  @override
  Future<Socket> detachSocket() => throw UnimplementedError();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(_responseBody)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _MerchantMockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {
    'content-type': ['application/json; charset=utf-8'],
  };

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = [value.toString()];
  }
  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];
  @override
  String? value(String name) => _map[name.toLowerCase()]?.first;
  @override
  void remove(String name, Object value) => _map[name.toLowerCase()]?.remove(value.toString());
  @override
  void removeAll(String name) => _map.remove(name.toLowerCase());
  @override
  void forEach(void Function(String name, List<String> values) action) => _map.forEach(action);
  @override
  void noFolding(String name) {}
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  ContentType? contentType = ContentType.json;
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host;
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = true;
  @override
  int? port;
  @override
  void clear() => _map.clear();
}
