import '../../config/enums.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/match.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/packs.dart';
import '../../models/progression.dart';
import '../../models/streak.dart';
import '../../models/xp_ledger.dart';
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

  factory PackRevealData.cricketStarter({
    required PackResult result,
    required List<int> levelsGained,
  }) => PackRevealData(
    playerCards: result.playerCards,
    actionCards: result.actionCards,
    headline: 'CRICKET\nSTARTER',
    statusLabel: 'UNLOCKED',
    ctaLabel: 'ENTER SUPER OVER',
    summaryLabel: '${result.cardCount} CARDS ADDED TO YOUR COLLECTION',
    xpGained: result.xpGained,
    levelsGained: levelsGained,
    maxAnimatedPlayerCards: 3,
  );

  factory PackRevealData.basketballStarter({
    required PackResult result,
    required List<int> levelsGained,
  }) => PackRevealData(
    playerCards: result.playerCards,
    actionCards: result.actionCards,
    headline: 'HOOP\nSTARTER',
    statusLabel: 'UNLOCKED',
    ctaLabel: 'ENTER HOOP DUEL',
    summaryLabel: '${result.cardCount} CARDS ADDED TO YOUR ROSTER DECK',
    xpGained: result.xpGained,
    levelsGained: levelsGained,
    maxAnimatedPlayerCards: 3,
  );

  factory PackRevealData.tennisStarter({
    required PackResult result,
    required List<int> levelsGained,
  }) => PackRevealData(
    playerCards: result.playerCards,
    actionCards: result.actionCards,
    headline: 'TENNIS\nSTARTER',
    statusLabel: 'UNLOCKED',
    ctaLabel: 'ENTER TENNIS RALLY',
    summaryLabel: 'YOUR FIRST PLAYER IS SIGNED',
    xpGained: result.xpGained,
    levelsGained: levelsGained,
    maxAnimatedPlayerCards: tennisStarterCardCount,
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

  factory PackRevealData.streakReward({
    required String rewardName,
    required PackResult result,
    required List<int> levelsGained,
  }) => PackRevealData(
    playerCards: result.playerCards,
    actionCards: result.actionCards,
    headline: 'STREAK\nREWARD',
    statusLabel: 'CLAIMED',
    ctaLabel: 'CONTINUE',
    summaryLabel: rewardName.toUpperCase(),
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
    required this.deckBatsmen,
    required this.deckFinalOverBatsmen,
    required this.deckBasketballPlayers,
    required this.deckBasketballStarter,
    required this.deckTennisPlayers,
    required this.deckTennisStarter,
    required this.coins,
    required this.coinLedger,
    required this.xpLedger,
    required this.ownedCardIds,
    required this.ownedActionCardIds,
    required this.ownedCardBackIds,
    required this.equippedCardBackId,
    required this.ownedAvatarFrameIds,
    required this.equippedAvatarFrameId,
    required this.ownedAvatarIds,
    required this.ownedBannerIds,
    required this.ownedFinalOverKitIds,
    required this.matchHistory,
    required this.tutorialSeen,
    required this.pendingPackReveal,
    required this.starterPackClaimed,
    required this.cricketStarterPackClaimed,
    required this.basketballStarterPackClaimed,
    required this.tennisStarterPackClaimed,
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
    this.opponentName,
    required this.progression,
    required this.previousProgression,
    required this.pendingLevelUps,
    required this.lastMatchXP,
    required this.streak,
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
    deckBatsmen: cardsByIds(batsmen, defaultDeckSlots.first.batsmen),
    deckFinalOverBatsmen: cardsByIds(
      batsmen,
      defaultDeckSlots.first.finalOverBatsmen,
    ),
    deckBasketballPlayers: cardsByIds(
      basketballPlayerCards,
      defaultDeckSlots.first.basketballPlayers,
    ),
    deckBasketballStarter: cardsByIds(
      basketballPlayerCards,
      [defaultDeckSlots.first.basketballStarter].whereType<String>().toList(),
    ).firstOrNull,
    deckTennisPlayers: cardsByIds(
      tennisPlayerCards,
      defaultDeckSlots.first.tennisPlayers,
    ),
    deckTennisStarter: cardsByIds(
      tennisPlayerCards,
      [defaultDeckSlots.first.tennisStarter].whereType<String>().toList(),
    ).firstOrNull,
    coins: 0,
    coinLedger: const [],
    xpLedger: const [],
    ownedCardIds: const [],
    ownedActionCardIds: const [],
    ownedCardBackIds: const ['default'],
    equippedCardBackId: 'default',
    ownedAvatarFrameIds: const [],
    equippedAvatarFrameId: '',
    ownedAvatarIds: const [],
    ownedBannerIds: const [],
    ownedFinalOverKitIds: const ['voltage'],
    matchHistory: const [],
    tutorialSeen: const {},
    pendingPackReveal: null,
    starterPackClaimed: false,
    cricketStarterPackClaimed: false,
    basketballStarterPackClaimed: false,
    tennisStarterPackClaimed: false,
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
    streak: StreakSnapshot.seeded(DateTime.now()),
  );

  final bool loading;
  final List<StoredDeckSlot> deckSlots;
  final String activeDeckId;
  final List<PlayerCard> deckAttackers;
  final List<PlayerCard> deckDefenders;
  final List<ActionCard> deckActions;
  final PlayerCard? deckKeeper;
  final List<PlayerCard> deckBatsmen;
  final List<PlayerCard> deckFinalOverBatsmen;
  final List<PlayerCard> deckBasketballPlayers;
  final PlayerCard? deckBasketballStarter;
  final List<PlayerCard> deckTennisPlayers;
  final PlayerCard? deckTennisStarter;
  final int coins;
  final List<OzCoinLedgerEntry> coinLedger;
  final List<XpLedgerEntry> xpLedger;
  final List<String> ownedCardIds;
  final List<String> ownedActionCardIds;
  final List<String> ownedCardBackIds;
  final String equippedCardBackId;
  final List<String> ownedAvatarFrameIds;
  final String equippedAvatarFrameId;
  // Shop cosmetics bought with coins (BUY → OWNED). Avatar ids are player
  // portrait short-names; banner ids are the shop banner placeholder ids.
  final List<String> ownedAvatarIds;
  final List<String> ownedBannerIds;
  final List<String> ownedFinalOverKitIds;
  final List<MatchHistoryEntry> matchHistory;
  final Set<String> tutorialSeen;
  final PackRevealData? pendingPackReveal;
  final bool starterPackClaimed;
  final bool cricketStarterPackClaimed;
  final bool basketballStarterPackClaimed;
  final bool tennisStarterPackClaimed;
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

  /// The rival's display name when this match was launched as a leaderboard
  /// CHALLENGE; null for a normal match.
  final String? opponentName;
  final PlayerProgression progression;
  final PlayerProgression? previousProgression;
  final List<int> pendingLevelUps;
  final int? lastMatchXP;
  final StreakSnapshot streak;

  bool get hasLevelUp => pendingLevelUps.isNotEmpty;

  bool get deckReady => pitchDuelDeckReady;

  bool get pitchDuelDeckReady =>
      deckAttackers.length == 2 &&
      deckDefenders.length == 2 &&
      deckActions.length == 6 &&
      deckKeeper != null &&
      deckAttackers.every((card) => ownedCardIds.contains(card.id)) &&
      deckDefenders.every((card) => ownedCardIds.contains(card.id)) &&
      deckActions.every((card) => ownedActionCardIds.contains(card.id)) &&
      ownedCardIds.contains(deckKeeper!.id);

  bool get superOverDeckReady =>
      deckBatsmen.length == 3 &&
      deckBatsmen.every((card) => ownedCardIds.contains(card.id));

  bool get finalOverDeckReady =>
      deckFinalOverBatsmen.length == 3 &&
      deckFinalOverBatsmen.every((card) => ownedCardIds.contains(card.id));

  bool get hoopDuelDeckReady =>
      deckBasketballPlayers.length == 3 &&
      deckBasketballStarter != null &&
      deckBasketballPlayers.any(
        (card) => card.id == deckBasketballStarter!.id,
      ) &&
      deckBasketballPlayers.any(
        (card) => card.role == PlayerRole.basketballGuard,
      ) &&
      deckBasketballPlayers.any(
        (card) => card.role == PlayerRole.basketballWing,
      ) &&
      deckBasketballPlayers.any(
        (card) => card.role == PlayerRole.basketballBig,
      ) &&
      deckBasketballPlayers.every((card) => ownedCardIds.contains(card.id));

  GameState copyWith({
    bool? loading,
    List<StoredDeckSlot>? deckSlots,
    String? activeDeckId,
    List<PlayerCard>? deckAttackers,
    List<PlayerCard>? deckDefenders,
    List<ActionCard>? deckActions,
    Object? deckKeeper = _sentinel,
    List<PlayerCard>? deckBatsmen,
    List<PlayerCard>? deckFinalOverBatsmen,
    List<PlayerCard>? deckBasketballPlayers,
    Object? deckBasketballStarter = _sentinel,
    List<PlayerCard>? deckTennisPlayers,
    Object? deckTennisStarter = _sentinel,
    int? coins,
    List<OzCoinLedgerEntry>? coinLedger,
    List<XpLedgerEntry>? xpLedger,
    List<String>? ownedCardIds,
    List<String>? ownedActionCardIds,
    List<String>? ownedCardBackIds,
    String? equippedCardBackId,
    List<String>? ownedAvatarFrameIds,
    String? equippedAvatarFrameId,
    List<String>? ownedAvatarIds,
    List<String>? ownedBannerIds,
    List<String>? ownedFinalOverKitIds,
    List<MatchHistoryEntry>? matchHistory,
    Set<String>? tutorialSeen,
    Object? pendingPackReveal = _sentinel,
    bool? starterPackClaimed,
    bool? cricketStarterPackClaimed,
    bool? basketballStarterPackClaimed,
    bool? tennisStarterPackClaimed,
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
    Object? opponentName = _sentinel,
    PlayerProgression? progression,
    Object? previousProgression = _sentinel,
    List<int>? pendingLevelUps,
    Object? lastMatchXP = _sentinel,
    StreakSnapshot? streak,
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
    deckBatsmen: deckBatsmen ?? this.deckBatsmen,
    deckFinalOverBatsmen: deckFinalOverBatsmen ?? this.deckFinalOverBatsmen,
    deckBasketballPlayers: deckBasketballPlayers ?? this.deckBasketballPlayers,
    deckBasketballStarter: deckBasketballStarter == _sentinel
        ? this.deckBasketballStarter
        : deckBasketballStarter as PlayerCard?,
    deckTennisPlayers: deckTennisPlayers ?? this.deckTennisPlayers,
    deckTennisStarter: deckTennisStarter == _sentinel
        ? this.deckTennisStarter
        : deckTennisStarter as PlayerCard?,
    coins: coins ?? this.coins,
    coinLedger: coinLedger ?? this.coinLedger,
    xpLedger: xpLedger ?? this.xpLedger,
    ownedCardIds: ownedCardIds ?? this.ownedCardIds,
    ownedActionCardIds: ownedActionCardIds ?? this.ownedActionCardIds,
    ownedCardBackIds: ownedCardBackIds ?? this.ownedCardBackIds,
    equippedCardBackId: equippedCardBackId ?? this.equippedCardBackId,
    ownedAvatarFrameIds: ownedAvatarFrameIds ?? this.ownedAvatarFrameIds,
    equippedAvatarFrameId: equippedAvatarFrameId ?? this.equippedAvatarFrameId,
    ownedAvatarIds: ownedAvatarIds ?? this.ownedAvatarIds,
    ownedBannerIds: ownedBannerIds ?? this.ownedBannerIds,
    ownedFinalOverKitIds: ownedFinalOverKitIds ?? this.ownedFinalOverKitIds,
    matchHistory: matchHistory ?? this.matchHistory,
    tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    pendingPackReveal: pendingPackReveal == _sentinel
        ? this.pendingPackReveal
        : pendingPackReveal as PackRevealData?,
    starterPackClaimed: starterPackClaimed ?? this.starterPackClaimed,
    cricketStarterPackClaimed:
        cricketStarterPackClaimed ?? this.cricketStarterPackClaimed,
    basketballStarterPackClaimed:
        basketballStarterPackClaimed ?? this.basketballStarterPackClaimed,
    tennisStarterPackClaimed:
        tennisStarterPackClaimed ?? this.tennisStarterPackClaimed,
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
    opponentName: opponentName == _sentinel
        ? this.opponentName
        : opponentName as String?,
    progression: progression ?? this.progression,
    previousProgression: previousProgression == _sentinel
        ? this.previousProgression
        : previousProgression as PlayerProgression?,
    pendingLevelUps: pendingLevelUps ?? this.pendingLevelUps,
    lastMatchXP: lastMatchXP == _sentinel
        ? this.lastMatchXP
        : lastMatchXP as int?,
    streak: streak ?? this.streak,
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
