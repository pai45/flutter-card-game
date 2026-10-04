import 'dart:math';

import 'package:card_game/data/grand_prix_circuits.dart';
import 'package:card_game/data/grand_prix_drivers.dart';
import 'package:card_game/games/grand_prix/grand_prix_engine.dart';
import 'package:card_game/games/grand_prix/grand_prix_simulation_clock.dart';
import 'package:card_game/models/grand_prix.dart';
import 'package:flutter_test/flutter_test.dart';

RaceField solo() => RaceField(
  circuit: const GrandPrixCircuit(
    id: GrandPrixCircuitId.emeraldPark,
    name: 'TEST',
    character: 'TEST',
    flavor: '',
    difficultyStars: 1,
    sections: [TrackSection.straight(10000)],
  ),
  cars: [
    CarState(
      index: 0,
      isPlayer: true,
      name: 'YOU',
      livery: GrandPrixLivery.gridLine,
      distance: 0,
      lateral: 0,
    ),
  ],
);

void run(
  GrandPrixEngine engine,
  RaceField field,
  RaceInputs inputs,
  int steps,
) {
  for (var i = 0; i < steps; i++) {
    engine.tick(field, inputs, 1 / 120);
  }
}

void main() {
  test(
    'smaller cars allow close racing without invisible old-size contact',
    () {
      for (final pose in [(6.0, 1.7), (4.8, 0.0)]) {
        final field = solo();
        field.player.speed = 45;
        field.cars.add(
          CarState(
            index: 1,
            isPlayer: false,
            name: 'RIVAL',
            livery: GrandPrixLivery.papaya,
            distance: pose.$1,
            lateral: pose.$2,
          )..speed = 45,
        );
        final event = GrandPrixEngine(
          random: Random(77),
        ).tick(field, const RaceInputs(throttle: true), 1 / 120);
        expect(event.playerContact, isFalse);
        expect(field.playerCleanRace, isTrue);
      }
      final field = solo();
      field.player.speed = 45;
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'RIVAL',
          livery: GrandPrixLivery.papaya,
          distance: 3.5,
          lateral: .8,
        )..speed = 45,
      );
      expect(
        GrandPrixEngine()
            .tick(field, const RaceInputs(throttle: true), 1 / 120)
            .playerContact,
        isTrue,
      );
    },
  );

  test('unobstructed rivals hold their lane throughout a straight', () {
    for (final lane in [-1.8, 1.8]) {
      final field = solo();
      field.player.distance = -2000;
      final rival = CarState(
        index: 1,
        isPlayer: false,
        name: 'RIVAL',
        livery: GrandPrixLivery.papaya,
        distance: 0,
        lateral: lane,
        strength: .8,
      );
      field.cars.add(rival);
      final engine = GrandPrixEngine(random: Random(77));
      for (var i = 0; i < 120 * 8; i++) {
        engine.tick(field, const RaceInputs(throttle: true), 1 / 120);
        expect(rival.lateral, closeTo(lane, .001));
        expect(rival.heading.abs(), lessThan(.001));
      }
      expect(rival.distance, greaterThan(200));
    }
  });

  test('low-speed steering travels forwards instead of darting sideways', () {
    for (final speed in [4.0, 12.0, 50.0]) {
      final field = solo();
      field.player.speed = speed;
      run(
        GrandPrixEngine(),
        field,
        const RaceInputs(throttle: true, steer: 1),
        120,
      );
      expect(field.player.lateral, greaterThan(0));
      final travelAngle = atan2(
        field.player.lateral * 5,
        field.player.distance,
      );
      expect(travelAngle, lessThan(pi / 15));
      expect(field.player.spinning, isFalse);
    }
  });

  test(
    'traffic launches forwards without diving into the centre or spinning',
    () {
      final base = solo();
      final setup = RaceSetup(
        circuit: base.circuit,
        playerLivery: GrandPrixLivery.gridLine,
        playerLevel: 6,
        startPosition: 14,
        seed: 77,
      );
      final previewRandom = Random(77)..nextInt(9);
      for (final seed in [7, 21, 77, 101, previewRandom.nextInt(1 << 31)]) {
        for (final grade in [LaunchGrade.good, LaunchGrade.jump]) {
          final random = Random(seed);
          final names = generateDriverNames(19, random);
          final field = buildField(setup, names, random);
          applyLaunch(field, grade, Random(seed ^ 0x1a));
          final engine = GrandPrixEngine(random: Random(seed ^ 0x51f15eed));
          for (var i = 0; i < 120 * 4; i++) {
            engine.tick(field, const RaceInputs(throttle: true), 1 / 120);
            for (final car in field.cars.where((car) => !car.isPlayer)) {
              expect(
                car.spinning,
                isFalse,
                reason: '$seed ${grade.name}: ${car.name}',
              );
              expect(car.heading.abs(), lessThan(.05));
              expect(car.onGrass, isFalse);
            }
          }
        }
      }
    },
  );

  test(
    'rivals still pass slower traffic and hold their new lane afterwards',
    () {
      final field = solo();
      field.player.distance = 500;
      final rival = CarState(
        index: 1,
        isPlayer: false,
        name: 'RIVAL',
        livery: GrandPrixLivery.papaya,
        distance: 486,
        lateral: 0,
        strength: .8,
      )..speed = 55;
      field.cars.add(rival);
      final engine = GrandPrixEngine(random: Random(77));
      for (var i = 0; i < 120 * 10; i++) {
        field.player.speed = 35;
        engine.tick(field, const RaceInputs(throttle: true), 1 / 120);
        expect(rival.heading.abs(), lessThan(.04));
      }
      expect(rival.distance - field.player.distance, greaterThan(30));
      expect(rival.lateral.abs(), greaterThan(2));
      final lane = rival.lateral;
      run(engine, field, const RaceInputs(throttleAmount: .2), 120 * 3);
      expect(rival.lateral, closeTo(lane, .1));
    },
  );

  test('wide phone projection keeps normal lane changes pointing forwards', () {
    for (final scale in [2.0, 5.0, 9.0]) {
      expect(
        projectedGrandPrixCarHeading(
          roadSlope: 0,
          relativeHeading: 0,
          lateralScale: scale,
          forwardScale: 1,
          straight: true,
        ),
        0,
      );
      for (final heading in [-.3, .3]) {
        final angle = projectedGrandPrixCarHeading(
          roadSlope: 0,
          relativeHeading: heading,
          lateralScale: scale,
          forwardScale: 1,
          straight: true,
        );
        expect(angle.sign, heading.sign);
        expect(angle.abs(), lessThanOrEqualTo(pi / 15));
      }
    }
    expect(
      projectedGrandPrixCarHeading(
        roadSlope: .5,
        relativeHeading: 0,
        lateralScale: 5,
        forwardScale: 1,
        straight: false,
      ),
      greaterThan(pi / 15),
    );
  });

  test(
    'render rates advance identical seeded physics; hitches are bounded',
    () {
      final poses = <double>[];
      for (final hz in [20, 30, 60, 120]) {
        final field = solo();
        final engine = GrandPrixEngine(random: Random(9));
        final clock = GrandPrixSimulationClock();
        var ticks = 0;
        for (var i = 0; i < hz * 5; i++) {
          clock.advance(1 / hz, (dt) {
            engine.tick(field, const RaceInputs(throttle: true), dt);
            ticks++;
            return true;
          });
        }
        expect(ticks, 600);
        poses.add(field.player.distance);
      }
      for (final pose in poses) {
        expect(pose, closeTo(poses.first, 1e-9));
      }
      final clock = GrandPrixSimulationClock();
      expect(clock.advance(5, (_) => true), 24);
      clock.advance(1 / 240, (_) => true);
      clock.reset();
      expect(clock.interpolation, 0);
    },
  );

  test(
    'steering builds momentum and unwinds; stationary cars cannot strafe',
    () {
      final field = solo();
      final engine = GrandPrixEngine();
      run(engine, field, const RaceInputs(steer: 1), 120);
      expect(field.player.lateral, 0);
      field.player.steeringAngle = 0;
      field.player.speed = 45;
      engine.tick(field, const RaceInputs(steer: .7, throttle: true), 1 / 120);
      expect(field.player.steeringAngle, inExclusiveRange(0, .7));
      expect(field.player.heading, greaterThan(0));
      run(engine, field, const RaceInputs(throttle: true), 80);
      expect(field.player.steeringAngle.abs(), lessThan(.002));
      expect(field.player.lateralVelocity.abs(), lessThan(.01));
    },
  );

  test(
    'ERS drains under load, braking restores it, standing still does not',
    () {
      final field = solo();
      final engine = GrandPrixEngine();
      field.player.speed = 60;
      run(engine, field, const RaceInputs(throttle: true, deploy: true), 240);
      expect(field.player.energy, lessThan(.6));
      expect(field.player.deploying, isTrue);
      final drained = field.player.energy;
      run(engine, field, const RaceInputs(brake: true), 30);
      expect(field.player.energy, greaterThan(drained));
      field.player.speed = 0;
      final parked = field.player.energy;
      run(engine, field, const RaceInputs(), 120);
      expect(field.player.energy, parked);
    },
  );

  test(
    'recovery costs three seconds, preserves distance and invalidates clean race',
    () {
      final field = solo();
      final engine = GrandPrixEngine();
      expect(engine.recoverPlayer(field), isFalse);
      field.player.distance = 200;
      field.player.lateral = 6;
      field.player.energy = .4;
      field.playerStuckSeconds = 3;
      expect(engine.recoverPlayer(field), isTrue);
      expect(engine.recoverPlayer(field), isFalse);
      run(engine, field, const RaceInputs(throttle: true, deploy: true), 359);
      expect(field.player.distance, 200);
      expect(field.player.energy, .4);
      expect(field.player.recovering, isTrue);
      run(engine, field, const RaceInputs(), 2);
      expect(field.player.recovering, isFalse);
      expect(field.player.lateral.abs(), lessThan(kTrackHalfWidth));
      expect(field.playerCleanRace, isFalse);
      expect(field.playerRecoveries, 1);
      expect(field.raceClockMs, closeTo(3008.333, .01));
    },
  );

  test('a car in another lane cannot hide an overlapping contact', () {
    final field = solo();
    field.player.speed = 50;
    for (final pose in [(1.0, 4.0), (2.0, 0.0)]) {
      field.cars.add(
        CarState(
          index: field.cars.length,
          isPlayer: false,
          name: 'RIVAL',
          livery: GrandPrixLivery.midnight,
          distance: pose.$1,
          lateral: pose.$2,
        )..speed = 50,
      );
    }
    final event = GrandPrixEngine().tick(
      field,
      const RaceInputs(throttle: true),
      1 / 120,
    );
    expect(event.playerContact, isTrue);
    expect(field.playerCleanRace, isFalse);
  });

  test(
    'all five circuits and race distances finish without unstable field state',
    () {
      for (final circuit in GrandPrixCircuitId.values) {
        for (final laps in [1, 3, 5]) {
          final setup = RaceSetup(
            circuit: grandPrixCircuit(circuit),
            playerLivery: GrandPrixLivery.gridLine,
            playerLevel: 6,
            startPosition: 10,
            seed: 77,
            laps: laps,
          );
          final field = buildField(setup, grandPrixDriverNames, Random(77));
          final engine = GrandPrixEngine(random: Random(77));
          applyLaunch(field, LaunchGrade.good, Random(78));
          for (
            var tick = 0;
            tick < 120 * 1200 && !field.player.finished;
            tick++
          ) {
            final car = field.player;
            final sample = field.geometry.sample(car.distance);
            final target = field.geometry.racingLine(
              car.distance,
              kTrackHalfWidth,
            );
            final steer =
                ((target - car.lateral) / 1.8 +
                        sample.slope *
                            kBendCompression *
                            car.speed /
                            (kSteerRate * max(.55, car.grip)))
                    .clamp(-1.0, 1.0);
            final corner = field.geometry.cornerAhead(
              car.distance,
              field.raceLength,
            );
            final brake =
                corner != null &&
                car.speed > corner.safeSpeed &&
                (car.speed * car.speed - corner.safeSpeed * corner.safeSpeed) /
                            (2 * kBrake) +
                        car.speed * .15 >=
                    corner.distance;
            engine.tick(
              field,
              RaceInputs(steer: steer, throttle: !brake, brake: brake),
              1 / 120,
            );
          }
          expect(
            field.player.finished,
            isTrue,
            reason: '${circuit.name} $laps laps',
          );
          expect(field.playerLapTimesMs.length, laps);
          expect(field.playerLapTimesMs.every((ms) => ms > 0), isTrue);
          expect(
            field.playerLapTimesMs.reduce((a, b) => a + b),
            closeTo(field.player.finishTimeMs, laps),
          );
          for (final car in field.cars) {
            expect(
              car.speed.isFinite &&
                  car.lateral.isFinite &&
                  car.heading.isFinite,
              isTrue,
            );
            expect(car.lateral.abs(), lessThanOrEqualTo(kWallLateral));
            expect(car.energy, inInclusiveRange(0, 1));
          }
        }
      }
    },
  );
}
