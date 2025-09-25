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
  //final TextEditingController _searchController = TextEditingController();
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

  //bool _isLoading = true;
  // قائمة لحفظ البيانات
  final List<Map<dynamic, dynamic>> _itemsList = [];

  // دالة لإضافة عنصر جديد

  void _getDataFromFirebase() {
    // الاستماع للتغييرات في قاعدة البيانات
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
              a = (_itemsList.length).toString();
              //_isLoading = false;
            });
          }
        });
  }

  //List<String> _filteredItems = [];
  @override
  void initState() {
    super.initState();
    //_filteredItems = _allItems;
    //_searchController.addListener(_filterItems);
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

  /* Future<void> saveLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEmailVerified', isLoggedIn);
  }*/

  @override
  void dispose() {
    //_searchController.dispose();
    super.dispose();
  }

  /*void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        return item.toLowerCase().contains(query);
      }).toList();
    });
  }*/
  Future<List<String>> fetchImages() async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('otaibah_main')
        .child('navigation_menu_items')
        .child('orders');
    final listResult = await storageRef.listAll();

    // تحويل الملفات إلى روابط تحميل
    final urls = await Future.wait(
      listResult.items.map((item) => item.getDownloadURL()),
    );
    return urls;
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
                SizedBox(height: 4),
                CarouselSlider(
                  options: CarouselOptions(
                    height: 100, // ارتفاع السلايدر
                    autoPlay: true, // تشغيل تلقائي
                    autoPlayInterval: const Duration(seconds: 5), // كل 4 ثواني
                    enlargeCenterPage: true, // تكبير الصورة النشطة قليلاً
                    viewportFraction: 1.0, // يعرض صورة واحدة فقط
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
                                return Center(
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
                const SizedBox(height: 8),

                GridView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 🔹 عنصرين في كل صف
                    crossAxisSpacing: 6, // مسافة أفقية بين العناصر
                    mainAxisSpacing: 6, // مسافة عمودية بين العناصر
                    mainAxisExtent: iconHeight * 75 / 3,
                  ),
                  itemCount: _itemsList.length,
                  itemBuilder: (context, index) {
                    /*final data =
                        _itemsList as Map<String, dynamic>;
                    final title = data['title'] ?? 'بدون عنوان';
                    final description = data['description'] ?? '';
                    final price = data['price'] ?? 0;
                    final isAvailable = data['isAvailable'] ?? false;*/

                    return GestureDetector(
                      onTap: () => displaySnackBar('تم الضغط', Colors.lime),
                      child: Container(
                        //height: iconHeight * 75 / 3,
                        color: Colors.grey[200],
                        child: Column(
                          children: [
                            SizedBox(
                              height: 140,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  child: CachedNetworkImage(
                                    imageUrl: _itemsList[index]['imgUrl'],
                                    fit: BoxFit.fill,
                                    placeholder: (context, url) =>
                                        CircularProgressIndicator(),
                                    errorWidget: (context, url, error) =>
                                        Icon(Icons.error),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(1.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        _itemsList[index]['name'],
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize:
                                              MediaQuery.sizeOf(
                                                context,
                                              ).height /
                                              60,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      //if (_itemsList[index]['compromise'])
                                      //Icon(CupertinoIcons.add),
                                    ],
                                  ),
                                ),
                                Spacer(),
                                IconButton(
                                  onPressed: () => Share.share(
                                    _itemsList[index]['description'] +
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
                            Text(
                              _itemsList[index]['description'],
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.sizeOf(context).height / 75,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            Text(
                              _itemsList[index]['price'],
                              style: TextStyle(
                                backgroundColor: Color(0xFF988561),
                                fontSize:
                                    MediaQuery.sizeOf(context).height / 75,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
