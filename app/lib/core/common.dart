import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'theme.dart';

String friendly(Object e) {
  final raw = e is PostgrestException
      ? '${e.message} ${e.details ?? ''}'
      : e is AuthException
          ? '${e.code ?? ''} ${e.message}'
          : e is FunctionException
              ? '${e.details ?? ''}'
              : e.toString();
  final m = raw.toLowerCase();
  bool has(String s) => m.contains(s.toLowerCase());
  if (has('out_of_stock')) return tr('المخزون مش كفاية للكمية دي.', 'Not enough stock for that quantity.');
  if (has('product_unavailable')) return tr('المنتج ده مبقاش متاح.', 'This item is no longer available.');
  if (has('cart_empty')) return tr('الشنطة فاضية.', 'Your bag is empty.');
  if (has('invalid_input')) return tr('راجع البيانات المدخلة.', 'Please check the details.');
  if (has('cannot_cancel')) return tr('الطلب اتأكد ومينفعش يتلغى من هنا. كلم الدعم.', 'This order is confirmed. Contact support to cancel.');
  if (has('forbidden')) return tr('مفيش صلاحية للإجراء ده.', 'You do not have permission for that.');
  if (has('not_found')) return tr('مش لاقيين الحساب أو العنصر ده.', 'Could not find that account or item.');
  if (has('already_registered') || has('already') && has('regist')) return tr('الإيميل ده متسجل قبل كده.', 'This email is already registered.');
  if (has('invalid_password') || has('weak')) return tr('كلمة السر لازم تكون 8 حروف على الأقل.', 'Password must be at least 8 characters.');
  if (has('invalid_email')) return tr('الإيميل غير صحيح.', 'Invalid email address.');
  if (has('invalid_name')) return tr('اكتب اسمك (حرفين على الأقل).', 'Enter your name (2+ characters).');
  if (has('invalid login') || has('invalid_credentials')) return tr('الإيميل أو كلمة السر غلط.', 'Wrong email or password.');
  if (has('socket') || has('failed host lookup') || has('clientexception') || has('timeout')) return tr('مفيش إنترنت. جرّب تاني.', 'No connection. Try again.');
  return tr('حصلت مشكلة. جرّب تاني.', 'Something went wrong. Try again.');
}

void toast(String msg) {
  messengerKey.currentState?.hideCurrentSnackBar();
  messengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
}

void toastError(Object e) => toast(friendly(e));

class Wordmark extends StatelessWidget {
  final double size;
  final Color color;
  const Wordmark({this.size = 20, this.color = C.ink});
  @override
  Widget build(BuildContext context) => Text(
        kBrand,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: size * 0.18, color: color, height: 1),
      );
}

class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading, outline, wide;
  final IconData? icon;
  const NeonButton(this.label, {this.onPressed, this.loading = false, this.outline = false, this.wide = true, this.icon});
  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final fg = outline ? C.ink : C.ink;
    final child = loading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.ink))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
            Flexible(
              child: Text(label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13)),
            ),
          ]);
    return Opacity(
      opacity: disabled && !loading ? 0.45 : 1,
      child: SizedBox(
        width: wide ? double.infinity : null,
        height: 50,
        child: Material(
          color: outline ? Colors.transparent : C.neon,
          shape: StadiumBorder(side: BorderSide(color: outline ? C.ink : C.neon, width: 1.2)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: disabled ? null : onPressed,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

/// Scrolling neon strip at the bottom of the storefront.
class Marquee extends StatefulWidget {
  final List<String> items;
  const Marquee(this.items);
  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: C.ink, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6);
    final unit = '${widget.items.map((e) => e.toUpperCase()).join('   ✦   ')}   ✦   ';
    final tp = TextPainter(text: TextSpan(text: unit, style: style), textDirection: TextDirection.ltr)..layout();
    final w = tp.width;
    return Container(
      height: 30,
      color: C.neon,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            child: Transform.translate(
              offset: Offset(-w * c.value, 0),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < 4; i++) Text(unit, style: style, softWrap: false),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading();
  @override
  Widget build(BuildContext context) => const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: C.ink)));
}

class Empty extends StatelessWidget {
  final String text;
  final IconData icon;
  const Empty(this.text, {this.icon = Icons.checkroom});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: C.line),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.mute)),
          ]),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorRetry(this.error, this.onRetry);
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(friendly(error), textAlign: TextAlign.center, style: const TextStyle(color: C.mute)),
            const SizedBox(height: 14),
            NeonButton(tr('إعادة المحاولة', 'Retry'), onPressed: onRetry, outline: true, wide: false),
          ]),
        ),
      );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class Badge2 extends StatelessWidget {
  final int count;
  final Widget child;
  const Badge2(this.count, this.child);
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        child,
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: C.neon, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.ink, width: 1)),
              child: Center(child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: C.ink, fontSize: 9, fontWeight: FontWeight.w900))),
            ),
          ),
      ]);
}

Future<bool> confirmDialog(BuildContext context, String title, {String? body}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.bg,
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('لأ', 'No'), style: const TextStyle(color: C.mute))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('تأكيد', 'Confirm'), style: const TextStyle(color: C.ink, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  return r == true;
}

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    );

/// Opens a product: it scales up from slightly smaller while fading in (feels like zooming into the piece).
Route<T> zoomRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: c,
          child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(c), child: child),
        );
      },
    );
