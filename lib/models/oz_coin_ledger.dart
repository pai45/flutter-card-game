enum OzCoinTransactionType { earn, spend, refund, topUp, openingBalance }

enum OzCoinTransactionSource {
  openingBalance,
  matchReward,
  shootoutReward,
  pickStake,
  pickPayout,
  packPurchase,
  duplicateRefund,
  directCardPurchase,
  shopTopUp,
  streakReward,
  referralReward,
  quizEntry,
  footballBingoLifeline,
  manual,
}

class OzCoinLedgerEntry {
  const OzCoinLedgerEntry({
    required this.id,
    required this.timestamp,
    required this.delta,
    required this.balanceAfter,
    required this.type,
    required this.source,
    required this.title,
    this.subtitle,
  });

  factory OzCoinLedgerEntry.fromJson(Map<String, dynamic> json) =>
      OzCoinLedgerEntry(
        id: json['id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] as int,
        ),
        delta: json['delta'] as int,
        balanceAfter: json['balanceAfter'] as int,
        type: OzCoinTransactionType.values.byName(json['type'] as String),
        source: OzCoinTransactionSource.values.byName(json['source'] as String),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
      );

  final String id;
  final DateTime timestamp;
  final int delta;
  final int balanceAfter;
  final OzCoinTransactionType type;
  final OzCoinTransactionSource source;
  final String title;
  final String? subtitle;

  bool get isPositive => delta > 0;
  bool get isNegative => delta < 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'delta': delta,
    'balanceAfter': balanceAfter,
    'type': type.name,
    'source': source.name,
    'title': title,
    'subtitle': subtitle,
  };
}
