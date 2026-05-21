import 'package:flutter/material.dart';

class Cyber {
  // Surfaces - premium dark esports palette.
  static const bg = Color(0xff0d111a); // --bg-deep
  static const bg2 = Color(0xff0a0e1a);
  static const card = Color(0xff111827); // --bg-card
  static const panel = Color(0xff161d2e); // --bg-panel
  static const panel2 = Color(0xff131b2e);

  // Accents.
  static const cyan = Color(0xff5cdfff); // --accent
  static const accentGlow = Color(0x405cdfff); // rgba(92,223,255,0.25)
  static const magenta = Color(0xffff3df7);
  static const lime = Color(0xffb6ff3d);
  static const amber = Color(0xffffb13d);
  static const gold = Color(0xffffd166); // --gold (ratings, scores)
  static const danger = Color(0xffff4c4c); // --danger (red cards, fouls)
  static const success = Color(0xff00e699); // --success (goals, wins)
  static const red = Color(0xffff2e63);
  static const violet = Color(0xff8a5cff);

  // Borders.
  static const line = Color(0x665cdfff);
  static const borderSubtle = Color(0x0fffffff); // rgba(255,255,255,0.06)
  static const borderActive = Color(0x665cdfff); // rgba(92,223,255,0.4)
  static const muted = Color(0xff8fa3b8);

  // Typography families. Orbitron is the bundled condensed display face
  // standing in for "Bebas Neue"; Onest stands in for "DM Sans".
  static const displayFont = 'Orbitron';
  static const bodyFont = 'Onest';

  static LinearGradient panelGradient([Color? glow]) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [(glow ?? cyan).withValues(alpha: 0.16), panel, panel2],
    stops: const [0, 0.42, 1],
  );

  // Display type scale (Bebas-Neue-style). 48 match-end, 36 outcome,
  // 24 phase titles, 18 card names.
  static TextStyle display(
    double size, {
    Color color = Colors.white,
    double letterSpacing = 1.5,
    FontWeight weight = FontWeight.w900,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: 1,
    decoration: TextDecoration.none,
  );

  static TextStyle body(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
    double height = 1.35,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: bodyFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );

  static TextStyle label(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = 0.9,
    double height = 1,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );

  static TextTheme buildTextTheme(TextTheme base) {
    final themed = base.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
      fontFamily: bodyFont,
    );

    TextStyle useBody(
      TextStyle? style, {
      FontWeight? weight,
      double? letterSpacing,
      double? height,
    }) => (style ?? const TextStyle()).copyWith(
      color: Colors.white,
      fontFamily: bodyFont,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
    );

    TextStyle useDisplay(
      TextStyle? style, {
      FontWeight weight = FontWeight.w900,
      double? letterSpacing,
      double height = 1,
    }) => (style ?? const TextStyle()).copyWith(
      color: Colors.white,
      fontFamily: displayFont,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
    );

    return themed.copyWith(
      displayLarge: useDisplay(themed.displayLarge, letterSpacing: 1.2),
      displayMedium: useDisplay(themed.displayMedium, letterSpacing: 1.2),
      displaySmall: useDisplay(themed.displaySmall, letterSpacing: 1.15),
      headlineLarge: useDisplay(themed.headlineLarge, letterSpacing: 1.1),
      headlineMedium: useDisplay(themed.headlineMedium, letterSpacing: 1.05),
      headlineSmall: useDisplay(themed.headlineSmall, letterSpacing: 1),
      titleLarge: useDisplay(
        themed.titleLarge,
        weight: FontWeight.w800,
        letterSpacing: 0.9,
      ),
      titleMedium: useDisplay(
        themed.titleMedium,
        weight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
      titleSmall: useDisplay(
        themed.titleSmall,
        weight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
      bodyLarge: useBody(
        themed.bodyLarge,
        weight: FontWeight.w500,
        height: 1.4,
      ),
      bodyMedium: useBody(
        themed.bodyMedium,
        weight: FontWeight.w500,
        height: 1.4,
      ),
      bodySmall: useBody(
        themed.bodySmall,
        weight: FontWeight.w500,
        height: 1.35,
      ),
      labelLarge: useDisplay(
        themed.labelLarge,
        weight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
      labelMedium: useDisplay(
        themed.labelMedium,
        weight: FontWeight.w800,
        letterSpacing: 0.75,
      ),
      labelSmall: useDisplay(
        themed.labelSmall,
        weight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    );
  }
}
