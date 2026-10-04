import 'dart:async';

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
import '../../utils/game_audio_mappings.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import 'widgets/grand_prix_controls.dart';
import 'widgets/grand_prix_result.dart';
import 'widgets/grand_prix_driving_hud.dart';
import 'widgets/grand_prix_race_feedback.dart';

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

class _GrandPrixRaceScreenState extends State<GrandPrixRaceScreen>
    with WidgetsBindingObserver {
  late final GrandPrixCubit _cubit;
  late final GrandPrixGame _game;
  RaceSetup? _setup;
  final String _questMatchId = 'quest-${DateTime.now().microsecondsSinceEpoch}';
  bool _rewardsDispatched = false;
  bool _lightsScheduled = false;
  bool _lightsOutSounded = false;
  bool _engineStarted = false;
  bool _hasLaunched = false;
  int _lastLightsOn = 0;
  Timer? _engineTimer;
  Timer? _lightsTimer;
  Timer? _finishTimer;
  Timer? _momentTimer;
  final ValueNotifier<GrandPrixMoment?> _moment = ValueNotifier(null);
  DateTime? _lastMomentAt;
  int _pauseReset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      onPlayerFinished: _onPlayerFinished,
      onAudioEvent: _onRaceAudioEvent,
      reducedMotion: reducedMotion,
      onMoment: _onMoment,
    );
    AudioController.instance.enterGrandPrixScene(_questMatchId);
    // The phase is already `grid` when this screen mounts, so the
    // BlocListener never fires for it — kick off the lights beat here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleLights();
    });
  }

  void _scheduleLights() {
    if (_lightsScheduled || !_cubit.state.stats.coachSeen) return;
    _lightsScheduled = true;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    _lightsTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted &&
          _game.isLoaded &&
          _cubit.state.phase == GrandPrixPhase.grid) {
        _cubit.beginLights(reducedMotion: reducedMotion);
      } else if (mounted && !_game.isLoaded) {
        _lightsScheduled = false;
        _scheduleLights();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _momentTimer?.cancel();
    _lightsTimer?.cancel();
    _finishTimer?.cancel();
    _moment.dispose();
    _engineTimer?.cancel();
    AudioController.instance.leaveGrandPrixScene(_questMatchId);
    _game.stopRace();
    // Leaving mid-race discards the attempt (no stats, no reward). A RACE
    // AGAIN relaunch has already replaced the setup by the time this route
    // is disposed — the identity check keeps us from resetting the new race.
    final phase = _cubit.state.phase;
    final midRace =
        phase == GrandPrixPhase.grid ||
        phase == GrandPrixPhase.lights ||
        phase == GrandPrixPhase.racing ||
        phase == GrandPrixPhase.paused;
    if (midRace && identical(_cubit.state.setup, _setup)) {
      _cubit.abandonRace();
    }
    super.dispose();
  }

  void _onOvertake(OvertakeEvent event) {
    _cubit.onOvertake(event);
    playSound(SoundEffect.gpOvertake);
    if (_cubit.state.stats.hapticsEnabled) HapticFeedback.selectionClick();
  }

  void _onMoment(GrandPrixMoment moment) {
    if (!mounted) return;
    final now = DateTime.now();
    if (moment.kind == GrandPrixMomentKind.cleanCorner &&
        _lastMomentAt != null &&
        now.difference(_lastMomentAt!) < const Duration(milliseconds: 1600)) {
      return;
    }
    _lastMomentAt = now;
    _momentTimer?.cancel();
    _moment.value = moment;
    if (moment.kind == GrandPrixMomentKind.cleanPass) {
      playSound(SoundEffect.uiConfirm);
      if (_cubit.state.stats.hapticsEnabled) HapticFeedback.lightImpact();
    }
    _momentTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) _moment.value = null;
    });
  }

  void _pauseRace() {
    final phase = _cubit.state.phase;
    if (phase == GrandPrixPhase.finished || phase == GrandPrixPhase.result) {
      return;
    }
    _game.stopRace();
    _lightsTimer?.cancel();
    _lightsScheduled = false;
    _engineTimer?.cancel();
    _engineStarted = false;
    AudioController.instance.stopGrandPrixAudio(_questMatchId);
    _cubit.pauseRace();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      _pauseRace();
      setState(() => _pauseReset++);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final relevant = {
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.escape,
    };
    if (!relevant.contains(key)) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      _pauseRace();
      return KeyEventResult.handled;
    }
    if (_cubit.state.phase != GrandPrixPhase.racing &&
        _cubit.state.phase != GrandPrixPhase.lights) {
      _game.clearInputs();
      return KeyEventResult.handled;
    }
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final throttle =
        keys.contains(LogicalKeyboardKey.keyW) ||
        keys.contains(LogicalKeyboardKey.arrowUp);
    _game.setInputs(
      left:
          keys.contains(LogicalKeyboardKey.keyA) ||
          keys.contains(LogicalKeyboardKey.arrowLeft),
      right:
          keys.contains(LogicalKeyboardKey.keyD) ||
          keys.contains(LogicalKeyboardKey.arrowRight),
      throttle: throttle,
      brake:
          keys.contains(LogicalKeyboardKey.keyS) ||
          keys.contains(LogicalKeyboardKey.arrowDown),
      deploy: keys.contains(LogicalKeyboardKey.space),
    );
    if (throttle &&
        event is KeyDownEvent &&
        _cubit.state.phase == GrandPrixPhase.lights) {
      _cubit.registerThrottleTap();
    }
    return KeyEventResult.handled;
  }

  void _onPlayerFinished(PlayerRaceOutcome outcome) {
    if (!outcome.dnf) playSound(SoundEffect.gpFinish);
    _cubit.onRaceFinished(outcome);
  }

  void _onRaceAudioEvent(GrandPrixAudioEvent event) {
    playSound(grandPrixEventSound(event));
  }

  void _drive(BuildContext context, GrandPrixState state) {
    if (state.lightsOn > _lastLightsOn) {
      playSound(SoundEffect.gpLightOn);
    }
    if (state.lightsOut &&
        !_lightsOutSounded &&
        state.launchGrade != LaunchGrade.jump) {
      _lightsOutSounded = true;
      playSound(SoundEffect.gpLightsOut);
    }
    _lastLightsOn = state.lightsOn;
    switch (state.phase) {
      case GrandPrixPhase.grid:
        _scheduleLights();
      case GrandPrixPhase.racing:
        final grade = state.launchGrade;
        if (grade != null) {
          _game.startRace(grade);
          _startEngineAudio();
          if (!_hasLaunched) {
            _hasLaunched = true;
            if (grade == LaunchGrade.jump) playSound(SoundEffect.gpJumpStart);
            if (_cubit.state.stats.hapticsEnabled &&
                grade == LaunchGrade.jump) {
              HapticFeedback.heavyImpact();
            } else if (_cubit.state.stats.hapticsEnabled) {
              HapticFeedback.mediumImpact();
            }
          }
        }
      case GrandPrixPhase.finished:
        _onFinished(state);
      case GrandPrixPhase.paused:
        _game.stopRace();
      case GrandPrixPhase.idle:
      case GrandPrixPhase.lights:
      case GrandPrixPhase.result:
        break;
    }
  }

  void _startEngineAudio() {
    if (_engineStarted) return;
    _engineStarted = true;
    AudioController.instance.startGrandPrixAudio(_questMatchId);
    _engineTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      final t = _game.telemetry.value;
      AudioController.instance.updateGrandPrixAudio(
        _questMatchId,
        rpm: t.rpm,
        load: t.throttle,
        speed: (_game.speedKph.value / 320).clamp(0.0, 1.0),
        scrub: (1 - t.grip) * 3 + t.brake * 0.1,
      );
    });
  }

  void _onFinished(GrandPrixState state) {
    final result = state.result;
    if (_rewardsDispatched || result == null) return;
    _rewardsDispatched = true;
    _game.stopRace();
    _engineTimer?.cancel();
    AudioController.instance.stopGrandPrixAudio(_questMatchId);
    final resultCue = result.retired
        ? SoundEffect.gpDnf
        : result.position <= 3
        ? SoundEffect.gpPodium
        : result.verdict == GrandPrixVerdict.points
        ? SoundEffect.gpPoints
        : null;
    if (resultCue != null) playSound(resultCue);
    if (_cubit.state.stats.hapticsEnabled) HapticFeedback.heavyImpact();
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
        matchId: _questMatchId,
        position: result.position,
        fieldSize: result.fieldSize,
        circuitName: circuitLabel,
        lapTimeMs: result.lapTimeMs,
        verdictLabel: verdictLabel,
        xp: result.xp,
      ),
    );
    _finishTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _cubit.showResult();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: BlocListener<GrandPrixCubit, GrandPrixState>(
        listenWhen: (p, c) =>
            p.phase != c.phase ||
            p.launchGrade != c.launchGrade ||
            p.lightsOn != c.lightsOn ||
            p.lightsOut != c.lightsOut,
        listener: _drive,
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          onFocusChange: (focused) {
            if (!focused && _cubit.state.phase == GrandPrixPhase.racing) {
              _pauseRace();
            }
          },
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeFocus(
                    child: GameWidget(game: _game, autofocus: false),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: GrandPrixDrivingHud(game: _game, onPause: _pauseRace),
                ),
                Align(child: _LightsRig()),
                _LaunchGradeFlash(),
                _LapFlash(game: _game),
                _StuckWarning(game: _game),
                _OvertakeToast(),
                GrandPrixMomentToast(moment: _moment),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: BlocBuilder<GrandPrixCubit, GrandPrixState>(
                    builder: (context, state) {
                      _game.reducedMotion =
                          MediaQuery.disableAnimationsOf(context) ||
                          state.stats.reducedEffects;
                      final enabled =
                          (state.phase == GrandPrixPhase.racing ||
                              state.phase == GrandPrixPhase.lights ||
                              state.phase == GrandPrixPhase.grid) &&
                          state.stats.coachSeen;
                      if (!enabled) return const SizedBox.shrink();
                      return GrandPrixControls(
                        key: ValueKey('live:${state.stats.classicControls}'),
                        classicControls: state.stats.classicControls,
                        onSteer: (value) => _game.setInputs(steer: value),
                        onDeploy: (down) => _game.setInputs(deploy: down),
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
                      );
                    },
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.52),
                  child: ValueListenableBuilder<double>(
                    valueListenable: _game.stuckSeconds,
                    builder: (context, seconds, _) => seconds < 2.5
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 64),
                            child: HudCtaButton(
                              label: 'RECOVER · 3s',
                              accent: Cyber.amber,
                              onTap: _game.recoverPlayer,
                            ),
                          ),
                  ),
                ),
                BlocBuilder<GrandPrixCubit, GrandPrixState>(
                  builder: (context, state) {
                    if (state.phase == GrandPrixPhase.paused) {
                      return Positioned.fill(
                        child: GrandPrixPauseLayer(
                          key: ValueKey(_pauseReset),
                          onExit: widget.onExit,
                          onResume: () => _cubit.resumeRace(
                            reducedMotion: MediaQuery.disableAnimationsOf(
                              context,
                            ),
                          ),
                        ),
                      );
                    }
                    if (state.phase == GrandPrixPhase.grid &&
                        !state.stats.coachSeen) {
                      return Positioned.fill(
                        child: GrandPrixGridCoach(
                          onReady: () {
                            _cubit.acknowledgeCoach();
                            _scheduleLights();
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                _ResultLayer(
                  questMatchId: _questMatchId,
                  onExit: widget.onExit,
                  onRaceAgain: widget.onRaceAgain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top HUD: exit · position · lap bar · speed
// ---------------------------------------------------------------------------

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
        final visible =
            state.phase == GrandPrixPhase.grid ||
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
        border: Border.all(color: on ? Cyber.danger : Cyber.border, width: 1.4),
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
    playSound(SoundEffect.gpLap);
    if (context.read<GrandPrixCubit>().state.stats.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
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
            style: Cyber.display(
              15,
              color: color,
              letterSpacing: 2,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Cyber.danger,
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  'GET BACK ON TRACK',
                  style: Cyber.display(
                    16,
                    color: Cyber.danger,
                    letterSpacing: 2,
                  ),
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
  const _ResultLayer({
    required this.questMatchId,
    required this.onExit,
    required this.onRaceAgain,
  });

  final String questMatchId;
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
          questMatchId: questMatchId,
          result: result,
          circuitName: grandPrixCircuit(result.circuit).name,
          onExit: onExit,
          onRaceAgain: onRaceAgain,
        );
      },
    );
  }
}
