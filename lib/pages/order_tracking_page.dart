import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:otaibah_app/pages/order_tracking_page.dart'; // للتوجيه في حالة النقر على الإشعار نفسه

class OrderTrackingPage extends StatefulWidget {
  final String orderId;
  const OrderTrackingPage({super.key, required this.orderId});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  final DatabaseReference ordersRef = FirebaseDatabase.instance.ref("orders");

  final Map<String, String> statusLabels = {
    "pending": "في انتظار قبول المتجر",
    "accepted": "تم قبول الطلب",
    "preparing": "الطلب قيد التجهيز",
    "on_delivery": "الطلب في الطريق إليك",
    "delivered": "تم توصيل الطلب",
    "rejected": "تم رفض الطلب",
  };

  final List<String> statusOrder = [
    "pending",
    "accepted",
    "preparing",
    "on_delivery",
    "delivered",
    "rejected",
  ];

  @override
  void initState() {
    super.initState();

    // ✅ لو المستخدم ضغط على إشعار (من الخلفية أو الإغلاق)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.containsKey("orderId")) {
        final orderId = message.data["orderId"];
        if (orderId != null && orderId.toString().isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingPage(orderId: orderId),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("متابعة الطلب"),
          backgroundColor: Colors.black,
        ),
        body: StreamBuilder(
          stream: ordersRef.child(widget.orderId).onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(
                child: Text("❌ لم يتم العثور على الطلب"),
              );
            }

            final orderData = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map,
            );

            final currentStatus = orderData["status"] ?? "pending";
            final referenceNumber = orderData["referenceNumber"] ?? "—";

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 رقم الطلب
                  Text(
                    "رقم الطلب: $referenceNumber",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    "حالة الطلب الحالية:",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabels[currentStatus] ?? "غير معروفة",
                    style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: ListView.builder(
                      itemCount: statusOrder.length,
                      itemBuilder: (context, index) {
                        final s = statusOrder[index];
                        final isDone = _isStatusReached(currentStatus, s);
                        final isRejected = currentStatus == "rejected";

                        return Opacity(
                          opacity: isRejected && s != "rejected"
                              ? 0.3
                              : isDone
                              ? 1
                              : 0.4,
                          child: ListTile(
                            leading: Icon(
                              s == "rejected"
                                  ? Icons.cancel
                                  : isDone
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: s == "rejected"
                                  ? Colors.red
                                  : isDone
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            title: Text(statusLabels[s] ?? ""),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (orderData["rejectionReason"] != null &&
                      (orderData["rejectionReason"] as String).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        "سبب الرفض: ${orderData["rejectionReason"]}",
                        style: const TextStyle(color: Colors.red),
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

  bool _isStatusReached(String current, String target) {
    if (current == target) return true;
    if (current == "rejected") return target == "rejected";
    final currentIndex = statusOrder.indexOf(current);
    final targetIndex = statusOrder.indexOf(target);
    return currentIndex >= targetIndex &&
        currentIndex != -1 &&
        targetIndex != -1;
  }
}
