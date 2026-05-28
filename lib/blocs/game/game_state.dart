import '../../config/enums.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/match.dart';
import '../../models/progression.dart';
import '../../utils/card_helpers.dart';

class PackRevealData {
  const PackRevealData({
    required this.cards,
    required this.headline,
    required this.statusLabel,
    required this.ctaLabel,
    required this.summaryLabel,
    this.detailLabel,
  });

  factory PackRevealData.starter(List<PlayerCard> cards) => PackRevealData(
    cards: cards,
    headline: 'STARTER\nPACK',
    statusLabel: 'UNLOCKED',
    ctaLabel: 'ENTER THE GAME',
    summaryLabel: '${cards.length} CARDS ADDED TO YOUR COLLECTION',
  );

  factory PackRevealData.shop({
    required String packName,
    required List<PlayerCard> cards,
    required int refund,
    required int newCardCount,
  }) {
    final summaryLabel = refund > 0 || newCardCount < cards.length
        ? '${cards.length} CARDS REVEALED'
        : '${cards.length} CARDS ADDED TO YOUR COLLECTION';
    final detailLabel = refund > 0
        ? '$newCardCount NEW CARDS | +${_formatPackCount(refund)} COIN REFUND'
        : newCardCount < cards.length
        ? '$newCardCount NEW CARDS ADDED'
        : null;
    return PackRevealData(
      cards: cards,
      headline: packName.toUpperCase().replaceAll(' ', '\n'),
      statusLabel: 'PURCHASED',
      ctaLabel: 'CONTINUE',
      summaryLabel: summaryLabel,
      detailLabel: detailLabel,
    );
  }

  final List<PlayerCard> cards;
  final String headline;
  final String statusLabel;
  final String ctaLabel;
  final String summaryLabel;
  final String? detailLabel;
}

class GameState {
  const GameState({
    required this.loading,
    required this.deckSlots,
    required this.activeDeckId,
    required this.deckAttackers,
    required this.deckDefenders,
    required this.deckActions,
    required this.coins,
    required this.ownedCardIds,
    required this.ownedCardBackIds,
    required this.equippedCardBackId,
    required this.matchHistory,
    required this.tutorialSeen,
    required this.pendingPackReveal,
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
    required this.penaltyKicks,
    required this.penaltyPlayerScore,
    required this.penaltyOpponentScore,
    required this.penaltyRound,
    required this.penaltyPhaseOver,
    required this.penaltyPlayerDirection,
    required this.penaltyKickPhase,
    required this.penaltySuddenDeath,
    required this.penaltyWinner,
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
    coins: 5000,
    ownedCardIds: const [],
    ownedCardBackIds: const ['default'],
    equippedCardBackId: 'default',
    matchHistory: const [],
    tutorialSeen: const {},
    pendingPackReveal: null,
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
    penaltyKicks: const [],
    penaltyPlayerScore: 0,
    penaltyOpponentScore: 0,
    penaltyRound: 0,
    penaltyPhaseOver: false,
    penaltyPlayerDirection: null,
    penaltyKickPhase: 'choose',
    penaltySuddenDeath: false,
    penaltyWinner: null,
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
  final int coins;
  final List<String> ownedCardIds;
  final List<String> ownedCardBackIds;
  final String equippedCardBackId;
  final List<MatchHistoryEntry> matchHistory;
  final Set<String> tutorialSeen;
  final PackRevealData? pendingPackReveal;
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
  final List<PenaltyKick> penaltyKicks;
  final int penaltyPlayerScore;
  final int penaltyOpponentScore;
  final int penaltyRound;
  final bool penaltyPhaseOver;
  final PenaltyDirection? penaltyPlayerDirection;
  final String penaltyKickPhase; // 'choose' | 'result'
  final bool penaltySuddenDeath;
  final String? penaltyWinner; // 'player' | 'opponent'
  final PlayerProgression progression;
  final PlayerProgression? previousProgression;
  final List<int> pendingLevelUps;
  final int? lastMatchXP;

  bool get hasLevelUp => pendingLevelUps.isNotEmpty;

  bool get deckReady =>
      deckAttackers.length == 2 &&
      deckDefenders.length == 2 &&
      deckActions.length == 6;

  GameState copyWith({
    bool? loading,
    List<StoredDeckSlot>? deckSlots,
    String? activeDeckId,
    List<PlayerCard>? deckAttackers,
    List<PlayerCard>? deckDefenders,
    List<ActionCard>? deckActions,
    int? coins,
    List<String>? ownedCardIds,
    List<String>? ownedCardBackIds,
    String? equippedCardBackId,
    List<MatchHistoryEntry>? matchHistory,
    Set<String>? tutorialSeen,
    Object? pendingPackReveal = _sentinel,
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
    List<PenaltyKick>? penaltyKicks,
    int? penaltyPlayerScore,
    int? penaltyOpponentScore,
    int? penaltyRound,
    bool? penaltyPhaseOver,
    Object? penaltyPlayerDirection = _sentinel,
    String? penaltyKickPhase,
    bool? penaltySuddenDeath,
    Object? penaltyWinner = _sentinel,
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
    coins: coins ?? this.coins,
    ownedCardIds: ownedCardIds ?? this.ownedCardIds,
    ownedCardBackIds: ownedCardBackIds ?? this.ownedCardBackIds,
    equippedCardBackId: equippedCardBackId ?? this.equippedCardBackId,
    matchHistory: matchHistory ?? this.matchHistory,
    tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    pendingPackReveal: pendingPackReveal == _sentinel
        ? this.pendingPackReveal
        : pendingPackReveal as PackRevealData?,
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
    penaltyKicks: penaltyKicks ?? this.penaltyKicks,
    penaltyPlayerScore: penaltyPlayerScore ?? this.penaltyPlayerScore,
    penaltyOpponentScore: penaltyOpponentScore ?? this.penaltyOpponentScore,
    penaltyRound: penaltyRound ?? this.penaltyRound,
    penaltyPhaseOver: penaltyPhaseOver ?? this.penaltyPhaseOver,
    penaltyPlayerDirection: penaltyPlayerDirection == _sentinel
        ? this.penaltyPlayerDirection
        : penaltyPlayerDirection as PenaltyDirection?,
    penaltyKickPhase: penaltyKickPhase ?? this.penaltyKickPhase,
    penaltySuddenDeath: penaltySuddenDeath ?? this.penaltySuddenDeath,
    penaltyWinner: penaltyWinner == _sentinel
        ? this.penaltyWinner
        : penaltyWinner as String?,
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
