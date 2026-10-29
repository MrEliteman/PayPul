import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(WhereIsMyMoneyApp(store: AppStore(prefs)));
}

class WhereIsMyMoneyApp extends StatelessWidget {
  const WhereIsMyMoneyApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    const black = Colors.black;
    const white = Colors.white;
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: black),
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: black,
        onPrimary: white,
        secondary: black,
        onSecondary: white,
        surface: white,
        onSurface: black,
        error: black,
      ),
      scaffoldBackgroundColor: white,
      dividerColor: black,
      dividerTheme: const DividerThemeData(color: Colors.black12, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 0,
        shape: RoundedRectangleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: black,
          foregroundColor: white,
          shape: const RoundedRectangleBorder(),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: black, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: black, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: black, width: 2),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(side: BorderSide(color: black)),
        backgroundColor: white,
        selectedColor: black,
        labelStyle: TextStyle(color: black),
        secondaryLabelStyle: TextStyle(color: white),
        checkmarkColor: white,
        showCheckmark: false,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: white,
        shape: RoundedRectangleBorder(side: BorderSide(color: black)),
      ),
    );

    return MaterialApp(
      title: 'Where Is My Money',
      debugShowCheckedModeBanner: false,
      theme: theme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ru')],
      home: HomeScreen(store: store),
    );
  }
}
