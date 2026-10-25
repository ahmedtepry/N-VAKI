import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/navbar.dart';
import 'auth.dart';
import 'chat.dart';
import 'orders.dart';
import 'track.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.i,
      builder: (context, _) {
        final a = App.i;
        if (a.user == null) {
          return Scaffold(
            appBar: AppBar(title: Text(tr('حسابي', 'ACCOUNT'))),
            bottomNavigationBar: const NavBar(current: 3),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_outline_rounded, size: 56, color: C.mute),
                  const SizedBox(height: 14),
                  Text(tr('إنت بتتصفح كزائر', 'You are browsing as a guest'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(tr('سجّل دخولك عشان تطلب وتتابع طلباتك وتكلم خدمة العملاء.', 'Sign in to order, follow your orders and chat with support.'), textAlign: TextAlign.center, style: TextStyle(color: C.mute, height: 1.5)),
                  const SizedBox(height: 22),
                  NeonButton(tr('تسجيل الدخول / إنشاء حساب', 'Sign in / Create account'), onPressed: () => Navigator.of(context).pushAndRemoveUntil(fadeRoute(const AuthScreen()), (_) => false)),
                  const SizedBox(height: 10),
                  NeonButton(tr('تتبّع طلب برقمه', 'Track an order by number'), outline: true, icon: Icons.local_shipping_outlined, onPressed: () => Navigator.of(context).push(fadeRoute(const GuestTrackScreen()))),
                ]),
              ),
            ),
          );
        }
        final initial = a.name.isEmpty ? '?' : a.name.characters.first.toUpperCase();
        return Scaffold(
          appBar: AppBar(title: Text(tr('حسابي', 'ACCOUNT'))),
          bottomNavigationBar: const NavBar(current: 3),
          body: ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 30), children: [
            Row(children: [
              Container(width: 60, height: 60, alignment: Alignment.center, decoration: BoxDecoration(color: C.neon, shape: BoxShape.circle), child: Text(initial, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: C.onNeon))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text(a.user?.email ?? '', style: TextStyle(color: C.mute, fontSize: 12.5)),
                  if (a.isStaff) Padding(padding: const EdgeInsets.only(top: 6), child: StatusChip(roleLabel(a.role), C.ink)),
                ]),
              ),
              IconButton(onPressed: () => _edit(context), icon: const Icon(Icons.edit_outlined, size: 20)),
            ]),
            const SizedBox(height: 22),
            _tile(context, Icons.inventory_2_outlined, tr('طلباتي', 'My orders'), () => Navigator.of(context).push(fadeRoute(const OrdersScreen()))),
            _tile(context, Icons.local_shipping_outlined, tr('تتبّع طلب برقمه', 'Track an order by number'), () => Navigator.of(context).push(fadeRoute(const GuestTrackScreen()))),
            _tile(context, Icons.chat_bubble_outline_rounded, tr('خدمة العملاء', 'Support chat'), () => Navigator.of(context).push(fadeRoute(const ChatScreen()))),
            _tile(context, Icons.translate_rounded, tr('اللغة: العربية / English', 'Language: English / العربية'), () => a.setLang(a.ar ? 'en' : 'ar')),
            const SizedBox(height: 18),
            NeonButton(tr('تسجيل الخروج', 'Sign out'), outline: true, onPressed: () async {
              await a.signOut();
              if (context.mounted) Navigator.of(context).pushAndRemoveUntil(fadeRoute(const AuthScreen()), (_) => false);
            }),
          ]),
        );
      },
    );
  }

  Widget _tile(BuildContext context, IconData i, String t, VoidCallback f, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Material(
          color: highlight ? C.tint : C.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: f,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: highlight ? C.ink : C.line)),
              child: Row(children: [Icon(i, size: 21), const SizedBox(width: 14), Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700))), Icon(Icons.chevron_right_rounded, color: C.mute)]),
            ),
          ),
        ),
      );

  Future<void> _edit(BuildContext context) async {
    final name = TextEditingController(text: App.i.name);
    final phone = TextEditingController(text: (App.i.profile?['phone'] as String?) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(tr('بياناتي', 'My details')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: tr('الاسم', 'Name'))),
          TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('الموبايل', 'Phone'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('إلغاء', 'Cancel'), style: TextStyle(color: C.mute))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('حفظ', 'Save'), style: TextStyle(color: C.ink, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok == true && name.text.trim().length >= 2) {
      try {
        await Api.updateProfile(name.text, phone.text);
      } catch (e) {
        toastError(e);
      }
    }
  }
}
