/// The Flame rendering boundary for Final Over.
///
/// [MatchController] (inside the `final_over` package) remains the ONLY
/// gameplay authority. This class advances its fixed-step clock and projects
/// the resulting immutable [MatchState] onto the canvas. It decides no run, no
/// wicket, no score — if you find yourself reaching for a rule here, it belongs
/// in the package.
///
/// The HUD is fed by [ValueNotifier]s, never by a bloc: a bloc emission per
/// frame at 60fps would rebuild the widget tree 60 times a second. The cubit
/// only ever hears about the coarse beats (match ended).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:final_over/final_over.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../data/final_over_kits.dart';
import 'final_over_rig.dart';
import 'final_over_tuning.dart';

/// A short, loud banner: SIX / FOUR / OUT / PERFECT.
class FinalOverSting {
  const FinalOverSting(this.label, this.color, {this.major = false});
  final String label;
  final Color color;
  final bool major;
}

/// Visual progress along the incoming delivery at which it reaches the pitch.
double finalOverBounceProgress(DeliveryLength length) => switch (length) {
  DeliveryLength.short => 0.42,
  DeliveryLength.good => 0.56,
  DeliveryLength.full => 0.70,
  DeliveryLength.yorker => 0.82,
};

bool finalOverShouldShowBounceMarker({
  required MatchPhase phase,
  required MatchPhase? suspendedPhase,
  required DeliveryLength length,
  required double incomingProgress,
}) {
  final activePhase = phase == MatchPhase.paused ? suspendedPhase : phase;
  return activePhase == MatchPhase.deliveryPreparation ||
      activePhase == MatchPhase.bowlerRunUp ||
      (activePhase == MatchPhase.incomingBall &&
          incomingProgress < finalOverBounceProgress(length));
}

/// One perspective projection shared by every element in the batting camera.
@immutable
class FinalOverBattingProjection {
  const FinalOverBattingProjection._({
    required this.size,
    required this.farY,
    required this.nearY,
    required this.farHalfWidth,
    required this.nearHalfWidth,
  });

  factory FinalOverBattingProjection.forViewport(
    Size size, {
    double? controlDeckTop,
  }) {
    final farY = size.height * (FinalOverGame.horizonFraction + 0.055);
    final requestedNearY = (controlDeckTop ?? size.height * 0.78) - 12;
    final bandedNearY = requestedNearY.clamp(
      size.height * 0.68,
      size.height * 0.78,
    );
    // Prefer the 68–78% band, but let the measured CTA win on compact screens:
    // the pitch may shrink further, never overlap the controls.
    final nearY = math.min(bandedNearY, requestedNearY);
    return FinalOverBattingProjection._(
      size: size,
      farY: farY,
      nearY: nearY,
      farHalfWidth: size.width * 0.042,
      nearHalfWidth: size.width * 0.21 * 0.82,
    );
  }

  final Size size;
  final double farY;
  final double nearY;
  final double farHalfWidth;
  final double nearHalfWidth;

  double get centerX => size.width * 0.5;

  double halfWidthAt(double depth) =>
      farHalfWidth + (nearHalfWidth - farHalfWidth) * depth.clamp(0, 1);

  Offset pointAt({required double depth, double lateral = 0}) {
    final d = depth.clamp(0.0, 1.0);
    final lateralScale = size.width * (0.55 + (1.25 - 0.55) * d);
    return Offset(centerX + lateral * lateralScale, farY + (nearY - farY) * d);
  }

  Offset incomingPoint(DeliverySpec delivery, double progress) => pointAt(
    depth: 0.08 + 0.78 * progress.clamp(0.0, 1.0),
    lateral: delivery.contactX,
  );

  Offset bouncePoint(DeliverySpec delivery) =>
      incomingPoint(delivery, finalOverBounceProgress(delivery.length));
}

class FinalOverGame extends FlameGame {
  FinalOverGame({
    required this.controller,
    required this.kit,
    required this.opponentKit,
    required this.onEvents,
    this.batsmanIds = const [],
    this.reducedMotion = false,
  });

  final MatchController controller;
  final FinalOverKit kit;
  final FinalOverKit opponentKit;
  final List<String> batsmanIds;
  final bool reducedMotion;

  /// Coarse beats out to the screen (sound, haptics, cubit phase changes).
  final void Function(GameplayEvent event) onEvents;

  // ── HUD bindings — cheap 60fps reads, never bloc emissions. ────────────────
  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> wickets = ValueNotifier(0);
  final ValueNotifier<int> ballsLeft = ValueNotifier(6);
  final ValueNotifier<int> runsNeeded = ValueNotifier(0);
  final ValueNotifier<int> target = ValueNotifier(0);
  final ValueNotifier<int> combo = ValueNotifier(1);
  final ValueNotifier<int> powerSegments = ValueNotifier(0);
  final ValueNotifier<bool> powerArmed = ValueNotifier(false);
  final ValueNotifier<bool> freeHit = ValueNotifier(false);
  final ValueNotifier<Elevation> elevation = ValueNotifier(Elevation.ground);
  final ValueNotifier<ShotDirection> selectedDirection = ValueNotifier(
    ShotDirection.straight,
  );
  final ValueNotifier<MatchPhase> phase = ValueNotifier(MatchPhase.idle);
  final ValueNotifier<int> preparationSeconds = ValueNotifier(0);
  final ValueNotifier<bool> canConfigureShot = ValueNotifier(false);
  final ValueNotifier<bool> canSwing = ValueNotifier(false);
  final ValueNotifier<bool> successfulContact = ValueNotifier(false);
  final ValueNotifier<RiskLevel> risk = ValueNotifier(RiskLevel.safe);
  final ValueNotifier<bool> canRun = ValueNotifier(false);
  final ValueNotifier<double> runProgress = ValueNotifier(0);
  final ValueNotifier<int> completedRuns = ValueNotifier(0);
  final ValueNotifier<bool> canTurnBack = ValueNotifier(false);

  final ValueNotifier<List<BallResult>> history = ValueNotifier(const []);
  final ValueNotifier<FinalOverSting?> sting = ValueNotifier(null);

  StreamSubscription<GameplayEvent>? _events;

  final List<FieldVector> _trail = <FieldVector>[];
  int _trailDeliveryOrdinal = -1;
  double _visualSeconds = 0;
  double _effectStartedAt = -10;
  GameplayEventType? _effect;
  int _effectSeed = 0;
  double _bowlerRunPhase = 0;
  double _stingClearAt = -1;
  double? _battingControlDeckTop;

  /// The finger is on HIT. A hold is cancelled whenever the live-ball input
  /// window closes, so it can never leak into the next delivery.
  bool _swingHeld = false;

  /// Engine time (matches `s.simulationMicros`) the current hold began. Null
  /// whenever `_swingHeld` is false. Drives the backlift hold-to-load ramp in
  /// `_batterProgress`; purely a render concern — the grading engine only
  /// ever sees the real release timestamp.
  int? _swingHeldAtMicros;

  MatchState get state => controller.state;
  GameplayTuning get tuning => controller.tuning;

  /// Updates the visual safe boundary; it never participates in game rules.
  void setBattingControlDeckTop(double top) {
    if (top.isFinite) _battingControlDeckTop = top;
  }

  /// Combo segments OVERDRIVE costs. Read from the engine so the plate can
  /// never light up for a shot the controller will refuse.
  int get overdriveRequirement => tuning.powerShotSegments;

  @override
  Color backgroundColor() => Cyber.bg;

  @override
  Future<void> onLoad() async {
    _events = controller.eventStream.listen(_onEvent);
  }

  @override
  void onRemove() {
    _events?.cancel();
    for (final n in <ValueNotifier<Object?>>[
      score,
      wickets,
      ballsLeft,
      runsNeeded,
      target,
      combo,
      powerSegments,
      powerArmed,
      freeHit,
      elevation,
      selectedDirection,
      phase,
      preparationSeconds,
      canConfigureShot,
      canSwing,
      successfulContact,
      risk,
      canRun,
      runProgress,
      completedRuns,
      canTurnBack,
      history,
      sting,
    ]) {
      n.dispose();
    }
    super.onRemove();
  }

  // ── Input (imperative, no state of its own) ────────────────────────────────

  /// Leaves the engine's `matchIntro` — until this lands, the fixed tick is a
  /// no-op and no ball is bowled. The intro overlay calls it when its countdown
  /// hits zero.
  void start() => controller.dispatch(const StartCommand());

  void selectElevation(Elevation e) =>
      controller.dispatch(SelectElevationCommand(e));

  void selectDirection(ShotDirection direction) =>
      controller.dispatch(SelectDirectionCommand(direction));

  /// Press: show a brief backlift while the player waits to release.
  void beginSwing() {
    if (_swingHeld) return;
    final s = controller.state;
    if (!_swingWindowOpen(s)) return;
    _swingHeld = true;
    _swingHeldAtMicros = s.simulationMicros;
  }

  /// Release: the swing itself. The engine grades when it is released.
  void releaseSwing() {
    if (!_swingHeld) return;
    _swingHeld = false;
    _swingHeldAtMicros = null;
    final s = controller.state;
    controller.dispatch(SwingCommand(s.selectedDirection));
  }

  /// The finger slid off the plate, or the deck swapped under it. No swing.
  void cancelSwing() {
    _swingHeld = false;
    _swingHeldAtMicros = null;
  }

  /// The CTA only becomes interactive during the engine's legal swing window.
  bool _swingWindowOpen(MatchState s) => s.canSwing;

  void activatePowerShot() =>
      controller.dispatch(const ActivatePowerShotCommand());
  void startRun() => controller.dispatch(const StartRunCommand());
  void holdBall() => controller.dispatch(const HoldBallCommand());
  void turnBack() => controller.dispatch(const TurnBackCommand());
  void pause() {
    cancelSwing();
    controller.dispatch(const PauseCommand());
  }

  void resume() => controller.dispatch(const ResumeCommand());
  void backgrounded() {
    cancelSwing();
    controller.dispatch(const AppBackgroundedCommand());
  }

  // ── Loop ──────────────────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);
    if (!dt.isFinite || dt <= 0) return;
    final bounded = dt.clamp(0.0, 1 / 30);
    _visualSeconds += bounded;

    controller.step(
      Duration(
        microseconds: (bounded * Duration.microsecondsPerSecond).round(),
      ),
    );

    final s = controller.state;
    _captureTrail(s);
    if (s.phase == MatchPhase.bowlerRunUp) {
      _bowlerRunPhase += bounded * kFoRunUpCycle;
    }
    if (_stingClearAt > 0 && _visualSeconds >= _stingClearAt) {
      sting.value = null;
      _stingClearAt = -1;
    }
    _syncNotifiers(s);
  }

  void _syncNotifiers(MatchState s) {
    score.value = s.score;
    wickets.value = s.wickets;
    ballsLeft.value = s.ballsRemaining;
    runsNeeded.value = s.runsNeeded;
    target.value = s.target;
    combo.value = s.combo;
    powerSegments.value = s.powerSegments;
    powerArmed.value = s.powerShotArmed;
    freeHit.value = s.freeHit || s.currentDeliveryFreeHit;
    elevation.value = s.selectedElevation;
    selectedDirection.value = s.selectedDirection;
    phase.value = s.phase;
    canConfigureShot.value = s.canConfigureShot;
    canSwing.value = s.canSwing;
    preparationSeconds.value = s.phase == MatchPhase.deliveryPreparation
        ? ((tuning.deliveryPreparationMicros - s.phaseElapsedMicros) /
                  Duration.microsecondsPerSecond)
              .ceil()
              .clamp(1, 3)
        : 0;
    risk.value = s.runner.risk;
    canRun.value = s.canRun;
    completedRuns.value = s.runner.completedRuns;
    canTurnBack.value = s.runner.canTurnBack;
    // Quantised so an unchanged bar never notifies.
    _setDouble(runProgress, (s.runner.progress * 100).round() / 100);
    if (!s.canSwing) {
      _swingHeld = false;
      _swingHeldAtMicros = null;
    }
    if (!identical(history.value, s.history)) history.value = s.history;
  }

  void _setDouble(ValueNotifier<double> n, double v) {
    if ((n.value - v).abs() > 0.001) n.value = v;
  }

  void _onEvent(GameplayEvent event) {
    switch (event.type) {
      case GameplayEventType.contactResolved:
        if (controller.state.contactOutcome?.madeContact == true) {
          successfulContact.value = true;
        }
        _effect = event.type;
        _effectStartedAt = _visualSeconds;
        _effectSeed = controller.state.currentDelivery?.seed ?? 0;
        break;
      case GameplayEventType.boundary:
      case GameplayEventType.wicket:
      case GameplayEventType.catchTaken:
      case GameplayEventType.catchDropped:
      case GameplayEventType.runOut:
      case GameplayEventType.runCompleted:
        _effect = event.type;
        _effectStartedAt = _visualSeconds;
        _effectSeed = controller.state.currentDelivery?.seed ?? 0;
      default:
        break;
    }
    _stingFor(event);
    onEvents(event);
  }

  void _stingFor(GameplayEvent event) {
    final s = controller.state;
    FinalOverSting? next;
    switch (event.type) {
      case GameplayEventType.boundary:
        final six = s.lastResult?.boundary == 6 || s.ledger.boundary == 6;
        next = six
            ? const FinalOverSting('SIX', Cyber.gold, major: true)
            : const FinalOverSting('FOUR', Cyber.cyan, major: true);
      case GameplayEventType.wicket:
        next = const FinalOverSting('OUT', Cyber.danger, major: true);
      case GameplayEventType.runOut:
        next = const FinalOverSting('RUN OUT', Cyber.danger, major: true);
      case GameplayEventType.catchDropped:
        next = const FinalOverSting('DROPPED', Cyber.lime);
      case GameplayEventType.powerShotActivated:
        next = const FinalOverSting('POWER SHOT', Cyber.magenta, major: true);
      case GameplayEventType.extraAwarded:
        next = FinalOverSting(
          s.currentDelivery?.isNoBall == true ? 'NO BALL · FREE HIT' : 'WIDE',
          Cyber.amber,
        );
      case GameplayEventType.contactResolved:
        if (s.contactOutcome?.timing == TimingGrade.perfect) {
          next = const FinalOverSting('PERFECT', Cyber.lime);
        }
      default:
        return;
    }
    if (next == null) return;
    sting.value = next;
    _stingClearAt =
        _visualSeconds +
        (next.major ? kFoStingMajorMs : kFoStingMinorMs) / 1000;
  }

  void _captureTrail(MatchState s) {
    final ordinal = s.currentDelivery?.ordinal ?? -1;
    if (ordinal != _trailDeliveryOrdinal) {
      _trailDeliveryOrdinal = ordinal;
      _trail.clear();
    }
    final position = s.ball?.position;
    if (position == null) return;
    if (_trail.isEmpty || _trail.last.distanceTo(position) >= 0.025) {
      _trail.add(position);
      if (_trail.length > 30) _trail.removeAt(0);
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────
  @override
  void render(Canvas canvas) {
    if (!hasLayout) return;
    final viewport = Size(size.x, size.y);
    if (viewport.isEmpty) return;

    final s = controller.state;
    final transition = s.cameraTransition.clamp(0.0, 1.0);
    final age = (_visualSeconds - _effectStartedAt).clamp(0.0, 2.0);
    final shake = reducedMotion ? Offset.zero : _shake(age);
    final zoom = reducedMotion ? 1.0 : _zoom(age);

    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    canvas.translate(viewport.width / 2, viewport.height / 2);
    canvas.scale(zoom);
    canvas.translate(-viewport.width / 2, -viewport.height / 2);

    if (transition < 1) {
      _withOpacity(
        canvas,
        viewport,
        1 - Curves.easeInCubic.transform(transition),
        () => _paintBattingView(canvas, viewport, s),
      );
    }
    if (transition > 0) {
      _withOpacity(
        canvas,
        viewport,
        Curves.easeOutCubic.transform(transition),
        () => _paintFieldView(canvas, viewport, s),
      );
    }
    canvas.restore();

    _paintEffects(canvas, viewport, s, age);
    if (s.ballsRemaining == 1 && !s.isTerminal) {
      _paintFinalBallVignette(canvas, viewport);
    }
    super.render(canvas);
  }

  void _withOpacity(
    Canvas canvas,
    Size size,
    double opacity,
    VoidCallback paint,
  ) {
    if (opacity <= 0) return;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
    paint();
    canvas.restore();
  }

  /// Where the grass starts — directly under the hoardings, so there is no
  /// no-man's-land between the boards and the rope. The pitch's far edge is
  /// pinned just below it (see [_paintPerspectivePitch]), which is what keeps
  /// the rope, the bowler's feet and the vanishing point agreeing on which way
  /// is *away*.
  static const double horizonFraction = 0.29;

  /// How loud the ground is. Idles low, jumps on a boundary or a wicket, and
  /// settles back over a couple of seconds — the crowd is the scoreboard you
  /// hear.
  double get _crowdHype {
    final loud = switch (_effect) {
      GameplayEventType.boundary => 1.0,
      GameplayEventType.wicket || GameplayEventType.runOut => 0.85,
      GameplayEventType.catchTaken || GameplayEventType.catchDropped => 0.6,
      _ => 0.0,
    };
    if (loud == 0) return kFoCrowdIdleHype;
    final age = ((_visualSeconds - _effectStartedAt) / kFoCrowdHypeSeconds)
        .clamp(0.0, 1.0);
    return kFoCrowdIdleHype +
        loud *
            (1 - Curves.easeOutCubic.transform(age)) *
            (1 - kFoCrowdIdleHype);
  }

  /// The ground, drawn: night sky, floodlights, a bowl of crowd, the hoardings,
  /// the sightscreen behind the bowler's arm, and the outfield running away to
  /// the rope. Back to front, flat fills and lit lines — the lamps are the only
  /// thing allowed to bloom.
  void _paintStadium(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizonY = h * horizonFraction;

    // Night sky over the ground.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizonY + 1),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, 0),
          Offset(w / 2, horizonY),
          [
            const Color(0xFF0B1C2B),
            const Color(0xFF07131F),
            const Color(0xFF030912),
          ],
          const [0.0, 0.48, 1.0],
        ),
    );
    final halo = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.14),
      width: w * 1.05,
      height: h * 0.30,
    );
    canvas.drawOval(
      halo,
      Paint()
        ..shader = ui.Gradient.radial(halo.center, halo.width / 2, [
          Cyber.cyan.withValues(alpha: 0.08),
          Colors.transparent,
        ]),
    );

    final standTop = h * 0.115;
    final standBottom = h * 0.245;
    _paintFloodlight(canvas, Offset(w * 0.07, standTop + 8), flip: false);
    _paintFloodlight(canvas, Offset(w * 0.93, standTop + 8), flip: true);
    _paintStands(canvas, size, standTop, standBottom);
    _paintSightscreen(canvas, size, standTop, standBottom);
    _paintHoardings(canvas, size, standBottom + h * 0.012);
    _paintOutfield(canvas, size, horizonY);
    _paintScanlines(canvas, size);
  }

  /// A pylon: two struts, a rack, and six lamps. The blur here is the only one
  /// in the scene — a floodlight is the one thing on a cricket ground that
  /// genuinely glows.
  void _paintFloodlight(Canvas canvas, Offset base, {required bool flip}) {
    final side = flip ? -1.0 : 1.0;
    final strut = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.30)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, base.translate(side * 14, -74), strut);
    canvas.drawLine(
      base.translate(side * 7, -2),
      base.translate(side * 21, -74),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );

    final rack = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: base.translate(side * 18, -84),
        width: 38,
        height: 24,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      rack,
      Paint()..color = Cyber.panel.withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      rack,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.45),
    );
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        canvas.drawCircle(
          Offset(rack.left + 8 + col * 11, rack.top + 8 + row * 9),
          2.6,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.62)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  /// The bowl. A curved back, a roof line, vomitories, tiers, and a few hundred
  /// people doing a Mexican wave in `sin`.
  void _paintStands(Canvas canvas, Size size, double top, double bottom) {
    final w = size.width;
    final h = size.height;
    final height = bottom - top;
    final hype = _crowdHype;

    final back = Path()
      ..moveTo(0, top)
      ..quadraticBezierTo(w * 0.5, top - h * 0.055, w, top)
      ..lineTo(w, bottom)
      ..quadraticBezierTo(w * 0.5, bottom + h * 0.035, 0, bottom)
      ..close();
    canvas.drawPath(
      back,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, top),
          Offset(w / 2, bottom),
          [
            Cyber.panel2.withValues(alpha: 0.88),
            Cyber.bg.withValues(alpha: 0.96),
          ],
        ),
    );
    canvas.drawPath(
      back,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Cyber.cyan.withValues(alpha: 0.20),
    );

    final roof = Path()
      ..moveTo(0, top - h * 0.010)
      ..quadraticBezierTo(w * 0.5, top - h * 0.066, w, top - h * 0.010)
      ..lineTo(w, top + h * 0.009)
      ..quadraticBezierTo(w * 0.5, top - h * 0.044, 0, top + h * 0.009)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF0F2334));
    canvas.drawPath(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.22),
    );

    // Vomitories — the aisles that break the crowd into blocks.
    for (var i = 1; i < 8; i++) {
      final x = w * i / 8;
      final inset = (i - 4).abs() * h * 0.004;
      canvas.drawLine(
        Offset(x, top - inset),
        Offset(x, bottom),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.07)
          ..strokeWidth = 1,
      );
    }

    // The crowd. Mostly a dark mass of heads — a stand full of neon would be a
    // rainbow, not a crowd — with the odd shirt catching the light. Positions
    // are hashed off the index, never a per-frame Random.
    final wave = reducedMotion ? 0.0 : 1.0;
    const rows = 5;
    final perRow = kFoCrowdDots ~/ rows;
    for (var i = 0; i < kFoCrowdDots; i++) {
      final row = i ~/ perRow;
      final col = i % perRow;
      // Odd rows sit half a seat over, so the heads stagger like real seating.
      final jitter = _hash(i) - 0.5;
      final x =
          (col + (row.isOdd ? 0.5 : 0.0) + jitter * 0.4) * (w / perRow) - 4;
      final bob =
          math.sin(_visualSeconds * (1.4 + hype * 2.4) + col * 0.55 + row) *
          (0.4 + hype * 1.6) *
          wave;
      final y = top + height * 0.22 + row * height / 6.6 + bob;

      final lit = i % 9 == 0;
      final color = lit
          ? (i % 27 == 0 ? Cyber.cyan : Cyber.amber)
          : const Color(0xFF243449);
      canvas.drawCircle(
        Offset(x, y),
        1.05 + _hash(i * 7) * 0.5,
        Paint()
          ..color = color.withValues(alpha: lit ? 0.40 + hype * 0.35 : 0.72),
      );
      // Camera flashes, but only when there is something worth shooting.
      if (hype > 0.6 && i % 13 == 0) {
        if (math.sin(_visualSeconds * 9 + i * 2.3) > 0.88) {
          canvas.drawCircle(
            Offset(x, y - 1),
            1.7,
            Paint()..color = Colors.white.withValues(alpha: 0.5 * hype),
          );
        }
      }
    }
  }

  /// Cheap deterministic 0..1 from an int — a seedless stand-in for a Random we
  /// must not allocate per frame.
  double _hash(int i) {
    final v = math.sin(i * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// The sightscreen, directly behind the bowler's arm — the one piece of
  /// stadium furniture that exists purely so you can pick the ball up. Pale, so
  /// a red ball reads against it, and panelled so it looks built rather than
  /// pasted on.
  void _paintSightscreen(Canvas canvas, Size size, double top, double bottom) {
    final height = bottom - top;
    final face = Rect.fromLTRB(
      size.width * 0.395,
      top + height * 0.26,
      size.width * 0.555,
      bottom - height * 0.06,
    );

    // Legs first, so the face sits on them.
    for (final x in [
      face.left + face.width * 0.22,
      face.right - face.width * 0.22,
    ]) {
      canvas.drawLine(
        Offset(x, face.bottom),
        Offset(x, bottom + size.height * 0.012),
        Paint()
          ..color = const Color(0xFF0B1420)
          ..strokeWidth = 3,
      );
    }

    canvas.drawRect(face, Paint()..color = const Color(0xFFB9C4CE));
    canvas.drawRect(face.deflate(2), Paint()..color = const Color(0xFFD6DEE6));
    // Panel seams.
    for (var i = 1; i < 4; i++) {
      final x = face.left + face.width * i / 4;
      canvas.drawLine(
        Offset(x, face.top + 2),
        Offset(x, face.bottom - 2),
        Paint()
          ..color = const Color(0xFF9AA6B2)
          ..strokeWidth = 1,
      );
    }
    canvas.drawRect(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.line.withValues(alpha: 0.8),
    );
  }

  /// The hoarding ring. Calm chrome — it is advertising, not a moment.
  void _paintHoardings(Canvas canvas, Size size, double y) {
    const labels = ['STATOZ', 'FINAL OVER', 'SIX TO WIN', 'PITCH DUEL'];
    final boardW = size.width / labels.length;
    final boardH = size.height * 0.026;
    for (var i = 0; i < labels.length; i++) {
      final rect = Rect.fromLTWH(i * boardW, y, boardW - 2, boardH);
      final accent = i.isEven ? Cyber.cyan : Cyber.amber;
      canvas.drawRect(
        rect,
        Paint()..color = Cyber.panel.withValues(alpha: 0.80),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: 0.32),
      );
      _paintCanvasLabel(
        canvas,
        labels[i],
        rect,
        Cyber.label(
          7,
          color: accent.withValues(alpha: 0.85),
          letterSpacing: 1.4,
        ),
      );
    }
  }

  void _paintCanvasLabel(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '',
    )..layout(maxWidth: rect.width - 8);
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  /// The outfield: turf from the rope to your feet, mown in bands, with the
  /// thirty-yard ring arcing across it.
  void _paintOutfield(Canvas canvas, Size size, double horizonY) {
    final w = size.width;
    final h = size.height;
    final turf = Rect.fromLTRB(0, horizonY, w, h);

    canvas.drawRect(
      turf,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, horizonY),
          Offset(w / 2, h),
          [
            const Color(0xFF174348),
            const Color(0xFF0C3338),
            const Color(0xFF06262D),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Mown bands, widening as they come at you.
    for (var i = 0; i < 6; i++) {
      final t0 = i / 6;
      final t1 = (i + 1) / 6;
      double band(double t) => horizonY + (h - horizonY) * t * t;
      if (i.isEven) continue;
      canvas.drawRect(
        Rect.fromLTRB(0, band(t0), w, band(t1)),
        Paint()..color = Colors.white.withValues(alpha: 0.013),
      );
    }

    // The rope, and the shadow it casts on the grass.
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(w, horizonY),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(0, horizonY + 3),
      Offset(w, horizonY + 3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..strokeWidth = 1,
    );

    // Thirty-yard ring — the far arc of it, seen almost edge-on.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.66),
        width: w * 1.30,
        height: h * 0.46,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.055),
    );
  }

  /// The same ground, from the blimp: a disc of turf mown in rings, the rope
  /// around it, the thirty-yard circle inside it, and the dark of the stands
  /// beyond. The fielders, the runners and the ball are painted on top of this
  /// by [_paintFieldView].
  void _paintGroundFromAbove(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
  ) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060B12),
    );

    final turf = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          const Color(0xFF17454A),
          const Color(0xFF0B3036),
        ]),
    );

    // Mown rings.
    for (var i = 1; i <= 5; i++) {
      if (i.isEven) continue;
      canvas.drawCircle(
        center,
        radius * i / 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius / 5
          ..color = Colors.white.withValues(alpha: 0.012),
      );
    }

    // Thirty-yard circle.
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // The rope.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      turf.deflate(-3),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _paintScanlines(canvas, size);
  }

  /// CRT scanlines — the same HUD texture the rest of the app wears.
  void _paintScanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  // ── Batting camera ────────────────────────────────────────────────────────
  void _paintBattingView(Canvas canvas, Size size, MatchState s) {
    final projection = FinalOverBattingProjection.forViewport(
      size,
      controlDeckTop: _battingControlDeckTop,
    );
    _paintStadium(canvas, size);
    _paintPerspectivePitch(canvas, projection, s);
    _paintBounceMarker(canvas, projection, s);
    _paintStumps(canvas, projection, s);

    // Depth by size: the bowler stands 20 metres away, so it is drawn small
    // and high; the batter is at your shoulder. Keep the head
    // of the batter (feet 0.88h, ~0.25h tall → crown ~0.63h) clear of the
    // bowler's feet (0.44h) or the two silhouettes collide mid-pitch.
    final bowlerPx = size.height * 0.145 * 0.85 / kFoReferenceHeightM;
    final (bowlerKind, bowlerT) = _bowlerPose(s);
    _paintActor(
      canvas,
      projection.pointAt(depth: 0.15, lateral: -0.065),
      bowlerPx,
      facing: 1,
      draw: (c, f) => drawFoBowler(
        c,
        foBowlerPose(bowlerKind, bowlerT, runPhase: _bowlerRunPhase),
        kit: opponentKit,
        look: finalOverLookFor('fo-bowler'),
        px: bowlerPx,
        heightM: kFoReferenceHeightM,
        number: finalOverNumberFor('fo-bowler'),
        facing: f,
        ballInHand:
            bowlerKind != FoBowlerPose.followThrough &&
            !(bowlerKind == FoBowlerPose.release && bowlerT > 0.72),
      ),
    );

    final strikerId = _strikerActorId;
    final batterPx = size.height * 0.25 * 0.85 / kFoReferenceHeightM;
    final batterKind = _batterPose(s);
    final batterT = _batterProgress(s);
    final frame = foBatterFrame(batterKind, batterT);
    final trailAngles = _batterTrailAngles(batterKind, batterT);
    _paintActor(
      canvas,
      projection.pointAt(depth: 0.84, lateral: 0.115),
      batterPx,
      facing: -1,
      draw: (c, f) => drawFoBatter(
        c,
        frame,
        kit: kit,
        look: finalOverLookFor(strikerId),
        px: batterPx,
        heightM: kFoReferenceHeightM,
        number: finalOverNumberFor(strikerId),
        facing: f,
        trailBatAngles: trailAngles,
      ),
    );

    _paintPerspectiveBall(canvas, projection, s);
  }

  /// Places an actor on the turf: ground shadow, then the rig. Turf is grass,
  /// not hardwood — no reflection.
  void _paintActor(
    Canvas canvas,
    Offset ground,
    double px, {
    required int facing,
    required void Function(Canvas canvas, int facing) draw,
  }) {
    canvas.save();
    canvas.translate(ground.dx, ground.dy);
    canvas.scale(facing.toDouble(), 1.0);

    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: px * 0.85, height: px * 0.16),
      Paint()..color = const Color(0x66000000),
    );

    draw(canvas, facing);
    canvas.restore();
  }

  /// The pitch receding to the bowler's end — a Cyber-toned trapezoid with
  /// creases. Flat fills and lit lines only: nothing here glows.
  void _paintPerspectivePitch(
    Canvas canvas,
    FinalOverBattingProjection projection,
    MatchState s,
  ) {
    final nearY = projection.nearY;
    final farY = projection.farY;
    final nearHalf = projection.nearHalfWidth;
    final farHalf = projection.farHalfWidth;
    final cx = projection.centerX;

    final pitch = Path()
      ..moveTo(cx - nearHalf, nearY)
      ..lineTo(cx + nearHalf, nearY)
      ..lineTo(cx + farHalf, farY)
      ..lineTo(cx - farHalf, farY)
      ..close();

    canvas.drawPath(
      pitch,
      Paint()
        ..shader = ui.Gradient.linear(Offset(cx, farY), Offset(cx, nearY), [
          const Color(0xFF6E5A3C),
          const Color(0xFF9C7F52),
        ]),
    );
    canvas.drawPath(
      pitch,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Creases — the batter's line, and the bowler's at the far end.
    void crease(double t, double alpha) {
      final point = projection.pointAt(depth: t);
      final half = projection.halfWidthAt(t);
      canvas.drawLine(
        Offset(cx - half * 1.08, point.dy),
        Offset(cx + half * 1.08, point.dy),
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..strokeWidth = 1 + t * 2,
      );
    }

    crease(0.14, 0.30);
    crease(0.78, 0.42);

    // The line the ball is on, shown only while it is in the air toward you.
    if (s.phase == MatchPhase.incomingBall && s.currentDelivery != null) {
      final delivery = s.currentDelivery!;
      canvas.drawLine(
        projection.incomingPoint(delivery, 0),
        projection.incomingPoint(delivery, 1),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.22)
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintBounceMarker(
    Canvas canvas,
    FinalOverBattingProjection projection,
    MatchState s,
  ) {
    final delivery = s.currentDelivery;
    if (delivery == null) return;
    final bounceProgress = finalOverBounceProgress(delivery.length);
    if (!finalOverShouldShowBounceMarker(
      phase: s.phase,
      suspendedPhase: s.suspendedPhase,
      length: delivery.length,
      incomingProgress: _incomingProgress(s),
    )) {
      return;
    }

    final point = projection.bouncePoint(delivery);
    final depth = 0.08 + 0.78 * bounceProgress;
    final radius = 7.0 + 6.0 * depth;
    final ring = Rect.fromCenter(
      center: point,
      width: radius * 2,
      height: radius * 0.72,
    );
    final glow = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final edge = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(ring, glow);
    canvas.drawOval(ring, edge);
    canvas.drawCircle(
      point,
      math.max(1.8, radius * 0.18),
      Paint()..color = Cyber.cyan,
    );
  }

  void _paintStumps(
    Canvas canvas,
    FinalOverBattingProjection projection,
    MatchState s,
  ) {
    final broken =
        s.ledger.dismissal == DismissalType.bowled ||
        s.lastResult?.dismissal == DismissalType.bowled;
    final size = projection.size;
    final cx = projection.centerX;
    final baseY = projection.pointAt(depth: 0.875).dy;
    final h = size.height * 0.095 * 0.85;
    final gap = size.width * 0.020 * 0.85;

    for (var i = -1; i <= 1; i++) {
      final lean = broken ? i * 0.28 : 0.0;
      final x = cx + i * gap;
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x + lean * h, baseY - h * (broken ? 0.82 : 1)),
        Paint()
          ..color = const Color(0xFFE8ECF3)
          ..strokeWidth = size.width * 0.011
          ..strokeCap = StrokeCap.round,
      );
    }
    // Bails.
    if (!broken) {
      canvas.drawLine(
        Offset(cx - gap, baseY - h),
        Offset(cx + gap, baseY - h),
        Paint()
          ..color = Cyber.amber
          ..strokeWidth = size.width * 0.008
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintPerspectiveBall(
    Canvas canvas,
    FinalOverBattingProjection projection,
    MatchState s,
  ) {
    final delivery = s.currentDelivery;
    if (delivery == null) return;
    final size = projection.size;

    double x;
    double y;
    double r;
    if (s.ball case final ball?) {
      final distance = ball.position.length.clamp(0.0, 1.0);
      x = size.width * (0.5 + ball.position.x * 0.24);
      y = size.height * (0.77 - distance * 0.34 - ball.height * 0.22);
      r = size.shortestSide * (0.037 - distance * 0.012) * 0.5;
    } else {
      final p = _incomingProgress(s);
      // Hold the ball in the hand until the arm has actually come over.
      if ((s.phase == MatchPhase.deliveryPreparation ||
              s.phase == MatchPhase.bowlerRunUp) &&
          s.phaseElapsedMicros < controller.tuning.runUpMicros * 0.78) {
        return;
      }
      final point = projection.incomingPoint(delivery, p);
      x = point.dx;
      y = point.dy;
      r = size.shortestSide * (0.018 + 0.026 * p) * 0.5 * 0.85;
    }

    _paintBall(canvas, Offset(x, y), r);
  }

  void _paintBall(Canvas canvas, Offset at, double r) {
    canvas.drawCircle(at, r, Paint()..color = const Color(0xFFC4342B));
    canvas.drawArc(
      Rect.fromCircle(center: at, radius: r * 0.72),
      -math.pi * 0.85 + _visualSeconds * 11,
      math.pi * 0.8,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.16),
    );
    canvas.drawCircle(
      at.translate(-r * 0.3, -r * 0.3),
      r * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  // ── Top-down fielding camera ──────────────────────────────────────────────
  void _paintFieldView(Canvas canvas, Size size, MatchState s) {
    final geometry = (
      center: Offset(size.width / 2, size.height / 2),
      radius: size.shortestSide * 0.445,
    );
    Offset at(FieldVector v) =>
        geometry.center + Offset(v.x, v.y) * geometry.radius;

    _paintGroundFromAbove(canvas, size, geometry.center, geometry.radius);

    // The strip.
    canvas.drawRect(
      Rect.fromCenter(
        center: geometry.center,
        width: geometry.radius * 0.11,
        height: geometry.radius * 0.46,
      ),
      Paint()..color = const Color(0xFF8A6E45).withValues(alpha: 0.85),
    );

    // Ball trail.
    if (_trail.length > 1) {
      final path = Path()..moveTo(at(_trail.first).dx, at(_trail.first).dy);
      for (final p in _trail.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color =
              (s.contactOutcome?.elevation == Elevation.loft
                      ? Cyber.gold
                      : Cyber.cyan)
                  .withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }

    final markerR = math.max(7.0, size.shortestSide * 0.019);
    for (final f in s.fielders) {
      drawFoFielderMark(
        canvas,
        at(f.position),
        markerR,
        kit: opponentKit,
        active: f.motion == FielderMotion.chasing || f.hasBall,
        facing: Offset(f.velocity.x, f.velocity.y),
      );
    }

    _paintRunners(canvas, at, markerR, s);

    if (s.ball case final ball?) {
      final center = at(ball.position);
      final r = math.max(
        4.5,
        size.shortestSide * (0.012 + ball.height.clamp(0.0, 0.3) * 0.04),
      );
      if (ball.aerial) {
        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(0, r * 1.8),
            width: r * 2.4,
            height: r * 0.8,
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.34),
        );
      }
      _paintBall(canvas, center, r);
    }

    if (s.phase == MatchPhase.throwInProgress) {
      final holder = s.fielders.where((f) => f.hasBall).firstOrNull;
      if (holder != null) {
        final targetEnd = s.runner.runNumber.isOdd
            ? const FieldVector(0, -0.21)
            : const FieldVector(0, 0.21);
        canvas.drawLine(
          at(holder.position),
          at(targetEnd),
          Paint()
            ..color = Cyber.amber.withValues(alpha: 0.55)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintRunners(
    Canvas canvas,
    Offset Function(FieldVector) at,
    double r,
    MatchState s,
  ) {
    final runner = s.runner;
    final direction = runner.runNumber.isOdd ? -1.0 : 1.0;
    final startY = direction > 0 ? -0.21 : 0.21;
    final endY = -startY;
    final strikerY = runner.active
        ? startY + (endY - startY) * runner.progress
        : (runner.completedRuns.isOdd ? -0.21 : 0.21);
    final nonStrikerY = runner.active
        ? -startY - (endY - startY) * runner.progress
        : -strikerY;

    drawFoRunnerMark(
      canvas,
      at(FieldVector(-0.025, strikerY)),
      r,
      kit: kit,
      number: finalOverNumberFor(_strikerActorId),
      striker: true,
      danger: runner.risk == RiskLevel.danger,
    );
    drawFoRunnerMark(
      canvas,
      at(FieldVector(0.025, nonStrikerY)),
      r,
      kit: kit,
      number: finalOverNumberFor(_partnerActorId),
      striker: false,
    );
  }

  String get _strikerActorId =>
      batsmanIds.isNotEmpty ? batsmanIds.first : 'fo-striker';

  String get _partnerActorId => batsmanIds.length > 1
      ? batsmanIds[1]
      : batsmanIds.isNotEmpty
      ? batsmanIds.first
      : 'fo-partner';

  // ── Pose selection (a projection of state, nothing more) ───────────────────
  (FoBowlerPose, double) _bowlerPose(MatchState s) {
    final p = s.phaseElapsedMicros / math.max(1, controller.tuning.runUpMicros);
    if (s.phase == MatchPhase.deliveryPreparation) {
      return (FoBowlerPose.ready, _visualSeconds);
    }
    if (s.phase == MatchPhase.bowlerRunUp) {
      if (p < 0.58) return (FoBowlerPose.runUp, p / 0.58);
      if (p < 0.80) return (FoBowlerPose.gather, (p - 0.58) / 0.22);
      return (FoBowlerPose.release, (p - 0.80) / 0.20);
    }
    if (s.phase == MatchPhase.incomingBall ||
        s.phase == MatchPhase.contact ||
        s.phase == MatchPhase.cameraTransition) {
      return (FoBowlerPose.followThrough, _incomingProgress(s));
    }
    return (FoBowlerPose.ready, _visualSeconds);
  }

  FoBatterPose _batterPose(MatchState s) {
    if (s.phase == MatchPhase.won) return FoBatterPose.celebrate;
    if (s.ledger.dismissal == DismissalType.bowled) return FoBatterPose.bowled;
    if (s.runner.active) return FoBatterPose.running;

    final outcome = s.contactOutcome;
    if (outcome != null && !outcome.madeContact) return FoBatterPose.miss;

    final swing = s.swingIntent;
    if (swing == null) {
      // Holding the swing control makes the batter visibly load up, while an
      // untouched bat still lifts slightly as the ball approaches.
      if (_swingHeld) return FoBatterPose.backlift;
      return s.phase == MatchPhase.incomingBall
          ? FoBatterPose.backlift
          : FoBatterPose.stance;
    }
    return switch ((s.selectedElevation, swing.direction)) {
      (Elevation.ground, ShotDirection.offSide) => FoBatterPose.groundOff,
      (Elevation.ground, ShotDirection.straight) => FoBatterPose.groundStraight,
      (Elevation.ground, ShotDirection.legSide) => FoBatterPose.groundLeg,
      (Elevation.loft, ShotDirection.offSide) => FoBatterPose.loftOff,
      (Elevation.loft, ShotDirection.straight) => FoBatterPose.loftStraight,
      (Elevation.loft, ShotDirection.legSide) => FoBatterPose.loftLeg,
    };
  }

  double _batterProgress(MatchState s) {
    if (s.phase == MatchPhase.won) return _visualSeconds - _effectStartedAt;
    if (s.ledger.dismissal == DismissalType.bowled) {
      return _visualSeconds - _effectStartedAt;
    }
    if (s.runner.active) return _bowlerRunPhase;
    final swing = s.swingIntent;
    if (swing == null) {
      if (_swingHeld) {
        final heldAt = _swingHeldAtMicros;
        // Defensive only — beginSwing() always sets both fields together.
        if (heldAt == null) return 1.0;
        // Deliberately NOT clamped to 1.0: `backlift` clamps the 0→1 windup
        // itself but reads the raw overflow to drive an idle coil for as
        // long as the hold continues past full cock.
        return ((s.simulationMicros - heldAt) / kFoBackliftLoadMicros)
            .clamp(0.0, double.infinity);
      }
      return s.phase == MatchPhase.incomingBall
          ? _incomingProgress(s)
          : _visualSeconds;
    }
    return ((s.simulationMicros - swing.inputMicros) / 520000).clamp(0.0, 1.0);
  }

  static const _trailPoses = {
    FoBatterPose.groundOff,
    FoBatterPose.groundStraight,
    FoBatterPose.groundLeg,
    FoBatterPose.loftOff,
    FoBatterPose.loftStraight,
    FoBatterPose.loftLeg,
    FoBatterPose.miss, // still a full-speed swing through the zone
  };

  /// Two recent past bat angles for a fading motion trail, oldest first.
  /// Only during the fast-motion middle of a committed swing (not the slow
  /// easeInOutCubic start/end), and never during stance/backlift/running/
  /// celebrate/bowled.
  List<double> _batterTrailAngles(FoBatterPose kind, double t) {
    if (!_trailPoses.contains(kind)) return const [];
    if (t < 0.15 || t > 0.85) return const [];
    return [
      foBatterFrame(kind, (t - 0.16).clamp(0.0, 1.0)).batAngle,
      foBatterFrame(kind, (t - 0.08).clamp(0.0, 1.0)).batAngle,
    ];
  }

  double _incomingProgress(MatchState s) {
    final delivery = s.currentDelivery;
    if (delivery == null) return 0;
    final release =
        delivery.expectedContactMicros -
        controller.tuning.incomingToContactMicros;
    return ((s.simulationMicros - release) /
            controller.tuning.incomingToContactMicros)
        .clamp(0.0, 1.0);
  }

  // ── Camera juice + full-screen effects ────────────────────────────────────
  Offset _shake(double age) {
    if (_effect != GameplayEventType.contactResolved &&
        _effect != GameplayEventType.wicket &&
        _effect != GameplayEventType.boundary) {
      return Offset.zero;
    }
    if (age >= kFoShakeSeconds) return Offset.zero;
    final decay = 1 - age / kFoShakeSeconds;
    final strength = _effect == GameplayEventType.wicket
        ? kFoShakeWicket
        : kFoShakeContact;
    return Offset(
      math.sin(_effectSeed * 0.17 + age * 95) * strength * decay,
      math.cos(_effectSeed * 0.23 + age * 77) * strength * decay,
    );
  }

  double _zoom(double age) {
    if ((_effect != GameplayEventType.runOut &&
            _effect != GameplayEventType.runCompleted) ||
        age >= kFoCineSeconds) {
      return 1;
    }
    return 1 + math.sin(age / kFoCineSeconds * math.pi) * kFoCineZoom;
  }

  void _paintEffects(Canvas canvas, Size size, MatchState s, double age) {
    if (age > kFoEffectSeconds || reducedMotion) return;
    final t = (age / kFoEffectSeconds).clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height * 0.6);

    switch (_effect) {
      case GameplayEventType.contactResolved:
        if (s.contactOutcome?.madeContact != true) return;
        final k = (age / 0.42).clamp(0.0, 1.0);
        canvas.drawCircle(
          center,
          size.shortestSide * (0.05 + k * 0.28),
          Paint()
            ..color = Cyber.cyan.withValues(alpha: 0.5 * (1 - k))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * (1 - k),
        );
      case GameplayEventType.boundary:
        final six = s.lastResult?.boundary == 6;
        final color = six ? Cyber.gold : Cyber.cyan;
        for (var i = 0; i < 3; i++) {
          final k = (t - i * 0.12).clamp(0.0, 1.0);
          if (k <= 0) continue;
          canvas.drawCircle(
            center,
            size.shortestSide * (0.1 + k * 0.55),
            Paint()
              ..color = color.withValues(alpha: 0.35 * (1 - k))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 * (1 - k),
          );
        }
      case GameplayEventType.wicket:
      case GameplayEventType.runOut:
        // Shards out of the stumps.
        final rnd = math.Random(_effectSeed);
        for (var i = 0; i < 14; i++) {
          final a = rnd.nextDouble() * math.pi * 2;
          final d =
              size.shortestSide * (0.05 + t * (0.2 + rnd.nextDouble() * 0.3));
          final p = center + Offset(math.cos(a), math.sin(a)) * d;
          canvas.drawCircle(
            p,
            math.max(1, 4 * (1 - t)),
            Paint()..color = Cyber.danger.withValues(alpha: 0.7 * (1 - t)),
          );
        }
      case GameplayEventType.catchTaken:
      case GameplayEventType.catchDropped:
        final ok = _effect == GameplayEventType.catchTaken;
        canvas.drawCircle(
          center,
          size.shortestSide * (0.08 + t * 0.2),
          Paint()
            ..color = (ok ? Cyber.danger : Cyber.lime).withValues(
              alpha: 0.55 * (1 - t),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - t),
        );
      default:
        break;
    }
  }

  /// One legal ball left. The world closes in.
  void _paintFinalBallVignette(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.5 * math.sin(_visualSeconds * 3.4);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.62),
          size.longestSide * 0.62,
          [
            Colors.transparent,
            Cyber.danger.withValues(
              alpha: 0.10 * kFoFinalBallVignette * (0.6 + 0.4 * pulse),
            ),
          ],
          const [0.55, 1.0],
        ),
    );
  }
}
