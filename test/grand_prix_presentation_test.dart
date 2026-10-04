import 'dart:math';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/grand_prix/grand_prix_cubit.dart';
import 'package:card_game/blocs/grand_prix/grand_prix_state.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/data/grand_prix_circuits.dart';
import 'package:card_game/games/grand_prix/grand_prix_engine.dart';
import 'package:card_game/games/grand_prix/grand_prix_game.dart';
import 'package:card_game/models/grand_prix.dart';
import 'package:card_game/screens/grand_prix/widgets/grand_prix_driving_hud.dart';
import 'package:card_game/screens/grand_prix/widgets/grand_prix_race_feedback.dart';
import 'package:card_game/screens/grand_prix/widgets/grand_prix_result.dart';
import 'package:card_game/screens/grand_prix/grand_prix_race_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAudio implements AudioPlaybackBackend {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _RaceFixtureStorage extends SecureGameStorage {
  @override
  Future<GrandPrixStats> loadGrandPrixStats() async =>
      const GrandPrixStats(coachSeen: true, hapticsEnabled: false);
  @override
  Future<void> saveGrandPrixStats(GrandPrixStats stats) async {}
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    AudioController.debugUseBackend(_SilentAudio());
    AudioController.instance.muted.value = true;
  });

  testWidgets(
    'keyboard launches through Flame, keeps throttle held and pauses without relaunching',
    (tester) async {
      // Queued race audio must be created in this widget test's fake clock.
      await AudioController.instance.disposeAll();
      AudioController.debugUseBackend(_SilentAudio());
      AudioController.instance.muted.value = true;
      final storage = _RaceFixtureStorage();
      final cubit = GrandPrixCubit(storage);
      await cubit.load();
      cubit.buildRace(6);
      final bloc = GameBloc(storage);
      addTearDown(cubit.close);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: bloc),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: GrandPrixRaceScreen(onExit: () {}, onRaceAgain: () {}),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final game = tester
          .widget<GrandPrixDrivingHud>(find.byType(GrandPrixDrivingHud))
          .game;
      expect(game.isLoaded, isTrue);
      cubit.beginLights(reducedMotion: false);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 16));
      expect(cubit.state.phase, GrandPrixPhase.racing);
      expect(cubit.state.launchGrade, LaunchGrade.jump);
      expect(game.field.player.throttleLoad, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(cubit.state.phase, GrandPrixPhase.paused);
      final atPause = game.field.player.distance;
      game.update(.1);
      expect(game.field.player.distance, atPause);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      cubit.resumeRace(reducedMotion: true);
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.field.player.throttleLoad, 0);
      expect(game.field.player.throttleCutTimer, lessThan(2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(cubit.state.stats.races, 0);
      await AudioController.instance.disposeAll();
    },
  );

  testWidgets('driving HUD and coach fit a 320px screen with enlarged text', (
    tester,
  ) async {
    addTearDown(AudioController.instance.disposeAll);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = GrandPrixCubit(SecureGameStorage(), random: Random(7));
    await cubit.load();
    cubit.buildRace(6);
    final game = GrandPrixGame(
      setup: cubit.state.setup!,
      onPositionChanged: (_) {},
      onOvertake: (_) {},
      onPlayerFinished: (_) {},
      onAudioEvent: (_) {},
    );
    game.speedKph.value = 317;
    game.telemetry.value = const GrandPrixTelemetry(
      energy: .65,
      gear: 7,
      tow: .8,
      grip: .6,
      corner: GrandPrixCornerPreview(
        distance: 45,
        safeSpeed: 27,
        direction: CornerDirection.left,
        chicane: false,
      ),
      braking: true,
      rivalName: 'Mika Montgomery',
    );
    Widget host(Widget child) => BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpWidget(
      host(GrandPrixDrivingHud(game: game, onPause: () {})),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('BRAKE NOW'), findsNothing);
    expect(find.text('TURN AHEAD'), findsNothing);
    expect(find.textContaining('45m'), findsNothing);
    expect(find.byIcon(Icons.turn_left), findsNothing);
    expect(find.text('MIKA MONTGOMERY'), findsOneWidget);
    await tester.pumpWidget(host(GrandPrixGridCoach(onReady: () {})));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await cubit.close();
  });

  testWidgets(
    'pause countdown is cancelled on removal; reduced motion resumes immediately',
    (tester) async {
      addTearDown(AudioController.instance.disposeAll);
      final cubit = GrandPrixCubit(SecureGameStorage());
      await cubit.load();
      var resumes = 0;
      Widget host(bool reduced) => BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Scaffold(
            body: GrandPrixPauseLayer(onExit: () {}, onResume: () => resumes++),
          ),
        ),
      );
      await tester.pumpWidget(host(false));
      await tester.tap(find.text('RESUME RACE'));
      await tester.pump(const Duration(milliseconds: 1100));
      expect(resumes, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
      expect(resumes, 0);
      await tester.pumpWidget(host(true));
      await tester.tap(find.text('RESUME RACE'));
      await tester.pump();
      expect(resumes, 1);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
    },
  );

  testWidgets(
    'enlarged result reveals mastery and splits without settling extra rewards',
    (tester) async {
      addTearDown(AudioController.instance.disposeAll);
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bloc = GameBloc(SecureGameStorage());
      addTearDown(bloc.close);
      final before = bloc.state.progression;
      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: const TextScaler.linear(1.4),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Stack(
                children: [
                  GrandPrixResultOverlay(
                    result: GrandPrixResult(
                      position: 3,
                      fieldSize: 20,
                      startPosition: 10,
                      lapTimeMs: 189000,
                      personalBest: true,
                      launchGrade: LaunchGrade.perfect,
                      circuit: grandPrixCircuit(
                        GrandPrixCircuitId.emeraldPark,
                      ).id,
                      xp: 39,
                      laps: 3,
                      lapTimesMs: const [64000, 63000, 62000],
                      cleanOvertakes: 4,
                      cleanRace: true,
                      newMastery: GrandPrixMastery.values,
                      bestOvertakeName: 'Mika Montgomery',
                    ),
                    circuitName: 'EMERALD PARK',
                    onExit: () {},
                    onRaceAgain: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('CIRCUIT MASTERY EARNED'), findsOneWidget);
      expect(find.text('BEST SPLIT'), findsOneWidget);
      expect(bloc.state.progression, same(before));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
