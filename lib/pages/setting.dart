import 'package:firebase_auth/firebase_auth.dart';
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

  void logOut() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => LoadingDialog(msg: 'جار تسجيل الخروج'),
    );
    FirebaseAuth.instance.signOut();
    saveLoginStatus(false, '', '');
    Future.delayed(Duration.zero);
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => SignIn()),
      (Route<dynamic> route) => false,
    );
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

  void deleteAccount() {}
  Future<void> deleteAccountCompletely(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مستخدم مسجل حالياً')),
      );
      return;
    }

    final userId = user.uid;

    try {} catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حذف الحساب والبيانات: $e')),
      );
    }
  }
}
