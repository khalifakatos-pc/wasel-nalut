import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_admin_app/services/admin_supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late HttpServer mockServer;
  late String originalBaseUrl;

  // Recorded request telemetry
  String? recordedMethod;
  Uri? recordedUri;
  Map<String, String>? recordedHeaders;
  dynamic recordedBody;

  // Mock server response configuration
  int mockStatusCode = 200;
  String mockResponseBody = jsonEncode({'success': true, 'message': 'OK'});
  bool mockDestroySocket = false;

  setUp(() async {
    originalBaseUrl = AdminSupabaseService.backendBaseUrl;

    // Reset telemetry
    recordedMethod = null;
    recordedUri = null;
    recordedHeaders = null;
    recordedBody = null;
    mockStatusCode = 200;
    mockResponseBody = jsonEncode({'success': true, 'message': 'OK'});
    mockDestroySocket = false;

    // Spin up local ephemeral loopback HTTP server strictly on 127.0.0.1
    mockServer = await HttpServer.bind(InternetAddress('127.0.0.1'), 0);
    mockServer.listen((HttpRequest request) async {
      recordedMethod = request.method;
      recordedUri = request.uri;
      recordedHeaders = {};
      request.headers.forEach((name, values) {
        recordedHeaders![name.toLowerCase()] = values.join(', ');
      });

      final bodyBytes = await request.fold<List<int>>([], (prev, element) => prev..addAll(element));
      final bodyString = utf8.decode(bodyBytes);
      if (bodyString.isNotEmpty) {
        try {
          recordedBody = jsonDecode(bodyString);
        } catch (_) {
          recordedBody = bodyString;
        }
      } else {
        recordedBody = null;
      }

      if (mockDestroySocket) {
        final socket = await request.response.detachSocket();
        socket.destroy();
        return;
      }

      request.response.statusCode = mockStatusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(mockResponseBody);
      await request.response.close();
    });

    // Point AdminSupabaseService strictly to 127.0.0.1 to avoid IPv6/localhost resolution latency
    AdminSupabaseService.backendBaseUrl = 'http://127.0.0.1:${mockServer.port}/api/v1';

    // Set default authenticated session
    SharedPreferences.setMockInitialValues({'wasel_admin_jwt': 'test_admin_jwt_token_9988'});
    await AdminSupabaseService.restoreSession();
  });

  tearDown(() async {
    AdminSupabaseService.backendBaseUrl = originalBaseUrl;
    await mockServer.close(force: true);
    await AdminSupabaseService.logout();
  });

  group('Adversarial Contract & Signature Challenge', () {
    test('1.1 Method signatures and tear-offs adhere strictly to API contracts', () {
      expect(AdminSupabaseService.updateOrderStatus, isA<Future<bool> Function(String, String)>());
      expect(AdminSupabaseService.cancelOrder, isA<Function>());
      expect(AdminSupabaseService.reassignOrder, isA<Future<bool> Function(String, String)>());
      expect(AdminSupabaseService.deleteOrder, isA<Future<bool> Function(String)>());
      expect(AdminSupabaseService.purgeOrders, isA<Future<Map<String, dynamic>> Function(String)>());
    });
  });

  group('Adversarial Payload & Header Inspection', () {
    test('2.1 updateOrderStatus sends POST, adminOverride: true, and Bearer token', () async {
      final success = await AdminSupabaseService.updateOrderStatus('ORD-8812', 'out_for_delivery');

      expect(success, isTrue);
      expect(recordedMethod, equals('POST'));
      expect(recordedUri?.path, equals('/api/v1/orders/ORD-8812/status'));
      expect(recordedHeaders?['authorization'], equals('Bearer test_admin_jwt_token_9988'));
      expect(recordedHeaders?['content-type'], contains('application/json'));
      expect(recordedBody, isA<Map<String, dynamic>>());
      expect(recordedBody['status'], equals('out_for_delivery'));
      expect(recordedBody['adminOverride'], isTrue);
    });

    test('2.2 cancelOrder sends POST, adminOverride: true, reason, and Bearer token', () async {
      final success = await AdminSupabaseService.cancelOrder('ORD-5544', reason: 'الزبون غير متاح في الموقع');

      expect(success, isTrue);
      expect(recordedMethod, equals('POST'));
      expect(recordedUri?.path, equals('/api/v1/orders/ORD-5544/cancel'));
      expect(recordedHeaders?['authorization'], equals('Bearer test_admin_jwt_token_9988'));
      expect(recordedHeaders?['content-type'], contains('application/json'));
      expect(recordedBody, isA<Map<String, dynamic>>());
      expect(recordedBody['reason'], equals('الزبون غير متاح في الموقع'));
      expect(recordedBody['adminOverride'], isTrue);
    });

    test('2.3 cancelOrder handles null or empty reason cleanly without crashing', () async {
      final success = await AdminSupabaseService.cancelOrder('ORD-5545', reason: null);

      expect(success, isTrue);
      expect(recordedMethod, equals('POST'));
      expect(recordedUri?.path, equals('/api/v1/orders/ORD-5545/cancel'));
      expect(recordedBody, isA<Map<String, dynamic>>());
      expect(recordedBody.containsKey('reason'), isFalse);
      expect(recordedBody['adminOverride'], isTrue);
    });

    test('2.4 reassignOrder sends POST, driver_id, and Bearer token', () async {
      final success = await AdminSupabaseService.reassignOrder('ORD-1029', 'driver_nalut_04');

      expect(success, isTrue);
      expect(recordedMethod, equals('POST'));
      expect(recordedUri?.path, equals('/api/v1/orders/ORD-1029/reassign'));
      expect(recordedHeaders?['authorization'], equals('Bearer test_admin_jwt_token_9988'));
      expect(recordedHeaders?['content-type'], contains('application/json'));
      expect(recordedBody, isA<Map<String, dynamic>>());
      expect(recordedBody['driver_id'], equals('driver_nalut_04'));
    });

    test('2.5 deleteOrder sends DELETE method to /api/v1/admin/orders/:id with Bearer token', () async {
      mockStatusCode = 204;
      final success = await AdminSupabaseService.deleteOrder('ORD-7777');

      expect(success, isTrue);
      expect(recordedMethod, equals('DELETE'));
      expect(recordedUri?.path, equals('/api/v1/admin/orders/ORD-7777'));
      expect(recordedHeaders?['authorization'], equals('Bearer test_admin_jwt_token_9988'));
      expect(recordedBody, isNull);
    });

    test('2.6 purgeOrders sends POST to /api/v1/admin/orders/purge with pin and Bearer token', () async {
      mockResponseBody = jsonEncode({
        'success': true,
        'message': 'تم تصفير كافة الطلبات وسجل الحركات بنجاح مع الحفاظ على المتاجر والمنتجات والكباتن',
      });

      final result = await AdminSupabaseService.purgeOrders('7788');

      expect(result['success'], isTrue);
      expect(result['message'], contains('تم تصفير كافة الطلبات'));
      expect(recordedMethod, equals('POST'));
      expect(recordedUri?.path, equals('/api/v1/admin/orders/purge'));
      expect(recordedHeaders?['authorization'], equals('Bearer test_admin_jwt_token_9988'));
      expect(recordedHeaders?['content-type'], contains('application/json'));
      expect(recordedBody, isA<Map<String, dynamic>>());
      expect(recordedBody['pin'], equals('7788'));
    });

    test('2.7 Unauthenticated state omits Authorization header while preserving Content-Type', () async {
      await AdminSupabaseService.logout();

      expect(AdminSupabaseService.isAuthenticated, isFalse);
      expect(AdminSupabaseService.jwtToken, isNull);
      expect(AdminSupabaseService.backendHeaders.containsKey('Authorization'), isFalse);
      expect(AdminSupabaseService.backendHeaders['Content-Type'], equals('application/json'));

      final success = await AdminSupabaseService.updateOrderStatus('ORD-UNAUTH', 'preparing');
      expect(success, isTrue);
      expect(recordedHeaders?.containsKey('authorization'), isFalse);
      expect(recordedHeaders?['content-type'], contains('application/json'));
    });
  });

  group('Adversarial HTTP Status Codes & Error Handling', () {
    test('3.1 400 Bad Request returns false/failure without crashing isolate', () async {
      mockStatusCode = 400;
      mockResponseBody = jsonEncode({'success': false, 'error': 'Invalid state transition'});

      expect(await AdminSupabaseService.updateOrderStatus('ORD-ERR', 'invalid_state'), isFalse);
      expect(await AdminSupabaseService.cancelOrder('ORD-ERR'), isFalse);
      expect(await AdminSupabaseService.reassignOrder('ORD-ERR', 'bad_driver'), isFalse);
      expect(await AdminSupabaseService.deleteOrder('ORD-ERR'), isFalse);

      final purgeResult = await AdminSupabaseService.purgeOrders('0000');
      expect(purgeResult['success'], isFalse);
      expect(purgeResult['message'], contains('Invalid state transition'));
    });

    test('3.2 401 Unauthorized returns false/failure with proper error extraction', () async {
      mockStatusCode = 401;
      mockResponseBody = jsonEncode({'success': false, 'error': 'رمز الأمان PIN مطلوب وغير صحيح'});

      expect(await AdminSupabaseService.updateOrderStatus('ORD-ERR', 'preparing'), isFalse);
      expect(await AdminSupabaseService.cancelOrder('ORD-ERR'), isFalse);
      expect(await AdminSupabaseService.reassignOrder('ORD-ERR', 'DRV-1'), isFalse);
      expect(await AdminSupabaseService.deleteOrder('ORD-ERR'), isFalse);

      final purgeResult = await AdminSupabaseService.purgeOrders('wrong_pin');
      expect(purgeResult['success'], isFalse);
      expect(purgeResult['message'], equals('رمز الأمان PIN مطلوب وغير صحيح'));
    });

    test('3.3 403 Forbidden returns false/failure without unhandled exceptions', () async {
      mockStatusCode = 403;
      mockResponseBody = jsonEncode({'success': false, 'error': 'Access denied: Admin role required'});

      expect(await AdminSupabaseService.updateOrderStatus('ORD-ERR', 'preparing'), isFalse);
      expect(await AdminSupabaseService.cancelOrder('ORD-ERR'), isFalse);
      expect(await AdminSupabaseService.reassignOrder('ORD-ERR', 'DRV-1'), isFalse);
      expect(await AdminSupabaseService.deleteOrder('ORD-ERR'), isFalse);

      final purgeResult = await AdminSupabaseService.purgeOrders('7788');
      expect(purgeResult['success'], isFalse);
      expect(purgeResult['message'], equals('Access denied: Admin role required'));
    });

    test('3.4 404 Not Found returns false/failure for non-existent orders', () async {
      mockStatusCode = 404;
      mockResponseBody = jsonEncode({'success': false, 'error': 'Order not found'});

      expect(await AdminSupabaseService.updateOrderStatus('ORD-404', 'preparing'), isFalse);
      expect(await AdminSupabaseService.cancelOrder('ORD-404'), isFalse);
      expect(await AdminSupabaseService.reassignOrder('ORD-404', 'DRV-1'), isFalse);
      expect(await AdminSupabaseService.deleteOrder('ORD-404'), isFalse);
    });

    test('3.5 500 Internal Server Error degrades gracefully', () async {
      mockStatusCode = 500;
      mockResponseBody = jsonEncode({'success': false, 'error': 'Database transaction failure'});

      expect(await AdminSupabaseService.updateOrderStatus('ORD-500', 'delivered'), isFalse);
      expect(await AdminSupabaseService.cancelOrder('ORD-500'), isFalse);
      expect(await AdminSupabaseService.reassignOrder('ORD-500', 'DRV-1'), isFalse);
      expect(await AdminSupabaseService.deleteOrder('ORD-500'), isFalse);

      final purgeResult = await AdminSupabaseService.purgeOrders('7788');
      expect(purgeResult['success'], isFalse);
      expect(purgeResult['message'], equals('Database transaction failure'));
    });
  });

  group('Adversarial Resilience to Network & Data Corruption', () {
    test('4.1 Server returning HTML/corrupted non-JSON body is handled safely', () async {
      mockStatusCode = 502;
      mockResponseBody = '<html><body><h1>502 Bad Gateway</h1><p>Nginx reverse proxy failure</p></body></html>';

      expect(await AdminSupabaseService.updateOrderStatus('ORD-CORRUPT', 'preparing'), isFalse);
      expect(await AdminSupabaseService.cancelOrder('ORD-CORRUPT'), isFalse);
      expect(await AdminSupabaseService.reassignOrder('ORD-CORRUPT', 'DRV-1'), isFalse);
      expect(await AdminSupabaseService.deleteOrder('ORD-CORRUPT'), isFalse);

      // purgeOrders attempts jsonDecode which throws FormatException, caught gracefully in try-catch
      final purgeResult = await AdminSupabaseService.purgeOrders('7788');
      expect(purgeResult['success'], isFalse);
      expect(purgeResult['message'], contains('خطأ في الاتصال بالخادم'));
    });

    test('4.2 Abrupt socket destruction is caught gracefully', () async {
      mockDestroySocket = true;

      expect(await AdminSupabaseService.updateOrderStatus('ORD-DROP', 'preparing'), isFalse);
      expect(await AdminSupabaseService.cancelOrder('ORD-DROP'), isFalse);
      expect(await AdminSupabaseService.reassignOrder('ORD-DROP', 'DRV-1'), isFalse);
      expect(await AdminSupabaseService.deleteOrder('ORD-DROP'), isFalse);

      final purgeResult = await AdminSupabaseService.purgeOrders('7788');
      expect(purgeResult['success'], isFalse);
      expect(purgeResult['message'], anyOf(contains('خطأ في الاتصال بالخادم'), contains('تعذر الاتصال')));
    });

    test('4.3 Unreachable host/offline port fails gracefully without crashing isolate', () async {
      // Point to an unallocated loopback port
      AdminSupabaseService.backendBaseUrl = 'http://127.0.0.1:59999/api/v1';

      expect(await AdminSupabaseService.updateOrderStatus('ORD-OFFLINE', 'preparing'), isFalse);
      expect(await AdminSupabaseService.cancelOrder('ORD-OFFLINE'), isFalse);
      expect(await AdminSupabaseService.reassignOrder('ORD-OFFLINE', 'DRV-1'), isFalse);
      expect(await AdminSupabaseService.deleteOrder('ORD-OFFLINE'), isFalse);

      final purgeResult = await AdminSupabaseService.purgeOrders('7788');
      expect(purgeResult['success'], isFalse);
      expect(purgeResult['message'], anyOf(contains('خطأ في الاتصال بالخادم'), contains('تعذر الاتصال')));
    });
  });
}
