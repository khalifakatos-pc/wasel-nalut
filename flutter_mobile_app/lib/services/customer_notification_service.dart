import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _customerFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  debugPrint('Customer background notification: ${message.messageId}');
}

class CustomerNotificationService {
  static final CustomerNotificationService _instance = CustomerNotificationService._internal();
  factory CustomerNotificationService() => _instance;
  CustomerNotificationService._internal();

  FirebaseMessaging? get _fcm {
    try {
      if (!kIsWeb && Firebase.apps.isNotEmpty) {
        return FirebaseMessaging.instance;
      }
    } catch (_) {}
    return null;
  }
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _customerOrderChannel = AndroidNotificationChannel(
    'wasel_customer_orders_channel',
    '🛍️ تحديثات طلباتي - واصل نالوت',
    description: 'إشعارات لحظية عن مراحل طهي وتوصيل وجبتك في نالوت',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  bool _isInitialized = false;

  Future<void> initialize({Function(Map<String, dynamic> data)? onNotificationTapped}) async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    // 1. Initialize local notifications first and unconditionally
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Customer notification clicked: ${response.payload}');
          if (onNotificationTapped != null && response.payload != null) {
            onNotificationTapped({'payload': response.payload});
          }
        },
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlatformChannel =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatformChannel != null) {
        await androidPlatformChannel.createNotificationChannel(_customerOrderChannel);
      }
      _isInitialized = true;
      debugPrint('Local notifications initialized successfully');
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }

    // 2. Initialize Firebase safely with timeout
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(const Duration(seconds: 2));
      }

      final fcm = _fcm;
      if (fcm != null) {
        // Background message handler
        FirebaseMessaging.onBackgroundMessage(_customerFirebaseBackgroundHandler);

        // Request permissions
        final settings = await fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('Customer FCM status: ${settings.authorizationStatus}');

        // Subscribe to Nalut general offers
        await fcm.subscribeToTopic('wasel_nalut_offers');

        // Foreground message handler
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Customer foreground message: ${message.notification?.title}');
          _showOrderNotification(
            id: message.hashCode,
            title: message.notification?.title ?? 'تحديث على طلبك - واصل',
            body: message.notification?.body ?? 'هناك تحديث جديد على مسار وجبتك.',
            payload: message.data.toString(),
          );
        });

        // Background launch handler
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          if (onNotificationTapped != null) {
            onNotificationTapped(message.data);
          }
        });
      }
    } catch (e) {
      debugPrint('FCM safe init error: $e');
    }

    _isInitialized = true;
    debugPrint('CustomerNotificationService initialized');
  }

  Future<void> subscribeToOrder(String orderId) async {
    try {
      final fcm = _fcm;
      if (fcm != null) {
        final topic = 'order_${orderId.replaceAll('-', '_')}';
        await fcm.subscribeToTopic(topic);
        debugPrint('Subscribed to order topic: $topic');
      }
    } catch (e) {
      debugPrint('Error subscribing to order topic: $e');
    }
  }

  Future<void> unsubscribeFromOrder(String orderId) async {
    try {
      final fcm = _fcm;
      if (fcm != null) {
        final topic = 'order_${orderId.replaceAll('-', '_')}';
        await fcm.unsubscribeFromTopic(topic);
        debugPrint('Unsubscribed from order topic: $topic');
      }
    } catch (e) {
      debugPrint('Error unsubscribing from order topic: $e');
    }
  }

  Future<void> showOrderStatusNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showOrderNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> _showOrderNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _customerOrderChannel.id,
      _customerOrderChannel.name,
      channelDescription: _customerOrderChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ticker: '🛍️ تحديث حالة طلبك - واصل نالوت',
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }
}
