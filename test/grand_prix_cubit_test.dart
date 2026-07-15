import 'dart:math';

import 'package:card_game/blocs/grand_prix/grand_prix_cubit.dart';
import 'package:card_game/blocs/grand_prix/grand_prix_state.dart';
import 'package:card_game/games/grand_prix/grand_prix_engine.dart';
import 'package:card_game/models/grand_prix.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  GrandPrixCubit makeCubit({int seed = 7}) =>
      GrandPrixCubit(SecureGameStorage(), random: Random(seed));

  test('load surfaces stored stats and clears loading', () async {
    final cubit = makeCubit();
    expect(cubit.state.loading, isTrue);
    await cubit.load();
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.stats.races, 0);
    await cubit.close();
  });

  test('lobby selections persist onto stats', () async {
    final cubit = makeCubit();
    await cubit.load();
    cubit.selectCircuit(GrandPrixCircuitId.desertMile);
    cubit.selectLivery(GrandPrixLivery.midnight);
    expect(cubit.state.circuitId, GrandPrixCircuitId.desertMile);
    expect(cubit.state.livery, GrandPrixLivery.midnight);

    // Round-trips through storage.
    await Future<void>.delayed(Duration.zero);
    final revived = await SecureGameStorage().loadGrandPrixStats();
    expect(revived.lastCircuit, GrandPrixCircuitId.desertMile);
    expect(revived.lastLivery, GrandPrixLivery.midnight);
    await cubit.close();
  });

  test('buildRace seeds a grid with a P8–P16 start slot', () async {
    for (var seed = 0; seed < 30; seed++) {
      final cubit = makeCubit(seed: seed);
      await cubit.load();
      cubit.buildRace(6);
      final setup = cubit.state.setup!;
      expect(cubit.state.phase, GrandPrixPhase.grid);
      expect(setup.startPosition, inInclusiveRange(8, 16));
      expect(cubit.state.playerPosition, setup.startPosition);
      expect(setup.playerLevel, 6);
      await cubit.close();
    }
  });

  test('lights sequence: five lamps, random hold, tap after out grades launch',
      () {
    fakeAsync((async) {
      final cubit = makeCubit();
      cubit.load();
      async.flushMicrotasks();
      cubit.buildRace(4);
      cubit.beginLights(reducedMotion: false);
      expect(cubit.state.phase, GrandPrixPhase.lights);

      for (var lamp = 1; lamp <= 5; lamp++) {
        async.elapse(const Duration(milliseconds: 1000));
        expect(cubit.state.lightsOn, lamp);
        expect(cubit.state.lightsOut, isFalse);
      }
      // Hold is 200–1500ms; after 1500ms the lights must be out.
      async.elapse(const Duration(milliseconds: 1500));
      expect(cubit.state.lightsOut, isTrue);
      expect(cubit.state.lightsOn, 0);
      expect(cubit.state.phase, GrandPrixPhase.lights);

      // Tap: inside fakeAsync no wall-clock time passes → perfect reaction.
      cubit.registerThrottleTap();
      expect(cubit.state.phase, GrandPrixPhase.racing);
      expect(cubit.state.launchGrade, LaunchGrade.perfect);
      cubit.close();
    });
  });

  test('throttle before lights-out is a jump start', () {
    fakeAsync((async) {
      final cubit = makeCubit();
      cubit.load();
      async.flushMicrotasks();
      cubit.buildRace(4);
      cubit.beginLights(reducedMotion: false);
      async.elapse(const Duration(milliseconds: 3200)); // 3 lamps lit
      expect(cubit.state.lightsOut, isFalse);
      cubit.registerThrottleTap();
      expect(cubit.state.phase, GrandPrixPhase.racing);
      expect(cubit.state.launchGrade, LaunchGrade.jump);
      expect(cubit.state.jumpStart, isTrue);
      // The rest of the lamp chain must be dead.
      async.elapse(const Duration(seconds: 10));
      expect(cubit.state.launchGrade, LaunchGrade.jump);
      cubit.close();
    });
  });

  test('no tap at all times out into a Slow launch', () {
    fakeAsync((async) {
      final cubit = makeCubit();
      cubit.load();
      async.flushMicrotasks();
      cubit.buildRace(4);
      cubit.beginLights(reducedMotion: false);
      // 5s of lamps + max 1.5s hold + 2s launch timeout.
      async.elapse(const Duration(milliseconds: 8500));
      expect(cubit.state.phase, GrandPrixPhase.racing);
      expect(cubit.state.launchGrade, LaunchGrade.slow);
      cubit.close();
    });
  });

  test('reduced motion skips the reaction test with a fixed average launch',
      () async {
    final cubit = makeCubit();
    await cubit.load();
    cubit.buildRace(4);
    cubit.beginLights(reducedMotion: true);
    expect(cubit.state.phase, GrandPrixPhase.racing);
    expect(cubit.state.launchGrade, LaunchGrade.good);
    await cubit.close();
  });

  test('finish settles result, XP, PB, and persists stats', () async {
    final cubit = makeCubit();
    await cubit.load();
    cubit.selectCircuit(GrandPrixCircuitId.emeraldPark);
    cubit.buildRace(4);
    cubit.beginLights(reducedMotion: true);
    final start = cubit.state.setup!.startPosition;

    await cubit.onRaceFinished(
      const PlayerRaceOutcome(
        position: 3,
        lapTimeMs: 91500,
        bestOvertakeName: 'Mika Okada',
      ),
    );
    expect(cubit.state.phase, GrandPrixPhase.finished);
    final result = cubit.state.result!;
    expect(result.position, 3);
    expect(result.verdict, GrandPrixVerdict.podium);
    expect(result.placesGained, start - 3);
    expect(result.personalBest, isTrue); // first lap on the circuit
    expect(result.xp, 21); // 18 podium + 3 PB
    expect(result.bestOvertakeName, 'Mika Okada');

    expect(cubit.state.stats.races, 1);
    expect(cubit.state.stats.podiums, 1);
    expect(cubit.state.stats.bestPosition, 3);
    expect(
      cubit.state.stats.bestLapMs(GrandPrixCircuitId.emeraldPark),
      91500,
    );

    cubit.showResult();
    expect(cubit.state.phase, GrandPrixPhase.result);

    final revived = await SecureGameStorage().loadGrandPrixStats();
    expect(revived.races, 1);
    expect(revived.bestLapMs(GrandPrixCircuitId.emeraldPark), 91500);
    await cubit.close();
  });

  test('a slower repeat lap is not a PB and earns no bonus', () async {
    final cubit = makeCubit();
    await cubit.load();
    cubit.buildRace(4);
    cubit.beginLights(reducedMotion: true);
    await cubit.onRaceFinished(
      const PlayerRaceOutcome(position: 1, lapTimeMs: 90000),
    );
    cubit.buildRace(4);
    cubit.beginLights(reducedMotion: true);
    await cubit.onRaceFinished(
      const PlayerRaceOutcome(position: 1, lapTimeMs: 95000),
    );
    final result = cubit.state.result!;
    expect(result.personalBest, isFalse);
    expect(result.xp, 26); // win, no PB bonus
    expect(cubit.state.stats.currentStreak, 2);
    expect(cubit.state.stats.bestLapMs(cubit.state.circuitId), 90000);
    await cubit.close();
  });

  test('abandoning a race leaves stats untouched and grants nothing', () {
    fakeAsync((async) {
      final cubit = makeCubit();
      cubit.load();
      async.flushMicrotasks();
      cubit.buildRace(4);
      cubit.beginLights(reducedMotion: false);
      async.elapse(const Duration(milliseconds: 4000));
      cubit.abandonRace();
      expect(cubit.state.phase, GrandPrixPhase.idle);
      expect(cubit.state.setup, isNull);
      expect(cubit.state.result, isNull);
      expect(cubit.state.stats.races, 0);
      // No zombie timers fire afterwards.
      async.elapse(const Duration(seconds: 10));
      expect(cubit.state.phase, GrandPrixPhase.idle);
      cubit.close();
    });
  });

  test('game callbacks only land during racing', () async {
    final cubit = makeCubit();
    await cubit.load();
    cubit.buildRace(4);
    // Still on the grid — position pings are ignored.
    cubit.onPlayerPositionChanged(2);
    expect(cubit.state.playerPosition, cubit.state.setup!.startPosition);

    cubit.beginLights(reducedMotion: true);
    cubit.onPlayerPositionChanged(9);
    expect(cubit.state.playerPosition, 9);
    cubit.onOvertake(
      const OvertakeEvent(
        overtakenName: 'Theo Duval',
        overtakenPosition: 9,
        atDistance: 500,
      ),
    );
    expect(cubit.state.eventTick, 1);
    expect(cubit.state.lastOvertake!.overtakenName, 'Theo Duval');

    // After the finish the feed goes quiet.
    await cubit.onRaceFinished(
      const PlayerRaceOutcome(position: 9, lapTimeMs: 93000),
    );
    cubit.onPlayerPositionChanged(12);
    expect(cubit.state.playerPosition, 9);
    await cubit.close();
  });
}
