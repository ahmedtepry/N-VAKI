import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import 'auth.dart';
import 'home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen();
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final started = DateTime.now();
    if (App.i.user != null) await App.i.loadProfile();
    final left = 1600 - DateTime.now().difference(started).inMilliseconds;
    if (left > 0) await Future.delayed(Duration(milliseconds: left));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(App.i.user != null ? const HomeScreen() : const AuthScreen()));
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.neon,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 120, height: 2, color: C.ink),
          AnimatedBuilder(
            animation: c,
            builder: (_, __) => GarmentView(
              garment: 'tee',
              color: C.ink,
              accent: C.neon,
              width: 96,
              swing: (c.value - 0.5) * 0.22,
              shadow: false,
            ),
          ),
          const SizedBox(height: 18),
          const Wordmark(size: 30),
        ]),
      ),
    );
  }
}
