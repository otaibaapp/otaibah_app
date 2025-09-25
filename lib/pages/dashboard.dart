import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:otaibah_app/pages/education.dart';
import 'package:otaibah_app/pages/open_souq.dart';
import 'package:otaibah_app/pages/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../loading_dialog.dart';
import '../main.dart';
import 'announcements.dart';
import 'donations.dart';
import 'online.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  TabController? controller;
  int indexSelected = 0;

  final List<String> navigationMenuItems = [
    'announcements',
    'open_souq',
    'shopping',
    'services',
    'education',
    'donations',
  ];

  onBarItemClicked(int i) {
    setState(() {
      indexSelected = i;
      controller!.index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    double iconSize = MediaQuery.of(context).size.width * 0.06;
    double labelFontSize = MediaQuery.of(context).size.width * 0.03;

    Future<void> saveLoginStatus(bool isLoggedIn) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isEmailVerified', isLoggedIn);
    }

    void logOut() {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) =>
            LoadingDialog(msg: 'جار تسجيل الخروج'),
      );
      FirebaseAuth.instance.signOut();
      saveLoginStatus(false);
      Future.delayed(Duration.zero);
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.push(context, MaterialPageRoute(builder: (c) => const MyApp()));
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  "https://b.top4top.io/p_3510xqunk1.jpg", // رابط صورة البروفايل
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "مرحبا بك أحمد!",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          controller: controller,
          children: const [
            Announcements(),
            OpenSouq(),
            Online(),
            Services(),
            Education(),
            Donations(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(
          left: 0,    // من اليسار
          right: 0,   // من اليمين
          top: 0,     // من فوق
          bottom: 0, // من تحت
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(top: 7), // 👈 هي المسافة البيضاء فوق الأيقونة
                child: SvgPicture.asset(
                  'assets/svg/announcements_icon_enabled.svg',
                  height: iconSize,
                  width: iconSize,
                  colorFilter: ColorFilter.mode(
                    indexSelected == 0
                        ? const Color(0xFF988561)
                        : const Color(0xFF231f20),
                    BlendMode.srcIn,
                  ),
                ),
                ),
                label: "الإعلانات",
              ),
              BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 5), // 👈 هي المسافة البيضاء فوق الأيقونة
                    child: SvgPicture.asset(
                  'assets/svg/open_souq_icon_enabled.svg',
                  height: iconSize,
                  width: iconSize,
                  colorFilter: ColorFilter.mode(
                    indexSelected == 1
                        ? const Color(0xFF988561)
                        : const Color(0xFF231f20),
                    BlendMode.srcIn,
                  ),
                    ),
                ),
                label: "السوق المفتوح",
              ),
              BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 5), // 👈 هي المسافة البيضاء فوق الأيقونة
                    child: SvgPicture.asset(
                  'assets/svg/shopping_icon_enabled.svg',
                  height: iconSize,
                  width: iconSize,
                  colorFilter: ColorFilter.mode(
                    indexSelected == 2
                        ? const Color(0xFF988561)
                        : const Color(0xFF231f20),
                    BlendMode.srcIn,
                  ),
                ),
                  ),
                label: "التسوق",
              ),
              BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 5), // 👈 هي المسافة البيضاء فوق الأيقونة
                    child: SvgPicture.asset(
                  'assets/svg/services_icon_enabled.svg',
                  height: iconSize,
                  width: iconSize,
                  colorFilter: ColorFilter.mode(
                    indexSelected == 3
                        ? const Color(0xFF988561)
                        : const Color(0xFF231f20),
                    BlendMode.srcIn,
                  ),
                ),
                  ),
                label: "الخدمات",
              ),
              BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 5), // 👈 هي المسافة البيضاء فوق الأيقونة
                    child: SvgPicture.asset(
                  'assets/svg/education_icon_enabled.svg',
                  height: iconSize,
                  width: iconSize,
                  colorFilter: ColorFilter.mode(
                    indexSelected == 4
                        ? const Color(0xFF988561)
                        : const Color(0xFF231f20),
                    BlendMode.srcIn,
                  ),
                ),
                  ),
                label: "التعليم",
              ),
              BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 5), // 👈 هي المسافة البيضاء فوق الأيقونة
                    child: SvgPicture.asset(
                  'assets/svg/free_stuffs_nav_bar_icon.svg',
                  height: iconSize,
                  width: iconSize,
                  colorFilter: ColorFilter.mode(
                    indexSelected == 5
                        ? const Color(0xFF988561)
                        : const Color(0xFF231f20),
                    BlendMode.srcIn,
                  ),
                ),
                  ),
                label: "ببلاش",
              ),
            ],
            currentIndex: indexSelected,
            unselectedItemColor: const Color(0xFF231f20),
            selectedItemColor: const Color(0xFF988561),
            selectedLabelStyle: TextStyle(
              fontSize: labelFontSize * 1.0,
              fontWeight: FontWeight.w400,
              height: 1.8,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: labelFontSize,
              fontWeight: FontWeight.w400,
              height: 1.8,
            ),
            type: BottomNavigationBarType.fixed,
            onTap: (i) {
              setState(() {
                indexSelected = i;
                controller!.index = i;
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    controller!.dispose();
    super.dispose();
  }
}
