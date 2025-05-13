// theme.dart
import 'package:flutter/material.dart';

/// オレンジ = アクセントカラー、紺色 = ベースカラー

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF0D1B2A), // 紺色
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0D1B2A),
    foregroundColor: Colors.white,
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF0D1B2A), // 紺色
    secondary: Color(0xFFFF6F00), // オレンジ
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color.fromARGB(222, 255, 111, 0),
    foregroundColor: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black87),
    titleLarge: TextStyle(fontWeight: FontWeight.bold),
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF0D1B2A), // 紺色
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0D1B2A),
    foregroundColor: Colors.white,
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF0D1B2A), // 紺色
    secondary: Color(0xFFFFA726), // 明るめのオレンジ
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFFFFA726),
    foregroundColor: Colors.black,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white70),
    titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
  ),
);
