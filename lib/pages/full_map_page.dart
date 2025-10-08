import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';


class FullMapPage extends StatefulWidget {
  final Function(LatLng)? onConfirm;

  const FullMapPage({super.key, this.onConfirm});

  @override
  State<FullMapPage> createState() => _FullMapPageState();
}

class _FullMapPageState extends State<FullMapPage> {
  late final MapController _mapController;
  LatLng _currentCenter = const LatLng(33.4838, 36.6063);
  LatLng? _currentLocation;
  double _currentZoom = 15.5;
  String _mapType = "satellite";

  final LatLng otaibahCenter = const LatLng(33.4838, 36.6063);
  final double allowedRadius = 3000; // حدود بلدة العتيبة
  final double viewRadiusLimit = 6000; // أقصى مدى للزووم الخارجي
  final Distance distance = const Distance();

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  // === تحديد الموقع الحالي ===
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position pos = await Geolocator.getCurrentPosition();
    LatLng position = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _currentLocation = position;
      _currentCenter = position;
    });
    _mapController.move(position, _currentZoom);
  }

  // === تحريك ضمن حدود الخريطة فقط ===
  void _moveWithinBounds(LatLng dest, double zoom) {
    final double dist = distance(otaibahCenter, dest);
    if (dist > viewRadiusLimit) return; // منع الابتعاد كثيراً
    _mapController.move(dest, zoom);
    setState(() {
      _currentCenter = dest;
      _currentZoom = zoom;
    });
  }

  // === تبديل نوع الخريطة ===
  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == "satellite" ? "roads" : "satellite";
    });
  }

  // === تكبير وتصغير ===
  void _zoomIn() {
    _currentZoom = (_currentZoom + 0.4).clamp(12.0, 19.0);
    _moveWithinBounds(_currentCenter, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 0.4).clamp(12.0, 19.0);
    _moveWithinBounds(_currentCenter, _currentZoom);
  }

  // === تحقق من داخل حدود العتيبة ===
  bool _isInsideOtaibah(LatLng point) {
    final double d = distance(otaibahCenter, point);
    return d <= allowedRadius;
  }

  // === مضلع العالم (لتظليل ما حول البلدة) ===
  List<LatLng> _generateWorldPolygon() {
    return [
      const LatLng(-85, -180),
      const LatLng(85, -180),
      const LatLng(85, 180),
      const LatLng(-85, 180),
    ];
  }

  // === إنشاء ثقب دائرة واضح حول البلدة ===
  List<LatLng> _generateCircleHole({
    required LatLng center,
    required double radiusInMeters,
    int segments = 80,
  }) {
    const Distance distance = Distance();
    List<LatLng> points = [];
    for (var i = 0; i < segments; i++) {
      final bearing = (360 / segments) * i;
      final p = distance.offset(center, radiusInMeters, bearing);
      points.add(p);
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final String tileUrl = _mapType == "satellite"
        ? "https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}"
        : "https://tile.openstreetmap.org/{z}/{x}/{y}.png";

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // ===== الخريطة =====
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: otaibahCenter,
                initialZoom: _currentZoom,
                maxZoom: 19.5,
                minZoom: 12.0,
                interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
                onTap: (tapPos, point) {
                  if (_isInsideOtaibah(point)) {
                    setState(() => _currentLocation = point);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.redAccent,
                        content: Text(
                          "❌ النقطة خارج حدود بلدة العتيبة (مسموح فقط ضمن 5 كم من المركز)",
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    );
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'com.otaibah.app',
                  retinaMode: true,
                ),

                // تظليل كل العالم ما عدا منطقة العتيبة
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _generateWorldPolygon(),
                      holePointsList: [
                        _generateCircleHole(
                          center: otaibahCenter,
                          radiusInMeters: allowedRadius,
                        ),
                      ],
                      color: Colors.black.withOpacity(0.55),
                      borderColor: Colors.transparent,
                    ),
                  ],
                ),

                // الحدود الذهبية للعتيبة
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: otaibahCenter,
                      radius: allowedRadius,
                      useRadiusInMeter: true,
                      color: Colors.transparent,
                      borderStrokeWidth: 2.5,
                      borderColor: const Color(0xFF988561),
                    ),
                  ],
                ),

                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 60,
                        height: 60,
                        child: SvgPicture.asset(
                          'assets/svg/pin.svg',
                          width: 50,
                          height: 50,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // ===== أزرار التحكم =====
            Positioned(
              top: 45,
              right: 15,
              child: Column(
                children: [
                  // تبديل القمر الصناعي / المسارات
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.black.withOpacity(0.8),
                    onPressed: _toggleMapType,
                    child: Icon(
                      _mapType == "satellite" ? Icons.map : Icons.satellite_alt,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // تحديد موقعي الحالي 🔄
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.black.withOpacity(0.8),
                    onPressed: _getCurrentLocation,
                    child: const Icon(Icons.my_location,
                        color: Color(0xFFFFFFFF)),
                  ),
                ],
              ),
            ),

            // ===== أزرار الزووم والرجوع =====
            Positioned(
              top: 45,
              left: 15,
              child: Column(
                children: [
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.black.withOpacity(0.8),
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        color: Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.black.withOpacity(0.8),
                    onPressed: _zoomIn,
                    child:
                    const Icon(Icons.add, color: Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.black.withOpacity(0.8),
                    onPressed: _zoomOut,
                    child:
                    const Icon(Icons.remove, color: Color(0xFFFFFFFF)),
                  ),
                ],
              ),
            ),

            // ===== البوتوم شييت =====
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight, // ✅ يجبره يكون يمين بالكامل
                      child: const Text(
                        "معلومات إضافيّة ( إختياريّة )",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),


                    const SizedBox(height: 10),
                    TextField(
                      controller: _noteController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: "اسم الحي أو المنطقة (اختياري)",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          const BorderSide(color: Colors.black12, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _detailsController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: "تفاصيل إضافية مثل: بيت أبو فلان... (اختياري)",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          const BorderSide(color: Colors.black12, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentLocation == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text("❌ يرجى اختيار موقعك على الخريطة"),
                              ),
                            );
                            return;
                          }

                          if (!_isInsideOtaibah(_currentLocation!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text(
                                  "❌ الموقع المحدد خارج حدود بلدة العتيبة",
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            );
                            return;
                          }

                          // ✅ نرجع البيانات إلى صفحة CheckoutPage
                          Navigator.pop(context, {
                            "lat": _currentLocation!.latitude,
                            "lng": _currentLocation!.longitude,
                            "note": _noteController.text,
                            "details": _detailsController.text,
                          });

                          // ✅ إشعار نجاح سريع
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "✅ تم تحديد الموقع بنجاح، يمكنك متابعة الطلب",
                                textDirection: TextDirection.rtl,
                              ),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );

                          // ✅ تنظيف الحقول بعد الإرسال
                          _noteController.clear();
                          _detailsController.clear();
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "تأكيد الموقع",
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
