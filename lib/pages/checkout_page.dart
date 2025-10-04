import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'full_map_page.dart';

class CheckoutPage extends StatefulWidget {
  final String shopId;
  final String shopName;
  final int deliveryTime;
  final double total;

  const CheckoutPage({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.deliveryTime,
    required this.total,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _autoAddress = "جارِ تحديد الموقع...";
  Map<String, String>? _manualAddressData;
  String _paymentMethod = "نقدًا عند الاستلام";

  // مركز العتيبة
  final LatLng otaibahCenter =
  const LatLng(33.48378590169768, 36.606306415046895);
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
                        setState(() {
                          _manualAddressData = {
                            "الحارة": hara.text,
                            "المنزل": house.text,
                            "الشارع": street.text,
                            "الهاتف": phone.text,
                            "ملاحظات": note.text,
                            "تسمية": label.text,
                          };
                          print("✅ عنوان يدوي محفوظ: $_manualAddressData");
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text("حفظ العنوان",
                          style: TextStyle(color: Colors.white)),
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
                            GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: otaibahCenter,
                                zoom: 14,
                              ),
                              onMapCreated: (c) => c.setMapStyle(_mapStyle),
                              markers: _selectedLocation != null
                                  ? {
                                Marker(
                                  markerId: const MarkerId("sel"),
                                  position: _selectedLocation!,
                                )
                              }
                                  : {},
                              zoomControlsEnabled: false,
                              scrollGesturesEnabled: false,
                              rotateGesturesEnabled: false,
                              tiltGesturesEnabled: false,
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
                                          initialLocation: _selectedLocation ?? otaibahCenter,
                                          isInsideOtaibah: _isInsideOtaibah,
                                          mapStyle: _mapStyle,
                                          pinAsset: "assets/svg/pin.svg",
                                        ),
                                      ),
                                    );
                                    if (result != null && result is LatLng) {
                                      setState(() {
                                        _selectedLocation = result;
                                      });
                                      _getAddress(result);
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
                      child: Text("سيصل طلبك خلال ${widget.deliveryTime} دقيقة",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87)),
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
                  onPressed: () {
                    final chosenAddress = _manualAddressData != null
                        ? _manualAddressData.toString()
                        : _autoAddress;

                    // هون مثلاً بتطبع أو بتخزن في Firebase
                    print("📌 العنوان المعتمد: $chosenAddress");
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
