import 'package:flutter/material.dart';

import 'sport_match.dart';

enum PickMarketType { match, event, future }

enum PickMarketStatus { upcoming, live, closed, unresolved, settled, voided }

enum PickPositionStatus {
  pending,
  live,
  unresolved,
  settleable,
  won,
  lost,
  voided,
}

abstract final class PickMath {
  static bool isValidProbability(int probabilityPercent) =>
      probabilityPercent >= 1 && probabilityPercent <= 99;

  static bool isValidStake({
    required int stakeOz,
    required int probabilityPercent,
    required int balanceOz,
  }) {
    return stakeOz > 0 &&
        isValidProbability(probabilityPercent) &&
        stakeOz <= balanceOz &&
        stakeOz % probabilityPercent == 0;
  }

  static int sharesForStake({
    required int stakeOz,
    required int probabilityPercent,
  }) {
    if (!isValidProbability(probabilityPercent) ||
        stakeOz <= 0 ||
        stakeOz % probabilityPercent != 0) {
      return 0;
    }
    return stakeOz ~/ probabilityPercent;
  }

  static int payoutForShares(int shares) => shares * 100;

  static int profitFor({required int stakeOz, required int shares}) =>
      payoutForShares(shares) - stakeOz;
}

class PickOutcome {
  const PickOutcome({
    required this.id,
    required this.label,
    required this.probabilityPercent,
    required this.color,
  });

  final String id;
  final String label;
  final int probabilityPercent;
  final Color color;

  PickOutcome copyWith({int? probabilityPercent}) => PickOutcome(
    id: id,
    label: label,
    probabilityPercent: probabilityPercent ?? this.probabilityPercent,
    color: color,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'probabilityPercent': probabilityPercent,
    'color': color.toARGB32(),
  };

  factory PickOutcome.fromJson(Map<String, dynamic> json) => PickOutcome(
    id: json['id'] as String,
    label: json['label'] as String,
    probabilityPercent: json['probabilityPercent'] as int,
    color: Color(json['color'] as int),
  );
}

class PickPricePoint {
  const PickPricePoint({required this.at, required this.percentsByOutcome});

  final DateTime at;
  final Map<String, int> percentsByOutcome;

  int? percentFor(String outcomeId) => percentsByOutcome[outcomeId];

  Map<String, dynamic> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'percentsByOutcome': percentsByOutcome,
  };

  factory PickPricePoint.fromJson(Map<String, dynamic> json) => PickPricePoint(
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
    percentsByOutcome: (json['percentsByOutcome'] as Map).map(
      (key, value) => MapEntry(key as String, value as int),
    ),
  );
}

class PickMarket {
  const PickMarket({
    required this.id,
    required this.question,
    required this.type,
    required this.sport,
    required this.leagueId,
    required this.leagueLabel,
    required this.status,
    required this.outcomes,
    required this.volumeOz,
    required this.closesAt,
    this.priceHistory = const [],
    this.matchId,
    this.contextTitle,
    this.contextSubtitle,
    this.homeLabel,
    this.awayLabel,
    this.homeScore,
    this.awayScore,
    this.liveLabel,
    this.resultNote,
    this.resolvedOutcomeId,
    this.voidReason,
  });

  final String id;
  final String question;
  final PickMarketType type;
  final Sport sport;
  final String leagueId;
  final String leagueLabel;
  final PickMarketStatus status;
  final List<PickOutcome> outcomes;
  final int volumeOz;
  final DateTime closesAt;
  final List<PickPricePoint> priceHistory;
  final String? matchId;
  final String? contextTitle;
  final String? contextSubtitle;
  final String? homeLabel;
  final String? awayLabel;
  final String? homeScore;
  final String? awayScore;
  final String? liveLabel;
  final String? resultNote;
  final String? resolvedOutcomeId;
  final String? voidReason;

  bool get canBuy =>
      status == PickMarketStatus.upcoming || status == PickMarketStatus.live;

  bool get isResultKnown =>
      status == PickMarketStatus.settled || status == PickMarketStatus.voided;

  PickOutcome? outcomeFor(String outcomeId) {
    for (final outcome in outcomes) {
      if (outcome.id == outcomeId) return outcome;
    }
    return null;
  }

  List<int> historyFor(String outcomeId) => [
    for (final point in priceHistory)
      if (point.percentFor(outcomeId) != null) point.percentFor(outcomeId)!,
  ];

  /// Probability movement (percentage points) between the last two price
  /// points for [outcomeId]; null when there isn't enough history.
  int? latestDeltaFor(String outcomeId) {
    if (priceHistory.length < 2) return null;
    final last = priceHistory.last.percentFor(outcomeId);
    final previous = priceHistory[priceHistory.length - 2].percentFor(
      outcomeId,
    );
    if (last == null || previous == null) return null;
    return last - previous;
  }

  /// The outcome currently priced highest — the market's headline number.
  PickOutcome get leadingOutcome => outcomes.reduce(
    (a, b) => b.probabilityPercent > a.probabilityPercent ? b : a,
  );
}

class PickPosition {
  const PickPosition({
    required this.id,
    required this.marketId,
    required this.marketQuestion,
    required this.marketType,
    required this.leagueLabel,
    required this.outcomeId,
    required this.outcomeLabel,
    required this.stakeOz,
    required this.shareCount,
    required this.averageProbabilityPercent,
    required this.submittedAt,
    required this.status,
    this.resolvedAt,
    this.payoutOz = 0,
    this.resultNote,
  });

  final String id;
  final String marketId;
  final String marketQuestion;
  final PickMarketType marketType;
  final String leagueLabel;
  final String outcomeId;
  final String outcomeLabel;
  final int stakeOz;
  final int shareCount;
  final double averageProbabilityPercent;
  final DateTime submittedAt;
  final PickPositionStatus status;
  final DateTime? resolvedAt;
  final int payoutOz;
  final String? resultNote;

  int get maxPayoutOz => PickMath.payoutForShares(shareCount);
  int get profitIfCorrect => maxPayoutOz - stakeOz;
  int get realizedProfit => payoutOz - stakeOz;

  bool get isFinal =>
      status == PickPositionStatus.won ||
      status == PickPositionStatus.lost ||
      status == PickPositionStatus.voided;

  bool get canSettle => status == PickPositionStatus.settleable;

  PickPosition addBuy({
    required int stakeOz,
    required int shareCount,
    required int probabilityPercent,
  }) {
    final nextStake = this.stakeOz + stakeOz;
    final nextShares = this.shareCount + shareCount;
    return copyWith(
      stakeOz: nextStake,
      shareCount: nextShares,
      averageProbabilityPercent: nextStake / nextShares,
    );
  }

  PickPosition copyWith({
    int? stakeOz,
    int? shareCount,
    double? averageProbabilityPercent,
    PickPositionStatus? status,
    DateTime? resolvedAt,
    int? payoutOz,
    String? resultNote,
  }) => PickPosition(
    id: id,
    marketId: marketId,
    marketQuestion: marketQuestion,
    marketType: marketType,
    leagueLabel: leagueLabel,
    outcomeId: outcomeId,
    outcomeLabel: outcomeLabel,
    stakeOz: stakeOz ?? this.stakeOz,
    shareCount: shareCount ?? this.shareCount,
    averageProbabilityPercent:
        averageProbabilityPercent ?? this.averageProbabilityPercent,
    submittedAt: submittedAt,
    status: status ?? this.status,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    payoutOz: payoutOz ?? this.payoutOz,
    resultNote: resultNote ?? this.resultNote,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'marketId': marketId,
    'marketQuestion': marketQuestion,
    'marketType': marketType.name,
    'leagueLabel': leagueLabel,
    'outcomeId': outcomeId,
    'outcomeLabel': outcomeLabel,
    'stakeOz': stakeOz,
    'shareCount': shareCount,
    'averageProbabilityPercent': averageProbabilityPercent,
    'submittedAt': submittedAt.millisecondsSinceEpoch,
    'status': status.name,
    'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
    'payoutOz': payoutOz,
    'resultNote': resultNote,
  };

  factory PickPosition.fromJson(Map<String, dynamic> json) => PickPosition(
    id: json['id'] as String,
    marketId: json['marketId'] as String,
    marketQuestion: json['marketQuestion'] as String,
    marketType: PickMarketType.values.byName(json['marketType'] as String),
    leagueLabel: json['leagueLabel'] as String,
    outcomeId: json['outcomeId'] as String,
    outcomeLabel: json['outcomeLabel'] as String,
    stakeOz: json['stakeOz'] as int,
    shareCount: json['shareCount'] as int,
    averageProbabilityPercent: (json['averageProbabilityPercent'] as num)
        .toDouble(),
    submittedAt: DateTime.fromMillisecondsSinceEpoch(
      json['submittedAt'] as int,
    ),
    status: PickPositionStatus.values.byName(json['status'] as String),
    resolvedAt: json['resolvedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['resolvedAt'] as int),
    payoutOz: json['payoutOz'] as int? ?? 0,
    resultNote: json['resultNote'] as String?,
  );
}
