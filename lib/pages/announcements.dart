import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class Announcements extends StatefulWidget {
  const Announcements({super.key});

  @override
  State<Announcements> createState() => _AnnouncementsState();
}

class _AnnouncementsState extends State<Announcements>
    with SingleTickerProviderStateMixin {
  List<String> imageUrls = [];
  bool loading = true;
  double get iconWidth => MediaQuery.sizeOf(context).width / 75;
  double get iconHeight => MediaQuery.sizeOf(context).height / 75;

  final TextEditingController _searchController = TextEditingController();
  List<Map<dynamic, dynamic>> _itemsList = [];
  List<Map<dynamic, dynamic>> _filteredList = [];

  final DatabaseReference _databaseRef =
  FirebaseDatabase.instance.ref('otaibah_navigators_taps');

  void displaySnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      displaySnackBar(' حدث خطأ ما:  $url', Colors.red);
      throw Exception('لم يتم تحميل الرابط بسبب الخطأ:  $url');
    }
  }

  void _getDataFromFirebase() {
    _databaseRef
        .child('announcements')
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
          _filteredList = _itemsList;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _getDataFromFirebase();
    loadImages();
    _searchController.addListener(() {
      _filterItems(_searchController.text);
    });
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredList = _itemsList;
      } else {
        _filteredList = _itemsList
            .where((item) =>
        item['content']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()) ||
            item['source']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    });
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
    final urls =
    await Future.wait(listResult.items.map((item) => item.getDownloadURL()));
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 4),

                // ==== البانر
                CarouselSlider(
                  options: CarouselOptions(
                    height: 150,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 5),
                    enlargeCenterPage: true,
                    viewportFraction: 1.0,
                  ),
                  items: imageUrls.map((url) {
                    return Builder(
                      builder: (BuildContext context) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(7),
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
                        );
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                // ==== مربع البحث
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      hintText: "عن ماذا تبحث...",
                      prefixIcon: const Icon(Icons.search, color: Colors.black38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // ==== المنشورات
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    return Card(
                      margin:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                      clipBehavior: Clip.antiAlias,
                      elevation: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ===== الهيدر
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundImage:
                                  NetworkImage(item['sourceImageUrl']),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['source'],
                                        style: TextStyle(
                                          fontSize: MediaQuery.sizeOf(context)
                                              .height /
                                              50,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['dateOfPost'],
                                        style: TextStyle(
                                          fontSize: MediaQuery.sizeOf(context)
                                              .height /
                                              75,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Share.share(
                                    '${item['content']}\nتمت مشاركة المنشور من تطبيق العتيبة..يمكنك تنزيله مجانا من الرابط www.google.com',
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

                          const SizedBox(height: 8),

                          // ===== النص الأساسي
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              item['content'],
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ===== صورة المحتوى مع كل المزايا
                          if (item['contentImgUrl'] != '')
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      opaque: false,
                                      transitionDuration:
                                      const Duration(milliseconds: 300),
                                      pageBuilder: (_, __, ___) => GestureDetector(
                                        onVerticalDragUpdate: (details) {
                                          if (details.primaryDelta! > 20 ||
                                              details.primaryDelta! < -20) {
                                            Navigator.pop(context);
                                          }
                                        },
                                        onTap: () {
                                          Navigator.pop(context);
                                        },
                                        child: Scaffold(
                                          backgroundColor: Colors.black,
                                          appBar: AppBar(
                                            backgroundColor:
                                            Colors.black.withOpacity(0.3),
                                            elevation: 0,
                                            leading: IconButton(
                                              icon: const Icon(Icons.arrow_back,
                                                  color: Colors.white),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                            ),
                                          ),
                                          body: Center(
                                            child: Hero(
                                              tag: item['contentImgUrl'],
                                              child: InteractiveViewer(
                                                panEnabled: true,
                                                minScale: 0.5,
                                                maxScale: 4.0,
                                                child: Image.network(
                                                  item['contentImgUrl'],
                                                  fit: BoxFit.contain,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Hero(
                                  tag: item['contentImgUrl'],
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      item['contentImgUrl'],
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, progress) {
                                        if (progress == null) return child;
                                        return const SizedBox(
                                          height: 160,
                                          child: Center(
                                            child:
                                            CircularProgressIndicator(),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),

                          // ===== زر الرابط
                          if (item['buttonContentUrl'] != '')
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 0, 12, 12),
                              child: Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () =>
                                        _launchURL(item['buttonContentUrl']),
                                    style: ButtonStyle(
                                      foregroundColor:
                                      WidgetStateProperty.all<Color>(
                                          Colors.white),
                                      backgroundColor:
                                      WidgetStateProperty.all<Color>(
                                          const Color(0xFF988561)),
                                      padding:
                                      WidgetStateProperty.all<EdgeInsets>(
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                      shape: WidgetStateProperty.all<
                                          RoundedRectangleBorder>(
                                        RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                    icon: SvgPicture.asset(
                                      'assets/svg/link_post_icon.svg',
                                      width: iconWidth - iconWidth / 6,
                                      height: iconHeight - iconHeight / 6,
                                    ),
                                    label: Text(item['buttonContent']),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
