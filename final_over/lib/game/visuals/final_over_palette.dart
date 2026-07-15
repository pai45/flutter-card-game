import 'package:flutter/material.dart';

/// The clean-room colour system used by every Final Over visual component.
///
/// Keeping the palette in one place makes the Canvas artwork predictable in
/// golden tests and lets the presentation layer theme surrounding widgets
/// without depending on game-domain types.
abstract final class FinalOverPalette {
  static const Color navy = Color(0xFF0D111A);
  static const Color navyRaised = Color(0xFF151D2B);
  static const Color cyan = Color(0xFF5CDFFF);
  static const Color cyanDeep = Color(0xFF168EBD);
  static const Color deepBlue = Color(0xFF00285E);
  static const Color royalBlue = Color(0xFF1558C9);
  static const Color green = Color(0xFF45D61F);
  static const Color fieldDark = Color(0xFF166A32);
  static const Color fieldLight = Color(0xFF238946);
  static const Color yellow = Color(0xFFFFC400);
  static const Color orange = Color(0xFFFF7A18);
  static const Color red = Color(0xFFE62D2D);
  static const Color white = Color(0xFFF5F7FA);
  static const Color pitchBrown = Color(0xFFB88A4A);
  static const Color pitchLight = Color(0xFFD7B26E);
  static const Color charcoal = Color(0xFF303845);
  static const Color black = Color(0xFF05070B);

  static Color timingColorForMagnitude(double milliseconds) {
    final magnitude = milliseconds.abs();
    if (magnitude <= 50) return cyan;
    if (magnitude <= 115) return green;
    if (magnitude <= 190) return yellow;
    if (magnitude <= 275) return orange;
    return red;
  }
}

/// Shared geometry constants for code-native artwork.
abstract final class FinalOverVisualTokens {
  static const double thinStroke = 1.5;
  static const double regularStroke = 2.5;
  static const double heavyStroke = 5;
  static const double cornerRadius = 18;
}

double visualClamp01(double value) => value.clamp(0.0, 1.0).toDouble();
