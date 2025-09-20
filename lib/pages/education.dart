import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class Education extends StatefulWidget {
  const Education({super.key});

  @override
  State<Education> createState() => _EducationState();
}

class _EducationState extends State<Education>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String a = "aaa";
  double get iconWidth => MediaQuery.sizeOf(context).width / 65;
  double get iconHeight => MediaQuery.sizeOf(context).height / 65;
  int indexSelected = 0;
  final String firebaseKey = 'otaibah_navigators_taps';
  void displaySnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref(
    'otaibah_navigators_taps',
  );
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      displaySnackBar(' حدث خطأ ما  $url', Colors.red);
      throw Exception('Could not launch $url');
    }
  }

  // قائمة لحفظ البيانات
  List<Map<dynamic, dynamic>> _itemsList = [];

  // دالة لإضافة عنصر جديد

  void _getDataFromFirebase() {
    // الاستماع للتغييرات في قاعدة البيانات
    _databaseRef
        .child('education')
        .child('categories')
        .child('general')
        .onValue
        .listen((event) {
          if (event.snapshot.value != null) {
            final Map<dynamic, dynamic> data =
                event.snapshot.value as Map<dynamic, dynamic>;
            _itemsList.clear();
            data.forEach((key, value) {
              _itemsList.add(value);
            });
            setState(() {
              a = (_itemsList.length).toString();
            });
          }
        });
  }

  List<String> _filteredItems = [];
  @override
  void initState() {
    super.initState();
    //_filteredItems = _allItems;
    _searchController.addListener(_filterItems);
    _getDataFromFirebase();
  }

  Future<void> saveLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEmailVerified', isLoggedIn);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      /*_filteredItems = _allItems.where((item) {
        return item.toLowerCase().contains(query);
      }).toList();*/
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      7.0,
                    ), // تحديد نصف قطر الدوران
                  ),
                  // إضافة الـ elevation يعطي تأثير الظل
                  elevation: 0,
                  margin: const EdgeInsets.all(8.0),
                  child: Column(
                    // لضبط حجم Card بناءً على محتواه
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // عرض الصورة من الإنترنت
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Image.network(
                          height: MediaQuery.sizeOf(context).height / 6,
                          "https://b.top4top.io/p_3510xqunk1.jpg",
                          fit: BoxFit.cover, // لجعل الصورة تغطي المساحة المتاحة
                          // يمكنك إضافة placeholder أو مؤشر تحميل
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return SizedBox(
                              height:
                                  MediaQuery.sizeOf(context).height /
                                  6, // يمكنك تعديل الارتفاع
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "عن ماذا تبحث؟",
                      icon: Icon(CupertinoIcons.search),
                    ),
                  ),
                ),
                SizedBox(
                  height: 45, // حدد ارتفاع للقائمة الأفقية
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    // خصائص لمنع تضارب التمرير
                    shrinkWrap: true,
                    physics:
                        const ClampingScrollPhysics(), // يسمح بالتمرير الأفقي
                    itemCount: 100,
                    itemBuilder: (context, index) {
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            7.0,
                          ), // تحديد نصف قطر الدوران
                        ),
                        //  الـ elevation يعطي تأثير الظل
                        elevation: 0,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(index.toString()),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // القائمة العمودية (ListView.builder)
                ListView.builder(
                  // خصائص لمنع تضارب التمرير
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _itemsList.length,
                  itemBuilder: (context, index) {
                    final item = _itemsList[index];
                    return Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: iconWidth * 8,
                              height: iconWidth * 8,
                              child: CircleAvatar(
                                radius: 4,
                                backgroundImage: NetworkImage(
                                  item['sourceImageUrl'],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(1.0),
                              child: Column(
                                children: [
                                  Text(
                                    item['source'],
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.sizeOf(context).height /
                                          50,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    item['dateOfPost'],
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.sizeOf(context).height /
                                          75,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(item['content']),
                        SizedBox(height: 8),
                        if (item['contentImgUrl'] != '')
                          Image.network(item['contentImgUrl']),
                        SizedBox(height: 20),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: [
                              if (item['buttonContentUrl'] != '')
                                TextButton.icon(
                                  onPressed: () {
                                    _launchURL(item['buttonContentUrl']);
                                  },
                                  style: ButtonStyle(
                                    foregroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Colors.white,
                                        ),
                                    backgroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Color(0xFF988561),
                                        ),
                                  ),
                                  label: Text(item['buttonContent']),
                                  icon: SvgPicture.asset(
                                    'assets/svg/link_post_icon.svg',
                                    width: iconWidth - iconWidth / 6,
                                    height: iconHeight - iconHeight / 6,
                                  ),
                                ),
                              Spacer(),
                              SvgPicture.asset(
                                'assets/svg/share_post_icon.svg',
                                width: iconWidth,
                                height: iconHeight,
                              ),
                              SizedBox(width: 12),
                              Text(item['numberOfComments'].toString()),
                              SizedBox(width: 8),
                              SvgPicture.asset(
                                'assets/svg/comment_like_icon.svg',
                                width: iconWidth,
                                height: iconHeight,
                              ),
                              SizedBox(width: 12),
                              Text(
                                item['numberOfLoved'].toString(),
                                style: TextStyle(color: Colors.black),
                              ),
                              SizedBox(width: 8),
                              SvgPicture.asset(
                                'assets/svg/empty_like_icon.svg',
                                width: iconWidth,
                                height: iconHeight,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
