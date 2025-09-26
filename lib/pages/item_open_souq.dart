import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ItemInOpenSouq extends StatelessWidget {
  final Map<dynamic, dynamic> data;
  const ItemInOpenSouq({super.key, required this.data});

  // اتصال هاتفي
  Future<void> callPhone(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // مشاركة المنتج
  Future<void> shareProduct() async {
    final productId = data['id'];
    final productLink = "https://otaibah-alt.web.app/product/$productId";
    await Share.share(
      "✨ اكتشف هذا المنتج المميز على تطبيق العُتيبة ✨\nيمكن أن يعجبك 👇\n$productLink",
      subject: "تطبيق العُتيبة",
    );
  }

  // القائمة المنسدلة (⋮)
  void showProductOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "خيارات المنتج",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
              title: const Text("الإبلاغ عن المنتج"),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم استلام بلاغك، شكرًا لتعاونك.")),
                );
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.share_outlined, color: Color(0xFF988561)),
              title: const Text("مشاركة المنتج"),
              onTap: () {
                Navigator.pop(ctx);
                shareProduct();
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text("التواصل مع البائع"),
              onTap: () {
                Navigator.pop(ctx);
                callPhone("491743779135");
              },
            ),
            ListTile(
              leading: const Icon(Icons.price_change_outlined,
                  color: Colors.blueGrey),
              title: const Text("طلب تخفيض السعر"),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("تم إرسال طلب تخفيض السعر إلى البائع.")),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // نجهز بيانات التفاصيل
    final entries = data.entries
        .where((e) =>
    e.key != 'imgUrl' &&
        e.key != 'description' &&
        e.key != 'id' &&
        e.key != 'name' &&
        e.key != 'price')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ======= الرأس =======
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: const [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage:
                              AssetImage('assets/images/profile.png'),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "مرحبًا بك يا أحمد",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: "رجوع",
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_forward_ios),
                      ),
                    ],
                  ),
                ),

                // ======= صورة المنتج =======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CachedNetworkImage(
                            imageUrl: data['imgUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Material(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => showProductOptions(context),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.more_vert, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ======= الاسم =======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    data['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: MediaQuery.sizeOf(context).height / 45,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // ======= الوصف =======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    data['description'] ?? '',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).height / 70,
                      height: 1.5,
                      color: Colors.grey[800],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ======= السعر =======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF988561),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      data['price'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ======= أزرار =======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => callPhone("491743779135"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF988561),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text(
                            "تواصل عبر مكالمة",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: shareProduct,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF988561), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          icon: const Icon(Icons.share,
                              color: Color(0xFF988561)),
                          label: const Text(
                            "مشاركة المنتج",
                            style: TextStyle(
                                color: Color(0xFF988561),
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ======= تفاصيل المنتج =======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "تفاصيل المنتج",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        child: Column(
                          children: List.generate(entries.length, (i) {
                            final e = entries[i];
                            final bg = i.isEven
                                ? const Color(0xFFF2F2F2)
                                : Colors.white;
                            return Container(
                              height: 52,
                              color: bg,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      e.key.toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700]),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      e.value.toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.left,
                                      style:
                                      TextStyle(color: Colors.grey[800]),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
