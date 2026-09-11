import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket service for real-time GPS tracking and order status updates.
class SocketService {
  static const String _wsUrl = 'ws://localhost:3000';
  static WebSocketChannel? _channel;
  static bool _isConnected = false;

  // Stream controllers for different event types
  static final _driverLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final _orderStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final _proximityAlertController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of real-time driver GPS location updates.
  static Stream<Map<String, dynamic>> get driverLocationStream =>
      _driverLocationController.stream;

  /// Stream of order status change events.
  static Stream<Map<String, dynamic>> get orderStatusStream =>
      _orderStatusController.stream;

  /// Stream of proximity alerts (driver near customer).
  static Stream<Map<String, dynamic>> get proximityAlertStream =>
      _proximityAlertController.stream;

  static bool get isConnected => _isConnected;

  /// Connect to the WebSocket server.
  static void connect({String? authToken}) {
    if (_isConnected) return;

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _isConnected = false;
          // Auto-reconnect after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            connect(authToken: authToken);
          });
        },
        onDone: () {
          _isConnected = false;
        },
      );

      // Authenticate if token provided
      if (authToken != null) {
        _send({'event': 'authenticate', 'token': authToken});
      }
    } catch (e) {
      _isConnected = false;
    }
  }

  /// Disconnect from the WebSocket server.
  static void disconnect() {
    _channel?.sink.close();
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
      _channel!.sink.add(jsonEncode(data));
    }
  }

  static void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = data['event'] as String?;

      switch (event) {
        case 'driver_location_update':
          _driverLocationController.add(data);
          break;
        case 'order_status_update':
          _orderStatusController.add(data);
          break;
        case 'proximity_alert':
          _proximityAlertController.add(data);
          break;
      }
    } catch (_) {
      // Silently ignore malformed messages
    }
  }

  /// Clean up all stream controllers (call on app dispose).
  static void dispose() {
    disconnect();
    _driverLocationController.close();
    _orderStatusController.close();
    _proximityAlertController.close();
  }
}
