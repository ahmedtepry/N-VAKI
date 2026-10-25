import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../dash/dash_work.dart' show openUrl;
import 'location_picker.dart';

const _steps = ['new', 'confirmed', 'packed', 'shipped', 'delivered'];

double _km(LatLng a, LatLng b) => const Distance().as(LengthUnit.Kilometer, a, b);

LatLng? _pt(dynamic lat, dynamic lng) => lat == null || lng == null ? null : LatLng(toD(lat), toD(lng));

/// Live tracking for a signed-in customer: the order row streams in, so the courier moves on the map.
class TrackScreen extends StatefulWidget {
  final String orderId;
  const TrackScreen({required this.orderId});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  Json? order;
  List<Json> timeline = [];
  Object? error;
  StreamSubscription? sub;
  Timer? poll;

  @override
  void initState() {
    super.initState();
    _load();
    sub = App.i.db.from('orders').stream(primaryKey: ['id']).eq('id', widget.orderId).listen((rows) {
      if (rows.isNotEmpty && mounted) {
        setState(() => order = {...?order, ...Json.from(rows.first)});
        _history();
      }
    }, onError: (_) {});
    poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    sub?.cancel();
    poll?.cancel();
    super.dispose();
  }

  Future<void> _history() async {
    try {
      final h = await Api.orderHistory(widget.orderId);
      if (mounted) setState(() => timeline = h.map((e) => {'status': e['status'], 'note': e['note'], 'at': e['created_at']}).toList());
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final r = Json.from(await App.i.db.from('orders').select().eq('id', widget.orderId).single());
      if (mounted) {
        setState(() {
          order = r;
          error = null;
        });
      }
      await _history();
    } catch (e) {
      if (mounted && order == null) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Scaffold(
      appBar: AppBar(title: Text(o == null ? tr('تتبع الطلب', 'TRACK ORDER') : '#${o['order_no']}')),
      body: error != null
          ? ErrorRetry(error!, _load)
          : o == null
              ? const Loading()
              : TrackBody(order: o, timeline: timeline),
    );
  }
}

/// Track an order without an account: order number + the phone used on the order.
class GuestTrackScreen extends StatefulWidget {
  const GuestTrackScreen();
  @override
  State<GuestTrackScreen> createState() => _GuestTrackScreenState();
}

class _GuestTrackScreenState extends State<GuestTrackScreen> {
  final no = TextEditingController(), phone = TextEditingController();
  Json? result;
  bool busy = false, notFound = false;
  Timer? poll;

  @override
  void dispose() {
    no.dispose();
    phone.dispose();
    poll?.cancel();
    super.dispose();
  }

  Future<void> _go({bool quiet = false}) async {
    if (!quiet) {
      FocusScope.of(context).unfocus();
      setState(() {
        busy = true;
        notFound = false;
      });
    }
    try {
      final r = await Api.trackOrder(no.text, phone.text);
      if (!mounted) return;
      setState(() {
        result = r;
        notFound = r == null;
      });
      poll?.cancel();
      if (r != null) poll = Timer.periodic(const Duration(seconds: 15), (_) => _go(quiet: true));
    } catch (e) {
      if (!quiet) toastError(e);
    } finally {
      if (mounted && !quiet) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Scaffold(
      appBar: AppBar(title: Text(tr('تتبع طلب', 'TRACK AN ORDER'))),
      body: r != null
          ? TrackBody(
              order: {...r, 'created_at': r['created_at']},
              timeline: (r['timeline'] as List).map((e) => Json.from(e)).toList(),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 30), children: [
              Text(tr('اكتب رقم الطلب ورقم الموبايل اللي طلبت بيه.', 'Enter your order number and the phone number used on the order.'), style: const TextStyle(color: C.mute, height: 1.5)),
              const SizedBox(height: 10),
              TextField(controller: no, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('رقم الطلب (مثلاً 1001)', 'Order number (e.g. 1001)'))),
              TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('رقم الموبايل', 'Phone number'))),
              if (notFound) Padding(padding: const EdgeInsets.only(top: 14), child: Text(tr('مش لاقيين طلب بالبيانات دي. راجع الرقمين.', 'No order matches those details. Check both numbers.'), style: const TextStyle(color: C.danger))),
              const SizedBox(height: 22),
              NeonButton(tr('تتبّع', 'Track'), icon: Icons.local_shipping_outlined, onPressed: _go, loading: busy),
            ]),
    );
  }
}

class TrackBody extends StatefulWidget {
  final Json order;
  final List<Json> timeline;
  const TrackBody({required this.order, required this.timeline});
  @override
  State<TrackBody> createState() => _TrackBodyState();
}

class _TrackBodyState extends State<TrackBody> {
  final map = MapController();
  bool ready = false;

  void _fit() {
    final o = widget.order;
    final d = _pt(o['dest_lat'], o['dest_lng']);
    final c = o['status'] == 'shipped' ? _pt(o['courier_lat'], o['courier_lng']) : null;
    if (!ready) return;
    try {
      if (d != null && c != null) {
        map.fitCamera(CameraFit.bounds(bounds: LatLngBounds(d, c), padding: const EdgeInsets.all(56), maxZoom: 17));
      } else if (d != null || c != null) {
        map.move((d ?? c)!, 15.5);
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant TrackBody old) {
    super.didUpdateWidget(old);
    if (old.order['courier_lat'] != widget.order['courier_lat'] || old.order['courier_lng'] != widget.order['courier_lng'] || old.order['status'] != widget.order['status']) _fit();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final status = '${o['status']}';
    final dest = _pt(o['dest_lat'], o['dest_lng']);
    final courier = status == 'shipped' ? _pt(o['courier_lat'], o['courier_lng']) : null;
    final eta = o['delivery_eta'] == null ? null : DateTime.tryParse('${o['delivery_eta']}')?.toLocal();
    final etaMin = eta == null ? null : math.max(1, eta.difference(DateTime.now()).inMinutes);
    final km = dest != null && courier != null ? _km(courier, dest) : null;
    final cancelled = status == 'cancelled';
    final at = _steps.indexOf(status);
    final name = (o['courier_name'] ?? '').toString();
    final cphone = (o['courier_phone'] ?? '').toString();

    String stepLabel(String s) => statusLabel(s);
    final tl = widget.timeline;
    String? timeOf(String s) {
      for (final e in tl) {
        if (e['status'] == s && e['at'] != null) return fmtDate('${e['at']}');
      }
      return null;
    }

    final notes = tl.where((e) => (e['note'] ?? '').toString().trim().isNotEmpty).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 30), children: [
      // ---------- map ----------
      SizedBox(
        height: 290,
        child: dest == null && courier == null
            ? Container(
                color: C.card,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_off_outlined, size: 34, color: C.mute),
                  const SizedBox(height: 8),
                  Text(tr('الموقع على الخريطة مش متحدد لهذا الطلب.', 'No map location was set for this order.'), textAlign: TextAlign.center, style: const TextStyle(color: C.mute)),
                ]),
              )
            : FlutterMap(
                mapController: map,
                options: MapOptions(
                  initialCenter: courier ?? dest!,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onMapReady: () {
                    ready = true;
                    _fit();
                  },
                ),
                children: [
                  TileLayer(urlTemplate: kTiles, userAgentPackageName: 'com.novaki.app'),
                  if (dest != null && courier != null) PolylineLayer(polylines: [Polyline(points: [courier, dest], strokeWidth: 3.5, color: C.neon.withValues(alpha: 0.7), pattern: StrokePattern.dashed(segments: const [8, 8]))]),
                  MarkerLayer(markers: [
                    if (dest != null) Marker(point: dest, width: 46, height: 52, alignment: Alignment.topCenter, child: const Icon(Icons.location_on, size: 46, color: C.neon)),
                    if (courier != null)
                      Marker(
                        point: courier,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(color: C.ink, shape: BoxShape.circle, border: Border.all(color: C.onNeon, width: 2.5), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)]),
                          child: const Icon(Icons.two_wheeler_rounded, color: C.onNeon, size: 22),
                        ),
                      ),
                  ]),
                  const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
                ],
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            StatusChip(statusLabel(status), statusColor(status)),
            const Spacer(),
            if (o['created_at'] != null) Text(fmtDate('${o['created_at']}'), style: const TextStyle(color: C.mute, fontSize: 11)),
          ]),
          if (status == 'shipped') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.ink)),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle), child: const Icon(Icons.two_wheeler_rounded, color: C.onNeon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(courier == null ? tr('طلبك خرج للتوصيل', 'Your order is out for delivery') : (etaMin != null ? tr('هيوصل خلال حوالي $etaMin دقيقة', 'Arriving in about $etaMin min') : tr('المندوب في الطريق', 'Courier is on the way')), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text([
                      if (name.isNotEmpty) name,
                      if (km != null) tr('${km.toStringAsFixed(1)} كم', '${km.toStringAsFixed(1)} km away'),
                      if (courier == null) tr('بنستنى مشاركة موقع المندوب', 'waiting for the courier location'),
                    ].join(' · '), style: const TextStyle(color: C.mute, fontSize: 12)),
                  ]),
                ),
                if (cphone.isNotEmpty) IconButton.filled(style: IconButton.styleFrom(backgroundColor: C.neon), onPressed: () => openUrl('tel:$cphone'), icon: const Icon(Icons.call_rounded, color: C.onNeon)),
              ]),
            ),
          ],
          const SizedBox(height: 22),
          Text(tr('مراحل الطلب', 'ORDER PROGRESS'), style: const TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (cancelled)
            Row(children: [const Icon(Icons.cancel_outlined, color: C.danger), const SizedBox(width: 10), Text(tr('الطلب اتلغى', 'This order was cancelled'), style: const TextStyle(fontWeight: FontWeight.w800, color: C.danger))])
          else
            for (var i = 0; i < _steps.length; i++)
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Column(children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: i <= at ? C.neon : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: i <= at ? C.neon : C.line, width: 1.6)),
                      child: i <= at ? const Icon(Icons.check_rounded, size: 14, color: C.onNeon) : null,
                    ),
                    if (i < _steps.length - 1) Expanded(child: Container(width: 2, color: i < at ? C.neon : C.line)),
                  ]),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(stepLabel(_steps[i]), style: TextStyle(fontWeight: i == at ? FontWeight.w900 : FontWeight.w600, color: i <= at ? C.ink : C.mute)),
                        if (timeOf(_steps[i]) != null) Text(timeOf(_steps[i])!, style: const TextStyle(fontSize: 11.5, color: C.mute)),
                      ]),
                    ),
                  ),
                ]),
              ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(tr('رسائل من الفريق', 'MESSAGES FROM THE TEAM'), style: const TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final n in notes.reversed)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.tint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${n['note']}', style: const TextStyle(height: 1.4)),
                  if (n['at'] != null) Text(fmtDate('${n['at']}'), style: const TextStyle(fontSize: 11, color: C.mute)),
                ]),
              ),
          ],
        ]),
      ),
    ]);
  }
}

/// Staff tools for a shipped order: share my live location with the customer, open the destination, post an update.
class DeliveryPanel extends StatefulWidget {
  final Json order;
  final VoidCallback onChanged;
  const DeliveryPanel({required this.order, required this.onChanged});
  @override
  State<DeliveryPanel> createState() => _DeliveryPanelState();
}

class _DeliveryPanelState extends State<DeliveryPanel> {
  Timer? timer;
  bool sharing = false;
  DateTime? lastSent;
  final msg = TextEditingController();
  bool posting = false;

  String get id => '${widget.order['id']}';

  @override
  void dispose() {
    timer?.cancel();
    msg.dispose();
    super.dispose();
  }

  Future<void> _ping() async {
    final p = await currentLocation();
    if (p == null) return;
    try {
      await Api.courierPing(id, p.latitude, p.longitude);
      if (mounted) setState(() => lastSent = DateTime.now());
    } catch (e) {
      toastError(e);
    }
  }

  void _toggle(bool on) {
    setState(() => sharing = on);
    timer?.cancel();
    if (on) {
      _ping();
      timer = Timer.periodic(const Duration(seconds: 10), (_) => _ping());
    }
  }

  Future<void> _post() async {
    if (msg.text.trim().length < 2) return;
    setState(() => posting = true);
    try {
      await Api.postOrderUpdate(id, msg.text);
      msg.clear();
      toast(tr('اتبعت للعميل ✓', 'Sent to the customer ✓'));
      widget.onChanged();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final dest = _pt(o['dest_lat'], o['dest_lng']);
    final shipped = o['status'] == 'shipped';
    final canManage = App.i.can('orders_manage');
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('التوصيل والتتبع', 'DELIVERY & TRACKING'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: [
          Icon(dest == null ? Icons.location_off_outlined : Icons.location_on, color: dest == null ? C.mute : C.neon),
          const SizedBox(width: 8),
          Expanded(child: Text(dest == null ? tr('العميل ماحددش موقع على الخريطة', 'The customer did not pin a location') : tr('العميل حدد موقع التوصيل', 'Customer pinned the delivery location'), style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          if (dest != null) Expanded(child: NeonButton(tr('افتح في الخرائط', 'Open in Maps'), icon: Icons.directions_outlined, outline: true, onPressed: () => openUrl('https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}'))),
          if (dest != null) const SizedBox(width: 10),
          Expanded(child: NeonButton(tr('خريطة التتبع', 'Live map'), icon: Icons.map_outlined, outline: true, onPressed: () => Navigator.of(context).push(fadeRoute(TrackScreen(orderId: id))))),
        ]),
        if (shipped && canManage) ...[
          const Divider(height: 26),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: C.onNeon,
            activeTrackColor: C.neon,
            title: Text(tr('شارك موقعي مع العميل', 'Share my live location'), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(sharing ? (lastSent == null ? tr('بيجيب الموقع...', 'Getting location…') : tr('آخر إرسال ${lastSent!.hour}:${lastSent!.minute.toString().padLeft(2, '0')}', 'Last sent ${lastSent!.hour}:${lastSent!.minute.toString().padLeft(2, '0')}')) : tr('سيب الشاشة دي مفتوحة وإنت بتوصّل', 'Keep this screen open while delivering'), style: const TextStyle(fontSize: 12, color: C.mute)),
            value: sharing,
            onChanged: _toggle,
          ),
        ],
        if (canManage) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: msg, decoration: InputDecoration(hintText: tr('رسالة للعميل (مثلاً: المندوب هيوصل بعد ساعة)', 'Message to the customer'), isDense: true))),
            IconButton(onPressed: posting ? null : _post, icon: const Icon(Icons.send_rounded, color: C.neon)),
          ]),
        ],
      ]),
    );
  }
}
