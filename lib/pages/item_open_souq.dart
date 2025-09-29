import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ItemInOpenSouq extends StatelessWidget {
  final Map<dynamic, dynamic> data;
  const ItemInOpenSouq({super.key, required this.data});

  // 📞 اتصال هاتفي
  Future<void> callPhone(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // 🔗 مشاركة المنتج
  Future<void> shareProduct() async {
    final productId = data['id'];
    final productLink = "https://otaibah-alt.web.app/product/$productId";
    await Share.share(
      "✨ اكتشف هذا المنتج المميز على تطبيق العُتيبة ✨\nيمكن أن يعجبك 👇\n$productLink",
      subject: "تطبيق العُتيبة",
    );
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.only(bottom: 90), // مساحة للزرين بالأسفل
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: AspectRatio(
                      aspectRatio: 1 / 1,
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
                ),

                // ======= الاسم + أيقونة المشاركة (يسار) =======
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: MediaQuery.sizeOf(context).height / 45,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: shareProduct,
                        borderRadius: BorderRadius.circular(30),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: SvgPicture.asset(
                            'assets/svg/share_icon.svg', // 👈 ضع الأيقونة هنا
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF988561),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ],
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

                const SizedBox(height: 7),

                // ======= السعر =======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF988561),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "سعر المنتج",
                          style: TextStyle(
                            color: Color(0xFFfffcee),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          data['price'] ?? '',
                          style: const TextStyle(
                            color: Color(0xFFfffcee),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ======= الأزرار =======
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // زر مراسلة المالك
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => callPhone("491743779135"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF054239),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          icon: SvgPicture.asset(
                            'assets/svg/send_a_msg_whatsapp.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          label: const Text(
                            "مُراسلة المالك",
                            style: TextStyle(
                              color: Color(0xFFf6f6f6),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // زر الاتصال بالمالك
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: shareProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4a151e),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          icon: SvgPicture.asset(
                            'assets/svg/call_the_merchant.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFFf6f6f6),
                              BlendMode.srcIn,
                            ),
                          ),
                          label: const Text(
                            "الإتّصال بالمالك",
                            style: TextStyle(
                              color: Color(0xFFf6f6f6),
                              fontSize: 15,
                            ),
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
                        borderRadius: const BorderRadius.all(Radius.circular(7)),
                        child: Column(
                          children: List.generate(entries.length, (i) {
                            final e = entries[i];
                            final bg = i.isEven
                                ? const Color(0x20a7a9ac)
                                : const Color(0x5a7a9ac);
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF000000),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      e.value.toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                        color: Color(0xFF000000),
                                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
