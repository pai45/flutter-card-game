import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/achievement/achievement_celebration_controller.dart';
import 'blocs/final_over/final_over_cubit.dart';
import 'blocs/friends/friends_cubit.dart';
import 'blocs/game/game_bloc.dart';
import 'blocs/game/game_event.dart';
import 'blocs/game/game_state.dart';
import 'blocs/match_circle/match_circle_cubit.dart';
import 'blocs/picks/picks_cubit.dart';
import 'blocs/picks/picks_state.dart';
import 'blocs/prediction/prediction_cubit.dart';
import 'blocs/prediction/prediction_state.dart';
import 'blocs/quiz/quiz_cubit.dart';
import 'blocs/tennis/tennis_cubit.dart';
import 'blocs/tennis/tennis_state.dart';
import 'config/enums.dart';
import 'config/theme.dart';
import 'models/league.dart';
import 'models/sport_match.dart';
import 'screens/deck/cricket_deck_builder_screen.dart';
import 'screens/final_over/final_over_hub.dart';
import 'screens/football_bingo/football_bingo_hub.dart';
import 'screens/football_chess/football_chess_hub.dart';
import 'screens/basketball/basketball_hub.dart';
import 'screens/grand_prix/grand_prix_hub.dart';
import 'screens/game/game_screen.dart';
import 'screens/shootout/shootout_hub.dart';
import 'screens/super_over/super_over_hub.dart';
import 'screens/tennis/tennis_hub.dart';
import 'screens/home/widgets/starter_pack_onboarding.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/predictions/league_detail_screen.dart';
import 'screens/predictions/match_detail_screen.dart';
import 'screens/predictions/prediction_home_screen.dart';
import 'screens/quiz/quiz_hub.dart';
import 'screens/guess_player/guess_player_hub.dart';
import 'data/guess_player_data.dart';
import 'models/cards.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'services/achievement_progress.dart';
import 'services/live_prediction_repository.dart';
import 'services/live_score_service.dart';
import 'services/match_circle_repository.dart';
import 'services/espn_service.dart';
import 'services/pick_repository.dart';
import 'services/prediction_repository.dart';
import 'services/secure_storage_service.dart';
import 'widgets/achievement_celebration_host.dart';
import 'widgets/reward_settlement_popup.dart';
import 'widgets/streak_celebration_host.dart';

enum _PendingGameLaunchKind { football, cricket, basketball }

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
          create: (_) => MatchCircleCubit(
            LocalMatchCircleRepository(),
            SecureGameStorage(),
          ),
        ),
        BlocProvider(
          create: (_) => PredictionCubit(
            LivePredictionRepository(
              MockPredictionRepository(),
              LiveScoreService(),
              const EspnService(),
            ),
            SecureGameStorage(),
          )..load(),
        ),
        BlocProvider(
          create: (_) =>
              PicksCubit(MockPickRepository(), SecureGameStorage())..load(),
        ),
        BlocProvider(
          create: (_) => AchievementCelebrationController(SecureGameStorage()),
        ),
        BlocProvider(create: (_) => FriendsCubit(SecureGameStorage())..load()),
        BlocProvider(create: (_) => QuizCubit(SecureGameStorage())..load()),
        BlocProvider(create: (_) => TennisCubit(SecureGameStorage())..load()),
        BlocProvider(
          create: (_) => FinalOverCubit(SecureGameStorage())..load(),
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
              BlocListener<TennisCubit, TennisState>(
                listener: (context, _) => _syncAchievements(context),
              ),
            ],
            child: Stack(
              children: [
                Positioned.fill(child: child ?? const SizedBox.shrink()),
                const Positioned.fill(child: AchievementCelebrationHost()),
                const Positioned.fill(child: StreakCelebrationHost()),
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
  // Default landing is Matches; its first internal tab is Predict.
  AppSection section = AppSection.predictions;
  int _predictionTab = 0;
  int _predictionMatchSportTab = 0;
  int _predictionGamesSportTab = 0;
  int _shopInitialTab = 0;
  // A game flow to push once the starter-pack reveal finishes (first launch).
  VoidCallback? _pendingGameLaunch;
  _PendingGameLaunchKind? _pendingGameLaunchKind;
  final SecureGameStorage _storage = SecureGameStorage();
  bool _onboardingLoading = true;
  bool _onboardingComplete = false;
  bool _demoRewardSettlementSeen = true;
  String? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    final avatarId = await _storage.loadSelectedAvatarId();
    final complete = await _storage.loadOnboardingComplete();
    final demoRewardSeen = await _storage.loadDemoRewardSettlementSeen();
    if (!mounted) return;
    setState(() {
      _selectedAvatarId = avatarId;
      _onboardingComplete = complete;
      _demoRewardSettlementSeen = demoRewardSeen;
      _onboardingLoading = false;
    });
  }

  void _go(AppSection next) => setState(() {
    section = next;
    if (next == AppSection.shop) _shopInitialTab = 0;
  });

  void _openShopCoins() => setState(() {
    _shopInitialTab = 2;
    section = AppSection.shop;
  });

  /// Launch a card match against a CPU themed as a leaderboard rival. Reuses the
  /// starter-pack gate, then opens the game flow straight into the match.
  void _openChallenge(String opponentName, int opponentLevel) {
    _enterFootballGameFlow(
      () => _pushChallengeMatch(opponentName, opponentLevel),
    );
  }

  void _pushChallengeMatch(String opponentName, int opponentLevel) {
    final navigator = Navigator.of(context);
    context.read<GameBloc>().add(
      MatchStarted(opponentName: opponentName, opponentLevel: opponentLevel),
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GameTabContent(
          initialSection: AppSection.match,
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  Future<void> _completeProfileSetup(ProfileSetupResult result) async {
    await _storage.saveSelectedAvatarId(result.avatarId);
    await _storage.saveSelectedProfileBannerId(result.bannerId);
    await _storage.savePrimarySportName(result.primarySport.name);
    await _storage.saveFollowedLeagueIds(result.followedLeagueIds);
    await _storage.saveFavoriteTeams(result.favoriteTeams);
    await _storage.saveOnboardingComplete(true);
    if (!mounted) return;
    setState(() {
      _selectedAvatarId = result.avatarId;
      _onboardingComplete = true;
      _demoRewardSettlementSeen = false;
    });
  }

  Future<void> _dismissDemoRewardSettlement() async {
    if (_demoRewardSettlementSeen) return;
    setState(() => _demoRewardSettlementSeen = true);
    await _storage.saveDemoRewardSettlementSeen();
  }

  Future<void> _logoutFromProfile() async {
    await _storage.resetProfileSetup();
    if (!mounted) return;
    setState(() {
      section = AppSection.predictions;
      _predictionTab = 0;
      _predictionMatchSportTab = 0;
      _predictionGamesSportTab = 0;
      _pendingGameLaunch = null;
      _pendingGameLaunchKind = null;
      _selectedAvatarId = null;
      _onboardingComplete = false;
      _demoRewardSettlementSeen = false;
    });
  }

  /// Enter the card game ("Pitch Duel") as a full-screen pushed flow from the
  /// GAMES tab. App-level destinations selected inside it pop back and switch
  /// the shell; card-game-internal sections are handled within GameTabContent.
  void _openGame() => _enterFootballGameFlow(_pushGame);

  /// Enter the standalone Penalty Shootout game from the GAMES tab.
  void _openShootout() => _enterFootballGameFlow(_pushShootout);

  /// Enter 5v5 Football Chess from the GAMES tab — it fields the equipped deck,
  /// so it shares the starter-pack gate with the other deck-based games.
  void _openFootballChess() => _enterFootballGameFlow(_pushFootballChess);

  /// Enter Super Over from the GAMES tab's Cricket section.
  void _openSuperOver() => _enterCricketGameFlow(_pushSuperOver);

  /// Enter Final Over from Cricket GAMES. The rules engine lives in the
  /// `final_over` package; the lobby, pitch and HUD are ours.
  void _openFinalOver() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => FinalOverHub(onExit: navigator.pop),
      ),
    );
  }

  /// Open the cricket-only deck editor from the GAMES tab's Cricket section.
  void _openCricketDeck() => _enterCricketGameFlow(_pushCricketDeck);

  /// Enter Hoop Duel from the GAMES tab's Basketball section.
  void _openBasketball() => _enterBasketballGameFlow(_pushBasketball);

  /// Both games share the starter deck — claim the starter pack first on a
  /// first launch, then push the requested flow once the reveal completes.
  void _enterFootballGameFlow(VoidCallback push) {
    final bloc = context.read<GameBloc>();
    if (!bloc.state.starterPackClaimed) {
      _pendingGameLaunch = push;
      _pendingGameLaunchKind = _PendingGameLaunchKind.football;
      bloc.add(StarterPackOpened());
      return;
    }
    push();
  }

  void _enterCricketGameFlow(VoidCallback push) {
    final bloc = context.read<GameBloc>();
    if (!bloc.state.cricketStarterPackClaimed) {
      _pendingGameLaunch = push;
      _pendingGameLaunchKind = _PendingGameLaunchKind.cricket;
      bloc.add(CricketStarterPackOpened());
      return;
    }
    push();
  }

  void _enterBasketballGameFlow(VoidCallback push) {
    final bloc = context.read<GameBloc>();
    if (!bloc.state.basketballStarterPackClaimed) {
      _pendingGameLaunch = push;
      _pendingGameLaunchKind = _PendingGameLaunchKind.basketball;
      bloc.add(BasketballStarterPackOpened());
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

  void _pushFootballChess() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => FootballChessTabContent(
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  void _pushSuperOver() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SuperOverHub(onExit: navigator.pop),
      ),
    );
  }

  void _pushCricketDeck() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => CricketDeckBuilderScreen(
          onBack: () => navigator.pop(),
          onPlaySuperOver: () {
            navigator.pop();
            _pushSuperOver();
          },
        ),
      ),
    );
  }

  /// Open the Quiz from the GAMES tab. Unlike the card games it needs
  /// no starter deck, so it pushes straight in (no starter-pack gate).
  void _openQuiz(Sport sport) {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => QuizTabContent(
          sport: sport,
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  void _openGuessPlayer() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GuessPlayerTabContent(
          sport: Sport.football,
          timelines: footballGuessTimelines,
          allPlayers: footballPlayerCards,
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  void _openBasketballGuessPlayer() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GuessPlayerTabContent(
          sport: Sport.basketball,
          timelines: basketballGuessTimelines,
          allPlayers: basketballPlayerCards,
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  void _openCricketGuessPlayer() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GuessPlayerTabContent(
          sport: Sport.cricket,
          timelines: cricketGuessTimelines,
          allPlayers: cricketPlayerCards,
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  void _openFootballBingo() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => FootballBingoTabContent(
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  /// Open Grand Prix Dash from the GAMES tab's F1 section. The car is purely
  /// cosmetic — no deck, so no starter-pack gate (like the quiz and bingo).
  void _openGrandPrix() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GrandPrixTabContent(
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  void _openTennisRally() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => TennisRallyHub(onExit: navigator.pop),
      ),
    );
  }

  /// Push Hoop Duel after its basketball starter pack gate is satisfied.
  void _pushBasketball() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BasketballTabContent(
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
      MaterialPageRoute<void>(builder: (_) => MatchDetailScreen(match: match)),
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
          final ready = switch (_pendingGameLaunchKind) {
            _PendingGameLaunchKind.cricket => state.cricketStarterPackClaimed,
            _PendingGameLaunchKind.basketball =>
              state.basketballStarterPackClaimed,
            _PendingGameLaunchKind.football => state.starterPackClaimed,
            null => false,
          };
          if (pending != null && state.pendingPackReveal == null && ready) {
            _pendingGameLaunch = null;
            _pendingGameLaunchKind = null;
            pending();
          }
        },
        builder: (context, state) {
          if (state.loading || _onboardingLoading) {
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
          if (!_onboardingComplete) {
            return ProfileSetupScreen(
              initialAvatarId: _selectedAvatarId,
              onComplete: _completeProfileSetup,
            );
          }
          final packReveal = state.pendingPackReveal;
          if (packReveal != null && packReveal.items.isNotEmpty) {
            return PackOnboardingScreen(
              key: const ValueKey('onboarding'),
              reveal: packReveal,
            );
          }
          final content = switch (section) {
            AppSection.shop => ShopScreen(
              onNavigate: _go,
              initialTab: _shopInitialTab,
            ),
            AppSection.leaderboard => LeaderboardScreen(
              onNavigate: _go,
              onAddCoins: _openShopCoins,
              onChallenge: _openChallenge,
            ),
            AppSection.profile => ProfileScreen(
              onNavigate: _go,
              onLogout: _logoutFromProfile,
              onChallenge: _openChallenge,
            ),
            _ => PredictionHomeScreen(
              activeTab: _predictionTab,
              onTabChanged: (tab) => setState(() => _predictionTab = tab),
              activeMatchSportTab: _predictionMatchSportTab,
              onMatchSportTabChanged: (tab) =>
                  setState(() => _predictionMatchSportTab = tab),
              activeGamesSportTab: _predictionGamesSportTab,
              onGamesSportTabChanged: (tab) =>
                  setState(() => _predictionGamesSportTab = tab),
              onNavigate: _go,
              onOpenMatch: _openMatch,
              onOpenLeague: _openLeague,
              onOpenGame: _openGame,
              onOpenShootout: _openShootout,
              onOpenQuiz: _openQuiz,
              onOpenFootballBingo: _openFootballBingo,
              onOpenFootballChess: _openFootballChess,
              onOpenSuperOver: _openSuperOver,
              onOpenFinalOver: _openFinalOver,
              onOpenCricketDeck: _openCricketDeck,
              onOpenGuessPlayer: _openGuessPlayer,
              onOpenBasketballGuessPlayer: _openBasketballGuessPlayer,
              onOpenCricketGuessPlayer: _openCricketGuessPlayer,
              onOpenGrandPrix: _openGrandPrix,
              onOpenBasketball: _openBasketball,
              onOpenTennisRally: _openTennisRally,
              onAddCoins: _openShopCoins,
            ),
          };
          return Stack(
            children: [
              Positioned.fill(child: content),
              if (!_demoRewardSettlementSeen)
                Positioned.fill(
                  child: RewardSettlementPopup(
                    data: RewardSettlementDemoData.demo(),
                    onDismiss: _dismissDemoRewardSettlement,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
