import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // Presentation mode theme (large fonts)
  static ThemeData get presentationTheme {
    return lightTheme.copyWith(
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(fontSize: 40),
        headlineMedium: TextStyle(fontSize: 32),
        titleLarge: TextStyle(fontSize: 28),
        bodyLarge: TextStyle(fontSize: 24),
        bodyMedium: TextStyle(fontSize: 20),
      ),
    );
  }
}
