import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:otaibah_app/pages/dashboard.dart';
import 'package:otaibah_app/pages/sign_up.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../loading_dialog.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  @override
  Widget build(BuildContext context) {
    Future<void> saveLoginStatus(bool isLoggedIn) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isEmailVerified', isLoggedIn);
    }

    void displaySnackBar(String msg, Color color) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
                saveLoginStatus(true);
                Future.delayed(Duration.zero);
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (c) => Dashboard()),
                );
              }
            })
            .catchError((onError) {
              String errorMessage = onError.toString();
              if (errorMessage.toString().contains('user-not-found')) {
                errorMessage = 'الايميل غير مسجل من قبل!';
              } else if (errorMessage.toString().contains('wrong-password') ||
                  errorMessage.toString().contains('incorrect')) {
                errorMessage = 'تحقق من الايميل او كلمة المرور!';
              } else if (errorMessage.toString().contains('badly forma')) {
                errorMessage = 'تحقق من صيغة الايميل!';
              }
              Future.delayed(Duration.zero);
              Navigator.of(context, rootNavigator: true).pop();
              displaySnackBar(errorMessage, Colors.red);
            });
      } on FirebaseAuthException {}
      () {};
    }

    void checkValidation(String email, String password) {
      if (email.isEmpty || password.isEmpty) {
        displaySnackBar('تحقق من كلمة السر او الايميل', Colors.red);
        return;
      } else {
        signIn(email, password);
      }
    }

    TextEditingController? passwordController = TextEditingController(),
        emailController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Logo
              SvgPicture.asset(
                'assets/svg/app_logo.svg',
                height: 40,
                width: 40,
              ),
              const SizedBox(height: 8),
              const Text(
                'بلدة العتيبة',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              const Text(
                'صفحة تسجيل الدخول',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // Email
              TextField(
                textAlign: TextAlign.right,
                controller: emailController,
                obscureText: false,
                decoration: InputDecoration(
                  hintText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                textAlign: TextAlign.right,
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.fingerprint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              // Password
              const SizedBox(height: 16),

              // Register Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Login Redirect
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ليس لديك حساب بعد؟'),
                  TextButton(
                    onPressed: () {
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (c) => SignUp()),
                      );
                    },
                    child: const Text(
                      'إنشاء حساب',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: FaIcon(FontAwesomeIcons.google, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
