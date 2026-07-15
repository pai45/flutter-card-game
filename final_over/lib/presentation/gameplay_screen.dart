import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:final_over/app/theme.dart';
import 'package:final_over/application/application.dart';
import 'package:final_over/domain/domain.dart';
import 'package:final_over/game/final_over_game.dart';
import 'package:final_over/game/visuals/final_over_visuals.dart' as art;
import 'package:final_over/services/services.dart';
import 'result_screen.dart';
import 'widgets/arcade_button.dart';
import 'widgets/stadium_backdrop.dart';

typedef ResultRouter = Future<void> Function(GameResultSummary summary);

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({
    super.key,
    required this.seed,
    required this.settings,
    required this.audio,
    required this.haptics,
    required this.onSoundChanged,
    required this.onVibrationChanged,
    required this.onResult,
    this.assetPackage,
    this.onExit,
  });

  final int seed;
  final FinalOverSettings settings;
  final AudioService audio;
  final HapticsService haptics;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onVibrationChanged;
  final ResultRouter onResult;
  final String? assetPackage;
  final VoidCallback? onExit;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with WidgetsBindingObserver {
  late final MatchController _controller;
  late final FinalOverGame _game;
  late MatchState _state;
  StreamSubscription<MatchState>? _stateSubscription;
  StreamSubscription<GameplayEvent>? _eventSubscription;
  Timer? _calloutTimer;
  Timer? _resultTimer;
  art.ResultCalloutVisual? _callout;
  String? _calloutSubtitle;
  bool _wicketCuePlayed = false;
  bool _resultRouted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MatchController();
    _game = FinalOverGame(
      controller: _controller,
      assetPackage: widget.assetPackage,
    );
    _state = _controller.state;
    _stateSubscription = _controller.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });
    _eventSubscription = _controller.eventStream.listen(_handleEvent);
    _controller.startMatch(seed: widget.seed);
    _state = _controller.state;
    unawaited(widget.audio.startAmbience());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _controller.dispatch(const GameCommand.appBackgrounded());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calloutTimer?.cancel();
    _resultTimer?.cancel();
    unawaited(_stateSubscription?.cancel());
    unawaited(_eventSubscription?.cancel());
    unawaited(widget.audio.stop());
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _dispatch(GameCommand command, {bool tapFeedback = true}) {
    if (tapFeedback) {
      unawaited(widget.audio.play(AudioCue.uiTap));
      unawaited(widget.haptics.play(HapticCue.tap));
    }
    _controller.dispatch(command);
  }

  void _handleEvent(GameplayEvent event) {
    _game.notifyEvent(event);
    if (event.type == GameplayEventType.deliveryPrepared) {
      _wicketCuePlayed = false;
      if (_controller.state.currentDeliveryFreeHit) {
        _showCallout(art.ResultCalloutVisual.freeHit);
      }
    } else if (event.type == GameplayEventType.ballReleased) {
      unawaited(widget.audio.play(AudioCue.release));
    } else if (event.type == GameplayEventType.contactResolved) {
      final outcome = event.payload['outcome'] as ContactOutcome?;
      if (outcome?.madeContact == true) {
        unawaited(widget.audio.duckFor());
        unawaited(
          widget.audio.play(
            outcome!.type == ContactType.edge
                ? AudioCue.edge
                : AudioCue.cleanHit,
          ),
        );
        if (outcome.timing == TimingGrade.perfect) {
          _showCallout(art.ResultCalloutVisual.perfect);
          unawaited(widget.haptics.play(HapticCue.perfectContact));
        } else {
          unawaited(widget.haptics.play(HapticCue.goodContact));
        }
      }
    } else if (event.type == GameplayEventType.extraAwarded) {
      final extra = event.payload['extra'] as ExtraType?;
      if (extra == ExtraType.noBall) {
        _showCallout(art.ResultCalloutVisual.freeHit, subtitle: 'No ball +1');
      }
    } else if (event.type == GameplayEventType.boundary) {
      final runs = event.payload['runs'] as int? ?? 4;
      unawaited(widget.audio.duckFor(const Duration(milliseconds: 700)));
      _showCallout(
        runs == 6 ? art.ResultCalloutVisual.six : art.ResultCalloutVisual.four,
      );
      unawaited(
        widget.audio.play(runs == 6 ? AudioCue.sixCrowd : AudioCue.fourCrowd),
      );
      unawaited(
        widget.haptics.play(runs == 6 ? HapticCue.six : HapticCue.four),
      );
    } else if (event.type == GameplayEventType.catchTaken) {
      unawaited(widget.audio.play(AudioCue.catchBall));
    } else if (event.type == GameplayEventType.catchDropped) {
      unawaited(widget.audio.play(AudioCue.bounce));
    } else if (event.type == GameplayEventType.throwStarted) {
      unawaited(widget.audio.play(AudioCue.throwWhoosh));
    } else if (event.type == GameplayEventType.runOut) {
      _showCallout(art.ResultCalloutVisual.out, subtitle: 'Run out');
    } else if (event.type == GameplayEventType.wicket && !_wicketCuePlayed) {
      _wicketCuePlayed = true;
      unawaited(widget.audio.duckFor(const Duration(milliseconds: 650)));
      final dismissal = event.payload['dismissal'] as DismissalType?;
      _showCallout(
        art.ResultCalloutVisual.out,
        subtitle: _dismissalLabel(dismissal),
      );
      unawaited(
        widget.audio.play(
          dismissal == DismissalType.bowled ? AudioCue.stumps : AudioCue.wicket,
        ),
      );
      unawaited(widget.haptics.play(HapticCue.wicket));
    } else if (event.type == GameplayEventType.matchEnded) {
      final won = event.payload['won'] as bool? ?? false;
      _showCallout(
        won ? art.ResultCalloutVisual.victory : art.ResultCalloutVisual.defeat,
      );
      unawaited(widget.audio.play(won ? AudioCue.victory : AudioCue.defeat));
      _scheduleResult();
    }
  }

  String _dismissalLabel(DismissalType? dismissal) => switch (dismissal) {
    DismissalType.bowled => 'Bowled',
    DismissalType.caught => 'Caught',
    DismissalType.runOut => 'Run out',
    DismissalType.none || null => 'Wicket',
  };

  void _showCallout(art.ResultCalloutVisual callout, {String? subtitle}) {
    _calloutTimer?.cancel();
    if (mounted) {
      setState(() {
        _callout = callout;
        _calloutSubtitle = subtitle;
      });
    }
    _calloutTimer = Timer(const Duration(milliseconds: 1050), () {
      if (!mounted) return;
      setState(() {
        _callout = null;
        _calloutSubtitle = null;
      });
    });
  }

  void _scheduleResult() {
    if (_resultRouted || _resultTimer?.isActive == true) return;
    _resultTimer = Timer(const Duration(milliseconds: 1150), () async {
      if (!mounted || _resultRouted) return;
      _resultRouted = true;
      await widget.onResult(_buildSummary(_controller.state));
    });
  }

  GameResultSummary _buildSummary(MatchState state) {
    final boundaries = state.history.where((ball) => ball.isBoundary).length;
    final sixes = state.history.where((ball) => ball.boundary == 6).length;
    final points =
        state.committedScore * 100 +
        boundaries * 150 +
        sixes * 250 +
        (state.objectiveCompleted ? 500 : 0) +
        (state.phase == MatchPhase.won ? state.ballsRemaining * 100 : 0);
    return GameResultSummary(
      won: state.phase == MatchPhase.won,
      runs: state.committedScore,
      target: state.target,
      legalBalls: state.legalBalls,
      wickets: state.wickets,
      stars: state.stars,
      points: points,
      objectiveLabel: objectiveLabel(state.objective),
      objectiveComplete: state.objectiveCompleted,
      history: state.history.map((ball) => ball.historyToken).toList(),
      reason: switch (state.endReason) {
        MatchEndReason.targetReached => 'TARGET CHASED',
        MatchEndReason.ballsExhausted => 'SIX LEGAL BALLS USED',
        MatchEndReason.wicketsLost => 'TWO WICKETS LOST',
        MatchEndReason.quit || null => null,
      },
    );
  }

  void _handleBack() {
    if (_state.phase == MatchPhase.matchIntro) {
      _exit();
    } else if (_state.phase == MatchPhase.paused) {
      _dispatch(const GameCommand.resume());
    } else if (!_state.isTerminal) {
      _dispatch(const GameCommand.pause());
    }
  }

  void _exit() {
    final callback = widget.onExit;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: StadiumBackdrop(
          dim: .52,
          assetPackage: widget.assetPackage,
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  children: [
                    _ScoreHud(
                      state: _state,
                      maximumWickets: _controller.tuning.maximumWickets,
                      onPause: _state.isTerminal
                          ? null
                          : () => _dispatch(const GameCommand.pause()),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: FinalOverPalette.night.withValues(
                                alpha: .55,
                              ),
                              border: Border.all(
                                color: FinalOverPalette.cyan.withValues(
                                  alpha: .45,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: GameWidget<FinalOverGame>(game: _game),
                          ),
                        ),
                      ),
                    ),
                    _ControlDeck(
                      state: _state,
                      tuning: _controller.tuning,
                      onCommand: _dispatch,
                    ),
                  ],
                ),
                if (_state.phase == MatchPhase.matchIntro)
                  _MatchIntroOverlay(
                    state: _state,
                    onStart: () => _dispatch(const GameCommand.start()),
                    onHome: _exit,
                  ),
                if (_state.phase == MatchPhase.paused)
                  _PauseOverlay(
                    settings: widget.settings,
                    onResume: () => _dispatch(const GameCommand.resume()),
                    onRestart: () => _dispatch(
                      GameCommand.restart(
                        seed: _state.matchSeed,
                        target: _state.target,
                      ),
                    ),
                    onHome: () {
                      _dispatch(const GameCommand.quitToHome());
                      _exit();
                    },
                    onSoundChanged: widget.onSoundChanged,
                    onVibrationChanged: widget.onVibrationChanged,
                  ),
                if (_callout case final callout?)
                  IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width * .88,
                        height: 112,
                        child: art.ResultCallout(
                          callout: callout,
                          subtitle: _calloutSubtitle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String objectiveLabel(ObjectiveType objective) => switch (objective) {
  ObjectiveType.twoBoundaries => 'Hit two boundaries',
  ObjectiveType.sixRunsFirstThreeLegalBalls =>
    'Score 6 before the third legal ball ends',
  ObjectiveType.completeDouble => 'Complete a double',
};

class _ScoreHud extends StatelessWidget {
  const _ScoreHud({
    required this.state,
    required this.onPause,
    required this.maximumWickets,
  });

  final MatchState state;
  final VoidCallback? onPause;
  final int maximumWickets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 7),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(5),
                decoration: arcadePanel(radius: 14),
                child: const art.FinalOverBrandMark(),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${state.score}/${state.wickets}',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: 28, height: 1),
                    ),
                    Text(
                      'NEED ${state.runsNeeded}  •  ${state.ballsRemaining} BALL${state.ballsRemaining == 1 ? '' : 'S'}',
                      style: const TextStyle(
                        color: FinalOverPalette.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniStat(label: 'TARGET', value: '${state.target}'),
              const SizedBox(width: 6),
              _MiniStat(
                label: 'WKT',
                value: '${state.wicketsRemaining(maximumWickets)}',
              ),
              IconButton(
                tooltip: 'Pause',
                onPressed: onPause,
                icon: const Icon(Icons.pause_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 27,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.history.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 5),
                    itemBuilder: (_, index) =>
                        _BallToken(token: state.history[index].historyToken),
                  ),
                ),
              ),
              if (state.freeHit || state.currentDeliveryFreeHit)
                const _StatusChip(
                  label: 'FREE HIT',
                  color: FinalOverPalette.yellow,
                ),
              const SizedBox(width: 6),
              _StatusChip(
                label: 'x${state.combo}',
                color: FinalOverPalette.cyan,
              ),
              const SizedBox(width: 6),
              _PowerMeter(
                segments: state.powerSegments,
                armed: state.powerShotArmed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FinalOverPalette.muted,
            fontSize: 8,
            letterSpacing: .7,
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _BallToken extends StatelessWidget {
  const _BallToken({required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    final wicket = token.contains('W');
    return Container(
      constraints: const BoxConstraints(minWidth: 27),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: wicket ? FinalOverPalette.red : FinalOverPalette.deepBlue,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: wicket ? FinalOverPalette.red : FinalOverPalette.cyan,
        ),
      ),
      child: Text(
        token,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _PowerMeter extends StatelessWidget {
  const _PowerMeter({required this.segments, required this.armed});
  final int segments;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: armed ? 'Power Shot armed' : 'Power $segments/10',
      child: Row(
        children: List.generate(5, (index) {
          final filled = segments >= (index + 1) * 2;
          return Container(
            width: 5,
            height: 18,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: filled
                  ? (armed ? FinalOverPalette.yellow : FinalOverPalette.orange)
                  : FinalOverPalette.muted.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

class _ControlDeck extends StatelessWidget {
  const _ControlDeck({
    required this.state,
    required this.tuning,
    required this.onCommand,
  });

  final MatchState state;
  final GameplayTuning tuning;
  final void Function(GameCommand command) onCommand;

  bool get _isLive =>
      state.phase == MatchPhase.cameraTransition ||
      state.phase == MatchPhase.fieldPlay ||
      state.phase == MatchPhase.runDecision ||
      state.phase == MatchPhase.runnersMoving ||
      state.phase == MatchPhase.throwInProgress;

  @override
  Widget build(BuildContext context) {
    if (state.phase == MatchPhase.matchIntro ||
        state.phase == MatchPhase.paused ||
        state.isTerminal) {
      return const SizedBox(height: 176);
    }
    return Container(
      height: 176,
      margin: const EdgeInsets.fromLTRB(10, 7, 10, 9),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: arcadePanel(
        color: FinalOverPalette.night.withValues(alpha: .94),
      ),
      child: _isLive ? _runningControls(context) : _battingControls(context),
    );
  }

  Widget _battingControls(BuildContext context) {
    final canSelect =
        state.phase == MatchPhase.deliveryPreparation ||
        state.phase == MatchPhase.bowlerRunUp;
    final canSwing =
        (state.phase == MatchPhase.bowlerRunUp ||
            state.phase == MatchPhase.incomingBall) &&
        state.swingIntent == null;
    final delivery = state.currentDelivery;
    final errorMs = delivery == null
        ? -350.0
        : ((state.simulationMicros - delivery.expectedContactMicros) / 1000)
              .clamp(-350.0, 350.0)
              .toDouble();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _deliveryLabel(delivery),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FinalOverPalette.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
            ),
            SizedBox(
              width: 165,
              height: 31,
              child: art.TimingMeter(
                errorMilliseconds: errorMs,
                showLabels: false,
                enabled: canSwing,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ElevationButton(
                label: 'GROUND',
                visual: art.ShotElevationVisual.ground,
                selected: state.selectedElevation == Elevation.ground,
                enabled: canSelect,
                onTap: () => onCommand(
                  const GameCommand.selectElevation(Elevation.ground),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _ElevationButton(
                label: 'LOFT',
                visual: art.ShotElevationVisual.loft,
                selected: state.selectedElevation == Elevation.loft,
                enabled: canSelect,
                onTap: () => onCommand(
                  const GameCommand.selectElevation(Elevation.loft),
                ),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 60,
              height: 43,
              child: FilledButton(
                onPressed:
                    state.powerSegments >= tuning.powerShotSegments && canSelect
                    ? () => onCommand(const GameCommand.activatePowerShot())
                    : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: FinalOverPalette.orange,
                ),
                child: Icon(
                  state.powerShotArmed
                      ? Icons.bolt_rounded
                      : Icons.flash_on_rounded,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _DirectionButton(
                  label: 'OFF',
                  visual: art.ShotDirectionVisual.off,
                  enabled: canSwing,
                  onTap: () =>
                      onCommand(const GameCommand.swing(ShotDirection.offSide)),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _DirectionButton(
                  label: 'STRAIGHT',
                  visual: art.ShotDirectionVisual.straight,
                  enabled: canSwing,
                  onTap: () => onCommand(
                    const GameCommand.swing(ShotDirection.straight),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _DirectionButton(
                  label: 'LEG',
                  visual: art.ShotDirectionVisual.leg,
                  enabled: canSwing,
                  onTap: () =>
                      onCommand(const GameCommand.swing(ShotDirection.legSide)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _deliveryLabel(DeliverySpec? delivery) {
    if (delivery == null) return 'PACE DELIVERY';
    final length = delivery.length.name.toUpperCase();
    final line = switch (delivery.line) {
      DeliveryLine.wideOff => 'WIDE OFF',
      DeliveryLine.off => 'OFF',
      DeliveryLine.middle => 'MIDDLE',
      DeliveryLine.leg => 'LEG',
      DeliveryLine.wideLeg => 'WIDE LEG',
    };
    return 'PACE  •  $length  •  $line';
  }

  Widget _runningControls(BuildContext context) {
    final risk = state.runner.risk;
    final riskColor = switch (risk) {
      RiskLevel.safe => FinalOverPalette.green,
      RiskLevel.close => FinalOverPalette.yellow,
      RiskLevel.danger => FinalOverPalette.red,
    };
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radar_rounded, color: riskColor, size: 20),
            const SizedBox(width: 7),
            Text(
              risk.name.toUpperCase(),
              style: TextStyle(
                color: riskColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '${state.runner.completedRuns}/3 RUNS',
              style: const TextStyle(
                color: FinalOverPalette.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !state.runner.active && !state.holdRequested
                      ? () => onCommand(const GameCommand.holdBall())
                      : null,
                  icon: const Icon(Icons.pan_tool_alt_rounded),
                  label: const Text('HOLD'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(68),
                    side: const BorderSide(color: FinalOverPalette.cyan),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: state.canRun
                      ? () => onCommand(const GameCommand.startRun())
                      : null,
                  icon: const Icon(Icons.directions_run_rounded, size: 27),
                  label: Text(
                    state.runner.completedRuns == 0 ? 'RUN' : 'RUN AGAIN',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(68),
                    backgroundColor: riskColor,
                    foregroundColor: FinalOverPalette.night,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (state.runner.active)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: state.runner.progress,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(5),
                    color: riskColor,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    onPressed: state.runner.canTurnBack
                        ? () => onCommand(const GameCommand.turnBack())
                        : null,
                    child: const Text('TURN BACK'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ElevationButton extends StatelessWidget {
  const _ElevationButton({
    required this.label,
    required this.visual,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final art.ShotElevationVisual visual;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        height: 43,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: enabled ? 1 : .45,
                child: art.ShotElevationIcon(
                  elevation: visual,
                  selected: selected,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.label,
    required this.visual,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final art.ShotDirectionVisual visual;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label swing',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: FinalOverPalette.deepBlue.withValues(
              alpha: enabled ? .92 : .38,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? FinalOverPalette.cyan
                  : FinalOverPalette.muted.withValues(alpha: .3),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 3, 7, 0),
                  child: art.ShotDirectionIcon(direction: visual),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchIntroOverlay extends StatelessWidget {
  const _MatchIntroOverlay({
    required this.state,
    required this.onStart,
    required this.onHome,
  });
  final MatchState state;
  final VoidCallback onStart;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: .80),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(22),
            decoration: arcadePanel(radius: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 118,
                  child: art.FinalOverWordmark(showTagline: false),
                ),
                const Text(
                  'THE CHASE',
                  style: TextStyle(
                    color: FinalOverPalette.muted,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '${state.target}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: FinalOverPalette.cyan,
                    fontSize: 68,
                  ),
                ),
                const Text('RUNS • SIX LEGAL BALLS • TWO WICKETS'),
                const SizedBox(height: 16),
                _ObjectiveCard(
                  label: objectiveLabel(state.objective),
                  complete: false,
                ),
                const SizedBox(height: 18),
                ArcadeButton(
                  label: 'CHASE NOW',
                  icon: Icons.sports_cricket_rounded,
                  onPressed: onStart,
                ),
                TextButton(onPressed: onHome, child: const Text('BACK HOME')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({required this.label, required this.complete});
  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: FinalOverPalette.deepBlue.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: complete ? FinalOverPalette.green : FinalOverPalette.yellow,
        ),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.flag_rounded,
            color: complete ? FinalOverPalette.green : FinalOverPalette.yellow,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.settings,
    required this.onResume,
    required this.onRestart,
    required this.onHome,
    required this.onSoundChanged,
    required this.onVibrationChanged,
  });
  final FinalOverSettings settings;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onVibrationChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: .84),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 390,
            padding: const EdgeInsets.all(22),
            decoration: arcadePanel(radius: 22),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PAUSED',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile(
                    value: settings.soundEnabled,
                    onChanged: onSoundChanged,
                    secondary: const Icon(Icons.volume_up_rounded),
                    title: const Text('Sound'),
                  ),
                  SwitchListTile(
                    value: settings.vibrationEnabled,
                    onChanged: onVibrationChanged,
                    secondary: const Icon(Icons.vibration_rounded),
                    title: const Text('Vibration'),
                  ),
                  const SizedBox(height: 12),
                  ArcadeButton(
                    label: 'RESUME',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onResume,
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('RESTART SAME CHASE'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onHome,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('QUIT TO HOME'),
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
