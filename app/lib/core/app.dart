import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const kSupabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const kBrand = 'NŌVAKI';

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

String tr(String ar, String en) => App.i.ar ? ar : en;

/// Global app state: language, session profile, cart, unread notifications.
class App extends ChangeNotifier {
  App._();
  static final App i = App._();

  late SharedPreferences prefs;
  String lang = 'ar';
  bool get ar => lang == 'ar';
  Map<String, dynamic>? profile;
  Map<String, String> settings = {};
  final List<CartLine> cart = [];
  int unread = 0;

  StreamSubscription? _notifSub;
  String? _notifUser;
  final Set<String> _seen = {};
  bool _firstNotif = true;

  SupabaseClient get db => Supabase.instance.client;
  User? get user => db.auth.currentUser;
  String get role => (profile?['role'] as String?) ?? 'customer';
  bool get isStaff => const ['owner', 'manager', 'support', 'fulfillment'].contains(role);
  bool get isManager => role == 'owner' || role == 'manager';
  String get name => (profile?['full_name'] as String?) ?? '';

  Future<void> init(SharedPreferences p) async {
    prefs = p;
    lang = p.getString('lang') ?? 'ar';
    _loadCart();
    db.auth.onAuthStateChange.listen((s) {
      if (s.session == null) {
        _stopRealtime();
        profile = null;
        notifyListeners();
      } else {
        _startRealtime();
      }
    });
    loadSettings();
  }

  void setLang(String l) {
    lang = l;
    prefs.setString('lang', l);
    notifyListeners();
  }

  Future<void> loadSettings() async {
    try {
      final rows = await db.from('app_settings').select();
      settings = {for (final r in rows) r['key'] as String: r['value'] as String};
      notifyListeners();
    } catch (_) {}
  }

  double get shippingFee => double.tryParse(settings['shipping_fee'] ?? '') ?? 60;
  double get freeOver => double.tryParse(settings['free_shipping_over'] ?? '') ?? 1500;

  Future<void> loadProfile() async {
    final u = user;
    if (u == null) return;
    try {
      profile = await db.from('profiles').select().eq('id', u.id).maybeSingle();
    } catch (_) {}
    _startRealtime();
    notifyListeners();
  }

  Future<void> signOut() async {
    _stopRealtime();
    await db.auth.signOut();
    profile = null;
    notifyListeners();
  }

  // ---- notifications (realtime) ----
  void _startRealtime() {
    final u = user;
    if (u == null) return;
    if (_notifUser == u.id && _notifSub != null) return;
    _stopRealtime();
    _notifUser = u.id;
    _firstNotif = true;
    _notifSub = db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', u.id)
        .order('created_at', ascending: false)
        .limit(60)
        .listen((rows) {
      unread = rows.where((r) => r['read_at'] == null).length;
      for (final r in rows) {
        final id = r['id'] as String;
        if (_seen.add(id) && !_firstNotif && r['read_at'] == null) _toast(r);
      }
      _firstNotif = false;
      notifyListeners();
    }, onError: (_) {});
  }

  void _stopRealtime() {
    _notifSub?.cancel();
    _notifSub = null;
    _notifUser = null;
    _seen.clear();
    unread = 0;
  }

  void _toast(Map<String, dynamic> r) {
    final title = ar ? r['title_ar'] : r['title_en'];
    final body = ar ? r['body_ar'] : r['body_en'];
    messengerKey.currentState?.showSnackBar(SnackBar(
      content: Text('$title${(body ?? '').toString().isEmpty ? '' : '\n$body'}', maxLines: 3, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 4),
    ));
  }

  // ---- cart ----
  void _loadCart() {
    try {
      final raw = prefs.getString('cart');
      if (raw == null) return;
      cart
        ..clear()
        ..addAll((jsonDecode(raw) as List).map((e) => CartLine.fromJson(Map<String, dynamic>.from(e))));
    } catch (_) {}
  }

  void _saveCart() {
    prefs.setString('cart', jsonEncode(cart.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  int get cartCount => cart.fold(0, (a, l) => a + l.qty);
  double get cartSubtotal => cart.fold(0.0, (a, l) => a + l.price * l.qty);
  double get cartShipping => cart.isEmpty ? 0 : (cartSubtotal >= freeOver ? 0 : shippingFee);

  void addToCart(Product p, Variant v) {
    for (final l in cart) {
      if (l.variantId == v.id) {
        l.qty = (l.qty + 1).clamp(1, 20);
        _saveCart();
        return;
      }
    }
    cart.add(CartLine(
      variantId: v.id,
      productId: p.id,
      nameAr: p.nameAr,
      nameEn: p.nameEn,
      colorAr: v.colorAr,
      colorEn: v.colorEn,
      hex: v.hex,
      garment: p.garment,
      size: v.size,
      accent: v.accent,
      price: p.price,
    ));
    _saveCart();
  }

  void setQty(CartLine l, int q) {
    if (q <= 0) {
      cart.remove(l);
    } else {
      l.qty = q.clamp(1, 20);
    }
    _saveCart();
  }

  void clearCart() {
    cart.clear();
    _saveCart();
  }
}
