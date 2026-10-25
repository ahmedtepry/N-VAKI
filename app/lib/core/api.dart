import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'models.dart';

typedef Json = Map<String, dynamic>;

class Api {
  static SupabaseClient get db => App.i.db;

  static Future<List<Product>> products({bool all = false}) async {
    var q = db.from('products').select('*, product_variants(*)');
    final rows = all ? await q.order('sort') : await q.eq('active', true).order('sort');
    return rows.map((r) => Product.fromJson(Json.from(r))).where((p) => all || p.variants.isNotEmpty).toList();
  }

  static Future<void> signIn(String email, String password) async {
    await db.auth.signInWithPassword(email: email.trim(), password: password);
    await App.i.loadProfile();
  }

  static Future<void> signUp(String name, String email, String password, String phone) async {
    final res = await db.functions.invoke('novaki-signup', body: {
      'email': email.trim(),
      'password': password,
      'full_name': name.trim(),
      if (phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
    final d = res.data;
    if (d is Map && d['error'] != null) throw Exception(d['error']);
    await signIn(email, password);
  }

  static Future<String> placeOrder({required String name, required String phone, required String address, required String city, String? notes}) async {
    final items = App.i.cart.map((l) => {'variant_id': l.variantId, 'qty': l.qty}).toList();
    final id = await db.rpc('place_order', params: {
      'p_items': items,
      'p_name': name,
      'p_phone': phone,
      'p_address': address,
      'p_city': city,
      'p_notes': notes,
    });
    return id as String;
  }

  static Future<List<Json>> myOrders() async {
    final rows = await db.from('orders').select('*, order_items(*)').eq('customer_id', App.i.user!.id).order('created_at', ascending: false);
    return rows.map((e) => Json.from(e)).toList();
  }

  static Future<List<Json>> orderHistory(String orderId) async {
    final rows = await db.from('order_status_history').select().eq('order_id', orderId).order('created_at');
    return rows.map((e) => Json.from(e)).toList();
  }

  static Future<void> cancelMyOrder(String id) async => db.rpc('cancel_my_order', params: {'p_order': id});

  static Future<String> supportOpen({String? subject, String? orderId}) async {
    final id = await db.rpc('support_open', params: {'p_subject': subject, 'p_order': orderId});
    return id as String;
  }

  static Future<void> markRead(String conv) async => db.rpc('support_mark_read', params: {'p_conv': conv});
  static Future<void> closeConv(String conv) async => db.rpc('support_close', params: {'p_conv': conv});

  static Future<void> sendMessage(String conv, String body, {required bool staff}) async {
    await db.from('support_messages').insert({
      'conversation_id': conv,
      'sender_id': App.i.user!.id,
      'sender_kind': staff ? 'staff' : 'customer',
      'body': body.trim(),
    });
  }

  static Future<List<Json>> notifications() async {
    final rows = await db.from('notifications').select().eq('user_id', App.i.user!.id).order('created_at', ascending: false).limit(80);
    return rows.map((e) => Json.from(e)).toList();
  }

  static Future<void> markNotificationsRead() async {
    await db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', App.i.user!.id).filter('read_at', 'is', null);
  }

  static Future<void> updateProfile(String name, String phone) async {
    await db.from('profiles').update({'full_name': name.trim(), 'phone': phone.trim()}).eq('id', App.i.user!.id);
    await App.i.loadProfile();
  }

  // ---- staff ----
  static Future<String> touchPresence() async => (await db.rpc('touch_presence')) as String;

  static Future<Json> dashboard() async => Json.from(await db.rpc('dashboard_stats'));

  static Future<void> setOrderStatus(String id, String status, {String? note}) async =>
      db.rpc('set_order_status', params: {'p_order': id, 'p_status': status, 'p_note': note});

  static Future<void> setUserRole(String email, String role) async => db.rpc('set_user_role', params: {'p_email': email, 'p_role': role});
  static Future<void> setMemberActive(String id, bool active) async => db.rpc('set_member_active', params: {'p_user': id, 'p_active': active});

  static Future<Map<String, Json>> profilesByIds(Iterable<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await db.from('profiles').select('id, full_name, email, phone, role').inFilter('id', ids.toList());
    return {for (final r in rows) r['id'] as String: Json.from(r)};
  }
}
