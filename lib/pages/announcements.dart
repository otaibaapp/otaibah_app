
import 'dart:convert';
import 'dart:math';
import 'dart:ui'; // 👈 للـ ImageFilter.blur
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/global_banner.dart';
import 'app_identity.dart';
import 'favorites_page.dart'; // يخص السوق (لن نستخدمه هنا لكن لن ألمسه)
import 'announcements_favorites_page.dart'; // صفحة مفضّلة المنشورات

class Announcements extends StatefulWidget {
  const Announcements({super.key});

  @override
  State<Announcements> createState() => _AnnouncementsState();
}

class _AnnouncementsState extends State<Announcements>
    with SingleTickerProviderStateMixin {
  // ===== بيانات الواجهة =====
  List<String> imageUrls = [];
  bool loading = true;

  double get iconWidth => MediaQuery.sizeOf(context).width / 75;
  double get iconHeight => MediaQuery.sizeOf(context).height / 75;

  final TextEditingController _searchController = TextEditingController();
  List<Map<dynamic, dynamic>> _itemsList = [];
  List<Map<dynamic, dynamic>> _filteredList = [];

  // ===== مراجع قاعدة البيانات =====
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref('otaibah_navigators_taps');

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
        .child('announcements')
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
    _databaseRef.child('favorites').child(_userId!).onValue.listen((event) async {
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
      _filterItems(_searchController.text);
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
            .map((m) => Map<dynamic, dynamic>.from(m as Map))
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
        final Map<String, dynamic> m =
            Map<String, dynamic>.from(jsonDecode(countsJson));
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
      loading = false;
    });
  }

  Future<List<String>> _fetchBannerImages() async {
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

  // ===== البحث =====
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
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                ),
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
    return _databaseRef.child('announcement_likes').child(postId).child('users');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      // ✅ AppBar علوي لفتح صفحة مفضلة المنشورات
      /*appBar: AppBar(
        title: const Text('المنشورات'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'المفضلة',
            icon: const Icon(Icons.favorite_outline, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AnnouncementsFavoritesPage(),
                ),
              );
            },
          ),
        ],
      ),


       */

      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 7),
                const GlobalBanner(section: "announcements"),


                const SizedBox(height: 4),

                // ===== مربع البحث =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  child: TextField(
                    controller: _searchController,
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

                const SizedBox(height: 2),

                // ===== المنشورات =====
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    final String imgUrl =
                        (item['contentImgUrl'] ?? '').toString();
                    final String postId = (item['id'] ?? '').toString();

                    // مراجع البث للحالات (للعدادات وأحدث حالة)
                    final likeUsersRef = _likeUsersRefFor(postId);

                    // رابط مشاركة فريد
                    final String shareUrl = (item['shareUrl'] ??
                            'https://otaibah-alt.web.app/ann?id=$postId')
                        .toString();

                    return Column(
                      children: [
                        Card(
                          color: Colors.transparent,
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ===== الهيدر =====
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 0, 0, 0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 0.0), // 👈 مسافة يمين ويسار
                                      child: GestureDetector(
                                        onTap: () {
                                          final img = (item['sourceImageUrl'] ?? '').toString();
                                          if (img.isNotEmpty) _openImageFullscreen(img);
                                        },
                                        child: Hero(
                                          tag: (item['sourceImageUrl'] ?? '').toString(),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(7),
                                            child: Image.network(
                                              (item['sourceImageUrl'] ?? '').toString(),
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: Colors.black,
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (item['source'] ?? '').toString(),
                                            style: TextStyle(
                                              fontSize:
                                                  MediaQuery.sizeOf(context)
                                                          .height /
                                                      55,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            (item['dateOfPost'] ?? '').toString(),
                                            style: TextStyle(
                                              fontSize:
                                                  MediaQuery.sizeOf(context)
                                                          .height /
                                                      80,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ===== زر المفضلة =====
                                    if (_userId == null)
                                      IconButton(
                                        tooltip: "إضافة إلى المفضلة",
                                        onPressed: null,
                                        icon: SvgPicture.asset(
                                          'assets/svg/favorite_outline.svg',
                                          width: iconWidth * 2,
                                          height: iconHeight * 2,
                                          color: const Color(0xFF000000),
                                        ),
                                      )
                                    else
                                      StreamBuilder<DatabaseEvent>(
                                        stream: _favRefFor(_userId!, postId)
                                            .onValue,
                                        builder: (context, snap) {
                                          final bool onlineFav =
                                              (snap.data?.snapshot.value == true);
                                          final bool isFav =
                                              onlineFav || _cachedFavIds.contains(postId);

                                          // 🎨 ألوان الزرين
                                          const Color favFilledColor =
                                              Color(0xFF988561);
                                          const Color favOutlineColor =
                                              Color(0xFF000000);

                                          return IconButton(
                                            tooltip: isFav
                                                ? "إزالة من المفضلة"
                                                : "إضافة إلى المفضلة",
                                            onPressed: () => _toggleFavorite(
                                                postId, isFav),
                                            icon: SvgPicture.asset(
                                              isFav
                                                  ? 'assets/svg/favorite_filled.svg'
                                                  : 'assets/svg/favorite_outline.svg',
                                              width: iconWidth * 2,
                                              height: iconHeight * 2,
                                              color: isFav
                                                  ? favFilledColor
                                                  : favOutlineColor,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 7),

                              // ===== النص =====
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 0),
                                child: Linkify(
                                  text: (item['content'] ?? '').toString(),
                                  onOpen: (link) async => await _launchURL(link.url),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Colors.black87,
                                  ),
                                  linkStyle: const TextStyle(
                                    color: Color(0xFF0056b3),
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 7),

                              // ===== الصورة =====
                              if (imgUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 0),
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        onTap: () =>
                                            _openImageFullscreen(imgUrl),
                                        child: Hero(
                                          tag: imgUrl,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(7),
                                            child: Image.network(
                                              imgUrl,
                                              fit: BoxFit.cover,
                                              loadingBuilder:
                                                  (context, child, progress) {
                                                if (progress == null) {
                                                  return child;
                                                }
                                                return const SizedBox(
                                                  height: 160,
                                                  child: Center(
                                                      child:
                                                          CircularProgressIndicator()),
                                                );
                                              },
                                              errorBuilder: (_, __, ___) =>
                                                  const SizedBox.shrink(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // ===== صف الأزرار السفلي =====
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      right: 0, bottom: 0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // زر المشاركة
                                      IconButton(
                                        tooltip: "مشاركة",
                                        onPressed: () => Share.share(
                                          "📢 شاهد هذا المنشور على تطبيق العُتيبة 👇\n$shareUrl",
                                          subject: "تطبيق العُتيبة",
                                        ),
                                        icon: SvgPicture.asset(
                                          'assets/svg/share_post_icon.svg',
                                          width: iconWidth * 1.8,
                                          height: iconHeight * 1.8,
                                          colorFilter: const ColorFilter.mode(
                                            Color(0xFF000000),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                      ),

                                      // زر القلب + العدّاد
                                      StreamBuilder<DatabaseEvent>(
                                        stream: likeUsersRef.onValue,
                                        builder: (context, snap) {
                                          final Map<dynamic, dynamic> usersMap =
                                              (snap.data?.snapshot.value
                                                      as Map?) ??
                                                  {};
                                          final int onlineCount =
                                              usersMap.length;
                                          // استخدم عداد الكاش كنسخة أولية عند عدم توفر الشبكة
                                          final int likesCount = (snap.hasData)
                                              ? onlineCount
                                              : (_cachedLikeCounts[postId] ?? onlineCount);
                                          final bool isLikedOnline = _userId != null &&
                                              usersMap.containsKey(_userId);
                                          final bool isLiked =
                                              isLikedOnline || _cachedLikedIds.contains(postId);

                                          // عند توفر بيانات الشبكة، خزّن العدادات لأجل المرة القادمة
                                          if (snap.hasData) {
                                            _cachedLikeCounts[postId] = onlineCount;
                                            // لا نكتب SharedPreferences في كل فريم UI،
                                            // ممكن تجميعه لاحقًا. هنا نبقيه بسيطًا:
                                            _saveLikesCache();
                                          }

                                          return Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 10),
                                                child: Text(
                                                  likesCount.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: isLiked
                                                    ? "إلغاء الإعجاب"
                                                    : "إعجاب",
                                                onPressed: _userId == null
                                                    ? null
                                                    : () => _toggleLike(
                                                        postId, isLiked),
                                                icon: SvgPicture.asset(
                                                  isLiked
                                                      ? 'assets/svg/heart_filled.svg'
                                                      : 'assets/svg/heart_outline.svg',
                                                  width: iconWidth * 1.8,
                                                  height: iconHeight * 1.8,
                                                  color: isLiked
                                                      ? const Color(0xFFef3733)
                                                      : Colors.black,
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
                            ],
                          ),
                        ),
                        // 👇 فقط لو لم يكن آخر منشور
                        if (index != _filteredList.length - 1)
                          const Divider(
                            color: Color(0x50000000),
                            thickness: 0.9,
                            indent: 0,
                            endIndent: 0,
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
