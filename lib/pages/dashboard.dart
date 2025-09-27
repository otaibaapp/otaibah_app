import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:otaibah_app/pages/education.dart';
import 'package:otaibah_app/pages/open_souq.dart';
import 'package:otaibah_app/pages/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../loading_dialog.dart';
import '../main.dart';
import 'Shopping.dart';
import 'announcements.dart';
import 'announcements_favorites_page.dart'; // ✅ زر المفضلة يفتح هذه الصفحة
import 'donations.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  TabController? controller;
  int indexSelected = 0;

  // ✅ مسار أيقونة المفضلة (غيّره لأي SVG عندك داخل assets/svg)
  static const String _favSvgPath = 'assets/svg/favorite_outline.svg';

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
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFf6f6f6), // ✅ لون الخلفية العام
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // ✅ شفاف ليظهر اللون الخلفي
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFf6f6f6), // ✅ نفس اللون للخلفية تحت الـ AppBar
          ),
        ),
        // ✅ عنوان مع توزيع العناصر: يمين (الصورة + الترحيب) / يسار (زر المفضلة عند تبويب الإعلانات)
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ▸ يمين: صورة البروفايل + النص
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.network(
                      "https://l.top4top.io/p_3556413iu1.png",
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "مرحبا بك أحمد...!",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // ▸ يسار: زر المفضلة (يظهر فقط عند تبويب الإعلانات)
              if (indexSelected == 0)
                IconButton(
                  tooltip: 'المفضلة',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AnnouncementsFavoritesPage(),
                      ),
                    );
                  },
                  icon: SvgPicture.asset(
                    _favSvgPath, // 🔸 غيّر المسار لأي SVG تحبه من مجلدك
                    width: 25,
                    height: 25,
                    colorFilter: const ColorFilter.mode(
                      Colors.black87,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // ❌ ما عاد نستخدم actions — لأن الزر صار داخل العنوان نفسه (يسار الصورة)
        actions: null,
      ),

      // ✅ الجسم كامل بنفس لون الخلفية
      body: Container(
        color: const Color(0xFFf6f6f6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: controller,
            children: const [
              Announcements(),
              OpenSouq(),
              Shopping(),
              Services(),
              Education(),
              Donations(),
            ],
          ),
        ),
      ),

      // ✅ شريط التنقل السفلي بلون خلفية f6f6f6
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFf6f6f6), // ✅ اللون الجديد المطلوب
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 0,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent, // ✅ لظهور الخلفية
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(top: 7),
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
                  padding: const EdgeInsets.only(top: 5),
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
                  padding: const EdgeInsets.only(top: 5),
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
                  padding: const EdgeInsets.only(top: 5),
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
                  padding: const EdgeInsets.only(top: 5),
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
                  padding: const EdgeInsets.only(top: 5),
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
