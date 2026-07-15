import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:final_over/application/application.dart';
import 'package:final_over/domain/domain.dart';
import 'visuals/final_over_visuals.dart' as art;

/// The Flame rendering boundary for Final Over.
///
/// [MatchController] remains the only gameplay authority. This class advances
/// its fixed-step clock and projects the resulting immutable state onto the
/// canvas; no score, physics, fielding, or running decision is made here.
final class FinalOverGame with Game {
  FinalOverGame({required this.controller, String? assetPackage}) {
    images = Images(
      prefix: assetPackage == null
          ? 'assets/'
          : 'packages/$assetPackage/assets/',
    );
  }

  final MatchController controller;

  final List<FieldVector> _trail = <FieldVector>[];
  int _trailDeliveryOrdinal = -1;
  double _visualSeconds = 0;
  double _effectStartedAt = -10;
  GameplayEventType? _effect;
  int _effectSeed = 0;
  ui.Image? _stadiumBackground;
  ui.Image? _fieldBackground;

  @override
  Future<void> onLoad() async {
    _stadiumBackground = await _optionalImage(
      'backgrounds/final_over_stadium.png',
    );
    _fieldBackground = await _optionalImage('backgrounds/final_over_field.png');
  }

  Future<ui.Image?> _optionalImage(String path) async {
    try {
      return await images.load(path);
    } catch (_) {
      // Code-native painters below are the guaranteed offline fallback.
      return null;
    }
  }

  @override
  void onRemove() {
    images.clearCache();
    _stadiumBackground = null;
    _fieldBackground = null;
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  bool containsEventHandlerAt(Vector2 position) => false;

  @override
  void update(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    final bounded = dt.clamp(0.0, .25);
    _visualSeconds += bounded;
    controller.step(
      Duration(
        microseconds: (bounded * Duration.microsecondsPerSecond).round(),
      ),
    );
    _captureTrail(controller.state);
  }

  /// Starts a deterministic, rendering-only effect for a gameplay event.
  void notifyEvent(GameplayEvent event) {
    switch (event.type) {
      case GameplayEventType.contactResolved ||
          GameplayEventType.boundary ||
          GameplayEventType.wicket ||
          GameplayEventType.catchTaken ||
          GameplayEventType.catchDropped ||
          GameplayEventType.runOut ||
          GameplayEventType.runCompleted:
        _effect = event.type;
        _effectStartedAt = _visualSeconds;
        _effectSeed = controller.state.currentDelivery?.seed ?? 0;
      case GameplayEventType.matchStarted ||
          GameplayEventType.deliveryPrepared ||
          GameplayEventType.ballReleased ||
          GameplayEventType.swingAccepted ||
          GameplayEventType.powerShotActivated ||
          GameplayEventType.extraAwarded ||
          GameplayEventType.cameraTransitionStarted ||
          GameplayEventType.runStarted ||
          GameplayEventType.runnerTurnedBack ||
          GameplayEventType.ballPickedUp ||
          GameplayEventType.throwStarted ||
          GameplayEventType.deliveryCompleted ||
          GameplayEventType.paused ||
          GameplayEventType.resumed ||
          GameplayEventType.matchEnded ||
          GameplayEventType.quitToHome:
        break;
    }
  }

  void _captureTrail(MatchState state) {
    final ordinal = state.currentDelivery?.ordinal ?? -1;
    if (ordinal != _trailDeliveryOrdinal) {
      _trailDeliveryOrdinal = ordinal;
      _trail.clear();
    }
    final position = state.ball?.position;
    if (position == null) return;
    if (_trail.isEmpty || _trail.last.distanceTo(position) >= .025) {
      _trail.add(position);
      if (_trail.length > 30) _trail.removeAt(0);
    }
  }

  @override
  void render(Canvas canvas) {
    if (!hasLayout) return;
    final viewport = Size(size.x, size.y);
    if (viewport.isEmpty) return;
    final state = controller.state;
    final transition = state.cameraTransition.clamp(0.0, 1.0);
    final effectAge = (_visualSeconds - _effectStartedAt).clamp(0.0, 2.0);
    final shake = _shakeForEffect(effectAge);

    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    final scale = _zoomForEffect(effectAge);
    canvas.translate(viewport.width / 2, viewport.height / 2);
    canvas.scale(scale);
    canvas.translate(-viewport.width / 2, -viewport.height / 2);

    if (transition < 1) {
      _paintWithOpacity(
        canvas,
        viewport,
        1 - Curves.easeInCubic.transform(transition),
        () => _paintBattingView(canvas, viewport, state),
      );
    }
    if (transition > 0) {
      _paintWithOpacity(
        canvas,
        viewport,
        Curves.easeOutCubic.transform(transition),
        () => _paintFieldView(canvas, viewport, state),
      );
    }
    canvas.restore();

    _paintEffects(canvas, viewport, state, effectAge);
    if (state.ballsRemaining == 1 && !state.isTerminal) {
      art.FinalBallVignettePainter(
        intensity: .62,
        pulse: _visualSeconds % 1,
      ).paint(canvas, viewport);
    }
  }

  void _paintWithOpacity(
    Canvas canvas,
    Size size,
    double opacity,
    VoidCallback paint,
  ) {
    if (opacity <= 0) return;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..color = Colors.white.withValues(
          alpha: opacity.clamp(0.0, 1.0).toDouble(),
        ),
    );
    paint();
    canvas.restore();
  }

  void _paintBattingView(Canvas canvas, Size size, MatchState state) {
    if (_stadiumBackground case final background?) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: background,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      );
      _paintWithOpacity(
        canvas,
        size,
        .48,
        () => art.StadiumBackdropPainter(
          animationProgress: 1,
          lightIntensity: state.ballsRemaining == 1 ? 1 : .82,
        ).paint(canvas, size),
      );
    } else {
      art.StadiumBackdropPainter(
        animationProgress: 1,
        lightIntensity: state.ballsRemaining == 1 ? 1 : .82,
      ).paint(canvas, size);
    }
    art.PerspectivePitchPainter(
      revealProgress: 1,
      ballProgress: _incomingProgress(state),
      showGuide: state.phase == MatchPhase.incomingBall,
    ).paint(canvas, size);

    _paintPerspectiveStumps(canvas, size, state);
    _paintBowler(canvas, size, state);
    _paintBatter(canvas, size, state);
    _paintPerspectiveBall(canvas, size, state);
  }

  void _paintPerspectiveStumps(Canvas canvas, Size size, MatchState state) {
    final broken =
        state.ledger.dismissal == DismissalType.bowled ||
        state.lastResult?.dismissal == DismissalType.bowled;
    final rect = Rect.fromCenter(
      center: Offset(size.width * .5, size.height * .76),
      width: size.width * .16,
      height: size.height * .23,
    );
    canvas.save();
    canvas.translate(rect.left, rect.top);
    art.StumpsPainter(
      broken: broken,
      progress: broken ? _effectProgress(.72) : 1,
      glow: broken ? 1 : 0,
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  void _paintBowler(Canvas canvas, Size size, MatchState state) {
    final rect = Rect.fromCenter(
      center: Offset(size.width * .5, size.height * .31),
      width: size.width * .28,
      height: size.height * .33,
    );
    final (pose, progress) = _bowlerPose(state);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    art.BowlerRigPainter(
      pose: pose,
      progress: progress,
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  (art.BowlerPose, double) _bowlerPose(MatchState state) {
    final phaseProgress =
        state.phaseElapsedMicros / math.max(1, controller.tuning.runUpMicros);
    if (state.phase == MatchPhase.deliveryPreparation) {
      return (art.BowlerPose.ready, _visualSeconds % 1);
    }
    if (state.phase == MatchPhase.bowlerRunUp) {
      if (phaseProgress < .58) {
        return (art.BowlerPose.runUp, phaseProgress / .58);
      }
      if (phaseProgress < .80) {
        return (art.BowlerPose.gather, (phaseProgress - .58) / .22);
      }
      return (art.BowlerPose.release, (phaseProgress - .80) / .20);
    }
    if (state.phase == MatchPhase.incomingBall ||
        state.phase == MatchPhase.contact ||
        state.phase == MatchPhase.cameraTransition) {
      return (art.BowlerPose.followThrough, _incomingProgress(state));
    }
    return (art.BowlerPose.ready, _visualSeconds % 1);
  }

  void _paintBatter(Canvas canvas, Size size, MatchState state) {
    final rect = Rect.fromCenter(
      center: Offset(size.width * .57, size.height * .73),
      width: size.width * .39,
      height: size.height * .46,
    );
    final pose = _batterPose(state);
    final progress = state.swingIntent == null
        ? _visualSeconds % 1
        : ((state.simulationMicros - state.swingIntent!.inputMicros) / 520000)
              .clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    art.BatterRigPainter(
      pose: pose,
      progress: progress,
      jerseyNumber: '06',
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  art.BatterPose _batterPose(MatchState state) {
    if (state.ledger.dismissal == DismissalType.bowled) {
      return art.BatterPose.bowled;
    }
    final outcome = state.contactOutcome;
    if (outcome != null && !outcome.madeContact) return art.BatterPose.miss;
    final swing = state.swingIntent;
    if (swing == null) return art.BatterPose.idle;
    return switch ((state.selectedElevation, swing.direction)) {
      (Elevation.ground, ShotDirection.offSide) => art.BatterPose.groundOff,
      (Elevation.ground, ShotDirection.straight) =>
        art.BatterPose.groundStraight,
      (Elevation.ground, ShotDirection.legSide) => art.BatterPose.groundLeg,
      (Elevation.loft, ShotDirection.offSide) => art.BatterPose.loftOff,
      (Elevation.loft, ShotDirection.straight) => art.BatterPose.loftStraight,
      (Elevation.loft, ShotDirection.legSide) => art.BatterPose.loftLeg,
    };
  }

  void _paintPerspectiveBall(Canvas canvas, Size size, MatchState state) {
    final delivery = state.currentDelivery;
    if (delivery == null) return;
    double x;
    double y;
    double apparent;
    if (state.ball case final ball?) {
      final distance = ball.position.length.clamp(0.0, 1.0);
      x = size.width * (.5 + ball.position.x * .24);
      y = size.height * (.77 - distance * .34 - ball.height * .22);
      apparent = size.shortestSide * (.037 - distance * .012);
    } else {
      final progress = _incomingProgress(state);
      x = size.width * (.5 + delivery.contactX * (1.1 + progress * 1.8));
      y = size.height * (.30 + .47 * Curves.easeInCubic.transform(progress));
      apparent = size.shortestSide * (.018 + .026 * progress);
      if (state.phase == MatchPhase.deliveryPreparation ||
          state.phase == MatchPhase.bowlerRunUp) {
        if (state.phaseElapsedMicros < controller.tuning.runUpMicros * .78) {
          return;
        }
      }
    }
    final rect = Rect.fromCircle(center: Offset(x, y), radius: apparent);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    art.CricketBallPainter(
      rotation: _visualSeconds * 11,
      glow: state.powerShotArmed ? .8 : .2,
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  double _incomingProgress(MatchState state) {
    final delivery = state.currentDelivery;
    if (delivery == null) return 0;
    final release =
        delivery.expectedContactMicros -
        controller.tuning.incomingToContactMicros;
    return ((state.simulationMicros - release) /
            controller.tuning.incomingToContactMicros)
        .clamp(0.0, 1.0);
  }

  void _paintFieldView(Canvas canvas, Size size, MatchState state) {
    if (_fieldBackground case final background?) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: background,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      );
      _paintWithOpacity(
        canvas,
        size,
        .52,
        () => art.TopDownFieldPainter(
          rotation: .025 * math.sin(_visualSeconds * .35),
          spotlight: state.runner.risk == RiskLevel.danger ? .22 : 0,
        ).paint(canvas, size),
      );
    } else {
      art.TopDownFieldPainter(
        rotation: .025 * math.sin(_visualSeconds * .35),
        spotlight: state.runner.risk == RiskLevel.danger ? .22 : 0,
      ).paint(canvas, size);
    }
    final field = _fieldGeometry(size);

    if (_trail.length > 1) {
      final normalized = _trail
          .map((point) => _fieldPoint(point, field))
          .map((point) => Offset(point.dx / size.width, point.dy / size.height))
          .toList(growable: false);
      art.TrajectoryTrailPainter(
        points: normalized,
        progress: 1,
        color: state.contactOutcome?.elevation == Elevation.loft
            ? art.FinalOverPalette.yellow
            : art.FinalOverPalette.cyan,
        showHead: false,
      ).paint(canvas, size);
    }

    for (final fielder in state.fielders) {
      _paintFielder(canvas, size, field, fielder, state);
    }
    _paintTopDownRunners(canvas, size, field, state);
    _paintTopDownBall(canvas, size, field, state);
    if (state.phase == MatchPhase.throwInProgress) {
      _paintThrow(canvas, size, field, state);
    }
  }

  ({Offset center, double radius}) _fieldGeometry(Size size) => (
    center: Offset(size.width / 2, size.height / 2),
    radius: size.shortestSide * .445,
  );

  Offset _fieldPoint(
    FieldVector vector,
    ({Offset center, double radius}) geometry,
  ) => geometry.center + Offset(vector.x, vector.y) * geometry.radius;

  void _paintFielder(
    Canvas canvas,
    Size size,
    ({Offset center, double radius}) geometry,
    FielderState fielder,
    MatchState state,
  ) {
    final center = _fieldPoint(fielder.position, geometry);
    final marker = math.max(18.0, size.shortestSide * .055);
    final rect = Rect.fromCenter(center: center, width: marker, height: marker);
    final visualState = switch (fielder.motion) {
      FielderMotion.idle ||
      FielderMotion.reacting => art.FielderVisualState.idle,
      FielderMotion.chasing => art.FielderVisualState.tracking,
      FielderMotion.backup => art.FielderVisualState.backingUp,
      FielderMotion.catching => art.FielderVisualState.catching,
      FielderMotion.carrying => art.FielderVisualState.pickup,
      FielderMotion.throwing => art.FielderVisualState.throwing,
    };
    final angle = math.atan2(fielder.velocity.y, fielder.velocity.x);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    art.FielderDotPainter(
      state: visualState,
      progress: _visualSeconds % 1,
      facingAngle: angle,
      isPrimary: fielder.motion == FielderMotion.chasing || fielder.hasBall,
      jerseyColor: fielder.role == FielderRole.wicketkeeper
          ? art.FinalOverPalette.orange
          : art.FinalOverPalette.deepBlue,
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  void _paintTopDownBall(
    Canvas canvas,
    Size size,
    ({Offset center, double radius}) geometry,
    MatchState state,
  ) {
    final ball = state.ball;
    if (ball == null) return;
    final center = _fieldPoint(ball.position, geometry);
    final diameter = math.max(
      9.0,
      size.shortestSide * (.025 + ball.height.clamp(0.0, .3) * .08),
    );
    final rect = Rect.fromCenter(
      center: center,
      width: diameter,
      height: diameter,
    );
    canvas.save();
    canvas.translate(rect.left, rect.top);
    art.CricketBallPainter(
      rotation: _visualSeconds * 12,
      glow: ball.aerial ? .65 : .18,
    ).paint(canvas, rect.size);
    canvas.restore();
    if (ball.aerial) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(0, diameter * .9),
          width: diameter * 1.2,
          height: diameter * .36,
        ),
        Paint()..color = Colors.black.withValues(alpha: .34),
      );
    }
  }

  void _paintTopDownRunners(
    Canvas canvas,
    Size size,
    ({Offset center, double radius}) geometry,
    MatchState state,
  ) {
    final runner = state.runner;
    final progress = runner.progress;
    final direction = runner.runNumber.isOdd ? -1.0 : 1.0;
    final startY = direction > 0 ? -.21 : .21;
    final endY = -startY;
    final strikerY = runner.active
        ? startY + (endY - startY) * progress
        : (runner.completedRuns.isOdd ? -.21 : .21);
    final nonStrikerY = runner.active
        ? -startY - (endY - startY) * progress
        : -strikerY;
    _paintRunnerDot(
      canvas,
      size,
      _fieldPoint(FieldVector(-.025, strikerY), geometry),
      art.FinalOverPalette.royalBlue,
      '06',
    );
    _paintRunnerDot(
      canvas,
      size,
      _fieldPoint(FieldVector(.025, nonStrikerY), geometry),
      art.FinalOverPalette.cyan,
      '12',
    );
  }

  void _paintRunnerDot(
    Canvas canvas,
    Size size,
    Offset center,
    Color color,
    String jersey,
  ) {
    final radius = math.max(7.0, size.shortestSide * .021);
    canvas.drawCircle(
      center,
      radius * 1.35,
      Paint()..color = Colors.black.withValues(alpha: .35),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
    final label = TextPainter(
      text: TextSpan(
        text: jersey,
        style: TextStyle(
          color: art.FinalOverPalette.white,
          fontSize: radius * .72,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
  }

  void _paintThrow(
    Canvas canvas,
    Size size,
    ({Offset center, double radius}) geometry,
    MatchState state,
  ) {
    final holder = state.fielders
        .where((fielder) => fielder.hasBall)
        .firstOrNull;
    if (holder == null) return;
    final target = state.runner.runNumber.isOdd
        ? const FieldVector(0, -0.21)
        : const FieldVector(0, 0.21);
    final a = _fieldPoint(holder.position, geometry);
    final b = _fieldPoint(target, geometry);
    art.TrajectoryTrailPainter(
      points: <Offset>[
        Offset(a.dx / size.width, a.dy / size.height),
        Offset(b.dx / size.width, b.dy / size.height),
      ],
      progress: ((_visualSeconds * 2.2) % 1),
      color: art.FinalOverPalette.orange,
      throwTrail: true,
    ).paint(canvas, size);
  }

  Offset _shakeForEffect(double age) {
    if (_effect != GameplayEventType.contactResolved &&
        _effect != GameplayEventType.wicket &&
        _effect != GameplayEventType.boundary) {
      return Offset.zero;
    }
    if (age >= .32) return Offset.zero;
    final decay = 1 - age / .32;
    final strength = _effect == GameplayEventType.wicket ? 8.0 : 5.0;
    return Offset(
      math.sin(_effectSeed * .17 + age * 95) * strength * decay,
      math.cos(_effectSeed * .23 + age * 77) * strength * decay,
    );
  }

  double _zoomForEffect(double age) {
    if ((_effect != GameplayEventType.runOut &&
            _effect != GameplayEventType.runCompleted) ||
        age >= .55) {
      return 1;
    }
    return 1 + math.sin(age / .55 * math.pi) * .055;
  }

  double _effectProgress(double duration) =>
      ((_visualSeconds - _effectStartedAt) / duration).clamp(0.0, 1.0);

  void _paintEffects(Canvas canvas, Size size, MatchState state, double age) {
    if (age > 1.1) return;
    final progress = (age / 1.1).clamp(0.0, 1.0);
    switch (_effect) {
      case GameplayEventType.contactResolved:
        if (state.contactOutcome?.madeContact == true) {
          art.ImpactEffectPainter(
            progress: (age / .42).clamp(0.0, 1.0),
            intensity: state.contactOutcome?.power ?? .7,
            seed: _effectSeed,
          ).paint(canvas, size);
        }
      case GameplayEventType.boundary:
        art.BoundaryPulsePainter(
          kind: state.lastResult?.boundary == 6
              ? art.BoundaryEffectKind.six
              : art.BoundaryEffectKind.four,
          progress: progress,
        ).paint(canvas, size);
      case GameplayEventType.wicket || GameplayEventType.runOut:
        art.WicketBurstPainter(
          progress: progress,
          seed: _effectSeed,
        ).paint(canvas, size);
      case GameplayEventType.catchTaken || GameplayEventType.catchDropped:
        art.CatchRingPainter(
          progress: progress,
          success: _effect == GameplayEventType.catchTaken,
          drop: _effect == GameplayEventType.catchDropped,
        ).paint(canvas, size);
      case GameplayEventType.runCompleted ||
          GameplayEventType.matchStarted ||
          GameplayEventType.deliveryPrepared ||
          GameplayEventType.ballReleased ||
          GameplayEventType.swingAccepted ||
          GameplayEventType.powerShotActivated ||
          GameplayEventType.extraAwarded ||
          GameplayEventType.cameraTransitionStarted ||
          GameplayEventType.runStarted ||
          GameplayEventType.runnerTurnedBack ||
          GameplayEventType.ballPickedUp ||
          GameplayEventType.throwStarted ||
          GameplayEventType.deliveryCompleted ||
          GameplayEventType.paused ||
          GameplayEventType.resumed ||
          GameplayEventType.matchEnded ||
          GameplayEventType.quitToHome ||
          null:
        break;
    }
  }
}
