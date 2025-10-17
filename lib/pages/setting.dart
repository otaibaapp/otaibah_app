import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:otaibah_app/pages/sign_in.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../loading_dialog.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  final _picker = ImagePicker();

  XFile? _pickedImage;
  CroppedFile? _croppedImage;
  Future<void> updateUserInfoInDatabase(
    String uid,
    String node,
    String string,
  ) async {
    final dbRef = FirebaseDatabase.instance.ref();

    try {
      await dbRef.child('otaibah_users/$uid/$node').set(string);
    } catch (e) {
      displaySnackBar('❌ فشل في تحديث الاسم: $e', Colors.redAccent);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'قصّ الصورة',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFF988561),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false, // ✅ ضروري لتظهر أدوات القص فعلياً
            showCropGrid: true,
          ),
          IOSUiSettings(title: 'قصّ الصورة', aspectRatioLockEnabled: true),
        ],
      );

      if (cropped != null) {
        setState(() {
          _croppedImage = cropped;
          _pickedImage = XFile(cropped.path);
        });
      } else {
        displaySnackBar('تم إلغاء القصّ', Colors.grey);
      }
    } catch (e) {
      displaySnackBar('فشل فتح أداة القصّ: $e', Colors.red);
    }
  }

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

  Future<void> updateUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
  }

  Future<void> updatePhotoProfileUrl(String profileImgUrl) async {
    final prefs = await SharedPreferences.getInstance();
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

  Future<Map<String, String>?> showConfirmDeletionDialog(
    BuildContext context,
  ) async {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('تأكيد حذف الحساب', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يؤسفنا قرارك بحذف حسابك, هل لازلت متأكدا من حذف الحساب؟',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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
                Navigator.of(context).pop({'confirmed': 'confirmed'});
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

  Future<Uint8List?> _compressPicked() async {
    final file = _croppedImage ?? _pickedImage;
    if (file == null) return null;

    try {
      Uint8List bytes;
      if (file is XFile) {
        bytes = await file.readAsBytes();
      } else if (file is CroppedFile) {
        bytes = await File(file.path).readAsBytes();
      } else {
        return null;
      }

      final out = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 50,
        minWidth: 500,
        minHeight: 500,
        format: CompressFormat.jpeg,
      );

      return Uint8List.fromList(out);
    } catch (e) {
      displaySnackBar("فشل ضغط الصورة: $e", Colors.red);
      return null;
    }
  }

  Future<String?> _uploadTempBeforeRegister(String uid, Uint8List bytes) async {
    try {
      final ref = FirebaseStorage.instance.ref("users/$uid/avatar.jpg");
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      displaySnackBar("تعذّر رفع الصورة النهائية: $e", Colors.red);
      return null;
    }
  }

  Future<void> updateSomething(int index) async {
    // 0 updat password
    // 1 updat name
    // 2 update profile image
    final creds = await showUpdatingDialog(context, index);
    if (creds == null) {
      displaySnackBar('تم الغاء العملية!', Colors.orangeAccent);
      return;
    }
    final currentPassword = creds['currentPassword']!;
    final field2 = creds['field2']!;
    final newProfileImage = creds['newProfileImage'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          LoadingDialog(msg: 'جارِ تحديث المعلومات..'),
    );
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (index == 0) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        try {
          await user.reauthenticateWithCredential(cred);
          await user.updatePassword(field2);
          Navigator.of(context).pop();
          displaySnackBar('تم تحديث كلمة السر بنجاح!', Colors.green);
        } catch (e) {
          if (e.toString().contains('incorrect')) {
            displaySnackBar('كلمة السر الحالية خاطئة!', Colors.red);
            Navigator.of(context).pop();
          } else {
            displaySnackBar('$e حدث خطأ ما !', Colors.red);
            Navigator.of(context).pop();
          }
        }
      } else if (index == 1) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        try {
          // إعادة المصادقة
          await user.reauthenticateWithCredential(cred);
          await user.updateDisplayName(field2);
          updateUserInfoInDatabase(user.uid, 'name', field2);
          Navigator.of(context).pop();
          updateUserName(field2);
          displaySnackBar('تم تحديث الاسم بنجاح!', Colors.green);
        } catch (e) {
          if (e.toString().contains('incorrect')) {
            displaySnackBar('كلمة السر الحالية خاطئة!', Colors.red);
            Navigator.of(context).pop();
          } else {
            displaySnackBar('$e حدث خطأ ما !', Colors.red);
            Navigator.of(context).pop();
          }
        }
      } else if (index == 2) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        try {
          // إعادة المصادقة
          await user.reauthenticateWithCredential(cred);

          if (newProfileImage != null || _croppedImage != null) {
            Uint8List? compressed;
            String? tempUrl;
            compressed = await _compressPicked();
            if (compressed != null) {
              tempUrl = await _uploadTempBeforeRegister(user.uid, compressed);
              await user.updatePhotoURL(tempUrl);
              Navigator.of(context).pop();
              updatePhotoProfileUrl(tempUrl!);
              updateUserInfoInDatabase(user.uid, 'photoUrl', tempUrl);
              displaySnackBar('تم تحديث الصورة بنجاح!', Colors.green);
            }
          }
        } catch (e) {
          if (e.toString().contains('incorrect')) {
            displaySnackBar('كلمة السر الحالية خاطئة!', Colors.red);
            Navigator.of(context).pop();
          } else {
            displaySnackBar('$e حدث خطأ ما !', Colors.red);
            Navigator.of(context).pop();
          }
        }
      }
    } else {
      displaySnackBar(
        'لم يتم العثور على المستخدم الحالي, الرجاء قم بتسجيل الدخول مرة أخرى!',
        Colors.redAccent,
      );
      Navigator.of(context).pop();
    }
  }

  Future<Map<dynamic, dynamic>?> showUpdatingDialog(
    BuildContext context,
    int index,
  ) async {
    final TextEditingController currentPassword = TextEditingController();
    final TextEditingController field2Controller = TextEditingController();
    return showDialog<Map<dynamic, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: index == 2
                  ? Text('تغيير صورة الملف الشخصي', textAlign: TextAlign.center)
                  : Text(
                      ' تغيير '
                      '${index == 0 ? 'كلمة السر' : 'الاسم'}',
                      textAlign: TextAlign.center,
                    ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'للتأكيد يجب ملأ جميع الحقول',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: currentPassword,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'كلمة السر الحالية',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    index == 2
                        ? GestureDetector(
                            onTap: () async {
                              await _pickImage();
                              setStateDialog(
                                () {},
                              ); // تحديث واجهة الديالوغ بعد اختيار صورة
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _pickedImage != null
                                    ? ClipOval(
                                        child: Image.file(
                                          File(_pickedImage!.path),
                                          width: 95,
                                          height: 95,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : SvgPicture.asset(
                                        'assets/svg/add_photo.svg', // 👈 غيّر هذا حسب اسم أيقونتك
                                        width: 100,
                                        height: 100,
                                      ),
                                const SizedBox(height: 10),
                                const Text(
                                  'أضف صورتك',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                            controller: field2Controller,
                            obscureText: index == 0 ? true : false,
                            decoration: InputDecoration(
                              labelText: index == 0
                                  ? 'كلمة السر الجديدة'
                                  : 'الاسم الجديد',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  child: Text('الغاء'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('تأكيد'),
                  onPressed: () {
                    Navigator.of(context).pop({
                      'currentPassword': currentPassword.text.toString().trim(),
                      'field2': field2Controller.text.toString().trim(),
                      'newProfileImage': _pickedImage != null,
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> inviteFriend() async {
    Share.share(
      'قم بتنزيل تطبيق العتيبة واستمتع بالعديد من المزايا',
      subject: ' قم بتنزيل تطبيق العتيبة واستمتع بالعديد من المزايا',
    );
  }

  Future<void> deleteAccount() async {
    final creds = await showConfirmDeletionDialog(context);
    if (creds == null) {
      displaySnackBar(
        'يسعدنا قرارك بالتراجع عن حذف حسابك ونتمتى لك تجربة مليئة بالافادة😊😊',
        Colors.green,
      );
      return;
    }

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
              TextButton(
                onPressed: () {
                  updateSomething(0);
                },
                child: Text('تغيير كلمة المرور'),
              ),
              TextButton(
                onPressed: () {
                  updateSomething(1);
                },
                child: Text('تغيير الاسم'),
              ),
              TextButton(
                onPressed: () {
                  updateSomething(2);
                },
                child: Text('تغيير صورة الملف الشخصي'),
              ),
              TextButton(onPressed: inviteFriend, child: Text('دعوة صديق')),
            ],
          ),
        ),
      ),
    );
  }
}
