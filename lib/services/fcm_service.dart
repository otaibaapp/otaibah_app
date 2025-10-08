import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("📬 إشعار بالخلفية أو التطبيق مغلق بالكامل: ${message.notification?.title}");
}

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  static const String _projectId = "otaiba-app";
  static const String _serviceAccountPath = "assets/service_account.json";

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'otaibah_channel',
    'إشعارات العتيبة',
    description: 'قناة الإشعارات لتطبيق المستخدم',
    importance: Importance.high,
  );

  // ✅ تهيئة الإشعارات المحلية + القناة
  static Future<void> initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final data = jsonDecode(payload);
            final orderId = data["orderId"];
            if (orderId != null) {
              print("📦 المستخدم ضغط على إشعار الطلب ID: $orderId");
              // TODO: افتح صفحة الطلب مباشرة هنا إذا رغبت لاحقًا
            }
          } catch (e) {
            print("⚠️ خطأ في تحليل بيانات الإشعار: $e");
          }
        }
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // ✅ طلب صلاحيات الإشعارات
  static Future<void> requestPermission() async {
    await _firebaseMessaging.requestPermission(alert: true, badge: true, sound: true);
    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ✅ تفعيل استقبال الإشعارات بالخلفية والمقدمة
  static void setupBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // ✅ الاستماع للإشعارات أثناء فتح التطبيق
  static void listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      final data = message.data;
      if (notif != null) {
        _showNotification(
          notif.title ?? "إشعار جديد",
          notif.body ?? "",
          data,
        );
      }
    });

    // عند الضغط على الإشعار بعد الإغلاق
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      final orderId = data["orderId"];
      print("🚀 فتح التطبيق من إشعار فيه orderId: $orderId");
    });
  }

  // ✅ عرض الإشعار محلياً حتى في السكون
  static Future<void> _showNotification(
      String title, String body, Map<String, dynamic> data) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableLights: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true, // 👈 يُومض الشاشة في بعض الأجهزة
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _local.show(
      0,
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
  }

  // ✅ حفظ توكن المستخدم (مسار مفرد + متعدد)
  static Future<void> saveUserFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      final multiRef =
      FirebaseDatabase.instance.ref("users/${user.uid}/fcmTokens/$token");
      await multiRef.set({"createdAt": ServerValue.timestamp});

      final singleRef =
      FirebaseDatabase.instance.ref("users/${user.uid}/fcmToken");
      await singleRef.set(token);

      print("✅ تم حفظ FCM Token للمستخدم ${user.uid}: $token");
    } else {
      print("⚠️ لم يتم الحصول على FCM Token");
    }
  }

  // ✅ إرسال إشعار مباشر عبر FCM v1 (يُستخدم فقط من الواجهة الإدارية)
  static Future<void> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 📁 تحميل بيانات حساب الخدمة من assets (إذا متاحة)
      final jsonStr = await File(_serviceAccountPath).readAsString();
      final serviceAccount = json.decode(jsonStr);

      final credentials = ServiceAccountCredentials.fromJson(serviceAccount);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(credentials, scopes);

      final url =
      Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send');

      final payload = {
        "message": {
          "token": token,
          "notification": {"title": title, "body": body},
          "android": {
            "priority": "high",
            "notification": {
              "click_action": "FLUTTER_NOTIFICATION_CLICK",
              "channel_id": _channel.id,
            }
          },
          "data": data ?? {},
        }
      };

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      );

      print("📩 إشعار مرسل برمز الحالة: ${response.statusCode}");
      client.close();
    } catch (e) {
      print("❌ خطأ أثناء إرسال الإشعار عبر FCM v1: $e");
    }
  }
}
