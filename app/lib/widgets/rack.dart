import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'garment.dart';

/// A freestanding clothes rack. Drag with a finger and the hangers slide along the rail like someone
/// flipping through the clothes: the hangers you push drag the ones behind them, they swing from
/// their hooks, and the piece in front is turned to face you and lifted slightly while touched.
class RackView extends StatefulWidget {
  final List<Product> items;
  final ValueChanged<int> onFocus;
  final ValueChanged<int> onOpen;
  const RackView({super.key, required this.items, required this.onFocus, required this.onOpen});
  @override
  State<RackView> createState() => _RackViewState();
}

class _RackViewState extends State<RackView> with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  Duration last = Duration.zero;
  double pos = 0, vel = 0; // in "items"
  int target = 0;
  bool down = false, touch = false;
  double press = 0, time = 0;
  int lastInt = 0;
  double itemW = 200, spacing = 120;
  final Frame frame = Frame();
  late List<double> lx, lv;
  late List<Swing> sw;

  int get n => widget.items.length;

  @override
  void initState() {
    super.initState();
    lx = List.filled(n, 0);
    lv = List.filled(n, 0);
    sw = List.generate(n, (_) => Swing());
    ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    ticker.dispose();
    frame.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ layout maths
  double _x(double d) {
    final a = d.abs();
    final g1 = itemW * 0.70, g2 = itemW * 0.17;
    final v = g1 * math.min(a, 1.0) + g2 * (a.clamp(1.0, 6.0) - 1.0);
    return d.sign * v;
  }

  void _tick(Duration dur) {
    final dt = ((dur - last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    last = dur;
    time = dur.inMicroseconds / 1e6;
    // finger-released motion: a soft spring to the item we are heading for
    if (!down) {
      const k = 62.0, c = 12.5;
      var t = dt;
      while (t > 0) {
        final h = math.min(t, 1 / 120);
        final acc = -k * (pos - target) - c * vel;
        vel += acc * h;
        pos += vel * h;
        t -= h;
      }
    }
    press += (((down || touch) ? 1.0 : 0.0) - press) * (1 - math.exp(-9 * dt));
    final r = pos.round().clamp(0, n - 1);
    if (r != lastInt) {
      lastInt = r;
      HapticFeedback.selectionClick();
      widget.onFocus(r);
    }
    // followers: hangers further from the hand lag behind and wobble
    var t = dt;
    while (t > 0) {
      final h = math.min(t, 1 / 120);
      for (var i = 0; i < n; i++) {
        final d = (i - pos).abs();
        if (d > 6.5) continue;
        final xt = _x(i - pos);
        final kf = 170 / (1 + 0.55 * d);
        final cf = 2 * math.sqrt(kf) * 0.72;
        final acc = kf * (xt - lx[i]) - cf * lv[i];
        final before = lv[i];
        lv[i] += acc * h;
        lx[i] += lv[i] * h;
        sw[i].v += -(lv[i] - before) / itemW * 0.55;
      }
      t -= h;
    }
    for (var i = 0; i < n; i++) {
      if ((i - pos).abs() < 6.5) sw[i].step(dt);
    }
    frame.bump();
  }

  // ------------------------------------------------------------ gestures
  void _dragStart(DragStartDetails d) {
    down = true;
    vel = 0;
  }

  void _dragUpdate(DragUpdateDetails d) {
    var dx = d.delta.dx;
    if (pos < 0 || pos > n - 1) dx *= 0.35; // rubber band at both ends
    final dp = -dx / spacing;
    pos += dp;
    final dt = math.max(1 / 120, 1 / 60);
    vel = vel * 0.6 + (dp / dt) * 0.4;
  }

  void _dragEnd(DragEndDetails d) {
    down = false;
    touch = false;
    final fling = (-(d.primaryVelocity ?? 0) / spacing) * 0.16;
    target = (pos + fling).round().clamp(0, n - 1);
    vel = -(d.primaryVelocity ?? 0) / spacing * 0.5;
    vel = vel.clamp(-14.0, 14.0);
  }

  void _tap(TapUpDetails d, double cx) {
    // topmost item under the finger = the one nearest the focus
    final order = List<int>.generate(n, (i) => i)..sort((a, b) => (a - pos).abs().compareTo((b - pos).abs()));
    for (final i in order) {
      if ((i - pos).abs() > 6) break;
      final w = itemW * (i == pos.round() ? 0.46 : 0.18);
      if ((d.localPosition.dx - (cx + lx[i])).abs() < w) {
        if (i == pos.round() && (pos - i).abs() < 0.2) {
          widget.onOpen(i);
        } else {
          target = i;
          vel += (i - pos).sign * 1.2;
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      itemW = math.min(w * 0.64, (h - 52) / 1.18);
      spacing = itemW * 0.62;
      final cx = w / 2;
      final upL = w * 0.045, upR = w * 0.955;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _dragStart,
        onHorizontalDragUpdate: _dragUpdate,
        onHorizontalDragEnd: _dragEnd,
        onHorizontalDragCancel: () {
          down = false;
          touch = false;
        },
        onTapDown: (_) => touch = true,
        onTapCancel: () => touch = false,
        onTapUp: (d) {
          touch = false;
          _tap(d, cx);
        },
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _StandPainter(upL, upR))),
          Positioned.fill(
            child: ClipRect(
              clipper: _Inset(upL + 4, upR - 4),
              child: AnimatedBuilder(
                animation: frame,
                builder: (_, __) {
                  final order = <int>[];
                  for (var i = 0; i < n; i++) {
                    if ((i - pos).abs() < 6.5) order.add(i);
                  }
                  order.sort((a, b) => (b - pos).abs().compareTo((a - pos).abs())); // far first, focus on top
                  return Stack(clipBehavior: Clip.none, children: [
                    for (final i in order) _item(i, cx, w),
                  ]);
                },
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _item(int i, double cx, double w) {
    final p = widget.items[i];
    final v = p.colors.isEmpty ? null : p.colors.first;
    final d = i - pos;
    final a = d.abs();
    final focus = (1 - a).clamp(0.0, 1.0);
    final yaw = -d.clamp(-1.0, 1.0) * 0.95;
    final scale = (1.0 - 0.06 * math.min(a, 3.0)) + 0.05 * press * focus;
    final lift = -12 * press * focus;
    final idle = math.sin(time * 0.9 + i * 1.7) * 0.012 * (1 - 0.5 * math.min(a, 1.0));
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0013)
      ..rotateY(yaw);
    return Positioned(
      left: cx + lx[i] - itemW / 2,
      top: 9 + lift + math.min(a, 3.0) * 3,
      width: itemW,
      child: RepaintBoundary(
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Transform(
            transform: m,
            alignment: Alignment.topCenter,
            child: GarmentView(
              garment: p.garment,
              color: v == null ? C.mute : hexColor(v.hex),
              accent: v?.accent == null ? null : hexColor(v!.accent!),
              imageUrl: v?.image,
              width: itemW,
              swing: sw[i].a + idle,
            ),
          ),
        ),
      ),
    );
  }
}

class _Inset extends CustomClipper<Rect> {
  final double l, r;
  _Inset(this.l, this.r);
  @override
  Rect getClip(Size s) => Rect.fromLTRB(l, 0, r, s.height);
  @override
  bool shouldReclip(covariant _Inset o) => o.l != l || o.r != r;
}

/// Chrome rail, two uprights, T-feet with little wheels and a floor shadow.
class _StandPainter extends CustomPainter {
  final double l, r;
  _StandPainter(this.l, this.r);

  Shader _chrome(Rect rc, {bool vertical = false}) => LinearGradient(
        begin: vertical ? Alignment.centerLeft : Alignment.topCenter,
        end: vertical ? Alignment.centerRight : Alignment.bottomCenter,
        colors: const [Color(0xFF6B6466), Color(0xFFE9E4E2), Color(0xFFB4ACAD), Color(0xFF5A5456)],
        stops: const [0, 0.35, 0.7, 1],
      ).createShader(rc);

  @override
  void paint(Canvas c, Size s) {
    final base = s.height - 14;
    // floor shadow
    c.drawOval(Rect.fromLTWH(l - 10, base - 6, r - l + 20, 22), Paint()..color = Colors.black.withValues(alpha: 0.13)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    for (final x in [l, r]) {
      // upright
      final up = Rect.fromLTWH(x - 3, 6, 6, base - 6);
      c.drawRRect(RRect.fromRectAndRadius(up, const Radius.circular(3)), Paint()..shader = _chrome(up, vertical: true));
      // foot (T) + wheels
      final foot = Rect.fromLTWH(x - 26, base - 3, 52, 6);
      c.drawRRect(RRect.fromRectAndRadius(foot, const Radius.circular(3)), Paint()..shader = _chrome(foot));
      for (final fx in [x - 22, x + 22]) {
        c.drawCircle(Offset(fx, base + 5), 4.2, Paint()..color = const Color(0xFF2A2326));
        c.drawCircle(Offset(fx, base + 5), 1.6, Paint()..color = const Color(0xFF8D8486));
      }
      // cap
      c.drawCircle(Offset(x, 6), 4.5, Paint()..shader = RadialGradient(colors: const [Color(0xFFF4F0EF), Color(0xFF6B6466)], center: const Alignment(-0.3, -0.4)).createShader(Rect.fromCircle(center: Offset(x, 6), radius: 4.5)));
    }
    // rail
    final rail = Rect.fromLTRB(l - 2, 9.5, r + 2, 15.5);
    c.drawRRect(RRect.fromRectAndRadius(rail, const Radius.circular(3)), Paint()..shader = _chrome(rail));
    c.drawLine(Offset(l, 10.8), Offset(r, 10.8), Paint()..color = Colors.white.withValues(alpha: 0.7)..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(covariant _StandPainter o) => o.l != l || o.r != r;
}
