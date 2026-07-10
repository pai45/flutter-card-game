import 'dart:math';

import 'package:card_game/data/grand_prix_circuits.dart';
import 'package:card_game/data/grand_prix_drivers.dart';
import 'package:card_game/games/grand_prix/grand_prix_engine.dart';
import 'package:card_game/models/grand_prix.dart';
import 'package:flutter_test/flutter_test.dart';

const _dt = 1 / 120;

RaceSetup _setup({
  GrandPrixCircuitId circuit = GrandPrixCircuitId.emeraldPark,
  int playerLevel = 6,
  int startPosition = 10,
  int seed = 7,
  int laps = 1,
}) => RaceSetup(
  circuit: grandPrixCircuit(circuit),
  playerLivery: GrandPrixLivery.scarlet,
  playerLevel: playerLevel,
  startPosition: startPosition,
  seed: seed,
  laps: laps,
);

/// A one-car field on a bare test circuit for isolated physics assertions.
RaceField _soloField(List<TrackSection> sections, {int laps = 1}) {
  final circuit = GrandPrixCircuit(
    id: GrandPrixCircuitId.emeraldPark,
    name: 'TEST',
    character: 'TEST',
    flavor: '',
    difficultyStars: 1,
    sections: sections,
  );
  final car = CarState(
    index: 0,
    isPlayer: true,
    name: 'YOU',
    livery: GrandPrixLivery.scarlet,
    distance: 0,
    lateral: 0,
  );
  return RaceField(
    circuit: circuit,
    cars: [car],
    laps: laps,
  );
}

void _run(
  GrandPrixEngine engine,
  RaceField field,
  RaceInputs inputs,
  double seconds,
) {
  for (var t = 0.0; t < seconds; t += _dt) {
    engine.tick(field, inputs, _dt);
  }
}

RaceInputs _manualInputs(RaceField field) {
  final car = field.player;
  final section = field.circuit.sections[car.sectionIndex];
  var target = 0.0;
  switch (section.type) {
    case TrackSectionType.straight:
      target = 0;
    case TrackSectionType.corner:
      final insideSign = section.direction == CornerDirection.left ? -1 : 1;
      target = insideSign * kTrackHalfWidth * 0.55;
    case TrackSectionType.chicane:
      final start = field.sectionStarts[car.sectionIndex];
      final local = lapLocalDistance(field.circuit.lapLength, car.distance);
      final t = (local - start) / section.length;
      final entrySign = section.direction == CornerDirection.left ? -1 : 1;
      target = (t < 0.5 ? entrySign : -entrySign) * kTrackHalfWidth * 0.45;
  }

  final delta = target - car.lateral;
  final steer = delta.abs() < 0.25 ? 0.0 : delta.sign * min(1.0, delta.abs() / 2);
  final safe = section.safeSpeed;
  final brake = safe != null && car.speed > safe;
  return RaceInputs(steer: steer, throttle: !brake, brake: brake);
}

void main() {
  group('speed integration', () {
    test('throttle ramps toward top speed and never exceeds it', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      final car = field.player;
      _run(engine, field, const RaceInputs(throttle: true), 2);
      final early = car.speed;
      expect(early, greaterThan(20));
      _run(engine, field, const RaceInputs(throttle: true), 30);
      expect(car.speed, greaterThan(early));
      expect(car.speed, lessThanOrEqualTo(kTopSpeed + 0.001));
      expect(car.speed, greaterThan(kTopSpeed * 0.95));
    });

    test('braking sheds speed faster than coasting', () {
      final engine = GrandPrixEngine(random: Random(1));

      final coasting = _soloField(const [TrackSection.straight(5000)]);
      coasting.player.speed = 60;
      _run(engine, coasting, const RaceInputs(), 1);

      final braking = _soloField(const [TrackSection.straight(5000)]);
      braking.player.speed = 60;
      _run(engine, braking, const RaceInputs(brake: true), 1);

      expect(coasting.player.speed, lessThan(60));
      expect(braking.player.speed, lessThan(coasting.player.speed));
      expect(braking.player.speed, greaterThanOrEqualTo(0));
    });
  });

  group('cornering', () {
    const corner = TrackSection.corner(
      length: 100,
      direction: CornerDirection.left,
      safeSpeed: 40,
      wallThreshold: 14,
      bend: 24,
    );

    test('a straight adds no drift — the car only moves when steered', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(2000)]);
      final car = field.player..speed = 60;
      _run(engine, field, const RaceInputs(throttle: true), 1.0);
      expect(car.lateral.abs(), lessThan(0.001));
      expect(car.spinning, isFalse);
    });

    test('a corner runs the car wide unless the player steers into it', () {
      final engine = GrandPrixEngine(random: Random(1));

      RaceField drive(RaceInputs inputs) {
        final field = _soloField(const [TrackSection.straight(50), corner]);
        field.player
          ..speed = 45
          ..distance = 49;
        _run(engine, field, inputs, 1.2);
        return field;
      }

      // No steer: the car keeps a straight heading and drifts to the OUTSIDE of
      // the (left) corner — positive lateral.
      final drifting = drive(const RaceInputs(throttle: true));
      expect(drifting.player.lateral, greaterThan(1.0));

      // Steering into the bend (left) follows the road — ends up on the inside,
      // nowhere near the outside drift.
      final steering = drive(const RaceInputs(throttle: true, steer: -0.5));
      expect(steering.player.lateral, lessThan(0));
      expect(steering.player.lateral, lessThan(drifting.player.lateral));
    });

    test('overspeed scrubs speed, and the hotter entry sheds more', () {
      final engine = GrandPrixEngine(random: Random(1));

      double scrubLoss(double speed) {
        final field = _soloField(const [TrackSection.straight(50), corner]);
        field.player
          ..speed = speed
          ..distance = 49;
        _run(engine, field, const RaceInputs(), 0.4);
        return speed - field.player.speed;
      }

      final mildLoss = scrubLoss(46); // +6 over
      final hotLoss = scrubLoss(52); // +12 over
      expect(hotLoss, greaterThan(kCoast * 0.4)); // more than coasting alone
      expect(hotLoss, greaterThan(mildLoss)); // worse when faster
    });

    test('a mid-corner wall hit is the only thing that hard-shakes the car', () {
      final engine = GrandPrixEngine(random: Random(1));
      // A long corner so there is room to slide out to the barrier. Outside of
      // a left corner is to the right (+lateral), so we steer hard right.
      const longCorner = TrackSection.corner(
        length: 600,
        direction: CornerDirection.left,
        safeSpeed: 40,
        wallThreshold: 14,
        bend: 24,
      );
      final field = _soloField(const [longCorner]);
      final car = field.player..speed = 60;
      const drivingIntoWall = RaceInputs(throttle: true, steer: 1);

      var sawWall = false;
      var spunWhileOnTrack = false;
      double? lateralAtSpin;
      for (var t = 0.0; t < 4 && lateralAtSpin == null; t += _dt) {
        // While still on the racing surface the car must never hard-shake.
        if (car.spinning && car.lateral.abs() < kTrackHalfWidth) {
          spunWhileOnTrack = true;
        }
        final events = engine.tick(field, drivingIntoWall, _dt);
        sawWall = sawWall || events.playerWallContact;
        if (car.spinning) lateralAtSpin = car.lateral.abs();
      }

      expect(car.spinning, isTrue, reason: 'slamming the wall spins the car');
      expect(sawWall, isTrue);
      expect(spunWhileOnTrack, isFalse);
      // The spin only fires at the wall — well past the red/white kerb line.
      expect(lateralAtSpin, isNotNull);
      expect(lateralAtSpin!, greaterThanOrEqualTo(kWallLateral - 0.001));
    });

    test('scraping the wall down a straight scrubs speed but never spins', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(3000)]);
      final car = field.player..speed = 70;
      const drivingIntoWall = RaceInputs(throttle: true, steer: 1);

      var sawWall = false;
      for (var t = 0.0; t < 2; t += _dt) {
        final events = engine.tick(field, drivingIntoWall, _dt);
        sawWall = sawWall || events.playerWallContact;
        expect(car.spinning, isFalse); // straights never hard-shake
      }
      expect(sawWall, isTrue);
      expect(car.lateral.abs(), closeTo(kWallLateral, 0.001));
    });
  });

  group('stuck watchdog', () {
    test('staying stopped past the timeout ends the race (DNF)', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      field.player.speed = 0; // parked, and the player does nothing

      var stuckOut = false;
      for (var t = 0.0; t < kStuckTimeout + 1 && !stuckOut; t += _dt) {
        stuckOut = stuckOut || engine.tick(field, const RaceInputs(), _dt).playerStuckOut;
      }
      expect(stuckOut, isTrue);
      expect(field.playerStuckSeconds, greaterThanOrEqualTo(kStuckTimeout));
    });

    test('getting moving again resets the stuck clock', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(20000)]);
      field.player.speed = 0;

      // Stall a while — but under the timeout, so no DNF yet.
      _run(engine, field, const RaceInputs(), 5);
      expect(field.playerStuckSeconds, greaterThan(4));

      // Get back up to racing speed — the clock resets to zero.
      _run(engine, field, const RaceInputs(throttle: true), 3);
      expect(field.player.speed, greaterThan(kStuckSpeed));
      expect(field.playerStuckSeconds, 0);
    });

    test('normal racing speed never trips the watchdog', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(30000)]);
      field.player.speed = kTopSpeed;

      var stuckOut = false;
      for (var t = 0.0; t < kStuckTimeout + 2; t += _dt) {
        stuckOut = stuckOut || engine.tick(field, const RaceInputs(throttle: true), _dt).playerStuckOut;
      }
      expect(stuckOut, isFalse);
      expect(field.playerStuckSeconds, 0);
    });
  });

  group('slipstream', () {
    test('grants a tow on straights when aligned and in range', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(8000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'CPU',
          livery: GrandPrixLivery.papaya,
          distance: 15,
          lateral: 0,
        )..speed = kTopSpeed,
      );
      field.player.speed = kTopSpeed;
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.slipstreaming, isTrue);

      // Pull out of line — tow lost.
      field.player.lateral = 3;
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.slipstreaming, isFalse);

      // Too far back — tow lost.
      field.player.lateral = 0;
      field.cars[1].distance = field.player.distance + kSlipstreamMax + 10;
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.slipstreaming, isFalse);
    });

    test('tow lifts speed above solo top speed', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(20000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'CPU',
          livery: GrandPrixLivery.papaya,
          distance: 12,
          lateral: 0,
        )..speed = kTopSpeed,
      );
      field.player.speed = kTopSpeed;
      // Keep the leader pinned ahead so the tow persists.
      for (var t = 0.0; t < 3; t += _dt) {
        field.cars[1]
          ..distance = field.player.distance + 12
          ..speed = field.player.speed;
        engine.tick(field, const RaceInputs(throttle: true), _dt);
      }
      expect(field.player.speed, greaterThan(kTopSpeed + 1));
      expect(
        field.player.speed,
        lessThanOrEqualTo(kTopSpeed * (1 + kSlipstreamBoost) + 0.001),
      );
    });
  });

  group('contact', () {
    test('rear-ending slows both cars', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'CPU',
          livery: GrandPrixLivery.papaya,
          distance: 4,
          lateral: 0,
        )..speed = 50,
      );
      field.player.speed = 58;
      final events = engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(events.playerContact, isTrue);
      expect(field.player.speed, lessThan(58));
      expect(field.cars[1].speed, lessThan(50));
    });

    test('heavy closing speed spins the rear car', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'CPU',
          livery: GrandPrixLivery.papaya,
          distance: 4,
          lateral: 0,
        )..speed = 30,
      );
      field.player.speed = 30 + kHeavyContactClosingSpeed + 10;
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.spinning, isTrue);
    });
  });

  group('positions and overtakes', () {
    test('position counts cars ahead; finishers always rank first', () {
      final field = _soloField(const [TrackSection.straight(1000)]);
      final player = field.player..distance = 500;
      field.cars.addAll([
        CarState(
          index: 1,
          isPlayer: false,
          name: 'AHEAD',
          livery: GrandPrixLivery.papaya,
          distance: 700,
          lateral: 0,
        ),
        CarState(
          index: 2,
          isPlayer: false,
          name: 'BEHIND',
          livery: GrandPrixLivery.midnight,
          distance: 300,
          lateral: 0,
        ),
        CarState(
          index: 3,
          isPlayer: false,
          name: 'DONE',
          livery: GrandPrixLivery.skyBlue,
          distance: 1001,
          lateral: 0,
        )
          ..mode = CarMode.finished
          ..finishTimeMs = 60000,
      ]);
      expect(positionOf(field, player), 3); // behind AHEAD and DONE
      player.distance = 900;
      expect(positionOf(field, player), 2); // passed AHEAD, DONE still counts
    });

    test('passing a car emits an overtake event with its name', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'TARGET',
          livery: GrandPrixLivery.papaya,
          distance: 3,
          lateral: 3.5, // offline so there is no contact
        )..speed = 10,
      );
      field.player.speed = 60;
      final seen = <String>[];
      for (var t = 0.0; t < 1; t += _dt) {
        final events = engine.tick(field, const RaceInputs(throttle: true), _dt);
        seen.addAll(events.overtakes.map((o) => o.overtakenName));
      }
      expect(seen, contains('TARGET'));
    });
  });

  group('launch grading', () {
    test('grades map to the spec reaction bands', () {
      expect(gradeLaunch(const Duration(milliseconds: 149)), LaunchGrade.perfect);
      expect(gradeLaunch(const Duration(milliseconds: 150)), LaunchGrade.great);
      expect(gradeLaunch(const Duration(milliseconds: 299)), LaunchGrade.great);
      expect(gradeLaunch(const Duration(milliseconds: 300)), LaunchGrade.good);
      expect(gradeLaunch(const Duration(milliseconds: 499)), LaunchGrade.good);
      expect(gradeLaunch(const Duration(milliseconds: 500)), LaunchGrade.slow);
    });

    test('better launches give strictly better boosts; jump start cuts throttle', () {
      final perfect = launchBoost(LaunchGrade.perfect);
      final great = launchBoost(LaunchGrade.great);
      final good = launchBoost(LaunchGrade.good);
      final slow = launchBoost(LaunchGrade.slow);
      expect(perfect.initialSpeed, greaterThan(great.initialSpeed));
      expect(great.initialSpeed, greaterThan(good.initialSpeed));
      expect(good.initialSpeed, greaterThan(slow.initialSpeed));
      expect(launchBoost(LaunchGrade.jump).initialSpeed, 0);

      final setup = _setup();
      final rng = Random(setup.seed);
      final field = buildField(setup, generateDriverNames(19, rng), rng);
      applyLaunch(field, LaunchGrade.jump, rng);
      expect(field.player.throttleCutTimer, kJumpStartCutSeconds);

      // Throttle does nothing while the jump-start cut is active.
      final engine = GrandPrixEngine(random: rng);
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.speed, 0);
    });

    test('cpu reactions improve with strength and never jump', () {
      final rng = Random(3);
      for (var i = 0; i < 200; i++) {
        final weak = sampleCpuReaction(0.1, rng);
        expect(weak.inMilliseconds, greaterThan(0));
      }
      final strongAvg =
          List.generate(300, (_) => sampleCpuReaction(1.0, rng).inMilliseconds)
                  .reduce((a, b) => a + b) /
              300;
      final weakAvg =
          List.generate(300, (_) => sampleCpuReaction(0.0, rng).inMilliseconds)
                  .reduce((a, b) => a + b) /
              300;
      expect(strongAvg, lessThan(weakAvg));
    });
  });

  group('field generation', () {
    test('20 cars, unique names, player at the chosen slot', () {
      final setup = _setup(startPosition: 12);
      final rng = Random(setup.seed);
      final field = buildField(setup, generateDriverNames(19, rng), rng);
      expect(field.cars.length, kFieldSize);
      expect(field.cars.where((c) => c.isPlayer).length, 1);
      expect(positionOf(field, field.player), 12);
      final names = field.cars.map((c) => c.name).toSet();
      expect(names.length, kFieldSize);
      // No CPU wears the player's livery.
      expect(
        field.cars
            .where((c) => !c.isPlayer && c.livery == GrandPrixLivery.scarlet),
        isEmpty,
      );
    });

    test('stronger fields finish faster (CPU pace scales with level)', () {
      double cpuAverageFinish(int level) {
        final setup = _setup(playerLevel: level, seed: 11);
        final rng = Random(setup.seed);
        final field = buildField(setup, generateDriverNames(19, rng), rng);
        applyLaunch(field, LaunchGrade.slow, rng);
        final engine = GrandPrixEngine(random: Random(5));
        // Player never throttles — only the CPU field races.
        const raceDt = 1 / 60;
        for (var t = 0.0; t < 240; t += raceDt) {
          engine.tick(field, const RaceInputs(), raceDt);
          if (field.cars.where((c) => !c.isPlayer).every((c) => c.finished)) {
            break;
          }
        }
        final cpus = field.cars.where((c) => !c.isPlayer).toList();
        expect(cpus.every((c) => c.finished), isTrue);
        return cpus.map((c) => c.finishTimeMs).reduce((a, b) => a + b) /
            cpus.length;
      }

      expect(cpuAverageFinish(12), lessThan(cpuAverageFinish(1)));
    });
  });

  group('multi-lap races', () {
    test('raceCenterlineX is continuous across the start/finish line', () {
      final circuit = grandPrixCircuit(GrandPrixCircuitId.emeraldPark);
      final starts = RaceField(circuit: circuit, cars: []).sectionStarts;
      final lapLength = circuit.lapLength;

      final before = raceCenterlineX(circuit, starts, lapLength - 0.01);
      final at = raceCenterlineX(circuit, starts, lapLength);
      final after = raceCenterlineX(circuit, starts, lapLength + 0.01);
      expect((at - before).abs(), lessThan(0.01));
      expect((after - at).abs(), lessThan(0.01));

      // Lap 2 repeats lap 1's shape, offset by the full-lap shift.
      final fullLapShift = centerlineX(circuit, starts, lapLength);
      expect(
        raceCenterlineX(circuit, starts, lapLength + 500),
        closeTo(fullLapShift + centerlineX(circuit, starts, 500), 1e-9),
      );
    });

    test('the finish only comes after every lap is run', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(1000)], laps: 3);
      final car = field.player..speed = kTopSpeed;

      var crossed = false;
      for (var t = 0.0; t < 60 && !crossed; t += _dt) {
        crossed = engine
            .tick(field, const RaceInputs(throttle: true), _dt)
            .playerCrossedLine;
        if (car.distance > 1000 && car.distance < 2900) {
          expect(car.finished, isFalse,
              reason: 'crossing an intermediate lap line must not finish');
        }
      }
      expect(crossed, isTrue);
      expect(car.distance, greaterThanOrEqualTo(field.raceLength));
    });

    test('a seeded 20-car 3-lap race completes with no NaNs', () {
      final setup = _setup(seed: 9, laps: 3);
      final rng = Random(setup.seed);
      final field = buildField(setup, generateDriverNames(19, rng), rng);
      applyLaunch(field, LaunchGrade.good, rng);
      final engine = GrandPrixEngine(random: Random(setup.seed));
      const raceDt = 1 / 60;
      for (var t = 0.0; t < 900; t += raceDt) {
        engine.tick(field, _manualInputs(field), raceDt);
        for (final car in field.cars) {
          if (car.speed.isNaN || car.distance.isNaN || car.lateral.isNaN) {
            fail('NaN state for ${car.name} at t=$t');
          }
          if (car.lateral.abs() > kWallLateral + 0.001) {
            fail('${car.name} escaped the wall at t=$t');
          }
        }
        if (field.cars.every((c) => c.finished)) break;
      }
      // Every car finishing proves the CPU brake lookahead wraps the lap
      // line — a hot turn-1 entry on laps 2/3 would strand cars on the grass.
      expect(field.cars.every((c) => c.finished), isTrue);
      for (final car in field.cars) {
        expect(car.distance, greaterThanOrEqualTo(field.raceLength));
      }
    });
  });

  group('full-race soak', () {
    test('a seeded 20-car race completes deterministically with no NaNs', () {
      List<String> classification(int seed) {
        final setup = _setup(seed: seed, circuit: GrandPrixCircuitId.emeraldPark);
        final rng = Random(setup.seed);
        final field = buildField(setup, generateDriverNames(19, rng), rng);
        applyLaunch(field, LaunchGrade.good, rng);
        final engine = GrandPrixEngine(random: Random(setup.seed));
        // Lightweight manual driver for the soak: follows the racing line and
        // brakes when already above the current section's safe speed.
        const raceDt = 1 / 60;
        for (var t = 0.0; t < 300; t += raceDt) {
          engine.tick(field, _manualInputs(field), raceDt);
          for (final car in field.cars) {
            // Plain checks (not expect) — this loop runs tens of thousands
            // of times; fail loudly only when an invariant actually breaks.
            if (car.speed.isNaN || car.distance.isNaN || car.lateral.isNaN) {
              fail('NaN state for ${car.name} at t=$t');
            }
            if (car.lateral.abs() > kWallLateral + 0.001) {
              fail('${car.name} escaped the wall at t=$t');
            }
          }
          if (field.cars.every((c) => c.finished)) break;
        }
        expect(field.cars.every((c) => c.finished), isTrue);
        final ordered = [...field.cars]
          ..sort((a, b) => a.finishTimeMs.compareTo(b.finishTimeMs));
        return ordered.map((c) => c.name).toList();
      }

      final first = classification(21);
      final second = classification(21);
      expect(first, second); // same seed → same result
      expect(first.toSet().length, kFieldSize);
    });
  });
}
