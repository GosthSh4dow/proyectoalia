import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color principal para la aplicación
  static const Color primaryColor = Color(0xFFF500A2);  // Fucsia
  static const Color secondaryColor = Color(0xFFFF80FF);  // Rosa claro
  
  static ThemeData lightTheme = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      background: Colors.white,
      surface: Color(0xFFF2F2F2),  // Color para tarjetas y superficies
      onPrimary: Colors.white,  // Texto sobre botones primarios
      onSecondary: Colors.black,
      onBackground: Colors.black,
      onSurface: Colors.black,
    ),
    textTheme: _lightTextTheme,
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: Color(0xFF800080),
      background: Color(0xFF121212),
      surface: Color(0xFF1E1E1E),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: Colors.white,
      onSurface: Colors.white,
    ),
    textTheme: _darkTextTheme,
    cardTheme: const CardThemeData(
      color: Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // TextTheme para el modo claro
  static final TextTheme _lightTextTheme = GoogleFonts.interTextTheme().copyWith(
    headlineSmall: const TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold),
    bodyMedium: const TextStyle(color: Color(0xFF333333), fontSize: 16),
  );

  // TextTheme para el modo oscuro
  static final TextTheme _darkTextTheme = GoogleFonts.interTextTheme().copyWith(
    headlineSmall: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    bodyMedium: const TextStyle(color: Colors.white70, fontSize: 16),
  );
}
