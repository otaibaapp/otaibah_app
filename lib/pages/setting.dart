import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:otaibah_app/pages/sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../loading_dialog.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  Future<void> saveLoginStatus(
    bool isLoggedIn,
    String name,
    String profileImgUrl,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEmailVerified', isLoggedIn);
    await prefs.setString('name', name);
    await prefs.setString('profileImgUrl', profileImgUrl);
  }

  void displaySnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color,
      ),
    );
  }

  Future<Map<String, String>?> showReAuthDialog(BuildContext context) async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('إعادة تسجيل الدخول', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يرجى إدخال البريد الإلكتروني وكلمة المرور لتأكيد هويتك قبل حذف الحساب.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // إغلاق بدون إرجاع بيانات
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                if (email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'يرجى إدخال البريد الإلكتروني وكلمة المرور',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                Navigator.of(
                  context,
                ).pop({'email': email, 'password': password});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => LoadingDialog(msg: 'جارٍ حذف الحساب'),
    );
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      try {
        await user.delete();
        await FirebaseStorage.instance.ref("users/$userId/avatar.jpg").delete();
        await FirebaseDatabase.instance.ref("otaibah_users/$userId/").remove();

        FirebaseAuth.instance.signOut();
      } on Exception catch (e) {
        if (e.toString().contains('requires-recent-login')) {
          final creds = await showReAuthDialog(context);
          if (creds == null) {
            Navigator.of(context, rootNavigator: true).pop();
            displaySnackBar(' المستخدم ألغى العملية', Colors.redAccent);
            return;
          }

          final email = creds['email']!;
          final password = creds['password']!;
          final cred = EmailAuthProvider.credential(
            email: email,
            password: password,
          );
          await user.reauthenticateWithCredential(cred);
          Navigator.of(context, rootNavigator: true).pop();
          deleteAccount();
          return;
        } else {
          Navigator.of(context, rootNavigator: true).pop();
          displaySnackBar(e.toString(), Colors.redAccent);
          return;
        }
      }
      saveLoginStatus(false, '', '');
      displaySnackBar('تم حذف الحساب بنجاح', Colors.green);
      Future.delayed(Duration.zero);
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => SignIn()),
        (Route<dynamic> route) => false,
      );
    } else {
      displaySnackBar('ظهر خطأ ما!', Colors.redAccent);
      FirebaseAuth.instance.signOut();
      saveLoginStatus(false, '', '');
      Future.delayed(Duration.zero);
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => SignIn()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              TextButton(onPressed: logOut, child: Text('تسجيل الخروج')),
              TextButton(onPressed: deleteAccount, child: Text('حذف الحساب')),
            ],
          ),
        ),
      ),
    );
  }

  void logOut() {
    FirebaseAuth.instance.signOut();
    saveLoginStatus(false, '', '');
    Future.delayed(Duration.zero);
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => SignIn()),
      (Route<dynamic> route) => false,
    );
  }
}
