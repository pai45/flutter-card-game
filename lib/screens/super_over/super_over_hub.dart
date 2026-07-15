import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/super_over/super_over_bloc.dart';
import '../../blocs/super_over/super_over_event.dart';
import '../../blocs/super_over/super_over_state.dart';
import '../../config/theme.dart';
import '../../games/super_over/super_over_engine.dart';
import '../../games/super_over/super_over_game.dart';
import '../../models/super_over.dart';
import '../../models/super_over_stats.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/sound_effects.dart';
import 'super_over_batting_unit_editor.dart';
import 'super_over_lobby_screen.dart';
import 'super_over_pre_match_screen.dart';
import 'widgets/effects_overlay.dart';
import 'widgets/final_stand_coach_overlay.dart';
import 'widgets/final_stand_match_hud.dart';
import 'widgets/super_over_pause_overlay.dart';
import 'widgets/super_over_result.dart';

class SuperOverHub extends StatelessWidget {
  const SuperOverHub({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SuperOverBloc(SecureGameStorage()),
      child: _SuperOverRouter(onExit: onExit),
    );
  }
}

enum _SuperOverPage { landing, unitEditor, preMatch, match }

class _SuperOverRouter extends StatefulWidget {
  const _SuperOverRouter({required this.onExit});

  final VoidCallback onExit;

  @override
  State<_SuperOverRouter> createState() => _SuperOverRouterState();
}

class _SuperOverRouterState extends State<_SuperOverRouter>
    with WidgetsBindingObserver {
  final SecureGameStorage _storage = SecureGameStorage();
  late final SuperOverGame _game;

  _SuperOverPage _page = _SuperOverPage.landing;
  SuperOverStats _stats = const SuperOverStats();
  SuperOverSettings _settings = const SuperOverSettings();
  CricketJersey _jersey = CricketJersey.nightCyan;
  SuperOverMode _selectedMode = SuperOverMode.chase;
  SuperOverDifficulty _difficulty = SuperOverDifficulty.pro;
  SuperOverMatchConfig? _preparedConfig;
  SuperOverObjective? _preparedObjective;
  int? _preparedTarget;
  bool _paused = false;
  bool _showResult = false;
  bool _rewardsDispatched = false;
  bool _tutorialVisible = false;
  bool _resumeNeedsNextBall = false;
  int _feedbackBall = -1;
  Timer? _targetRevealTimer;
  Timer? _nextBallTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = SuperOverGame(
      initialState: context.read<SuperOverBloc>().state,
      onPhaseChanged: (phase) {
        if (!mounted) return;
        context.read<SuperOverBloc>().add(SuperOverPhaseChanged(phase));
      },
      onInputArmed: () {
        if (!mounted) return;
        if (_settings.soundEnabled) playSound(SoundEffect.cricketRelease);
        context.read<SuperOverBloc>().add(const SuperOverInputArmed());
      },
      onBallBounce: () {
        if (!mounted || !_settings.soundEnabled) return;
        playSound(SoundEffect.cricketBounce);
      },
      onSwingLocked: () {
        if (!mounted) return;
        context.read<SuperOverBloc>().add(const SuperOverSwingLocked());
      },
      onShotResolved: (intent) {
        if (!mounted) return;
        context.read<SuperOverBloc>().add(
          SuperOverShotResolved(intent: intent),
        );
      },
      onNoInput: () {
        if (!mounted) return;
        context.read<SuperOverBloc>().add(
          const SuperOverShotResolved(noInput: true),
        );
      },
      onOutcomeAnimationComplete: _handleOutcomeAnimationComplete,
    );
    _loadProfileAndSnapshot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_page != _SuperOverPage.match || _showResult) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pauseGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _targetRevealTimer?.cancel();
    _nextBallTimer?.cancel();
    AudioController.instance.stopLoop();
    super.dispose();
  }

  Future<void> _loadProfileAndSnapshot() async {
    final profile = await _storage.loadSuperOverStats();
    final snapshot = await _storage.loadSuperOverMatchSnapshot();
    if (!mounted) return;
    setState(() {
      _stats = profile;
      _settings = profile.settings;
      _difficulty = profile.difficulty;
      _jersey = profile.lastJersey;
    });
    if (snapshot == null) return;
    final deck = context.read<GameBloc>().state.deckBatsmen;
    final deckIds = deck.map((card) => card.id).toList();
    final resumable =
        deck.length == 3 &&
        snapshot.config.battingCardIds.every(deckIds.contains);
    if (!resumable) {
      await _storage.clearSuperOverMatchSnapshot();
      return;
    }
    final bloc = context.read<SuperOverBloc>();
    bloc.add(SuperOverSnapshotRestored(snapshot: snapshot, battingOrder: deck));
    await bloc.stream
        .firstWhere((state) => state.config?.matchId == snapshot.config.matchId)
        .timeout(const Duration(seconds: 2), onTimeout: () => bloc.state);
    if (!mounted) return;
    setState(() {
      _page = _SuperOverPage.match;
      _selectedMode = snapshot.config.mode;
      _difficulty = snapshot.config.difficulty;
      _tutorialVisible = snapshot.config.tutorial;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<SuperOverBloc>().state;
      _game.syncState(state);
      _game.startDelivery(state);
      _startAmbient();
    });
  }

  void _preparePreMatch({bool tutorial = false}) {
    final gameState = context.read<GameBloc>().state;
    if (!gameState.superOverDeckReady) {
      setState(() => _page = _SuperOverPage.unitEditor);
      return;
    }
    final now = DateTime.now();
    final seed = now.microsecondsSinceEpoch & 0x7fffffff;
    final config = SuperOverMatchConfig(
      matchId: 'so-${now.microsecondsSinceEpoch}',
      seed: seed,
      mode: tutorial ? SuperOverMode.chase : _selectedMode,
      difficulty: tutorial ? SuperOverDifficulty.rookie : _difficulty,
      level: gameState.progression.playerLevel,
      battingCardIds: gameState.deckBatsmen.map((card) => card.id).toList(),
      jerseyId: _jersey.name,
      tutorial: tutorial,
    );
    final engine = SuperOverEngine(seed: seed);
    final target = config.mode == SuperOverMode.chase
        ? engine.targetForConfig(config)
        : null;
    setState(() {
      _preparedConfig = config;
      _preparedTarget = target;
      _preparedObjective = engine.objectiveForConfig(config, target: target);
      _page = _SuperOverPage.preMatch;
      _tutorialVisible = tutorial;
    });
  }

  void _changePreparedDifficulty(SuperOverDifficulty difficulty) {
    final current = _preparedConfig;
    if (current == null || current.tutorial) return;
    final config = SuperOverMatchConfig(
      matchId: current.matchId,
      seed: current.seed,
      mode: current.mode,
      difficulty: difficulty,
      level: current.level,
      battingCardIds: current.battingCardIds,
      jerseyId: current.jerseyId,
    );
    final engine = SuperOverEngine(seed: current.seed);
    final target = config.mode == SuperOverMode.chase
        ? engine.targetForConfig(config)
        : null;
    final settings = _settings.copyWith(difficulty: difficulty);
    setState(() {
      _difficulty = difficulty;
      _settings = settings;
      _preparedConfig = config;
      _preparedTarget = target;
      _preparedObjective = engine.objectiveForConfig(config, target: target);
    });
    context.read<SuperOverBloc>().add(SuperOverSettingsChanged(settings));
  }

  void _startPreparedMatch() {
    final config = _preparedConfig;
    if (config == null) return;
    final gameState = context.read<GameBloc>().state;
    _targetRevealTimer?.cancel();
    _nextBallTimer?.cancel();
    _feedbackBall = -1;
    _game.resumeEngine();
    setState(() {
      _page = _SuperOverPage.match;
      _showResult = false;
      _paused = false;
      _rewardsDispatched = false;
    });
    final bloc = context.read<SuperOverBloc>();
    bloc.add(
      SuperOverStarted(
        battingOrder: gameState.deckBatsmen,
        mode: config.mode,
        playerLevel: config.level,
        jersey: _jersey,
        difficulty: config.difficulty,
        settings: _settings.copyWith(difficulty: config.difficulty),
        config: config,
        tutorial: config.tutorial,
      ),
    );
    unawaited(_armStartedMatch(config.matchId));
    _startAmbient();
  }

  Future<void> _armStartedMatch(String matchId) async {
    final bloc = context.read<SuperOverBloc>();
    var state = bloc.state;
    if (state.config?.matchId != matchId) {
      try {
        state = await bloc.stream
            .firstWhere((value) => value.config?.matchId == matchId)
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        return;
      }
    }
    if (!mounted ||
        _page != _SuperOverPage.match ||
        state.config?.matchId != matchId) {
      return;
    }
    _game.syncState(state);
    if (state.phase == SuperOverPhase.targetReveal) {
      _scheduleFirstBall();
    } else if (state.phase == SuperOverPhase.ballSetup) {
      _game.startDelivery(state);
    }
  }

  void _scheduleFirstBall() {
    _targetRevealTimer?.cancel();
    _targetRevealTimer = Timer(const Duration(milliseconds: 1450), () {
      if (!mounted || _paused) return;
      context.read<SuperOverBloc>().add(
        const SuperOverPhaseChanged(SuperOverPhase.ballSetup),
      );
    });
  }

  void _handleOutcomeAnimationComplete() {
    if (!mounted) return;
    final state = context.read<SuperOverBloc>().state;
    if (state.isOver) {
      setState(() => _showResult = true);
      AudioController.instance.stopLoop(fadeMs: 250);
      return;
    }
    _nextBallTimer?.cancel();
    _nextBallTimer = Timer(const Duration(milliseconds: 420), () {
      if (!mounted || _paused) return;
      context.read<SuperOverBloc>().add(const SuperOverNextBallRequested());
    });
  }

  void _handleBatTap() {
    final state = context.read<SuperOverBloc>().state;
    if (state.phase == SuperOverPhase.targetReveal) {
      _targetRevealTimer?.cancel();
      context.read<SuperOverBloc>().add(
        const SuperOverPhaseChanged(SuperOverPhase.ballSetup),
      );
      return;
    }
    if (!state.canTap) return;
    if (_settings.hapticsEnabled) HapticFeedback.lightImpact();
    _game.tapBat(sector: state.selectedSector, style: state.selectedShotStyle);
  }

  void _playOutcomeFeedback(SuperOverState state) {
    if (state.lastOutcome == null || state.ballsFaced == _feedbackBall) return;
    _feedbackBall = state.ballsFaced;
    if (_settings.soundEnabled) {
      playSound(switch (state.timingTier) {
        TimingTier.perfect => SoundEffect.cricketPerfect,
        TimingTier.great => SoundEffect.cricketGreat,
        TimingTier.good => SoundEffect.cricketGood,
        TimingTier.edgePoor => SoundEffect.cricketEdge,
        TimingTier.miss || null =>
          state.lastOutcome == ShotOutcome.bowled
              ? SoundEffect.cricketStumps
              : SoundEffect.cricketKeeper,
      });
      if (state.lastOutcome == ShotOutcome.six) {
        playSound(SoundEffect.cricketSix);
      } else if (state.lastOutcome == ShotOutcome.four) {
        playSound(SoundEffect.cricketBoundary);
      }
    }
    if (!_settings.hapticsEnabled) return;
    switch (state.lastOutcome) {
      case ShotOutcome.six || ShotOutcome.bowled:
        HapticFeedback.heavyImpact();
      case ShotOutcome.four || ShotOutcome.caught:
        HapticFeedback.mediumImpact();
      case ShotOutcome.one || ShotOutcome.two || ShotOutcome.three:
        HapticFeedback.selectionClick();
      case ShotOutcome.dot || null:
        break;
    }
  }

  void _pauseGame() {
    if (_paused || _showResult || _page != _SuperOverPage.match) return;
    _resumeNeedsNextBall = _nextBallTimer?.isActive ?? false;
    _targetRevealTimer?.cancel();
    _nextBallTimer?.cancel();
    _game.pauseEngine();
    context.read<SuperOverBloc>().add(const SuperOverPaused());
    setState(() => _paused = true);
  }

  void _resumeGame() {
    if (!_paused) return;
    _game.resumeEngine();
    context.read<SuperOverBloc>().add(const SuperOverResumed());
    setState(() => _paused = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<SuperOverBloc>().state;
      if (_resumeNeedsNextBall) {
        _resumeNeedsNextBall = false;
        context.read<SuperOverBloc>().add(const SuperOverNextBallRequested());
      } else {
        _game.startDelivery(state);
      }
    });
  }

  void _restartGame() {
    final tutorial =
        context.read<SuperOverBloc>().state.config?.tutorial ?? false;
    context.read<SuperOverBloc>().add(const SuperOverReset(toLanding: false));
    setState(() {
      _paused = false;
      _showResult = false;
    });
    _preparePreMatch(tutorial: tutorial);
    _startPreparedMatch();
  }

  void _quitToLanding() {
    _game.resumeEngine();
    AudioController.instance.stopLoop(fadeMs: 200);
    context.read<SuperOverBloc>().add(const SuperOverReset());
    setState(() {
      _paused = false;
      _showResult = false;
      _page = _SuperOverPage.landing;
      _tutorialVisible = false;
    });
    _reloadStats();
  }

  Future<void> _changeSettings(SuperOverSettings settings) async {
    setState(() {
      _settings = settings;
      _difficulty = settings.difficulty;
      _stats = _stats.copyWith(
        settings: settings,
        difficulty: settings.difficulty,
      );
    });
    context.read<SuperOverBloc>().add(SuperOverSettingsChanged(settings));
    _game.reducedMotion = settings.reducedMotion;
    if (settings.musicEnabled && _page == _SuperOverPage.match) {
      _startAmbient();
    } else if (!settings.musicEnabled) {
      await AudioController.instance.stopLoop(fadeMs: 180);
    }
  }

  void _startAmbient() {
    if (_settings.musicEnabled) {
      AudioController.instance.playLoop(MusicTrack.superOverAmbient);
    }
    if (_settings.crowdEnabled) {
      playSound(SoundEffect.cricketCrowdPressure);
    }
  }

  SuperOverMatchSummary _stableSummary(SuperOverMatchSummary summary) {
    final record = summary.mode == SuperOverMode.scoreAttack
        ? summary.score > _stats.scoreAttackHighScore
        : summary.score > _stats.highScore;
    if (summary.isNewRecord == record) return summary;
    return SuperOverMatchSummary.fromJson({
      ...summary.toJson(),
      'isNewRecord': record,
    });
  }

  Future<void> _selectJersey(CricketJersey jersey) async {
    if (jersey == _jersey) return;
    final updated = _stats.copyWith(lastJersey: jersey);
    setState(() {
      _jersey = jersey;
      _stats = updated;
    });
    await _storage.saveSuperOverStats(updated);
  }

  Future<void> _reloadStats() async {
    final stats = await _storage.loadSuperOverStats();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _skipTutorial() async {
    final updated = _stats.copyWith(
      tutorialCompleted: true,
      tutorialVersion: 1,
    );
    await _storage.saveSuperOverStats(updated);
    if (!mounted) return;
    _stats = updated;
    context.read<SuperOverBloc>().add(const SuperOverReset(toLanding: false));
    _preparePreMatch();
  }

  Future<void> _markTutorialComplete() async {
    if (!_tutorialVisible) return;
    final updated = _stats.copyWith(
      tutorialCompleted: true,
      tutorialVersion: 1,
    );
    await _storage.saveSuperOverStats(updated);
    if (mounted) {
      setState(() {
        _stats = updated;
        _tutorialVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_page) {
      case _SuperOverPage.unitEditor:
        return SuperOverBattingUnitEditor(
          onBack: () => setState(() => _page = _SuperOverPage.landing),
          onContinue: _preparePreMatch,
        );
      case _SuperOverPage.preMatch:
        final config = _preparedConfig;
        if (config == null || _preparedObjective == null) {
          return const Scaffold(
            backgroundColor: Cyber.bg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return SuperOverPreMatchScreen(
          mode: config.mode,
          difficulty: config.difficulty,
          battingOrder: context.read<GameBloc>().state.deckBatsmen,
          jersey: _jersey,
          stats: _stats,
          target: _preparedTarget,
          objective: _preparedObjective!,
          onDifficultyChanged: _changePreparedDifficulty,
          onStart: _startPreparedMatch,
          onBack: () => setState(() => _page = _SuperOverPage.landing),
        );
      case _SuperOverPage.match:
        return _buildMatch();
      case _SuperOverPage.landing:
        return SuperOverLobbyScreen(
          onBack: widget.onExit,
          onStartGame: () =>
              _preparePreMatch(tutorial: !_stats.tutorialCompleted),
          onEditDeck: () => setState(() => _page = _SuperOverPage.unitEditor),
          onJerseySelected: _selectJersey,
          selectedMode: _selectedMode,
          onModeChanged: (mode) => setState(() => _selectedMode = mode),
          stats: _stats,
          onTutorial: () => _preparePreMatch(tutorial: true),
        );
    }
  }

  Widget _buildMatch() {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: BlocConsumer<SuperOverBloc, SuperOverState>(
        listenWhen: (previous, current) =>
            previous.phase != current.phase ||
            previous.isOver != current.isOver ||
            previous.lastOutcome != current.lastOutcome ||
            previous.summary != current.summary,
        listener: (context, state) {
          _game.syncState(state);
          if (state.phase == SuperOverPhase.targetReveal) {
            _scheduleFirstBall();
          } else if (state.phase == SuperOverPhase.ballSetup) {
            _game.startDelivery(state);
          }
          _playOutcomeFeedback(state);
          if (state.isOver && state.summary != null) {
            if (state.summary!.tutorial) _markTutorialComplete();
            if (!state.summary!.tutorial && !_rewardsDispatched) {
              _rewardsDispatched = true;
              context.read<GameBloc>().add(
                SuperOverFinished(summary: _stableSummary(state.summary!)),
              );
            }
          }
        },
        builder: (context, state) {
          _game.reducedMotion =
              _settings.reducedMotion ||
              MediaQuery.disableAnimationsOf(context);
          return Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
              Positioned.fill(child: EffectsOverlay(state: state)),
              if (!state.isOver || !_showResult)
                Positioned.fill(
                  child: FinalStandMatchHud(
                    state: state,
                    onBatTap: _handleBatTap,
                    onExit: _pauseGame,
                    onPause: _pauseGame,
                    onSectorSelected: (sector) {
                      if (_settings.hapticsEnabled) {
                        HapticFeedback.selectionClick();
                      }
                      context.read<SuperOverBloc>().add(
                        SuperOverSectorSelected(sector),
                      );
                    },
                    onShotStyleSelected: (style) {
                      if (_settings.hapticsEnabled) {
                        HapticFeedback.selectionClick();
                      }
                      context.read<SuperOverBloc>().add(
                        SuperOverShotStyleSelected(style),
                      );
                    },
                  ),
                ),
              if (_tutorialVisible && !state.isOver && !_paused)
                Positioned.fill(
                  child: FinalStandCoachOverlay(
                    state: state,
                    onSkip: _skipTutorial,
                  ),
                ),
              if (state.isOver && _showResult)
                Positioned.fill(
                  child: SuperOverResult(
                    state: state,
                    settings: _settings,
                    previousHigh: state.mode == SuperOverMode.scoreAttack
                        ? _stats.scoreAttackHighScore
                        : _stats.highScore,
                    onPlayAgain: () {
                      _preparePreMatch(tutorial: false);
                    },
                    onChangeMode: _quitToLanding,
                    onChangeBatters: () {
                      context.read<SuperOverBloc>().add(const SuperOverReset());
                      setState(() => _page = _SuperOverPage.unitEditor);
                    },
                    onExit: widget.onExit,
                  ),
                ),
              if (_paused)
                Positioned.fill(
                  child: SuperOverPauseOverlay(
                    settings: _settings,
                    onSettingsChanged: _changeSettings,
                    onResume: _resumeGame,
                    onRestart: _restartGame,
                    onQuit: _quitToLanding,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
