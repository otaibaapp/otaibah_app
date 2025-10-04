import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'checkout_page.dart';

class CartPage extends StatefulWidget {
  final String shopId;
  final String shopName;
  const CartPage({super.key, required this.shopId, required this.shopName});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // إعدادات قابلة للتعديل
  static const double serviceFee = 100.0;
  static const double deliveryFee = 5000.0;
  static const Color primaryColor = Color(0xFF988561);
  static const Color backgroundColor = Color(0xffffffff);

  String note = "";

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cartRef =
    FirebaseDatabase.instance.ref("carts/${user?.uid}/${widget.shopId}");

    return Directionality(
      textDirection: TextDirection.rtl, // 👈 الصفحة كلها RTL
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.white,
          title: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: SvgPicture.asset(
                  "assets/svg/back.svg", // زر الرجوع
                  width: 26,
                  height: 26,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("سلّة المُشتريات",
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                  Text(widget.shopName,
                      style:
                      const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        body: StreamBuilder(
          stream: cartRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(
                child: Text(
                  "السلة فارغة",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              );
            }

            final data =
            Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
            final items = data.entries
                .map((e) =>
            {"key": e.key, ...Map<String, dynamic>.from(e.value)})
                .toList();

            double totalWithoutDiscount = 0;
            double totalWithDiscount = 0;

            for (final item in items) {
              double price = double.tryParse(item['price'].toString()) ?? 0;
              double discountPrice =
                  double.tryParse(item['discountPrice']?.toString() ?? '') ??
                      price;
              int quantity = int.tryParse(item['quantity'].toString()) ?? 0;

              totalWithoutDiscount += price * quantity;
              totalWithDiscount += discountPrice * quantity;
            }

            final double saving = totalWithoutDiscount - totalWithDiscount;
            final double grandTotal =
                totalWithDiscount + deliveryFee + serviceFee;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      // ===== المنتجات =====
                      ...items.map((item) {
                        final itemRef = cartRef.child(item['key']);
                        double price =
                            double.tryParse(item['price'].toString()) ?? 0;
                        double discountPrice =
                            double.tryParse(item['discountPrice']?.toString() ??
                                '') ??
                                price;
                        int quantity =
                            int.tryParse(item['quantity'].toString()) ?? 0;

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                textDirection: TextDirection.rtl, // 👈 مهم جداً
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // ✅ الصورة بأقصى اليمين
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item['imageUrl'] ?? "",
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 50),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // ✅ النصوص بعد الصورة (يمين بالنسبة للـ RTL)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, // في RTL = يمين
                                      children: [
                                        Text(
                                          item['name'] ?? "",
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        if (discountPrice < price)
                                          Row(
                                            textDirection: TextDirection.rtl, // لنفس محاذاة الأسعار
                                            children: [
                                              Text(
                                                "${price.toStringAsFixed(0)} ل.س",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black45,
                                                  decoration: TextDecoration.lineThrough,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "${discountPrice.toStringAsFixed(0)} ل.س",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Text(
                                            "${price.toStringAsFixed(0)} ل.س",
                                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // ✅ أزرار الكمية بأقصى اليسار
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => itemRef.update({"quantity": quantity + 1}),
                                        child: Image.asset("assets/images/plus.png", width: 23, height: 23),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "$quantity",
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 12),
                                      if (quantity > 1)
                                        GestureDetector(
                                          onTap: () => itemRef.update({"quantity": quantity - 1}),
                                          child: Image.asset("assets/images/minus.png", width: 23, height: 23),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text("تأكيد الحذف", textAlign: TextAlign.right), // 👈 حتى العنوان يمين
                                                content: const Text(
                                                  "هل تريد حذف هذا المنتج من السلة؟",
                                                  textAlign: TextAlign.right, // 👈 النص يمين
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(ctx).pop(false),
                                                    child: const Text("إلغاء"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.of(ctx).pop(true),
                                                    child: const Text("حذف"),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) itemRef.remove();
                                          },
                                          child: Image.asset("assets/images/trash.png", width: 23, height: 23),
                                        ),
                                    ],
                                  )

                                ],
                              ),

                            ),
                            const Divider(color: Colors.black12, thickness: 1),
                          ],
                        );
                      }),

                      // ===== الملاحظة =====
                      ListTile(
                        onTap: () => _openNoteSheet(context),
                        leading: SvgPicture.asset(
                          "assets/svg/note.svg",
                          width: 22,
                          height: 22,
                          color: Colors.black,
                        ),
                        title: Align(
                          alignment: Alignment.centerRight,
                          child: const Text(
                            "دوّن ملاحظة",
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                        subtitle: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            note.isEmpty
                                ? "هل تود أن تخبر المتجر بشيء ما؟"
                                : note,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      const Divider(color: Colors.black12, thickness: 1),

                      // ===== ملخص الدفع =====
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("ملخّص الدفع",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            _buildSummaryRow(
                                "السعر قبل الخصم", totalWithoutDiscount),
                            _buildSummaryRow("المجموع الفرعي", totalWithDiscount),
                            _buildSummaryRow("التوفير", -saving,
                                valueColor: Colors.green),
                            _buildSummaryRow("رسوم الخدمة", serviceFee,
                                hasInfo: true),
                            _buildSummaryRow("رسوم التوصيل", deliveryFee, hasInfo: true, isDelivery: true),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12), // 👈 8 بكسل فوق وتحت
                              child: DashedDivider(color: Colors.black26),
                            ),
                            _buildSummaryRow("الإجمالي", grandTotal,
                                isTotal: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== الأزرار =====
                Container(
                  color: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CheckoutPage(
                                  shopId: widget.shopId,
                                  shopName: widget.shopName,
                                  deliveryTime: 30, // أو خذها من بيانات المتجر widget.shopData['deliveryTime']
                                  total: grandTotal,
                                ),
                              ),
                            );
                          },

                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7)),
                          ),
                          child: const Text("متابعة الدفع",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFfffcee))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context); // متابعة التسوق
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7)),
                          ),
                          child: const Text("متابعة التسوّق",
                               style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF988561))),

                        ),
                      ),
                    ],
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== صف الملخص =====
  Widget _buildSummaryRow(String label, double value,
      {bool isTotal = false, Color? valueColor, bool hasInfo = false, bool isDelivery = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: isTotal ? 15 : 13,
                      fontWeight: isTotal ? FontWeight.bold : FontWeight.w400)),
              if (hasInfo) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: isDelivery ? _openDeliveryInfo : _openServiceInfo,
                  child: SvgPicture.asset(
                    "assets/svg/info.svg",
                    width: 15,
                    height: 15,
                    color: Colors.black,
                  ),
                ),
              ],
            ],
          ),
          Text(
            "${value.toStringAsFixed(0)} ل.س",
            style: TextStyle(
                fontSize: isTotal ? 15 : 13,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w400,
                color: valueColor ?? Colors.black),
          ),
        ],
      ),
    );
  }


  // ===== BottomSheet الملاحظة =====
  void _openNoteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final controller = TextEditingController(text: note);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end, // 👈 كل شي يمين
            children: [
              // 👇 الشخطة الصغيرة (Grabber)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[400], // 👈 لون رمادي فاتح
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // مربع الكتابة
              TextField(
                controller: controller,
                maxLength: 250,
                maxLines: 4,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: "...اكتب مُلاحظتك للمتجر هنا",
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Colors.black38,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(
                      color: Color(0xFF988561),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(
                      color: Color(0x20000000),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(
                      color: Color(0x50000000),
                      width: 1.5,
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // زر الحفظ
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      note = controller.text.trim();
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF988561), // ذهبي
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 169,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    "موافق",
                    style: TextStyle(
                      color: Color(0xFFfffcee), // بيج
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }


  // ===== BottomSheet رسوم الخدمة =====
  void _openServiceInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white, // 👈 خلفية بيضاء
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👇 الشخطة الصغيرة (Grabber)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400], // 👈 رمادي فاتح
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 30),



            // النص + الأيقونة بمحاذاة واحدة
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // النص الطويل
                const Expanded(
                  child: Text(
                    "رسوم الخدمة (100 ل.س) ثابتة على كل طلب\n"
                        "تساعدنا على تغطية التكاليف والاستمرار في تقديم أفضل أداء وتشغيل التطبيق بشكل مستمر",
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                    textAlign: TextAlign.right, // 👈 محاذاة لليمين
                  ),
                ),
                const SizedBox(width: 6),

                Image.asset(
                  "assets/images/delivery_costs.png", // 👈 مسار الصورة
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ],
            ),

            const SizedBox(height: 50),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text(
                  "مُوافق",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFfffcee),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }


  // ===== BottomSheet رسوم التوصيل =====
  void _openDeliveryInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white, // 👈 خلفية بيضاء
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👇 الشخطة الصغيرة (Grabber)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400], // 👈 رمادي فاتح
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // النص + الأيقونة بمحاذاة واحدة
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // النص الطويل
                const Expanded(
                  child: Text(
                    "رسوم التوصيل (5000 ل.س) ثابتة لكل طلب\n"
                        "وهي تساعدنا على تأمين وصول طلبك بسرعة وأمان مع الحفاظ على جودة الخدمة",
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                    textAlign: TextAlign.right, // 👈 محاذاة لليمين
                  ),
                ),
                const SizedBox(width: 6),

                Image.asset(
                  "assets/images/delivery_money_costs.png", // 👈 غير الصورة لو عندك أيقونة تانية
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ],
            ),

            const SizedBox(height: 50),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text(
                  "مُوافق",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFfffcee),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }


}

// ===== ويدجت لعمل خط متقطع =====
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;

  const DashedDivider({this.height = 1, this.color = Colors.black26, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

        return Flex(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

