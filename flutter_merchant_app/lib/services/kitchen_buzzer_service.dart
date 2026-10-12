import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// ============================================================================
/// KITCHEN AUDIO BUZZER SERVICE (جرس وتنبيه المطبخ المستمر)
/// ============================================================================
/// Plays continuous loud audible bell and haptic alert pulses (every 3 seconds)
/// when a new incoming kitchen order arrives until the cook/cashier accepts the ticket.
/// ============================================================================
class KitchenBuzzerService with ChangeNotifier {
  KitchenBuzzerService._internal() {
    _initAudio();
  }
  static final KitchenBuzzerService instance = KitchenBuzzerService._internal();

  AudioPlayer? _player;
  Timer? _buzzerTimer;
  bool _isBuzzing = false;
  String? _buzzingOrderId;

  void _initAudio() {
    try {
      _player = AudioPlayer();
      _player?.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('[KitchenBuzzerService] AudioPlayer init error: $e');
    }
  }

  bool get isBuzzing => _isBuzzing;
  String? get buzzingOrderId => _buzzingOrderId;

  /// Start playing continuous kitchen buzzer alert
  void startBuzzer({String? orderId}) {
    _buzzingOrderId = orderId ?? _buzzingOrderId;
    if (_isBuzzing) return;

    _isBuzzing = true;
    notifyListeners();

    // Trigger immediate alert pulse
    _playAlertPulse();

    // Repeat alert pulse every 3 seconds until accepted
    _buzzerTimer?.cancel();
    _buzzerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isBuzzing) {
        timer.cancel();
        return;
      }
      _playAlertPulse();
    });

    debugPrint('[KitchenBuzzerService] 🚨 Kitchen buzzer STARTED for order: $_buzzingOrderId');
  }

  /// Stop the kitchen buzzer (cook accepted the order)
  void stopBuzzer({String? orderId}) {
    if (!_isBuzzing) return;

    _isBuzzing = false;
    _buzzingOrderId = null;
    _buzzerTimer?.cancel();
    _buzzerTimer = null;
    try {
      _player?.stop();
    } catch (_) {}
    notifyListeners();

    debugPrint('[KitchenBuzzerService] 🔕 Kitchen buzzer STOPPED (Order accepted/cleared)');
  }

  Future<void> _playAlertPulse() async {
    try {
      // 1. Play real offline acoustic kitchen bell sound
      if (_player != null) {
        await _player!.stop();
        await _player!.play(AssetSource('sounds/kitchen_order_bell.wav'), volume: 1.0);
      }
      // 2. Play tactile heavy haptics
      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('[KitchenBuzzerService] Sound play failed, using fallback: $e');
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _buzzerTimer?.cancel();
    try {
      _player?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
