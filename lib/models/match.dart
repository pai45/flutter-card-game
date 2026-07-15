import '../config/enums.dart';
import 'cards.dart';
import 'super_over.dart';

class MatchHistoryRound {
  const MatchHistoryRound({
    required this.round,
    required this.scenarioTitle,
    required this.outcomeLabel,
    required this.playerAttacking,
  });

  final int round;
  final String scenarioTitle;
  final String outcomeLabel;
  final bool playerAttacking;

  Map<String, dynamic> toJson() => {
    'round': round,
    'scenarioTitle': scenarioTitle,
    'outcomeLabel': outcomeLabel,
    'playerAttacking': playerAttacking,
  };

  static MatchHistoryRound fromJson(Map<String, dynamic> json) =>
      MatchHistoryRound(
        round: json['round'] as int,
        scenarioTitle: json['scenarioTitle'] as String,
        outcomeLabel: json['outcomeLabel'] as String,
        playerAttacking: json['playerAttacking'] as bool,
      );
}

class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.id,
    required this.deckName,
    required this.timestampIso,
    required this.resultLabel,
    required this.playerScore,
    required this.opponentScore,
    required this.rounds,
    this.mode = 'match',
    // Legacy in-match shootout scores; kept nullable so old saved history
    // still deserializes and renders its PEN badge.
    this.penaltyPlayerScore,
    this.penaltyOpponentScore,
    this.xpEarned,
    this.superOverSummary,
  });

  final String id;
  final String mode; // Includes match, shootout, grandprix, basketball, tennis.
  final String deckName;
  final String timestampIso;
  final String resultLabel;
  final int playerScore;
  final int opponentScore;
  final int? penaltyPlayerScore;
  final int? penaltyOpponentScore;
  final List<MatchHistoryRound> rounds;
  final int? xpEarned;
  final SuperOverMatchSummary? superOverSummary;

  bool get isShootout => mode == 'shootout';
  bool get isGrandPrix => mode == 'grandprix';
  bool get isBasketball => mode == 'basketball';
  bool get isTennis => mode == 'tennis';
  bool get isSuperOver => mode == 'super_over';

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode,
    'deckName': deckName,
    'timestampIso': timestampIso,
    'resultLabel': resultLabel,
    'playerScore': playerScore,
    'opponentScore': opponentScore,
    'penaltyPlayerScore': penaltyPlayerScore,
    'penaltyOpponentScore': penaltyOpponentScore,
    'rounds': rounds.map((round) => round.toJson()).toList(),
    'xpEarned': xpEarned,
    'superOverSummary': superOverSummary?.toJson(),
  };

  static MatchHistoryEntry fromJson(Map<String, dynamic> json) =>
      MatchHistoryEntry(
        id: json['id'] as String,
        mode: json['mode'] as String? ?? 'match',
        deckName: json['deckName'] as String,
        timestampIso: json['timestampIso'] as String,
        resultLabel: json['resultLabel'] as String,
        playerScore: json['playerScore'] as int,
        opponentScore: json['opponentScore'] as int,
        penaltyPlayerScore: json['penaltyPlayerScore'] as int?,
        penaltyOpponentScore: json['penaltyOpponentScore'] as int?,
        rounds: (json['rounds'] as List)
            .map(
              (item) =>
                  MatchHistoryRound.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
        xpEarned: json['xpEarned'] as int?,
        superOverSummary: json['superOverSummary'] is Map
            ? SuperOverMatchSummary.fromJson(
                Map<String, dynamic>.from(json['superOverSummary'] as Map),
              )
            : null,
      );
}

class RoundResult {
  const RoundResult({
    required this.round,
    required this.scenario,
    required this.playerAttacking,
    required this.attackerCard,
    required this.defenderCard,
    required this.attackAction,
    required this.defenseAction,
    required this.outcome,
    required this.attackPower,
    required this.defensePower,
  });

  final int round;
  final ScenarioCard scenario;
  final bool playerAttacking;
  final PlayerCard attackerCard;
  final PlayerCard defenderCard;
  final ActionCard attackAction;
  final ActionCard defenseAction;
  final RoundOutcome outcome;
  final double attackPower;
  final double defensePower;
}

class PenaltyKick {
  const PenaltyKick({
    required this.kickNumber,
    required this.byPlayer,
    required this.shootDirection,
    required this.diveDirection,
    required this.scored,
    this.shooter,
    this.keeper,
  });

  final int kickNumber; // 1-indexed
  final bool byPlayer; // true = player is taker
  final PenaltyDirection shootDirection;
  final PenaltyDirection diveDirection;
  final bool scored;

  // Squad context for the standalone shootout mode (in-memory only).
  final PlayerCard? shooter;
  final PlayerCard? keeper;

  String get label => scored ? 'Goal' : 'Saved';
}
