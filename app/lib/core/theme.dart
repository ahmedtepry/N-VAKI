import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const bg = Color(0xFFF4F3EE);
  static const ink = Color(0xFF0E0E0E);
  static const neon = Color(0xFF39FF14);
  static const mute = Color(0xFF8B8A84);
  static const line = Color(0xFFDAD8D0);
  static const card = Color(0xFFFFFFFF);
  static const danger = Color(0xFFD92D20);
  static const ok = Color(0xFF12B76A);
  static const warn = Color(0xFFF79009);
}

ThemeData buildTheme(bool ar) {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: C.neon).copyWith(
      primary: C.ink,
      onPrimary: Colors.white,
      secondary: C.neon,
      onSecondary: C.ink,
      surface: C.bg,
      onSurface: C.ink,
      error: C.danger,
    ),
    splashFactory: InkRipple.splashFactory,
  );
  final text = (ar ? GoogleFonts.tajawalTextTheme(base.textTheme) : GoogleFonts.spaceGroteskTextTheme(base.textTheme))
      .apply(bodyColor: C.ink, displayColor: C.ink);
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: C.ink),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: UnderlineInputBorder(borderSide: BorderSide(color: C.line)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: C.line)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: C.ink, width: 1.4)),
      labelStyle: TextStyle(color: C.mute),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: C.bg, indicatorColor: C.neon),
    dividerColor: C.line,
  );
}
