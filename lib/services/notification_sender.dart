// notification_sender.dart
// Updated: Safe + Smart version. Works even without service_account.json
// Tries service account if present, otherwise falls back to Cloud Function.
// By Ahmad & ChatGPT ❤️

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class NotificationSender {
  // Firebase Project ID
  static const String _projectId = 'otaiba-app';
  static const String _serviceAccountAssetPath = 'assets/service_account.json';

  /// ==============================
  /// 1️⃣ الإرسال عبر Service Account (فقط إن وُجد الملف)
  /// ==============================
  static Future<bool> _sendWithServiceAccount({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // حاول تحميل ملف service_account.json من مجلد الأصول
      final jsonStr = await rootBundle.loadString(_serviceAccountAssetPath);
      final Map<String, dynamic> sa = json.decode(jsonStr);

      final credentials = ServiceAccountCredentials.fromJson(sa);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(credentials, scopes);

      final url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send');

      final message = {
        "message": {
          "token": token,
          "notification": {"title": title, "body": body},
          "android": {"priority": "high"},
          "data": data ?? {},
        }
      };

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(message),
      );

      client.close();

      print("📩 (SA) status: ${response.statusCode}");
      if (response.statusCode == 200) {
        print("✅ تم الإرسال عبر Service Account");
        return true;
      } else {
        print("📩 (SA) body: ${response.body}");
        return false;
      }
    } catch (e) {
      // طبيعي يفشل لأن الملف غير موجود — لذلك ما يوقف التطبيق
      print("⚠️ _sendWithServiceAccount failed: $e");
      return false;
    }
  }

  /// ==============================
  /// 2️⃣ الإرسال عبر دالة Cloud Function (sendNotification)
  /// ==============================
  static Future<bool> _sendWithCallable({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendNotification');

      final res = await callable.call(<String, dynamic>{
        'token': token,
        'title': title,
        'body': body,
        'data': data ?? {},
      });

      print("📩 (CF) result: ${jsonEncode(res.data)}");
      return true;
    } on FirebaseFunctionsException catch (e) {
      print("❌ (CF) Functions error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      print("❌ (CF) Unexpected error calling function: $e");
      return false;
    }
  }

  /// ==============================
  /// 3️⃣ نقطة الدخول العامة (Public API)
  /// ==============================
  static Future<void> send({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    print("🚀 بدء عملية إرسال الإشعار...");

    // الخطوة 1: جرّب Service Account (لو الملف موجود)
    final okSa = await _sendWithServiceAccount(
      token: token,
      title: title,
      body: body,
      data: data,
    );

    // الخطوة 2: لو فشل أو الملف غير موجود → استخدم Cloud Function
    if (!okSa) {
      print("ℹ️ الانتقال للإرسال عبر الدالة السحابية...");
      final okCf = await _sendWithCallable(
        token: token,
        title: title,
        body: body,
        data: data,
      );

      if (!okCf) {
        print("❌ فشل إرسال الإشعار عبر جميع الطرق (SA + CF)");
      } else {
        print("✅ تم إرسال الإشعار عبر Cloud Function بنجاح!");
      }
    }
  }
}
