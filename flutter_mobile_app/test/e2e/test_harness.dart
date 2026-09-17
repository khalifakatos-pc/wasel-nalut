// ignore_for_file: use_null_aware_elements
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_customer_app/design_system.dart';
import 'package:wasel_customer_app/services/api_service.dart';
import 'package:wasel_customer_app/cart_checkout_screen.dart';

/// Central Test Harness for Wasel E2E Test Suite (Tiers 1-4)
class TestHarness {
  static bool _httpOverridesInstalled = false;

  /// Installs zero-latency, hermetic HTTP mock overrides to eliminate network calls and DNS queries.
  static void installMockHttpOverrides() {
    if (!_httpOverridesInstalled) {
      HttpOverrides.global = MockHttpOverrides();
      _httpOverridesInstalled = true;
    }
  }

  /// Initializes hermetic mock environment for SharedPreferences and ApiService.
  static Future<void> setupMockEnvironment({
    bool isGuest = true,
    String? phone,
    String? name,
    String? token,
    int loyaltyPoints = 140,
    String? activeOrderId,
  }) async {
    installMockHttpOverrides();
    SharedPreferences.setMockInitialValues({
      'is_guest': isGuest,
      if (phone != null) 'user_phone': phone,
      if (name != null) 'user_name': name,
      if (token != null) 'auth_token': token,
      'wasel_loyalty_points': loyaltyPoints,
      'wasel_user_vouchers': '[]',
      'wasel_invited_friends': '[]',
      if (activeOrderId != null) 'active_order_id': activeOrderId,
      'wasel_referral_code': 'WAS-TEST-REFERRAL',
    });
    await ApiService.loadToken();
  }

  /// Builds a complete MaterialApp test harness configured with Arabic RTL localizations.
  static Widget buildTestApp({
    required Widget home,
    ThemeMode themeMode = ThemeMode.light,
    NavigatorObserver? navigatorObserver,
  }) {
    return MaterialApp(
      title: 'واصل نالوت - Test Harness',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [
        if (navigatorObserver != null) navigatorObserver,
      ],
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: home,
      ),
    );
  }

  /// Helper to generate sample CartItem for testing Cart & Checkout.
  static CartItem createSampleCartItem({
    String id = 'item_01',
    String title = 'صحن مشكل كباب وشقف لحم وطني',
    String storeName = 'مطعم قصر نالوت للمشويات',
    double price = 34.00,
    int quantity = 1,
    List<String> selectedAddons = const ['صلصة ثومية ليبية حارة (+1.50 د.ل)'],
  }) {
    return CartItem(
      id: id,
      title: title,
      storeName: storeName,
      price: price,
      quantity: quantity,
      selectedAddons: selectedAddons,
    );
  }
}

// ============================================================================
// ZERO-LATENCY HERMETIC HTTP OVERRIDES FOR E2E TESTING
// ============================================================================
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout = const Duration(milliseconds: 10);
  @override
  Duration idleTimeout = const Duration(seconds: 5);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  void addAuthentication(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest(url);
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

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  _MockHttpClientRequest(this.uri);

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
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  void write(Object? obj) {}
  @override
  void writeAll(Iterable objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? obj = '']) {}
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  Future<void> flush() async {}

  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];
  @override
  Future<HttpClientResponse> get done => Future.value(_MockHttpClientResponse(uri));
  @override
  String get method => 'GET';

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse(uri);
  }
}

class _MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }

  @override
  List<String>? operator [](String name) => _headers[name];
  @override
  String? value(String name) => _headers[name]?.first;
  @override
  void remove(String name, Object value) => _headers[name]?.remove(value.toString());
  @override
  void removeAll(String name) => _headers.remove(name);
  @override
  void forEach(void Function(String name, List<String> values) action) => _headers.forEach(action);
  @override
  void noFolding(String name) {}

  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  ContentType? contentType;
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
  void clear() => _headers.clear();
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final Uri uri;
  _MockHttpClientResponse(this.uri);

  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  int get contentLength => -1;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  HttpHeaders get headers => _MockHttpHeaders()..set('content-type', 'application/json');
  @override
  List<Cookie> get cookies => [];
  @override
  Future<Socket> detachSocket() => throw UnimplementedError();
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  bool get persistentConnection => true;
  @override
  X509Certificate? get certificate => null;
  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) async => this;

  static const List<int> transparentPng = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final bool isImage = uri.path.endsWith('.png') ||
        uri.path.endsWith('.jpg') ||
        uri.host.contains('openstreetmap') ||
        uri.host.contains('unsplash');

    final List<int> bytes = isImage ? transparentPng : utf8.encode(_buildMockResponseBody(uri));
    if (isImage) {
      headers.set('content-type', 'image/png');
    }
    return Stream.value(bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  String _buildMockResponseBody(Uri uri) {
    final path = uri.path;
    if (path.contains('/orders')) {
      return jsonEncode({
        'success': true,
        'data': {
          'id': 'ord_mock_123',
          'order_number': 'WAS-9988',
          'status': 'placed',
          'store_name': 'مطعم قصر نالوت للمشويات',
          'total_amount_lyd': 42.0,
          'otp_code': '4821',
          'delivery_address': 'نالوت - حي القلعة',
          'delivery_latitude': 31.8687,
          'delivery_longitude': 10.9818,
          'driver_id': 'drv_01',
          'driver': {
            'full_name': 'كابتن طارق النالوتي',
            'phone': '0915544332',
            'vehicle_model': 'تويوتا يارس',
            'plate_number': '14-88492',
            'rating': 4.9,
          }
        }
      });
    }
    return jsonEncode({'success': true, 'data': []});
  }
}
