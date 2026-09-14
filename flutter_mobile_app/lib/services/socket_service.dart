import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket service for real-time GPS tracking and order status updates.
class SocketService {
  static const String defaultWsUrl = 'wss://wasel-nalut.onrender.com';
  static String wsUrl = const String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: defaultWsUrl,
  );
  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static bool _isConnected = false;
  static bool _isExplicitDisconnect = false;
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  static Timer? _reconnectTimer;
  static bool _isPassiveFallback = false;

  // Stream controllers for different event types
  static StreamController<Map<String, dynamic>> _driverLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  static StreamController<Map<String, dynamic>> _orderStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  static StreamController<Map<String, dynamic>> _proximityAlertController =
      StreamController<Map<String, dynamic>>.broadcast();

  static void _ensureControllersOpen() {
    if (_driverLocationController.isClosed) {
      _driverLocationController =
          StreamController<Map<String, dynamic>>.broadcast();
    }
    if (_orderStatusController.isClosed) {
      _orderStatusController =
          StreamController<Map<String, dynamic>>.broadcast();
    }
    if (_proximityAlertController.isClosed) {
      _proximityAlertController =
          StreamController<Map<String, dynamic>>.broadcast();
    }
  }

  /// Stream of real-time driver GPS location updates.
  static Stream<Map<String, dynamic>> get driverLocationStream {
    _ensureControllersOpen();
    return _driverLocationController.stream;
  }

  /// Stream of order status change events.
  static Stream<Map<String, dynamic>> get orderStatusStream {
    _ensureControllersOpen();
    return _orderStatusController.stream;
  }

  /// Stream of proximity alerts (driver near customer).
  static Stream<Map<String, dynamic>> get proximityAlertStream {
    _ensureControllersOpen();
    return _proximityAlertController.stream;
  }

  static bool get isConnected => _isConnected;
  static bool get isPassiveFallback => _isPassiveFallback;
  static int get reconnectAttempts => _reconnectAttempts;

  /// Connect to the WebSocket server with capped exponential backoff retries.
  static void connect({String? authToken, bool resetBackoff = false}) {
    if (_isConnected) return;

    if (resetBackoff) {
      _reconnectAttempts = 0;
      _isPassiveFallback = false;
    }

    if (_isPassiveFallback && !resetBackoff) {
      return;
    }

    _isExplicitDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _ensureControllersOpen();

    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Immediately catch and suppress uncaught errors on ready future to prevent
      // WebSocketChannelException leaking to Dart root zone during connection failures.
      unawaited(_channel!.ready.catchError((_) {}));

      unawaited(
        _channel!.ready.then((_) {
          _isConnected = true;
          _reconnectAttempts = 0;
          _isPassiveFallback = false;

          // Authenticate upon ready completion if token provided
          if (authToken != null && _channel != null) {
            try {
              _channel!.sink.add(jsonEncode({
                'event': 'authenticate',
                'token': authToken,
              }));
            } catch (_) {}
          }
        }).catchError((_) {
          // Suppress unhandled future error; error handling is handled via stream onError
        }),
      );

      _subscription?.cancel();
      _subscription = _channel!.stream.listen(
        (message) {
          if (!_isConnected) {
            _isConnected = true;
            _reconnectAttempts = 0;
            _isPassiveFallback = false;
          }
          _handleMessage(message);
        },
        onError: (error) {
          _handleDisconnect(authToken: authToken);
        },
        onDone: () {
          _handleDisconnect(authToken: authToken);
        },
        cancelOnError: true,
      );
    } catch (e) {
      _handleDisconnect(authToken: authToken);
    }
  }

  static void _handleDisconnect({String? authToken}) {
    // Guard against double invocation (when both onError and onDone fire)
    // or when explicitly disconnected or already in passive fallback.
    if (_isExplicitDisconnect) return;
    if (_isPassiveFallback) return;
    if (_reconnectTimer != null) return;

    _subscription?.cancel();
    _subscription = null;
    _isConnected = false;
    _channel = null;

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      // Exponential backoff: 2s, 4s, 8s
      final delaySeconds = 1 << _reconnectAttempts;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        _reconnectTimer = null;
        connect(authToken: authToken);
      });
    } else {
      _isPassiveFallback = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
  }

  /// Disconnect from the WebSocket server.
  static void disconnect() {
    _isExplicitDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _isPassiveFallback = false;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
  }

  /// Subscribe to a specific order's tracking room.
  static void joinOrderRoom(String orderId) {
    _send({'event': 'join_order', 'order_id': orderId});
  }

  /// Leave an order's tracking room.
  static void leaveOrderRoom(String orderId) {
    _send({'event': 'leave_order', 'order_id': orderId});
  }

  /// Send driver GPS location update (for driver app mode).
  static void sendDriverLocation(double lat, double lng) {
    _send({
      'event': 'driver_location',
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // -------------------------------------------------------------------------
  // INTERNAL HELPERS
  // -------------------------------------------------------------------------

  static void _send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (_) {
        // Guard against abrupt sink closure
      }
    }
  }

  static void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = data['event'] as String?;

      switch (event) {
        case 'driver_location_update':
          if (!_driverLocationController.isClosed) {
            _driverLocationController.add(data);
          }
          break;
        case 'order_status_update':
          if (!_orderStatusController.isClosed) {
            _orderStatusController.add(data);
          }
          break;
        case 'proximity_alert':
          if (!_proximityAlertController.isClosed) {
            _proximityAlertController.add(data);
          }
          break;
      }
    } catch (_) {
      // Silently ignore malformed messages
    }
  }

  /// Clean up all stream controllers (call on app dispose).
  static void dispose() {
    disconnect();
    // Static StreamControllers are preserved / reopened on demand
    // to prevent StateError: Cannot add event after closing.
  }
}
