import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../blocs/grand_prix/grand_prix_state.dart';
import '../../config/theme.dart';
import '../../data/grand_prix_circuits.dart';
import '../../games/grand_prix/grand_prix_engine.dart';
import '../../games/grand_prix/grand_prix_game.dart';
import '../../models/grand_prix.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/grand_prix_controls.dart';
import 'widgets/grand_prix_result.dart';

/// The live race: full-bleed Flame scroller under a slim cyber HUD (position,
/// lap progress, speed), the five-lights start rig, overtake toasts, the
/// control pad, and the result overlay. The cubit owns the phase machine; the
/// Flame game owns the 60fps simulation; this screen bridges the two and
/// dispatches the reward exactly once at the finish.
class GrandPrixRaceScreen extends StatefulWidget {
  const GrandPrixRaceScreen({
    required this.onExit,
    required this.onRaceAgain,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onRaceAgain;

  @override
  State<GrandPrixRaceScreen> createState() => _GrandPrixRaceScreenState();
}

class _GrandPrixRaceScreenState extends State<GrandPrixRaceScreen> {
  late final GrandPrixCubit _cubit;
  late final GrandPrixGame _game;
  RaceSetup? _setup;
  bool _rewardsDispatched = false;
  bool _lightsScheduled = false;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<GrandPrixCubit>();
    _setup = _cubit.state.setup;
    final reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _game = GrandPrixGame(
      setup: _setup!,
      onPositionChanged: _cubit.onPlayerPositionChanged,
      onOvertake: _onOvertake,
      onPlayerFinished: _cubit.onRaceFinished,
      reducedMotion: reducedMotion,
    );
    // The phase is already `grid` when this screen mounts, so the
    // BlocListener never fires for it — kick off the lights beat here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleLights(context);
    });
  }

  void _scheduleLights(BuildContext context) {
    if (_lightsScheduled) return;
    _lightsScheduled = true;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _cubit.beginLights(reducedMotion: reducedMotion);
    });
  }

  @override
  void dispose() {
    _game.stopRace();
    // Leaving mid-race discards the attempt (no stats, no reward). A RACE
    // AGAIN relaunch has already replaced the setup by the time this route
    // is disposed — the identity check keeps us from resetting the new race.
    final phase = _cubit.state.phase;
    final midRace = phase == GrandPrixPhase.grid ||
        phase == GrandPrixPhase.lights ||
        phase == GrandPrixPhase.racing;
    if (midRace && identical(_cubit.state.setup, _setup)) {
      _cubit.abandonRace();
    }
    super.dispose();
  }

  void _onOvertake(OvertakeEvent event) {
    _cubit.onOvertake(event);
    playSound(SoundEffect.whoosh);
    HapticFeedback.selectionClick();
  }

  void _drive(BuildContext context, GrandPrixState state) {
    switch (state.phase) {
      case GrandPrixPhase.grid:
        _scheduleLights(context);
      case GrandPrixPhase.racing:
        final grade = state.launchGrade;
        if (grade != null) {
          _game.startRace(grade);
          playSound(SoundEffect.bannerSlam);
          if (grade == LaunchGrade.jump) {
            HapticFeedback.heavyImpact();
          } else {
            HapticFeedback.mediumImpact();
          }
        }
      case GrandPrixPhase.finished:
        _onFinished(state);
      case GrandPrixPhase.idle:
      case GrandPrixPhase.lights:
      case GrandPrixPhase.result:
        break;
    }
  }

  void _onFinished(GrandPrixState state) {
    final result = state.result;
    if (_rewardsDispatched || result == null) return;
    _rewardsDispatched = true;
    _game.stopRace();
    playSound(
      result.retired
          ? SoundEffect.bannerSlam
          : result.position <= 3
              ? SoundEffect.matchWin
              : SoundEffect.bannerSlam,
    );
    HapticFeedback.heavyImpact();
    final verdictLabel = result.retired
        ? 'Retired'
        : switch (result.verdict) {
            GrandPrixVerdict.win => 'Victory',
            GrandPrixVerdict.podium => 'Podium',
            GrandPrixVerdict.points => 'Points',
            GrandPrixVerdict.finished => 'Finished',
          };
    // Distance rides along in the label so history + XP ledger read
    // 'EMERALD PARK · 3 LAPS' without touching the event shape.
    final circuitLabel = result.laps > 1
        ? '${grandPrixCircuit(result.circuit).name} · ${result.laps} LAPS'
        : grandPrixCircuit(result.circuit).name;
    context.read<GameBloc>().add(
      GrandPrixFinished(
        position: result.position,
        fieldSize: result.fieldSize,
        circuitName: circuitLabel,
        lapTimeMs: result.lapTimeMs,
        verdictLabel: verdictLabel,
        xp: result.xp,
      ),
    );
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _cubit.showResult();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: BlocListener<GrandPrixCubit, GrandPrixState>(
        listenWhen: (p, c) =>
            p.phase != c.phase || p.launchGrade != c.launchGrade,
        listener: _drive,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
              Align(
                alignment: Alignment.topCenter,
                child: _RaceHud(game: _game, onExit: widget.onExit),
              ),
              Align(child: _LightsRig()),
              _LaunchGradeFlash(),
              _LapFlash(game: _game),
              _StuckWarning(game: _game),
              _OvertakeToast(),
              Align(
                alignment: Alignment.bottomCenter,
                child: GrandPrixControls(
                  onLeft: (down) => _game.setInputs(left: down),
                  onRight: (down) => _game.setInputs(right: down),
                  onBrake: (down) => _game.setInputs(brake: down),
                  onThrottle: (down) {
                    _game.setInputs(throttle: down);
                    if (down &&
                        _cubit.state.phase == GrandPrixPhase.lights) {
                      _cubit.registerThrottleTap();
                    }
                  },
                ),
              ),
              _ResultLayer(
                onExit: widget.onExit,
                onRaceAgain: widget.onRaceAgain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top HUD: exit · position · lap bar · speed
// ---------------------------------------------------------------------------

class _RaceHud extends StatelessWidget {
  const _RaceHud({required this.game, required this.onExit});

  final GrandPrixGame game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0.92),
            Cyber.bg.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close, color: Cyber.muted, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              BlocBuilder<GrandPrixCubit, GrandPrixState>(
                buildWhen: (p, c) => p.playerPosition != c.playerPosition,
                builder: (context, state) => Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'P${state.playerPosition}',
                      style: Cyber.display(26, color: Cyber.cyan).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '/$kFieldSize',
                      style: Cyber.display(13, color: Cyber.muted).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<double>(
                valueListenable: game.speedKph,
                builder: (context, kph, _) => SizedBox(
                  width: 84,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${kph.round()} KPH',
                      maxLines: 1,
                      softWrap: false,
                      style: Cyber.display(13, color: Colors.white).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 12),
              ValueListenableBuilder<int>(
                valueListenable: game.currentLap,
                builder: (context, lap, _) => Text(
                  game.laps == 1 ? 'LAP' : 'LAP $lap/${game.laps}',
                  style: const TextStyle(
                    color: Cyber.muted,
                    fontFamily: Cyber.displayFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: game.lapProgress,
                  builder: (context, progress, _) => CyberProgressBar(
                    value: progress,
                    accent: Cyber.magenta,
                    height: 5,
                    radius: 2,
                    animate: false,
                    trackColor: Cyber.magenta.withValues(alpha: 0.14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: game.slipstreamActive,
                builder: (context, tow, _) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: tow ? 1 : 0,
                  child: const CyberChip(label: 'TOW', color: Cyber.cyan),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Start lights rig
// ---------------------------------------------------------------------------

class _LightsRig extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrandPrixCubit, GrandPrixState>(
      buildWhen: (p, c) =>
          p.phase != c.phase ||
          p.lightsOn != c.lightsOn ||
          p.lightsOut != c.lightsOut,
      builder: (context, state) {
        final visible = state.phase == GrandPrixPhase.grid ||
            state.phase == GrandPrixPhase.lights;
        if (!visible) return const SizedBox.shrink();
        final waiting = state.phase == GrandPrixPhase.grid;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.85),
                border: Border.all(color: Cyber.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var lamp = 1; lamp <= 5; lamp++) ...[
                    _Lamp(on: lamp <= state.lightsOn),
                    if (lamp < 5) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              waiting
                  ? 'ON THE GRID'
                  : state.lightsOut
                      ? 'GO GO GO!'
                      : 'WAIT FOR LIGHTS OUT…',
              style: Cyber.label(
                10,
                color: state.lightsOut ? Cyber.success : Cyber.muted,
                letterSpacing: 2.4,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Lamp extends StatelessWidget {
  const _Lamp({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? Cyber.danger : Cyber.panel,
        border: Border.all(
          color: on ? Cyber.danger : Cyber.border,
          width: 1.4,
        ),
        boxShadow: on ? Cyber.glow(Cyber.danger, alpha: 0.6, blur: 14) : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Launch-grade flash (PERFECT LAUNCH / JUMP START …)
// ---------------------------------------------------------------------------

class _LaunchGradeFlash extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrandPrixCubit, GrandPrixState>(
      buildWhen: (p, c) => p.launchGrade != c.launchGrade || p.phase != c.phase,
      builder: (context, state) {
        final grade = state.launchGrade;
        if (grade == null || state.phase != GrandPrixPhase.racing) {
          return const SizedBox.shrink();
        }
        final (label, color) = switch (grade) {
          LaunchGrade.perfect => ('PERFECT LAUNCH', Cyber.gold),
          LaunchGrade.great => ('GREAT LAUNCH', Cyber.success),
          LaunchGrade.good => ('GOOD LAUNCH', Cyber.cyan),
          LaunchGrade.slow => ('SLOW AWAY', Cyber.amber),
          LaunchGrade.jump => ('JUMP START — THROTTLE CUT', Cyber.danger),
        };
        return Align(
          alignment: const Alignment(0, -0.45),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(grade),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1900),
            builder: (context, t, child) {
              final appear = (t * 6).clamp(0.0, 1.0);
              final fade = t > 0.75 ? (1 - (t - 0.75) / 0.25) : 1.0;
              return Opacity(
                // Clamped: the fade math can dip a hair below 0 at t == 1.0
                // (binary float), which trips Opacity's assert.
                opacity: (appear * fade).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.8 + 0.2 * Curves.easeOutBack.transform(appear),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.8),
                border: Border.all(color: color),
                boxShadow: Cyber.glow(color, alpha: 0.35),
              ),
              child: Text(
                label,
                style: Cyber.display(15, color: color, letterSpacing: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Lap-cross flash — a beat every time the player takes the line (multi-lap)
// ---------------------------------------------------------------------------

class _LapFlash extends StatefulWidget {
  const _LapFlash({required this.game});

  final GrandPrixGame game;

  @override
  State<_LapFlash> createState() => _LapFlashState();
}

class _LapFlashState extends State<_LapFlash> {
  int _shownLap = 1;

  @override
  void initState() {
    super.initState();
    widget.game.currentLap.addListener(_onLap);
  }

  @override
  void dispose() {
    widget.game.currentLap.removeListener(_onLap);
    super.dispose();
  }

  void _onLap() {
    final lap = widget.game.currentLap.value;
    // Only fires forwards: a fresh race mounts a fresh screen, so no resets.
    if (lap <= 1 || lap == _shownLap) return;
    setState(() => _shownLap = lap);
    playSound(
      lap == widget.game.laps ? SoundEffect.bannerSlam : SoundEffect.whoosh,
    );
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (_shownLap <= 1) return const SizedBox.shrink();
    final finalLap = _shownLap == widget.game.laps;
    final color = finalLap ? Cyber.gold : Cyber.cyan;
    return Align(
      alignment: const Alignment(0, -0.45),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_shownLap),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1600),
        builder: (context, t, child) {
          final appear = (t * 5).clamp(0.0, 1.0);
          final fade = t > 0.72 ? (1 - (t - 0.72) / 0.28) : 1.0;
          return Opacity(
            // Clamped: the fade math can dip a hair below 0 at t == 1.0
            // (binary float), which trips Opacity's assert.
            opacity: (appear * fade).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.85 + 0.15 * Curves.easeOutBack.transform(appear),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Cyber.bg.withValues(alpha: 0.8),
            border: Border.all(color: color),
            // FINAL LAP is the moment; ordinary lap crossings stay calm.
            boxShadow: finalLap ? Cyber.glow(color, alpha: 0.35) : null,
          ),
          child: Text(
            finalLap ? 'FINAL LAP' : 'LAP $_shownLap / ${widget.game.laps}',
            style: Cyber.display(15, color: color, letterSpacing: 2).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stuck warning — get moving or the race is over
// ---------------------------------------------------------------------------

class _StuckWarning extends StatelessWidget {
  const _StuckWarning({required this.game});

  final GrandPrixGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: game.stuckSeconds,
      builder: (context, stuck, _) {
        // Only warn once the player has been stuck a beat — brief dips (a hard
        // brake or a spin) shouldn't flash it.
        if (stuck < 2.5) return const SizedBox.shrink();
        final remaining = (kStuckTimeout - stuck).clamp(0.0, kStuckTimeout);
        return Align(
          alignment: const Alignment(0, -0.12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: 0.85),
              border: Border.all(color: Cyber.danger, width: 1.5),
              boxShadow: Cyber.glow(Cyber.danger, alpha: 0.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Cyber.danger, size: 26),
                const SizedBox(height: 6),
                Text(
                  'GET BACK ON TRACK',
                  style:
                      Cyber.display(16, color: Cyber.danger, letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                Text(
                  'RETIRING IN ${remaining.ceil()}s',
                  style: Cyber.label(11, color: Cyber.danger, letterSpacing: 2)
                      .copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Overtake toast
// ---------------------------------------------------------------------------

class _OvertakeToast extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrandPrixCubit, GrandPrixState>(
      buildWhen: (p, c) => p.eventTick != c.eventTick,
      builder: (context, state) {
        final overtake = state.lastOvertake;
        if (overtake == null || state.phase != GrandPrixPhase.racing) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: const Alignment(0, -0.72),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(state.eventTick),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1500),
            builder: (context, t, child) {
              final appear = (t * 5).clamp(0.0, 1.0);
              final fade = t > 0.7 ? (1 - (t - 0.7) / 0.3) : 1.0;
              return Opacity(
                // Clamped: (1 - 0.7) / 0.3 > 1 in binary float, so the fade
                // ends ~-2e-16 at t == 1.0 and trips Opacity's assert.
                opacity: (appear * fade).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - appear) * 10),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.78),
                border: Border.all(color: Cyber.cyan.withValues(alpha: 0.6)),
              ),
              child: Text(
                'P${overtake.overtakenPosition} ▲ PASSED '
                '${overtake.overtakenName.toUpperCase()}',
                style: Cyber.label(9, color: Cyber.cyan, letterSpacing: 1.4),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Result overlay layer
// ---------------------------------------------------------------------------

class _ResultLayer extends StatelessWidget {
  const _ResultLayer({required this.onExit, required this.onRaceAgain});

  final VoidCallback onExit;
  final VoidCallback onRaceAgain;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrandPrixCubit, GrandPrixState>(
      buildWhen: (p, c) =>
          (p.phase == GrandPrixPhase.result) !=
          (c.phase == GrandPrixPhase.result),
      builder: (context, state) {
        final result = state.result;
        if (state.phase != GrandPrixPhase.result || result == null) {
          return const SizedBox.shrink();
        }
        return GrandPrixResultOverlay(
          result: result,
          circuitName: grandPrixCircuit(result.circuit).name,
          onExit: onExit,
          onRaceAgain: onRaceAgain,
        );
      },
    );
  }
}
