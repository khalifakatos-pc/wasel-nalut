import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _customerFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Customer background notification: ${message.messageId}');
}

class CustomerNotificationService {
  static final CustomerNotificationService _instance = CustomerNotificationService._internal();
  factory CustomerNotificationService() => _instance;
  CustomerNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
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

    try {
      // 1. Initialize Firebase
      await Firebase.initializeApp();

      // 2. Set background handler
      FirebaseMessaging.onBackgroundMessage(_customerFirebaseBackgroundHandler);

      // 3. Request permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('Customer FCM status: ${settings.authorizationStatus}');

      // 4. Setup local notifications
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

      // 5. Create Android Channel
      final AndroidFlutterLocalNotificationsPlugin? androidPlatformChannel =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatformChannel != null) {
        await androidPlatformChannel.createNotificationChannel(_customerOrderChannel);
      }

      // 6. Subscribe to General Nalut Offers Topic
      await _fcm.subscribeToTopic('wasel_nalut_offers');

      // 7. Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Customer foreground message: ${message.notification?.title}');
        _showOrderNotification(
          id: message.hashCode,
          title: message.notification?.title ?? 'تحديث على طلبك - واصل',
          body: message.notification?.body ?? 'هناك تحديث جديد على مسار وجبتك.',
          payload: message.data.toString(),
        );
      });

      // 8. Background launch handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (onNotificationTapped != null) {
          onNotificationTapped(message.data);
        }
      });

      _isInitialized = true;
      debugPrint('CustomerNotificationService initialized');
    } catch (e) {
      debugPrint('Error initializing CustomerNotificationService: $e');
    }
  }

  Future<void> subscribeToOrder(String orderId) async {
    try {
      final topic = 'order_${orderId.replaceAll('-', '_')}';
      await _fcm.subscribeToTopic(topic);
      debugPrint('Subscribed to order topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to order topic: $e');
    }
  }

  Future<void> unsubscribeFromOrder(String orderId) async {
    try {
      final topic = 'order_${orderId.replaceAll('-', '_')}';
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from order topic: $topic');
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
