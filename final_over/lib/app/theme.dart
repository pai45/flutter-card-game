import 'package:flutter/material.dart';

abstract final class FinalOverPalette {
  static const night = Color(0xFF0D111A);
  static const cyan = Color(0xFF5CDFFF);
  static const deepBlue = Color(0xFF00285E);
  static const green = Color(0xFF45D61F);
  static const yellow = Color(0xFFFFC400);
  static const red = Color(0xFFE62D2D);
  static const white = Color(0xFFF5F7FA);
  static const muted = Color(0xFF9FB0C4);
  static const pitch = Color(0xFFB88A4A);
  static const orange = Color(0xFFFF8A1F);
}

ThemeData buildFinalOverTheme({String? assetPackage}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: FinalOverPalette.cyan,
    brightness: Brightness.dark,
    surface: FinalOverPalette.night,
    error: FinalOverPalette.red,
  );
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: assetPackage == null
        ? 'FinalOverCondensed'
        : 'packages/$assetPackage/FinalOverCondensed',
    colorScheme: scheme,
    scaffoldBackgroundColor: FinalOverPalette.night,
    textTheme:
        const TextTheme(
          displayLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
            height: .92,
          ),
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
          titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .7),
          bodyLarge: TextStyle(fontWeight: FontWeight.w600, height: 1.35),
          labelLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ).apply(
          bodyColor: FinalOverPalette.white,
          displayColor: FinalOverPalette.white,
        ),
    dialogTheme: DialogThemeData(
      backgroundColor: FinalOverPalette.night.withValues(alpha: .98),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: FinalOverPalette.cyan, width: 1.2),
        borderRadius: BorderRadius.circular(18),
      ),
    ),
  );
}

BoxDecoration arcadePanel({Color? color, double radius = 16}) {
  return BoxDecoration(
    color: color ?? FinalOverPalette.night.withValues(alpha: .88),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: FinalOverPalette.cyan.withValues(alpha: .72)),
    boxShadow: [
      BoxShadow(
        color: FinalOverPalette.cyan.withValues(alpha: .12),
        blurRadius: 20,
      ),
    ],
  );
}
