import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/models.dart';

/// Draws a garment hanging on a hanger, in vector. The colour/accent come from the product variant.
class GarmentPainter extends CustomPainter {
  final String garment;
  final Color color;
  final Color? accent;
  final double swing; // radians, rotates around the hook
  final bool shadow;
  GarmentPainter({required this.garment, required this.color, this.accent, this.swing = 0, this.shadow = true});

  static const double W = 100, H = 118;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / W, size.height / H);
    canvas.save();
    canvas.translate((size.width - W * s) / 2, 0);
    canvas.scale(s);
    canvas.translate(50, 4);
    canvas.rotate(swing);
    canvas.translate(-50, -4);

    final body = _body();
    if (shadow) {
      canvas.save();
      canvas.translate(-5, 5);
      canvas.drawPath(body, Paint()..color = Colors.black.withValues(alpha: 0.13)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5));
      canvas.restore();
    }
    _hanger(canvas);
    if (garment == 'hoodie') _hood(canvas);

    canvas.drawPath(body, Paint()..color = color);
    // fabric shading
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white.withValues(alpha: 0.12), Colors.transparent, Colors.black.withValues(alpha: 0.16)],
          stops: const [0, 0.5, 1],
        ).createShader(const Rect.fromLTWH(0, 0, W, H)),
    );
    _details(canvas, body);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.restore();
  }

  Path _body() {
    final p = Path();
    switch (garment) {
      case 'hoodie':
      case 'jacket':
        p
          ..moveTo(40, 14)
          ..lineTo(14, 25)
          ..lineTo(6, 78)
          ..lineTo(20, 82)
          ..lineTo(24, 48)
          ..lineTo(23, 104)
          ..lineTo(77, 104)
          ..lineTo(76, 48)
          ..lineTo(80, 82)
          ..lineTo(94, 78)
          ..lineTo(86, 25)
          ..lineTo(60, 14)
          ..quadraticBezierTo(50, 24, 40, 14)
          ..close();
        break;
      case 'shirt':
        p
          ..moveTo(40, 13)
          ..lineTo(15, 25)
          ..lineTo(8, 80)
          ..lineTo(21, 83)
          ..lineTo(25, 47)
          ..lineTo(24, 106)
          ..lineTo(76, 106)
          ..lineTo(75, 47)
          ..lineTo(79, 83)
          ..lineTo(92, 80)
          ..lineTo(85, 25)
          ..lineTo(60, 13)
          ..lineTo(50, 22)
          ..close();
        break;
      case 'jersey':
        p
          ..moveTo(38, 14)
          ..lineTo(14, 25)
          ..lineTo(3, 46)
          ..lineTo(19, 53)
          ..lineTo(24, 44)
          ..lineTo(23, 106)
          ..lineTo(77, 106)
          ..lineTo(76, 44)
          ..lineTo(81, 53)
          ..lineTo(97, 46)
          ..lineTo(86, 25)
          ..lineTo(62, 14)
          ..lineTo(50, 33)
          ..close();
        break;
      default: // tee
        p
          ..moveTo(38, 14)
          ..lineTo(14, 25)
          ..lineTo(3, 46)
          ..lineTo(19, 53)
          ..lineTo(24, 44)
          ..lineTo(23, 106)
          ..lineTo(77, 106)
          ..lineTo(76, 44)
          ..lineTo(81, 53)
          ..lineTo(97, 46)
          ..lineTo(86, 25)
          ..lineTo(62, 14)
          ..quadraticBezierTo(50, 28, 38, 14)
          ..close();
    }
    return p;
  }

  void _hanger(Canvas canvas) {
    final hp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF6E6B65);
    final hook = Path()
      ..moveTo(50, 12)
      ..lineTo(50, 7)
      ..quadraticBezierTo(50, 3, 54, 3)
      ..quadraticBezierTo(58, 3, 58, 6.5);
    canvas.drawPath(hook, hp);
    final arms = Path()
      ..moveTo(15, 26)
      ..lineTo(50, 11)
      ..lineTo(85, 26);
    canvas.drawPath(arms, hp..strokeWidth = 1.6);
  }

  void _hood(Canvas canvas) {
    final hood = Path()
      ..moveTo(35, 17)
      ..cubicTo(28, 0, 72, 0, 65, 17)
      ..quadraticBezierTo(50, 34, 35, 17)
      ..close();
    canvas.drawPath(hood, Paint()..color = shade(color, -0.06));
    canvas.drawPath(hood, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.7..color = Colors.black.withValues(alpha: 0.18));
    // hood opening
    final inner = Path()
      ..moveTo(40, 14)
      ..quadraticBezierTo(50, 24, 60, 14)
      ..quadraticBezierTo(50, 8, 40, 14)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.black.withValues(alpha: 0.35));
  }

  Paint _line(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = c;

  void _details(Canvas canvas, Path body) {
    final fold = _line(Colors.black.withValues(alpha: 0.07), 1.4);
    final light = _line(Colors.white.withValues(alpha: 0.10), 1.2);
    canvas.drawPath(Path()..moveTo(33, 52)..quadraticBezierTo(37, 78, 32, 102), fold);
    canvas.drawPath(Path()..moveTo(66, 56)..quadraticBezierTo(62, 80, 68, 103), fold);
    canvas.drawPath(Path()..moveTo(45, 48)..quadraticBezierTo(48, 74, 44, 100), light);
    final rib = shade(color, isDark(color) ? 0.10 : -0.14);
    final a = accent;

    switch (garment) {
      case 'tee':
        canvas.drawPath(Path()..moveTo(38, 14)..quadraticBezierTo(50, 28, 62, 14), _line(rib, 2.6));
        canvas.drawPath(Path()..moveTo(3, 46)..lineTo(19, 53), _line(rib, 1.6));
        canvas.drawPath(Path()..moveTo(97, 46)..lineTo(81, 53), _line(rib, 1.6));
        // small back-print style mark on the chest
        _text(canvas, a != null ? 'N' : '', 50, 62, 15, a ?? Colors.transparent);
        break;
      case 'jersey':
        final ac = a ?? const Color(0xFF1E9E48);
        // side panels
        canvas.drawPath(Path()..moveTo(24, 46)..lineTo(23, 106)..lineTo(31, 106)..lineTo(30, 49)..close(), Paint()..color = ac);
        canvas.drawPath(Path()..moveTo(76, 46)..lineTo(77, 106)..lineTo(69, 106)..lineTo(70, 49)..close(), Paint()..color = ac);
        // V-neck + sleeve trim
        canvas.drawPath(Path()..moveTo(38, 14)..lineTo(50, 33)..lineTo(62, 14), _line(ac, 2.6));
        canvas.drawPath(Path()..moveTo(3, 46)..lineTo(19, 53), _line(ac, 3.4));
        canvas.drawPath(Path()..moveTo(97, 46)..lineTo(81, 53), _line(ac, 3.4));
        // chest stripes
        canvas.drawPath(Path()..moveTo(31, 66)..lineTo(69, 66), _line(ac.withValues(alpha: 0.55), 1.2));
        canvas.drawPath(Path()..moveTo(31, 70)..lineTo(69, 70), _line(ac.withValues(alpha: 0.35), 1.2));
        _text(canvas, '25', 50, 84, 17, ac);
        break;
      case 'hoodie':
        // hem rib + cuffs
        canvas.drawPath(Path()..moveTo(23, 99)..lineTo(77, 99), _line(rib, 1.2));
        canvas.drawRect(const Rect.fromLTWH(23, 99, 54, 5), Paint()..color = rib.withValues(alpha: 0.55));
        canvas.drawPath(Path()..moveTo(8, 72)..lineTo(22, 76), _line(rib, 1.4));
        canvas.drawPath(Path()..moveTo(92, 72)..lineTo(78, 76), _line(rib, 1.4));
        // kangaroo pocket
        canvas.drawPath(Path()..moveTo(31, 72)..lineTo(36, 92)..lineTo(64, 92)..lineTo(69, 72), _line(Colors.black.withValues(alpha: 0.2), 1));
        // drawstrings
        final cord = Colors.white.withValues(alpha: 0.85);
        canvas.drawPath(Path()..moveTo(45, 24)..lineTo(44, 46), _line(cord, 1.1));
        canvas.drawPath(Path()..moveTo(55, 24)..lineTo(56, 46), _line(cord, 1.1));
        break;
      case 'jacket':
        final ac = a ?? const Color(0xFFEFE6D2);
        canvas.drawRect(const Rect.fromLTWH(23, 99, 54, 5), Paint()..color = rib.withValues(alpha: 0.7));
        canvas.drawPath(Path()..moveTo(23, 99)..lineTo(77, 99), _line(ac, 1.3));
        canvas.drawPath(Path()..moveTo(8, 72)..lineTo(22, 76), _line(ac, 1.6));
        canvas.drawPath(Path()..moveTo(92, 72)..lineTo(78, 76), _line(ac, 1.6));
        // collar
        final collar = Path()
          ..moveTo(38, 14)
          ..lineTo(42, 8)
          ..lineTo(58, 8)
          ..lineTo(62, 14)
          ..quadraticBezierTo(50, 26, 38, 14)
          ..close();
        canvas.drawPath(collar, Paint()..color = rib.withValues(alpha: 0.9));
        canvas.drawPath(Path()..moveTo(41, 10)..lineTo(59, 10), _line(ac, 1.2));
        // zip
        canvas.drawPath(Path()..moveTo(50, 22)..lineTo(50, 104), _line(const Color(0xFFBDBDBD), 1.4));
        canvas.drawCircle(const Offset(50, 30), 1.6, Paint()..color = const Color(0xFFE0E0E0));
        // chest pockets
        canvas.drawPath(Path()..moveTo(30, 66)..lineTo(40, 66), _line(Colors.black.withValues(alpha: 0.28), 1.1));
        canvas.drawPath(Path()..moveTo(60, 66)..lineTo(70, 66), _line(Colors.black.withValues(alpha: 0.28), 1.1));
        break;
      case 'shirt':
        final lc = shade(color, isDark(color) ? 0.12 : -0.08);
        final c1 = Path()..moveTo(40, 13)..lineTo(50, 31)..lineTo(33, 27)..close();
        final c2 = Path()..moveTo(60, 13)..lineTo(50, 31)..lineTo(67, 27)..close();
        canvas.drawPath(c1, Paint()..color = lc);
        canvas.drawPath(c2, Paint()..color = lc);
        final edge = _line(Colors.black.withValues(alpha: 0.2), 0.8);
        canvas.drawPath(c1, edge);
        canvas.drawPath(c2, edge);
        canvas.drawPath(Path()..moveTo(50, 31)..lineTo(50, 106), _line(Colors.black.withValues(alpha: 0.16), 0.9));
        final btn = Paint()..color = isDark(color) ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.35);
        for (final y in [40.0, 54.0, 68.0, 82.0, 96.0]) {
          canvas.drawCircle(Offset(50, y), 1.15, btn);
        }
        canvas.drawPath(Path()..moveTo(9, 74)..lineTo(22, 77), _line(Colors.black.withValues(alpha: 0.2), 1.2));
        canvas.drawPath(Path()..moveTo(91, 74)..lineTo(78, 77), _line(Colors.black.withValues(alpha: 0.2), 1.2));
        canvas.drawPath(Path()..moveTo(30, 50)..lineTo(40, 50)..lineTo(40, 60)..lineTo(30, 60)..close(), _line(Colors.black.withValues(alpha: 0.16), 0.8));
        break;
    }
  }

  void _text(Canvas canvas, String t, double cx, double cy, double size, Color c) {
    if (t.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: c, letterSpacing: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GarmentPainter o) =>
      o.garment != garment || o.color != color || o.accent != accent || o.swing != swing || o.shadow != shadow;
}

class GarmentView extends StatelessWidget {
  final String garment;
  final Color color;
  final Color? accent;
  final double swing;
  final double width;
  final bool shadow;
  const GarmentView({required this.garment, required this.color, this.accent, this.swing = 0, required this.width, this.shadow = true});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: width * GarmentPainter.H / GarmentPainter.W,
        child: CustomPaint(painter: GarmentPainter(garment: garment, color: color, accent: accent, swing: swing, shadow: shadow)),
      );
}
