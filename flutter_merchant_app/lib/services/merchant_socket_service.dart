import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'kitchen_buzzer_service.dart';

/// Real-Time Socket.io Service for Wasel Kitchen & Merchant App.
/// Connects to Socket.io on port 3000 / Render Cloud, joins 'store:{store_id}',
/// and provides real-time event streams for immediate sub-50ms kitchen tickets.
class MerchantSocketService {
  MerchantSocketService._internal();

  static final MerchantSocketService instance = MerchantSocketService._internal();

  io.Socket? _socket;
  String? _currentStoreId;
  bool _isConnected = false;

  final StreamController<Map<String, dynamic>> _newOrderController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _orderStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewOrder => _newOrderController.stream;
  Stream<Map<String, dynamic>> get onOrderStatusChanged => _orderStatusController.stream;

  bool get isConnected => _isConnected;

  static String resolveDefaultUrl() {
    const envUrl = String.fromEnvironment('SOCKET_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return 'https://wasel-nalut.onrender.com';
  }

  void connect({required String storeId, String? url}) {
    _currentStoreId = storeId;
    final serverUrl = url ?? resolveDefaultUrl();

    if (_socket != null) {
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    try {
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionAttempts(10)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('[MerchantSocket] Connected to $serverUrl. Subscribing to store: $_currentStoreId');
        _socket!.emit('store:subscribe', {'store_id': _currentStoreId});
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('[MerchantSocket] Disconnected from socket server');
      });

      _socket!.on('store:new_order', (data) {
        debugPrint('[MerchantSocket] 🚨 NEW INCOMING ORDER RECEIVED: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _newOrderController.add(map);
          // Trigger immediate kitchen buzzer
          final orderId = map['order_id']?.toString() ?? map['id']?.toString();
          KitchenBuzzerService.instance.startBuzzer(orderId: orderId);
        }
      });

      _socket!.on('order:status_changed', (data) {
        debugPrint('[MerchantSocket] Order status changed: $data');
        if (data is Map) {
          _orderStatusController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('[MerchantSocket] Socket connection failed: $e');
    }
  }

  void updateStore(String storeId) {
    if (_currentStoreId == storeId) return;
    _currentStoreId = storeId;
    if (_isConnected && _socket != null) {
      _socket!.emit('store:subscribe', {'store_id': _currentStoreId});
    }
  }

  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _isConnected = false;
  }
}
