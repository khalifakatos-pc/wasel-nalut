import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_supabase_service.dart';

/// Live GPS Telemetry and Device Location Service for Wasel Captain App.
/// Streams genuine device GPS coordinates exclusively from Geolocator sensor.
class DriverGpsService {
  DriverGpsService._internal();
  static final DriverGpsService instance = DriverGpsService._internal();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  String? _activeOrderId;
  bool _isTracking = false;
  bool _isUsingRealGps = false;
  bool _isServiceEnabled = true;

  double _currentLat = 31.8686;
  double _currentLng = 10.9818;
  double _currentHeading = 0.0;
  double _currentSpeedKmh = 0.0;

  final StreamController<Map<String, dynamic>> _locationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _gpsStatusController =
      StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onLocationUpdate => _locationStreamController.stream;
  Stream<bool> get onGpsStatusChanged => _gpsStatusController.stream;
  bool get isTracking => _isTracking;
  bool get isUsingRealGps => _isUsingRealGps;
  bool get isServiceEnabled => _isServiceEnabled;
  bool get isLocationServiceEnabled => _isServiceEnabled;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  double get currentHeading => _currentHeading;
  double get currentSpeedKmh => _currentSpeedKmh;

  /// Open device system location settings
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Open application permission settings
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Check whether GPS service is actively enabled and authorized
  Future<bool> checkGpsAvailability() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      _isServiceEnabled = enabled;
      if (!enabled) {
        _isUsingRealGps = false;
        _gpsStatusController.add(false);
        return false;
      }
      final permission = await Geolocator.checkPermission();
      final hasPerm = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      _gpsStatusController.add(hasPerm);
      return hasPerm;
    } catch (_) {
      return false;
    }
  }

  /// Start live location tracking
  Future<void> startTracking({String? orderId}) async {
    _activeOrderId = orderId;
    if (_isTracking) {
      if (orderId != null) _activeOrderId = orderId;
      return;
    }

    _isTracking = true;

    // Monitor continuous service status stream (enabled / disabled)
    _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((status) {
      final enabled = status == ServiceStatus.enabled;
      _isServiceEnabled = enabled;
      if (!enabled) {
        _isUsingRealGps = false;
      }
      _gpsStatusController.add(enabled);
    });

    final bool hasPermission = await _checkAndRequestPermissions();

    if (hasPermission && !kIsWeb) {
      try {
        _isUsingRealGps = true;
        _isServiceEnabled = true;
        _gpsStatusController.add(true);

        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        );

        _positionSubscription?.cancel();
        _positionSubscription = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          _handleRealGpsPosition,
          onError: (err) {
            debugPrint('[DriverGpsService] Real GPS sensor stream error: $err');
            _isUsingRealGps = false;
            _gpsStatusController.add(false);
          },
        );

        // Fetch initial immediate location fix
        try {
          final initialPos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          ).timeout(const Duration(seconds: 4));
          _handleRealGpsPosition(initialPos);
        } catch (_) {}
        return;
      } catch (e) {
        debugPrint('[DriverGpsService] Failed to initialize real GPS: $e');
        _isUsingRealGps = false;
        _gpsStatusController.add(false);
      }
    } else {
      _isUsingRealGps = false;
      _gpsStatusController.add(false);
    }
  }

  /// Request permissions cleanly
  Future<bool> _checkAndRequestPermissions() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _isServiceEnabled = serviceEnabled;
      if (!serviceEnabled) {
        debugPrint('[DriverGpsService] Location services are disabled.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[DriverGpsService] Location permissions are denied.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[DriverGpsService] Location permissions permanently denied.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[DriverGpsService] Permission check error: $e');
      return false;
    }
  }

  void _handleRealGpsPosition(Position position) {
    _currentLat = position.latitude;
    _currentLng = position.longitude;
    _currentHeading = position.heading >= 0 ? position.heading : _currentHeading;
    _currentSpeedKmh = position.speed >= 0 ? (position.speed * 3.6) : _currentSpeedKmh;
    _isUsingRealGps = true;

    _dispatchTelemetry();
  }

  void _dispatchTelemetry() {
    final payload = {
      'driver_id': DriverSupabaseService.activeDriverId,
      'order_id': _activeOrderId,
      'latitude': _currentLat,
      'longitude': _currentLng,
      'heading': _currentHeading,
      'speed_kmh': _currentSpeedKmh,
      'is_real_gps': _isUsingRealGps,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (!_locationStreamController.isClosed) {
      _locationStreamController.add(payload);
    }

    // Broadcast directly to backend and cloud
    DriverSupabaseService.broadcastTelemetry(
      latitude: _currentLat,
      longitude: _currentLng,
      heading: _currentHeading,
      speedKmh: _currentSpeedKmh,
      orderId: _activeOrderId,
    );
  }

  /// Update active order linked to telemetry stream
  void setActiveOrderId(String? orderId) {
    _activeOrderId = orderId;
  }

  /// Stop live location tracking
  void stopTracking() {
    _isTracking = false;
    _isUsingRealGps = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
  }

  void dispose() {
    stopTracking();
    _locationStreamController.close();
    _gpsStatusController.close();
  }
}
