import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/pitch_duel_rules.dart';
import 'package:card_game/models/pitch_duel_mastery.dart';
import 'package:card_game/screens/game/widgets/match_phases.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameState playable() {
  final base = GameState.initial();
  return base.copyWith(
    loading: false,
    ownedCardIds: [
      ...base.deckAttackers,
      ...base.deckDefenders,
      base.deckKeeper!,
    ].map((p) => p.id).toList(),
    ownedActionCardIds: base.deckActions.map((a) => a.id).toList(),
  );
}

Future<void> until(GameBloc bloc, bool Function(GameState) predicate) async {
  if (predicate(bloc.state)) return;
  await bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
}

Future<void> send(
  GameBloc bloc,
  GameEvent event,
  bool Function(GameState) predicate,
) async {
  bloc.add(event);
  try {
    await until(bloc, predicate);
  } catch (_) {
    throw StateError(
      '${event.runtimeType}: phase=${bloc.state.phase} round=${bloc.state.currentRound} error=${bloc.state.questError}',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  for (final attackFirst in [true, false]) {
    test(
      'both sides complete four rounds; previews match totals; duplicate commits and rewards are ignored ($attackFirst)',
      () async {
        final bloc = GameBloc(SecureGameStorage());
        addTearDown(bloc.close);
        bloc.emit(playable());
        await send(
          bloc,
          MatchStarted(opponentLevel: 12),
          (s) => s.phase == MatchPhase.toss,
        );
        bloc.emit(
          bloc.state.copyWith(
            phase: MatchPhase.roleReveal,
            playerAttacking: attackFirst,
            initialAttackingChoice: attackFirst,
          ),
        );
        for (var r = 1; r <= 4; r++) {
          await send(
            bloc,
            RoleRevealAcknowledged(),
            (s) => s.phase == MatchPhase.scenario,
          );
          await send(bloc, ScenarioShown(), (s) => s.currentScenario != null);
          await send(bloc, PlayStarted(), (s) => s.phase == MatchPhase.play);
          final state = bloc.state;
          expect(state.playerAttacking, r.isOdd ? attackFirst : !attackFirst);
          final cpuPlayer = state.opponentSelectedPlayerCard!;
          final cpuAction = state.opponentSelectedActionCard!;
          expect(state.opponentUsedPlayerCards, isNot(contains(cpuPlayer.id)));
          expect(state.opponentUsedActionCards, isNot(contains(cpuAction.id)));
          final range = playerRivalRange(state)!;
          final alternative =
              (state.playerAttacking
                      ? state.opponentDefenders
                      : state.opponentAttackers)
                  .where((p) => !state.opponentUsedPlayerCards.contains(p.id))
                  .last;
          final switched = playerRivalRange(
            state.copyWith(
              opponentSelectedPlayerCard: alternative,
              opponentSelectedActionCard: state.opponentActions.last,
            ),
          )!;
          expect(
            (switched.min, switched.max),
            (range.min, range.max),
            reason: 'Preview must not depend on the hidden commitment',
          );
          final p =
              (state.playerAttacking
                      ? state.deckAttackers
                      : state.deckDefenders)
                  .firstWhere((p) => !state.usedPlayerCards.contains(p.id));
          final a = pitchLegalActions(
            actions: state.deckActions,
            usedIds: state.usedActionCards,
            round: r,
            attacking: state.playerAttacking,
          ).first;
          await send(
            bloc,
            PlayerSelected(p),
            (s) => s.selectedPlayerCard?.id == p.id,
          );
          await send(
            bloc,
            ActionSelected(a),
            (s) => s.selectedActionCard?.id == a.id,
          );
          final preview = pitchPower(
            player: p,
            action: a,
            scenario: state.currentScenario!,
            attacking: state.playerAttacking,
          );
          final timing = r.isOdd
              ? ShotTimingResult.at(.5)
              : ShotTimingResult.accessible;
          bloc.add(MovePlayed(shotTiming: timing));
          bloc.add(MovePlayed(shotTiming: timing));
          await until(bloc, (s) => s.phase == MatchPhase.roundResult);
          final result = bloc.state.roundResults.last;
          final own = result.playerAttacking
              ? result.attackBreakdown!
              : result.defenseBreakdown!;
          final rival = result.playerAttacking
              ? result.defenseBreakdown!
              : result.attackBreakdown!;
          expect(own.base, preview.base);
          expect(own.timing, timing.bonus);
          expect(
            result.playerAttacking ? result.attackPower : result.defensePower,
            preview.base + timing.bonus,
          );
          expect(rival.total, inInclusiveRange(range.min, range.max));
          expect(rival.timing, inInclusiveRange(0, 8));
          expect(bloc.state.usedPlayerCards, hasLength(r));
          expect(bloc.state.opponentUsedPlayerCards, hasLength(r));
          bloc.add(RoundAdvanced());
          bloc.add(RoundAdvanced());
          await until(
            bloc,
            (s) =>
                s.phase ==
                (r < 4 ? MatchPhase.roleReveal : MatchPhase.finalResult),
          );
        }
        final settled = bloc.state;
        expect(settled.roundResults, hasLength(4));
        expect(settled.usedPlayerCards.toSet(), hasLength(4));
        expect(settled.opponentUsedPlayerCards.toSet(), hasLength(4));
        expect(settled.opponentUsedActionCards.toSet(), hasLength(4));
        expect(settled.matchHistory, hasLength(1));
        expect(settled.matchHistory.single.pitchMasteryIndex, 0);
        expect(
          pitchMasteryGoal(settled.matchHistory).kind,
          PitchMasteryKind.doubleMatch,
        );
        expect(
          settled.matchHistory.single.rounds.every(
            (r) => r.playerBreakdown != null && r.opponentBreakdown != null,
          ),
          isTrue,
        );
        bloc.add(MatchFinished());
        bloc.add(MatchFinished());
        // A queued benign tutorial event establishes that both finishes were processed.
        await send(
          bloc,
          TutorialSeenMarked('regression-finished'),
          (s) => s.tutorialSeen.contains('regression-finished'),
        );
        expect(bloc.state.coins, settled.coins);
        expect(bloc.state.progression.totalXP, settled.progression.totalXP);
        expect(bloc.state.matchHistory, hasLength(1));
      },
    );
  }

  test('old one-sided decks load but cannot start', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    final attacks = actionCards
        .where((a) => a.category == ActionCategory.attack)
        .take(6)
        .toList();
    bloc.emit(
      playable().copyWith(
        deckActions: attacks,
        ownedActionCardIds: attacks.map((a) => a.id).toList(),
      ),
    );
    expect(bloc.state.deckReady, isFalse);
    bloc.add(MatchStarted());
    await send(
      bloc,
      TutorialSeenMarked('old-deck-checked'),
      (s) => s.tutorialSeen.contains('old-deck-checked'),
    );
    expect(bloc.state.phase, MatchPhase.idle);
  });

  test('a reserved special action cannot be committed early', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    final actions = [
      for (final id in ['act1', 'act2', 'act3', 'act4', 'act13', 'act14'])
        actionCards.firstWhere((a) => pitchActionBaseId(a) == id),
    ];
    final reserved = actions.firstWhere((a) => pitchActionBaseId(a) == 'act13');
    bloc.emit(
      playable().copyWith(
        phase: MatchPhase.play,
        currentRound: 1,
        playerAttacking: true,
        currentScenario: scenarios.first,
        deckActions: actions,
        ownedActionCardIds: actions.map((a) => a.id).toList(),
        selectedPlayerCard: playable().deckAttackers.first,
        selectedActionCard: reserved,
      ),
    );
    expect(bloc.state.deckReady, isTrue);
    expect(
      pitchLegalActions(
        actions: actions,
        usedIds: const [],
        round: 1,
        attacking: true,
      ),
      isNot(contains(reserved)),
    );
    bloc.add(MovePlayed(shotTiming: ShotTimingResult.accessible));
    await send(
      bloc,
      TutorialSeenMarked('reservation-checked'),
      (s) => s.tutorialSeen.contains('reservation-checked'),
    );
    expect(bloc.state.phase, MatchPhase.play);
    expect(bloc.state.roundResults, isEmpty);
    expect(bloc.state.usedActionCards, isEmpty);
    expect(bloc.state.usedPlayerCards, isEmpty);
  });

  test('level full-time scores remain draws with one settlement', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    bloc.emit(
      playable().copyWith(
        phase: MatchPhase.roundResult,
        currentRound: 4,
        playerScore: 2,
        opponentScore: 2,
      ),
    );
    await send(bloc, RoundAdvanced(), (s) => s.phase == MatchPhase.finalResult);
    expect(bloc.state.matchHistory.single.resultLabel, 'Draw');
    expect(bloc.state.matchHistory.single.penaltyPlayerScore, isNull);
  });
}
