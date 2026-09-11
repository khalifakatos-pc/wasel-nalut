import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

class DriverNotificationService {
  static final DriverNotificationService _instance = DriverNotificationService._internal();
  factory DriverNotificationService() => _instance;
  DriverNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _driverAlertChannel = AndroidNotificationChannel(
    'wasel_driver_alerts_channel',
    '🚨 تنبيهات طلبات كباتن واصل',
    description: 'رنين واهتزاز فوري عالي الأهمية لإشعار الكابتن بالطلبات الجديدة في نالوت',
    importance: Importance.max,
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
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Request permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Authorization status: ${settings.authorizationStatus}');

      // 4. Setup local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
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
        await androidPlatformChannel.createNotificationChannel(_driverAlertChannel);
      }

      // 6. Subscribe to Wasel Captains Topic
      await _fcm.subscribeToTopic('wasel_captains');
      debugPrint('Subscribed to topic: wasel_captains');

      // 7. Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground FCM message received: ${message.notification?.title}');
        _showLocalNotification(
          id: message.hashCode,
          title: message.notification?.title ?? '🚨 طلب توصيل جديد - واصل نالوت',
          body: message.notification?.body ?? 'يوجد طلب جديد متاح في منطقتك، افتح التطبيق للقبول.',
          payload: message.data.toString(),
        );
      });

      // 8. Handle app launch from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from notification: ${message.data}');
        if (onNotificationTapped != null) {
          onNotificationTapped(message.data);
        }
      });

      _isInitialized = true;
      debugPrint('DriverNotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing DriverNotificationService: $e');
    }
  }

  Future<String?> getDeviceToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> showOrderAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _driverAlertChannel.id,
      _driverAlertChannel.name,
      channelDescription: _driverAlertChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: '🚨 طلب جديد متاح - كابتن واصل',
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
