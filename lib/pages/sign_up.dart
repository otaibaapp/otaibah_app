import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:otaibah_app/loading_dialog.dart';
import 'package:otaibah_app/main.dart';
import 'package:otaibah_app/pages/sign_in.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  final _picker = ImagePicker();

  XFile? _pickedImage;
  String? _tempUploadedPath;

  void displaySnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textAlign: TextAlign.center), backgroundColor: color),
    );
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => _pickedImage = x);
  }

  Future<Uint8List?> _compressPicked() async {
    if (_pickedImage == null) return null;
    try {
      if (kIsWeb) {
        final bytes = await _pickedImage!.readAsBytes();
        final out = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 60,
          minWidth: 400,
          minHeight: 400,
          format: CompressFormat.jpeg,
        );
        return Uint8List.fromList(out);
      } else {
        final out = await FlutterImageCompress.compressWithFile(
          _pickedImage!.path,
          quality: 60,
          minWidth: 400,
          minHeight: 400,
          format: CompressFormat.jpeg,
        );
        if (out == null) return null;
        return Uint8List.fromList(out);
      }
    } catch (_) {
      return null;
    }
  }

  Future<String?> _uploadTempBeforeRegister(Uint8List bytes) async {
    try {
      final millis = DateTime.now().millisecondsSinceEpoch;
      final rnd = Random().nextInt(999999);
      final tempPath = "temp_profile_uploads/$millis-$rnd.jpg";
      final ref = FirebaseStorage.instance.ref(tempPath);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      _tempUploadedPath = tempPath;
      return await ref.getDownloadURL();
    } catch (e) {
      displaySnackBar("تعذّر رفع الصورة مؤقتًا: $e", Colors.red);
      return null;
    }
  }

  Future<String?> _uploadFinalAfterRegister(String uid, Uint8List bytes) async {
    try {
      final ref = FirebaseStorage.instance.ref("users/$uid/avatar.jpg");
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      displaySnackBar("تعذّر رفع الصورة النهائية: $e", Colors.red);
      return null;
    }
  }

  Future<void> _deleteTempIfAny() async {
    if (_tempUploadedPath == null) return;
    try {
      await FirebaseStorage.instance.ref(_tempUploadedPath!).delete();
    } catch (_) {}
    _tempUploadedPath = null;
  }

  void checkFieldsValidation(
      String email, String password, String confirmPassword, String fullName) {
    if (email.length < 5 ||
        password.length < 5 ||
        confirmPassword.length < 5 ||
        fullName.length < 5) {
      displaySnackBar('AppLocalizations.of(context)!.check_fields', Colors.red);
      return;
    } else if (!email.contains("@")) {
      displaySnackBar('AppLocalizations.of(context)!.check_email', Colors.red);
      return;
    } else if (password.length < 6) {
      displaySnackBar('AppLocalizations.of(context)!.check_password', Colors.red);
      return;
    } else if (password.compareTo(confirmPassword) != 0) {
      displaySnackBar('AppLocalizations.of(context)!.password_not_match', Colors.red);
      return;
    } else if (_pickedImage == null) {
      displaySnackBar('الرجاء اختيار صورة الحساب أولاً', Colors.red);
      return;
    } else {
      registerNewUser(email, password, confirmPassword, fullName);
    }
  }

  Future<void> registerNewUser(
      String email, String password, String confirmPassword, String fullName) async {
    setState(() => isLoading = true);

    try {
      final compressed = await _compressPicked();
      if (compressed == null) {
        displaySnackBar('تعذّر ضغط الصورة. حاول صورة أخرى.', Colors.red);
        setState(() => isLoading = false);
        return;
      }

      final tempUrl = await _uploadTempBeforeRegister(compressed);
      if (tempUrl == null) {
        setState(() => isLoading = false);
        return;
      }

      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;
      final finalUrl = await _uploadFinalAfterRegister(uid, compressed);

      await userCredential.user!.updateDisplayName(fullName);
      await userCredential.user!.updatePhotoURL(finalUrl ?? tempUrl);

      await _db.child('otaibah_users/$uid').set({
        'name': fullName,
        'email': email,
        'photoUrl': finalUrl ?? tempUrl,
        'createdAt': ServerValue.timestamp,
      });

      await _deleteTempIfAny();

      displaySnackBar('تم إنشاء الحساب بنجاح', Colors.green);
      try {
        await userCredential.user?.sendEmailVerification();
        displaySnackBar('تم إرسال رابط التأكيد إلى بريدك', Colors.amber);
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (c) => const MyApp()));
        setState(() => isLoading = false);
      } on FirebaseAuthException catch (e) {
        displaySnackBar(e.code, Colors.red);
        setState(() => isLoading = false);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = e.code;
      displaySnackBar(errorMessage, Colors.red);
      setState(() => isLoading = false);
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  void signUp() {
    checkFieldsValidation(
      emailController.text.trim(),
      passwordController.text.trim(),
      confirmPasswordController.text.trim(),
      nameController.text.trim(),
    );
  }

  // =============== واجهة المستخدم ===============
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // ✅ يرجع للمصدر (SignIn إذا كنت جاي منه)
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
            Image.asset('assets/images/background.png', fit: BoxFit.cover),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      SvgPicture.asset('assets/svg/app_logo.svg', height: 40, width: 40),
                      const SizedBox(height: 8),
                      const Text('تطبيق بلدة العتيبة',
                          style: TextStyle(fontSize: 16, color: Colors.black54)),
                      const SizedBox(height: 12),
                      const Text('صفحة التسجيل',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      // صورة الحساب
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            backgroundImage: _pickedImage != null
                                ? (kIsWeb
                                ? NetworkImage(_pickedImage!.path)
                                : FileImage(File(_pickedImage!.path))
                            as ImageProvider)
                                : null,
                            child: _pickedImage == null
                                ? SvgPicture.asset(
                              'assets/svg/user_icon.svg',
                              width: 50,
                              height: 50,
                              colorFilter: const ColorFilter.mode(
                                  Color(0xFF988561), BlendMode.srcIn),
                            )
                                : null,
                          ),
                          InkWell(
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(100),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0x30000000),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: SvgPicture.asset(
                                'assets/svg/camera_icon1.svg',
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                    Colors.black, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // الاسم الكامل
                      TextField(
                        textAlign: TextAlign.right,
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'الاسم الكامل',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SvgPicture.asset(
                              'assets/svg/name_icon.svg',
                              width: 12,
                              height: 12,
                              colorFilter: const ColorFilter.mode(
                                  Colors.black, BlendMode.srcIn),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide:
                              const BorderSide(color: Colors.black26)),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // البريد الإلكتروني
                      TextField(
                        textAlign: TextAlign.right,
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'البريد الإلكتروني',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SvgPicture.asset(
                              'assets/svg/email_icon.svg',
                              width: 13,
                              height: 13,
                              colorFilter: const ColorFilter.mode(
                                  Colors.black, BlendMode.srcIn),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide:
                              const BorderSide(color: Colors.black26)),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // كلمة المرور
                      TextField(
                        textAlign: TextAlign.right,
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(13.0),
                            child: SvgPicture.asset(
                              'assets/svg/password_icon.svg',
                              width: 22,
                              height: 22,
                              colorFilter: const ColorFilter.mode(
                                  Colors.black, BlendMode.srcIn),
                            ),
                          ),
                          suffixIcon: InkWell(
                            onTap: () =>
                                setState(() => obscurePassword = !obscurePassword),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: SvgPicture.asset(
                                obscurePassword
                                    ? 'assets/svg/eye_closed.svg'
                                    : 'assets/svg/eye_open.svg',
                                width: 13,
                                height: 13,
                                colorFilter: const ColorFilter.mode(
                                    Color(0xFF000000), BlendMode.srcIn),
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide:
                              const BorderSide(color: Colors.black26)),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // تأكيد كلمة المرور
                      TextField(
                        textAlign: TextAlign.right,
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          hintText: 'تأكيد كلمة المرور',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SvgPicture.asset(
                              'assets/svg/password_icon.svg',
                              width: 13,
                              height: 13,
                              colorFilter: const ColorFilter.mode(
                                  Colors.black, BlendMode.srcIn),
                            ),
                          ),
                          suffixIcon: InkWell(
                            onTap: () =>
                                setState(() => obscureConfirm = !obscureConfirm),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: SvgPicture.asset(
                                obscureConfirm
                                    ? 'assets/svg/eye_closed.svg'
                                    : 'assets/svg/eye_open.svg',
                                width: 13,
                                height: 13,
                                colorFilter: const ColorFilter.mode(
                                    Color(0xFF000000), BlendMode.srcIn),
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide:
                              const BorderSide(color: Colors.black26)),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // زر التسجيل
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7)),
                          ),
                          onPressed: isLoading ? null : signUp,
                          child: !isLoading
                              ? const Text('فتح حساب جديد',
                              style: TextStyle(fontSize: 15))
                              : LoadingDialog(msg: 'جاري المصادقة'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('هل لديك حساب بالفعل؟',
                          style: TextStyle(color: Colors.black87)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 60, vertical: 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF988561),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (c) => const SignIn()),
                            );
                          },
                          child: const Text('أنقُر لتسجيل الدخول',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
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
