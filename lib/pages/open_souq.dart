import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/global_banner.dart';
import 'item_open_souq.dart';

class OpenSouq extends StatefulWidget {
  final String? productId;
  const OpenSouq({super.key, this.productId});

  @override
  State<OpenSouq> createState() => _OpenSouqState();
}

class _OpenSouqState extends State<OpenSouq> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<String> imageUrls = [];
  bool loading = true;

  final DatabaseReference _databaseRef =
  FirebaseDatabase.instance.ref('otaibah_navigators_taps');

  final List<Map<dynamic, dynamic>> _itemsList = [];
  List<Map<dynamic, dynamic>> _filteredList = [];
  Set<String> favoriteIds = {};

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadFavoritesFromFirebase();
    _getDataFromFirebase();
    loadImages();
  }

  /// ✅ تحميل المفضلات الخاصة بالسوق المفتوح فقط
  Future<void> _loadFavoritesFromFirebase() async {
    if (user == null) return;
    final favRef =
    FirebaseDatabase.instance.ref("open_souq_favorites/${user!.uid}");
    final snapshot = await favRef.get();
    if (snapshot.exists && snapshot.value is Map) {
      final data = snapshot.value as Map;
      setState(() {
        favoriteIds = data.keys.map((e) => e.toString()).toSet();
      });
    }
  }

  /// ✅ تحديث المفضلات في Firebase
  Future<void> _updateFavoriteInFirebase(String productId, bool add) async {
    if (user == null) return;
    final favRef = FirebaseDatabase.instance
        .ref("open_souq_favorites/${user!.uid}/$productId");
    if (add) {
      await favRef.set(true);
    } else {
      await favRef.remove();
    }
  }

  /// ✅ تحميل صور البانر
  void loadImages() async {
    final urls = await fetchImages();
    if (mounted) {
      setState(() {
        imageUrls = urls;
        loading = false;
      });
    }
  }

  Future<List<String>> fetchImages() async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('otaibah_main/navigation_menu_items/orders');
    final listResult = await storageRef.listAll();
    final urls =
    await Future.wait(listResult.items.map((item) => item.getDownloadURL()));
    return urls;
  }

  /// ✅ تحميل بيانات السوق من Firebase
  void _getDataFromFirebase() {
    _databaseRef.child('open_souq/categories/general').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data =
        event.snapshot.value as Map<dynamic, dynamic>;
        _itemsList.clear();
        data.forEach((key, value) {
          if (value is Map) {
            value['id'] = key;
            _itemsList.add(Map<dynamic, dynamic>.from(value));
          }
        });
        setState(() => _filteredList = List.from(_itemsList));
      }
    });
  }

  /// 🔍 البحث داخل المنتجات
  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredList = List.from(_itemsList);
      } else {
        _filteredList = _itemsList.where((item) {
          final name = (item['name'] ?? '').toString().toLowerCase();
          final description =
          (item['description'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) ||
              description.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  /// ❤️ تفعيل / إلغاء المفضلة
  void toggleFavorite(String productId) async {
    final isFav = favoriteIds.contains(productId);
    setState(() {
      if (isFav) {
        favoriteIds.remove(productId);
      } else {
        favoriteIds.add(productId);
      }
    });
    await _updateFavoriteInFirebase(productId, !isFav);
  }

  /// 🧭 فتح صفحة المنتج
  void _openProductPage(Map<dynamic, dynamic> item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ItemInOpenSouq(data: item),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.1, 0.0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                const SizedBox(height: 7),
                // ===== البانر =====
                const GlobalBanner(section: "open_souq"),
                const SizedBox(height: 4),

                // ===== مربع البحث =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterItems,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0x20a7a9ac),
                      hintText: "عن ماذا تبحث...",
                      hintStyle: const TextStyle(
                        color: Color(0x70000000),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        child: SvgPicture.asset(
                          'assets/svg/search.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                            Color(0x70000000),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // ===== شبكة المنتجات =====
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(0),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    mainAxisExtent: 300,
                  ),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    final isFav = favoriteIds.contains(item['id']);

                    return GestureDetector(
                      onTap: () => _openProductPage(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: const Color(0x20a7a9ac),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 180,
                                  width: double.infinity,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(7),
                                      topRight: Radius.circular(7),
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: item['imgUrl'],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                      const Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 6, left: 6, right: 6, bottom: 2),
                                  child: Text(
                                    item['name'],
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize:
                                      MediaQuery.sizeOf(context).height / 60,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  child: Text(
                                    item['description'],
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                      MediaQuery.sizeOf(context).height / 85,
                                      color: Colors.grey[900],
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // السعر
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF988561),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${item['price']} ',
                                        style: const TextStyle(
                                          color: Color(0xFFfffcee),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: 'ل.س',
                                        style: TextStyle(
                                          color: Color(0xFFfffcee),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ❤️ زر المفضلة داخل الكارد
                            Positioned(
                              top: 6,
                              left: 6,
                              child: GestureDetector(
                                onTap: () => toggleFavorite(item['id']),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    isFav
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.white,
                                    size: 17,
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
                // ✅ مسافة صغيرة أسفل آخر عنصر
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
