
import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 🔹 هذا الملف يوفّر هوية ثابتة للجهاز أو المستخدم.
/// إذا المستخدم مسجّل دخول → نستخدم UID الخاص به.
/// إذا لا → نستخدم deviceId الثابت (محفوظ محلياً).
class AppIdentity {
  /// إرجاع معرّف المستخدم الثابت.
  static Future<String> getStableUserId() async {
    // 🔸 أولاً: نتحقق إن كان هناك مستخدم Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      return user.uid; // 🔹 المعرّف الحقيقي للمستخدم المسجل
    }

    // 🔸 إذا لم يكن هناك تسجيل دخول، نرجع إلى deviceId المحلي
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('stableDeviceId');
    if (cached != null && cached.isNotEmpty) return cached;

    // إنشاء معرف جديد للجهاز
    final info = DeviceInfoPlugin();
    String? id;
    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        id = a.id; // ANDROID_ID
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        id = i.identifierForVendor;
      }
    } catch (_) {}

    id ??= _randomId(24);
    await prefs.setString('stableDeviceId', id);
    return id;
  }

  static String _randomId(int n) {
    const s =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    return String.fromCharCodes(List.generate(
        n, (_) => s.codeUnitAt(r.nextInt(s.length))));
  }
}
