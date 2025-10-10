import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class GlobalBanner extends StatefulWidget {
  final String section; // لتحديد القسم (إعلانات، سوق...إلخ)

  const GlobalBanner({super.key, this.section = "all"});

  @override
  State<GlobalBanner> createState() => _GlobalBannerState();
}

class _GlobalBannerState extends State<GlobalBanner> {
  final DatabaseReference _ref =
  FirebaseDatabase.instance.ref('global_banners');
  List<Map<String, dynamic>> banners = [];

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    final snap = await _ref.get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      final allBanners = data.entries.map((e) {
        final v = Map<String, dynamic>.from(e.value);
        return {
          "id": e.key,
          "imageUrl": v["imageUrl"],
          "section": v["section"],
          "actionType": v["actionType"],
          "actionValue": v["actionValue"],
        };
      }).toList();

      // ✅ فلترة حسب القسم
      setState(() {
        banners = allBanners
            .where((b) =>
        b["section"] == widget.section || b["section"] == "all")
            .toList();
      });
    }
  }

  Future<void> _handleBannerTap(String type, String value) async {
    if (value.isEmpty) return;

    if (type == "url") {
      final uri = Uri.tryParse(value);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (type == "call") {
      final uri = Uri.parse("tel:$value");
      await launchUrl(uri);
    } else if (type == "internal") {
      try {
        if (value.startsWith("shop:")) {
          final shopId = value.split(":")[1];
          Navigator.pushNamed(context, '/shop', arguments: shopId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ المسار الداخلي غير مدعوم حالياً إلا للمتاجر (shop:shopId)"),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ أثناء فتح المتجر: $e")),
        );
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox(height: 160);

    return CarouselSlider(
      options: CarouselOptions(
        height: 160,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        enlargeCenterPage: false,
        viewportFraction: 1.0,
      ),
      items: banners.map((b) {
        return Builder(
          builder: (context) {
            return GestureDetector(
              onTap: () => _handleBannerTap(b["actionType"], b["actionValue"]),
              child: SizedBox(
                height: 160,
                width: MediaQuery.of(context).size.width,
                child: Stack(
                  children: [
                    // ✅ الصورة مع الحواف الدائرية
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: CachedNetworkImage(
                        imageUrl: b["imageUrl"],
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: Colors.redAccent),
                      ),
                    ),

                    // ✅ مستطيل "إعلان مُمَوّل"
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
                            bottomLeft: Radius.circular(7),
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
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
