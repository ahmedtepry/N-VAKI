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
  String cur = 'overview'; // section id, or 'panel' for the control panel
  Timer? presence;
  static const maxPinned = 4;

  /// Every section this person may open, in the order they arranged them.
  List<(String, String, IconData, Widget)> get sections {
    final a = App.i;
    final all = <(String, String, IconData, Widget)>[
      ('overview', tr('نظرة عامة', 'Overview'), Icons.insights_rounded, const OverviewTab()),
    ];
    if (a.can('orders_view')) all.add(('orders', tr('الطلبات', 'Orders'), Icons.inventory_2_outlined, const OrdersTab()));
    if (a.can('driver')) all.add(('deliveries', tr('توصيلاتي', 'Deliveries'), Icons.two_wheeler_outlined, const DeliveriesTab()));
    if (a.can('chat')) all.add(('inbox', tr('المحادثات', 'Inbox'), Icons.forum_outlined, const InboxTab()));
    if (a.can('catalog_edit') || a.can('prices_edit') || a.can('stock_edit')) all.add(('catalog', tr('الكتالوج', 'Catalog'), Icons.checkroom_outlined, const CatalogTab()));
    if (a.can('customers_view')) all.add(('customers', tr('العملاء', 'Customers'), Icons.people_outline_rounded, const CustomersTab()));
    if (a.can('coupons_edit')) all.add(('coupons', tr('كوبونات', 'Coupons'), Icons.confirmation_number_outlined, const CouponsTab()));
    if (a.can('settings_edit') || a.can('categories_edit') || a.can('sizes_edit')) all.add(('settings', tr('الإعدادات', 'Settings'), Icons.tune_rounded, const SettingsTab()));
    if (a.role == 'owner') all.add(('team', tr('الفريق', 'Team'), Icons.groups_outlined, const TeamTab()));
    final saved = a.prefs.getStringList('dash_order') ?? const <String>[];
    all.sort((x, y) {
      final i = saved.indexOf(x.$1), j = saved.indexOf(y.$1);
      return (i < 0 ? 999 : i).compareTo(j < 0 ? 999 : j);
    });
    return all;
  }

  /// Sections pinned to the bottom bar (at most [maxPinned]); the rest live in the control panel.
  List<String> pinnedIds(List<(String, String, IconData, Widget)> secs) {
    final ids = secs.map((e) => e.$1).toSet();
    final saved = App.i.prefs.getStringList('dash_pinned');
    final p = (saved ?? const ['overview', 'orders', 'deliveries', 'inbox']).where(ids.contains).toList();
    final out = p.take(maxPinned).toList();
    if (out.isEmpty) out.addAll(secs.take(3).map((e) => e.$1));
    return out;
  }

  void _savePinned(List<String> ids) {
    App.i.prefs.setStringList('dash_pinned', ids);
    setState(() {});
  }

  void _saveOrder(List<String> ids) {
    App.i.prefs.setStringList('dash_order', ids);
    setState(() {});
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
    final secs = sections;
    final pinned = pinnedIds(secs);
    if (cur != 'panel' && !secs.any((e) => e.$1 == cur)) cur = secs.first.$1;
    final byId = {for (final e in secs) e.$1: e};
    final panelIndex = secs.length;
    final bodyIndex = cur == 'panel' ? panelIndex : secs.indexWhere((e) => e.$1 == cur);
    final navIndex = pinned.contains(cur) ? pinned.indexOf(cur) : pinned.length;
    return Scaffold(
      appBar: AppBar(
        title: Text((cur == 'panel' ? tr('لوحة التحكم', 'Control panel') : byId[cur]!.$2).toUpperCase()),
        actions: [
          Padding(padding: const EdgeInsetsDirectional.only(end: 14), child: Center(child: StatusChip(roleLabel(App.i.role), C.ink))),
        ],
      ),
      body: IndexedStack(index: bodyIndex, children: [
        for (final e in secs) e.$4,
        _ControlPanel(
          sections: secs,
          pinned: pinned,
          max: maxPinned,
          onOpen: (id) => setState(() => cur = id),
          onPinned: _savePinned,
          onOrder: _saveOrder,
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (v) => setState(() => cur = v < pinned.length ? pinned[v] : 'panel'),
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final id in pinned) NavigationDestination(icon: Icon(byId[id]!.$3), label: byId[id]!.$2),
          NavigationDestination(icon: const Icon(Icons.dashboard_customize_outlined), selectedIcon: const Icon(Icons.dashboard_customize_rounded), label: tr('لوحة التحكم', 'Panel')),
        ],
        indicatorColor: C.tint,
      ),
    );
  }
}

/// All sections listed one under another: open one, drag to reorder, and pin up to four to the bottom bar.
class _ControlPanel extends StatelessWidget {
  final List<(String, String, IconData, Widget)> sections;
  final List<String> pinned;
  final int max;
  final ValueChanged<String> onOpen;
  final ValueChanged<List<String>> onPinned, onOrder;
  const _ControlPanel({required this.sections, required this.pinned, required this.max, required this.onOpen, required this.onPinned, required this.onOrder});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Text(tr('اسحب أي قسم عشان ترتّبه، وادوس على الدبوس عشان يظهر في الشريط اللي تحت (لحد $max). الباقي بتلاقيه هنا.', 'Drag to reorder. Tap the pin to show a section in the bottom bar (up to $max). Everything else stays here.'), style: TextStyle(color: C.mute, fontSize: 12.5, height: 1.45)),
      ),
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: sections.length,
          onReorder: (from, to) {
            final ids = sections.map((e) => e.$1).toList();
            if (to > from) to -= 1;
            ids.insert(to, ids.removeAt(from));
            onOrder(ids);
          },
          itemBuilder: (_, i) {
            final e = sections[i];
            final on = pinned.contains(e.$1);
            return Container(
              key: ValueKey(e.$1),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? C.ink : C.line)),
              child: ListTile(
                onTap: () => onOpen(e.$1),
                leading: ReorderableDragStartListener(index: i, child: Icon(Icons.drag_indicator_rounded, color: C.mute)),
                title: Row(children: [Icon(e.$3, size: 20), const SizedBox(width: 10), Expanded(child: Text(e.$2, style: const TextStyle(fontWeight: FontWeight.w800)))]),
                trailing: IconButton(
                  tooltip: tr('تثبيت في الشريط', 'Pin to bar'),
                  icon: Icon(on ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: on ? C.neon : C.mute),
                  onPressed: () {
                    final next = [...pinned];
                    if (on) {
                      if (next.length > 1) next.remove(e.$1);
                    } else {
                      if (next.length >= max) {
                        toast(tr('الشريط بياخد $max بس. شيل واحد الأول.', 'The bar holds $max. Unpin one first.'));
                        return;
                      }
                      next.add(e.$1);
                    }
                    // keep the bar in the same order as the list
                    final order = sections.map((x) => x.$1).toList();
                    next.sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
                    onPinned(next);
                  },
                ),
              ),
            );
          },
        ),
      ),
    ]);
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
