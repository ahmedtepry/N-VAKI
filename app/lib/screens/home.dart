import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import 'account.dart';
import 'cart.dart';
import 'notifications.dart';
import 'product.dart';

const _cats = [
  ['all', 'الكل', 'All'],
  ['tees', 'تيشيرتات', 'Tees'],
  ['jerseys', 'جيرسي', 'Jerseys'],
  ['hoodies', 'هوديز', 'Hoodies'],
  ['jackets', 'جاكيتات', 'Jackets'],
  ['shirts', 'قمصان', 'Shirts'],
];

class HomeScreen extends StatefulWidget {
  const HomeScreen();
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Product> all = [];
  bool loading = true;
  Object? error;
  String cat = 'all';
  int idx = 0;
  final pc = PageController(viewportFraction: 0.38);
  late final AnimationController tick = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  double swing = 0, swingV = 0, lastPage = 0;

  List<Product> get list => cat == 'all' ? all : all.where((p) => p.category == cat).toList();

  @override
  void initState() {
    super.initState();
    tick.addListener(_physics);
    _load();
    if (App.i.profile == null && App.i.user != null) App.i.loadProfile();
  }

  @override
  void dispose() {
    tick.dispose();
    pc.dispose();
    super.dispose();
  }

  double get page => pc.hasClients && pc.position.haveDimensions ? (pc.page ?? 0) : 0;

  void _physics() {
    final cur = page;
    final v = cur - lastPage;
    lastPage = cur;
    swingV += v * 1.8;
    swingV += -swing * 0.11;
    swingV *= 0.9;
    swing = clampD(swing + swingV, -0.4, 0.4);
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      all = await Api.products();
    } catch (e) {
      error = e;
    }
    if (mounted) setState(() => loading = false);
  }

  void _open(int i) {
    final l = list;
    Navigator.of(context).push(fadeRoute(ProductScreen(products: l, index: i)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.i,
      builder: (context, _) {
        final l = list;
        final sel = l.isEmpty ? null : l[idx.clamp(0, l.length - 1)];
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              _topBar(),
              _catBar(),
              Expanded(child: _rack(l)),
              _info(sel),
              Ticker([
                tr('شحن مجاني فوق ${App.i.freeOver.round()} ج.م', 'FREE SHIPPING OVER ${App.i.freeOver.round()} EGP'),
                tr('الدفع عند الاستلام', 'CASH ON DELIVERY'),
                tr('تشكيلة جديدة', 'NEW DROP'),
                tr('خدمة عملاء مباشرة', 'LIVE SUPPORT'),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(color: C.neon, borderRadius: BorderRadius.circular(6)),
          child: const Wordmark(size: 13),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).push(fadeRoute(const NotificationsScreen())),
          icon: Badge2(App.i.unread, const Icon(Icons.notifications_none_rounded, color: C.ink)),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(fadeRoute(const CartScreen())),
          icon: Badge2(App.i.cartCount, const Icon(Icons.shopping_bag_outlined, color: C.ink)),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(fadeRoute(const AccountScreen())),
          icon: const Icon(Icons.person_outline_rounded, color: C.ink),
        ),
      ]),
    );
  }

  Widget _catBar() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          for (final c in _cats)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 18),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    cat = c[0];
                    idx = 0;
                  });
                  if (pc.hasClients) pc.jumpToPage(0);
                },
                child: Center(
                  child: Text(
                    tr(c[1], c[2]).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: cat == c[0] ? FontWeight.w900 : FontWeight.w500,
                      color: cat == c[0] ? C.ink : C.mute,
                      decoration: cat == c[0] ? TextDecoration.underline : TextDecoration.none,
                      decorationColor: C.neon,
                      decorationThickness: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rack(List<Product> l) {
    if (loading) return const Loading();
    if (error != null) return ErrorRetry(error!, _load);
    if (l.isEmpty) return Empty(tr('مفيش قطع في القسم ده لسه', 'Nothing here yet'));
    return LayoutBuilder(builder: (context, c) {
      final itemW = c.maxWidth * 0.38;
      final cur = page;
      return Stack(children: [
        Positioned(
          left: 14,
          right: 14,
          top: 26,
          child: Container(height: 2.2, decoration: BoxDecoration(color: C.ink.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2))),
        ),
        Positioned.fill(
          top: 20,
          child: PageView.builder(
            controller: pc,
            itemCount: l.length,
            clipBehavior: Clip.none,
            onPageChanged: (i) => setState(() => idx = i),
            itemBuilder: (_, i) {
              final p = l[i];
              final v = p.colors.isEmpty ? null : p.colors.first;
              final d = (cur - i).abs();
              final scale = (1.12 - d * 0.14).clamp(0.72, 1.12);
              final sway = math.sin(tick.value * 2 * math.pi + i * 1.3) * 0.022;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => i == idx ? _open(i) : pc.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOut),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Opacity(
                    opacity: (1 - d * 0.18).clamp(0.5, 1.0),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: GarmentView(
                        garment: p.garment,
                        color: v == null ? C.mute : hexColor(v.hex),
                        accent: v?.accent == null ? null : hexColor(v!.accent!),
                        width: itemW,
                        swing: swing * (1 - d.clamp(0.0, 1.0) * 0.4) + sway,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]);
    });
  }

  Widget _info(Product? p) {
    if (p == null) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(p.name.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(money(p.price), style: const TextStyle(fontSize: 12, color: C.mute, letterSpacing: 0.6)),
          if (p.compareAt != null && p.compareAt! > p.price) ...[
            const SizedBox(width: 8),
            Text(money(p.compareAt!), style: const TextStyle(fontSize: 11, color: C.mute, decoration: TextDecoration.lineThrough)),
          ],
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final v in p.colors.take(6))
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: hexColor(v.hex), shape: BoxShape.circle, border: Border.all(color: C.ink.withValues(alpha: 0.25), width: 0.6)),
            ),
        ]),
        const SizedBox(height: 14),
        NeonButton(tr('شوف القطعة', 'View piece'), onPressed: () => _open(idx), outline: true, wide: false),
      ]),
    );
  }
}
