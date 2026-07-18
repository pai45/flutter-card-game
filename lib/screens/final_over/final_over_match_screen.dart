import 'dart:async';

import 'package:final_over/final_over.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/final_over/final_over_cubit.dart';
import '../../blocs/final_over/final_over_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../config/theme.dart';
import '../../data/final_over_kits.dart';
import '../../games/final_over/final_over_game.dart';
import '../../models/final_over.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/final_over_controls.dart';
import 'widgets/final_over_hud.dart';
import 'widgets/final_over_overlays.dart';
import 'widgets/final_over_result.dart';

/// The chase: a full-bleed Flame pitch under the score HUD, sting banners, the
/// two-faced control deck, and the intro / pause / result
/// overlays.
///
/// Three owners, cleanly separated — the `final_over` package's
/// [MatchController] owns the rules, [FinalOverGame] owns the 60fps projection
/// of them, and [FinalOverCubit] owns the coarse session phase. This screen is
/// the wiring between them: it maps engine events to sound and haptics, and it
/// pays the player exactly once.
class FinalOverMatchScreen extends StatefulWidget {
  const FinalOverMatchScreen({
    required this.config,
    required this.onExit,
    super.key,
  });

  final FinalOverMatchConfig config;
  final VoidCallback onExit;

  @override
  State<FinalOverMatchScreen> createState() => _FinalOverMatchScreenState();
}

class _FinalOverMatchScreenState extends State<FinalOverMatchScreen>
    with WidgetsBindingObserver {
  late final FinalOverCubit _cubit;
  late final MatchController _controller;
  late final FinalOverGame _game;

  bool _rewardsDispatched = false;
  bool _paused = false;
  double _controlStackHeight = 116;

  // Tallied from the engine's own ball ledger, never counted here.
  int _sixes = 0;
  int _fours = 0;
  int _bestCombo = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = context.read<FinalOverCubit>();

    final reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    // The tier is the difficulty: it sets the timing windows, the wickets in
    // hand and what OVERDRIVE costs. See [FinalOverTierX.tuning].
    _controller = MatchController(tuning: widget.config.tier.tuning);
    _game = FinalOverGame(
      controller: _controller,
      kit: finalOverKitById(widget.config.kitId),
      opponentKit: finalOverOpponentKit(widget.config.kitId),
      onEvents: _onEvent,
      reducedMotion: reducedMotion,
    );
    _controller.startMatch(
      seed: widget.config.seed,
      target: widget.config.target,
    );

    AudioController.instance.playLoop(MusicTrack.matchAmbient);
  }

  /// CHASE AGAIN builds the next match on the shared cubit and *then* replaces
  /// this route, so the new screen is already up — and already owns the cubit —
  /// by the time this one is torn down. Anything global we clean up on the way
  /// out (the session, the music) would land on the new chase instead of ours.
  bool get _replacedByNextChase =>
      _cubit.state.config?.matchId != widget.config.matchId;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_replacedByNextChase) {
      AudioController.instance.stopLoop();
      // Walking out mid-chase discards it — no stats, no XP.
      final phase = _cubit.state.phase;
      if (phase == FinalOverPhase.intro || phase == FinalOverPhase.playing) {
        _cubit.abandonMatch();
      }
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_paused) {
      _game.backgrounded();
      if (mounted) setState(() => _paused = true);
    }
  }

  // ── engine events → sound / haptics / cubit beats ─────────────────────────
  void _onEvent(GameplayEvent event) {
    final s = _controller.state;
    switch (event.type) {
      case GameplayEventType.ballReleased:
        playSound(SoundEffect.cricketRelease);
      case GameplayEventType.contactResolved:
        final outcome = s.contactOutcome;
        if (outcome == null) break;
        switch (outcome.timing) {
          case TimingGrade.perfect:
            playSound(SoundEffect.cricketPerfect);
            HapticFeedback.mediumImpact();
          case TimingGrade.good:
            playSound(SoundEffect.cricketGreat);
            HapticFeedback.selectionClick();
          case TimingGrade.early:
          case TimingGrade.late:
            playSound(SoundEffect.cricketGood);
          case TimingGrade.poor:
            playSound(SoundEffect.cricketEdge);
          case TimingGrade.miss:
            playSound(SoundEffect.cricketKeeper);
        }
      case GameplayEventType.boundary:
        final six = s.lastResult?.boundary == 6 || s.ledger.boundary == 6;
        playSound(six ? SoundEffect.cricketSix : SoundEffect.cricketBoundary);
        playSound(SoundEffect.bannerSlam);
        HapticFeedback.heavyImpact();
      case GameplayEventType.wicket:
        playSound(SoundEffect.cricketStumps);
        HapticFeedback.heavyImpact();
      case GameplayEventType.runOut:
        playSound(SoundEffect.cricketStumps);
        playSound(SoundEffect.redCard);
        HapticFeedback.heavyImpact();
      case GameplayEventType.catchTaken:
        playSound(SoundEffect.cricketKeeper);
        HapticFeedback.heavyImpact();
      case GameplayEventType.catchDropped:
        playSound(SoundEffect.cricketBounce);
      case GameplayEventType.powerShotActivated:
        playSound(SoundEffect.riser);
        HapticFeedback.mediumImpact();
      case GameplayEventType.runStarted:
      case GameplayEventType.runnerTurnedBack:
        playSound(SoundEffect.whoosh);
      case GameplayEventType.runCompleted:
        playSound(SoundEffect.cricketGood);
        HapticFeedback.selectionClick();
      case GameplayEventType.extraAwarded:
        playSound(SoundEffect.cricketBounce);
      case GameplayEventType.deliveryCompleted:
        _tallyBall(s.lastResult);
        // Last ball of the over: let the crowd tell them.
        if (s.ballsRemaining == 1 && !s.isTerminal) {
          playSound(SoundEffect.cricketCrowdPressure);
        }
      case GameplayEventType.matchEnded:
        _onMatchEnded();
      default:
        break;
    }
  }

  void _tallyBall(BallResult? ball) {
    if (ball == null) return;
    if (ball.boundary == 6) _sixes += 1;
    if (ball.boundary == 4) _fours += 1;
    final combo = _controller.state.combo;
    if (combo > _bestCombo) _bestCombo = combo;
  }

  void _onMatchEnded() {
    if (_rewardsDispatched) return;
    _rewardsDispatched = true;

    final s = _controller.state;
    final won = s.phase == MatchPhase.won;
    final xp = calculateFinalOverXp(
      won: won,
      runs: s.score,
      wickets: s.wickets,
      stars: s.stars,
      objectiveCompleted: s.objectiveCompleted,
      ballsToSpare: won ? (6 - s.legalBalls).clamp(0, 6) : 0,
      tier: widget.config.tier,
    );
    final summary = FinalOverMatchSummary(
      matchId: widget.config.matchId,
      won: won,
      tier: widget.config.tier,
      runs: s.score,
      target: s.target,
      wickets: s.wickets,
      legalBalls: s.legalBalls,
      stars: s.stars,
      objectiveCompleted: s.objectiveCompleted,
      sixes: _sixes,
      fours: _fours,
      bestCombo: _bestCombo,
      xp: xp,
    );

    unawaited(_cubit.onMatchEnded(summary));
    context.read<GameBloc>().add(
      FinalOverFinished(
        matchId: summary.matchId,
        runs: summary.runs,
        target: summary.target,
        wickets: summary.wickets,
        resultLabel: summary.resultLabel,
        tierLabel: summary.tier.label,
        grade: summary.grade,
        stars: summary.stars,
        xp: xp,
      ),
    );

    playSound(won ? SoundEffect.cricketVictory : SoundEffect.cricketDefeat);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _cubit.showResult();
    });
  }

  // ── flow ──────────────────────────────────────────────────────────────────
  void _beginPlay() {
    _cubit.beginPlay();
    _cubit.markHintsSeen();
    // The engine parks in matchIntro and bowls nothing until this lands.
    _game.start();
  }

  void _pause() {
    if (_paused) return;
    _game.pause();
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_paused) return;
    _game.resume();
    setState(() => _paused = false);
  }

  Future<void> _confirmExit() async {
    final phase = _cubit.state.phase;
    if (phase == FinalOverPhase.result || phase == FinalOverPhase.finished) {
      widget.onExit();
      return;
    }
    _pause();
    final leave = await showCyberConfirmDialog(
      context,
      title: 'LEAVE THE CHASE?',
      message: 'Walking out abandons the over — no XP, no record.',
      confirmLabel: 'Leave',
      cancelLabel: 'Keep batting',
      destructive: true,
    );
    if (!mounted) return;
    if (leave) {
      widget.onExit();
    } else {
      _resume();
    }
  }

  void _rematch() {
    final config = _cubit.buildMatch();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: _cubit,
          child: FinalOverMatchScreen(config: config, onExit: widget.onExit),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: FinalOverGameScope(
        game: _game,
        child: Scaffold(
          backgroundColor: Cyber.bg,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(child: GameWidget(game: _game)),
                  Align(
                    alignment: Alignment.topCenter,
                    child: FinalOverHudBar(game: _game, onExit: _confirmExit),
                  ),
                  FinalOverStingLayer(game: _game),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _MeasureSize(
                      onChanged: (deckSize) {
                        if (!mounted) return;
                        _game.setBattingControlDeckTop(
                          constraints.maxHeight - deckSize.height,
                        );
                        if ((_controlStackHeight - deckSize.height).abs() >
                            .5) {
                          setState(() => _controlStackHeight = deckSize.height);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FinalOverOverdriveRail(game: _game),
                          const SizedBox(height: 6),
                          FinalOverControls(
                            game: _game,
                            showHints: widget.config.showHints,
                            rookieAssist:
                                widget.config.tier == FinalOverTier.rookie,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_paused)
                    Positioned.fill(
                      child: FinalOverPauseOverlay(
                        onResume: _resume,
                        onQuit: widget.onExit,
                      ),
                    ),
                  _PhaseOverlays(
                    game: _game,
                    onBeginPlay: _beginPlay,
                    onRematch: _rematch,
                    onExit: widget.onExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChanged, required super.child});

  final ValueChanged<Size> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChanged);

  ValueChanged<Size> onChanged;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_lastSize == size) return;
    _lastSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(size));
  }
}

/// Intro and result, driven straight off the cubit's phase. Builders see the
/// mount phase, so no initial-listener kick is needed.
class _PhaseOverlays extends StatelessWidget {
  const _PhaseOverlays({
    required this.game,
    required this.onBeginPlay,
    required this.onRematch,
    required this.onExit,
  });

  final FinalOverGame game;
  final VoidCallback onBeginPlay;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FinalOverCubit, FinalOverState>(
      buildWhen: (p, c) => p.phase != c.phase,
      builder: (context, state) {
        switch (state.phase) {
          case FinalOverPhase.intro:
            final config = state.config;
            if (config == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: FinalOverIntroOverlay(config: config, onDone: onBeginPlay),
            );
          case FinalOverPhase.result:
            final summary = state.summary;
            if (summary == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: FinalOverResultOverlay(
                summary: summary,
                stats: state.stats,
                history: game.history.value,
                onRematch: onRematch,
                onExit: onExit,
              ),
            );
          case FinalOverPhase.idle:
          case FinalOverPhase.playing:
          case FinalOverPhase.finished:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
