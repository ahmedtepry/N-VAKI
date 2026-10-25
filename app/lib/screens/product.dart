import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/specs.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import 'cart.dart';
import 'viewer.dart';

class ProductScreen extends StatefulWidget {
  final List<Product> products;
  final int index;
  const ProductScreen({required this.products, required this.index});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> with SingleTickerProviderStateMixin {
  late int i = widget.index;
  late final PageController pc = PageController(initialPage: widget.index);
  final Map<String, String> hexOf = {}, sizeOf = {};
  final frame = Frame();
  final sw = Swing();
  late final Ticker ticker;
  Duration last = Duration.zero;
  double lastPage = 0, time = 0;

  Product get p => widget.products[i];
  String hexFor(Product x) => hexOf[x.id] ?? x.colors.first.hex;
  String get curHex => hexFor(p);
  String? get curSize => sizeOf[p.id];
  Variant? get curVariant => curSize == null ? null : p.find(curHex, curSize!);

  @override
  void initState() {
    super.initState();
    lastPage = widget.index.toDouble();
    sw.kick(1.5); // the piece swings as it arrives
    ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    ticker.dispose();
    pc.dispose();
    frame.dispose();
    super.dispose();
  }

  void _tick(Duration d) {
    final dt = ((d - last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    last = d;
    time = d.inMicroseconds / 1e6;
    final cur = pc.hasClients && pc.position.haveDimensions ? (pc.page ?? lastPage) : lastPage;
    final delta = cur - lastPage;
    lastPage = cur;
    if (delta != 0) sw.kick(-delta * 14);
    sw.step(dt);
    frame.bump();
  }

  void _go(int d) {
    final n = i + d;
    if (n < 0 || n >= widget.products.length) return;
    pc.animateToPage(n, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  void _pickColor(Variant v) {
    setState(() {
      hexOf[p.id] = v.hex;
      sizeOf.remove(p.id);
    });
    sw.kick(1.1);
  }

  void _add() {
    final v = curVariant;
    if (v == null) {
      toast(tr('اختار المقاس الأول', 'Pick a size first'));
      return;
    }
    if (v.stock <= 0) {
      toast(tr('المقاس ده خلص', 'That size is sold out'));
      return;
    }
    App.i.addToCart(p, v);
    sw.kick(1.0);
    toast(tr('اتضافت للشنطة ✓', 'Added to your bag ✓'));
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;
    final rackH = h * 0.44;
    final gw = math.min(w * 0.78, (rackH - 18) / 1.18);
    return ListenableBuilder(
      listenable: App.i,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text('${i + 1} / ${widget.products.length}', style: TextStyle(fontSize: 12, letterSpacing: 2, color: C.mute)),
          actions: [
            IconButton(
              onPressed: () => App.i.toggleFav(p.id),
              icon: Icon(App.i.isFav(p.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: App.i.isFav(p.id) ? C.danger : C.ink),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).push(fadeRoute(const CartScreen())),
              icon: Badge2(App.i.cartCount, const Icon(Icons.shopping_bag_outlined)),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            SizedBox(
              height: rackH,
              child: Stack(children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 6,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [C.ink.withValues(alpha: 0), C.ink.withValues(alpha: 0.85), C.ink.withValues(alpha: 0.85), C.ink.withValues(alpha: 0)], stops: const [0, 0.08, 0.92, 1])),
                  ),
                ),
                PageView.builder(
                  controller: pc,
                  itemCount: widget.products.length,
                  onPageChanged: (n) => setState(() => i = n),
                  itemBuilder: (_, pi) {
                    final x = widget.products[pi];
                    final hx = hexFor(x);
                    final v = x.colors.firstWhere((e) => e.hex == hx, orElse: () => x.colors.first);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        sw.kick(1.3);
                        Navigator.of(context).push(cinemaRoute(ViewerScreen(product: x, variant: v)));
                      },
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: frame,
                            builder: (_, __) => GarmentView(
                              garment: x.garment,
                              color: hexColor(hx),
                              accent: v.accent == null ? null : hexColor(v.accent!),
                              imageUrl: v.image,
                              width: gw,
                              swing: sw.a + math.sin(time * 0.9) * 0.014,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // hang tags (colours)
                PositionedDirectional(end: 12, top: 0, child: Column(children: [for (final v in p.colors) _tag(v)])),
                Positioned(left: 8, top: 0, bottom: 0, child: Center(child: _arrow(Icons.chevron_left_rounded, -1))),
                Positioned(right: 8, top: 0, bottom: 0, child: Center(child: _arrow(Icons.chevron_right_rounded, 1))),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var k = 0; k < widget.products.length && widget.products.length <= 12; k++)
                      AnimatedContainer(duration: const Duration(milliseconds: 220), width: k == i ? 16 : 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: k == i ? C.ink : C.line, borderRadius: BorderRadius.circular(3))),
                  ]),
                ),
              ]),
            ),
            Expanded(child: SingleChildScrollView(child: _panel())),
            _buyBar(),
          ]),
        ),
      ),
    );
  }

  Widget _arrow(IconData icon, int d) {
    final enabled = (i + d) >= 0 && (i + d) < widget.products.length;
    return Opacity(
      opacity: enabled ? 0.9 : 0.2,
      child: Material(
        color: C.bg.withValues(alpha: 0.7),
        shape: CircleBorder(side: BorderSide(color: C.ink, width: 1)),
        child: InkWell(customBorder: const CircleBorder(), onTap: enabled ? () => _go(d) : null, child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 20))),
      ),
    );
  }

  Widget _tag(Variant v) {
    final sel = v.hex == curHex;
    final c = hexColor(v.hex);
    return GestureDetector(
      onTap: () => _pickColor(v),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(duration: const Duration(milliseconds: 220), width: 1.3, height: sel ? 10 : 18, color: C.ink.withValues(alpha: 0.6)),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: sel ? 24 : 18,
          height: sel ? 42 : 31,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 4.5),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: sel ? C.ink : C.ink.withValues(alpha: 0.25), width: sel ? 1.5 : 0.8),
            boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 7, offset: const Offset(0, 4))] : null,
          ),
          child: Container(width: 4.5, height: 4.5, decoration: BoxDecoration(color: C.bg, shape: BoxShape.circle, border: Border.all(color: C.ink.withValues(alpha: 0.4), width: 0.6))),
        ),
      ]),
    );
  }

  Widget _buyBar() {
    final v = curVariant;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      decoration: BoxDecoration(color: C.bg, border: Border(top: BorderSide(color: C.line))),
      child: NeonButton(
        v == null ? tr('اختار المقاس', 'Pick a size') : tr('أضف للشنطة · ${money(p.price)}', 'Add to bag · ${money(p.price)}'),
        onPressed: _add,
        icon: Icons.add_shopping_cart_rounded,
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(k, style: TextStyle(fontSize: 12.5, color: C.mute))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.35))),
        ]),
      );

  Widget _sizeTable(List<Variant> sizes) {
    final rows = <SizeSpec>[];
    for (final s in sizes) {
      final sp = sizeSpec(p.garment, s.size);
      if (sp != null) rows.add(sp);
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final sel = curSize?.toUpperCase();
    TextStyle hd() => TextStyle(fontSize: 10.5, color: C.mute, fontWeight: FontWeight.w700);
    Widget cell(String t, {bool bold = false, int flex = 1}) => Expanded(flex: flex, child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.w900 : FontWeight.w600)));
    String n(double x) => x == x.roundToDouble() ? x.round().toString() : x.toStringAsFixed(1);
    final detail = rows.firstWhere((r) => r.size == sel, orElse: () => rows.firstWhere((r) => r.size == 'M', orElse: () => rows.first));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(tr('المقاسات بالسنتي', 'Measurements (cm)')),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(tr('المقاس', 'Size'), style: hd())),
            Expanded(flex: 2, child: Text(tr('عرض الصدر', 'Chest'), style: hd())),
            Expanded(flex: 2, child: Text(tr('الطول', 'Length'), style: hd())),
            Expanded(flex: 2, child: Text(tr('الكتف', 'Shoulder'), style: hd())),
            Expanded(flex: 2, child: Text(tr('الكم', 'Sleeve'), style: hd())),
          ]),
          const Divider(height: 14),
          for (final r in rows)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(color: r.size == sel ? C.tint : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                cell(r.size, bold: true),
                cell(n(r.chest), flex: 2),
                cell(n(r.length), flex: 2),
                cell(n(r.shoulder), flex: 2),
                cell(n(r.sleeve), flex: 2),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.tint.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.straighten_rounded, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('مقاس ${detail.size} مناسب لطول ${detail.height} سم ووزن ${detail.weight} كجم تقريباً', 'Size ${detail.size} suits roughly ${detail.height} cm height and ${detail.weight} kg'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.4),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Text(tr('القياسات للقطعة وهي مفرودة، وممكن تختلف 1-2 سم. لو بين مقاسين خد الأكبر لو بتحب الواسع، أو الأصغر لو بتحب الضيق.', 'Measured flat on the garment, ±1-2 cm. Between sizes? Size up for a looser fit, down for a closer one.'), style: TextStyle(fontSize: 11.5, color: C.mute, height: 1.45)),
    ]);
  }

  Widget _panel() {
    final sizes = p.sizesFor(curHex);
    final v = curVariant;
    final colorName = p.colors.firstWhere((e) => e.hex == curHex, orElse: () => p.colors.first).color;
    final off = (p.compareAt != null && p.compareAt! > p.price) ? ((1 - p.price / p.compareAt!) * 100).round() : 0;
    final fab = fabricFor(p.garment);
    final inStock = sizes.where((s) => s.stock > 0).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(p.name.toUpperCase(), key: ValueKey(p.id), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.6)))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(p.price), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            if (off > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(money(p.compareAt!), style: TextStyle(fontSize: 11, color: C.mute, decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: C.neon, borderRadius: BorderRadius.circular(4)), child: Text('-$off%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: C.onNeon))),
              ]),
          ]),
        ]),
        const SizedBox(height: 4),
        Text(colorName, style: TextStyle(fontSize: 12.5, color: C.mute, letterSpacing: 0.8)),
        const SizedBox(height: 18),
        _label(tr('المقاسات المتاحة', 'Available sizes')),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final s in sizes)
            GestureDetector(
              onTap: s.stock <= 0 ? null : () => setState(() => sizeOf[p.id] = s.size),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: curSize == s.size ? C.ink : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: s.stock <= 0 ? C.line : C.ink, width: 1)),
                child: Column(children: [
                  Text(s.size, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: curSize == s.size ? C.bg : (s.stock <= 0 ? C.line : C.ink), decoration: s.stock <= 0 ? TextDecoration.lineThrough : TextDecoration.none)),
                  const SizedBox(height: 2),
                  Text(
                    s.stock <= 0 ? tr('خلص', 'Sold out') : (s.stock <= 3 ? tr('باقي ${s.stock}', '${s.stock} left') : tr('متاح', 'In stock')),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: curSize == s.size ? C.bg.withValues(alpha: 0.8) : (s.stock <= 0 ? C.line : (s.stock <= 3 ? C.warn : C.mute))),
                  ),
                ]),
              ),
            ),
        ]),
        if (inStock == 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('اللون ده خلص كله', 'This colour is sold out'), style: const TextStyle(color: C.danger, fontWeight: FontWeight.w700, fontSize: 12.5))),
        if (v != null && v.stock > 0 && v.stock <= 3) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('باقي ${v.stock} قطع بس من المقاس ده', 'Only ${v.stock} left in this size'), style: const TextStyle(color: C.warn, fontWeight: FontWeight.w700, fontSize: 12.5))),
        const SizedBox(height: 22),
        _sizeTable(sizes),
        const SizedBox(height: 22),
        _label(tr('الخامة والتفاصيل', 'Fabric & details')),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
          child: Column(children: [
            _kv(tr('الخامة', 'Material'), fab.material),
            const Divider(height: 1),
            _kv(tr('الوزن', 'Weight'), fab.weight),
            const Divider(height: 1),
            _kv(tr('القصّة', 'Fit'), fab.fit),
            const Divider(height: 1),
            _kv(tr('العناية', 'Care'), fab.care),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.local_shipping_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('الدفع عند الاستلام · شحن ${money(App.i.shippingFee)}، ومجاني فوق ${money(App.i.freeOver)}', 'Cash on delivery · shipping ${money(App.i.shippingFee)}, free over ${money(App.i.freeOver)}'), style: TextStyle(fontSize: 12.5, color: C.mute, height: 1.4))),
        ]),
        if (p.desc.isNotEmpty) ...[
          const SizedBox(height: 16),
          _label(tr('عن القطعة', 'About')),
          Text(p.desc, style: TextStyle(fontSize: 13, color: C.ink, height: 1.55)),
        ],
      ]),
    );
  }
}
