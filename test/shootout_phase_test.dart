import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/blocs/shootout/shootout_bloc.dart';
import 'package:card_game/blocs/shootout/shootout_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/screens/shootout/widgets/shootout_phase.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlayerCard _card(String id, PlayerRole role, int rating) => PlayerCard(
  id: id,
  name: id,
  shortName: id,
  country: 'X',
  countryCode: 'X',
  position: role == PlayerRole.goalkeeper ? 'GK' : 'ST',
  role: role,
  rating: rating,
  trait: 'T',
  tier: CardTier.gold,
  icon: Icons.sports_soccer,
);

List<PlayerCard> _squad(String tag) => [
  _card('$tag-a1', PlayerRole.attacker, 88),
  _card('$tag-a2', PlayerRole.attacker, 84),
  _card('$tag-d1', PlayerRole.defender, 80),
  _card('$tag-d2', PlayerRole.defender, 79),
  _card('$tag-gk', PlayerRole.goalkeeper, 82),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  final player = _squad('p');
  final cpu = _squad('c');

  ShootoutState baseState() => ShootoutState.initial(
    playerShooters: player,
    playerKeeper: player.last,
    cpuShooters: cpu,
    cpuKeeper: cpu.last,
    cpuLevel: 1,
    opponentName: 'Maya Santos',
  );

  Future<ShootoutBloc> pumpPhase(
    WidgetTester tester,
    ShootoutState state, {
    Size physicalSize = const Size(1080, 2400),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gameBloc = GameBloc(SecureGameStorage());
    addTearDown(gameBloc.close);
    // Suppress the spotlight walkthrough during the test.
    gameBloc.emit(
      GameState.initial().copyWith(
        loading: false,
        tutorialSeen: const {'shootout', 'shootout-attack', 'shootout-defence'},
      ),
    );

    final shootoutBloc = ShootoutBloc(
      playerShooters: player,
      playerKeeper: player.last,
      cpuShooters: cpu,
      cpuKeeper: cpu.last,
      cpuLevel: 1,
      opponentName: 'Maya Santos',
    );
    addTearDown(shootoutBloc.close);
    shootoutBloc.emit(state);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: gameBloc),
                BlocProvider.value(value: shootoutBloc),
              ],
              child: ShootoutPhase(state: state, onQuit: () {}),
            ),
          ),
        ),
      ),
    );
    return shootoutBloc;
  }

  testWidgets('attacking turn uses goal targets and shot language', (
    tester,
  ) async {
    final bloc = await pumpPhase(
      tester,
      baseState().copyWith(stage: ShootoutStage.choose),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('YOUR SHOT'), findsOneWidget);
    expect(find.text('ATTACK'), findsOneWidget);
    // The active shooter (player's first attacker) is named with their OVR.
    expect(find.text('P-A1'), findsOneWidget);
    expect(find.textContaining('OVR 88'), findsWidgets);
    // The confirm CTA prompts for a target before a side is selected.
    expect(find.text('CHOOSE SHOT TARGET'), findsOneWidget);
    expect(find.byKey(const ValueKey('shot-reticle-left')), findsOneWidget);
    expect(find.text('DIVE LEFT'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('shoot-direction-left')));
    await tester.pump();
    expect(bloc.state.selectedDirection, PenaltyDirection.left);
  });

  testWidgets('defending turn uses visible dive pads and keeper language', (
    tester,
  ) async {
    final defending = baseState().copyWith(
      stage: ShootoutStage.choose,
      round: 1,
    );
    final bloc = await pumpPhase(tester, defending);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('YOU’RE IN GOAL'), findsOneWidget);
    expect(find.text('DEFEND'), findsOneWidget);
    expect(find.text('DIVE LEFT'), findsOneWidget);
    expect(find.text('HOLD CENTER'), findsOneWidget);
    expect(find.text('DIVE RIGHT'), findsOneWidget);
    expect(find.byKey(const ValueKey('shot-reticle-left')), findsNothing);
    expect(find.byKey(const ValueKey('shoot-direction-left')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dive-direction-right')));
    await tester.pump();
    expect(bloc.state.selectedDirection, PenaltyDirection.right);
  });

  testWidgets('selected controls use distinct confirmation language', (
    tester,
  ) async {
    await pumpPhase(
      tester,
      baseState().copyWith(
        stage: ShootoutStage.choose,
        selectedDirection: PenaltyDirection.left,
      ),
    );
    expect(find.text('TAKE SHOT · LEFT'), findsOneWidget);
    expect(find.byKey(const ValueKey('shot-preview-left')), findsOneWidget);

    await pumpPhase(
      tester,
      baseState().copyWith(
        stage: ShootoutStage.choose,
        round: 1,
        selectedDirection: PenaltyDirection.right,
      ),
    );
    expect(find.text('COMMIT DIVE · RIGHT'), findsOneWidget);
    expect(find.byKey(const ValueKey('shot-preview-right')), findsNothing);
  });

  testWidgets('result stage shows the verdict and a winning banner', (
    tester,
  ) async {
    final kick = PenaltyKick(
      kickNumber: 10,
      byPlayer: true,
      shootDirection: PenaltyDirection.right,
      diveDirection: PenaltyDirection.left,
      scored: true,
      shooter: player[0],
      keeper: cpu.last,
    );
    final over = baseState().copyWith(
      stage: ShootoutStage.result,
      kicks: [kick],
      playerScore: 5,
      opponentScore: 4,
      round: 10,
      over: true,
      winner: 'player',
    );
    await pumpPhase(tester, over);
    await tester.pump(const Duration(milliseconds: 300));

    // The goal-scene stamps its verdict in (reduced motion snaps to the end).
    expect(find.text('GOAL'), findsOneWidget);
    expect(find.text('YOU WIN THE SHOOTOUT'), findsOneWidget);
    // The over banner offers CONTINUE rather than an auto-advance countdown.
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('Next kick in...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('result verdicts are expressed from the user perspective', (
    tester,
  ) async {
    Future<void> pumpKick(PenaltyKick kick, String verdict) async {
      await pumpPhase(
        tester,
        baseState().copyWith(
          stage: ShootoutStage.result,
          kicks: [kick],
          round: kick.byPlayer ? 1 : 2,
          over: true,
          winner: kick.byPlayer ? 'player' : 'opponent',
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(verdict), findsOneWidget);
    }

    await pumpKick(
      PenaltyKick(
        kickNumber: 1,
        byPlayer: true,
        shootDirection: PenaltyDirection.left,
        diveDirection: PenaltyDirection.left,
        scored: false,
        shooter: player.first,
        keeper: cpu.last,
      ),
      'SAVED BY C-GK',
    );
    await pumpKick(
      PenaltyKick(
        kickNumber: 2,
        byPlayer: false,
        shootDirection: PenaltyDirection.right,
        diveDirection: PenaltyDirection.left,
        scored: true,
        shooter: cpu.first,
        keeper: player.last,
      ),
      'GOAL CONCEDED',
    );
    await pumpKick(
      PenaltyKick(
        kickNumber: 2,
        byPlayer: false,
        shootDirection: PenaltyDirection.center,
        diveDirection: PenaltyDirection.center,
        scored: false,
        shooter: cpu.first,
        keeper: player.last,
      ),
      'YOU SAVED IT',
    );
  });

  testWidgets('next turn is named and can be advanced after the impact', (
    tester,
  ) async {
    final kick = PenaltyKick(
      kickNumber: 1,
      byPlayer: true,
      shootDirection: PenaltyDirection.right,
      diveDirection: PenaltyDirection.left,
      scored: true,
      shooter: player.first,
      keeper: cpu.last,
    );
    final bloc = await pumpPhase(
      tester,
      baseState().copyWith(
        stage: ShootoutStage.result,
        kicks: [kick],
        playerScore: 1,
        round: 1,
      ),
    );

    expect(find.text('RESOLVING KICK…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('NEXT: DEFEND · 2'), findsOneWidget);
    await tester.tap(find.text('NEXT: DEFEND · 2'));
    await tester.pump();
    expect(bloc.state.stage, ShootoutStage.choose);
  });

  testWidgets('defence controls fit a narrow screen with large text', (
    tester,
  ) async {
    await pumpPhase(
      tester,
      baseState().copyWith(stage: ShootoutStage.choose, round: 1),
      physicalSize: const Size(960, 1920),
      textScale: 1.4,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('DIVE LEFT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
