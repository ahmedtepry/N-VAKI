import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import 'auth.dart';
import 'home.dart';

/// A tee is pressed by a printing machine, the logo is printed on it, and it drops out of the slot.
class SplashScreen extends StatefulWidget {
  const SplashScreen();
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..forward();
  bool _going = false;

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final started = DateTime.now();
    if (App.i.user != null) await App.i.loadProfile();
    final left = 3500 - DateTime.now().difference(started).inMilliseconds;
    if (left > 0) await Future.delayed(Duration(milliseconds: left));
    _next();
  }

  void _next() {
    if (!mounted || _going) return;
    _going = true;
    Navigator.of(context).pushReplacement(fadeRoute(App.i.user != null ? const HomeScreen() : const AuthScreen()));
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  static double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mw = math.min(size.width * 0.78, 300.0);
    final mh = mw * 0.46;
    final tw = mw * 0.56;
    final th = tw * 1.18;
    const cream = Color(0xFFEFE6DC);
    return Scaffold(
      backgroundColor: C.neon,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Center(
          child: AnimatedBuilder(
            animation: c,
            builder: (_, __) {
              final t = c.value;
              final out = Curves.easeInOutCubic.transform(_seg(t, 0.14, 0.62)); // tee leaves the slot
              final print = _seg(t, 0.2, 0.6); // logo gets printed while it moves
              final settle = (t - 0.62).clamp(0.0, 1.0);
              final swing = settle == 0 ? 0.0 : 0.16 * math.exp(-settle * 9) * math.sin(settle * 38);
              final shake = t < 0.66 ? math.sin(t * 150) * 1.1 : 0.0;
              final word = Curves.easeOut.transform(_seg(t, 0.68, 0.9));
              final slotY = mh - 6;
              return SizedBox(
                width: mw,
                height: mh + th + 76,
                child: Stack(clipBehavior: Clip.none, children: [
                  // tee (clipped so it only exists below the slot)
                  Positioned(
                    left: (mw - tw) / 2,
                    top: slotY,
                    width: tw,
                    height: th + 30,
                    child: ClipRect(
                      child: Transform.translate(
                        offset: Offset(0, -th * (1 - out) + 4),
                        child: Transform.rotate(
                          angle: swing,
                          alignment: const Alignment(0, -0.2),
                          child: SizedBox(
                            width: tw,
                            height: th,
                            child: Stack(children: [
                              GarmentView(garment: 'tee', color: cream, width: tw, shadow: false, hanger: false),
                              // the print: revealed top-down, with a bright scan edge
                              Positioned(
                                left: 0,
                                right: 0,
                                top: th * 0.36,
                                height: th * 0.2,
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    heightFactor: print.clamp(0.001, 1.0),
                                    child: SizedBox(
                                      height: th * 0.2,
                                      child: Center(child: Text(kBrand, style: TextStyle(fontSize: tw * 0.12, fontWeight: FontWeight.w900, letterSpacing: tw * 0.02, color: C.neon, height: 1))),
                                    ),
                                  ),
                                ),
                              ),
                              if (print > 0 && print < 1)
                                Positioned(left: tw * 0.22, right: tw * 0.22, top: th * 0.36 + th * 0.2 * print, height: 2, child: Container(decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6)]))),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // the machine
                  Positioned(
                    left: shake,
                    top: 0,
                    width: mw,
                    height: mh,
                    child: CustomPaint(painter: _MachinePainter(t)),
                  ),
                  Positioned(left: 0, right: 0, bottom: 0, child: Opacity(opacity: word, child: Transform.translate(offset: Offset(0, 14 * (1 - word)), child: const Center(child: Wordmark(size: 28, color: C.onNeon))))),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MachinePainter extends CustomPainter {
  final double t;
  _MachinePainter(this.t);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h - 6), const Radius.circular(18));
    // body
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 10, true);
    canvas.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B1D20), Color(0xFF171012)]).createShader(body.outerRect));
    canvas.drawRRect(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.white.withValues(alpha: 0.12));
    // top panel + lights
    final blink = (math.sin(t * 40) > 0) && t < 0.66;
    for (var i = 0; i < 3; i++) {
      final on = i == 0 ? true : (i == 1 ? blink : t >= 0.66);
      canvas.drawCircle(Offset(w * 0.1 + i * 16, 16), 4, Paint()..color = on ? (i == 2 ? const Color(0xFF7FD99A) : const Color(0xFFE8B46A)) : Colors.white.withValues(alpha: 0.15));
    }
    final tp = TextPainter(text: TextSpan(text: 'PRESS · 01', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, letterSpacing: 2.4, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(w - tp.width - 18, 11));
    // print head travelling along a rail
    final railY = h * 0.42;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, railY, w * 0.84, 5), const Radius.circular(3)), Paint()..color = Colors.white.withValues(alpha: 0.18));
    final k = ((t - 0.1) / 0.55).clamp(0.0, 1.0);
    final x = w * 0.12 + (w * 0.76) * (0.5 - 0.5 * math.cos(k * math.pi * 6));
    final head = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, railY + 2), width: 30, height: 20), const Radius.circular(5));
    canvas.drawRRect(head, Paint()..color = const Color(0xFFD9C7B8));
    canvas.drawRect(Rect.fromCenter(center: Offset(x, railY + 15), width: 6, height: 9), Paint()..color = C.neon);
    // slot
    final slot = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.14, h - 22, w * 0.72, 14), const Radius.circular(7));
    canvas.drawRRect(slot, Paint()..color = Colors.black);
    canvas.drawRRect(slot, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withValues(alpha: 0.2));
  }

  @override
  bool shouldRepaint(covariant _MachinePainter o) => o.t != t;
}
