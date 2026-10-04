/// Pure race simulation for Grand Prix Dash.
///
/// No Flutter/Flame imports — everything here is deterministic given a seeded
/// [Random] and a fixed tick. Track-space progress, steering, lateral momentum,
/// heading, grip, tow and energy stay independent of Flutter/Flame.
library;

import 'dart:math';

import '../../models/grand_prix.dart';
import '../../models/progression.dart' show cpuSmartness;
import 'grand_prix_track.dart';
import 'grand_prix_car_dimensions.dart';

export 'grand_prix_track.dart';
export 'grand_prix_car_dimensions.dart';

// ---------------------------------------------------------------------------
// Tuning constants (m, m/s, m/s², seconds). All race feel lives here.
// ---------------------------------------------------------------------------

const double kTopSpeed = 88; // ~316 kph
const double kAccel = 26; // peak acceleration off the line
const double kCoast = 10; // speed decay with throttle released
const double kBrake = 44; // braking deceleration

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
const double kBendCompression = 0.21;

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
const double kContactRearDecel = 22; // m/s² lost by the rear car while touching
const double kContactFrontDecel = 14; // impact remains a loss even under ERS
const double kContactPushRate = 12; // lateral separation m/s while overlapping
const double kHeavyContactClosingSpeed = 22;
const double kJumpStartCutSeconds = 2.0;
const int kFieldSize = 20;
const double kGridGap = 7.0; // metres between grid slots
const double kMaxCornerError = 0.35; // weak-CPU corner-entry overspeed fraction

/// The scroller stretches lane widths relative to forward distance. Keep that
/// projection from turning an ordinary lane change into a sideways-looking car.
double projectedGrandPrixCarHeading({
  required double roadSlope,
  required double relativeHeading,
  required double lateralScale,
  required double forwardScale,
  required bool straight,
}) {
  final angle = atan(
    (roadSlope * kBendCompression + tan(relativeHeading)) *
        lateralScale /
        forwardScale,
  );
  final bend = straight ? 0.0 : (roadSlope.abs() / .5).clamp(0.0, 1.0);
  final limit = pi / 15 + (pi / 5 - pi / 15) * bend;
  return angle.clamp(-limit, limit);
}

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
  LaunchGrade.perfect => (
    initialSpeed: 14,
    accelFactor: 1.5,
    boostSeconds: 3.0,
  ),
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

enum CpuRacecraft { patient, balanced, aggressive }

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
    this.personality = CpuRacecraft.balanced,
  }) : cruiseLateral = lateral;

  final int index;
  final bool isPlayer;
  final String name;
  final GrandPrixLivery livery;

  double distance; // m along the lap; negative on the grid behind the line
  double lateral; // m, negative = left
  double speed = 0;
  double previousDistance = 0;
  double previousLateral = 0;
  double previousHeading = 0;
  bool hasPreviousPose = false;
  double steeringAngle = 0;
  double lateralVelocity = 0;
  double heading = 0;
  double yawRate = 0;
  double grip = 1;
  double energy = 1;
  double towStrength = 0;
  bool deploying = false;
  double throttleLoad = 0;
  double brakeLoad = 0;
  double recoveryTimer = 0;
  double ghostTimer = 0;
  double decisionTimer = 0;
  double passTarget = 0;
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
  final CpuRacecraft personality;
  double cruiseLateral;
  int decisionSection = 0;

  bool get finished => mode == CarMode.finished;
  bool get spinning => mode == CarMode.spinning;
  bool get onGrass => lateral.abs() > kTrackHalfWidth;
  bool get onKerb => lateral.abs() > kTrackHalfWidth - 0.35 && !onGrass;
  bool get recovering => recoveryTimer > 0;
  int get gear => (1 + speed / 14).floor().clamp(1, 8);
  double get rpm =>
      (0.3 + (speed % 14) / 14 * 0.62 + throttleLoad * 0.08).clamp(0.0, 1.0);
}

class RaceInputs {
  const RaceInputs({
    this.steer = 0,
    this.throttle = false,
    this.brake = false,
    this.throttleAmount,
    this.brakeAmount,
    this.deploy = false,
  });

  final double steer; // −1 (left) .. 1 (right)
  final bool throttle;
  final bool brake;
  final double? throttleAmount;
  final double? brakeAmount;
  final bool deploy;
  static double _pedal(double value) =>
      value.isFinite ? value.clamp(0.0, 1.0) : 0;
  double get throttleValue => _pedal(throttleAmount ?? (throttle ? 1.0 : 0.0));
  double get brakeValue => _pedal(brakeAmount ?? (brake ? 1.0 : 0.0));
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
    this.rulesetVersion = grandPrixRulesetVersion,
  });

  final GrandPrixCircuit circuit;
  final GrandPrixLivery playerLivery;
  final int playerLevel;
  final int startPosition; // grid slot, P8–P16
  final int seed;

  /// Race distance in laps (1 = sprint).
  final int laps;
  final int rulesetVersion;
}

class RaceField {
  RaceField({required this.circuit, required this.cars, this.laps = 1})
    : sectionStarts = _cumulative(circuit.sections) {
    geometry = GrandPrixTrackGeometry(circuit, sectionStarts);
  }

  final GrandPrixCircuit circuit;
  final List<CarState> cars;
  final List<double> sectionStarts;
  final int laps;
  late final GrandPrixTrackGeometry geometry;
  double raceClockMs = 0;
  bool playerCleanRace = true;
  double playerLastContactMs = -10000;
  int playerRecoveries = 0;
  final List<int> playerLapTimesMs = [];
  double _lastLapCrossingMs = 0;
  final Map<int, double> pendingCleanPasses = {};
  final Set<int> cleanPassedCars = {};
  bool playerCornerContact = false;

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
    this.lapTimesMs = const [],
    this.cleanOvertakes = 0,
    this.cleanRace = false,
    this.recoveries = 0,
  });

  final int position;
  final int lapTimeMs;

  /// Name of the highest-placed car the player passed on track (MVP move).
  final String? bestOvertakeName;

  /// True when the player never finished — they got stuck and timed out.
  final bool dnf;
  final List<int> lapTimesMs;
  final int cleanOvertakes;
  final bool cleanRace;
  final int recoveries;
}

enum GrandPrixMomentKind { cleanPass, cleanCorner, lap, recovery }

class GrandPrixMoment {
  const GrandPrixMoment(this.kind, this.label, this.detail);
  final GrandPrixMomentKind kind;
  final String label;
  final String detail;
}

/// Coarse per-tick events — everything the HUD/cubit cares about. High-
/// frequency values (speed, exact distances) are read straight off the field.
class RaceTickEvents {
  int? playerPosition; // set only on change
  final List<OvertakeEvent> overtakes = [];
  bool playerWallContact = false;
  bool playerContact = false;
  bool playerTireScrub = false;
  bool playerCrossedLine = false;
  GrandPrixMoment? moment;
  bool lapCompleted = false;

  /// The player stayed stuck past [kStuckTimeout] — the race is over (DNF).
  bool playerStuckOut = false;

  bool get isEmpty =>
      playerPosition == null &&
      overtakes.isEmpty &&
      !playerWallContact &&
      !playerContact &&
      !playerTireScrub &&
      !playerCrossedLine &&
      moment == null &&
      !lapCompleted &&
      !playerStuckOut;
}

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

int sectionAt(
  List<double> sectionStarts,
  List<TrackSection> sections,
  double s,
) {
  if (s <= 0) return 0;
  for (var i = sections.length - 1; i >= 0; i--) {
    if (s >= sectionStarts[i]) return i;
  }
  return 0;
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
double centerlineX(
  GrandPrixCircuit circuit,
  List<double> sectionStarts,
  double s,
) {
  return trackCenterlineX(circuit, sectionStarts, s);
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
          personality:
              CpuRacecraft.values[random.nextInt(CpuRacecraft.values.length)],
        ),
      );
      cpuCount++;
    }
  }
  return RaceField(circuit: setup.circuit, cars: cars, laps: setup.laps);
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
    assert(dt > 0 && dt.isFinite);
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
      car.previousDistance = car.distance;
      car.previousLateral = car.lateral;
      car.previousHeading = car.heading;
      car.hasPreviousPose = true;
      if (car.finished) {
        // Coast over the line so finishers glide out of frame.
        car.speed = max(0, car.speed - kCoast * dt);
        car.distance += car.speed * dt;
        continue;
      }
      final inputs = car.isPlayer ? playerInputs : _cpuInputs(field, car, dt);
      _stepCar(field, car, inputs, dt, events);
    }

    _resolveContacts(field, dt, events);
    _recordLaps(field, events);
    _detectFinishes(field, dt, events);

    // Position + overtake diff (player only — the HUD cares about the player).
    final newPosition = positionOf(field, player);
    if (newPosition != prevPlayerPosition) events.playerPosition = newPosition;
    if (!player.finished) {
      for (final car in field.cars) {
        if (car.isPlayer || !prevAhead.contains(car.index)) continue;
        if (car.distance <= player.distance && !car.finished) {
          if (!field.cleanPassedCars.contains(car.index) &&
              field.raceClockMs - field.playerLastContactMs >= 1000) {
            field.pendingCleanPasses.putIfAbsent(
              car.index,
              () => field.raceClockMs,
            );
          }
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
    _gradeCleanPasses(field, events);

    // Stuck watchdog: if the player runs off / into a barrier and grinds to a
    // crawl, the clock runs out and the race is over. Reset the moment they're
    // moving again — steering back onto the track is the escape.
    if (!player.finished) {
      if (player.recovering) {
        field.playerStuckSeconds = 0;
      } else if (player.speed < kStuckSpeed) {
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

  /// A three-second stationary recovery. Distance and energy are preserved;
  /// rivals keep racing. Pick the clearest lane and grant brief collision
  /// clearance on release so a rejoin cannot shove a rival out of the way.
  bool recoverPlayer(RaceField field) {
    final car = field.player;
    if (car.finished || car.recovering || field.playerStuckSeconds < 2.5) {
      return false;
    }
    car.recoveryTimer = 3;
    car.speed = 0;
    car.lateralVelocity = 0;
    car.steeringAngle = 0;
    car.mode = CarMode.racing;
    car.spinTimer = 0;
    car.launchBoostTimer = 0;
    car.launchAccelFactor = 1;
    car.deploying = false;
    field.playerRecoveries++;
    field.playerCleanRace = false;
    field.playerStuckSeconds = 0;
    field.pendingCleanPasses.clear();
    return true;
  }

  void _recordLaps(RaceField field, RaceTickEvents events) {
    final car = field.player;
    if (car.finished) return;
    final boundary =
        (field.playerLapTimesMs.length + 1) * field.circuit.lapLength;
    if (boundary > field.raceLength || car.distance < boundary) return;
    final crossedAt =
        field.raceClockMs -
        (car.distance - boundary) / max(0.01, car.speed) * 1000;
    final lapMs = max(1, (crossedAt - field._lastLapCrossingMs).round());
    final oldBest = field.playerLapTimesMs.isEmpty
        ? null
        : field.playerLapTimesMs.reduce(min);
    field.playerLapTimesMs.add(lapMs);
    field._lastLapCrossingMs = crossedAt;
    events.lapCompleted = true;
    if (boundary < field.raceLength) {
      final improved = oldBest != null && lapMs < oldBest;
      events.moment = GrandPrixMoment(
        GrandPrixMomentKind.lap,
        improved ? 'FASTER LAP' : 'LAP COMPLETE',
        '${formatLapTime(lapMs)}${improved ? ' · −${((oldBest - lapMs) / 1000).toStringAsFixed(2)}s' : ''}',
      );
    }
  }

  void _gradeCleanPasses(RaceField field, RaceTickEvents events) {
    for (final index in field.pendingCleanPasses.keys.toList()) {
      final rival = field.cars.firstWhere((car) => car.index == index);
      final since = field.pendingCleanPasses[index]!;
      if (rival.distance >= field.player.distance ||
          field.playerLastContactMs >= since) {
        field.pendingCleanPasses.remove(index);
      } else if (field.raceClockMs - since >= 1000) {
        field.cleanPassedCars.add(index);
        field.pendingCleanPasses.remove(index);
        events.moment = GrandPrixMoment(
          GrandPrixMomentKind.cleanPass,
          'CLEAN OVERTAKE',
          '${rival.name} · ${field.cleanPassedCars.length} CLEAN',
        );
      }
    }
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
    final previousSection = car.sectionIndex;
    final sample = field.geometry.sample(car.distance);
    car.sectionIndex = sample.sectionIndex;
    final section = sections[car.sectionIndex];
    final prevLateral = car.lateral;
    if (car.isPlayer && previousSection != car.sectionIndex) {
      final previous = sections[previousSection];
      if (!previous.isStraight &&
          !field.playerCornerContact &&
          car.grip > 0.8 &&
          !car.onGrass &&
          car.speed >= previous.safeSpeed! * 0.85) {
        events.moment = const GrandPrixMoment(
          GrandPrixMomentKind.cleanCorner,
          'CLEAN EXIT',
          'LINE HELD · CARRY THE SPEED',
        );
      }
      field.playerCornerContact = false;
    }

    if (car.ghostTimer > 0) car.ghostTimer = max(0, car.ghostTimer - dt);
    if (car.recovering) {
      car.recoveryTimer = max(0, car.recoveryTimer - dt);
      if (!car.recovering) {
        var bestLane = 0.0;
        var bestClearance = -1.0;
        for (final lane in const [0.0, -2.5, 2.5]) {
          var clearance = 10.0;
          for (final rival in field.cars) {
            if (identical(rival, car) ||
                (rival.distance - car.distance).abs() > 14) {
              continue;
            }
            clearance = min(clearance, (rival.lateral - lane).abs());
          }
          if (clearance > bestClearance) {
            bestClearance = clearance;
            bestLane = lane;
          }
        }
        car.lateral = bestLane;
        car.previousLateral = bestLane;
        car.heading = 0;
        car.previousHeading = 0;
        car.ghostTimer = 1;
        if (car.isPlayer) {
          events.moment = const GrandPrixMoment(
            GrandPrixMomentKind.recovery,
            'BACK ON TRACK',
            'ACCELERATE · FIND YOUR RHYTHM',
          );
        }
      }
      return;
    }

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

    // Tow builds while following and fades after pulling out. Weak fresh tows
    // provide a small immediate benefit; sustained alignment earns the full tow.
    var towTarget = 0.0;
    if (section.isStraight && !car.spinning) {
      for (final other in field.cars) {
        if (identical(other, car)) continue;
        final gap = other.distance - car.distance;
        if (gap >= kSlipstreamMin &&
            gap <= kSlipstreamMax &&
            (other.lateral - car.lateral).abs() < kSlipstreamAlign) {
          towTarget = max(
            towTarget,
            (1 -
                (gap - kSlipstreamMin) /
                    (kSlipstreamMax - kSlipstreamMin) *
                    0.35),
          );
        }
      }
    }
    car.towStrength +=
        (towTarget - car.towStrength) *
        (1 - exp(-dt * (towTarget > 0 ? 2.5 : 2.0)));
    car.slipstreaming = towTarget > 0 || car.towStrength > 0.1;
    final tow = towTarget > 0 ? max(0.2, car.towStrength) : car.towStrength;
    car.throttleLoad = inputs.throttleValue;
    car.brakeLoad = inputs.brakeValue;
    car.deploying =
        inputs.deploy &&
        car.energy > 0 &&
        car.speed > 15 &&
        car.throttleLoad > 0 &&
        car.brakeLoad == 0 &&
        !car.spinning &&
        !car.onGrass;
    if (car.deploying) {
      car.energy = max(0, car.energy - dt * 0.23);
    } else if (car.speed > 12 && !car.spinning && !car.onGrass) {
      car.energy = min(
        1,
        car.energy +
            dt * (car.brakeLoad * 0.12 + (car.throttleLoad == 0 ? 0.025 : 0)),
      );
    }

    // Effective top speed.
    var effTop = kTopSpeed;
    effTop *= 1 + kSlipstreamBoost * tow;
    if (car.deploying) effTop *= 1.08;
    if (!car.isPlayer) effTop *= 0.9 + 0.1 * car.strength + car.paceJitter;
    if (car.onGrass) effTop *= kGrassTopSpeedFactor;

    // Speed integration.
    final throttleOn =
        car.throttleLoad > 0 && car.throttleCutTimer == 0 && !car.spinning;
    if (car.brakeLoad > 0 && !car.spinning) {
      car.speed = max(0, car.speed - kBrake * car.brakeLoad * dt);
    } else if (throttleOn) {
      final headroom = max(0.0, 1 - car.speed / effTop);
      car.speed +=
          kAccel *
          car.launchAccelFactor *
          headroom *
          car.throttleLoad *
          (car.deploying ? 1.25 : 1.0) *
          dt;
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
    final overspeed = safeSpeed == null
        ? 0.0
        : max(0.0, car.speed - safeSpeed) / safeSpeed;
    car.grip =
        (1 - overspeed * 0.3).clamp(0.65, 1.0) *
        (car.onGrass
            ? 0.5
            : car.onKerb
            ? 0.88
            : 1.0);
    if (safeSpeed != null && !car.spinning && car.speed > safeSpeed) {
      car.speed = max(0, car.speed - kScrub * (car.speed - safeSpeed) * dt);
      if (car.isPlayer) events.playerTireScrub = true;
    }

    // Lateral integration: steering, then the corner's curvature drift.
    if (!car.spinning) {
      final previousHeading = car.heading;
      final steer = inputs.steer.isFinite ? inputs.steer.clamp(-1.0, 1.0) : 0.0;
      car.steeringAngle += (steer - car.steeringAngle) * (1 - exp(-dt * 12));
      final speedFactor = (car.speed / 12).clamp(0.0, 1.0);
      final steeringAuthority = (1 - car.speed / kTopSpeed * 0.2).clamp(
        0.7,
        1.0,
      );
      final rotation = car.brakeLoad > 0
          ? 1.08
          : car.throttleLoad == 0
          ? 1.04
          : 1.0;
      var targetVelocity =
          kSteerRate *
          car.steeringAngle *
          speedFactor *
          steeringAuthority *
          car.grip *
          rotation;
      // Lane changes need forward movement, especially while pulling away.
      // The player keeps more steering authority than traffic. Corners retain
      // the steering needed to follow their curvature.
      if (section.isStraight) {
        final laneChangeSpeed = min(
          car.isPlayer ? 4.0 : 2.5,
          car.speed * (car.isPlayer ? .04 : .028),
        );
        targetVelocity = targetVelocity.clamp(
          -laneChangeSpeed,
          laneChangeSpeed,
        );
      }
      car.lateralVelocity +=
          (targetVelocity - car.lateralVelocity) *
          (1 - exp(-dt * (car.onGrass ? 5 : 10)));
      car.lateral += car.lateralVelocity * dt;

      // Curvature drift: the car holds a straight heading unless steered, so as
      // the road bends its centerline slides out from under it. Without steering
      // the car runs to the OUTSIDE of the corner (matching the drawn bend);
      // the player must steer INTO the bend to follow the road. Straights don't
      // bend, so they add no drift — the car only moves on the player's input.
      final ahead = car.distance + car.speed * dt;
      final centerShift = field.geometry.sample(ahead).centerX - sample.centerX;
      car.lateral -= centerShift * kBendCompression;
      // Heading is relative to the road; the renderer adds its projected
      // tangent once. Following the bend must not double the body's rotation.
      final relativeVelocity =
          car.lateralVelocity - centerShift * kBendCompression / dt;
      car.heading +=
          (atan2(relativeVelocity, max(12, car.speed)) - car.heading) *
          (1 - exp(-dt * 9));
      car.yawRate = (car.heading - previousHeading) / dt;
    } else {
      car.lateralVelocity *= exp(-dt * 8);
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
      car.lateralVelocity = 0;
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
      if (car.isPlayer) {
        events.playerWallContact = true;
        field.playerCleanRace = false;
        field.playerCornerContact = true;
        field.playerLastContactMs = field.raceClockMs;
      }
    }

    // Distance integration.
    car.distance += car.speed * dt;
  }

  // -- CPU driver -----------------------------------------------------------

  RaceInputs _cpuInputs(RaceField field, CarState car, double dt) {
    if (car.recovering) return const RaceInputs();
    car.sectionIndex = field.geometry.sample(car.distance).sectionIndex;
    var brake = _shouldBrake(
      field,
      car,
      errorFactor: kMaxCornerError * (1 - car.strength) * car.cornerNoise,
    );

    final section = field.circuit.sections[car.sectionIndex];
    if (car.decisionSection != car.sectionIndex) {
      car.decisionSection = car.sectionIndex;
      car.passTarget = 0;
      if (section.isStraight) {
        car.cruiseLateral = car.lateral.clamp(-2.7, 2.7);
      }
    }
    // Hold the grid/exit lane on straights. Do not herd the entire field back
    // into the middle after each pass or repeatedly hunt a new lane.
    var target = section.isStraight
        ? car.cruiseLateral
        : _racingLineLateral(field, car);
    car.decisionTimer -= dt;
    if (section.isStraight && car.speed > 35 && car.strength > 0.5) {
      final attacker = _attackerBehind(field, car);
      if (attacker != null &&
          attacker.speed > car.speed + 3 &&
          car.distance - attacker.distance < 14 &&
          (attacker.lateral - car.lateral).abs() < 1.5 &&
          car.decisionTimer <= 0 &&
          _random.nextDouble() < car.strength * 0.65) {
        car.cruiseLateral = attacker.lateral.clamp(-2.7, 2.7);
        target = car.cruiseLateral;
        car.decisionTimer = 2;
      }
    }

    // Avoidance/passing: never plow into a slower car ahead — pull to the
    // free side (on straights this doubles as the overtake setup) and lift
    // when right on its gearbox.
    final blocker = _blockerAhead(field, car);
    if (blocker != null) {
      if (section.isStraight && car.speed > 8) {
        if (car.decisionTimer <= 0 &&
            (car.passTarget == 0 ||
                (car.lateral - car.passTarget).abs() < .35)) {
          var bestClearance = -1.0;
          for (final side in const [-1.0, 1.0]) {
            final lane = (blocker.lateral + side * kCarWidth * 1.35).clamp(
              -kTrackHalfWidth * 0.85,
              kTrackHalfWidth * 0.85,
            );
            var clearance = 10.0;
            for (final other in field.cars) {
              if (identical(other, car) ||
                  (other.distance - car.distance).abs() > 22) {
                continue;
              }
              clearance = min(clearance, (other.lateral - lane).abs());
            }
            if (clearance > bestClearance) {
              bestClearance = clearance;
              car.passTarget = lane;
            }
          }
          car.decisionTimer = car.personality == CpuRacecraft.aggressive
              ? 1.25
              : 1.8;
          car.cruiseLateral = car.passTarget;
        }
        target = car.cruiseLateral;
      }
      final closing = max(0.0, car.speed - blocker.speed);
      final followingDistance =
          max(12.1, kCarLength * 2.2) +
          closing * .3 +
          closing * closing / (2 * kBrake);
      if (blocker.distance - car.distance < followingDistance) brake = true;
    } else if (car.decisionTimer <= 0) {
      car.passTarget = 0;
    }

    if (section.isStraight) {
      final upcoming = field.geometry.cornerAhead(
        car.distance,
        field.raceLength,
      );
      if (upcoming != null && upcoming.distance < 70) {
        final entry = 1 - upcoming.distance / 70;
        target += (_racingLineLateral(field, car) - target) * entry;
      }
    }

    final delta = target - car.lateral;
    final curvature =
        field.geometry.sample(car.distance).slope *
        kBendCompression *
        car.speed;
    final feedForward = curvature / (kSteerRate * max(0.55, car.grip));
    final steer = ((delta.abs() < 0.15 ? 0.0 : delta / 1.8) + feedForward)
        .clamp(-1.0, 1.0);
    final deploy =
        section.isStraight &&
        !brake &&
        car.energy > 0.25 &&
        (blocker != null ||
            _attackerBehind(field, car) != null ||
            car.personality == CpuRacecraft.aggressive);
    return RaceInputs(
      steer: steer,
      throttle: !brake,
      brake: brake,
      deploy: deploy,
    );
  }

  /// The nearest slower car within closing-speed braking range. A stopped
  /// car needs much earlier braking than traffic travelling at a similar pace.
  CarState? _blockerAhead(RaceField field, CarState car) {
    CarState? nearest;
    var nearestGap = double.infinity;
    for (final other in field.cars) {
      if (identical(other, car) || other.finished) continue;
      final gap = other.distance - car.distance;
      final closing = max(0.0, car.speed - other.speed);
      final lookahead = max(
        kCarLength * 3,
        max(12.1, kCarLength * 2.2) +
            closing * .5 +
            closing * closing / (2 * kBrake),
      );
      if (gap <= 0 || gap > lookahead) continue;
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
  bool _shouldBrake(
    RaceField field,
    CarState car, {
    required double errorFactor,
  }) {
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
    for (
      var step = currentSafe != null ? 1 : 0;
      step < sections.length;
      step++
    ) {
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
    return field.geometry.racingLine(car.distance, kTrackHalfWidth);
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
      // A third car in another lane must not hide an overlapping pair.
      for (var j = i + 1; j < ordered.length; j++) {
        final front = ordered[j];
        if (front.distance - rear.distance > kCarLength) break;
        if (rear.finished ||
            front.finished ||
            rear.recovering ||
            front.recovering ||
            rear.ghostTimer > 0 ||
            front.ghostTimer > 0) {
          continue;
        }
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
        final push =
            (rear.lateral <= front.lateral ? -1 : 1) * kContactPushRate * dt;
        rear.lateral = (rear.lateral + push).clamp(-kWallLateral, kWallLateral);
        front.lateral = (front.lateral - push).clamp(
          -kWallLateral,
          kWallLateral,
        );

        if (closing > kHeavyContactClosingSpeed && !rear.spinning) {
          rear.mode = CarMode.spinning;
          // A car-contact spin is lighter than a wall smash: a shorter spin (vs
          // the full kSpinSeconds a mid-corner wall hit keeps) and much less speed
          // lost, so a heavy rear-end is a setback, not a race-ender.
          rear.spinTimer = kSpinSeconds * 0.7;
          rear.speed = min(rear.speed, front.speed * 0.78);
        }
        if (playerInvolved) {
          events.playerContact = true;
          field.playerCleanRace = false;
          field.playerCornerContact = true;
          field.playerLastContactMs = field.raceClockMs;
          field.pendingCleanPasses.clear();
        }
      }
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
