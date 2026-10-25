import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import 'cart.dart';

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
    final gw = math.min(w * 0.68, h * 0.36);
    return ListenableBuilder(
      listenable: App.i,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text('${i + 1} / ${widget.products.length}', style: const TextStyle(fontSize: 12, letterSpacing: 2, color: C.mute)),
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
            Expanded(
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
                      onTap: () => sw.kick(1.3), // tap the garment to make it swing
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: hexColor(hx)),
                          duration: const Duration(milliseconds: 400),
                          builder: (_, col, __) => AnimatedBuilder(
                            animation: frame,
                            builder: (_, __) => GarmentView(
                              garment: x.garment,
                              color: col ?? hexColor(hx),
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
            ConstrainedBox(constraints: BoxConstraints(maxHeight: h * 0.46), child: SingleChildScrollView(child: _panel())),
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
        shape: const CircleBorder(side: BorderSide(color: C.ink, width: 1)),
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

  void _sizeGuide() {
    const rows = [
      ['S', '52', '68'],
      ['M', '54', '70'],
      ['L', '56', '72'],
      ['XL', '58', '74'],
      ['XXL', '60', '76'],
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('دليل المقاسات (تقريبي بالسم)', 'SIZE GUIDE (approx., cm)'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [for (final t in [tr('المقاس', 'Size'), tr('عرض الصدر', 'Chest'), tr('الطول', 'Length')]) Expanded(child: Text(t, style: const TextStyle(color: C.mute, fontSize: 12)))]),
          const Divider(),
          for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [for (final t in r) Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)))])),
          const SizedBox(height: 8),
          Text(tr('القصّة واسعة شوية. لو بين مقاسين، خد الأصغر.', 'Relaxed fit. Between sizes? Go smaller.'), style: const TextStyle(color: C.mute, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _panel() {
    final sizes = p.sizesFor(curHex);
    final v = curVariant;
    final colorName = p.colors.firstWhere((e) => e.hex == curHex, orElse: () => p.colors.first).color;
    final off = (p.compareAt != null && p.compareAt! > p.price) ? ((1 - p.price / p.compareAt!) * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(p.name.toUpperCase(), key: ValueKey(p.id), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.6)))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(p.price), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (off > 0) Row(mainAxisSize: MainAxisSize.min, children: [
              Text(money(p.compareAt!), style: const TextStyle(fontSize: 11, color: C.mute, decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: C.neon, borderRadius: BorderRadius.circular(4)), child: Text('-$off%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
            ]),
          ]),
        ]),
        const SizedBox(height: 4),
        Text(colorName, style: const TextStyle(fontSize: 12, color: C.mute, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Row(children: [
          Text(tr('المقاس', 'SIZE'), style: const TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
          const Spacer(),
          GestureDetector(onTap: _sizeGuide, child: Text(tr('دليل المقاسات', 'Size guide'), style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in sizes)
            GestureDetector(
              onTap: s.stock <= 0 ? null : () => setState(() => sizeOf[p.id] = s.size),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 48,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: curSize == s.size ? C.ink : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: s.stock <= 0 ? C.line : C.ink, width: 1)),
                child: Text(s.size, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: curSize == s.size ? Colors.white : (s.stock <= 0 ? C.line : C.ink), decoration: s.stock <= 0 ? TextDecoration.lineThrough : TextDecoration.none)),
              ),
            ),
        ]),
        if (v != null && v.stock > 0 && v.stock <= 3) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('باقي ${v.stock} قطع بس', 'Only ${v.stock} left'), style: const TextStyle(color: C.warn, fontWeight: FontWeight.w700, fontSize: 12))),
        const SizedBox(height: 16),
        NeonButton(tr('أضف للشنطة', 'Add to bag'), onPressed: _add, icon: Icons.add_shopping_cart_rounded),
        if (p.desc.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(p.desc, style: const TextStyle(fontSize: 12.5, color: C.mute, height: 1.5)),
        ],
      ]),
    );
  }
}
