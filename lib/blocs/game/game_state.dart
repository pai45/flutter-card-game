import '../../config/enums.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/match.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/packs.dart';
import '../../models/progression.dart';
import '../../utils/card_helpers.dart';

class PackRevealItem {
  const PackRevealItem.player(this.playerCard) : actionCard = null;
  const PackRevealItem.action(this.actionCard) : playerCard = null;

  final PlayerCard? playerCard;
  final ActionCard? actionCard;

  bool get isPlayer => playerCard != null;
  String get name => playerCard?.name ?? actionCard!.title;
  String get shortName => playerCard?.shortName ?? actionCard!.title;
  String get subtitle => playerCard?.position ?? actionCard!.category.name;
  int get rating => playerCard?.rating ?? actionCard!.power;
  CardTier get tier => playerCard?.tier ?? actionCard!.tier;
}

class PackRevealData {
  const PackRevealData({
    required this.playerCards,
    required this.actionCards,
    required this.headline,
    required this.statusLabel,
    required this.ctaLabel,
    required this.summaryLabel,
    required this.xpGained,
    required this.levelsGained,
    this.groupActionCards = false,
    this.maxAnimatedPlayerCards,
    this.detailLabel,
  });

  factory PackRevealData.starter({
    required PackResult result,
    required List<int> levelsGained,
  }) => PackRevealData(
    playerCards: result.playerCards,
    actionCards: result.actionCards,
    headline: 'STARTER\nPACK',
    statusLabel: 'UNLOCKED',
    ctaLabel: 'ENTER THE GAME',
    summaryLabel: '${result.cardCount} CARDS ADDED TO YOUR COLLECTION',
    xpGained: result.xpGained,
    levelsGained: levelsGained,
    groupActionCards: true,
    maxAnimatedPlayerCards: 5,
  );

  factory PackRevealData.shop({
    required String packName,
    required PackResult result,
    required int refund,
    required int newCardCount,
    required List<int> levelsGained,
  }) {
    final summaryLabel = refund > 0 || newCardCount < result.cardCount
        ? '${result.cardCount} CARDS REVEALED'
        : '${result.cardCount} CARDS ADDED TO YOUR COLLECTION';
    final detailLabel = refund > 0
        ? '$newCardCount NEW CARDS | +${_formatPackCount(refund)} COIN REFUND'
        : newCardCount < result.cardCount
        ? '$newCardCount NEW CARDS ADDED'
        : null;
    return PackRevealData(
      playerCards: result.playerCards,
      actionCards: result.actionCards,
      headline: packName.toUpperCase().replaceAll(' ', '\n'),
      statusLabel: 'PURCHASED',
      ctaLabel: 'CONTINUE',
      summaryLabel: summaryLabel,
      xpGained: result.xpGained,
      levelsGained: levelsGained,
      detailLabel: detailLabel,
    );
  }

  factory PackRevealData.daily({
    required PackResult result,
    required List<int> levelsGained,
  }) => PackRevealData(
    playerCards: result.playerCards,
    actionCards: result.actionCards,
    headline: 'DAILY\nDROP',
    statusLabel: 'CLAIMED',
    ctaLabel: 'CONTINUE',
    summaryLabel: '${result.cardCount} CARD ADDED TO YOUR COLLECTION',
    xpGained: result.xpGained,
    levelsGained: levelsGained,
  );

  factory PackRevealData.direct({
    required PackResult result,
    required List<int> levelsGained,
  }) => PackRevealData(
    playerCards: result.playerCards,
    actionCards: result.actionCards,
    headline: 'CARD\nUNLOCKED',
    statusLabel: 'PURCHASED',
    ctaLabel: 'CONTINUE',
    summaryLabel: '${result.cardCount} CARD ADDED TO YOUR COLLECTION',
    xpGained: result.xpGained,
    levelsGained: levelsGained,
  );

  final List<PlayerCard> playerCards;
  final List<ActionCard> actionCards;
  final String headline;
  final String statusLabel;
  final String ctaLabel;
  final String summaryLabel;
  final String? detailLabel;
  final int xpGained;
  final List<int> levelsGained;
  final bool groupActionCards;
  final int? maxAnimatedPlayerCards;

  List<PlayerCard> get cards => playerCards;
  List<PackRevealItem> get items => [
    for (final card in playerCards) PackRevealItem.player(card),
    for (final card in actionCards) PackRevealItem.action(card),
  ];
  List<PackRevealItem> get animatedItems => groupActionCards
      ? [
          for (final card in playerCards.take(
            maxAnimatedPlayerCards ?? playerCards.length,
          ))
            PackRevealItem.player(card),
        ]
      : items;
  List<PackRevealItem> get groupedActionItems => [
    for (final card in actionCards) PackRevealItem.action(card),
  ];
}

class GameState {
  const GameState({
    required this.loading,
    required this.deckSlots,
    required this.activeDeckId,
    required this.deckAttackers,
    required this.deckDefenders,
    required this.deckActions,
    required this.deckKeeper,
    required this.coins,
    required this.coinLedger,
    required this.ownedCardIds,
    required this.ownedActionCardIds,
    required this.ownedCardBackIds,
    required this.equippedCardBackId,
    required this.matchHistory,
    required this.tutorialSeen,
    required this.pendingPackReveal,
    required this.starterPackClaimed,
    required this.dailyDropLastClaimedAt,
    required this.phase,
    required this.currentRound,
    required this.playerScore,
    required this.opponentScore,
    required this.playerAttacking,
    required this.tossChoice,
    required this.tossResult,
    required this.playerWonToss,
    required this.initialAttackingChoice,
    required this.currentScenario,
    required this.selectedPlayerCard,
    required this.selectedActionCard,
    required this.usedPlayerCards,
    required this.usedActionCards,
    required this.redCardedCards,
    required this.roundResults,
    required this.opponentAttackers,
    required this.opponentDefenders,
    required this.opponentActions,
    required this.opponentRedCarded,
    required this.progression,
    required this.previousProgression,
    required this.pendingLevelUps,
    required this.lastMatchXP,
  });

  factory GameState.initial() => GameState(
    loading: true,
    deckSlots: defaultDeckSlots,
    activeDeckId: defaultDeckSlots.first.id,
    deckAttackers: cardsByIds(attackers, defaultDeckSlots.first.attackers),
    deckDefenders: cardsByIds(defenders, defaultDeckSlots.first.defenders),
    deckActions: actionCardsByIds(defaultDeckSlots.first.actions),
    deckKeeper: cardsByIds(
      goalkeepers,
      [defaultDeckSlots.first.keeper].whereType<String>().toList(),
    ).firstOrNull,
    coins: 0,
    coinLedger: const [],
    ownedCardIds: const [],
    ownedActionCardIds: const [],
    ownedCardBackIds: const ['default'],
    equippedCardBackId: 'default',
    matchHistory: const [],
    tutorialSeen: const {},
    pendingPackReveal: null,
    starterPackClaimed: false,
    dailyDropLastClaimedAt: null,
    phase: MatchPhase.idle,
    currentRound: 0,
    playerScore: 0,
    opponentScore: 0,
    playerAttacking: true,
    tossChoice: null,
    tossResult: null,
    playerWonToss: null,
    initialAttackingChoice: null,
    currentScenario: null,
    selectedPlayerCard: null,
    selectedActionCard: null,
    usedPlayerCards: const [],
    usedActionCards: const [],
    redCardedCards: const [],
    roundResults: const [],
    opponentAttackers: const [],
    opponentDefenders: const [],
    opponentActions: const [],
    opponentRedCarded: const [],
    progression: PlayerProgression.initial(),
    previousProgression: null,
    pendingLevelUps: const [],
    lastMatchXP: null,
  );

  final bool loading;
  final List<StoredDeckSlot> deckSlots;
  final String activeDeckId;
  final List<PlayerCard> deckAttackers;
  final List<PlayerCard> deckDefenders;
  final List<ActionCard> deckActions;
  final PlayerCard? deckKeeper;
  final int coins;
  final List<OzCoinLedgerEntry> coinLedger;
  final List<String> ownedCardIds;
  final List<String> ownedActionCardIds;
  final List<String> ownedCardBackIds;
  final String equippedCardBackId;
  final List<MatchHistoryEntry> matchHistory;
  final Set<String> tutorialSeen;
  final PackRevealData? pendingPackReveal;
  final bool starterPackClaimed;
  final DateTime? dailyDropLastClaimedAt;
  final MatchPhase phase;
  final int currentRound;
  final int playerScore;
  final int opponentScore;
  final bool playerAttacking;
  final String? tossChoice;
  final String? tossResult;
  final bool? playerWonToss;
  final bool? initialAttackingChoice;
  final ScenarioCard? currentScenario;
  final PlayerCard? selectedPlayerCard;
  final ActionCard? selectedActionCard;
  final List<String> usedPlayerCards;
  final List<String> usedActionCards;
  final List<String> redCardedCards;
  final List<RoundResult> roundResults;
  final List<PlayerCard> opponentAttackers;
  final List<PlayerCard> opponentDefenders;
  final List<ActionCard> opponentActions;
  final List<String> opponentRedCarded;
  final PlayerProgression progression;
  final PlayerProgression? previousProgression;
  final List<int> pendingLevelUps;
  final int? lastMatchXP;

  bool get hasLevelUp => pendingLevelUps.isNotEmpty;

  bool get deckReady =>
      deckAttackers.length == 2 &&
      deckDefenders.length == 2 &&
      deckActions.length == 6 &&
      deckKeeper != null &&
      deckAttackers.every((card) => ownedCardIds.contains(card.id)) &&
      deckDefenders.every((card) => ownedCardIds.contains(card.id)) &&
      deckActions.every((card) => ownedActionCardIds.contains(card.id)) &&
      ownedCardIds.contains(deckKeeper!.id);

  GameState copyWith({
    bool? loading,
    List<StoredDeckSlot>? deckSlots,
    String? activeDeckId,
    List<PlayerCard>? deckAttackers,
    List<PlayerCard>? deckDefenders,
    List<ActionCard>? deckActions,
    Object? deckKeeper = _sentinel,
    int? coins,
    List<OzCoinLedgerEntry>? coinLedger,
    List<String>? ownedCardIds,
    List<String>? ownedActionCardIds,
    List<String>? ownedCardBackIds,
    String? equippedCardBackId,
    List<MatchHistoryEntry>? matchHistory,
    Set<String>? tutorialSeen,
    Object? pendingPackReveal = _sentinel,
    bool? starterPackClaimed,
    Object? dailyDropLastClaimedAt = _sentinel,
    MatchPhase? phase,
    int? currentRound,
    int? playerScore,
    int? opponentScore,
    bool? playerAttacking,
    Object? tossChoice = _sentinel,
    Object? tossResult = _sentinel,
    Object? playerWonToss = _sentinel,
    Object? initialAttackingChoice = _sentinel,
    Object? currentScenario = _sentinel,
    Object? selectedPlayerCard = _sentinel,
    Object? selectedActionCard = _sentinel,
    List<String>? usedPlayerCards,
    List<String>? usedActionCards,
    List<String>? redCardedCards,
    List<RoundResult>? roundResults,
    List<PlayerCard>? opponentAttackers,
    List<PlayerCard>? opponentDefenders,
    List<ActionCard>? opponentActions,
    List<String>? opponentRedCarded,
    PlayerProgression? progression,
    Object? previousProgression = _sentinel,
    List<int>? pendingLevelUps,
    Object? lastMatchXP = _sentinel,
  }) => GameState(
    loading: loading ?? this.loading,
    deckSlots: deckSlots ?? this.deckSlots,
    activeDeckId: activeDeckId ?? this.activeDeckId,
    deckAttackers: deckAttackers ?? this.deckAttackers,
    deckDefenders: deckDefenders ?? this.deckDefenders,
    deckActions: deckActions ?? this.deckActions,
    deckKeeper: deckKeeper == _sentinel
        ? this.deckKeeper
        : deckKeeper as PlayerCard?,
    coins: coins ?? this.coins,
    coinLedger: coinLedger ?? this.coinLedger,
    ownedCardIds: ownedCardIds ?? this.ownedCardIds,
    ownedActionCardIds: ownedActionCardIds ?? this.ownedActionCardIds,
    ownedCardBackIds: ownedCardBackIds ?? this.ownedCardBackIds,
    equippedCardBackId: equippedCardBackId ?? this.equippedCardBackId,
    matchHistory: matchHistory ?? this.matchHistory,
    tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    pendingPackReveal: pendingPackReveal == _sentinel
        ? this.pendingPackReveal
        : pendingPackReveal as PackRevealData?,
    starterPackClaimed: starterPackClaimed ?? this.starterPackClaimed,
    dailyDropLastClaimedAt: dailyDropLastClaimedAt == _sentinel
        ? this.dailyDropLastClaimedAt
        : dailyDropLastClaimedAt as DateTime?,
    phase: phase ?? this.phase,
    currentRound: currentRound ?? this.currentRound,
    playerScore: playerScore ?? this.playerScore,
    opponentScore: opponentScore ?? this.opponentScore,
    playerAttacking: playerAttacking ?? this.playerAttacking,
    tossChoice: tossChoice == _sentinel
        ? this.tossChoice
        : tossChoice as String?,
    tossResult: tossResult == _sentinel
        ? this.tossResult
        : tossResult as String?,
    playerWonToss: playerWonToss == _sentinel
        ? this.playerWonToss
        : playerWonToss as bool?,
    initialAttackingChoice: initialAttackingChoice == _sentinel
        ? this.initialAttackingChoice
        : initialAttackingChoice as bool?,
    currentScenario: currentScenario == _sentinel
        ? this.currentScenario
        : currentScenario as ScenarioCard?,
    selectedPlayerCard: selectedPlayerCard == _sentinel
        ? this.selectedPlayerCard
        : selectedPlayerCard as PlayerCard?,
    selectedActionCard: selectedActionCard == _sentinel
        ? this.selectedActionCard
        : selectedActionCard as ActionCard?,
    usedPlayerCards: usedPlayerCards ?? this.usedPlayerCards,
    usedActionCards: usedActionCards ?? this.usedActionCards,
    redCardedCards: redCardedCards ?? this.redCardedCards,
    roundResults: roundResults ?? this.roundResults,
    opponentAttackers: opponentAttackers ?? this.opponentAttackers,
    opponentDefenders: opponentDefenders ?? this.opponentDefenders,
    opponentActions: opponentActions ?? this.opponentActions,
    opponentRedCarded: opponentRedCarded ?? this.opponentRedCarded,
    progression: progression ?? this.progression,
    previousProgression: previousProgression == _sentinel
        ? this.previousProgression
        : previousProgression as PlayerProgression?,
    pendingLevelUps: pendingLevelUps ?? this.pendingLevelUps,
    lastMatchXP: lastMatchXP == _sentinel
        ? this.lastMatchXP
        : lastMatchXP as int?,
  );
}

String _formatPackCount(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

const _sentinel = Object();
