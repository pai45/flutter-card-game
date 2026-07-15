/// Pure race simulation for Grand Prix Dash.
///
/// No Flutter/Flame imports — everything here is deterministic given a seeded
/// [Random] and a fixed tick, so it is fully unit-testable (mirrors
/// `football_chess_engine.dart`). The simulation is 1D: each car is a distance
/// along the lap centerline plus a lateral offset. Corners affect physics only
/// through their `safeSpeed`; how the road bends on screen is rendering-only
/// (see [centerlineX]).
library;

import 'dart:math';

import '../../models/grand_prix.dart';
import '../../models/progression.dart' show cpuSmartness;

// ---------------------------------------------------------------------------
// Tuning constants (m, m/s, m/s², seconds). All race feel lives here.
// ---------------------------------------------------------------------------

const double kTopSpeed = 88; // ~316 kph
const double kAccel = 26; // peak acceleration off the line
const double kCoast = 10; // speed decay with throttle released
const double kBrake = 44; // braking deceleration
const double kCarLength = 5.5;
const double kCarWidth = 2.0;

/// Drivable asphalt half-width (~4 car-widths of total band + margins).
const double kTrackHalfWidth = 4.5;

/// Grass runs from the asphalt edge to the wall; the wall is a hard clamp.
const double kWallLateral = 6.5;
const double kGrassTopSpeedFactor = 0.55;

/// Off the asphalt the car bogs down hard — enough that a car that runs wide
/// and is NOT steered back grinds to a crawl and gets stuck (below
/// [kStuckSpeed]), which eventually ends the race (see [kStuckTimeout]).
const double kGrassDrag = 22; // direct m/s² lost while off the asphalt

const double kSteerRate = 7.5; // lateral m/s at full stick

/// The rendered road compresses corner curvature to this fraction of lane
/// widths (`bendPxPerMeter = pxPerMeterX * kBendCompression` in the Flame
/// game). The physics drifts the car to the OUTSIDE of a bend by the same
/// amount as the road curves, so a straight-heading (un-steered) car runs wide
/// and the player must steer INTO the corner to follow it. Keep the two in sync.
const double kBendCompression = 0.18;

/// Below this forward speed (m/s) the player counts as stuck — reached only by
/// running off / into a barrier and stopping, never by normal cornering (the
/// slowest safe corner is ~23 m/s).
const double kStuckSpeed = 14;

/// Seconds the player may stay stuck (below [kStuckSpeed]) before the race is
/// over — steer back onto the track and get moving to reset it.
const double kStuckTimeout = 10.0;
const double kSlipstreamMin = 4;
const double kSlipstreamMax = 28;
const double kSlipstreamBoost = 0.08;
const double kSlipstreamAlign = 1.8;

/// Speed scrubbed per second per m/s of corner overspeed (tyres scrubbing when
/// the car carries more than the safe entry speed). Overspeed bleeds off as a
/// pure speed loss — it never pushes the car sideways, so the driver keeps full
/// lateral control through the bend and the car only leaves its line on steer.
const double kScrub = 2.2;

const double kWallHitSpeedFactor = 0.35;

/// A corner wall impact only spins the car (the one hard-shake in a turn) when
/// it arrives with real speed — a slow graze along the barrier just scrubs.
const double kWallSpinMinSpeed = 30;
const double kSpinSeconds = 0.8;
const double kSpinSpeedFactor = 0.25; // crawl speed multiplier while spinning
const double kContactRearDecel = 30; // m/s² lost by the rear car while touching
const double kContactFrontDecel = 14; // m/s² lost by the car hit from behind
const double kContactPushRate = 12; // lateral separation m/s while overlapping
const double kHeavyContactClosingSpeed = 15;
const double kJumpStartCutSeconds = 2.0;
const int kFieldSize = 20;
const double kGridGap = 7.0; // metres between grid slots
const double kMaxCornerError = 0.35; // weak-CPU corner-entry overspeed fraction

// ---------------------------------------------------------------------------
// Launch grading (the lights-out skill moment)
// ---------------------------------------------------------------------------

LaunchGrade gradeLaunch(Duration reaction) {
  final ms = reaction.inMilliseconds;
  if (ms < 150) return LaunchGrade.perfect;
  if (ms < 300) return LaunchGrade.great;
  if (ms < 500) return LaunchGrade.good;
  return LaunchGrade.slow;
}

/// Off-the-line reward for a launch grade: an instant rolling start speed plus
/// a temporary acceleration multiplier. A jump start gets nothing — the
/// throttle cut is applied separately in [applyLaunch].
({double initialSpeed, double accelFactor, double boostSeconds}) launchBoost(
  LaunchGrade grade,
) => switch (grade) {
  LaunchGrade.perfect => (initialSpeed: 14, accelFactor: 1.5, boostSeconds: 3.0),
  LaunchGrade.great => (initialSpeed: 10, accelFactor: 1.35, boostSeconds: 2.5),
  LaunchGrade.good => (initialSpeed: 7, accelFactor: 1.2, boostSeconds: 2.0),
  LaunchGrade.slow => (initialSpeed: 2, accelFactor: 1.0, boostSeconds: 0),
  LaunchGrade.jump => (initialSpeed: 0, accelFactor: 1.0, boostSeconds: 0),
};

/// CPU reaction sample: stronger fields launch better (never jump-start).
Duration sampleCpuReaction(double strength, Random random) {
  final bestMs = 140 + (1 - strength) * 160;
  final spreadMs = 120 + (1 - strength) * 240;
  return Duration(
    milliseconds: (bestMs + random.nextDouble() * spreadMs).round(),
  );
}

// ---------------------------------------------------------------------------
// Car / field state
// ---------------------------------------------------------------------------

enum CarMode { racing, spinning, finished }

class CarState {
  CarState({
    required this.index,
    required this.isPlayer,
    required this.name,
    required this.livery,
    required this.distance,
    required this.lateral,
    this.strength = 0,
    this.paceJitter = 0,
    this.cornerNoise = 0,
  });

  final int index;
  final bool isPlayer;
  final String name;
  final GrandPrixLivery livery;

  double distance; // m along the lap; negative on the grid behind the line
  double lateral; // m, negative = left
  double speed = 0;
  int sectionIndex = 0;
  CarMode mode = CarMode.racing;
  double spinTimer = 0;
  double throttleCutTimer = 0;
  double launchBoostTimer = 0;
  double launchAccelFactor = 1.0;
  bool slipstreaming = false;
  double finishTimeMs = -1;

  // CPU personality (seeded at build; player leaves these at 0/1).
  final double strength; // cpuSmartness(level) with per-car spread
  final double paceJitter; // small ± on top speed
  final double cornerNoise; // 0..1 — how hot this driver enters corners
  double targetLateral = 0;

  bool get finished => mode == CarMode.finished;
  bool get spinning => mode == CarMode.spinning;
  bool get onGrass => lateral.abs() > kTrackHalfWidth;
}

class RaceInputs {
  const RaceInputs({this.steer = 0, this.throttle = false, this.brake = false});

  final double steer; // −1 (left) .. 1 (right)
  final bool throttle;
  final bool brake;
}

/// Everything the cubit fixes at race start so the Flame game and the engine
/// replay the same race for the same seed.
class RaceSetup {
  const RaceSetup({
    required this.circuit,
    required this.playerLivery,
    required this.playerLevel,
    required this.startPosition,
    required this.seed,
    this.laps = 1,
  });

  final GrandPrixCircuit circuit;
  final GrandPrixLivery playerLivery;
  final int playerLevel;
  final int startPosition; // grid slot, P8–P16
  final int seed;

  /// Race distance in laps (1 = sprint).
  final int laps;
}

class RaceField {
  RaceField({
    required this.circuit,
    required this.cars,
    this.laps = 1,
  }) : sectionStarts = _cumulative(circuit.sections);

  final GrandPrixCircuit circuit;
  final List<CarState> cars;
  final List<double> sectionStarts;
  final int laps;
  double raceClockMs = 0;

  /// Full race distance — the finish line's position on the distance axis.
  double get raceLength => circuit.lapLength * laps;

  /// How long the player has been stuck (below [kStuckSpeed]) without a break.
  /// Resets the instant the player is moving again; [kStuckTimeout] ends it.
  double playerStuckSeconds = 0;

  CarState get player => cars.firstWhere((car) => car.isPlayer);

  static List<double> _cumulative(List<TrackSection> sections) {
    final starts = <double>[];
    var s = 0.0;
    for (final section in sections) {
      starts.add(s);
      s += section.length;
    }
    return starts;
  }
}

/// What the Flame game reports up to the cubit when the player crosses the
/// line — everything needed to settle the race.
class PlayerRaceOutcome {
  const PlayerRaceOutcome({
    required this.position,
    required this.lapTimeMs,
    this.bestOvertakeName,
    this.dnf = false,
  });

  final int position;
  final int lapTimeMs;

  /// Name of the highest-placed car the player passed on track (MVP move).
  final String? bestOvertakeName;

  /// True when the player never finished — they got stuck and timed out.
  final bool dnf;
}

/// Coarse per-tick events — everything the HUD/cubit cares about. High-
/// frequency values (speed, exact distances) are read straight off the field.
class RaceTickEvents {
  int? playerPosition; // set only on change
  final List<OvertakeEvent> overtakes = [];
  bool playerWallContact = false;
  bool playerContact = false;
  bool playerCrossedLine = false;

  /// The player stayed stuck past [kStuckTimeout] — the race is over (DNF).
  bool playerStuckOut = false;

  bool get isEmpty =>
      playerPosition == null &&
      overtakes.isEmpty &&
      !playerWallContact &&
      !playerContact &&
      !playerCrossedLine &&
      !playerStuckOut;
}

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

int sectionAt(List<double> sectionStarts, List<TrackSection> sections, double s) {
  if (s <= 0) return 0;
  for (var i = sections.length - 1; i >= 0; i--) {
    if (s >= sectionStarts[i]) return i;
  }
  return 0;
}

double _smoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Distance within the current lap. Grid distances (≤ 0, behind the line)
/// pass through untouched so grid cars still resolve to section 0.
double lapLocalDistance(double lapLength, double distance) =>
    distance <= 0 ? distance : distance % lapLength;

/// Multi-lap centerline: continuous across the start/finish line so cars on
/// different laps agree on where the road is. Each completed lap contributes
/// the full-lap shift; the current lap adds the usual [centerlineX].
double raceCenterlineX(
  GrandPrixCircuit circuit,
  List<double> sectionStarts,
  double s,
) {
  if (s <= 0) return 0;
  final lapLength = circuit.lapLength;
  final lap = s ~/ lapLength;
  final local = s - lap * lapLength;
  if (lap == 0) return centerlineX(circuit, sectionStarts, local);
  return lap * centerlineX(circuit, sectionStarts, lapLength) +
      centerlineX(circuit, sectionStarts, local);
}

/// Rendering-only: the sideways world offset of the track centerline at lap
/// distance [s]. Straights hold their offset; a corner eases across by its
/// signed bend; a chicane swings out and back (an S through the section).
double centerlineX(GrandPrixCircuit circuit, List<double> sectionStarts, double s) {
  var x = 0.0;
  final clamped = s.clamp(0.0, circuit.lapLength);
  for (var i = 0; i < circuit.sections.length; i++) {
    final section = circuit.sections[i];
    final start = sectionStarts[i];
    final end = start + section.length;
    if (clamped <= start) break;
    final t = ((clamped.clamp(start, end)) - start) / section.length;
    switch (section.type) {
      case TrackSectionType.straight:
        break;
      case TrackSectionType.corner:
        x += section.signedBend * _smoothstep(t);
      case TrackSectionType.chicane:
        // Out by half the bend, then back — net zero shift.
        x += section.signedBend * sin(t * pi) * 0.5;
    }
  }
  return x;
}

/// 1 + the number of cars ahead. Finished cars rank by finish time and always
/// beat running cars.
int positionOf(RaceField field, CarState car) {
  var ahead = 0;
  for (final other in field.cars) {
    if (identical(other, car)) continue;
    if (car.finished) {
      if (other.finished && other.finishTimeMs < car.finishTimeMs) ahead++;
    } else if (other.finished || other.distance > car.distance) {
      ahead++;
    }
  }
  return 1 + ahead;
}

// ---------------------------------------------------------------------------
// Field construction + launch
// ---------------------------------------------------------------------------

RaceField buildField(RaceSetup setup, List<String> driverNames, Random random) {
  assert(driverNames.length >= kFieldSize - 1);
  final baseStrength = cpuSmartness(setup.playerLevel);
  final cpuLiveries = GrandPrixLivery.values
      .where((livery) => livery != setup.playerLivery)
      .toList();

  final cars = <CarState>[];
  var cpuCount = 0;
  for (var slot = 1; slot <= kFieldSize; slot++) {
    final isPlayer = slot == setup.startPosition;
    // Staggered two-wide grid behind the start line.
    final gridDistance = -kGridGap * slot;
    final gridLateral = (slot.isOdd ? -1.8 : 1.8);
    if (isPlayer) {
      cars.add(
        CarState(
          index: cars.length,
          isPlayer: true,
          name: 'YOU',
          livery: setup.playerLivery,
          distance: gridDistance,
          lateral: gridLateral,
        ),
      );
    } else {
      cars.add(
        CarState(
          index: cars.length,
          isPlayer: false,
          name: driverNames[cpuCount],
          livery: cpuLiveries[cpuCount % cpuLiveries.length],
          distance: gridDistance,
          lateral: gridLateral,
          strength: (baseStrength + (random.nextDouble() - 0.5) * 0.3).clamp(
            0.0,
            1.0,
          ),
          paceJitter: (random.nextDouble() - 0.5) * 0.04,
          cornerNoise: 0.2 + random.nextDouble() * 0.8,
        ),
      );
      cpuCount++;
    }
  }
  return RaceField(
    circuit: setup.circuit,
    cars: cars,
    laps: setup.laps,
  );
}

/// Applies lights-out launches: the player's graded boost (or jump-start
/// throttle cut) and a sampled reaction for every CPU. Call once when racing
/// goes live.
void applyLaunch(RaceField field, LaunchGrade playerGrade, Random random) {
  for (final car in field.cars) {
    final grade = car.isPlayer
        ? playerGrade
        : gradeLaunch(sampleCpuReaction(car.strength, random));
    final boost = launchBoost(grade);
    car.speed = boost.initialSpeed;
    car.launchBoostTimer = boost.boostSeconds;
    car.launchAccelFactor = boost.accelFactor;
    if (car.isPlayer && grade == LaunchGrade.jump) {
      car.throttleCutTimer = kJumpStartCutSeconds;
    }
  }
}

// ---------------------------------------------------------------------------
// The engine
// ---------------------------------------------------------------------------

class GrandPrixEngine {
  GrandPrixEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Advances the whole field by [dt] seconds. Mutates [field]; returns the
  /// coarse events of this tick.
  RaceTickEvents tick(RaceField field, RaceInputs playerInputs, double dt) {
    final events = RaceTickEvents();
    final player = field.player;
    final prevPlayerPosition = positionOf(field, player);
    final prevAhead = <int>{
      for (final car in field.cars)
        if (!car.isPlayer && !player.finished && car.distance > player.distance)
          car.index,
    };

    field.raceClockMs += dt * 1000;

    for (final car in field.cars) {
      if (car.finished) {
        // Coast over the line so finishers glide out of frame.
        car.speed = max(0, car.speed - kCoast * dt);
        car.distance += car.speed * dt;
        continue;
      }
      final inputs = car.isPlayer ? playerInputs : _cpuInputs(field, car);
      _stepCar(field, car, inputs, dt, events);
    }

    _resolveContacts(field, dt, events);
    _detectFinishes(field, dt, events);

    // Position + overtake diff (player only — the HUD cares about the player).
    final newPosition = positionOf(field, player);
    if (newPosition != prevPlayerPosition) events.playerPosition = newPosition;
    if (!player.finished) {
      for (final car in field.cars) {
        if (car.isPlayer || !prevAhead.contains(car.index)) continue;
        if (car.distance <= player.distance && !car.finished) {
          events.overtakes.add(
            OvertakeEvent(
              overtakenName: car.name,
              overtakenPosition: newPosition,
              atDistance: player.distance,
            ),
          );
        }
      }
    }

    // Stuck watchdog: if the player runs off / into a barrier and grinds to a
    // crawl, the clock runs out and the race is over. Reset the moment they're
    // moving again — steering back onto the track is the escape.
    if (!player.finished) {
      if (player.speed < kStuckSpeed) {
        field.playerStuckSeconds += dt;
        if (field.playerStuckSeconds >= kStuckTimeout) {
          events.playerStuckOut = true;
        }
      } else {
        field.playerStuckSeconds = 0;
      }
    }
    return events;
  }

  // -- per-car step ---------------------------------------------------------

  void _stepCar(
    RaceField field,
    CarState car,
    RaceInputs inputs,
    double dt,
    RaceTickEvents events,
  ) {
    final sections = field.circuit.sections;
    car.sectionIndex = sectionAt(
      field.sectionStarts,
      sections,
      lapLocalDistance(field.circuit.lapLength, car.distance),
    );
    final section = sections[car.sectionIndex];
    final prevLateral = car.lateral;

    // Timers.
    if (car.spinTimer > 0) {
      car.spinTimer = max(0, car.spinTimer - dt);
      if (car.spinTimer == 0 && car.mode == CarMode.spinning) {
        car.mode = CarMode.racing;
      }
    }
    if (car.throttleCutTimer > 0) {
      car.throttleCutTimer = max(0, car.throttleCutTimer - dt);
    }
    if (car.launchBoostTimer > 0) {
      car.launchBoostTimer = max(0, car.launchBoostTimer - dt);
      if (car.launchBoostTimer == 0) car.launchAccelFactor = 1.0;
    }

    // Slipstream (straights only).
    car.slipstreaming = false;
    if (section.isStraight && !car.spinning) {
      for (final other in field.cars) {
        if (identical(other, car)) continue;
        final gap = other.distance - car.distance;
        if (gap >= kSlipstreamMin &&
            gap <= kSlipstreamMax &&
            (other.lateral - car.lateral).abs() < kSlipstreamAlign) {
          car.slipstreaming = true;
          break;
        }
      }
    }

    // Effective top speed.
    var effTop = kTopSpeed;
    if (car.slipstreaming) effTop *= 1 + kSlipstreamBoost;
    if (!car.isPlayer) effTop *= 0.9 + 0.1 * car.strength + car.paceJitter;
    if (car.onGrass) effTop *= kGrassTopSpeedFactor;

    // Speed integration.
    final throttleOn =
        inputs.throttle && car.throttleCutTimer == 0 && !car.spinning;
    if (inputs.brake && !car.spinning) {
      car.speed = max(0, car.speed - kBrake * dt);
    } else if (throttleOn) {
      final headroom = max(0.0, 1 - car.speed / effTop);
      car.speed += kAccel * car.launchAccelFactor * headroom * dt;
    } else {
      car.speed = max(0, car.speed - kCoast * dt);
    }
    if (car.speed > effTop) {
      // Ease down when boost/slipstream expires instead of snapping.
      car.speed = max(effTop, car.speed - kCoast * 2 * dt);
    }
    if (car.spinning) car.speed = min(car.speed, kTopSpeed * kSpinSpeedFactor);

    // Corner resolution — carrying more than the safe entry speed scrubs speed
    // (tyres fighting for grip) but NEVER moves the car sideways on its own.
    // The driver keeps full lateral control, so the car holds its line through
    // a corner and only leaves it when the player actually steers. Steering all
    // the way into the outside wall is what spins the car — handled at the wall
    // clamp below.
    final safeSpeed = section.safeSpeed;
    if (safeSpeed != null && !car.spinning && car.speed > safeSpeed) {
      car.speed = max(0, car.speed - kScrub * (car.speed - safeSpeed) * dt);
    }

    // Lateral integration: steering, then the corner's curvature drift.
    if (!car.spinning) {
      car.lateral += kSteerRate * inputs.steer.clamp(-1.0, 1.0) * dt;

      // Curvature drift: the car holds a straight heading unless steered, so as
      // the road bends its centerline slides out from under it. Without steering
      // the car runs to the OUTSIDE of the corner (matching the drawn bend);
      // the player must steer INTO the bend to follow the road. Straights don't
      // bend, so they add no drift — the car only moves on the player's input.
      final ahead = car.distance + car.speed * dt;
      final centerShift =
          raceCenterlineX(field.circuit, field.sectionStarts, ahead) -
          raceCenterlineX(field.circuit, field.sectionStarts, car.distance);
      car.lateral -= centerShift * kBendCompression;
    }
    if (car.onGrass) {
      car.speed = max(0, car.speed - kGrassDrag * dt);
    }
    if (car.lateral.abs() >= kWallLateral) {
      // Fresh hit = the car was strictly inside the wall last tick and reached
      // it this tick. Reaching the wall exactly (steering lands on the clamp)
      // still counts; once pinned, prevLateral == kWallLateral so it reads as a
      // graze, not a repeat spin.
      final freshHit = prevLateral.abs() < kWallLateral;
      car.lateral = car.lateral.clamp(-kWallLateral, kWallLateral);
      if (freshHit &&
          !section.isStraight &&
          !car.spinning &&
          car.speed > kWallSpinMinSpeed) {
        // Ran clean off the road into the outside barrier mid-corner: big loss
        // + spin. This is the ONLY hard-shake in a turn, and it can't trigger
        // until the car is past the kerb and actually into the wall.
        car.speed *= kWallHitSpeedFactor;
        car.mode = CarMode.spinning;
        car.spinTimer = kSpinSeconds;
      } else {
        // A graze, or scraping the wall down a straight, just bleeds speed.
        car.speed = max(0, car.speed - kBrake * 0.75 * dt);
      }
      if (car.isPlayer) events.playerWallContact = true;
    }

    // Distance integration.
    car.distance += car.speed * dt;
  }

  // -- CPU driver -----------------------------------------------------------

  RaceInputs _cpuInputs(RaceField field, CarState car) {
    var brake = _shouldBrake(
      field,
      car,
      errorFactor: kMaxCornerError * (1 - car.strength) * car.cornerNoise,
    );

    // Steering: ease toward the racing line; defend the inside on straights.
    var target = _racingLineLateral(field, car);
    final section = field.circuit.sections[car.sectionIndex];
    if (section.isStraight && car.strength > 0.5) {
      final attacker = _attackerBehind(field, car);
      if (attacker != null && _random.nextDouble() < car.strength * 0.03) {
        // Occasional covering move toward the attacker's side.
        car.targetLateral = attacker.lateral.clamp(
          -kTrackHalfWidth * 0.8,
          kTrackHalfWidth * 0.8,
        );
      }
      if (car.targetLateral != 0) target = car.targetLateral;
    } else {
      car.targetLateral = 0;
    }

    // Avoidance/passing: never plow into a slower car ahead — pull to the
    // free side (on straights this doubles as the overtake setup) and lift
    // when right on its gearbox.
    final blocker = _blockerAhead(field, car);
    if (blocker != null) {
      if (section.isStraight) {
        final passSide = blocker.lateral >= car.lateral ? -1 : 1;
        target = (car.lateral + passSide * kCarWidth * 1.6).clamp(
          -kTrackHalfWidth,
          kTrackHalfWidth,
        );
      }
      if (blocker.distance - car.distance < kCarLength * 1.4) brake = true;
    }

    final delta = target - car.lateral;
    final steer = delta.abs() < 0.25 ? 0.0 : (delta.sign * min(1, delta.abs() / 2));
    return RaceInputs(steer: steer, throttle: !brake, brake: brake);
  }

  /// The nearest meaningfully slower car directly ahead within a couple of
  /// car lengths — the one this CPU must steer around or lift for.
  CarState? _blockerAhead(RaceField field, CarState car) {
    CarState? nearest;
    var nearestGap = double.infinity;
    for (final other in field.cars) {
      if (identical(other, car) || other.finished) continue;
      final gap = other.distance - car.distance;
      if (gap <= 0 || gap > kCarLength * 3) continue;
      if ((other.lateral - car.lateral).abs() > kCarWidth * 1.3) continue;
      if (other.speed > car.speed - 1) continue;
      if (gap < nearestGap) {
        nearest = other;
        nearestGap = gap;
      }
    }
    return nearest;
  }

  /// Physics stopping-distance check against the next corner. [errorFactor]
  /// inflates the believed-safe entry speed — weak CPUs arrive hot and pay in
  /// the corner resolution.
  bool _shouldBrake(RaceField field, CarState car, {required double errorFactor}) {
    final sections = field.circuit.sections;
    final lapLength = field.circuit.lapLength;
    final localDistance = lapLocalDistance(lapLength, car.distance);
    final index = car.sectionIndex;
    final current = sections[index];
    double believed(double safe) => safe * (1 + errorFactor);

    // Already inside a corner and over the TRUE safe speed → back off. The
    // error inflation only applies to the entry lookahead (below), so a weak
    // CPU still brakes late and arrives hot; but once in the corner no car
    // keeps the throttle pinned above the grip limit and slowly runs itself
    // off onto the grass.
    final currentSafe = current.safeSpeed;
    if (currentSafe != null && car.speed > currentSafe) return true;

    // Look ahead to the next corner within braking range, wrapping across the
    // start/finish line on multi-lap races (every circuit opens with a long
    // straight, so the wrap never triggers braking before the actual finish).
    for (var step = currentSafe != null ? 1 : 0; step < sections.length; step++) {
      final i = (index + step) % sections.length;
      var distTo = field.sectionStarts[i] - localDistance;
      if (i < index || (i == index && step > 0)) distTo += lapLength;
      if (distTo > 450) break;
      final nextSafe = sections[i].safeSpeed;
      if (nextSafe == null) continue;
      final target = believed(nextSafe);
      if (car.speed <= target) break;
      final need =
          (car.speed * car.speed - target * target) / (2 * kBrake) +
          car.speed * 0.15;
      if (need >= distTo) return true;
      break;
    }
    return false;
  }

  /// The lateral the racing line wants at the car's current spot: apex on the
  /// inside through corners/chicanes, track middle on straights.
  double _racingLineLateral(RaceField field, CarState car) {
    final section = field.circuit.sections[car.sectionIndex];
    switch (section.type) {
      case TrackSectionType.straight:
        return 0;
      case TrackSectionType.corner:
        final insideSign = section.direction == CornerDirection.left ? -1 : 1;
        return insideSign * kTrackHalfWidth * 0.55;
      case TrackSectionType.chicane:
        // Flick to the entry side then across — approximate with the entry
        // side for the first half, exit side for the second.
        final start = field.sectionStarts[car.sectionIndex];
        final local = lapLocalDistance(field.circuit.lapLength, car.distance);
        final t = (local - start) / section.length;
        final entrySign = section.direction == CornerDirection.left ? -1 : 1;
        return (t < 0.5 ? entrySign : -entrySign) * kTrackHalfWidth * 0.45;
    }
  }

  CarState? _attackerBehind(RaceField field, CarState car) {
    CarState? nearest;
    var nearestGap = double.infinity;
    for (final other in field.cars) {
      if (identical(other, car) || other.finished) continue;
      final gap = car.distance - other.distance;
      if (gap > 0 && gap < kSlipstreamMax && gap < nearestGap) {
        nearest = other;
        nearestGap = gap;
      }
    }
    return nearest;
  }

  // -- contact --------------------------------------------------------------

  void _resolveContacts(RaceField field, double dt, RaceTickEvents events) {
    final ordered = [...field.cars]
      ..sort((a, b) => a.distance.compareTo(b.distance));
    for (var i = 0; i < ordered.length - 1; i++) {
      final rear = ordered[i];
      final front = ordered[i + 1];
      if (rear.finished || front.finished) continue;
      if (front.distance - rear.distance > kCarLength) continue;
      if ((front.lateral - rear.lateral).abs() > kCarWidth) continue;

      // Contact costs BOTH cars speed — it's a downside, not a weapon. CPU↔CPU
      // touches are softened: full contact physics is a player experience, and
      // unsoftened it bunches high-level fields into slow contact trains.
      final playerInvolved = rear.isPlayer || front.isPlayer;
      final softening = playerInvolved ? 1.0 : 0.35;
      final closing = rear.speed - front.speed;
      rear.speed = max(0, rear.speed - kContactRearDecel * softening * dt);
      front.speed = max(0, front.speed - kContactFrontDecel * softening * dt);
      // Nudge apart laterally.
      final push = (rear.lateral <= front.lateral ? -1 : 1) * kContactPushRate * dt;
      rear.lateral = (rear.lateral + push).clamp(-kWallLateral, kWallLateral);
      front.lateral = (front.lateral - push).clamp(-kWallLateral, kWallLateral);

      if (closing > kHeavyContactClosingSpeed && !rear.spinning) {
        rear.mode = CarMode.spinning;
        rear.spinTimer = kSpinSeconds;
        rear.speed = min(rear.speed, front.speed * 0.6);
      }
      if (rear.isPlayer || front.isPlayer) events.playerContact = true;
    }
  }

  // -- finish ---------------------------------------------------------------

  void _detectFinishes(RaceField field, double dt, RaceTickEvents events) {
    final raceLength = field.raceLength;
    for (final car in field.cars) {
      if (car.finished || car.distance < raceLength) continue;
      // Sub-tick interpolation for a fair classification.
      final overshoot = car.distance - raceLength;
      final overshootMs = car.speed > 0 ? (overshoot / car.speed) * 1000 : 0;
      car.mode = CarMode.finished;
      car.finishTimeMs = field.raceClockMs - overshootMs;
      if (car.isPlayer) events.playerCrossedLine = true;
    }
  }
}
