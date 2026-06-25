import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/screens/game/widgets/match_phases.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  GameState tossState({
    String? tossResult,
    bool? playerWonToss,
    bool playerAttacking = false,
  }) => GameState.initial().copyWith(
    loading: false,
    phase: tossResult == null ? MatchPhase.toss : MatchPhase.tossResult,
    currentRound: 1,
    tossResult: tossResult,
    playerWonToss: playerWonToss,
    playerAttacking: playerAttacking,
    opponentName: 'Maya Santos',
    // 'toss' marked seen so the spotlight walkthrough stays out of the test.
    tutorialSeen: const {'toss'},
  );

  // Pumps CoinTossPhase with motion disabled so the coin resolves to a face
  // without a long spin, keeping the test deterministic.
  Future<GameBloc> pumpToss(WidgetTester tester, GameState state) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    bloc.emit(state);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: BlocProvider.value(
              value: bloc,
              child: CoinTossPhase(state: state, onQuit: () {}),
            ),
          ),
        ),
      ),
    );
    return bloc;
  }

  testWidgets('idle toss shows HEADS/TAILS call and no score bar', (
    tester,
  ) async {
    await pumpToss(tester, tossState());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('HEADS'), findsOneWidget);
    expect(find.text('TAILS'), findsOneWidget);
    // The caption is just COIN TOSS — no round prefix.
    expect(find.text('COIN TOSS'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    // The old [P1] YOU / VS / ATTACKING score bar is gone.
    expect(find.text('ATTACKING'), findsNothing);
    expect(find.text('VS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calling HEADS resolves the toss', (tester) async {
    final bloc = await pumpToss(tester, tossState());
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.text('HEADS'));
    await tester.pump(); // start the call button's press animation
    await tester.pump(const Duration(milliseconds: 200)); // press → onTap
    await tester.pump(); // flush the dispatched TossResolved event

    expect(bloc.state.tossResult, isNotNull);
    expect(bloc.state.phase, MatchPhase.tossResult);
    // Win/lose follows the call: won iff the landed face matches it.
    expect(bloc.state.playerWonToss, bloc.state.tossResult == 'heads');
  });

  testWidgets('player win shows role choice and dispatches RoleChosen', (
    tester,
  ) async {
    final bloc = await pumpToss(
      tester,
      tossState(tossResult: 'heads', playerWonToss: true),
    );
    // Flush the post-frame "landed" callback + result reveal.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('YOU WON THE TOSS'), findsOneWidget);
    expect(find.text('ATTACK'), findsOneWidget);
    expect(find.text('DEFEND'), findsOneWidget);

    await tester.tap(find.text('ATTACK'));
    await tester.pump(); // start the button's press animation
    await tester.pump(
      const Duration(milliseconds: 200),
    ); // press completes → onTap
    await tester.pump(); // flush the dispatched RoleChosen event

    expect(bloc.state.phase, MatchPhase.scenario);
    expect(bloc.state.playerAttacking, isTrue);
  });

  testWidgets('opponent win shows the opponent decision panel', (tester) async {
    await pumpToss(
      tester,
      tossState(
        tossResult: 'tails',
        playerWonToss: false,
        playerAttacking: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('MAYA SANTOS WON THE TOSS'), findsOneWidget);

    // Drain the decision meter (~900ms) + the 650ms auto-advance delay so no
    // timers outlive the test. Stepped pumps let each chained future resolve.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('loss colour stays hidden until the flip animation lands', (
    tester,
  ) async {
    // Animations ENABLED (no disableAnimations) so the real 1.5s flip runs.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    final state = tossState(
      tossResult: 'tails',
      playerWonToss: false,
      playerAttacking: true,
    );
    bloc.emit(state);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: bloc,
          child: CoinTossPhase(state: state, onQuit: () {}),
        ),
      ),
    );

    // The loss treatment is the red-bordered coin (border colour _kTossRed).
    bool redCoinVisible() =>
        tester.widgetList<Container>(find.byType(Container)).any((c) {
          final d = c.decoration;
          return d is BoxDecoration &&
              d.border is Border &&
              (d.border as Border).top.color == const Color(0xFFFF4D4D);
        });

    // Mid-flip: the outcome must stay hidden — no red coin, no result text.
    await tester.pump(const Duration(milliseconds: 700));
    expect(redCoinVisible(), isFalse);
    expect(find.text('MAYA SANTOS WON THE TOSS'), findsNothing);

    // Let the flip land (1.5s total) and the result panel reveal.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    expect(redCoinVisible(), isTrue);
    expect(find.text('MAYA SANTOS WON THE TOSS'), findsOneWidget);

    // Drain the CPU decision meter (3.6s) + the 650ms auto-advance delay so
    // no timers outlive the test.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
