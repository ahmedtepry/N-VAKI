import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';

/// Cinematic push-in: the page dims, the camera "zooms" onto the piece.
Route<void> cinemaRoute(Widget page) => PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 900),
      reverseTransitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final z = CurvedAnimation(parent: a, curve: Curves.easeOutQuart, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: const Interval(0, 0.55, curve: Curves.easeOut)),
          child: ScaleTransition(scale: Tween(begin: 0.55, end: 1.0).animate(z), child: child),
        );
      },
    );

/// 360° turntable: drag to spin, pinch / double-tap to zoom, buttons snap to front / side / back.
class ViewerScreen extends StatefulWidget {
  final Product product;
  final Variant variant;
  const ViewerScreen({required this.product, required this.variant});
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> with TickerProviderStateMixin {
  final frame = Frame();
  final sw = Swing();
  late final Ticker ticker;
  Duration last = Duration.zero;
  double angle = 0, vel = 0; // radians, rad/s
  double zoom = 1, baseZoom = 1;
  Offset pan = Offset.zero;
  bool dragging = false, intro = true;
  double? target; // animated snap target
  double time = 0;

  @override
  void initState() {
    super.initState();
    ticker = createTicker(_tick)..start();
    // intro: a full slow turn once the zoom has landed
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) target = math.pi * 2;
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    frame.dispose();
    super.dispose();
  }

  void _tick(Duration d) {
    final dt = ((d - last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    last = d;
    time = d.inMicroseconds / 1e6;
    if (!dragging) {
      if (target != null) {
        final diff = target! - angle;
        // critically damped follow
        final k = intro ? 3.2 : 7.0;
        angle += diff * (1 - math.exp(-k * dt));
        if (diff.abs() < 0.002) {
          angle = target!;
          if (target! >= math.pi * 2 - 0.01) angle = target! - math.pi * 2;
          target = null;
          intro = false;
        }
      } else if (vel.abs() > 0.02) {
        angle += vel * dt;
        vel *= math.exp(-2.6 * dt);
      }
    }
    sw.step(dt);
    frame.bump();
  }

  void _snap(double a) {
    intro = false;
    vel = 0;
    // shortest way round
    final cur = angle % (math.pi * 2);
    var diff = a - cur;
    if (diff > math.pi) diff -= math.pi * 2;
    if (diff < -math.pi) diff += math.pi * 2;
    angle = cur;
    target = cur + diff;
    sw.kick(diff.sign * 1.1);
  }

  void _start(ScaleStartDetails d) {
    dragging = true;
    target = null;
    intro = false;
    baseZoom = zoom;
  }

  void _update(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      zoom = (baseZoom * d.scale).clamp(1.0, 3.2);
    } else if (zoom > 1.05) {
      pan += d.focalPointDelta;
    } else {
      angle += d.focalPointDelta.dx * 0.012;
      vel = d.focalPointDelta.dx * 0.012 * 60;
      sw.kick(-d.focalPointDelta.dx * 0.03);
    }
    if (zoom <= 1.05) pan = Offset.zero;
  }

  void _end(ScaleEndDetails d) {
    dragging = false;
  }

  void _dbl() {
    zoom = zoom > 1.2 ? 1 : 2.3;
    pan = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product, v = widget.variant;
    final size = MediaQuery.sizeOf(context);
    final bw = math.min(size.width * 0.9, size.height * 0.56 / 1.18);
    final col = hexColor(v.hex);
    final acc = v.accent == null ? null : hexColor(v.accent!);
    const hi = 1.5; // render a denser raster so zoomed details stay crisp
    Widget face(bool back) => SizedBox(
          width: bw,
          height: bw * 1.18,
          child: FittedBox(
            child: GarmentView(garment: p.garment, color: col, accent: acc, imageUrl: v.image, width: bw * hi, back: back),
          ),
        );
    final front = face(false), rear = face(true);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.25), radius: 1.1, colors: [Color(0xFF4A2229), Color(0xFF1A0E11)])),
        child: SafeArea(
          child: Stack(children: [
            // spotlight
            Positioned.fill(
              child: IgnorePointer(
                child: Container(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.2), radius: 0.7, colors: [Colors.white.withValues(alpha: 0.13), Colors.transparent]))),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _start,
                onScaleUpdate: _update,
                onScaleEnd: _end,
                onDoubleTap: _dbl,
                child: AnimatedBuilder(
                  animation: frame,
                  builder: (_, __) {
                    final a = angle;
                    final isBack = math.cos(a) < 0;
                    final m = Matrix4.identity()
                      ..setEntry(3, 2, 0.0011)
                      ..rotateY(isBack ? a + math.pi : a);
                    final sway = math.sin(time * 0.8) * 0.01;
                    return Stack(alignment: Alignment.center, children: [
                      // floor shadow that breathes with the turn
                      Align(
                        alignment: const Alignment(0, 0.62),
                        child: Container(
                          width: bw * (0.2 + 0.5 * math.cos(a).abs()),
                          height: 16,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4)]),
                        ),
                      ),
                      Transform.translate(
                        offset: pan,
                        child: Transform.scale(
                          scale: zoom,
                          child: Transform.rotate(
                            angle: sw.a + sway,
                            alignment: const Alignment(0, -0.94),
                            child: Transform(
                              transform: m,
                              alignment: Alignment.center,
                              child: RepaintBoundary(child: isBack ? rear : front),
                            ),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ),
            // top bar
            Positioned(
              left: 8,
              right: 8,
              top: 4,
              child: Row(children: [
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: C.onNeon)),
                Expanded(child: Text(p.name.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: C.onNeon, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13))),
                const SizedBox(width: 48),
              ]),
            ),
            // bottom controls
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: AnimatedBuilder(
                animation: frame,
                builder: (_, __) {
                  final deg = (angle % (math.pi * 2)) / math.pi * 180;
                  int cur = 0;
                  if (deg > 45 && deg < 135) cur = 1;
                  if (deg >= 135 && deg <= 225) cur = 2;
                  if (deg > 225 && deg < 315) cur = 3;
                  Widget chip(String t, int i, double target) {
                    final on = cur == i;
                    return GestureDetector(
                      onTap: () => _snap(target),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(color: on ? C.onNeon : Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withValues(alpha: on ? 0 : 0.25))),
                        child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: on ? C.ink : C.onNeon)),
                      ),
                    );
                  }

                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(tr('اسحب عشان تلفّ القطعة · قرّب بإصبعين أو دوس مرتين', 'Drag to spin · pinch or double-tap to zoom'), textAlign: TextAlign.center, style: TextStyle(color: C.onNeon.withValues(alpha: 0.65), fontSize: 12)),
                    const SizedBox(height: 14),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      chip(tr('أمام', 'Front'), 0, 0),
                      const SizedBox(width: 8),
                      chip(tr('جنب', 'Side'), 1, math.pi * 0.42),
                      const SizedBox(width: 8),
                      chip(tr('ضهر', 'Back'), 2, math.pi),
                      const SizedBox(width: 8),
                      chip(tr('جنب', 'Side'), 3, math.pi * 1.58),
                    ]),
                  ]);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
