import 'package:flutter/material.dart';

const kGold = Color(0xFFF0B90B);
const kGreen = Color(0xFF0ECB81);
const kRed = Color(0xFFF6465D);
const kBg = Color(0xFF0B0E11);
const kSurface = Color(0xFF1E2329);
const kSurface2 = Color(0xFF2B3139);
const kMuted = Color(0xFF848E9C);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kGold,
      secondary: kGreen,
      error: kRed,
      surface: kSurface,
      onPrimary: Colors.black,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: kSurface, elevation: 0),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: kSurface),
  );
}
