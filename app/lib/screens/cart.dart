import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import '../widgets/navbar.dart';
import 'location_picker.dart';
import 'orders.dart';
import 'package:latlong2/latlong.dart';

class CartScreen extends StatelessWidget {
  const CartScreen();
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.i,
      builder: (context, _) {
        final a = App.i;
        return Scaffold(
          appBar: AppBar(title: Text(tr('الشنطة', 'BAG'))),
          bottomNavigationBar: const NavBar(current: 2),
          body: a.cart.isEmpty
              ? Empty(tr('الشنطة فاضية. اختار قطعة من الشماعة.', 'Your bag is empty. Pick a piece from the rack.'), icon: Icons.shopping_bag_outlined)
              : Column(children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      itemCount: a.cart.length,
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemBuilder: (_, i) {
                        final l = a.cart[i];
                        return Row(children: [
                          Container(
                            width: 72,
                            height: 82,
                            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                            child: Center(child: GarmentView(garment: l.garment, color: hexColor(l.hex), accent: l.accent == null ? null : hexColor(l.accent!), imageUrl: l.image, width: 52, shadow: false)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: 0.8)),
                              const SizedBox(height: 3),
                              Text('${l.color} · ${l.size}', style: TextStyle(color: C.mute, fontSize: 12)),
                              const SizedBox(height: 6),
                              Text(money(l.price * l.qty), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          Column(children: [
                            _q(Icons.add, () => a.setQty(l, l.qty + 1)),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w800))),
                            _q(l.qty == 1 ? Icons.delete_outline : Icons.remove, () => a.setQty(l, l.qty - 1)),
                          ]),
                        ]);
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: C.line))),
                    child: SafeArea(
                      top: false,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _row(tr('المجموع', 'Subtotal'), money(a.cartSubtotal)),
                        _row(tr('الشحن', 'Shipping'), a.cartShipping == 0 ? tr('مجاني', 'Free') : money(a.cartShipping)),
                        if (a.cartShipping > 0) Padding(padding: const EdgeInsets.only(bottom: 4), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(tr('الشحن مجاني فوق ${money(a.freeOver)}', 'Free shipping over ${money(a.freeOver)}'), style: TextStyle(fontSize: 11, color: C.mute)))),
                        const Divider(height: 18),
                        _row(tr('الإجمالي', 'Total'), money(a.cartSubtotal + a.cartShipping), bold: true),
                        const SizedBox(height: 12),
                        NeonButton(tr('إتمام الطلب', 'Checkout'), onPressed: () => Navigator.of(context).push(fadeRoute(const CheckoutScreen()))),
                      ]),
                    ),
                  ),
                ]),
        );
      },
    );
  }

  Widget _q(IconData i, VoidCallback f) => InkWell(
        onTap: f,
        customBorder: const CircleBorder(),
        child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.ink, width: 1)), child: Icon(i, size: 15)),
      );

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(a, style: TextStyle(color: bold ? C.ink : C.mute, fontWeight: bold ? FontWeight.w900 : FontWeight.w500)),
          const Spacer(),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 16 : 14)),
        ]),
      );
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen();
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final key = GlobalKey<FormState>();
  late final name = TextEditingController(text: App.i.name);
  late final phone = TextEditingController(text: (App.i.profile?['phone'] as String?) ?? '');
  final city = TextEditingController(), address = TextEditingController(), notes = TextEditingController();
  final coupon = TextEditingController();
  bool busy = false, checking = false;
  double discount = 0;
  String? appliedCode;
  LatLng? pin;
  String payment = 'cod';

  double get shipNow {
    final a = App.i;
    if (a.cart.isEmpty) return 0;
    final sub = a.cartSubtotal - discount;
    return (a.freeOver > 0 && sub >= a.freeOver) ? 0 : a.shippingFee;
  }

  double get totalNow => App.i.cartSubtotal - discount + shipNow;

  Future<void> _applyCoupon() async {
    final code = coupon.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => checking = true);
    try {
      final d = await Api.validateCoupon(code, App.i.cartSubtotal);
      setState(() {
        discount = d.toDouble();
        appliedCode = code;
      });
      toast(tr('اتطبّق الكوبون ✓', 'Coupon applied ✓'));
    } catch (e) {
      setState(() {
        discount = 0;
        appliedCode = null;
      });
      toastError(e);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _pickLocation() async {
    final r = await Navigator.of(context).push<LatLng>(MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: pin)));
    if (r != null && mounted) setState(() => pin = r);
  }

  @override
  void dispose() {
    coupon.dispose();
    for (final c in [name, phone, city, address, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _place() async {
    if (!key.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final id = await Api.placeOrder(name: name.text, phone: phone.text, address: address.text, city: city.text, notes: notes.text, coupon: appliedCode, lat: pin?.latitude, lng: pin?.longitude, payment: payment);
      final row = await App.i.db.from('orders').select('order_no, total').eq('id', id).single();
      App.i.clearCart();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(OrderPlacedScreen(orderId: id, orderNo: '${row['order_no']}', total: toD(row['total']), wallet: payment == 'wallet')), (r) => r.isFirst);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _payOption(String v, IconData icon, String title, String sub) {
    final on = payment == v;
    return InkWell(
      onTap: () => setState(() => payment = v),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: on ? C.tint.withValues(alpha: 0.6) : Colors.transparent, border: Border.all(color: on ? C.ink : C.line, width: on ? 1.5 : 1), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: on ? C.neon : C.mute),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: C.mute, fontSize: 12, height: 1.3)),
          ])),
          Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? C.neon : C.line),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = App.i;
    return Scaffold(
      appBar: AppBar(title: Text(tr('بيانات التوصيل', 'DELIVERY'))),
      body: SafeArea(
        child: Form(
          key: key,
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
            TextFormField(controller: name, decoration: InputDecoration(labelText: tr('الاسم', 'Full name')), validator: (v) => (v ?? '').trim().length < 2 ? tr('اكتب الاسم', 'Required') : null),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: tr('رقم الموبايل', 'Phone')),
              validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? tr('رقم غير صحيح', 'Invalid phone') : null,
            ),
            TextFormField(controller: city, decoration: InputDecoration(labelText: tr('المدينة', 'City')), validator: (v) => (v ?? '').trim().isEmpty ? tr('اكتب المدينة', 'Required') : null),
            TextFormField(controller: address, maxLines: 2, decoration: InputDecoration(labelText: tr('العنوان بالتفصيل', 'Address')), validator: (v) => (v ?? '').trim().length < 5 ? tr('اكتب العنوان', 'Required') : null),
            TextFormField(controller: notes, decoration: InputDecoration(labelText: tr('ملاحظات (اختياري)', 'Notes (optional)'))),
            const SizedBox(height: 18),
            InkWell(
              onTap: _pickLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: pin == null ? Colors.transparent : C.tint.withValues(alpha: 0.6), border: Border.all(color: pin == null ? C.line : C.ink), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(pin == null ? Icons.add_location_alt_outlined : Icons.location_on, color: pin == null ? C.ink : C.neon),
                  const SizedBox(width: 10),
                  Expanded(child: Text(pin == null ? tr('حدّد موقع التوصيل على الخريطة (اختياري، بيسهّل على المندوب)', 'Pin the delivery spot on the map (optional, helps the courier)') : tr('تم تحديد الموقع ✓ — دوس للتعديل', 'Location pinned ✓ — tap to change'), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35))),
                  Icon(Icons.chevron_right_rounded, color: C.mute),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextField(controller: coupon, textCapitalization: TextCapitalization.characters, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('كوبون خصم (اختياري)', 'Coupon (optional)'), suffixIcon: appliedCode == null ? null : const Icon(Icons.check_circle, color: C.ok)))),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: checking ? null : _applyCoupon, child: checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr('تطبيق', 'Apply'))),
            ]),
            if (discount > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('الخصم: -${money(discount)}', 'Discount: -${money(discount)}'), style: const TextStyle(color: C.ok, fontWeight: FontWeight.w800))),
            const SizedBox(height: 22),
            Text(tr('طريقة الدفع', 'PAYMENT'), style: TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _payOption('cod', Icons.payments_outlined, tr('الدفع عند الاستلام', 'Cash on delivery'), tr('تدفع للمندوب لما الطلب يوصلك', 'Pay the courier when it arrives')),
            const SizedBox(height: 10),
            _payOption('wallet', Icons.account_balance_wallet_outlined, tr('محفظة إلكترونية', 'E-wallet'), tr('حوّل المبلغ على رقم المحفظة وفريقنا يأكد الدفع', 'Transfer to our wallet number; the team confirms it')),
            if (payment == 'wallet')
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.tint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('بعد تأكيد الطلب حوّل ${money(totalNow)} على الرقم:', 'After placing the order, transfer ${money(totalNow)} to:'), style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text(a.walletNumber, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
                    IconButton(onPressed: () {
                      Clipboard.setData(ClipboardData(text: a.walletNumber));
                      toast(tr('اتنسخ الرقم', 'Number copied'));
                    }, icon: const Icon(Icons.copy_rounded, size: 20)),
                  ]),
                  Text(tr('فريقنا هيوصله إشعار بطلبك فورًا.', 'Our team is notified of your order right away.'), style: TextStyle(color: C.mute, fontSize: 12)),
                ]),
              ),
            const SizedBox(height: 14),
            Row(children: [
              Text(tr('الإجمالي', 'Total'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(money(totalNow), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
            const SizedBox(height: 22),
            NeonButton(tr('تأكيد الطلب', 'Place order'), onPressed: _place, loading: busy),
          ]),
        ),
      ),
    );
  }
}

class OrderPlacedScreen extends StatefulWidget {
  final String orderId, orderNo;
  final double total;
  final bool wallet;
  const OrderPlacedScreen({required this.orderId, required this.orderNo, required this.total, this.wallet = false});
  @override
  State<OrderPlacedScreen> createState() => _OrderPlacedScreenState();
}

class _OrderPlacedScreenState extends State<OrderPlacedScreen> {
  String get orderId => widget.orderId;
  String get orderNo => widget.orderNo;
  double get total => widget.total;
  bool sent = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 84, height: 84, decoration: BoxDecoration(color: C.neon, shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 48, color: C.onNeon)),
              const SizedBox(height: 22),
              Text(tr('تم استلام طلبك', 'ORDER RECEIVED'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
              const SizedBox(height: 8),
              Text('#$orderNo', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(money(total), style: TextStyle(color: C.mute)),
              const SizedBox(height: 14),
              Text(tr('فريقنا هيراجع الطلب ويأكده معاك. هتوصلك إشعارات بكل تحديث.', 'Our team will review and confirm it. You will get a notification on every update.'), textAlign: TextAlign.center, style: TextStyle(color: C.mute, height: 1.5)),
              if (widget.wallet) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.tint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                  child: Column(children: [
                    Text(tr('حوّل ${money(total)} على المحفظة:', 'Transfer ${money(total)} to the wallet:'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(App.i.walletNumber, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      IconButton(onPressed: () {
                        Clipboard.setData(ClipboardData(text: App.i.walletNumber));
                        toast(tr('اتنسخ الرقم', 'Number copied'));
                      }, icon: const Icon(Icons.copy_rounded, size: 20)),
                    ]),
                    const SizedBox(height: 6),
                    NeonButton(sent ? tr('اتبلّغ الفريق ✓', 'Team notified ✓') : tr('حوّلت المبلغ', 'I have transferred'), onPressed: sent ? null : () async {
                      final ref = await askTransferRef(context);
                      if (ref == null) return;
                      try {
                        await Api.walletMarkSent(orderId, ref: ref);
                        if (mounted) setState(() => sent = true);
                      } catch (e) {
                        toastError(e);
                      }
                    }),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              NeonButton(tr('تابع طلباتي', 'Track my orders'), onPressed: () => Navigator.of(context).pushReplacement(fadeRoute(const OrdersScreen()))),
              const SizedBox(height: 10),
              NeonButton(tr('كمّل تسوق', 'Keep shopping'), outline: true, onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Asks the customer for the sender number / reference (optional). Returns null if cancelled.
Future<String?> askTransferRef(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.bg,
      title: Text(tr('تأكيد التحويل', 'Confirm transfer')),
      content: TextField(controller: c, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('رقم المحفظة اللي حوّلت منها (اختياري)', 'Wallet number you sent from (optional)'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('رجوع', 'Back'), style: TextStyle(color: C.mute))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('أيوه حوّلت', 'Yes, sent'), style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    ),
  );
  final r = c.text.trim();
  c.dispose();
  return ok == true ? r : null;
}
