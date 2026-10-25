import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app.dart';
import 'core/theme.dart';
import 'screens/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (kSupabaseUrl.isEmpty || kSupabaseKey.isEmpty) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Missing SUPABASE_URL / SUPABASE_ANON_KEY')))));
    return;
  }
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseKey, debug: false);
  await App.i.init(prefs);
  runApp(const NovakiApp());
}

final _themes = <String, ThemeData>{};

class NovakiApp extends StatelessWidget {
  const NovakiApp();
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.i,
      builder: (context, _) {
        final ar = App.i.ar;
        return MaterialApp(
          title: App.i.brand,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: messengerKey,
          locale: Locale(App.i.lang),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          theme: _themes.putIfAbsent('${C.current}-$ar', () => buildTheme(ar)),
          // a language switch rebuilds the whole tree so every tr() string refreshes
          builder: (context, child) => KeyedSubtree(key: ValueKey('${App.i.lang}-${C.current}-${App.i.brand}'), child: child ?? const SizedBox()),
          home: const SplashScreen(),
        );
      },
    );
  }
}
