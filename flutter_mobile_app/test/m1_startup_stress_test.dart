import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:wasel_customer_app/services/customer_notification_service.dart';
import 'package:wasel_customer_app/services/socket_service.dart';
import 'package:wasel_customer_app/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 1 Empirical Stress Tests: CustomerNotificationService', () {
    test('Verifying that direct FirebaseMessaging query throws without Firebase.initializeApp()', () {
      expect(Firebase.apps.isEmpty, isTrue);
      // Directly querying FirebaseMessaging.instance before Firebase.initializeApp() throws
      expect(
        () => FirebaseMessaging.instance,
        throwsA(isA<Exception>()),
      );
    });

    test('CustomerNotificationService instantiation succeeds without throwing [core/no-app]', () {
      expect(Firebase.apps.isEmpty, isTrue);
      CustomerNotificationService? service;
      expect(() {
        service = CustomerNotificationService();
      }, returnsNormally);
      expect(service, isNotNull);
    });

    test('CustomerNotificationService methods safely handle null _fcm without throwing', () async {
      final service = CustomerNotificationService();
      await expectLater(service.subscribeToOrder('order-nalut-test-01'), completes);
      await expectLater(service.unsubscribeFromOrder('order-nalut-test-01'), completes);
    });

    test('CustomerNotificationService.initialize() executes and completes within 3 seconds', () async {
      final service = CustomerNotificationService();
      final stopwatch = Stopwatch()..start();
      await service.initialize();
      stopwatch.stop();

      debugPrint('initialize() elapsed time: ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(3));
    });

    test('Concurrent initialize() calls complete within 3 seconds without deadlock', () async {
      final service = CustomerNotificationService();
      final stopwatch = Stopwatch()..start();
      await Future.wait([
        service.initialize(),
        service.initialize(),
        service.initialize(),
      ]);
      stopwatch.stop();

      debugPrint('Concurrent initialize() elapsed time: ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(3));
    });
  });

  group('Milestone 1 Empirical Stress Tests: SocketService Resilient Backoff', () {
    setUp(() {
      SocketService.disconnect();
    });

    tearDown(() {
      SocketService.disconnect();
    });

    test('SocketService initial state is clean and idle', () {
      expect(SocketService.isConnected, isFalse);
      expect(SocketService.isPassiveFallback, isFalse);
      expect(SocketService.reconnectAttempts, equals(0));
    });

    test('SocketService send methods do not throw when disconnected', () {
      expect(() => SocketService.joinOrderRoom('order-nalut-99'), returnsNormally);
      expect(() => SocketService.leaveOrderRoom('order-nalut-99'), returnsNormally);
      expect(() => SocketService.sendDriverLocation(31.8687, 10.9818), returnsNormally);
    });

    test('SocketService disconnect() cleanly cancels pending retry timer', () async {
      SocketService.wsUrl = 'ws://127.0.0.1:59991';
      SocketService.connect();

      // Wait until connection failure schedules first retry timer
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (SocketService.reconnectAttempts == 0 && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      expect(SocketService.reconnectAttempts, equals(1));

      // Call disconnect()
      SocketService.disconnect();
      expect(SocketService.reconnectAttempts, equals(0));
      expect(SocketService.isPassiveFallback, isFalse);

      // Wait longer than attempt 1 backoff (2s) to verify timer was truly cancelled
      await Future.delayed(const Duration(seconds: 3));
      expect(SocketService.reconnectAttempts, equals(0),
          reason: 'Timer should not fire after disconnect()');
      expect(SocketService.isConnected, isFalse);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('SocketService capped backoff stops reconnecting after 3 retries and sets isPassiveFallback', () async {
      // Direct socket to an unavailable local port so it fails immediately
      SocketService.wsUrl = 'ws://127.0.0.1:59992';

      expect(SocketService.isConnected, isFalse);
      expect(SocketService.isPassiveFallback, isFalse);
      expect(SocketService.reconnectAttempts, equals(0));

      final stopwatch = Stopwatch()..start();
      SocketService.connect();

      // Poll until isPassiveFallback is set or timeout reached (2s + 4s + 8s = 14s total backoff)
      final timeoutDeadline = DateTime.now().add(const Duration(seconds: 25));
      while (!SocketService.isPassiveFallback && DateTime.now().isBefore(timeoutDeadline)) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      stopwatch.stop();

      debugPrint('Total backoff cycle duration: ${stopwatch.elapsed.inSeconds} s');

      // Assertions for Requirement R1 / Milestone 1
      expect(SocketService.isPassiveFallback, isTrue,
          reason: 'SocketService must enter passive fallback after 3 failed retries');
      expect(SocketService.reconnectAttempts, equals(3),
          reason: 'SocketService must cap retries at exactly 3 attempts');
      expect(SocketService.isConnected, isFalse);

      // Verify passive fallback suppresses further connect attempts
      SocketService.connect();
      expect(SocketService.reconnectAttempts, equals(3),
          reason: 'connect() in passive fallback must be a no-op');
      expect(SocketService.isPassiveFallback, isTrue);

      // Verify resetBackoff resets the state
      SocketService.connect(resetBackoff: true);
      expect(SocketService.isPassiveFallback, isFalse,
          reason: 'resetBackoff: true must clear passive fallback');
    }, timeout: const Timeout(Duration(seconds: 35)));
  });

  group('Milestone 1 Empirical Stress Tests: SplashScreen Fast Route & Clean Dispose', () {
    testWidgets('SplashScreen unmount before 1400ms timer does not leave pending timer assertion', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            isLoggedIn: false,
            nextScreen: Scaffold(body: Text('Next Screen')),
          ),
        ),
      );

      expect(find.byType(SplashScreen), findsOneWidget);

      // Pump 400ms into the 1400ms timer
      await tester.pump(const Duration(milliseconds: 400));

      // Replace with another widget to trigger dispose()
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Replacement Screen')),
        ),
      );

      // Pump beyond 1400ms to verify navigation timer was cancelled cleanly
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('Replacement Screen'), findsOneWidget);
    });
  });
}
