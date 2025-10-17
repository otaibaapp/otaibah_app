import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:otaibah_app/pages/dashboard.dart';
import 'package:otaibah_app/pages/sign_up.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../loading_dialog.dart';
import '../main.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  bool obscurePassword = true;
  Future<void> saveLoginStatus(
    bool isLoggedIn,
    String name,
    String profileImgUrl,
    String email,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEmailVerified', isLoggedIn);
    await prefs.setString('name', name);
    await prefs.setString('profileImgUrl', profileImgUrl);
    await prefs.setString('email', email);
  }

  void displaySnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color,
      ),
    );
  }

  void signIn(String email, String password) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) =>
            LoadingDialog(msg: 'جار تسجيل الدخول'),
      );
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          )
          .then((onValue) {
            if (onValue.user!.emailVerified) {
              saveLoginStatus(
                true,
                onValue.user!.displayName ?? 'مستخدم جديد',
                onValue.user!.photoURL ??
                    'https://firebasestorage.googleapis.com/v0/b/otaiba-app.firebasestorage.app/o/temp_profile_uploads%2Fnew_icon.png?alt=media&token=ebe59377-60e1-4dbf-8215-07ef2c8c6e3d',
                onValue.user!.email ?? '',
              );
              Future.delayed(Duration.zero);
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (c) => const Dashboard()),
              );
            } else {
              Future.delayed(Duration.zero);
              Navigator.of(context, rootNavigator: true).pop();
              displaySnackBar(
                'رجاء قم بتأكيد الايميل قبل بتسجيل الدخول!',
                Colors.blueGrey,
              );
            }
          })
          .catchError((onError) {
            String errorMessage = onError.toString();
            if (errorMessage.contains('user-not-found')) {
              errorMessage = 'الايميل غير مسجل من قبل!';
            } else if (errorMessage.contains('wrong-password') ||
                errorMessage.contains('incorrect')) {
              errorMessage = 'تحقق من الايميل او كلمة المرور!';
            } else if (errorMessage.contains('badly forma')) {
              errorMessage = 'تحقق من صيغة الايميل!';
            }
            Future.delayed(Duration.zero);
            Navigator.of(context, rootNavigator: true).pop();
            displaySnackBar(errorMessage, Colors.red);
          });
    } on FirebaseAuthException {
      // تجاهل الأخطاء الصامتة
    }
  }

  void checkValidation(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      displaySnackBar('تحقق من كلمة السر او الايميل', Colors.red);
      return;
    } else {
      signIn(email, password);
    }
  }

  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyApp()),
            );
          }
        }
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // الخلفية
            Image.asset('assets/images/background.png', fit: BoxFit.cover),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // الشعار
                      SvgPicture.asset(
                        'assets/svg/app_logo.svg',
                        height: 40,
                        width: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'تطبيق بلدة العتيبة',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'صفحة تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // البريد الإلكتروني
                      TextField(
                        textAlign: TextAlign.right,
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'البريد الإلكتروني',
                          hintStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SvgPicture.asset(
                              'assets/svg/email_icon.svg',
                              width: 13,
                              height: 13,
                              colorFilter: const ColorFilter.mode(
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black26,
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF988561),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // كلمة المرور
                      TextField(
                        textAlign: TextAlign.right,
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور',
                          hintStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SvgPicture.asset(
                              'assets/svg/password_icon.svg',
                              width: 13,
                              height: 13,
                              colorFilter: const ColorFilter.mode(
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          suffixIcon: InkWell(
                            onTap: () {
                              setState(
                                () => obscurePassword = !obscurePassword,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: SvgPicture.asset(
                                obscurePassword
                                    ? 'assets/svg/eye_closed.svg'
                                    : 'assets/svg/eye_open.svg',
                                width: 13,
                                height: 13,
                                colorFilter: const ColorFilter.mode(
                                  Colors.black,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black26,
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF988561),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // زر تسجيل الدخول
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          onPressed: () {
                            checkValidation(
                              emailController.text.trim(),
                              passwordController.text.trim(),
                            );
                          },
                          child: const Text(
                            'تسجيل الدخول',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'ليس لديك حساب بعد؟',
                        style: TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 8),

                      // زر إنشاء الحساب
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF988561),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: () {
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (c) => const SignUp()),
                            );
                          },
                          child: const Text(
                            'إنشاء حساب جديد',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
