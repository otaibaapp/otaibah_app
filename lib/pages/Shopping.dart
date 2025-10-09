import 'dart:convert';
import 'dart:ui'; // 👈 للـ ImageFilter.blur
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/skeletons/shopping_skeleton.dart';
import 'app_identity.dart';
import 'shop_page.dart';
import 'package:otaibah_app/widgets/otaibah_skeleton.dart';
import 'my_orders_page.dart';

import '../core/global_skeleton_wrapper.dart';
import '../widgets/skeletons/shopping_skeleton.dart';


class Shopping extends StatefulWidget {
  const Shopping({super.key});

  @override
  State<Shopping> createState() => _ShoppingState();
}

class _ShoppingState extends State<Shopping>
    with SingleTickerProviderStateMixin {
  // ===== بيانات الواجهة =====
  List<String> imageUrls = [];
  List<dynamic> shopsCategoryNames = [];
  List<dynamic> shopsWithAllDetails = [];
  List<dynamic> shopsNames = [];
  List<Map<dynamic, dynamic>> shopsDetails = [];

  double get iconWidth => MediaQuery.sizeOf(context).width / 75;
  double get iconHeight => MediaQuery.sizeOf(context).height / 75;

  final TextEditingController _searchController = TextEditingController();
  List<Map<dynamic, dynamic>> _itemsList = [];
  List<Map<dynamic, dynamic>> _filteredList = [];

  // ===== مراجع قاعدة البيانات =====
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref(
    'otaibah_navigators_taps',
  );

  // ===== هوية المستخدم (UID أو deviceId) =====
  String? _userId;

  // ===== كاش محلي (مفاتيح المنشورات فقط) =====
  // نستخدم Sets للسرعة في التحقق
  Set<String> _cachedFavIds = <String>{};
  Set<String> _cachedLikedIds = <String>{};
  Map<String, int> _cachedLikeCounts = <String, int>{};

  // مفاتيح التخزين
  String get _kPostsKey => 'ann_cache_posts';
  String get _kFavKey => 'ann_cache_favs_${_userId ?? "guest"}';
  String get _kLikeKey => 'ann_cache_likes_${_userId ?? "guest"}';
  String get _kLikeCountsKey => 'ann_cache_like_counts';

  // ===== دوال مساعدة عامة =====
  void displaySnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      displaySnackBar('حدث خطأ أثناء فتح الرابط: $url', Colors.red);
    }
  }

  // ===== تحميل البيانات من Firebase =====
  void _listenAnnouncementsRealtime() {
    _databaseRef
        .child('shopping')
        .child('categories')
        .child('general')
        .onValue
        .listen((event) async {
          if (event.snapshot.value != null) {
            final Map<dynamic, dynamic> data =
                event.snapshot.value as Map<dynamic, dynamic>;
            final List<Map<dynamic, dynamic>> tmp = [];
            data.forEach((key, value) {
              final map = Map<dynamic, dynamic>.from(value);
              map['id'] = key;
              tmp.add(map);
            });
            // تحديث الواجهة
            setState(() {
              _itemsList = tmp;
              _filteredList = _itemsList;
            });
            // حفظ كاش للمنشورات (Minimal fields)
            await _savePostsCache(tmp);
          }
        });
  }

  // الاستماع لمفضلة المستخدم كاملة لتحديث الكاش (تزامن لحظي)
  void _listenFavoritesRealtime() {
    if (_userId == null) return;
    _databaseRef.child('favorites').child(_userId!).onValue.listen((
      event,
    ) async {
      final favMap = (event.snapshot.value as Map?) ?? {};
      final ids = favMap.keys.map((e) => e.toString()).toSet();
      setState(() => _cachedFavIds = ids);
      await _saveFavoritesCache();
    });
  }

  // ملاحظة: لا نستمع لكل إعجابات كل المنشورات (قد تكون كبيرة).
  // نحدّث الكاش محلياً عند تغييرات المستخدم (toggle) ونحدّث العدادات من كل بطاقة على حدة.
  // هذا توازن ممتاز بين الأداء والدقة.
  // ========

  // ===== دورة حياة =====
  @override
  void initState() {
    super.initState();
    _bootstrap();
    _getCategories();
  }

  // ✅ فلترة حسب القسم
  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;

      if (category == null) {
        // نادرًا ما نستخدم null الآن، لكنها fallback
        _visibleShops = List<Map<dynamic, dynamic>>.from(shopsDetails);
        return;
      }

      if (category == "مختارة لك") {
        _visibleShops = shopsDetails.where((m) {
          final s = m['order']?.toString().trim() ?? "";
          return s.isNotEmpty && int.tryParse(s) != null;
        }).toList()
          ..sort((a, b) {
            final ao = int.tryParse(a['order'].toString()) ?? 9999;
            final bo = int.tryParse(b['order'].toString()) ?? 9999;
            return ao.compareTo(bo);
          });
        return;
      }

      // فلترة حسب الفئة الأصلية
      _visibleShops = shopsDetails
          .where((shop) => shop['category']?.toString() == category)
          .toList()
        ..sort((a, b) {
          final ao = int.tryParse(a['order']?.toString() ?? "") ?? 9999;
          final bo = int.tryParse(b['order']?.toString() ?? "") ?? 9999;
          return ao.compareTo(bo);
        });
    });
  }


  // ✅ بحث حسب الاسم أو الوصف
  void _filterSearch(String query) {
    final lower = query.toLowerCase();

    // حدّد القائمة الأساسية بحسب التبويب المختار
    List<Map<dynamic, dynamic>> base;
    if (_selectedCategory == null) {
      base = List<Map<dynamic, dynamic>>.from(shopsDetails);
    } else if (_selectedCategory == "مختارة لك") {
      base = shopsDetails.where((m) {
        final s = m['order']?.toString().trim() ?? "";
        return s.isNotEmpty && int.tryParse(s) != null;
      }).toList();
    } else {
      base = shopsDetails
          .where((m) => m['category']?.toString() == _selectedCategory)
          .toList();
    }

    setState(() {
      if (lower.isEmpty) {
        _visibleShops = base;
      } else {
        _visibleShops = base.where((m) {
          final name = m['name']?.toString().toLowerCase() ?? "";
          return name.contains(lower);
        }).toList();
      }
    });
  }



  Future<void> _bootstrap() async {
    // 1) نحصل على هوية المستخدم (UID أو deviceId)
    _userId = await AppIdentity.getStableUserId();

    // 2) نحمّل الكاش ونظهره فوراً (صامت)
    await _loadCacheAndShow();

    // 3) نبدأ الاستماع للتحديثات الحية لتحديث الواجهة + تحديث الكاش
    _listenAnnouncementsRealtime();
    _listenFavoritesRealtime();

    // 4) تحميل صور البانر (لا حاجة لكاشها هنا)
    _loadBannerImages();

    // 5) بحث محلي
    _searchController.addListener(() {
      _filterSearch(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===== تحميل/حفظ الكاش =====
  Future<void> _loadCacheAndShow() async {
    final prefs = await SharedPreferences.getInstance();

    // المنشورات
    final postsJson = prefs.getString(_kPostsKey);
    if (postsJson != null && postsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(postsJson);
        final List<Map<dynamic, dynamic>> localPosts = decoded
            .whereType<Map>()
            .map((m) => Map<dynamic, dynamic>.from(m))
            .toList();
        setState(() {
          _itemsList = localPosts;
          _filteredList = _itemsList;
        });
      } catch (_) {}
    }

    // المفضلة
    final favList = prefs.getStringList(_kFavKey) ?? <String>[];
    _cachedFavIds = favList.toSet();

    // إعجابات المستخدم
    final likeList = prefs.getStringList(_kLikeKey) ?? <String>[];
    _cachedLikedIds = likeList.toSet();

    // عدادات الإعجابات
    final countsJson = prefs.getString(_kLikeCountsKey);
    if (countsJson != null && countsJson.isNotEmpty) {
      try {
        final Map<String, dynamic> m = Map<String, dynamic>.from(
          jsonDecode(countsJson),
        );
        _cachedLikeCounts = m.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _savePostsCache(List<Map<dynamic, dynamic>> posts) async {
    final prefs = await SharedPreferences.getInstance();
    // نحفظ فقط الحقول المستخدمة في الواجهة لتقليل الحجم
    final minimized = posts.map((p) {
      return {
        'id': p['id'],
        'content': p['content'],
        'contentImgUrl': p['contentImgUrl'],
        'source': p['source'],
        'sourceImageUrl': p['sourceImageUrl'],
        'dateOfPost': p['dateOfPost'],
        'shareUrl': p['shareUrl'],
      };
    }).toList();
    await prefs.setString(_kPostsKey, jsonEncode(minimized));
  }

  Future<void> _saveFavoritesCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavKey, _cachedFavIds.toList());
  }

  Future<void> _saveLikesCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLikeKey, _cachedLikedIds.toList());
    await prefs.setString(_kLikeCountsKey, jsonEncode(_cachedLikeCounts));
  }

  // ===== بنرات الصور =====
  void _loadBannerImages() async {
    final urls = await _fetchBannerImages();
    setState(() {
      imageUrls = urls;
    });
  }




  Future<List<String>> _fetchBannerImages() async {
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

  // ===== البحث =====
  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredList = _itemsList;
      } else {
        _filteredList = _itemsList
            .where(
              (item) =>
                  item['content'].toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  item['source'].toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
      }
    });
  }

  // ===== Viewer ملء الشاشة مع blur + zoom + إغلاق =====
  void _openImageFullscreen(String imageUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'image_view',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.black.withOpacity(0.25)),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 1.0,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(100),
                    child: Center(
                      child: Hero(
                        tag: imageUrl,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.white70,
                              size: 80,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'إغلاق',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ====== عمليات المفضلة والإعجاب ======
  DatabaseReference _favRefFor(String userId, String postId) {
    return _databaseRef.child('favorites').child(userId).child(postId);
  }

  DatabaseReference _likeUsersRefFor(String postId) {
    return _databaseRef
        .child('announcement_likes')
        .child(postId)
        .child('users');
  }

  Future<void> _toggleFavorite(String postId, bool isFav) async {
    final uid = _userId;
    if (uid == null) return;
    final ref = _favRefFor(uid, postId);
    if (isFav) {
      await ref.remove();
      _cachedFavIds.remove(postId);
    } else {
      await ref.set(true);
      _cachedFavIds.add(postId);
    }
    await _saveFavoritesCache(); // ✅ تحديث الكاش
    if (mounted) setState(() {});
  }

  Future<void> _toggleLike(String postId, bool isLiked) async {
    final uid = _userId;
    if (uid == null) return;
    final usersRef = _likeUsersRefFor(postId);
    if (isLiked) {
      await usersRef.child(uid).remove();
      _cachedLikedIds.remove(postId);
      // نقص العداد محلياً
      final current = _cachedLikeCounts[postId] ?? 0;
      _cachedLikeCounts[postId] = (current - 1).clamp(0, 1 << 31);
    } else {
      await usersRef.child(uid).set(true);
      _cachedLikedIds.add(postId);
      // زد العداد محلياً
      final current = _cachedLikeCounts[postId] ?? 0;
      _cachedLikeCounts[postId] = current + 1;
    }
    await _saveLikesCache(); // ✅ تحديث الكاش
    if (mounted) setState(() {});
  }

  String? _selectedCategory; // القسم الحالي المختار
  List<Map<dynamic, dynamic>> _visibleShops = []; // المتاجر المعروضة بعد الفلترة والبحث

  String a = '';

  Future<void> _getCategories() async {
    shopsDetails.clear();
    shopsCategoryNames.clear();

    // ✅ "مختارة لك" ثابتة دائمًا كأول تبويب (قائمة افتراضية)
    shopsCategoryNames.add("مختارة لك");

    // 🔹 حمّل الفئات من Firebase
    final catsEvent = await _databaseRef.child('shopping').child('categories').once();
    final catsMap = catsEvent.snapshot.value as Map?;
    final List<String> allCats = catsMap == null
        ? []
        : catsMap.keys.map((e) => e.toString()).toList()..sort((a, b) => a.compareTo(b));

    // أضف باقي الفئات بعد "مختارة لك"
    // نتأكد ما نكرّر "مختارة لك" لو كانت موجودة فعلاً داخل الفايربيز
    for (final c in allCats) {
      if (c != "مختارة لك") {
        shopsCategoryNames.add(c);
      }
    }

    // 🔹 حمّل المتاجر من كل فئة
    final List<Map<dynamic, dynamic>> allStores = [];
    for (final cat in allCats) {
      final snap = await _databaseRef.child("shopping").child("categories").child(cat).get();
      if (!snap.exists) continue;

      final raw = Map<dynamic, dynamic>.from(snap.value as Map);
      raw.forEach((id, val) {
        if (val is! Map) return; // ← تجاهل مفاتيح مثل "_init": true
        final m = Map<dynamic, dynamic>.from(val as Map);
        m['id'] = id.toString();
        // ثبّت الفئة داخل المتجر لو غير موجودة
        m['category'] = (m['category']?.toString().isNotEmpty ?? false) ? m['category'] : cat;
        allStores.add(m);
      });
    }

    // 🔹 ترتيب عام حسب order (القيم الفارغة تروح آخر شي)
    int asOrder(Map m) {
      final v = m['order'];
      if (v == null) return 9999;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 9999;
    }
    allStores.sort((a, b) => asOrder(a).compareTo(asOrder(b)));

    // ✅ المتاجر المميزة "مختارة لك" = كل متجر عنده order رقمي
    final List<Map<dynamic, dynamic>> featured = allStores.where((m) {
      final o = m['order'];
      if (o == null) return false;
      final s = o.toString().trim();
      return s.isNotEmpty && int.tryParse(s) != null;
    }).toList()
      ..sort((a, b) {
        final ao = int.tryParse(a['order'].toString()) ?? 9999;
        final bo = int.tryParse(b['order'].toString()) ?? 9999;
        return ao.compareTo(bo);
      });

    setState(() {
      shopsDetails = allStores;
      _selectedCategory = "مختارة لك"; // 👈 اختيار افتراضي
      _visibleShops = featured.isNotEmpty ? featured : allStores;
    });

    // للمتابعة في الديبَغ إن لزم
    // print("cats: $shopsCategoryNames");
    // print("allStores: ${shopsDetails.length}, featured: ${featured.length}");
  }




  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: GlobalSkeletonWrapper(
        loadFuture: _getCategories, // 👈 نفس دالة التحميل الحالية
        skeletonBuilder: (_) => const ShoppingSkeleton(),
        child: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 7),
                      // ===== البانر =====
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 160,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 5),
                          enlargeCenterPage: true,
                          viewportFraction: 1.0,
                        ),
                        items: imageUrls.map((url) {
                          return Builder(
                            builder: (context) {
                              return SizedBox(
                                height: 160,
                                width: MediaQuery.of(context).size.width,
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Image.network(
                                        url,
                                        width: double.infinity,
                                        height: 160,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF988561),
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(7),
                                          ),
                                        ),
                                        child: const Text(
                                          "إعلان مُمَوّل",
                                          style: TextStyle(
                                            color: Color(0xFFedebdf),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 4),
                      // ===== مربع البحث =====
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 0,
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.black, fontSize: 14),
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
                                horizontal: 10,
                                vertical: 10,
                              ),
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
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 45,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          itemCount: shopsCategoryNames.length,
                          itemBuilder: (context, index) {
                            bool isSelected =
                                _selectedCategory == shopsCategoryNames[index]; // ← غيّر لاحقًا حسب الحالة

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 0),
                              child: Card(
                                color: isSelected
                                    ? const Color(0x20a7a9ac)
                                    : const Color(0x20a7a9ac),
                                elevation: isSelected ? 0 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: isSelected
                                        ? const Color(0xFF000000)
                                        : const Color(0xFF000000),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                  ),
                                  onPressed: () {
                                    final selected = shopsCategoryNames[index];
                                    if (_selectedCategory == selected) {
                                      _filterByCategory(null);
                                    } else {
                                      _filterByCategory(selected);
                                    }
                                  },
                                  child: Text(
                                    shopsCategoryNames[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                      isSelected ? FontWeight.w500 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // ===== قائمة المتاجر =====
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _visibleShops.length,
                        itemBuilder: (context, index) {
                          final shop = _visibleShops[index];

                          if (shop == null || shop.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final String name = shop['name']?.toString() ?? '';
                          final String category = shop['category']?.toString() ?? '';
                          final String imageUrl = shop['imageUrl']?.toString() ?? '';
                          final String discount = shop['discountText']?.toString() ?? '';
                          final String deliveryTime =
                              shop['deliveryTime']?.toString() ?? '';
                          final String deliveryMethod =
                              shop['deliveryMethod']?.toString() ?? '';
                          final String openTime = shop['openTime']?.toString() ?? '';
                          final String closeTime = shop['closeTime']?.toString() ?? '';
                          final String description =
                              shop['description']?.toString() ?? '';
                          final bool verified = shop['verified'] == true;

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShopPage(shopData: shop),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0x20a7a9ac),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(7),
                                      ),
                                      child: Stack(
                                        children: [
                                          AspectRatio(
                                            aspectRatio: 2.35,
                                            child: Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: Icon(Icons.store,
                                                      size: 60, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (discount.isNotEmpty)
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 0),
                                                child: Row(
                                                  children: [
                                                    Image.asset(
                                                      'assets/images/discount_icon_above.png',
                                                      width: 45,
                                                      height: 45,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (shop['createdAt'] != null)
                                            Builder(builder: (context) {
                                              final createdAt = DateTime.tryParse(
                                                  shop['createdAt']);
                                              final now = DateTime.now();
                                              final isNew = createdAt != null &&
                                                  now.difference(createdAt).inDays <= 30;
                                              if (!isNew)
                                                return const SizedBox.shrink();

                                              return Positioned(
                                                top: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 0, vertical: 0),
                                                  child: Row(
                                                    children: [
                                                      Image.asset(
                                                        'assets/images/new_icon.png',
                                                        width: 40,
                                                        height: 40,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    child: Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (verified) ...[
                                                      const SizedBox(width: 2),
                                                      Transform.translate(
                                                        offset: const Offset(0, -8),
                                                        child: SvgPicture.asset(
                                                          'assets/svg/verified.svg',
                                                          width: 13,
                                                          height: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                SizedBox(
                                                  width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                      0.5,
                                                  child: Text(
                                                    description,
                                                    maxLines: 1,
                                                    overflow:
                                                    TextOverflow.ellipsis,
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                if (discount.isNotEmpty)
                                                  Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      Container(
                                                        margin:
                                                        const EdgeInsets.only(top: 4),
                                                        padding: const EdgeInsets.only(
                                                          right: 30,
                                                          left: 10,
                                                          top: 5,
                                                          bottom: 5,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF6b1f2a),
                                                          borderRadius:
                                                          BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          discount,
                                                          style: const TextStyle(
                                                            color:
                                                            Color(0xFFedebe0),
                                                            fontSize: 10,
                                                            fontWeight:
                                                            FontWeight.w400,
                                                          ),
                                                          overflow:
                                                          TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Positioned(
                                                        right: 3,
                                                        top: -0,
                                                        child: Image.asset(
                                                          'assets/images/discount_icon.png',
                                                          width: 25,
                                                          height: 25,
                                                          fit: BoxFit.contain,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 0),
                                          Expanded(
                                            flex: 1,
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'خلال $deliveryTime ${deliveryTime == "1" ? "دقيقة" : "دقائق"}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Image.asset(
                                                      'assets/images/time_delivery.png',
                                                      width: 15,
                                                      height: 15,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'عبر $deliveryMethod',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Image.asset(
                                                      'assets/images/delivery_method.png',
                                                      width: 15,
                                                      height: 15,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                if (openTime.isNotEmpty &&
                                                    closeTime.isNotEmpty)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'من $openTime إلى $closeTime',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Image.asset(
                                                        'assets/images/clock.png',
                                                        width: 15,
                                                        height: 15,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
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
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 20),
                    child: _floatingSquareButton(Icons.receipt_long, "طلباتي", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _floatingSquareButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Color(0xfff6f6f6),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
