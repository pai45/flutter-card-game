import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/enums.dart';
import '../../config/tutorial_steps.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/match.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/card_helpers.dart';
import '../../utils/label_helpers.dart';
import 'game_event.dart';
import 'game_state.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc(this._storage) : super(GameState.initial()) {
    on<GameLoaded>(_onLoaded);
    on<DeckSaved>(_onDeckSaved);
    on<DeckApplied>(_onDeckApplied);
    on<DeckCreated>(_onDeckCreated);
    on<TutorialReset>(_onTutorialReset);
    on<TutorialSeenMarked>(_onTutorialSeenMarked);
    on<TutorialsSkippedAll>(_onTutorialsSkippedAll);
    on<OwnedCardAdded>(_onOwnedCardAdded);
    on<CoinsAdded>(_onCoinsAdded);
    on<CoinsSpent>(_onCoinsSpent);
    on<CardPurchased>(_onCardPurchased);
    on<PackOpened>(_onPackOpened);
    on<CardBackPurchased>(_onCardBackPurchased);
    on<CardBackEquipped>(_onCardBackEquipped);
    on<PackRevealSeen>((_, emit) => emit(state.copyWith(pendingPackReveal: null)));
    on<MatchReset>((_, emit) => emit(_resetMatch(state)));
    on<MatchStarted>(_onMatchStarted);
    on<TossChoiceChanged>(
      (event, emit) => emit(state.copyWith(tossChoice: event.choice)),
    );
    on<TossResolved>(_onTossResolved);
    on<RoleChosen>(_onRoleChosen);
    on<ScenarioShown>(_onScenarioShown);
    on<PlayStarted>((_, emit) => emit(state.copyWith(phase: MatchPhase.play)));
    on<PlayerSelected>(
      (event, emit) => emit(state.copyWith(selectedPlayerCard: event.card)),
    );
    on<ActionSelected>(
      (event, emit) => emit(state.copyWith(selectedActionCard: event.card)),
    );
    on<MovePlayed>(_onMovePlayed);
    on<RoundAdvanced>(_onRoundAdvanced);
    on<PenaltyStarted>(
      (_, emit) => emit(
        state.copyWith(
          phase: MatchPhase.penalty,
          penaltyKicks: [],
          penaltyPlayerScore: 0,
          penaltyOpponentScore: 0,
          penaltyRound: 0,
          penaltyPhaseOver: false,
          penaltyPlayerDirection: null,
          penaltyKickPhase: 'choose',
          penaltySuddenDeath: false,
          penaltyWinner: null,
        ),
      ),
    );
    on<PenaltyDirectionSelected>(
      (event, emit) => emit(
        state.copyWith(penaltyPlayerDirection: event.direction),
      ),
    );
    on<PenaltyKickConfirmed>(_onPenaltyKickConfirmed);
    on<PenaltyNextKick>(
      (_, emit) => emit(
        state.copyWith(
          penaltyKickPhase: 'choose',
          penaltyPlayerDirection: null,
        ),
      ),
    );
    on<MatchFinished>(_onMatchFinished);
  }

  final SecureGameStorage _storage;
  final Random _random = Random();

  Future<void> _onLoaded(GameLoaded event, Emitter<GameState> emit) async {
    try {
      developer.log('GameLoaded: Starting initialization');

      final slots = await _storage.loadDecks().timeout(
        const Duration(seconds: 2),
        onTimeout: () => defaultDeckSlots,
      );
      developer.log('GameLoaded: Loaded decks');

      final safeSlots = slots.isEmpty
          ? defaultDeckSlots
          : slots.map(_hydratedSlot).toList();
      final active = safeSlots.first;

      final seen = await _storage.loadTutorialSeen().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <String>{},
      );
      developer.log('GameLoaded: Loaded tutorial seen');

      final owned = await _storage.loadOwnedCards().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <String>[],
      );
      developer.log('GameLoaded: Loaded owned cards');

      final history = await _storage.loadMatchHistory().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <MatchHistoryEntry>[],
      );
      developer.log('GameLoaded: Loaded history');

      final starterPackClaimed = await _storage.loadStarterPackClaimed().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      developer.log('GameLoaded: Loaded starter pack status: $starterPackClaimed');

      final wallet = await _storage.loadWallet().timeout(
        const Duration(seconds: 2),
        onTimeout: WalletSnapshot.initial,
      );
      developer.log('GameLoaded: Loaded wallet');

      var ownedCards = {...owned, ...wallet.ownedCardIds}.toList();
      PackRevealData? pendingPackReveal;

      if (!starterPackClaimed) {
        developer.log('GameLoaded: Building starter pack');
        final starterPackCards = _buildStarterPack();
        ownedCards = {
          ...ownedCards,
          ...starterPackCards.map((card) => card.id),
        }.toList();
        pendingPackReveal = PackRevealData.starter(starterPackCards);
        await _storage.saveOwnedCards(ownedCards);
        await _storage.saveStarterPackClaimed();
        developer.log('GameLoaded: Starter pack built and saved');
      }

      developer.log('GameLoaded: Emitting state');
      emit(
        state.copyWith(
          loading: false,
          deckSlots: safeSlots,
          activeDeckId: active.id,
          deckAttackers: cardsByIds(attackers, active.attackers),
          deckDefenders: cardsByIds(defenders, active.defenders),
          deckActions: actionCardsByIds(active.actions),
          coins: wallet.coins,
          ownedCardIds: ownedCards,
          ownedCardBackIds: wallet.ownedCardBackIds.contains('default')
              ? wallet.ownedCardBackIds
              : ['default', ...wallet.ownedCardBackIds],
          equippedCardBackId: wallet.equippedCardBackId,
          matchHistory: history,
          tutorialSeen: seen,
          pendingPackReveal: pendingPackReveal,
        ),
      );
      developer.log('GameLoaded: Complete');
    } catch (e, st) {
      developer.log('GameLoaded ERROR: $e\n$st');
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> _onOwnedCardAdded(
    OwnedCardAdded event,
    Emitter<GameState> emit,
  ) async {
    final owned = {...state.ownedCardIds, event.cardId}.toList();
    emit(state.copyWith(ownedCardIds: owned));
    await _storage.saveOwnedCards(owned);
    await _saveWallet(ownedCardIds: owned);
  }

  Future<void> _onCoinsAdded(
    CoinsAdded event,
    Emitter<GameState> emit,
  ) async {
    final coins = state.coins + event.amount;
    emit(state.copyWith(coins: coins));
    await _saveWallet(coins: coins);
  }

  Future<void> _onCoinsSpent(
    CoinsSpent event,
    Emitter<GameState> emit,
  ) async {
    if (state.coins < event.amount) return;
    final coins = state.coins - event.amount;
    emit(state.copyWith(coins: coins));
    await _saveWallet(coins: coins);
  }

  Future<void> _onCardPurchased(
    CardPurchased event,
    Emitter<GameState> emit,
  ) async {
    if (state.ownedCardIds.contains(event.cardId)) return;
    final owned = {...state.ownedCardIds, event.cardId}.toList();
    emit(state.copyWith(ownedCardIds: owned));
    await _storage.saveOwnedCards(owned);
    await _saveWallet(ownedCardIds: owned);
  }

  Future<void> _onPackOpened(
    PackOpened event,
    Emitter<GameState> emit,
  ) async {
    final rolledCards = cardsByIds(allPlayerCards, event.rolledCardIds);
    final newCardCount = rolledCards
        .where((card) => !state.ownedCardIds.contains(card.id))
        .length;
    final owned = {...state.ownedCardIds, ...event.rolledCardIds}.toList();
    final coins = state.coins + event.refund;
    emit(
      state.copyWith(
        ownedCardIds: owned,
        coins: coins,
        pendingPackReveal: PackRevealData.shop(
          packName: event.packName,
          cards: rolledCards,
          refund: event.refund,
          newCardCount: newCardCount,
        ),
      ),
    );
    await _storage.saveOwnedCards(owned);
    await _saveWallet(coins: coins, ownedCardIds: owned);
  }

  Future<void> _onCardBackPurchased(
    CardBackPurchased event,
    Emitter<GameState> emit,
  ) async {
    if (state.ownedCardBackIds.contains(event.cardBackId)) return;
    final owned = {...state.ownedCardBackIds, event.cardBackId}.toList();
    emit(state.copyWith(ownedCardBackIds: owned));
    await _saveWallet(ownedCardBackIds: owned);
  }

  Future<void> _onCardBackEquipped(
    CardBackEquipped event,
    Emitter<GameState> emit,
  ) async {
    if (!state.ownedCardBackIds.contains(event.cardBackId)) return;
    emit(state.copyWith(equippedCardBackId: event.cardBackId));
    await _saveWallet(equippedCardBackId: event.cardBackId);
  }

  Future<void> _onDeckSaved(DeckSaved event, Emitter<GameState> emit) async {
    final cleaned = _hydratedSlot(event.slot);
    final slots = [
      for (final slot in state.deckSlots)
        if (slot.id == cleaned.id) cleaned else slot,
    ];
    await _storage.saveDecks(slots);
    emit(
      state.copyWith(
        deckSlots: slots,
        activeDeckId: cleaned.id,
        deckAttackers: cardsByIds(attackers, cleaned.attackers),
        deckDefenders: cardsByIds(defenders, cleaned.defenders),
        deckActions: actionCardsByIds(cleaned.actions),
      ),
    );
  }

  void _onDeckApplied(DeckApplied event, Emitter<GameState> emit) {
    final slot = state.deckSlots.firstWhere(
      (deck) => deck.id == event.slotId,
      orElse: () => state.deckSlots.first,
    );
    emit(
      state.copyWith(
        activeDeckId: slot.id,
        deckAttackers: cardsByIds(attackers, slot.attackers),
        deckDefenders: cardsByIds(defenders, slot.defenders),
        deckActions: actionCardsByIds(slot.actions),
      ),
    );
  }

  Future<void> _onDeckCreated(
    DeckCreated event,
    Emitter<GameState> emit,
  ) async {
    final slot = StoredDeckSlot(
      id: 'slot-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Squad ${state.deckSlots.length + 1}',
      attackers: const [],
      defenders: const [],
      actions: const [],
    );
    final slots = [...state.deckSlots, slot];
    await _storage.saveDecks(slots);
    emit(
      state.copyWith(
        deckSlots: slots,
        activeDeckId: slot.id,
        deckAttackers: const [],
        deckDefenders: const [],
        deckActions: const [],
      ),
    );
  }

  Future<void> _onTutorialReset(
    TutorialReset event,
    Emitter<GameState> emit,
  ) async {
    await _storage.resetTutorial();
    emit(state.copyWith(tutorialSeen: {}));
  }

  Future<void> _onTutorialSeenMarked(
    TutorialSeenMarked event,
    Emitter<GameState> emit,
  ) async {
    final seen = {...state.tutorialSeen, event.keyName};
    emit(state.copyWith(tutorialSeen: seen));
    await _storage.saveTutorialSeen(seen);
  }

  Future<void> _onTutorialsSkippedAll(
    TutorialsSkippedAll event,
    Emitter<GameState> emit,
  ) async {
    final seen = tutorialKeys.toSet();
    emit(state.copyWith(tutorialSeen: seen));
    await _storage.saveTutorialSeen(seen);
  }

  void _onMatchStarted(MatchStarted event, Emitter<GameState> emit) {
    final oppAttackers = [...attackers]..shuffle(_random);
    final oppDefenders = [...defenders]..shuffle(_random);
    final oppActions = [...actionCards]..shuffle(_random);
    emit(
      _resetMatch(state).copyWith(
        phase: MatchPhase.toss,
        currentRound: 1,
        opponentAttackers: oppAttackers.take(2).toList(),
        opponentDefenders: oppDefenders.take(2).toList(),
        opponentActions: oppActions.take(6).toList(),
      ),
    );
  }

  void _onTossResolved(TossResolved event, Emitter<GameState> emit) {
    if (state.tossChoice == null) return;
    final result = _random.nextBool() ? 'heads' : 'tails';
    emit(
      state.copyWith(
        tossResult: result,
        playerWonToss: result == state.tossChoice,
        phase: MatchPhase.tossResult,
      ),
    );
  }

  void _onRoleChosen(RoleChosen event, Emitter<GameState> emit) {
    emit(
      state.copyWith(
        playerAttacking: event.playerAttacking,
        initialAttackingChoice: event.playerAttacking,
        phase: MatchPhase.scenario,
        currentScenario: null,
      ),
    );
  }

  void _onScenarioShown(ScenarioShown event, Emitter<GameState> emit) {
    final used = state.roundResults.map((round) => round.scenario.id).toSet();
    final available = scenarios
        .where((scenario) => !used.contains(scenario.id))
        .toList();
    final pool = available.isEmpty ? scenarios : available;
    emit(
      state.copyWith(
        currentScenario: pool[_random.nextInt(pool.length)],
        phase: MatchPhase.scenario,
      ),
    );
  }

  void _onMovePlayed(MovePlayed event, Emitter<GameState> emit) {
    final playerCard = state.selectedPlayerCard;
    final actionCard = state.selectedActionCard;
    final scenario = state.currentScenario;
    if (playerCard == null || actionCard == null || scenario == null) return;

    final oppPlayers = state.playerAttacking
        ? state.opponentDefenders
              .where((card) => !state.opponentRedCarded.contains(card.id))
              .toList()
        : state.opponentAttackers
              .where((card) => !state.opponentRedCarded.contains(card.id))
              .toList();
    final fallback = state.playerAttacking
        ? state.opponentDefenders.first
        : state.opponentAttackers.first;
    // Smarter pick: 70% of the time take the strongest available player,
    // otherwise a random one (keeps it unpredictable).
    final PlayerCard oppPlayer;
    if (oppPlayers.isEmpty) {
      oppPlayer = fallback;
    } else if (_random.nextDouble() < 0.7) {
      oppPlayer = oppPlayers.reduce((a, b) => a.rating >= b.rating ? a : b);
    } else {
      oppPlayer = oppPlayers[_random.nextInt(oppPlayers.length)];
    }

    // Action choice respects the opponent's role and the scenario.
    final oppDefending = state.playerAttacking;
    final relevantCategory = oppDefending
        ? ActionCategory.defense
        : ActionCategory.attack;
    final roleActions = state.opponentActions
        .where(
          (a) =>
              a.category == relevantCategory ||
              a.category == ActionCategory.special,
        )
        .toList();
    final actionPool = roleActions.isEmpty
        ? state.opponentActions
        : roleActions;
    final scenarioFavorsOpp = oppDefending
        ? scenario.defenseBonus > 8
        : scenario.attackBonus > 8;
    final ActionCard oppAction;
    if (scenarioFavorsOpp || _random.nextDouble() < 0.5) {
      // Lean into a strong scenario (or half the time) with the top action.
      oppAction = actionPool.reduce((a, b) => a.power >= b.power ? a : b);
    } else {
      oppAction = actionPool[_random.nextInt(actionPool.length)];
    }

    final attackerCard = state.playerAttacking ? playerCard : oppPlayer;
    final defenderCard = state.playerAttacking ? oppPlayer : playerCard;
    final attackAction = state.playerAttacking ? actionCard : oppAction;
    final defenseAction = state.playerAttacking ? oppAction : actionCard;
    final attackPower =
        attackerCard.rating +
        attackAction.power +
        scenario.attackBonus +
        _random.nextDouble() * 20;
    final defensePower =
        defenderCard.rating +
        defenseAction.power +
        scenario.defenseBonus +
        _random.nextDouble() * 20;
    final outcome = _resolveRound(
      attackPower,
      defensePower,
      attackAction,
      defenseAction,
    );

    final opponentRedCarded = [...state.opponentRedCarded];
    final redCarded = [...state.redCardedCards];
    if (outcome == RoundOutcome.redCard) {
      if (state.playerAttacking) {
        opponentRedCarded.add(defenderCard.id);
      } else {
        redCarded.add(defenderCard.id);
      }
    }

    final playerGoal = outcome == RoundOutcome.goal && state.playerAttacking;
    final opponentGoal = outcome == RoundOutcome.goal && !state.playerAttacking;
    final result = RoundResult(
      round: state.currentRound,
      scenario: scenario,
      playerAttacking: state.playerAttacking,
      attackerCard: attackerCard,
      defenderCard: defenderCard,
      attackAction: attackAction,
      defenseAction: defenseAction,
      outcome: outcome,
      attackPower: attackPower,
      defensePower: defensePower,
    );

    emit(
      state.copyWith(
        phase: MatchPhase.roundResult,
        playerScore: state.playerScore + (playerGoal ? 1 : 0),
        opponentScore: state.opponentScore + (opponentGoal ? 1 : 0),
        usedPlayerCards: [...state.usedPlayerCards, playerCard.id],
        usedActionCards: [...state.usedActionCards, actionCard.id],
        redCardedCards: redCarded,
        opponentRedCarded: opponentRedCarded,
        roundResults: [...state.roundResults, result],
      ),
    );
  }

  void _onRoundAdvanced(RoundAdvanced event, Emitter<GameState> emit) {
    if (state.currentRound >= 4) {
      emit(state.copyWith(phase: MatchPhase.matchEnd));
      return;
    }
    final nextRound = state.currentRound + 1;
    final initialAttack = state.initialAttackingChoice ?? state.playerAttacking;
    emit(
      state.copyWith(
        currentRound: nextRound,
        phase: MatchPhase.scenario,
        currentScenario: null,
        selectedPlayerCard: null,
        selectedActionCard: null,
        playerAttacking: nextRound.isOdd ? initialAttack : !initialAttack,
      ),
    );
  }

  void _onPenaltyKickConfirmed(
    PenaltyKickConfirmed event,
    Emitter<GameState> emit,
  ) {
    if (state.penaltyPhaseOver || state.penaltyPlayerDirection == null) return;
    final playerTaking = state.penaltyRound.isEven;
    final playerDir = state.penaltyPlayerDirection!;
    final aiDir = PenaltyDirection.values[_random.nextInt(3)];

    final shootDir = playerTaking ? playerDir : aiDir;
    final diveDir = playerTaking ? aiDir : playerDir;
    final scored = shootDir != diveDir; // goal when directions differ

    final kick = PenaltyKick(
      kickNumber: state.penaltyRound + 1,
      byPlayer: playerTaking,
      shootDirection: shootDir,
      diveDirection: diveDir,
      scored: scored,
    );
    final kicks = [...state.penaltyKicks, kick];
    final playerScore =
        state.penaltyPlayerScore + (playerTaking && scored ? 1 : 0);
    final opponentScore =
        state.penaltyOpponentScore + (!playerTaking && scored ? 1 : 0);

    var over = false;
    var suddenDeath = state.penaltySuddenDeath;
    String? winner = state.penaltyWinner;

    if (!suddenDeath) {
      if (_penaltyEarlyOut(kicks, playerScore, opponentScore)) {
        over = true;
        winner = playerScore > opponentScore ? 'player' : 'opponent';
      } else if (kicks.length >= 6) {
        if (playerScore != opponentScore) {
          over = true;
          winner = playerScore > opponentScore ? 'player' : 'opponent';
        } else {
          suddenDeath = true; // tied after 6 > sudden death
        }
      }
    } else {
      // In sudden death, check each completed pair (2 kicks)
      final sdDone = kicks.length - 6;
      if (sdDone > 0 && sdDone.isEven) {
        final pair = kicks.sublist(kicks.length - 2);
        final playerGoal = pair.any((k) => k.byPlayer && k.scored);
        final opponentGoal = pair.any((k) => !k.byPlayer && k.scored);
        if (playerGoal != opponentGoal) {
          over = true;
          winner = playerGoal ? 'player' : 'opponent';
        }
      }
    }

    emit(
      state.copyWith(
        penaltyKicks: kicks,
        penaltyPlayerScore: playerScore,
        penaltyOpponentScore: opponentScore,
        penaltyRound: state.penaltyRound + 1,
        penaltyPhaseOver: over,
        penaltyWinner: winner,
        penaltyPlayerDirection: null,
        penaltyKickPhase: 'result',
        penaltySuddenDeath: suddenDeath,
      ),
    );
  }

  bool _penaltyEarlyOut(
    List<PenaltyKick> kicks,
    int playerScore,
    int opponentScore,
  ) {
    final done = kicks.length;
    if (done >= 6) return false;
    var playerLeft = 0;
    var opponentLeft = 0;
    for (var i = done; i < 6; i++) {
      if (i.isEven) { playerLeft++; } else { opponentLeft++; }
    }
    return playerScore > opponentScore + opponentLeft ||
        opponentScore > playerScore + playerLeft;
  }

  Future<void> _onMatchFinished(
    MatchFinished event,
    Emitter<GameState> emit,
  ) async {
    final activeDeck = state.deckSlots
        .where((slot) => slot.id == state.activeDeckId)
        .firstOrNull;
    final historyEntry = MatchHistoryEntry(
      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
      deckName: activeDeck?.name ?? 'Unknown Deck',
      timestampIso: DateTime.now().toIso8601String(),
      resultLabel: _resultLabelForState(state),
      playerScore: state.playerScore,
      opponentScore: state.opponentScore,
      penaltyPlayerScore: state.penaltyKicks.isEmpty
          ? null
          : state.penaltyPlayerScore,
      penaltyOpponentScore: state.penaltyKicks.isEmpty
          ? null
          : state.penaltyOpponentScore,
      rounds: state.roundResults
          .map(
            (round) => MatchHistoryRound(
              round: round.round,
              scenarioTitle: round.scenario.title,
              outcomeLabel: outcomeLabel(round.outcome),
              playerAttacking: round.playerAttacking,
            ),
          )
          .toList(),
    );
    final history = [historyEntry, ...state.matchHistory].take(12).toList();
    emit(state.copyWith(phase: MatchPhase.finalResult, matchHistory: history));
    await _storage.saveMatchHistory(history);
  }

  RoundOutcome _resolveRound(
    double attackPower,
    double defensePower,
    ActionCard attackAction,
    ActionCard defenseAction,
  ) {
    if (defenseAction.risky && _random.nextDouble() < 0.12) {
      return RoundOutcome.redCard;
    }
    if (attackAction.risky && _random.nextDouble() < 0.12) {
      return RoundOutcome.foul;
    }
    final diff = attackPower - defensePower;
    final roll = _random.nextDouble();
    if (diff > 15) {
      if (roll < 0.75) return RoundOutcome.goal;
      if (roll < 0.95) return RoundOutcome.saved;
      return RoundOutcome.blocked;
    }
    if (diff > 5) {
      if (roll < 0.60) return RoundOutcome.goal;
      if (roll < 0.90) return RoundOutcome.saved;
      return RoundOutcome.missed;
    }
    if (diff > -5) {
      if (roll < 0.45) return RoundOutcome.goal;
      if (roll < 0.80) return RoundOutcome.saved;
      return _random.nextBool() ? RoundOutcome.missed : RoundOutcome.blocked;
    }
    if (diff > -15) {
      if (roll < 0.65) return RoundOutcome.saved;
      if (roll < 0.90) return RoundOutcome.blocked;
      return RoundOutcome.goal;
    }
    if (roll < 0.75) return RoundOutcome.saved;
    if (roll < 0.95) return RoundOutcome.blocked;
    return RoundOutcome.goal;
  }

  GameState _resetMatch(GameState old) => GameState.initial().copyWith(
    loading: false,
    deckSlots: old.deckSlots,
    activeDeckId: old.activeDeckId,
    deckAttackers: old.deckAttackers,
    deckDefenders: old.deckDefenders,
    deckActions: old.deckActions,
    coins: old.coins,
    ownedCardIds: old.ownedCardIds,
    ownedCardBackIds: old.ownedCardBackIds,
    equippedCardBackId: old.equippedCardBackId,
    matchHistory: old.matchHistory,
    tutorialSeen: old.tutorialSeen,
    pendingPackReveal: old.pendingPackReveal,
  );

  Future<void> _saveWallet({
    int? coins,
    List<String>? ownedCardIds,
    List<String>? ownedCardBackIds,
    String? equippedCardBackId,
  }) => _storage.saveWallet(
    WalletSnapshot(
      coins: coins ?? state.coins,
      ownedCardIds: ownedCardIds ?? state.ownedCardIds,
      ownedCardBackIds: ownedCardBackIds ?? state.ownedCardBackIds,
      equippedCardBackId: equippedCardBackId ?? state.equippedCardBackId,
    ),
  );

  StoredDeckSlot _hydratedSlot(StoredDeckSlot slot) => StoredDeckSlot(
    id: slot.id,
    name: slot.name,
    attackers: slot.attackers
        .where((id) => attackers.any((card) => card.id == id))
        .toList(),
    defenders: slot.defenders
        .where((id) => defenders.any((card) => card.id == id))
        .toList(),
    actions: slot.actions
        .where((id) => actionCards.any((card) => card.id == id))
        .toList(),
  );

  List<PlayerCard> _buildStarterPack() {
    final usedIds = <String>{};
    return [
      _pickCardForPack(attackers, excludeIds: usedIds),
      _pickCardForPack(attackers, excludeIds: usedIds),
      _pickCardForPack(defenders, excludeIds: usedIds),
      _pickCardForPack(defenders, excludeIds: usedIds),
      _pickCardForPack(goalkeepers, excludeIds: usedIds),
    ];
  }

  PlayerCard _pickCardForPack(List<PlayerCard> source, {Set<String>? excludeIds}) {
    final available = excludeIds == null
        ? source
        : source.where((card) => !excludeIds.contains(card.id)).toList();
    final poolSource = available.isEmpty ? source : available;
    final byTier = {
      CardTier.bronze: poolSource
          .where((card) => card.tier == CardTier.bronze)
          .toList(),
      CardTier.silver: poolSource
          .where((card) => card.tier == CardTier.silver)
          .toList(),
      CardTier.gold: poolSource.where((card) => card.tier == CardTier.gold).toList(),
      CardTier.platinum: poolSource
          .where((card) => card.tier == CardTier.platinum)
          .toList(),
    };
    final roll = _random.nextDouble();
    final tier = roll < 0.50
        ? CardTier.bronze
        : roll < 0.80
        ? CardTier.silver
        : roll < 0.95
        ? CardTier.gold
        : CardTier.platinum;
    final pool = byTier[tier];
    if (pool != null && pool.isNotEmpty) {
      final card = pool[_random.nextInt(pool.length)];
      excludeIds?.add(card.id);
      return card;
    }
    final card = poolSource[_random.nextInt(poolSource.length)];
    excludeIds?.add(card.id);
    return card;
  }

  String _resultLabelForState(GameState state) {
    if (state.playerScore > state.opponentScore) return 'Victory';
    if (state.playerScore < state.opponentScore) return 'Defeat';
    if (state.penaltyPlayerScore > state.penaltyOpponentScore) return 'Victory';
    if (state.penaltyPlayerScore < state.penaltyOpponentScore) return 'Defeat';
    return 'Draw';
  }
}
