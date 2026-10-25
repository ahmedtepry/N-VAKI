import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import '../widgets/navbar.dart';
import 'chat.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen();
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Json>? orders;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await Api.myOrders();
      if (mounted) setState(() {
            orders = o;
            error = null;
          });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('طلباتي', 'MY ORDERS'))),
      bottomNavigationBar: const NavBar(current: 3),
      body: error != null
          ? ErrorRetry(error!, _load)
          : orders == null
              ? const Loading()
              : orders!.isEmpty
                  ? Empty(tr('لسه ملكش طلبات.', 'No orders yet.'), icon: Icons.inventory_2_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: C.ink,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: orders!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final o = orders![i];
                          final items = (o['order_items'] as List).map((e) => Json.from(e)).toList();
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await Navigator.of(context).push(fadeRoute(OrderDetailScreen(order: o)));
                              _load();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text('#${o['order_no']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  const Spacer(),
                                  StatusChip(statusLabel(o['status']), statusColor(o['status'])),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  for (final it in items.take(4))
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(end: 8),
                                      child: GarmentView(garment: it['garment'] ?? 'tee', color: hexColor(it['color_hex']), width: 34, shadow: false),
                                    ),
                                  const Spacer(),
                                  Text(money(toD(o['total'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                                ]),
                                const SizedBox(height: 6),
                                Text(fmtDate(o['created_at']), style: const TextStyle(color: C.mute, fontSize: 11)),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final Json order;
  const OrderDetailScreen({required this.order});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Json o = widget.order;
  List<Json> history = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final fresh = await App.i.db.from('orders').select('*, order_items(*)').eq('id', o['id']).single();
      final h = await Api.orderHistory(o['id']);
      if (mounted) setState(() {
            o = Json.from(fresh);
            history = h;
          });
    } catch (_) {}
  }

  Future<void> _cancel() async {
    if (!await confirmDialog(context, tr('تلغي الطلب؟', 'Cancel this order?'))) return;
    setState(() => busy = true);
    try {
      await Api.cancelMyOrder(o['id']);
      await _load();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (o['order_items'] as List).map((e) => Json.from(e)).toList();
    final status = o['status'] as String;
    return Scaffold(
      appBar: AppBar(title: Text('#${o['order_no']}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 28), children: [
        Row(children: [StatusChip(statusLabel(status), statusColor(status)), const Spacer(), Text(fmtDate(o['created_at']), style: const TextStyle(color: C.mute, fontSize: 11))]),
        const SizedBox(height: 18),
        _timeline(status),
        const SizedBox(height: 18),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                width: 52,
                height: 58,
                decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
                child: Center(child: GarmentView(garment: it['garment'] ?? 'tee', color: hexColor(it['color_hex']), width: 38, shadow: false)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(it['name_ar'], it['name_en']).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  Text('${tr(it['color_name_ar'], it['color_name_en'])} · ${it['size']} · x${it['qty']}', style: const TextStyle(color: C.mute, fontSize: 12)),
                ]),
              ),
              Text(money(toD(it['unit_price']) * toI(it['qty'])), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        const Divider(height: 28),
        _kv(tr('المجموع', 'Subtotal'), money(toD(o['subtotal']))),
        _kv(tr('الشحن', 'Shipping'), toD(o['shipping_fee']) == 0 ? tr('مجاني', 'Free') : money(toD(o['shipping_fee']))),
        _kv(tr('الإجمالي', 'Total'), money(toD(o['total'])), bold: true),
        const Divider(height: 28),
        Text(tr('التوصيل إلى', 'DELIVER TO').toUpperCase(), style: const TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4)),
        const SizedBox(height: 6),
        Text('${o['customer_name']}\n${o['phone']}\n${o['city']} - ${o['address']}', style: const TextStyle(height: 1.5)),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(tr('سجل الطلب', 'HISTORY'), style: const TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          for (final h in history.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor(h['status']), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(statusLabel(h['status']), style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(fmtDate(h['created_at']), style: const TextStyle(color: C.mute, fontSize: 11)),
              ]),
            ),
        ],
        const SizedBox(height: 26),
        NeonButton(tr('اسأل خدمة العملاء عن الطلب', 'Ask support about this order'), icon: Icons.chat_bubble_outline_rounded, outline: true, onPressed: () => Navigator.of(context).push(fadeRoute(ChatScreen(subject: '#${o['order_no']}', orderId: o['id'])))),
        if (status == 'new') ...[
          const SizedBox(height: 10),
          NeonButton(tr('إلغاء الطلب', 'Cancel order'), onPressed: _cancel, loading: busy, outline: true),
        ],
      ]),
    );
  }

  Widget _kv(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Text(a, style: TextStyle(color: bold ? C.ink : C.mute, fontWeight: bold ? FontWeight.w900 : FontWeight.w500)), const Spacer(), Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600))]),
      );

  Widget _timeline(String status) {
    if (status == 'cancelled') return const SizedBox.shrink();
    const steps = ['new', 'confirmed', 'packed', 'shipped', 'delivered'];
    final at = steps.indexOf(status);
    return Row(children: [
      for (var i = 0; i < steps.length; i++) ...[
        Column(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: i <= at ? C.neon : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: i <= at ? C.ink : C.line, width: 1.2)),
            child: i <= at ? const Icon(Icons.check_rounded, size: 14, color: C.onNeon) : null,
          ),
          const SizedBox(height: 4),
          Text(statusLabel(steps[i]), style: TextStyle(fontSize: 8.5, color: i <= at ? C.ink : C.mute, fontWeight: i == at ? FontWeight.w900 : FontWeight.w500)),
        ]),
        if (i < steps.length - 1) Expanded(child: Container(height: 1.4, margin: const EdgeInsets.only(bottom: 16), color: i < at ? C.ink : C.line)),
      ],
    ]);
  }
}
