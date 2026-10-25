import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/rack.dart';
import 'account.dart';
import 'cart.dart';
import 'notifications.dart';
import 'product.dart';
import 'staff_access.dart';
import '../widgets/navbar.dart';

List<List<String>> get _cats => [
      ['all', 'الكل', 'All'],
      ['fav', 'المفضلة', 'Saved'],
      for (final c in App.i.categories) ['${c['slug']}', '${c['name_ar']}', '${c['name_en']}'],
    ];

class HomeScreen extends StatefulWidget {
  const HomeScreen();
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> all = [];
  bool loading = true, searching = false;
  Object? error;
  String cat = 'all', query = '';
  int idx = 0;
  final search = TextEditingController();
  int logoTaps = 0;
  Timer? logoTimer;

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

  @override
  void initState() {
    super.initState();
    _load();
    if (App.i.profile == null && App.i.user != null) App.i.loadProfile();
  }

  @override
  void dispose() {
    search.dispose();
    logoTimer?.cancel();
    super.dispose();
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

  void _resetPage() => idx = 0; // the rack is re-created (keyed on category + search) and starts at the first piece

  void _open(int i) {
    final l = list;
    if (i < 0 || i >= l.length) return;
    Navigator.of(context).push(zoomRoute(ProductScreen(products: l, index: i)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.i,
      builder: (context, _) {
        final pc = App.i.pendingCat;
        if (pc != null) {
          App.i.pendingCat = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                cat = pc;
                searching = false;
                query = '';
                search.clear();
                idx = 0;
              });
            }
          });
        }
        final l = list;
        final sel = l.isEmpty ? null : l[idx.clamp(0, l.length - 1)];
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              _topBar(),
              if (!App.i.storeOpen)
                Container(
                  width: double.infinity,
                  color: C.ink,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(tr('المتجر مقفول مؤقتًا — تقدر تتصفح بس', 'Store temporarily closed — browsing only'), textAlign: TextAlign.center, style: TextStyle(color: C.onNeon, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              searching ? _searchBar() : _catBar(),
              Expanded(child: _rack(l)),
              _info(sel),
              Ticker2(),
            ]),
          ),
          bottomNavigationBar: NavBar(current: cat == 'fav' ? 1 : 0, onTap: _tab),
        );
      },
    );
  }

  void _logoTap() {
    logoTimer?.cancel();
    logoTaps++;
    if (logoTaps >= 5) {
      logoTaps = 0;
      openStaffArea(context);
      return;
    }
    logoTimer = Timer(const Duration(milliseconds: 1600), () => logoTaps = 0);
  }

  void _tab(int i) {
    switch (i) {
      case 0:
        setState(() {
          cat = 'all';
          searching = false;
          query = '';
          search.clear();
          idx = 0;
        });
        break;
      case 1:
        setState(() {
          cat = 'fav';
          idx = 0;
        });
        break;
      case 2:
        Navigator.of(context).push(fadeRoute(const CartScreen()));
        break;
      case 3:
        Navigator.of(context).push(fadeRoute(const AccountScreen()));
        break;
    }
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
        GestureDetector(
          onTap: _logoTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: C.neon, borderRadius: BorderRadius.circular(6)),
            child: Wordmark(size: 13, color: C.onNeon),
          ),
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
    return RackView(
      key: ValueKey('$cat|${query.trim()}|${l.length}'),
      items: l,
      onFocus: (i) {
        if (i != idx && mounted) setState(() => idx = i);
      },
      onOpen: _open,
    );
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
              Text(money(p.price), style: TextStyle(fontSize: 12.5, color: C.mute, letterSpacing: 0.6)),
              if (p.compareAt != null && p.compareAt! > p.price) ...[
                const SizedBox(width: 8),
                Text(money(p.compareAt!), style: TextStyle(fontSize: 11, color: C.mute, decoration: TextDecoration.lineThrough)),
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
  Widget build(BuildContext context) {
    final custom = App.i.tickerItems;
    return Marquee(custom.isNotEmpty
        ? custom
        : [
            tr('شحن مجاني فوق ${App.i.freeOver.round()} ج.م', 'FREE SHIPPING OVER ${App.i.freeOver.round()} EGP'),
            tr('الدفع عند الاستلام', 'CASH ON DELIVERY'),
            tr('تشكيلة جديدة', 'NEW DROP'),
            tr('خدمة عملاء مباشرة', 'LIVE SUPPORT'),
          ]);
  }
}
