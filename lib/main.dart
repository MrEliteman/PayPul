import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_page.dart';

void main() => runApp(const MoiTratyApp());

class MoiTratyApp extends StatelessWidget {
  const MoiTratyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      title: 'Мои траты',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF1B1C1E),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme),
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: const Color(0xFF7C9885),
        ),
      ),
      home: const HomePage(),
    );
  }
}
