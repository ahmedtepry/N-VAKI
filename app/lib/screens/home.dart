import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  ['fav', 'المفضلة', 'Saved'],
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
  bool loading = true, searching = false;
  Object? error;
  String cat = 'all', query = '';
  int idx = 0;
  final pc = PageController(viewportFraction: 0.68);
  final frame = Frame();
  final search = TextEditingController();
  late final Ticker ticker;
  Duration last = Duration.zero;
  double lastPage = 0, time = 0;
  final Map<String, Swing> swings = {};

  List<Product> get list {
    var l = all;
    if (cat == 'fav') {
      l = l.where((p) => App.i.isFav(p.id)).toList();
    } else if (cat != 'all') {
      l = l.where((p) => p.category == cat).toList();
    }
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      l = l.where((p) => p.nameAr.toLowerCase().contains(q) || p.nameEn.toLowerCase().contains(q)).toList();
    }
    return l;
  }

  double get page => pc.hasClients && pc.position.haveDimensions ? (pc.page ?? 0) : 0;

  @override
  void initState() {
    super.initState();
    ticker = createTicker(_tick)..start();
    _load();
    if (App.i.profile == null && App.i.user != null) App.i.loadProfile();
  }

  @override
  void dispose() {
    ticker.dispose();
    pc.dispose();
    search.dispose();
    frame.dispose();
    super.dispose();
  }

  void _tick(Duration d) {
    final dt = ((d - last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    last = d;
    time = d.inMicroseconds / 1e6;
    final cur = page;
    final delta = cur - lastPage;
    lastPage = cur;
    final l = list;
    for (var i = 0; i < l.length; i++) {
      final s = swings.putIfAbsent(l[i].id, () => Swing());
      if (delta != 0) s.kick(-delta * 12 * (1 + 0.3 * math.sin(i * 1.7)));
      s.step(dt);
    }
    frame.bump();
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

  void _resetPage() {
    idx = 0;
    if (pc.hasClients) pc.jumpToPage(0);
  }

  void _open(int i) {
    final l = list;
    if (i < 0 || i >= l.length) return;
    swings[l[i].id]?.kick(1.6);
    Navigator.of(context).push(zoomRoute(ProductScreen(products: l, index: i)));
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
              searching ? _searchBar() : _catBar(),
              Expanded(child: _rack(l)),
              _info(sel),
              Ticker2(),
            ]),
          ),
        );
      },
    );
  }

  Widget _topBar() {
    Widget ic(IconData i, VoidCallback f, {int badge = 0}) => IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: f,
          icon: Badge2(badge, Icon(i, color: C.ink, size: 24)),
        );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 6, 6, 0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(color: C.neon, borderRadius: BorderRadius.circular(6)),
          child: const Wordmark(size: 13, color: C.onNeon),
        ),
        const Spacer(),
        ic(searching ? Icons.close_rounded : Icons.search_rounded, () {
          setState(() {
            searching = !searching;
            if (!searching) {
              query = '';
              search.clear();
              _resetPage();
            }
          });
        }),
        ic(Icons.notifications_none_rounded, () => Navigator.of(context).push(fadeRoute(const NotificationsScreen())), badge: App.i.unread),
        ic(Icons.shopping_bag_outlined, () => Navigator.of(context).push(fadeRoute(const CartScreen())), badge: App.i.cartCount),
        ic(Icons.person_outline_rounded, () => Navigator.of(context).push(fadeRoute(const AccountScreen()))),
      ]),
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
        child: SizedBox(
          height: 40,
          child: TextField(
            controller: search,
            autofocus: true,
            onChanged: (v) => setState(() {
              query = v;
              _resetPage();
            }),
            decoration: InputDecoration(hintText: tr('دوّر على قطعة...', 'Search the rack…'), isDense: true, prefixIcon: const Icon(Icons.search_rounded, size: 20)),
          ),
        ),
      );

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
                onTap: () => setState(() {
                  cat = c[0];
                  _resetPage();
                }),
                child: Center(
                  child: Text(
                    '${c[0] == 'fav' ? '♥ ' : ''}${tr(c[1], c[2]).toUpperCase()}',
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
    if (l.isEmpty) return Empty(cat == 'fav' ? tr('لسه مضفتش حاجة للمفضلة', 'Nothing saved yet') : tr('مفيش قطع هنا', 'Nothing here'));
    return LayoutBuilder(builder: (context, c) {
      final itemW = math.min(c.maxWidth * 0.68 * 0.98, (c.maxHeight - 34) / 1.18);
      return Stack(children: [
        // the rail
        Positioned(
          left: 0,
          right: 0,
          top: 22,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.ink.withValues(alpha: 0.0), C.ink.withValues(alpha: 0.85), C.ink.withValues(alpha: 0.85), C.ink.withValues(alpha: 0.0)], stops: const [0, 0.08, 0.92, 1]),
            ),
          ),
        ),
        Positioned.fill(
          top: 18,
          child: PageView.builder(
            controller: pc,
            itemCount: l.length,
            clipBehavior: Clip.none,
            onPageChanged: (i) => setState(() => idx = i),
            itemBuilder: (_, i) {
              final p = l[i];
              final v = p.colors.isEmpty ? null : p.colors.first;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => i == idx ? _open(i) : pc.animateToPage(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic),
                child: AnimatedBuilder(
                  animation: frame,
                  builder: (_, __) {
                    final d = i - page;
                    final a = d.abs().clamp(0.0, 1.0);
                    final sw = swings[p.id]?.a ?? 0;
                    final wind = math.sin(time * 0.9 + i * 1.3) * 0.016;
                    final m = Matrix4.identity()
                      ..setEntry(3, 2, 0.0011)
                      ..rotateY(-d.clamp(-1.0, 1.0) * 0.5);
                    return Align(
                      alignment: Alignment.topCenter,
                      child: RepaintBoundary(
                        child: Transform(
                          transform: m,
                          alignment: Alignment.topCenter,
                          child: Transform.scale(
                            scale: 1 - 0.2 * a,
                            alignment: Alignment.topCenter,
                            child: GarmentView(
                              garment: p.garment,
                              color: v == null ? C.mute : hexColor(v.hex),
                              accent: v?.accent == null ? null : hexColor(v!.accent!),
                              imageUrl: v?.image,
                              width: itemW,
                              swing: sw + wind,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]);
    });
  }

  Widget _info(Product? p) {
    if (p == null) return const SizedBox(height: 14);
    final fav = App.i.isFav(p.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(key: ValueKey(p.id), mainAxisSize: MainAxisSize.min, children: [
            Text(p.name.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(money(p.price), style: const TextStyle(fontSize: 12.5, color: C.mute, letterSpacing: 0.6)),
              if (p.compareAt != null && p.compareAt! > p.price) ...[
                const SizedBox(width: 8),
                Text(money(p.compareAt!), style: const TextStyle(fontSize: 11, color: C.mute, decoration: TextDecoration.lineThrough)),
              ],
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final v in p.colors.take(6))
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: hexColor(v.hex), shape: BoxShape.circle, border: Border.all(color: C.ink.withValues(alpha: 0.25), width: 0.6)),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          NeonButton(tr('شوف القطعة', 'View piece'), onPressed: () => _open(idx), outline: true, wide: false),
          const SizedBox(width: 10),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => App.i.toggleFav(p.id),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.ink, width: 1.2), color: fav ? C.neon : Colors.transparent),
              child: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 21, color: fav ? C.onNeon : C.ink),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Bottom ticker with the live shipping threshold.
class Ticker2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Marquee([
        tr('شحن مجاني فوق ${App.i.freeOver.round()} ج.م', 'FREE SHIPPING OVER ${App.i.freeOver.round()} EGP'),
        tr('الدفع عند الاستلام', 'CASH ON DELIVERY'),
        tr('تشكيلة جديدة', 'NEW DROP'),
        tr('خدمة عملاء مباشرة', 'LIVE SUPPORT'),
      ]);
}
