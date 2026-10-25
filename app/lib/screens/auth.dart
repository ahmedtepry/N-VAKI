import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import 'home.dart';
import 'staff_access.dart';
import 'track.dart';

/// Guests can browse and fill a bag; anything tied to an account asks them to sign in first.
Future<bool> requireLogin(BuildContext context) async {
  if (App.i.user != null) return true;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.bg,
      title: Text(tr('سجّل دخولك الأول', 'Sign in first')),
      content: Text(tr('عشان تكمّل لازم يكون عندك حساب. الشنطة هتفضل زي ما هي.', 'You need an account to continue. Your bag stays as it is.'), style: const TextStyle(height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('رجوع', 'Back'), style: TextStyle(color: C.mute))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('تسجيل الدخول', 'Sign in'), style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    ),
  );
  if (go == true && context.mounted) Navigator.of(context).pushAndRemoveUntil(fadeRoute(const AuthScreen()), (_) => false);
  return false;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen();
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  int _logoTaps = 0;
  Timer? _logoTimer;

  void _logoTap() {
    _logoTimer?.cancel();
    if (++_logoTaps >= 5) {
      _logoTaps = 0;
      openStaffArea(context);
      return;
    }
    _logoTimer = Timer(const Duration(milliseconds: 1600), () => _logoTaps = 0);
  }

  bool register = false, busy = false, hide = true;
  final name = TextEditingController(), email = TextEditingController(), pass = TextEditingController(), phone = TextEditingController();
  final formKey = GlobalKey<FormState>();
  late final AnimationController sway = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _logoTimer?.cancel();
    sway.dispose();
    for (final c in [name, email, pass, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (register) {
        await Api.signUp(name.text, email.text, pass.text, phone.text);
      } else {
        await Api.signIn(email.text, pass.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const HomeScreen()), (_) => false);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => App.i.setLang(App.i.ar ? 'en' : 'ar'),
                      child: Text(App.i.ar ? 'EN' : 'عربي', style: TextStyle(color: C.ink, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ),
                  Center(child: Container(width: 170, height: 2, color: C.ink)),
                  Center(
                    child: AnimatedBuilder(
                      animation: sway,
                      builder: (_, __) => GarmentView(
                        garment: register ? 'hoodie' : 'jersey',
                        color: register ? const Color(0xFF9AA0A6) : const Color(0xFFF2C318),
                        accent: const Color(0xFF1E9E48),
                        width: 120,
                        swing: (sway.value - 0.5) * 0.12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: GestureDetector(onTap: _logoTap, child: const Wordmark(size: 26))),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      register ? tr('اعمل حسابك وابدأ', 'Create your account') : tr('أهلاً بيك تاني', 'Welcome back'),
                      style: TextStyle(color: C.mute, letterSpacing: 0.6),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (register)
                    TextFormField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: tr('الاسم', 'Full name')),
                      validator: (v) => (v ?? '').trim().length < 2 ? tr('اكتب اسمك', 'Enter your name') : null,
                    ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: tr('الإيميل', 'Email')),
                    validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : tr('إيميل غير صحيح', 'Invalid email'),
                  ),
                  if (register)
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(labelText: tr('رقم الموبايل (اختياري)', 'Phone (optional)')),
                    ),
                  TextFormField(
                    controller: pass,
                    obscureText: hide,
                    textDirection: TextDirection.ltr,
                    onFieldSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: tr('كلمة السر', 'Password'),
                      suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: C.mute), onPressed: () => setState(() => hide = !hide)),
                    ),
                    validator: (v) => (v ?? '').length < 8 ? tr('8 حروف على الأقل', 'At least 8 characters') : null,
                  ),
                  const SizedBox(height: 28),
                  NeonButton(register ? tr('إنشاء حساب', 'Create account') : tr('تسجيل الدخول', 'Sign in'), onPressed: submit, loading: busy),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: busy ? null : () => setState(() => register = !register),
                    child: Text(
                      register ? tr('عندي حساب بالفعل', 'I already have an account') : tr('مفيش عندي حساب؟ سجّل دلوقتي', 'New here? Create an account'),
                      style: TextStyle(color: C.ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => Navigator.of(context).pushAndRemoveUntil(fadeRoute(const HomeScreen()), (_) => false),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: Text(tr('تصفّح كزائر', 'Browse as a guest'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(foregroundColor: C.ink, side: BorderSide(color: C.ink), minimumSize: const Size.fromHeight(46), shape: const StadiumBorder()),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : () => Navigator.of(context).push(fadeRoute(const GuestTrackScreen())),
                    icon: Icon(Icons.local_shipping_outlined, size: 18, color: C.mute),
                    label: Text(tr('تتبّع طلب من غير حساب', 'Track an order without an account'), style: TextStyle(color: C.mute, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
