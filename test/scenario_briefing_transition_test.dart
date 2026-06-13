import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
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

  final scenario = scenarios.first;

  GameState scenarioState(GameState base) => base.copyWith(
    loading: false,
    phase: MatchPhase.scenario,
    currentRound: 1,
    playerAttacking: false,
    currentScenario: scenario,
    opponentAttackers: base.deckAttackers,
    opponentDefenders: base.deckDefenders,
    opponentActions: base.deckActions,
    tutorialSeen: const {'scenario'},
  );

  testWidgets('ScenarioBriefingSection calls onComplete after countdown', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ScenarioBriefingSection(
          scenario: scenario,
          attacking: false,
          initialSeconds: 3,
          onComplete: () => completed = true,
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('GO'), findsOneWidget);
    expect(completed, isTrue);
  });

  testWidgets('PlayPhase builds with full-bleed selection backdrops', (
    tester,
  ) async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    final base = GameState.initial().copyWith(loading: false);
    bloc.emit(scenarioState(base).copyWith(phase: MatchPhase.play));

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: SizedBox(
            height: 900,
            child: PlayPhase(state: bloc.state, onQuit: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
