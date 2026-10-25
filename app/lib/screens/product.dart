import 'dart:math' as math;
import 'package:flutter/material.dart';
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
  String? hex, size;
  int dir = 1;
  late final AnimationController sway = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  double kick = 0;

  Product get p => widget.products[i];
  String get curHex => hex ?? (p.colors.isEmpty ? '#888888' : p.colors.first.hex);
  Variant? get curVariant => size == null ? null : p.find(curHex, size!);

  @override
  void dispose() {
    sway.dispose();
    super.dispose();
  }

  void _go(int d) {
    final n = i + d;
    if (n < 0 || n >= widget.products.length) return;
    setState(() {
      dir = d;
      i = n;
      hex = null;
      size = null;
      kick = 0.25 * d;
    });
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) setState(() => kick = 0);
    });
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
    toast(tr('اتضافت للشنطة ✓', 'Added to your bag ✓'));
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;
    final colors = p.colors;
    final accentV = colors.firstWhere((v) => v.hex == curHex, orElse: () => colors.first);
    return Scaffold(
      appBar: AppBar(
        title: Text('${i + 1} / ${widget.products.length}', style: const TextStyle(fontSize: 12, letterSpacing: 2, color: C.mute)),
        actions: [
          ListenableBuilder(
            listenable: App.i,
            builder: (_, __) => IconButton(
              onPressed: () => Navigator.of(context).push(fadeRoute(const CartScreen())),
              icon: Badge2(App.i.cartCount, const Icon(Icons.shopping_bag_outlined)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Stack(children: [
              Positioned(left: 14, right: 14, top: 6, child: Container(height: 2.2, decoration: BoxDecoration(color: C.ink.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2)))),
              Align(
                alignment: Alignment.topCenter,
                child: AnimatedBuilder(
                  animation: sway,
                  builder: (_, __) => TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: hexColor(curHex)),
                    duration: const Duration(milliseconds: 380),
                    builder: (_, col, __) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(position: Tween<Offset>(begin: Offset(0.12 * dir, 0), end: Offset.zero).animate(a), child: child),
                      ),
                      child: Padding(
                        key: ValueKey(p.id),
                        padding: const EdgeInsets.only(top: 2),
                        child: GarmentView(
                          garment: p.garment,
                          color: col ?? hexColor(curHex),
                          accent: accentV.accent == null ? null : hexColor(accentV.accent!),
                          width: math.min(w * 0.66, h * 0.36),
                          swing: math.sin(sway.value * 2 * math.pi) * 0.03 + kick,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // hang tags
              PositionedDirectional(
                end: 14,
                top: 0,
                child: Column(children: [
                  for (final v in colors) _tag(v),
                ]),
              ),
              Positioned(left: 10, top: 0, bottom: 0, child: Center(child: _arrow(Icons.chevron_left_rounded, -1))),
              Positioned(right: 10, top: 0, bottom: 0, child: Center(child: _arrow(Icons.chevron_right_rounded, 1))),
            ]),
          ),
          ConstrainedBox(constraints: BoxConstraints(maxHeight: h * 0.46), child: SingleChildScrollView(child: _panel())),
        ]),
      ),
    );
  }

  Widget _arrow(IconData icon, int d) {
    final enabled = (i + d) >= 0 && (i + d) < widget.products.length;
    return Opacity(
      opacity: enabled ? 1 : 0.25,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(side: BorderSide(color: C.ink, width: 1)),
        child: InkWell(customBorder: const CircleBorder(), onTap: enabled ? () => _go(d) : null, child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 20))),
      ),
    );
  }

  Widget _tag(Variant v) {
    final sel = v.hex == curHex;
    final c = hexColor(v.hex);
    return GestureDetector(
      onTap: () => setState(() {
        hex = v.hex;
        size = null;
      }),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 1.2, height: sel ? 10 : 16, color: C.ink.withValues(alpha: 0.6)),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: sel ? 22 : 17,
          height: sel ? 40 : 30,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: sel ? C.ink : C.ink.withValues(alpha: 0.25), width: sel ? 1.4 : 0.8),
            boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 3))] : null,
          ),
          child: Container(width: 4, height: 4, decoration: BoxDecoration(color: C.bg, shape: BoxShape.circle, border: Border.all(color: C.ink.withValues(alpha: 0.4), width: 0.6))),
        ),
      ]),
    );
  }

  Widget _panel() {
    final sizes = p.sizesFor(curHex);
    final v = curVariant;
    final colorName = p.colors.firstWhere((e) => e.hex == curHex, orElse: () => p.colors.first).color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(p.name.toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.6))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(p.price), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (p.compareAt != null && p.compareAt! > p.price) Text(money(p.compareAt!), style: const TextStyle(fontSize: 11, color: C.mute, decoration: TextDecoration.lineThrough)),
          ]),
        ]),
        const SizedBox(height: 4),
        Text(colorName, style: const TextStyle(fontSize: 12, color: C.mute, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in sizes)
            GestureDetector(
              onTap: s.stock <= 0 ? null : () => setState(() => size = s.size),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 46,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: size == s.size ? C.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s.stock <= 0 ? C.line : C.ink, width: 1),
                ),
                child: Text(
                  s.size,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: size == s.size ? Colors.white : (s.stock <= 0 ? C.line : C.ink),
                    decoration: s.stock <= 0 ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
              ),
            ),
        ]),
        if (v != null && v.stock > 0 && v.stock <= 3)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('باقي ${v.stock} قطع بس', 'Only ${v.stock} left'), style: const TextStyle(color: C.warn, fontWeight: FontWeight.w700, fontSize: 12))),
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
