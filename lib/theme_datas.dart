import 'package:flutter/material.dart';

class HealthAppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,

    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00BFA6),
      secondary: Color(0xFF4DD0E1),
      surface: Color(0xFFFFFFFF),
      error: Color(0xFFE53935),
    ),

    scaffoldBackgroundColor: const Color(0xFFF6FBFA),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Color(0xFF1E2D2F),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Color(0xFF1E2D2F),
      ),
    ),

    cardTheme: const CardThemeData(
      color: Color(0xFFE8F7F4),
      elevation: 6,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF1E2D2F)),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF1E2D2F)),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1E2D2F)),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1E2D2F)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF6C8A8F)),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF00BFA6),
      foregroundColor: Colors.white,
      elevation: 6,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Color(0xFF9DB9B5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00E5C3),
      secondary: Color(0xFF26C6DA),
      surface: Color(0xFF142B2F),
      error: Color(0xFFEF5350),
    ),

    scaffoldBackgroundColor: const Color(0xFF0E1C1F),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Color(0xFFE6F7F6),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Color(0xFFE6F7F6),
      ),
    ),

    cardTheme: const CardThemeData(
      color: Color(0xFF1C3A3F),
      elevation: 6,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFFE6F7F6)),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFFE6F7F6)),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFE6F7F6)),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFE6F7F6)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF9EC9C5)),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00E5C3),
        foregroundColor: Colors.black,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF00E5C3),
      foregroundColor: Colors.black,
      elevation: 6,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF142B2F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Color(0xFF9EC9C5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
  );
}
