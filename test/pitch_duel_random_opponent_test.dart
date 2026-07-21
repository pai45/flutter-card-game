import 'dart:math';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/data/random_opponent_names.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/deck.dart';
import 'package:card_game/models/packs.dart';
import 'package:card_game/models/progression.dart';
import 'package:card_game/screens/game/widgets/match_phases.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameState _playableState() {
  final state = GameState.initial();
  final keeper = state.deckKeeper!;
  return state.copyWith(
    loading: false,
    ownedCardIds: [
      ...state.deckAttackers.map((card) => card.id),
      ...state.deckDefenders.map((card) => card.id),
      keeper.id,
    ],
    ownedActionCardIds: state.deckActions.map((card) => card.id).toList(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('normal Pitch Duel match resolves a random opponent name', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    bloc.emit(_playableState());

    bloc.add(MatchStarted());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.opponentName, isNotNull);
    expect(randomOpponentNames, contains(bloc.state.opponentName));
  });

  test('Pitch Duel starts from a football deck without batsmen', () async {
    final base = GameState.initial();
    final keeper = base.deckKeeper!;
    final footballOnlySlot = StoredDeckSlot(
      id: 'football-only',
      name: 'Football Only',
      attackers: base.deckAttackers.map((card) => card.id).toList(),
      defenders: base.deckDefenders.map((card) => card.id).toList(),
      actions: base.deckActions.map((card) => card.id).toList(),
      keeper: keeper.id,
    );
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    bloc.emit(
      base.copyWith(
        loading: false,
        deckSlots: [footballOnlySlot],
        activeDeckId: footballOnlySlot.id,
        deckFinalOverBatsmen: const [],
        ownedCardIds: [
          ...base.deckAttackers.map((card) => card.id),
          ...base.deckDefenders.map((card) => card.id),
          keeper.id,
        ],
        ownedActionCardIds: base.deckActions.map((card) => card.id).toList(),
      ),
    );

    expect(bloc.state.deckReady, isTrue);
    expect(bloc.state.finalOverDeckReady, isFalse);

    bloc.add(MatchStarted());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.phase, MatchPhase.toss);
  });

  test('cricket deck save keeps the football deck intact', () async {
    final base = _playableState();
    final footballSlot = defaultDeckSlots.first;
    final cricketIds = batsmen.take(3).map((card) => card.id).toList();
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    bloc.emit(
      base.copyWith(
        deckSlots: [footballSlot],
        activeDeckId: footballSlot.id,
        ownedCardIds: [...base.ownedCardIds, ...cricketIds],
      ),
    );

    bloc.add(
      DeckSaved(
        StoredDeckSlot(
          id: footballSlot.id,
          name: footballSlot.name,
          attackers: footballSlot.attackers,
          defenders: footballSlot.defenders,
          actions: footballSlot.actions,
          keeper: footballSlot.keeper,
          finalOverBatsmen: cricketIds,
          chessFormation: footballSlot.chessFormation,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      bloc.state.deckAttackers.map((card) => card.id),
      footballSlot.attackers,
    );
    expect(
      bloc.state.deckDefenders.map((card) => card.id),
      footballSlot.defenders,
    );
    expect(bloc.state.deckActions.map((card) => card.id), footballSlot.actions);
    expect(bloc.state.deckFinalOverBatsmen.map((card) => card.id), cricketIds);
    expect(bloc.state.deckReady, isTrue);
    expect(bloc.state.finalOverDeckReady, isTrue);
  });

  test('cricket starter unlocks Final Over deck only', () async {
    final base = _playableState();
    final footballSlot = defaultDeckSlots.first;
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    bloc.emit(
      base.copyWith(
        deckSlots: [footballSlot],
        activeDeckId: footballSlot.id,
        deckFinalOverBatsmen: const [],
        starterPackClaimed: false,
        cricketStarterPackClaimed: false,
      ),
    );

    bloc.add(CricketStarterPackOpened());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.cricketStarterPackClaimed, isTrue);
    expect(bloc.state.starterPackClaimed, isFalse);
    expect(bloc.state.deckFinalOverBatsmen, hasLength(cricketStarterCardCount));
    expect(
      bloc.state.deckFinalOverBatsmen.every((card) => card.role == PlayerRole.batsman),
      isTrue,
    );
    expect(bloc.state.finalOverDeckReady, isTrue);
    expect(
      bloc.state.deckAttackers.map((card) => card.id),
      footballSlot.attackers,
    );
  });

  test('football starter does not claim cricket starter', () async {
    final base = GameState.initial();
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    bloc.emit(
      base.copyWith(
        loading: false,
        starterPackClaimed: false,
        cricketStarterPackClaimed: false,
      ),
    );

    bloc.add(StarterPackOpened());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.starterPackClaimed, isTrue);
    expect(bloc.state.cricketStarterPackClaimed, isFalse);
  });

  test(
    'challenge Pitch Duel match preserves the provided rival name',
    () async {
      final bloc = GameBloc(SecureGameStorage());
      addTearDown(bloc.close);
      bloc.emit(_playableState());

      bloc.add(MatchStarted(opponentName: 'Rival Prime', opponentLevel: 7));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.opponentName, 'Rival Prime');
    },
  );

  test('same-level Pitch Duel opponent decks can differ across seeds', () {
    final lineups = <String>{};

    for (var seed = 0; seed < 8; seed++) {
      final opponent = generateOpponentDeck(
        4,
        attackers,
        defenders,
        actionCards,
        random: Random(seed),
      );
      lineups.add(
        [
          ...opponent.attackers.map((card) => card.id),
          ...opponent.defenders.map((card) => card.id),
        ].join('|'),
      );
    }

    expect(lineups.length, greaterThan(1));
  });

  testWidgets('match intro searches, locks opponent, then counts down', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MatchIntroPhase(
          deckName: 'Starter XI',
          opponentName: 'Maya Santos',
          onComplete: () => completed = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('CYBER REACT'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('OPP'), findsOneWidget);
    expect(find.text('SEARCHING...'), findsOneWidget);
    expect(find.text('OPPONENT FOUND'), findsNothing);
    expect(find.text('MATCH STARTING IN'), findsNothing);
    expect(find.text('MAYA SANTOS'), findsNothing);
    expect(find.text('CPU'), findsNothing);
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 4000));
    await tester.pump();

    expect(find.text('MAYA SANTOS'), findsOneWidget);
    expect(find.text('OPPONENT FOUND'), findsOneWidget);
    expect(find.text('SEARCHING...'), findsNothing);
    expect(find.text('MATCH STARTING IN'), findsNothing);
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('MATCH STARTING IN'), findsOneWidget);
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 3800));

    expect(completed, isTrue);
  });
}
