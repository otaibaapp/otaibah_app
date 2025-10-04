import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FullMapPage extends StatefulWidget {
  final LatLng initialLocation;
  final bool Function(LatLng) isInsideOtaibah;
  final String mapStyle;
  final String? pinAsset;

  const FullMapPage({
    super.key,
    required this.initialLocation,
    required this.isInsideOtaibah,
    required this.mapStyle,
    this.pinAsset,
  });

  @override
  State<FullMapPage> createState() => _FullMapPageState();
}

class _FullMapPageState extends State<FullMapPage> {
  GoogleMapController? _mapController;
  LatLng? _chosenLocation;

  final LatLng otaibahCenter =
  const LatLng(33.48378590169768, 36.606306415046895);

  @override
  void initState() {
    super.initState();
    _chosenLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _chosenLocation!, zoom: 15),
            onMapCreated: (c) {
              _mapController = c;
              _mapController!.setMapStyle(widget.mapStyle);
            },
            onCameraMove: (pos) => setState(() => _chosenLocation = pos.target),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            circles: {
              Circle(
                circleId: const CircleId("otaibah"),
                center: otaibahCenter,
                radius: 2000,
                fillColor: Colors.orange.withOpacity(0.15),
                strokeColor: Colors.orange,
                strokeWidth: 2,
              )
            },
          ),

          // الدبوس بالوسط
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.pinAsset != null
                  ? SvgPicture.asset(widget.pinAsset!, width: 50, height: 50)
                  : Icon(Icons.location_pin, color: Colors.amber[800], size: 50),
            ],
          ),

          // زر تأكيد
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _chosenLocation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("تأكيد الموقع",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
