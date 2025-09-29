import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'item_open_souq.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final DatabaseReference _db =
  FirebaseDatabase.instance.ref('otaibah_navigators_taps');
  final user = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  List<Map<dynamic, dynamic>> _favoriteItems = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// ✅ تحميل مفضلة السوق المفتوح فقط
  Future<void> _loadFavorites() async {
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    // مفضلات المستخدم من مسار خاص بالسوق المفتوح
    final favSnap = await FirebaseDatabase.instance
        .ref("open_souq_favorites/${user!.uid}")
        .get();

    if (favSnap.value == null || favSnap.value is! Map) {
      setState(() => _loading = false);
      return;
    }

    final favMap = Map<dynamic, dynamic>.from(favSnap.value as Map);
    final favIds = favMap.keys.map((e) => e.toString()).toList();

    // 🔹 جلب جميع المنتجات
    final productsSnap =
    await _db.child('open_souq/categories/general').get();

    final List<Map<dynamic, dynamic>> favList = [];
    if (productsSnap.exists && productsSnap.value is Map) {
      final Map<dynamic, dynamic> all =
      productsSnap.value as Map<dynamic, dynamic>;
      all.forEach((key, value) {
        if (favIds.contains(key.toString()) && value is Map) {
          final item = Map<dynamic, dynamic>.from(value);
          item['id'] = key.toString();
          favList.add(item);
        }
      });
    }

    setState(() {
      _favoriteItems = favList.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _removeFavorite(String productId) async {
    if (user == null) return;
    await FirebaseDatabase.instance
        .ref("open_souq_favorites/${user!.uid}/$productId")
        .remove();

    setState(() {
      _favoriteItems.removeWhere((item) => item['id'] == productId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("تمت إزالة المنتج من المفضلة"),
        backgroundColor: Colors.black.withOpacity(0.8),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openProductPage(Map<dynamic, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ItemInOpenSouq(data: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('مفضلتي - السوق المفتوح'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteItems.isEmpty
          ? const Center(
        child: Text(
          "لا توجد منتجات في المفضلة بعد.",
          style: TextStyle(fontSize: 15, color: Colors.black54),
        ),
      )
          : Directionality(
        textDirection: TextDirection.rtl,
        child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            mainAxisExtent: 300,
          ),
          itemCount: _favoriteItems.length,
          itemBuilder: (context, index) {
            final item = _favoriteItems[index];
            final String imgUrl = (item['imgUrl'] ?? '').toString();

            return GestureDetector(
              onTap: () => _openProductPage(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
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
                              imageUrl: imgUrl,
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
                          padding: const EdgeInsets.only(
                              top: 6, left: 6, right: 6, bottom: 2),
                          child: Text(
                            item['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: MediaQuery.sizeOf(context)
                                  .height /
                                  60,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: Text(
                            item['description'] ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: MediaQuery.sizeOf(context)
                                  .height /
                                  85,
                              color: Colors.grey[900],
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    Positioned(
                      top: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: () =>
                            _removeFavorite(item['id'].toString()),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.favorite,
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
      ),
    );
  }
}
