import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Notifies listeners once per animation frame (drives the swing physics without rebuilding whole screens).
class Frame extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Damped pendulum used to make garments swing from their hanger.
class Swing {
  double a = 0, v = 0;
  void step(double dt) {
    var t = dt;
    while (t > 0) {
      final h = math.min(t, 1 / 120);
      v += (-22 * a - 1.5 * v) * h;
      a += v * h;
      t -= h;
    }
    a = clampD(a, -0.6, 0.6);
  }

  void kick(double x) => v += x;
}

/// Draws a garment hanging on a wooden hanger, fully in vector: fabric shading, folds, seams and stitching.
class GarmentPainter extends CustomPainter {
  final String garment;
  final Color color;
  final Color? accent;
  final double swing; // radians, rotates around the hook
  final bool shadow;
  final bool hangerOnly;
  final bool hanger;
  final bool back; // view from behind
  GarmentPainter({required this.garment, required this.color, this.accent, this.swing = 0, this.shadow = true, this.hangerOnly = false, this.hanger = true, this.back = false});

  static const double W = 100, H = 118;
  static const _rect = Rect.fromLTWH(0, 0, W, H);

  bool get _dark => isDark(color);
  Color get _rib => shade(color, _dark ? 0.09 : -0.12);
  Color get _stitch => _dark ? Colors.white.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.26);
  bool get _long => garment == 'hoodie' || garment == 'jacket' || garment == 'shirt';

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / W, size.height / H);
    canvas.save();
    canvas.translate((size.width - W * s) / 2, 0);
    canvas.scale(s);
    canvas.translate(50, 3);
    canvas.rotate(swing);
    canvas.translate(-50, -3);

    if (hangerOnly) {
      _arms(canvas);
      _hook(canvas);
      canvas.restore();
      return;
    }

    final torso = _torso();
    final sleeves = _long ? [_sleeve(false), _sleeve(true)] : <Path>[];
    var sil = torso;
    for (final sl in sleeves) {
      sil = Path.combine(PathOperation.union, sil, sl);
    }

    if (shadow) {
      canvas.save();
      canvas.translate(-7, 6);
      canvas.drawPath(sil, Paint()..color = Colors.black.withValues(alpha: 0.14)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.restore();
    }
    if (hanger) _arms(canvas);
    if (garment == 'hoodie') _hood(canvas);

    // sleeves sit behind the torso's front edge but over the body: draw torso first, then sleeves
    _fabric(canvas, torso, color);
    _torsoFolds(canvas, torso);
    for (final sl in sleeves) {
      _fabric(canvas, sl, shade(color, _dark ? 0.015 : -0.025));
      canvas.drawPath(sl, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.9..color = Colors.black.withValues(alpha: 0.2));
    }
    if (_long) _sleeveFolds(canvas, sleeves);

    canvas.save();
    canvas.clipPath(sil);
    _details(canvas);
    canvas.restore();
    if (hanger) _hook(canvas);

    canvas.drawPath(sil, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.7..strokeJoin = StrokeJoin.round..color = Colors.black.withValues(alpha: 0.24));
    canvas.restore();
  }

  // ------------------------------------------------------------------ shapes
  Path _torso() {
    final p = Path();
    if (_long) {
      p.moveTo(39, 13);
      p.quadraticBezierTo(26, 17, 15, 25);
      p.lineTo(24, 50);
      p.cubicTo(25, 74, 21, 96, 22, 106);
      p.quadraticBezierTo(50, 110, 78, 106);
      p.cubicTo(79, 96, 75, 74, 76, 50);
      p.lineTo(85, 25);
      p.quadraticBezierTo(74, 17, 61, 13);
      if (back) {
        p.quadraticBezierTo(50, 17.5, 39, 13);
      } else if (garment == 'shirt') {
        p.lineTo(50, 30);
        p.lineTo(39, 13);
      } else {
        p.cubicTo(57, 28, 43, 28, 39, 13);
      }
      p.close();
      return p;
    }
    p.moveTo(39, 13);
    p.quadraticBezierTo(26, 17, 15, 25);
    p.quadraticBezierTo(6, 34, 2, 47);
    p.lineTo(19, 55);
    p.quadraticBezierTo(20, 50, 24, 47);
    p.cubicTo(26, 70, 21, 92, 22, 105);
    p.quadraticBezierTo(50, 109, 78, 105);
    p.cubicTo(79, 92, 74, 70, 76, 47);
    p.quadraticBezierTo(80, 50, 81, 55);
    p.lineTo(98, 47);
    p.quadraticBezierTo(94, 34, 85, 25);
    p.quadraticBezierTo(74, 17, 61, 13);
    if (back) {
      p.quadraticBezierTo(50, 17.5, 39, 13);
    } else if (garment == 'jersey') {
      p.lineTo(50, 34);
      p.lineTo(39, 13);
    } else {
      p.cubicTo(57, 28, 43, 28, 39, 13);
    }
    p.close();
    return p;
  }

  Path _sleeve(bool right) {
    final p = Path()
      ..moveTo(15, 25)
      ..quadraticBezierTo(7, 52, 5, 85)
      ..lineTo(20, 90)
      ..quadraticBezierTo(20, 68, 25, 50)
      ..close();
    return right ? _mirror(p) : p;
  }

  Path _mirror(Path p) => p.transform(Float64List.fromList(<double>[-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 100, 0, 0, 1]));

  // ------------------------------------------------------------------ fabric
  void _fabric(Canvas c, Path p, Color base) {
    c.save();
    c.clipPath(p);
    c.drawPath(p, Paint()..color = base);
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.10), Colors.transparent, Colors.black.withValues(alpha: 0.13)],
          stops: const [0, 0.45, 1],
        ).createShader(_rect),
    );
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white.withValues(alpha: 0.10), Colors.transparent, Colors.black.withValues(alpha: 0.17)],
          stops: const [0, 0.55, 1],
        ).createShader(_rect),
    );
    // inner edge vignette makes the cloth look puffed
    c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..color = Colors.black.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    c.restore();
  }

  void _soft(Canvas c, Path p, double w, double alpha, {Color col = Colors.black, double blur = 1.8}) {
    c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round..color = col.withValues(alpha: alpha)..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
  }

  void _torsoFolds(Canvas c, Path torso) {
    c.save();
    c.clipPath(torso);
    // armpit pockets of shadow
    for (final o in const [Offset(25, 52), Offset(75, 52)]) {
      c.drawCircle(o, 8, Paint()..color = Colors.black.withValues(alpha: 0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    // neck shadow
    c.drawOval(const Rect.fromLTWH(36, 12, 28, 14), Paint()..color = Colors.black.withValues(alpha: 0.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final f1 = Path()..moveTo(34, 48)..cubicTo(39, 62, 33, 82, 36, 102);
    final f2 = Path()..moveTo(63, 52)..cubicTo(58, 68, 64, 86, 60, 104);
    final f3 = Path()..moveTo(46, 40)..cubicTo(49, 58, 45, 78, 48, 100);
    final f4 = Path()..moveTo(27, 62)..quadraticBezierTo(33, 66, 40, 63);
    _soft(c, f1, 3.2, 0.10);
    _soft(c, f2, 3.2, 0.11);
    _soft(c, f4, 2.4, 0.07);
    _soft(c, f3, 2.6, 0.09, col: Colors.white);
    _soft(c, f1.shift(const Offset(1.8, 0)), 1.4, 0.07, col: Colors.white, blur: 1);
    // hem shadow
    c.drawRect(const Rect.fromLTWH(18, 99, 64, 14), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.12)]).createShader(const Rect.fromLTWH(18, 99, 64, 14)));
    c.restore();
  }

  void _sleeveFolds(Canvas c, List<Path> sleeves) {
    for (var i = 0; i < sleeves.length; i++) {
      c.save();
      c.clipPath(sleeves[i]);
      final dx = i == 0 ? 0.0 : 0.0;
      final f = i == 0 ? (Path()..moveTo(13, 36)..cubicTo(11, 52, 14, 66, 12, 82)) : (Path()..moveTo(87, 36)..cubicTo(89, 52, 86, 66, 88, 82));
      final g = i == 0 ? (Path()..moveTo(18, 40)..cubicTo(17, 54, 19, 64, 17, 76)) : (Path()..moveTo(82, 40)..cubicTo(83, 54, 81, 64, 83, 76));
      _soft(c, f.shift(Offset(dx, 0)), 3, 0.12);
      _soft(c, g, 2.2, 0.09, col: Colors.white);
      c.restore();
    }
  }

  // ------------------------------------------------------------------ hanger
  void _arms(Canvas c) {
    final arms = Path()
      ..moveTo(12, 28)
      ..cubicTo(26, 22, 40, 15, 50, 11)
      ..cubicTo(60, 15, 74, 22, 88, 28);
    c.drawPath(arms, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.4..strokeCap = StrokeCap.round..color = const Color(0xFF6B4A2B));
    c.drawPath(arms, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.3..strokeCap = StrokeCap.round..color = const Color(0xFFC49A6C));
    c.drawPath(arms.shift(const Offset(0, -0.5)), Paint()..style = PaintingStyle.stroke..strokeWidth = 0.7..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.35));
  }

  void _hook(Canvas c) {
    final hook = Path()
      ..moveTo(50, 12)
      ..lineTo(50, 7.5)
      ..cubicTo(50, 2.5, 57.5, 2.5, 57.5, 6.2);
    c.drawPath(hook, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.7..strokeCap = StrokeCap.round..color = const Color(0xFF5E5E5E));
    c.drawPath(hook, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..strokeCap = StrokeCap.round..color = const Color(0xFFD9D9D9));
  }

  void _hood(Canvas c) {
    final hood = Path()
      ..moveTo(32, 20)
      ..cubicTo(25, 6, 38, 3, 50, 3.5)
      ..cubicTo(62, 3, 75, 6, 68, 20)
      ..quadraticBezierTo(50, 36, 32, 20)
      ..close();
    _fabric(c, hood, shade(color, _dark ? 0.02 : -0.05));
    c.drawPath(hood, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.7..color = Colors.black.withValues(alpha: 0.24));
    if (back) {
      c.drawPath(Path()..moveTo(50, 4)..cubicTo(51, 12, 50, 20, 50, 29), _ln(Colors.black.withValues(alpha: 0.2), 0.7));
      return;
    }
    // dark opening
    final inner = Path()
      ..moveTo(39, 14)
      ..quadraticBezierTo(50, 26, 61, 14)
      ..quadraticBezierTo(50, 8, 39, 14)
      ..close();
    c.drawPath(inner, Paint()..color = Colors.black.withValues(alpha: 0.42));
  }

  // ------------------------------------------------------------------ details
  Path _dash(Path src, double on, double off) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  Paint _ln(Color c, double w) => Paint()..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = c;

  void _stitchLine(Canvas c, Path p) => c.drawPath(_dash(p, 1.1, 0.9), _ln(_stitch, 0.55));

  void _neckBack(Canvas c, {double depth = 28}) {
    final back = Path()
      ..moveTo(39, 13)
      ..cubicTo(43, 15.5, 57, 15.5, 61, 13)
      ..cubicTo(57, depth, 43, depth, 39, 13)
      ..close();
    c.drawPath(back, Paint()..color = shade(color, -0.22).withValues(alpha: 0.9));
  }

  void _ribBand(Canvas c, Path band, {bool vertical = true}) {
    c.save();
    c.clipPath(band);
    c.drawPath(band, Paint()..color = _rib);
    final lc = _dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.10);
    final b = band.getBounds();
    for (var x = b.left; x < b.right; x += 2.2) {
      c.drawLine(Offset(x, b.top), Offset(x, b.bottom), _ln(lc, 0.7));
    }
    c.restore();
    c.drawPath(band, _ln(Colors.black.withValues(alpha: 0.18), 0.6));
  }

  void _brand(Canvas c, double x, double y, double size, Color col) {
    final tp = TextPainter(text: TextSpan(text: 'NŌVAKI', style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: size * 0.22, color: col)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  void _number(Canvas c, String t, double x, double y, double size, Color fill, Color stroke) {
    final style = TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 1);
    final o = TextPainter(text: TextSpan(text: t, style: style.copyWith(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = size * 0.16..color = stroke)), textDirection: TextDirection.ltr)..layout();
    final f = TextPainter(text: TextSpan(text: t, style: style.copyWith(color: fill)), textDirection: TextDirection.ltr)..layout();
    o.paint(c, Offset(x - o.width / 2, y - o.height / 2));
    f.paint(c, Offset(x - f.width / 2, y - f.height / 2));
  }

  void _details(Canvas c) {
    if (back) {
      _detailsBack(c);
      return;
    }
    final a = accent;
    switch (garment) {
      case 'tee':
        _neckBack(c);
        c.drawPath(Path()..moveTo(39, 13)..cubicTo(43, 26, 57, 26, 61, 13), _ln(_rib, 2.4));
        c.drawPath(Path()..moveTo(39, 13)..cubicTo(43, 24, 57, 24, 61, 13), _ln(Colors.black.withValues(alpha: 0.16), 0.5));
        c.drawRect(const Rect.fromLTWH(46, 13.2, 8, 3.2), Paint()..color = Colors.white.withValues(alpha: 0.75));
        c.drawPath(Path()..moveTo(15, 25)..quadraticBezierTo(21, 38, 24, 47), _ln(Colors.black.withValues(alpha: 0.13), 0.7));
        c.drawPath(Path()..moveTo(85, 25)..quadraticBezierTo(79, 38, 76, 47), _ln(Colors.black.withValues(alpha: 0.13), 0.7));
        _stitchLine(c, Path()..moveTo(2.8, 51)..lineTo(19.2, 58.2));
        _stitchLine(c, Path()..moveTo(97.2, 51)..lineTo(80.8, 58.2));
        _stitchLine(c, Path()..moveTo(23, 102)..quadraticBezierTo(50, 105.5, 77, 102));
        if (a != null) {
          _brand(c, 37, 34, 3.6, a);
          _number(c, 'N', 50, 66, 20, a, Colors.black.withValues(alpha: 0.0));
        }
        break;
      case 'jersey':
        final ac = a ?? const Color(0xFF1E9E48);
        final left = Path()..moveTo(24, 47)..cubicTo(26, 70, 21, 92, 22, 105)..lineTo(31, 105.6)..cubicTo(30, 92, 34, 70, 31.5, 49)..close();
        final right = _mirror(left);
        c.drawPath(left, Paint()..color = ac);
        c.drawPath(right, Paint()..color = ac);
        c.drawPath(left, _ln(Colors.black.withValues(alpha: 0.15), 0.6));
        c.drawPath(right, _ln(Colors.black.withValues(alpha: 0.15), 0.6));
        // sleeve bands
        final sb = Path()..moveTo(2, 47)..lineTo(19, 55)..lineTo(18, 59.5)..lineTo(0.2, 51.5)..close();
        c.drawPath(sb, Paint()..color = ac);
        c.drawPath(_mirror(sb), Paint()..color = ac);
        // V collar
        _neckBack(c, depth: 30);
        c.drawPath(Path()..moveTo(39, 13)..lineTo(50, 34)..lineTo(61, 13), _ln(ac, 3.4));
        c.drawPath(Path()..moveTo(39, 13)..lineTo(50, 34)..lineTo(61, 13), _ln(Colors.black.withValues(alpha: 0.2), 0.5));
        // chest stripes
        c.drawPath(Path()..moveTo(33, 60)..lineTo(67, 60), _ln(ac.withValues(alpha: 0.65), 1.3));
        c.drawPath(Path()..moveTo(33, 63.5)..lineTo(67, 63.5), _ln(ac.withValues(alpha: 0.4), 1.3));
        _brand(c, 50, 52, 3.6, isDark(color) ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.7));
        _number(c, '25', 50, 84, 21, ac, isDark(color) ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.55));
        _stitchLine(c, Path()..moveTo(32, 102)..quadraticBezierTo(50, 105.3, 68, 102));
        break;
      case 'hoodie':
        final hem = Path()..moveTo(22.2, 98.5)..quadraticBezierTo(50, 102, 77.8, 98.5)..lineTo(78, 106)..quadraticBezierTo(50, 110, 22, 106)..close();
        _ribBand(c, hem);
        final cl = Path()..moveTo(5.8, 79.5)..lineTo(19.6, 84.2)..lineTo(20, 90)..lineTo(5, 85)..close();
        _ribBand(c, cl);
        _ribBand(c, _mirror(cl));
        // kangaroo pouch
        final pouch = Path()..moveTo(33, 71)..lineTo(67, 71)..lineTo(72.5, 97)..lineTo(27.5, 97)..close();
        c.drawPath(pouch, _ln(Colors.black.withValues(alpha: 0.2), 0.9));
        c.drawPath(Path()..moveTo(33, 71)..lineTo(28.5, 95), _ln(Colors.white.withValues(alpha: 0.10), 1.6));
        _stitchLine(c, Path()..moveTo(34.5, 72.5)..lineTo(66, 72.5)..moveTo(34.5, 72.5)..lineTo(30.5, 94));
        // drawstrings
        final cord = const Color(0xFFEDE6D6);
        c.drawPath(Path()..moveTo(44, 23)..cubicTo(43, 32, 45, 40, 43.5, 51), _ln(Colors.black.withValues(alpha: 0.25), 2.0));
        c.drawPath(Path()..moveTo(56, 23)..cubicTo(57, 32, 55, 40, 56.5, 51), _ln(Colors.black.withValues(alpha: 0.25), 2.0));
        c.drawPath(Path()..moveTo(44, 23)..cubicTo(43, 32, 45, 40, 43.5, 51), _ln(cord, 1.3));
        c.drawPath(Path()..moveTo(56, 23)..cubicTo(57, 32, 55, 40, 56.5, 51), _ln(cord, 1.3));
        for (final o in const [Offset(43.5, 52), Offset(56.5, 52)]) {
          c.drawCircle(o, 1.25, Paint()..color = const Color(0xFF8E8E8E));
        }
        if (a != null) _brand(c, 50, 63, 3.4, a);
        c.drawPath(Path()..moveTo(15, 25)..lineTo(24, 50), _ln(Colors.black.withValues(alpha: 0.14), 0.7));
        break;
      case 'jacket':
        final ac = a ?? const Color(0xFFEFE6D2);
        final hem = Path()..moveTo(22.2, 98.5)..quadraticBezierTo(50, 102, 77.8, 98.5)..lineTo(78, 106)..quadraticBezierTo(50, 110, 22, 106)..close();
        _ribBand(c, hem);
        c.drawPath(Path()..moveTo(22.3, 100.2)..quadraticBezierTo(50, 103.7, 77.7, 100.2), _ln(ac, 1.1));
        final cl = Path()..moveTo(5.8, 79.5)..lineTo(19.6, 84.2)..lineTo(20, 90)..lineTo(5, 85)..close();
        _ribBand(c, cl);
        _ribBand(c, _mirror(cl));
        c.drawPath(Path()..moveTo(5.9, 81.5)..lineTo(19.7, 86.2), _ln(ac, 1.0));
        c.drawPath(Path()..moveTo(94.1, 81.5)..lineTo(80.3, 86.2), _ln(ac, 1.0));
        // standing ribbed collar
        final col = Path()..moveTo(36.5, 15)..lineTo(40, 7.5)..quadraticBezierTo(50, 5.5, 60, 7.5)..lineTo(63.5, 15)..quadraticBezierTo(50, 28, 36.5, 15)..close();
        _ribBand(c, col);
        c.drawPath(Path()..moveTo(40.6, 9.6)..quadraticBezierTo(50, 7.6, 59.4, 9.6), _ln(ac, 1.1));
        // zip
        c.drawPath(Path()..moveTo(50, 25)..lineTo(50, 99), _ln(Colors.black.withValues(alpha: 0.35), 2.2));
        c.drawPath(_dash(Path()..moveTo(50, 25)..lineTo(50, 99), 0.7, 0.6), _ln(const Color(0xFFD6D6D6), 1.3));
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48.6, 24, 2.8, 6), const Radius.circular(1)), Paint()..color = const Color(0xFFBDBDBD));
        // welt pockets
        for (final p in [Path()..moveTo(31, 70)..lineTo(36, 88), Path()..moveTo(69, 70)..lineTo(64, 88)]) {
          c.drawPath(p, _ln(Colors.black.withValues(alpha: 0.38), 1.6));
          c.drawPath(p.shift(const Offset(0.9, 0)), _ln(Colors.white.withValues(alpha: 0.12), 0.8));
        }
        c.drawCircle(const Offset(63, 40), 3.6, Paint()..color = ac.withValues(alpha: 0.92));
        c.drawCircle(const Offset(63, 40), 3.6, _ln(Colors.black.withValues(alpha: 0.25), 0.5));
        _number(c, 'N', 63, 40, 5, shade(color, -0.1), Colors.transparent);
        c.drawPath(Path()..moveTo(15, 25)..lineTo(24, 50), _ln(Colors.black.withValues(alpha: 0.14), 0.7));
        break;
      case 'shirt':
        final lc = shade(color, _dark ? 0.1 : -0.07);
        final l = Path()..moveTo(40, 11.5)..lineTo(32.5, 22)..lineTo(39.5, 36)..lineTo(50, 28.5)..close();
        final r = _mirror(l);
        for (final p in [l, r]) {
          c.drawPath(p, Paint()..color = lc);
          c.drawPath(p, _ln(Colors.black.withValues(alpha: 0.26), 0.8));
          _stitchLine(c, p.shift(Offset(p == l ? 0.9 : -0.9, 0.9)));
        }
        c.drawPath(Path()..moveTo(41, 12)..quadraticBezierTo(50, 17, 59, 12), _ln(shade(color, -0.2).withValues(alpha: 0.7), 1.6));
        // placket + buttons
        c.drawPath(Path()..moveTo(50, 29)..lineTo(50, 106), _ln(Colors.black.withValues(alpha: 0.18), 0.9));
        c.drawPath(Path()..moveTo(53.2, 33)..lineTo(53.2, 106), _ln(_stitch, 0.45));
        c.drawPath(Path()..moveTo(46.8, 33)..lineTo(46.8, 106), _ln(_stitch, 0.45));
        final btn = _dark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFFF7F4EC);
        for (final y in const [40.0, 54.0, 68.0, 82.0, 96.0]) {
          c.drawCircle(Offset(50, y), 1.5, Paint()..color = btn);
          c.drawCircle(Offset(50, y), 1.5, _ln(Colors.black.withValues(alpha: 0.35), 0.4));
          c.drawCircle(Offset(49.5, y - 0.4), 0.22, Paint()..color = Colors.black.withValues(alpha: 0.5));
          c.drawCircle(Offset(50.5, y + 0.4), 0.22, Paint()..color = Colors.black.withValues(alpha: 0.5));
        }
        // chest pocket
        final pk = Path()..moveTo(28, 50)..lineTo(41, 50)..lineTo(41, 60)..lineTo(34.5, 63)..lineTo(28, 60)..close();
        c.drawPath(pk, _ln(Colors.black.withValues(alpha: 0.22), 0.8));
        _stitchLine(c, pk.shift(const Offset(0.7, 0.8)));
        // cuffs
        final cf = Path()..moveTo(5.8, 79.5)..lineTo(19.6, 84.2)..lineTo(20, 90)..lineTo(5, 85)..close();
        for (final p in [cf, _mirror(cf)]) {
          c.drawPath(p, Paint()..color = shade(color, _dark ? 0.04 : -0.04));
          c.drawPath(p, _ln(Colors.black.withValues(alpha: 0.24), 0.7));
        }
        c.drawCircle(const Offset(11.5, 85.5), 1.1, Paint()..color = btn);
        c.drawCircle(const Offset(88.5, 85.5), 1.1, Paint()..color = btn);
        c.drawPath(Path()..moveTo(15, 25)..lineTo(24, 50), _ln(Colors.black.withValues(alpha: 0.16), 0.7));
        _stitchLine(c, Path()..moveTo(23, 103)..quadraticBezierTo(50, 107, 77, 103));
        break;
    }
  }

  void _detailsBack(Canvas c) {
    final a = accent;
    final dk = isDark(color);
    final ink = dk ? Colors.white.withValues(alpha: 0.88) : Colors.black.withValues(alpha: 0.75);
    // neck: shallow back neckline with a rib band and a woven label
    c.drawPath(Path()..moveTo(39, 13)..quadraticBezierTo(50, 17.5, 61, 13), _ln(garment == 'jacket' || garment == 'hoodie' ? _rib : _rib, 2.6));
    c.drawRect(const Rect.fromLTWH(47, 17.5, 6, 3.2), Paint()..color = Colors.white.withValues(alpha: 0.78));
    c.drawPath(Path()..moveTo(15, 25)..quadraticBezierTo(21, 38, 24, 47), _ln(Colors.black.withValues(alpha: 0.13), 0.7));
    c.drawPath(Path()..moveTo(85, 25)..quadraticBezierTo(79, 38, 76, 47), _ln(Colors.black.withValues(alpha: 0.13), 0.7));
    switch (garment) {
      case 'tee':
        _stitchLine(c, Path()..moveTo(2.8, 51)..lineTo(19.2, 58.2));
        _stitchLine(c, Path()..moveTo(97.2, 51)..lineTo(80.8, 58.2));
        _stitchLine(c, Path()..moveTo(23, 102)..quadraticBezierTo(50, 105.5, 77, 102));
        if (a != null) {
          _brand(c, 50, 36, 4.2, a);
          _number(c, 'N', 50, 62, 30, a, Colors.transparent);
        }
        break;
      case 'jersey':
        final ac = a ?? const Color(0xFF1E9E48);
        final left = Path()..moveTo(24, 47)..cubicTo(26, 70, 21, 92, 22, 105)..lineTo(31, 105.6)..cubicTo(30, 92, 34, 70, 31.5, 49)..close();
        c.drawPath(left, Paint()..color = ac);
        c.drawPath(_mirror(left), Paint()..color = ac);
        final sb = Path()..moveTo(2, 47)..lineTo(19, 55)..lineTo(18, 59.5)..lineTo(0.2, 51.5)..close();
        c.drawPath(sb, Paint()..color = ac);
        c.drawPath(_mirror(sb), Paint()..color = ac);
        c.drawPath(Path()..moveTo(39, 13)..quadraticBezierTo(50, 17.5, 61, 13), _ln(ac, 3.2));
        _brand(c, 50, 36, 4.2, ink);
        _number(c, '25', 50, 66, 34, ac, dk ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.55));
        _stitchLine(c, Path()..moveTo(32, 102)..quadraticBezierTo(50, 105.3, 68, 102));
        break;
      case 'hoodie':
        final hem = Path()..moveTo(22.2, 98.5)..quadraticBezierTo(50, 102, 77.8, 98.5)..lineTo(78, 106)..quadraticBezierTo(50, 110, 22, 106)..close();
        _ribBand(c, hem);
        final cl = Path()..moveTo(5.8, 79.5)..lineTo(19.6, 84.2)..lineTo(20, 90)..lineTo(5, 85)..close();
        _ribBand(c, cl);
        _ribBand(c, _mirror(cl));
        if (a != null) _brand(c, 50, 48, 4, a);
        c.drawPath(Path()..moveTo(50, 28)..lineTo(50, 98), _ln(Colors.black.withValues(alpha: 0.08), 0.8));
        break;
      case 'jacket':
        final ac = a ?? const Color(0xFFEFE6D2);
        final hem = Path()..moveTo(22.2, 98.5)..quadraticBezierTo(50, 102, 77.8, 98.5)..lineTo(78, 106)..quadraticBezierTo(50, 110, 22, 106)..close();
        _ribBand(c, hem);
        c.drawPath(Path()..moveTo(22.3, 100.2)..quadraticBezierTo(50, 103.7, 77.7, 100.2), _ln(ac, 1.1));
        final cl = Path()..moveTo(5.8, 79.5)..lineTo(19.6, 84.2)..lineTo(20, 90)..lineTo(5, 85)..close();
        _ribBand(c, cl);
        _ribBand(c, _mirror(cl));
        c.drawPath(Path()..moveTo(50, 19)..lineTo(50, 99), _ln(Colors.black.withValues(alpha: 0.16), 0.9));
        _stitchLine(c, Path()..moveTo(51.4, 19)..lineTo(51.4, 99));
        _brand(c, 50, 46, 4.4, ac);
        c.drawCircle(const Offset(50, 63), 6, _ln(ac.withValues(alpha: 0.9), 1.1));
        _number(c, 'N', 50, 63, 8, ac, Colors.transparent);
        break;
      case 'shirt':
        c.drawPath(Path()..moveTo(23, 32)..quadraticBezierTo(50, 38, 77, 32), _ln(Colors.black.withValues(alpha: 0.2), 0.8)); // yoke seam
        _stitchLine(c, Path()..moveTo(23, 33.6)..quadraticBezierTo(50, 39.6, 77, 33.6));
        c.drawPath(Path()..moveTo(50, 37)..lineTo(50, 105), _ln(Colors.black.withValues(alpha: 0.1), 3));
        final cf = Path()..moveTo(5.8, 79.5)..lineTo(19.6, 84.2)..lineTo(20, 90)..lineTo(5, 85)..close();
        for (final p in [cf, _mirror(cf)]) {
          c.drawPath(p, Paint()..color = shade(color, dk ? 0.04 : -0.04));
          c.drawPath(p, _ln(Colors.black.withValues(alpha: 0.24), 0.7));
        }
        _stitchLine(c, Path()..moveTo(23, 103)..quadraticBezierTo(50, 107, 77, 103));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant GarmentPainter o) =>
      o.garment != garment || o.color != color || o.accent != accent || o.swing != swing || o.shadow != shadow || o.hangerOnly != hangerOnly || o.hanger != hanger || o.back != back;
}

/// Painted garments are rasterised once (per garment/colour/size) and then only rotated, which keeps swiping smooth.
class _RasterCache {
  static final Map<String, ui.Image> _m = {};
  static final Set<String> _busy = {};
  static ui.Image? get(String k) {
    final v = _m.remove(k);
    if (v != null) _m[k] = v; // LRU touch
    return v;
  }

  static Future<ui.Image?> make(String k, GarmentPainter p, Size px) async {
    if (!_busy.add(k)) return null;
    try {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      p.paint(c, px);
      final img = await rec.endRecording().toImage(px.width.ceil(), px.height.ceil());
      _m[k] = img;
      while (_m.length > 48) {
        _m.remove(_m.keys.first);
      }
      return img;
    } finally {
      _busy.remove(k);
    }
  }
}

/// A garment (painted, or a real product photo when [imageUrl] is set) hanging from its hook.
class GarmentView extends StatefulWidget {
  final String garment;
  final Color color;
  final Color? accent;
  final String? imageUrl;
  final double swing;
  final double width;
  final bool shadow, hanger, back;
  const GarmentView({required this.garment, required this.color, this.accent, this.imageUrl, this.swing = 0, required this.width, this.shadow = true, this.hanger = true, this.back = false});
  @override
  State<GarmentView> createState() => _GarmentViewState();
}

class _GarmentViewState extends State<GarmentView> {
  String? _asked;

  String _key(double dpr) =>
      '${widget.garment}|${widget.color.hashCode}|${widget.accent?.hashCode}|${(widget.width * dpr).round()}|${widget.shadow}|${widget.hanger}|${widget.back}';

  GarmentPainter _painter() => GarmentPainter(garment: widget.garment, color: widget.color, accent: widget.accent, shadow: widget.shadow, hanger: widget.hanger, back: widget.back);

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * GarmentPainter.H / GarmentPainter.W;
    final hasPhoto = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    if (hasPhoto) {
      return SizedBox(
        width: w,
        height: h,
        child: Transform.rotate(
          angle: widget.swing,
          alignment: const Alignment(0, -1),
          child: Stack(children: [
            Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: GarmentPainter(garment: widget.garment, color: widget.color, hangerOnly: true)))),
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.09,
              bottom: 0,
              child: Image.network(
                widget.imageUrl!,
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                // multiplying by the page colour makes a white photo background disappear
                color: C.bg,
                colorBlendMode: BlendMode.multiply,
                errorBuilder: (_, __, ___) => CustomPaint(painter: _painter()),
              ),
            ),
          ]),
        ),
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final k = _key(dpr);
    final img = _RasterCache.get(k);
    Widget body;
    if (img != null) {
      body = RawImage(image: img, scale: dpr, width: w, height: h, fit: BoxFit.fill, filterQuality: FilterQuality.high);
    } else {
      body = CustomPaint(size: Size(w, h), painter: _painter());
      if (_asked != k) {
        _asked = k;
        _RasterCache.make(k, _painter(), Size(w * dpr, h * dpr)).then((_) {
          if (mounted && _asked == k) setState(() {});
        });
      }
    }
    return SizedBox(
      width: w,
      height: h,
      child: Transform.rotate(angle: widget.swing, alignment: const Alignment(0, -0.94), child: body),
    );
  }
}
