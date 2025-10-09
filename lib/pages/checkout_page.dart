import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'Shopping.dart';
import 'full_map_page.dart';
import 'package:otaibah_app/services/notification_sender.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/services.dart';


import 'my_orders_page.dart';
import 'order_tracking_page.dart';
//import 'package:intl/intl.dart';

class CheckoutPage extends StatefulWidget {
  final String shopId;
  final String shopName;
  final int deliveryTime;
  final double total;
  final List<Map<String, dynamic>> cartItems; // 👈 هذا السطر المهم
  final String? note; // ✅ هذا هو الجديد

  const CheckoutPage({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.deliveryTime,
    required this.total,
    required this.cartItems,
    this.note,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  LatLng? _selectedLocation;
  String _autoAddress = "جارِ تحديد الموقع...";
  Map<String, String>? _manualAddressData;
  String _paymentMethod = "نقدًا عند الاستلام";

  // مركز العتيبة
  final LatLng otaibahCenter = LatLng(33.4837859, 36.6063064);
  final double allowedRadius = 2000; // مترين كم

  final String _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","stylers":[{"color":"#e0e0e0"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#bdbdbd"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    LatLng pos = LatLng(position.latitude, position.longitude);
    if (_isInsideOtaibah(pos)) {
      setState(() => _selectedLocation = pos);
      _getAddress(pos);
    } else {
      setState(() => _selectedLocation = otaibahCenter);
      _getAddress(otaibahCenter);
    }
  }

  bool _isInsideOtaibah(LatLng pos) {
    double d = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, otaibahCenter.latitude, otaibahCenter.longitude);
    return d <= allowedRadius;
  }

  Future<void> _getAddress(LatLng pos) async {
    try {
      final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() => _autoAddress = "${p.locality ?? ''} - ${p.street ?? ''}");
      }
    } catch (_) {
      setState(() => _autoAddress = "تعذّر جلب العنوان, يجب إدخال العنوان يدويّاً");
    }
  }

  // ===== BottomSheet للعنوان اليدوي =====
  void _openManualSheet() {
    final hara   = TextEditingController(text: _manualAddressData?["الحارة"] ?? "");
    final house  = TextEditingController(text: _manualAddressData?["المنزل"] ?? "");
    final street = TextEditingController(text: _manualAddressData?["الشارع"] ?? "");
    final phone  = TextEditingController(text: _manualAddressData?["الهاتف"] ?? "");
    final note   = TextEditingController(text: _manualAddressData?["ملاحظات"] ?? "");
    final label  = TextEditingController(text: _manualAddressData?["تسمية"] ?? "");




    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async {
            // 🔹 نحفظ القيم قبل الإغلاق
            setState(() {
              _manualAddressData = {
                "الحارة": hara.text,
                "المنزل": house.text,
                "الشارع": street.text,
                "الهاتف": phone.text,
                "ملاحظات": note.text,
                "تسمية": label.text,
              };
            });
            // 🔹 الشخطة الصغيرة (Grabber)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );

            return true; // يسمح بالإغلاق
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔹 الشخطة الصغيرة (Grabber)
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  _input("اسم الحارة (اختياري)", "الحارة الغربية", hara),
                  _input("رقم المنزل", "12", house),
                  _input("اسم الشارع", "الشهيد أحمد", street),
                  _input("رقم الهاتف", "09xxxxxxxx", phone,
                      type: TextInputType.phone),
                  _input("إرشادات إضافية", "مثلاً: بجانب المدرسة", note),
                  _input("تسمية العنوان", "منزل عائلة فلان", label),

                  const SizedBox(height: 14),


                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final phoneText = phone.text.trim();

                        // 🔹 التحقق من رقم الهاتف
                        final phoneRegex = RegExp(r'^09\d{8}$'); // يبدأ بـ 09 + 8 أرقام

                        if (!phoneRegex.hasMatch(phoneText)) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "❌ الرقم غير صحيح! يجب أن يبدأ بـ 09 ويتكون من 10 أرقام فقط.",
                                textDirection: TextDirection.rtl,
                              ),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(seconds: 3),
                            ),
                          );
                          return;
                        }

                        // ✅ إذا الرقم صحيح → نحفظ العنوان
                        setState(() {
                          _manualAddressData = {
                            "الحارة": hara.text,
                            "المنزل": house.text,
                            "الشارع": street.text,
                            "الهاتف": phoneText,
                            "ملاحظات": note.text,
                            "تسمية": label.text,
                          };
                          print("✅ عنوان يدوي محفوظ: $_manualAddressData");
                        });

                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "حفظ العنوان",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _input(String label, String hint, TextEditingController c,
      {TextInputType type = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: type,
        inputFormatters: type == TextInputType.phone
            ? [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Colors.black26),
          ),
        ),
      ),
    );
  }


  // 👇 حطها هون بعد } للـ onPressed، وقبل build()
  String _monthName(int month) {
    const months = [
      "كانون الثاني", "شباط", "آذار", "نيسان", "أيار", "حزيران",
      "تموز", "آب", "أيلول", "تشرين الأول", "تشرين الثاني", "كانون الأول"
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    // رسوم ثابتة
    const serviceFee = 100.0;
    const deliveryFee = 5000.0;

    // محاكاة القيم (لازم تنحسب مثل الكارت)
    final totalWithoutDiscount = widget.total - serviceFee - deliveryFee;
    final totalWithDiscount = totalWithoutDiscount;
    final saving = 0.0;
    final grandTotal = widget.total;


    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: SvgPicture.asset("assets/svg/back.svg",
                      width: 26, height: 26)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("إكمال الطلب",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(widget.shopName,
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("عنوان التوصيل",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),

              // 🗺️ خريطة + العنوان
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: _selectedLocation ?? otaibahCenter,
                                initialZoom: 15,
                                onTap: (tapPos, latLng) {
                                  setState(() => _selectedLocation = latLng);
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                  userAgentPackageName: 'com.otaibah.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedLocation ?? otaibahCenter,
                                      width: 60,
                                      height: 60,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Color(0xFF988561),
                                        size: 50,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),


                            // 👇 Overlay شفاف فوق الخريطة للنقر
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FullMapPage(
                                          onConfirm: (pos) {
                                            setState(() {
                                              _selectedLocation = pos;
                                            });
                                          },
                                        ),
                                      ),
                                    );


                                    if (result != null && result is Map) {
                                      setState(() {
                                        _selectedLocation = LatLng(result["lat"], result["lng"]);
                                        _manualAddressData = {
                                          "المنزل": result["houseCode"] ?? "",
                                          "ملاحظات": result["notes"] ?? "",
                                          "الهاتف": result["phone"] ?? "",
                                        };
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ✅ هنا العنوان النصي + زر القلم
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: _openManualSheet,
                            icon: SvgPicture.asset("assets/svg/location.svg",
                                width: 22, height: 22),
                          ),
                          // ✅ النص + أيقونة الموقع (محاذاة يمين)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start, // 👈 كلشي لليمين
                              children: [
                                Flexible(
                                  child: _manualAddressData == null
                                      ? Padding(
                                    padding: const EdgeInsets.only(top: 14), // 👈 هون المسافة من الأعلى
                                    child: Text(
                                      _autoAddress,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                      : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _manualAddressData!.entries
                                        .where((e) => e.value.isNotEmpty)
                                        .map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        "${e.key}: ${e.value}",
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 🔹 أيقونة القلم + كلمة تغيير (ما قربت عليهم)
                          GestureDetector(
                            onTap: _openManualSheet,
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  "assets/svg/edit.svg",
                                  width: 16,
                                  height: 16,
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  "إدخــــال \n العنوان \n يدويّــــاً",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.black,
                                    decorationThickness: 1.7,
                                    height: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_manualAddressData != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _manualAddressData = null; // 🔹 نرجع للوضع التلقائي
                          });
                        },
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 57, bottom: 8), // 👈 مسافة من اليمين والأسفل
                              child: Row(
                                children: [
                                  SvgPicture.asset("assets/svg/delete.svg",
                                      width: 15, height: 15, color: Colors.red),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "حذف العنوان",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      decorationColor: Colors.red, // 👈 خط تحت الكلمة
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],

                  ],
                ),
              ),


              const SizedBox(height: 20),

              // 🕒 وقت التوصيل
              const Text("وقت التوصيل",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    SvgPicture.asset("assets/svg/delivery_time.svg",
                        width: 20, height: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "سيصل طلبك خلال ${widget.deliveryTime + 10} دقيقة تقريباً",
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 💰 الدفع
              const Text("الدفع عبر",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Column(
                children: [
                  RadioListTile(
                      title: const Text("نقدًا عند الاستلام"),
                      value: "نقدًا عند الاستلام",
                      groupValue: _paymentMethod,
                      onChanged: (v) =>
                          setState(() => _paymentMethod = v!)),
                  const DashedDivider(),
                  RadioListTile(
                      title: const Text("شام كاش"),
                      value: "شام كاش",
                      groupValue: _paymentMethod,
                      onChanged: (v) =>
                          setState(() => _paymentMethod = v!)),
                  const DashedDivider(),
                  RadioListTile(
                      title: const Text("سيريتل كاش"),
                      value: "سيريتل كاش",
                      groupValue: _paymentMethod,
                      onChanged: (v) =>
                          setState(() => _paymentMethod = v!)),
                ],
              ),

              const SizedBox(height: 20),
              const Text("رقم الهاتف للتواصل",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),

              TextField(
                keyboardType: TextInputType.phone,
                onChanged: (v) => setState(() {
                  _manualAddressData ??= {};
                  _manualAddressData!["رقم الهاتف"] = v;
                }),
                decoration: InputDecoration(
                  hintText: "أدخل رقم هاتفك (إجباري)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: Colors.black26),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 💵 ملخص الدفع
              const Text("ملخص الدفع",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow("السعر قبل الخصم", totalWithoutDiscount),
                  _summaryRow("المجموع الفرعي", totalWithDiscount),
                  _summaryRow("التوفير", -saving, valueColor: Colors.green),
                  _summaryRow("رسوم الخدمة", serviceFee),
                  _summaryRow("رسوم التوصيل", deliveryFee),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: DashedDivider(color: Colors.black26),
                  ),
                  _summaryRow("الإجمالي", grandTotal, isTotal: true),
                ],
              ),

              const SizedBox(height: 30),

              // زر الإرسال
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("يجب تسجيل الدخول لإرسال الطلب")),
                      );
                      return;
                    }

                    // 🔹 تحقق من رقم الهاتف قبل إرسال الطلب
                    final phoneText = _manualAddressData?["رقم الهاتف"]?.trim() ?? "";

                    // إذا المستخدم ما كتب رقم
                    if (phoneText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "⚠️ يرجى إدخال رقم الهاتف قبل إرسال الطلب.",
                            textDirection: TextDirection.rtl,
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // 🔹 تحقق من صيغة الرقم
                    final phoneRegex = RegExp(r'^09\d{8}$'); // يبدأ بـ09 وطوله 10 أرقام
                    if (!phoneRegex.hasMatch(phoneText)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "❌ الرقم غير صحيح! يجب أن يبدأ بـ 09 ويتكوّن من 10 أرقام فقط.",
                            textDirection: TextDirection.rtl,
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // ✅ إذا الرقم صحيح نكمل
                    final db = FirebaseDatabase.instance;
                    final userDataSnap = await db.ref("otaibah_users/${user.uid}").get();
                    final userName = userDataSnap.child("name").value?.toString() ??
                        (user.displayName ?? "مستخدم");

                    final userPhone = phoneText; // 👈 استخدم الرقم المدخل من المستخدم


                    if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("يجب تسجيل الدخول لإرسال الطلب")),
                        );
                        return;
                      }


                      // توليد رقم طلب تسلسلي مثل OT00001
                      final ordersRef = db.ref("orders");
                      final lastSnap = await ordersRef.limitToLast(1).get();
                      int nextNumber = 1;
                      if (lastSnap.exists) {
                        final lastOrder = lastSnap.children.first;
                        final lastRef = (lastOrder.child("referenceNumber").value ?? "OT00000").toString();
                        final numPart = int.tryParse(lastRef.replaceAll("OT", "")) ?? 0;
                        nextNumber = numPart + 1;
                      }
                      final referenceNumber = "OT${nextNumber.toString().padLeft(5, '0')}";

                      // 🔹 قراءة الأصناف من السلة
                      final cartRef = db.ref("carts/${user.uid}/${widget.shopId}"); // ✅ جمع
                      final cartSnap = await cartRef.get();

                      if (!cartSnap.exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("سلتك فارغة")),
                        );
                        return;
                      }

                      final items = <String, dynamic>{};
                      double subtotal = 0;

                      for (int i = 0; i < widget.cartItems.length; i++) {
                        final item = widget.cartItems[i];
                        final price = (item["price"] ?? 0).toDouble();
                        final qty = (item["qty"] ?? 1).toDouble();

                        items["item_${i + 1}"] = {
                          "name": item["name"],
                          "qty": qty,
                          "price": price,
                          "total": price * qty,
                        };

                        subtotal += price * qty;
                      }


                      const serviceFee = 100.0;
                      const deliveryFee = 5000.0;
                      final grandTotal = subtotal + serviceFee + deliveryFee;

                      final chosenAddress = _manualAddressData != null
                          ? _manualAddressData
                          : {"العنوان": _autoAddress};

                      final orderRef = ordersRef.push();

                      final now = DateTime.now();
                      final formattedDate =
                          "${now.day} تشرين ${_monthName(now.month)} ${now.year}، ${now.hour}:${now.minute.toString().padLeft(2, '0')}";

                      final orderData = {
                        "orderId": orderRef.key,
                        "referenceNumber": referenceNumber,
                        "shopId": widget.shopId,
                        "shopName": widget.shopName,
                        "userId": user.uid,
                        "userName": userName,
                        "userPhone": userPhone,
                        "notes": [
                          if (widget.note?.isNotEmpty ?? false) widget.note,
                          if ((_manualAddressData?["ملاحظات"]?.toString().isNotEmpty ?? false))
                            _manualAddressData!["ملاحظات"]
                        ].join(" — "),
                        "items": items,
                        "subtotal": subtotal,
                        "serviceFee": serviceFee,
                        "deliveryFee": deliveryFee,
                        "total": grandTotal,
                        "paymentMethod": "نقدًا عند الاستلام",
                        "status": "pending",
                        "timestamp": ServerValue.timestamp,
                        "createdAtFormatted": formattedDate,
                        "deliveryTime": widget.deliveryTime,
                        "address": chosenAddress,
                        "orderType": "طلب عبر التطبيق",
                        "isPaid": false,
                        "rejectionReason": "",
                        "latitude": _selectedLocation?.latitude,
                        "longitude": _selectedLocation?.longitude,
                      };


                      await orderRef.set(orderData);
                      await db.ref("user_orders/${user.uid}/${orderRef.key}").set(orderData);

                      await cartRef.remove();


                      try {
                        // 🟢 جلب اسم المستخدم الحقيقي من قاعدة بيانات otaibah_users
                        String userName = "مستخدم";
                        try {
                          final userDataSnap = await db.ref("otaibah_users/${user.uid}").get();
                          if (userDataSnap.exists) {
                            final userData = Map<String, dynamic>.from(userDataSnap.value as Map);
                            userName = userData["name"] ?? "مستخدم";
                          }
                        } catch (e) {
                          print("⚠️ فشل جلب الاسم من otaibah_users: $e");
                        }


                        String? merchantToken;
                        final singleRef = db.ref("merchants/${widget.shopId}/fcmToken");
                        final singleSnap = await singleRef.get();
                        if (singleSnap.exists) merchantToken = singleSnap.value.toString();

                        if (merchantToken != null && merchantToken.isNotEmpty) {
                          await NotificationSender.send(
                            token: merchantToken,
                            title: "طلب جديد من $userName",
                            body: "طلب رقم $referenceNumber يحتوي ${items.length} صنفًا بانتظار المراجعة.",
                            data: {"orderId": orderRef.key!, "click_action": "FLUTTER_NOTIFICATION_CLICK"},
                          );

                        }
                      } catch (e) {
                        print("❌ خطأ أثناء إرسال الإشعار: $e");
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ تم إرسال الطلب بنجاح")),
                      );

                    // ✅ بعد إرسال الطلب، نوجّه المستخدم إلى صفحة "طلباتي"
                    // ✅ بعد إرسال الطلب، نوجّه المستخدم إلى صفحة تتبع الطلب
                    // ✅ بعد إرسال الطلب، نوجّه المستخدم إلى صفحة "طلباتي"
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MyOrdersPage(fromCheckout: true)),
                          (route) => false,
                    );


                  },

                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text("إرسال الطلب",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value,
      {bool isTotal = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w400,
                  fontSize: isTotal ? 15 : 13)),
          Text("${value.toStringAsFixed(0)} ل.س",
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w400,
                  fontSize: isTotal ? 15 : 13,
                  color: valueColor ?? Colors.black)),
        ],
      ),
    );
  }
}

// ===== خط متقطع =====
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
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            );
          }),
        );
      },
    );
  }
}
