import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/achievement/achievement_celebration_controller.dart';
import 'blocs/game/game_bloc.dart';
import 'blocs/game/game_event.dart';
import 'blocs/game/game_state.dart';
import 'blocs/picks/picks_cubit.dart';
import 'blocs/picks/picks_state.dart';
import 'blocs/prediction/prediction_cubit.dart';
import 'blocs/prediction/prediction_state.dart';
import 'config/enums.dart';
import 'config/theme.dart';
import 'models/league.dart';
import 'models/sport_match.dart';
import 'screens/game/game_screen.dart';
import 'screens/shootout/shootout_hub.dart';
import 'screens/home/widgets/starter_pack_onboarding.dart';
import 'screens/onboarding/avatar_selection_screen.dart';
import 'screens/predictions/league_detail_screen.dart';
import 'screens/predictions/match_prediction_screen.dart';
import 'screens/predictions/prediction_home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'services/achievement_progress.dart';
import 'services/pick_repository.dart';
import 'services/prediction_repository.dart';
import 'services/secure_storage_service.dart';
import 'widgets/achievement_celebration_host.dart';

class PitchDuelApp extends StatelessWidget {
  const PitchDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
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
        BlocProvider(
          create: (_) =>
              PicksCubit(MockPickRepository(), SecureGameStorage())..load(),
        ),
        BlocProvider(
          create: (_) => AchievementCelebrationController(SecureGameStorage()),
        ),
      ],
      child: MaterialApp(
        title: 'Pitch Duel',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // Watch the three source blocs and float the achievement-unlock reveal
        // above every route. The reveal itself lives in [AchievementCelebrationHost].
        builder: (context, child) {
          return MultiBlocListener(
            listeners: [
              BlocListener<GameBloc, GameState>(
                listener: (context, _) => _syncAchievements(context),
              ),
              BlocListener<PredictionCubit, PredictionState>(
                listener: (context, _) => _syncAchievements(context),
              ),
              BlocListener<PicksCubit, PicksState>(
                listener: (context, _) => _syncAchievements(context),
              ),
            ],
            child: Stack(
              children: [
                Positioned.fill(child: child ?? const SizedBox.shrink()),
                const Positioned.fill(child: AchievementCelebrationHost()),
              ],
            ),
          );
        },
        home: const AppShell(),
      ),
    );
  }
}

/// Recomputes the live achievement snapshot and hands it to the celebration
/// controller — but only once all three source blocs have finished loading, so
/// the silent first-run seed is based on complete data (no launch-time replays).
void _syncAchievements(BuildContext context) {
  final gameLoading = context.read<GameBloc>().state.loading;
  final predLoading = context.read<PredictionCubit>().state.loading;
  final picksLoading = context.read<PicksCubit>().state.loading;
  if (gameLoading || predLoading || picksLoading) return;
  context.read<AchievementCelebrationController>().sync(
    currentAchievementStats(context),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Default landing is the new prediction HOME.
  AppSection section = AppSection.predictions;
  int _predictionTab = 0;
  // A game flow to push once the starter-pack reveal finishes (first launch).
  VoidCallback? _pendingGameLaunch;
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
  void _openGame() => _enterGameFlow(_pushGame);

  /// Enter the standalone Penalty Shootout game from the GAMES tab.
  void _openShootout() => _enterGameFlow(_pushShootout);

  /// Both games share the starter deck — claim the starter pack first on a
  /// first launch, then push the requested flow once the reveal completes.
  void _enterGameFlow(VoidCallback push) {
    final bloc = context.read<GameBloc>();
    if (!bloc.state.starterPackClaimed) {
      _pendingGameLaunch = push;
      bloc.add(StarterPackOpened());
      return;
    }
    push();
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

  void _pushShootout() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ShootoutTabContent(
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
          final pending = _pendingGameLaunch;
          if (pending != null &&
              state.pendingPackReveal == null &&
              state.starterPackClaimed) {
            _pendingGameLaunch = null;
            pending();
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
              activeTab: _predictionTab,
              onTabChanged: (tab) => setState(() => _predictionTab = tab),
              onNavigate: _go,
              onOpenMatch: _openMatch,
              onOpenLeague: _openLeague,
              onOpenGame: _openGame,
              onOpenShootout: _openShootout,
            ),
          };
        },
      ),
    );
  }
}
