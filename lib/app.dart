import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/achievement/achievement_celebration_controller.dart';
import 'blocs/final_over/final_over_cubit.dart';
import 'blocs/friends/friends_cubit.dart';
import 'blocs/game/game_bloc.dart';
import 'blocs/game/game_event.dart';
import 'blocs/game/game_state.dart';
import 'blocs/league_stats/league_stats_cubit.dart';
import 'blocs/match_circle/match_circle_cubit.dart';
import 'blocs/picks/picks_cubit.dart';
import 'blocs/picks/picks_state.dart';
import 'blocs/prediction/prediction_cubit.dart';
import 'blocs/prediction/prediction_state.dart';
import 'blocs/quiz/quiz_cubit.dart';
import 'blocs/tennis/tennis_cubit.dart';
import 'blocs/tennis/tennis_state.dart';
import 'config/enums.dart';
import 'config/game_ladder.dart';
import 'config/sport_modules.dart';
import 'config/theme.dart';
import 'models/league.dart';
import 'models/oz_coin_ledger.dart';
import 'models/sport_match.dart';
import 'models/streak_reminder.dart';
import 'screens/final_over/final_over_hub.dart';
import 'screens/football_bingo/football_bingo_hub.dart';
import 'screens/football_chess/football_chess_hub.dart';
import 'screens/basketball/basketball_hub.dart';
import 'screens/grand_prix/grand_prix_hub.dart';
import 'screens/game/game_screen.dart';
import 'screens/shootout/shootout_hub.dart';
import 'screens/tennis/tennis_hub.dart';
import 'screens/home/widgets/starter_pack_onboarding.dart';
import 'screens/onboarding/widgets/onboarding_coin_reward_animation.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/predictions/league_detail_screen.dart';
import 'screens/predictions/match_detail_screen.dart';
import 'screens/predictions/market_detail_screen.dart';
import 'screens/predictions/prediction_home_screen.dart';
import 'screens/predictions/streak_calendar_screen.dart';
import 'screens/predictions/widgets/unlock_sheets.dart';
import 'screens/quiz/quiz_hub.dart';
import 'screens/guess_player/guess_player_hub.dart';
import 'screens/guess_driver/guess_driver_hub.dart';
import 'screens/guess_winner/guess_winner_hub.dart';
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
import 'services/rolling_window_service.dart';
import 'services/secure_storage_service.dart';
import 'widgets/achievement_celebration_host.dart';
import 'widgets/streak_celebration_host.dart';
import 'widgets/streak_reminder_popup.dart';
import 'widgets/unlock_celebration_host.dart';

/// Lets the shell know when a pushed route covers the home hub, so unlock
/// moments wait until the player is back on it.
final RouteObserver<ModalRoute<void>> _appRouteObserver =
    RouteObserver<ModalRoute<void>>();

enum _PendingGameLaunchKind { football, cricket, basketball, tennis, grandPrix }

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
        title: 'StatOz',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        navigatorObservers: [_appRouteObserver],
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
                const Positioned.fill(child: UnlockCelebrationHost()),
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

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver, RouteAware {
  // Default landing is Matches; both hub strips start on Trending.
  AppSection section = AppSection.predictions;
  int _predictionTab = 0;
  int _predictionMatchSportTab = 0;
  int _predictionGamesSportTab = 0;
  int _shopInitialTab = 0;
  // A game flow to push once the starter-pack reveal finishes (first launch).
  VoidCallback? _pendingGameLaunch;
  _PendingGameLaunchKind? _pendingGameLaunchKind;
  final SecureGameStorage _storage = SecureGameStorage();
  late final RollingWindowService _rollingWindow = RollingWindowService(
    _storage,
  );
  bool _onboardingLoading = true;
  bool _onboardingComplete = false;
  OnboardingRewardStatus? _onboardingRewardStatus;
  bool _onboardingRewardDismissing = false;
  String? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    UnlockRevealGate.instance
      ..playGame = _openArcadeGame
      ..openSport = _enterSport;
    _loadOnboardingState();
    _runRollingWindowIfDue();
  }

  bool _hubOnTop = true;
  bool _homeTabsSeeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) _appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => _setHubOnTop(false);

  @override
  void didPopNext() => _setHubOnTop(true);

  void _setHubOnTop(bool onTop) {
    _hubOnTop = onTop;
    _syncRevealGate();
  }

  /// Unlock reveals may only play on the bare, fully onboarded hub.
  void _syncRevealGate() {
    UnlockRevealGate.instance.hubVisible.value =
        mounted &&
        _hubOnTop &&
        !_onboardingLoading &&
        _onboardingComplete &&
        _onboardingRewardStatus != OnboardingRewardStatus.pending;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<GameBloc>().add(DailyQuestsRefreshed());
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeShowStreakReminder(),
      );
    }
    if (state == AppLifecycleState.resumed) {
      _runRollingWindowIfDue();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appRouteObserver.unsubscribe(this);
    final gate = UnlockRevealGate.instance;
    gate.hubVisible.value = false;
    gate.playGame = null;
    gate.openSport = null;
    super.dispose();
  }

  /// The frontend "cronjob": settles yesterday's finished fixtures and pulls
  /// in the day newly entering the rolling window, once per calendar day.
  Future<void> _runRollingWindowIfDue() async {
    final rollingWindowDue = await _rollingWindow.isDue();
    if (!mounted) return;
    if (!rollingWindowDue) {
      await context.read<PredictionCubit>().refreshLiveAndPendingMatches();
      return;
    }
    await _rollingWindow.runIfDue(
      predictionCubit: context.read<PredictionCubit>(),
      picksCubit: context.read<PicksCubit>(),
    );
  }

  Future<void> _loadOnboardingState() async {
    final avatarId = await _storage.loadSelectedAvatarId();
    final complete = await _storage.loadOnboardingComplete();
    var rewardStatus = await _storage.loadOnboardingRewardStatus();
    // A completed profile with no reward marker predates this feature. Mark it
    // seen without granting coins so rollout only rewards new onboarding runs.
    if (complete && rewardStatus == null) {
      rewardStatus = OnboardingRewardStatus.seen;
      await _storage.saveOnboardingRewardStatus(rewardStatus);
    }
    if (!mounted) return;
    setState(() {
      _selectedAvatarId = avatarId;
      _onboardingComplete = complete;
      _onboardingRewardStatus = rewardStatus;
      _onboardingLoading = false;
    });
    if (complete && rewardStatus == OnboardingRewardStatus.pending) {
      context.read<GameBloc>().add(OnboardingRewardClaimed());
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowStreakReminder(),
    );
  }

  void _go(AppSection next) => setState(() {
    section = next;
    if (next == AppSection.shop) _shopInitialTab = 0;
  });

  void _openShopCoins() => setState(() {
    _shopInitialTab = 2;
    section = AppSection.shop;
  });

  /// One streak-hub entry for every surface (top-bar flame on each tab, the
  /// home quest tile, profile streak badges) so quest CTAs route identically.
  void _openStreakHub() =>
      showStreakCalendar(context, onQuestNavigate: _routeQuest);

  void _routeQuest(QuestDestination destination) {
    switch (destination) {
      case QuestDestination.pitchDuel:
        _openQuestGame(ArcadeGame.pitchDuel);
      case QuestDestination.penaltyShootout:
        _openQuestGame(ArcadeGame.penaltyShootout);
      case QuestDestination.guessPlayer:
        _openQuestGame(ArcadeGame.footballGuessPlayer);
      case QuestDestination.prediction:
        setState(() {
          section = AppSection.predictions;
          _predictionTab = 0;
        });
      case QuestDestination.pick:
        final market = context
            .read<PicksCubit>()
            .state
            .markets
            .where((market) => market.canBuy)
            .firstOrNull;
        if (market != null) {
          _openMarket(market.id);
        } else {
          setState(() {
            section = AppSection.predictions;
            _predictionTab = 0;
            _predictionMatchSportTab = 0;
          });
        }
    }
  }

  bool _reminderOpen = false;

  /// Escalating streak reminder (nudge → AT RISK). Only fires on the bare shell
  /// — never over onboarding, reveals, a pushed game/hub, or a queued moment —
  /// and is logged before showing so a killed app can't re-spam it.
  Future<void> _maybeShowStreakReminder() async {
    if (_reminderOpen || !mounted) return;
    final game = context.read<GameBloc>().state;
    final achievements = context.read<AchievementCelebrationController>().state;
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (game.loading ||
        _onboardingLoading ||
        !_onboardingComplete ||
        _onboardingRewardStatus == OnboardingRewardStatus.pending ||
        game.pendingPackReveal != null ||
        !onTop ||
        game.streak.celebrationQueue.isNotEmpty ||
        game.questRewardCoins > 0 ||
        game.unlocks.pendingReveals.isNotEmpty ||
        achievements.holding ||
        achievements.queue.isNotEmpty) {
      return;
    }
    _reminderOpen = true;
    try {
      final now = DateTime.now();
      final log = await _storage.loadStreakReminderLog();
      if (!mounted) return;
      final streak = context.read<GameBloc>().state.streak;
      final kind = streakReminderDue(streak: streak, now: now, log: log);
      if (kind == null) return;
      await _storage.saveStreakReminderLog(log.markShown(kind, now));
      if (!mounted) return;
      final action = await showStreakReminder(
        context,
        kind: kind,
        streak: streak,
        now: now,
      );
      if (!mounted || action == null) return;
      switch (action) {
        case StreakReminderAction.openHub:
          _openStreakHub();
        case StreakReminderAction.play:
          _routeQuest(QuestDestination.pitchDuel);
        case StreakReminderAction.predict:
          _routeQuest(QuestDestination.prediction);
        case StreakReminderAction.pick:
          _routeQuest(QuestDestination.pick);
      }
    } finally {
      _reminderOpen = false;
    }
  }

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
    await _storage.saveFollowedSportNames([
      for (final sport in result.sports) sport.name,
    ]);
    await _storage.saveFollowedLeagueIds(result.followedLeagueIds);
    await _storage.saveFavoriteTeams(result.favoriteTeams);
    final rewardPending =
        _onboardingRewardStatus != OnboardingRewardStatus.seen;
    if (rewardPending) {
      await _storage.saveOnboardingRewardStatus(OnboardingRewardStatus.pending);
    }
    await _storage.saveOnboardingComplete(true);
    if (!mounted) return;
    // Starts the gated unlock ladder: only the home sport (and its first game)
    // is open, and both hub strips land on it.
    context.read<GameBloc>().add(HomeSportChosen(result.primarySport));
    setState(() {
      _selectedAvatarId = result.avatarId;
      _onboardingComplete = true;
      _predictionMatchSportTab = hubIndexForSport(result.primarySport);
      _predictionGamesSportTab = hubIndexForSport(result.primarySport);
      if (rewardPending) {
        _onboardingRewardStatus = OnboardingRewardStatus.pending;
      }
    });
    if (rewardPending) {
      context.read<GameBloc>().add(OnboardingRewardClaimed());
    }
    // The clubs just picked drive the match feed's YOUR CLUB pin.
    await context.read<PredictionCubit>().refreshFollowing();
  }

  Future<void> _dismissOnboardingReward() async {
    if (_onboardingRewardStatus != OnboardingRewardStatus.pending ||
        _onboardingRewardDismissing) {
      return;
    }
    _onboardingRewardDismissing = true;
    await _storage.saveOnboardingRewardStatus(OnboardingRewardStatus.seen);
    if (!mounted) return;
    setState(() {
      _onboardingRewardStatus = OnboardingRewardStatus.seen;
      _onboardingRewardDismissing = false;
    });
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
      _onboardingRewardDismissing = false;
    });
  }

  /// Daily-quest game CTAs name football modes; a player whose home sport is
  /// something else (or who has not reached that mode yet) is sent to their
  /// home sport's current Beginner's Quest game instead of a lock sheet.
  void _openQuestGame(ArcadeGame preferred) {
    final unlocks = context.read<GameBloc>().state.unlocks;
    if (unlocks.isGameUnlocked(preferred)) {
      _openArcadeGame(preferred);
      return;
    }
    final home = unlocks.homeSport ?? Sport.football;
    _openArcadeGame(unlocks.currentStep(home) ?? sportGameLadder[home]!.first);
  }

  /// The single, guarded entry into every GAMES-tab mode. A locked game (or a
  /// game of a locked sport) opens its unlock sheet instead of launching.
  void _openArcadeGame(ArcadeGame game) {
    final unlocks = context.read<GameBloc>().state.unlocks;
    if (!unlocks.isGameUnlocked(game)) {
      showLockedGameSheet(context, game, onPlay: _openArcadeGame);
      return;
    }
    switch (game) {
      case ArcadeGame.pitchDuel:
        _openGame();
      case ArcadeGame.penaltyShootout:
        _openShootout();
      case ArcadeGame.footballChess:
        _openFootballChess();
      case ArcadeGame.footballBingo:
        _openFootballBingo();
      case ArcadeGame.footballGuessPlayer:
        _openGuessPlayer();
      case ArcadeGame.cricketGuessPlayer:
        _openCricketGuessPlayer();
      case ArcadeGame.basketballGuessPlayer:
        _openBasketballGuessPlayer();
      case ArcadeGame.finalOver:
        _openFinalOver();
      case ArcadeGame.hoopDuel:
        _openBasketball();
      case ArcadeGame.grandPrixDash:
        _openGrandPrix();
      case ArcadeGame.guessDriver:
        _openF1GuessDriver();
      case ArcadeGame.tennisRally:
        _openTennisRally();
      case ArcadeGame.guessWinner:
        _openTennisGuessWinner();
      case ArcadeGame.footballQuiz ||
          ArcadeGame.cricketQuiz ||
          ArcadeGame.basketballQuiz ||
          ArcadeGame.motorsportQuiz ||
          ArcadeGame.tennisQuiz:
        _openQuiz(game.sport);
    }
  }

  /// SPORT UNLOCKED → land on that sport's GAMES tab, where its quest starts.
  void _enterSport(Sport sport) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _openSportGames(sport);
  }

  /// Deck Locker → the sport's GAMES tab, where launching a game claims that
  /// sport's starter pack (see `_enterCricketGameFlow` and friends below) and
  /// fills in the loadout the player just found locked.
  void _openSportGames(Sport sport) {
    setState(() {
      section = AppSection.predictions;
      _predictionTab = 1; // GAMES (0 = MATCH)
      _predictionGamesSportTab = hubIndexForSport(sport);
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

  /// Enter Final Over from Cricket GAMES. The rules engine lives in the
  /// `final_over` package; the lobby, pitch and HUD are ours.
  void _openFinalOver() => _enterCricketGameFlow(_pushFinalOver);

  void _pushFinalOver() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => FinalOverHub(onExit: navigator.pop),
      ),
    );
  }

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

  void _enterTennisGameFlow(VoidCallback push) {
    final bloc = context.read<GameBloc>();
    if (!bloc.state.tennisStarterPackClaimed) {
      _pendingGameLaunch = push;
      _pendingGameLaunchKind = _PendingGameLaunchKind.tennis;
      bloc.add(TennisStarterPackOpened());
      return;
    }
    push();
  }

  void _enterGrandPrixGameFlow(VoidCallback push) {
    final bloc = context.read<GameBloc>();
    if (!bloc.state.grandPrixStarterPackClaimed) {
      _pendingGameLaunch = push;
      _pendingGameLaunchKind = _PendingGameLaunchKind.grandPrix;
      bloc.add(GrandPrixStarterPackOpened());
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

  void _openGuessPlayer() => _openGuessPlayerFor(
    sport: Sport.football,
    timelines: footballGuessTimelines,
    allPlayers: footballPlayerCards,
  );

  void _openBasketballGuessPlayer() => _openGuessPlayerFor(
    sport: Sport.basketball,
    timelines: basketballGuessTimelines,
    allPlayers: basketballPlayerCards,
  );

  void _openCricketGuessPlayer() => _openGuessPlayerFor(
    sport: Sport.cricket,
    timelines: cricketGuessTimelines,
    allPlayers: cricketPlayerCards,
  );

  void _openGuessPlayerFor({
    required Sport sport,
    required List<GuessPlayerTimeline> timelines,
    required List<PlayerCard> allPlayers,
  }) {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GuessPlayerTabContent(
          sport: sport,
          timelines: timelines,
          allPlayers: allPlayers,
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  void _openF1GuessDriver() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GuessDriverTabContent(
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
        ),
      ),
    );
  }

  void _openTennisGuessWinner() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GuessWinnerTabContent(
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

  /// Open Grand Prix Dash from the GAMES tab's F1 section. First visit grants
  /// a random bronze motorsport driver via the shared pack-reveal flow.
  void _openGrandPrix() => _enterGrandPrixGameFlow(_pushGrandPrix);

  void _openGrandPrixShop() {
    final navigator = Navigator.of(context);
    navigator.pop();
    setState(() => _shopInitialTab = 3);
    _go(AppSection.shop);
  }

  void _openBasketballShop() {
    final navigator = Navigator.of(context);
    navigator.pop();
    setState(() => _shopInitialTab = 3);
    _go(AppSection.shop);
  }

  void _pushGrandPrix() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GrandPrixTabContent(
          onNavigate: (next) {
            navigator.pop();
            _go(next);
          },
          onBrowseShop: _openGrandPrixShop,
        ),
      ),
    );
  }

  /// Enter Tennis Rally from the GAMES tab's Tennis section.
  void _openTennisRally() => _enterTennisGameFlow(_pushTennisRally);

  /// Push Tennis Rally once its starter pack gate is satisfied.
  void _pushTennisRally() {
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
          onBrowseShop: _openBasketballShop,
        ),
      ),
    );
  }

  void _openMatch(SportMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MatchDetailScreen(match: match)),
    );
  }

  void _openMarket(String marketId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketDetailScreen(marketId: marketId),
      ),
    );
  }

  void _openLeague(League league, {bool openFixturesTab = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<LeagueStatsCubit>(
          // Name and short code are passed alongside the id because the same
          // competition reaches here under several ids (curated `eng.1`,
          // follow-list `epl`, or ESPN's runtime numeric id) — the stats
          // package resolves on whichever of the three matches.
          create: (_) => LeagueStatsCubit(
            league.id,
            leagueName: league.name,
            shortCode: league.shortCode,
          )..load(),
          child: LeagueDetailScreen(
            league: league,
            openFixturesTab: openFixturesTab,
          ),
        ),
      ),
    );
  }

  void _openLeagueGames(League league) =>
      _openLeague(league, openFixturesTab: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<GameBloc, GameState>(
        listenWhen: (previous, current) =>
            previous.pendingPackReveal != current.pendingPackReveal ||
            previous.loading != current.loading ||
            previous.streak.celebrationQueue !=
                current.streak.celebrationQueue ||
            previous.questRewardCoins != current.questRewardCoins,
        listener: (context, state) {
          // Re-check the streak reminder once loading finishes and whenever a
          // queued moment clears (its guards decide whether it can show).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncRevealGate();
            _maybeShowStreakReminder();
          });
          // Hub tabs start on TRENDING; a gated player's first view after a
          // relaunch is their home sport instead (TRENDING stays reachable
          // once they own a second sport).
          final home = state.unlocks.homeSport;
          if (!_homeTabsSeeded && !state.loading && home != null) {
            _homeTabsSeeded = true;
            if (state.unlocks.gated) {
              setState(() {
                if (_predictionMatchSportTab == hubTrendingTabIndex) {
                  _predictionMatchSportTab = hubIndexForSport(home);
                }
                if (_predictionGamesSportTab == hubTrendingTabIndex) {
                  _predictionGamesSportTab = hubIndexForSport(home);
                }
              });
            }
          }
          final pending = _pendingGameLaunch;
          final ready = switch (_pendingGameLaunchKind) {
            _PendingGameLaunchKind.cricket => state.cricketStarterPackClaimed,
            _PendingGameLaunchKind.basketball =>
              state.basketballStarterPackClaimed,
            _PendingGameLaunchKind.tennis => state.tennisStarterPackClaimed,
            _PendingGameLaunchKind.grandPrix =>
              state.grandPrixStarterPackClaimed,
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
          if (_onboardingRewardStatus == OnboardingRewardStatus.pending) {
            OzCoinLedgerEntry? rewardEntry;
            for (final entry in state.coinLedger) {
              if (entry.source == OzCoinTransactionSource.onboardingReward) {
                rewardEntry = entry;
                break;
              }
            }
            if (rewardEntry == null) {
              return const ColoredBox(color: Cyber.bg);
            }
            return OnboardingCoinRewardAnimation(
              key: const ValueKey('onboarding-coin-reward'),
              amount: rewardEntry.delta,
              balanceAfter: rewardEntry.balanceAfter,
              onComplete: _dismissOnboardingReward,
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
              onOpenStreakHub: _openStreakHub,
            ),
            AppSection.leaderboard => LeaderboardScreen(
              onNavigate: _go,
              onAddCoins: _openShopCoins,
              onChallenge: _openChallenge,
              onOpenStreakHub: _openStreakHub,
            ),
            AppSection.profile => ProfileScreen(
              onNavigate: _go,
              onLogout: _logoutFromProfile,
              onChallenge: _openChallenge,
              onOpenSportGames: _openSportGames,
              onOpenStreakHub: _openStreakHub,
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
              onOpenMarket: _openMarket,
              onOpenLeague: _openLeague,
              onOpenLeagueGames: _openLeagueGames,
              onOpenArcadeGame: _openArcadeGame,
              onOpenGame: () => _openArcadeGame(ArcadeGame.pitchDuel),
              onOpenShootout: () => _openArcadeGame(ArcadeGame.penaltyShootout),
              onOpenQuiz: (sport) => _openArcadeGame(quizGameFor(sport)),
              onOpenFootballBingo: () =>
                  _openArcadeGame(ArcadeGame.footballBingo),
              onOpenFootballChess: () =>
                  _openArcadeGame(ArcadeGame.footballChess),
              onOpenFinalOver: () => _openArcadeGame(ArcadeGame.finalOver),
              onOpenGuessPlayer: () =>
                  _openArcadeGame(ArcadeGame.footballGuessPlayer),
              onOpenBasketballGuessPlayer: () =>
                  _openArcadeGame(ArcadeGame.basketballGuessPlayer),
              onOpenCricketGuessPlayer: () =>
                  _openArcadeGame(ArcadeGame.cricketGuessPlayer),
              onOpenGrandPrix: () => _openArcadeGame(ArcadeGame.grandPrixDash),
              onOpenF1GuessDriver: () =>
                  _openArcadeGame(ArcadeGame.guessDriver),
              onOpenTennisGuessWinner: () =>
                  _openArcadeGame(ArcadeGame.guessWinner),
              onOpenBasketball: () => _openArcadeGame(ArcadeGame.hoopDuel),
              onOpenTennisRally: () => _openArcadeGame(ArcadeGame.tennisRally),
              onAddCoins: _openShopCoins,
              onOpenStreakHub: _openStreakHub,
            ),
          };
          return content;
        },
      ),
    );
  }
}
