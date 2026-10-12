import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_supabase_service.dart';

/// Live GPS Telemetry and Device Location Service for Wasel Captain App.
/// Handles high-precision device GPS streaming with graceful simulated fallback for Nalut.
class DriverGpsService {
  DriverGpsService._internal();
  static final DriverGpsService instance = DriverGpsService._internal();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _fallbackSimulationTimer;
  String? _activeOrderId;
  bool _isTracking = false;
  bool _isUsingRealGps = false;

  double _currentLat = 31.8686;
  double _currentLng = 10.9818;
  double _currentHeading = 0.0;
  double _currentSpeedKmh = 0.0;
  int _simulationStep = 0;

  final StreamController<Map<String, dynamic>> _locationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onLocationUpdate => _locationStreamController.stream;
  bool get isTracking => _isTracking;
  bool get isUsingRealGps => _isUsingRealGps;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  double get currentHeading => _currentHeading;
  double get currentSpeedKmh => _currentSpeedKmh;

  /// Start live location tracking
  Future<void> startTracking({String? orderId}) async {
    _activeOrderId = orderId;
    if (_isTracking) {
      if (orderId != null) _activeOrderId = orderId;
      return;
    }

    _isTracking = true;
    bool hasPermission = await _checkAndRequestPermissions();

    if (hasPermission && !kIsWeb) {
      try {
        _isUsingRealGps = true;
        // Listen to continuous high-accuracy position updates
        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // update every 5 meters
        );

        _positionSubscription = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          _handleRealGpsPosition,
          onError: (err) {
            debugPrint('[DriverGpsService] GPS stream error: $err. Falling back to simulation.');
            _startFallbackSimulation();
          },
        );

        // Fetch initial immediate fix
        final initialPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 4), onTimeout: () => Position(
          latitude: _currentLat,
          longitude: _currentLng,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ));
        _handleRealGpsPosition(initialPos);
        return;
      } catch (e) {
        debugPrint('[DriverGpsService] Could not start real GPS: $e');
      }
    }

    // Fallback: Real GPS unavailable or permission denied
    _startFallbackSimulation();
  }

  /// Request permissions cleanly
  Future<bool> _checkAndRequestPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
      debugPrint('[DriverGpsService] Permission error: $e');
      return false;
    }
  }

  void _handleRealGpsPosition(Position position) {
    _currentLat = position.latitude;
    _currentLng = position.longitude;
    _currentHeading = position.heading >= 0 ? position.heading : _currentHeading;
    _currentSpeedKmh = position.speed >= 0 ? (position.speed * 3.6) : _currentSpeedKmh;

    _dispatchTelemetry();
  }

  void _startFallbackSimulation() {
    _isUsingRealGps = false;
    _fallbackSimulationTimer?.cancel();
    _fallbackSimulationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isTracking) return;
      _simulationStep++;

      // Smooth realistic movement along Nalut thoroughfare (31.8686, 10.9818)
      final latOffset = ((_simulationStep % 12) - 6) * 0.00015;
      final lngOffset = ((_simulationStep % 10) - 5) * 0.00018;

      _currentLat = 31.8686 + latOffset;
      _currentLng = 10.9818 + lngOffset;
      _currentHeading = (_simulationStep * 30.0) % 360.0;
      _currentSpeedKmh = 35.0 + (_simulationStep % 15);

      _dispatchTelemetry();
    });
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
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _fallbackSimulationTimer?.cancel();
    _fallbackSimulationTimer = null;
  }

  void dispose() {
    stopTracking();
    _locationStreamController.close();
  }
}
