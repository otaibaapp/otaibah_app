import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';

class ItemInOpenSouq extends StatelessWidget {
  final Map<dynamic, dynamic> data;
  const ItemInOpenSouq({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x20a7a9ac),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height / 3.7,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['name'],
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: MediaQuery.sizeOf(context).height / 60,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          try {
                            final productId =
                                data['id']; // تأكد إنه عندك ID بالـ item
                            final productLink =
                                "https://otaibah-alt.web.app/product/$productId";

                            await Share.share(
                              "✨ اكتشف هذا المنتج المميز على تطبيق العُتيبة ✨\nيمكن أن يعجبك 👇\n$productLink",
                              subject: "تطبيق العُتيبة",
                            );
                          } catch (e) {}
                        },
                        icon: SvgPicture.asset(
                          'assets/svg/share_post_icon.svg',
                          width: 25,
                          height: 25,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    data['description'],
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).height / 80,
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      // تحويل Map إلى List للوصول بالعناصر حسب الفهرس
                      final entry = data.entries.elementAt(index);
                      final key = entry.key;
                      final value = entry.value.toString();

                      // 🔹 تغيير اللون حسب كون السطر زوجي أو فردي
                      final bool isEven = index % 2 == 0;
                      final Color textColor = isEven ? Colors.blue : Colors.red;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          color: isEven ? textColor : Colors.grey[700],
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // المفتاح
                              if (key != 'description' && key != 'imgUrl')
                                Text(
                                  key + ' : ' + value,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF988561),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    data['price'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
