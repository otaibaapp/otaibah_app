import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'order_details_page.dart';
import 'dashboard.dart'; // ✅ استيراد الصفحة الرئيسية

class MyOrdersPage extends StatelessWidget {
  final bool fromCheckout; // 👈 لتحديد إذا المستخدم جاي بعد إتمام الطلب

  const MyOrdersPage({super.key, this.fromCheckout = false});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final dbRef = FirebaseDatabase.instance.ref("user_orders/${user!.uid}");

    return WillPopScope(
      onWillPop: () async {
        // ✅ لما المستخدم يضغط رجوع، نرجعه إلى Dashboard على تبويب التسوق
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Dashboard(initialIndex: 2)), // 👈 تبويب التسوق
              (route) => false,
        );
        return false;
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title:
            const Text("سجل طلباتي", style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const Dashboard(initialIndex: 2)), // 👈 تبويب التسوق
                      (route) => false,
                );
              },
            ),
          ),
          body: StreamBuilder(
            stream: dbRef.onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return _noOrders(context);
              }

              final data = Map<String, dynamic>.from(
                  snapshot.data!.snapshot.value as Map<dynamic, dynamic>);

              final orders = data.values
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
                ..sort((a, b) =>
                    (b["timestamp"] ?? 0).compareTo(a["timestamp"] ?? 0));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (context, i) {
                  final o = Map<String, dynamic>.from(orders[i]);
                  final statusColor = _statusColor(o["status"]);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("رقم الطلب: ${o["referenceNumber"]}",
                            style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                        Text("المتجر: ${o["shopName"]}"),
                        Text("المجموع: ${o["total"]} ل.س"),
                        Text("الوقت: ${o["createdAtFormatted"]}"),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _statusText(o["status"]),
                                style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OrderDetailsPage(orderId: o["orderId"]),
                                  ),
                                );
                              },
                              child: const Text("عرض التفاصيل"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _noOrders(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset("assets/images/noorder.png", width: 160, height: 160),
          const SizedBox(height: 20),
          const Text(
            "ليس لديك طلبات جارية",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "ابدأ طلبك الأول من المتاجر المميزة 👇",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const Dashboard(initialIndex: 2)), // 👈 تبويب التسوق
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF988561),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("العودة إلى المتاجر",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.grey;
      case "accepted":
        return Colors.blue;
      case "preparing":
        return Colors.orange;
      case "on_the_way":
        return Colors.purple;
      case "delivered":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.black54;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case "pending":
        return "طلبك قيد المراجعة";
      case "accepted":
        return "تم القبول";
      case "preparing":
        return "قيد التحضير";
      case "on_the_way":
        return "قيد التوصيل";
      case "delivered":
        return "تم التسليم";
      case "rejected":
        return "مرفوض";
      default:
        return status;
    }
  }
}
