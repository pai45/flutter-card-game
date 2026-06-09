import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/enums.dart';
import '../../config/tutorial_steps.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/match.dart';
import '../../models/packs.dart';
import '../../models/progression.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/card_helpers.dart';
import '../../utils/label_helpers.dart';
import 'game_event.dart';
import 'game_state.dart';

/// Probability that an attack with the given power advantage [diff]
/// (attackPower - defensePower) results in a goal.
///
/// This is the single source of truth for the honest odds shown on the Shot
/// Meter overlay. It MUST mirror the goal branches of [GameBloc._resolveRound];
/// keep the two in lockstep if the resolution table ever changes.
double goalChanceForDiff(double diff) {
  if (diff > 15) return 0.80;
  if (diff > 5) return 0.65;
  if (diff > -5) return 0.45;
  if (diff > -15) return 0.10;
  return 0.05;
}

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
    on<DirectCardPurchased>(_onDirectCardPurchased);
    on<PackOpened>(_onPackOpened);
    on<StarterPackClaimed>(_onStarterPackClaimed);
    on<StarterPackOpened>(_onStarterPackOpened);
    on<DailyDropClaimed>(_onDailyDropClaimed);
    on<ShopPackPurchased>(_onShopPackPurchased);
    on<CardBackPurchased>(_onCardBackPurchased);
    on<CardBackEquipped>(_onCardBackEquipped);
    on<PackRevealSeen>(
      (_, emit) => emit(state.copyWith(pendingPackReveal: null)),
    );
    on<MatchReset>((_, emit) => emit(_resetMatch(state)));
    on<MatchStarted>(_onMatchStarted);
    on<TossChoiceChanged>(
      (event, emit) => emit(state.copyWith(tossChoice: event.choice)),
    );
    on<TossResolved>(_onTossResolved);
    on<TossContinued>(
      (_, emit) => emit(state.copyWith(phase: MatchPhase.roleReveal)),
    );
    on<RoleChosen>(_onRoleChosen);
    on<RoleRevealAcknowledged>(
      (_, emit) => emit(
        state.copyWith(phase: MatchPhase.scenario, currentScenario: null),
      ),
    );
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
      (event, emit) =>
          emit(state.copyWith(penaltyPlayerDirection: event.direction)),
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
        onTimeout: () => <StoredDeckSlot>[],
      );
      developer.log('GameLoaded: Loaded decks');

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

      final progression = await _storage.loadProgression().timeout(
        const Duration(seconds: 2),
        onTimeout: PlayerProgression.initial,
      );
      developer.log(
        'GameLoaded: Loaded progression (level ${progression.playerLevel})',
      );

      final starterPackClaimed = await _storage
          .loadStarterPackClaimed()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      developer.log(
        'GameLoaded: Loaded starter pack status: $starterPackClaimed',
      );

      final wallet = await _storage.loadWallet().timeout(
        const Duration(seconds: 2),
        onTimeout: WalletSnapshot.initial,
      );
      developer.log('GameLoaded: Loaded wallet');

      var ownedPlayerIds = _validPlayerIds({...owned, ...wallet.ownedCardIds});
      var ownedActionIds = _validActionIds(wallet.ownedActionCardIds);
      var safeSlots = slots.map(_hydratedSlot).toList();
      for (final slot in safeSlots) {
        ownedPlayerIds = _validPlayerIds({
          ...ownedPlayerIds,
          ...slot.attackers,
          ...slot.defenders,
        });
        ownedActionIds = _validActionIds({...ownedActionIds, ...slot.actions});
      }

      var migratedProgression = progression;
      var migratedStarterClaimed = starterPackClaimed;
      var coins = wallet.coins;
      final dailyDropLastClaimedAt = wallet.dailyDropLastClaimedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              wallet.dailyDropLastClaimedAtMillis!,
            );
      final activeBeforeStarter = safeSlots.firstOrNull;
      final needsFallbackDeck =
          activeBeforeStarter == null || !_isLegalSlot(activeBeforeStarter);

      if (needsFallbackDeck) {
        developer.log('GameLoaded: Preparing fallback deck');
        safeSlots = defaultDeckSlots.map(_hydratedSlot).toList();
        for (final slot in safeSlots) {
          ownedPlayerIds = _validPlayerIds({
            ...ownedPlayerIds,
            ...slot.attackers,
            ...slot.defenders,
            if (slot.keeper != null) slot.keeper!,
          });
          ownedActionIds = _validActionIds({
            ...ownedActionIds,
            ...slot.actions,
          });
        }
        await _storage.saveDecks(safeSlots);
        await _storage.saveOwnedCards(ownedPlayerIds);
      }

      final active = safeSlots.first;
      await _storage.saveOwnedCards(ownedPlayerIds);
      await _storage.saveWallet(
        WalletSnapshot(
          coins: coins,
          ownedCardIds: ownedPlayerIds,
          ownedActionCardIds: ownedActionIds,
          ownedCardBackIds: wallet.ownedCardBackIds.contains('default')
              ? wallet.ownedCardBackIds
              : ['default', ...wallet.ownedCardBackIds],
          equippedCardBackId: wallet.equippedCardBackId,
          dailyDropLastClaimedAtMillis: wallet.dailyDropLastClaimedAtMillis,
        ),
      );

      developer.log('GameLoaded: Emitting state');
      emit(
        state.copyWith(
          loading: false,
          deckSlots: safeSlots,
          activeDeckId: active.id,
          deckAttackers: cardsByIds(attackers, active.attackers),
          deckDefenders: cardsByIds(defenders, active.defenders),
          deckActions: actionCardsByIds(active.actions),
          deckKeeper: _keeperOf(active),
          coins: coins,
          ownedCardIds: ownedPlayerIds,
          ownedActionCardIds: ownedActionIds,
          ownedCardBackIds: wallet.ownedCardBackIds.contains('default')
              ? wallet.ownedCardBackIds
              : ['default', ...wallet.ownedCardBackIds],
          equippedCardBackId: wallet.equippedCardBackId,
          matchHistory: history,
          tutorialSeen: seen,
          pendingPackReveal: null,
          starterPackClaimed: migratedStarterClaimed,
          dailyDropLastClaimedAt: dailyDropLastClaimedAt,
          progression: migratedProgression,
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

  Future<void> _onCoinsAdded(CoinsAdded event, Emitter<GameState> emit) async {
    final coins = state.coins + event.amount;
    emit(state.copyWith(coins: coins));
    await _saveWallet(coins: coins);
  }

  Future<void> _onCoinsSpent(CoinsSpent event, Emitter<GameState> emit) async {
    if (state.coins < event.amount) return;
    final coins = state.coins - event.amount;
    emit(state.copyWith(coins: coins));
    await _saveWallet(coins: coins);
  }

  Future<void> _onCardPurchased(
    CardPurchased event,
    Emitter<GameState> emit,
  ) async {
    await _purchaseDirectCard(
      cardId: event.cardId,
      price: 0,
      spendCoins: false,
      emit: emit,
    );
  }

  Future<void> _onDirectCardPurchased(
    DirectCardPurchased event,
    Emitter<GameState> emit,
  ) async {
    await _purchaseDirectCard(
      cardId: event.cardId,
      price: event.price,
      spendCoins: event.spendCoins,
      emit: emit,
    );
  }

  Future<void> _onPackOpened(PackOpened event, Emitter<GameState> emit) async {
    final rolledCards = cardsByIds(allPlayerCards, event.rolledCardIds);
    final result = PackResult(
      playerCards: rolledCards,
      actionCards: const [],
      xpGained: rolledCards.fold<int>(
        0,
        (sum, card) => sum + playerCardXp(card),
      ),
    );
    final newCardCount = rolledCards
        .where((card) => !state.ownedCardIds.contains(card.id))
        .length;
    await _unlockPack(
      result: result,
      emit: emit,
      coinDelta: event.refund,
      revealBuilder: (levels) => PackRevealData.shop(
        packName: event.packName,
        result: result,
        refund: event.refund,
        newCardCount: newCardCount,
        levelsGained: levels,
      ),
    );
  }

  Future<void> _onStarterPackClaimed(
    StarterPackClaimed event,
    Emitter<GameState> emit,
  ) async {
    emit(state.copyWith(starterPackClaimed: true));
    await _storage.saveStarterPackClaimed();
  }

  Future<void> _onStarterPackOpened(
    StarterPackOpened event,
    Emitter<GameState> emit,
  ) async {
    if (state.starterPackClaimed) return;
    final result = buildStarterPack(attackers, defenders, actionCards);
    final slot = _starterDeckSlot(
      result,
      id: state.activeDeckId,
      name: state.deckSlots.firstOrNull?.name ?? 'Starter Squad',
    );
    await _unlockPack(
      result: result,
      emit: emit,
      starterClaimed: true,
      equippedSlot: slot,
      revealBuilder: (levels) =>
          PackRevealData.starter(result: result, levelsGained: levels),
    );
    await _storage.saveStarterPackClaimed();
  }

  Future<void> _onDailyDropClaimed(
    DailyDropClaimed event,
    Emitter<GameState> emit,
  ) async {
    if (!dailyDropStatus(state.dailyDropLastClaimedAt).ready) return;
    final result = rollDailyDrop(
      [...attackers, ...defenders],
      actionCards,
      random: _random,
    );
    final claimedAt = DateTime.now();
    await _unlockPack(
      result: result,
      emit: emit,
      dailyDropLastClaimedAt: claimedAt,
      revealBuilder: (levels) =>
          PackRevealData.daily(result: result, levelsGained: levels),
    );
  }

  Future<void> _onShopPackPurchased(
    ShopPackPurchased event,
    Emitter<GameState> emit,
  ) async {
    final pack = getProgressionPack(event.packId);
    if (pack == null) return;
    if (event.spendCoins && state.coins < pack.price) return;
    if (pack.id == starterPackId && state.starterPackClaimed) return;

    final result = pack.id == starterPackId
        ? buildStarterPack(attackers, defenders, actionCards)
        : rollPack(
            pack,
            [...attackers, ...defenders],
            actionCards,
            random: _random,
          );
    final newCardCount =
        result.playerCards
            .where((card) => !state.ownedCardIds.contains(card.id))
            .length +
        result.actionCards
            .where((card) => !state.ownedActionCardIds.contains(card.id))
            .length;

    await _unlockPack(
      result: result,
      emit: emit,
      coinDelta: event.spendCoins ? -pack.price : 0,
      starterClaimed: pack.id == starterPackId ? true : null,
      equippedSlot: pack.id == starterPackId
          ? _starterDeckSlot(
              result,
              id: state.activeDeckId,
              name: state.deckSlots.firstOrNull?.name ?? 'Starter Squad',
            )
          : null,
      revealBuilder: (levels) => PackRevealData.shop(
        packName: pack.name,
        result: result,
        refund: 0,
        newCardCount: newCardCount,
        levelsGained: levels,
      ),
    );
    if (pack.id == starterPackId) await _storage.saveStarterPackClaimed();
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
        deckKeeper: _keeperOf(cleaned),
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
        deckKeeper: _keeperOf(slot),
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
        deckKeeper: null,
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
    if (!state.deckReady) return;
    final opponent = generateOpponentDeck(
      state.progression.playerLevel,
      attackers,
      defenders,
      actionCards,
      random: _random,
    );
    emit(
      _resetMatch(state).copyWith(
        phase: MatchPhase.toss,
        currentRound: 1,
        opponentAttackers: opponent.attackers,
        opponentDefenders: opponent.defenders,
        opponentActions: opponent.actions,
      ),
    );
  }

  void _onTossResolved(TossResolved event, Emitter<GameState> emit) {
    if (state.tossChoice == null) return;
    final result = _random.nextBool() ? 'heads' : 'tails';
    final playerWon = result == state.tossChoice;
    if (playerWon) {
      // Winner picks their role on the toss-result screen (RoleChosen).
      emit(
        state.copyWith(
          tossResult: result,
          playerWonToss: true,
          phase: MatchPhase.tossResult,
        ),
      );
      return;
    }
    // Player lost: the CPU picks its role now, and the player gets the opposite.
    // The resulting role is revealed in MatchPhase.roleReveal after CONTINUE.
    final cpuAttacks = _random.nextBool();
    emit(
      state.copyWith(
        tossResult: result,
        playerWonToss: false,
        playerAttacking: !cpuAttacks,
        initialAttackingChoice: !cpuAttacks,
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
    final PlayerCard oppPlayer;
    if (oppPlayers.isEmpty) {
      oppPlayer = fallback;
    } else {
      oppPlayer = chooseOpponentPlayer(
        oppPlayers,
        state.progression.playerLevel,
        random: _random,
      );
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
    if (scenarioFavorsOpp &&
        _random.nextDouble() < cpuSmartness(state.progression.playerLevel)) {
      oppAction = actionPool.reduce((a, b) => a.power >= b.power ? a : b);
    } else {
      oppAction = chooseOpponentAction(
        actionPool,
        state.progression.playerLevel,
        random: _random,
      );
    }

    final attackerCard = state.playerAttacking ? playerCard : oppPlayer;
    final defenderCard = state.playerAttacking ? oppPlayer : playerCard;
    final attackAction = state.playerAttacking ? actionCard : oppAction;
    final defenseAction = state.playerAttacking ? oppAction : actionCard;
    // The player's swing comes from the Shot Meter when provided; the opponent
    // always rolls randomly. A null surge (reduced-motion bypass) falls back to
    // a random roll, leaving the original behaviour unchanged.
    final playerSwing = event.playerSurge ?? _random.nextDouble() * 20;
    final oppSwing = _random.nextDouble() * 20;
    final attackSwing = state.playerAttacking ? playerSwing : oppSwing;
    final defenseSwing = state.playerAttacking ? oppSwing : playerSwing;
    final attackPower =
        attackerCard.rating +
        attackAction.power +
        scenario.attackBonus +
        attackSwing;
    final defensePower =
        defenderCard.rating +
        defenseAction.power +
        scenario.defenseBonus +
        defenseSwing;
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
        phase: MatchPhase.roleReveal,
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
      if (i.isEven) {
        playerLeft++;
      } else {
        opponentLeft++;
      }
    }
    return playerScore > opponentScore + opponentLeft ||
        opponentScore > playerScore + playerLeft;
  }

  Future<void> _onMatchFinished(
    MatchFinished event,
    Emitter<GameState> emit,
  ) async {
    final wentToPenalties = state.penaltyKicks.isNotEmpty;
    final resultLabel = _resultLabelForState(state);
    final xpDelta = calculateMatchXP(
      resultLabel: resultLabel,
      playerScore: state.playerScore,
      opponentScore: state.opponentScore,
      wentToPenalties: wentToPenalties,
    );
    final (:updated, :levelsGained) = state.progression.applyXP(xpDelta);
    final coins = state.coins + coinsForResult(resultLabel);

    final activeDeck = state.deckSlots
        .where((slot) => slot.id == state.activeDeckId)
        .firstOrNull;
    final historyEntry = MatchHistoryEntry(
      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
      deckName: activeDeck?.name ?? 'Unknown Deck',
      timestampIso: DateTime.now().toIso8601String(),
      resultLabel: resultLabel,
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
      xpEarned: xpDelta,
    );
    final history = [historyEntry, ...state.matchHistory].take(12).toList();
    emit(
      state.copyWith(
        phase: MatchPhase.finalResult,
        matchHistory: history,
        coins: coins,
        progression: updated,
        previousProgression: state.progression,
        pendingLevelUps: levelsGained,
        lastMatchXP: xpDelta,
      ),
    );
    await _storage.saveMatchHistory(history);
    await _storage.saveProgression(updated);
    await _saveWallet(coins: coins);
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
      if (roll < 0.80) return RoundOutcome.goal;
      if (roll < 0.95) return RoundOutcome.saved;
      return RoundOutcome.blocked;
    }
    if (diff > 5) {
      if (roll < 0.65) return RoundOutcome.goal;
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

  Future<void> _purchaseDirectCard({
    required String cardId,
    required int price,
    required bool spendCoins,
    required Emitter<GameState> emit,
  }) async {
    final playerCard = allPlayerCards
        .where((card) => card.id == cardId)
        .firstOrNull;
    final actionCard = actionCards
        .where((card) => card.id == cardId)
        .firstOrNull;
    if (playerCard == null && actionCard == null) return;
    if (playerCard != null && state.ownedCardIds.contains(cardId)) return;
    if (actionCard != null && state.ownedActionCardIds.contains(cardId)) return;
    if (spendCoins && state.coins < price) return;

    final result = playerCard != null
        ? singlePlayerUnlock(playerCard)
        : singleActionUnlock(actionCard!);
    await _unlockPack(
      result: result,
      emit: emit,
      coinDelta: spendCoins ? -price : 0,
      revealBuilder: (levels) =>
          PackRevealData.direct(result: result, levelsGained: levels),
    );
  }

  Future<void> _unlockPack({
    required PackResult result,
    required Emitter<GameState> emit,
    required PackRevealData Function(List<int> levelsGained) revealBuilder,
    int coinDelta = 0,
    DateTime? dailyDropLastClaimedAt,
    bool? starterClaimed,
    StoredDeckSlot? equippedSlot,
  }) async {
    final applied = _applyPackSnapshot(
      result: result,
      ownedPlayerIds: state.ownedCardIds,
      ownedActionIds: state.ownedActionCardIds,
      progression: state.progression,
    );
    final coins = max(0, state.coins + coinDelta);
    final slots = equippedSlot == null
        ? state.deckSlots
        : _replaceActiveSlot(state.deckSlots, equippedSlot);
    final activeSlot =
        equippedSlot ??
        slots.where((slot) => slot.id == state.activeDeckId).firstOrNull ??
        slots.firstOrNull;

    emit(
      state.copyWith(
        deckSlots: slots,
        activeDeckId: activeSlot?.id ?? state.activeDeckId,
        deckAttackers: activeSlot == null
            ? state.deckAttackers
            : cardsByIds(attackers, activeSlot.attackers),
        deckDefenders: activeSlot == null
            ? state.deckDefenders
            : cardsByIds(defenders, activeSlot.defenders),
        deckActions: activeSlot == null
            ? state.deckActions
            : actionCardsByIds(activeSlot.actions),
        deckKeeper: activeSlot == null
            ? state.deckKeeper
            : _keeperOf(activeSlot),
        coins: coins,
        ownedCardIds: applied.ownedPlayerIds,
        ownedActionCardIds: applied.ownedActionIds,
        pendingPackReveal: revealBuilder(applied.levelsGained),
        starterPackClaimed: starterClaimed ?? state.starterPackClaimed,
        dailyDropLastClaimedAt:
            dailyDropLastClaimedAt ?? state.dailyDropLastClaimedAt,
        progression: applied.progression,
        previousProgression: state.progression,
        pendingLevelUps: applied.levelsGained,
        lastMatchXP: result.xpGained,
      ),
    );

    await _storage.saveOwnedCards(applied.ownedPlayerIds);
    if (equippedSlot != null) await _storage.saveDecks(slots);
    await _storage.saveProgression(applied.progression);
    await _saveWallet(
      coins: coins,
      ownedCardIds: applied.ownedPlayerIds,
      ownedActionCardIds: applied.ownedActionIds,
      dailyDropLastClaimedAt: dailyDropLastClaimedAt,
    );
  }

  ({
    List<String> ownedPlayerIds,
    List<String> ownedActionIds,
    PlayerProgression progression,
    List<int> levelsGained,
  })
  _applyPackSnapshot({
    required PackResult result,
    required List<String> ownedPlayerIds,
    required List<String> ownedActionIds,
    required PlayerProgression progression,
  }) {
    final nextPlayers = _validPlayerIds({
      ...ownedPlayerIds,
      ...result.playerCards.map((card) => card.id),
    });
    final nextActions = _validActionIds({
      ...ownedActionIds,
      ...result.actionCards.map((card) => card.id),
    });
    final (:updated, :levelsGained) = progression.applyXP(result.xpGained);
    return (
      ownedPlayerIds: nextPlayers,
      ownedActionIds: nextActions,
      progression: updated,
      levelsGained: levelsGained,
    );
  }

  GameState _resetMatch(GameState old) => GameState.initial().copyWith(
    loading: false,
    deckSlots: old.deckSlots,
    activeDeckId: old.activeDeckId,
    deckAttackers: old.deckAttackers,
    deckDefenders: old.deckDefenders,
    deckActions: old.deckActions,
    deckKeeper: old.deckKeeper,
    coins: old.coins,
    ownedCardIds: old.ownedCardIds,
    ownedActionCardIds: old.ownedActionCardIds,
    ownedCardBackIds: old.ownedCardBackIds,
    equippedCardBackId: old.equippedCardBackId,
    matchHistory: old.matchHistory,
    tutorialSeen: old.tutorialSeen,
    pendingPackReveal: old.pendingPackReveal,
    starterPackClaimed: old.starterPackClaimed,
    dailyDropLastClaimedAt: old.dailyDropLastClaimedAt,
    progression: old.progression,
  );

  Future<void> _saveWallet({
    int? coins,
    List<String>? ownedCardIds,
    List<String>? ownedActionCardIds,
    List<String>? ownedCardBackIds,
    String? equippedCardBackId,
    DateTime? dailyDropLastClaimedAt,
  }) => _storage.saveWallet(
    WalletSnapshot(
      coins: coins ?? state.coins,
      ownedCardIds: ownedCardIds ?? state.ownedCardIds,
      ownedActionCardIds: ownedActionCardIds ?? state.ownedActionCardIds,
      ownedCardBackIds: ownedCardBackIds ?? state.ownedCardBackIds,
      equippedCardBackId: equippedCardBackId ?? state.equippedCardBackId,
      dailyDropLastClaimedAtMillis:
          (dailyDropLastClaimedAt ?? state.dailyDropLastClaimedAt)
              ?.millisecondsSinceEpoch,
    ),
  );

  List<String> _validPlayerIds(Iterable<String> ids) => ids
      .where((id) => allPlayerCards.any((card) => card.id == id))
      .toSet()
      .toList();

  List<String> _validActionIds(Iterable<String> ids) => ids
      .where((id) => actionCards.any((card) => card.id == id))
      .toSet()
      .toList();

  bool _isLegalSlot(StoredDeckSlot slot) =>
      slot.attackers.length == 2 &&
      slot.defenders.length == 2 &&
      slot.actions.length == 6 &&
      slot.keeper != null &&
      goalkeepers.any((card) => card.id == slot.keeper);

  PlayerCard? _keeperOf(StoredDeckSlot slot) => slot.keeper == null
      ? null
      : goalkeepers.where((card) => card.id == slot.keeper).firstOrNull;

  StoredDeckSlot _starterDeckSlot(
    PackResult result, {
    required String id,
    required String name,
  }) => StoredDeckSlot(
    id: id,
    name: name,
    attackers: result.playerCards
        .where((card) => card.role == PlayerRole.attacker)
        .map((card) => card.id)
        .take(2)
        .toList(),
    defenders: result.playerCards
        .where((card) => card.role == PlayerRole.defender)
        .map((card) => card.id)
        .take(2)
        .toList(),
    actions: result.actionCards.map((card) => card.id).take(6).toList(),
    keeper: result.playerCards
        .where((card) => card.role == PlayerRole.goalkeeper)
        .map((card) => card.id)
        .firstOrNull,
  );

  List<StoredDeckSlot> _replaceActiveSlot(
    List<StoredDeckSlot> slots,
    StoredDeckSlot replacement,
  ) {
    if (slots.isEmpty) return [replacement];
    var replaced = false;
    final next = <StoredDeckSlot>[];
    for (final slot in slots) {
      if (slot.id == replacement.id) {
        next.add(replacement);
        replaced = true;
      } else {
        next.add(slot);
      }
    }
    return replaced ? next : [replacement, ...slots];
  }

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
    keeper: goalkeepers.any((card) => card.id == slot.keeper)
        ? slot.keeper
        : null,
  );

  String _resultLabelForState(GameState state) {
    if (state.playerScore > state.opponentScore) return 'Victory';
    if (state.playerScore < state.opponentScore) return 'Defeat';
    if (state.penaltyPlayerScore > state.penaltyOpponentScore) return 'Victory';
    if (state.penaltyPlayerScore < state.penaltyOpponentScore) return 'Defeat';
    return 'Draw';
  }
}
