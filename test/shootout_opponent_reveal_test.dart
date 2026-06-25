import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/blocs/shootout/shootout_bloc.dart';
import 'package:card_game/blocs/shootout/shootout_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/screens/shootout/widgets/shootout_lineup_phase.dart';
import 'package:card_game/screens/shootout/widgets/shootout_opponent_reveal_phase.dart';
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
  final opponent = _squad('o');

  ShootoutState baseState() => ShootoutState.initial(
    playerShooters: player,
    playerKeeper: player.last,
    cpuShooters: opponent,
    cpuKeeper: opponent.last,
    cpuLevel: 1,
    opponentName: 'Maya Santos',
  );

  Future<({GameBloc gameBloc, ShootoutBloc shootoutBloc})> pumpWithBlocs(
    WidgetTester tester,
    Widget child,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gameBloc = GameBloc(SecureGameStorage());
    addTearDown(gameBloc.close);
    gameBloc.emit(GameState.initial().copyWith(loading: false));

    final shootoutBloc = ShootoutBloc(
      playerShooters: player,
      playerKeeper: player.last,
      cpuShooters: opponent,
      cpuKeeper: opponent.last,
      cpuLevel: 1,
      opponentName: 'Maya Santos',
    );
    addTearDown(shootoutBloc.close);

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
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (gameBloc: gameBloc, shootoutBloc: shootoutBloc);
  }

  testWidgets('opponent draw locks a random player and advances to lineup', (
    tester,
  ) async {
    final blocs = await pumpWithBlocs(
      tester,
      ShootoutOpponentRevealPhase(state: baseState(), onQuit: () {}),
    );

    await tester.pump();

    expect(find.text('OPPONENT DRAW'), findsOneWidget);
    expect(find.text('MAYA SANTOS'), findsOneWidget);
    expect(find.text('SQUAD CLASH'), findsOneWidget);

    await tester.tap(find.text('SQUAD CLASH'));
    await tester.pump();

    expect(blocs.shootoutBloc.state.stage, ShootoutStage.lineup);
  });

  testWidgets('lineup names the drawn opponent squad instead of CPU', (
    tester,
  ) async {
    await pumpWithBlocs(
      tester,
      ShootoutLineupPhase(
        state: baseState().copyWith(stage: ShootoutStage.lineup),
        onQuit: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('MAYA SANTOS SQUAD'), findsOneWidget);
    expect(find.text('CPU SQUAD'), findsNothing);
  });
}
