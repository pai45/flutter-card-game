import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/screens/game/widgets/duel_board_phase.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  final playerAttacking =
      Uri.base.queryParameters['attacking']?.toLowerCase() != 'false';
  final base = GameState.initial().copyWith(loading: false);
  final result = RoundResult(
    round: 3,
    scenario: scenarios.first,
    playerAttacking: playerAttacking,
    attackerCard: attackers.first,
    defenderCard: defenders.first,
    attackAction: actionCards.firstWhere((card) => card.title == 'All In'),
    defenseAction: actionCards.firstWhere(
      (card) => card.title == 'Last-Ditch Tackle',
    ),
    outcome: RoundOutcome.goal,
    attackPower: 118,
    defensePower: 129,
  );
  final previewState = base.copyWith(
    phase: MatchPhase.roundResult,
    currentRound: 3,
    playerScore: 1,
    opponentScore: 1,
    playerAttacking: playerAttacking,
    currentScenario: result.scenario,
    opponentAttackers: base.deckAttackers,
    opponentDefenders: base.deckDefenders,
    opponentActions: base.deckActions,
    roundResults: [result],
    tutorialSeen: const {'scenario', 'play', 'round-result'},
  );
  // Scratch layout harness — same seed path as widget tests.
  // ignore: invalid_use_of_visible_for_testing_member
  final bloc = GameBloc(SecureGameStorage())..emit(previewState);

  runApp(
    BlocProvider.value(
      value: bloc,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: DuelBoardPhase(state: bloc.state, onQuit: () {}),
      ),
    ),
  );
}
