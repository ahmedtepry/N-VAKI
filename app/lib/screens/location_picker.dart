import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/common.dart';
import '../core/app.dart';
import '../core/theme.dart';

const kCairo = LatLng(30.0444, 31.2357);
const kTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Current GPS position, or null (with a friendly toast) if it is unavailable.
Future<LatLng?> currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      toast(tr('شغّل الموقع (GPS) من إعدادات الموبايل', 'Turn on location (GPS) in your phone settings'));
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      toast(tr('محتاجين إذن الموقع عشان نحدد مكانك', 'Location permission is needed'));
      return null;
    }
    final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
    return LatLng(p.latitude, p.longitude);
  } catch (_) {
    toast(tr('مقدرناش نحدد موقعك. حرّك الدبوس يدويًا.', 'Could not get your location. Move the pin by hand.'));
    return null;
  }
}

/// Pan the map under the fixed pin, or jump to your GPS position. Returns the chosen point.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const LocationPickerScreen({this.initial});
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final map = MapController();
  late LatLng center = widget.initial ?? kCairo;
  bool locating = false;

  Future<void> _me() async {
    setState(() => locating = true);
    final p = await currentLocation();
    if (p != null && mounted) {
      map.move(p, 17);
      setState(() => center = p);
    }
    if (mounted) setState(() => locating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('حدّد موقع التوصيل', 'DELIVERY LOCATION'))),
      body: Stack(children: [
        FlutterMap(
          mapController: map,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initial == null ? 12 : 17,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onPositionChanged: (cam, _) => center = cam.center,
          ),
          children: [
            TileLayer(urlTemplate: kTiles, userAgentPackageName: 'com.novaki.app'),
            const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
          ],
        ),
        const IgnorePointer(child: Center(child: Padding(padding: EdgeInsets.only(bottom: 44), child: Icon(Icons.location_on, size: 50, color: C.neon)))),
        Positioned(
          right: 14,
          bottom: 100,
          child: FloatingActionButton.small(
            heroTag: 'me',
            backgroundColor: C.bg,
            foregroundColor: C.ink,
            elevation: 2,
            onPressed: locating ? null : _me,
            child: locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 22,
          child: SafeArea(child: NeonButton(tr('تأكيد الموقع', 'Confirm location'), icon: Icons.check_rounded, onPressed: () => Navigator.of(context).pop(center))),
        ),
      ]),
    );
  }
}
