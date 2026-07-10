import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../config/theme.dart';
import '../../data/grand_prix_drivers.dart';
import '../../data/grand_prix_liveries.dart';
import '../../models/grand_prix.dart';
import 'grand_prix_car_painter.dart';
import 'grand_prix_engine.dart';

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
    this.reducedMotion = false,
  });

  final RaceSetup setup;
  final void Function(int position) onPositionChanged;
  final void Function(OvertakeEvent event) onOvertake;
  final void Function(PlayerRaceOutcome outcome) onPlayerFinished;
  final bool reducedMotion;

  // HUD bindings — cheap 60fps reads, never bloc emissions.
  final ValueNotifier<double> speedKph = ValueNotifier(0);
  final ValueNotifier<double> lapProgress = ValueNotifier(0);
  final ValueNotifier<bool> slipstreamActive = ValueNotifier(false);

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
  final Random _fxRng = Random();

  bool _running = false;
  bool _finishedReported = false;
  bool _left = false, _right = false, _throttle = false, _brake = false;
  double _accumulator = 0;
  double _cameraRefX = 0;
  OvertakeEvent? _bestOvertake;

  static const double _subDt = 1 / 120;

  /// Player car's fixed screen row (fraction of height from the top).
  static const double _anchorFrac = 0.68;

  // -- camera / world→screen mapping ----------------------------------------

  /// Vertical px per metre — sized so the player can see ~95m up the road.
  double get pxPerMeterY => max(3.0, size.y * _anchorFrac / 95);

  /// Lateral px per metre for lane offsets — the asphalt band spans ~42% of
  /// the screen width.
  double get pxPerMeterX => size.x * 0.42 / (kTrackHalfWidth * 2);

  /// Curvature is compressed relative to lane widths so a 30m corner bend
  /// sweeps across the screen instead of off it (pseudo-scroller trick). The
  /// engine drifts the car wide by this same ratio (see [kBendCompression]) so
  /// the physics and the drawn road agree on how sharp the bend is.
  double get bendPxPerMeter => pxPerMeterX * kBendCompression;

  double get anchorY => size.y * _anchorFrac;

  Offset worldToScreen(double distance, double lateral) {
    final bend =
        raceCenterlineX(field.circuit, field.sectionStarts, distance) *
        bendPxPerMeter;
    return Offset(
      size.x / 2 + (bend - _cameraRefX) + lateral * pxPerMeterX,
      anchorY - (distance - field.player.distance) * pxPerMeterY,
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
    _cameraRefX =
        raceCenterlineX(
          field.circuit,
          field.sectionStarts,
          field.player.distance,
        ) *
        bendPxPerMeter;

    add(_TrackComponent()..priority = -10);
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

  void setInputs({bool? left, bool? right, bool? throttle, bool? brake}) {
    _left = left ?? _left;
    _right = right ?? _right;
    _throttle = throttle ?? _throttle;
    _brake = brake ?? _brake;
  }

  RaceInputs get _playerInputs => RaceInputs(
    steer: (_right ? 1.0 : 0.0) - (_left ? 1.0 : 0.0),
    throttle: _throttle,
    brake: _brake,
  );

  // -- race lifecycle ---------------------------------------------------------

  /// Lights out: applies the graded launches and arms the simulation.
  void startRace(LaunchGrade playerGrade) {
    if (_running || _finishedReported) return;
    applyLaunch(field, playerGrade, Random(setup.seed ^ 0x1a));
    _running = true;
  }

  void stopRace() => _running = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_running) {
      // Clamp + fixed substeps so a dropped frame can't tunnel a braking zone.
      _accumulator += min(dt, 1 / 30);
      while (_accumulator >= _subDt && _running) {
        _accumulator -= _subDt;
        final events = _engine.tick(field, _playerInputs, _subDt);
        _handleEvents(events);
      }
    }
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
    if ((events.playerWallContact || events.playerContact) && !reducedMotion) {
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
        ),
      );
    }
    if (events.playerStuckOut && !_finishedReported) {
      // Game over: stuck too long. Classified last (DNF), no lap time.
      _finishedReported = true;
      _running = false;
      onPlayerFinished(
        const PlayerRaceOutcome(
          position: kFieldSize,
          lapTimeMs: 0,
          dnf: true,
        ),
      );
    }
  }

  void _syncCamera() {
    // Lock the camera exactly onto the centerline under the player so the
    // player car keeps a fixed horizontal screen position — offset only by its
    // own lateral, i.e. only when the player steers. Any lag/smoothing here
    // reads as the car sliding sideways on its own through a bend.
    _cameraRefX =
        raceCenterlineX(
          field.circuit,
          field.sectionStarts,
          field.player.distance,
        ) *
        bendPxPerMeter;
  }

  void _syncSprites() {
    if (!isLoaded) return;
    final playerDistance = field.player.distance;
    final window = viewAheadMeters;
    for (final sprite in _carSprites) {
      final delta = sprite.car.distance - playerDistance;
      sprite.visibleOnTrack = delta > -60 && delta < window;
      if (!sprite.visibleOnTrack) continue;
      final at = worldToScreen(sprite.car.distance, sprite.car.lateral);
      sprite.position = Vector2(at.dx, at.dy);
      // Slimmer + longer than the old 1.75 block — real F1 proportions.
      final carW = kCarWidth * pxPerMeterX * 0.68;
      sprite.size = Vector2(carW, carW * 2.05);
      sprite.angle = sprite.car.spinning
          ? sin(sprite.car.spinTimer * 24) * 0.7
          : (_steerLean(sprite.car));
    }
  }

  double _steerLean(CarState car) {
    if (!car.isPlayer) return 0;
    return ((_right ? 1 : 0) - (_left ? 1 : 0)) * 0.12;
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
      lapProgress.value =
          ((player.distance - lapIndex * lapLength) / lapLength).clamp(
        0.0,
        1.0,
      );
    }
    slipstreamActive.value = player.slipstreaming;
    stuckSeconds.value = _running ? field.playerStuckSeconds : 0;
  }

  void _spawnSparks(Color color, int count) {
    if (!isLoaded) return;
    final player = field.player;
    final at = worldToScreen(player.distance, player.lateral);
    add(
      ParticleSystemComponent(
        position: Vector2(at.dx, at.dy),
        priority: 30,
        particle: Particle.generate(
          count: count,
          lifespan: 0.45,
          generator: (_) {
            final angle = _fxRng.nextDouble() * pi * 2;
            final speed = 60 + _fxRng.nextDouble() * 160;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              acceleration: Vector2(0, 260),
              child: CircleParticle(
                radius: 1.4 + _fxRng.nextDouble() * 1.8,
                paint: Paint()..color = color,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void onRemove() {
    speedKph.dispose();
    lapProgress.dispose();
    slipstreamActive.dispose();
    stuckSeconds.dispose();
    currentLap.dispose();
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
      Paint()..color = const Color(0xff07230f),
    );
    // Asphalt.
    canvas.drawPath(
      _band(leftEdge, rightEdge),
      Paint()..color = const Color(0xff11161f),
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
        for (var s = max(sectionStart, from);
            s < min(sectionEnd, to);
            s += 5, red = !red) {
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = (red ? Cyber.danger : const Color(0xffe8ecf2)).withValues(
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

  void _checker(Canvas canvas, GrandPrixGame gameRef, double at, {int rows = 2}) {
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
          Paint()
            ..color = even
                ? const Color(0xffe8ecf2)
                : const Color(0xff0a0e14),
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

    paintGrandPrixCar(canvas, w, h, _style);

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
