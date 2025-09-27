import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_identity.dart';

class AnnouncementsFavoritesPage extends StatefulWidget {
  const AnnouncementsFavoritesPage({super.key});

  @override
  State<AnnouncementsFavoritesPage> createState() =>
      _AnnouncementsFavoritesPageState();
}

class _AnnouncementsFavoritesPageState
    extends State<AnnouncementsFavoritesPage> {
  final _db = FirebaseDatabase.instance.ref('otaibah_navigators_taps');
  String? _userId;
  bool _loading = true;

  Map<String, Map<String, dynamic>> _allAnnouncements = {};
  List<String> _favIds = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 🔹 احصل على uid أو deviceId
    _userId = await AppIdentity.getStableUserId();

    // 🔹 راقب المفضلات بشكل لحظي
    _db.child('favorites/$_userId').onValue.listen((event) {
      final favMap = (event.snapshot.value as Map?) ?? {};
      setState(() {
        _favIds = favMap.keys.map((e) => e.toString()).toList();
      });
      _loadAllAnnouncements();
    });
  }

  Future<void> _loadAllAnnouncements() async {
    final annSnap =
    await _db.child('announcements/categories/general').get();
    if (annSnap.value is Map) {
      final m = Map<dynamic, dynamic>.from(annSnap.value as Map);
      setState(() {
        _allAnnouncements = m.map((k, v) =>
            MapEntry(k.toString(), Map<String, dynamic>.from(v)));
        _loading = false;
      });
    }
  }

  Future<void> _removeFavorite(String postId) async {
    if (_userId == null) return;
    await _db.child('favorites/$_userId/$postId').remove();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("تمت إزالة المنشور من المفضلة"),
        backgroundColor: Colors.black.withOpacity(0.85),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final items = _favIds
        .where((id) => _allAnnouncements.containsKey(id))
        .map((id) {
      final map = Map<String, dynamic>.from(_allAnnouncements[id]!);
      map['id'] = id;
      return map;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('المفضلة - المنشورات'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(
        child: Text(
          "لا توجد منشورات في المفضلة بعد.",
          style: TextStyle(fontSize: 15, color: Colors.black54),
        ),
      )
          : Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.separated(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(
            color: Color(0x50000000),
            thickness: 0.9,
            indent: 12,
            endIndent: 12,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final postId = item['id'].toString();
            final imgUrl =
            (item['contentImgUrl'] ?? '').toString();
            final sourceImg =
            (item['sourceImageUrl'] ?? '').toString();
            final source = (item['source'] ?? '').toString();
            final date = (item['dateOfPost'] ?? '').toString();
            final content = (item['content'] ?? '').toString();
            final shareUrl = (item['shareUrl'] ??
                'https://otaibah-alt.web.app/ann?id=$postId')
                .toString();

            return Card(
              color: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 الهيدر
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(0, 10, 0, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: sourceImg.isEmpty
                              ? Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius:
                              BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            ),
                          )
                              : CachedNetworkImage(
                            imageUrl: sourceImg,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                            const SizedBox(
                              width: 50,
                              height: 50,
                              child: Center(
                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth: 2,
                                  )),
                            ),
                            errorWidget: (_, __, ___) =>
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius:
                                    BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey),
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
                                source,
                                style: TextStyle(
                                  fontSize:
                                  MediaQuery.sizeOf(context)
                                      .height /
                                      50,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize:
                                  MediaQuery.sizeOf(context)
                                      .height /
                                      75,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 🔹 إزالة من المفضلة
                        IconButton(
                          tooltip: "إزالة من المفضلة",
                          onPressed: () =>
                              _removeFavorite(postId),
                          icon: const Icon(Icons.favorite,
                              color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 🔹 النص مع الروابط
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 0),
                    child: Linkify(
                      text: content,
                      onOpen: (link) => _openLink(link.url),
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
                  const SizedBox(height: 10),

                  // 🔹 الصورة (إن وُجدت)
                  if (imgUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(
                          height: 160,
                          child: Center(
                              child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) =>
                        const SizedBox.shrink(),
                      ),
                    ),

                  // 🔹 زر المشاركة
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: "مشاركة",
                      onPressed: () => Share.share(
                        "📢 شاهد هذا المنشور 👇\n$shareUrl",
                        subject: "تطبيق العُتيبة",
                      ),
                      icon: const Icon(Icons.share,
                          color: Colors.black87),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
