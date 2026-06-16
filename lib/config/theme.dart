import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color blackColor = Color(0xFF000000);
  static const Color activeButtonColor = Color(0xFF2B7FFF);
  static const Color inactiveButtonTextColor = Color(0xFFA2F4FD);
  static const Color inactiveButtonColor = Color(0xFF1D293D);
  static const Color textFieldBorderColor = Color.fromRGBO(173, 70, 255, 0.302);
  static const Color textFieldFillColor = Color.fromRGBO(2, 6, 24, 0.8);
  static const Color backgroundColor = Color(0xFF162454);
  static const Color answerLetterBackgroundColor = Color.fromRGBO(
    49,
    65,
    88,
    1,
  );
  static const Color textMedium = Color.fromRGBO(144, 161, 185, 1);
  static const Color answerBackgroundColor = Color.fromRGBO(29, 41, 61, 1);
  static const Color answerBackgroundColorSelected = Color.fromRGBO(
    28,
    57,
    142,
    0.5,
  );
  static const Color answerTextColor = Color.fromRGBO(202, 213, 226, 1);
  static const Color dropShadowColor = Color.fromRGBO(0, 0, 0, 0.3);
  static const Color predictionCardBorderColor = Color.fromRGBO(
    255,
    255,
    255,
    0.2,
  );
  static const Color yellowColor = Color.fromRGBO(253, 199, 0, 1);
  static const Color redColor = Color.fromRGBO(227, 31, 38, 1);
  static const Color greyColor = Color.fromRGBO(53, 69, 87, 1);
  static const Color blueColor = Color.fromRGBO(60, 149, 218, 1);
  static const Color bottomNavigationLabelColor = Color.fromRGBO(
    144,
    161,
    185,
    1,
  );
  static const Color matchesBorder = Color.fromRGBO(173, 70, 255, 0.5);
  static const Color matchesLabel = Color.fromRGBO(194, 122, 255, 1);
  static const Color gamesBorder = Color.fromRGBO(255, 105, 0, 0.5);
  static const Color gamesLabel = Color.fromRGBO(255, 137, 4, 1);
  static const Color pickLabel = Color.fromRGBO(81, 255, 148, 1);
  static const Color topBorder = Color.fromRGBO(240, 177, 0, 0.5);
  static const Color topLabel = Color.fromRGBO(253, 199, 0, 1);
  static const Color profileBorder = Color.fromRGBO(142, 197, 255, 1);
  static const Color profileLabel = Color.fromRGBO(81, 162, 255, 1);
  static const Color finishedTextColor = Color.fromRGBO(129, 129, 129, 1);
  static const Color quizCardBorderColor = Color.fromRGBO(30, 30, 30, 1);
  static const Color unselectedAppBarColor = Color.fromRGBO(138, 143, 152, 1);
  static const Color quizAppBarBackgroundColor = Color.fromRGBO(24, 25, 29, 1);
  static const Color unselectedButtonBackgroundColor = Color.fromRGBO(
    162,
    244,
    253,
    1,
  );
  static const Color logoDefaultPrimaryColor = Color.fromRGBO(11, 23, 64, 1);
  static const Color textPrimary = Color.fromRGBO(92, 223, 255, 1);
  static const Color logoDefaultTextColor = Color.fromRGBO(92, 223, 255, 1);
  static const Color logoutBackgroundColor = Color.fromRGBO(251, 44, 54, 1);
  static const Color logoutTextColor = Color.fromRGBO(162, 244, 253, 1);
  static const Color backgroundPrimary = Color.fromRGBO(13, 17, 26, 1);
  static const Color quizCardBottomDetailBackground = Color.fromRGBO(
    29,
    55,
    96,
    1,
  );
  static const Color quizStartTime = Color.fromRGBO(212, 161, 30, 1);
  static const Color quizLiveTime = Color.fromRGBO(255, 47, 51, 1);
  static const Color greenColor = Color.fromRGBO(0, 201, 80, 0.5);
  static const Color green700 = Color.fromRGBO(5, 223, 114, 1);
  static const Color voteUnselected = Color.fromRGBO(7, 12, 31, 1);
  static const Color voteSelected = Color.fromRGBO(58, 73, 99, 1);
  static const Color voteUserSelected = Color.fromRGBO(92, 223, 255, 1);
  static const Color amoutFilledWagerbackgroundColor = Color.fromRGBO(
    49,
    65,
    88,
    0.66,
  );
  static const Color betBackgroundColor = Color.fromRGBO(0, 146, 184, 0.3);
  static const Color wagerPlacedBorderColor = Color.fromRGBO(34, 197, 94, 1);
  static const Color whiteA10 = Color.fromRGBO(255, 255, 255, 0.1);
  static const Color unselectedColor = Color.fromRGBO(26, 37, 58, 1);
  static const Color backgroundSecondary = Color.fromRGBO(15, 23, 43, 1);
  static const Color border = Color.fromRGBO(49, 65, 88, 1);
  static const Color myPicksDateColor = Color.fromRGBO(255, 255, 255, 0.5);
  static const Color settingsBorderColor = Color.fromRGBO(69, 85, 108, 1);
  static const Color grey900 = Color.fromRGBO(16, 24, 40, 1);
  static const Color backgroundSecondary95 = Color.fromRGBO(15, 23, 43, 0.95);
  static const Color primary950 = Color.fromRGBO(0, 90, 112, 1);
  static const Color textContrast = Color.fromRGBO(255, 255, 255, 1);
  static const Color selectCard = Color.fromRGBO(43, 127, 255, 1);
  static const Color accountBorderColor = Color.fromRGBO(29, 40, 61, 1);
  static const Color dangerColor = Color.fromRGBO(255, 77, 77, 1);
  static const Color white227 = Color.fromRGBO(227, 227, 227, 1);
  static const Color greyColor100 = Color.fromRGBO(100, 116, 139, 1);
  static const Color grey500 = Color.fromRGBO(106, 114, 130, 1);
  static const Color purple900 = Color.fromRGBO(89, 22, 139, 1);
  static const Color purple950 = Color.fromRGBO(60, 3, 102, 1);
  static const Color indigo900 = Color.fromRGBO(49, 44, 133, 1);
  static const Color indigo950 = Color.fromRGBO(30, 26, 77, 1);
  static const Color slate800 = Color.fromRGBO(29, 41, 61, 1);
  static const Color slate400 = Color.fromRGBO(148, 163, 184, 1);
  static const Color onboardingPanelFill = Color.fromRGBO(16, 23, 44, 1);
  static const Color onboardingPanelBorder = Color.fromRGBO(32, 41, 62, 1);
  static const Color whitea80 = Color.fromRGBO(255, 255, 255, 0.8);
  static const Color profileBackgroundColor = Color.fromRGBO(15, 22, 42, 1);
  static const Color blackA20 = Color.fromRGBO(0, 0, 0, 0.2);
  static const Color statsCardBorder = Color.fromRGBO(43, 51, 72, 1);
  static const Color statsBackgroundColor = Color.fromRGBO(19, 28, 52, 1);
  static const Color statsBorderColor = Color.fromRGBO(39, 45, 63, 1);
  static const Color lime900 = Color.fromRGBO(53, 83, 14, 1);
  static const Color lime950 = Color.fromRGBO(25, 46, 3, 1);
  static const Color emerland900 = Color.fromRGBO(0, 79, 59, 1);
  static const Color emerland950 = Color.fromRGBO(0, 44, 34, 1);
  static const Color roseMint800 = Color.fromRGBO(0, 109, 105, 1);
  static const Color roseMint900 = Color.fromRGBO(0, 84, 80, 1);
  static const Color text2 = Color.fromRGBO(209, 213, 220, 1);
  static const Color futureLost = Color.fromRGBO(33, 35, 39, 1);

  // Predictions home tokens (exact values lifted from inline literals).
  static const Color darkInk = Color(0xFF081019); // ink on bright accent plates
  static const Color calendarOnPrimary = Color(0xFF101826);
  static const Color calendarSurface = Color(0xFF162235);
  static const Color skeletonFill = Color(0xFF111827);
  static const Color borderMuted = Color(0xFF243654);
  static const Color gameCtaFill = Color(0xFF0F3E4F);
  static const Color gameCtaBorder = Color(0xFF087B95);

  static LinearGradient get backgroundGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF010916), Color(0xFF0E2646)],
    );
  }

  static LinearGradient get questionCardGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.fromRGBO(15, 23, 43, 1), Color.fromRGBO(29, 41, 61, 1)],
    );
  }

  static LinearGradient get quizCardGradient {
    return const LinearGradient(
      begin: Alignment(-1, 0.39),
      end: Alignment(1, -0.39),
      stops: [0.099, 0.794],
      colors: [
        Color.fromRGBO(15, 23, 43, 0.95),
        Color.fromRGBO(29, 41, 61, 0.95),
      ],
    );
  }

  static LinearGradient get xpGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.9224],
      colors: [
        Color.fromRGBO(21, 93, 252, 0.9),
        Color.fromRGBO(130, 0, 219, 0.9),
      ],
    );
  }

  static LinearGradient get completedXpGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.9224],
      colors: [Color.fromRGBO(240, 177, 0, 1), Color.fromRGBO(225, 113, 0, 1)],
    );
  }

  static LinearGradient get predictionCardGradient {
    return const LinearGradient(
      begin: Alignment(-0.559, -0.829),
      end: Alignment(0.559, 0.829),
      stops: [0.0, 1.0],
      colors: [
        Color.fromRGBO(15, 23, 43, 0.95),
        Color.fromRGBO(29, 41, 61, 0.95),
      ],
    );
  }

  static LinearGradient get bottomNavigationGradient {
    return const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color.fromRGBO(15, 23, 43, 0.98),
        Color.fromRGBO(29, 41, 61, 0.98),
      ],
    );
  }

  static LinearGradient get matchesGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.fromRGBO(173, 70, 255, 0.25),
        Color.fromRGBO(127, 34, 254, 0.25),
      ],
    );
  }

  static LinearGradient get appBarGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.fromRGBO(29, 41, 61, 0.95),
        Color.fromRGBO(15, 23, 43, 0.95),
      ],
    );
  }

  static LinearGradient get gamesGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.fromRGBO(255, 105, 0, 0.25),
        Color.fromRGBO(231, 0, 11, 0.25),
      ],
    );
  }

  static LinearGradient get topGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.fromRGBO(240, 177, 0, 0.25),
        Color.fromRGBO(225, 113, 0, 0.25),
      ],
    );
  }

  static LinearGradient get profileGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.fromRGBO(43, 127, 255, 1),
        Color.fromRGBO(152, 16, 250, 1),
      ],
    );
  }

  static LinearGradient get questionPageBottomGradient {
    return const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      stops: [0.0, 0.5, 1.0],
      colors: [
        Color.fromRGBO(2, 6, 24, 1),
        Color.fromRGBO(2, 6, 24, 0.95),
        Colors.transparent,
      ],
    );
  }

  static LinearGradient get logoutGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.fromRGBO(231, 0, 11, 1), Color.fromRGBO(193, 0, 7, 1)],
    );
  }

  static LinearGradient get pinkGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.fromRGBO(173, 70, 255, 1), Color.fromRGBO(230, 0, 118, 1)],
    );
  }

  static LinearGradient get wagerPlacedGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.5, 1.0],
      colors: [
        Color.fromRGBO(13, 84, 43, 1),
        Color.fromRGBO(0, 79, 59, 1),
        Color.fromRGBO(3, 46, 21, 1),
      ],
    );
  }

  static LinearGradient get wagerPlacedCircularGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.fromRGBO(0, 201, 80, 1), Color.fromRGBO(0, 153, 102, 1)],
    );
  }

  static LinearGradient get quizPageBackgroundGradient {
    return const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      stops: [0.0, 0.5, 1.0],
      colors: [
        Color.fromRGBO(2, 6, 24, 1),
        Color.fromRGBO(22, 36, 86, 1),
        Color.fromRGBO(2, 6, 24, 1),
      ],
    );
  }

  static LinearGradient get settingsGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.fromRGBO(24, 36, 68, 1), Color.fromRGBO(17, 26, 46, 1)],
    );
  }

  static TextTheme get _baseTextTheme {
    return const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'Onest',
        color: whiteColor,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Onest',
        color: whiteColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Onest',
        color: textMedium,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Onest',
        color: whiteColor,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Onest',
        color: whiteColor,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Orbitron',
        color: whiteColor,
        fontSize: 28,
        fontWeight: FontWeight.w800,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Onest',
        color: whiteColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Onest',
        color: whiteColor,
        fontSize: 14,
        fontWeight: FontWeight.w300,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Orbitron',
        color: whiteColor,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Onest',
        color: whiteColor,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Onest',
        color: whiteColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      displayLarge: TextStyle(
        fontFamily: 'Orbitron',
        color: whiteColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Onest',
        color: whiteColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Onest',
        color: textMedium,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = Cyber.buildTextTheme(_baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: textPrimary,
        brightness: Brightness.dark,
        primary: textPrimary,
        secondary: selectCard,
        tertiary: matchesLabel,
        surface: backgroundSecondary,
        error: dangerColor,
      ),
      scaffoldBackgroundColor: backgroundPrimary,
      fontFamily: Cyber.bodyFont,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: whiteColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: whiteColor),
        titleTextStyle: Cyber.label(20),
        // Keep the app-wide transparent/light overlay (AppBar would otherwise
        // reset the status bar to its own computed style).
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      cardTheme: const CardThemeData(
        color: backgroundSecondary,
        elevation: 0,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: backgroundPrimary,
          backgroundColor: activeButtonColor,
          minimumSize: const Size.fromHeight(48),
          textStyle: Cyber.label(
            14,
            color: backgroundPrimary,
            weight: FontWeight.w900,
          ),
          shape: const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          minimumSize: const Size.fromHeight(46),
          textStyle: Cyber.label(14, color: textPrimary),
          shape: const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: Cyber.label(13, color: textPrimary),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: backgroundSecondary,
        selectedColor: textPrimary,
        side: BorderSide(color: border),
        labelStyle: TextStyle(
          color: whiteColor,
          fontFamily: Cyber.displayFont,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.7,
        ),
      ),
      snackBarTheme: SnackBarThemeData(contentTextStyle: Cyber.body(13)),
      listTileTheme: ListTileThemeData(
        titleTextStyle: Cyber.body(14, weight: FontWeight.w700),
        subtitleTextStyle: Cyber.body(
          12,
          color: textMedium,
          weight: FontWeight.w500,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: textPrimary,
        circularTrackColor: Colors.transparent,
        linearTrackColor: grey900,
        strokeWidth: 5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: textFieldFillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: textFieldBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: textPrimary),
        ),
      ),
    );
  }
}

class Cyber {
  // Compatibility facade for the existing app. Values now come from AppTheme.
  static const bg = AppTheme.backgroundPrimary;
  static const bg2 = AppTheme.voteUnselected;
  static const card = AppTheme.backgroundSecondary;
  static const panel = AppTheme.slate800;
  static const panel2 = AppTheme.backgroundSecondary;

  static const cyan = AppTheme.textPrimary;
  static const accentGlow = Color(0x405cdfff);
  static const magenta = AppTheme.matchesLabel;
  static const lime = AppTheme.pickLabel;
  static const amber = AppTheme.gamesLabel;
  static const gold = AppTheme.yellowColor;
  static const danger = AppTheme.dangerColor;
  static const success = AppTheme.green700;
  static const red = AppTheme.redColor;
  static const violet = AppTheme.matchesLabel;

  static const border = AppTheme.border;
  static const line = AppTheme.settingsBorderColor;
  static const borderSubtle = AppTheme.whiteA10;
  static const borderActive = AppTheme.matchesBorder;
  static const muted = AppTheme.textMedium;

  static const displayFont = 'Orbitron';
  static const bodyFont = 'Onest';

  static LinearGradient panelGradient([Color? glow]) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [(glow ?? cyan).withValues(alpha: 0.16), panel, panel2],
    stops: const [0, 0.42, 1],
  );

  static List<BoxShadow> glow(
    Color color, {
    double alpha = 0.3,
    double blur = 16,
    double spread = -2,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

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
