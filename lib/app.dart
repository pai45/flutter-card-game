import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/game/game_bloc.dart';
import 'blocs/game/game_event.dart';
import 'blocs/game/game_state.dart';
import 'blocs/prediction/prediction_cubit.dart';
import 'config/enums.dart';
import 'config/theme.dart';
import 'models/league.dart';
import 'models/sport_match.dart';
import 'screens/game/game_screen.dart';
import 'screens/home/widgets/starter_pack_onboarding.dart';
import 'screens/onboarding/avatar_selection_screen.dart';
import 'screens/predictions/league_detail_screen.dart';
import 'screens/predictions/match_prediction_screen.dart';
import 'screens/predictions/prediction_home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'services/prediction_repository.dart';
import 'services/secure_storage_service.dart';

class PitchDuelApp extends StatelessWidget {
  const PitchDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Cyber.buildTextTheme(ThemeData.dark().textTheme);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => GameBloc(SecureGameStorage())..add(GameLoaded()),
        ),
        BlocProvider(
          create: (_) =>
              PredictionCubit(MockPredictionRepository(), SecureGameStorage())
                ..load(),
        ),
      ],
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
  // Default landing is the new prediction HOME.
  AppSection section = AppSection.predictions;
  bool _openGameAfterStarterReveal = false;
  final SecureGameStorage _storage = SecureGameStorage();
  bool _avatarLoading = true;
  String? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    _loadSelectedAvatar();
  }

  Future<void> _loadSelectedAvatar() async {
    final avatarId = await _storage.loadSelectedAvatarId();
    if (!mounted) return;
    setState(() {
      _selectedAvatarId = avatarId;
      _avatarLoading = false;
    });
  }

  void _go(AppSection next) => setState(() => section = next);

  Future<void> _completeAvatarSelection(String avatarId) async {
    await _storage.saveSelectedAvatarId(avatarId);
    if (!mounted) return;
    setState(() => _selectedAvatarId = avatarId);
  }

  /// Enter the card game ("Pitch Duel") as a full-screen pushed flow from the
  /// GAMES tab. App-level destinations selected inside it pop back and switch
  /// the shell; card-game-internal sections are handled within GameTabContent.
  void _openGame() {
    final bloc = context.read<GameBloc>();
    if (!bloc.state.starterPackClaimed) {
      _openGameAfterStarterReveal = true;
      bloc.add(StarterPackOpened());
      return;
    }
    _pushGame();
  }

  void _pushGame() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GameTabContent(
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  void _openMatch(SportMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchPredictionScreen(match: match),
      ),
    );
  }

  void _openLeague(League league) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeagueDetailScreen(league: league),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<GameBloc, GameState>(
        listenWhen: (previous, current) =>
            previous.pendingPackReveal != current.pendingPackReveal,
        listener: (context, state) {
          if (_openGameAfterStarterReveal &&
              state.pendingPackReveal == null &&
              state.starterPackClaimed) {
            _openGameAfterStarterReveal = false;
            _pushGame();
          }
        },
        builder: (context, state) {
          if (state.loading || _avatarLoading) {
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
                      'Loading...',
                      style: TextStyle(color: Cyber.cyan, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
          if (_selectedAvatarId == null) {
            return AvatarSelectionScreen(onComplete: _completeAvatarSelection);
          }
          final packReveal = state.pendingPackReveal;
          if (packReveal != null && packReveal.items.isNotEmpty) {
            return PackOnboardingScreen(
              key: const ValueKey('onboarding'),
              reveal: packReveal,
            );
          }
          return switch (section) {
            AppSection.shop => ShopScreen(onNavigate: _go),
            AppSection.leaderboard => LeaderboardScreen(onNavigate: _go),
            AppSection.profile => ProfileScreen(onNavigate: _go),
            _ => PredictionHomeScreen(
              onNavigate: _go,
              onOpenMatch: _openMatch,
              onOpenLeague: _openLeague,
              onOpenGame: _openGame,
            ),
          };
        },
      ),
    );
  }
}
