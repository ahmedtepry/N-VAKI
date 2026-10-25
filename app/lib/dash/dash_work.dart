import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../screens/chat.dart';
import '../screens/notifications.dart' show fmtAgo;
import '../widgets/garment.dart';

// ===================================================== ORDERS =====================================================
class OrdersTab extends StatefulWidget {
  const OrdersTab();
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<Json> rows = [];
  Map<String, Json> people = {};
  String filter = 'active';
  StreamSubscription? sub;
  Object? error;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    sub = App.i.db.from('orders').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(200).listen((r) async {
      final list = r.map((e) => Json.from(e)).toList();
      final ids = list.map((e) => e['assigned_to']).whereType<String>().toSet().difference(people.keys.toSet());
      if (ids.isNotEmpty) {
        try {
          people = {...people, ...await Api.profilesByIds(ids)};
        } catch (_) {}
      }
      if (mounted) setState(() {
            rows = list;
            loaded = true;
          });
    }, onError: (e) {
      if (mounted) setState(() => error = e);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  List<Json> get shown {
    final me = App.i.user?.id;
    return rows.where((o) {
      final s = o['status'];
      switch (filter) {
        case 'active':
          return s == 'new' || s == 'confirmed' || s == 'packed' || s == 'shipped';
        case 'mine':
          return o['assigned_to'] == me && s != 'delivered' && s != 'cancelled';
        case 'all':
          return true;
        default:
          return s == filter;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      ['active', tr('نشطة', 'Active')],
      ['mine', tr('طلباتي', 'Mine')],
      ['new', tr('جديدة', 'New')],
      ['delivered', tr('اتسلمت', 'Delivered')],
      ['cancelled', tr('ملغية', 'Cancelled')],
      ['all', tr('الكل', 'All')],
    ];
    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Center(
                child: ChoiceChip(
                  label: Text(f[1], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: filter == f[0] ? C.ink : C.mute)),
                  selected: filter == f[0],
                  selectedColor: C.neon,
                  backgroundColor: C.card,
                  showCheckmark: false,
                  side: BorderSide(color: filter == f[0] ? C.ink : C.line),
                  onSelected: (_) => setState(() => filter = f[0]),
                ),
              ),
            ),
        ]),
      ),
      Expanded(
        child: error != null
            ? ErrorRetry(error!, () => setState(() => error = null))
            : !loaded
                ? const Loading()
                : shown.isEmpty
                    ? Empty(tr('مفيش طلبات هنا.', 'No orders here.'), icon: Icons.inventory_2_outlined)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final o = shown[i];
                          final who = people[o['assigned_to']];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.of(context).push(fadeRoute(OrderManageScreen(orderId: o['id']))),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: o['status'] == 'new' ? C.warn : C.line, width: o['status'] == 'new' ? 1.5 : 1)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text('#${o['order_no']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(o['customer_name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  StatusChip(statusLabel(o['status']), statusColor(o['status'])),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Text(money(toD(o['total'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const Spacer(),
                                  Icon(Icons.person_pin_outlined, size: 15, color: who == null ? C.warn : C.mute),
                                  const SizedBox(width: 4),
                                  Text(who == null ? tr('بدون مسؤول', 'Unassigned') : '${who['full_name']}', style: TextStyle(fontSize: 12, color: who == null ? C.warn : C.mute)),
                                ]),
                                const SizedBox(height: 4),
                                Text(fmtAgo(o['created_at']), style: const TextStyle(fontSize: 10.5, color: C.mute)),
                              ]),
                            ),
                          );
                        },
                      ),
      ),
    ]);
  }
}

String waNumber(String phone) {
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.startsWith('0') && d.length == 11) d = '20${d.substring(1)}';
  return d;
}

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class OrderManageScreen extends StatefulWidget {
  final String orderId;
  const OrderManageScreen({required this.orderId});
  @override
  State<OrderManageScreen> createState() => _OrderManageScreenState();
}

class _OrderManageScreenState extends State<OrderManageScreen> {
  Json? o;
  List<Json> history = [];
  Map<String, Json> people = {};
  Object? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = Json.from(await App.i.db.from('orders').select('*, order_items(*)').eq('id', widget.orderId).single());
      final h = await Api.orderHistory(widget.orderId);
      final ids = <String>{if (r['assigned_to'] != null) r['assigned_to'] as String, ...h.map((e) => e['changed_by']).whereType<String>()};
      final p = await Api.profilesByIds(ids);
      if (mounted) setState(() {
            o = r;
            history = h;
            people = p;
          });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  List<String> get nextStatuses {
    final s = o!['status'] as String;
    final m = {
      'new': ['confirmed', 'cancelled'],
      'confirmed': ['packed', 'cancelled'],
      'packed': ['shipped', 'cancelled'],
      'shipped': ['delivered', 'cancelled'],
    };
    final l = m[s] ?? <String>[];
    if (App.i.role == 'support') return l.where((e) => e == 'confirmed' || e == 'cancelled').toList();
    return l;
  }

  Future<void> _set(String status) async {
    String? note;
    if (status == 'cancelled') {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: C.bg,
          title: Text(tr('إلغاء الطلب؟', 'Cancel order?')),
          content: TextField(controller: c, decoration: InputDecoration(labelText: tr('السبب (بيوصل للعميل)', 'Reason (sent to customer)'))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('رجوع', 'Back'), style: const TextStyle(color: C.mute))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('إلغاء الطلب', 'Cancel order'), style: const TextStyle(color: C.danger, fontWeight: FontWeight.w800))),
          ],
        ),
      );
      if (ok != true) return;
      note = c.text.trim();
    }
    setState(() => busy = true);
    try {
      await Api.setOrderStatus(widget.orderId, status, note: note);
      await _load();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = o;
    return Scaffold(
      appBar: AppBar(title: Text(d == null ? '' : '#${d['order_no']}')),
      body: error != null
          ? ErrorRetry(error!, () {
              setState(() => error = null);
              _load();
            })
          : d == null
              ? const Loading()
              : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
                  Row(children: [StatusChip(statusLabel(d['status']), statusColor(d['status'])), const Spacer(), Text(fmtDate(d['created_at']), style: const TextStyle(color: C.mute, fontSize: 11))]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['customer_name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('${d['city']} - ${d['address']}', style: const TextStyle(height: 1.4)),
                      if ((d['notes'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('📝 ${d['notes']}', style: const TextStyle(color: C.mute))),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: NeonButton(tr('اتصال', 'Call'), icon: Icons.call_outlined, outline: true, onPressed: () => openUrl('tel:${d['phone']}'))),
                        const SizedBox(width: 10),
                        Expanded(child: NeonButton('WhatsApp', icon: Icons.chat_outlined, outline: true, onPressed: () => openUrl('https://wa.me/${waNumber(d['phone'])}'))),
                      ]),
                      const SizedBox(height: 6),
                      Text('${d['phone']}', textDirection: TextDirection.ltr, style: const TextStyle(color: C.mute, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  for (final it in (d['order_items'] as List).map((e) => Json.from(e)))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Container(width: 46, height: 52, decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)), child: Center(child: GarmentView(garment: it['garment'] ?? 'tee', color: hexColor(it['color_hex']), width: 34, shadow: false))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(it['name_ar'], it['name_en']), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${tr(it['color_name_ar'], it['color_name_en'])} · ${it['size']} · x${it['qty']}', style: const TextStyle(color: C.mute, fontSize: 12)),
                        ])),
                        Text(money(toD(it['unit_price']) * toI(it['qty'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  const Divider(height: 26),
                  Row(children: [Text(tr('الإجمالي', 'Total'), style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text(money(toD(d['total'])), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))]),
                  const SizedBox(height: 4),
                  Text(tr('المسؤول: ${people[d['assigned_to']]?['full_name'] ?? 'لسه محدش'}', 'Owner: ${people[d['assigned_to']]?['full_name'] ?? 'nobody yet'}'), style: const TextStyle(color: C.mute, fontSize: 12)),
                  const SizedBox(height: 18),
                  if (nextStatuses.isNotEmpty)
                    for (final s in nextStatuses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: NeonButton(s == 'cancelled' ? tr('إلغاء الطلب', 'Cancel order') : '${tr('تحويل إلى', 'Mark as')} ${statusLabel(s)}', outline: s == 'cancelled', loading: busy && s != 'cancelled', onPressed: busy ? null : () => _set(s)),
                      ),
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(tr('سجل الطلب', 'HISTORY'), style: const TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4)),
                    const SizedBox(height: 6),
                    for (final h in history.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(margin: const EdgeInsets.only(top: 5), width: 8, height: 8, decoration: BoxDecoration(color: statusColor(h['status']), shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${statusLabel(h['status'])}${people[h['changed_by']] != null ? '  ·  ${people[h['changed_by']]!['full_name']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            if ((h['note'] ?? '').toString().isNotEmpty && h['note'] != 'customer') Text('${h['note']}', style: const TextStyle(color: C.mute, fontSize: 12)),
                          ])),
                          Text(fmtDate(h['created_at']), style: const TextStyle(color: C.mute, fontSize: 10.5)),
                        ]),
                      ),
                  ],
                ]),
    );
  }
}

// ===================================================== INBOX =====================================================
class InboxTab extends StatefulWidget {
  const InboxTab();
  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  List<Json> rows = [];
  Map<String, Json> people = {};
  String filter = 'mine';
  StreamSubscription? sub;
  Object? error;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    sub = App.i.db.from('support_conversations').stream(primaryKey: ['id']).order('last_message_at', ascending: false).limit(200).listen((r) async {
      final list = r.map((e) => Json.from(e)).toList();
      final ids = list.map((e) => e['customer_id']).whereType<String>().toSet().difference(people.keys.toSet());
      if (ids.isNotEmpty) {
        try {
          people = {...people, ...await Api.profilesByIds(ids)};
        } catch (_) {}
      }
      if (mounted) setState(() {
            rows = list;
            loaded = true;
          });
    }, onError: (e) {
      if (mounted) setState(() => error = e);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  List<Json> get shown {
    final me = App.i.user?.id;
    return rows.where((c) {
      final open = c['status'] == 'open';
      switch (filter) {
        case 'mine':
          return open && c['assigned_to'] == me;
        case 'unassigned':
          return open && c['assigned_to'] == null;
        case 'open':
          return open;
        default:
          return !open;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      ['mine', tr('محادثاتي', 'Mine')],
      ['unassigned', tr('بدون مسؤول', 'Unassigned')],
      ['open', tr('كل المفتوحة', 'All open')],
      ['closed', tr('المقفولة', 'Closed')],
    ];
    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Center(
                child: ChoiceChip(
                  label: Text(f[1], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: filter == f[0] ? C.ink : C.mute)),
                  selected: filter == f[0],
                  selectedColor: C.neon,
                  backgroundColor: C.card,
                  showCheckmark: false,
                  side: BorderSide(color: filter == f[0] ? C.ink : C.line),
                  onSelected: (_) => setState(() => filter = f[0]),
                ),
              ),
            ),
        ]),
      ),
      Expanded(
        child: error != null
            ? ErrorRetry(error!, () => setState(() => error = null))
            : !loaded
                ? const Loading()
                : shown.isEmpty
                    ? Empty(tr('مفيش محادثات هنا.', 'No conversations here.'), icon: Icons.forum_outlined)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = shown[i];
                          final cust = people[c['customer_id']];
                          final unread = toI(c['staff_unread']);
                          final name = (cust?['full_name'] ?? tr('عميل', 'Customer')).toString();
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            leading: Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: unread > 0 ? C.neon : C.card, shape: BoxShape.circle, border: Border.all(color: unread > 0 ? C.ink : C.line)), child: Text(name.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900))),
                            title: Text(name, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w700)),
                            subtitle: Text('${(c['subject'] ?? '').toString().isEmpty ? tr('استفسار', 'Inquiry') : c['subject']}  ·  ${c['agent_name'] ?? tr('بدون مسؤول', 'unassigned')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.mute)),
                            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(fmtAgo(c['last_message_at']), style: const TextStyle(fontSize: 10.5, color: C.mute)),
                              if (unread > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Badge2(0, Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(10)), child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))))
                            ]),
                            onTap: () => Navigator.of(context).push(fadeRoute(ChatScreen(convId: c['id'], staff: true, title: name))),
                          );
                        },
                      ),
      ),
    ]);
  }
}
