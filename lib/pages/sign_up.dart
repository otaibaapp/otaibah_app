import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:otaibah_app/loading_dialog.dart';
import 'package:otaibah_app/main.dart';
import 'package:otaibah_app/pages/sign_in.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  @override
  Widget build(BuildContext context) {
    void displaySnackBar(String msg, Color color) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    }

    bool isLoading = false;
    TextEditingController? passwordController = TextEditingController(),
        emailController = TextEditingController(),
        confirmPasswordController = TextEditingController(),
        nameController = TextEditingController();
    void registerNewUser(
      String email,
      String password,
      String confirmPassword,
      String fullName,
    ) async {
      setState(() {
        isLoading = true;
      });
      try {
        // استخدام FirebaseAuth لإنشاء المستخدم
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );
        // إذا نجح إنشاء الحساب، يمكنك توجيه المستخدم لصفحة أخرى
        displaySnackBar('تم إنشاء الحساب بنجاح', Colors.green);
        try {
          userCredential.user?.sendEmailVerification();
          displaySnackBar('تم إرسال رابط التأكيد الى ايميلك', Colors.amber);
          //Navigator.pop(context);
          await Future.delayed(const Duration(seconds: 3));
          Navigator.push(context, MaterialPageRoute(builder: (c) => MyApp()));
          setState(() {
            isLoading = false;
          });
        } on FirebaseAuthException catch (e) {
          displaySnackBar(e.code, Colors.red);
          setState(() {
            isLoading = false;
          });
        }
        // يمكنك إضافة كود للتنقل إلى صفحة أخرى هنا
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
      } on FirebaseAuthException catch (e) {
        setState(() {
          isLoading = false;
        });
        // التعامل مع الأخطاء التي قد تحدث
        String errorMessage = 'حدث خطأ غير معروف.';
        if (e.code == 'weak-password') {
          errorMessage = 'كلمة المرور ضعيفة جداً.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'يوجد حساب مسجل بهذا البريد الإلكتروني بالفعل.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'صيغة البريد الإلكتروني غير صحيحة.';
        } else {
          errorMessage = e.code;
        }
        setState(() {
          isLoading = false;
        });
        // عرض رسالة الخطأ للمستخدم
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
        displaySnackBar('خطأ في إنشاء الحساب: ${e.code}', Colors.red);
      } catch (e) {
        setState(() {
          isLoading = false;
        });
      }
    }

    void checkFieldsValidation(
      String email,
      String password,
      String confirmPassword,
      String fullName,
    ) {
      if (email.length < 5 ||
          password.length < 5 ||
          confirmPassword.length < 5 ||
          fullName.length < 5) {
        displaySnackBar(
          'AppLocalizations.of(context)!.check_fields',
          Colors.red,
        );
        return;
      } else if (!email.contains("@")) {
        displaySnackBar(
          'AppLocalizations.of(context)!.check_email',
          Colors.red,
        );
        return;
      } else if (password.length < 6) {
        displaySnackBar(
          'AppLocalizations.of(context)!.check_password',
          Colors.red,
        );
        return;
      } else if (password.compareTo(confirmPassword) != 0) {
        displaySnackBar(
          'AppLocalizations.of(context)!.password_not_match',
          Colors.red,
        );
        return;
      } else {
        registerNewUser(email, password, confirmPassword, fullName);
      }
    }

    // ... (بقية الكود الخاص بالواجهة)

    void signUp() {
      checkFieldsValidation(
        emailController.text.trim(),
        passwordController.text.trim(),
        passwordController.text.trim(),
        nameController.text.trim(),
      );
    }

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
                'صفحة التسجيل',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // Full Name
              TextField(
                textAlign: TextAlign.right,
                obscureText: false,
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              // Email
              TextField(
                textAlign: TextAlign.right,
                obscureText: false,
                controller: emailController,
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

              // Password
              TextField(
                textAlign: TextAlign.right,
                obscureText: true,
                controller: passwordController,
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

              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                textAlign: TextAlign.right,
                obscureText: true,
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  hintText: 'تأكيد كلمة المرور',
                  prefixIcon: Icon(Icons.fingerprint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

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
                    signUp();
                    //Navigator.pop(context);
                  },
                  child: !isLoading
                      ? Text('فتح حساب جديد', style: TextStyle(fontSize: 16))
                      : LoadingDialog(msg: 'جاري المصادقة'),
                ),
              ),
              const SizedBox(height: 24),

              // OR
              const Text('أو من خلال'),
              const SizedBox(height: 16),

              // Social Login
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
              const SizedBox(height: 24),

              // Login Redirect
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('هل لديك حساب بالفعل؟'),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => SignIn()),
                      );
                    },
                    child: const Text(
                      'أنقُر لتسجيل الدخول',
                      style: TextStyle(color: Colors.black),
                    ),
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
