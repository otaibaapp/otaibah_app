import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_svg/svg.dart';
import 'package:otaibah_app/pages/dashboard.dart';
import 'package:otaibah_app/pages/sign_in.dart';
import 'package:otaibah_app/pages/sign_up.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterNativeSplash.remove();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTL App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Qomra', // 👈 هنا عيّنا الخط الافتراضي
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

  _checkEmailStatus() async {
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
              fit: BoxFit.cover,        // 👈 غيّرها من contain إلى cover
              width: double.infinity,   // 👈 يخليها تغطي العرض كامل
              height: double.infinity,  // 👈 يغطي الطول كامل
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
                            fontWeight: FontWeight.bold, fontFamily: 'Qomra',
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          style: TextStyle(color: Colors.black, fontFamily: 'Qomra' ),
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
                  height: 50, // 👈 الطول المطلوب
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => const SignIn()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      side: const BorderSide(
                          color: Colors.black, width: 1),
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
                  height: 50, // 👈 الطول المطلوب
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => const SignUp()),
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
