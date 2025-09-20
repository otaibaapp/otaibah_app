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
  List<String> navigation_menu_items = [
    'ads',
    'shop',
    'orders',
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
    double widthOfTabBar = MediaQuery.sizeOf(context).width / 7;
    double heightOfTabBar = MediaQuery.sizeOf(context).height / 25;
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
      Navigator.push(context, MaterialPageRoute(builder: (c) => MyApp()));
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 4,
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  "https://b.top4top.io/p_3510xqunk1.jpg", // رابط صورة البروفايل
                ),
              ),
              SizedBox(width: 8),
              Text(
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
          physics: NeverScrollableScrollPhysics(),
          controller: controller,
          children: [
            Announcements(),
            OpenSouq(),
            Online(),
            Services(),
            Education(),
            Donations(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/svg/announcements_icon_enabled.svg',
              height: heightOfTabBar,
              width: widthOfTabBar,
              colorFilter: ColorFilter.mode(
                indexSelected == 0 ? Color(0xFF988561) : Color(0xFF231f20),
                BlendMode.srcIn,
              ),
            ),
            label: "الإعلانات",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/svg/open_souq_icon_enabled.svg',
              height: heightOfTabBar,
              width: widthOfTabBar,
              colorFilter: ColorFilter.mode(
                indexSelected == 1 ? Color(0xFF988561) : Color(0xFF231f20),
                BlendMode.srcIn,
              ),
            ),
            label: "السوق المفتوح",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/svg/shopping_icon_enabled.svg',
              height: heightOfTabBar,
              width: widthOfTabBar,
              colorFilter: ColorFilter.mode(
                indexSelected == 2 ? Color(0xFF988561) : Color(0xFF231f20),
                BlendMode.srcIn,
              ),
            ),
            label: "اونلاين",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/svg/services_icon_enabled.svg',
              height: heightOfTabBar,
              width: widthOfTabBar,
              colorFilter: ColorFilter.mode(
                indexSelected == 3 ? Color(0xFF988561) : Color(0xFF231f20),
                BlendMode.srcIn,
              ),
            ),
            label: "الخدمات",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/svg/education_icon_enabled.svg',
              height: heightOfTabBar,
              width: widthOfTabBar,
              colorFilter: ColorFilter.mode(
                indexSelected == 4 ? Color(0xFF988561) : Color(0xFF231f20),
                BlendMode.srcIn,
              ),
            ),
            label: "التعليم",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/svg/free_stuffs_nav_bar_icon.svg',
              height: heightOfTabBar,
              width: widthOfTabBar,
              colorFilter: ColorFilter.mode(
                indexSelected == 5 ? Color(0xFF988561) : Color(0xFF231f20),
                BlendMode.srcIn,
              ),
            ),
            label: "التبرعات",
          ),
        ],

        currentIndex: indexSelected,
        unselectedItemColor: Color(0xFF231f20),
        selectedItemColor: Color(0xFF988561),
        showSelectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        onTap: (i) => {
          setState(() {
            indexSelected = i;
            controller!.index = i;
          }),
        },
      ),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    controller = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    controller!.dispose();
    super.dispose();
  }
}
