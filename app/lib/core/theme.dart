import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A selectable colour scheme. The owner picks one in the dashboard and everyone gets it.
class Pal {
  final String key, ar, en;
  final Color bg, ink, neon, onNeon, tint, mute, line, card;
  const Pal(this.key, this.ar, this.en, this.bg, this.ink, this.neon, this.onNeon, this.tint, this.mute, this.line, this.card);
}

const kPalettes = [
  Pal('burgundy', 'بورجندي مطفي', 'Muted burgundy', Color(0xFFEBDAD7), Color(0xFF1B1315), Color(0xFF6E2A35), Color(0xFFF7EEE8), Color(0xFFDDBFBF), Color(0xFF86696C), Color(0xFFD4BCBA), Color(0xFFF6ECEA)),
  Pal('olive', 'زيتوني غامق', 'Deep olive', Color(0xFFDDE0D2), Color(0xFF15190F), Color(0xFF3F4A2B), Color(0xFFF2F3E8), Color(0xFFC5CBB0), Color(0xFF6B7259), Color(0xFFBFC5AE), Color(0xFFEDEFE3)),
  Pal('navy', 'كحلي ورملي', 'Navy & sand', Color(0xFFE6DFD2), Color(0xFF101828), Color(0xFF1F2F55), Color(0xFFF4EFE6), Color(0xFFCBC3AE), Color(0xFF6F6A5C), Color(0xFFD2C9B4), Color(0xFFF1EBDF)),
  Pal('plum', 'موف داكن', 'Deep plum', Color(0xFFE4D9E3), Color(0xFF1D1220), Color(0xFF5A2A64), Color(0xFFF6EEF7), Color(0xFFD3BFD6), Color(0xFF7E6A82), Color(0xFFCDBBD0), Color(0xFFF2EAF3)),
  Pal('terracotta', 'تراكوتا', 'Terracotta', Color(0xFFEAD9CC), Color(0xFF201813), Color(0xFFB5532F), Color(0xFFFBF1E9), Color(0xFFE3C2AE), Color(0xFF8A6C5C), Color(0xFFD8BDAA), Color(0xFFF5E8DE)),
];

class C {
  static Color bg = const Color(0xFFEBDAD7);
  static Color ink = const Color(0xFF1B1315);
  static Color neon = const Color(0xFF6E2A35); // brand accent
  static Color onNeon = const Color(0xFFF7EEE8);
  static Color tint = const Color(0xFFDDBFBF);
  static Color mute = const Color(0xFF86696C);
  static Color line = const Color(0xFFD4BCBA);
  static Color card = const Color(0xFFF6ECEA);
  static const danger = Color(0xFFD92D20);
  static const ok = Color(0xFF12B76A);
  static const warn = Color(0xFFF79009);

  static String current = 'burgundy';
  static void apply(String key) {
    final p = kPalettes.firstWhere((e) => e.key == key, orElse: () => kPalettes.first);
    current = p.key;
    bg = p.bg;
    ink = p.ink;
    neon = p.neon;
    onNeon = p.onNeon;
    tint = p.tint;
    mute = p.mute;
    line = p.line;
    card = p.card;
  }
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
  final text = (ar ? GoogleFonts.tajawalTextTheme(base.textTheme) : GoogleFonts.poppinsTextTheme(base.textTheme))
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
    inputDecorationTheme: InputDecorationTheme(
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
    navigationBarTheme: NavigationBarThemeData(backgroundColor: C.bg, indicatorColor: C.tint),
    dividerColor: C.line,
    chipTheme: ChipThemeData(selectedColor: C.tint, secondarySelectedColor: C.tint, checkmarkColor: C.ink),
  );
}
