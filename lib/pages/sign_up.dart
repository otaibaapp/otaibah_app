import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
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
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController nameController = TextEditingController();

  final _db = FirebaseDatabase.instance.ref();
  final _picker = ImagePicker();

  XFile? _pickedImage;
  CroppedFile? _croppedImage;

  void displaySnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color,
      ),
    );
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

  // 🔄 ضغط الصورة بأفضل توازن بين الحجم والجودة (متوافق مع كل المنصات)
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

  void checkFieldsValidation(
    String email,
    String password,
    String confirmPassword,
    String fullName,
  ) {
    if (email.length < 5 ||
        password.length < 5 ||
        confirmPassword.length < 5 ||
        fullName.length < 3) {
      displaySnackBar('الرجاء تعبئة جميع الحقول بشكل صحيح', Colors.red);
      return;
    } else if (!email.contains("@")) {
      displaySnackBar('الرجاء إدخال بريد إلكتروني صحيح', Colors.red);
      return;
    } else if (password.length < 6) {
      displaySnackBar('كلمة المرور يجب أن تكون 6 أحرف على الأقل', Colors.red);
      return;
    } else if (password.compareTo(confirmPassword) != 0) {
      displaySnackBar('كلمتا المرور غير متطابقتين', Colors.red);
      return;
    } else {
      registerNewUser(email, password, confirmPassword, fullName);
    }
  }

  Future<void> registerNewUser(
    String email,
    String password,
    String confirmPassword,
    String fullName,
  ) async {
    setState(() => isLoading = true);

    try {
      Uint8List? compressed;
      String? tempUrl;
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final uid = userCredential.user!.uid;
      // إذا المستخدم اختار صورة
      if (_pickedImage != null || _croppedImage != null) {
        compressed = await _compressPicked();
        if (compressed != null) {
          tempUrl = await _uploadTempBeforeRegister(uid, compressed);
        }
      }
      await userCredential.user!.updatePhotoURL(tempUrl);
      await userCredential.user!.updateDisplayName(fullName);
      await _db.child('otaibah_users/$uid').set({
        'name': fullName,
        'email': email,
        'photoUrl': tempUrl ?? '',
        'createdAt': DateTime.now().toLocal().toString(),
      });

      try {
        await userCredential.user?.sendEmailVerification();
        displaySnackBar(
          '✅ تم إرسال رسالة تأكيد إلى بريدك الإلكتروني. يرجى تأكيد الحساب قبل تسجيل الدخول.',
          Colors.green,
        );
      } on FirebaseAuthException catch (e) {
        displaySnackBar(e.code, Colors.red);
      }

      setState(() => isLoading = false);

      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => const SignIn()),
      );
    } on FirebaseAuthException catch (e) {
      displaySnackBar(e.message ?? e.code, Colors.red);
      setState(() => isLoading = false);
    } catch (e) {
      displaySnackBar('حدث خطأ غير متوقع: $e', Colors.red);
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
                        'صفحة التسجيل',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // صورة الحساب
                      // ✅ واجهة اختيار الصورة الجديدة (أيقونة واحدة فقط)
                      // ✅ واجهة اختيار الصورة البسيطة (أيقونة فقط في الفراغ)
                      // ✅ واجهة اختيار الصورة (أيقونة + نص "أضف صورتك")
                      GestureDetector(
                        onTap: _pickImage,
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
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(color: Colors.black26),
                          ),
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
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(color: Colors.black26),
                          ),
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
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          suffixIcon: InkWell(
                            onTap: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: SvgPicture.asset(
                                obscurePassword
                                    ? 'assets/svg/eye_closed.svg'
                                    : 'assets/svg/eye_open.svg',
                                width: 13,
                                height: 13,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF000000),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(color: Colors.black26),
                          ),
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
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          suffixIcon: InkWell(
                            onTap: () => setState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: SvgPicture.asset(
                                obscureConfirm
                                    ? 'assets/svg/eye_closed.svg'
                                    : 'assets/svg/eye_open.svg',
                                width: 13,
                                height: 13,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF000000),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(color: Colors.black26),
                          ),
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
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          onPressed: isLoading ? () {} : signUp,
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'فتح حساب جديد',
                                  style: TextStyle(fontSize: 15),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        'هل لديك حساب بالفعل؟',
                        style: TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 6),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF988561),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (c) => const SignIn()),
                            );
                          },
                          child: const Text(
                            'أنقُر لتسجيل الدخول',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
