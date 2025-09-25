import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class OpenSouq extends StatefulWidget {
  const OpenSouq({super.key});

  @override
  State<OpenSouq> createState() => _OpenSouqState();
}

class _OpenSouqState extends State<OpenSouq>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<String> imageUrls = [];
  bool loading = true;
  String a = "aaa";

  int indexSelected = 0;
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
    if (!await launchUrl(url)) {
      displaySnackBar(' حدث خطأ ما:  $url', Colors.red);
      throw Exception('لم يتم تحميل الرابط بسبب الخطأ:  $url');
    }
  }

  final List<Map<dynamic, dynamic>> _itemsList = [];
  List<Map<dynamic, dynamic>> _filteredList = [];

  void _getDataFromFirebase() {
    _databaseRef
        .child('open_souq')
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
          _filteredList = List.from(_itemsList); // نسخة للعرض
          a = (_itemsList.length).toString();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _getDataFromFirebase();
    loadImages();
  }

  void loadImages() async {
    final urls = await fetchImages();
    setState(() {
      imageUrls = urls;
      loading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<String>> fetchImages() async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('otaibah_main')
        .child('navigation_menu_items')
        .child('orders');
    final listResult = await storageRef.listAll();

    final urls = await Future.wait(
      listResult.items.map((item) => item.getDownloadURL()),
    );
    return urls;
  }

  // فلترة العناصر حسب النص
  void _filterItems(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredList = List.from(_itemsList);
      });
    } else {
      setState(() {
        _filteredList = _itemsList.where((item) {
          final name = (item['name'] ?? '').toString().toLowerCase();
          final description =
          (item['description'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) ||
              description.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconWidth = MediaQuery.sizeOf(context).width / 75;
    final iconHeight = MediaQuery.sizeOf(context).height / 75;

    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                const SizedBox(height: 4),
                CarouselSlider(
                  options: CarouselOptions(
                    height: 150, // رفعنا ارتفاع السلايدر
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 5),
                    enlargeCenterPage: true,
                    viewportFraction: 1.0,
                  ),
                  items: imageUrls.map((url) {
                    return Builder(
                      builder: (BuildContext context) {
                        return GestureDetector(
                          onTap: () {
                            displaySnackBar('Done', Colors.green);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: MediaQuery.of(context).size.width,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                // مربع البحث
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterItems, // ← ربط البحث
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0x20a7a9ac),
                      hintText: "عن ماذا تبحث...",
                      prefixIcon:
                      const Icon(Icons.search, color: Colors.black38),
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(0),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    mainAxisExtent: iconHeight * 75 / 3,
                  ),
                  itemCount: _filteredList.length, // ← القائمة المفلترة
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    return GestureDetector(
                      onTap: () =>
                          displaySnackBar('تم الضغط', Colors.lime),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x20a7a9ac), // خلفية
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 140,
                                  width: double.infinity,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: item['imgUrl'],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                      const Center(
                                          child:
                                          CircularProgressIndicator()),
                                      errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['name'],
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize:
                                            MediaQuery.sizeOf(context)
                                                .height /
                                                60,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => Share.share(
                                          (item['description'] ?? '') +
                                              '\n' +
                                              'تمت مشاركة المنشور من تطبيق العتيبة..يمكنك تنزيله مجانا من الرابط www.google.com',
                                          subject: 'تطبيق رائع',
                                        ),
                                        icon: SvgPicture.asset(
                                          'assets/svg/share_post_icon.svg',
                                          width: iconWidth * 3,
                                          height: iconWidth * 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: Text(
                                    item['description'],
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                      MediaQuery.sizeOf(context).height /
                                          80,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // زر السعر
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF988561),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  item['price'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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


/* Future<void> saveLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEmailVerified', isLoggedIn);
  }*/



  /*void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        return item.toLowerCase().contains(query);
      }).toList();
    });
  }*/


                /*Padding(
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
                        // إضافة الـ elevation يعطي تأثير الظل
                        elevation: 0,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(index.toString()),
                        ),
                      );
                    },
                  ),
                ),
*/
                // مساحة فاصلة


                // القائمة العمودية (ListView.builder)
                /*ListView.builder(
                  // خصائص لمنع تضارب التمرير
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _itemsList.length,
                  itemBuilder: (context, index) {
                    final item = _itemsList[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(1.0),
                                child: Column(
                                  children: [
                                    Text(
                                      item['name'],
                                      style: TextStyle(
                                        fontSize:
                                            MediaQuery.sizeOf(context).height /
                                            50,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      item['price'],
                                      style: TextStyle(
                                        fontSize:
                                            MediaQuery.sizeOf(context).height /
                                            75,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    if (item['compromise'])
                                      Icon(CupertinoIcons.add),
                                  ],
                                ),
                              ),
                              Spacer(),
                              IconButton(
                                onPressed: () => Share.share(
                                  item['description'] +
                                      '\n' +
                                      'تمت مشاركة المنشور من تطبيق العتيبة..يمكنك تنزيله مجانا من الرابط www.google.com',
                                  subject: 'تطبيق رائع',
                                ),
                                icon: SvgPicture.asset(
                                  'assets/svg/share_post_icon.svg',
                                  width: iconWidth * 3,
                                  height: iconWidth * 3,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(item['description']),
                          SizedBox(height: 8),
                          //if (item['contentImgUrl'] != '')
                          //Image.network(item['contentImgUrl']),
                        ],
                      ),
                    );
                  },
                ),*/

