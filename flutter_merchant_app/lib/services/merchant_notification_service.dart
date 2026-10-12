import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'kitchen_buzzer_service.dart';

@pragma('vm:entry-point')
Future<void> _merchantFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    debugPrint('[Merchant FCM Background] Received message: ${message.messageId}');

    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await localNotifications.initialize(initSettings);

    const AndroidNotificationChannel kitchenAlertChannel = AndroidNotificationChannel(
      'wasel_kitchen_alerts_channel',
      '🔔 تنبيهات مطبخ شريك واصل (نالوت)',
      description: 'رنين واهتزاز فوري عالي الأهمية لإشعار المطبخ بالطلبات الجديدة',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('kitchen_bell'),
      enableVibration: true,
      showBadge: true,
    );

    final androidPlatformChannel = localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlatformChannel != null) {
      await androidPlatformChannel.createNotificationChannel(kitchenAlertChannel);
    }

    final title = message.notification?.title ?? '🔔 طلب مطبخ جديد - واصل نالوت';
    final body = message.notification?.body ?? 'وصل طلب جديد للمطعم، افتح شاشة KDS للبدء.';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      kitchenAlertChannel.id,
      kitchenAlertChannel.name,
      channelDescription: kitchenAlertChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('kitchen_bell'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: '🚨 طلب جديد وارد - واصل نالوت',
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'open_kds',
          '📋 عرض الطلب في KDS',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: message.data.toString(),
    );
  } catch (e) {
    debugPrint('[Merchant FCM Background] Error displaying background notification: $e');
  }
}

class MerchantNotificationService {
  static final MerchantNotificationService _instance = MerchantNotificationService._internal();
  factory MerchantNotificationService() => _instance;
  MerchantNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _kitchenAlertChannel = AndroidNotificationChannel(
    'wasel_kitchen_alerts_channel',
    '🔔 تنبيهات مطبخ شريك واصل (نالوت)',
    description: 'رنين واهتزاز فوري عالي الأهمية لإشعار المطبخ بالطلبات الجديدة',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('kitchen_bell'),
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
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // 2. Set background handler
      FirebaseMessaging.onBackgroundMessage(_merchantFirebaseBackgroundHandler);

      // 3. Request permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        criticalAlert: true,
        sound: true,
      );

      debugPrint('Merchant FCM status: ${settings.authorizationStatus}');

      // 4. Setup local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Merchant notification clicked: ${response.payload}');
          KitchenBuzzerService.instance.stopBuzzer();
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
        await androidPlatformChannel.createNotificationChannel(_kitchenAlertChannel);
      }

      // 6. Subscribe to Merchant topics
      await _fcm.subscribeToTopic('wasel_merchants');
      await _fcm.subscribeToTopic('store_store_nalut_01');
      debugPrint('Merchant subscribed to topics: wasel_merchants, store_store_nalut_01');

      // 7. Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Merchant foreground message: ${message.notification?.title}');
        final orderId = message.data['order_id'] ?? message.data['orderId'];
        // Start continuous kitchen buzzer audio until cook accepts
        KitchenBuzzerService.instance.startBuzzer(orderId: orderId?.toString());
        showKitchenOrderAlert(
          title: message.notification?.title ?? '🔔 طلب مطبخ جديد - واصل نالوت',
          body: message.notification?.body ?? 'وصل طلب جديد للمطعم، افتح شاشة KDS للبدء.',
          payload: message.data.toString(),
        );
      });

      // 8. Background launch handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        KitchenBuzzerService.instance.stopBuzzer();
        if (onNotificationTapped != null) {
          onNotificationTapped(message.data);
        }
      });

      _isInitialized = true;
      debugPrint('MerchantNotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing MerchantNotificationService: $e');
    }
  }

  Future<void> showKitchenOrderAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _kitchenAlertChannel.id,
      _kitchenAlertChannel.name,
      channelDescription: _kitchenAlertChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('kitchen_bell'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: '🚨 طلب جديد وارد - واصل نالوت',
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'open_kds',
          '📋 عرض الطلب في KDS',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  /// Subscribes this merchant device to the store's high-priority FCM topic
  Future<void> subscribeToStore(String storeId) async {
    try {
      final topic = 'store_${storeId.replaceAll('-', '_')}';
      await _fcm.subscribeToTopic(topic);
      debugPrint('[MerchantNotificationService] Successfully subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[MerchantNotificationService] Failed to subscribe to topic: $e');
    }
  }

  /// Unsubscribes from the store's FCM topic on logout
  Future<void> unsubscribeFromStore(String storeId) async {
    try {
      final topic = 'store_${storeId.replaceAll('-', '_')}';
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('[MerchantNotificationService] Successfully unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('[MerchantNotificationService] Failed to unsubscribe from topic: $e');
    }
  }
}
