import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/game/game_bloc.dart';
import 'blocs/game/game_event.dart';
import 'blocs/game/game_state.dart';
import 'config/enums.dart';
import 'config/theme.dart';
import 'screens/game/game_screen.dart';
import 'screens/home/widgets/starter_pack_onboarding.dart';
import 'screens/shop/shop_screen.dart';
import 'services/secure_storage_service.dart';

class PitchDuelApp extends StatelessWidget {
  const PitchDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Cyber.buildTextTheme(ThemeData.dark().textTheme);

    return BlocProvider(
      create: (_) => GameBloc(SecureGameStorage())..add(GameLoaded()),
      child: MaterialApp(
        title: 'Pitch Duel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Cyber.cyan,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Cyber.bg,
          fontFamily: Cyber.bodyFont,
          textTheme: textTheme,
          primaryTextTheme: textTheme,
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xff070b14),
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: Cyber.label(20),
          ),
          cardTheme: CardThemeData(
            color: Cyber.panel,
            elevation: 0,
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              side: BorderSide(color: Cyber.line),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              foregroundColor: Cyber.bg,
              backgroundColor: Cyber.cyan,
              minimumSize: const Size.fromHeight(48),
              textStyle: Cyber.label(
                14,
                color: Cyber.bg,
                weight: FontWeight.w900,
              ),
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Cyber.cyan,
              side: const BorderSide(color: Cyber.line),
              minimumSize: const Size.fromHeight(46),
              textStyle: Cyber.label(14, color: Cyber.cyan),
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Cyber.cyan,
              textStyle: Cyber.label(13, color: Cyber.cyan),
            ),
          ),
          chipTheme: const ChipThemeData(
            backgroundColor: Cyber.panel2,
            selectedColor: Cyber.cyan,
            side: BorderSide(color: Cyber.line),
            labelStyle: TextStyle(
              color: Colors.white,
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
              color: Cyber.muted,
              weight: FontWeight.w500,
            ),
          ),
        ),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection section = AppSection.game;

  void _go(AppSection next) => setState(() => section = next);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<GameBloc, GameState>(
        builder: (context, state) {
          if (state.loading) {
            return Container(
              color: Cyber.bg,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Cyber.cyan),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading Game...',
                      style: TextStyle(color: Cyber.cyan, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state.starterPackPending && state.starterPackCards.isNotEmpty) {
            return StarterPackOnboardingScreen(
              key: const ValueKey('onboarding'),
              cards: state.starterPackCards,
            );
          }
          return switch (section) {
            AppSection.shop => ShopScreen(onNavigate: _go),
            _ => GameTabContent(onNavigate: _go),
          };
        },
      ),
    );
  }
}
