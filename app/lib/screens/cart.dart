import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import '../widgets/navbar.dart';
import 'orders.dart';

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
                              Text('${l.color} · ${l.size}', style: const TextStyle(color: C.mute, fontSize: 12)),
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
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
                    child: SafeArea(
                      top: false,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _row(tr('المجموع', 'Subtotal'), money(a.cartSubtotal)),
                        _row(tr('الشحن', 'Shipping'), a.cartShipping == 0 ? tr('مجاني', 'Free') : money(a.cartShipping)),
                        if (a.cartShipping > 0) Padding(padding: const EdgeInsets.only(bottom: 4), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(tr('الشحن مجاني فوق ${money(a.freeOver)}', 'Free shipping over ${money(a.freeOver)}'), style: const TextStyle(fontSize: 11, color: C.mute)))),
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
  bool busy = false;

  @override
  void dispose() {
    for (final c in [name, phone, city, address, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _place() async {
    if (!key.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final id = await Api.placeOrder(name: name.text, phone: phone.text, address: address.text, city: city.text, notes: notes.text);
      final row = await App.i.db.from('orders').select('order_no, total').eq('id', id).single();
      App.i.clearCart();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(OrderPlacedScreen(orderId: id, orderNo: '${row['order_no']}', total: toD(row['total']))), (r) => r.isFirst);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: C.ink), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.payments_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text(tr('الدفع عند الاستلام', 'Cash on delivery'), style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(money(a.cartSubtotal + a.cartShipping), style: const TextStyle(fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 22),
            NeonButton(tr('تأكيد الطلب', 'Place order'), onPressed: _place, loading: busy),
          ]),
        ),
      ),
    );
  }
}

class OrderPlacedScreen extends StatelessWidget {
  final String orderId, orderNo;
  final double total;
  const OrderPlacedScreen({required this.orderId, required this.orderNo, required this.total});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 84, height: 84, decoration: const BoxDecoration(color: C.neon, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 48, color: C.onNeon)),
              const SizedBox(height: 22),
              Text(tr('تم استلام طلبك', 'ORDER RECEIVED'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
              const SizedBox(height: 8),
              Text('#$orderNo', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(money(total), style: const TextStyle(color: C.mute)),
              const SizedBox(height: 14),
              Text(tr('فريقنا هيراجع الطلب ويأكده معاك. هتوصلك إشعارات بكل تحديث.', 'Our team will review and confirm it. You will get a notification on every update.'), textAlign: TextAlign.center, style: const TextStyle(color: C.mute, height: 1.5)),
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
