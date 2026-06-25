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

  Future<void> pumpPhase(WidgetTester tester, ShootoutState state) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gameBloc = GameBloc(SecureGameStorage());
    addTearDown(gameBloc.close);
    // Suppress the spotlight walkthrough during the test.
    gameBloc.emit(
      GameState.initial().copyWith(
        loading: false,
        tutorialSeen: const {'shootout'},
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
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
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
  }

  testWidgets('choose stage names the shooter on the spot', (tester) async {
    await pumpPhase(tester, baseState().copyWith(stage: ShootoutStage.choose));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CHOOSE YOUR CORNER'), findsOneWidget);
    // The active shooter (player's first attacker) is named with their OVR.
    expect(find.text('P-A1'), findsOneWidget);
    expect(find.textContaining('OVR 88'), findsWidgets);
    // The confirm CTA prompts for a target before a side is selected.
    expect(find.text('PICK A SIDE'), findsOneWidget);
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
}
