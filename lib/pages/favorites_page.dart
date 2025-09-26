import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'item_open_souq.dart';

class FavoritesPage extends StatefulWidget {
  final List<Map<dynamic, dynamic>> favorites;
  const FavoritesPage({super.key, required this.favorites});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late List<Map<dynamic, dynamic>> _favorites;
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// 🧠 تحميل المفضلات من Firebase للمستخدم الحالي
  Future<void> _loadFavorites() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _db.child('users/${user.uid}/favorites');
    final snapshot = await userRef.get();

    final List<Map<dynamic, dynamic>> firebaseFavorites = [];
    if (snapshot.value != null) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        if (value is Map) firebaseFavorites.add(Map<String, dynamic>.from(value));
      });
    }

    setState(() {
      // دمج بين Firebase و SharedPreferences (لو فيه بيانات محلية)
      _favorites = {...{for (var f in firebaseFavorites) f['id']: f},
        ...{for (var f in widget.favorites) f['id']: f}}.values.toList();
    });

    // حفظ نسخة محلية لتسريع التحميل لاحقًا
    _saveFavoritesLocally();
  }

  /// 💾 حفظ نسخة من المفضلة في SharedPreferences (محليًا فقط)
  Future<void> _saveFavoritesLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _favorites.map((item) => json.encode(item)).toList();
    await prefs.setStringList('favorites', encoded);
  }

  /// 🗑️ إزالة منتج من المفضلة (Firebase + محليًا)
  Future<void> _removeFavorite(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // حذف من Firebase
    await _db.child('users/${user.uid}/favorites/$id').remove();

    // حذف من القائمة المحلية
    setState(() {
      _favorites.removeWhere((item) => item['id'] == id);
    });

    await _saveFavoritesLocally();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("تمت إزالة المنتج من المفضلة"),
        backgroundColor: Colors.black.withOpacity(0.8),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 🔗 فتح صفحة المنتج
  void _openProduct(Map<dynamic, dynamic> item) {
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
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // ✅ شريط علوي بنفس شكل السوق المفتوح
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: AssetImage('assets/images/profile.png'),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "مرحبًا بك يا أحمد!",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    // 🔙 زر الرجوع
                    IconButton(
                      tooltip: "رجوع",
                      icon: const Icon(Icons.arrow_forward_ios,
                          color: Colors.black87, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              Expanded(
                child: _favorites.isEmpty
                    ? const Center(
                  child: Text(
                    "لا توجد منتجات في المفضلة بعد.",
                    style: TextStyle(fontSize: 16),
                  ),
                )
                    : GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    mainAxisExtent: 300,
                  ),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final item = _favorites[index];
                    return GestureDetector(
                      onTap: () => _openProduct(item),
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
                                      color: Colors.grey[800],
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

                            // ❤️ زر الإزالة من المفضلة (Firebase + محلي)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: GestureDetector(
                                onTap: () => _removeFavorite(item['id']),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(
                                    Icons.favorite,
                                    color: Colors.white,
                                    size: 20,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
