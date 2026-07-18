import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/screens/game/widgets/duel_board_phase.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoundResult _sampleResult({
  required bool playerAttacking,
  required RoundOutcome outcome,
}) {
  final attackAction = actionCards.firstWhere((c) => c.title == 'All In');
  final defenseAction = actionCards.firstWhere(
    (c) => c.title == 'Last-Ditch Tackle',
  );
  return RoundResult(
    round: 1,
    scenario: scenarios.first,
    playerAttacking: playerAttacking,
    attackerCard: attackers.first,
    defenderCard: defenders.first,
    attackAction: attackAction,
    defenseAction: defenseAction,
    outcome: outcome,
    attackPower: 115,
    defensePower: 129,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpResolveBeat(
    WidgetTester tester, {
    required RoundResult result,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    final base = GameState.initial().copyWith(loading: false);
    bloc.emit(
      base.copyWith(
        phase: MatchPhase.roundResult,
        currentRound: 1,
        playerScore: 1,
        opponentScore: 2,
        playerAttacking: result.playerAttacking,
        currentScenario: result.scenario,
        opponentAttackers: base.deckAttackers,
        opponentDefenders: base.deckDefenders,
        opponentActions: base.deckActions,
        roundResults: [result],
        tutorialSeen: const {'scenario', 'play', 'round-result'},
      ),
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: DuelBoardPhase(state: bloc.state, onQuit: () {}),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // Step through the deal-in → flip → power tick → verdict → score
    // timeline (4.2s) checking for overflow at every beat...
    for (var step = 0; step < 15; step++) {
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
    // ...then let the next-round countdown finish so no timers are pending.
    for (var step = 0; step < 5; step++) {
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }
  }

  testWidgets('Duel Board resolve beat has no overflow across the timeline', (
    tester,
  ) async {
    const outcomes = [
      RoundOutcome.goal,
      RoundOutcome.foul,
      RoundOutcome.redCard,
      RoundOutcome.missed,
    ];
    for (final attacking in [true, false]) {
      for (final outcome in outcomes) {
        await pumpResolveBeat(
          tester,
          result: _sampleResult(playerAttacking: attacking, outcome: outcome),
        );
      }
    }
  });
}
