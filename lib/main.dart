import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_svg/svg.dart';
import 'package:otaibah_app/pages/dashboard.dart';
import 'package:otaibah_app/pages/sign_in.dart';
import 'package:otaibah_app/pages/sign_up.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otaibah_app/services/fcm_service.dart';
import 'package:otaibah_app/services/notification_sender.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// ✅ لازم نضيف هذا الجزء لاستقبال الإشعارات بالخلفية والمغلق
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📬 إشعار بالخلفية أو التطبيق مغلق بالكامل: ${message.notification?.title}");
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp();

  // ✅ تشغيل المعالج الخلفي قبل أي شيء
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ نظام الإشعارات
  await FCMService.initLocalNotifications();
  await FCMService.requestPermission();
  FCMService.listenToForegroundMessages();
  await FCMService.saveUserFcmToken();

  // ✅ تهيئة الخدمة التي تمنع التطبيق من الإغلاق
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'otaibah_keep_alive',
      channelName: 'Otaibah Running Service',
      channelDescription: 'يحافظ على تشغيل تطبيق العتيبة في الخلفية 🌙',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 60000,
      isOnceEvent: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  // ✅ تشغيل الخدمة بالخلفية
  FlutterForegroundTask.startService(
    notificationTitle: 'تطبيق العتيبة يعمل بالخلفية',
    notificationText: 'جاهز دائمًا لتلبية طلباتك 💫',
  );

  FlutterNativeSplash.remove();

  runApp(const MyApp());
  FCMService.setupBackgroundHandler();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'العتيبة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'PortadaAra',
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0x25000000),
        ),
        scaffoldBackgroundColor: const Color(0xFFf6f6f6),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: MyStatefulWidget(),
      ),
    );
  }
}

class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({super.key});

  @override
  _MyStatefulWidgetState createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  final TextEditingController _textController = TextEditingController();
  bool _isEmailVerified = false;


  Future<void> _checkEmailStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isEmailVerified') ?? false;
    setState(() {
      _isEmailVerified = isLoggedIn;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkEmailStatus();
    _initDynamicLinks();

    // ✅ لما يضغط المستخدم على الإشعار بعد الإغلاق
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print("🚀 تم فتح التطبيق من إشعار (terminated state)");
        // بإمكانك هنا تفتح صفحة محددة لو الإشعار فيه orderId
      }
    });

    // ✅ هذا السطر يخفي الإشعار بعد التشغيل مباشرة
    FlutterForegroundTask.stopService();
  }

  void _initDynamicLinks() async {
    FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
      _handleDeepLink(dynamicLinkData.link);
    }).onError((error) {});

    final PendingDynamicLinkData? initialLink =
    await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink.link);
    }
  }

  void _handleDeepLink(Uri deepLink) {
    if (deepLink.pathSegments.contains('product')) {
      final productId = deepLink.pathSegments.last;
      print("📌 تم استقبال رابط المنتج: $productId");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Dashboard(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return !_isEmailVerified
        ? Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Column(
            children: [
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.40),
              SvgPicture.asset(
                'assets/svg/app_logo.svg',
                height: 75,
                width: 75,
              ),
              const SizedBox(height: 10),
              const Text(
                'تطبيق بلدة العتيبة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 25.0,
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      children: <TextSpan>[
                        TextSpan(
                          text: 'تطبيق العتيبة: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'PortadaAra',
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: 'PortadaAra',
                          ),
                          text:
                          'منصة تجمع كل خدمات البلدة في مكان واحد, الطب, التعليم, الدعم, التواصل, الإعلانات.. كل ماتحتاجه لحياة أسهل',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Text(
                'بلدتنا تستحق, فلننهض بها معاَ🤞',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),


              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const SignIn()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      side: const BorderSide(
                        color: Colors.black,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: const Text('تسجيل الدخول'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const SignUp()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: const Text('إنشاء حساب جديد'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        : const Dashboard();
  }
}
