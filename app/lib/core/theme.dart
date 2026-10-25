import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const bg = Color(0xFFF6F0EA); // warm cream
  static const ink = Color(0xFF1B1315); // warm near-black
  static const neon = Color(0xFF6E2A35); // muted burgundy (brand accent)
  static const onNeon = Color(0xFFF7EEE8); // text/icons on the accent
  static const tint = Color(0xFFE9D3D3); // pale rose for selected chips / highlights
  static const mute = Color(0xFF8A7F7B);
  static const line = Color(0xFFDDD2CB);
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
      onSecondary: C.onNeon,
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
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: C.bg, indicatorColor: C.tint),
    dividerColor: C.line,
    chipTheme: ChipThemeData(selectedColor: C.tint, secondarySelectedColor: C.tint, checkmarkColor: C.ink),
  );
}
