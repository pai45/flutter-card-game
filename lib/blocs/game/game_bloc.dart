import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/enums.dart';
import '../../config/tutorial_steps.dart';
import '../../data/random_opponent_names.dart';
import '../../models/avatar_frame_option.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/grand_prix.dart' show formatLapTime;
import '../../models/match.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/packs.dart';
import '../../models/progression.dart';
import '../../models/streak.dart';
import '../../models/xp_ledger.dart';
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
    on<PredictionXpAdded>(_onPredictionXpAdded);
    on<CardPurchased>(_onCardPurchased);
    on<DirectCardPurchased>(_onDirectCardPurchased);
    on<PackOpened>(_onPackOpened);
    on<StarterPackClaimed>(_onStarterPackClaimed);
    on<StarterPackOpened>(_onStarterPackOpened);
    on<CricketStarterPackOpened>(_onCricketStarterPackOpened);
    on<BasketballStarterPackOpened>(_onBasketballStarterPackOpened);
    on<DailyDropClaimed>(_onDailyDropClaimed);
    on<ShopPackPurchased>(_onShopPackPurchased);
    on<CardBackPurchased>(_onCardBackPurchased);
    on<CardBackEquipped>(_onCardBackEquipped);
    on<AvatarFramePurchased>(_onAvatarFramePurchased);
    on<AvatarFrameEquipped>(_onAvatarFrameEquipped);
    on<ShopAvatarPurchased>(_onShopAvatarPurchased);
    on<ShopBannerPurchased>(_onShopBannerPurchased);
    on<PackRevealSeen>(
      (_, emit) => emit(state.copyWith(pendingPackReveal: null)),
    );
    on<StreakActivityRecorded>(_onStreakActivityRecorded);
    on<StreakCelebrationConsumed>(_onStreakCelebrationConsumed);
    on<StreakMilestoneClaimed>(_onStreakMilestoneClaimed);
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
    on<MatchFinished>(_onMatchFinished);
    on<ShootoutFinished>(_onShootoutFinished);
    on<GrandPrixFinished>(_onGrandPrixFinished);
    on<SuperOverFinished>(_onSuperOverFinished);
    on<BasketballFinished>(_onBasketballFinished);
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

      var streak = await _storage.loadStreak().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (streak == null) {
        streak = StreakSnapshot.seeded(DateTime.now());
        await _storage.saveStreak(streak);
      }
      developer.log('GameLoaded: Loaded daily streak');

      final starterPackClaimed = await _storage
          .loadStarterPackClaimed()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      final cricketStarterPackClaimed = await _storage
          .loadCricketStarterPackClaimed()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      final basketballStarterPackClaimed = await _storage
          .loadBasketballStarterPackClaimed()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      developer.log(
        'GameLoaded: Loaded starter pack status: $starterPackClaimed',
      );
      developer.log(
        'GameLoaded: Loaded cricket starter pack status: '
        '$cricketStarterPackClaimed',
      );
      developer.log(
        'GameLoaded: Loaded basketball starter pack status: '
        '$basketballStarterPackClaimed',
      );

      final wallet = await _storage.loadWallet().timeout(
        const Duration(seconds: 2),
        onTimeout: WalletSnapshot.initial,
      );
      developer.log('GameLoaded: Loaded wallet');
      var coinLedger = await _storage.loadCoinLedger().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <OzCoinLedgerEntry>[],
      );
      developer.log('GameLoaded: Loaded coin ledger');
      var xpLedger = await _storage.loadXpLedger().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <XpLedgerEntry>[],
      );
      developer.log('GameLoaded: Loaded XP ledger');

      var ownedPlayerIds = _validPlayerIds({...owned, ...wallet.ownedCardIds});
      var ownedActionIds = _validActionIds(wallet.ownedActionCardIds);
      var safeSlots = slots.map(_hydratedSlot).toList();
      for (final slot in safeSlots) {
        ownedPlayerIds = _validPlayerIds({
          ...ownedPlayerIds,
          ...slot.attackers,
          ...slot.defenders,
          ...slot.batsmen,
          ...slot.basketballPlayers,
          if (slot.keeper != null) slot.keeper!,
        });
        ownedActionIds = _validActionIds({...ownedActionIds, ...slot.actions});
      }

      var migratedProgression = progression;
      var migratedStarterClaimed = starterPackClaimed;
      var migratedCricketStarterClaimed = cricketStarterPackClaimed;
      var migratedBasketballStarterClaimed = basketballStarterPackClaimed;
      var coins = wallet.coins;
      if (coinLedger.isEmpty && coins > 0) {
        coinLedger = [_openingBalanceEntry(coins)];
        await _storage.saveCoinLedger(coinLedger);
      }
      if (xpLedger.isEmpty && progression.totalXP > 0) {
        xpLedger = [_openingXpEntry(progression.totalXP)];
        await _storage.saveXpLedger(xpLedger);
      }
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
            ...slot.batsmen,
            ...slot.basketballPlayers,
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
          ownedAvatarFrameIds: wallet.ownedAvatarFrameIds,
          equippedAvatarFrameId: wallet.equippedAvatarFrameId,
          ownedAvatarIds: wallet.ownedAvatarIds,
          ownedBannerIds: wallet.ownedBannerIds,
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
          deckBatsmen: cardsByIds(batsmen, active.batsmen),
          deckBasketballPlayers: cardsByIds(
            basketballPlayerCards,
            active.basketballPlayers,
          ),
          deckBasketballStarter: _basketballStarterOf(active),
          coins: coins,
          coinLedger: coinLedger,
          xpLedger: xpLedger,
          ownedCardIds: ownedPlayerIds,
          ownedActionCardIds: ownedActionIds,
          ownedCardBackIds: wallet.ownedCardBackIds.contains('default')
              ? wallet.ownedCardBackIds
              : ['default', ...wallet.ownedCardBackIds],
          equippedCardBackId: wallet.equippedCardBackId,
          ownedAvatarFrameIds: wallet.ownedAvatarFrameIds,
          equippedAvatarFrameId: wallet.equippedAvatarFrameId,
          ownedAvatarIds: wallet.ownedAvatarIds,
          ownedBannerIds: wallet.ownedBannerIds,
          matchHistory: history,
          tutorialSeen: seen,
          pendingPackReveal: null,
          starterPackClaimed: migratedStarterClaimed,
          cricketStarterPackClaimed: migratedCricketStarterClaimed,
          basketballStarterPackClaimed: migratedBasketballStarterClaimed,
          dailyDropLastClaimedAt: dailyDropLastClaimedAt,
          progression: migratedProgression,
          streak: streak,
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
    await _applyCoinDelta(
      delta: event.amount,
      emit: emit,
      source: event.source,
      type: event.type ?? _defaultPositiveType(event.source),
      title: event.title ?? _defaultCoinTitle(event.source, true),
      subtitle: event.subtitle,
    );
  }

  Future<void> _onStreakActivityRecorded(
    StreakActivityRecorded event,
    Emitter<GameState> emit,
  ) async {
    final now = DateTime.now();
    if (dateOnly(event.occurredAt).isAfter(dateOnly(now))) return;
    final next = state.streak.record(event.activity, event.occurredAt);
    if (identical(next, state.streak)) return;
    emit(state.copyWith(streak: next));
    await _storage.saveStreak(next);
  }

  Future<void> _onStreakCelebrationConsumed(
    StreakCelebrationConsumed event,
    Emitter<GameState> emit,
  ) async {
    if (state.streak.celebrationQueue.isEmpty) return;
    final next = state.streak.copyWith(
      celebrationQueue: state.streak.celebrationQueue.sublist(1),
    );
    emit(state.copyWith(streak: next));
    await _storage.saveStreak(next);
  }

  Future<void> _onStreakMilestoneClaimed(
    StreakMilestoneClaimed event,
    Emitter<GameState> emit,
  ) async {
    final milestone = streakMilestones
        .where((item) => item.days == event.days)
        .firstOrNull;
    if (milestone == null ||
        !state.streak.announcedMilestones.contains(milestone.days) ||
        state.streak.claimedMilestones.contains(milestone.days)) {
      return;
    }

    final claimed = {...state.streak.claimedMilestones, milestone.days};
    final remainingQueue = [
      for (final celebration in state.streak.celebrationQueue)
        if (!(celebration.type == StreakCelebrationType.milestone &&
            celebration.milestoneDays == milestone.days))
          celebration,
    ];
    final nextStreak = state.streak.copyWith(
      claimedMilestones: claimed,
      celebrationQueue: remainingQueue,
    );
    emit(state.copyWith(streak: nextStreak));
    await _storage.saveStreak(nextStreak);

    switch (milestone.rewardType) {
      case StreakRewardType.coins:
        await _applyCoinDelta(
          delta: milestone.coins!,
          emit: emit,
          source: OzCoinTransactionSource.streakReward,
          type: OzCoinTransactionType.earn,
          title: 'STREAK REWARD',
          subtitle: '${milestone.days} DAY MILESTONE',
        );
      case StreakRewardType.card:
        await _claimStreakCard(milestone, emit);
      case StreakRewardType.pack:
        await _claimStreakPack(milestone, emit);
    }
  }

  Future<void> _claimStreakCard(
    StreakMilestone milestone,
    Emitter<GameState> emit,
  ) async {
    final tier = milestone.cardTier!;
    final playerPool = allPlayerCards
        .where(
          (card) => card.tier == tier && !state.ownedCardIds.contains(card.id),
        )
        .toList();
    final actionPool = actionCards
        .where(
          (card) =>
              card.tier == tier && !state.ownedActionCardIds.contains(card.id),
        )
        .toList();
    if (playerPool.isEmpty && actionPool.isEmpty) {
      await _applyCoinDelta(
        delta: tier == CardTier.platinum ? 1500 : 500,
        emit: emit,
        source: OzCoinTransactionSource.duplicateRefund,
        type: OzCoinTransactionType.refund,
        title: 'STREAK CARD REFUND',
        subtitle: milestone.rewardLabel,
      );
      return;
    }
    final choosePlayer =
        playerPool.isNotEmpty && (actionPool.isEmpty || _random.nextBool());
    final result = choosePlayer
        ? singlePlayerUnlock(playerPool[_random.nextInt(playerPool.length)])
        : singleActionUnlock(actionPool[_random.nextInt(actionPool.length)]);
    await _unlockPack(
      result: result,
      emit: emit,
      xpSource: XpTransactionSource.streakReward,
      xpTitle: 'STREAK CARD REWARD',
      xpDetails: milestone.rewardLabel,
      revealBuilder: (levels) => PackRevealData.streakReward(
        rewardName: milestone.rewardLabel,
        result: result,
        levelsGained: levels,
      ),
    );
  }

  Future<void> _claimStreakPack(
    StreakMilestone milestone,
    Emitter<GameState> emit,
  ) async {
    final pack = getProgressionPack(milestone.packId!);
    if (pack == null) return;
    final result = rollPack(
      pack,
      [...attackers, ...defenders],
      actionCards,
      random: _random,
    );
    await _unlockPack(
      result: result,
      emit: emit,
      xpSource: XpTransactionSource.streakReward,
      xpTitle: 'STREAK PACK REWARD',
      xpDetails: milestone.rewardLabel,
      revealBuilder: (levels) => PackRevealData.streakReward(
        rewardName: milestone.rewardLabel,
        result: result,
        levelsGained: levels,
      ),
    );
  }

  /// The settlement reveal renders its own level-up moment, so this leaves
  /// [GameState.pendingLevelUps] untouched (that queue belongs to match flow).
  Future<void> _onPredictionXpAdded(
    PredictionXpAdded event,
    Emitter<GameState> emit,
  ) async {
    if (event.amount <= 0) return;
    final xp = _nextXpSnapshot(
      delta: event.amount,
      source: event.source,
      title: event.title,
      details: event.details ?? 'Settled prediction',
    );
    emit(
      state.copyWith(
        progression: xp.progression,
        previousProgression: state.progression,
        xpLedger: xp.ledger,
      ),
    );
    await _storage.saveProgression(xp.progression);
    await _storage.saveXpLedger(xp.ledger);
  }

  Future<void> _onCoinsSpent(CoinsSpent event, Emitter<GameState> emit) async {
    await _applyCoinDelta(
      delta: -event.amount,
      emit: emit,
      source: event.source,
      type: event.type ?? OzCoinTransactionType.spend,
      title: event.title ?? _defaultCoinTitle(event.source, false),
      subtitle: event.subtitle,
    );
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
      xpSource: XpTransactionSource.pack,
      xpTitle: 'PACK OPENED',
      xpDetails: event.packName,
      coinDelta: event.refund,
      coinSource: OzCoinTransactionSource.duplicateRefund,
      coinType: OzCoinTransactionType.refund,
      coinTitle: 'DUPLICATE REFUND',
      coinSubtitle: event.packName,
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
      xpSource: XpTransactionSource.pack,
      xpTitle: 'STARTER PACK',
      xpDetails: 'Starter squad unlocked',
      starterClaimed: true,
      equippedSlot: slot,
      revealBuilder: (levels) =>
          PackRevealData.starter(result: result, levelsGained: levels),
    );
    await _storage.saveStarterPackClaimed();
  }

  Future<void> _onCricketStarterPackOpened(
    CricketStarterPackOpened event,
    Emitter<GameState> emit,
  ) async {
    if (state.cricketStarterPackClaimed) return;
    final result = buildCricketStarterPack(
      cricketBattingCards,
      random: _random,
    );
    final slot = _cricketStarterDeckSlot(
      result,
      id: state.activeDeckId,
      name: state.deckSlots.firstOrNull?.name ?? 'Starter Squad',
    );
    await _unlockPack(
      result: result,
      emit: emit,
      xpSource: XpTransactionSource.pack,
      xpTitle: 'CRICKET STARTER PACK',
      xpDetails: 'Super Over batting deck unlocked',
      cricketStarterClaimed: true,
      equippedSlot: slot,
      revealBuilder: (levels) =>
          PackRevealData.cricketStarter(result: result, levelsGained: levels),
    );
    await _storage.saveCricketStarterPackClaimed();
  }

  Future<void> _onBasketballStarterPackOpened(
    BasketballStarterPackOpened event,
    Emitter<GameState> emit,
  ) async {
    if (state.basketballStarterPackClaimed) return;
    final result = buildBasketballStarterPack(
      basketballPlayerCards,
      random: _random,
    );
    final slot = _basketballStarterDeckSlot(
      result,
      id: state.activeDeckId,
      name: state.deckSlots.firstOrNull?.name ?? 'Starter Squad',
    );
    await _unlockPack(
      result: result,
      emit: emit,
      xpSource: XpTransactionSource.pack,
      xpTitle: 'BASKETBALL STARTER PACK',
      xpDetails: 'Hoop Duel roster deck unlocked',
      basketballStarterClaimed: true,
      equippedSlot: slot,
      revealBuilder: (levels) => PackRevealData.basketballStarter(
        result: result,
        levelsGained: levels,
      ),
    );
    await _storage.saveBasketballStarterPackClaimed();
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
      xpSource: XpTransactionSource.dailyDrop,
      xpTitle: 'DAILY DROP',
      xpDetails: 'Card reward claimed',
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
      xpSource: XpTransactionSource.pack,
      xpTitle: 'PACK OPENED',
      xpDetails: pack.name,
      coinDelta: event.spendCoins ? -pack.price : 0,
      coinSource: OzCoinTransactionSource.packPurchase,
      coinType: OzCoinTransactionType.spend,
      coinTitle: 'PACK PURCHASE',
      coinSubtitle: pack.name,
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

  Future<void> _onAvatarFramePurchased(
    AvatarFramePurchased event,
    Emitter<GameState> emit,
  ) async {
    if (state.ownedAvatarFrameIds.contains(event.frameId)) return;
    final frame = avatarFrameOptionById(event.frameId);
    if (frame == null || state.coins < frame.coinPrice) return;
    // Spend coins (with ledger entry), then unlock the frame.
    await _applyCoinDelta(
      delta: -frame.coinPrice,
      emit: emit,
      source: OzCoinTransactionSource.directCardPurchase,
      type: OzCoinTransactionType.spend,
      title: 'FRAME PURCHASE',
      subtitle: frame.label,
    );
    final owned = {...state.ownedAvatarFrameIds, event.frameId}.toList();
    emit(state.copyWith(ownedAvatarFrameIds: owned));
    await _saveWallet(ownedAvatarFrameIds: owned);
  }

  Future<void> _onAvatarFrameEquipped(
    AvatarFrameEquipped event,
    Emitter<GameState> emit,
  ) async {
    // An empty id un-equips (back to the default ring).
    if (event.frameId.isNotEmpty &&
        !state.ownedAvatarFrameIds.contains(event.frameId)) {
      return;
    }
    emit(state.copyWith(equippedAvatarFrameId: event.frameId));
    await _saveWallet(equippedAvatarFrameId: event.frameId);
  }

  Future<void> _onShopAvatarPurchased(
    ShopAvatarPurchased event,
    Emitter<GameState> emit,
  ) async {
    if (state.ownedAvatarIds.contains(event.avatarId)) return;
    if (state.coins < event.price) return;
    // Spend coins (with ledger entry), then add the avatar to the collection.
    await _applyCoinDelta(
      delta: -event.price,
      emit: emit,
      source: OzCoinTransactionSource.directCardPurchase,
      type: OzCoinTransactionType.spend,
      title: 'AVATAR PURCHASE',
      subtitle: event.name,
    );
    final owned = {...state.ownedAvatarIds, event.avatarId}.toList();
    emit(state.copyWith(ownedAvatarIds: owned));
    await _saveWallet(ownedAvatarIds: owned);
  }

  Future<void> _onShopBannerPurchased(
    ShopBannerPurchased event,
    Emitter<GameState> emit,
  ) async {
    if (state.ownedBannerIds.contains(event.bannerId)) return;
    if (state.coins < event.price) return;
    await _applyCoinDelta(
      delta: -event.price,
      emit: emit,
      source: OzCoinTransactionSource.directCardPurchase,
      type: OzCoinTransactionType.spend,
      title: 'BANNER PURCHASE',
      subtitle: event.name,
    );
    final owned = {...state.ownedBannerIds, event.bannerId}.toList();
    emit(state.copyWith(ownedBannerIds: owned));
    await _saveWallet(ownedBannerIds: owned);
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
        deckBatsmen: cardsByIds(batsmen, cleaned.batsmen),
        deckBasketballPlayers: cardsByIds(
          basketballPlayerCards,
          cleaned.basketballPlayers,
        ),
        deckBasketballStarter: _basketballStarterOf(cleaned),
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
        deckBatsmen: cardsByIds(batsmen, slot.batsmen),
        deckBasketballPlayers: cardsByIds(
          basketballPlayerCards,
          slot.basketballPlayers,
        ),
        deckBasketballStarter: _basketballStarterOf(slot),
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
        deckBatsmen: const [],
        deckBasketballPlayers: const [],
        deckBasketballStarter: null,
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

  Future<void> _applyCoinDelta({
    required int delta,
    required Emitter<GameState> emit,
    required OzCoinTransactionSource source,
    required OzCoinTransactionType type,
    required String title,
    String? subtitle,
  }) async {
    final snapshot = _nextCoinSnapshot(
      delta: delta,
      source: source,
      type: type,
      title: title,
      subtitle: subtitle,
    );
    if (snapshot == null) return;
    emit(state.copyWith(coins: snapshot.coins, coinLedger: snapshot.ledger));
    await _saveWallet(coins: snapshot.coins);
    await _storage.saveCoinLedger(snapshot.ledger);
  }

  ({int coins, List<OzCoinLedgerEntry> ledger})? _nextCoinSnapshot({
    required int delta,
    required OzCoinTransactionSource source,
    required OzCoinTransactionType type,
    required String title,
    String? subtitle,
  }) {
    if (delta == 0) return (coins: state.coins, ledger: state.coinLedger);
    final coins = state.coins + delta;
    if (coins < 0) return null;
    final now = DateTime.now();
    final entry = OzCoinLedgerEntry(
      id: 'coin-${now.microsecondsSinceEpoch}',
      timestamp: now,
      delta: delta,
      balanceAfter: coins,
      type: type,
      source: source,
      title: title,
      subtitle: subtitle,
    );
    return (coins: coins, ledger: [entry, ...state.coinLedger]);
  }

  ({
    PlayerProgression progression,
    List<int> levelsGained,
    List<XpLedgerEntry> ledger,
    int appliedDelta,
  })
  _nextXpSnapshot({
    required int delta,
    required XpTransactionSource source,
    required String title,
    String? details,
  }) {
    final applied = applyXpTransaction(
      progression: state.progression,
      ledger: state.xpLedger,
      delta: delta,
      source: source,
      title: title,
      details: details,
    );
    return (
      progression: applied.progression,
      levelsGained: applied.levelsGained,
      ledger: applied.ledger,
      appliedDelta: applied.appliedDelta,
    );
  }

  void _onMatchStarted(MatchStarted event, Emitter<GameState> emit) {
    if (!state.deckReady) return;
    final opponentName =
        event.opponentName ?? randomOpponentName(random: _random);
    final opponent = generateOpponentDeck(
      event.opponentLevel ?? state.progression.playerLevel,
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
        opponentName: opponentName,
      ),
    );
  }

  void _onTossResolved(TossResolved event, Emitter<GameState> emit) {
    // The player calls a face before the flip; the flip itself is random.
    // They win the toss only when the landed face matches their call.
    final result = _random.nextBool() ? 'heads' : 'tails';
    final playerWon = result == event.call;
    if (playerWon) {
      // Winner picks their role on the toss-result screen (RoleChosen).
      emit(
        state.copyWith(
          tossChoice: event.call,
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
        tossChoice: event.call,
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
      // A level score after 4 rounds is a draw — no penalties.
      add(MatchFinished());
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

  Future<void> _onMatchFinished(
    MatchFinished event,
    Emitter<GameState> emit,
  ) async {
    final resultLabel = _resultLabelForState(state);
    final xpDelta = calculateMatchXP(
      resultLabel: resultLabel,
      playerScore: state.playerScore,
      opponentScore: state.opponentScore,
    );
    final xp = _nextXpSnapshot(
      delta: xpDelta,
      source: XpTransactionSource.match,
      title: 'PITCH DUEL',
      details: '$resultLabel · ${state.playerScore}-${state.opponentScore}',
    );
    final coinReward = coinsForResult(resultLabel);
    final coinSnapshot = _nextCoinSnapshot(
      delta: coinReward,
      source: OzCoinTransactionSource.matchReward,
      type: OzCoinTransactionType.earn,
      title: 'MATCH REWARD',
      subtitle: resultLabel,
    );
    final coins = coinSnapshot?.coins ?? state.coins;
    final coinLedger = coinSnapshot?.ledger ?? state.coinLedger;

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
      xpEarned: xp.appliedDelta,
    );
    final history = [historyEntry, ...state.matchHistory].take(12).toList();
    final streak = state.streak.record(
      StreakActivity.pitchDuel,
      DateTime.now(),
    );
    emit(
      state.copyWith(
        phase: MatchPhase.finalResult,
        matchHistory: history,
        coins: coins,
        coinLedger: coinLedger,
        progression: xp.progression,
        previousProgression: state.progression,
        pendingLevelUps: xp.levelsGained,
        lastMatchXP: xp.appliedDelta,
        xpLedger: xp.ledger,
        streak: streak,
      ),
    );
    await _storage.saveMatchHistory(history);
    await _storage.saveProgression(xp.progression);
    await _storage.saveXpLedger(xp.ledger);
    await _saveWallet(coins: coins);
    await _storage.saveCoinLedger(coinLedger);
    await _storage.saveStreak(streak);
  }

  Future<void> _onShootoutFinished(
    ShootoutFinished event,
    Emitter<GameState> emit,
  ) async {
    final won = event.playerGoals > event.cpuGoals;
    final xpDelta = calculateShootoutXP(
      won: won,
      margin: (event.playerGoals - event.cpuGoals).abs(),
    );
    final xp = _nextXpSnapshot(
      delta: xpDelta,
      source: XpTransactionSource.shootout,
      title: 'PENALTY SHOOTOUT',
      details:
          '${won ? 'Victory' : 'Defeat'} · ${event.playerGoals}-${event.cpuGoals}',
    );
    final coinReward = shootoutCoins(won);
    final coinSnapshot = _nextCoinSnapshot(
      delta: coinReward,
      source: OzCoinTransactionSource.shootoutReward,
      type: OzCoinTransactionType.earn,
      title: 'SHOOTOUT REWARD',
      subtitle: won ? 'Victory' : 'Defeat',
    );
    final coins = coinSnapshot?.coins ?? state.coins;
    final coinLedger = coinSnapshot?.ledger ?? state.coinLedger;

    final activeDeck = state.deckSlots
        .where((slot) => slot.id == state.activeDeckId)
        .firstOrNull;
    final historyEntry = MatchHistoryEntry(
      id: 'shootout-${DateTime.now().microsecondsSinceEpoch}',
      mode: 'shootout',
      deckName: activeDeck?.name ?? 'Unknown Deck',
      timestampIso: DateTime.now().toIso8601String(),
      resultLabel: won ? 'Victory' : 'Defeat',
      playerScore: event.playerGoals,
      opponentScore: event.cpuGoals,
      rounds: const [],
      xpEarned: xp.appliedDelta,
    );
    final history = [historyEntry, ...state.matchHistory].take(12).toList();
    final streak = state.streak.record(
      StreakActivity.penaltyShootout,
      DateTime.now(),
    );
    emit(
      state.copyWith(
        matchHistory: history,
        coins: coins,
        coinLedger: coinLedger,
        progression: xp.progression,
        previousProgression: state.progression,
        pendingLevelUps: xp.levelsGained,
        lastMatchXP: xp.appliedDelta,
        xpLedger: xp.ledger,
        streak: streak,
      ),
    );
    await _storage.saveMatchHistory(history);
    await _storage.saveProgression(xp.progression);
    await _storage.saveXpLedger(xp.ledger);
    await _saveWallet(coins: coins);
    await _storage.saveCoinLedger(coinLedger);
    await _storage.saveStreak(streak);
  }

  Future<void> _onGrandPrixFinished(
    GrandPrixFinished event,
    Emitter<GameState> emit,
  ) async {
    final xp = _nextXpSnapshot(
      delta: event.xp,
      source: XpTransactionSource.grandPrix,
      title: 'GRAND PRIX DASH',
      details: 'P${event.position} · ${event.circuitName}',
    );
    final historyEntry = MatchHistoryEntry(
      id: 'grandprix-${DateTime.now().microsecondsSinceEpoch}',
      mode: 'grandprix',
      deckName: '${event.circuitName} · ${formatLapTime(event.lapTimeMs)}',
      timestampIso: DateTime.now().toIso8601String(),
      resultLabel: event.verdictLabel,
      playerScore: event.position,
      opponentScore: event.fieldSize,
      rounds: const [],
      xpEarned: xp.appliedDelta,
    );
    final history = [historyEntry, ...state.matchHistory].take(12).toList();
    emit(
      state.copyWith(
        matchHistory: history,
        progression: xp.progression,
        previousProgression: state.progression,
        pendingLevelUps: xp.levelsGained,
        lastMatchXP: xp.appliedDelta,
        xpLedger: xp.ledger,
      ),
    );
    await _storage.saveMatchHistory(history);
    await _storage.saveProgression(xp.progression);
    await _storage.saveXpLedger(xp.ledger);
  }

  Future<void> _onBasketballFinished(
    BasketballFinished event,
    Emitter<GameState> emit,
  ) async {
    final xp = _nextXpSnapshot(
      delta: event.xp,
      source: XpTransactionSource.basketball,
      title: 'HOOP DUEL',
      details:
          '${event.resultLabel} ${event.playerScore}-${event.cpuScore}'
          '${event.overtime ? ' (OT)' : ''}',
    );
    final historyEntry = MatchHistoryEntry(
      id: 'basketball-${DateTime.now().microsecondsSinceEpoch}',
      mode: 'basketball',
      deckName: 'HOOP DUEL · ${event.difficultyLabel}',
      timestampIso: DateTime.now().toIso8601String(),
      resultLabel: event.resultLabel,
      playerScore: event.playerScore,
      opponentScore: event.cpuScore,
      rounds: const [],
      xpEarned: xp.appliedDelta,
    );
    final history = [historyEntry, ...state.matchHistory].take(12).toList();
    emit(
      state.copyWith(
        matchHistory: history,
        progression: xp.progression,
        previousProgression: state.progression,
        pendingLevelUps: xp.levelsGained,
        lastMatchXP: xp.appliedDelta,
        xpLedger: xp.ledger,
      ),
    );
    await _storage.saveMatchHistory(history);
    await _storage.saveProgression(xp.progression);
    await _storage.saveXpLedger(xp.ledger);
  }

  Future<void> _onSuperOverFinished(
    SuperOverFinished event,
    Emitter<GameState> emit,
  ) async {
    final xp = _nextXpSnapshot(
      delta: event.xp,
      source: XpTransactionSource.superOver,
      title: 'SUPER OVER',
      details: '${event.runs} RUNS (${event.wickets} WKT)',
    );
    final activeDeck = state.deckSlots
        .where((slot) => slot.id == state.activeDeckId)
        .firstOrNull;
    final historyEntry = MatchHistoryEntry(
      id: 'superover-${DateTime.now().microsecondsSinceEpoch}',
      mode: 'super_over',
      deckName: activeDeck?.name ?? 'Unknown Deck',
      timestampIso: DateTime.now().toIso8601String(),
      resultLabel: event.wonChase == null
          ? 'Completed'
          : (event.wonChase! ? 'Victory' : 'Defeat'),
      playerScore: event.runs,
      opponentScore: event.wickets,
      rounds: const [],
      xpEarned: xp.appliedDelta,
    );
    final history = [historyEntry, ...state.matchHistory].take(12).toList();
    emit(
      state.copyWith(
        matchHistory: history,
        progression: xp.progression,
        previousProgression: state.progression,
        pendingLevelUps: xp.levelsGained,
        lastMatchXP: xp.appliedDelta,
        xpLedger: xp.ledger,
      ),
    );
    await _storage.saveMatchHistory(history);
    await _storage.saveProgression(xp.progression);
    await _storage.saveXpLedger(xp.ledger);
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
      xpSource: XpTransactionSource.cardUnlock,
      xpTitle: 'CARD UNLOCKED',
      xpDetails: playerCard?.shortName ?? actionCard!.title,
      coinDelta: spendCoins ? -price : 0,
      coinSource: OzCoinTransactionSource.directCardPurchase,
      coinType: OzCoinTransactionType.spend,
      coinTitle: 'CARD PURCHASE',
      coinSubtitle: playerCard?.shortName ?? actionCard!.title,
      revealBuilder: (levels) =>
          PackRevealData.direct(result: result, levelsGained: levels),
    );
  }

  Future<void> _unlockPack({
    required PackResult result,
    required Emitter<GameState> emit,
    required PackRevealData Function(List<int> levelsGained) revealBuilder,
    required XpTransactionSource xpSource,
    required String xpTitle,
    String? xpDetails,
    int coinDelta = 0,
    OzCoinTransactionSource coinSource = OzCoinTransactionSource.manual,
    OzCoinTransactionType? coinType,
    String? coinTitle,
    String? coinSubtitle,
    DateTime? dailyDropLastClaimedAt,
    bool? starterClaimed,
    bool? cricketStarterClaimed,
    bool? basketballStarterClaimed,
    StoredDeckSlot? equippedSlot,
  }) async {
    final ownedPlayerIds = _validPlayerIds({
      ...state.ownedCardIds,
      ...result.playerCards.map((card) => card.id),
      ...?equippedSlot?.batsmen,
      ...?equippedSlot?.basketballPlayers,
    });
    final ownedActionIds = _validActionIds({
      ...state.ownedActionCardIds,
      ...result.actionCards.map((card) => card.id),
    });
    final xp = _nextXpSnapshot(
      delta: result.xpGained,
      source: xpSource,
      title: xpTitle,
      details: xpDetails,
    );
    final coinSnapshot = _nextCoinSnapshot(
      delta: coinDelta,
      source: coinSource,
      type:
          coinType ??
          (coinDelta >= 0
              ? _defaultPositiveType(coinSource)
              : OzCoinTransactionType.spend),
      title: coinTitle ?? _defaultCoinTitle(coinSource, coinDelta >= 0),
      subtitle: coinSubtitle,
    );
    if (coinSnapshot == null) return;
    final coins = coinSnapshot.coins;
    final coinLedger = coinSnapshot.ledger;
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
        deckBatsmen: activeSlot == null
            ? state.deckBatsmen
            : cardsByIds(batsmen, activeSlot.batsmen),
        deckBasketballPlayers: activeSlot == null
            ? state.deckBasketballPlayers
            : cardsByIds(basketballPlayerCards, activeSlot.basketballPlayers),
        deckBasketballStarter: activeSlot == null
            ? state.deckBasketballStarter
            : _basketballStarterOf(activeSlot),
        coins: coins,
        coinLedger: coinLedger,
        ownedCardIds: ownedPlayerIds,
        ownedActionCardIds: ownedActionIds,
        pendingPackReveal: revealBuilder(xp.levelsGained),
        starterPackClaimed: starterClaimed ?? state.starterPackClaimed,
        cricketStarterPackClaimed:
            cricketStarterClaimed ?? state.cricketStarterPackClaimed,
        basketballStarterPackClaimed:
            basketballStarterClaimed ?? state.basketballStarterPackClaimed,
        dailyDropLastClaimedAt:
            dailyDropLastClaimedAt ?? state.dailyDropLastClaimedAt,
        progression: xp.progression,
        previousProgression: state.progression,
        pendingLevelUps: xp.levelsGained,
        lastMatchXP: xp.appliedDelta,
        xpLedger: xp.ledger,
      ),
    );

    await _storage.saveOwnedCards(ownedPlayerIds);
    if (equippedSlot != null) await _storage.saveDecks(slots);
    await _storage.saveProgression(xp.progression);
    await _storage.saveXpLedger(xp.ledger);
    await _saveWallet(
      coins: coins,
      ownedCardIds: ownedPlayerIds,
      ownedActionCardIds: ownedActionIds,
      dailyDropLastClaimedAt: dailyDropLastClaimedAt,
    );
    await _storage.saveCoinLedger(coinLedger);
  }

  GameState _resetMatch(GameState old) => GameState.initial().copyWith(
    loading: false,
    deckSlots: old.deckSlots,
    activeDeckId: old.activeDeckId,
    deckAttackers: old.deckAttackers,
    deckDefenders: old.deckDefenders,
    deckActions: old.deckActions,
    deckKeeper: old.deckKeeper,
    deckBatsmen: old.deckBatsmen,
    deckBasketballPlayers: old.deckBasketballPlayers,
    deckBasketballStarter: old.deckBasketballStarter,
    coins: old.coins,
    coinLedger: old.coinLedger,
    xpLedger: old.xpLedger,
    ownedCardIds: old.ownedCardIds,
    ownedActionCardIds: old.ownedActionCardIds,
    ownedCardBackIds: old.ownedCardBackIds,
    equippedCardBackId: old.equippedCardBackId,
    ownedAvatarFrameIds: old.ownedAvatarFrameIds,
    equippedAvatarFrameId: old.equippedAvatarFrameId,
    ownedAvatarIds: old.ownedAvatarIds,
    ownedBannerIds: old.ownedBannerIds,
    streak: old.streak,
    matchHistory: old.matchHistory,
    tutorialSeen: old.tutorialSeen,
    pendingPackReveal: old.pendingPackReveal,
    starterPackClaimed: old.starterPackClaimed,
    cricketStarterPackClaimed: old.cricketStarterPackClaimed,
    basketballStarterPackClaimed: old.basketballStarterPackClaimed,
    dailyDropLastClaimedAt: old.dailyDropLastClaimedAt,
    progression: old.progression,
  );

  Future<void> _saveWallet({
    int? coins,
    List<String>? ownedCardIds,
    List<String>? ownedActionCardIds,
    List<String>? ownedCardBackIds,
    String? equippedCardBackId,
    List<String>? ownedAvatarFrameIds,
    String? equippedAvatarFrameId,
    List<String>? ownedAvatarIds,
    List<String>? ownedBannerIds,
    DateTime? dailyDropLastClaimedAt,
  }) => _storage.saveWallet(
    WalletSnapshot(
      coins: coins ?? state.coins,
      ownedCardIds: ownedCardIds ?? state.ownedCardIds,
      ownedActionCardIds: ownedActionCardIds ?? state.ownedActionCardIds,
      ownedCardBackIds: ownedCardBackIds ?? state.ownedCardBackIds,
      equippedCardBackId: equippedCardBackId ?? state.equippedCardBackId,
      ownedAvatarFrameIds: ownedAvatarFrameIds ?? state.ownedAvatarFrameIds,
      equippedAvatarFrameId:
          equippedAvatarFrameId ?? state.equippedAvatarFrameId,
      ownedAvatarIds: ownedAvatarIds ?? state.ownedAvatarIds,
      ownedBannerIds: ownedBannerIds ?? state.ownedBannerIds,
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

  PlayerCard? _basketballStarterOf(StoredDeckSlot slot) {
    final roster = cardsByIds(basketballPlayerCards, slot.basketballPlayers);
    if (roster.isEmpty) return null;
    return roster
            .where((card) => card.id == slot.basketballStarter)
            .firstOrNull ??
        roster.first;
  }

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
    batsmen: _activeSlot()?.batsmen ?? const [],
    basketballPlayers: _activeSlot()?.basketballPlayers ?? const [],
    basketballStarter: _activeSlot()?.basketballStarter,
  );

  StoredDeckSlot _cricketStarterDeckSlot(
    PackResult result, {
    required String id,
    required String name,
  }) {
    final active = _activeSlot();
    return StoredDeckSlot(
      id: id,
      name: name,
      attackers: active?.attackers ?? const [],
      defenders: active?.defenders ?? const [],
      actions: active?.actions ?? const [],
      keeper: active?.keeper,
      batsmen: result.playerCards
          .where((card) => card.role == PlayerRole.batsman)
          .map((card) => card.id)
          .take(cricketStarterCardCount)
          .toList(),
      basketballPlayers: active?.basketballPlayers ?? const [],
      basketballStarter: active?.basketballStarter,
      chessFormation: active?.chessFormation,
    );
  }

  StoredDeckSlot _basketballStarterDeckSlot(
    PackResult result, {
    required String id,
    required String name,
  }) {
    final active = _activeSlot();
    final cards = [...result.playerCards]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return StoredDeckSlot(
      id: id,
      name: name,
      attackers: active?.attackers ?? const [],
      defenders: active?.defenders ?? const [],
      actions: active?.actions ?? const [],
      keeper: active?.keeper,
      batsmen: active?.batsmen ?? const [],
      basketballPlayers: result.playerCards
          .map((card) => card.id)
          .take(basketballStarterCardCount)
          .toList(),
      basketballStarter: cards.firstOrNull?.id,
      chessFormation: active?.chessFormation,
    );
  }

  StoredDeckSlot? _activeSlot() => state.deckSlots
      .where((slot) => slot.id == state.activeDeckId)
      .firstOrNull;

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

  StoredDeckSlot _hydratedSlot(StoredDeckSlot slot) {
    final basketballPlayers = slot.basketballPlayers
        .where((id) => basketballPlayerCards.any((card) => card.id == id))
        .toList();
    return StoredDeckSlot(
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
      batsmen: slot.batsmen
          .where((id) => batsmen.any((card) => card.id == id))
          .toList(),
      basketballPlayers: basketballPlayers,
      basketballStarter: basketballPlayers.contains(slot.basketballStarter)
          ? slot.basketballStarter
          : null,
      keeper: goalkeepers.any((card) => card.id == slot.keeper)
          ? slot.keeper
          : null,
      chessFormation: slot.chessFormation,
    );
  }

  String _resultLabelForState(GameState state) {
    if (state.playerScore > state.opponentScore) return 'Victory';
    if (state.playerScore < state.opponentScore) return 'Defeat';
    return 'Draw';
  }

  OzCoinLedgerEntry _openingBalanceEntry(int coins) {
    final now = DateTime.now();
    return OzCoinLedgerEntry(
      id: 'coin-opening-${now.microsecondsSinceEpoch}',
      timestamp: now,
      delta: coins,
      balanceAfter: coins,
      type: OzCoinTransactionType.openingBalance,
      source: OzCoinTransactionSource.openingBalance,
      title: 'OPENING BALANCE',
      subtitle: 'Wallet balance before coin tracking',
    );
  }

  XpLedgerEntry _openingXpEntry(int totalXp) {
    final now = DateTime.now();
    return XpLedgerEntry(
      id: 'xp-opening-${now.microsecondsSinceEpoch}',
      timestamp: now,
      delta: totalXp,
      balanceAfter: totalXp,
      type: XpTransactionType.openingBalance,
      source: XpTransactionSource.openingBalance,
      title: 'PREVIOUS PROGRESS',
      details: 'XP earned before history tracking',
    );
  }

  OzCoinTransactionType _defaultPositiveType(OzCoinTransactionSource source) {
    return switch (source) {
      OzCoinTransactionSource.shopTopUp => OzCoinTransactionType.topUp,
      OzCoinTransactionSource.openingBalance =>
        OzCoinTransactionType.openingBalance,
      OzCoinTransactionSource.duplicateRefund => OzCoinTransactionType.refund,
      _ => OzCoinTransactionType.earn,
    };
  }

  String _defaultCoinTitle(OzCoinTransactionSource source, bool positive) {
    return switch (source) {
      OzCoinTransactionSource.matchReward => 'MATCH REWARD',
      OzCoinTransactionSource.shootoutReward => 'SHOOTOUT REWARD',
      OzCoinTransactionSource.pickStake => 'PICK STAKE',
      OzCoinTransactionSource.pickPayout => 'PICK PAYOUT',
      OzCoinTransactionSource.packPurchase => 'PACK PURCHASE',
      OzCoinTransactionSource.duplicateRefund => 'DUPLICATE REFUND',
      OzCoinTransactionSource.directCardPurchase => 'CARD PURCHASE',
      OzCoinTransactionSource.shopTopUp => 'COIN TOP-UP',
      OzCoinTransactionSource.streakReward => 'STREAK REWARD',
      OzCoinTransactionSource.referralReward => 'FRIEND REFERRAL',
      OzCoinTransactionSource.quizEntry => 'FOOTBALL QUIZ ENTRY',
      OzCoinTransactionSource.footballBingoLifeline => 'BINGO LIFELINE',
      OzCoinTransactionSource.openingBalance => 'OPENING BALANCE',
      OzCoinTransactionSource.manual =>
        positive ? 'COINS ADDED' : 'COINS SPENT',
    };
  }
}
