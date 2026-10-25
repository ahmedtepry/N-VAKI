import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/perms.dart';
import '../core/theme.dart';

Widget _card({required Widget child, Color? border}) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border ?? C.line)),
      child: child,
    );

Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
    );

Switch _sw(bool v, ValueChanged<bool> f) => Switch(value: v, activeColor: C.onNeon, activeTrackColor: C.neon, onChanged: f);

Future<String?> _ask(BuildContext context, String title, {String hint = '', String initial = '', TextInputType? type}) async {
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: C.bg,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      content: TextField(controller: c, autofocus: true, keyboardType: type, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'), style: TextStyle(color: C.mute))),
        TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: Text(tr('حفظ', 'Save'), style: const TextStyle(fontWeight: FontWeight.w900))),
      ],
    ),
  );
  return r;
}

// ===================================================== TEAM =====================================================
class TeamTab extends StatefulWidget {
  const TeamTab();
  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  List<Json>? team;
  Object? error;
  final email = TextEditingController();
  String role = 'support';
  bool busy = false;
  String? open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.dashboard();
      if (mounted) {
        setState(() {
          team = (d['team'] as List).map((e) => Json.from(e)).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _add() async {
    if (email.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await Api.setUserRole(email.text, role);
      email.clear();
      toast(tr('اتضاف للفريق ✓', 'Added to the team ✓'));
      await _load();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _perm(Json m, String key, bool on) async {
    final cur = ((m['perms'] as List?) ?? const []).map((e) => '$e').toSet();
    on ? cur.add(key) : cur.remove(key);
    setState(() => m['perms'] = cur.toList());
    try {
      await Api.setMemberPerms(m['id'], cur.toList());
    } catch (e) {
      toastError(e);
      _load();
    }
  }

  Future<void> _preset(Json m, String r) async {
    try {
      await Api.setUserRole(m['email'], r);
      await _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _active(Json m, bool v) async {
    try {
      await Api.setMemberActive(m['id'], v);
      await _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _remove(Json m) async {
    if (!await confirmDialog(context, tr('تشيل ${m['full_name']} من الفريق؟', 'Remove ${m['full_name']} from the team?'), body: tr('هيرجع عميل عادي.', 'They become a regular customer.'))) return;
    try {
      await Api.removeMember(m['id']);
      await _load();
    } catch (e) {
      toastError(e);
    }
  }

  Widget _chips(String current, ValueChanged<String> pick, {bool presets = false}) => Wrap(spacing: 8, runSpacing: 6, children: [
        for (final r in const ['manager', 'support', 'fulfillment'])
          ChoiceChip(
            label: Text(roleLabel(r), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: current == r ? C.ink : C.mute)),
            selected: current == r,
            selectedColor: C.tint,
            backgroundColor: C.bg,
            showCheckmark: false,
            side: BorderSide(color: current == r ? C.ink : C.line),
            onSelected: (_) => pick(r),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    if (error != null) return ErrorRetry(error!, _load);
    final t = team;
    if (t == null) return const Loading();
    return RefreshIndicator(
      onRefresh: _load,
      color: C.ink,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 30), children: [
        _card(
          border: C.ink,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('ضيف عضو للفريق', 'ADD A TEAMMATE'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 12)),
            const SizedBox(height: 4),
            Text(tr('لازم يكون عمل حساب في التطبيق الأول، وبعدين اكتب إيميله هنا. بتتحدد له صلاحيات حسب الدور، وبعدها تعدّلها زي ما تحب.', 'They must create an account first, then enter their email. They get the role preset, then you can fine-tune it.'), style: TextStyle(color: C.mute, fontSize: 12, height: 1.4)),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('إيميل العضو', 'Teammate email'))),
            const SizedBox(height: 12),
            _chips(role, (r) => setState(() => role = r)),
            const SizedBox(height: 14),
            NeonButton(tr('إضافة', 'Add'), onPressed: _add, loading: busy),
          ]),
        ),
        _label(tr('الفريق (${t.length})', 'Team (${t.length})')),
        for (final m in t) _member(m),
      ]),
    );
  }

  Widget _member(Json m) {
    final isOwner = m['role'] == 'owner';
    final expanded = open == m['id'];
    final perms = ((m['perms'] as List?) ?? const []).map((e) => '$e').toSet();
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: isOwner ? null : () => setState(() => open = expanded ? null : m['id']),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: m['online'] == true ? C.ok : C.line, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['full_name']}', style: TextStyle(fontWeight: FontWeight.w800, color: m['is_active'] == true ? C.ink : C.mute)),
                Text('${roleLabel(m['role'])}  ·  ${m['email'] ?? ''}', style: TextStyle(fontSize: 11.5, color: C.mute)),
                Text(isOwner ? tr('كل الصلاحيات', 'All permissions') : tr('${perms.length} صلاحية · طلبات ${m['open_orders']} · محادثات ${m['open_chats']}', '${perms.length} permissions · orders ${m['open_orders']} · chats ${m['open_chats']}'), style: TextStyle(fontSize: 11, color: C.mute)),
              ]),
            ),
            if (!isOwner) _sw(m['is_active'] == true, (v) => _active(m, v)),
            if (!isOwner) Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.mute),
          ]),
        ),
        if (expanded) ...[
          const Divider(height: 22),
          Text(tr('الدور الجاهز (بيرجّع الصلاحيات للافتراضي)', 'Role preset (resets permissions to default)'), style: TextStyle(fontSize: 11.5, color: C.mute)),
          const SizedBox(height: 8),
          _chips('${m['role']}', (r) => _preset(m, r)),
          const SizedBox(height: 12),
          for (final p in permCatalog)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: C.onNeon,
              activeTrackColor: C.neon,
              secondary: Icon(p.icon, size: 20, color: C.ink),
              title: Text(tr(p.ar, p.en), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(tr(p.hintAr, p.hintEn), style: TextStyle(fontSize: 11.5, color: C.mute)),
              value: perms.contains(p.key),
              onChanged: (v) => _perm(m, p.key, v),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(onPressed: () => _remove(m), icon: const Icon(Icons.person_remove_outlined, color: C.danger, size: 19), label: Text(tr('شيل من الفريق', 'Remove from team'), style: const TextStyle(color: C.danger, fontWeight: FontWeight.w800))),
          ),
        ],
      ]),
    );
  }
}

// ===================================================== CUSTOMERS =====================================================
class CustomersTab extends StatefulWidget {
  const CustomersTab();
  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  List<Json>? rows;
  Object? error;
  final q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.customers(q.text);
      if (mounted) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _block(Json c, bool blocked) async {
    try {
      await Api.setCustomerBlocked(c['id'], blocked);
      await _load();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: TextField(controller: q, onSubmitted: (_) => _load(), decoration: InputDecoration(hintText: tr('دوّر بالاسم أو الإيميل أو التليفون', 'Search name, email or phone'), prefixIcon: const Icon(Icons.search_rounded), isDense: true)),
      ),
      Expanded(
        child: error != null
            ? ErrorRetry(error!, _load)
            : rows == null
                ? const Loading()
                : rows!.isEmpty
                    ? Empty(tr('مفيش عملاء.', 'No customers.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: C.ink,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: rows!.length,
                          itemBuilder: (_, i) {
                            final c = rows![i];
                            final active = c['is_active'] == true;
                            return _card(
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${c['full_name']}', style: TextStyle(fontWeight: FontWeight.w800, color: active ? C.ink : C.mute)),
                                    Text('${c['email'] ?? ''}${(c['phone'] ?? '').toString().isEmpty ? '' : '  ·  ${c['phone']}'}', style: TextStyle(fontSize: 11.5, color: C.mute)),
                                    const SizedBox(height: 2),
                                    Text(tr('${c['orders']} طلب · ${money(toD(c['spent']))}', '${c['orders']} orders · ${money(toD(c['spent']))}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                                if (!active) StatusChip(tr('محظور', 'Blocked'), C.danger),
                                if (App.i.can('customers_block'))
                                  IconButton(onPressed: () => _block(c, active), tooltip: active ? tr('حظر', 'Block') : tr('إلغاء الحظر', 'Unblock'), icon: Icon(active ? Icons.block_outlined : Icons.lock_open_rounded, color: active ? C.danger : C.ok)),
                              ]),
                            );
                          },
                        ),
                      ),
      ),
    ]);
  }
}

// ===================================================== COUPONS =====================================================
class CouponsTab extends StatefulWidget {
  const CouponsTab();
  @override
  State<CouponsTab> createState() => _CouponsTabState();
}

class _CouponsTabState extends State<CouponsTab> {
  List<Json>? rows;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.coupons();
      if (mounted) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _new() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => const _CouponSheet(),
    );
    if (ok == true) _load();
  }

  Future<void> _toggle(Json c, bool v) async {
    try {
      await App.i.db.from('coupons').update({'active': v}).eq('code', c['code']);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _delete(Json c) async {
    if (!await confirmDialog(context, tr('تحذف الكوبون ${c['code']}؟', 'Delete coupon ${c['code']}?'))) return;
    try {
      await App.i.db.from('coupons').delete().eq('code', c['code']);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.neon,
        foregroundColor: C.onNeon,
        elevation: 0,
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: Text(tr('كوبون جديد', 'NEW COUPON'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
      body: error != null
          ? ErrorRetry(error!, _load)
          : rows == null
              ? const Loading()
              : rows!.isEmpty
                  ? Empty(tr('مفيش كوبونات. اعمل أول كوبون.', 'No coupons yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                      itemCount: rows!.length,
                      itemBuilder: (_, i) {
                        final c = rows![i];
                        final pct = c['kind'] == 'percent';
                        final exp = c['expires_at'] == null ? null : DateTime.tryParse('${c['expires_at']}')?.toLocal();
                        return _card(
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${c['code']}', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.6, fontSize: 15)),
                                Text(pct ? tr('خصم ${toD(c['value']).round()}%', '${toD(c['value']).round()}% off') : tr('خصم ${money(toD(c['value']))}', '${money(toD(c['value']))} off'), style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  [
                                    if (toD(c['min_order']) > 0) tr('حد أدنى ${money(toD(c['min_order']))}', 'min ${money(toD(c['min_order']))}'),
                                    tr('استُخدم ${c['used']}${toI(c['max_uses']) > 0 ? ' / ${c['max_uses']}' : ''}', 'used ${c['used']}${toI(c['max_uses']) > 0 ? ' / ${c['max_uses']}' : ''}'),
                                    if (exp != null) tr('ينتهي ${exp.day}/${exp.month}', 'ends ${exp.day}/${exp.month}'),
                                  ].join(' · '),
                                  style: TextStyle(fontSize: 11.5, color: C.mute),
                                ),
                              ]),
                            ),
                            _sw(c['active'] == true, (v) => _toggle(c, v)),
                            IconButton(onPressed: () => _delete(c), icon: const Icon(Icons.delete_outline, color: C.danger, size: 20)),
                          ]),
                        );
                      },
                    ),
    );
  }
}

class _CouponSheet extends StatefulWidget {
  const _CouponSheet();
  @override
  State<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<_CouponSheet> {
  final code = TextEditingController(), value = TextEditingController(), minOrder = TextEditingController(text: '0'), maxUses = TextEditingController(text: '0'), days = TextEditingController();
  String kind = 'percent';
  bool busy = false;

  @override
  void dispose() {
    for (final c in [code, value, minOrder, maxUses, days]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final v = double.tryParse(value.text.trim());
    final cd = code.text.trim().toUpperCase();
    if (cd.length < 3 || v == null || v <= 0 || (kind == 'percent' && v > 100)) {
      toast(tr('راجع الكود والقيمة', 'Check the code and value'));
      return;
    }
    setState(() => busy = true);
    try {
      final d = int.tryParse(days.text.trim());
      await App.i.db.from('coupons').insert({
        'code': cd,
        'kind': kind,
        'value': v,
        'min_order': double.tryParse(minOrder.text.trim()) ?? 0,
        'max_uses': int.tryParse(maxUses.text.trim()) ?? 0,
        'expires_at': d == null || d <= 0 ? null : DateTime.now().add(Duration(days: d)).toUtc().toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      toastError(e);
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('كوبون جديد', 'NEW COUPON'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          TextField(controller: code, textCapitalization: TextCapitalization.characters, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('الكود (مثلاً WELCOME10)', 'Code (e.g. WELCOME10)'))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final k in const ['percent', 'fixed'])
              ChoiceChip(
                label: Text(k == 'percent' ? tr('نسبة %', 'Percent %') : tr('مبلغ ثابت', 'Fixed amount'), style: const TextStyle(fontWeight: FontWeight.w800)),
                selected: kind == k,
                selectedColor: C.tint,
                backgroundColor: C.card,
                showCheckmark: false,
                onSelected: (_) => setState(() => kind = k),
              ),
          ]),
          TextField(controller: value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: kind == 'percent' ? tr('نسبة الخصم', 'Discount %') : tr('قيمة الخصم', 'Discount amount'))),
          Row(children: [
            Expanded(child: TextField(controller: minOrder, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('حد أدنى للطلب', 'Min order')))),
            const SizedBox(width: 14),
            Expanded(child: TextField(controller: maxUses, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('أقصى استخدام (0 = بلا حد)', 'Max uses (0 = ∞)')))),
          ]),
          TextField(controller: days, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('صالح لكام يوم (فاضي = بلا نهاية)', 'Valid for days (empty = no end)'))),
          const SizedBox(height: 18),
          NeonButton(tr('إنشاء', 'Create'), onPressed: _save, loading: busy),
        ]),
      ),
    );
  }
}

// ===================================================== SETTINGS =====================================================
class SettingsTab extends StatefulWidget {
  const SettingsTab();
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final ship = TextEditingController(text: App.i.settings['shipping_fee'] ?? '60');
  late final free = TextEditingController(text: App.i.settings['free_shipping_over'] ?? '1500');
  late final hoursAr = TextEditingController(text: App.i.settings['support_hours_ar'] ?? '');
  late final hoursEn = TextEditingController(text: App.i.settings['support_hours_en'] ?? '');
  late final tickAr = TextEditingController(text: (App.i.settings['ticker_ar'] ?? '').split('|').join('\n'));
  late final tickEn = TextEditingController(text: (App.i.settings['ticker_en'] ?? '').split('|').join('\n'));
  late bool open = App.i.storeOpen;
  late final brandCtl = TextEditingController(text: App.i.brand);
  bool busy = false;

  Future<void> _renameApp() async {
    final name = brandCtl.text.trim();
    if (name.length < 2 || name.length > 24) {
      toast(tr('الاسم من حرفين لحد 24 حرف', 'The name must be 2 to 24 characters'));
      return;
    }
    if (name == App.i.brand) return;
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(tr('تأكيد بالرمز السري', 'Confirm with secret code')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('هيتغيّر اسم التطبيق لكل الناس فورًا إلى "$name".', 'The app name changes for everyone instantly to "$name".'), style: const TextStyle(height: 1.45)),
          const SizedBox(height: 10),
          TextField(controller: code, obscureText: true, autofocus: true, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('الرمز السري', 'Secret code'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('رجوع', 'Back'), style: TextStyle(color: C.mute))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('غيّر الاسم', 'Rename'), style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
    final secret = code.text;
    code.dispose();
    if (ok != true) return;
    try {
      await Api.setBrandName(name, secret);
      await App.i.loadSettings();
      toast(tr('اتغيّر اسم التطبيق ✓', 'App renamed ✓'));
    } catch (e) {
      toastError(e);
    }
  }

  @override
  void dispose() {
    for (final c in [ship, free, hoursAr, hoursEn, tickAr, tickEn, brandCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  String _lines(TextEditingController c) => c.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).join('|');

  Future<void> _save() async {
    if (double.tryParse(ship.text.trim()) == null || double.tryParse(free.text.trim()) == null) {
      toast(tr('الشحن لازم يكون رقم', 'Shipping values must be numbers'));
      return;
    }
    setState(() => busy = true);
    try {
      await Api.saveSetting('shipping_fee', ship.text.trim());
      await Api.saveSetting('free_shipping_over', free.text.trim());
      await Api.saveSetting('support_hours_ar', hoursAr.text.trim());
      await Api.saveSetting('support_hours_en', hoursEn.text.trim());
      await Api.saveSetting('ticker_ar', _lines(tickAr));
      await Api.saveSetting('ticker_en', _lines(tickEn));
      await Api.saveSetting('store_open', open ? 'true' : 'false');
      await App.i.loadSettings();
      toast(tr('اتحفظ ✓', 'Saved ✓'));
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
      _card(
        border: open ? C.line : C.danger,
        child: Row(children: [
          Icon(open ? Icons.storefront_outlined : Icons.store_mall_directory_outlined, color: open ? C.ok : C.danger),
          const SizedBox(width: 12),
          Expanded(child: Text(open ? tr('المتجر مفتوح', 'Store is open') : tr('المتجر مقفول (محدش يقدر يطلب)', 'Store is closed (no new orders)'), style: const TextStyle(fontWeight: FontWeight.w800))),
          _sw(open, (v) => setState(() => open = v)),
        ]),
      ),
      if (App.i.role == 'owner') ...[
        _label(tr('اسم التطبيق (المالك فقط)', 'App name (owner only)')),
        _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: brandCtl, maxLength: 24, decoration: InputDecoration(labelText: tr('الاسم الجديد', 'New name'))),
            Text(tr('بيتغيّر في الشعار وشاشة البداية والفواتير والتطبيق كله. الاسم تحت أيقونة الموبايل بيتغيّر مع نسخة جديدة من التطبيق بس.', 'Changes the logo, splash, invoices and the whole app. The name under the phone icon only changes with a new app build.'), style: TextStyle(color: C.mute, fontSize: 12, height: 1.4)),
            const SizedBox(height: 10),
            NeonButton(tr('غيّر الاسم', 'Rename app'), icon: Icons.drive_file_rename_outline, onPressed: _renameApp),
          ]),
        ),
      ],
      if (App.i.can('settings_edit')) ...[
        _label(tr('ألوان التطبيق (بتتغير عند كل العملاء)', 'App colours (changes for every customer)')),
        SizedBox(
          height: 108,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final p in kPalettes)
              GestureDetector(
                onTap: () async {
                  try {
                    await Api.saveSetting('theme', p.key);
                    App.i.setPalette(p.key);
                    toast(tr('اتغيّر اللون ✓', 'Colours updated ✓'));
                  } catch (e) {
                    toastError(e);
                  }
                },
                child: Container(
                  width: 96,
                  margin: const EdgeInsetsDirectional.only(end: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.current == p.key ? C.ink : C.line, width: C.current == p.key ? 2.2 : 1)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      for (final c in [p.neon, p.tint, p.card, p.ink]) Container(width: 16, height: 16, margin: const EdgeInsetsDirectional.only(end: 3), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: p.line))),
                    ]),
                    const Spacer(),
                    Text(tr(p.ar, p.en), style: TextStyle(color: p.ink, fontWeight: FontWeight.w800, fontSize: 12)),
                    if (C.current == p.key) Icon(Icons.check_circle, size: 16, color: p.neon),
                  ]),
                ),
              ),
          ]),
        ),
      ],
      if (App.i.can('categories_edit') || App.i.can('sizes_edit')) ...[
        _label(tr('الكتالوج', 'Catalog')),
        if (App.i.can('categories_edit')) _link(Icons.category_outlined, tr('الأقسام', 'Categories'), const CategoriesScreen()),
        if (App.i.can('sizes_edit')) _link(Icons.straighten_outlined, tr('المقاسات', 'Sizes'), const SizesScreen()),
      ],
      _label(tr('الشحن', 'Shipping')),
      Row(children: [
        Expanded(child: TextField(controller: ship, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('سعر الشحن', 'Shipping fee')))),
        const SizedBox(width: 16),
        Expanded(child: TextField(controller: free, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('شحن مجاني فوق', 'Free shipping over')))),
      ]),
      _label(tr('ساعات خدمة العملاء', 'Support hours')),
      TextField(controller: hoursAr, decoration: InputDecoration(labelText: tr('بالعربي', 'Arabic'))),
      TextField(controller: hoursEn, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('بالإنجليزي', 'English'))),
      _label(tr('الشريط المتحرك تحت (سطر لكل رسالة)', 'Scrolling ticker (one line per message)')),
      TextField(controller: tickAr, maxLines: 4, minLines: 2, decoration: InputDecoration(labelText: tr('بالعربي', 'Arabic'))),
      TextField(controller: tickEn, maxLines: 4, minLines: 2, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('بالإنجليزي', 'English'))),
      const SizedBox(height: 22),
      NeonButton(tr('حفظ الإعدادات', 'Save settings'), onPressed: _save, loading: busy),
    ]);
  }

  Widget _link(IconData i, String t, Widget page) => _card(
        child: InkWell(
          onTap: () => Navigator.of(context).push(fadeRoute(page)),
          child: Row(children: [Icon(i, color: C.ink), const SizedBox(width: 12), Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800))), Icon(Icons.chevron_right_rounded, color: C.mute)]),
        ),
      );
}

// ===================================================== CATEGORIES =====================================================
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen();
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Json>? rows;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.categories(all: true);
      if (mounted) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
    App.i.loadSettings();
  }

  Future<void> _add() async {
    final ar = await _ask(context, tr('اسم القسم بالعربي', 'Category name (Arabic)'));
    if (ar == null || ar.isEmpty || !mounted) return;
    final en = await _ask(context, tr('اسم القسم بالإنجليزي', 'Category name (English)'));
    if (en == null || en.isEmpty) return;
    final slug = en.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length < 2) {
      toast(tr('الاسم الإنجليزي لازم حروف أو أرقام', 'The English name needs letters or digits'));
      return;
    }
    try {
      await App.i.db.from('categories').insert({'slug': slug, 'name_ar': ar, 'name_en': en, 'sort': ((rows?.length ?? 0) + 1) * 10});
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _rename(Json c) async {
    final ar = await _ask(context, tr('الاسم بالعربي', 'Arabic name'), initial: '${c['name_ar']}');
    if (ar == null || ar.isEmpty || !mounted) return;
    final en = await _ask(context, tr('الاسم بالإنجليزي', 'English name'), initial: '${c['name_en']}');
    if (en == null || en.isEmpty) return;
    try {
      await App.i.db.from('categories').update({'name_ar': ar, 'name_en': en}).eq('slug', c['slug']);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _move(int i, int d) async {
    final r = rows!;
    final j = i + d;
    if (j < 0 || j >= r.length) return;
    try {
      await App.i.db.from('categories').update({'sort': toI(r[j]['sort'])}).eq('slug', r[i]['slug']);
      await App.i.db.from('categories').update({'sort': toI(r[i]['sort'])}).eq('slug', r[j]['slug']);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _toggle(Json c, bool v) async {
    try {
      await App.i.db.from('categories').update({'active': v}).eq('slug', c['slug']);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _delete(Json c) async {
    if (!await confirmDialog(context, tr('تحذف قسم ${c['name_ar']}؟', 'Delete ${c['name_en']}?'))) return;
    try {
      await App.i.db.from('categories').delete().eq('slug', c['slug']);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('الأقسام', 'CATEGORIES'))),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: C.neon, foregroundColor: C.onNeon, elevation: 0, onPressed: _add, icon: const Icon(Icons.add), label: Text(tr('قسم جديد', 'NEW'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: error != null
          ? ErrorRetry(error!, _load)
          : rows == null
              ? const Loading()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                  itemCount: rows!.length,
                  itemBuilder: (_, i) {
                    final c = rows![i];
                    return _card(
                      child: Row(children: [
                        Column(children: [
                          InkWell(onTap: () => _move(i, -1), child: const Icon(Icons.keyboard_arrow_up_rounded, size: 22)),
                          InkWell(onTap: () => _move(i, 1), child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22)),
                        ]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _rename(c),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(tr('${c['name_ar']}', '${c['name_en']}'), style: TextStyle(fontWeight: FontWeight.w800, color: c['active'] == true ? C.ink : C.mute)),
                              Text('${c['name_ar']} · ${c['name_en']}  (${c['slug']})', style: TextStyle(fontSize: 11, color: C.mute)),
                            ]),
                          ),
                        ),
                        _sw(c['active'] == true, (v) => _toggle(c, v)),
                        IconButton(onPressed: () => _delete(c), icon: const Icon(Icons.delete_outline, color: C.danger, size: 20)),
                      ]),
                    );
                  },
                ),
    );
  }
}

// ===================================================== SIZES =====================================================
class SizesScreen extends StatefulWidget {
  const SizesScreen();
  @override
  State<SizesScreen> createState() => _SizesScreenState();
}

class _SizesScreenState extends State<SizesScreen> {
  List<Json>? rows;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.sizes(all: true);
      if (mounted) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _add() async {
    final code = (await _ask(context, tr('كود المقاس (مثلاً 4XL أو 38)', 'Size code (e.g. 4XL or 38)')))?.toUpperCase();
    if (code == null || code.isEmpty) return;
    try {
      await App.i.db.from('size_options').insert({'code': code, 'sort': ((rows?.length ?? 0) + 1) * 10});
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _toggle(Json s, bool v) async {
    try {
      await App.i.db.from('size_options').update({'active': v}).eq('code', s['code']);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _delete(Json s) async {
    if (!await confirmDialog(context, tr('تحذف المقاس ${s['code']}؟', 'Delete size ${s['code']}?'))) return;
    try {
      await App.i.db.from('size_options').delete().eq('code', s['code']);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('المقاسات', 'SIZES'))),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: C.neon, foregroundColor: C.onNeon, elevation: 0, onPressed: _add, icon: const Icon(Icons.add), label: Text(tr('مقاس جديد', 'NEW'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: error != null
          ? ErrorRetry(error!, _load)
          : rows == null
              ? const Loading()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                  itemCount: rows!.length,
                  itemBuilder: (_, i) {
                    final s = rows![i];
                    return _card(
                      child: Row(children: [
                        Expanded(child: Text('${s['code']}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: s['active'] == true ? C.ink : C.mute))),
                        _sw(s['active'] == true, (v) => _toggle(s, v)),
                        IconButton(onPressed: () => _delete(s), icon: const Icon(Icons.delete_outline, color: C.danger, size: 20)),
                      ]),
                    );
                  },
                ),
    );
  }
}
