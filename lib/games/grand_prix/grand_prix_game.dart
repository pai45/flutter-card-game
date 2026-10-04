import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../config/theme.dart';
import '../../data/grand_prix_drivers.dart';
import '../../data/grand_prix_liveries.dart';
import '../../models/grand_prix.dart';
import 'grand_prix_car_painter.dart';
import 'grand_prix_engine.dart';
import 'grand_prix_simulation_clock.dart';
import 'grand_prix_scenery.dart';

class GrandPrixTelemetry {
  const GrandPrixTelemetry({
    this.energy = 1,
    this.tow = 0,
    this.grip = 1,
    this.deploying = false,
    this.gear = 1,
    this.rpm = 0.3,
    this.throttle = 0,
    this.brake = 0,
    this.cleanPasses = 0,
    this.elapsedMs = 0,
    this.bestLapMs,
    this.lastLapMs,
    this.corner,
    this.braking = false,
    this.rivalName,
    this.rivalGapSeconds = 0,
    this.recoverySeconds = 0,
  });
  final double energy,
      tow,
      grip,
      rpm,
      throttle,
      brake,
      rivalGapSeconds,
      recoverySeconds;
  final bool deploying, braking;
  final int gear, cleanPasses, elapsedMs;
  final int? bestLapMs, lastLapMs;
  final GrandPrixCornerPreview? corner;
  final String? rivalName;
}

enum GrandPrixAudioEvent { tireScrub, wallContact, carContact }

/// Flame renderer + real-time loop for Grand Prix Dash.
///
/// Unlike turn-based Football Chess (where the cubit owns the clock), the 60fps
/// simulation lives HERE: `update(dt)` advances the pure engine in fixed
/// substeps and only coarse events (position change, overtake, finish) are
/// called back up to the cubit. High-frequency HUD values (speed, lap
/// progress) are exposed as [ValueNotifier]s so nothing emits bloc state per
/// frame. All drawing is procedural Canvas on `Cyber` tokens — livery colors
/// are the one content-color exception.
class GrandPrixGame extends FlameGame {
  GrandPrixGame({
    required this.setup,
    required this.onPositionChanged,
    required this.onOvertake,
    required this.onPlayerFinished,
    required this.onAudioEvent,
    this.reducedMotion = false,
    this.onMoment,
  });

  final RaceSetup setup;
  final void Function(int position) onPositionChanged;
  final void Function(OvertakeEvent event) onOvertake;
  final void Function(PlayerRaceOutcome outcome) onPlayerFinished;
  final void Function(GrandPrixAudioEvent event) onAudioEvent;
  bool reducedMotion;
  final void Function(GrandPrixMoment moment)? onMoment;

  // HUD bindings — cheap 60fps reads, never bloc emissions.
  final ValueNotifier<double> speedKph = ValueNotifier(0);
  final ValueNotifier<double> lapProgress = ValueNotifier(0);
  final ValueNotifier<bool> slipstreamActive = ValueNotifier(false);
  final ValueNotifier<GrandPrixTelemetry> telemetry = ValueNotifier(
    const GrandPrixTelemetry(),
  );

  /// 1-based lap the player is on (clamped to [laps]); the HUD shows LAP n/N
  /// and the race screen flashes a beat when it climbs.
  final ValueNotifier<int> currentLap = ValueNotifier(1);

  int get laps => setup.laps;

  /// Seconds the player has been stuck; the HUD raises a get-moving warning as
  /// this climbs toward [kStuckTimeout].
  final ValueNotifier<double> stuckSeconds = ValueNotifier(0);

  late final RaceField field;
  late final GrandPrixEngine _engine;
  final List<_CarComponent> _carSprites = [];
  final GrandPrixSimulationClock _clock = GrandPrixSimulationClock();
  late final GrandPrixScenery _scenery = GrandPrixScenery(setup.circuit.id);
  late final _TrackEffectsComponent _effects = _TrackEffectsComponent();

  bool _running = false;
  bool _started = false;
  bool _finishedReported = false;
  bool _left = false,
      _right = false,
      _throttle = false,
      _brake = false,
      _deploy = false;
  double _steer = 0;
  double _telemetryTimer = 0;
  double _cameraScale = 1;
  double _impact = 0;
  double _sparkCooldown = 0;
  double _finishCoast = 0;
  double _cameraRefX = 0;
  double _cameraDistance = 0;
  OvertakeEvent? _bestOvertake;

  /// Player car's fixed screen row (fraction of height from the top).
  static const double _anchorFrac = 0.68;

  // -- camera / world→screen mapping ----------------------------------------

  /// Vertical px per metre — sized so the player can see ~95m up the road.
  double get pxPerMeterY => max(2.8, size.y * _anchorFrac / 110) * _cameraScale;

  /// Lateral px per metre for lane offsets — the asphalt band spans ~42% of
  /// the screen width.
  double get pxPerMeterX => min(size.x * 0.56, 360.0) / (kTrackHalfWidth * 2);

  /// Curvature is compressed relative to lane widths so a 30m corner bend
  /// sweeps across the screen instead of off it (pseudo-scroller trick). The
  /// engine drifts the car wide by this same ratio (see [kBendCompression]) so
  /// the physics and the drawn road agree on how sharp the bend is.
  double get bendPxPerMeter => pxPerMeterX * kBendCompression;

  double get anchorY => size.y * _anchorFrac;

  Offset worldToScreen(double distance, double lateral) {
    final bend = field.geometry.sample(distance).centerX * bendPxPerMeter;
    return Offset(
      size.x / 2 +
          (bend - _cameraRefX) +
          lateral * pxPerMeterX +
          (reducedMotion ? 0 : sin(_impact * 70) * _impact * 12),
      anchorY - (distance - _cameraDistance) * pxPerMeterY,
    );
  }

  /// How far up the road (m) is still on screen.
  double get viewAheadMeters => anchorY / pxPerMeterY + 20;

  @override
  Color backgroundColor() => Cyber.bg;

  @override
  Future<void> onLoad() async {
    final rng = Random(setup.seed);
    field = buildField(setup, generateDriverNames(kFieldSize - 1, rng), rng);
    _engine = GrandPrixEngine(random: Random(setup.seed ^ 0x51f15eed));
    _cameraDistance = field.player.distance;
    _cameraRefX =
        field.geometry.sample(_cameraDistance).centerX * bendPxPerMeter;

    add(_TrackComponent()..priority = -10);
    add(_effects..priority = 5);
    for (final car in field.cars) {
      final sprite = _CarComponent(
        car: car,
        spec: grandPrixLiverySpec(car.livery),
      )..priority = car.isPlayer ? 20 : 10;
      _carSprites.add(sprite);
      add(sprite);
    }
    _syncSprites();
  }

  // -- inputs from the HUD control pad ---------------------------------------

  void setInputs({
    bool? left,
    bool? right,
    bool? throttle,
    bool? brake,
    double? steer,
    bool? deploy,
  }) {
    _left = left ?? _left;
    _right = right ?? _right;
    _throttle = throttle ?? _throttle;
    _brake = brake ?? _brake;
    _steer = steer?.clamp(-1.0, 1.0) ?? _steer;
    _deploy = deploy ?? _deploy;
  }

  void clearInputs() {
    _left = _right = _throttle = _brake = _deploy = false;
    _steer = 0;
  }

  RaceInputs get _playerInputs => RaceInputs(
    steer: (_steer + (_right ? 1.0 : 0.0) - (_left ? 1.0 : 0.0)).clamp(
      -1.0,
      1.0,
    ),
    throttle: _throttle,
    brake: _brake,
    deploy: _deploy,
  );

  // -- race lifecycle ---------------------------------------------------------

  /// Lights out: applies the graded launches and arms the simulation.
  void startRace(LaunchGrade playerGrade) {
    if (_running || _finishedReported) return;
    if (!_started) {
      applyLaunch(field, playerGrade, Random(setup.seed ^ 0x1a));
      _started = true;
    }
    _clock.reset();
    _running = true;
  }

  void stopRace() {
    _running = false;
    _clock.reset();
    clearInputs();
    if (isLoaded) {
      for (final car in field.cars) {
        car.previousDistance = car.distance;
        car.previousLateral = car.lateral;
        car.previousHeading = car.heading;
      }
    }
  }

  bool recoverPlayer() {
    if (!_running || !_engine.recoverPlayer(field)) return false;
    clearInputs();
    onMoment?.call(
      const GrandPrixMoment(
        GrandPrixMomentKind.recovery,
        'RECOVERING',
        'THREE SECONDS · RIVALS KEEP RACING',
      ),
    );
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sparkCooldown = max(0, _sparkCooldown - dt);
    _impact = max(0, _impact - dt);
    if (_running) {
      _clock.advance(dt, (step) {
        final events = _engine.tick(field, _playerInputs, step);
        _handleEvents(events);
        return _running;
      });
    } else if (_finishedReported && !reducedMotion && field.player.finished) {
      _finishCoast = min(16, _finishCoast + field.player.speed * dt * 0.35);
    }
    final scaleTarget = reducedMotion
        ? 1.0
        : 1 - field.player.speed / kTopSpeed * 0.12;
    _cameraScale += (scaleTarget - _cameraScale) * (1 - exp(-dt * 3));
    _telemetryTimer += dt;
    _syncCamera();
    _syncSprites();
    _syncNotifiers();
  }

  void _handleEvents(RaceTickEvents events) {
    if (events.playerPosition case final position?) {
      onPositionChanged(position);
    }
    for (final overtake in events.overtakes) {
      final best = _bestOvertake;
      if (best == null || overtake.overtakenPosition < best.overtakenPosition) {
        _bestOvertake = overtake;
      }
      onOvertake(overtake);
    }
    if (events.moment case final moment?) onMoment?.call(moment);
    if (events.playerTireScrub) {
      onAudioEvent(GrandPrixAudioEvent.tireScrub);
    }
    if (events.playerWallContact) {
      onAudioEvent(GrandPrixAudioEvent.wallContact);
    } else if (events.playerContact) {
      onAudioEvent(GrandPrixAudioEvent.carContact);
    }
    if ((events.playerWallContact || events.playerContact) &&
        !reducedMotion &&
        _sparkCooldown == 0) {
      _sparkCooldown = 0.16;
      _impact = events.playerWallContact ? 0.16 : 0.09;
      _spawnSparks(
        events.playerWallContact ? Cyber.danger : Cyber.amber,
        events.playerWallContact ? 18 : 8,
      );
    }
    if (events.playerCrossedLine && !_finishedReported) {
      _finishedReported = true;
      _running = false;
      final player = field.player;
      onPlayerFinished(
        PlayerRaceOutcome(
          position: positionOf(field, player),
          lapTimeMs: player.finishTimeMs.round(),
          bestOvertakeName: _bestOvertake?.overtakenName,
          lapTimesMs: List.unmodifiable(field.playerLapTimesMs),
          cleanOvertakes: field.cleanPassedCars.length,
          cleanRace: field.playerCleanRace,
          recoveries: field.playerRecoveries,
        ),
      );
    }
    if (events.playerStuckOut && !_finishedReported) {
      // Game over: stuck too long. Classified last (DNF), no lap time.
      _finishedReported = true;
      _running = false;
      onPlayerFinished(
        PlayerRaceOutcome(
          position: kFieldSize,
          lapTimeMs: 0,
          dnf: true,
          lapTimesMs: List.unmodifiable(field.playerLapTimesMs),
          cleanOvertakes: field.cleanPassedCars.length,
          recoveries: field.playerRecoveries,
        ),
      );
    }
  }

  void _syncCamera() {
    // Lock the camera exactly onto the centerline under the player so the
    // player car keeps a fixed horizontal screen position — offset only by its
    // own lateral, i.e. only when the player steers. Any lag/smoothing here
    // reads as the car sliding sideways on its own through a bend.
    final player = field.player;
    _cameraDistance = _interpolate(
      player.previousDistance,
      player.distance,
      player,
    );
    _cameraRefX =
        field.geometry.sample(_cameraDistance).centerX * bendPxPerMeter;
  }

  double _interpolate(double previous, double current, CarState car) =>
      !_running || !car.hasPreviousPose
      ? current
      : previous + (current - previous) * _clock.interpolation;

  void _syncSprites() {
    if (!isLoaded) return;
    final playerDistance = _cameraDistance;
    final window = viewAheadMeters;
    for (final sprite in _carSprites) {
      final delta = sprite.car.distance - playerDistance;
      sprite.visibleOnTrack = delta > -60 && delta < window;
      if (!sprite.visibleOnTrack) continue;
      final car = sprite.car;
      final sample = field.geometry.sample(
        _interpolate(car.previousDistance, car.distance, car),
      );
      final distance =
          _interpolate(car.previousDistance, car.distance, car) +
          (car.isPlayer ? _finishCoast : 0);
      final lateral = _interpolate(car.previousLateral, car.lateral, car);
      final at = worldToScreen(distance, lateral);
      sprite.position = Vector2(at.dx, at.dy);
      // Slimmer + longer than the old 1.75 block — real F1 proportions.
      final carW = kCarWidth * pxPerMeterX * 0.68;
      sprite.size = Vector2(carW, carW * 2.05);
      sprite.angle = sprite.car.spinning
          ? sin(sprite.car.spinTimer * 24) * 0.7
          : projectedGrandPrixCarHeading(
              roadSlope: sample.slope,
              relativeHeading: _interpolate(
                car.previousHeading,
                car.heading,
                car,
              ),
              lateralScale: pxPerMeterX,
              forwardScale: pxPerMeterY,
              straight: field.circuit.sections[sample.sectionIndex].isStraight,
            );
    }
  }

  void _syncNotifiers() {
    final player = field.player;
    speedKph.value = player.speed * 3.6;
    final lapLength = field.circuit.lapLength;
    if (player.finished) {
      currentLap.value = field.laps;
      lapProgress.value = 1.0;
    } else {
      final lapIndex = player.distance <= 0
          ? 0
          : min(field.laps - 1, player.distance ~/ lapLength);
      currentLap.value = lapIndex + 1;
      lapProgress.value = ((player.distance - lapIndex * lapLength) / lapLength)
          .clamp(0.0, 1.0);
    }
    slipstreamActive.value = player.slipstreaming;
    stuckSeconds.value = _running ? field.playerStuckSeconds : 0;
    if (_telemetryTimer >= 1 / 20) {
      _telemetryTimer = 0;
      final corner = field.geometry.cornerAhead(
        player.distance,
        field.raceLength,
      );
      CarState? rival;
      for (final car in field.cars) {
        if (car.isPlayer || car.distance <= player.distance) continue;
        if (rival == null || car.distance < rival.distance) rival = car;
      }
      final stoppingDistance = corner == null
          ? 0.0
          : max(
                  0.0,
                  (player.speed * player.speed -
                          corner.safeSpeed * corner.safeSpeed) /
                      (2 * kBrake),
                ) +
                player.speed * 0.18;
      telemetry.value = GrandPrixTelemetry(
        energy: player.energy,
        tow: player.towStrength,
        grip: player.grip,
        deploying: player.deploying,
        gear: player.gear,
        rpm: player.rpm,
        throttle: player.throttleLoad,
        brake: player.brakeLoad,
        cleanPasses: field.cleanPassedCars.length,
        elapsedMs: field.raceClockMs.round(),
        bestLapMs: field.playerLapTimesMs.isEmpty
            ? null
            : field.playerLapTimesMs.reduce(min),
        lastLapMs: field.playerLapTimesMs.isEmpty
            ? null
            : field.playerLapTimesMs.last,
        corner: corner,
        braking:
            corner != null &&
            corner.distance <= stoppingDistance &&
            player.speed > corner.safeSpeed,
        rivalName: rival?.name,
        rivalGapSeconds: rival == null
            ? 0
            : (rival.distance - player.distance) / max(1, player.speed),
        recoverySeconds: player.recoveryTimer,
      );
    }
  }

  void _spawnSparks(Color color, int count) {
    if (isLoaded) _effects.sparks(field.player, color, count);
  }

  @override
  void onRemove() {
    speedKph.dispose();
    lapProgress.dispose();
    slipstreamActive.dispose();
    stuckSeconds.dispose();
    currentLap.dispose();
    telemetry.dispose();
    _scenery.dispose();
    super.onRemove();
  }
}

/// Draws the vertically-scrolling road: grass, walls, asphalt band, kerbs on
/// corner sections, braking boards, the centre dashes, and the start/finish
/// checker line. Everything is sampled around the player each frame from the
/// same world→screen mapping the cars use, so the road bends exactly where the
/// physics says the corner is.
class _TrackComponent extends PositionComponent
    with HasGameReference<GrandPrixGame> {
  static const double _sampleStep = 6;

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    if (!gameRef.isLoaded) return;
    final field = gameRef.field;
    final player = field.player;
    final from = player.distance - 60;
    final to = player.distance + gameRef.viewAheadMeters;
    gameRef._scenery.paint(
      canvas,
      Size(gameRef.size.x, gameRef.size.y),
      gameRef.worldToScreen,
      from,
      to,
      gameRef.pxPerMeterX,
    );

    final leftWall = <Offset>[];
    final rightWall = <Offset>[];
    final leftEdge = <Offset>[];
    final rightEdge = <Offset>[];
    for (var s = from; s <= to; s += _sampleStep) {
      leftWall.add(gameRef.worldToScreen(s, -kWallLateral));
      rightWall.add(gameRef.worldToScreen(s, kWallLateral));
      leftEdge.add(gameRef.worldToScreen(s, -kTrackHalfWidth));
      rightEdge.add(gameRef.worldToScreen(s, kTrackHalfWidth));
    }
    if (leftWall.length < 2) return;

    // Grass: the full corridor between the walls.
    canvas.drawPath(
      _band(leftWall, rightWall),
      Paint()..color = gameRef._scenery.runoff,
    );
    // Asphalt.
    canvas.drawPath(
      _band(leftEdge, rightEdge),
      Paint()..color = AppTheme.backgroundSecondary,
    );
    gameRef._scenery.paintAsphalt(
      canvas,
      _band(leftEdge, rightEdge),
      gameRef.worldToScreen,
      from,
      to,
    );
    final rubber = Path();
    var firstRubber = true;
    for (var s = from; s <= to; s += _sampleStep) {
      final at = gameRef.worldToScreen(
        s,
        field.geometry.racingLine(s, kTrackHalfWidth),
      );
      if (firstRubber) {
        rubber.moveTo(at.dx, at.dy);
        firstRubber = false;
      } else {
        rubber.lineTo(at.dx, at.dy);
      }
    }
    canvas.drawPath(
      rubber,
      Paint()
        ..color = Cyber.arenaFloor.withValues(alpha: 0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = gameRef.pxPerMeterX * 1.7,
    );

    // Track edge lines.
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Cyber.cyan.withValues(alpha: 0.18);
    canvas.drawPath(_polyline(leftEdge), edgePaint);
    canvas.drawPath(_polyline(rightEdge), edgePaint);

    // Walls.
    final wallPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Cyber.muted.withValues(alpha: 0.55);
    canvas.drawPath(_polyline(leftWall), wallPaint);
    canvas.drawPath(_polyline(rightWall), wallPaint);

    _renderCentreDashes(canvas, gameRef, from, to);
    _renderKerbsAndBoards(canvas, gameRef, from, to);
    _renderFinishLine(canvas, gameRef);
  }

  Path _band(List<Offset> left, List<Offset> right) {
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Path _polyline(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// Centre-line dashes every 12m — the main speed-feel cue.
  void _renderCentreDashes(
    Canvas canvas,
    GrandPrixGame gameRef,
    double from,
    double to,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Cyber.cyan.withValues(alpha: 0.10);
    final start = (from / 12).floor() * 12.0;
    for (var s = start; s <= to; s += 12) {
      final a = gameRef.worldToScreen(s, 0);
      final b = gameRef.worldToScreen(s + 5, 0);
      canvas.drawLine(a, b, paint);
    }
  }

  /// Kerb dashes along corner/chicane edges + amber braking boards 60m and
  /// 110m before each braking zone, repeated for every lap in view.
  void _renderKerbsAndBoards(
    Canvas canvas,
    GrandPrixGame gameRef,
    double from,
    double to,
  ) {
    final field = gameRef.field;
    final sections = field.circuit.sections;
    final lapLength = field.circuit.lapLength;
    final firstLap = max(0, (from / lapLength).floor());
    final lastLap = min(field.laps - 1, (to / lapLength).floor());
    for (var lap = firstLap; lap <= lastLap; lap++) {
      final lapBase = lap * lapLength;
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i];
        if (section.isStraight) continue;
        final sectionStart = lapBase + field.sectionStarts[i];
        final sectionEnd = sectionStart + section.length;
        if (sectionEnd < from || sectionStart > to) continue;

        // Kerbs: alternating dashes on both edges through the section.
        var red = true;
        for (
          var s = max(sectionStart, from);
          s < min(sectionEnd, to);
          s += 5, red = !red
        ) {
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = (red ? Cyber.danger : AppTheme.whiteColor).withValues(
              alpha: 0.55,
            );
          for (final side in const [-1.0, 1.0]) {
            final a = gameRef.worldToScreen(s, side * kTrackHalfWidth);
            final b = gameRef.worldToScreen(
              min(s + 3.4, sectionEnd),
              side * kTrackHalfWidth,
            );
            canvas.drawLine(a, b, paint);
          }
        }

        // Braking boards ahead of the zone.
        for (final lead in const [60.0, 110.0]) {
          final s = sectionStart - lead;
          if (s < from || s > to) continue;
          final paint = Paint()..color = Cyber.amber.withValues(alpha: 0.7);
          for (final side in const [-1.0, 1.0]) {
            final at = gameRef.worldToScreen(s, side * (kTrackHalfWidth + 1.0));
            canvas.drawRect(
              Rect.fromCenter(center: at, width: 10, height: 4),
              paint,
            );
          }
        }
      }
    }
  }

  /// Start line, a slim marker at every intermediate lap boundary, and the
  /// full checkered flag at the race's finish.
  void _renderFinishLine(Canvas canvas, GrandPrixGame gameRef) {
    final field = gameRef.field;
    final lapLength = field.circuit.lapLength;
    for (var lap = 0; lap <= field.laps; lap++) {
      final at = lap * lapLength;
      final delta = at - field.player.distance;
      if (delta < -30 || delta > gameRef.viewAheadMeters) continue;
      final isFinish = lap == field.laps;
      _checker(canvas, gameRef, at, rows: isFinish || lap == 0 ? 2 : 1);
    }
  }

  void _checker(
    Canvas canvas,
    GrandPrixGame gameRef,
    double at, {
    int rows = 2,
  }) {
    const cells = 8;
    final cellW = kTrackHalfWidth * 2 / cells;
    for (var row = 0; row < rows; row++) {
      for (var i = 0; i < cells; i++) {
        final even = (i + row).isEven;
        final a = gameRef.worldToScreen(
          at + row * 2.0,
          -kTrackHalfWidth + i * cellW,
        );
        final b = gameRef.worldToScreen(
          at + (row + 1) * 2.0,
          -kTrackHalfWidth + (i + 1) * cellW,
        );
        canvas.drawRect(
          Rect.fromPoints(a, b),
          Paint()..color = even ? AppTheme.whiteColor : Cyber.arenaFloor,
        );
      }
    }
  }
}

/// A detailed top-down F1 car (see [paintGrandPrixCar]): multi-element wings,
/// halo + helmet, coke-bottle sidepods and a diffuser — tinted with the
/// livery. The player's car is the one glowing element on the track (THE GLOW
/// RULE).
class _CarComponent extends PositionComponent {
  _CarComponent({required this.car, required GrandPrixLiverySpec spec})
    : _glowColor = spec.accent,
      _style = GrandPrixCarStyle(spec) {
    anchor = Anchor.center;
  }

  final CarState car;
  final Color _glowColor;
  final GrandPrixCarStyle _style;
  bool visibleOnTrack = true;

  @override
  void render(Canvas canvas) {
    if (!visibleOnTrack) return;
    final w = size.x;
    final h = size.y;

    if (car.isPlayer) {
      canvas.drawOval(
        Rect.fromLTWH(-w * 0.25, -h * 0.15, w * 1.5, h * 1.3),
        Paint()
          ..color = _glowColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    if (car.recovering || car.ghostTimer > 0) {
      canvas.saveLayer(
        Rect.fromLTWH(-w, -h, w * 3, h * 3),
        Paint()..color = AppTheme.whiteColor.withValues(alpha: 0.45),
      );
    }
    paintGrandPrixCar(
      canvas,
      w,
      h,
      _style,
      steering: car.steeringAngle,
      brake: car.brakeLoad,
      deploying: car.deploying,
    );
    if (car.recovering || car.ghostTimer > 0) canvas.restore();

    if (car.spinning) {
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.5),
        w * 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Cyber.danger.withValues(alpha: 0.6),
      );
    }
  }
}

class _RoadEffect {
  _RoadEffect(
    this.distance,
    this.lateral,
    this.color, {
    this.life = 0.5,
    this.sideVelocity = 0,
    this.forwardVelocity = 0,
    this.smoke = false,
    this.mark = false,
  });
  double distance, lateral, age = 0;
  final double life, sideVelocity, forwardVelocity;
  final Color color;
  final bool smoke, mark;
}

/// Bounded world-space effects: marks stay attached to asphalt, and smoke and
/// sparks scroll past with the road. The presentation RNG never enters physics.
class _TrackEffectsComponent extends PositionComponent
    with HasGameReference<GrandPrixGame> {
  final List<_RoadEffect> _effects = [];
  final Random _random = Random(31);
  double _emission = 0;
  static const _capacity = 160;

  void _add(_RoadEffect effect) {
    if (_effects.length >= _capacity) _effects.removeAt(0);
    _effects.add(effect);
  }

  void sparks(CarState car, Color color, int count) {
    for (var i = 0; i < count; i++) {
      _add(
        _RoadEffect(
          car.distance,
          car.lateral,
          color,
          sideVelocity: (_random.nextDouble() - 0.5) * 12,
          forwardVelocity: -5 - _random.nextDouble() * 15,
          life: 0.25 + _random.nextDouble() * 0.25,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    if (!game.isLoaded) return;
    if (game.reducedMotion) {
      _effects.clear();
      return;
    }
    if (!game._running && !game._finishedReported) return;
    for (final effect in _effects) {
      effect.age += dt;
      effect.distance += effect.forwardVelocity * dt;
      effect.lateral += effect.sideVelocity * dt;
    }
    _effects.removeWhere((effect) => effect.age >= effect.life);
    _emission += dt;
    if (_emission < 0.075 || !game._running) return;
    _emission = 0;
    for (final car in game.field.cars) {
      if ((car.distance - game.field.player.distance).abs() > 100 ||
          car.speed < 12) {
        continue;
      }
      if (car.brakeLoad > 0.1 || car.grip < 0.82 || car.spinning) {
        for (final side in const [-0.65, 0.65]) {
          _add(
            _RoadEffect(
              car.distance - 2,
              car.lateral + side,
              Cyber.arenaFloor,
              life: 8,
              mark: true,
            ),
          );
        }
      }
      if (car.spinning || car.grip < 0.78) {
        _add(
          _RoadEffect(
            car.distance - 3,
            car.lateral,
            Cyber.muted,
            smoke: true,
            life: 0.65,
            sideVelocity: car.lateralVelocity * 0.2,
            forwardVelocity: -3,
          ),
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!game.isLoaded || game.reducedMotion) return;
    for (final effect in _effects) {
      final at = game.worldToScreen(effect.distance, effect.lateral);
      if (at.dy < -20 || at.dy > game.size.y + 20) continue;
      final fade = (1 - effect.age / effect.life).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = effect.color.withValues(
          alpha:
              fade *
              (effect.smoke
                  ? 0.16
                  : effect.mark
                  ? 0.42
                  : 0.8),
        );
      if (effect.mark) {
        paint
          ..strokeWidth = max(1.5, game.pxPerMeterX * 0.08)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          at,
          game.worldToScreen(effect.distance - 1.6, effect.lateral),
          paint,
        );
      } else if (effect.smoke) {
        canvas.drawCircle(at, 4 + effect.age * 12, paint);
      } else {
        canvas.drawCircle(at, 1.8, paint);
      }
    }
    final player = game.field.player;
    if (player.deploying || player.towStrength > 0.3) {
      final at = game.worldToScreen(player.distance - 4, player.lateral);
      final paint = Paint()
        ..color = Cyber.cyan.withValues(alpha: player.deploying ? 0.55 : 0.22)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (final side in const [-0.6, 0.6]) {
        canvas.drawLine(
          at + Offset(side * game.pxPerMeterX, 0),
          at +
              Offset(
                side * game.pxPerMeterX,
                game.pxPerMeterY * (player.deploying ? 11 : 5),
              ),
          paint,
        );
      }
    }
  }
}
