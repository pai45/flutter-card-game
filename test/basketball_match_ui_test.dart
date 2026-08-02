import 'package:card_game/blocs/basketball/basketball_cubit.dart';
import 'package:card_game/data/basketball_athletes.dart';
import 'package:card_game/games/basketball/basketball_engine.dart';
import 'package:card_game/games/basketball/basketball_game.dart';
import 'package:card_game/models/basketball.dart';
import 'package:card_game/screens/basketball/widgets/basketball_controls.dart';
import 'package:card_game/screens/basketball/widgets/basketball_hud.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

BasketballGame _game() {
  final roster = basketballAthletes.take(6).toList();
  return BasketballGame(
    config: BasketballMatchConfig(
      playerRoster: roster.take(3).toList(),
      playerStarterIndex: 0,
      cpuRoster: roster.skip(3).take(3).toList(),
      cpuStarterIndex: 0,
      difficulty: BasketballDifficulty.pro,
      seed: 17,
    ),
    onEvents: (_) {},
  );
}

Widget _app(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(child: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ACTION pad transitions through every contextual cue', (
    tester,
  ) async {
    final game = _game();
    await tester.pumpWidget(_app(Align(child: BasketballControls(game: game))));

    const expected = {
      BasketballActionCue.shoot: ('SHOOT', 'HOLD · RELEASE IN LIME'),
      BasketballActionCue.finish: ('FINISH', 'TAP LAYUP · HOLD DUNK'),
      BasketballActionCue.release: ('RELEASE', 'HIT THE LIME'),
      BasketballActionCue.defend: ('DEFEND', 'TAP STEAL · HOLD GUARD'),
      BasketballActionCue.block: ('BLOCK', 'RELEASE WITH SHOOTER'),
      BasketballActionCue.rebound: ('REBOUND', 'TAP AT MARKER'),
    };

    for (final entry in expected.entries) {
      game.actionCue.value = entry.key;
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('shot meter marks the perfect window hot and haptics once', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final game = _game();
    await tester.pumpWidget(_app(BasketballShotMeter(game: game)));
    game.meter.value = const ShotMeterView(
      progress: 0.3,
      perfectCenter: 0.7,
      perfectHalf: 0.05,
      goodHalf: 0.12,
    );
    await tester.pump();

    var meter = tester.widget<CyberChargeMeter>(find.byType(CyberChargeMeter));
    expect(meter.view.hot, isFalse);

    game.meter.value = const ShotMeterView(
      progress: 0.68,
      perfectCenter: 0.7,
      perfectHalf: 0.05,
      goodHalf: 0.12,
    );
    await tester.pump();
    meter = tester.widget<CyberChargeMeter>(find.byType(CyberChargeMeter));
    expect(meter.view.hot, isTrue);
    expect(
      calls.where((call) => call.method == 'HapticFeedback.vibrate'),
      hasLength(1),
    );

    game.meter.value = const ShotMeterView(
      progress: 0.72,
      perfectCenter: 0.7,
      perfectHalf: 0.05,
      goodHalf: 0.12,
    );
    await tester.pump();
    expect(
      calls.where((call) => call.method == 'HapticFeedback.vibrate'),
      hasLength(1),
    );

    game.meter.value = const ShotMeterView(
      progress: 0.4,
      perfectCenter: 0.7,
      perfectHalf: 0.05,
      goodHalf: 0.12,
    );
    await tester.pump();
    game.meter.value = const ShotMeterView(
      progress: 0.7,
      perfectCenter: 0.7,
      perfectHalf: 0.05,
      goodHalf: 0.12,
    );
    await tester.pump();
    expect(
      calls.where((call) => call.method == 'HapticFeedback.vibrate'),
      hasLength(2),
    );
  });

  testWidgets('compact HUD labels heat and stamina without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = _game();
    final cubit = BasketballCubit(SecureGameStorage());
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: _app(
          Column(
            children: [
              BasketballHudBar(game: game, onExit: () {}),
              const Spacer(),
              BasketballStaminaRail(game: game),
              BasketballControls(game: game),
            ],
          ),
        ),
      ),
    );

    expect(find.text('HEAT'), findsNWidgets(2));
    game.heatActivePlayer.value = true;
    game.stamina01.value = 0.42;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('ON FIRE'), findsOneWidget);
    expect(find.text('HEAT'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final rosterIds = game.config.playerRoster
        .map((athlete) => athlete.id)
        .toList();
    cubit
      ..buildMatchFromRoster(rosterIds: rosterIds, starterId: rosterIds.first)
      ..beginPlay()
      ..onHalfEnded(halfIndex: 0, needsOvertime: false)
      ..resumeSecondHalf()
      ..onHalfEnded(halfIndex: 1, needsOvertime: true)
      ..beginOvertime();
    expect(cubit.state.halfIndex, 2);
    await tester.pump();
    await tester.pump();
    expect(find.text('SUDDEN DEATH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
