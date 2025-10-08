import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderId;
  const OrderDetailsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeSlideController;
  late AnimationController _pulseController;

  String? lastStatus;

  @override
  void initState() {
    super.initState();

    _fadeSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      lowerBound: 0.9,
      upperBound: 1.1,
    );
  }

  @override
  void dispose() {
    _fadeSlideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref("orders/${widget.orderId}");

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: Text("تفاصيل الطلب",
              style: const TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: StreamBuilder(
          stream: ref.onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(child: Text("❌ لم يتم العثور على الطلب"));
            }

            final order =
            Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

            final items = Map<String, dynamic>.from(order["items"]);
            final steps = [
              {"title": "طلبك قيد المراجعة", "key": "pending"},
              {"title": "تم القبول", "key": "accepted"},
              {"title": "قيد التحضير", "key": "preparing"},
              {"title": "قيد التوصيل", "key": "on_delivery"},
              {"title": "تم التسليم", "key": "delivered"},
              {"title": "مرفوض", "key": "rejected"},
            ];

            final currentIndex =
            steps.indexWhere((s) => s["key"] == order["status"]);

            // 🔁 نبضة عند تغيّر الحالة
            if (order["status"] != lastStatus) {
              _pulseController.forward(from: 0).then((_) {
                _pulseController.reverse();
              });
              lastStatus = order["status"];
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section("تفاصيل المتجر", [
                    "المتجر: ${order["shopName"] ?? "-"}",
                    "وقت الطلب: ${order["createdAtFormatted"] ?? "-"}",
                  ]),
                  const SizedBox(height: 10),
                  _section("العنوان", [
                    order["address"]
                        ?.toString()
                        .replaceAll("{", "")
                        .replaceAll("}", "") ??
                        "-",
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== العنوان + زر النسخ =====
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "المنتجات",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20, color: Colors.black54),
                              tooltip: "نسخ تفاصيل الفاتورة",
                              onPressed: () {
                                final buffer = StringBuffer();
                                buffer.writeln("📦 تفاصيل الطلب:");
                                for (var e in items.values) {
                                  buffer.writeln(
                                      "• ${e["name"]} × ${e["qty"]} = ${e["total"]} ل.س");
                                }
                                buffer.writeln("——————————");
                                buffer.writeln("الإجمالي: ${order["total"]} ل.س");

                                Clipboard.setData(ClipboardData(text: buffer.toString()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("✅ تم نسخ تفاصيل الطلب إلى الحافظة"),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ===== جدول المنتجات =====
                        ...items.values.map((e) {
                          final total = double.tryParse(e["total"].toString()) ?? 0;
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      e["name"] ?? "",
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      "×${e["qty"]}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "${total.toStringAsFixed(0)} ل.س",
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 10, color: Colors.black12),
                            ],
                          );
                        }),

                        // ===== الإجمالي =====
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "الإجمالي: ${order["total"] ?? 0} ل.س",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "تتبع الطلب",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 20),

                  // ✅ تتبع الطلب مع الأنيميشن والنبضة
                  Column(
                    children: List.generate(steps.length, (i) {
                      final step = steps[i];
                      final done = i <= currentIndex;
                      final isCurrent = i == currentIndex;

                      Color getStepColor() {
                        switch (step["key"]) {
                          case "pending":
                            return Colors.orange;
                          case "accepted":
                            return Colors.green;
                          case "preparing":
                            return Colors.blueAccent;
                          case "on_delivery":
                            return Colors.purple;
                          case "delivered":
                            return Colors.black;
                          case "rejected":
                            return Colors.red;
                          default:
                            return Colors.grey;
                        }
                      }

                      String getStepSubtitle() {
                        switch (step["key"]) {
                          case "pending":
                            return "طلبك بانتظار تأكيد المتجر";
                          case "accepted":
                            return "تم قبول طلبك من المتجر";
                          case "preparing":
                            return "المتجر يقوم بتحضير الأصناف";
                          case "on_delivery":
                            return "مندوب التوصيل في الطريق إليك";
                          case "delivered":
                            return "تم تسليم الطلب بنجاح";
                          case "rejected":
                            return "تم رفض الطلب من قبل المتجر";
                          default:
                            return "";
                        }
                      }

                      final stepColor = getStepColor();

                      final animation = Tween<Offset>(
                        begin: const Offset(0.3, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _fadeSlideController,
                        curve: Interval((i / steps.length), 1.0,
                            curve: Curves.easeOut),
                      ));

                      final opacityAnim = Tween<double>(
                        begin: 0,
                        end: 1,
                      ).animate(CurvedAnimation(
                        parent: _fadeSlideController,
                        curve: Interval((i / steps.length), 1.0,
                            curve: Curves.easeIn),
                      ));

                      return FadeTransition(
                        opacity: opacityAnim,
                        child: SlideTransition(
                          position: animation,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    ScaleTransition(
                                      scale: isCurrent
                                          ? _pulseController
                                          : const AlwaysStoppedAnimation(1.0),
                                      child: AnimatedContainer(
                                        duration:
                                        const Duration(milliseconds: 400),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: done
                                              ? stepColor
                                              : Colors.white,
                                          border: Border.all(
                                            color: done
                                                ? stepColor
                                                : Colors.grey.shade400,
                                            width: 2,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: done
                                            ? const Icon(Icons.check,
                                            size: 14, color: Colors.white)
                                            : null,
                                      ),
                                    ),
                                    if (i != steps.length - 1)
                                      Container(
                                        width: 3,
                                        height: 40,
                                        color: (done || isCurrent)
                                            ? stepColor.withOpacity(0.6)
                                            : Colors.grey.shade300,
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step["title"]!,
                                        style: TextStyle(
                                          fontWeight: done || isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.w400,
                                          color: done || isCurrent
                                              ? stepColor
                                              : Colors.black87,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        getStepSubtitle(),
                                        style: TextStyle(
                                          color: done || isCurrent
                                              ? Colors.black87
                                              : Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _section(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          ...lines.map((l) => Text(l, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
