import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_svg/svg.dart';
import 'package:otaibah_app/pages/dashboard.dart';
import 'package:otaibah_app/pages/sign_in.dart';
import 'package:otaibah_app/pages/sign_up.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp();
  FlutterNativeSplash.remove();
  runApp(const MaterialApp(home: MyApp(), debugShowCheckedModeBanner: false));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      // هنا يتم تحديد الاتجاه لكل التطبيق
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        title: 'RTL App',
        home: MyStatefulWidget(),
        debugShowCheckedModeBanner: false,
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
  // دالة للتحقق من حالة تسجيل الدخول
  _checkEmailStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final isLoggedIn = prefs.getBool('isEmailVerified') ?? false;

    setState(() {
      _isEmailVerified = isLoggedIn;
    });
  }

  @override
  void initState() {
    super.initState(); // مهم جداً استدعاء الدالة الأصلية
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
              fit: BoxFit.contain,
            ),
          ),
          Column(
            children: [
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.45),
              SvgPicture.asset(
                'assets/svg/app_logo.svg',
                height: 20,
                width: 20,
              ),
              Text(
                'بلدة العتيبة ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),

              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: RichText(
                    text: TextSpan(
                      children: <TextSpan>[
                        TextSpan(
                          text: 'تطبيق العتيبة: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // يجعل النص غامقًا
                          ),
                        ),
                        TextSpan(
                          style: TextStyle(
                            color: Colors.black, // يجعل النص غامقًا
                          ),
                          text:
                          'منصة تجمع كل خدمات البلدة في مكان واحد, الطب, التعليم, الدعم, التواصل, الإعلانات.. كل ماتحتاجه لحياة أسهل',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Text(
                'بلدتنا تستحق, فلننهض بها معاَ🤞',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => SignIn()),
                      );
                    },
                    child: Text('تسجيل الدخول'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.black, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => SignUp()),
                      );
                    },
                    child: Text('إنشاء حساب جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),

              /*Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => AddToFirebaseDatabase(),
                              ),
                            );
                          },
                          child: Text('إضافة بيانات إلى قاعدة البيانات'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),*/
            ],
          ),
        ],
      ),
    )
        : Dashboard();
  }
}
