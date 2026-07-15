import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/basketball/basketball_cubit.dart';
import '../../blocs/basketball/basketball_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../config/theme.dart';
import '../../games/basketball/basketball_engine.dart';
import '../../games/basketball/basketball_game.dart';
import '../../models/basketball.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/basketball_controls.dart';
import 'widgets/basketball_hud.dart';
import 'widgets/basketball_overlays.dart';
import 'widgets/basketball_result.dart';

/// The live duel: full-bleed Flame court under the score/clock HUD, the shot
/// meter, sting banners, the two-zone control deck, and the intro / halftime /
/// overtime / result overlays. The cubit owns the phase machine; the Flame
/// game owns the 60fps simulation; this screen bridges the two, maps engine
/// events to sound/haptics, and dispatches the reward exactly once.
class BasketballMatchScreen extends StatefulWidget {
  const BasketballMatchScreen({
    required this.onExit,
    required this.onRematch,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onRematch;

  @override
  State<BasketballMatchScreen> createState() => _BasketballMatchScreenState();
}

class _BasketballMatchScreenState extends State<BasketballMatchScreen> {
  late final BasketballCubit _cubit;
  late final BasketballGame _game;
  BasketballMatchConfig? _config;
  bool _rewardsDispatched = false;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<BasketballCubit>();
    _config = _cubit.state.config;
    final reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _game = BasketballGame(
      config: _config!,
      onEvents: _onGameEvents,
      reducedMotion: reducedMotion,
    );
    // Crowd bed (no-ops silently until the ambient asset exists — chess spec).
    AudioController.instance.playLoop(MusicTrack.matchAmbient);
  }

  @override
  void dispose() {
    AudioController.instance.stopLoop();
    // Leaving mid-match discards the attempt (no stats, no reward). A REMATCH
    // relaunch has already replaced the config by the time this route is
    // disposed — the identity check keeps us from resetting the new match.
    final phase = _cubit.state.phase;
    final midMatch =
        phase == BasketballPhase.intro ||
        phase == BasketballPhase.playing ||
        phase == BasketballPhase.halftime ||
        phase == BasketballPhase.overtimeBreak;
    if (midMatch && identical(_cubit.state.config, _config)) {
      _cubit.abandonMatch();
    }
    super.dispose();
  }

  // -- engine events → sound / haptics / cubit beats --------------------------

  void _onGameEvents(List<BasketballEvent> events) {
    for (final event in events) {
      switch (event.type) {
        case BasketballEventType.basketMade:
          playSound(SoundEffect.bbSwish);
          if (event.team == 0) HapticFeedback.mediumImpact();
        case BasketballEventType.shotMissed:
          playSound(SoundEffect.bbRimRattle);
        case BasketballEventType.dunk:
          playSound(SoundEffect.bbDunkSlam);
          HapticFeedback.heavyImpact();
        case BasketballEventType.poster:
          playSound(SoundEffect.bannerSlam);
        case BasketballEventType.block:
          playSound(SoundEffect.bbBackboard);
          HapticFeedback.heavyImpact();
        case BasketballEventType.steal:
          playSound(SoundEffect.bbSneakerSqueak);
          HapticFeedback.mediumImpact();
        case BasketballEventType.ankleBreaker:
          playSound(SoundEffect.bbSneakerSqueak);
          HapticFeedback.mediumImpact();
        case BasketballEventType.spinMove:
          playSound(SoundEffect.bbSneakerSqueak);
          if (event.team == 0) HapticFeedback.selectionClick();
        case BasketballEventType.crossover:
          if (event.team == 0) playSound(SoundEffect.bbSneakerSqueak);
        case BasketballEventType.perfectRelease:
          if (event.team == 0) {
            playSound(SoundEffect.commit);
            HapticFeedback.selectionClick();
          }
        case BasketballEventType.shotReleased:
          if (event.team == 0) playSound(SoundEffect.whoosh);
        case BasketballEventType.heatStarted:
          playSound(SoundEffect.riser);
          playSound(SoundEffect.bbCrowdRoar);
          if (event.team == 0) HapticFeedback.mediumImpact();
        case BasketballEventType.shotClockViolation:
          playSound(SoundEffect.redCard);
        case BasketballEventType.buzzerBeater:
          playSound(SoundEffect.bbBuzzer);
          playSound(SoundEffect.bannerSlam);
          HapticFeedback.heavyImpact();
        case BasketballEventType.halfEnded:
          playSound(SoundEffect.bbBuzzer);
          HapticFeedback.heavyImpact();
          if (event.halfIndex == 0) _cubit.markHintsSeen();
          _cubit.onHalfEnded(
            halfIndex: event.halfIndex,
            needsOvertime: event.needsOvertime,
          );
        case BasketballEventType.matchEnded:
          _onMatchEnded();
        default:
          break;
      }
    }
  }

  void _onMatchEnded() {
    if (_rewardsDispatched) return;
    _rewardsDispatched = true;
    final summary = _game.summary();
    unawaited(_cubit.onMatchEnded(summary));
    final xp = _cubit.state.xp;
    context.read<GameBloc>().add(
      BasketballFinished(
        playerScore: summary.playerScore,
        cpuScore: summary.cpuScore,
        resultLabel: summary.won ? 'Victory' : 'Defeat',
        difficultyLabel: basketballDifficultyLabel(summary.difficulty),
        grade: summary.grade,
        overtime: summary.overtime,
        xp: xp,
      ),
    );
    playSound(summary.won ? SoundEffect.matchWin : SoundEffect.matchLose);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _cubit.showResult();
    });
  }

  // -- phase transitions (driven by overlay callbacks, not listeners) ---------

  void _beginPlay() {
    _cubit.beginPlay();
    _game.startHalf(0);
  }

  void _resumeSecondHalf(int rosterIndex) {
    _game.halftimeRest();
    if (rosterIndex != _game.engine.teams[0].activeIndex) {
      _game.substitutePlayer(rosterIndex);
      playSound(SoundEffect.cardSelect);
    }
    _game.cpuAutoSubstitute();
    _cubit.resumeSecondHalf();
    _game.startHalf(1);
  }

  void _beginOvertime() {
    _cubit.beginOvertime();
    _game.startHalf(2);
  }

  Future<void> _confirmExit() async {
    final phase = _cubit.state.phase;
    if (phase == BasketballPhase.result ||
        phase == BasketballPhase.finished) {
      widget.onExit();
      return;
    }
    _game.setPaused(true);
    final leave = await showCyberConfirmDialog(
      context,
      title: 'LEAVE THE COURT?',
      message: 'Walking out abandons the match — no XP, no record.',
      confirmLabel: 'Leave',
      cancelLabel: 'Keep playing',
      destructive: true,
    );
    if (leave) {
      widget.onExit();
    } else {
      _game.setPaused(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showHints = _config?.showHints ?? false;
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: _game)),
            Align(
              alignment: Alignment.topCenter,
              child: BasketballHudBar(game: _game, onExit: _confirmExit),
            ),
            BasketballStingLayer(game: _game),
            Positioned(
              right: 22,
              bottom: 168,
              child: BasketballShotMeter(game: _game),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BasketballStaminaRail(game: _game),
                  const SizedBox(height: 6),
                  BasketballControls(game: _game, showHints: showHints),
                ],
              ),
            ),
            _PhaseOverlays(
              game: _game,
              onBeginPlay: _beginPlay,
              onResumeSecondHalf: _resumeSecondHalf,
              onBeginOvertime: _beginOvertime,
              onRematch: widget.onRematch,
              onExit: widget.onExit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the phase-scoped full-screen overlays (intro / halftime / overtime
/// break / result) from cubit state — builders see the mount phase, so no
/// initial-listener kick is needed.
class _PhaseOverlays extends StatelessWidget {
  const _PhaseOverlays({
    required this.game,
    required this.onBeginPlay,
    required this.onResumeSecondHalf,
    required this.onBeginOvertime,
    required this.onRematch,
    required this.onExit,
  });

  final BasketballGame game;
  final VoidCallback onBeginPlay;
  final ValueChanged<int> onResumeSecondHalf;
  final VoidCallback onBeginOvertime;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BasketballCubit, BasketballState>(
      buildWhen: (p, c) => p.phase != c.phase,
      builder: (context, state) {
        final config = state.config;
        switch (state.phase) {
          case BasketballPhase.intro:
            if (config == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: BasketballIntroOverlay(
                config: config,
                onDone: onBeginPlay,
              ),
            );
          case BasketballPhase.halftime:
            return Positioned.fill(
              child: BasketballHalftimeOverlay(
                game: game,
                rosterIds: state.rosterIds,
                onResume: onResumeSecondHalf,
              ),
            );
          case BasketballPhase.overtimeBreak:
            return Positioned.fill(
              child: BasketballOvertimeOverlay(onBegin: onBeginOvertime),
            );
          case BasketballPhase.result:
            final summary = state.summary;
            if (summary == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: BasketballResultOverlay(
                summary: summary,
                xp: state.xp,
                stats: state.stats,
                onRematch: onRematch,
                onExit: onExit,
              ),
            );
          case BasketballPhase.idle:
          case BasketballPhase.playing:
          case BasketballPhase.finished:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
