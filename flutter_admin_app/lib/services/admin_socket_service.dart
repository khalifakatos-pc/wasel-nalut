import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Production Socket.io Client for Wasel Super Admin App.
/// Connects to Socket.io on port 3000, identifies as role: 'admin' to join 'admin:fleet',
/// and provides real-time event streams for fleet telemetry and order lifecycle changes.
class AdminSocketService {
  AdminSocketService._internal();

  static final AdminSocketService _instance = AdminSocketService._internal();
  static AdminSocketService get instance => _instance;

  io.Socket? _socket;
  String _serverUrl = 'http://localhost:3000';
  bool _isConnected = false;
  bool _isConnecting = false;

  final StreamController<Map<String, dynamic>> _orderStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _driverMovedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onOrderStatusChanged =>
      _orderStatusController.stream;
  Stream<Map<String, dynamic>> get onDriverMoved =>
      _driverMovedController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool get isConnected => _isConnected;
  String get serverUrl => _serverUrl;

  /// Determine the default socket server URL based on platform and environment
  static String resolveDefaultUrl() {
    const envUrl = String.fromEnvironment('SOCKET_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return 'https://wasel-nalut.onrender.com';
  }

  /// Initialize and configure the socket client
  void init({String? url}) {
    _serverUrl = url ?? resolveDefaultUrl();
    _initSocket();
  }

  void _initSocket() {
    if (_socket != null) {
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    try {
      _socket = io.io(
        _serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1500)
            .setReconnectionDelayMax(5000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        _isConnecting = false;
        _connectionController.add(true);
        debugPrint('✅ [AdminSocketService] Connected to $_serverUrl (id: ${_socket?.id})');

        // Identify as super admin to join admin:fleet and role:admin rooms
        _socket!.emit('identify', {'role': 'admin'});
        _socket!.emit('join_admin');
      });

      _socket!.onDisconnect((reason) {
        _isConnected = false;
        _isConnecting = false;
        _connectionController.add(false);
        debugPrint('ℹ️ [AdminSocketService] Disconnected: $reason');
      });

      _socket!.onConnectError((err) {
        _isConnected = false;
        _isConnecting = false;
        _connectionController.add(false);
        debugPrint('⚠️ [AdminSocketService] Connect error: $err');
      });

      _socket!.onError((err) {
        debugPrint('⚠️ [AdminSocketService] Socket error: $err');
      });

      // Primary fleet events
      _socket!.on('admin:order_status_changed', (data) {
        _dispatchOrderStatus(data);
      });

      _socket!.on('order:status_changed', (data) {
        _dispatchOrderStatus(data);
      });

      _socket!.on('admin:driver_moved', (data) {
        _dispatchDriverMoved(data);
      });

      _socket!.on('driver:location_changed', (data) {
        _dispatchDriverMoved(data);
      });
    } catch (e) {
      debugPrint('❌ [AdminSocketService] Init exception: $e');
    }
  }

  /// Connect to the socket server
  void connect() {
    if (_socket == null) {
      _initSocket();
    }
    if (!_isConnected && !_isConnecting) {
      _isConnecting = true;
      try {
        _socket?.connect();
      } catch (e) {
        _isConnecting = false;
        debugPrint('⚠️ [AdminSocketService] Connect exception: $e');
      }
    }
  }

  /// Disconnect socket client
  void disconnect() {
    try {
      _socket?.disconnect();
    } catch (_) {}
    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(false);
  }

  void _dispatchOrderStatus(dynamic rawData) {
    final map = _normalizeMap(rawData);
    if (map.isNotEmpty) {
      _orderStatusController.add(map);
    }
  }

  void _dispatchDriverMoved(dynamic rawData) {
    final map = _normalizeMap(rawData);
    if (map.isNotEmpty) {
      _driverMovedController.add(map);
    }
  }

  Map<String, dynamic> _normalizeMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  /// Testing & Simulation Helpers
  void simulateOrderStatusChanged(Map<String, dynamic> data) {
    _dispatchOrderStatus(data);
  }

  void simulateDriverMoved(Map<String, dynamic> telemetry) {
    _dispatchDriverMoved(telemetry);
  }

  void dispose() {
    disconnect();
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _orderStatusController.close();
    _driverMovedController.close();
    _connectionController.close();
  }
}
