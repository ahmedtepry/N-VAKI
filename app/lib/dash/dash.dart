import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'dash_admin.dart';
import 'dash_manage.dart';
import 'dash_work.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen();
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int tab = 0;
  Timer? presence;

  List<(String, IconData, Widget)> get tabs {
    final a = App.i;
    final all = <(String, IconData, Widget)>[
      (tr('نظرة عامة', 'Overview'), Icons.insights_rounded, const OverviewTab()),
    ];
    if (a.can('orders_view')) all.add((tr('الطلبات', 'Orders'), Icons.inventory_2_outlined, const OrdersTab()));
    if (a.can('driver')) all.add((tr('توصيلاتي', 'Deliveries'), Icons.two_wheeler_outlined, const DeliveriesTab()));
    if (a.can('chat')) all.add((tr('المحادثات', 'Inbox'), Icons.forum_outlined, const InboxTab()));
    if (a.can('catalog_edit') || a.can('prices_edit') || a.can('stock_edit')) all.add((tr('الكتالوج', 'Catalog'), Icons.checkroom_outlined, const CatalogTab()));
    if (a.can('customers_view')) all.add((tr('العملاء', 'Customers'), Icons.people_outline_rounded, const CustomersTab()));
    if (a.can('coupons_edit')) all.add((tr('كوبونات', 'Coupons'), Icons.confirmation_number_outlined, const CouponsTab()));
    if (a.can('settings_edit') || a.can('categories_edit') || a.can('sizes_edit')) all.add((tr('الإعدادات', 'Settings'), Icons.tune_rounded, const SettingsTab()));
    if (a.role == 'owner') all.add((tr('الفريق', 'Team'), Icons.groups_outlined, const TeamTab()));
    return all;
  }

  @override
  void initState() {
    super.initState();
    _ping();
    presence = Timer.periodic(const Duration(seconds: 60), (_) => _ping());
  }

  void _ping() => Api.touchPresence().catchError((_) => '');

  @override
  void dispose() {
    presence?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = tabs;
    final i = tab.clamp(0, t.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(t[i].$1.toUpperCase()),
        actions: [
          Padding(padding: const EdgeInsetsDirectional.only(end: 14), child: Center(child: StatusChip(roleLabel(App.i.role), C.ink))),
        ],
      ),
      body: IndexedStack(index: i, children: [for (final e in t) e.$3]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => tab = v),
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [for (final e in t) NavigationDestination(icon: Icon(e.$2), label: e.$1)],
        indicatorColor: C.tint,
      ),
    );
  }
}

class OverviewTab extends StatefulWidget {
  const OverviewTab();
  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  Json? s;
  Object? error;
  Timer? t;

  @override
  void initState() {
    super.initState();
    _load();
    t = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.dashboard();
      if (mounted) setState(() {
            s = r;
            error = null;
          });
    } catch (e) {
      if (mounted && s == null) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return ErrorRetry(error!, _load);
    final d = s;
    if (d == null) return const Loading();
    final week = (d['week'] as List).map((e) => Json.from(e)).toList();
    final top = (d['top_products'] as List).map((e) => Json.from(e)).toList();
    final team = (d['team'] as List).map((e) => Json.from(e)).toList();
    final role = App.i.role;
    return RefreshIndicator(
      onRefresh: _load,
      color: C.ink,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 24), children: [
        Text(tr('أهلاً ${App.i.name}', 'Hi ${App.i.name}'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(tr('الطلبات والمحادثات بتتوزع تلقائيًا على أقل واحد مشغول في الفريق.', 'Orders and chats are routed automatically to the least-busy teammate.'), style: TextStyle(color: C.mute, fontSize: 12.5, height: 1.4)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            if (role != 'support') _kpi(tr('طلبات النهارده', 'Orders today'), '${d['today_orders']}', Icons.today_outlined),
            if (role == 'owner' || role == 'manager') _kpi(tr('مبيعات النهارده', 'Revenue today'), money(toD(d['today_revenue'])), Icons.payments_outlined, neon: true),
            if (role != 'support') _kpi(tr('طلبات جديدة', 'New orders'), '${d['new_orders']}', Icons.fiber_new_rounded, hot: toI(d['new_orders']) > 0),
            if (role != 'support') _kpi(tr('طلباتي', 'My orders'), '${d['my_orders']}', Icons.person_pin_outlined),
            if (role != 'fulfillment') _kpi(tr('محادثات مفتوحة', 'Open chats'), '${d['open_chats']}', Icons.forum_outlined),
            if (role != 'fulfillment') _kpi(tr('محادثاتي', 'My chats'), '${d['my_chats']}', Icons.person_pin_outlined),
            if (role == 'owner' || role == 'manager') _kpi(tr('مخزون قليل', 'Low stock'), '${d['low_stock']}', Icons.warning_amber_rounded, hot: toI(d['low_stock']) > 0),
            if (role == 'owner' || role == 'manager') _kpi(tr('العملاء', 'Customers'), '${d['customers']}', Icons.people_outline_rounded),
          ],
        ),
        if (role == 'owner' || role == 'manager') ...[
          const SizedBox(height: 20),
          _title(tr('آخر 7 أيام', 'Last 7 days')),
          Container(
            height: 150,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
            child: CustomPaint(painter: _WeekPainter(week), child: const SizedBox.expand()),
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 20),
            _title(tr('الأكثر مبيعًا (30 يوم)', 'Top sellers (30d)')),
            for (final p in top)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(child: Text(tr(p['name_ar'], p['name_en']), style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text('x${p['qty']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                ]),
              ),
          ],
          if (team.isNotEmpty) ...[
            const SizedBox(height: 20),
            _title(tr('الفريق دلوقتي', 'Team right now')),
            for (final m in team)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: m['online'] == true ? C.ok : C.line, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${m['full_name']}  ·  ${roleLabel(m['role'])}', style: TextStyle(fontWeight: FontWeight.w700, color: m['is_active'] == true ? C.ink : C.mute))),
                  Text(tr('طلبات ${m['open_orders']} · محادثات ${m['open_chats']}', 'orders ${m['open_orders']} · chats ${m['open_chats']}'), style: TextStyle(color: C.mute, fontSize: 11.5)),
                ]),
              ),
          ],
        ],
      ]),
    );
  }

  Widget _title(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.5, fontWeight: FontWeight.w800)));

  Widget _kpi(String label, String value, IconData icon, {bool neon = false, bool hot = false}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: neon ? C.tint : C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: hot ? C.warn : (neon ? C.ink : C.line), width: hot ? 1.6 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [Icon(icon, size: 17, color: hot ? C.warn : C.ink), const SizedBox(width: 6), Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: C.mute, fontWeight: FontWeight.w600)))]),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
        ]),
      );
}

class _WeekPainter extends CustomPainter {
  final List<Json> week;
  _WeekPainter(this.week);
  @override
  void paint(Canvas canvas, Size size) {
    if (week.isEmpty) return;
    final vals = week.map((e) => toD(e['revenue'])).toList();
    final mx = vals.fold<double>(1, (a, b) => b > a ? b : a);
    final bw = size.width / week.length;
    final chartH = size.height - 18;
    for (var i = 0; i < week.length; i++) {
      final h = (vals[i] / mx) * (chartH - 4);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(i * bw + bw * 0.2, chartH - h, bw * 0.6, h < 3 ? 3 : h), const Radius.circular(5));
      canvas.drawRRect(r, Paint()..color = vals[i] > 0 ? C.neon : C.line);
      canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = C.ink.withValues(alpha: vals[i] > 0 ? 0.9 : 0.2));
      final d = DateTime.tryParse('${week[i]['d']}');
      final label = d == null ? '' : '${d.day}';
      final tp = TextPainter(text: TextSpan(text: label, style: TextStyle(fontSize: 10, color: C.mute)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(i * bw + (bw - tp.width) / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _WeekPainter o) => true;
}
